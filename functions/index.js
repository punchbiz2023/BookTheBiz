const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Razorpay = require('razorpay');
const axios = require('axios');
const express = require('express');
const bodyParser = require('body-parser');
const nodemailer = require('nodemailer');
const path = require('path');
const crypto = require('crypto');

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Razorpay client
function getRazorpayClient() {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  if (!keyId || !keySecret) {
    throw new Error('Razorpay environment variables (RAZORPAY_KEY_ID/RAZORPAY_KEY_SECRET) not set');
  }
  return new Razorpay({ key_id: keyId, key_secret: keySecret });
}

// =========================
// HELPER FUNCTIONS
// =========================

// Function to update payout status
async function updatePayoutStatus(snap, status, reason) {
  try {
    await snap.ref.update({ payoutStatus: status, payoutError: reason });
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
    
    if (!turfDoc.exists) {
      console.error(`Turf ${turfId} not found`);
      return null;
    }
    
    const turf = turfDoc.data();
    const ownerId = turf.ownerId || bookingData.ownerId;
    
    if (!ownerId) {
      console.error(`No ownerId found for turf ${turfId}`);
      return null;
    }
    
    const userDoc = await db.collection('users').doc(ownerId).get();
    
    if (!userDoc.exists) {
      console.error(`Owner user ${ownerId} not found`);
      return null;
    }
    
    const user = userDoc.data();
    
    // Try common field names for Razorpay connected account id
    const candidateKeys = ['razorpayAccountId', 'ownerAccountId', 'accountId', 'razorpay_account_id', 'razorpay_accountId'];
    for (const key of candidateKeys) {
      const acc = user[key];
      if (typeof acc === 'string' && acc.startsWith('acc_')) {
        return acc;
      }
    }
    
    // Return null instead of placeholder to trigger proper error handling
    console.error(`No valid Razorpay account ID found for owner ${ownerId}`);
    return null;
  } catch (error) {
    console.error('Error resolving owner account ID:', error);
    return null;
  }
}

// Returns the platform profit based on turf rate slabs
function calculatePlatformProfit(turfRate) {
  if (turfRate <= 1000) {
    return turfRate * 0.15;
  } else if (turfRate <= 3000) {
    return 110;
  } else {
    return 210;
  }
}

// Always return the full turf rate as owner share
function calculateOwnerShare(turfRate) {
  return turfRate;
}

// Function to determine owner's payment method
async function getOwnerPaymentMethod(ownerAccountId, turfId, bookingData) {
  if (ownerAccountId && ownerAccountId.startsWith('acc_')) {
    return { type: 'razorpay', accountId: ownerAccountId };
  }
  throw new Error('No valid Razorpay connected account ID for owner.');
}

// Function to process Razorpay Route transfer
async function processRazorpayTransfer(client, paymentId, ownerShare, accountId) {
  try {
    const amountInPaise = Math.round(ownerShare * 100);
    const transferResp = await client.payments.transfer(paymentId, {
      transfers: [{
        account: accountId,
        amount: amountInPaise,
        currency: 'INR',
        notes: {
          purpose: 'Turf booking settlement - Base amount only',
          note: 'Company profit and platform fees retained in merchant account'
        }
      }]
    });
    console.log('Razorpay transfer successful:', amountInPaise, 'paise to', accountId);
    return transferResp;
  } catch (error) {
    console.error('Razorpay transfer failed:', error);
    throw error;
  }
}

// Input validation helper for booking data
function validateBookingInput(data) {
  const errors = [];
  
  if (!data.paymentId || typeof data.paymentId !== 'string' || data.paymentId.trim().length === 0) {
    errors.push('Invalid paymentId');
  }
  
  if (!data.userId || typeof data.userId !== 'string' || data.userId.trim().length === 0) {
    errors.push('Invalid userId');
  }
  
  if (!data.turfId || typeof data.turfId !== 'string' || data.turfId.trim().length === 0) {
    errors.push('Invalid turfId');
  }
  
  const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
  if (!data.bookingDate || !dateRegex.test(data.bookingDate)) {
    errors.push('Invalid bookingDate format (expected YYYY-MM-DD)');
  } else {
    const bookingDateObj = new Date(data.bookingDate);
    if (isNaN(bookingDateObj.getTime())) {
      errors.push('Invalid bookingDate value');
    }
  }
  
  if (!Array.isArray(data.slots) || data.slots.length === 0) {
    errors.push('Slots must be a non-empty array');
  }
  
  const baseAmount = Number(data.baseAmount);
  const payableAmount = Number(data.payableAmount);
  
  if (!isFinite(baseAmount) || baseAmount <= 0) {
    errors.push('Invalid baseAmount - must be a positive number');
  }
  
  if (!isFinite(payableAmount) || payableAmount <= 0) {
    errors.push('Invalid payableAmount - must be a positive number');
  }
  
  if (isFinite(baseAmount) && isFinite(payableAmount) && payableAmount < baseAmount) {
    errors.push('Payable amount cannot be less than base amount');
  }
  
  if (!data.selectedGround || typeof data.selectedGround !== 'string' || data.selectedGround.trim().length === 0) {
    errors.push('Invalid selectedGround');
  }
  
  if (errors.length > 0) {
    throw new functions.https.HttpsError('invalid-argument', errors.join('; '));
  }
  
  return {
    ...data,
    paymentId: data.paymentId.trim(),
    userId: data.userId.trim(),
    turfId: data.turfId.trim(),
    baseAmount,
    payableAmount,
    totalHours: Number(data.totalHours) || data.slots.length,
    selectedGround: data.selectedGround.trim()
  };
}

// =========================
// NOTIFICATION FUNCTIONS
// =========================

