import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Bookings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsSection('upcoming'),
          _buildBookingsSection('past'),
          _buildBookingsSection('cancelled'),
        ],
      ),
    );
  }

  Stream<List<DocumentSnapshot>> _fetchBookings() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Widget _buildBookingsSection(String state) {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _fetchBookings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error fetching bookings'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Image.asset(
              "lib/assets/static/undraw_empty_4zx0.png",
            ),
          );
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
          return bookingDate.isAfter(DateTime.now());
        }).toList();

        var pastBookings = filteredBookings.where((booking) {
          var bookingData = booking.data() as Map<String, dynamic>;
          var bookingDate =
              DateTime.tryParse(bookingData['bookingDate'] ?? '') ??
                  DateTime.now();
          return bookingDate.isBefore(DateTime.now());
        }).toList();

        var cancelledBookings = filteredBookings.where((booking) {
          var bookingData = booking.data() as Map<String, dynamic>;
          return bookingData['status'] == 'cancelled';
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
          return Center(
            child: SvgPicture.asset(
              'assets/static/undraw_empty_4zx0.svg', // Ensure this path is correct
              width: 200,
              height: 200,
            ),
          );
        }

        return ListView.builder(
          itemCount: displayBookings.length,
          padding:
              const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
          itemBuilder: (context, index) {
            var bookingData =
                displayBookings[index].data() as Map<String, dynamic>;
            bookingData['bookID'] = displayBookings[index].id;

            return GestureDetector(
              onLongPress: () => _enableSelectionMode(bookingData, state),
              child: Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
                                fontSize: 14,
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  bookingData['bookingDate'] ??
                                      'No Booking Date',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(
                          height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Provider',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                bookingData['provider'] ?? 'No Provider',
                                style: const TextStyle(
                                  fontSize: 12,
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
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                bookingData['price'] ?? 'No Price',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.info_outline, size: 14),
                        label: const Text('Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          minimumSize: const Size(double.infinity, 32),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          side: const BorderSide(color: Color(0xFFDCECFD)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
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
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
