import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odp/pages/BookingFailedPage.dart';
import 'package:table_calendar/table_calendar.dart';
import 'BookingSuccessPage.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class BookingPage extends StatefulWidget {
  final String documentId;
  final String documentname;
  final String userId;

  const BookingPage({
    super.key,
    required this.documentId,
    required this.documentname,
    required this.userId,
  });

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  late Razorpay _razorpay;
  DateTime? selectedDate;
  List<String> selectedSlots = [];
  bool timeSlotBooked = false;
  double price = 0.0;
  double? totalHours = 0.0;
  bool isBookingConfirmed = false;
  String? selectedGround;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int bookingSlotsForSelectedDay = 0;
  bool isosp = false; // Track on-spot payment status
  List<String> ownerselectedSlots = [];
  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _fetchTurfDetails(); // Fetch turf details including isosp
  }

  @override
  void dispose() {
    super.dispose();
    _razorpay.clear();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Payment successful!')));
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Payment failed!')));
  }

  Future<void> _fetchTurfDetails() async {
    try {
      DocumentSnapshot turfSnapshot = await FirebaseFirestore.instance
          .collection('turfs')
          .doc(widget.documentId)
          .get();

      if (turfSnapshot.exists) {
        setState(() {
          isosp = turfSnapshot['isosp'] ?? false; // Fetch isosp from Firestore
        });
      }
    } catch (e) {
      print('Error fetching turf details: $e');
    }
  }

  Future<Map<String, List<String>>> _fetchBookedSlots() async {
    try {
      QuerySnapshot<Map<String, dynamic>> bookingSnapshot = await _firestore
          .collection('turfs')
          .doc(widget.documentId)
          .collection('bookings')
          .where('bookingDate',
              isEqualTo: DateFormat('yyyy-MM-dd').format(selectedDate!))
          .get();

      Map<String, List<String>> bookedSlotsMap = {};

      for (var doc in bookingSnapshot.docs) {
        String selectedGround = doc.data()['selectedGround'];
        List<String> slots = List<String>.from(doc.data()['bookingSlots']);

        if (!bookedSlotsMap.containsKey(selectedGround)) {
          bookedSlotsMap[selectedGround] = [];
        }

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
            style:
                TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          children: [
            if (!isBookingConfirmed) _buildCalendar(),
            if (!isBookingConfirmed) _buildSlotSelector(),
            if (selectedSlots.isNotEmpty)
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
      return;
    }

    if (selectedDate == null || selectedSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('These slots have already been booked. Try new slots')),
      );
      return;
    }

    double totalAmount = 0.0;
    double totalHours = 0.0;

    DocumentSnapshot turfSnapshot = await FirebaseFirestore.instance
        .collection('turfs')
        .doc(widget.documentId)
        .get();

// Check if selectedSlots field exists and is a List
    if (turfSnapshot.exists) {
      var data = turfSnapshot.data() as Map<String, dynamic>?;

      if (data != null && data.containsKey('selectedSlots')) {
        var rawSlots = data['selectedSlots'];

        if (rawSlots is List<dynamic>) {
          // Convert each item to String safely
          setState(() {
            // ✅ This ensures UI updates after fetching
            ownerselectedSlots = rawSlots.whereType<String>().toList();
          });
        }
      }
    }

    print('Selected Slots: $ownerselectedSlots');

    var price = turfSnapshot['price'] ?? 0.0;

    if (price is Map) {
      price = price[selectedGround] ?? 0.0;
    } else if (price is List) {
      price = (price.isNotEmpty) ? price.first : 0.0;
    } else if (price is String) {
      price = double.tryParse(price) ?? 0.0;
    } else if (price is double) {
      price = price;
    }

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
            if (isosp) // Show "Pay On Spot" button only if isosp is true
              TextButton(
                child:
                    Text('Pay On Spot', style: TextStyle(color: Colors.green)),
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('On-spot payment selected')),
                  );

                  try {
                    Map<String, dynamic> bookingData = {
                      'userId': currentUser.uid,
                      'userName': userName,
                      'bookingDate':
                          DateFormat('yyyy-MM-dd').format(selectedDate!),
                      'bookingSlots': selectedSlots,
                      'totalHours': totalHours,
                      'amount': totalAmount,
                      'turfId': widget.documentId,
                      'turfName': widget.documentname,
                      'selectedGround': selectedGround,
                      'paymentMethod': 'On Spot',
                    };

                    await _firestore
                        .collection('turfs')
                        .doc(widget.documentId)
                        .collection('bookings')
                        .add(bookingData);

                    await _firestore.collection('bookings').add(bookingData);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Booking confirmed successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => BookingSuccessPage()),
                      (Route<dynamic> route) => false,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to confirm booking: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            TextButton(
              child: Text('Confirm Booking',
                  style: TextStyle(color: Colors.green)),
              onPressed: () async {
                var options = {
                  'key': 'rzp_test_RmOLs985IPNRVq',
                  'amount': (totalAmount * 100).toInt(),
                  'name': 'Turf Booking',
                  'description': 'Booking fee for your selected slots',
                  'prefill': {
                    'contact': 'test',
                    'email': 'test',
                  },
                  'theme': {
                    'color': '#00FF00',
                  },
                };

                _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,
                    (PaymentSuccessResponse response) async {
                  try {
                    Map<String, dynamic> bookingData = {
                      'userId': currentUser.uid,
                      'userName': userName,
                      'bookingDate':
                          DateFormat('yyyy-MM-dd').format(selectedDate!),
                      'bookingSlots': selectedSlots,
                      'totalHours': totalHours,
                      'amount': totalAmount,
                      'turfId': widget.documentId,
                      'turfName': widget.documentname,
                      'selectedGround': selectedGround,
                      'paymentMethod': 'Online',
                      'status': 'confirmed', // Add status as confirmed
                    };

                    await _firestore
                        .collection('turfs')
                        .doc(widget.documentId)
                        .collection('bookings')
                        .add(bookingData);

                    await _firestore.collection('bookings').add(bookingData);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Booking confirmed successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => BookingSuccessPage()),
                      (Route<dynamic> route) => false,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to confirm booking: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                });

                _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,
                    (PaymentFailureResponse response) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Payment failed: ${response.message}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                });

                try {
                  _razorpay.open(options);
                } catch (e) {
                  print("Error: $e");
                }
              },
            ),
          ],
        );
      },
    );
  }

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

        List<dynamic> bookingSlotsRaw = bookingDoc['bookingSlots'] ?? [];
        int bookingSlotsCount = bookingSlotsRaw.length;

        if (bookingCounts.containsKey(bookingDate)) {
          bookingCounts[bookingDate] =
              (bookingCounts[bookingDate]! + bookingSlotsCount).clamp(0, 10);
        } else {
          bookingCounts[bookingDate] = bookingSlotsCount.clamp(0, 10);
        }
      }
    } catch (e) {
      print('Error fetching bookings: $e');
    }
    return bookingCounts;
  }

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
                        color: selectedDayColor,
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.all(6.0),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
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

  Color? _getColorForSelectedDay() {
    const int maxSlotsPerDay = 10;
    if (selectedDate == null) {
      return Colors.grey;
    }
    double bookingPercentage =
        (bookingSlotsForSelectedDay / maxSlotsPerDay) * 100;

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

  Color _getColorForBookingSlots(int bookedSlots) {
    if (bookedSlots <= 2) {
      return Colors.green;
    } else if (bookedSlots <= 5) {
      return Colors.teal;
    } else if (bookedSlots <= 9) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildBookingStatus() {
    const int maxSlotsPerDay = 10;

    if (selectedDate == null) {
      return Text("Select a date to see booking status");
    }
    double bookingPercentage =
        (bookingSlotsForSelectedDay / maxSlotsPerDay) * 100;
    Color statusColor;
    String statusText;

    if (bookingSlotsForSelectedDay == 0) {
      statusColor = Colors.green;
      statusText = "Available (0/$maxSlotsPerDay slots booked)";
    } else if (bookingPercentage >= 100) {
      statusColor = Colors.red;
      statusText =
          "Fully Booked ($bookingSlotsForSelectedDay/$maxSlotsPerDay slots booked)";
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
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('turfs')
          .doc(widget.documentId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error fetching slots: ${snapshot.error}'));
        } else if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildSlotSelectionColumn(
              [], []); // No data, return empty slots
        } else {
          var data = snapshot.data!.data() as Map<String, dynamic>?;
          List<String> ownerSelectedSlots = [];

          if (data != null && data.containsKey('selectedSlots')) {
            var rawSlots = data['selectedSlots'];
            if (rawSlots is List<dynamic>) {
              ownerSelectedSlots = rawSlots.whereType<String>().toList();
            }
          }

          var bookedSlotsMap =
              data?['bookedSlots'] as Map<String, dynamic>? ?? {};
          List<String> bookedSlots =
              bookedSlotsMap[selectedGround]?.cast<String>() ?? [];

          return _buildSlotSelectionColumn(bookedSlots, ownerSelectedSlots);
        }
      },
    );
  }

  Column _buildSlotSelectionColumn(
      List<String> bookedSlots, List<String> ownerSelectedSlots) {
    // Default slot structure if ownerSelectedSlots is empty
    final defaultSlots = {
      'Early Morning': [
        '12:00 AM - 1:00 AM',
        '1:00 AM - 2:00 AM',
        '2:00 AM - 3:00 AM',
        '3:00 AM - 4:00 AM',
        '4:00 AM - 5:00 AM',
      ],
      'Morning': [
        '5:00 AM - 6:00 AM',
        '6:00 AM - 7:00 AM',
        '7:00 AM - 8:00 AM',
        '8:00 AM - 9:00 AM',
        '9:00 AM - 10:00 AM',
        '10:00 AM - 11:00 AM',
      ],
      'Afternoon': [
        '12:00 PM - 1:00 PM',
        '1:00 PM - 2:00 PM',
        '2:00 PM - 3:00 PM',
        '3:00 PM - 4:00 PM',
        '4:00 PM - 5:00 PM',
      ],
      'Evening': [
        '5:00 PM - 6:00 PM',
        '6:00 PM - 7:00 PM',
        '7:00 PM - 8:00 PM',
        '8:00 PM - 9:00 PM',
        '9:00 PM - 10:00 PM',
        '10:00 PM - 11:00 PM',
      ],
    };

    // Use `ownerSelectedSlots` if available; otherwise, use default slots
    Map<String, List<String>> slots = {};
    if (ownerSelectedSlots.isNotEmpty) {
      slots['Choose your best play time'] = ownerSelectedSlots;
    } else {
      slots = defaultSlots;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGroundSelector(),
        SizedBox(height: 20),
        Text(
          'Available Slots',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        SizedBox(height: 10),
        ...slots.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSlotChips(entry.key, '', entry.value, bookedSlots),
            )),
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
                  color: Colors.indigo,
                ),
              ),
              SizedBox(height: 15),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.indigo,
                    width: 1.5,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedGround,
                    dropdownColor: Colors.indigo.shade50,
                    hint: Text(
                      'Select your ground',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down, color: Colors.indigo),
                    items: availableGrounds.map((ground) {
                      return DropdownMenuItem<String>(
                        value: ground,
                        child: Text(
                          ground,
                          style: TextStyle(fontSize: 18, color: Colors.black87),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedGround = newValue;
                      });
                    },
                  ),
                ),
              ),
              if (selectedGround != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    'You selected: $selectedGround',
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
        .doc(widget.documentId)
        .get();

    List<String> grounds = [];
    if (snapshot.exists) {
      List<dynamic> availableGroundsList = snapshot['availableGrounds'];
      grounds =
          availableGroundsList.map((ground) => ground.toString()).toList();
    }

    return grounds;
  }

  Widget _buildSlotChips(String title, String subtitle, List<String> slots,
      List<String> bookedSlots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey)),
        Wrap(
          spacing: 8.0,
          children: slots.map((slot) {
            bool isBooked = bookedSlots.contains(slot);
            return ChoiceChip(
              label: Text(slot),
              selected: selectedSlots.contains(slot),
              selectedColor: isBooked ? Colors.red : Colors.blue,
              disabledColor: Colors.grey,
              onSelected: isBooked
                  ? null
                  : (selected) {
                      setState(() {
                        selectedSlots.contains(slot)
                            ? selectedSlots.remove(slot)
                            : selectedSlots.add(slot);
                      });
                    },
            );
          }).toList(),
        ),
      ],
    );
  }

  double _getHoursForSlot(String slot) {
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
