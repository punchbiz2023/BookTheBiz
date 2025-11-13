import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

class MyEventsPage extends StatefulWidget {
  final User? user;
  MyEventsPage({super.key, this.user});

  @override
  _MyEventsPageState createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> with TickerProviderStateMixin {
  String searchQuery = '';
  String selectedFilter = 'All';
  bool _showCancelledOnly = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String _derivePaymentType(Map<String, dynamic> data) {
    final explicitType = (data['paymentType'] ?? data['paymentMethod'])?.toString();
    if (explicitType != null && explicitType.trim().isNotEmpty) {
      final lowered = explicitType.toLowerCase();
      if (lowered == 'free' || lowered == 'paid' || lowered == 'online' || lowered == 'offline') {
        if (lowered == 'online') {
          return (_parseDouble(data['price']) ?? 0) > 0 ? 'Paid' : 'Free';
        }
        return lowered == 'free' ? 'Free' : 'Paid';
      }
    }
    return (_parseDouble(data['price']) ?? _parseDouble(data['baseAmount']) ?? 0) > 0 ? 'Paid' : 'Free';
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatCurrency(double? amount) {
    if (amount == null) return '';
    if (amount == amount.roundToDouble()) {
      return '₹${amount.toStringAsFixed(0)}';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  DateTime? _parseEventDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
      // Handle plain YYYY-MM-DD strings (parse already covers, but fallback to DateTime components)
      try {
        final sanitized = value.replaceAll('/', '-');
        return DateTime.parse(sanitized);
      } catch (_) {}
    }
    return null;
  }

  DateTime _fallbackDateTime(Map<String, dynamic> data, {DateTime? fallback}) {
    return _parseEventDateTime(data['eventDate']) ??
        _parseEventDateTime(data['createdAt']) ??
        _parseEventDateTime(data['updatedAt']) ??
        fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'My Events',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF00838F),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Search and Filter Bar
            _buildSearchAndFilterBar(),
            // Events List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('event_registrations')
                    .where('userId', isEqualTo: widget.user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final now = DateTime.now();

                  if (_showCancelledOnly) {
                    final cancelledDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = (data['status'] ?? '').toString().toLowerCase();
                      if (status != 'cancelled') return false;
                      final eventName = (data['eventName'] ?? '').toString().toLowerCase();
                    if (searchQuery.isNotEmpty && !eventName.contains(searchQuery)) {
                      return false;
                    }
                      return true;
                    }).toList();

                    cancelledDocs.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;
                      final dateA = _parseEventDateTime(dataA['cancelledAt']) ??
                          _parseEventDateTime(dataA['updatedAt']) ??
                          _fallbackDateTime(dataA);
                      final dateB = _parseEventDateTime(dataB['cancelledAt']) ??
                          _parseEventDateTime(dataB['updatedAt']) ??
                          _fallbackDateTime(dataB);
                      return dateB.compareTo(dateA);
                    });

