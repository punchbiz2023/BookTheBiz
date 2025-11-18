import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class PendingClawbackDetailsPage extends StatefulWidget {
  final List<Map<String, dynamic>> pendingClawbacks;
  final double totalAmount;

  const PendingClawbackDetailsPage({
    Key? key,
    required this.pendingClawbacks,
    required this.totalAmount,
  }) : super(key: key);

  @override
  State<PendingClawbackDetailsPage> createState() => _PendingClawbackDetailsPageState();
}

class _PendingClawbackDetailsPageState extends State<PendingClawbackDetailsPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red[700],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment Required',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Warning Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[700]!, Colors.red[500]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Immediate Action Required',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your account requires settlement to continue operations',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Total Amount Card
            Padding(
              padding: EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.red[300]!, width: 2),
                ),
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Total Outstanding Amount',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '₹${widget.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${widget.pendingClawbacks.length} Pending Transaction(s)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // What Happened Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 What Happened?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildExplanationCard(
                    icon: Icons.event_busy,
                    iconColor: Colors.orange,
                    title: 'Customer Cancelled Booking/Event',
                    description:
                        'One or more customers cancelled their bookings or event registrations after payment was already processed and transferred to you.',
                  ),
                  SizedBox(height: 12),
                  _buildExplanationCard(
                    icon: Icons.account_balance_wallet,
                    iconColor: Colors.blue,
                    title: 'BookTheBiz Issued Refund',
                    description:
                        'To maintain customer trust and as per our policy, BookTheBiz immediately refunded the full amount to the customers from our account.',
                  ),
                  SizedBox(height: 12),
                  _buildExplanationCard(
                    icon: Icons.timer_off,
                    iconColor: Colors.red,
                    title: 'No Future Bookings to Deduct',
                    description:
                        'We waited 7+ days for new bookings to automatically deduct the refund amount, but you didn\'t receive any new bookings during this period.',
                  ),
                  SizedBox(height: 12),
                  _buildExplanationCard(
                    icon: Icons.payments,
                    iconColor: Colors.teal,
                    title: 'Manual Settlement Required',
                    description:
                        'Since automatic deduction wasn\'t possible, you need to manually pay this amount to continue using BookTheBiz services.',
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Detailed Breakdown
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📊 Detailed Breakdown',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  ...widget.pendingClawbacks.map((clawback) {
                    return _buildClawbackDetailCard(clawback);
                  }).toList(),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Consequences Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!, width: 2),
                ),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '⚠️ Failure to Pay',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildConsequenceItem('Your account will be temporarily suspended'),
                    _buildConsequenceItem('New bookings will not be accepted'),
                    _buildConsequenceItem('Existing turfs will be hidden from users'),
                    _buildConsequenceItem('Account may be permanently terminated after 15 days'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Payment Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _initiatePayment(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        padding: EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Pay Now - ₹${widget.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _contactSupport(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.teal, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.support_agent, color: Colors.teal, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Contact Support',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClawbackDetailCard(Map<String, dynamic> clawback) {
    double amount = (clawback['amount'] ?? 0).toDouble();
    
    // Determine if this is an event or turf clawback
    // Handle notes as either String or Map - be defensive
    bool notesIsEvent = false;
    try {
      dynamic notesValue = clawback['notes'];
      if (notesValue != null) {
        if (notesValue is Map<String, dynamic>) {
          notesIsEvent = notesValue['type'] == 'event';
        }
        // If notesValue is String, it doesn't contain type info, so notesIsEvent stays false
      }
    } catch (e) {
      // If any error occurs accessing notes, just ignore it
      print('Error checking notes for event type: $e');
    }
    
    final isEventClawback = clawback['eventId'] != null || 
                            clawback['registrationId'] != null || 
                            (clawback['type'] == 'event') ||
                            notesIsEvent;
    
    String bookingId = clawback['bookingId'] ?? 'N/A';
    String registrationId = clawback['registrationId'] ?? 'N/A';
    String referenceId = isEventClawback ? registrationId : bookingId;
    DateTime? createdDate;
    if (clawback['createdAt'] != null) {
      createdDate = (clawback['createdAt'] as Timestamp).toDate();
    }
    
    // Fetch event name if event clawback
    String? eventName;
    if (isEventClawback && clawback['eventId'] != null) {
      // We'll fetch this asynchronously or pass it from parent
      // For now, show event ID
      eventName = null; // Will be fetched if needed
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Text(
                  'PENDING',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Show event info for event clawbacks, booking info for turf clawbacks
          if (isEventClawback) ...[
            if (registrationId != 'N/A')
              _buildDetailRow('Registration ID', registrationId),
            if (clawback['eventId'] != null)
              FutureBuilder<DocumentSnapshot>(
                future: firestore.collection('spot_events').doc(clawback['eventId']).get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildDetailRow('Event', 'Loading...');
                  }
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final eventName = (snapshot.data!.data() as Map<String, dynamic>)?['name'] ?? 'Unknown Event';
                    return _buildDetailRow('Event', eventName);
                  }
                  return _buildDetailRow('Event ID', clawback['eventId'] ?? 'N/A');
                },
              ),
          ] else ...[
            if (bookingId != 'N/A')
              _buildDetailRow('Booking ID', bookingId),
          ],
          if (createdDate != null)
            _buildDetailRow(
              'Refund Date',
              DateFormat('dd MMM yyyy, hh:mm a').format(createdDate),
            ),
          SizedBox(height: 8),
          Text(
            clawback['reason'] ?? (isEventClawback 
              ? 'Customer cancelled event registration after payment was transferred to your account.'
              : 'Customer cancelled booking after payment was transferred to your account.'),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsequenceItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right, color: Colors.red[700], size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _initiatePayment() async {
    // Get the first payment link available
    String? paymentLink;
    for (var clawback in widget.pendingClawbacks) {
      if (clawback['paymentLink'] != null && clawback['paymentLink'].toString().isNotEmpty) {
        paymentLink = clawback['paymentLink'];
        break;
      }
    }

    if (paymentLink != null && paymentLink.isNotEmpty) {
      // Open payment link
      try {
        final Uri url = Uri.parse(paymentLink);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          Fluttertoast.showToast(
            msg: 'Unable to open payment link',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Error opening payment link: $e',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } else {
      // Show contact support dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Payment Link Not Available'),
          content: Text(
            'Payment link is being generated. Please contact support to complete the payment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _contactSupport();
              },
              child: Text('Contact Support'),
            ),
          ],
        ),
      );
    }
  }

  void _contactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.support_agent, color: Colors.teal, size: 28),
            SizedBox(width: 12),
            Text('Contact Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get help with your payment:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildContactItem(Icons.email, 'Email', 'ownersbtb@gmail.com'),
            SizedBox(height: 12),
            _buildContactItem(Icons.phone, 'Phone', '+91-8248708300'),
            SizedBox(height: 12),
            _buildContactItem(Icons.access_time, 'Hours', 'Mon-Sat: 9 AM - 6 PM'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
