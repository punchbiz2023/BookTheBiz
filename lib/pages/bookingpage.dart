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
  double selectedGroundPrice = 0.0;
  double runningTotalAmount = 0.0;
  int runningTotalHours = 0;

  // 1. Add these fields to your _BookingPageState:
  Map<String, dynamic>? _turfData;
  Map<DateTime, int> _bookingCounts = {};
  Map<String, List<String>> _bookedSlotsMap = {};
  bool _isLoadingTurf = true;
  bool _isLoadingBookings = true;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _fetchAllTurfData();
  }

  Future<void> _fetchAllTurfData() async {
    setState(() {
      _isLoadingTurf = true;
      _isLoadingBookings = true;
    });
    try {
      // Fetch turf details
      DocumentSnapshot turfSnapshot = await FirebaseFirestore.instance
          .collection('turfs')
          .doc(widget.documentId)
          .get();
      if (turfSnapshot.exists) {
        _turfData = turfSnapshot.data() as Map<String, dynamic>;
        isosp = _turfData?['isosp'] ?? false;
      }

      // Fetch all bookings for this turf
      QuerySnapshot<Map<String, dynamic>> bookingSnapshot = await _firestore
          .collection('turfs')
          .doc(widget.documentId)
          .collection('bookings')
          .get();

      _bookingCounts.clear();
      _bookedSlotsMap.clear();

      for (var doc in bookingSnapshot.docs) {
        String selectedGround = doc.data()['selectedGround'];
        List<String> slots = List<String>.from(doc.data()['bookingSlots']);
        String userId = doc.data()['userId'];
        String bookingDateStr = doc.data()['bookingDate'];
        DateTime bookingDate = DateTime.parse(bookingDateStr);

        // Count slots per date
        _bookingCounts[bookingDate] = (_bookingCounts[bookingDate] ?? 0) + slots.length;

        // Map of ground+date to slots
        String groundDateKey = '$selectedGround|$bookingDateStr';
        if (!_bookedSlotsMap.containsKey(groundDateKey)) {
          _bookedSlotsMap[groundDateKey] = [];
        }
        _bookedSlotsMap[groundDateKey]!.addAll(slots);

        // Prevent duplicate booking for same user, same slot, same date
        if (userId == widget.userId && bookingDateStr == DateFormat('yyyy-MM-dd').format(selectedDate ?? DateTime.now())) {
          for (var slot in slots) {
            if (selectedSlots.contains(slot)) {
              selectedSlots.remove(slot); // Remove already booked slot by this user
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching turf or bookings: $e');
    }
    setState(() {
      _isLoadingTurf = false;
      _isLoadingBookings = false;
    });
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Payment successful!')));
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Payment failed!')));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTurf || _isLoadingBookings) {
      return Scaffold(
        appBar: AppBar(title: Text('Book Your Turf')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog when trying to leave
        bool shouldPop = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Leave Booking Page?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Are you sure you want to leave?'),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Note: On Spot Payment Not Accepted',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
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
                  child: Text('Stay', style: TextStyle(color: Colors.green)),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text('Leave', style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ?? false;
        return shouldPop;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Book Your Turf',
              style:
                  TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold)),
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () async {
              // Show the same confirmation dialog when pressing back button
              bool shouldPop = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Leave Booking Page?'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Are you sure you want to leave?'),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Note: On Spot Payment Not Accepted',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
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
                        child: Text('Stay', style: TextStyle(color: Colors.green)),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      TextButton(
                        child: Text('Leave', style: TextStyle(color: Colors.red)),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  );
                },
              ) ?? false;
              if (shouldPop) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Note: On Spot Payment Not Accepted',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                children: [
                  if (!isBookingConfirmed) _buildCalendar(),
                  if (!isBookingConfirmed) _buildSlotSelector(),
                  if (selectedSlots.isNotEmpty)
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!timeSlotBooked) {
                            // Check slot availability just before booking (sync, first-come-first-served)
                            bool slotsAvailable = await _checkSlotAvailability();
                            if (!slotsAvailable) {
                              await _showSlotUnavailableDialog(context);
                              Navigator.of(context).pop(); // Go back to previous page
                              return;
                            }
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
            ],
          ),
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

    if (turfSnapshot.exists) {
      var data = turfSnapshot.data() as Map<String, dynamic>?;

      if (data != null && data.containsKey('selectedSlots')) {
        var rawSlots = data['selectedSlots'];

        if (rawSlots is List<dynamic>) {
          setState(() {
            ownerselectedSlots = rawSlots.whereType<String>().toList();
          });
        }
      }
    }

    var price = turfSnapshot['price'] ?? 0.0;

    if (selectedGround != null) {
      if (price is Map) {
        selectedGroundPrice = getPriceForGround(price, selectedGround!);
      } else if (price is double) {
        selectedGroundPrice = price;
      } else if (price is String) {
        selectedGroundPrice = double.tryParse(price) ?? 0.0;
      } else {
        selectedGroundPrice = 0.0;
      }
    }

    for (String slot in selectedSlots) {
      double hours = _getHoursForSlot(slot);
      totalHours += hours;
      totalAmount += hours * selectedGroundPrice;
    }

    // Before confirming booking, check for slot conflicts
    String groundDateKey = selectedGround != null && selectedDate != null
        ? '$selectedGround|${DateFormat('yyyy-MM-dd').format(selectedDate!)}'
        : '';
    List<String> bookedForThisGroundDate = _bookedSlotsMap[groundDateKey] ?? [];
    List<String> conflictSlots = selectedSlots.where((slot) => bookedForThisGroundDate.contains(slot)).toList();
    if (conflictSlots.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Some selected slots are already booked: ${conflictSlots.join(", ")}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Professional, modern AlertDialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.92,
              padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Column(
                      children: [
                        Icon(Icons.verified, color: Colors.white, size: 38),
                        SizedBox(height: 8),
                        Text(
                          'Confirm Booking',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.documentname,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: Colors.indigo),
                            SizedBox(width: 6),
                            Text(
                              DateFormat('EEE, MMM d, yyyy').format(selectedDate!),
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Ground:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.indigo,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                selectedGround ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade900,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Time Slots:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: selectedSlots
                                    .map((slot) => Container(
                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.teal.shade200),
                                          ),
                                          child: Text(
                                            slot,
                                            style: TextStyle(
                                              color: Colors.teal.shade900,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time, color: Colors.deepPurple, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Total Hours: ',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.deepPurple),
                            ),
                            Text(
                              '${totalHours.toStringAsFixed(0)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 16),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.currency_rupee, color: Colors.green, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Total Amount: ',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                            ),
                            Text(
                              '${totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 17),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade300),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.cancel, color: Colors.red),
                          label: Text('Cancel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showCancellationDialog();
                          },
                        ),
                        if (isosp)
                          TextButton.icon(
                            icon: Icon(Icons.payments, color: Colors.teal),
                            label: Text('Pay On Spot', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('On-spot payment selected')),
                              );
                              try {
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
                                  'paymentMethod': 'On Spot',
                                };

                                await _firestore
                                    .collection('turfs')
                                    .doc(widget.documentId)
                                    .collection('bookings')
                                    .add(bookingData);

                                await _firestore.collection('bookings').add(bookingData);

                                await _showSuccessDialog(context, "Booking confirmed successfully!", true);
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
                        TextButton.icon(
                          icon: Icon(Icons.check_circle, color: Colors.green),
                          label: Text('Confirm', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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

                            _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) async {
                              try {
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
                                  'paymentMethod': 'Online',
                                  'status': 'confirmed',
                                };

                                await _firestore
                                    .collection('turfs')
                                    .doc(widget.documentId)
                                    .collection('bookings')
                                    .add(bookingData);

                                await _firestore.collection('bookings').add(bookingData);

                                await _showSuccessDialog(context, "Booking confirmed successfully!", true);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to confirm booking: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            });

                            _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) async {
                              await _showSuccessDialog(context, "Payment failed: ${response.message}", false);
                            });

                            try {
                              _razorpay.open(options);
                            } catch (e) {
                              print("Error: $e");
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                DateTime localSelectedDate = selectedDate!.toLocal();
                bookingSlotsForSelectedDay = 0;
                _bookingCounts.forEach((date, slots) {
                  DateTime localDate = date.toLocal();
                  if (localDate.year == localSelectedDate.year &&
                      localDate.month == localSelectedDate.month &&
                      localDate.day == localSelectedDate.day) {
                    bookingSlotsForSelectedDay = slots;
                  }
                });
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
              if (_bookingCounts.containsKey(day)) {
                int bookedSlots = _bookingCounts[day] ?? 0;
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
    // Use _turfData and _bookedSlotsMap directly
    List<String> ownerSelectedSlots = [];
    if (_turfData != null && _turfData!.containsKey('selectedSlots')) {
      var rawSlots = _turfData!['selectedSlots'];
      if (rawSlots is List<dynamic>) {
        ownerSelectedSlots = rawSlots.whereType<String>().toList();
      }
    }
    String groundDateKey = selectedGround != null && selectedDate != null
        ? '$selectedGround|${DateFormat('yyyy-MM-dd').format(selectedDate!)}'
        : '';
    List<String> bookedForThisGroundDate = _bookedSlotsMap[groundDateKey] ?? [];
    return _buildSlotSelectionColumn(bookedForThisGroundDate, ownerSelectedSlots);
  }

  Column _buildSlotSelectionColumn(
      List<String> bookedSlots, List<String> ownerSelectedSlots) {
    // Use _turfData and _bookedSlotsMap for slot availability
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

    Map<String, List<String>> slots = {};
    if (ownerSelectedSlots.isNotEmpty) {
      slots['Choose your best play time'] = ownerSelectedSlots;
    } else {
      slots = defaultSlots;
    }

    // Use selectedGround and selectedDate to get booked slots for this ground and date
    String groundDateKey = selectedGround != null && selectedDate != null
        ? '$selectedGround|${DateFormat('yyyy-MM-dd').format(selectedDate!)}'
        : '';
    List<String> bookedForThisGroundDate = _bookedSlotsMap[groundDateKey] ?? [];

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
              child: _buildSlotChips(entry.key, '', entry.value, bookedForThisGroundDate),
            )),
      ],
    );
  }

  Widget _buildGroundSelector() {
    List<String> availableGrounds = [];
    if (_turfData != null && _turfData!['availableGrounds'] != null) {
      availableGrounds = List<String>.from(_turfData!['availableGrounds']);
    }
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
              onChanged: (String? newValue) async {
                await _fetchPriceForSelectedGround(newValue);
                setState(() {
                  selectedGround = newValue;
                  runningTotalAmount = 0.0;
                  runningTotalHours = 0;
                  selectedSlots.clear();
                });
              },
            ),
          ),
        ),
        if (selectedGround != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Price per hour: ₹${selectedGroundPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (selectedGround != null && runningTotalHours > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Selected: $runningTotalHours hour(s) | Total: ₹${runningTotalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
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
    bool groundSelected = selectedGround != null && selectedGround!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey)),
        Wrap(
          spacing: 8.0,
          children: slots.map((slot) {
            bool isBooked = bookedSlots.contains(slot);
            bool isAlreadySelected = selectedSlots.contains(slot);
            return ChoiceChip(
              label: Text(slot),
              selected: isAlreadySelected,
              selectedColor: isBooked ? Colors.red : Colors.blue,
              disabledColor: Colors.grey.shade300,
              onSelected: (!groundSelected || isBooked)
                  ? null
                  : (selected) {
                      // Prevent user from booking the same slot twice
                      if (isAlreadySelected && selected) return;
                      setState(() {
                        if (isAlreadySelected) {
                          selectedSlots.remove(slot);
                        } else {
                          if (!isBooked) {
                            selectedSlots.add(slot);
                          }
                        }
                        runningTotalHours = selectedSlots.length;
                        runningTotalAmount = runningTotalHours * selectedGroundPrice;
                      });
                    },
            );
          }).toList(),
        ),
        if (!groundSelected)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              "Please select a ground to choose time slots.",
              style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
            ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.red[50],
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Slot Unavailable', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'One or more of the selected slots are already booked. Please choose different slots.',
                style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Icon(Icons.event_busy, color: Colors.red, size: 48),
            ],
          ),
          actions: [
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.red)),
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
    // Show the 'Oops Failed Try Again Later' error message by navigating to BookingFailedPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingFailedPage(),
      ),
    );
  }

  Future<void> _fetchPriceForSelectedGround(String? ground) async {
    if (ground == null) return;
    try {
      DocumentSnapshot turfSnapshot = await FirebaseFirestore.instance
          .collection('turfs')
          .doc(widget.documentId)
          .get();
      print('Full turfSnapshot data: ${turfSnapshot.data()}');
      var data = turfSnapshot.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('price')) {
        final priceField = data['price'];
        double priceValue = getPriceForGround(priceField, ground);
        setState(() {
          selectedGroundPrice = priceValue;
          runningTotalAmount = selectedSlots.length * selectedGroundPrice;
        });
      } else {
        print('No price found for ground: $ground');
        setState(() {
          selectedGroundPrice = 0.0;
          runningTotalAmount = selectedSlots.length * selectedGroundPrice;
        });
      }
    } catch (e) {
      print('Error fetching price for $ground: $e');
      setState(() {
        selectedGroundPrice = 0.0;
        runningTotalAmount = selectedSlots.length * selectedGroundPrice;
      });
    }
  }

  // Helper to get price for a ground with normalization and debug prints
  double getPriceForGround(dynamic priceMap, String ground) {
    if (priceMap is Map) {
      print('Trying to match key: $ground');
      print('Available keys in price map: ${priceMap.keys}');
      for (var key in priceMap.keys) {
        if (key.toString().trim().toLowerCase() == ground.trim().toLowerCase()) {
          print('Matched key: $key, price: ${priceMap[key]}');
          var val = priceMap[key];
          if (val is num) return val.toDouble();
          if (val is String) return double.tryParse(val) ?? 0.0;
          return 0.0;
        }
      }
      print('No match found for $ground');
      return 0.0;
    } else if (priceMap is num) {
      // If price is not a map, use same price for all grounds
      print('Price is not a map, using $priceMap for all grounds');
      return priceMap.toDouble();
    } else if (priceMap is String) {
      print('Price is not a map, using $priceMap for all grounds');
      return double.tryParse(priceMap) ?? 0.0;
    }
    print('Price is not a map or number, defaulting to 0.0');
    return 0.0;
  }

  // Fetch user name from Firestore using userId
  Future<String> _fetchUserName(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('name')) {
          return data['name'] ?? 'Anonymous';
        }
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }
    return 'Anonymous';
  }

  Future<bool> _checkSlotAvailability() async {
    if (selectedGround == null || selectedDate == null) return false;
    String groundDateKey = '$selectedGround|${DateFormat('yyyy-MM-dd').format(selectedDate!)}';
    // Fetch latest bookings for this ground and date
    QuerySnapshot<Map<String, dynamic>> bookingSnapshot = await _firestore
        .collection('turfs')
        .doc(widget.documentId)
        .collection('bookings')
        .where('selectedGround', isEqualTo: selectedGround)
        .where('bookingDate', isEqualTo: DateFormat('yyyy-MM-dd').format(selectedDate!))
        .get();

    List<String> allBookedSlots = [];
    for (var doc in bookingSnapshot.docs) {
      List<String> slots = List<String>.from(doc.data()['bookingSlots']);
      allBookedSlots.addAll(slots);
    }
    // If any selected slot is already booked, return false
    return selectedSlots.every((slot) => !allBookedSlots.contains(slot));
  }

  Future<void> _showSlotUnavailableDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.orange[50],
          title: Row(
            children: [
              Icon(Icons.event_busy, color: Colors.deepOrange, size: 28),
              SizedBox(width: 8),
              Text('Slot Unavailable', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sorry, one or more of your selected slots have just been booked by another user.\n\nPlease try different slots or another time.',
                style: TextStyle(color: Colors.deepOrange[800], fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Icon(Icons.schedule, color: Colors.deepOrange, size: 48),
            ],
          ),
          actions: [
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSuccessDialog(BuildContext context, String message, bool isSuccess) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: isSuccess ? Colors.green[50] : Colors.red[50],
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error_outline,
                color: isSuccess ? Colors.green : Colors.red,
                size: 32,
              ),
              SizedBox(width: 10),
              Text(
                isSuccess ? 'Success' : 'Payment Failed',
                style: TextStyle(
                  color: isSuccess ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: TextStyle(
                  color: isSuccess ? Colors.green[900] : Colors.red[900],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 18),
              Icon(
                isSuccess ? Icons.celebration : Icons.warning_amber_rounded,
                color: isSuccess ? Colors.green : Colors.red,
                size: 48,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                if (isSuccess) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => BookingSuccessPage()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
