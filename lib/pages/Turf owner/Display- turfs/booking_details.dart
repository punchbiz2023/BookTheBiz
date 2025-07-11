import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bkuserdetails.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchField(),
            SizedBox(height: 16.0),
            _buildFilterRow(), // Using the custom filter row
            SizedBox(height: 16.0),
            Expanded(child: _buildBookingList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value.toLowerCase();
        });
      },
      decoration: InputDecoration(
        labelText: 'Search Bookings',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        prefixIcon: Icon(Icons.search, color: Colors.teal),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSortDropdown(),
        SizedBox(width: 10), // Space between dropdown and button
        _buildDateButton(),
        SizedBox(width: 10),
        _buildClearFiltersButton(),
      ],
    );
  }

  Widget _buildSortDropdown() {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30), // Rounded corners
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _sortOrder,
            icon: Icon(Icons.filter_list, color: Colors.teal),
            style: TextStyle(color: Colors.black, fontSize: 16),
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
                    Icon(Icons.arrow_upward, color: Colors.teal),
                    SizedBox(width: 5),
                    Text('Old to New'),
                  ],
                ),
              ),
              DropdownMenuItem<String>(
                value: 'Descending',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, color: Colors.teal),
                    SizedBox(width: 5),
                    Text('New to Old'),
                  ],
                ),
              ),
            ],
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton() {
    return ElevatedButton.icon(
      onPressed: () => _selectDate(context),
      icon: Icon(Icons.calendar_today, color: Colors.white),
      label: Text(''),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30), // Rounded corners
        ),
        elevation: 5, // Add elevation for a shadow effect
      ),
    );
  }

  Widget _buildClearFiltersButton() {
    return ElevatedButton(
      onPressed: _clearFilters,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero, // Remove extra padding to fit the button around the icon
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center the icon and text
        children: const [
          Icon(
            Icons.clear_all,
            color: Colors.teal,
            size: 24, // Adjust size as needed
          ),
          SizedBox(width: 8), // Space between the icon and the text
          Text(''), // Added text for clarity
        ],
      ),
    );
  }

  Widget _buildBookingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('turfs')
          .doc(widget.turfId)
          .collection('bookings')
          .orderBy('bookingDate', descending: _sortOrder == 'Descending') // Use selected sort order
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> bookingSnapshot) {
        if (bookingSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (bookingSnapshot.hasError) {
          return Center(child: Text('Error loading bookings.'));
        }

        if (!bookingSnapshot.hasData || bookingSnapshot.data!.docs.isEmpty) {
          return Center(child: Text('No bookings available.'));
        }

        // Get the current date for comparison
        final currentDate = DateTime.now();

        // Filter bookings based on the search query and selected date
        var filteredBookings = bookingSnapshot.data!.docs.where((doc) {
          var bookingData = doc.data() as Map<String, dynamic>;
          final bookingDate = DateTime.parse(bookingData['bookingDate']);
          bool matchesSearch = bookingData['userName']?.toLowerCase().contains(_searchQuery) ?? false;

          if (_selectedDate != null) {
            return matchesSearch && bookingData['bookingDate'].startsWith(_selectedDate!.split('T')[0]);
          }
          return matchesSearch;
        }).toList();

        // Separate bookings into past and active
        var pastBookings = filteredBookings.where((doc) {
          var bookingData = doc.data() as Map<String, dynamic>;
          final bookingDate = DateTime.parse(bookingData['bookingDate']);
          return bookingDate.isBefore(currentDate);
        }).toList();

        var activeBookings = filteredBookings.where((doc) {
          var bookingData = doc.data() as Map<String, dynamic>;
          final bookingDate = DateTime.parse(bookingData['bookingDate']);
          return bookingDate.isAfter(currentDate) || bookingDate.isAtSameMomentAs(currentDate);
        }).toList();

        return ListView(
          children: [
            if (activeBookings.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Active Bookings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20,color:Colors.teal),
                ),
              ),
              ...activeBookings.map((doc) {
                var bookingData = doc.data() as Map<String, dynamic>;
                return _buildBookingCard(bookingData, doc.id);
              }),
            ],
            if (pastBookings.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Past Bookings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20,color: Colors.teal),
                ),
              ),
              ...pastBookings.map((doc) {
                var bookingData = doc.data() as Map<String, dynamic>;
                return _buildBookingCard(bookingData, doc.id);
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> bookingData, String bookingId) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.0),
        title: Text(
          bookingData['userName'] ?? 'Unknown User',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          'Date: ${bookingData['bookingDate']}\n',
          style: TextStyle(color: Colors.black54),
        ),
        trailing: Text(
          '₹${bookingData['amount']?.toStringAsFixed(2) ?? '0.00'}',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
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
      ),
    );
  }

}