                    if (cancelledDocs.isEmpty) {
                      return _buildNoResultsState();
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: cancelledDocs.length,
                      itemBuilder: (context, index) {
                        final registration = cancelledDocs[index];
                        final data = registration.data() as Map<String, dynamic>;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: _buildEventTicketCard(
                            data,
                            registration.id,
                            isCancelled: true,
                          ),
                        );
                      },
                    );
                  }

                  final List<QueryDocumentSnapshot> upcoming = [];
                  final List<QueryDocumentSnapshot> past = [];

                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = (data['status'] ?? '').toString().toLowerCase();
                    if (status != 'confirmed') continue;

                    final eventName = (data['eventName'] ?? '').toString().toLowerCase();
                    if (searchQuery.isNotEmpty && !eventName.contains(searchQuery)) {
                      continue;
                    }

                    final eventDateTime = _parseEventDateTime(data['eventDate']);
                    final isUpcoming = eventDateTime != null && eventDateTime.isAfter(now);

                    if (selectedFilter == 'Upcoming' && !isUpcoming) continue;
                    if (selectedFilter == 'Past' && isUpcoming) continue;

                    if (isUpcoming) {
                      upcoming.add(doc);
                    } else {
                      past.add(doc);
                    }
                  }

                  upcoming.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;
                    final dateA = _parseEventDateTime(dataA['eventDate']) ?? _fallbackDateTime(dataA, fallback: DateTime.now());
                    final dateB = _parseEventDateTime(dataB['eventDate']) ?? _fallbackDateTime(dataB, fallback: DateTime.now());
                    return dateA.compareTo(dateB);
                  });

                  past.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;
                    final dateA = _parseEventDateTime(dataA['eventDate']) ?? _fallbackDateTime(dataA);
                    final dateB = _parseEventDateTime(dataB['eventDate']) ?? _fallbackDateTime(dataB);
                    return dateB.compareTo(dateA);
                  });

                  List<QueryDocumentSnapshot> orderedDocs;
                  if (selectedFilter == 'Upcoming') {
                    orderedDocs = upcoming;
                  } else if (selectedFilter == 'Past') {
                    orderedDocs = past;
                  } else {
                    orderedDocs = [...upcoming, ...past];
                  }

                  if (orderedDocs.isEmpty) {
                    return _buildNoResultsState();
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: orderedDocs.length,
                    itemBuilder: (context, index) {
                      final registration = orderedDocs[index];
                      final data = registration.data() as Map<String, dynamic>;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: _buildEventTicketCard(
                          data,
                          registration.id,
                          isCancelled: false,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Field
          Container(
            decoration: BoxDecoration(
              color: Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search events...',
                hintStyle: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.search, 
                  color: Color(0xFF00838F),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
          SizedBox(height: 12),
          // Filter Dropdown
          Row(
            children: [
              Expanded(
                child: Container(
            decoration: BoxDecoration(
              color: Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<String>(
              value: selectedFilter,
              decoration: InputDecoration(
                labelText: 'Filter by Status',
                labelStyle: TextStyle(
                  color: Color(0xFF00838F),
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.filter_list, 
                  color: Color(0xFF00838F),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              items: ['All', 'Upcoming', 'Past'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: Color(0xFF424242),
                      fontSize: 16,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedFilter = newValue!;
                        _showCancelledOnly = false;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: _showCancelledOnly ? const Color(0xFFFFEBEE) : const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showCancelledOnly ? const Color(0xFFE53935) : const Color(0xFFFFCDD2),
                    width: 1.2,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.delete_sweep_rounded,
                    color: _showCancelledOnly ? const Color(0xFFC62828) : const Color(0xFFE53935),
                  ),
                  tooltip: _showCancelledOnly ? 'Show active bookings' : 'View cancelled bookings',
                  onPressed: () {
                    setState(() {
                      _showCancelledOnly = !_showCancelledOnly;
                      if (_showCancelledOnly) {
                        selectedFilter = 'All';
                      }
                });
              },
            ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelRegistrationSheet(
      Map<String, dynamic> registrationData,
      String registrationId,
      bool isPaid,
      bool isUpcoming) async {
    if (!isUpcoming) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final price = _parseDouble(registrationData['price']) ??
            _parseDouble(registrationData['baseAmount']) ??
            0;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 16),
              Icon(
                Icons.cancel_schedule_send_rounded,
                color: isPaid ? const Color(0xFFFF7043) : const Color(0xFFD32F2F),
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                'Cancel Event Booking?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPaid
                    ? 'You will receive a refund within 3-5 business days once admin processes the request.'
                    : 'This will release your spot for other participants.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (isPaid && price > 0) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.payments, color: Color(0xFFFFA726)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Amount to refund: ${_formatCurrency(price)}',
                          style: const TextStyle(
                            color: Color(0xFFEF6C00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Keep Booking'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _cancelEventRegistration(
                          registrationData,
                          registrationId,
                          isPaid,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Yes, Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cancelEventRegistration(
      Map<String, dynamic> registrationData,
      String registrationId,
      bool isPaid) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('event_registrations')
          .doc(registrationId);
      final currentSnap = await docRef.get();
      if (!currentSnap.exists) {
        throw Exception('Registration not found.');
      }
      final currentData = currentSnap.data() as Map<String, dynamic>;
      final currentStatus =
          (currentData['status'] ?? '').toString().toLowerCase();
      if (currentStatus == 'cancelled') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This booking has already been cancelled.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (currentData['refundRequestId'] != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refund request already submitted for this booking.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (isPaid) {
        final refundFn =
            FirebaseFunctions.instance.httpsCallable('createEventRefundRequest');
        await refundFn({
          'registrationId': registrationId,
          'userId': widget.user?.uid,
          'eventId': registrationData['eventId'],
          'amount': registrationData['price'],
          'paymentId': registrationData['razorpayPaymentId'],
          'reason': 'User requested cancellation',
          'eventDate': registrationData['eventDate'],
          'eventName': registrationData['eventName'],
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Event booking cancelled. Refund request sent to admin.'),
            backgroundColor: Colors.deepOrange,
          ),
        );
      } else {
        await docRef.update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event booking cancelled.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEventTicketCard(
      Map<String, dynamic> registrationData,
      String registrationId,
      {bool isCancelled = false}) {
    final eventDate = registrationData['eventDate'];
    DateTime? eventDateTime;
    bool isUpcoming = true;
    final paymentType = _derivePaymentType(registrationData);
    final price = _parseDouble(registrationData['price']) ??
        _parseDouble(registrationData['baseAmount']) ??
        0;
    final bool isPaid = paymentType == 'Paid' && price > 0;
    final statusValue =
        (registrationData['status'] ?? '').toString().toLowerCase();
    final bool isCancelledStatus = isCancelled || statusValue == 'cancelled';
    
    if (eventDate != null) {
      if (eventDate is Timestamp) {
        eventDateTime = eventDate.toDate();
      } else {
        eventDateTime = DateTime.parse(eventDate.toString());
      }
      isUpcoming = eventDateTime.isAfter(DateTime.now());
    }
    if (isCancelledStatus) {
      isUpcoming = false;
    }

    return Container(
      decoration: BoxDecoration(
        color: isCancelledStatus ? const Color(0xFFFFEBEE) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isCancelledStatus
                ? Colors.red.withOpacity(0.08)
                : Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Ticket Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCancelledStatus
                    ? [const Color(0xFFFF8A80), const Color(0xFFD32F2F)]
                    : [const Color(0xFF00838F), const Color(0xFF26A69A)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCancelledStatus
                        ? const Color(0xFFC62828)
                        : (isUpcoming
                            ? const Color(0xFF00C853)
                            : const Color(0xFF757575)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCancelledStatus
                        ? 'CANCELLED'
                        : (isUpcoming ? 'UPCOMING' : 'PAST'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Spacer(),
                Icon(
                  isCancelledStatus ? Icons.cancel : Icons.confirmation_number,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
          // Ticket Perforation
          Container(
            height: 20,
            child: Row(
              children: List.generate(
                30,
                (index) => Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: index % 2 == 0 
                          ? Color(0xFFE0E0E0) 
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Ticket Body
          Container(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Name
                Text(
                  registrationData['eventName'] ?? 'Event',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Color(0xFF212121),
                    letterSpacing: 0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 16),
                // Event Info
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        Icons.calendar_today, 
                        _formatEventDate(registrationData['eventDate']),
                        'Date',
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoItem(
                        Icons.access_time, 
                        _formatEventTime(registrationData['eventTime']),
                        'Time',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        Icons.payments, 
                        isPaid
                            ? '$paymentType - ${_formatCurrency(price)}'
                            : paymentType,
                        'Payment',
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoItem(
                        Icons.app_registration,
                        _formatEventDate(
                          registrationData['registeredAt'] ??
                              registrationData['createdAt'] ??
                              registrationData['updatedAt'],
                        ),
                        'Registered',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _navigateToEventDetails(registrationData, registrationId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF00838F),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.visibility, size: 18),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _navigateToRegistrationInfo(registrationData, registrationId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF00838F),
                          side: BorderSide(color: Color(0xFF00838F)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Registration'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (isUpcoming && !isCancelledStatus) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                  child: OutlinedButton.icon(
                      onPressed: () => _showCancelRegistrationSheet(
                        registrationData,
                        registrationId,
                        isPaid,
                        isUpcoming,
                      ),
                      icon: const Icon(Icons.cancel),
                      label: const Text(
                        'Cancel Booking',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD32F2F),
                        side: const BorderSide(color: Color(0xFFD32F2F)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Color(0xFF00838F),
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Color(0xFF757575),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Color(0xFF424242),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF00838F),
          ),
          SizedBox(height: 24),
          Text(
            'Loading Your Events...',
            style: TextStyle(
              color: Color(0xFF00838F),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Color(0xFFD32F2F),
            size: 48,
          ),
          SizedBox(height: 24),
          Text(
            'Error Loading Events',
            style: TextStyle(
              color: Color(0xFFD32F2F),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: Color(0xFFD32F2F),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80,
            color: Color(0xFF00838F),
          ),
          SizedBox(height: 32),
          Text(
            'No Events Registered Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00838F),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Register for events to see them here',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Color(0xFF00838F),
          ),
          SizedBox(height: 32),
          Text(
            'No Events Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00838F),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Try adjusting your search or filter',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEventDetails(Map<String, dynamic> registrationData, String registrationId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventDetailsPage(
          registrationData: registrationData,
          registrationId: registrationId,
        ),
      ),
    );
  }

  void _navigateToRegistrationInfo(Map<String, dynamic> registrationData, String registrationId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RegistrationInfoPage(
          registrationData: registrationData,
          registrationId: registrationId,
        ),
      ),
    );
  }

  String _formatEventDate(dynamic date) {
    DateTime? dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is DateTime) {
      dateTime = date;
    } else if (date is String && date.isNotEmpty) {
      dateTime = DateTime.tryParse(date);
    }
    if (dateTime == null) return date?.toString() ?? 'N/A';
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  String _formatEventTime(dynamic time) {
    if (time == null) return 'TBA';
    
    if (time is Timestamp) {
      final dateTime = time.toDate();
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      
      return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
    }
    
    // If it's a string in 24-hour format (HH:MM)
    if (time is String) {
      try {
        final parts = time.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          
          final period = hour >= 12 ? 'PM' : 'AM';
          final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
          
          return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
        }
      } catch (e) {
        print('Error parsing time: $e');
      }
    }
    
    return time.toString();
  }
}

class EventDetailsPage extends StatelessWidget {
  final Map<String, dynamic> registrationData;
  final String registrationId;

  const EventDetailsPage({
    super.key,
    required this.registrationData,
    required this.registrationId,
  });

  String get _eventPaymentType {
    final rawType = (registrationData['paymentType'] ?? registrationData['paymentMethod'])?.toString().trim();
    if (rawType != null && rawType.isNotEmpty) {
      final lowered = rawType.toLowerCase();
      if (lowered == 'free') return 'Free';
      if (lowered == 'paid') return 'Paid';
    }
    final price = _eventPrice ?? 0;
    return price > 0 ? 'Paid' : 'Free';
  }

  double? get _eventPrice {
    final price = _tryParseDouble(registrationData['price']);
    if (price != null) return price;
    return _tryParseDouble(registrationData['baseAmount']);
  }

  double? _tryParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatCurrency(double amount) {
    if (amount == amount.roundToDouble()) {
      return '₹${amount.toStringAsFixed(0)}';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Event Details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF00838F),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEventHeader(),
            SizedBox(height: 24),
            _buildEventInfoCard(),
            SizedBox(height: 24),
            _buildEventDescriptionCard(),
            SizedBox(height: 24),
            _buildEventActionsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEventHeader() {
    final eventDate = registrationData['eventDate'];
    DateTime? eventDateTime;
    bool isUpcoming = true;
    
    if (eventDate != null) {
      if (eventDate is Timestamp) {
        eventDateTime = eventDate.toDate();
      } else {
        eventDateTime = DateTime.parse(eventDate.toString());
      }
      isUpcoming = eventDateTime.isAfter(DateTime.now());
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isUpcoming 
                      ? Color(0xFF00C853) 
                      : Color(0xFF757575),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isUpcoming ? 'UPCOMING' : 'PAST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Spacer(),
              Icon(Icons.confirmation_number, color: Color(0xFF00838F), size: 28),
            ],
          ),
          SizedBox(height: 16),
          Text(
            registrationData['eventName'] ?? 'Event',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF212121),
              letterSpacing: 0.3,
            ),
          ),
          if (isUpcoming && eventDateTime != null) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF0F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFB2EBF2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event Countdown',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00838F),
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  EventCountdown(eventDateTime: eventDateTime),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventInfoCard() {
    final paymentType = _eventPaymentType;
    final price = _eventPrice;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF00838F),
            ),
          ),
          SizedBox(height: 16),
          _buildDetailRow(
            Icons.calendar_today,
            'Date',
            _formatEventDate(registrationData['eventDate']),
          ),
          SizedBox(height: 12),
          if (registrationData['eventTime'] != null)
            _buildDetailRow(
              Icons.access_time,
              'Time',
              _formatEventTime(registrationData['eventTime']),
            ),
          SizedBox(height: 12),
          _buildDetailRow(
            Icons.payments,
            'Payment Type',
            paymentType,
          ),
          if (paymentType == 'Paid' && price != null)
            _buildDetailRow(
              Icons.attach_money,
              'Price',
              _formatCurrency(price),
            ),
        ],
      ),
    );
  }

  Widget _buildEventDescriptionCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About This Event',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF00838F),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'This is an exciting event that you have registered for. Please make sure to attend on time and bring any necessary items mentioned by the organizers.',
            style: TextStyle(
              color: Color(0xFF616161),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventActionsCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF00838F),
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00838F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back, size: 20),
                  SizedBox(width: 8),
                  Text('Back to My Events'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFFF0F9FA),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Color(0xFF00838F), size: 20),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF757575),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: Color(0xFF424242),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatEventDate(dynamic date) {
    DateTime? dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is DateTime) {
      dateTime = date;
    } else if (date is String && date.isNotEmpty) {
      dateTime = DateTime.tryParse(date);
    }

    if (dateTime == null) {
      return date?.toString() ?? 'N/A';
    }

    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  String _formatEventTime(dynamic time) {
    if (time == null) return 'TBA';
    
    if (time is Timestamp) {
      final dateTime = time.toDate();
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      
      return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
    }
    
    // If it's a string in 24-hour format (HH:MM)
    if (time is String) {
      try {
        final parts = time.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          
          final period = hour >= 12 ? 'PM' : 'AM';
          final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
          
          return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
        }
      } catch (e) {
        print('Error parsing time: $e');
      }
    }
    
    return time.toString();
  }
}

class RegistrationInfoPage extends StatelessWidget {
  final Map<String, dynamic> registrationData;
  final String registrationId;

  const RegistrationInfoPage({
    super.key,
    required this.registrationData,
    required this.registrationId,
  });

  bool get _isCancelled {
    final status = (registrationData['status'] ?? '').toString().toLowerCase();
    return status == 'cancelled';
  }

  String get _registrationPaymentType {
    final rawType = (registrationData['paymentType'] ?? registrationData['paymentMethod'])?.toString().trim();
    if (rawType != null && rawType.isNotEmpty) {
      final lowered = rawType.toLowerCase();
      if (lowered == 'free') return 'Free';
      if (lowered == 'paid') return 'Paid';
    }
    final price = _registrationPrice ?? 0;
    return price > 0 ? 'Paid' : 'Free';
  }

  double? get _registrationPrice {
    final price = _tryParseDouble(registrationData['price']);
    if (price != null) return price;
    return _tryParseDouble(registrationData['baseAmount']);
  }

  double? _tryParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatCurrency(double amount) {
    if (amount == amount.roundToDouble()) {
      return '₹${amount.toStringAsFixed(0)}';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Registration Details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF00838F),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRegistrationStatusCard(),
            SizedBox(height: 24),
            _buildRegistrationDetailsCard(),
            SizedBox(height: 24),
            _buildNextStepsCard(),
            SizedBox(height: 24),
            _buildActionCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationStatusCard() {
    final Color accentColor = _isCancelled ? const Color(0xFFD32F2F) : const Color(0xFF00C853);
    final Color bgColor = _isCancelled ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9);
    final String title = _isCancelled ? 'Registration Status' : 'Registration Status';
    final String subtitle = _isCancelled ? 'Booking Cancelled' : 'Successfully Registered';

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isCancelled ? Icons.cancel_rounded : Icons.check_circle,
              color: accentColor,
              size: 32,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF757575),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                if (_isCancelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      _registrationPaymentType == 'Paid'
                          ? 'Refund request will reflect once reviewed by admin.'
                          : 'This registration is no longer active.'
                      ,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationDetailsCard() {
    final paymentType = _registrationPaymentType;
    final price = _registrationPrice;
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registration Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF00838F),
            ),
          ),
          SizedBox(height: 16),
          _buildDetailRow(Icons.confirmation_number, 'Event Name', registrationData['eventName'] ?? 'N/A'),
          SizedBox(height: 12),
          _buildDetailRow(Icons.calendar_today, 'Event Date', _formatEventDate(registrationData['eventDate'])),
          SizedBox(height: 12),
          if (registrationData['eventTime'] != null)
            _buildDetailRow(Icons.access_time, 'Event Time', _formatEventTime(registrationData['eventTime'])),
          SizedBox(height: 12),
          _buildDetailRow(Icons.payments, 'Payment Type', paymentType),
          SizedBox(height: 12),
          if (paymentType == 'Paid' && price != null)
            _buildDetailRow(Icons.attach_money, 'Price', _formatCurrency(price)),
          SizedBox(height: 12),
          _buildDetailRow(
            Icons.app_registration,
            'Registration Date',
            _formatEventDate(
              registrationData['registeredAt'] ??
                  registrationData['createdAt'] ??
                  registrationData['updatedAt'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepsCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isCancelled ? const Color(0xFFFFEBEE) : const Color(0xFFF0F9FA),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isCancelled ? Icons.info_outline : Icons.next_plan,
                  color: _isCancelled ? const Color(0xFFD32F2F) : const Color(0xFF00838F),
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                _isCancelled ? 'Cancellation Notes' : 'Next Steps',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _isCancelled ? const Color(0xFFD32F2F) : const Color(0xFF00838F),
                  fontSize: 20,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_isCancelled) ...[
            _buildStepItem(
              _registrationPaymentType == 'Paid'
                  ? 'Refund request submitted. Admin will process within 3-5 business days.'
                  : 'Your spot has been released to other participants.',
            ),
            SizedBox(height: 12),
            _buildStepItem('Need help? Reach out via Support anytime.'),
          ] else ...[
          _buildStepItem('Event organizers will contact you with further details'),
          SizedBox(height: 12),
          _buildStepItem('Check your email for confirmation'),
          SizedBox(height: 12),
          _buildStepItem('Arrive on time for the event'),
          SizedBox(height: 12),
          _buildStepItem('Bring any required items mentioned by organizers'),
          ],
        ],
      ),
    );
  }

  Widget _buildStepItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(top: 2),
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _isCancelled ? const Color(0xFFFFEBEE) : const Color(0xFFF0F9FA),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isCancelled ? Icons.info_outline : Icons.check,
            color: _isCancelled ? const Color(0xFFD32F2F) : const Color(0xFF00838F),
            size: 16,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF00838F),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(vertical: 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back, size: 20),
              SizedBox(width: 8),
              Text('Back to My Events'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFFF0F9FA),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Color(0xFF00838F), size: 20),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF757575),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: Color(0xFF424242),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatEventDate(dynamic date) {
    DateTime? dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is DateTime) {
      dateTime = date;
    } else if (date is String && date.isNotEmpty) {
      dateTime = DateTime.tryParse(date);
    }

    if (dateTime == null) {
      return date?.toString() ?? 'N/A';
    }

    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  String _formatEventTime(dynamic time) {
    if (time == null) return 'TBA';
    
    if (time is Timestamp) {
      final dateTime = time.toDate();
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      
      return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
    }
    
    // If it's a string in 24-hour format (HH:MM)
    if (time is String) {
      try {
        final parts = time.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          
          final period = hour >= 12 ? 'PM' : 'AM';
          final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
          
          return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
        }
      } catch (e) {
        print('Error parsing time: $e');
      }
    }
    
    return time.toString();
  }
}

class EventCountdown extends StatefulWidget {
  final DateTime eventDateTime;

  const EventCountdown({super.key, required this.eventDateTime});

  @override
  _EventCountdownState createState() => _EventCountdownState();
}

class _EventCountdownState extends State<EventCountdown> {
  late Timer _timer;
  late Duration _timeUntilEvent;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    final now = DateTime.now();
    setState(() {
      _timeUntilEvent = widget.eventDateTime.difference(now);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeUntilEvent.isNegative) {
      return Text(
        'Event has started',
        style: TextStyle(
          color: Color(0xFF00C853),
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      );
    }

    final days = _timeUntilEvent.inDays;
    final hours = _timeUntilEvent.inHours % 24;
    final minutes = _timeUntilEvent.inMinutes % 60;
    final seconds = _timeUntilEvent.inSeconds % 60;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildCountdownItem('Days', days.toString()),
        _buildCountdownItem('Hours', hours.toString().padLeft(2, '0')),
        _buildCountdownItem('Minutes', minutes.toString().padLeft(2, '0')),
        _buildCountdownItem('Seconds', seconds.toString().padLeft(2, '0')),
      ],
    );
  }

  Widget _buildCountdownItem(String label, String value) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                spreadRadius: 0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF00838F),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF757575),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}