import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_upi_payment/easy_upi_payment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odp/pages/BookingFailedPage.dart';
import 'package:odp/pages/home_page.dart';
import 'package:table_calendar/table_calendar.dart';
import 'BookingSuccessPage.dart';
import 'BookingFailedPage.dart';
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
  List<String> selectedSlots = [];
  bool timeSlotBooked = false;
  double price = 0.0;
  double? totalHours = 0.0;
  bool isBookingConfirmed = false;
  String? selectedGround;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int bookingSlotsForSelectedDay = 0;

  Future<Map<String, List<String>>> _fetchBookedSlots() async {
    try {
      // Fetch the booking documents for the selected date
      QuerySnapshot<Map<String, dynamic>> bookingSnapshot = await _firestore
          .collection('turfs')
          .doc(widget.documentId)
          .collection('bookings')
          .where('bookingDate', isEqualTo: DateFormat('yyyy-MM-dd').format(selectedDate!))
          .get();

      // Initialize a map to hold the ground names and their corresponding booking slots
      Map<String, List<String>> bookedSlotsMap = {};

      // Iterate through each booking document
      for (var doc in bookingSnapshot.docs) {
        // Fetch the selected ground and booking slots
        String selectedGround = doc.data()['selectedGround']; // Adjust this based on your data structure
        List<String> slots = List<String>.from(doc.data()['bookingSlots']);

        // If the ground name is not already in the map, initialize it
        if (!bookedSlotsMap.containsKey(selectedGround)) {
          bookedSlotsMap[selectedGround] = [];
        }

        // Add the booking slots to the corresponding ground
        bookedSlotsMap[selectedGround]!.addAll(slots);
      }

      return bookedSlotsMap;
    } catch (e) {
      print('Error fetching booked slots: $e');
      return {};
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

    // Check if the user is logged in
    if (currentUser != null) {
      userName = await _fetchUserName(currentUser.uid);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
      return; // Exit if the user is not logged in
    }

    // Check if a date and slots have been selected
    if (selectedDate == null || selectedSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('These slots have already been booked. Try new slots')),
      );
      return;
    }

    // Calculate total amount and total hours
    double totalAmount = 0.0;
    double totalHours = 0.0;

    // Fetch turf details
    DocumentSnapshot turfSnapshot = await FirebaseFirestore.instance
        .collection('turfs')
        .doc(widget.documentId)
        .get();

    var price = turfSnapshot['price'] ?? 0.0;

    // Handle different formats for price (Map, List, String, etc.)
    if (price is Map) {
      price = price[selectedGround] ?? 0.0;
    } else if (price is List) {
      price = (price.isNotEmpty) ? price.first : 0.0;
    } else if (price is String) {
      price = double.tryParse(price) ?? 0.0;
    } else if (price is double) {
      price = price;
    }

    // Calculate total amount and hours based on selected slots
    for (String slot in selectedSlots) {
      double hours = _getHoursForSlot(slot);
      totalHours += hours;
      totalAmount += hours * price;
    }

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
              Text('Total Hours: ${totalHours.toStringAsFixed(0)} hours'),
              SizedBox(height: 10),
              Text('Total Amount: ₹${totalAmount.toStringAsFixed(2)}'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Leave', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _showCancellationDialog();
              },
            ),
            TextButton(
              child: Text('Confirm Booking', style: TextStyle(color: Colors.green)),
              onPressed: () async {
                try {
                  // Fetch the owner's details
                  DocumentSnapshot turfDoc = await _firestore.collection('turfs').doc(widget.documentId).get();
                  if (!turfDoc.exists) {
                    throw Exception("Turf details not found.");
                  }

                  String ownerId = turfDoc['ownerId'] ?? '';
                  if (ownerId.isEmpty) {
                    throw Exception("Owner ID not found.");
                  }

                  // Fetch the owner's document
                  DocumentSnapshot ownerDoc = await _firestore.collection('users').doc(ownerId).get();
                  if (!ownerDoc.exists) {
                    throw Exception("Owner details not found.");
                  }

                  // Retrieve UPI ID directly from the owner's details
                  String upiId = ownerDoc['upiId'] ?? '';
                  if (upiId.isEmpty) {
                    throw Exception("UPI ID not found for the owner.");
                  }

                  // Validate UPI ID format (correct pattern for UPI ID)
                  // Validate UPI ID format (correct pattern for UPI ID)
                  final upiPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z]+$';
                  if (!RegExp(upiPattern).hasMatch(upiId)) {
                    throw Exception("Invalid UPI ID format for the owner.");
                  }

                  // Parameters required by easy_upi_payment method
                  String amount = totalAmount.toStringAsFixed(2);

                  // Initiate UPI transaction using easy_upi_payment
                  final res = await EasyUpiPaymentPlatform.instance.startPayment(
                    EasyUpiPaymentModel(
                      payeeVpa: upiId,  // UPI ID of the owner
                      payeeName: 'Turf Owner',  // Name of the owner
                      amount: double.parse(amount),
                      description: 'Booking payment for ${widget.documentname}',
                    ),
                  );

                  // Print the response object to check its structure
                  print("Payment Response: $res");
                  // Payment was successful, store booking data
                  Map<String, dynamic> bookingData = {
                    'userId': currentUser.uid,
                    'userName': userName,
                    'bookingDate': DateFormat('yyyy-MM-dd').format(selectedDate!),
                    'bookingSlots': selectedSlots,
                    'totalHours': totalHours,
                    'amount': totalAmount,
                    'turfId': widget.documentId,
                    'turfName': widget.documentname,
                    'selectedGround': selectedGround,
                  };

                  // Add booking data to Firestore under the turf's bookings collection
                  await _firestore
                      .collection('turfs')
                      .doc(widget.documentId)
                      .collection('bookings')
                      .add(bookingData);

                  // Add booking data to global bookings collection
                  await _firestore.collection('bookings').add(bookingData);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Booking confirmed successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Navigate to booking success page
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => BookingSuccessPage()),
                        (Route<dynamic> route) => false,
                  );
                } on EasyUpiPaymentException {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to confirm booking'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Fetch booked slots per date from Firestore for the given turf
  Future<Map<DateTime, int>> getBookedSlotsPerDate(String turfId) async {
    Map<DateTime, int> bookingCounts = {};
    try {
      QuerySnapshot bookingsSnapshot = await FirebaseFirestore.instance
          .collection('turfs')
          .doc(turfId)
          .collection('bookings')
          .get();

      for (QueryDocumentSnapshot bookingDoc in bookingsSnapshot.docs) {
        var bookingDateRaw = bookingDoc['bookingDate'];
        DateTime bookingDate;

        if (bookingDateRaw is String) {
          bookingDate = DateTime.parse(bookingDateRaw);
        } else if (bookingDateRaw is Timestamp) {
          bookingDate = bookingDateRaw.toDate();
        } else {
          print('Unknown booking date format: $bookingDateRaw');
          continue;
        }

        // Count the number of booked slots (length of bookingSlots array)
        List<dynamic> bookingSlotsRaw = bookingDoc['bookingSlots'] ?? [];
        int bookingSlotsCount = bookingSlotsRaw.length;

        // Accumulate the booking slots for the same date
        if (bookingCounts.containsKey(bookingDate)) {
          bookingCounts[bookingDate] = (bookingCounts[bookingDate]! + bookingSlotsCount).clamp(0, 10);
        } else {
          bookingCounts[bookingDate] = bookingSlotsCount.clamp(0, 10);
        }
      }
    } catch (e) {
      print('Error fetching bookings: $e');
    }
    return bookingCounts;
  }
  // Track booked slots for the selected day

  Widget _buildCalendar() {
    return FutureBuilder(
      future: getBookedSlotsPerDate(widget.documentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text(
            'Error fetching bookings: ${snapshot.error}',
            style: TextStyle(color: Colors.red, fontSize: 16),
          );
        } else {
          Map<DateTime, int> bookingCounts = snapshot.data ?? {};

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2022, 1, 1),
                lastDay: DateTime.utc(2025, 12, 31),
                focusedDay: selectedDate ?? DateTime.now(),
                selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                onDaySelected: (selectedDay, focusedDay) {
                  if (selectedDay.isAfter(DateTime.now())) {
                    setState(() {
                      selectedDate = selectedDay;

                      if (selectedDate != null) {
                        DateTime localSelectedDate = selectedDate!.toLocal();
                        bookingSlotsForSelectedDay = 0;

                        bookingCounts.forEach((date, slots) {
                          DateTime localDate = date.toLocal();
                          if (localDate.year == localSelectedDate.year &&
                              localDate.month == localSelectedDate.month &&
                              localDate.day == localSelectedDate.day) {
                            bookingSlotsForSelectedDay = slots;
                          }
                        });
                      } else {
                        print("Selected date is null");
                      }
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Bookings are only available for future dates. Please select a valid date.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                enabledDayPredicate: (day) => day.isAfter(DateTime.now()),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    if (bookingCounts.containsKey(day)) {
                      int bookedSlots = bookingCounts[day] ?? 0;
                      return Container(
                        decoration: BoxDecoration(
                          color: _getColorForBookingSlots(bookedSlots),
                          shape: BoxShape.circle,
                        ),
                        margin: const EdgeInsets.all(6.0),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    return null;
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    Color? selectedDayColor = _getColorForSelectedDay();
                    return Container(
                      decoration: BoxDecoration(
                        color: selectedDayColor, // Use dynamically updated color
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.all(6.0),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  defaultDecoration: BoxDecoration(shape: BoxShape.circle),
                ),
                daysOfWeekVisible: true,
                headerStyle: HeaderStyle(formatButtonVisible: false),
              ),
              SizedBox(height: 16),
              _buildBookingStatus(),
            ],
          );
        }
      },
    );
  }

// Function to determine the color of the selected day based on the booking status
  Color? _getColorForSelectedDay() {
    const int maxSlotsPerDay = 10;
    if (selectedDate == null) {
      return Colors.grey; // Default color if no date is selected
    }
    double bookingPercentage = (bookingSlotsForSelectedDay / maxSlotsPerDay) * 100;

    if (bookingSlotsForSelectedDay == 0) {
      return Colors.green;
    } else if (bookingPercentage >= 100) {
      return Colors.red;
    } else if (bookingPercentage >= 50) {
      return Colors.orange;
    } else {
      return Colors.teal;
    }
  }


// Function to determine color based on booked slots
  Color _getColorForBookingSlots(int bookedSlots) {
    if (bookedSlots <= 2) {
      return Colors.green; // 0-2 slots booked
    } else if (bookedSlots <= 5) {
      return Colors.teal; // 3-5 slots booked
    } else if (bookedSlots <= 9) {
      return Colors.orange; // 6-9 slots booked
    } else {
      return Colors.red; // 10 or more slots booked
    }
  }

  Widget _buildBookingStatus() {
    const int maxSlotsPerDay = 10; // Maximum slots per day

    if (selectedDate == null) {
      return Text("Select a date to see booking status");
    }
    double bookingPercentage = (bookingSlotsForSelectedDay / maxSlotsPerDay) * 100;
    Color statusColor;
    String statusText;

    // Determine the booking status based on number of booked slots
    if (bookingSlotsForSelectedDay == 0) {
      statusColor = Colors.green;
      statusText = "Available (0/$maxSlotsPerDay slots booked)";
    } else if (bookingPercentage >= 100) {
      statusColor = Colors.red;
      statusText = "Fully Booked ($bookingSlotsForSelectedDay/$maxSlotsPerDay slots booked)";
    } else if (bookingPercentage >= 50) {
      statusColor = Colors.orange;
      statusText =
      "Partially Booked ($bookingSlotsForSelectedDay/$maxSlotsPerDay slots booked)";
    } else {
      statusColor = Colors.teal;
      statusText =
      "Available ($bookingSlotsForSelectedDay/$maxSlotsPerDay slots booked)";
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: 16),
        LinearProgressIndicator(
          value: bookingPercentage / 100,
          color: statusColor,
          backgroundColor: Colors.grey.shade300,
        ),
      ],
    );
  }

  Widget _buildSlotSelector() {
    return FutureBuilder<Map<String, List<String>>>(
      future: selectedDate != null ? _fetchBookedSlots() : Future.value({}),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error fetching booked slots: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // When no data is available
          return _buildSlotSelectionColumn([]);
        } else {
          // When data is successfully fetched
          final bookedSlotsMap = snapshot.data!;
          return _buildSlotSelectionColumn(bookedSlotsMap[selectedGround] ?? []);
        }
      },
    );
  }


  Column _buildSlotSelectionColumn(List<String> bookedSlots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGroundSelector(), // Add ground selector
        SizedBox(height: 20),
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
          '4:00 AM - 5:00 AM',
        ], bookedSlots),
        SizedBox(height: 10),
        // Morning Slot
        _buildSlotChips('Morning', '5 AM - 11 AM', [
          '5:00 AM - 6:00 AM',
          '6:00 AM - 7:00 AM',
          '7:00 AM - 8:00 AM',
          '8:00 AM - 9:00 AM',
          '9:00 AM - 10:00 AM',
          '10:00 AM - 11:00 AM',
        ], bookedSlots),
        SizedBox(height: 10),
        // Afternoon Slot
        _buildSlotChips('Afternoon', '12 PM - 5 PM', [
          '12:00 PM - 1:00 PM',
          '1:00 PM - 2:00 PM',
          '2:00 PM - 3:00 PM',
          '3:00 PM - 4:00 PM',
          '4:00 PM - 5:00 PM',
        ], bookedSlots),
        SizedBox(height: 10),
        // Evening Slot
        _buildSlotChips('Evening', '5 PM - 11 PM', [
          '5:00 PM - 6:00 PM',
          '6:00 PM - 7:00 PM',
          '7:00 PM - 8:00 PM',
          '8:00 PM - 9:00 PM',
          '9:00 PM - 10:00 PM',
          '10:00 PM - 11:00 PM',
        ], bookedSlots),
      ],
    );
  }


  Widget _buildGroundSelector() {
    return FutureBuilder<List<String>>(
      future: _fetchAvailableGrounds(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error fetching available grounds: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text('No grounds available');
        } else {
          List<String> availableGrounds = snapshot.data!;


          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Your Ground:',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo,  // Changed to a more vibrant color
                ),
              ),
              SizedBox(height: 15),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.indigo,  // Border color to match the text color
                    width: 1.5,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedGround,  // Display the selected ground in the dropdown
                    dropdownColor: Colors.indigo.shade50,  // Background color for the dropdown
                    hint: Text(
                      'Select your ground',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down, color: Colors.indigo),  // Customized the dropdown icon color
                    items: availableGrounds.map((ground) {
                      return DropdownMenuItem<String>(
                        value: ground,
                        child: Text(
                          ground,
                          style: TextStyle(fontSize: 18, color: Colors.black87),  // Increased font size and color contrast
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedGround = newValue;  // Set the selected ground when chosen
                      });
                    },
                  ),
                ),
              ),
              if (selectedGround != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    'You selected: $selectedGround',  // Feedback text after selection
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.indigo,
                    ),
                  ),
                ),
            ],
          );
        }
      },
    );
  }

  Future<List<String>> _fetchAvailableGrounds() async {
    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('turfs')
        .doc(widget.documentId) // Use turfId to get the specific document
        .get();

    List<String> grounds = [];
    if (snapshot.exists) {
      // Get the availableGrounds from the document
      List<dynamic> availableGroundsList = snapshot['availableGrounds'];
      grounds = availableGroundsList.map((ground) => ground.toString()).toList();
    }

    return grounds;
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingFailedPage(),
      ),
    );
  }
}