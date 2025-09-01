const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Razorpay = require('razorpay');
const axios = require('axios');

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Razorpay client
function getRazorpayClient() {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  
  if (!keyId || !keySecret) {
    throw new Error('Razorpay environment variables RAZORPAY_KEY_ID/RAZORPAY_KEY_SECRET not set');
  }
  
  return new Razorpay({
    key_id: keyId,
    key_secret: keySecret
  });
}

// Function to update payout status
async function updatePayoutStatus(snap, status, reason) {
  try {
    await snap.ref.update({
      payoutStatus: status,
      payoutError: reason
    });
  } catch (error) {
    console.error('Error updating payout status:', error);
  }
}

// Function to update booking after successful transfer
async function updateBookingAfterTransfer(snap, status, transferResp, ownerAccountId) {
  try {
    await snap.ref.update({
      payoutStatus: status,
      transferResponse: transferResp,
      turfOwnerAccountId: ownerAccountId,
      payoutMethod: 'Razorpay Route'
    });
  } catch (error) {
    console.error('Error updating booking after transfer:', error);
  }
}

// Function to resolve owner account ID from turf and user data
async function resolveOwnerAccountId(turfId, bookingData) {
  if (!turfId) return null;
  
  try {
    const db = admin.firestore();
    const turfDoc = await db.collection('turfs').doc(turfId).get();
    
    if (!turfDoc.exists) return null;
    
    const turf = turfDoc.data();
    const ownerId = turf.ownerId || bookingData.ownerId;
    
    if (!ownerId) return null;
    
    const userDoc = await db.collection('users').doc(ownerId).get();
    
    if (!userDoc.exists) return null;
    
    const user = userDoc.data();
    
    // Try common field names for Razorpay connected account id
    const candidateKeys = [
      'razorpayAccountId', 'ownerAccountId', 'accountId', 'razorpay_account_id', 'razorpay_accountId'
    ];
    
    for (const key of candidateKeys) {
      const acc = user[key];
      if (typeof acc === 'string' && acc.startsWith('acc_')) {
        return acc;
      }
    }
    
    return null;
  } catch (error) {
    console.error('Error resolving owner account ID:', error);
    return null;
  }
}

