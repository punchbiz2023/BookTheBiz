import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odp/pages/home_page.dart';
import 'package:table_calendar/table_calendar.dart';

class BookingPage extends StatefulWidget {
  final String documentId;
  final String documentname;
  final String userId;

  const BookingPage({
    Key? key,
    required this.documentId,
    required this.documentname,
    required this.userId,
  }) : super(key: key);

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  DateTime? selectedDate;
  List<String> selectedSlots = []; // Allow multiple selections
  bool timeSlotBooked = false;
  double price = 0.0;
  double? totalHours = 0.0;
  bool isBookingConfirmed = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> _fetchDetails() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> documentSnapshot =
      await _firestore.collection('turfs').doc(widget.documentId).get();

      if (documentSnapshot.exists) {
        price = documentSnapshot.data()?['price'] ?? 0.0;
        return documentSnapshot.data();
      } else {
        print('Document does not exist');
        return null;
      }
    } catch (e) {
      print('Error fetching document: $e');
      return null;
    }
  }

  Future<List<String>> _fetchBookedSlots() async {
    try {
      QuerySnapshot<Map<String, dynamic>> bookingSnapshot = await _firestore
          .collection('turfs')
          .doc(widget.documentId)
          .collection('bookings')
          .where('bookingDate', isEqualTo: DateFormat('yyyy-MM-dd').format(selectedDate!))
          .get();

      List<String> bookedSlots = [];
      for (var doc in bookingSnapshot.docs) {
        List<String> slots = List<String>.from(doc.data()['bookingSlots']);
        bookedSlots.addAll(slots);
      }
      return bookedSlots;
    } catch (e) {
      print('Error fetching booked slots: $e');
      return [];
    }
  }

  Future<String> _fetchUserName(String userId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> userDoc =
      await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        return userDoc.data()?['name'] ?? 'Anonymous';
      } else {
        return 'Anonymous';
      }
    } catch (e) {
      print('Error fetching user name: $e');
      return 'Anonymous';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book Your Turf',
            style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView( // Enable scrolling
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          children: [
            if (!isBookingConfirmed) _buildCalendar(),
            if (!isBookingConfirmed) _buildSlotSelector(),
            if (selectedSlots.isNotEmpty) // Check if any slots are selected
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (!timeSlotBooked) {
                      setState(() {
                        isBookingConfirmed = true;
                      });
                      _showBookingDialog();
                    } else {
                      _showErrorDialog(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 5,
                    textStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Text('Book Now'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showBookingDialog() async {
    String userName = 'Anonymous';
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      userName = await _fetchUserName(currentUser.uid);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
      return; // Exit if the user is not logged in
    }

    if (selectedDate == null || selectedSlots.isEmpty) { // Check if slots are selected
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a date and at least one slot')),
      );
      return;
    }

    // Calculate total amount and total hours
    double totalAmount = 0.0;
    totalHours = 0.0;

    for (String slot in selectedSlots) {
      double hours = _getHoursForSlot(slot);
      totalHours = (totalHours ?? 0) + hours;
      totalAmount += hours * price;
    }

    // Show the confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Your Booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10),
              Text(widget.documentname, style: TextStyle(fontSize: 18)),
              SizedBox(height: 10),
              Text('Slots: ${selectedSlots.join(", ")}'),
              SizedBox(height: 10),
              Text('Total Hours: ${totalHours!.toStringAsFixed(0)} hours'),
              SizedBox(height: 10),
              Text('Total Amount: ₹${totalAmount.toStringAsFixed(2)}'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Leave', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _showCancellationDialog(); // Show the cancellation dialog
              },
            ),
            TextButton(
              child: Text('Confirm Booking', style: TextStyle(color: Colors.green)),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog

                // Store the booking in Firestore under the specific turf's bookings subcollection
        // Store the booking in Firestore under the specific turf's bookings subcollection
        Map<String, dynamic> bookingData = {
        'userId': currentUser?.uid ?? '',
        'userName': userName,
        'bookingDate': DateFormat('yyyy-MM-dd').format(selectedDate!),
        'bookingSlots': selectedSlots, // Store selected slots as a list
        'totalHours': totalHours,
        'amount': totalAmount,
        'turfId': widget.documentId,
        'turfName': widget.documentname,
        };

        try {
        // Change the path to store booking in the turf document's bookings subcollection
        await _firestore.collection('turfs')
            .doc(widget.documentId)
            .collection('bookings') // Create or reference the 'bookings' subcollection
            .add(bookingData);

        // Also store the booking in the top-level 'bookings' collection
        await _firestore.collection('bookings') // Add to the top-level bookings collection
            .add(bookingData);

        setState(() {
        timeSlotBooked = true;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
        content: Text('Booking confirmed successfully!'),
        backgroundColor: Colors.green, // Set background color to green
        ),
        );

        // Navigate to the home screen after a short delay
        Future.delayed(Duration(seconds: 2), () {
        Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => HomePage1()), // Replace HomeScreen with your home screen widget
        (Route<dynamic> route) => false, // Remove all previous routes
        );
        });
        } catch (e) {
        print('Error booking: $e');
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to confirm booking')),
        );
        }
              }
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2022, 1, 1),
      lastDay: DateTime.utc(2025, 12, 31),
      focusedDay: selectedDate ?? DateTime.now(),
      selectedDayPredicate: (day) {
        return isSameDay(selectedDate, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        if (selectedDay.isAfter(DateTime.now())) {
          setState(() {
            selectedDate = selectedDay;
            selectedSlots.clear(); // Clear selected slots when date changes
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You cannot book for today or past dates')),
          );
        }
      },
      enabledDayPredicate: (day) {
        return day.isAfter(DateTime.now()); // Disable today and all previous dates
      },
      calendarStyle: CalendarStyle(
        selectedDecoration: BoxDecoration(
          color: Colors.green, // Set the selected date color to green
          shape: BoxShape.circle, // Shape of the selected date (circle or rectangle)
        ),
        todayDecoration: BoxDecoration(
          color: Colors.blue, // Set the color for today's date (if you need it)
          shape: BoxShape.circle,
        ),
        defaultDecoration: BoxDecoration(
          shape: BoxShape.circle, // Set shape for the default unselected days
        ),
      ),
    );
  }

  Widget _buildSlotSelector() {
    return FutureBuilder<List<String>>(
      future: selectedDate != null ? _fetchBookedSlots() : Future.value([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error fetching booked slots: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Slots:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              SizedBox(height: 10),
              // Early Morning Slot
              _buildSlotChips('Early Morning', '12 AM - 5 AM', [
                '12:00 AM - 1:00 AM',
                '1:00 AM - 2:00 AM',
                '2:00 AM - 3:00 AM',
                '3:00 AM - 4:00 AM',
                '4:00 AM - 5:00 AM'
              ], snapshot.data!),
              SizedBox(height: 10),
// Morning Slot
              _buildSlotChips('Morning', '5 AM - 11 AM', [
                '5:00 AM - 6:00 AM',
                '6:00 AM - 7:00 AM',
                '7:00 AM - 8:00 AM',
                '8:00 AM - 9:00 AM',
                '9:00 AM - 10:00 AM',
                '10:00 AM - 11:00 AM'
              ], snapshot.data!),
              SizedBox(height: 10),
// Afternoon Slot
              _buildSlotChips('Afternoon', '12 PM - 5 PM', [
                '12:00 PM - 1:00 PM',
                '1:00 PM - 2:00 PM',
                '2:00 PM - 3:00 PM',
                '3:00 PM - 4:00 PM',
                '4:00 PM - 5:00 PM'
              ], snapshot.data!),
              SizedBox(height: 10),
// Evening Slot
              _buildSlotChips('Evening', '5 PM - 11 PM', [
                '5:00 PM - 6:00 PM',
                '6:00 PM - 7:00 PM',
                '7:00 PM - 8:00 PM',
                '8:00 PM - 9:00 PM',
                '9:00 PM - 10:00 PM',
                '10:00 PM - 11:00 PM'
              ], snapshot.data!),

            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Slots:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              SizedBox(height: 10),
              // Early Morning Slot
              _buildSlotChips('Early Morning', '12 AM - 5 AM', [
                '12:00 AM - 1:00 AM',
                '1:00 AM - 2:00 AM',
                '2:00 AM - 3:00 AM',
                '3:00 AM - 4:00 AM',
                '4:00 AM - 5:00 AM'
              ], snapshot.data!),
              SizedBox(height: 10),
// Morning Slot
              _buildSlotChips('Morning', '5 AM - 11 AM', [
                '5:00 AM - 6:00 AM',
                '6:00 AM - 7:00 AM',
                '7:00 AM - 8:00 AM',
                '8:00 AM - 9:00 AM',
                '9:00 AM - 10:00 AM',
                '10:00 AM - 11:00 AM'
              ], snapshot.data!),
              SizedBox(height: 10),
// Afternoon Slot
              _buildSlotChips('Afternoon', '12 PM - 5 PM', [
                '12:00 PM - 1:00 PM',
                '1:00 PM - 2:00 PM',
                '2:00 PM - 3:00 PM',
                '3:00 PM - 4:00 PM',
                '4:00 PM - 5:00 PM'
              ], snapshot.data!),
              SizedBox(height: 10),
// Evening Slot
              _buildSlotChips('Evening', '5 PM - 11 PM', [
                '5:00 PM - 6:00 PM',
                '6:00 PM - 7:00 PM',
                '7:00 PM - 8:00 PM',
                '8:00 PM - 9:00 PM',
                '9:00 PM - 10:00 PM',
                '10:00 PM - 11:00 PM'
              ], snapshot.data!),

            ],
          );
        }
      },
    );
  }

  Widget _buildSlotChips(String title, String subtitle, List<String> slots, List<String> bookedSlots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey)),
        Wrap(
          spacing: 8.0,
          children: slots.map((slot) {
            bool isBooked = bookedSlots.contains(slot); // Check if slot is booked
            return ChoiceChip(
              label: Text(slot),
              selected: selectedSlots.contains(slot),
              selectedColor: isBooked ? Colors.red : Colors.blue,
              disabledColor: Colors.grey,
              onSelected: isBooked
                  ? null // Disable the chip if it's booked
                  : (selected) {
                setState(() {
                  selectedSlots.contains(slot) ? selectedSlots.remove(slot) : selectedSlots.add(slot);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  double _getHoursForSlot(String slot) {
    // Assuming each slot is for 1 hour. You can adjust this if needed.
    return 1.0;
  }

  void _showErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text('This time slot is already booked.'),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showCancellationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Booking Canceled'),
          content: Text('Your booking has been canceled.'),
          actions: [
            TextButton(
              child: Text('Okay'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
