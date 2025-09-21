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
      const db = admin.firestore();

      // Ensure there is exactly one mirrored record in top-level bookings with same id
      try {
        const mainDocRef = db.collection('bookings').doc(context.params.bookingId);
        const mainDoc = await mainDocRef.get();
        if (!mainDoc.exists) {
          await mainDocRef.set({
            ...data,
            turfBookingId: context.params.bookingId,
            turfId: context.params.turfId || data.turfId || null,
          }, { merge: true });
        }
      } catch (mirrorErr) {
        console.error('Failed to mirror booking to main collection:', mirrorErr);
      }
      
      // Only process online confirmed payments with pending payout
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
    
    const transferResp = await client.payments.transfer(paymentId, {
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
    const { totalAmount, payableAmount, ownerAccountId, bookingId, turfId, currency = 'INR' } = data;
    if (!totalAmount || !payableAmount || !ownerAccountId || !bookingId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    if (!ownerAccountId.startsWith('acc_')) {
      throw new functions.https.HttpsError('failed-precondition', 'Owner Razorpay Account ID is invalid');
    }
    const client = getRazorpayClient();
    
    // totalAmount = base turf amount (what owner should get)
    // payableAmount = total amount customer pays (including platform profit + fees)
    const ownerShare = calculateOwnerShare(totalAmount); // This should be the base turf amount
    const platformProfit = payableAmount - totalAmount; // Additional amount platform keeps
    
    const order = await client.orders.create({
      amount: Math.round(payableAmount * 100), // Customer pays the full amount
      currency,
      transfers: [
        {
          account: ownerAccountId,
          amount: Math.round(ownerShare * 100), // Owner gets the base turf amount
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
        platform_profit: platformProfit.toString(),
        base_turf_amount: totalAmount.toString()
      }
    });
    // Save profit/owner share info in Firestore for tracking
    const db = admin.firestore();
    await db.collection('razorpay_orders').doc(order.id).set({
      booking_id: bookingId,
      turf_id: turfId || null,
      total_paid: payableAmount, // What customer paid
      base_turf_amount: totalAmount, // What owner should get
      owner_share: ownerShare,
      platform_profit: platformProfit,
      razorpay_order_id: order.id,
      owner_account_id: ownerAccountId,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
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
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// --- Support Ticket Email Acknowledgement Endpoint ---
const express = require('express');
const bodyParser = require('body-parser');
const nodemailer = require('nodemailer');

const supportApp = express();
supportApp.use(bodyParser.json());

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

supportApp.post('/sendSupportAck', async (req, res) => {
  const { ticketId, message } = req.body;
  if (!ticketId) {
    res.status(400).send('Missing ticketId');
    return;
  }
  try {
    // 1. Fetch the support ticket
    const ticketDoc = await admin.firestore().collection('support_tickets').doc(ticketId).get();
    if (!ticketDoc.exists) {
      res.status(404).send('Support ticket not found');
      return;
    }
    const ticket = ticketDoc.data();
    const userId = ticket.userId;
    const subject = ticket.subject || '';
    const userEmail = ticket.userEmail || '';
    // 2. Fetch the user
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      res.status(404).send('User not found');
      return;
    }
    const user = userDoc.data();
    const userName = user.name || 'User';
    const userType = user.userType || 'User';
    // 3. Choose transporter
    const transporter = userType === 'User' ? TRANSPORTS.User : TRANSPORTS.Other;
    const fromEmail = userType === 'User'
      ? 'BookTheBiz Support <customersbtb@gmail.com>'
      : 'BookTheBiz Support <bookthebiza@gmail.com>';
    // 4. Compose email
    let emailText = `Dear ${userName},\n\n`;
    if (message && message.trim() !== '') {
      emailText += `Admin Response: ${message.trim()}\n\n`;
    } else {
      emailText += `We have received your support ticket (Subject: ${subject}). Our team will respond within 3 business days to your registered email/phone number.\n\n`;
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

// Export the express app as a Cloud Function
exports.supportApi = functions.https.onRequest(supportApp);

// --- Booking Confirmation Email (Callable) ---
exports.sendBookingConfirmationEmail = functions.https.onCall(async (data, context) => {
  try {
    const {
      to,
      userName = 'Customer',
      bookingId = '',
      turfName = '',
      ground = '',
      bookingDate = '',
      slots = [],
      totalHours = 0,
      amount = 0,
      paymentMethod = 'Online'
    } = data || {};

    if (!to || typeof to !== 'string' || !to.includes('@')) {
      throw new functions.https.HttpsError('invalid-argument', 'Valid recipient email (to) is required');
    }

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: 'customersbtb@gmail.com',
        pass: 'fofb axss moce zspb'
      }
    });

    const path = require('path');
    const appLogoPath = path.resolve(__dirname, 'assets', 'app.png');
    const companyLogoPath = path.resolve(__dirname, 'assets', 'logo.png');

    const prettyDate = bookingDate || new Date().toISOString().slice(0, 10);
    const slotList = Array.isArray(slots) ? slots.join(', ') : '';
    const subject = `Booking Confirmed • ${turfName} • ${prettyDate}`;

    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Booking Confirmation</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
</head>
<body style="margin:0; padding:0; background-color:#f5f5f5; font-family: Arial, sans-serif; color:#333333;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color:#f5f5f5; width:100%;">
<tr>
  <td align="center" style="padding: 20px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:600px; background-color:#ffffff; border-radius:8px; overflow:hidden; box-shadow:0 0 10px rgba(0,0,0,0.1);">
      <!-- Header -->
      <tr>
        <td style="background-color:#0f766e; padding:20px;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
            <tr>
              <td align="left" style="width:50%;">
                <img src="cid:companyLogo" alt="Company Logo" width="120" style="display:block; max-width:120px; height:auto;">
              </td>
              <td align="right" style="width:50%;">
                <img src="cid:appLogo" alt="App Logo" width="50" style="display:block; max-width:50px; height:auto;">
              </td>
            </tr>
            <tr>
              <td colspan="2" align="center" style="padding:20px 0 10px 0;">
                <h1 style="color:#ffffff; font-size:22px; line-height:28px; font-weight:bold; margin:0;">Your Booking is Confirmed</h1>
              </td>
            </tr>
          </table>
        </td>
      </tr>
      <!-- Greeting -->
      <tr>
        <td style="padding:20px;">
          <p style="margin:0; font-size:16px; line-height:24px;">Hi <strong>${userName}</strong>, thanks for booking with us. Here are your booking details:</p>
        </td>
      </tr>
      <!-- Booking Details -->
      <tr>
        <td style="padding:0 20px 20px 20px;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%; border-collapse: collapse; font-size:14px;">
            <tr>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Booking ID:</strong></td>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;">${bookingId}</td>
            </tr>
            <tr>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Turf:</strong></td>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;">${turfName}</td>
            </tr>
            <tr>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Ground:</strong></td>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;">${ground}</td>
            </tr>
            <tr>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Date:</strong></td>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;">${prettyDate}</td>
            </tr>
            <tr>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Time Slot(s):</strong></td>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;">${slotList}</td>
            </tr>
            <tr>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Total Hours:</strong></td>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;">${Number(totalHours || 0).toFixed(0)}</td>
            </tr>
            <tr>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Amount Paid:</strong></td>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><span style="color:#0f766e; font-weight:bold;">₹${Number(amount || 0).toFixed(2)}</span></td>
            </tr>
            <tr>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;"><strong>Payment Method:</strong></td>
              <td style="padding:10px 0; border-bottom:1px solid #e0e0e0;">${paymentMethod}</td>
            </tr>
          </table>
        </td>
      </tr>
      <!-- Footer -->
      <tr>
        <td style="background-color:#f9fafb; padding:15px 20px; text-align:center; font-size:12px; color:#6b7280;">
          If you have questions, reply to this email or contact support.<br>
          © ${new Date().getFullYear()} BookTheBiz • All rights reserved
        </td>
      </tr>
    </table>
  </td>
</tr>
</table>
</body>
</html>`;

    const mailOptions = {
      from: 'BookTheBiz <customersbtb@gmail.com>',
      to,
      subject,
      html,
      attachments: [
        { filename: 'app.png', path: appLogoPath, cid: 'appLogo' },
        { filename: 'logo.png', path: companyLogoPath, cid: 'companyLogo' }
      ]
    };

    const info = await transporter.sendMail(mailOptions);
    return { ok: true, id: info.messageId };
  } catch (error) {
    console.error('sendBookingConfirmationEmail error:', error);
    throw new functions.https.HttpsError('internal', error.message || 'Failed to send email');
  }
});


// --- FCM Notification Functions ---
async function sendNotificationToAdmin(title, body, data = {}) {
  try {
    // Get admin user document to find their FCM token
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
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      token: fcmToken,
      android: {
        notification: {
          channel_id: 'verification_channel',
          priority: 'high',
          default_sound: true,
          default_vibrate_timings: true,
          icon: 'app', // Added app icon for all notifications
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

// Function to send notification to turf owner
async function sendNotificationToTurfOwner(ownerId, title, body, data = {}) {
  try {
    // Get turf owner document to find their FCM token
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
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      token: fcmToken,
      android: {
        notification: {
          channel_id: 'turf_status_channel',
          priority: 'high',
          default_sound: true,
          default_vibrate_timings: true,
          icon: 'app', // Added app icon for all notifications
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

// Function to handle turf approval
exports.onTurfApproved = functions.firestore
  .document('turfs/{turfId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      
      // Check if status changed from 'Not Verified' to 'Verified'
      if (beforeData.turf_status === 'Not Verified' && afterData.turf_status === 'Verified') {
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
              timestamp: new Date().toISOString(),
            }
          );
          console.log('Turf approval notification sent to owner:', ownerId);
        }
      }
    } catch (error) {
      console.error('Error in onTurfApproved:', error);
    }
  });

// Function to handle turf rejection
exports.onTurfRejected = functions.firestore
  .document('turfs/{turfId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      
      // Check if status changed from 'Not Verified' to 'Disapproved'
      if (beforeData.turf_status === 'Not Verified' && afterData.turf_status === 'Disapproved') {
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
              timestamp: new Date().toISOString(),
            }
          );
          console.log('Turf rejection notification sent to owner:', ownerId);
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
      let ownerName = turfData.name || 'A Turf Owner';

      // Optionally fetch more owner details if needed
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
          timestamp: new Date().toISOString(),
        }
      );
      console.log('Admin notified for new turf:', context.params.turfId);
    } catch (error) {
      console.error('Error notifying admin for new turf:', error);
    }
  });
// Function to send notification when user submits verification details
exports.onUserVerificationSubmitted = functions.firestore
  .document('documents/{userId}')
  .onCreate(async (snap, context) => {
    try {
      const documentData = snap.data();
      const userId = context.params.userId;

      // Get user details
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) {
        console.log('User document not found');
        return;
      }

      const userData = userDoc.data();
      const userName = userData.name || 'Unknown User';
      const userEmail = userData.email || 'No email';

      // Send notification to admin
      await sendNotificationToAdmin(
        'New User Verification Submitted',
        `User ${userName} has submitted verification details for review`,
        {
          type: 'verification_submitted',
          userId: userId,
          userName: userName,
          userEmail: userEmail,
          timestamp: new Date().toISOString(),
        }
      );

      console.log('Verification notification sent for user:', userId);
    } catch (error) {
      console.error('Error in onUserVerificationSubmitted:', error);
    }
  });

// Function to handle refund request creation
exports.createRefundRequest = functions.https.onCall(async (data, context) => {
  try {
    const {
      bookingId,
      userId,
      turfId,
      amount,
      paymentId,
      reason = 'User requested cancellation',
      bookingDate,
      turfName,
      ground,
      slots
    } = data;

    if (!bookingId || !userId || !amount || !paymentId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }

    const db = admin.firestore();
    
    // Get base amount from booking data
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    const bookingData = bookingDoc.exists ? bookingDoc.data() : {};
    const baseAmount = bookingData.baseAmount || (parseFloat(amount) * 0.85); // Estimate if not stored
    
    // Create refund request document
    const refundRequest = {
      bookingId,
      userId,
      turfId,
      amount: parseFloat(amount),
      baseAmount: baseAmount,
      paymentId,
      reason,
      status: 'pending', // pending, approved, rejected, processed
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
    
    // Get user details for notification
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.exists ? userDoc.data() : {};
    const userName = userData.name || 'User';

    // Send notification to admin
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
        timestamp: new Date().toISOString(),
      }
    );

    // Update booking status to 'cancelled'
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

// Function to process refund (admin approval)
// Function to process refund (admin approval)
exports.processRefund = functions.https.onCall(async (data, context) => {
  try {
    const { refundRequestId, action, adminNotes = '' } = data; // action: 'approve' or 'reject'
    
    if (!refundRequestId || !action) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }

    const db = admin.firestore();
    const refundDoc = await db.collection('refund_requests').doc(refundRequestId).get();
    
    if (!refundDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Refund request not found');
    }

    const refundData = refundDoc.data();
    
    if (refundData.status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 'Refund request already processed');
    }

    if (action === 'reject') {
      // Simply update status to rejected
      await refundDoc.ref.update({
        status: 'rejected',
        adminNotes,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Notify user about rejection
      await sendNotificationToUser(refundData.userId, 
        'Refund Request Rejected',
        `Your refund request has been rejected. ${adminNotes || 'Please contact support for more details.'}`,
        {
          type: 'refund_rejected',
          refundRequestId,
          bookingId: refundData.bookingId
        }
      );

      return { success: true, message: 'Refund request rejected' };
    }

    if (action === 'approve') {
      // Process refund with Razorpay
      const client = getRazorpayClient();
      const totalAmount = refundData.amount;
      const paymentId = refundData.paymentId;
      
      try {
        // Calculate amounts
        const baseTurfAmount = refundData.baseAmount || (totalAmount * 0.85); // Estimate if not stored
        const platformAmount = totalAmount - baseTurfAmount;
        
        console.log(`Refund breakdown: Total=${totalAmount}, Base=${baseTurfAmount}, Platform=${platformAmount}`);
        
        // Process refund to user directly - Razorpay will handle the settlement with the turf owner
        const refundAmount = Math.round(totalAmount * 100); // Full amount in paise
        const refund = await client.payments.refund(paymentId, {
          amount: refundAmount,
          notes: {
            reason: refundData.reason,
            booking_id: refundData.bookingId,
            refund_request_id: refundRequestId,
            admin_notes: adminNotes
          }
        });

        // Update refund request with details
        await refundDoc.ref.update({
          status: 'processed',
          refundId: refund.id,
          razorpayRefundId: refund.id,
          refundStatus: refund.status,
          adminNotes,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          refundBreakdown: {
            totalAmount: totalAmount,
            baseTurfAmount: baseTurfAmount,
            platformAmount: platformAmount
          }
        });

        // Update booking status
        await db.collection('bookings').doc(refundData.bookingId).update({
          refundStatus: 'processed',
          refundId: refund.id,
          refundedAt: admin.firestore.FieldValue.serverTimestamp(),
          refundBreakdown: {
            totalAmount: totalAmount,
            baseTurfAmount: baseTurfAmount,
            platformAmount: platformAmount
          }
        });

        // Notify user about successful refund
        await sendNotificationToUser(refundData.userId,
          'Refund Processed Successfully',
          `Your refund of ₹${totalAmount} has been processed and will reflect in your account within 5-7 business days.`,
          {
            type: 'refund_processed',
            refundRequestId,
            bookingId: refundData.bookingId,
            amount: totalAmount,
            refundId: refund.id
          }
        );

        return { 
          success: true, 
          refundId: refund.id,
          message: 'Refund processed successfully',
          refundBreakdown: {
            totalAmount: totalAmount,
            baseTurfAmount: baseTurfAmount,
            platformAmount: platformAmount
          }
        };

      } catch (razorpayError) {
        console.error('Razorpay refund failed:', razorpayError);
        
        // Update status to failed
        await refundDoc.ref.update({
          status: 'failed',
          adminNotes: `Razorpay refund failed: ${razorpayError.message || razorpayError.toString()}`,
          processedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        throw new functions.https.HttpsError('internal', `Refund processing failed: ${razorpayError.message || razorpayError.toString()}`);
      }
    }

  } catch (error) {
    console.error('Error processing refund:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error; // Preserve original error code like failed-precondition
    }
    throw new functions.https.HttpsError('internal', error.message || error.toString() || 'Unknown error occurred');
  }
});

// Verify payment with Razorpay and create booking atomically in Firestore
exports.confirmBookingAndWrite = functions.https.onCall(async (data, context) => {
  try {
    const {
      orderId,
      paymentId,
      userId,
      turfId,
      turfName = '',
      ownerId = '',
      bookingDate, // 'yyyy-MM-dd'
      selectedGround,
      slots = [],
      totalHours = 0,
      baseAmount, // amount for turf (owner share)
      payableAmount // user paid amount (incl. profit + fees)
    } = data || {};

    if (!paymentId || !orderId || !userId || !turfId || !bookingDate || !selectedGround || !Array.isArray(slots) || slots.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required booking parameters');
    }
    if (!baseAmount || !payableAmount) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing amount information');
    }

    const client = getRazorpayClient();
    const payment = await client.payments.fetch(paymentId);

    if (!payment || payment.status !== 'captured') {
      throw new functions.https.HttpsError('failed-precondition', 'Payment not captured');
    }
    if (payment.order_id !== orderId) {
      throw new functions.https.HttpsError('failed-precondition', 'Payment does not match order');
    }
    // Optional: amount check with tolerance of 1 INR
    const paidAmountInr = Number(payment.amount) / 100.0;
    if (Math.abs(paidAmountInr - Number(payableAmount)) > 1) {
      throw new functions.https.HttpsError('failed-precondition', 'Paid amount mismatch');
    }

    const db = admin.firestore();

    const result = await db.runTransaction(async (tx) => {
      const bookingsCol = db.collection('turfs').doc(turfId).collection('bookings');
      const q = await tx.get(
        bookingsCol
          .where('selectedGround', '==', selectedGround)
          .where('bookingDate', '==', bookingDate)
      );

      let allBooked = [];
      q.forEach((doc) => {
        const s = doc.data().bookingSlots || [];
        allBooked = allBooked.concat(s);
      });

      const hasConflict = slots.some((slot) => allBooked.includes(slot));
      if (hasConflict) {
        throw new functions.https.HttpsError('aborted', 'Selected slot(s) already booked');
      }

      const now = admin.firestore.FieldValue.serverTimestamp();
      const bookingData = {
        userId,
        userName: data.userName || 'User',
        bookingDate,
        bookingSlots: slots,
        totalHours: Number(totalHours) || slots.length,
        amount: Number(payableAmount),
        baseAmount: Number(baseAmount),
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

      // Do not write to top-level bookings here; onBookingCreated trigger mirrors it with same id
      return { turfBookingId: turfBookingRef.id, bookingId: turfBookingRef.id };
    });

    return { ok: true, status: 'confirmed', ...result };
  } catch (error) {
    console.error('confirmBookingAndWrite error:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message || 'Failed to confirm booking');
  }
});

// Function to send notification to user
async function sendNotificationToUser(userId, title, body, data = {}) {
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
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      token: fcmToken,
      android: {
        notification: {
          channel_id: 'refund_channel',
          priority: 'high',
          default_sound: true,
          default_vibrate_timings: true,
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