// Main function: triggered when a new booking is created
exports.onBookingCreated = functions.firestore
  .document('turfs/{turfId}/bookings/{bookingId}')
  .onCreate(async (snap, context) => {
    try {
      const data = snap.data();
      
      // Only process online confirmed payments with pending payout
      if (data.paymentMethod !== 'Online') {
        console.log('Skipping: Not an online payment');
        return;
      }
      if (data.status !== 'confirmed') {
        console.log('Skipping: Payment not confirmed');
        return;
      }
      if (data.payoutStatus === 'settled') {
        console.log('Skipping: Payout already settled');
        return;
      }

      const totalAmount = parseFloat(data.amount) || 0;
      let ownerAccountId = data.turfOwnerAccountId;
      const paymentId = data.razorpayPaymentId;
      const turfId = context.params.turfId || data.turfId;

      console.log(`Processing booking: ${context.params.bookingId}, Amount: ${totalAmount}, Turf: ${turfId}`);

      // Guard clauses
      if (totalAmount <= 0) {
        await updatePayoutStatus(snap, 'failed', 'Invalid amount');
        return;
      }

      if (!ownerAccountId || ownerAccountId === 'owner_placeholder') {
        // Try to resolve from turf -> users collection
        try {
          ownerAccountId = await resolveOwnerAccountId(turfId, data);
        } catch (error) {
          await updatePayoutStatus(snap, 'failed', `Owner account resolution error: ${error.message}`);
          return;
        }
        
        if (!ownerAccountId) {
          await updatePayoutStatus(snap, 'failed', 'Missing Razorpay connected account ID. Owner must add their Razorpay account ID to receive payments.');
          return;
        }
      }

      if (!paymentId) {
        await updatePayoutStatus(snap, 'failed', 'Missing Razorpay payment ID for transfer');
        return;
      }

      if (!ownerAccountId.startsWith('acc_')) {
        await updatePayoutStatus(snap, 'failed', 'Owner does not have a valid Razorpay connected account ID.');
        return;
      }

      // Calculate owner's share internally (confidential business logic)
      const ownerShare = calculateOwnerShare(totalAmount);
      const companyProfit = totalAmount - ownerShare;
      console.log(`Total amount paid by user: ${totalAmount}`);
      console.log(`Owner share (base amount): ${ownerShare}`);
      console.log(`Company keeps (profit + fees): ${companyProfit}`);
      console.log(`Breakdown: Base=${ownerShare}, Profit+Fees=${companyProfit}`);

      // Check if owner has Razorpay connected account or UPI details
      const ownerPaymentMethod = await getOwnerPaymentMethod(ownerAccountId, turfId, data);
      
      const client = getRazorpayClient();
      
      if (ownerPaymentMethod.type === 'razorpay') {
        // Use Razorpay Route transfer
        await processRazorpayTransfer(client, paymentId, ownerShare, ownerPaymentMethod.accountId);
      } else {
        throw new Error('No valid payment method found for owner');
      }

      // Update booking with transfer details
      await updateBookingAfterTransfer(snap, 'settled', null, ownerAccountId);
      
      // Save profit/owner share info in Firestore for tracking
      const db = admin.firestore();
      await db.collection('booking_settlements').doc(context.params.bookingId).set({
        booking_id: context.params.bookingId,
        turf_id: turfId || null,
        total_paid: totalAmount,
        owner_share: ownerShare,
        platform_profit: companyProfit,
        razorpay_payment_id: paymentId,
        owner_account_id: ownerAccountId,
        settledAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Successfully processed payout for booking ${context.params.bookingId}`);
      
    } catch (error) {
      console.error('Function execution error:', error);
      try {
        await updatePayoutStatus(snap, 'failed', `Function error: ${error.message}`);
      } catch (updateError) {
        console.error('Failed to update payout status:', updateError);
      }
    }
  });

// Returns the platform profit based on turf rate slabs
function calculatePlatformProfit(turfRate) {
  if (turfRate < 1000) {
    // 15% profit for < 1000
    return turfRate * 0.15;
  } else if (turfRate <= 3000) {
    // Fixed ₹110 profit for 1000-3000
    return 110;
  } else {
    // Fixed ₹210 profit for > 3000
    return 210;
  }
}

// Returns the total amount to charge the customer so that owner gets full turfRate after all deductions
function calculateTotalToCharge(turfRate) {
  // Platform profit as per slab
  const platformProfit = calculatePlatformProfit(turfRate);
  // Razorpay fee: 2% + 18% GST = 2.36%
  const razorpayFeePercent = 0.02 * 1.18; // 0.0236
  // Total to charge = (turfRate + platformProfit) / (1 - fee%)
  return (turfRate + platformProfit) / (1 - razorpayFeePercent);
}

// Always return the full turf rate as owner share
function calculateOwnerShare(turfRate) {
  return turfRate;
}

// Function to determine owner's payment method (Razorpay or UPI)
async function getOwnerPaymentMethod(ownerAccountId, turfId, bookingData) {
  // Only allow Razorpay Connected Account
  if (ownerAccountId && ownerAccountId.startsWith('acc_')) {
    return {
      type: 'razorpay',
      accountId: ownerAccountId
    };
  }
  throw new Error('No valid Razorpay connected account ID for owner.');
}

// Function to process Razorpay Route transfer
async function processRazorpayTransfer(client, paymentId, ownerShare, accountId) {
  try {
    const amountInPaise = Math.round(ownerShare * 100);
    
    const transferResp = await client.payment.transfer(paymentId, {
      transfers: [
        {
          account: accountId,
          amount: amountInPaise,
          currency: 'INR',
          notes: {
            purpose: 'Turf booking settlement - Base amount only',
            note: 'Company profit and platform fees retained in merchant account'
          }
        }
      ]
    });
    
    console.log(`Razorpay transfer successful: ${amountInPaise} paise to ${accountId}`);
    return transferResp;
    
  } catch (error) {
    console.error('Razorpay transfer failed:', error);
    throw error;
  }
}

// Add callable function to create Razorpay order with transfer split
exports.createRazorpayOrderWithTransfer = functions.https.onCall(async (data, context) => {
  try {
    const { totalAmount, ownerAccountId, bookingId, turfId, currency = 'INR' } = data;
    if (!totalAmount || !ownerAccountId || !bookingId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    if (!ownerAccountId.startsWith('acc_')) {
      throw new functions.https.HttpsError('failed-precondition', 'Owner Razorpay Account ID is invalid');
    }
    const client = getRazorpayClient();
    const ownerShare = calculateOwnerShare(totalAmount);
    const profit = totalAmount - ownerShare;
    const order = await client.orders.create({
      amount: Math.round(totalAmount * 100),
      currency,
      transfers: [
        {
          account: ownerAccountId,
          amount: Math.round(ownerShare * 100),
          currency,
          notes: {
            booking_id: bookingId,
            owner_share: ownerShare.toString()
          }
        }
      ],
      notes: {
        booking_id: bookingId,
        owner_share: ownerShare.toString(),
        platform_profit: profit.toString()
      }
    });
    // Save profit/owner share info in Firestore for tracking
    const db = admin.firestore();
    await db.collection('razorpay_orders').doc(order.id).set({
      booking_id: bookingId,
      turf_id: turfId || null,
      total_paid: totalAmount,
      owner_share: ownerShare,
      platform_profit: profit,
      razorpay_order_id: order.id,
      owner_account_id: ownerAccountId,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    return {
      orderId: order.id,
      ownerShare,
      profit,
      amount: totalAmount
    };
  } catch (error) {
    console.error('Error creating Razorpay order with transfer:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});