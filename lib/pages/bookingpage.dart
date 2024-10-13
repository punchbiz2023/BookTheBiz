import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;
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
            style:
            TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isBookingConfirmed) _buildCalendar(),
            if (!isBookingConfirmed) _buildTimeSelector(),
            Spacer(),
            if (selectedStartTime != null && selectedEndTime != null)
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
                    padding:
                    EdgeInsets.symmetric(horizontal: 30, vertical: 15),
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
    future: _fetchDetails();
    if (currentUser != null) {
      userName = await _fetchUserName(currentUser.uid);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
      return; // Exit if the user is not logged in
    }

    if (selectedDate == null || selectedStartTime == null || selectedEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    // Calculate the total hours booked
    TimeOfDay fromTime = selectedStartTime!;
    TimeOfDay toTime = selectedEndTime!;
    final now = DateTime.now();
    DateTime fromDateTime = DateTime(now.year, now.month, now.day, fromTime.hour, fromTime.minute);
    DateTime toDateTime = DateTime(now.year, now.month, now.day, toTime.hour, toTime.minute);
    Duration bookingDuration = toDateTime.difference(fromDateTime);

    double hours = bookingDuration.inMinutes / 60.0;
    int roundedHours = hours.floor();
    totalHours = roundedHours.toDouble();

    if (roundedHours < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bookings less than 1 hour are not allowed.')),
      );
      return;
    }

    // Calculate total amount
    double amount = totalHours! * price;

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
              Text('Play Time: ${selectedStartTime!.format(context)} - ${selectedEndTime!.format(context)}'),
              SizedBox(height: 10),
              Text('Hours: ${totalHours!.toStringAsFixed(0)} hours'),
              SizedBox(height: 10),
              Text('Amount: ₹${amount.toStringAsFixed(2)}'),
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

                // Store the booking in Firestore
                Map<String, dynamic> bookingData = {
                  'userId': currentUser?.uid ?? '',
                  'userName': userName,
                  'bookingDate': DateFormat('yyyy-MM-dd').format(selectedDate!),
                  'bookingFromTime': selectedStartTime!.format(context),
                  'bookingToTime': selectedEndTime!.format(context),
                  'turfId': widget.documentId,
                  'turfName': widget.documentname,
                  'totalHoursBooked': () {
                    // Assuming _selectedFromTime and _selectedToTime are TimeOfDay objects
                    TimeOfDay fromTime = selectedStartTime!;
                    TimeOfDay toTime = selectedEndTime!;

                    final now = DateTime.now();
                    DateTime fromDateTime =
                    DateTime(now.year, now.month, now.day, fromTime.hour, fromTime.minute);
                    DateTime toDateTime =
                    DateTime(now.year, now.month, now.day, toTime.hour, toTime.minute);

                    // Calculate the duration difference between the two times
                    Duration bookingDuration = toDateTime.difference(fromDateTime);

                    // Calculate the total number of hours (rounded down to the nearest whole number)
                    double hours = bookingDuration.inMinutes / 60.0;
                    int roundedHours = hours.floor(); // Round down to the nearest hour
                    totalHours = roundedHours.toDouble();
                    if (roundedHours < 1) {
                      // Show a message and prevent booking
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Cannot Book'),
                            content: Text(
                                'Bookings less than 1 hour are not allowed. Please visit the turf for manual bookings.'),
                            actions: <Widget>[
                              TextButton(
                                child: Text('Okay'),
                                onPressed: () {
                                  Navigator.of(context).pop(); // Close the dialog
                                },
                              ),
                            ],
                          );
                        },
                      );
                      return null;
                    }

                    return totalHours;
                  }(),
                  'amount': () {
                    if (totalHours != null) {
                      return totalHours! * price;
                    }
                    return 0;
                  }(),
                };

                if (totalHours != null) {
                  try {
                    await _firestore.collection('bookings').add(bookingData);
                    setState(() {
                      timeSlotBooked = true;
                    });
                    _showSuccessMessage('Booking Confirmed!', true);
                    Navigator.pushNamed(context, '/home_page.dart'); // Redirect to the Home Page
                  } catch (e) {
                    _showSuccessMessage('Oops! Failed, try again later.', false);
                  }
                }
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
          title: Text('Booking Cancelled'),
          content: Text('Your booking has been cancelled.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.pushNamed(context, '/home_page.dart'); // Redirect to the home page
              },
            ),
          ],
        );
      },
    );
  }


  void _showSuccessMessage(String message, bool isSuccess) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: isSuccess ? Colors.green : Colors.red,
    );

    // Show the SnackBar at the center of the screen for 4 seconds
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    Future.delayed(Duration(seconds: 4), () {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  void _showErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text('You have already booked this time slot.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a Date:',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.blueGrey[900],
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                spreadRadius: 2,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: TableCalendar(
            firstDay: DateTime.now(),
            lastDay: DateTime(2100),
            focusedDay: selectedDate ?? DateTime.now(),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                selectedDate = selectedDay;
              });
            },
            selectedDayPredicate: (day) {
              return isSameDay(selectedDate, day);
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              todayDecoration: BoxDecoration(
                color: Colors.lightBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              markerDecoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              defaultDecoration: BoxDecoration(
                color: Colors.blueGrey[700],
                borderRadius: BorderRadius.circular(10),
              ),
              weekendDecoration: BoxDecoration(
                color: Colors.blueGrey[800],
                borderRadius: BorderRadius.circular(10),
              ),
              holidayDecoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Time:',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTimeCard(
              title: 'Start Time',
              timeText: selectedStartTime != null
                  ? selectedStartTime!.format(context)
                  : 'Select Start Time',
              onTap: () async {
                final startTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (startTime != null) {
                  setState(() {
                    selectedStartTime = startTime;
                  });
                }
              },
            ),
            _buildTimeCard(
              title: 'End Time',
              timeText: selectedEndTime != null
                  ? selectedEndTime!.format(context)
                  : 'Select End Time',
              onTap: () async {
                final endTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (endTime != null) {
                  setState(() {
                    selectedEndTime = endTime;
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildTimeCard({required String title, required String timeText, required VoidCallback onTap}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white, backgroundColor: Colors.blueGrey[800],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
      onPressed: onTap,
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 16)),
          SizedBox(height: 5),
          Text(timeText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
