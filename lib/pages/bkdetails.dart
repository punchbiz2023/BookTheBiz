import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingDetailsPage1 extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const BookingDetailsPage1({super.key, required this.bookingData});

  @override
  _BookingDetailsPage1State createState() => _BookingDetailsPage1State();
}

class _BookingDetailsPage1State extends State<BookingDetailsPage1> {
  // Moved helper methods into the State class so they can access context and setState
  bool _isCancelling = false;

  // Cancel all remaining slots at once
  Future<void> _cancelAllSlots(String bookID) async {
    try {
      final bookingRef = FirebaseFirestore.instance.collection('bookings');
      final querySnapshot = await bookingRef.get();

      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          if (doc.id == bookID) {
            var bookingData = doc.data() as Map<String, dynamic>;
            final List<String> bookingSlots = List<String>.from(bookingData['bookingSlots'] ?? []);

            // Check if there are any slots to cancel
            if (bookingSlots.isEmpty) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No slots to cancel'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            // Check if this is a paid booking that needs refund
            bool isPaidBooking = bookingData['paymentMethod'] == 'Online' &&
                bookingData['status'] == 'confirmed' &&
                bookingData['razorpayPaymentId'] != null;

            if (isPaidBooking) {
              // Create refund request for paid booking
              final created = await _createRefundRequest(bookingData, bookID);
              if (created) {
                await _removeAllBookingSlots(doc, bookingSlots);
              }
            } else {
              // For non-paid bookings, just remove all slots
              await _removeAllBookingSlots(doc, bookingSlots);
            }
            break;
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      print('Error cancelling booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _createRefundRequest(Map<String, dynamic> bookingData, String bookingId) async {
    try {
      if (!mounted) return false;
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Processing refund request...'),
              ],
            ),
          );
        },
      );

      // Call Cloud Function to create refund request
      final HttpsCallable createRefundRequest = FirebaseFunctions.instance.httpsCallable('createRefundRequest');

      final result = await createRefundRequest({
        'bookingId': bookingId,
        'userId': bookingData['userId'],
        'turfId': bookingData['turfId'],
        'amount': bookingData['amount'],
        'paymentId': bookingData['razorpayPaymentId'],
        'reason': 'User requested slot cancellation',
        'bookingDate': bookingData['bookingDate'],
        'turfName': bookingData['turfName'],
        'ground': bookingData['selectedGround'],
        'slots': bookingData['bookingSlots'],
      });

      if (!mounted) return false;
      // Close loading dialog
      Navigator.of(context).pop();

      if (result.data['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Refund request submitted! Amount will be refunded within 3-5 business days. Need help? Reach support anytime.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 6),
          ),
        );

