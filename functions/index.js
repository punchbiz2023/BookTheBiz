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
      console.log('Turf owner not found:', ownerId);
      return;
    }
    
    const ownerData = ownerDoc.data();
    const fcmToken = ownerData.fcmToken;
    
    if (!fcmToken) {
      console.log('Turf owner FCM token not found:', ownerId);
      return;
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
    
    const response = await admin.messaging().send(message);
    console.log('Successfully sent notification to turf owner:', response);
    return response;
  } catch (error) {
    console.error('Error sending notification to turf owner:', error);
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
          const deductionsQuery = await db.collection('turfownerdeductions')
            .where('ownerId', '==', ownerId)
            .where('status', '==', 'pending')
            .get();
          
          deductionsQuery.forEach(doc => {
            totalDeductions += (doc.data().amount || 0);
          });
          
          if (totalDeductions > 0) {
            console.log(`Found pending deductions: ₹${totalDeductions} for owner ${ownerId} (account: ${ownerAccountId})`);
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
      
      // Process payment
      const ownerPaymentMethod = await getOwnerPaymentMethod(ownerAccountId, turfId, data);
      const client = getRazorpayClient();
      
      if (ownerPaymentMethod.type === 'razorpay') {
        await processRazorpayTransfer(client, paymentId, finalPayout, ownerPaymentMethod.accountId);
        
        // Mark deductions as applied
        if (totalDeductions > 0 && ownerId) {
          try {
            const deductionsQuery = await db.collection('turfownerdeductions')
              .where('ownerId', '==', ownerId)
              .where('status', '==', 'pending')
              .get();
            
            const batch = db.batch();
            deductionsQuery.forEach(doc => {
              batch.update(doc.ref, {
                status: 'applied',
                appliedAt: admin.firestore.FieldValue.serverTimestamp(),
                appliedToBooking: context.params.bookingId
              });
            });
            await batch.commit();
            console.log(`Marked ${deductionsQuery.size} deductions as applied for owner ${ownerId}`);
          } catch (error) {
            console.error('Error updating deduction status:', error);
          }
        }
      }
      
      // Update booking
      await updateBookingAfterTransfer(snap, 'settled', null, ownerAccountId);
      
      // Save settlement info
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
        settled_at: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log('Successfully processed payout for booking:', context.params.bookingId);
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

exports.confirmBookingAndWrite = functions.https.onCall(async (data, context) => {
  const lockRef = null;
  try {
    // Validate and sanitize input
    const validatedData = validateBookingInput(data);
    const { orderId, paymentId, userId, turfId, turfName = '', ownerId = '', bookingDate, selectedGround, slots, totalHours, baseAmount, payableAmount } = validatedData;
    
    const client = getRazorpayClient();
    const payment = await client.payments.fetch(paymentId);
    
    if (!payment || payment.status !== 'captured') {
      throw new functions.https.HttpsError('failed-precondition', 'Payment not captured');
    }
    
    if (payment.order_id !== orderId) {
      throw new functions.https.HttpsError('failed-precondition', 'Payment does not match order');
    }
    
    const paidAmountInr = Number(payment.amount) / 100.0;
    if (Math.abs(paidAmountInr - payableAmount) > 1) {
      throw new functions.https.HttpsError('failed-precondition', 'Paid amount mismatch');
    }
    
    const db = admin.firestore();
    const lockId = `${turfId}_${selectedGround}_${bookingDate}_${slots.sort().join('_')}`;
    const lockRef = db.collection('slot_locks').doc(lockId);
    
    try {
      const result = await db.runTransaction(async (tx) => {
        const lockDoc = await tx.get(lockRef);
        
        if (lockDoc.exists) {
          const lockData = lockDoc.data();
          if (lockData.locked) {
            const expiresAt = lockData.expiresAt?.toDate();
            if (expiresAt && expiresAt > new Date()) {
              throw new functions.https.HttpsError('aborted', 'Slots are currently being booked. Please try again.');
            }
          }
        }
        
        tx.set(lockRef, {
          locked: true,
          userId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30000))
        });
        
        const bookingsCol = db.collection('turfs').doc(turfId).collection('bookings');
        const q = await tx.get(
          bookingsCol
            .where('selectedGround', '==', selectedGround)
            .where('bookingDate', '==', bookingDate)
        );
        
        let allBooked = [];
        q.forEach(doc => {
          const s = doc.data().bookingSlots || [];
          allBooked = allBooked.concat(s);
        });
        
        const hasConflict = slots.some(slot => allBooked.includes(slot));
        if (hasConflict) {
          throw new functions.https.HttpsError('aborted', 'Selected slots already booked');
        }
        
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
    
  } catch (error) {
    console.error('confirmBookingAndWrite error:', error);
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
      
      await sendNotificationToUser(
        req.userId,
        'Refund Request Rejected',
        `Your refund request has been rejected. ${adminNotes}. Please contact support for more details.`,
        {
          type: 'refund_rejected',
          refundRequestId,
          bookingId: req.bookingId
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
    
    // Get turf owner ID
    const bookingDoc = await db.collection('bookings').doc(req.bookingId).get();
    const bookingData = bookingDoc.exists ? bookingDoc.data() : {};
    
    let turfOwnerId = bookingData.ownerId;
    if (!turfOwnerId && req.turfId) {
      try {
        const turfDoc = await db.collection('turfs').doc(req.turfId).get();
        if (turfDoc.exists) {
          turfOwnerId = turfDoc.data().ownerId;
        }
      } catch (error) {
        console.error('Error fetching turf owner:', error);
      }
    }
    
    const baseTurfAmount = Number(req.baseAmount) || (totalAmountInr * 0.85);
    const platformAmount = totalAmountInr - baseTurfAmount;
    
    let refund;
    try {
      // Refund FULL amount to customer
      refund = await client.payments.refund(paymentId, {
        amount: requestedPaise,
        notes: {
          reason: req.reason,
          booking_id: req.bookingId,
          refund_request_id: refundRequestId,
          admin_notes: adminNotes || '',
          full_refund: 'true'
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
      if (baseTurfAmount > 0 && turfOwnerId) {
        const deductionRef = db.collection('turfownerdeductions').doc();
        tx.set(deductionRef, {
          ownerId: turfOwnerId,
          turfId: req.turfId,
          bookingId: req.bookingId,
          refundRequestId: refundRequestId,
          refundId: refund.id,
          amount: baseTurfAmount,
          reason: 'Automated clawback for approved refund - owner share only',
          status: 'pending',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          appliedAt: null,
          notes: {
            customerRefund: totalAmountInr,
            platformAbsorbed: platformAmount,
            clawbackAmount: baseTurfAmount
          }
        });
        console.log(`Clawback created: ₹${baseTurfAmount} (Platform absorbs: ₹${platformAmount})`);
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
          baseTurfAmount: baseTurfAmount,
          platformAmount: platformAmount,
          clawbackCreated: (baseTurfAmount > 0 && turfOwnerId) ? true : false
        }
      });
      
      // Update booking
      const bookingRef = db.collection('bookings').doc(req.bookingId);
      tx.update(bookingRef, {
        refundStatus: 'processed',
        refundId: refund.id,
        refundedAt: admin.firestore.FieldValue.serverTimestamp(),
        refundBreakdown: {
          totalAmount: totalAmountInr,
          baseTurfAmount: baseTurfAmount,
          platformAmount: platformAmount,
          clawbackCreated: (baseTurfAmount > 0 && turfOwnerId) ? true : false
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
        bookingId: req.bookingId,
        amount: totalAmountInr,
        refundId: refund.id
      }
    );
    
    return { success: true, refundId: refund.id, message: 'Refund processed successfully' };
  } catch (err) {
    const raw = err?.error || err?.response || err;
    const rpMsg = raw?.description || raw?.error?.description || raw?.data?.error?.description || raw?.message;
    const finalMsg = rpMsg || (typeof raw === 'string' ? raw : JSON.stringify(raw));
    console.error('processRefund error:', finalMsg);
    
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
        overdueMarkedAt: admin.firestore.FieldValue.serverTimestamp()
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
      
      let paymentLink = null;
      try {
        paymentLink = await razorpay.paymentLink.create({
          amount: Math.round(data.amount * 100),
          currency: 'INR',
          description: `Refund Clawback Payment - Booking ${data.bookingId}`,
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
            booking_id: data.bookingId,
            turf_id: data.turfId
          },
          callback_url: `https://yourapp.com/payment-success`,
          callback_method: 'get'
        });
      } catch (error) {
        console.error('Error creating payment link:', error);
      }
      
      await db.collection('manual_clawback_payments').doc(doc.id).set({
        deductionId: doc.id,
        ownerId: data.ownerId,
        turfId: data.turfId,
        bookingId: data.bookingId,
        amount: data.amount,
        reason: data.reason,
        status: 'pending_payment',
        paymentLink: paymentLink?.short_url || '',
        paymentLinkId: paymentLink?.id || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        dueDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        notes: 'Automated: Pending clawback exceeded 7 days. Manual payment required.',
        remindersSent: 0,
        lastReminderAt: null
      });
      
      await sendNotificationToTurfOwner(
        data.ownerId,
        '⚠️ Urgent: Payment Required',
        `You must pay ₹${data.amount} for a refunded booking. ${paymentLink ? `Pay here: ${paymentLink.short_url}` : 'Contact admin for payment details.'}`,
        {
          type: 'clawback_overdue',
          deductionId: doc.id,
          amount: data.amount.toString(),
          paymentLink: paymentLink?.short_url || '',
          dueDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
        }
      );
      
      await sendNotificationToAdmin(
        'Overdue Clawback Created',
        `Owner ${data.ownerId} has overdue clawback of ₹${data.amount}. Payment link ${paymentLink ? 'sent' : 'creation failed'}.`,
        {
          type: 'clawback_overdue_admin',
          deductionId: doc.id,
          ownerId: data.ownerId,
          amount: data.amount.toString(),
          paymentLink: paymentLink?.short_url || ''
        }
      );
    }
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
      
      if (notes.purpose === 'clawback_payment') {
        const db = admin.firestore();
        const deductionId = notes.deduction_id;
        
        await db.collection('manual_clawback_payments').doc(deductionId).update({
          status: 'paid',
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
          paymentId: payload.payment.entity.id,
          paymentMethod: payload.payment.entity.method
        });
        
        await db.collection('turfownerdeductions').doc(deductionId).update({
          status: 'settled_manual',
          settledAt: admin.firestore.FieldValue.serverTimestamp(),
          settlementMethod: 'manual_payment_link'
        });
        
        await sendNotificationToTurfOwner(
          notes.owner_id,
          '✅ Payment Received',
          `Your payment of ₹${payload.payment.entity.amount / 100} has been received. Thank you!`,
          { type: 'clawback_paid' }
        );
        
        await sendNotificationToAdmin(
          'Clawback Paid',
          `Owner ${notes.owner_id} paid clawback of ₹${payload.payment.entity.amount / 100}`,
          { type: 'clawback_paid_admin', deductionId }
        );
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
      throw new functions.https.HttpsError('not-found', 'Payment record not found');
    }
    
    const paymentData = paymentDoc.data();
    
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
    
    await paymentDoc.ref.update({
      remindersSent: admin.firestore.FieldValue.increment(1),
      lastReminderAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return { success: true, message: 'Reminder sent successfully' };
  } catch (error) {
    console.error('Error sending reminder:', error);
    throw new functions.https.HttpsError('internal', error.message);
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

exports.createRazorpayOrderWithTransfer = functions.https.onCall(async (data, context) => {
  try {
    const { totalAmount, payableAmount, ownerAccountId, bookingId, turfId, currency = 'INR' } = data;
    
    if (!totalAmount || !payableAmount || !ownerAccountId || !bookingId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    
    if (!ownerAccountId.startsWith('acc_')) {
      throw new functions.https.HttpsError('failed-precondition', 'Owner Razorpay Account ID is invalid');
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
      total_paid: payableAmount,
      base_turf_amount: totalAmount,
      owner_share: ownerShare,
      platform_profit: platformProfit,
      razorpay_order_id: order.id,
      owner_account_id: ownerAccountId,
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
const TRANSPORTS = {
  User: nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: 'customersbtb@gmail.com',
      pass: 'fofb axss moce zspb'
    }
  }),
  Other: nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: 'ownersbtb@gmail.com',
      pass: 'uqec eqiq ipti zbhp'
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
    
    const prettyDate = bookingDate || new Date().toISOString().slice(0, 10);
    const slotList = Array.isArray(slots) ? slots.join(', ') : slots;
    
    const subject = `Booking Confirmed - ${turfName} - ${prettyDate}`;
    
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Booking Confirmation</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0; padding:0; background-color:#f5f5f5; font-family: Arial, sans-serif; color:#333333;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color:#f5f5f5; width:100%;">
    <tr>
      <td align="center" style="padding: 20px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:600px; background-color:#ffffff; border-radius:8px; overflow:hidden; box-shadow:0 0 10px rgba(0,0,0,0.1);">
          <tr>
            <td style="background-color:#0f766e; padding:20px;">
              <h1 style="color:#ffffff; font-size:22px; text-align:center; margin:0;">Your Booking is Confirmed</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:20px;">
              <p style="margin:0; font-size:16px;">Hi <strong>${userName}</strong>, thanks for booking with us. Here are your booking details:</p>
            </td>
          </tr>
          <tr>
            <td style="padding:0 20px 20px 20px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%; border-collapse: collapse; font-size:14px;">
                <tr>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Booking ID</strong></td>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;">${bookingId}</td>
                </tr>
                <tr>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Turf</strong></td>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;">${turfName}</td>
                </tr>
                <tr>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Ground</strong></td>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;">${ground}</td>
                </tr>
                <tr>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Date</strong></td>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;">${prettyDate}</td>
                </tr>
                <tr>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Time Slots</strong></td>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;">${slotList}</td>
                </tr>
                <tr>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Total Hours</strong></td>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;">${Number(totalHours || 0).toFixed(0)}</td>
                </tr>
                <tr>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Amount Paid</strong></td>
                  <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><span style="color:#0f766e; font-weight:bold;">₹${Number(amount || 0).toFixed(2)}</span></td>
                </tr>
                <tr>
                  <td style="padding:10px 0;"><strong>Payment Method</strong></td>
                  <td style="padding:10px 0;">${paymentMethod}</td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="background-color:#f9fafb; padding:15px 20px; text-align:center; font-size:12px; color:#6b7280;">
              If you have questions, reply to this email or contact support.<br>
              &copy; ${new Date().getFullYear()} BookTheBiz. All rights reserved.
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
