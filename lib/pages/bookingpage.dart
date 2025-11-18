import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odp/pages/BookingFailedPage.dart';
import 'package:table_calendar/table_calendar.dart';
import 'BookingSuccessPage.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

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

class _BookingPageState extends State<BookingPage> with SingleTickerProviderStateMixin {
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
  double runningTotalHours = 0.0;
  late AnimationController _loadingAnimationController;

  // 1. Add these fields to your _BookingPageState:
  Map<String, dynamic>? _turfData;
  final Map<DateTime, int> _bookingCounts = {};
  final Map<String, List<String>> _bookedSlotsMap = {};
  bool _isLoadingTurf = true;
  bool _isLoadingBookings = true;

  // Queue-based booking system
  String? _reservationId;
  int? _queuePosition;
  String? _queueStatus;
  Timer? _queueCheckTimer;
  StateSetter? _queueDialogSetter;

  // Add these helper functions to your _BookingPageState:
  double _platformProfit(double turfRate) {
    if (turfRate < 1000) {
      return turfRate * 0.15;
    } else if (turfRate <= 3000) {
      return 110;
    } else {
      return 210;
    }
  }
  double _razorpayFeePercent() {
    return 0.02 * 1.18; // 2% + 18% GST = 2.36%
  }
  double _totalToCharge(double turfRate) {
    double profit = _platformProfit(turfRate);
    double feePercent = _razorpayFeePercent();
    return (turfRate + profit) / (1 - feePercent);
  }
  double _razorpayFeeAmount(double turfRate) {
    double total = _totalToCharge(turfRate);
    double profit = _platformProfit(turfRate);
    return total - turfRate - profit;
  }

  // ===================================================================
  // ✅ BUG FIX #2: PAYMENT PERSISTENCE & RECOVERY FUNCTIONS
  // ===================================================================

