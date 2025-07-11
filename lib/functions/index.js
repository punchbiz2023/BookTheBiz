const functions = require('firebase-functions');
const nodemailer = require('nodemailer');

// Configure your email and app password
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'bookthebiza@gmail.com',
    pass: 'bogq cosg kibq ulqs'
  }
});

exports.sendSupportAck = functions.https.onRequest(async (req, res) => {
  // Allow CORS for local testing and Flutter web
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  const { email, subject } = req.body;

  if (!email || !subject) {
    res.status(400).send('Missing email or subject');
    return;
  }

  const mailOptions = {
    from: 'BookTheBiz Support <bookthebiza@gmail.com>',
    to: email,
    subject: 'Support Ticket Received',
    text: `Dear user,\n\nWe have received your support ticket (Subject: ${subject}). Our team will respond within 3 business days to your registered email/phone number.\n\nThank you for contacting us!\n\n- BookTheBiz Support`
  };

  try {
    await transporter.sendMail(mailOptions);
    res.status(200).send('Email sent!');
  } catch (error) {
    console.error('Error sending email:', error);
    res.status(500).send('Failed to send email');
  }
});