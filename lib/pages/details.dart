import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:booking_and_publish_slots/booking_and_publish_slots.dart';
import 'package:intl/intl.dart'; // Add this for date formatting
import 'bookingpage.dart';
class DetailsPage extends StatefulWidget {
  final String documentId;
  final String documentname;

  const DetailsPage({
    Key? key,
    required this.documentId,
    required this.documentname,
  }) : super(key: key);

  @override
  _DetailsPageState createState() => _DetailsPageState();
}


class _DetailsPageState extends State<DetailsPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedFromTime;
  TimeOfDay? _selectedToTime;
  double price = 0.0;
  double? totalHours = 0.0;
  Future<Map<String, dynamic>?> _fetchDetails() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> documentSnapshot =
          await FirebaseFirestore.instance
              .collection('turfs') // Replace with your collection
              .doc(widget.documentId)
              .get();

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

  IconData _getIconForItem(String item) {
    switch (item.toLowerCase()) {
      case 'football field':
        return Icons.sports_soccer;
      case 'volleyball court':
        return Icons.sports_volleyball;
      case 'cricket ground':
        return Icons.sports_cricket;
      case 'basketball court':
        return Icons.sports_basketball;
      case 'swimming pool':
        return Icons.pool;
      case 'shuttlecock':
        return Icons.sports_tennis;
      case 'tennis court':
        return Icons.sports_tennis;
      case 'badminton court':
        return Icons.sports_tennis;
      case 'parking':
        return Icons.local_parking;
      case 'restroom':
        return Icons.wc;
      case 'cafeteria':
        return Icons.restaurant;
      case 'lighting':
        return Icons.lightbulb;
      case 'seating':
        return Icons.event_seat;
      case 'shower':
        return Icons.shower;
      case 'changing room':
        return Icons.room_preferences;
      case 'wi-fi':
        return Icons.wifi;
      default:
        return Icons.sports;
    }
  }

  Widget _buildChipList(String title, List<dynamic> items,
      Color backgroundColor, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 6.0,
          runSpacing: 3.0,
          children: items
              .map((item) => Chip(
                    label: Text(item),
                    avatar: Icon(
                      _getIconForItem(item),
                      color: Colors.white,
                      size: 20,
                    ),
                    backgroundColor: backgroundColor,
                    labelStyle: TextStyle(
                      color: labelColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ))
              .toList(),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Future<String> _fetchUserName(String userId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> userDoc =
          await FirebaseFirestore.instance
              .collection('users') // Your Firestore collection for user details
              .doc(userId)
              .get();

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

  void _showBookingDialog() async {
    String userName = 'Anonymous';
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      userName = await _fetchUserName(currentUser.uid);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Automatically open the date picker when the dialog is built
        Future<void> _selectDate(BuildContext context) async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime(2101),
          );
          if (pickedDate != null) {
            setState(() {
              _selectedDate = pickedDate;
            });
          }
        }

        // Immediately call the date picker once the dialog is displayed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _selectDate(context);
        });

        return AlertDialog(
            shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.grey[900], // Darker background for the dialog
        elevation: 10, // Adding elevation to the dialog
        title: Text(
        'Book Now',
        style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        ),
        ),
        content: Container(
        width: 800, // Increased width of the dialog
        height: 800, // Height of the dialog
        child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        Text(
        'Select Date and Time (More than 1 hour)',
        style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        SizedBox(height: 16),
        // Date Selection Display
        Card(
        color: Colors.blueGrey[800],
        shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
        title: Text(
        _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
            : 'Date Not Selected',
        style: TextStyle(color: Colors.white, fontSize: 16),
        ),
          trailing: GestureDetector(
            onTap: () => _selectDate(context), // Call _selectDate on tap
            child: Icon(Icons.calendar_today, color: Colors.white),
          ),
        ),
        ),
        SizedBox(height: 16),
        // From Time Selection Card
        Card(
        color: Colors.blueGrey[800],
        shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
        title: Text(
        _selectedFromTime != null
        ? 'From: ${_selectedFromTime!.format(context)}'
            : 'Select From Time',
        style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        trailing: Icon(Icons.access_time, color: Colors.white),
        onTap: () async {
        TimeOfDay? pickedFromTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        );
        if (pickedFromTime != null) {
        setState(() {
        _selectedFromTime = pickedFromTime;
        });
        }
        },
        ),
        ),
        SizedBox(height: 16),
        // To Time Selection Card
        Card(
        color: Colors.blueGrey[800],
        shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
        title: Text(
        _selectedToTime != null
        ? 'To: ${_selectedToTime!.format(context)}'
            : 'Select To Time',
        style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        trailing: Icon(Icons.access_time, color: Colors.white),
        onTap: () async {
        TimeOfDay? pickedToTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        );
        if (pickedToTime != null) {
        setState(() {
        _selectedToTime = pickedToTime;
        });
        }
        },
        ),
        ),
        SizedBox(height: 16),
        ],
        ),
        ),),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_selectedDate == null ||
                    _selectedFromTime == null ||
                    _selectedToTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select date and time')),
                  );
                  return;
                }
                //double? totalHours;
                // Create booking data
                double? totalHours; // Declare totalHours variable
                Map<String, dynamic> bookingData = {
                  'userId': currentUser?.uid ?? '',
                  'userName': userName,
                  'bookingDate': DateFormat('yyyy-MM-dd').format(_selectedDate!),
                  'bookingFromTime': _selectedFromTime!.format(context),
                  'bookingToTime': _selectedToTime!.format(context),
                  'turfId': widget.documentId,
                  'turfName': widget.documentname,
                  'totalHoursBooked': () {
                    // Assuming _selectedFromTime and _selectedToTime are TimeOfDay objects
                    TimeOfDay fromTime = _selectedFromTime!;
                    TimeOfDay toTime = _selectedToTime!;

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
                try {
                  if (totalHours != null && totalHours! >= 1) {
                    await FirebaseFirestore.instance
                        .collection('bookings') // Your Firestore collection
                        .add(bookingData);

                    // Show a success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Booking confirmed!')),
                    );
                    Navigator.of(context).pop(); // Close the dialog
                  } else {
                    // Show a message indicating booking was not allowed
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Cannot confirm booking. Total hours must be at least 1 hour.'),
                      ),
                    );
                  }
                } catch (e) {
                  print('Error saving booking: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to confirm booking')),
                  );
                }
              },
              child: Text('Confirm', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Dark background for the entire page
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchDetails(),
        builder: (BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Error fetching details',
                    style: TextStyle(color: Colors.white)));
          }

          if (snapshot.hasData && snapshot.data != null) {
            // Extract imageUrl, availableGrounds, and facilities
            String imageUrl = snapshot.data!['imageUrl'] ?? '';
            List<dynamic> availableGrounds =
                snapshot.data!['availableGrounds'] ?? [];
            List<dynamic> facilities = snapshot.data!['facilities'] ?? [];
            //double price = snapshot.data!['price'] ?? 0.0; // Fetch the price
            String status = snapshot.data!['status'] ?? 'Opened';
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(widget.documentname,
                        style: TextStyle(color: Colors.white, fontSize: 20)),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                color: Colors.black
                                    .withOpacity(0.5), // Gradient overlay
                                colorBlendMode: BlendMode.darken,
                              )
                            : Container(
                                color: Colors.grey[700],
                                child: Center(
                                  child: Text(
                                    'Image not available',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7)
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                _buildChipList('Available Grounds', availableGrounds, Colors.blueAccent, Colors.white),
                _buildChipList('Facilities', facilities, Colors.green, Colors.white),
                SizedBox(height: 20),
                SizedBox(
                width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Check if the turf is available (not closed)
                      if (status.toLowerCase() == 'closed') {
                        // Show a message when the turf is unavailable
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Turf is currently unavailable, please check again later!')),
                        );
                        return; // Do not proceed if the turf is unavailable
                      }

                      // Navigate to BookingPage if the turf is available
                      User? currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('User not logged in')),
                        );
                        return;
                      }

                      String documentId = widget.documentId; // TurfId is the document ID you're passing to DetailsPage
                      String userId = currentUser.uid;
                      String documentname = widget.documentname;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingPage(documentId: documentId, documentname: documentname, userId: userId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: status.toLowerCase() == 'closed'
                          ? Colors.red // Disabled color when turf is closed
                          : Colors.blueAccent, // Active color when turf is available
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                      status.toLowerCase() == 'closed'
                          ? '⚠️ Turf is unavailable, please check later ⚠️ '
                          : 'Book Now',
                      style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold),
                    ),
                  ),

                ),
          SizedBox(height: 20),
          ],
          ),
          ),

          ],
                  ),
                ),
              ],
            );
          } else {
            return Center(
                child: Text('No details available',
                    style: TextStyle(color: Colors.white)));
          }
        },
      ),
    );
  }
}