async function sendNotificationToAdmin(title, body, data) {
  try {
    const adminQuery = await admin.firestore()
      .collection('users')
      .where('email', '==', 'adminpunc@bizgmail.com')
      .limit(1)
      .get();
      
    if (adminQuery.empty) {
      console.log('Admin user not found');
      return;
    }
    
    const adminDoc = adminQuery.docs[0];
    const adminData = adminDoc.data();
    const fcmToken = adminData.fcmToken;
    
    if (!fcmToken) {
      console.log('Admin FCM token not found');
      return;
    }
    
    const message = {
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      token: fcmToken,
      android: {
        notification: {
          channel_id: 'verification_channel',
          priority: 'high',
          default_sound: true,
          default_vibrate_timings: true,
          icon: 'app'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    };
    
    const response = await admin.messaging().send(message);
    console.log('Successfully sent notification:', response);
    return response;
  } catch (error) {
    console.error('Error sending notification:', error);
    throw error;
  }
}

async function sendNotificationToTurfOwner(ownerId, title, body, data) {
  try {
    const ownerDoc = await admin.firestore().collection('users').doc(ownerId).get();
    
    if (!ownerDoc.exists) {
      console.log('⚠️ Turf owner not found:', ownerId);
      throw new Error(`Owner user ${ownerId} not found in database`);
    }
    
    const ownerData = ownerDoc.data();
    const fcmToken = ownerData.fcmToken;
    
    if (!fcmToken) {
      console.log('⚠️ Turf owner FCM token not found:', ownerId);
      throw new Error(`FCM token not found for owner ${ownerId}`);
    }
    
    const message = {
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      token: fcmToken,
      android: {
        notification: {
          channel_id: 'turf_status_channel',
          priority: 'high',
          default_sound: true,
          default_vibrate_timings: true,
          icon: 'app'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    };
    
    try {
      const response = await admin.messaging().send(message);
      console.log('✅ Successfully sent notification to turf owner:', response);
      return response;
    } catch (fcmError) {
      // Handle specific FCM errors
      if (fcmError.code === 'messaging/registration-token-not-registered' || 
          fcmError.code === 'messaging/invalid-registration-token') {
        console.log(`⚠️ Invalid FCM token for owner ${ownerId}, removing token`);
        // Optionally remove invalid token from user document
        await ownerDoc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
        throw new Error(`Invalid FCM token for owner ${ownerId}`);
      } else if (fcmError.message && fcmError.message.includes('Requested entity was not found')) {
        console.log(`⚠️ FCM entity not found for owner ${ownerId}`);
        throw new Error(`FCM entity not found - token may be invalid or expired`);
      }
      throw fcmError;
    }
  } catch (error) {
    console.error('❌ Error sending notification to turf owner:', error);
    throw error;
  }
}

async function sendNotificationToUser(userId, title, body, data) {
  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.log('User not found:', userId);
      return;
    }
    
    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;
    
    if (!fcmToken) {
      console.log('User FCM token not found:', userId);
      return;
    }
    
    const message = {
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      token: fcmToken,
      android: {
        notification: {
          channel_id: 'refund_channel',
          priority: 'high',
          default_sound: true,
          default_vibrate_timings: true,
          icon: 'app'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    };
    
    const response = await admin.messaging().send(message);
    console.log('Successfully sent notification to user:', response);
    return response;
  } catch (error) {
    console.error('Error sending notification to user:', error);
    throw error;
  }
}

// =========================
// BOOKING CREATION TRIGGER
// =========================

exports.onBookingCreated = functions.firestore
  .document('turfs/{turfId}/bookings/{bookingId}')
  .onCreate(async (snap, context) => {
    try {
      const data = snap.data();
      const db = admin.firestore();
      
      // Mirror booking to main collection with retry logic
      const mainDocRef = db.collection('bookings').doc(context.params.bookingId);
      let retries = 3;
      let mirrored = false;
      
      while (retries > 0 && !mirrored) {
        try {
          await mainDocRef.set({
            ...data,
            turfBookingId: context.params.bookingId,
            turfId: context.params.turfId || data.turfId || null,
            mirroredAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
          mirrored = true;
        } catch (mirrorErr) {
          retries--;
          if (retries === 0) {
            console.error('Failed to mirror booking after 3 attempts:', mirrorErr);
            await db.collection('failed_mirrors').add({
              bookingId: context.params.bookingId,
              turfId: context.params.turfId,
              error: mirrorErr.message,
              data: data,
              timestamp: admin.firestore.FieldValue.serverTimestamp()
            });
          } else {
            await new Promise(resolve => setTimeout(resolve, 1000));
          }
        }
      }
      
      // Only process online confirmed payments
      if (data.paymentMethod !== 'Online') {
        console.log('Skipping payout: Not an online payment');
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
      
      console.log('Processing booking:', context.params.bookingId, 'Amount:', totalAmount, 'Turf:', turfId);
      
      // Guard clauses
      if (totalAmount <= 0) {
        await updatePayoutStatus(snap, 'failed', 'Invalid amount');
        return;
      }
      
      if (!ownerAccountId) {
        try {
          ownerAccountId = await resolveOwnerAccountId(turfId, data);
        } catch (error) {
          await updatePayoutStatus(snap, 'failed', `Owner account resolution error: ${error.message}`);
          return;
        }
      }
      
      if (!ownerAccountId) {
        await updatePayoutStatus(snap, 'failed', 'Missing Razorpay connected account ID. Owner must add their Razorpay account ID to receive payments.');
        return;
      }
      
      if (!paymentId) {
        await updatePayoutStatus(snap, 'failed', 'Missing Razorpay payment ID for transfer');
        return;
      }
      
      if (!ownerAccountId.startsWith('acc_')) {
        await updatePayoutStatus(snap, 'failed', 'Owner does not have a valid Razorpay connected account ID.');
        return;
      }
      
      // Calculate owner's share
      const ownerShare = calculateOwnerShare(totalAmount);
      const companyProfit = totalAmount - ownerShare;
      
      // Check for pending clawback deductions
      let totalDeductions = 0;
      let ownerId = null;
      
      try {
        if (data.ownerId) {
          ownerId = data.ownerId;
        } else {
          const usersQuery = await db.collection('users')
            .where('razorpayAccountId', '==', ownerAccountId)
            .limit(1)
            .get();
          if (!usersQuery.empty) {
            ownerId = usersQuery.docs[0].id;
          }
        }
        
        if (ownerId) {
          // FIX #2: Query BOTH pending AND overdue deductions
          const pendingDeductions = await db.collection('turfownerdeductions')
            .where('ownerId', '==', ownerId)
            .where('status', '==', 'pending')
            .get();
          
          const overdueDeductions = await db.collection('turfownerdeductions')
            .where('ownerId', '==', ownerId)
            .where('status', '==', 'overdue')
            .get();
          
          // Merge both query results
          const allDeductions = [...pendingDeductions.docs, ...overdueDeductions.docs];
          
          allDeductions.forEach(doc => {
            totalDeductions += (doc.data().amount || 0);
          });
          
          if (totalDeductions > 0) {
            console.log(`Found ${pendingDeductions.size} pending + ${overdueDeductions.size} overdue deductions: ₹${totalDeductions} for owner ${ownerId} (account: ${ownerAccountId})`);
          }
        }
      } catch (error) {
        console.error('Error checking deductions:', error);
      }
      
      // Calculate final payout after deductions
      const finalPayout = Math.max(0, ownerShare - totalDeductions);
      const actualDeduction = ownerShare - finalPayout;
      
      console.log('Total amount paid by user:', totalAmount);
      console.log('Owner share (base amount):', ownerShare);
      console.log('Pending deductions:', totalDeductions);
      console.log('Final payout to owner:', finalPayout);
      console.log('Company keeps (profit + fees):', companyProfit);
      
      // Mark deductions as applied BEFORE transfer attempt
      // This ensures deductions are marked even if transfer fails
      if (totalDeductions > 0 && ownerId) {
        try {
          // FIX #2: Query BOTH pending AND overdue deductions to mark as applied
          const pendingDeductions = await db.collection('turfownerdeductions')
            .where('ownerId', '==', ownerId)
            .where('status', '==', 'pending')
            .get();
          
          const overdueDeductions = await db.collection('turfownerdeductions')
            .where('ownerId', '==', ownerId)
            .where('status', '==', 'overdue')
            .get();
          
          // Merge both query results
          const allDeductions = [...pendingDeductions.docs, ...overdueDeductions.docs];
          
          if (allDeductions.length > 0) {
            const batch = db.batch();
            allDeductions.forEach(doc => {
              batch.update(doc.ref, {
                status: 'applied',
                appliedAt: admin.firestore.FieldValue.serverTimestamp(),
                appliedToBooking: context.params.bookingId,
                appliedToBookingAmount: finalPayout,
                actualDeductionAmount: actualDeduction
              });
            });
            await batch.commit();
            console.log(`✅ Marked ${allDeductions.length} deductions (${pendingDeductions.size} pending + ${overdueDeductions.size} overdue) as applied for owner ${ownerId} (booking: ${context.params.bookingId}, payout: ₹${finalPayout})`);
          }
        } catch (error) {
          console.error('❌ Error updating deduction status:', error);
          // Continue with transfer attempt even if deduction marking fails
          // This prevents blocking the payout if there's a deduction update issue
        }
      }
      
      // Process payment
      const ownerPaymentMethod = await getOwnerPaymentMethod(ownerAccountId, turfId, data);
      const client = getRazorpayClient();
      
      if (ownerPaymentMethod.type === 'razorpay') {
        try {
          await processRazorpayTransfer(client, paymentId, finalPayout, ownerPaymentMethod.accountId);
          // Update booking after successful transfer
          await updateBookingAfterTransfer(snap, 'settled', null, ownerAccountId);
          
          // Save settlement info for successful transfer
          await db.collection('booking_settlements').doc(context.params.bookingId).set({
            booking_id: context.params.bookingId,
            turf_id: turfId || null,
            total_paid: totalAmount,
            owner_share: ownerShare,
            platform_profit: companyProfit,
            pending_deductions: totalDeductions,
            final_payout: finalPayout,
            actual_deduction: actualDeduction,
            razorpay_payment_id: paymentId,
            owner_account_id: ownerAccountId,
            transfer_status: 'success',
            settled_at: admin.firestore.FieldValue.serverTimestamp()
          });
          
          console.log('✅ Successfully processed payout for booking:', context.params.bookingId);
        } catch (transferError) {
          console.error('❌ Razorpay transfer failed:', transferError);
          // Mark as failed but deductions are already marked as applied
          await updatePayoutStatus(snap, 'failed', `Razorpay transfer failed: ${transferError.message}`);
          
          // Save settlement info even for failed transfer (deductions were applied)
          try {
            await db.collection('booking_settlements').doc(context.params.bookingId).set({
              booking_id: context.params.bookingId,
              turf_id: turfId || null,
              total_paid: totalAmount,
              owner_share: ownerShare,
              platform_profit: companyProfit,
              pending_deductions: totalDeductions,
              final_payout: finalPayout,
              actual_deduction: actualDeduction,
              razorpay_payment_id: paymentId,
              owner_account_id: ownerAccountId,
              transfer_status: 'failed',
              transfer_error: transferError.message,
              deductions_applied: true, // Important: deductions were marked as applied
              settled_at: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
          } catch (settlementError) {
            console.error('Error saving failed settlement info:', settlementError);
          }
          
          throw transferError; // Re-throw to be caught by outer catch block
        }
      }
    } catch (error) {
      console.error('Function execution error:', error);
      try {
        await updatePayoutStatus(snap, 'failed', `Function error: ${error.message}`);
      } catch (updateError) {
        console.error('Failed to update payout status:', updateError);
      }
    }
  });

// =========================
// BOOKING CONFIRMATION
// =========================

// Internal function to create booking (shared logic)
async function createBookingInternal(validatedData) {
  const { orderId, paymentId, userId, turfId, turfName = '', ownerId = '', bookingDate, selectedGround, slots, totalHours, baseAmount, payableAmount } = validatedData;
    
    const db = admin.firestore();
    
    // Check for duplicate booking with same payment ID (idempotency)
    const existingBooking = await db.collection('bookings')
      .where('razorpayPaymentId', '==', paymentId)
      .limit(1)
      .get();
    
    if (!existingBooking.empty) {
      const existing = existingBooking.docs[0].data();
      console.log('Duplicate booking attempt detected for payment:', paymentId);
      return {
        ok: true,
        status: 'confirmed',
        turfBookingId: existingBooking.docs[0].id,
        bookingId: existingBooking.docs[0].id,
        message: 'Booking already exists for this payment'
      };
    }
    
    const client = getRazorpayClient();
    const payment = await client.payments.fetch(paymentId);
    
    if (!payment || payment.status !== 'captured') {
      throw new functions.https.HttpsError('failed-precondition', 'Payment not captured');
    }
    
    if (payment.order_id !== orderId) {
      throw new functions.https.HttpsError('failed-precondition', 'Payment does not match order');
    }
    
    const paidAmountInr = Number(payment.amount) / 100.0;
    if (Math.abs(paidAmountInr - payableAmount) > 0.01) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Payment verification failed. Expected: ₹${payableAmount.toFixed(2)}, Received: ₹${paidAmountInr.toFixed(2)}`
      );
    }
    
    const lockId = `${turfId}_${selectedGround}_${bookingDate}_${slots.sort().join('_')}`;
    const lockRef = db.collection('slot_locks').doc(lockId);
    
    try {
      const result = await db.runTransaction(async (tx) => {
        // ✅ BUG FIX #1: ALL READS FIRST, THEN ALL WRITES
        // STEP 1: Do ALL READS FIRST
        const lockDoc = await tx.get(lockRef);
        
        const bookingsCol = db.collection('turfs').doc(turfId).collection('bookings');
        const q = await tx.get(
          bookingsCol
            .where('selectedGround', '==', selectedGround)
            .where('bookingDate', '==', bookingDate)
        );
        
        // STEP 2: VALIDATE (after reads completed)
        if (lockDoc.exists) {
          const lockData = lockDoc.data();
          if (lockData.locked) {
            const expiresAt = lockData.expiresAt?.toDate();
            if (expiresAt && expiresAt > new Date()) {
              throw new functions.https.HttpsError('aborted', 'Slots are currently being booked. Please try again.');
            }
          }
        }
        
        let allBooked = [];
        q.forEach(doc => {
          const s = doc.data().bookingSlots || [];
          allBooked = allBooked.concat(s);
        });
        
        const hasConflict = slots.some(slot => allBooked.includes(slot));
        if (hasConflict) {
          throw new functions.https.HttpsError('aborted', 'Selected slots already booked');
        }
        
        // STEP 3: Do ALL WRITES
        tx.set(lockRef, {
          locked: true,
          userId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30000))
        });
        
        const now = admin.firestore.FieldValue.serverTimestamp();
        const bookingData = {
          userId,
          userName: validatedData.userName || 'User',
          bookingDate,
          bookingSlots: slots,
          totalHours: Number(totalHours) || slots.length,
          amount: payableAmount,
          baseAmount: baseAmount,
          turfId,
          turfName,
          selectedGround,
          paymentMethod: 'Online',
          status: 'confirmed',
          payoutStatus: 'pending',
          razorpayPaymentId: paymentId,
          razorpayOrderId: orderId,
          ownerId: ownerId || null,
          createdAt: now,
          updatedAt: now
        };
        
        const turfBookingRef = bookingsCol.doc();
        tx.set(turfBookingRef, bookingData);
        tx.delete(lockRef);
        
        return { turfBookingId: turfBookingRef.id, bookingId: turfBookingRef.id };
      });
      
      // Update razorpay_orders to mark booking as completed
      try {
        await db.collection('razorpay_orders').doc(orderId).update({
          booking_completed: true,
          completed_at: admin.firestore.FieldValue.serverTimestamp()
        });
      } catch (updateErr) {
        console.error('Failed to update razorpay_orders booking_completed flag:', updateErr);
        // Don't throw - booking was created successfully
      }
      
      return { ok: true, status: 'confirmed', ...result };
      
    } catch (txError) {
      // Ensure lock is released on any transaction error
      try {
        await lockRef.delete();
      } catch (deleteErr) {
        console.error('Failed to release lock after error:', deleteErr);
      }
      throw txError;
    }
}

// Public function for direct booking confirmation
exports.confirmBookingAndWrite = functions.https.onCall(async (data, context) => {
  try {
    // Validate and sanitize input
    const validatedData = validateBookingInput(data);
    
    // Call internal shared function
    return await createBookingInternal(validatedData);
    
  } catch (error) {
    console.error('confirmBookingAndWrite error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// =========================
// ✅ BUG FIX #2: PAYMENT RECOVERY FOR LOW-RAM DEVICES
// =========================

exports.verifyAndCompleteBooking = functions.https.onCall(async (data, context) => {
  try {
    const { orderId, bookingData } = data;
    
    if (!orderId || !bookingData) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing orderId or bookingData');
    }
    
    const db = admin.firestore();
    
    // Check if booking already exists (idempotency)
    const existingBooking = await db
      .collection('bookings')
      .where('razorpayOrderId', '==', orderId)
      .limit(1)
      .get();
    
    if (!existingBooking.empty) {
      const existing = existingBooking.docs[0].data();
      console.log('Booking already exists for order:', orderId);
      return {
        ok: true,
        status: 'confirmed',
        bookingId: existingBooking.docs[0].id,
        message: 'Booking already confirmed for this payment'
      };
    }
    
    // Fetch order details from razorpay_orders collection
    const orderDoc = await db.collection('razorpay_orders').doc(orderId).get();
    
    if (!orderDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Order not found in database');
    }
    
    const orderData = orderDoc.data();
    const client = getRazorpayClient();
    
    // Fetch order from Razorpay to get payment info
    const order = await client.orders.fetch(orderId);
    
    if (!order) {
      throw new functions.https.HttpsError('not-found', 'Order not found in Razorpay');
    }
    
    // Get payments for this order
    const payments = await client.orders.fetchPayments(orderId);
    
    if (!payments || !payments.items || payments.items.length === 0) {
      throw new functions.https.HttpsError('failed-precondition', 'No payment found for this order');
    }
    
    // Find captured payment
    const capturedPayment = payments.items.find((p) => p.status === 'captured');
    
    if (!capturedPayment) {
      throw new functions.https.HttpsError('failed-precondition', 'Payment not captured yet');
    }
    
    // Validate and call internal booking function
    const validatedData = validateBookingInput({
      orderId: orderId,
      paymentId: capturedPayment.id,
      ...bookingData
    });
    
    return await createBookingInternal(validatedData);
  } catch (error) {
    console.error('verifyAndCompleteBooking error:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// =========================
// ✅ RECOVERY: Check razorpay_orders for incomplete bookings
// =========================
exports.recoverIncompleteBookings = functions.https.onCall(async (data, context) => {
  try {
    const userId = data.userId || context.auth?.uid;
    if (!userId) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const db = admin.firestore();
    const client = getRazorpayClient();
    const recoveredBookings = [];
    const errors = [];
    
    // Query razorpay_orders for this user with booking_id
    // Note: We'll filter for incomplete bookings in the loop since Firestore doesn't support != null
    const userOrders = await db.collection('razorpay_orders')
      .where('user_id', '==', userId)
      .get();
    
    // Filter for orders with booking_id that are not completed
    const incompleteOrders = userOrders.docs.filter(doc => {
      const data = doc.data();
      return data.booking_id != null && data.booking_completed !== true;
    });
    
    console.log(`[Recovery] Found ${incompleteOrders.length} incomplete razorpay orders for user ${userId}`);
    
    for (const orderDoc of incompleteOrders) {
      const orderData = orderDoc.data();
      const orderId = orderDoc.id;
      const bookingId = orderData.booking_id;
      const turfId = orderData.turf_id;
      
      try {
        // Check if booking exists in bookings collection
        const bookingsQuery = await db.collection('bookings')
          .where('razorpayOrderId', '==', orderId)
          .limit(1)
          .get();
        
        // Check if booking exists in turfs/{turfId}/bookings
        let turfBookingExists = false;
        if (turfId) {
          const turfBookingsQuery = await db.collection('turfs').doc(turfId)
            .collection('bookings')
            .where('razorpayOrderId', '==', orderId)
            .limit(1)
            .get();
          turfBookingExists = !turfBookingsQuery.empty;
        }
        
        // If booking exists, mark as completed
        if (!bookingsQuery.empty || turfBookingExists) {
          await db.collection('razorpay_orders').doc(orderId).update({
            booking_completed: true,
            completed_at: admin.firestore.FieldValue.serverTimestamp()
          });
          console.log(`[Recovery] Booking already exists for order ${orderId}, marked as completed`);
          continue;
        }
        
        // Check payment status in Razorpay
        const order = await client.orders.fetch(orderId);
        if (!order) {
          console.log(`[Recovery] Order ${orderId} not found in Razorpay`);
          continue;
        }
        
        const payments = await client.orders.fetchPayments(orderId);
        const capturedPayment = payments?.items?.find((p) => p.status === 'captured');
        
        if (!capturedPayment) {
          console.log(`[Recovery] Payment not captured for order ${orderId}`);
          continue;
        }
        
        // Payment is captured but booking doesn't exist - create it
        console.log(`[Recovery] Payment captured but booking missing for order ${orderId}, creating booking...`);
        
        // Check if this is a queue-based booking (has reservation_id)
        const reservationId = orderData.reservation_id;
        
        if (reservationId) {
          // This is a queue-based booking - use confirmBookingAfterPayment to handle queue updates
          console.log(`[Recovery] Queue-based booking detected, reservationId: ${reservationId}`);
          
          if (!orderData.booking_data) {
            console.log(`[Recovery] No booking_data stored for order ${orderId}, cannot recover`);
            errors.push({ orderId, error: 'No booking data stored' });
            continue;
          }
          
          const bookingData = orderData.booking_data;
          
          // Use confirmBookingAfterPaymentInternal which handles queue updates
          try {
            const confirmResult = await confirmBookingAfterPaymentInternal({
              orderId: orderId,
              paymentId: capturedPayment.id,
              reservationId: reservationId,
              userId: userId,
              userName: bookingData.userName || 'User',
              turfId: turfId,
              turfName: bookingData.turfName || '',
              ownerId: bookingData.ownerId || '',
              bookingDate: bookingData.bookingDate,
              selectedGround: bookingData.selectedGround,
              slots: bookingData.slots,
              totalHours: bookingData.totalHours,
              baseAmount: bookingData.baseAmount || orderData.base_turf_amount,
              payableAmount: orderData.total_paid,
            });
            
            if (confirmResult.ok) {
              recoveredBookings.push({ orderId, bookingId: confirmResult.bookingId, reservationId: reservationId });
              console.log(`[Recovery] Successfully recovered queue-based booking for order ${orderId}, reservation ${reservationId}`);
            } else {
              errors.push({ orderId, error: 'Failed to confirm booking after payment' });
            }
          } catch (confirmError) {
            console.error(`[Recovery] Error confirming booking for reservation ${reservationId}:`, confirmError);
            errors.push({ orderId, reservationId, error: confirmError.message });
          }
        } else {
          // Old-style booking (non-queue) - use createBookingInternal
        if (!orderData.booking_data) {
          console.log(`[Recovery] No booking_data stored for order ${orderId}, cannot recover`);
          errors.push({ orderId, error: 'No booking data stored' });
          continue;
        }
        
        const bookingData = orderData.booking_data;
        const validatedData = validateBookingInput({
          orderId: orderId,
          paymentId: capturedPayment.id,
          userId: userId,
          turfId: turfId,
          turfName: bookingData.turfName || '',
          ownerId: bookingData.ownerId || '',
          bookingDate: bookingData.bookingDate,
          selectedGround: bookingData.selectedGround,
          slots: bookingData.slots,
          totalHours: bookingData.totalHours,
          baseAmount: bookingData.baseAmount || orderData.base_turf_amount,
          payableAmount: orderData.total_paid,
          userName: bookingData.userName || 'User'
        });
        
        const result = await createBookingInternal(validatedData);
        recoveredBookings.push({ orderId, bookingId: result.bookingId });
        console.log(`[Recovery] Successfully created booking for order ${orderId}`);
        }
        
      } catch (orderError) {
        console.error(`[Recovery] Error processing order ${orderId}:`, orderError);
        errors.push({ orderId, error: orderError.message });
      }
    }
    
    return {
      ok: true,
      recoveredCount: recoveredBookings.length,
      recoveredBookings,
      errors: errors.length > 0 ? errors : null
    };
    
  } catch (error) {
    console.error('recoverIncompleteBookings error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// =========================
// ✅ RECOVERY: Check razorpay_orders for incomplete event registrations
// =========================
exports.recoverIncompleteEventRegistrations = functions.https.onCall(async (data, context) => {
  try {
    const userId = data.userId || context.auth?.uid;
    if (!userId) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const db = admin.firestore();
    const client = getRazorpayClient();
    const recoveredRegistrations = [];
    const errors = [];
    
    // Query razorpay_orders for this user with registration_id
    const userOrders = await db.collection('razorpay_orders')
      .where('user_id', '==', userId)
      .get();
    
    // Filter for orders with registration_id that are not completed
    const incompleteOrders = userOrders.docs.filter(doc => {
      const data = doc.data();
      return data.registration_id != null && data.registration_completed !== true;
    });
    
    console.log(`[Recovery] Found ${incompleteOrders.length} incomplete event registrations for user ${userId}`);
    
    for (const orderDoc of incompleteOrders) {
      const orderData = orderDoc.data();
      const orderId = orderDoc.id;
      const registrationId = orderData.registration_id;
      const eventId = orderData.event_id;
      
      try {
        // Check if registration exists in event_registrations collection
        const registrationsQuery = await db.collection('event_registrations')
          .where('razorpayOrderId', '==', orderId)
          .limit(1)
          .get();
        
        // If registration exists, mark as completed
        if (!registrationsQuery.empty) {
          await db.collection('razorpay_orders').doc(orderId).update({
            registration_completed: true,
            completed_at: admin.firestore.FieldValue.serverTimestamp()
          });
          console.log(`[Recovery] Registration already exists for order ${orderId}, marked as completed`);
          continue;
        }
        
        // Check payment status in Razorpay
        const order = await client.orders.fetch(orderId);
        if (!order) {
          console.log(`[Recovery] Order ${orderId} not found in Razorpay`);
          continue;
        }
        
        const payments = await client.orders.fetchPayments(orderId);
        const capturedPayment = payments?.items?.find((p) => p.status === 'captured');
        
        if (!capturedPayment) {
          console.log(`[Recovery] Payment not captured for order ${orderId}`);
          continue;
        }
        
        // Payment is captured but registration doesn't exist - create it
        console.log(`[Recovery] Payment captured but registration missing for order ${orderId}, creating registration...`);
        
        // Check if this is a queue-based registration (has reservation_id)
        const reservationId = orderData.reservation_id;
        
        if (reservationId) {
          // This is a queue-based registration - use confirmEventRegistrationAfterPaymentInternal to handle queue updates
          console.log(`[Recovery] Queue-based event registration detected, reservationId: ${reservationId}`);
          
          if (!orderData.registration_data) {
            console.log(`[Recovery] No registration_data stored for order ${orderId}, cannot recover`);
            errors.push({ orderId, error: 'No registration data stored' });
            continue;
          }
          
          const registrationData = orderData.registration_data;
          
          // Use confirmEventRegistrationAfterPaymentInternal which handles queue updates
          try {
            const confirmResult = await confirmEventRegistrationAfterPaymentInternal({
              orderId: orderId,
              paymentId: capturedPayment.id,
              reservationId: reservationId,
              userId: userId,
              userName: registrationData.userName || 'User',
              eventId: eventId,
              eventName: registrationData.eventName || '',
              ownerId: registrationData.ownerId || '',
              eventDate: registrationData.eventDate,
              eventTime: registrationData.eventTime,
              eventLocation: registrationData.eventLocation || orderData.event_location || '',
              eventType: registrationData.eventType || orderData.event_type || '',
              baseAmount: registrationData.baseAmount || orderData.base_event_amount,
              payableAmount: orderData.total_paid,
              userEmail: registrationData.userEmail || orderData.user_email || '',
              userPhone: registrationData.userPhone || orderData.user_phone || '',
              userImageUrl: registrationData.userImageUrl || ''
            });
            
            if (confirmResult.ok) {
              recoveredRegistrations.push({ orderId, registrationId: confirmResult.registrationId, reservationId: reservationId });
              console.log(`[Recovery] Successfully recovered queue-based event registration for order ${orderId}, reservation ${reservationId}`);
            } else {
              errors.push({ orderId, error: 'Failed to confirm registration after payment' });
            }
          } catch (confirmError) {
            console.error(`[Recovery] Error confirming registration for reservation ${reservationId}:`, confirmError);
            errors.push({ orderId, reservationId, error: confirmError.message });
          }
        } else {
          // Old-style registration (non-queue) - use createEventRegistrationInternal
        if (!orderData.registration_data) {
          console.log(`[Recovery] No registration_data stored for order ${orderId}, cannot recover`);
          errors.push({ orderId, error: 'No registration data stored' });
          continue;
        }
        
        const registrationData = orderData.registration_data;
        const result = await createEventRegistrationInternal({
          orderId: orderId,
          paymentId: capturedPayment.id,
          userId: userId,
          eventId: eventId,
          eventName: registrationData.eventName || '',
          ownerId: registrationData.ownerId || '',
          eventDate: registrationData.eventDate,
          eventTime: registrationData.eventTime,
          eventLocation: registrationData.eventLocation || orderData.event_location || '',
          eventType: registrationData.eventType || orderData.event_type || '',
          baseAmount: registrationData.baseAmount || orderData.base_event_amount,
          payableAmount: orderData.total_paid,
          userName: registrationData.userName || 'User',
          userEmail: registrationData.userEmail || orderData.user_email || '',
          userPhone: registrationData.userPhone || orderData.user_phone || '',
          userImageUrl: registrationData.userImageUrl || ''
        });
        
        recoveredRegistrations.push({ orderId, registrationId: result.registrationId });
        console.log(`[Recovery] Successfully created registration for order ${orderId}`);
        }
        
      } catch (orderError) {
        console.error(`[Recovery] Error processing order ${orderId}:`, orderError);
        errors.push({ orderId, error: orderError.message });
      }
    }
    
    return {
      ok: true,
      recoveredCount: recoveredRegistrations.length,
      recoveredRegistrations,
      errors: errors.length > 0 ? errors : null
    };
    
  } catch (error) {
    console.error('recoverIncompleteEventRegistrations error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Cleanup expired locks
exports.cleanupExpiredLocks = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const expiredLocks = await db.collection('slot_locks')
    .where('expiresAt', '<=', now)
    .get();
  
  const batch = db.batch();
  expiredLocks.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
  console.log(`Cleaned up ${expiredLocks.size} expired locks`);
});

// =========================
// REFUND FUNCTIONS
// =========================

exports.createRefundRequest = functions.https.onCall(async (data, context) => {
  try {
    const { bookingId, userId, turfId, amount, paymentId, reason = 'User requested cancellation', bookingDate, turfName, ground, slots } = data;
    
    if (!bookingId || !userId || !amount || !paymentId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    const db = admin.firestore();
    
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    const bookingData = bookingDoc.exists ? bookingDoc.data() : {};
    const baseAmount = bookingData.baseAmount || (parseFloat(amount) * 0.85);
    
    const refundRequest = {
      bookingId,
      userId,
      turfId,
      amount: parseFloat(amount),
      baseAmount: baseAmount,
      paymentId,
      reason,
      status: 'pending',
      bookingDate,
      turfName,
      ground,
      slots: slots || [],
      requestedAt: admin.firestore.FieldValue.serverTimestamp(),
      processedAt: null,
      refundId: null,
      adminNotes: '',
      createdBy: 'user'
    };
    
    const refundDoc = await db.collection('refund_requests').add(refundRequest);
    
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.exists ? userDoc.data() : {};
    const userName = userData.name || 'User';
    
    await sendNotificationToAdmin(
      'New Refund Request',
      `${userName} has requested a refund of ₹${amount} for booking cancellation`,
      {
        type: 'refund_request',
        refundRequestId: refundDoc.id,
        bookingId,
        userId,
        amount: parseFloat(amount),
        userName,
        timestamp: new Date().toISOString()
      }
    );
    
    await db.collection('bookings').doc(bookingId).update({
      status: 'cancelled',
      refundRequestId: refundDoc.id,
      cancelledAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return {
      success: true,
      refundRequestId: refundDoc.id,
      message: 'Refund request submitted successfully. Admin will review and process your refund.'
    };
  } catch (error) {
    console.error('Error creating refund request:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

exports.processRefund = functions.https.onCall(async (data, context) => {
  try {
    const { refundRequestId, action, adminNotes = '' } = data;
    
    if (!refundRequestId || !action) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    const db = admin.firestore();
    const reqSnap = await db.collection('refund_requests').doc(refundRequestId).get();
    
    if (!reqSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Refund request not found');
    }
    
    const req = reqSnap.data();
    
    if (req.status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 'Refund request already processed');
    }
    
    if (action === 'reject') {
      await reqSnap.ref.update({
        status: 'rejected',
        adminNotes,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      const isEventRefund = req.type === 'event' || !!req.registrationId || !!req.eventId;
      
      await sendNotificationToUser(
        req.userId,
        'Refund Request Rejected',
        `Your refund request has been rejected. ${adminNotes}. Please contact support for more details.`,
        {
          type: 'refund_rejected',
          refundRequestId,
          bookingId: req.bookingId || null,
          registrationId: req.registrationId || null,
          eventId: req.eventId || null
        }
      );
      
      return { success: true, message: 'Refund request rejected' };
    }
    
    // APPROVE
    const client = getRazorpayClient();
    const paymentId = String(req.paymentId).trim();
    const totalAmountInr = Number(req.amount);
    
    if (!paymentId || !isFinite(totalAmountInr) || totalAmountInr <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid paymentId or amount');
    }
    
    // Fetch payment details with better error handling
    let payment;
    try {
      payment = await client.payments.fetch(paymentId);
    } catch (fetchError) {
      const errorMsg = fetchError?.error?.description || fetchError?.description || fetchError?.message || 'Failed to fetch payment details';
      console.error('Error fetching payment:', fetchError);
      throw new functions.https.HttpsError('failed-precondition', `Payment fetch failed: ${errorMsg}`);
    }
    
    if (!payment) {
      throw new functions.https.HttpsError('not-found', 'Payment not found');
    }
    
    console.log(`Payment status: ${payment.status}, Amount: ${payment.amount}, Refunded: ${payment.amount_refunded}`);
    
    if (payment.status !== 'captured') {
      throw new functions.https.HttpsError('failed-precondition', `Payment status is '${payment.status}', not 'captured'. Cannot process refund.`);
    }
    
    const paidPaise = Number(payment.amount) || 0;
    const refundedPaise = Number(payment.amount_refunded) || 0;
    const remainingPaise = paidPaise - refundedPaise;
    const requestedPaise = Math.round(totalAmountInr * 100);
    
    console.log(`Refund calculation: Paid=${paidPaise}, Refunded=${refundedPaise}, Remaining=${remainingPaise}, Requested=${requestedPaise}`);
    
    if (remainingPaise <= 0) {
      throw new functions.https.HttpsError('failed-precondition', 'Payment has already been fully refunded. No remaining amount to refund.');
    }
    
    if (requestedPaise > remainingPaise) {
      throw new functions.https.HttpsError('failed-precondition', `Requested refund (₹${(requestedPaise/100).toFixed(2)}) exceeds remaining refundable amount (₹${(remainingPaise/100).toFixed(2)}).`);
    }
    
    // Determine if this is an event or turf refund
    const isEventRefund = req.type === 'event' || !!req.registrationId || !!req.eventId;
    
    // Get owner ID based on refund type
    let ownerId = null;
    let ownerAccountId = null;
    
    if (isEventRefund) {
      // For event refunds, get owner from event document
      try {
        const eventId = req.eventId;
        if (eventId) {
          const eventDoc = await db.collection('spot_events').doc(eventId).get();
          if (eventDoc.exists) {
            ownerId = eventDoc.data().ownerId;
            if (ownerId) {
              const ownerDoc = await db.collection('users').doc(ownerId).get();
              if (ownerDoc.exists) {
                ownerAccountId = ownerDoc.data().razorpayAccountId;
              }
            }
          }
        }
      } catch (error) {
        console.error('Error fetching event owner:', error);
      }
    } else {
      // For turf refunds, get owner from booking document
      const bookingId = req.bookingId;
      if (bookingId) {
        const bookingDoc = await db.collection('bookings').doc(bookingId).get();
        const bookingData = bookingDoc.exists ? bookingDoc.data() : {};
        
        ownerId = bookingData.ownerId;
        if (!ownerId && req.turfId) {
          try {
            const turfDoc = await db.collection('turfs').doc(req.turfId).get();
            if (turfDoc.exists) {
              ownerId = turfDoc.data().ownerId;
            }
          } catch (error) {
            console.error('Error fetching turf owner:', error);
          }
        }
      }
    }
    
    const baseAmount = Number(req.baseAmount) || (totalAmountInr * 0.85);
    const platformAmount = totalAmountInr - baseAmount;
    
    let refund;
    try {
      console.log(`Attempting Razorpay refund: PaymentId=${paymentId}, Amount=${requestedPaise} paise (₹${(requestedPaise/100).toFixed(2)})`);
      
      // Refund FULL amount to customer
      refund = await client.payments.refund(paymentId, {
        amount: requestedPaise,
        notes: {
          reason: String(req.reason || ''),
          booking_id: String(req.bookingId || req.registrationId || ''),
          registration_id: String(req.registrationId || ''),
          event_id: String(req.eventId || ''),
          refund_request_id: String(refundRequestId || ''),
          full_refund: 'true',
          type: isEventRefund ? 'event' : 'turf'
        }
      });
      
      console.log(`Razorpay refund successful: RefundId=${refund.id}, Status=${refund.status}`);
    } catch (refundError) {
      console.error('Razorpay refund API error:', JSON.stringify(refundError, null, 2));
      
      // Extract error message from Razorpay error structure
      let errorMessage = 'Unknown error';
      if (refundError?.error?.description) {
        errorMessage = refundError.error.description;
      } else if (refundError?.error?.field) {
        errorMessage = `${refundError.error.field}: ${refundError.error.description || refundError.error.message || 'Invalid field'}`;
      } else if (refundError?.description) {
        errorMessage = refundError.description;
      } else if (refundError?.message) {
        errorMessage = refundError.message;
      } else if (typeof refundError === 'string') {
        errorMessage = refundError;
      } else {
        errorMessage = JSON.stringify(refundError);
      }
      
      console.error('Extracted error message:', errorMessage);
      
      await reqSnap.ref.update({
        status: 'failed',
        adminNotes: `Razorpay refund failed: ${errorMessage}`,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      throw new functions.https.HttpsError('failed-precondition', `Razorpay refund failed: ${errorMessage}`);
    }
    
    // Use transaction to ensure all database updates succeed together
    await db.runTransaction(async (tx) => {
      // Create clawback for owner's share ONLY
      if (baseAmount > 0 && ownerId) {
        const deductionRef = db.collection('turfownerdeductions').doc();
        const deductionData = {
          ownerId: ownerId,
          refundRequestId: refundRequestId,
          refundId: refund.id,
          amount: baseAmount,
          reason: 'Automated clawback for approved refund - owner share only',
          status: 'pending',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          appliedAt: null,
          notes: {
            customerRefund: totalAmountInr,
            platformAbsorbed: platformAmount,
            clawbackAmount: baseAmount,
            type: isEventRefund ? 'event' : 'turf'
          }
        };
        
        // Add type-specific fields
        if (isEventRefund) {
          deductionData.eventId = req.eventId || null;
          deductionData.registrationId = req.registrationId || null;
        } else {
          deductionData.turfId = req.turfId || null;
          deductionData.bookingId = req.bookingId || null;
        }
        
        tx.set(deductionRef, deductionData);
        console.log(`Clawback created: ₹${baseAmount} (Platform absorbs: ₹${platformAmount})`);
      }
      
      // Update refund request
      tx.update(reqSnap.ref, {
        status: 'processed',
        refundId: refund.id,
        razorpayRefundId: refund.id,
        refundStatus: refund.status,
        adminNotes,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        refundBreakdown: {
          totalAmount: totalAmountInr,
          baseAmount: baseAmount,
          platformAmount: platformAmount,
          clawbackCreated: (baseAmount > 0 && ownerId) ? true : false
        }
      });
      
      // Update booking or registration based on type
      if (isEventRefund && req.registrationId) {
        const registrationRef = db.collection('event_registrations').doc(req.registrationId);
        tx.update(registrationRef, {
          refundStatus: 'processed',
          refundId: refund.id,
          refundedAt: admin.firestore.FieldValue.serverTimestamp(),
          refundBreakdown: {
            totalAmount: totalAmountInr,
            baseAmount: baseAmount,
            platformAmount: platformAmount,
            clawbackCreated: (baseAmount > 0 && ownerId) ? true : false
          }
        });
      } else if (!isEventRefund && req.bookingId) {
        const bookingRef = db.collection('bookings').doc(req.bookingId);
        tx.update(bookingRef, {
          refundStatus: 'processed',
          refundId: refund.id,
          refundedAt: admin.firestore.FieldValue.serverTimestamp(),
          refundBreakdown: {
            totalAmount: totalAmountInr,
            baseAmount: baseAmount,
            platformAmount: platformAmount,
            clawbackCreated: (baseAmount > 0 && ownerId) ? true : false
          }
        });
      }
    });
    
    await sendNotificationToUser(
      req.userId,
      'Refund Processed Successfully',
      `Your refund of ₹${totalAmountInr.toFixed(2)} has been processed and will reflect in your account within 5-7 business days.`,
      {
        type: 'refund_processed',
        refundRequestId,
        bookingId: req.bookingId || null,
        registrationId: req.registrationId || null,
        eventId: req.eventId || null,
        amount: totalAmountInr,
        refundId: refund.id
      }
    );
    
    return { success: true, refundId: refund.id, message: 'Refund processed successfully' };
  } catch (err) {
    console.error('processRefund outer catch error:', JSON.stringify(err, null, 2));
    
    // Extract error message with better handling
    let finalMsg = 'Unknown error occurred';
    
    if (err instanceof functions.https.HttpsError) {
      finalMsg = err.message || err.code || 'HttpsError occurred';
    } else {
      const raw = err?.error || err?.response || err;
      const rpMsg = raw?.description || raw?.error?.description || raw?.data?.error?.description || raw?.message;
      finalMsg = rpMsg || (typeof raw === 'string' ? raw : JSON.stringify(raw)) || 'Unknown error';
    }
    
    console.error('processRefund final error message:', finalMsg);
    
    // Update refund request with error (only if not already updated)
    try {
      if (data?.refundRequestId) {
        const reqSnap = await admin.firestore().collection('refund_requests').doc(data.refundRequestId).get();
        if (reqSnap.exists) {
          const currentStatus = reqSnap.data()?.status;
          if (currentStatus === 'pending' || currentStatus === 'failed') {
            await reqSnap.ref.update({
              status: 'failed',
              adminNotes: `Razorpay refund failed: ${finalMsg}`,
              processedAt: admin.firestore.FieldValue.serverTimestamp()
            });
          }
        }
      }
    } catch (updateError) {
      console.error('Error updating refund request status:', updateError);
    }
    
    if (err instanceof functions.https.HttpsError) throw err;
    throw new functions.https.HttpsError('failed-precondition', `Razorpay refund failed: ${finalMsg}`);
  }
});

// =========================
// OVERDUE CLAWBACK DETECTION
// =========================

exports.checkOverdueClawbacks = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  const db = admin.firestore();
  const razorpay = getRazorpayClient();
  const cutoffDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  
  const pendingDeductions = await db.collection('turfownerdeductions')
    .where('status', '==', 'pending')
    .get();
  
  for (const doc of pendingDeductions.docs) {
    const data = doc.data();
    const createdAt = data.createdAt?.toDate?.() || new Date(data.createdAt);
    
    if (createdAt < cutoffDate) {
      await doc.ref.update({
        status: 'overdue',
        overdueMarkedAt: admin.firestore.FieldValue.serverTimestamp(),
        appliedAt: admin.firestore.FieldValue.serverTimestamp(), // FIX #1: Set appliedAt when marking overdue
        appliedReason: 'Auto-marked overdue after 7 days. Manual payment required.',
        markedOverdueStatus: true
      });
      
      let ownerEmail = '';
      let ownerPhone = '';
      let ownerName = 'Turf Owner';
      
      try {
        const ownerDoc = await db.collection('users').doc(data.ownerId).get();
        if (ownerDoc.exists) {
          const ownerData = ownerDoc.data();
          ownerEmail = ownerData.email || '';
          ownerPhone = ownerData.phoneNumber || '';
          ownerName = ownerData.name || 'Turf Owner';
        }
      } catch (error) {
        console.error('Error fetching owner details:', error);
      }
      
      // Determine if this is an event or turf booking clawback
      const isEventClawback = data.eventId || data.registrationId || (data.notes && data.notes.type === 'event');
      const bookingType = isEventClawback ? 'Event Registration' : 'Booking';
      const bookingId = isEventClawback ? (data.registrationId || data.eventId) : data.bookingId;
      const referenceId = isEventClawback ? data.registrationId : data.bookingId;
      
      let paymentLink = null;
      try {
        paymentLink = await razorpay.paymentLink.create({
          amount: Math.round(data.amount * 100),
          currency: 'INR',
          description: `Refund Clawback Payment - ${bookingType} ${referenceId || bookingId || 'N/A'}`,
          customer: {
            name: ownerName,
            email: ownerEmail,
            contact: ownerPhone
          },
          notify: {
            sms: Boolean(ownerPhone),
            email: Boolean(ownerEmail)
          },
          reminder_enable: true,
          notes: {
            purpose: 'clawback_payment',
            deduction_id: doc.id,
            owner_id: data.ownerId,
            booking_id: data.bookingId || null,
            registration_id: data.registrationId || null,
            turf_id: data.turfId || null,
            event_id: data.eventId || null,
            type: isEventClawback ? 'event' : 'turf'
          }
          // callback_url removed - not needed for clawback payment links
        });
      } catch (error) {
        console.error('Error creating payment link:', error);
      }
      
      const manualPaymentData = {
        deductionId: doc.id,
        ownerId: data.ownerId,
        amount: data.amount,
        reason: data.reason,
        status: 'pending_payment',
        paymentLink: paymentLink?.short_url || '',
        paymentLinkId: paymentLink?.id || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        dueDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        notes: 'Automated: Pending clawback exceeded 7 days. Manual payment required.',
        remindersSent: 0,
        lastReminderAt: null,
        type: isEventClawback ? 'event' : 'turf'
      };
      
      // Add appropriate fields based on type
      if (isEventClawback) {
        manualPaymentData.eventId = data.eventId || null;
        manualPaymentData.registrationId = data.registrationId || null;
      } else {
        manualPaymentData.turfId = data.turfId || null;
        manualPaymentData.bookingId = data.bookingId || null;
      }
      
      await db.collection('manual_clawback_payments').doc(doc.id).set(manualPaymentData);
      
      await sendNotificationToTurfOwner(
        data.ownerId,
        '⚠️ Urgent: Payment Required',
        `You must pay ₹${data.amount} for a refunded ${isEventClawback ? 'event registration' : 'booking'}. ${paymentLink ? `Pay here: ${paymentLink.short_url}` : 'Contact admin for payment details.'}`,
        {
          type: 'clawback_overdue',
          deductionId: doc.id,
          amount: data.amount.toString(),
          paymentLink: paymentLink?.short_url || '',
          dueDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
          clawbackType: isEventClawback ? 'event' : 'turf'
        }
      );
      
      await sendNotificationToAdmin(
        'Overdue Clawback Created',
        `Owner ${data.ownerId} has overdue clawback of ₹${data.amount} for ${isEventClawback ? 'event registration' : 'booking'}. Payment link ${paymentLink ? 'sent' : 'creation failed'}.`,
        {
          type: 'clawback_overdue_admin',
          deductionId: doc.id,
          ownerId: data.ownerId,
          amount: data.amount.toString(),
          paymentLink: paymentLink?.short_url || '',
          clawbackType: isEventClawback ? 'event' : 'turf'
        }
      );
    }
  }
});

// =========================
// CLAWBACK RECOVERY & VALIDATION
// =========================

// FIX #3: Recovery function for failed transfer bookings
exports.recoverFailedClawbacks = functions.https.onCall(async (data, context) => {
  const db = admin.firestore();
  const { ownerId, bookingId } = data;
  
  if (!ownerId || !bookingId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing ownerId or bookingId');
  }
  
  try {
    console.log(`Recovering clawbacks for owner ${ownerId}, booking ${bookingId}`);
    
    // Find all pending/overdue deductions for this owner
    const pendingDocs = await db.collection('turfownerdeductions')
      .where('ownerId', '==', ownerId)
      .where('status', '==', 'pending')
      .get();
    
    const overdueDocs = await db.collection('turfownerdeductions')
      .where('ownerId', '==', ownerId)
      .where('status', '==', 'overdue')
      .get();
    
    const allDocs = [...pendingDocs.docs, ...overdueDocs.docs];
    
    if (allDocs.length === 0) {
      return { 
        success: true, 
        count: 0, 
        message: 'No pending clawbacks found for recovery' 
      };
    }
    
    // Mark all as applied
    const batch = db.batch();
    allDocs.forEach(doc => {
      batch.update(doc.ref, {
        status: 'applied',
        appliedAt: admin.firestore.FieldValue.serverTimestamp(),
        appliedToBooking: bookingId,
        recoveredViaAdminFunction: true,
        recoveredAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    
    await batch.commit();
    
    console.log(`✅ Successfully recovered ${allDocs.length} clawbacks`);
    return { 
      success: true, 
      count: allDocs.length,
      message: `Marked ${allDocs.length} deductions as applied` 
    };
    
  } catch (error) {
    console.error('❌ Error in recoverFailedClawbacks:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// FIX #4: Validation function to check for inconsistencies
exports.validateClawbackConsistency = functions.https.onCall(async (data, context) => {
  const db = admin.firestore();
  
  try {
    // Check 1: Overdue with null appliedAt (INCONSISTENT)
    const overdueDeductions = await db.collection('turfownerdeductions')
      .where('status', '==', 'overdue')
      .get();
    
    const inconsistent = overdueDeductions.docs.filter(doc => 
      !doc.data().appliedAt
    );
    
    if (inconsistent.length > 0) {
      console.warn(`Found ${inconsistent.length} overdue deductions with null appliedAt`);
      return {
        status: 'warning',
        inconsistentCount: inconsistent.length,
        details: inconsistent.map(doc => ({
          id: doc.id,
          ownerId: doc.data().ownerId,
          amount: doc.data().amount,
          createdAt: doc.data().createdAt,
          overdueMarkedAt: doc.data().overdueMarkedAt,
          appliedAt: doc.data().appliedAt
        }))
      };
    }
    
    // Check 2: Stuck pending (older than 8 days)
    const pendingDeductions = await db.collection('turfownerdeductions')
      .where('status', '==', 'pending')
      .get();
    
    const stuck = pendingDeductions.docs.filter(doc => {
      const createdAt = doc.data().createdAt?.toDate?.() || new Date(doc.data().createdAt);
      const age = Date.now() - createdAt.getTime();
      return age > 8 * 24 * 60 * 60 * 1000; // 8 days
    });
    
    if (stuck.length > 0) {
      console.warn(`Found ${stuck.length} stuck pending deductions`);
      return {
        status: 'warning',
        stuckCount: stuck.length,
        details: stuck.map(doc => {
          const createdAt = doc.data().createdAt?.toDate?.() || new Date(doc.data().createdAt);
          const age = Math.floor((Date.now() - createdAt.getTime()) / (24*60*60*1000));
          return {
            id: doc.id,
            ownerId: doc.data().ownerId,
            amount: doc.data().amount,
            createdAt: doc.data().createdAt,
            ageInDays: age
          };
        })
      };
    }
    
    return {
      status: 'healthy',
      message: 'All clawback statuses are consistent',
      inconsistentCount: 0,
      stuckCount: 0
    };
    
  } catch (error) {
    console.error('❌ Error in validateClawbackConsistency:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// =========================
// RAZORPAY WEBHOOK HANDLER
// =========================

exports.handleRazorpayWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
    const signature = req.headers['x-razorpay-signature'];
    
    if (!secret) {
      console.error('Webhook secret not configured');
      return res.status(500).json({ error: 'Webhook secret not configured' });
    }
    
    if (!signature) {
      console.error('Missing webhook signature');
      return res.status(400).json({ error: 'Missing signature' });
    }
    
    // Use crypto.timingSafeEqual for constant-time comparison
    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(JSON.stringify(req.body))
      .digest('hex');
    
    const sigBuffer = Buffer.from(signature);
    const expectedBuffer = Buffer.from(expectedSignature);
    
    if (sigBuffer.length !== expectedBuffer.length) {
      console.error('Invalid webhook signature length');
      return res.status(400).json({ error: 'Invalid signature' });
    }
    
    if (!crypto.timingSafeEqual(sigBuffer, expectedBuffer)) {
      console.error('Invalid webhook signature');
      return res.status(400).json({ error: 'Invalid signature' });
    }
    
    const event = req.body.event;
    const payload = req.body.payload;
    
    if (event === 'payment_link.paid') {
      const paymentLinkId = payload.payment_link.entity.id;
      const notes = payload.payment_link.entity.notes || {};
      
      console.log('🔔 Payment link paid event received:', {
        paymentLinkId,
        notes,
        event
      });
      
      if (notes.purpose === 'clawback_payment') {
        const db = admin.firestore();
        const deductionId = notes.deduction_id;
        
        if (!deductionId) {
          console.error('❌ Missing deduction_id in payment link notes');
          return res.status(400).json({ error: 'Missing deduction_id' });
        }
        
        console.log('💰 Processing clawback payment for deductionId:', deductionId);
        
        // Update manual_clawback_payments document
        // Use transaction to ensure atomic update and prevent duplicate processing
        const manualPaymentRef = db.collection('manual_clawback_payments').doc(deductionId);
        
        await db.runTransaction(async (transaction) => {
          const manualPaymentDoc = await transaction.get(manualPaymentRef);
          
          if (!manualPaymentDoc.exists) {
            console.error('❌ manual_clawback_payments document not found:', deductionId);
            // Try to find by paymentLinkId instead
            const querySnapshot = await db.collection('manual_clawback_payments')
              .where('paymentLinkId', '==', paymentLinkId)
              .limit(1)
              .get();
            
            if (querySnapshot.empty) {
              throw new Error(`Payment record not found for deductionId: ${deductionId} or paymentLinkId: ${paymentLinkId}`);
            }
            
            const foundDoc = querySnapshot.docs[0];
            const foundData = foundDoc.data();
            
            // Check if already processed (idempotency check)
            if (foundData.status === 'paid') {
              console.log('⚠️ Payment already processed for document:', foundDoc.id);
              return; // Already processed, skip update
            }
            
            transaction.update(foundDoc.ref, {
              status: 'paid',
              paidAt: admin.firestore.FieldValue.serverTimestamp(),
              paymentId: payload.payment.entity.id,
              paymentMethod: payload.payment.entity.method,
              processedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log('✅ Updated manual_clawback_payments by paymentLinkId:', foundDoc.id);
          } else {
            const existingData = manualPaymentDoc.data();
            
            // Check if already processed (idempotency check)
            if (existingData.status === 'paid') {
              console.log('⚠️ Payment already processed for document:', deductionId);
              return; // Already processed, skip update
            }
            
            transaction.update(manualPaymentRef, {
              status: 'paid',
              paidAt: admin.firestore.FieldValue.serverTimestamp(),
              paymentId: payload.payment.entity.id,
              paymentMethod: payload.payment.entity.method,
              processedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log('✅ Updated manual_clawback_payments document:', deductionId);
          }
        });
        
        // Update turfownerdeductions document
        const deductionRef = db.collection('turfownerdeductions').doc(deductionId);
        const deductionDoc = await deductionRef.get();
        
        if (deductionDoc.exists) {
          const existingDeduction = deductionDoc.data();
          
          // Check if already settled (idempotency check)
          if (existingDeduction.status === 'settled_manual' || existingDeduction.status === 'applied') {
            console.log('⚠️ Deduction already settled:', deductionId);
          } else {
            await deductionRef.update({
              status: 'settled_manual',
              settledAt: admin.firestore.FieldValue.serverTimestamp(),
              settlementMethod: 'manual_payment_link',
              paymentLinkId: paymentLinkId
            });
            console.log('✅ Updated turfownerdeductions document:', deductionId);
          }
        } else {
          console.warn('⚠️ turfownerdeductions document not found:', deductionId);
        }
        
        // Send notifications
        if (notes.owner_id) {
          try {
            await sendNotificationToTurfOwner(
              notes.owner_id,
              '✅ Payment Received',
              `Your payment of ₹${payload.payment.entity.amount / 100} has been received. Thank you!`,
              { type: 'clawback_paid' }
            );
            console.log('✅ Sent notification to owner:', notes.owner_id);
          } catch (notifError) {
            console.error('❌ Error sending owner notification:', notifError);
          }
          
          try {
            await sendNotificationToAdmin(
              'Clawback Paid',
              `Owner ${notes.owner_id} paid clawback of ₹${payload.payment.entity.amount / 100}`,
              { type: 'clawback_paid_admin', deductionId }
            );
            console.log('✅ Sent notification to admin');
          } catch (notifError) {
            console.error('❌ Error sending admin notification:', notifError);
          }
        }
      } else {
        console.log('ℹ️ Payment link paid but not a clawback payment (purpose:', notes.purpose, ')');
      }
    }
    
    res.status(200).json({ received: true });
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).json({ error: error.message });
  }
});

// =========================
// SEND CLAWBACK REMINDER
// =========================

exports.sendClawbackReminder = functions.https.onCall(async (data, context) => {
  try {
    const { deductionId } = data;
    
    if (!deductionId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing deductionId');
    }
    
    const db = admin.firestore();
    const paymentDoc = await db.collection('manual_clawback_payments').doc(deductionId).get();
    
    if (!paymentDoc.exists) {
      throw new functions.https.HttpsError('not-found', `Payment record not found for deductionId: ${deductionId}`);
    }
    
    const paymentData = paymentDoc.data();
    
    if (!paymentData.ownerId) {
      throw new functions.https.HttpsError('failed-precondition', 'Owner ID not found in payment record');
    }
    
    // Try to send notification, but don't fail if it doesn't work
    let notificationSent = false;
    try {
      await sendNotificationToTurfOwner(
        paymentData.ownerId,
        '🔔 Payment Reminder',
        `Reminder: You have a pending payment of ₹${paymentData.amount}. ${paymentData.paymentLink ? `Pay now: ${paymentData.paymentLink}` : 'Please contact admin.'}`,
        {
          type: 'clawback_reminder',
          deductionId,
          amount: paymentData.amount.toString(),
          paymentLink: paymentData.paymentLink || ''
        }
      );
      notificationSent = true;
    } catch (notifError) {
      console.error('Error sending notification (continuing anyway):', notifError);
      // Continue even if notification fails - still update reminder count
    }
    
    // Update reminder count regardless of notification success
    await paymentDoc.ref.update({
      remindersSent: admin.firestore.FieldValue.increment(1),
      lastReminderAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return { 
      success: true, 
      message: notificationSent 
        ? 'Reminder sent successfully' 
        : 'Reminder recorded (notification may not have been delivered)',
      notificationSent
    };
  } catch (error) {
    console.error('Error sending reminder:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', `Failed to send reminder: ${error.message}`);
  }
});

// =========================
// OTHER FUNCTIONS
// =========================

exports.checkTurfSlotAvailability = functions.https.onCall(async (data, context) => {
  try {
    const { turfId, selectedGround, bookingDate, slots } = data;
    
    if (!turfId || !selectedGround || !bookingDate || !Array.isArray(slots) || slots.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    const db = admin.firestore();
    const snap = await db
      .collection('turfs')
      .doc(turfId)
      .collection('bookings')
      .where('selectedGround', '==', selectedGround)
      .where('bookingDate', '==', bookingDate)
      .get();
    
    let booked = new Set();
    snap.forEach(doc => {
      const arr = doc.data().bookingSlots || [];
      for (const s of arr) {
        booked.add(s);
      }
    });
    
    const conflicting = slots.filter(s => booked.has(s));
    const available = conflicting.length === 0;
    
    return { available, conflicting };
  } catch (error) {
    console.error('checkTurfSlotAvailability error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Failed to check availability: ${error.message}`);
  }
});

// =========================
// QUEUE-BASED SLOT BOOKING SYSTEM
// =========================

// Freeze slot and add user to queue
exports.freezeSlotAndQueue = functions.https.onCall(async (data, context) => {
  try {
    const { turfId, selectedGround, bookingDate, slots, userId, userName } = data;
    
    if (!turfId || !selectedGround || !bookingDate || !Array.isArray(slots) || slots.length === 0 || !userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    const db = admin.firestore();
    const slotKey = `${turfId}_${selectedGround}_${bookingDate}_${slots.sort().join('_')}`;
    const reservationId = `${slotKey}_${userId}_${Date.now()}`;
    const queueId = `queue_${slotKey}`;
    
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 1000)); // 2 minutes
    
    return await db.runTransaction(async (tx) => {
      // Check existing bookings
      const bookingsQuery = await tx.get(
        db.collection('turfs').doc(turfId).collection('bookings')
          .where('selectedGround', '==', selectedGround)
          .where('bookingDate', '==', bookingDate)
      );
      
      let booked = new Set();
      bookingsQuery.forEach(doc => {
        const arr = doc.data().bookingSlots || [];
        for (const s of arr) {
          booked.add(s);
        }
      });
      
      const conflicting = slots.filter(s => booked.has(s));
      if (conflicting.length > 0) {
        throw new functions.https.HttpsError('failed-precondition', `Slots already booked: ${conflicting.join(', ')}`);
      }
      
      // Check active reservations (query by slotKey only, filter expiresAt in code to avoid composite index)
      const activeReservationsQuery = await tx.get(
        db.collection('slot_reservations')
          .where('slotKey', '==', slotKey)
      );
      
      const now = admin.firestore.Timestamp.now();
      const conflictingReservations = [];
      activeReservationsQuery.forEach(doc => {
        const resData = doc.data();
        const resExpiresAt = resData.expiresAt;
        // Filter by expiresAt in code (avoids composite index requirement)
        if (resExpiresAt && resExpiresAt > now) {
          const resSlots = resData.slots || [];
          if (slots.some(s => resSlots.includes(s))) {
            conflictingReservations.push(doc.id);
          }
        }
      });
      
      if (conflictingReservations.length > 0) {
        // Get queue
        const queueDoc = await tx.get(db.collection('slot_queues').doc(queueId));
        let queueData = queueDoc.exists ? queueDoc.data() : { users: [] };
        let users = queueData.users || [];
        
        // Check if user already in queue
        const existingIndex = users.findIndex(u => u.userId === userId);
        if (existingIndex >= 0) {
          return {
            reservationId: users[existingIndex].reservationId,
            queuePosition: existingIndex + 1,
            status: existingIndex === 0 ? 'ready' : 'queued',
            message: existingIndex === 0 ? 'Ready to pay' : `Position ${existingIndex + 1} in queue`
          };
        }
        
        // Add to queue
        const queuePosition = users.length + 1;
        users.push({
          userId,
          userName: userName || 'User',
          reservationId,
          joinedAt: admin.firestore.Timestamp.now() // Use Timestamp.now() instead of serverTimestamp() for arrays
        });
        
        // Create reservation
        tx.set(db.collection('slot_reservations').doc(reservationId), {
          slotKey,
          turfId,
          selectedGround,
          bookingDate,
          slots,
          userId,
          userName: userName || 'User',
          queuePosition,
          status: 'queued',
          expiresAt,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // Update queue
        tx.set(db.collection('slot_queues').doc(queueId), {
          slotKey,
          turfId,
          selectedGround,
          bookingDate,
          slots,
          users,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        
        return {
          reservationId,
          queuePosition,
          status: 'queued',
          message: `Position ${queuePosition} in queue`
        };
      }
      
      // No conflicts - user is first
      // Create reservation
      tx.set(db.collection('slot_reservations').doc(reservationId), {
        slotKey,
        turfId,
        selectedGround,
        bookingDate,
        slots,
        userId,
        userName: userName || 'User',
        queuePosition: 1,
        status: 'ready',
        expiresAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Create queue with this user as first
      tx.set(db.collection('slot_queues').doc(queueId), {
        slotKey,
        turfId,
        selectedGround,
        bookingDate,
        slots,
        users: [{
          userId,
          userName: userName || 'User',
          reservationId,
          joinedAt: admin.firestore.Timestamp.now() // Use Timestamp.now() instead of serverTimestamp() for arrays
        }],
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      return {
        reservationId,
        queuePosition: 1,
        status: 'ready',
        message: 'Ready to pay'
      };
    });
  } catch (error) {
    console.error('freezeSlotAndQueue error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Create Razorpay order only if user is first in queue
exports.createRazorpayOrderForQueuedSlot = functions.https.onCall(async (data, context) => {
  try {
    const { reservationId, totalAmount, payableAmount, ownerAccountId, bookingId, turfId, userId, bookingData } = data;
    
    if (!reservationId || !totalAmount || !payableAmount || !ownerAccountId || !bookingId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    const db = admin.firestore();
    const reservationDoc = await db.collection('slot_reservations').doc(reservationId).get();
    
    if (!reservationDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Reservation not found');
    }
    
    const reservation = reservationDoc.data();
    
    // Verify user owns this reservation
    if (reservation.userId !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'You do not own this reservation');
    }
    
    // Verify queue position is 1
    if (reservation.queuePosition !== 1 || reservation.status !== 'ready') {
      throw new functions.https.HttpsError('failed-precondition', `Not your turn. Position: ${reservation.queuePosition}`);
    }
    
    // Check if reservation expired
    const expiresAt = reservation.expiresAt?.toDate();
    if (expiresAt && expiresAt < new Date()) {
      throw new functions.https.HttpsError('deadline-exceeded', 'Reservation expired. Please try again.');
    }
    
    // Verify slots still available
    const bookingsQuery = await db
      .collection('turfs').doc(turfId).collection('bookings')
      .where('selectedGround', '==', reservation.selectedGround)
      .where('bookingDate', '==', reservation.bookingDate)
      .get();
    
    let booked = new Set();
    bookingsQuery.forEach(doc => {
      const arr = doc.data().bookingSlots || [];
      for (const s of arr) {
        booked.add(s);
      }
    });
    
    const conflicting = reservation.slots.filter(s => booked.has(s));
    if (conflicting.length > 0) {
      throw new functions.https.HttpsError('failed-precondition', `Slots no longer available: ${conflicting.join(', ')}`);
    }
    
    // Create Razorpay order
    const client = getRazorpayClient();
    const ownerShare = calculateOwnerShare(totalAmount);
    const platformProfit = payableAmount - totalAmount;
    
    const order = await client.orders.create({
      amount: Math.round(payableAmount * 100),
      currency: 'INR',
      transfers: [{
        account: ownerAccountId,
        amount: Math.round(ownerShare * 100),
        currency: 'INR'
      }],
      notes: {
        booking_id: bookingId,
        reservation_id: reservationId,
        owner_share: ownerShare.toString(),
        platform_profit: platformProfit.toString(),
        base_turf_amount: totalAmount.toString()
      }
    });
    
    // Update reservation with order ID
    await reservationDoc.ref.update({
      razorpayOrderId: order.id,
      status: 'payment_pending',
      orderCreatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Store in razorpay_orders
    await db.collection('razorpay_orders').doc(order.id).set({
      booking_id: bookingId,
      reservation_id: reservationId,
      turf_id: turfId || null,
      user_id: userId,
      total_paid: payableAmount,
      base_turf_amount: totalAmount,
      owner_share: ownerShare,
      platform_profit: platformProfit,
      razorpay_order_id: order.id,
      owner_account_id: ownerAccountId,
      booking_data: bookingData || null,
      booking_completed: false,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return {
      orderId: order.id,
      ownerShare,
      platformProfit,
      baseTurfAmount: totalAmount,
      amount: payableAmount
    };
  } catch (error) {
    console.error('createRazorpayOrderForQueuedSlot error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Internal function to confirm booking after payment (can be called from recovery)
async function confirmBookingAfterPaymentInternal(data) {
  const { orderId, paymentId, reservationId, userId, userName, turfId, turfName, ownerId, bookingDate, selectedGround, slots, totalHours, baseAmount, payableAmount } = data;
  
  if (!orderId || !paymentId || !reservationId) {
    throw new Error('Missing required parameters: orderId, paymentId, reservationId');
  }
  
  const db = admin.firestore();
  const reservationDoc = await db.collection('slot_reservations').doc(reservationId).get();
  
  if (!reservationDoc.exists) {
    throw new Error('Reservation not found');
  }
  
  const reservation = reservationDoc.data();
  
  // Verify user owns this reservation
  if (reservation.userId !== userId) {
    throw new Error('You do not own this reservation');
  }
  
  const slotKey = reservation.slotKey;
  const queueId = `queue_${slotKey}`;
  
  return await db.runTransaction(async (tx) => {
      // Verify payment
      const client = getRazorpayClient();
      const payment = await client.payments.fetch(paymentId);
      
      if (!payment || payment.status !== 'captured') {
        throw new functions.https.HttpsError('failed-precondition', 'Payment not captured');
      }
      
      if (payment.order_id !== orderId) {
        throw new functions.https.HttpsError('failed-precondition', 'Payment does not match order');
      }
      
      // Final slot availability check
      const bookingsQuery = await tx.get(
        db.collection('turfs').doc(turfId).collection('bookings')
          .where('selectedGround', '==', selectedGround)
          .where('bookingDate', '==', bookingDate)
      );
      
      let booked = new Set();
      bookingsQuery.forEach(doc => {
        const arr = doc.data().bookingSlots || [];
        for (const s of arr) {
          booked.add(s);
        }
      });
      
      const conflicting = slots.filter(s => booked.has(s));
      if (conflicting.length > 0) {
        throw new functions.https.HttpsError('aborted', `Slots already booked: ${conflicting.join(', ')}`);
      }
      
      // Create booking
      const now = admin.firestore.FieldValue.serverTimestamp();
      const bookingData = {
        userId,
        userName: userName || 'User',
        bookingDate,
        bookingSlots: slots,
        totalHours: Number(totalHours) || slots.length,
        amount: payableAmount,
        baseAmount: baseAmount,
        turfId,
        turfName,
        selectedGround,
        paymentMethod: 'Online',
        status: 'confirmed',
        payoutStatus: 'pending',
        razorpayPaymentId: paymentId,
        razorpayOrderId: orderId,
        ownerId: ownerId || null,
        createdAt: now,
        updatedAt: now
      };
      
      const turfBookingRef = db.collection('turfs').doc(turfId).collection('bookings').doc();
      tx.set(turfBookingRef, bookingData);
      
      // Remove reservation
      tx.delete(reservationDoc.ref);
      
      // Update queue - remove this user and promote next
      const queueDoc = await tx.get(db.collection('slot_queues').doc(queueId));
      if (queueDoc.exists) {
        const queueData = queueDoc.data();
        let users = queueData.users || [];
        
        // Remove current user
        users = users.filter(u => u.userId !== userId);
        
        // Promote next user to position 1
        if (users.length > 0) {
          const nextUser = users[0];
          const nextReservationId = nextUser.reservationId;
          
          // Update next user's reservation
          const nextReservationRef = db.collection('slot_reservations').doc(nextReservationId);
          const nextReservationDoc = await tx.get(nextReservationRef);
          if (nextReservationDoc.exists) {
            tx.update(nextReservationRef, {
              queuePosition: 1,
              status: 'ready',
              expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 1000))
            });
          }
          
          // Update queue positions
          users.forEach((user, index) => {
            if (index > 0) {
              const userReservationRef = db.collection('slot_reservations').doc(user.reservationId);
              tx.update(userReservationRef, {
                queuePosition: index + 1,
                status: 'queued'
              });
            }
          });
        }
        
        // Update queue
        if (users.length > 0) {
          tx.update(db.collection('slot_queues').doc(queueId), {
            users,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          });
        } else {
          tx.delete(db.collection('slot_queues').doc(queueId));
        }
      }
      
      // Update razorpay_orders
      const orderRef = db.collection('razorpay_orders').doc(orderId);
      tx.update(orderRef, {
        booking_completed: true,
        completed_at: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return {
        ok: true,
        status: 'confirmed',
        bookingId: turfBookingRef.id,
        message: 'Booking confirmed successfully'
      };
    });
}

// Public callable function for confirming booking after payment
exports.confirmBookingAfterPayment = functions.https.onCall(async (data, context) => {
  try {
    return await confirmBookingAfterPaymentInternal(data);
  } catch (error) {
    console.error('confirmBookingAfterPayment error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Check queue position
exports.checkQueuePosition = functions.https.onCall(async (data, context) => {
  try {
    const { reservationId, userId } = data;
    
    if (!reservationId || !userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    const db = admin.firestore();
    const reservationDoc = await db.collection('slot_reservations').doc(reservationId).get();
    
    if (!reservationDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Reservation not found');
    }
    
    const reservation = reservationDoc.data();
    
    if (reservation.userId !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'You do not own this reservation');
    }
    
    // Check if expired
    const expiresAt = reservation.expiresAt?.toDate();
    if (expiresAt && expiresAt < new Date()) {
      return {
        expired: true,
        message: 'Reservation expired'
      };
    }
    
    return {
      reservationId,
      queuePosition: reservation.queuePosition || 1,
      status: reservation.status || 'queued',
      expiresAt: reservation.expiresAt,
      message: reservation.queuePosition === 1 ? 'Ready to pay' : `Position ${reservation.queuePosition} in queue`
    };
  } catch (error) {
    console.error('checkQueuePosition error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Cleanup expired reservations (runs every 1 minute)
exports.cleanupExpiredReservations = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  
  // Get expired reservations (single field query - no composite index needed)
  const expiredReservations = await db.collection('slot_reservations')
    .where('expiresAt', '<=', now)
    .limit(500) // Process in batches to avoid timeout
    .get();
  
  console.log(`[Cleanup] Found ${expiredReservations.size} expired reservations`);
  
  const client = getRazorpayClient();
  
  for (const doc of expiredReservations.docs) {
    const reservation = doc.data();
    
    try {
      // If payment was made but booking not confirmed, process refund
      if (reservation.razorpayOrderId) {
        const orderDoc = await db.collection('razorpay_orders').doc(reservation.razorpayOrderId).get();
        if (orderDoc.exists) {
          const orderData = orderDoc.data();
          if (!orderData.booking_completed) {
            // Check if payment was captured
            try {
              const order = await client.orders.fetch(reservation.razorpayOrderId);
              const payments = await client.orders.fetchPayments(reservation.razorpayOrderId);
              const capturedPayment = payments?.items?.find(p => p.status === 'captured');
              
              if (capturedPayment) {
                // Refund the payment
                await client.payments.refund(capturedPayment.id, {
                  amount: Math.round((orderData.total_paid || 0) * 100),
                  notes: {
                    reason: 'Reservation expired - automatic refund',
                    reservation_id: doc.id
                  }
                });
                console.log(`[Cleanup] Refunded payment for expired reservation ${doc.id}`);
              }
            } catch (refundError) {
              console.error(`[Cleanup] Error refunding for ${doc.id}:`, refundError);
            }
          }
        }
      }
      
      // Remove from queue
      const slotKey = reservation.slotKey;
      const queueId = `queue_${slotKey}`;
      const queueDoc = await db.collection('slot_queues').doc(queueId).get();
      
      if (queueDoc.exists) {
        const queueData = queueDoc.data();
        let users = queueData.users || [];
        users = users.filter(u => u.reservationId !== doc.id);
        
        // Promote next user if this was position 1
        if (reservation.queuePosition === 1 && users.length > 0) {
          const nextUser = users[0];
          const nextReservationRef = db.collection('slot_reservations').doc(nextUser.reservationId);
          const nextReservationDoc = await nextReservationRef.get();
          
          if (nextReservationDoc.exists) {
            await nextReservationRef.update({
              queuePosition: 1,
              status: 'ready',
              expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 1000))
            });
            
            // Update other positions
            for (let i = 1; i < users.length; i++) {
              const userReservationRef = db.collection('slot_reservations').doc(users[i].reservationId);
              await userReservationRef.update({
                queuePosition: i + 1,
                status: 'queued'
              });
            }
          }
        }
        
        // Update or delete queue
        if (users.length > 0) {
          await queueDoc.ref.update({
            users,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          });
        } else {
          await queueDoc.ref.delete();
        }
      }
      
      // Delete reservation
      await doc.ref.delete();
      console.log(`[Cleanup] Removed expired reservation ${doc.id}`);
      
    } catch (error) {
      console.error(`[Cleanup] Error processing reservation ${doc.id}:`, error);
    }
  }
  
  return null;
});

// =========================
// EVENT REGISTRATION QUEUE SYSTEM
// =========================

// Freeze event slot and add user to queue
exports.freezeEventSlotAndQueue = functions.https.onCall(async (data, context) => {
  try {
    const { eventId, userId, userName } = data;
    
    if (!eventId || !userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    const db = admin.firestore();
    const reservationId = `event_${eventId}_${userId}_${Date.now()}`;
    const queueId = `event_queue_${eventId}`;
    
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 1000)); // 2 minutes
    
    return await db.runTransaction(async (tx) => {
      // Check event exists and is open
      const eventDoc = await tx.get(db.collection('spot_events').doc(eventId));
      if (!eventDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Event not found');
      }
      
      const eventData = eventDoc.data();
      if (eventData.status !== 'approved' || !eventData.isBookingOpen) {
        throw new functions.https.HttpsError('failed-precondition', 'Event registration is not open');
      }
      
      // Check if user already registered
      const existingReg = await tx.get(
        db.collection('event_registrations')
          .where('userId', '==', userId)
          .where('eventId', '==', eventId)
          .where('status', '!=', 'cancelled')
          .limit(1)
      );
      
      if (!existingReg.empty) {
        throw new functions.https.HttpsError('already-exists', 'You are already registered for this event');
      }
      
      // Check max participants
      const maxParticipants = eventData.maxParticipants || 0;
      if (maxParticipants > 0) {
        const registrationsQuery = await tx.get(
          db.collection('event_registrations')
            .where('eventId', '==', eventId)
            .where('status', '!=', 'cancelled')
        );
        
        if (registrationsQuery.size >= maxParticipants) {
          throw new functions.https.HttpsError('failed-precondition', 'Event is full');
        }
      }
      
      // Check active reservations (query by eventId only, filter expiresAt in code to avoid composite index)
      const activeReservationsQuery = await tx.get(
        db.collection('event_reservations')
          .where('eventId', '==', eventId)
      );
      
      const now = admin.firestore.Timestamp.now();
      const activeReservations = activeReservationsQuery.docs.filter(doc => {
        const resData = doc.data();
        const resExpiresAt = resData.expiresAt;
        return resExpiresAt && resExpiresAt > now;
      });
      
      if (activeReservations.length > 0) {
        // Get queue
        const queueDoc = await tx.get(db.collection('event_queues').doc(queueId));
        let queueData = queueDoc.exists ? queueDoc.data() : { users: [] };
        let users = queueData.users || [];
        
        // Check if user already in queue
        const existingIndex = users.findIndex(u => u.userId === userId);
        if (existingIndex >= 0) {
          return {
            reservationId: users[existingIndex].reservationId,
            queuePosition: existingIndex + 1,
            status: existingIndex === 0 ? 'ready' : 'queued',
            message: existingIndex === 0 ? 'Ready to pay' : `Position ${existingIndex + 1} in queue`
          };
        }
        
        // Add to queue
        const queuePosition = users.length + 1;
        users.push({
          userId,
          userName: userName || 'User',
          reservationId,
          joinedAt: admin.firestore.Timestamp.now() // Use Timestamp.now() instead of serverTimestamp() for arrays
        });
        
        // Create reservation
        tx.set(db.collection('event_reservations').doc(reservationId), {
          eventId,
          userId,
          userName: userName || 'User',
          queuePosition,
          status: 'queued',
          expiresAt,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // Update queue
        tx.set(db.collection('event_queues').doc(queueId), {
          eventId,
          users,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        
        return {
          reservationId,
          queuePosition,
          status: 'queued',
          message: `Position ${queuePosition} in queue`
        };
      }
      
      // No conflicts - user is first
      // Create reservation
      tx.set(db.collection('event_reservations').doc(reservationId), {
        eventId,
        userId,
        userName: userName || 'User',
        queuePosition: 1,
        status: 'ready',
        expiresAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Create queue with this user as first
      tx.set(db.collection('event_queues').doc(queueId), {
        eventId,
        users: [{
          userId,
          userName: userName || 'User',
          reservationId,
          joinedAt: admin.firestore.Timestamp.now() // Use Timestamp.now() instead of serverTimestamp() for arrays
        }],
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      return {
        reservationId,
        queuePosition: 1,
        status: 'ready',
        message: 'Ready to pay'
      };
    });
  } catch (error) {
    console.error('freezeEventSlotAndQueue error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Create Razorpay order for queued event registration
exports.createRazorpayOrderForQueuedEvent = functions.https.onCall(async (data, context) => {
  try {
    const { reservationId, totalAmount, payableAmount, ownerAccountId, registrationId, eventId, userId, registrationData } = data;
    
    if (!reservationId || !totalAmount || !payableAmount || !ownerAccountId || !registrationId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    const db = admin.firestore();
    const reservationDoc = await db.collection('event_reservations').doc(reservationId).get();
    
    if (!reservationDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Reservation not found');
    }
    
    const reservation = reservationDoc.data();
    
    // Verify user owns this reservation
    if (reservation.userId !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'You do not own this reservation');
    }
    
    // Verify queue position is 1
    if (reservation.queuePosition !== 1 || reservation.status !== 'ready') {
      throw new functions.https.HttpsError('failed-precondition', `Not your turn. Position: ${reservation.queuePosition}`);
    }
    
    // Check if reservation expired
    const expiresAt = reservation.expiresAt?.toDate();
    if (expiresAt && expiresAt < new Date()) {
      throw new functions.https.HttpsError('deadline-exceeded', 'Reservation expired. Please try again.');
    }
    
    // Create Razorpay order
    const client = getRazorpayClient();
    const ownerShare = calculateOwnerShare(totalAmount);
    const platformProfit = payableAmount - totalAmount;
    
    const order = await client.orders.create({
      amount: Math.round(payableAmount * 100),
      currency: 'INR',
      transfers: [{
        account: ownerAccountId,
        amount: Math.round(ownerShare * 100),
        currency: 'INR'
      }],
      notes: {
        registration_id: registrationId,
        reservation_id: reservationId,
        event_id: eventId,
        owner_share: ownerShare.toString(),
        platform_profit: platformProfit.toString(),
        base_event_amount: totalAmount.toString()
      }
    });
    
    // Update reservation with order ID
    await reservationDoc.ref.update({
      razorpayOrderId: order.id,
      status: 'payment_pending',
      orderCreatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Store in razorpay_orders
    await db.collection('razorpay_orders').doc(order.id).set({
      registration_id: registrationId,
      reservation_id: reservationId,
      event_id: eventId || null,
      user_id: userId,
      total_paid: payableAmount,
      base_event_amount: totalAmount,
      owner_share: ownerShare,
      platform_profit: platformProfit,
      razorpay_order_id: order.id,
      owner_account_id: ownerAccountId,
      registration_data: registrationData || null,
      registration_completed: false,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return {
      orderId: order.id,
      ownerShare,
      platformProfit,
      baseEventAmount: totalAmount,
      amount: payableAmount
    };
  } catch (error) {
    console.error('createRazorpayOrderForQueuedEvent error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Internal function to confirm event registration after payment (can be called from recovery)
async function confirmEventRegistrationAfterPaymentInternal(data) {
  const { orderId, paymentId, reservationId, userId, eventId, eventName, ownerId, eventDate, eventTime, eventLocation, eventType, baseAmount, payableAmount, userName, userEmail, userPhone, userImageUrl } = data;
  
  if (!orderId || !paymentId || !reservationId) {
    throw new Error('Missing required parameters: orderId, paymentId, reservationId');
  }
  
  const db = admin.firestore();
  const reservationDoc = await db.collection('event_reservations').doc(reservationId).get();
  
  if (!reservationDoc.exists) {
    throw new Error('Reservation not found');
  }
  
  const reservation = reservationDoc.data();
  
  // Verify user owns this reservation
  if (reservation.userId !== userId) {
    throw new Error('You do not own this reservation');
  }
  
  const queueId = `queue_${eventId}`;
  
  return await db.runTransaction(async (tx) => {
      // Verify payment
      const client = getRazorpayClient();
      const payment = await client.payments.fetch(paymentId);
      
      if (!payment || payment.status !== 'captured') {
        throw new functions.https.HttpsError('failed-precondition', 'Payment not captured');
      }
      
      if (payment.order_id !== orderId) {
        throw new functions.https.HttpsError('failed-precondition', 'Payment does not match order');
      }
      
      // Final check - event still open and not full
      const eventDoc = await tx.get(db.collection('spot_events').doc(eventId));
      if (!eventDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Event not found');
      }
      
      const eventData = eventDoc.data();
      const maxParticipants = eventData.maxParticipants || 0;
      
      if (maxParticipants > 0) {
        const registrationsQuery = await tx.get(
          db.collection('event_registrations')
            .where('eventId', '==', eventId)
            .where('status', '!=', 'cancelled')
        );
        
        if (registrationsQuery.size >= maxParticipants) {
          throw new functions.https.HttpsError('failed-precondition', 'Event is full');
        }
      }
      
      // Check if user already registered
      const existingReg = await tx.get(
        db.collection('event_registrations')
          .where('userId', '==', userId)
          .where('eventId', '==', eventId)
          .where('status', '!=', 'cancelled')
          .limit(1)
      );
      
      if (!existingReg.empty) {
        throw new functions.https.HttpsError('already-exists', 'You are already registered for this event');
      }
      
      // Create registration
      const now = admin.firestore.FieldValue.serverTimestamp();
      const registrationData = {
        eventId,
        eventName,
        eventDate,
        eventTime: eventTime || null,
        eventLocation: eventLocation || null,
        eventType: eventType || null,
        userId,
        userName,
        userEmail,
        userPhone: userPhone || null,
        userImageUrl: userImageUrl || null,
        paymentMethod: 'Online',
        status: 'confirmed',
        payoutStatus: 'pending',
        price: payableAmount,
        baseAmount: baseAmount,
        razorpayPaymentId: paymentId,
        razorpayOrderId: orderId,
        ownerId: ownerId || null,
        createdAt: now,
        updatedAt: now
      };
      
      const registrationRef = db.collection('event_registrations').doc();
      tx.set(registrationRef, registrationData);
      
      // Remove reservation
      tx.delete(reservationDoc.ref);
      
      // Update queue - remove this user and promote next
      const queueDoc = await tx.get(db.collection('event_queues').doc(queueId));
      if (queueDoc.exists) {
        const queueData = queueDoc.data();
        let users = queueData.users || [];
        
        // Remove current user
        users = users.filter(u => u.userId !== userId);
        
        // Promote next user to position 1
        if (users.length > 0) {
          const nextUser = users[0];
          const nextReservationId = nextUser.reservationId;
          
          // Update next user's reservation
          const nextReservationRef = db.collection('event_reservations').doc(nextReservationId);
          const nextReservationDoc = await tx.get(nextReservationRef);
          if (nextReservationDoc.exists) {
            tx.update(nextReservationRef, {
              queuePosition: 1,
              status: 'ready',
              expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 1000))
            });
          }
          
          // Update queue positions
          users.forEach((user, index) => {
            if (index > 0) {
              const userReservationRef = db.collection('event_reservations').doc(user.reservationId);
              tx.update(userReservationRef, {
                queuePosition: index + 1,
                status: 'queued'
              });
            }
          });
        }
        
        // Update queue
        if (users.length > 0) {
          tx.update(db.collection('event_queues').doc(queueId), {
            users,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          });
        } else {
          tx.delete(db.collection('event_queues').doc(queueId));
        }
      }
      
      // Update razorpay_orders
      const orderRef = db.collection('razorpay_orders').doc(orderId);
      tx.update(orderRef, {
        registration_completed: true,
        completed_at: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return {
        ok: true,
        status: 'confirmed',
        registrationId: registrationRef.id,
        message: 'Registration confirmed successfully'
      };
    });
}

// Public callable function for confirming event registration after payment
exports.confirmEventRegistrationAfterPayment = functions.https.onCall(async (data, context) => {
  try {
    return await confirmEventRegistrationAfterPaymentInternal(data);
  } catch (error) {
    console.error('confirmEventRegistrationAfterPayment error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Check event queue position
exports.checkEventQueuePosition = functions.https.onCall(async (data, context) => {
  try {
    const { reservationId, userId } = data;
    
    if (!reservationId || !userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    const db = admin.firestore();
    const reservationDoc = await db.collection('event_reservations').doc(reservationId).get();
    
    if (!reservationDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Reservation not found');
    }
    
    const reservation = reservationDoc.data();
    
    if (reservation.userId !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'You do not own this reservation');
    }
    
    // Check if expired
    const expiresAt = reservation.expiresAt?.toDate();
    if (expiresAt && expiresAt < new Date()) {
      return {
        expired: true,
        message: 'Reservation expired'
      };
    }
    
    return {
      reservationId,
      queuePosition: reservation.queuePosition || 1,
      status: reservation.status || 'queued',
      expiresAt: reservation.expiresAt,
      message: reservation.queuePosition === 1 ? 'Ready to pay' : `Position ${reservation.queuePosition} in queue`
    };
  } catch (error) {
    console.error('checkEventQueuePosition error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Cleanup expired event reservations (runs every 1 minute)
exports.cleanupExpiredEventReservations = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  
  // Get expired reservations (single field query - no composite index needed)
  const expiredReservations = await db.collection('event_reservations')
    .where('expiresAt', '<=', now)
    .limit(500) // Process in batches to avoid timeout
    .get();
  
  console.log(`[Cleanup] Found ${expiredReservations.size} expired event reservations`);
  
  const client = getRazorpayClient();
  
  for (const doc of expiredReservations.docs) {
    const reservation = doc.data();
    
    try {
      // If payment was made but registration not confirmed, process refund
      if (reservation.razorpayOrderId) {
        const orderDoc = await db.collection('razorpay_orders').doc(reservation.razorpayOrderId).get();
        if (orderDoc.exists) {
          const orderData = orderDoc.data();
          if (!orderData.registration_completed) {
            // Check if payment was captured
            try {
              const order = await client.orders.fetch(reservation.razorpayOrderId);
              const payments = await client.orders.fetchPayments(reservation.razorpayOrderId);
              const capturedPayment = payments?.items?.find(p => p.status === 'captured');
              
              if (capturedPayment) {
                // Refund the payment
                await client.payments.refund(capturedPayment.id, {
                  amount: Math.round((orderData.total_paid || 0) * 100),
                  notes: {
                    reason: 'Event reservation expired - automatic refund',
                    reservation_id: doc.id
                  }
                });
                console.log(`[Cleanup] Refunded payment for expired event reservation ${doc.id}`);
              }
            } catch (refundError) {
              console.error(`[Cleanup] Error refunding for ${doc.id}:`, refundError);
            }
          }
        }
      }
      
      // Remove from queue
      const eventId = reservation.eventId;
      const queueId = `event_queue_${eventId}`;
      const queueDoc = await db.collection('event_queues').doc(queueId).get();
      
      if (queueDoc.exists) {
        const queueData = queueDoc.data();
        let users = queueData.users || [];
        users = users.filter(u => u.reservationId !== doc.id);
        
        // Promote next user if this was position 1
        if (reservation.queuePosition === 1 && users.length > 0) {
          const nextUser = users[0];
          const nextReservationRef = db.collection('event_reservations').doc(nextUser.reservationId);
          const nextReservationDoc = await nextReservationRef.get();
          
          if (nextReservationDoc.exists) {
            await nextReservationRef.update({
              queuePosition: 1,
              status: 'ready',
              expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 1000))
            });
            
            // Update other positions
            for (let i = 1; i < users.length; i++) {
              const userReservationRef = db.collection('event_reservations').doc(users[i].reservationId);
              await userReservationRef.update({
                queuePosition: i + 1,
                status: 'queued'
              });
            }
          }
        }
        
        // Update or delete queue
        if (users.length > 0) {
          await queueDoc.ref.update({
            users,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          });
        } else {
          await queueDoc.ref.delete();
        }
      }
      
      // Delete reservation
      await doc.ref.delete();
      console.log(`[Cleanup] Removed expired event reservation ${doc.id}`);
      
    } catch (error) {
      console.error(`[Cleanup] Error processing event reservation ${doc.id}:`, error);
    }
  }
  
  return null;
});

exports.createRazorpayOrderWithTransfer = functions.https.onCall(async (data, context) => {
  try {
    const { totalAmount, payableAmount, ownerAccountId, bookingId, turfId, userId, bookingData, currency = 'INR' } = data;
    
    if (!totalAmount || !payableAmount || !ownerAccountId || !bookingId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    if (!ownerAccountId.startsWith('acc_')) {
      throw new functions.https.HttpsError('failed-precondition', 'Owner Razorpay Account ID is invalid');
    }
    
    // Get userId from context if not provided
    const actualUserId = userId || context.auth?.uid;
    if (!actualUserId) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const client = getRazorpayClient();
    const ownerShare = calculateOwnerShare(totalAmount);
    const platformProfit = payableAmount - totalAmount;
    
    const order = await client.orders.create({
      amount: Math.round(payableAmount * 100),
      currency,
      transfers: [{
        account: ownerAccountId,
        amount: Math.round(ownerShare * 100),
        currency
      }],
      notes: {
        booking_id: bookingId,
        owner_share: ownerShare.toString(),
        platform_profit: platformProfit.toString(),
        base_turf_amount: totalAmount.toString()
      }
    });
    
    const db = admin.firestore();
    await db.collection('razorpay_orders').doc(order.id).set({
      booking_id: bookingId,
      turf_id: turfId || null,
      user_id: actualUserId,
      total_paid: payableAmount,
      base_turf_amount: totalAmount,
      owner_share: ownerShare,
      platform_profit: platformProfit,
      razorpay_order_id: order.id,
      owner_account_id: ownerAccountId,
      booking_data: bookingData || null, // Store booking data for recovery
      booking_completed: false, // Flag to track if booking was created
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return {
      orderId: order.id,
      ownerShare,
      platformProfit,
      baseTurfAmount: totalAmount,
      amount: payableAmount
    };
  } catch (error) {
    console.error('Error creating Razorpay order with transfer:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Turf status change notifications
exports.onTurfApproved = functions.firestore
  .document('turfs/{turfId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      
      if (beforeData.turfstatus === 'Not Verified' && afterData.turfstatus === 'Verified') {
        const ownerId = afterData.ownerId;
        const turfName = afterData.name || 'Your turf';
        
        if (ownerId) {
          await sendNotificationToTurfOwner(
            ownerId,
            'Turf Approved! 🎉',
            `Congratulations! Your turf "${turfName}" has been approved and is now visible to users.`,
            {
              type: 'turf_approved',
              turfId: context.params.turfId,
              turfName: turfName,
              timestamp: new Date().toISOString()
            }
          );
        }
      }
    } catch (error) {
      console.error('Error in onTurfApproved:', error);
    }
  });

exports.onTurfRejected = functions.firestore
  .document('turfs/{turfId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      
      if (beforeData.turfstatus === 'Not Verified' && afterData.turfstatus === 'Disapproved') {
        const ownerId = afterData.ownerId;
        const turfName = afterData.name || 'Your turf';
        const rejectionReason = afterData.rejectionReason || 'No reason provided';
        
        if (ownerId) {
          await sendNotificationToTurfOwner(
            ownerId,
            'Turf Review Update',
            `Your turf "${turfName}" requires changes. Please review the feedback and resubmit.`,
            {
              type: 'turf_rejected',
              turfId: context.params.turfId,
              turfName: turfName,
              rejectionReason: rejectionReason,
              timestamp: new Date().toISOString()
            }
          );
        }
      }
    } catch (error) {
      console.error('Error in onTurfRejected:', error);
    }
  });

exports.onTurfCreated = functions.firestore
  .document('turfs/{turfId}')
  .onCreate(async (snap, context) => {
    try {
      const turfData = snap.data();
      const ownerId = turfData.ownerId;
      let ownerName = 'A Turf Owner';
      
      if (ownerId) {
        const userDoc = await admin.firestore().collection('users').doc(ownerId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          ownerName = userData.name || ownerName;
        }
      }
      
      await sendNotificationToAdmin(
        'New Turf Added',
        `${ownerName} added a new turf, kindly review it`,
        {
          type: 'turf_added',
          turfId: context.params.turfId,
          ownerId: ownerId,
          ownerName: ownerName,
          timestamp: new Date().toISOString()
        }
      );
    } catch (error) {
      console.error('Error notifying admin for new turf:', error);
    }
  });

exports.onUserVerificationSubmitted = functions.firestore
  .document('documents/{userId}')
  .onCreate(async (snap, context) => {
    try {
      const userId = context.params.userId;
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        console.log('User document not found');
        return;
      }
      
      const userData = userDoc.data();
      const userName = userData.name || 'Unknown User';
      const userEmail = userData.email || 'No email';
      
      await sendNotificationToAdmin(
        'New User Verification Submitted',
        `User "${userName}" has submitted verification details for review`,
        {
          type: 'verification_submitted',
          userId: userId,
          userName: userName,
          userEmail: userEmail,
          timestamp: new Date().toISOString()
        }
      );
    } catch (error) {
      console.error('Error in onUserVerificationSubmitted:', error);
    }
  });

// Email sending - Module-level transporters to prevent memory leaks
// Email transports - use environment variables for credentials
const TRANSPORTS = {
  User: nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: functions.config().customer.email_user,
      pass: functions.config().customer.email_pass
    }
  }),
  Other: nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: functions.config().owner.email_user,
      pass: functions.config().owner.email_pass
    }
  })
};

const supportApp = express();
supportApp.use(bodyParser.json());

supportApp.post('/sendSupportAck', async (req, res) => {
  const { ticketId, message } = req.body;
  
  if (!ticketId) {
    res.status(400).send('Missing ticketId');
    return;
  }
  
  try {
    const ticketDoc = await admin.firestore().collection('support_tickets').doc(ticketId).get();
    
    if (!ticketDoc.exists) {
      res.status(404).send('Support ticket not found');
      return;
    }
    
    const ticket = ticketDoc.data();
    const userId = ticket.userId;
    const subject = ticket.subject;
    const userEmail = ticket.userEmail;
    
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      res.status(404).send('User not found');
      return;
    }
    
    const user = userDoc.data();
    const userName = user.name || 'User';
    const userType = user.userType || 'User';
    
    const transporter = userType === 'User' ? TRANSPORTS.User : TRANSPORTS.Other;
    const fromEmail = userType === 'User' 
      ? 'BookTheBiz Support <customersbtb@gmail.com>'
      : 'BookTheBiz Support <bookthebizag@gmail.com>';
    
    let emailText = `Dear ${userName},\n\n`;
    
    if (message && message.trim() !== '') {
      emailText += `Admin Response:\n${message.trim()}\n\n`;
    } else {
      emailText += `We have received your support ticket.\n\nSubject: ${subject}\n\nOur team will respond within 3 business days to your registered email/phone number.\n\n`;
    }
    
    emailText += `Thank you for contacting us!\n\n- BookTheBiz Support`;
    
    const mailOptions = {
      from: fromEmail,
      to: userEmail,
      subject: 'Support Ticket Update',
      text: emailText
    };
    
    await transporter.sendMail(mailOptions);
    res.status(200).send('Email sent!');
  } catch (error) {
    console.error('Error sending email:', error);
    res.status(500).send('Failed to send email');
  }
});

exports.supportApi = functions.https.onRequest(supportApp);

exports.sendBookingConfirmationEmail = functions.https.onCall(async (data, context) => {
  try {
    const { to, userName = 'Customer', bookingId = '', turfName = '', ground = '', bookingDate = '', slots = '', totalHours = 0, amount = 0, paymentMethod = 'Online' } = data;
    
    if (!to || typeof to !== 'string' || !to.includes('@')) {
      throw new functions.https.HttpsError('invalid-argument', 'Valid recipient email (to) is required');
    }
    
    // Use pre-created transporter instead of creating new one
    const transporter = TRANSPORTS.User;
    
    const appLogoPath = path.resolve(__dirname, 'assets', 'app.png');
    const companyLogoPath = path.resolve(__dirname, 'assets', 'logo.png');
    
    // Format date nicely
    const formatDate = (value) => {
      if (!value) return 'Not specified';
      try {
        if (value.toDate) {
          return new Date(value.toDate()).toLocaleDateString('en-IN', { day: '2-digit', month: 'long', year: 'numeric' });
        }
        const parsed = new Date(value);
        if (!isNaN(parsed.getTime())) {
          return parsed.toLocaleDateString('en-IN', { day: '2-digit', month: 'long', year: 'numeric' });
        }
      } catch (err) {
        console.error('Error formatting booking date:', err);
      }
      return value.toString();
    };

    const prettyDate = formatDate(bookingDate);
    const slotList = Array.isArray(slots) ? slots.join(', ') : slots;
    
    const subject = `🏆 Booking Confirmed - ${turfName} - ${prettyDate}`;
    
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Turf Booking Confirmation</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0; padding:0; background-color:#f5f7fb; font-family: 'Segoe UI', Arial, sans-serif; color:#1e293b;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#f5f7fb;">
    <tr>
      <td align="center" style="padding:32px 16px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:660px; background-color:#ffffff; border-radius:18px; overflow:hidden; box-shadow:0 15px 45px rgba(15,118,110,0.12);">
          <tr>
            <td style="background:linear-gradient(135deg,#0f766e,#14b8a6); padding:32px 28px;">
              <h1 style="margin:0; color:#f8fafc; font-size:26px; font-weight:700;">Booking Confirmed 🎾</h1>
              <p style="margin:12px 0 0; color:#f0fdfa; font-size:16px;">Hi <strong>${userName}</strong>, your turf is ready! We're excited to host your game at <strong>${turfName}</strong>.</p>
            </td>
          </tr>
          <tr>
            <td style="padding:28px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse; background-color:#f8fafc; border:1px solid #e2e8f0; border-radius:14px; overflow:hidden;">
                <tr style="background-color:#e0f2f1;">
                  <td colspan="2" style="padding:14px 18px; font-weight:700; font-size:15px; color:#0f766e;">📍 Booking Details</td>
          </tr>
          <tr>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">Booking ID</td>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0; font-weight:600;">${bookingId || 'Will be shared at venue'}</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">🏟️ Turf</td>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0; font-weight:600;">${turfName || 'Not specified'}</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">⚽ Ground</td>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">${ground || 'Not specified'}</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">📅 Date</td>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">${prettyDate}</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">🕐 Time Slots</td>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">${slotList || 'Not specified'}</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px;">⏱️ Total Hours</td>
                  <td style="padding:12px 18px; font-weight:600;">${Number(totalHours || 0).toFixed(0)} hour${Number(totalHours || 0) !== 1 ? 's' : ''}</td>
                </tr>
              </table>

              <table width="100%" cellpadding="0" cellspacing="0" style="margin-top:24px; border-collapse:collapse; background-color:#f8fafc; border:1px solid #e2e8f0; border-radius:14px; overflow:hidden;">
                <tr style="background-color:#e0f2f1;">
                  <td colspan="2" style="padding:14px 18px; font-weight:700; font-size:15px; color:#0f766e;">💳 Payment Summary</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">Amount Paid</td>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0; font-weight:700; font-size:16px; color:#0f766e;">₹${Number(amount || 0).toFixed(2)}</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px;">Payment Method</td>
                  <td style="padding:12px 18px;">${paymentMethod === 'Online' ? '💳 Online Payment' : paymentMethod}</td>
                </tr>
              </table>

              <div style="margin-top:28px; padding:18px 20px; background-color:#ecfeff; border:1px solid #99f6e4; border-radius:14px; color:#0f766e;">
                <strong>📋 Important Reminders:</strong>
                <ul style="margin:12px 0 0 18px; padding:0;">
                  <li>Arrive at least 10 minutes before your booked time slot.</li>
                  <li>Carry a valid ID proof for verification at the venue.</li>
                  <li>Save this email for quick access to your booking details.</li>
                  <li>Contact the turf owner if you need to reschedule or cancel.</li>
                </ul>
              </div>

              <p style="margin:28px 0 8px; font-size:14px; color:#475569;">We hope you have an amazing game! 🎉 Have questions? Reply to this email or reach us at <a href="mailto:customersbtb@gmail.com" style="color:#0f766e; font-weight:600;">customersbtb@gmail.com</a>.</p>
              <p style="margin:0; font-size:13px; color:#94a3b8;">Warm regards,<br><strong>Team BookTheBiz</strong> ⚽</p>
            </td>
          </tr>
          <tr>
            <td style="background-color:#0f172a; color:#cbd5f5; text-align:center; padding:18px; font-size:12px;">
              © ${new Date().getFullYear()} BookTheBiz. All rights reserved. Need help? <a href="mailto:customersbtb@gmail.com" style="color:#38bdf8;">Contact Support</a>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `;
    
    const mailOptions = {
      from: 'BookTheBiz <customersbtb@gmail.com>',
      to,
      subject,
      html
    };
    
    const info = await transporter.sendMail(mailOptions);
    return { ok: true, id: info.messageId };
  } catch (error) {
    console.error('sendBookingConfirmationEmail error:', error);
    throw new functions.https.HttpsError('internal', `${error.message} - Failed to send email`);
  }
});

// =========================
// EVENT REGISTRATION FUNCTIONS
// =========================

// Function to resolve event owner account ID
async function resolveEventOwnerAccountId(eventId, registrationData) {
  if (!eventId) return null;
  
  try {
    const db = admin.firestore();
    const eventDoc = await db.collection('spot_events').doc(eventId).get();
    
    if (!eventDoc.exists) {
      console.error(`Event ${eventId} not found`);
      return null;
    }
    
    const event = eventDoc.data();
    const ownerId = event.ownerId || registrationData.ownerId;
    
    if (!ownerId) {
      console.error(`No ownerId found for event ${eventId}`);
      return null;
    }
    
    const userDoc = await db.collection('users').doc(ownerId).get();
    
    if (!userDoc.exists) {
      console.error(`Owner user ${ownerId} not found`);
      return null;
    }
    
    const user = userDoc.data();
    
    // Try common field names for Razorpay connected account id
    const candidateKeys = ['razorpayAccountId', 'ownerAccountId', 'accountId', 'razorpay_account_id', 'razorpay_accountId'];
    for (const key of candidateKeys) {
      const acc = user[key];
      if (typeof acc === 'string' && acc.startsWith('acc_')) {
        return acc;
      }
    }
    
    console.error(`No valid Razorpay account ID found for owner ${ownerId}`);
    return null;
  } catch (error) {
    console.error('Error resolving event owner account ID:', error);
    return null;
  }
}

// Create Razorpay order with transfer for events
exports.createRazorpayOrderWithTransferForEvent = functions.https.onCall(async (data, context) => {
  try {
    const { totalAmount, payableAmount, ownerAccountId, registrationId, eventId, userId, registrationData, currency = 'INR' } = data;
    
    if (!totalAmount || !payableAmount || !ownerAccountId || !registrationId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    if (!ownerAccountId.startsWith('acc_')) {
      throw new functions.https.HttpsError('failed-precondition', 'Owner Razorpay Account ID is invalid');
    }
    
    // Get userId from context if not provided
    const actualUserId = userId || context.auth?.uid;
    if (!actualUserId) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const client = getRazorpayClient();
    const ownerShare = calculateOwnerShare(totalAmount);
    const platformProfit = payableAmount - totalAmount;
    
    const order = await client.orders.create({
      amount: Math.round(payableAmount * 100),
      currency,
      transfers: [{
        account: ownerAccountId,
        amount: Math.round(ownerShare * 100),
        currency
      }],
      notes: {
        registration_id: registrationId,
        event_id: eventId,
        owner_share: ownerShare.toString(),
        platform_profit: platformProfit.toString(),
        base_event_amount: totalAmount.toString()
      }
    });
    
    const db = admin.firestore();
    await db.collection('razorpay_orders').doc(order.id).set({
      registration_id: registrationId,
      event_id: eventId || null,
      user_id: actualUserId,
      total_paid: payableAmount,
      base_event_amount: totalAmount,
      owner_share: ownerShare,
      platform_profit: platformProfit,
      razorpay_order_id: order.id,
      owner_account_id: ownerAccountId,
      registration_data: registrationData || null, // Store registration data for recovery
      registration_completed: false, // Flag to track if registration was created
      user_name: registrationData?.userName || null,
      user_email: registrationData?.userEmail || null,
      user_phone: registrationData?.userPhone || null,
      event_location: registrationData?.eventLocation || null,
      event_type: registrationData?.eventType || null,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return {
      orderId: order.id,
      ownerShare,
      platformProfit,
      baseEventAmount: totalAmount,
      amount: payableAmount
    };
  } catch (error) {
    console.error('Error creating Razorpay order with transfer for event:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Internal function to create event registration (shared logic)
async function createEventRegistrationInternal(data) {
  const {
    orderId,
    paymentId,
    userId,
    eventId,
    eventName = '',
    ownerId = '',
    eventDate,
    eventTime,
    eventLocation = '',
    eventType = '',
    baseAmount,
    payableAmount,
    userName = 'User',
    userEmail = '',
    userPhone = '',
    userImageUrl = ''
  } = data;
    
    if (!orderId || !paymentId || !userId || !eventId || !eventDate) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    const client = getRazorpayClient();
    const payment = await client.payments.fetch(paymentId);
    
    if (!payment || payment.status !== 'captured') {
      throw new functions.https.HttpsError('failed-precondition', 'Payment not captured');
    }
    
    if (payment.order_id !== orderId) {
      throw new functions.https.HttpsError('failed-precondition', 'Payment does not match order');
    }
    
    const paidAmountInr = Number(payment.amount) / 100.0;
    if (Math.abs(paidAmountInr - payableAmount) > 0.01) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Payment verification failed. Expected: ₹${payableAmount.toFixed(2)}, Received: ₹${paidAmountInr.toFixed(2)}`
      );
    }
    
    const db = admin.firestore();
    
    // Check for duplicate booking with same payment ID (idempotency)
    const existingRegistration = await db.collection('event_registrations')
      .where('razorpayPaymentId', '==', paymentId)
      .limit(1)
      .get();
    
    if (!existingRegistration.empty) {
      const existing = existingRegistration.docs[0].data();
      console.log('Duplicate event registration attempt detected for payment:', paymentId);
      return {
        ok: true,
        status: 'confirmed',
        registrationId: existingRegistration.docs[0].id,
        message: 'Registration already exists for this payment'
      };
    }
    
    const lockId = `event_${eventId}_${eventDate}`;
    const lockRef = db.collection('event_locks').doc(lockId);
    
    try {
      const result = await db.runTransaction(async (tx) => {
        // ✅ BUG FIX #1: ALL READS FIRST, THEN ALL WRITES
        // STEP 1: Do ALL READS FIRST
        const lockDoc = await tx.get(lockRef);
        
        // Check if event is full
        const eventDoc = await tx.get(db.collection('spot_events').doc(eventId));
        if (!eventDoc.exists) {
          throw new functions.https.HttpsError('not-found', 'Event not found');
        }
        
        const eventData = eventDoc.data();
        const maxParticipants = eventData.maxParticipants || 0;
        
        let registrationsQuery = null;
        if (maxParticipants > 0) {
          registrationsQuery = await tx.get(
            db.collection('event_registrations')
              .where('eventId', '==', eventId)
              .where('status', '!=', 'cancelled')
          );
        }
        
        // Check if user already registered
        const existingReg = await tx.get(
          db.collection('event_registrations')
            .where('userId', '==', userId)
            .where('eventId', '==', eventId)
            .where('status', '!=', 'cancelled')
            .limit(1)
        );
        
        // STEP 2: VALIDATE (after all reads)
        if (lockDoc.exists) {
          const lockData = lockDoc.data();
          if (lockData.locked) {
            const expiresAt = lockData.expiresAt?.toDate();
            if (expiresAt && expiresAt > new Date()) {
              throw new functions.https.HttpsError('aborted', 'Event registration is currently being processed. Please try again.');
            }
          }
        }
        
        if (maxParticipants > 0 && registrationsQuery) {
          const currentCount = registrationsQuery.size;
          if (currentCount >= maxParticipants) {
            throw new functions.https.HttpsError('failed-precondition', 'Event is full');
          }
        }
        
        if (!existingReg.empty) {
          throw new functions.https.HttpsError('already-exists', 'You are already registered for this event');
        }
        
        // STEP 3: Do ALL WRITES
        tx.set(lockRef, {
          locked: true,
          userId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30000))
        });
        
        const now = admin.firestore.FieldValue.serverTimestamp();
        const registrationData = {
          eventId,
          eventName,
          eventDate,
          eventTime: eventTime || null,
          eventLocation: eventLocation || null,
          eventType: eventType || null,
          userId,
          userName,
          userEmail,
          userPhone: userPhone || null,
          userImageUrl: userImageUrl || null,
          paymentMethod: 'Online',
          status: 'confirmed',
          payoutStatus: 'pending',
          price: payableAmount,
          baseAmount: baseAmount,
          razorpayPaymentId: paymentId,
          razorpayOrderId: orderId,
          ownerId: ownerId || null,
          createdAt: now,
          updatedAt: now
        };
        
        const registrationRef = db.collection('event_registrations').doc();
        tx.set(registrationRef, registrationData);
        tx.delete(lockRef);
        
        return { registrationId: registrationRef.id };
      });
      
      // Update razorpay_orders to mark registration as completed
      try {
        await db.collection('razorpay_orders').doc(orderId).update({
          registration_completed: true,
          completed_at: admin.firestore.FieldValue.serverTimestamp()
        });
      } catch (updateErr) {
        console.error('Failed to update razorpay_orders registration_completed flag:', updateErr);
        // Don't throw - registration was created successfully
      }
      
      return { ok: true, status: 'confirmed', ...result };
      
    } catch (txError) {
      try {
        await lockRef.delete();
      } catch (deleteErr) {
        console.error('Failed to release lock after error:', deleteErr);
      }
      throw txError;
    }
}

// Public function for event registration confirmation
exports.confirmEventRegistrationAndWrite = functions.https.onCall(async (data, context) => {
  try {
    // Call internal shared function
    return await createEventRegistrationInternal(data);
    
  } catch (error) {
    console.error('confirmEventRegistrationAndWrite error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Event registration creation trigger for payout processing
exports.onEventRegistrationCreated = functions.firestore
  .document('event_registrations/{registrationId}')
  .onCreate(async (snap, context) => {
    try {
      const data = snap.data();
      const db = admin.firestore();
      
      // Only process online confirmed payments
      if (data.paymentMethod !== 'Online') {
        console.log('Skipping payout: Not an online payment');
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
      
      const totalAmount = parseFloat(data.price) || 0;
      let ownerAccountId = data.eventOwnerAccountId;
      const paymentId = data.razorpayPaymentId;
      const eventId = data.eventId;
      
      console.log('Processing event registration:', context.params.registrationId, 'Amount:', totalAmount, 'Event:', eventId);
      
      // Guard clauses
      if (totalAmount <= 0) {
        await snap.ref.update({ payoutStatus: 'failed', payoutError: 'Invalid amount' });
        return;
      }
      
      if (!ownerAccountId) {
        try {
          ownerAccountId = await resolveEventOwnerAccountId(eventId, data);
        } catch (error) {
          await snap.ref.update({ payoutStatus: 'failed', payoutError: `Owner account resolution error: ${error.message}` });
          return;
        }
      }
      
      if (!ownerAccountId) {
        await snap.ref.update({ payoutStatus: 'failed', payoutError: 'Missing Razorpay connected account ID. Owner must add their Razorpay account ID to receive payments.' });
        return;
      }
      
      if (!paymentId) {
        await snap.ref.update({ payoutStatus: 'failed', payoutError: 'Missing Razorpay payment ID for transfer' });
        return;
      }
      
      if (!ownerAccountId.startsWith('acc_')) {
        await snap.ref.update({ payoutStatus: 'failed', payoutError: 'Owner does not have a valid Razorpay connected account ID.' });
        return;
      }
      
      // Calculate owner's share
      const ownerShare = calculateOwnerShare(data.baseAmount || totalAmount);
      const companyProfit = totalAmount - ownerShare;
      
      // Check for pending clawback deductions
      let totalDeductions = 0;
      let ownerId = data.ownerId;
      
      if (ownerId) {
        try {
          // FIX #2: Query BOTH pending AND overdue deductions
          const pendingDeductions = await db.collection('turfownerdeductions')
            .where('ownerId', '==', ownerId)
            .where('status', '==', 'pending')
            .get();
          
          const overdueDeductions = await db.collection('turfownerdeductions')
            .where('ownerId', '==', ownerId)
            .where('status', '==', 'overdue')
            .get();
          
          // Merge both query results
          const allDeductions = [...pendingDeductions.docs, ...overdueDeductions.docs];
          
          allDeductions.forEach(doc => {
            totalDeductions += (doc.data().amount || 0);
          });
          
          if (totalDeductions > 0) {
            console.log(`Found ${pendingDeductions.size} pending + ${overdueDeductions.size} overdue deductions: ₹${totalDeductions} for owner ${ownerId}`);
          }
        } catch (error) {
          console.error('Error checking deductions:', error);
        }
      }
      
      // Calculate final payout after deductions
      const finalPayout = Math.max(0, ownerShare - totalDeductions);
      const actualDeduction = ownerShare - finalPayout;
      
      console.log('Total amount paid by user:', totalAmount);
      console.log('Owner share (base amount):', ownerShare);
      console.log('Pending deductions:', totalDeductions);
      console.log('Final payout to owner:', finalPayout);
      console.log('Company keeps (profit + fees):', companyProfit);
      
      // Mark deductions as applied BEFORE transfer attempt
      // This ensures deductions are marked even if transfer fails
      if (totalDeductions > 0 && ownerId) {
        try {
          // FIX #2: Query BOTH pending AND overdue deductions to mark as applied
          const pendingDeductions = await db.collection('turfownerdeductions')
            .where('ownerId', '==', ownerId)
            .where('status', '==', 'pending')
            .get();
          
          const overdueDeductions = await db.collection('turfownerdeductions')
            .where('ownerId', '==', ownerId)
            .where('status', '==', 'overdue')
            .get();
          
          // Merge both query results
          const allDeductions = [...pendingDeductions.docs, ...overdueDeductions.docs];
          
          if (allDeductions.length > 0) {
            const batch = db.batch();
            allDeductions.forEach(doc => {
              batch.update(doc.ref, {
                status: 'applied',
                appliedAt: admin.firestore.FieldValue.serverTimestamp(),
                appliedToRegistration: context.params.registrationId,
                appliedToRegistrationAmount: finalPayout,
                actualDeductionAmount: actualDeduction
              });
            });
            await batch.commit();
            console.log(`✅ Marked ${allDeductions.length} deductions (${pendingDeductions.size} pending + ${overdueDeductions.size} overdue) as applied for owner ${ownerId} (registration: ${context.params.registrationId}, payout: ₹${finalPayout})`);
          }
        } catch (error) {
          console.error('❌ Error updating deduction status:', error);
          // Continue with transfer attempt even if deduction marking fails
          // This prevents blocking the payout if there's a deduction update issue
        }
      }
      
      // Process payment
      const ownerPaymentMethod = await getOwnerPaymentMethod(ownerAccountId, eventId, data);
      const client = getRazorpayClient();
      
      if (ownerPaymentMethod.type === 'razorpay') {
        try {
          await processRazorpayTransfer(client, paymentId, finalPayout, ownerPaymentMethod.accountId);
          
          // Update registration after successful transfer
          await snap.ref.update({
            payoutStatus: 'settled',
            transferResponse: null,
            eventOwnerAccountId: ownerAccountId,
            payoutMethod: 'Razorpay Route'
          });
          
          // Save settlement info for successful transfer
          await db.collection('event_settlements').doc(context.params.registrationId).set({
            registration_id: context.params.registrationId,
            event_id: eventId || null,
            total_paid: totalAmount,
            owner_share: ownerShare,
            platform_profit: companyProfit,
            pending_deductions: totalDeductions,
            final_payout: finalPayout,
            actual_deduction: actualDeduction,
            razorpay_payment_id: paymentId,
            owner_account_id: ownerAccountId,
            transfer_status: 'success',
            settled_at: admin.firestore.FieldValue.serverTimestamp()
          });
          
          console.log('✅ Successfully processed payout for event registration:', context.params.registrationId);
        } catch (transferError) {
          console.error('❌ Razorpay transfer failed:', transferError);
          // Mark as failed but deductions are already marked as applied
          await snap.ref.update({ 
            payoutStatus: 'failed', 
            payoutError: `Razorpay transfer failed: ${transferError.message}` 
          });
          
          // Save settlement info even for failed transfer (deductions were applied)
          try {
            await db.collection('event_settlements').doc(context.params.registrationId).set({
              registration_id: context.params.registrationId,
              event_id: eventId || null,
              total_paid: totalAmount,
              owner_share: ownerShare,
              platform_profit: companyProfit,
              pending_deductions: totalDeductions,
              final_payout: finalPayout,
              actual_deduction: actualDeduction,
              razorpay_payment_id: paymentId,
              owner_account_id: ownerAccountId,
              transfer_status: 'failed',
              transfer_error: transferError.message,
              deductions_applied: true, // Important: deductions were marked as applied
              settled_at: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
          } catch (settlementError) {
            console.error('Error saving failed settlement info:', settlementError);
          }
          
          throw transferError; // Re-throw to be caught by outer catch block
        }
      }
    } catch (error) {
      console.error('Function execution error:', error);
      try {
        await snap.ref.update({ payoutStatus: 'failed', payoutError: `Function error: ${error.message}` });
      } catch (updateError) {
        console.error('Failed to update payout status:', updateError);
      }
  }
});

// =========================
// ✅ BUG FIX #2: EVENT REGISTRATION RECOVERY FOR LOW-RAM DEVICES
// =========================

exports.verifyAndCompleteEventRegistration = functions.https.onCall(async (data, context) => {
  try {
    const { orderId, registrationData } = data;
    
    if (!orderId || !registrationData) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing orderId or registrationData');
    }
    
    const db = admin.firestore();
    
    // Check if registration already exists (idempotency)
    const existingRegistration = await db
      .collection('event_registrations')
      .where('razorpayOrderId', '==', orderId)
      .limit(1)
      .get();
    
    if (!existingRegistration.empty) {
      console.log('Registration already exists for order:', orderId);
      return {
        ok: true,
        status: 'confirmed',
        registrationId: existingRegistration.docs[0].id,
        message: 'Registration already confirmed for this payment'
      };
    }
    
    // Fetch order from database
    const orderDoc = await db.collection('razorpay_orders').doc(orderId).get();
    
    if (!orderDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Order not found');
    }
    
    const client = getRazorpayClient();
    const order = await client.orders.fetch(orderId);
    
    if (!order) {
      throw new functions.https.HttpsError('not-found', 'Order not found in Razorpay');
    }
    
    // Get payments
    const payments = await client.orders.fetchPayments(orderId);
    
    if (!payments || !payments.items || payments.items.length === 0) {
      throw new functions.https.HttpsError('failed-precondition', 'No payment found');
    }
    
    // Find captured payment
    const capturedPayment = payments.items.find((p) => p.status === 'captured');
    
    if (!capturedPayment) {
      throw new functions.https.HttpsError('failed-precondition', 'Payment not captured');
    }
    
    // Call internal event registration function
    return await createEventRegistrationInternal({
      orderId,
      paymentId: capturedPayment.id,
      ...registrationData
    });
  } catch (error) {
    console.error('verifyAndCompleteEventRegistration error:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Cleanup expired event locks
exports.cleanupExpiredEventLocks = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const expiredLocks = await db.collection('event_locks')
    .where('expiresAt', '<=', now)
    .get();
  
  const batch = db.batch();
  expiredLocks.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
  console.log(`Cleaned up ${expiredLocks.size} expired event locks`);
});

// Create refund request for event
exports.createEventRefundRequest = functions.https.onCall(async (data, context) => {
  try {
    const { registrationId, userId, eventId, amount, paymentId, reason = 'User requested cancellation', eventDate, eventName } = data;
    
    if (!registrationId || !userId || !amount || !paymentId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    const db = admin.firestore();
    
    const registrationDoc = await db.collection('event_registrations').doc(registrationId).get();
    const registrationData = registrationDoc.exists ? registrationDoc.data() : {};
    const baseAmount = registrationData.baseAmount || (parseFloat(amount) * 0.85);
    
    const refundRequest = {
      registrationId,
      userId,
      eventId,
      amount: parseFloat(amount),
      baseAmount: baseAmount,
      paymentId,
      reason,
      status: 'pending',
      eventDate,
      eventName,
      requestedAt: admin.firestore.FieldValue.serverTimestamp(),
      processedAt: null,
      refundId: null,
      adminNotes: '',
      createdBy: 'user',
      type: 'event'
    };
    
    const refundDoc = await db.collection('refund_requests').add(refundRequest);
    
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.exists ? userDoc.data() : {};
    const userName = userData.name || 'User';
    
    await sendNotificationToAdmin(
      'New Event Refund Request',
      `${userName} has requested a refund of ₹${amount} for event registration cancellation`,
      {
        type: 'refund_request',
        refundRequestId: refundDoc.id,
        registrationId,
        userId,
        amount: parseFloat(amount),
        userName,
        timestamp: new Date().toISOString()
      }
    );
    
    await db.collection('event_registrations').doc(registrationId).update({
      status: 'cancelled',
      refundRequestId: refundDoc.id,
      cancelledAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return {
      success: true,
      refundRequestId: refundDoc.id,
      message: 'Refund request submitted successfully. Admin will review and process your refund.'
    };
  } catch (error) {
    console.error('Error creating event refund request:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Process event refund (reuse turf refund logic with event-specific handling)
exports.processEventRefund = functions.https.onCall(async (data, context) => {
  try {
    const { refundRequestId, action, adminNotes = '' } = data;
    
    if (!refundRequestId || !action) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    const db = admin.firestore();
    const reqSnap = await db.collection('refund_requests').doc(refundRequestId).get();
    
    if (!reqSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Refund request not found');
    }
    
    const req = reqSnap.data();
    
    if (req.status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 'Refund request already processed');
    }
    
    if (action === 'reject') {
      await reqSnap.ref.update({
        status: 'rejected',
        adminNotes,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      await sendNotificationToUser(
        req.userId,
        'Refund Request Rejected',
        `Your refund request has been rejected. ${adminNotes}. Please contact support for more details.`,
        {
          type: 'refund_rejected',
          refundRequestId,
          registrationId: req.registrationId
        }
      );
      
      return { success: true, message: 'Refund request rejected' };
    }
    
    // APPROVE
    const client = getRazorpayClient();
    const paymentId = String(req.paymentId).trim();
    const totalAmountInr = Number(req.amount);
    
    if (!paymentId || !isFinite(totalAmountInr) || totalAmountInr <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid paymentId or amount');
    }
    
    const payment = await client.payments.fetch(paymentId);
    if (!payment || payment.status !== 'captured') {
      throw new functions.https.HttpsError('failed-precondition', 'Payment not captured or not found');
    }
    
    const paidPaise = Number(payment.amount) || 0;
    const refundedPaise = Number(payment.amount_refunded) || 0;
    const remainingPaise = paidPaise - refundedPaise;
    const requestedPaise = Math.round(totalAmountInr * 100);
    
    if (requestedPaise > remainingPaise) {
      throw new functions.https.HttpsError('failed-precondition', `Requested refund exceeds remaining refundable amount. Remaining: ₹${(remainingPaise/100).toFixed(2)}`);
    }
    
    // Get event owner ID
    const registrationDoc = await db.collection('event_registrations').doc(req.registrationId).get();
    const registrationData = registrationDoc.exists ? registrationDoc.data() : {};
    
    let eventOwnerId = registrationData.ownerId;
    if (!eventOwnerId && req.eventId) {
      try {
        const eventDoc = await db.collection('spot_events').doc(req.eventId).get();
        if (eventDoc.exists) {
          eventOwnerId = eventDoc.data().ownerId;
        }
      } catch (error) {
        console.error('Error fetching event owner:', error);
      }
    }
    
    const baseEventAmount = Number(req.baseAmount) || (totalAmountInr * 0.85);
    const platformAmount = totalAmountInr - baseEventAmount;
    
    let refund;
    try {
      // Refund FULL amount to customer
      refund = await client.payments.refund(paymentId, {
        amount: requestedPaise,
        notes: {
          reason: String(req.reason || ''),
          registration_id: String(req.registrationId || ''),
          refund_request_id: String(refundRequestId || ''),
          full_refund: 'true',
          type: 'event'
        }
      });
    } catch (refundError) {
      console.error('Razorpay refund API error:', refundError);
      
      await reqSnap.ref.update({
        status: 'failed',
        adminNotes: `Razorpay refund failed: ${refundError.message}`,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      throw new functions.https.HttpsError('failed-precondition', `Razorpay refund failed: ${refundError.message}`);
    }
    
    // Use transaction to ensure all database updates succeed together
    await db.runTransaction(async (tx) => {
      // Create clawback for owner's share ONLY
      if (baseEventAmount > 0 && eventOwnerId) {
        const deductionRef = db.collection('turfownerdeductions').doc();
        tx.set(deductionRef, {
          ownerId: eventOwnerId,
          eventId: req.eventId,
          registrationId: req.registrationId,
          refundRequestId: refundRequestId,
          refundId: refund.id,
          amount: baseEventAmount,
          reason: 'Automated clawback for approved event refund - owner share only',
          status: 'pending',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          appliedAt: null,
          notes: {
            customerRefund: totalAmountInr,
            platformAbsorbed: platformAmount,
            clawbackAmount: baseEventAmount,
            type: 'event'
          }
        });
        console.log(`Clawback created: ₹${baseEventAmount} (Platform absorbs: ₹${platformAmount})`);
      }
      
      // Update refund request
      tx.update(reqSnap.ref, {
        status: 'processed',
        refundId: refund.id,
        razorpayRefundId: refund.id,
        refundStatus: refund.status,
        adminNotes,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        refundBreakdown: {
          totalAmount: totalAmountInr,
          baseEventAmount: baseEventAmount,
          platformAmount: platformAmount,
          clawbackCreated: (baseEventAmount > 0 && eventOwnerId) ? true : false
        }
      });
      
      // Update registration
      const registrationRef = db.collection('event_registrations').doc(req.registrationId);
      tx.update(registrationRef, {
        refundStatus: 'processed',
        refundId: refund.id,
        refundedAt: admin.firestore.FieldValue.serverTimestamp(),
        refundBreakdown: {
          totalAmount: totalAmountInr,
          baseEventAmount: baseEventAmount,
          platformAmount: platformAmount,
          clawbackCreated: (baseEventAmount > 0 && eventOwnerId) ? true : false
        }
      });
    });
    
    await sendNotificationToUser(
      req.userId,
      'Refund Processed Successfully',
      `Your refund of ₹${totalAmountInr.toFixed(2)} has been processed and will reflect in your account within 5-7 business days.`,
      {
        type: 'refund_processed',
        refundRequestId,
        registrationId: req.registrationId,
        amount: totalAmountInr,
        refundId: refund.id
      }
    );
    
    return { success: true, refundId: refund.id, message: 'Refund processed successfully' };
  } catch (err) {
    const raw = err?.error || err?.response || err;
    const rpMsg = raw?.description || raw?.error?.description || raw?.data?.error?.description || raw?.message;
    const finalMsg = rpMsg || (typeof raw === 'string' ? raw : JSON.stringify(raw));
    console.error('processEventRefund error:', finalMsg);
    
    try {
      if (data?.refundRequestId) {
        await admin.firestore().collection('refund_requests').doc(data.refundRequestId).update({
          status: 'failed',
          adminNotes: `Razorpay refund failed: ${finalMsg}`,
          processedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
    } catch {}
    
    if (err instanceof functions.https.HttpsError) throw err;
    throw new functions.https.HttpsError('failed-precondition', `Razorpay refund failed: ${finalMsg}`);
  }
});

// Send event registration confirmation email
exports.sendEventRegistrationConfirmationEmail = functions.https.onCall(async (data, context) => {
  try {
    const {
      to,
      userName = 'Customer',
      registrationId = '',
      eventName = '',
      eventDate = '',
      eventTime = '',
      eventLocation = '',
      eventType = '',
      amount = 0,
      paymentMethod = 'Online',
      paymentReference = '',
      userEmail = '',
      userPhone = ''
    } = data;

    if (!to || typeof to !== 'string' || !to.includes('@')) {
      throw new functions.https.HttpsError('invalid-argument', 'Valid recipient email (to) is required');
    }

    const transporter = TRANSPORTS.User;

    const formatDate = (value) => {
      if (!value) return 'To be announced';
      try {
        if (value.toDate) {
          return new Date(value.toDate()).toLocaleDateString('en-IN', { day: '2-digit', month: 'long', year: 'numeric' });
        }
        const parsed = new Date(value);
        if (!isNaN(parsed.getTime())) {
          return parsed.toLocaleDateString('en-IN', { day: '2-digit', month: 'long', year: 'numeric' });
        }
      } catch (err) {
        console.error('Error formatting event date:', err);
      }
      return value.toString();
    };

    const formatTime = (value) => {
      if (!value) return 'To be announced';
      if (typeof value === 'string') {
        const parts = value.split(':');
        if (parts.length >= 2) {
          let hour = parseInt(parts[0], 10);
          const minute = parseInt(parts[1], 10);
          if (!isNaN(hour) && !isNaN(minute)) {
            const period = hour >= 12 ? 'PM' : 'AM';
            hour = hour % 12;
            if (hour === 0) hour = 12;
            return `${hour}:${minute.toString().padStart(2, '0')} ${period}`;
          }
        }
      }
      return value.toString();
    };

    const prettyDate = formatDate(eventDate);
    const prettyTime = formatTime(eventTime);
    const attendeeEmail = userEmail && userEmail.trim().length > 0 ? userEmail : to;
    const attendeePhone = userPhone && userPhone.trim().length > 0 ? userPhone : 'Not provided';
    const locationLabel = eventLocation && eventLocation.toString().trim().length > 0 ? eventLocation : 'To be announced';
    const eventTypeLabel = eventType && eventType.toString().trim().length > 0 ? eventType : 'General';
    const paymentRows = amount > 0
      ? `
        <tr>
          <td style="padding:12px; border-bottom:1px solid #e2e8f0;">Amount Paid</td>
          <td style="padding:12px; border-bottom:1px solid #e2e8f0; font-weight:600; color:#047857;">₹${Number(amount || 0).toFixed(2)}</td>
        </tr>
        <tr>
          <td style="padding:12px; border-bottom:1px solid #e2e8f0;">Payment Method</td>
          <td style="padding:12px; border-bottom:1px solid #e2e8f0;">${paymentMethod}</td>
        </tr>
        ${paymentReference ? `
          <tr>
            <td style="padding:12px;">Payment Reference</td>
            <td style="padding:12px;">${paymentReference}</td>
          </tr>
        ` : ''}
      `
      : `
        <tr>
          <td style="padding:12px; border-bottom:1px solid #e2e8f0;">Entry Type</td>
          <td style="padding:12px; border-bottom:1px solid #e2e8f0; font-weight:600; color:#047857;">Free Entry</td>
        </tr>
      `;

    const subject = `Event Registration Confirmed - ${eventName || 'Upcoming Event'} (${prettyDate})`;

    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Event Registration Confirmation</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0; padding:0; background-color:#f5f7fb; font-family: 'Segoe UI', Arial, sans-serif; color:#1e293b;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#f5f7fb;">
    <tr>
      <td align="center" style="padding:32px 16px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:660px; background-color:#ffffff; border-radius:18px; overflow:hidden; box-shadow:0 15px 45px rgba(15,118,110,0.12);">
          <tr>
            <td style="background:linear-gradient(135deg,#0f766e,#14b8a6); padding:32px 28px;">
              <h1 style="margin:0; color:#f8fafc; font-size:26px; font-weight:700;">Registration Confirmed ✅</h1>
              <p style="margin:12px 0 0; color:#f0fdfa; font-size:16px;">Hi ${userName}, we're excited to see you at <strong>${eventName}</strong>.</p>
            </td>
          </tr>
          <tr>
            <td style="padding:28px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse; background-color:#f8fafc; border:1px solid #e2e8f0; border-radius:14px; overflow:hidden;">
                <tr style="background-color:#e0f2f1;">
                  <td colspan="2" style="padding:14px 18px; font-weight:700; font-size:15px; color:#0f766e;">Attendee Details</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">Name</td>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0; font-weight:600;">${userName}</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">Email</td>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">${attendeeEmail}</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px;">Phone</td>
                  <td style="padding:12px 18px;">${attendeePhone}</td>
                </tr>
              </table>

              <table width="100%" cellpadding="0" cellspacing="0" style="margin-top:24px; border-collapse:collapse; background-color:#f8fafc; border:1px solid #e2e8f0; border-radius:14px; overflow:hidden;">
                <tr style="background-color:#e0f2f1;">
                  <td colspan="2" style="padding:14px 18px; font-weight:700; font-size:15px; color:#0f766e;">Event Details</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">Registration ID</td>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0; font-weight:600;">${registrationId || 'Will be shared onsite'}</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">Date</td>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">${prettyDate}</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">Time</td>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">${prettyTime}</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">Location</td>
                  <td style="padding:12px 18px; border-bottom:1px solid #e2e8f0;">${locationLabel}</td>
                </tr>
                <tr>
                  <td style="padding:12px 18px;">Category</td>
                  <td style="padding:12px 18px;">${eventTypeLabel}</td>
                </tr>
              </table>

              <table width="100%" cellpadding="0" cellspacing="0" style="margin-top:24px; border-collapse:collapse; background-color:#f8fafc; border:1px solid #e2e8f0; border-radius:14px; overflow:hidden;">
                <tr style="background-color:#e0f2f1;">
                  <td colspan="2" style="padding:14px 18px; font-weight:700; font-size:15px; color:#0f766e;">Payment Summary</td>
                </tr>
                ${paymentRows}
              </table>

              <div style="margin-top:28px; padding:18px 20px; background-color:#ecfeff; border:1px solid #99f6e4; border-radius:14px; color:#0f766e;">
                <strong>Next steps:</strong>
                <ul style="margin:12px 0 0 18px; padding:0;">
                  <li>Save this email for smooth entry at the venue.</li>
                  <li>Arrive at least 15 minutes before the scheduled start time.</li>
                  <li>Contact us if you need to update attendee information.</li>
                </ul>
              </div>

              <p style="margin:28px 0 8px; font-size:14px; color:#475569;">We look forward to hosting you. Have questions? Reply to this email or reach us at <a href="mailto:customersbtb@gmail.com" style="color:#0f766e; font-weight:600;">customersbtb@gmail.com</a>.</p>
              <p style="margin:0; font-size:13px; color:#94a3b8;">Warm regards,<br><strong>Team BookTheBiz</strong></p>
            </td>
          </tr>
          <tr>
            <td style="background-color:#0f172a; color:#cbd5f5; text-align:center; padding:18px; font-size:12px;">
              © ${new Date().getFullYear()} BookTheBiz. All rights reserved. Need help? <a href="mailto:customersbtb@gmail.com" style="color:#38bdf8;">Contact Support</a>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `;

    const mailOptions = {
      from: 'BookTheBiz <customersbtb@gmail.com>',
      to,
      subject,
      html
    };

    const info = await transporter.sendMail(mailOptions);
    return { ok: true, id: info.messageId };
  } catch (error) {
    console.error('sendEventRegistrationConfirmationEmail error:', error);
    throw new functions.https.HttpsError('internal', `${error.message} - Failed to send email`);
  }
});
