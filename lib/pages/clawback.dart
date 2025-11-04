import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

/// Overdue Clawbacks Management Page for Admin
/// Shows all clawbacks that haven't been settled from turf owners after 7+ days
class OverdueClawbacksPage extends StatefulWidget {
  const OverdueClawbacksPage({Key? key}) : super(key: key);

  @override
  OverdueClawbacksPageState createState() => OverdueClawbacksPageState();
}

class OverdueClawbacksPageState extends State<OverdueClawbacksPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  
  // State variables
  String clawbackSearchQuery = '';
  DateTime? clawbackFilterDate;
  bool isLoading = false;
  
  // Cache for owner and turf names to avoid repeated fetches
  Map<String, String> ownerNamesCache = {};
  Map<String, String> turfNamesCache = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal[600],
        title: Text(
          'Overdue Clawbacks',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Search and filter section
            Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: buildSearchBar(),
            ),
            // Content section
            Expanded(
              child: buildOverdueClawbacksList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build search and filter bar
  Widget buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search field
          TextField(
            onChanged: (value) {
              setState(() {
                clawbackSearchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by owner name, turf name, or booking ID...',
              prefixIcon: Icon(Icons.search, color: Colors.teal),
              suffixIcon: clawbackSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          clawbackSearchQuery = '';
                          clawbackFilterDate = null;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          SizedBox(height: 12),
          // Date picker
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: clawbackFilterDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  clawbackFilterDate = picked;
                });
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.teal, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      clawbackFilterDate != null
                          ? 'Filter: ${DateFormat('dd MMM yyyy').format(clawbackFilterDate!)}'
                          : 'Filter by creation date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (clawbackFilterDate != null)
                    InkWell(
                      onTap: () {
                        setState(() {
                          clawbackFilterDate = null;
                        });
                      },
                      child: Icon(Icons.clear, color: Colors.grey, size: 18),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build overdue clawbacks list with StreamBuilder for real-time updates
  Widget buildOverdueClawbacksList() {
    Query query = firestore
        .collection('manual_clawback_payments')
        .where('status', whereIn: ['pending_payment', 'overdue'])
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.teal),
                SizedBox(height: 20),
                Text(
                  'Loading Overdue Clawbacks...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.teal[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red),
                SizedBox(height: 20),
                Text(
                  'Error loading clawbacks',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Please try again later.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _filterClawbacksWithNames(snapshot.data!.docs),
          builder: (context, filteredSnapshot) {
            if (filteredSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: Colors.teal));
            }

            List<Map<String, dynamic>> clawbacks = filteredSnapshot.data ?? [];

            if (clawbacks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 80, color: Colors.green),
                    SizedBox(height: 20),
                    Text(
                      'No overdue clawbacks found! 🎉',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      clawbackSearchQuery.isNotEmpty || clawbackFilterDate != null
                          ? 'Try adjusting your search criteria.'
                          : 'All clawbacks have been settled.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8),
              itemCount: clawbacks.length,
              itemBuilder: (context, index) {
                final clawback = clawbacks[index];
                return buildOverdueClawbackCard(clawback);
              },
            );
          },
        );
      },
    );
  }

  /// Filter clawbacks based on search query (owner name, turf name, booking ID)
  Future<List<Map<String, dynamic>>> _filterClawbacksWithNames(
    List<QueryDocumentSnapshot> docs,
  ) async {
    List<Map<String, dynamic>> filteredClawbacks = [];

    for (var clawbackDoc in docs) {
      var clawbackData = clawbackDoc.data() as Map<String, dynamic>;
      clawbackData['id'] = clawbackDoc.id;

      // Fetch owner name if not cached
      String ownerId = clawbackData['ownerId'] ?? '';
      if (ownerId.isNotEmpty && !ownerNamesCache.containsKey(ownerId)) {
        try {
          DocumentSnapshot ownerDoc = await firestore.collection('users').doc(ownerId).get();
          if (ownerDoc.exists) {
            ownerNamesCache[ownerId] = (ownerDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown';
          } else {
            ownerNamesCache[ownerId] = 'Unknown';
          }
        } catch (e) {
          ownerNamesCache[ownerId] = 'Unknown';
        }
      }
      String ownerName = ownerNamesCache[ownerId] ?? 'Unknown';
      clawbackData['ownerName'] = ownerName;

      // Fetch turf name if not cached
      String turfId = clawbackData['turfId'] ?? '';
      if (turfId.isNotEmpty && !turfNamesCache.containsKey(turfId)) {
        try {
          DocumentSnapshot turfDoc = await firestore.collection('turfs').doc(turfId).get();
          if (turfDoc.exists) {
            turfNamesCache[turfId] = (turfDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown';
          } else {
            turfNamesCache[turfId] = 'Unknown';
          }
        } catch (e) {
          turfNamesCache[turfId] = 'Unknown';
        }
      }
      String turfName = turfNamesCache[turfId] ?? 'Unknown';
      clawbackData['turfName'] = turfName;

      // Filter based on search query (owner name, turf name, or booking ID)
      bool searchMatch = clawbackSearchQuery.isEmpty ||
          ownerName.toLowerCase().contains(clawbackSearchQuery.toLowerCase()) ||
          turfName.toLowerCase().contains(clawbackSearchQuery.toLowerCase()) ||
          (clawbackData['bookingId']?.toString().toLowerCase().contains(clawbackSearchQuery.toLowerCase()) ?? false);

      // Filter based on date if specified
      bool dateMatch = true;
      if (clawbackFilterDate != null) {
        DateTime? createdDate;
        if (clawbackData['createdAt'] != null) {
          createdDate = (clawbackData['createdAt'] as Timestamp).toDate();
        }
        if (createdDate != null) {
          dateMatch = createdDate.year == clawbackFilterDate!.year &&
              createdDate.month == clawbackFilterDate!.month &&
              createdDate.day == clawbackFilterDate!.day;
        } else {
          dateMatch = false;
        }
      }

      if (searchMatch && dateMatch) {
        filteredClawbacks.add(clawbackData);
      }
    }

    return filteredClawbacks;
  }

  /// Build individual overdue clawback card
  Widget buildOverdueClawbackCard(Map<String, dynamic> clawback) {
    String status = clawback['status'] ?? 'pending_payment';
    double amount = (clawback['amount'] ?? 0).toDouble();
    String ownerName = clawback['ownerName'] ?? 'Unknown Owner';
    String turfName = clawback['turfName'] ?? 'Unknown Turf';
    String bookingId = clawback['bookingId'] ?? 'Unknown';
    String paymentLink = clawback['paymentLink'] ?? '';
    
    DateTime? createdDate;
    DateTime? dueDate;
    if (clawback['createdAt'] != null) {
      createdDate = (clawback['createdAt'] as Timestamp).toDate();
    }
    if (clawback['dueDate'] != null) {
      dueDate = (clawback['dueDate'] as Timestamp).toDate();
    }

    bool isOverdue = dueDate != null && dueDate.isBefore(DateTime.now());
    int daysOverdue = createdDate != null 
        ? DateTime.now().difference(createdDate).inDays 
        : 0;

    Color statusColor = isOverdue ? Colors.red : Colors.orange;

    return GlassmorphismCard(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: () => showClawbackDetailsDialog(clawback),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Overdue for $daysOverdue days',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOverdue ? Icons.error : Icons.warning,
                          size: 16,
                          color: statusColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          isOverdue ? 'OVERDUE' : 'PENDING',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              Divider(height: 24, color: Colors.grey[300]),
              
              // Owner & Turf Info (now with names!)
              _buildInfoRow(Icons.person, 'Owner', ownerName),
              _buildInfoRow(Icons.stadium, 'Turf', turfName),
              _buildInfoRow(Icons.confirmation_number, 'Booking ID', bookingId),
              _buildInfoRow(Icons.calendar_today, 'Created', 
                  createdDate != null ? DateFormat('dd MMM yyyy').format(createdDate) : 'N/A'),
              
              if (dueDate != null)
                _buildInfoRow(Icons.alarm, 'Due Date', 
                    DateFormat('dd MMM yyyy').format(dueDate),
                    valueColor: isOverdue ? Colors.red[700] : Colors.orange[700]),
              
              if (paymentLink.isNotEmpty) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.link, size: 16, color: Colors.blue[700]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment Link Available',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              
              SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _sendClawbackReminder(clawback['id']),
                      icon: Icon(Icons.notification_important, size: 18, color: Colors.white),
                      label: Text('Send Reminder', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showMarkAsPaidDialog(clawback),
                      icon: Icon(Icons.check_circle, size: 18, color: Colors.white),
                      label: Text('Mark Paid', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Rest of the methods remain the same...
  // (Keep all other methods: _buildInfoRow, showClawbackDetailsDialog, etc. exactly as they were)
  
  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
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
                color: valueColor ?? Colors.grey[800],
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void showClawbackDetailsDialog(Map<String, dynamic> clawback) {
    String ownerName = clawback['ownerName'] ?? 'Unknown Owner';
    String turfName = clawback['turfName'] ?? 'Unknown Turf';
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.money_off, color: Colors.red, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Clawback Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.teal[900],
                        ),
                      ),
                    ),
                  ],
                ),
                
                Divider(height: 20, color: Colors.grey[300]),
                
                // Amount Section
                GlassmorphismCard(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          '₹${(clawback['amount'] ?? 0).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        Text(
                          'Pending Payment',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Owner Information
                GlassmorphismCard(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Owner Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildDetailRow('Name', ownerName),
                        _buildDetailRow('Owner ID', clawback['ownerId'] ?? 'Unknown'),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Booking & Turf Information
                GlassmorphismCard(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking & Turf Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildDetailRow('Turf Name', turfName),
                        _buildDetailRow('Turf ID', clawback['turfId'] ?? 'Unknown'),
                        _buildDetailRow('Booking ID', clawback['bookingId'] ?? 'Unknown'),
                        _buildDetailRow('Deduction ID', clawback['deductionId'] ?? 'Unknown'),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Payment Link
                if (clawback['paymentLink'] != null && clawback['paymentLink'].toString().isNotEmpty)
                  GlassmorphismCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Link',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          SelectableText(
                            clawback['paymentLink'],
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: Icon(Icons.copy, size: 18),
                            label: Text('Copy Link'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: clawback['paymentLink']));
                              Fluttertoast.showToast(msg: 'Payment link copied!');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                
                SizedBox(height: 16),
                
                // Dates
                GlassmorphismCard(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Timeline',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildDetailRow('Created At', _formatTimestamp(clawback['createdAt'])),
                        _buildDetailRow('Due Date', _formatTimestamp(clawback['dueDate'])),
                        if (clawback['lastReminderAt'] != null)
                          _buildDetailRow('Last Reminder', _formatTimestamp(clawback['lastReminderAt'])),
                        _buildDetailRow('Reminders Sent', (clawback['remindersSent'] ?? 0).toString()),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Notes
                if (clawback['notes'] != null && clawback['notes'].toString().isNotEmpty)
                  GlassmorphismCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            clawback['notes'],
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _sendClawbackReminder(clawback['id']);
                        },
                        icon: Icon(Icons.send, color: Colors.white),
                        label: Text('Send Reminder', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showMarkAsPaidDialog(clawback);
                        },
                        icon: Icon(Icons.check_circle, color: Colors.white),
                        label: Text('Mark as Paid', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 12),
                
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'N/A';
    }
    return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
  }

  Future<void> _sendClawbackReminder(String deductionId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Sending reminder...'),
              ],
            ),
          );
        },
      );

      final HttpsCallable sendReminder =
          FirebaseFunctions.instance.httpsCallable('sendClawbackReminder');
      final result = await sendReminder.call({'deductionId': deductionId});

      Navigator.of(context).pop();

      if (result.data['success'] == true) {
        Fluttertoast.showToast(
          msg: 'Reminder sent successfully!',
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        throw Exception('Failed to send reminder');
      }
    } on FirebaseFunctionsException catch (e) {
      Navigator.of(context).pop();
      Fluttertoast.showToast(
        msg: 'Error: ${e.message}',
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      Navigator.of(context).pop();
      Fluttertoast.showToast(
        msg: 'Error sending reminder: $e',
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _showMarkAsPaidDialog(Map<String, dynamic> clawback) {
    final TextEditingController notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Manual Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Amount: ₹${(clawback['amount'] ?? 0).toStringAsFixed(2)}'),
            SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Payment confirmation notes',
                hintText: 'e.g., Received via bank transfer on [date]',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: Text('Confirm Paid'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              try {
                await firestore
                    .collection('manual_clawback_payments')
                    .doc(clawback['id'])
                    .update({
                  'status': 'paid',
                  'paidAt': FieldValue.serverTimestamp(),
                  'paymentMethod': 'manual_confirmation',
                  'adminNotes': notesController.text,
                  'confirmedBy': auth.currentUser?.uid,
                });
                
                await firestore
                    .collection('turfownerdeductions')
                    .doc(clawback['deductionId'])
                    .update({
                  'status': 'settled_manual',
                  'settledAt': FieldValue.serverTimestamp(),
                });
                
                Navigator.pop(ctx);
                Fluttertoast.showToast(
                  msg: 'Payment marked as received successfully!',
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                );
              } catch (e) {
                Navigator.pop(ctx);
                Fluttertoast.showToast(
                  msg: 'Error: $e',
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Glassmorphism Card Widget (matching your theme)
class GlassmorphismCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? color;

  const GlassmorphismCard({
    Key? key,
    required this.child,
    this.margin,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.6),
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}