        // Refresh the page to show updated status
        if (mounted) {
          setState(() {});
        }
        return true;
      } else {
        throw Exception('Failed to create refund request');
      }
    } catch (e) {
      if (!mounted) return false;
      // Close loading dialog if still open
      Navigator.of(context).maybePop();

      print('Error creating refund request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating refund request: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  // Remove all booking slots at once
  Future<void> _removeAllBookingSlots(QueryDocumentSnapshot doc, List<String> slotsToRemove) async {
    try {
      if (slotsToRemove.isEmpty) {
        return;
      }

      print('Removing all slots: $slotsToRemove');

      // Move all slots from bookingSlots to bookingStatus
      await doc.reference.update({
        'bookingSlots': [], // Clear all slots
        'bookingStatus': FieldValue.arrayUnion(slotsToRemove) // Move all to cancelled status
      });
      print('Updated bookingSlots and bookingStatus in main collection.');

      // Update the bookings sub-collection in the corresponding turf document
      String turfId = doc['turfId'];
      final turfRef = FirebaseFirestore.instance.collection('turfs').doc(turfId);
      final bookingsSubCollectionRef = turfRef.collection('bookings');
      final turfBookingDocs = await bookingsSubCollectionRef.get();

      // Find matching booking in turf subcollection
      for (var subDoc in turfBookingDocs.docs) {
        var bookingData = subDoc.data();
        if (bookingData['selectedGround'] == doc['selectedGround'] &&
            bookingData['bookingDate'] == doc['bookingDate'] &&
            bookingData['userId'] == doc['userId']) {
          
          // Get current slots from turf booking
          List<dynamic> turfBookingSlots = List.from(bookingData['bookingSlots'] ?? []);
          
          // Remove all slots that match the ones being cancelled
          List<String> slotsToMoveToStatus = [];
          for (var slot in slotsToRemove) {
            // Find matching slot in turf booking
            int index = turfBookingSlots.indexWhere((s) => s.toString().trim() == slot.trim());
            if (index != -1) {
              slotsToMoveToStatus.add(turfBookingSlots[index].toString());
              turfBookingSlots.removeAt(index);
            }
          }

          // Update the sub-collection document
          if (slotsToMoveToStatus.isNotEmpty) {
            await bookingsSubCollectionRef.doc(subDoc.id).update({
              'bookingSlots': turfBookingSlots,
              'bookingStatus': FieldValue.arrayUnion(slotsToMoveToStatus)
            });
            print('Updated turf bookingSlots and bookingStatus.');
          }
          break;
        }
      }

      if (!mounted) return;
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All slots cancelled successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the page
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      print('Error removing booking slots: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling slots: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Details', style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 4,
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTurfImage(),
                SizedBox(height: 16),
                _buildDetailRow('Turf Name', widget.bookingData['turfName'] ?? 'Unknown Turf'),
                _buildDetailRow('Date', widget.bookingData['bookingDate'] ?? 'N/A'),
                _buildDetailRow('Amount', '₹${_formatAmount(widget.bookingData['amount'])}'),
                _buildDetailRow('Total Hours', '${widget.bookingData['totalHours'] ?? 0}'),
                _buildDetailRow('Selected Ground', widget.bookingData['selectedGround'] ?? 'N/A'),
                _buildDetailRow('Name', widget.bookingData['userName'] ?? 'Unknown User'),
                _buildDetailRow('Payment Method', widget.bookingData['paymentMethod'] ?? 'N/A'), // Add Payment Method
                _buildBookedTimeSlots(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  FutureBuilder<String> _buildTurfImage() {
    String turfId = widget.bookingData['turfId'];
    return FutureBuilder<String>(
      future: _fetchTurfImageUrl(turfId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text('Error fetching image', style: TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text('No image available', style: TextStyle(color: Colors.grey)),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 250,
            width: double.infinity,
            child: Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  Future<String> _fetchTurfImageUrl(String turfId) async {
    DocumentSnapshot turfDoc = await FirebaseFirestore.instance
        .collection('turfs')
        .doc(turfId)
        .get();

    if (turfDoc.exists) {
      return turfDoc['imageUrl'] ?? '';
    } else {
      throw Exception('Turf not found');
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0.00';
    
    // Convert to double and format to 2 decimal places
    double amountValue;
    if (amount is int) {
      amountValue = amount.toDouble();
    } else if (amount is double) {
      amountValue = amount;
    } else {
      try {
        amountValue = double.parse(amount.toString());
      } catch (e) {
        return '0.00';
      }
    }
    
    // Format to 2 decimal places and remove trailing zeros
    String formatted = amountValue.toStringAsFixed(2);
    if (formatted.endsWith('.00')) {
      formatted = formatted.substring(0, formatted.length - 3);
    } else if (formatted.endsWith('0')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    
    return formatted;
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black87,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookedTimeSlots(BuildContext context) {
    final documentID = widget.bookingData['bookID'];

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(documentID)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'Error loading booking details',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        // Extract booking slots and status from the snapshot
        final bookingData = snapshot.data!.data() as Map<String, dynamic>;
        final List<String> bookingSlots = List<String>.from(bookingData['bookingSlots'] ?? []);
        final List<String> bookingStatus = List<String>.from(bookingData['bookingStatus'] ?? []);
        final currentDateTime = DateTime.now();
        final bookingDate = DateFormat('yyyy-MM-dd').parse(widget.bookingData['bookingDate']);

        // Check if any slot can be cancelled (at least 8 hours before first slot)
        bool canCancelAll = false;
        if (bookingSlots.isNotEmpty) {
          for (var slot in bookingSlots) {
            final normalizedSlot = slot
                .replaceAll('-', ' - ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            final timeParts = normalizedSlot.split(' - ');
            
            if (timeParts.length == 2) {
              try {
                DateTime? bookedStartTime;
                try {
                  bookedStartTime = DateFormat('h:mm a').parseLoose(timeParts[0].trim());
                } catch (_) {
                  try {
                    bookedStartTime = DateFormat('h a').parseLoose(timeParts[0].trim());
                  } catch (_) {}
                }

                if (bookedStartTime != null) {
                  final bookingDateTime = DateTime(
                    bookingDate.year,
                    bookingDate.month,
                    bookingDate.day,
                    bookedStartTime.hour,
                    bookedStartTime.minute,
                  );
                  if (bookingDateTime.isAfter(currentDateTime) &&
                      bookingDateTime.difference(currentDateTime).inHours >= 8) {
                    canCancelAll = true;
                    break;
                  }
                }
              } catch (_) {}
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Booked Time Slots',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  // Dynamic booking slots (active slots)
                  ...bookingSlots.map((slot) {
                    return Chip(
                      label: Text(
                        slot,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: Colors.teal,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    );
                  }),

                  // Dynamic booking status (cancelled slots)
                  ...bookingStatus.map((status) {
                    return Chip(
                      label: Text(
                        status,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: Colors.red.shade400,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    );
                  }),
                ],
              ),
              
              // Single Cancel Booking button at the bottom
              if (bookingSlots.isNotEmpty && canCancelAll) ...[
                SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isCancelling
                        ? null
                        : () async {
                            // Show confirmation dialog
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text('Cancel Booking?'),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Are you sure you want to cancel all ${bookingSlots.length} slot(s)?',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      SizedBox(height: 12),
                                      if (bookingData['paymentMethod'] == 'Online')
                                        Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.info_outline, color: Colors.blue, size: 20),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'A refund request will be submitted. Amount will be refunded within 3-5 business days.',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.blue.shade900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: Text('No', style: TextStyle(color: Colors.grey)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: Text('Yes, Cancel All'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirmed == true) {
                              setState(() {
                                _isCancelling = true;
                              });

                              await _cancelAllSlots(documentID);

                              if (mounted) {
                                setState(() {
                                  _isCancelling = false;
                                });
                              }
                            }
                          },
                    icon: _isCancelling
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.cancel_outlined, color: Colors.white),
                    label: Text(
                      _isCancelling ? 'Cancelling...' : 'Cancel All Bookings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}