  // Save pending payment data to local storage
  Future<void> _savePendingPayment(String orderId, Map<String, dynamic> bookingData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_order_id', orderId);
      await prefs.setString('pending_booking_data', jsonEncode(bookingData));
      await prefs.setInt('pending_payment_timestamp', DateTime.now().millisecondsSinceEpoch);
      print('[PaymentPersistence] Saved pending payment: $orderId');
    } catch (e) {
      print('[PaymentPersistence] Error saving pending payment: $e');
    }
  }

  // Clear pending payment data after success
  Future<void> _clearPendingPayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_order_id');
      await prefs.remove('pending_booking_data');
      await prefs.remove('pending_payment_timestamp');
      print('[PaymentPersistence] Cleared pending payment data');
    } catch (e) {
      print('[PaymentPersistence] Error clearing pending payment: $e');
    }
  }


  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    
    // Initialize animation controller for loading dialog
    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    
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

        // Count total booked hours per date (custom slots contribute their full duration)
        double hoursForDoc = 0.0;
        for (var slot in slots) {
          hoursForDoc += _getHoursForSlot(slot);
        }
        _bookingCounts[bookingDate] = (_bookingCounts[bookingDate] ?? 0) + hoursForDoc.round();

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
              if (!isBookingConfirmed) // Only show warning if not confirming
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
              if (!isBookingConfirmed)
                SizedBox(height: 16),
              Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                children: [
                  if (!isBookingConfirmed) _buildCalendar(),
                  if (!isBookingConfirmed) _buildSlotSelector(),
                  if (!isBookingConfirmed && selectedSlots.isNotEmpty)
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!timeSlotBooked) {
                            // Use queue-based booking system
                            await _freezeSlotAndQueue();
                          } else {
                            _showErrorDialog(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 5,
                          textStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: Text('Book Now',style: TextStyle(color: Colors.white),),
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

  // Queue-based booking functions
  Future<void> _freezeSlotAndQueue() async {
    if (selectedDate == null || selectedSlots.isEmpty || selectedGround == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select date, ground, and slots')),
      );
      return;
    }

    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    // Show elegant loading UI
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => _buildReservationLoadingDialog(),
    );

    try {
      setState(() {
        isBookingConfirmed = true;
      });

      String userName = await _fetchUserName(currentUser.uid);
      
      final HttpsCallable freezeFn = FirebaseFunctions.instance.httpsCallable('freezeSlotAndQueue');
      final result = await freezeFn({
        'turfId': widget.documentId,
        'selectedGround': selectedGround,
        'bookingDate': DateFormat('yyyy-MM-dd').format(selectedDate!),
        'slots': selectedSlots,
        'userId': currentUser.uid,
        'userName': userName,
      });

      // Close loading dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      final data = result.data as Map;
      setState(() {
        _reservationId = data['reservationId'] as String?;
        _queuePosition = data['queuePosition'] as int?;
        _queueStatus = data['status'] as String?;
      });

      if (_queueStatus == 'ready' && _queuePosition == 1) {
        // User is first in queue - show booking dialog
        _showBookingDialog();
      } else {
        // User is queued - show queue status and start polling
        _showQueueStatusDialog();
        _startQueuePolling();
      }
    } catch (e) {
      // Close loading dialog on error
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      setState(() {
        isBookingConfirmed = false;
      });
      String errorMsg = 'Failed to reserve slot';
      if (e is FirebaseFunctionsException) {
        errorMsg = e.message ?? errorMsg;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    }
  }

  // Elegant loading dialog for slot reservation
  Widget _buildReservationLoadingDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.teal.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: Offset(0, 15),
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Icon Container with continuous rotation
            AnimatedBuilder(
              animation: _loadingAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.9 + (_loadingAnimationController.value * 0.1),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.teal.shade400,
                          Colors.teal.shade600,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withOpacity(0.4),
                          blurRadius: 25,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Rotating circular progress
                        Transform.rotate(
                          angle: _loadingAnimationController.value * 2 * 3.14159,
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.4)),
                              backgroundColor: Colors.transparent,
                              value: 0.3,
                            ),
                          ),
                        ),
                        // Center icon
                        Icon(
                          Icons.access_time_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 32),
            // Title
            Text(
              'Reserving Your Slot',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade900,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 12),
            // Subtitle
            Text(
              'Please wait while we secure your booking...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            SizedBox(height: 28),
            // Animated loading indicator
            SizedBox(
              width: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                  minHeight: 6,
                ),
              ),
            ),
            SizedBox(height: 24),
            // Elegant info card
            Container(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.teal.shade50,
                    Colors.teal.shade100.withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.teal.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: Colors.teal.shade700,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'This may take a few seconds',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.teal.shade800,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startQueuePolling() {
    _queueCheckTimer?.cancel();
    _queueCheckTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (_reservationId == null) {
        timer.cancel();
        return;
      }

      try {
        final HttpsCallable checkFn = FirebaseFunctions.instance.httpsCallable('checkQueuePosition');
        final result = await checkFn({
          'reservationId': _reservationId,
          'userId': FirebaseAuth.instance.currentUser?.uid,
        });

        final data = result.data as Map;
        
        if (data['expired'] == true) {
          timer.cancel();
          setState(() {
            isBookingConfirmed = false;
            _reservationId = null;
            _queuePosition = null;
            _queueStatus = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reservation expired. Please try again.'), backgroundColor: Colors.orange),
          );
          return;
        }

        final newPosition = data['queuePosition'] as int?;
        final newStatus = data['status'] as String?;

        if (newStatus == 'ready' && newPosition == 1 && _queueStatus != 'ready') {
          // User promoted to position 1
          timer.cancel();
          setState(() {
            _queuePosition = 1;
            _queueStatus = 'ready';
          });
          _queueDialogSetter?.call(() {}); // Update dialog
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pop(); // Close queue status dialog
              _showBookingDialog(); // Show payment dialog
            }
          });
        } else if (newPosition != _queuePosition) {
          // Position changed
          setState(() {
            _queuePosition = newPosition;
            _queueStatus = newStatus;
          });
          _queueDialogSetter?.call(() {}); // Update dialog
        }
      } catch (e) {
        print('Error checking queue position: $e');
      }
    });
  }

  void _showQueueStatusDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Store setState reference for updates
            _queueDialogSetter = setDialogState;

            return AlertDialog(
              title: Text('Slot Reserved'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.queue, size: 48, color: Colors.teal),
                  SizedBox(height: 16),
                  Text(
                    _queuePosition == 1
                        ? 'Ready to Pay'
                        : 'Position #${_queuePosition ?? '...'} in Queue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _queuePosition == 1
                        ? 'You can proceed to payment'
                        : 'Please wait for your turn. You will be notified when ready.',
                    textAlign: TextAlign.center,
                  ),
                  if (_queuePosition != null && _queuePosition! > 1)
                    Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                if (_queuePosition == 1)
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _showBookingDialog();
                    },
                    child: Text('Proceed to Payment'),
                  ),
                TextButton(
                  onPressed: () {
                    _queueCheckTimer?.cancel();
                    _queueDialogSetter = null;
                    setState(() {
                      isBookingConfirmed = false;
                      _reservationId = null;
                      _queuePosition = null;
                      _queueStatus = null;
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
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

    // Verify reservation is still valid
    if (_reservationId == null || _queuePosition != 1 || _queueStatus != 'ready') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reservation expired or not ready. Please try again.'), backgroundColor: Colors.red),
      );
      setState(() {
        isBookingConfirmed = false;
        _reservationId = null;
        _queuePosition = null;
        _queueStatus = null;
      });
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

    
    showDialog(
  context: context,
  barrierDismissible: false,
  builder: (BuildContext context) {
    // State variable to track loading state
    bool isLoading = false;
    bool isPayingOnSpot = false;
    
    return StatefulBuilder(
      builder: (context, setState) {
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
                      color: Colors.teal,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Column(
                      children: const [
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
                            Icon(Icons.calendar_today, size: 18, color: Colors.teal),
                            SizedBox(width: 6),
                            Text(
                              DateFormat('EEE, MMM d, yyyy').format(selectedDate!),
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Ground:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                selectedGround ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade900,
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
                            Icon(Icons.access_time, color: Colors.teal, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Total Hours: ',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal),
                            ),
                            Text(
                              totalHours.toStringAsFixed(0),
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 16),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.currency_rupee, color: Colors.teal, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Total Amount: ',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal),
                            ),
                            Text(
                              _totalToCharge(totalAmount).toStringAsFixed(2),
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 17),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(),
                              Text('Total Payable + Inclusive of GST: ₹${_totalToCharge(totalAmount).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade300),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                icon: Icon(Icons.cancel, color: Colors.red),
                                label: Text('Cancel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                onPressed: isLoading || isPayingOnSpot
                                  ? null // Disable button when processing
                                  : () {
                                      Navigator.of(context).pop(); // Just close the dialog
                                    },
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                icon: isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                                      ),
                                    )
                                  : Icon(Icons.check_circle, color: Colors.teal),
                                label: isLoading
                                  ? Text("Processing...", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))
                                  : Text('Confirm', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                onPressed: isLoading || isPayingOnSpot
                                  ? null // Disable button when processing
                                  : () async {
                                      setState(() {
                                        isLoading = true;
                                      });
                                      
                                      try {
                                        // Validate that we have the owner ID
                                        if (_turfData == null || _turfData!['ownerId'] == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: Turf owner information not found. Please try again.'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          setState(() {
                                            isLoading = false;
                                          });
                                          return;
                                        }

                                        // Calculate total amount with profit and fees (confidential business logic)
                                        final payableAmount = _totalToCharge(totalAmount);
                                        
                                        // Validate calculated amount
                                        if (payableAmount <= 0) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: Invalid amount calculated. Please try again.'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          setState(() {
                                            isLoading = false;
                                          });
                                          return;
                                        }

                                        String userEmail = FirebaseAuth.instance.currentUser?.email ?? await _fetchUserEmail(currentUser.uid);
                                        String userPhone = FirebaseAuth.instance.currentUser?.phoneNumber ?? await _fetchUserPhone(currentUser.uid);

                                        // Before opening Razorpay checkout, call the callable function to create order with transfer
                                        String? ownerAccountId;

                                        if (_turfData != null && _turfData!['ownerId'] != null) {
                                          final ownerDoc = await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(_turfData!['ownerId'])
                                              .get();
                                          if (ownerDoc.exists && ownerDoc.data() != null) {
                                            ownerAccountId = ownerDoc['razorpayAccountId'];
                                          }
                                        }
                                        
                                        if (ownerAccountId == null || !ownerAccountId.toString().startsWith('acc_')) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Turf owner does not have a valid Razorpay Account ID. Please contact support.')),
                                          );
                                          setState(() {
                                            isLoading = false;
                                          });
                                          return;
                                        }
                                        
                                        // 1) Server-side availability check before creating order
                                        final HttpsCallable availabilityFn = FirebaseFunctions.instance.httpsCallable('checkTurfSlotAvailability');
                                        final availability = await availabilityFn({
                                          'turfId': widget.documentId,
                                          'selectedGround': selectedGround,
                                          'bookingDate': DateFormat('yyyy-MM-dd').format(selectedDate!),
                                          'slots': selectedSlots,
                                        });
                                        final availData = availability.data as Map;
                                        if (availData['available'] != true) {
                                          final List conflicts = (availData['conflicting'] as List?) ?? [];
                                          await _showSuccessDialog(context, conflicts.isNotEmpty
                                            ? 'Some selected slots are already booked: ${conflicts.join(', ')}'
                                            : 'Selected slots are no longer available. Please choose different slots.', false);
                                          setState(() { isLoading = false; });
                                          return;
                                        }

                                        // 2) Create order using queue-based system
                                        final bookingId = widget.documentId + '_' + DateTime.now().millisecondsSinceEpoch.toString();
                                        final bookingData = {
                                          'userId': currentUser.uid,
                                          'userName': userName,
                                          'turfId': widget.documentId,
                                          'turfName': widget.documentname,
                                          'ownerId': _turfData != null ? _turfData!['ownerId'] : null,
                                          'bookingDate': DateFormat('yyyy-MM-dd').format(selectedDate!),
                                          'selectedGround': selectedGround,
                                          'slots': selectedSlots,
                                          'totalHours': totalHours,
                                          'baseAmount': totalAmount,
                                          'payableAmount': payableAmount,
                                        };
                                        
                                        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createRazorpayOrderForQueuedSlot');
                                        final orderResult = await callable({
                                          'reservationId': _reservationId,
                                          'totalAmount': totalAmount,
                                          'payableAmount': payableAmount,
                                          'ownerAccountId': ownerAccountId,
                                          'bookingId': bookingId,
                                          'turfId': widget.documentId,
                                          'userId': currentUser.uid,
                                          'bookingData': bookingData,
                                        });
                                        final orderId = orderResult.data['orderId'];
                                        if (orderId == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Failed to create Razorpay order. Please try again.')),
                                          );
                                          setState(() {
                                            isLoading = false;
                                          });
                                          return;
                                        }
                                        var options = {
                                          'key': 'rzp_live_lUkgWvIy2IHCWA',
                                          'amount': (payableAmount * 100).round(),
                                          'name': widget.documentname,
                                          'description': 'Booking at ${selectedGround ?? ''} on ${DateFormat('yyyy-MM-dd').format(selectedDate!)} - Total: ₹${payableAmount.toStringAsFixed(2)}',
                                          'order_id': orderId,
                                          'prefill': {
                                            'contact': userPhone,
                                            'email': userEmail,
                                          },
                                          'theme': {
                                            'color': '#009688',
                                          },
                                        };

                                        print('Payment Options:');
                                        print('Base Amount: ₹$totalAmount');
                                        print('Payable Amount: ₹$payableAmount');
                                        print('Amount in Paise: ${(payableAmount * 100).round()}');
                                        print('Turf: ${widget.documentname}');
                                        print('Ground: $selectedGround');
                                        print('Date: ${DateFormat('yyyy-MM-dd').format(selectedDate!)}');

                                        // ✅ SAVE PAYMENT DATA LOCALLY BEFORE OPENING RAZORPAY (backup)
                                        await _savePendingPayment(orderId, bookingData);

                                        print('[Payment] Saved pending payment data locally');

                                        _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) async {
                                          try {
                                            print('[PaymentSuccess] Payment response: ${response.paymentId}');
                                            
                                            // ✅ CLEAR PENDING PAYMENT IMMEDIATELY ON SUCCESS
                                            await _clearPendingPayment();
                                            final HttpsCallable confirmFn = FirebaseFunctions.instance.httpsCallable('confirmBookingAfterPayment');
                                            final result = await confirmFn({
                                              'orderId': response.orderId,
                                              'paymentId': response.paymentId,
                                              'reservationId': _reservationId,
                                              'userId': currentUser.uid,
                                              'userName': userName,
                                              'turfId': widget.documentId,
                                              'turfName': widget.documentname,
                                              'ownerId': _turfData != null ? _turfData!['ownerId'] : null,
                                              'bookingDate': DateFormat('yyyy-MM-dd').format(selectedDate!),
                                              'selectedGround': selectedGround,
                                              'slots': selectedSlots,
                                              'totalHours': totalHours,
                                              'baseAmount': totalAmount,
                                              'payableAmount': payableAmount,
                                            });

                                            final data = result.data as Map;
                                            if (data['ok'] == true && data['status'] == 'confirmed') {
                                              try {
                                                final HttpsCallable emailFn = FirebaseFunctions.instance.httpsCallable('sendBookingConfirmationEmail');
                                                await emailFn({
                                                  'to': await _fetchUserEmail(currentUser.uid),
                                                  'userName': userName,
                                                  'bookingId': data['bookingId'] ?? '',
                                                  'turfName': widget.documentname,
                                                  'ground': selectedGround,
                                                  'bookingDate': DateFormat('yyyy-MM-dd').format(selectedDate!),
                                                  'slots': selectedSlots,
                                                  'totalHours': totalHours,
                                                  'amount': payableAmount,
                                                  'paymentMethod': 'Online',
                                                });
                                              } catch (e) {
                                                print('Email send failed: $e');
                                              }
                                              await _showSuccessDialog(context, 'Booking confirmed successfully!', true);
                                              Navigator.of(context).pushAndRemoveUntil(
                                                MaterialPageRoute(builder: (context) => BookingSuccessPage()),
                                                (Route<dynamic> route) => false,
                                              );
                                            } else {
                                              await _showSuccessDialog(context, 'Payment verified, but booking failed. Please try again.', false);
                                              Navigator.of(context).pushAndRemoveUntil(
                                                MaterialPageRoute(
                                                  builder: (context) => BookingFailedPage(
                                                    documentId: widget.documentId,
                                                    documentname: widget.documentname,
                                                    userId: widget.userId,
                                                  ),
                                                ),
                                                (Route<dynamic> route) => false,
                                              );
                                            }
                                          } on FirebaseFunctionsException catch (e) {
                                            print('confirmBookingAndWrite error: ${e.code} ${e.message}');
                                            String msg = e.code == 'aborted'
                                                ? 'Oops! Slot(s) just got booked by another user. Please try again.'
                                                : (e.message ?? 'Payment verification failed');
                                            await _showSuccessDialog(context, msg, false);
                                            Navigator.of(context).pushAndRemoveUntil(
                                              MaterialPageRoute(
                                                builder: (context) => BookingFailedPage(
                                                  documentId: widget.documentId,
                                                  documentname: widget.documentname,
                                                  userId: widget.userId,
                                                ),
                                              ),
                                              (Route<dynamic> route) => false,
                                            );
                                          } catch (e) {
                                            print('Unexpected booking confirm error: $e');
                                            await _showSuccessDialog(context, 'Unexpected error after payment. Please contact support.', false);
                                            Navigator.of(context).pushAndRemoveUntil(
                                              MaterialPageRoute(
                                                builder: (context) => BookingFailedPage(
                                                  documentId: widget.documentId,
                                                  documentname: widget.documentname,
                                                  userId: widget.userId,
                                                ),
                                              ),
                                              (Route<dynamic> route) => false,
                                            );
                                          }
                                        });

                                        _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) async {
                                          try {
                                            print('[PaymentError] Payment failed: ${response.message}');
                                            print('[PaymentError] Code: ${response.code}');
                                            
                                            await _showSuccessDialog(context, "Oops! Payment failed. Please try again", false);
                                          } catch (e) {
                                            print('[Error] in payment error handler: $e');
                                          }
                                          // DO NOT navigate on payment error - let user retry
                                          // Payment data is still in SharedPreferences for recovery
                                        });

                                        try {
                                          print('[Payment] Opening Razorpay payment...');
                                          print('[Payment] Amount: ${payableAmount * 100} paise');
                                          print('[Payment] User: $userEmail, Phone: $userPhone');
                                          _razorpay.open(options);
                                        } catch (e) {
                                          print("[Razorpay] Error: $e");
                                          await _clearPendingPayment(); // Clear if failed to open
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Failed to open payment: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          setState(() {
                                            isLoading = false;
                                          });
                                        }
                                      } catch (e) {
                                        print('Error during payment process: $e');
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        setState(() {
                                          isLoading = false;
                                        });
                                      }
                                    },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        if (isosp)
                          TextButton.icon(
                            icon: isPayingOnSpot
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                                  ),
                                )
                              : Icon(Icons.payments, color: Colors.teal),
                            label: isPayingOnSpot
                              ? Text("Processing...", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))
                              : Text('Pay On Spot', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                            onPressed: isLoading || isPayingOnSpot
                              ? null // Disable button when processing
                              : () async {
                                  setState(() {
                                    isPayingOnSpot = true;
                                  });
                                  
                                  try {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Processing your on-spot payment...')),
                                    );
                                    
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
                                      'status': 'confirmed',
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    };

                                    // Only write to turf subcollection; backend trigger mirrors it
                                    await _firestore
                                        .collection('turfs')
                                        .doc(widget.documentId)
                                        .collection('bookings')
                                        .add(bookingData);

                                    // Send confirmation email for On Spot too
                                    try {
                                      final HttpsCallable emailFn = FirebaseFunctions.instance.httpsCallable('sendBookingConfirmationEmail');
                                      await emailFn({
                                        'to': await _fetchUserEmail(currentUser.uid),
                                        'userName': userName,
                                        'bookingId': '${widget.documentId}_${DateTime.now().millisecondsSinceEpoch}',
                                        'turfName': widget.documentname,
                                        'ground': selectedGround,
                                        'bookingDate': DateFormat('yyyy-MM-dd').format(selectedDate!),
                                        'slots': selectedSlots,
                                        'totalHours': totalHours,
                                        'amount': totalAmount,
                                        'paymentMethod': 'On Spot',
                                      });
                                    } catch (e) {
                                      print('Email send failed (On Spot): $e');
                                    }

                                    await _showSuccessDialog(context, "Booking confirmed successfully!", true);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to confirm booking: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } finally {
                                    setState(() {
                                      isPayingOnSpot = false;
                                    });
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
  },
);// Professional, modern AlertDialog
    setState(() {
      isBookingConfirmed = false;
    });
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
              color: Colors.teal,
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
    // Default hour slots as fallback only
    final defaultSlots = {
      '1. Night (12 AM - 5 AM)': [
        '12:00 AM - 1:00 AM',
        '1:00 AM - 2:00 AM',
        '2:00 AM - 3:00 AM',
        '3:00 AM - 4:00 AM',
        '4:00 AM - 5:00 AM',
      ],
      '2. Morning (5 AM - 12 PM)': [
        '5:00 AM - 6:00 AM',
        '6:00 AM - 7:00 AM',
        '7:00 AM - 8:00 AM',
        '8:00 AM - 9:00 AM',
        '9:00 AM - 10:00 AM',
        '10:00 AM - 11:00 AM',
        '11:00 AM - 12:00 PM',
      ],
      '3. Afternoon (12 PM - 5 PM)': [
        '12:00 PM - 1:00 PM',
        '1:00 PM - 2:00 PM',
        '2:00 PM - 3:00 PM',
        '3:00 PM - 4:00 PM',
        '4:00 PM - 5:00 PM',
      ],
      '4. Evening (5 PM - 12 AM)': [
        '5:00 PM - 6:00 PM',
        '6:00 PM - 7:00 PM',
        '7:00 PM - 8:00 PM',
        '8:00 PM - 9:00 PM',
        '9:00 PM - 10:00 PM',
        '10:00 PM - 11:00 PM',
        '11:00 PM - 12:00 AM',
      ],
    };

    // Use selectedSlots from turf when provided; otherwise fallback to default
    final bool hasOwnerSelected = ownerSelectedSlots.isNotEmpty;
    final List<String> normalOwnerSlots = hasOwnerSelected
        ? ownerSelectedSlots
            .where((s) => _getHoursForSlot(s) <= 1.0)
            .toList()
        : [];
    final List<String> specialOwnerSlots = hasOwnerSelected
        ? ownerSelectedSlots
            .where((s) => _getHoursForSlot(s) > 1.0)
            .toList()
        : [];

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
        if (hasOwnerSelected) ...[
          if (normalOwnerSlots.isNotEmpty) ...[
            Text(
              'Available Slots',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 10),
            _buildSlotChips('Choose your best play time', '', normalOwnerSlots, bookedForThisGroundDate),
          ],
          if (specialOwnerSlots.isNotEmpty) ...[
            Divider(height: 32, thickness: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Special Slots',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple)),
            ),
            _buildSlotChips('Special Slots', '', specialOwnerSlots, bookedForThisGroundDate),
          ],
          if (normalOwnerSlots.isEmpty && specialOwnerSlots.isEmpty)
            Text('No slots available',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
        ] else ...[
          // Fallback to default slots when owner selectedSlots not provided
          Text(
            'Available Slots',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          SizedBox(height: 10),
          ...defaultSlots.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildSlotChips(
                    entry.key, '', entry.value, bookedForThisGroundDate),
              )),
        ],
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
            color: Colors.teal,
          ),
        ),
        SizedBox(height: 15),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.teal,
              width: 1.5,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedGround,
              dropdownColor: Colors.teal.shade50,
              hint: Text(
                'Select your ground',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: Colors.teal),
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
                if (selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please select the play date first'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                await _fetchPriceForSelectedGround(newValue);
                setState(() {
                  selectedGround = newValue;
                  runningTotalAmount = 0.0;
                  runningTotalHours = 0.0;
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
              'Selected: ${runningTotalHours.toStringAsFixed(2)} hour(s) | Total: ₹${runningTotalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.teal,
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
                color: Colors.teal,
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
    // Sort slots chronologically before displaying
    List<String> sortedSlots = List<String>.from(slots);
    sortedSlots.sort((a, b) => _compareSlotTimes(a, b));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey)),
        Wrap(
          spacing: 8.0,
          children: sortedSlots.map((slot) {
            // Consider any overlap with booked slots as booked/disabled
            bool isBooked = bookedSlots.any((booked) => _slotsOverlap(slot, booked));
            bool isAlreadySelected = selectedSlots.contains(slot);
            // Lock if this slot overlaps with any currently selected slot (prevent mixed overlapping selections)
            bool overlapsWithSelected = selectedSlots.any((sel) => sel != slot && _slotsOverlap(slot, sel));
            return ChoiceChip(
              label: Text(slot),
              selected: isAlreadySelected,
              selectedColor: isBooked ? Colors.red : Colors.teal,
              disabledColor: Colors.grey.shade300,
              onSelected: (!groundSelected || isBooked || overlapsWithSelected)
                  ? null
                  : (selected) {
                      // Prevent user from booking the same slot twice
                      if (isAlreadySelected && selected) return;
                      setState(() {
                        if (isAlreadySelected) {
                          selectedSlots.remove(slot);
                        } else {
                          if (!isBooked && !overlapsWithSelected) {
                            selectedSlots.add(slot);
                          }
                        }
                        // Update runningTotalHours and runningTotalAmount based on actual slot durations
                        runningTotalHours = selectedSlots.fold<double>(0.0, (sum, s) => sum + _getHoursForSlot(s));
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

  // Helper to compare slot strings by their start time
  int _compareSlotTimes(String a, String b) {
    DateTime? parseStart(String slot) {
      // Example slot: '7:00 AM - 8:00 AM'
      final parts = slot.split(' - ');
      if (parts.isEmpty) return null;
      try {
        // Parse time in 12-hour format
        final timeStr = parts[0].trim();
        final time = DateFormat('h:mm a').parse(timeStr);
        
        // Special handling for 12 AM/PM to ensure correct ordering
        if (timeStr.endsWith('12:00 AM')) {
          // Move 12 AM to start of day (00:00)
          return DateTime(2000, 1, 1, 0, 0);
        } else if (timeStr.endsWith('12:00 PM')) {
          // Move 12 PM to middle of day (12:00)
          return DateTime(2000, 1, 1, 12, 0);
        }
        return time;
      } catch (_) {
        return null;
      }
    }
    final startA = parseStart(a);
    final startB = parseStart(b);
    if (startA == null && startB == null) return 0;
    if (startA == null) return 1;
    if (startB == null) return -1;
    return startA.compareTo(startB);
  }

  // Helper to get the duration in hours for a slot string like '5:00 PM - 8:00 PM'
  double _getHoursForSlot(String slot) {
    try {
      final range = _parseSlotRange(slot);
      if (range.length != 2) return 1.0;
      final start = range[0];
      final end = range[1];
      double hours = end.difference(start).inMinutes / 60.0;
      return hours <= 0 ? 1.0 : hours;
    } catch (_) {
      return 1.0;
    }
  }

  // Flexible parsing: supports 'h:mm a' and 'h a'
  DateTime? _parseTimeFlexible(String timeStr) {
    try {
      return DateFormat('h:mm a').parse(timeStr);
    } catch (_) {
      try {
        return DateFormat('h a').parse(timeStr);
      } catch (_) {
        return null;
      }
    }
  }

  // Helper to parse slot time range, handling overnight by rolling end forward
  List<DateTime> _parseSlotRange(String slot) {
    final parts = slot.split(' - ');
    if (parts.length != 2) return [];
    final start = _parseTimeFlexible(parts[0].trim());
    final endRaw = _parseTimeFlexible(parts[1].trim());
    if (start == null || endRaw == null) return [];
    DateTime end = endRaw;
    if (!end.isAfter(start)) {
      end = end.add(Duration(days: 1));
    }
    // Normalize to same arbitrary date
    final s = DateTime(2000, 1, 1, start.hour, start.minute);
    final e = DateTime(2000, 1, 1, end.hour, end.minute).isAfter(DateTime(2000, 1, 1, start.hour, start.minute))
        ? DateTime(2000, 1, 1, end.hour, end.minute)
        : DateTime(2000, 1, 2, end.hour, end.minute);
    return [s, e];
  }

  // Normalize slot to 'h:mm a - h:mm a' for reliable comparisons
  String _normalizeSlot(String slot) {
    final range = _parseSlotRange(slot);
    if (range.length != 2) return slot;
    final fmt = DateFormat('h:mm a');
    return '${fmt.format(range[0])} - ${fmt.format(range[1])}';
  }

  // Check if two slot ranges overlap (adjacent is allowed)
  bool _slotsOverlap(String slotA, String slotB) {
    final a = _parseSlotRange(slotA);
    final b = _parseSlotRange(slotB);
    if (a.length != 2 || b.length != 2) return false;
    final startA = a[0];
    final endA = a[1];
    final startB = b[0];
    final endB = b[1];
    final overlaps = startA.isBefore(endB) && startB.isBefore(endA);
    return overlaps;
  }

  void _showErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.red[50],
          title: Row(
            children: const [
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
        builder: (context) => BookingFailedPage(
          documentId: widget.documentId,
                          documentname: widget.documentname,
                          userId: widget.userId,
        ),
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

  Future<String> _fetchUserEmail(String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email != null && user!.email!.isNotEmpty) return user.email!;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        final email = data != null ? (data['email'] as String?) : null;
        if (email != null && email.isNotEmpty) return email;
      }
    } catch (e) {
      print('Error fetching user email: $e');
    }
    return '';
  }

  Future<String> _fetchUserPhone(String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty) return user.phoneNumber!;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        final phone = data != null ? (data['phone'] ?? data['contact']) as String? : null;
        if (phone != null && phone.isNotEmpty) return phone;
      }
    } catch (e) {
      print('Error fetching user phone: $e');
    }
    return '';
  }


  // Calculate total amount with profit and fees (confidential business logic)
  // This is what the user pays - the base amount plus company profit and platform fees
  double _calculateTotalAmount(double baseAmount) {
    if (baseAmount <= 0) {
      return 0.0; // Handle invalid amounts
    }
    
    if (baseAmount < 1000) {
      // For amounts < 1000: 100% base + 15% profit + 2% platform fee = 117%
      return (baseAmount * 1.17).roundToDouble();
    } else if (baseAmount <= 3000) {
      // For amounts 1000-3000: base + fixed ₹110 profit + 2% platform fee
      return (baseAmount + 110 + (baseAmount * 0.02)).roundToDouble();
    } else {
      // For amounts > 3000: base + fixed ₹210 profit + 2% platform fee
      return (baseAmount + 210 + (baseAmount * 0.02)).roundToDouble();
    }
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
            children: const [
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

  @override
  void dispose() {
    // Clean up animation controller
    _loadingAnimationController.dispose();
    
    // Clean up queue polling timer
    _queueCheckTimer?.cancel();
    
    // Clean up Razorpay listeners to prevent memory leaks
    try {
      _razorpay.clear(); // This removes all event listeners
    } catch (e) {
      print('Error disposing Razorpay: $e');
    }
    super.dispose();
  }
}
