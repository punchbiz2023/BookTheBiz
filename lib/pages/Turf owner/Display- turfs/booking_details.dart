import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bkuserdetails.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class BookingDetailsPage extends StatefulWidget {
  final String turfId;

  const BookingDetailsPage({super.key, required this.turfId, required Map bookingData});

  @override
  _BookingDetailsPageState createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedDate;
  String _sortOrder = 'Ascending'; // Default sort order

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate != null ? DateTime.parse(_selectedDate!) : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked.toIso8601String(); // Store selected date as ISO string
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedDate = null;
    });
  }

  Widget _buildGlassCard({required Widget child, double? height, Color? accentColor}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (accentColor ?? Colors.teal).withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: (accentColor ?? Colors.teal).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchField(),
            const SizedBox(height: 16.0),
            _buildFilterRow(),
            const SizedBox(height: 16.0),
            Expanded(child: _buildBookingList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return _buildGlassCard(
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          labelText: 'Search Bookings',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: Colors.teal),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          labelStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        Expanded(flex: 2, child: _buildSortDropdown()),
        const SizedBox(width: 12),
        _buildDateButton(),
        const SizedBox(width: 12),
        _buildClearFiltersButton(),
      ],
    );
  }

  Widget _buildSortDropdown() {
    return _buildGlassCard(
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            value: _sortOrder,
            icon: Icon(Icons.filter_list, color: Colors.teal),
            style: TextStyle(color: Colors.black87, fontSize: 14),
            onChanged: (String? newValue) {
              setState(() {
                _sortOrder = newValue!;
              });
            },
            items: const [
              DropdownMenuItem<String>(
                value: 'Ascending',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, color: Colors.teal, size: 18),
                    SizedBox(width: 8),
                    Text('Old to New'),
                  ],
                ),
              ),
              DropdownMenuItem<String>(
                value: 'Descending',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, color: Colors.teal, size: 18),
                    SizedBox(width: 8),
                    Text('New to Old'),
                  ],
                ),
              ),
            ],
            dropdownColor: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Icon(
              Icons.calendar_today,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearFiltersButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _clearFilters,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Icon(
              Icons.refresh,
              color: Colors.teal,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('turfs')
          .doc(widget.turfId)
          .collection('bookings')
          .orderBy('bookingDate', descending: _sortOrder == 'Descending')
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> bookingSnapshot) {
        if (bookingSnapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                      strokeWidth: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading bookings...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        if (bookingSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(Icons.error_outline, size: 30, color: Colors.red),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading bookings',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        if (!bookingSnapshot.hasData || bookingSnapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(Icons.event_busy, size: 30, color: Colors.teal),
                ),
                const SizedBox(height: 16),
                Text(
                  'No bookings available',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        // Get the current date for comparison
        final currentDate = DateTime.now();

        // Filter bookings based on the search query and selected date
        var filteredBookings = bookingSnapshot.data!.docs.where((doc) {
          var bookingData = doc.data() as Map<String, dynamic>;
          bool matchesSearch = bookingData['userName']?.toLowerCase().contains(_searchQuery) ?? false;

          // Check if booking has a bookingDate (not cancelled)
          if (bookingData['bookingDate'] != null) {
            if (_selectedDate != null) {
              return matchesSearch && bookingData['bookingDate'].startsWith(_selectedDate!.split('T')[0]);
            }
            return matchesSearch;
          } else {
            // For cancelled bookings, only apply search filter
            return matchesSearch;
          }
        }).toList();

        // Separate bookings into categories
        var activeBookings = filteredBookings.where((doc) {
          var bookingData = doc.data() as Map<String, dynamic>;
          // Check if booking is cancelled (empty bookingSlots or status is "cancelled")
          if (bookingData['status'] == 'cancelled' || 
              (bookingData['bookingSlots'] is List && (bookingData['bookingSlots'] as List).isEmpty)) {
            return false;
          }
          
          // Only consider bookings with bookingDate for active/past categorization
          if (bookingData['bookingDate'] == null) return false;
          
          final bookingDate = DateTime.parse(bookingData['bookingDate']);
          return bookingDate.isAfter(currentDate) || bookingDate.isAtSameMomentAs(currentDate);
        }).toList();

        var pastBookings = filteredBookings.where((doc) {
          var bookingData = doc.data() as Map<String, dynamic>;
          // Check if booking is cancelled (empty bookingSlots or status is "cancelled")
          if (bookingData['status'] == 'cancelled' || 
              (bookingData['bookingSlots'] is List && (bookingData['bookingSlots'] as List).isEmpty)) {
            return false;
          }
          
          // Only consider bookings with bookingDate for active/past categorization
          if (bookingData['bookingDate'] == null) return false;
          
          final bookingDate = DateTime.parse(bookingData['bookingDate']);
          return bookingDate.isBefore(currentDate);
        }).toList();

        var cancelledBookings = filteredBookings.where((doc) {
          var bookingData = doc.data() as Map<String, dynamic>;
          // Bookings with empty bookingSlots array or status "cancelled" are considered cancelled
          return (bookingData['status'] == 'cancelled') || 
                 (bookingData['bookingSlots'] is List && (bookingData['bookingSlots'] as List).isEmpty);
        }).toList();

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            if (activeBookings.isNotEmpty) ...[
              _buildSectionHeader('Active Bookings', Icons.event_available, Colors.teal),
              const SizedBox(height: 12),
              ...activeBookings.map((doc) {
                var bookingData = doc.data() as Map<String, dynamic>;
                return _buildBookingCard(bookingData, doc.id, 'active');
              }),
              const SizedBox(height: 24),
            ],
            if (pastBookings.isNotEmpty) ...[
              _buildSectionHeader('Past Bookings', Icons.history, Colors.grey),
              const SizedBox(height: 12),
              ...pastBookings.map((doc) {
                var bookingData = doc.data() as Map<String, dynamic>;
                return _buildBookingCard(bookingData, doc.id, 'past');
              }),
              const SizedBox(height: 24),
            ],
            if (cancelledBookings.isNotEmpty) ...[
              _buildSectionHeader('Cancelled Bookings', Icons.cancel, Colors.red),
              const SizedBox(height: 12),
              ...cancelledBookings.map((doc) {
                var bookingData = doc.data() as Map<String, dynamic>;
                return _buildBookingCard(bookingData, doc.id, 'cancelled');
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> bookingData, String bookingId, String status) {
    Color accentColor;
    String statusText;
    IconData statusIcon;
    
    switch (status) {
      case 'active':
        accentColor = Colors.teal;
        statusText = 'Active';
        statusIcon = Icons.event_available;
        break;
      case 'past':
        accentColor = Colors.grey;
        statusText = 'Completed';
        statusIcon = Icons.history;
        break;
      case 'cancelled':
        accentColor = Colors.red;
        statusText = 'Cancelled';
        statusIcon = Icons.cancel;
        break;
      default:
        accentColor = Colors.teal;
        statusText = 'Unknown';
        statusIcon = Icons.help_outline;
    }

    String formattedDate = '';
    if (bookingData['bookingDate'] != null) {
      final bookingDate = DateTime.parse(bookingData['bookingDate']);
      formattedDate = DateFormat('EEE, MMM d, yyyy').format(bookingDate);
    }
    
    // Get the cancelled slot timing from bookingStatus if available
    String cancelledSlot = '';
    if (status == 'cancelled' && bookingData['bookingStatus'] is List && bookingData['bookingStatus'].isNotEmpty) {
      cancelledSlot = bookingData['bookingStatus'][0].toString();
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => bkUserDetails(
                      bookingId: bookingId,
                      userId: bookingData['userId'],
                      turfId: widget.turfId,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bookingData['userName'] ?? 'Unknown User',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accentColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusIcon,
                                size: 14,
                                color: accentColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Show date if available
                    if (bookingData['bookingDate'] != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    // Show time slots or cancelled slot
                    if (status != 'cancelled' && bookingData['bookingSlots'] != null && bookingData['bookingSlots'].isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${bookingData['bookingSlots'].join(', ')}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ] else if (status == 'cancelled' && cancelledSlot.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cancelled Slot: $cancelledSlot',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Ground and amount row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.sports_soccer,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              bookingData['selectedGround'] ?? 'Not specified',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₹${bookingData['amount']?.toStringAsFixed(2) ?? '0.00'}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: status == 'cancelled' ? Colors.red : accentColor,
                          ),
                        ),
                      ],
                    ),
                    
                    // Show refund status for cancelled bookings
                    if (status == 'cancelled' && bookingData['payoutStatus'] != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.replay,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Refund: ${bookingData['payoutStatus']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}