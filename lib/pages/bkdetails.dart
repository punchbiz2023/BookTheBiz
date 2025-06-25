import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingDetailsPage1 extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const BookingDetailsPage1({Key? key, required this.bookingData})
      : super(key: key);

  @override
  _BookingDetailsPage1State createState() => _BookingDetailsPage1State();
}

class _BookingDetailsPage1State extends State<BookingDetailsPage1> {
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
                _buildDetailRow('Amount', '₹${widget.bookingData['amount'] ?? 0}'),
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
          child: Container(
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
        bool isCancelling = false;

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
              SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  // Dynamic booking slots
                  ...bookingSlots.map((slot) {
                    // Normalize slot string to handle various formats
                    final normalizedSlot = slot
                        .replaceAll('-', ' - ')
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim();

                    final timeParts = normalizedSlot.split(' - ');
                    DateTime? bookedStartTime;
                    DateTime? bookedEndTime;
                    bool canCancel = false;
                    bool validFormat = false;

                    if (timeParts.length == 2) {
                      try {
                        // Try parsing with and without minutes
                        bookedStartTime = DateFormat('h:mm a').parseLoose(timeParts[0].trim());
                      } catch (_) {
                        try {
                          bookedStartTime = DateFormat('h a').parseLoose(timeParts[0].trim());
                        } catch (_) {}
                      }
                      try {
                        bookedEndTime = DateFormat('h:mm a').parseLoose(timeParts[1].trim());
                      } catch (_) {
                        try {
                          bookedEndTime = DateFormat('h a').parseLoose(timeParts[1].trim());
                        } catch (_) {}
                      }

                      if (bookedStartTime != null && bookedEndTime != null) {
                        final bookingDateTime = DateTime(
                          bookingDate.year,
                          bookingDate.month,
                          bookingDate.day,
                          bookedStartTime.hour,
                          bookedStartTime.minute,
                        );
                        canCancel = bookingDateTime.isAfter(currentDateTime) &&
                            bookingDateTime.difference(currentDateTime).inHours >= 8;
                        validFormat = true;
                      }
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Chip(
                            label: Text(
                              slot,
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.teal,
                          ),
                        ),
                        SizedBox(width: 16),
                        if (validFormat)
                          ElevatedButton(
                            onPressed: canCancel && !isCancelling
                                ? () async {
                                    setState(() {
                                      isCancelling = true;
                                    });

                                    await _cancelBooking(
                                      documentID,
                                      bookedStartTime!,
                                      bookedEndTime!,
                                    );

                                    setState(() {
                                      isCancelling = false;
                                    });
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: canCancel ? Colors.red : Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Cancel Booking',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                      ],
                    );
                  }).toList(),

                  // Dynamic booking status
                  ...bookingStatus.map((status) {
                    return Chip(
                      label: Text(
                        status,
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _cancelBooking(String bookID, DateTime startTime, DateTime endTime) async {
  try {
    final bookingRef = FirebaseFirestore.instance.collection('bookings');

    // Query to get all documents from the bookings collection
    final querySnapshot = await bookingRef.get();

    if (querySnapshot.docs.isNotEmpty) {
      for (var doc in querySnapshot.docs) {
        if (doc.id == bookID) {
          // Get the current bookingSlots
          List<dynamic> bookingSlots = List.from(doc['bookingSlots']); // Ensure mutability
          print('Current bookingSlots: $bookingSlots');

          // Construct the slot to remove with non-zero-padded hours
          String slotToRemove =
              '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}';
          print('Slot to remove: $slotToRemove');

          if (bookingSlots.contains(slotToRemove)) {
            // Remove the slot from bookingSlots
            bookingSlots.remove(slotToRemove);

            // Update the document in Firebase
            await bookingRef.doc(doc.id).update({
              'bookingSlots': bookingSlots,
              'bookingStatus': FieldValue.arrayUnion([slotToRemove]) // Add the slot directly
            });
            print('Updated bookingSlots and bookingStatus.');
          } else {
            print('Slot not found in bookingSlots.');
          }

          // Update the bookings sub-collection in the corresponding turf document
          String turfId = doc['turfId'];
          final turfRef = FirebaseFirestore.instance.collection('turfs').doc(turfId);
          final bookingsSubCollectionRef = turfRef.collection('bookings');
          final turfBookingDocs = await bookingsSubCollectionRef.get();

          for (var subDoc in turfBookingDocs.docs) {
            var bookingData = subDoc.data();
            if (bookingData['selectedGround'] == doc['selectedGround'] &&
                bookingData['bookingDate'] == doc['bookingDate'] &&
                listEquals(bookingData['bookingSlots'], doc['bookingSlots']) &&
                bookingData['userId'] == doc['userId']) {
              List<dynamic> turfBookingSlots = List.from(bookingData['bookingSlots']);
              if (turfBookingSlots.contains(slotToRemove)) {
                turfBookingSlots.remove(slotToRemove);

                // Update the sub-collection document
                await bookingsSubCollectionRef.doc(subDoc.id).update({
                  'bookingSlots': turfBookingSlots,
                  'bookingStatus': FieldValue.arrayUnion([slotToRemove])
                });
                print('Updated turf bookingSlots and bookingStatus.');
              } else {
                print('Slot not found in turfBookingSlots.');
              }
              break;
            }
          }
          break;
        }
      }
    }
  } catch (e) {
    print('Error cancelling booking: $e');
  }
}