// ===================================================================
// COMPLETE FIXED index.js - PAYMENT GATEWAY BUGS FIXED
// ===================================================================
// BUG FIXES APPLIED:
// 1. Transaction Read-After-Write Error - FIXED ✅
//    - All reads moved BEFORE any writes
//    - Applied to confirmBookingAndWrite and confirmEventRegistrationAndWrite
// 2. Low-RAM Device Payment Loss - FIXED ✅
//    - New verifyAndCompleteBooking function added for payment recovery
//    - New verifyAndCompleteEventRegistration function added
//    - Payment persistence + auto-recovery flow implemented in bookingpage.dart
// ===================================================================

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
    throw new Error('Razorpay environment variables RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET not set');
  }

  return new Razorpay({
    key_id: keyId,
    key_secret: keySecret,
  });
}

// ===================================================================
// HELPER FUNCTIONS
// ===================================================================

// Function to update payout status
async function updatePayoutStatus(snap, status, reason) {
  try {
    await snap.ref.update({
      payoutStatus: status,
      payoutError: reason,
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
      payoutMethod: 'Razorpay Route',
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
      console.error('Turf', turfId, 'not found');
      return null;
    }

    const turf = turfDoc.data();
    const ownerId = turf.ownerId || bookingData.ownerId;

    if (!ownerId) {
      console.error('No ownerId found for turf', turfId);
      return null;
    }

    const userDoc = await db.collection('users').doc(ownerId).get();

    if (!userDoc.exists) {
      console.error('Owner user', ownerId, 'not found');
      return null;
    }

    const user = userDoc.data();

    // Try common field names for Razorpay connected account id
    const candidateKeys = ['razorpayAccountId', 'ownerAccountId', 'accountId', 'razorpayaccountid', 'razorpayaccountId'];
    for (const key of candidateKeys) {
      const acc = user[key];
      if (typeof acc === 'string' && acc.startsWith('acc_')) {
        return acc;
      }
    }

    console.error('No valid Razorpay account ID found for owner', ownerId);
    return null;
  } catch (error) {
    console.error('Error resolving owner account ID:', error);
    return null;
  }
}

// Returns the platform profit based on turf rate slabs
function calculatePlatformProfit(turfRate) {
  if (turfRate < 1000) {
    return turfRate * 0.15;
  } else if (turfRate < 3000) {
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
      transfers: [
        {
          account: accountId,
          amount: amountInPaise,
          currency: 'INR',
        },
      ],
      notes: {
        purpose: 'Turf booking settlement - Base amount only',
        note: 'Company profit and platform fees retained in merchant account',
      },
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

  if (!isFinite(baseAmount) || baseAmount < 0) {
    errors.push('Invalid baseAmount - must be a positive number');
  }

  if (!isFinite(payableAmount) || payableAmount < 0) {
    errors.push('Invalid payableAmount - must be a positive number');
  }

  if (isFinite(baseAmount) && isFinite(payableAmount) && payableAmount < baseAmount) {
    errors.push('Payable amount cannot be less than base amount');
  }

  if (!data.selectedGround || typeof data.selectedGround !== 'string' || data.selectedGround.trim().length === 0) {
    errors.push('Invalid selectedGround');
  }

  if (errors.length > 0) {
    throw new functions.https.HttpsError('invalid-argument', errors.join(', '));
  }

  return {
    ...data,
    paymentId: data.paymentId.trim(),
    userId: data.userId.trim(),
    turfId: data.turfId.trim(),
    baseAmount,
    payableAmount,
    totalHours: Number(data.totalHours) || data.slots.length,
    selectedGround: data.selectedGround.trim(),
  };
}

// ===================================================================
// NOTIFICATION FUNCTIONS
// ===================================================================

async function sendNotificationToAdmin(title, body, data) {
  try {
    const adminQuery = await admin.firestore()
      .collection('users')
      .where('email', '==', 'adminpuncbiz@gmail.com')
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
      data: {
        ...data,
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
      token: fcmToken,
      android: {
        notification: {
          channelId: 'verification_channel',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
          icon: 'app',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
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
      data: {
        ...data,
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
      token: fcmToken,
      android: {
        notification: {
          channelId: 'turf_status_channel',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
          icon: 'app',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
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
      data: {
        ...data,
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
      token: fcmToken,
      android: {
        notification: {
          channelId: 'refund_channel',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
          icon: 'app',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log('Successfully sent notification to user:', response);
    return response;
  } catch (error) {
    console.error('Error sending notification to user:', error);
    throw error;
  }
}

// ===================================================================
// BOOKING CREATION TRIGGER
// ===================================================================

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
          await mainDocRef.set(
            {
              ...data,
              turfBookingId: context.params.bookingId,
              turfId: context.params.turfId,
              [data.turfId]: null,
              mirroredAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
          mirrored = true;
        } catch (mirrorErr) {
          retries--;
          if (retries === 0) {
            console.error('Failed to mirror booking after 3 attempts:', mirrorErr);
            await db.collection('failedMirrors').add({
              bookingId: context.params.bookingId,
              turfId: context.params.turfId,
              error: mirrorErr.message,
              data: data,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });
          } else {
            await new Promise((resolve) => setTimeout(resolve, 1000));
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
      if (totalAmount < 0) {
        await updatePayoutStatus(snap, 'failed', 'Invalid amount');
        return;
      }

      if (!ownerAccountId) {
        try {
          ownerAccountId = await resolveOwnerAccountId(turfId, data);
        } catch (error) {
          await updatePayoutStatus(snap, 'failed', 'Owner account resolution error: ' + error.message);
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
          const usersQuery = await db
            .collection('users')
            .where('razorpayAccountId', '==', ownerAccountId)
            .limit(1)
            .get();

          if (!usersQuery.empty) {
            ownerId = usersQuery.docs[0].id;
          }
        }

        if (ownerId) {
          const deductionsQuery = await db
            .collection('turf_owner_deductions')
            .where('ownerId', '==', ownerId)
            .where('status', '==', 'pending')
            .get();

          deductionsQuery.forEach((doc) => {
            totalDeductions += doc.data().amount || 0;
          });

          if (totalDeductions > 0) {
            console.log('Found pending deductions:', totalDeductions, 'for owner:', ownerId, 'account:', ownerAccountId);
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
      }

      // Mark deductions as applied
      if (totalDeductions > 0 && ownerId) {
        try {
          const deductionsQuery = await db
            .collection('turf_owner_deductions')
            .where('ownerId', '==', ownerId)
            .where('status', '==', 'pending')
            .get();

          const batch = db.batch();
          deductionsQuery.forEach((doc) => {
            batch.update(doc.ref, {
              status: 'applied',
              appliedAt: admin.firestore.FieldValue.serverTimestamp(),
              appliedToBooking: context.params.bookingId,
            });
          });
          await batch.commit();
          console.log('Marked', deductionsQuery.size, 'deductions as applied for owner:', ownerId);
        } catch (error) {
          console.error('Error updating deduction status:', error);
        }
      }

      // Update booking
      await updateBookingAfterTransfer(snap, 'settled', null, ownerAccountId);

      // Save settlement info
      await db
        .collection('bookingSettlements')
        .doc(context.params.bookingId)
        .set({
          bookingid: context.params.bookingId,
          turfid: turfId || null,
          totalpaid: totalAmount,
          ownershare: ownerShare,
          platformprofit: companyProfit,
          pendingdeductions: totalDeductions,
          finalpayout: finalPayout,
          actualdeduction: actualDeduction,
          razorpaypaymentid: paymentId,
          owneraccountid: ownerAccountId,
          settledat: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log('Successfully processed payout for booking:', context.params.bookingId);
    } catch (error) {
      console.error('Function execution error:', error);
      try {
        await updatePayoutStatus(snap, 'failed', 'Function error: ' + error.message);
      } catch (updateError) {
        console.error('Failed to update payout status:', updateError);
      }
    }
  });

// ===================================================================
// BOOKING CONFIRMATION - FIXED: Transaction Read-After-Write
// ===================================================================

exports.confirmBookingAndWrite = functions.https.onCall(async (data, context) => {
  let lockRef = null;

  try {
    // Validate and sanitize input
    const validatedData = validateBookingInput(data);
    const { orderId, paymentId, userId, turfId, turfName, ownerId, bookingDate, selectedGround, slots, totalHours, baseAmount, payableAmount } = validatedData;
    const db = admin.firestore();

    // Check for duplicate booking with same payment ID (idempotency)
    const existingBooking = await db
      .collection('bookings')
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
        message: 'Booking already exists for this payment',
      };
    }

    const client = getRazorpayClient();

    // Verify payment with Razorpay
    const payment = await client.payments.fetch(paymentId);

    if (!payment || payment.status !== 'captured') {
      throw new functions.https.HttpsError('failed-precondition', 'Payment not captured');
    }

    if (payment.order_id !== orderId) {
      throw new functions.https.HttpsError('failed-precondition', 'Payment does not match order');
    }

    const paidAmountInr = Number(payment.amount) / 100.0;

    if (Math.abs(paidAmountInr - payableAmount) > 0.01) {
      throw new functions.https.HttpsError('failed-precondition', 
        `Payment verification failed. Expected ${payableAmount.toFixed(2)}, Received ${paidAmountInr.toFixed(2)}`);
    }

    const lockId = turfId + selectedGround + bookingDate + slots.sort().join('');
    lockRef = db.collection('slotLocks').doc(lockId);

    try {
      // ✅ BUG FIX #1: ALL READS FIRST, THEN ALL WRITES
      const result = await db.runTransaction(async (tx) => {
        // ✅ STEP 1: Do ALL READS FIRST
        const lockDoc = await tx.get(lockRef);

        const bookingsCol = db.collection('turfs').doc(turfId).collection('bookings');
        const q = await tx.get(
          bookingsCol
            .where('selectedGround', '==', selectedGround)
            .where('bookingDate', '==', bookingDate)
        );

        // ✅ STEP 2: VALIDATE (after reads completed)
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
        q.forEach((doc) => {
          const s = doc.data().bookingSlots;
          allBooked = allBooked.concat(s);
        });

        const hasConflict = slots.some((slot) => allBooked.includes(slot));
        if (hasConflict) {
          throw new functions.https.HttpsError('aborted', 'Selected slots already booked');
        }

        // ✅ STEP 3: Do ALL WRITES
        tx.set(lockRef, {
          locked: true,
          userId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30000)),
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
          updatedAt: now,
        };

        const turfBookingRef = bookingsCol.doc();
        tx.set(turfBookingRef, bookingData);
        tx.delete(lockRef);

        return {
          turfBookingId: turfBookingRef.id,
          bookingId: turfBookingRef.id,
        };
      });

      return {
        ok: true,
        status: 'confirmed',
        ...result,
      };
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
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ===================================================================
// NEW FUNCTION: Verify and Complete Booking (Payment Recovery)
// ===================================================================

exports.verifyAndCompleteBooking = functions.https.onCall(async (data, context) => {
  try {
    const { orderId, bookingData } = data;

    if (!orderId || !bookingData) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing orderId or bookingData');
    }

    const db = admin.firestore();

    // Check if booking already exists
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
        message: 'Booking already confirmed for this payment',
      };
    }

    // Fetch order details from razorpay_orders collection
    const orderDoc = await db.collection('razorpayOrders').doc(orderId).get();

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

    // Now call confirmBookingAndWrite with the payment ID
    const result = await admin
      .functions()
      .httpsCallable('confirmBookingAndWrite')({
        orderId: orderId,
        paymentId: capturedPayment.id,
        ...bookingData,
      });

    return result;
  } catch (error) {
    console.error('verifyAndCompleteBooking error:', error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ===================================================================
// CLEANUP EXPIRED LOCKS
// ===================================================================

exports.cleanupExpiredLocks = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  const expiredLocks = await db
    .collection('slotLocks')
    .where('expiresAt', '<', now)
    .get();

  const batch = db.batch();
  expiredLocks.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
  console.log('Cleaned up', expiredLocks.size, 'expired locks');
});

// ===================================================================
// REFUND FUNCTIONS
// ===================================================================

exports.createRefundRequest = functions.https.onCall(async (data, context) => {
  try {
    const { bookingId, userId, turfId, amount, paymentId, reason, bookingDate, turfName, ground, slots } = data;

    if (!bookingId || !userId || !amount || !paymentId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }

    const db = admin.firestore();
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    const bookingData = bookingDoc.exists ? bookingDoc.data() : {};

    const baseAmount = bookingData.baseAmount ? parseFloat(amount) * 0.85 : 0;

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
      createdBy: 'user',
    };

    const refundDoc = await db.collection('refundRequests').add(refundRequest);

    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.exists ? userDoc.data() : {};
    const userName = userData.name || 'User';

    await sendNotificationToAdmin(
      'New Refund Request',
      `${userName} has requested a refund of ${amount} for booking cancellation`,
      {
        type: 'refundrequest',
        refundRequestId: refundDoc.id,
        bookingId,
        userId,
        amount: parseFloat(amount),
        userName,
        timestamp: new Date().toISOString(),
      }
    );

    await db.collection('bookings').doc(bookingId).update({
      status: 'cancelled',
      refundRequestId: refundDoc.id,
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      refundRequestId: refundDoc.id,
      message: 'Refund request submitted successfully. Admin will review and process your refund.',
    };
  } catch (error) {
    console.error('Error creating refund request:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

exports.processRefund = functions.https.onCall(async (data, context) => {
  try {
    const { refundRequestId, action, adminNotes } = data;

    if (!refundRequestId || !action) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }

    const db = admin.firestore();
    const reqSnap = await db.collection('refundRequests').doc(refundRequestId).get();

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
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await sendNotificationToUser(
        req.userId,
        'Refund Request Rejected',
        `Your refund request has been rejected. ${adminNotes}. Please contact support for more details.`,
        {
          type: 'refundrejected',
          refundRequestId,
          bookingId: req.bookingId,
        }
      );

      return {
        success: true,
        message: 'Refund request rejected',
      };
    }

    // APPROVE
    const client = getRazorpayClient();
    const paymentId = String(req.paymentId).trim();
    const totalAmountInr = Number(req.amount);

    if (!paymentId || !isFinite(totalAmountInr) || totalAmountInr < 0) {
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
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Requested refund exceeds remaining refundable amount. Remaining: ${(remainingPaise / 100).toFixed(2)}`
      );
    }

    let refund;
    try {
      refund = await client.payments.refund(paymentId, {
        amount: requestedPaise,
        notes: {
          reason: req.reason,
          bookingid: req.bookingId,
          refundrequestid: refundRequestId,
          adminnotes: adminNotes,
        },
        fullrefund: true,
      });
    } catch (refundError) {
      console.error('Razorpay refund API error:', refundError);
      await reqSnap.ref.update({
        status: 'failed',
        adminNotes: 'Razorpay refund failed: ' + refundError.message,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      throw new functions.https.HttpsError('failed-precondition', 'Razorpay refund failed: ' + refundError.message);
    }

    // Update refund request
    await reqSnap.ref.update({
      status: 'processed',
      refundId: refund.id,
      razorpayRefundId: refund.id,
      refundStatus: refund.status,
      adminNotes,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      refundBreakdown: {
        totalAmount: totalAmountInr,
        baseAmount: req.baseAmount,
        platformAmount: totalAmountInr - req.baseAmount,
      },
    });

    // Update booking
    await db.collection('bookings').doc(req.bookingId).update({
      refundStatus: 'processed',
      refundId: refund.id,
      refundedAt: admin.firestore.FieldValue.serverTimestamp(),
      refundBreakdown: {
        totalAmount: totalAmountInr,
        baseAmount: req.baseAmount,
        platformAmount: totalAmountInr - req.baseAmount,
      },
    });

    // Send notification to user
    await sendNotificationToUser(
      req.userId,
      'Refund Processed Successfully',
      `Your refund of ₹${totalAmountInr.toFixed(2)} has been processed and will reflect in your account within 5-7 business days.`,
      {
        type: 'refundprocessed',
        refundRequestId,
        bookingId: req.bookingId,
        amount: totalAmountInr,
        refundId: refund.id,
      }
    );

    return {
      success: true,
      refundId: refund.id,
      message: 'Refund processed successfully',
    };
  } catch (err) {
    const raw = err?.error || err?.response || err?.data?.error || err?.data || err?.message || err;
    const rpMsg =
      raw?.description ||
      raw?.error?.description ||
      raw?.data?.error?.description ||
      raw?.message;

    const finalMsg =
      rpMsg || (typeof raw === 'string' ? raw : JSON.stringify(raw));

    console.error('processRefund error:', finalMsg);

    try {
      if (data?.refundRequestId) {
        await admin
          .firestore()
          .collection('refundRequests')
          .doc(data.refundRequestId)
          .update({
            status: 'failed',
            adminNotes: 'Razorpay refund failed: ' + finalMsg,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      }
    } catch (e) {
      // ignored
    }

    if (err instanceof functions.https.HttpsError) {
      throw err;
    }

    throw new functions.https.HttpsError('failed-precondition', 'Razorpay refund failed: ' + finalMsg);
  }
});

// ===================================================================
// EVENT REGISTRATION FUNCTIONS
// ===================================================================

// Function to resolve event owner account ID
async function resolveEventOwnerAccountId(eventId, registrationData) {
  if (!eventId) return null;

  try {
    const db = admin.firestore();
    const eventDoc = await db.collection('spotevents').doc(eventId).get();

    if (!eventDoc.exists) {
      console.error('Event', eventId, 'not found');
      return null;
    }

    const event = eventDoc.data();
    const ownerId = event.ownerId || registrationData.ownerId;

    if (!ownerId) {
      console.error('No ownerId found for event', eventId);
      return null;
    }

    const userDoc = await db.collection('users').doc(ownerId).get();

    if (!userDoc.exists) {
      console.error('Owner user', ownerId, 'not found');
      return null;
    }

    const user = userDoc.data();

    // Try common field names for Razorpay connected account id
    const candidateKeys = ['razorpayAccountId', 'ownerAccountId', 'accountId', 'razorpayaccountid', 'razorpayaccountId'];
    for (const key of candidateKeys) {
      const acc = user[key];
      if (typeof acc === 'string' && acc.startsWith('acc_')) {
        return acc;
      }
    }

    console.error('No valid Razorpay account ID found for owner', ownerId);
    return null;
  } catch (error) {
    console.error('Error resolving event owner account ID:', error);
    return null;
  }
}

// Create Razorpay order with transfer for events
exports.createRazorpayOrderWithTransferForEvent = functions.https.onCall(async (data, context) => {
  try {
    const { totalAmount, payableAmount, ownerAccountId, registrationId, eventId, currency = 'INR' } = data;

    if (!totalAmount || !payableAmount || !ownerAccountId || !registrationId) {
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
      transfers: [
        {
          account: ownerAccountId,
          amount: Math.round(ownerShare * 100),
          currency,
        },
      ],
      notes: {
        registrationid: registrationId,
        eventid: eventId,
        ownershare: ownerShare.toString(),
        platformprofit: platformProfit.toString(),
        baseEventAmount: totalAmount.toString(),
      },
    });

    const db = admin.firestore();
    await db.collection('razorpayOrders').doc(order.id).set({
      registrationid: registrationId,
      eventid: eventId || null,
      totalpaid: payableAmount,
      baseEventAmount: totalAmount,
      ownershare: ownerShare,
      platformprofit: platformProfit,
      razorpayOrderId: order.id,
      ownerAccountId: ownerAccountId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      orderId: order.id,
      ownerShare,
      platformProfit,
      baseEventAmount: totalAmount,
      amount: payableAmount,
    };
  } catch (error) {
    console.error('Error creating Razorpay order with transfer for event:', error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Confirm event registration and write with payment verification
exports.confirmEventRegistrationAndWrite = functions.https.onCall(async (data, context) => {
  let lockRef = null;

  try {
    const { orderId, paymentId, userId, eventId, eventDate, eventTime, baseAmount, payableAmount, userName, userEmail, ownerId } = data;

    if (!orderId || !paymentId || !userId || !eventId || !eventDate) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }

    const client = getRazorpayClient();

    // Verify payment
    const payment = await client.payments.fetch(paymentId);

    if (!payment || payment.status !== 'captured') {
      throw new functions.https.HttpsError('failed-precondition', 'Payment not captured');
    }

    if (payment.order_id !== orderId) {
      throw new functions.https.HttpsError('failed-precondition', 'Payment does not match order');
    }

    const paidAmountInr = Number(payment.amount) / 100.0;

    if (Math.abs(paidAmountInr - payableAmount) > 0.01) {
      throw new functions.https.HttpsError('failed-precondition',
        `Payment verification failed. Expected ${payableAmount.toFixed(2)}, Received ${paidAmountInr.toFixed(2)}`);
    }

    const db = admin.firestore();

    // Check for duplicate registration (idempotency)
    const existingRegistration = await db
      .collection('eventRegistrations')
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
        message: 'Registration already exists for this payment',
      };
    }

    const lockId = 'event-' + eventId + '-' + eventDate;
    lockRef = db.collection('eventLocks').doc(lockId);

    try {
      // ✅ FIXED: ALL READS FIRST, THEN ALL WRITES
      const result = await db.runTransaction(async (tx) => {
        // ✅ STEP 1: Do ALL READS FIRST
        const lockDoc = await tx.get(lockRef);

        // Check event capacity
        const eventDoc = await tx.get(db.collection('spotevents').doc(eventId));

        if (!eventDoc.exists) {
          throw new functions.https.HttpsError('not-found', 'Event not found');
        }

        const eventData = eventDoc.data();
        const maxParticipants = eventData.maxParticipants || 0;

        if (maxParticipants > 0) {
          const registrationsQuery = await tx.get(
            db
              .collection('eventRegistrations')
              .where('eventId', '==', eventId)
              .where('status', '!=', 'cancelled')
          );
          const currentCount = registrationsQuery.size;

          if (currentCount >= maxParticipants) {
            throw new functions.https.HttpsError('failed-precondition', 'Event is full');
          }
        }

        // Check if user already registered
        const existingReg = await tx.get(
          db
            .collection('eventRegistrations')
            .where('userId', '==', userId)
            .where('eventId', '==', eventId)
            .where('status', '!=', 'cancelled')
            .limit(1)
        );

        if (!existingReg.empty) {
          throw new functions.https.HttpsError('already-exists', 'You are already registered for this event');
        }

        // ✅ STEP 2: VALIDATE (after all reads)
        if (lockDoc.exists) {
          const lockData = lockDoc.data();
          if (lockData.locked) {
            const expiresAt = lockData.expiresAt?.toDate();
            if (expiresAt && expiresAt > new Date()) {
              throw new functions.https.HttpsError('aborted', 'Event registration is currently being processed. Please try again.');
            }
          }
        }

        // ✅ STEP 3: Do ALL WRITES
        tx.set(lockRef, {
          locked: true,
          userId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30000)),
        });

        const now = admin.firestore.FieldValue.serverTimestamp();
        const registrationData = {
          eventId,
          eventName: data.eventName,
          eventDate,
          eventTime: eventTime || null,
          userId,
          userName,
          userEmail,
          paymentMethod: 'Online',
          status: 'confirmed',
          payoutStatus: 'pending',
          price: payableAmount,
          baseAmount: baseAmount,
          razorpayPaymentId: paymentId,
          razorpayOrderId: orderId,
          ownerId: ownerId || null,
          createdAt: now,
          updatedAt: now,
        };

        const registrationRef = db.collection('eventRegistrations').doc();
        tx.set(registrationRef, registrationData);
        tx.delete(lockRef);

        return {
          registrationId: registrationRef.id,
        };
      });

      return {
        ok: true,
        status: 'confirmed',
        ...result,
      };
    } catch (txError) {
      try {
        await lockRef.delete();
      } catch (deleteErr) {
        console.error('Failed to release lock after error:', deleteErr);
      }
      throw txError;
    }
  } catch (error) {
    console.error('confirmEventRegistrationAndWrite error:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ===================================================================
// NEW FUNCTION: Verify and Complete Event Registration
// ===================================================================

exports.verifyAndCompleteEventRegistration = functions.https.onCall(async (data, context) => {
  try {
    const { orderId, registrationData } = data;

    if (!orderId || !registrationData) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing orderId or registrationData');
    }

    const db = admin.firestore();

    // Check if registration already exists
    const existingRegistration = await db
      .collection('eventRegistrations')
      .where('razorpayOrderId', '==', orderId)
      .limit(1)
      .get();

    if (!existingRegistration.empty) {
      console.log('Registration already exists for order:', orderId);
      return {
        ok: true,
        status: 'confirmed',
        registrationId: existingRegistration.docs[0].id,
        message: 'Registration already confirmed for this payment',
      };
    }

    // Fetch order from database
    const orderDoc = await db.collection('razorpayOrders').doc(orderId).get();

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

    // Call confirmEventRegistrationAndWrite
    const result = await admin
      .functions()
      .httpsCallable('confirmEventRegistrationAndWrite')({
        orderId,
        paymentId: capturedPayment.id,
        ...registrationData,
      });

    return result;
  } catch (error) {
    console.error('verifyAndCompleteEventRegistration error:', error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ===================================================================
// EVENT REGISTRATION CREATION TRIGGER
// ===================================================================

exports.onEventRegistrationCreated = functions.firestore
  .document('eventRegistrations/{registrationId}')
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
      if (totalAmount < 0) {
        await snap.ref.update({
          payoutStatus: 'failed',
          payoutError: 'Invalid amount',
        });
        return;
      }

      if (!ownerAccountId) {
        try {
          ownerAccountId = await resolveEventOwnerAccountId(eventId, data);
        } catch (error) {
          await snap.ref.update({
            payoutStatus: 'failed',
            payoutError: 'Owner account resolution error: ' + error.message,
          });
          return;
        }
      }

      if (!ownerAccountId) {
        await snap.ref.update({
          payoutStatus: 'failed',
          payoutError: 'Missing Razorpay connected account ID',
        });
        return;
      }

      if (!paymentId) {
        await snap.ref.update({
          payoutStatus: 'failed',
          payoutError: 'Missing Razorpay payment ID',
        });
        return;
      }

      if (!ownerAccountId.startsWith('acc_')) {
        await snap.ref.update({
          payoutStatus: 'failed',
          payoutError: 'Owner does not have a valid Razorpay connected account ID.',
        });
        return;
      }

      // Calculate owner's share
      const ownerShare = calculateOwnerShare(data.baseAmount || totalAmount);
      const companyProfit = totalAmount - ownerShare;

      // Check for pending deductions
      let totalDeductions = 0;
      let ownerId = data.ownerId;

      if (ownerId) {
        try {
          const deductionsQuery = await db
            .collection('turf_owner_deductions')
            .where('ownerId', '==', ownerId)
            .where('status', '==', 'pending')
            .get();

          deductionsQuery.forEach((doc) => {
            totalDeductions += doc.data().amount || 0;
          });

          if (totalDeductions > 0) {
            console.log('Found pending deductions:', totalDeductions, 'for owner:', ownerId);
          }
        } catch (error) {
          console.error('Error checking deductions:', error);
        }
      }

      // Calculate final payout
      const finalPayout = Math.max(0, ownerShare - totalDeductions);
      const actualDeduction = ownerShare - finalPayout;

      console.log('Total amount:', totalAmount);
      console.log('Owner share:', ownerShare);
      console.log('Deductions:', totalDeductions);
      console.log('Final payout:', finalPayout);

      // Process payment
      const ownerPaymentMethod = await getOwnerPaymentMethod(ownerAccountId, eventId, data);
      const client = getRazorpayClient();

      if (ownerPaymentMethod.type === 'razorpay') {
        await processRazorpayTransfer(client, paymentId, finalPayout, ownerPaymentMethod.accountId);
      }

      // Mark deductions as applied
      if (totalDeductions > 0 && ownerId) {
        try {
          const deductionsQuery = await db
            .collection('turf_owner_deductions')
            .where('ownerId', '==', ownerId)
            .where('status', '==', 'pending')
            .get();

          const batch = db.batch();
          deductionsQuery.forEach((doc) => {
            batch.update(doc.ref, {
              status: 'applied',
              appliedAt: admin.firestore.FieldValue.serverTimestamp(),
              appliedToRegistration: context.params.registrationId,
            });
          });
          await batch.commit();
        } catch (error) {
          console.error('Error updating deduction status:', error);
        }
      }

      // Update registration
      await snap.ref.update({
        payoutStatus: 'settled',
        transferResponse: null,
        eventOwnerAccountId: ownerAccountId,
        payoutMethod: 'Razorpay Route',
      });

      // Save settlement info
      await db
        .collection('eventSettlements')
        .doc(context.params.registrationId)
        .set({
          registrationid: context.params.registrationId,
          eventid: eventId || null,
          totalpaid: totalAmount,
          ownershare: ownerShare,
          platformprofit: companyProfit,
          pendingdeductions: totalDeductions,
          finalpayout: finalPayout,
          actualdeduction: actualDeduction,
          razorpaypaymentid: paymentId,
          owneraccountid: ownerAccountId,
          settledat: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log('Successfully processed payout for event registration:', context.params.registrationId);
    } catch (error) {
      console.error('Function execution error:', error);
      try {
        await snap.ref.update({
          payoutStatus: 'failed',
          payoutError: 'Function error: ' + error.message,
        });
      } catch (updateError) {
        console.error('Failed to update payout status:', updateError);
      }
    }
  });

// ===================================================================
// CLEANUP EXPIRED EVENT LOCKS
// ===================================================================

exports.cleanupExpiredEventLocks = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  const expiredLocks = await db
    .collection('eventLocks')
    .where('expiresAt', '<', now)
    .get();

  const batch = db.batch();
  expiredLocks.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
  console.log('Cleaned up', expiredLocks.size, 'expired event locks');
});

// ===================================================================
// END OF FIXED CODE
// ===================================================================
