import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:odp/pages/Turf%20owner/Display-%20turfs/bkuserdetails.dart';
import 'package:odp/pages/bkdetails.dart';

class BookingsPage extends StatefulWidget {
  @override
  _BookingsPageState createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage>
    with SingleTickerProviderStateMixin {
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  late TabController _tabController;
  bool selectionMode = false;
  List<Map<String, dynamic>> selectedBookings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<DocumentSnapshot>> _fetchBookings() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(110),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade700, Colors.teal.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.18),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Colors.white, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'My Bookings',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          letterSpacing: 1.1,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white, // Underline color
                  indicatorWeight: 3.5,         // Underline thickness
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  tabs: const [
                    Tab(text: 'Upcoming'),
                    Tab(text: 'Past'),
                    Tab(text: 'Cancelled'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 350),
        child: TabBarView(
          controller: _tabController,
          physics: BouncingScrollPhysics(),
          children: [
            _buildBookingsSection('upcoming'),
            _buildBookingsSection('past'),
            _buildBookingsSection('cancelled'),
          ],
        ),
      ),
      floatingActionButton: selectionMode
          ? FloatingActionButton.extended(
              backgroundColor: Colors.red.shade600,
              icon: Icon(Icons.delete),
              label: Text('Delete (${selectedBookings.length})'),
              onPressed: _deleteSelectedBookings,
            )
          : null,
    );
  }

  Widget _buildBookingsSection(String state) {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _fetchBookings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: CircularProgressIndicator(
                color: Colors.teal,
                strokeWidth: 3,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error fetching bookings',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        var bookings = snapshot.data!;
        var filteredBookings = bookings.where((booking) {
          var bookingData = booking.data() as Map<String, dynamic>;
          return bookingData['userId'] == _currentUserId;
        }).toList();

        var upcomingBookings = filteredBookings.where((booking) {
          var bookingData = booking.data() as Map<String, dynamic>;
          var bookingDate =
              DateTime.tryParse(bookingData['bookingDate'] ?? '') ??
                  DateTime.now();
          return bookingDate.isAfter(DateTime.now()) &&
              (bookingData['bookingSlots']?.isNotEmpty ?? false) &&
              (bookingData['status'] != 'cancelled');
        }).toList();

        var pastBookings = filteredBookings.where((booking) {
          var bookingData = booking.data() as Map<String, dynamic>;
          var bookingDate =
              DateTime.tryParse(bookingData['bookingDate'] ?? '') ??
                  DateTime.now();
          return bookingDate.isBefore(DateTime.now()) &&
              (bookingData['bookingSlots']?.isNotEmpty ?? false) &&
              (bookingData['status'] != 'cancelled');
        }).toList();

        var cancelledBookings = filteredBookings.where((booking) {
          var bookingData = booking.data() as Map<String, dynamic>;
          return bookingData['status'] == 'cancelled' ||
              (bookingData['bookingSlots']?.isEmpty ?? true);
        }).toList();

        List<DocumentSnapshot> displayBookings = [];
        if (state == 'upcoming') {
          displayBookings = upcomingBookings;
        } else if (state == 'past') {
          displayBookings = pastBookings;
        } else if (state == 'cancelled') {
          displayBookings = cancelledBookings;
        }

        if (displayBookings.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          itemCount: displayBookings.length,
          padding: const EdgeInsets.only(top: 18, left: 12, right: 12, bottom: 80),
          separatorBuilder: (context, index) => SizedBox(height: 14),
          itemBuilder: (context, index) {
            var bookingData =
                displayBookings[index].data() as Map<String, dynamic>;
            bookingData['bookID'] = displayBookings[index].id;

            return Hero(
              tag: 'booking_${bookingData['bookID']}',
              child: GestureDetector(
                onLongPress: () => _enableSelectionMode(bookingData, state),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: selectionMode && selectedBookings.any((b) => b['bookID'] == bookingData['bookID'])
                        ? Colors.teal.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.07),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: selectionMode && selectedBookings.any((b) => b['bookID'] == bookingData['bookID'])
                          ? Colors.teal
                          : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                bookingData['turfName'] ?? 'No Turf Name',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.teal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(
                                status: bookingData['status'] ?? 'Confirmed'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              bookingData['bookingDate'] ?? 'No Booking Date',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Provider',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bookingData['provider'] ?? 'No Provider',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Price',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bookingData['price'] ?? 'No Price',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookingDetailsPage1(
                                  bookingData: bookingData,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text('Details'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal.shade700,
                            minimumSize: const Size(double.infinity, 36),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            side: const BorderSide(color: Color(0xFFDCECFD)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 350),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SvgPicture.asset(
                'assets/static/undraw_empty_4zx0.svg',
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No bookings found',
              style: TextStyle(
                color: Colors.teal.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'You have no bookings in this category.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _enableSelectionMode(
      Map<String, dynamic> bookingData, String bookingType) {
    setState(() {
      selectionMode = true;
      selectedBookings.add({
        'bookID': bookingData['bookID'],
        'data': bookingData,
        'type': bookingType,
      });
    });
  }

  void _resetSelectedBookings() {
    setState(() {
      selectedBookings.clear();
      selectionMode = false;
    });
  }

  void _deleteSelectedBookings() async {
    bool deletionSuccessful = true;

    for (var booking in selectedBookings) {
      String bookID = booking['bookID'];

      try {
        var bookingRef =
            FirebaseFirestore.instance.collection('bookings').doc(bookID);
        await bookingRef.delete();
        print('Booking with ID: $bookID has been deleted successfully');
      } catch (e) {
        print('Failed to delete booking with ID: $bookID');
        deletionSuccessful = false;
      }
    }

    if (deletionSuccessful) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selected bookings have been deleted successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Some bookings failed to delete')),
      );
    }

    setState(() {
      selectionMode = false;
      selectedBookings.clear();
    });
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({
    Key? key,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label = status[0].toUpperCase() + status.substring(1);

    switch (status) {
      case 'confirmed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'pending':
        color = Colors.amber;
        icon = Icons.error;
        break;
      case 'completed':
        color = Colors.blue;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.green;
        icon = Icons.check_box_sharp;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
