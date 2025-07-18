import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class bkUserDetails extends StatelessWidget {
  final String bookingId; // Booking ID
  final String userId; // User ID
  final String turfId; // Turf ID

  // Constructor to accept bookingId, userId, and turfId
  const bkUserDetails({super.key, required this.bookingId, required this.userId, required this.turfId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Details'),
        centerTitle: true,
        backgroundColor: Colors.green[700], // AppBar color
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchUserAndBookingDetails(userId, bookingId, turfId),
        builder: (context, snapshot) {
          // Show loading indicator while waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          // Show error message if there's an error
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error fetching details.',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            );
          }

          // Show message if no data is available
          if (!snapshot.hasData) {
            return Center(
              child: Text(
                'No data available.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          // Extract user and booking data from snapshot
          var userData = snapshot.data!['userData'] as Map<String, dynamic>;
          var bookingData = snapshot.data!['bookingData'] as Map<String, dynamic>;

          // Display user and booking details in a card wrapped in a SingleChildScrollView
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Details',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green[700]),
                    ),
                    SizedBox(height: 20),
                    _buildUserDataTable(userData),
                    SizedBox(height: 20),
                    Divider(),
                    SizedBox(height: 20),
                    Text(
                      'Booking Details',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[700]),
                    ),
                    SizedBox(height: 10),
                    _buildBookingDataTable(bookingData),
                    SizedBox(height: 20),
                    _buildBookingSlotsSection(bookingData['bookingSlots'] ?? []),
                    SizedBox(height: 20),
                    _buildBookingStatus(bookingData['bookingStatus'] ?? []),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Method to build the user details DataTable
  Widget _buildUserDataTable(Map<String, dynamic> userData) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Field', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Value', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: [
        DataRow(cells: [
          DataCell(Text('User Name')),
          DataCell(Text(userData['name'] ?? 'N/A')),
        ]),
        DataRow(cells: [
          DataCell(Text('Email')),
          DataCell(Text(userData['email'] ?? 'N/A')),
        ]),
        DataRow(cells: [
          DataCell(Text('Phone')),
          DataCell(Text(userData['mobile'] ?? 'N/A')),
        ]),
      ],
    );
  }

  // Method to build the booking details DataTable
  Widget _buildBookingDataTable(Map<String, dynamic> bookingData) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Field', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Value', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: [
        DataRow(cells: [
          DataCell(Text('Booking Date')),
          DataCell(Text(bookingData['bookingDate'] ?? 'N/A')),
        ]),
        DataRow(cells: [
          DataCell(Text('Selected Ground')),
          DataCell(Text(bookingData['selectedGround'] ?? 'N/A')),
        ]),
        DataRow(cells: [
          DataCell(Text('Amount')),
          DataCell(Text('₹${bookingData['amount']?.toStringAsFixed(2) ?? '0.00'}')),
        ]),
        DataRow(cells: [
          DataCell(Text('Total Hours')),
          DataCell(Text('${bookingData['totalHours'] ?? 0}')),
        ]),
        DataRow(cells: [
          DataCell(Text('Turf Name')),
          DataCell(Text(bookingData['turfName'] ?? 'N/A')),
        ]),
        DataRow(cells: [
          DataCell(Text('Payment Method')),
          DataCell(Text(bookingData['paymentMethod'] ?? 'N/A')), // Display paymentMethod
        ]),
      ],
    );
  }

  // Method to build the Booking Slots section with a Confirm button
  Widget _buildBookingSlotsSection(List<dynamic> bookingSlots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Booking Slots',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[700]),
        ),
        SizedBox(height: 10),
        bookingSlots.isEmpty
            ? Chip(
          label: Text('All Booking Cancelled'),
          backgroundColor: Colors.red[100],
        )
            : Wrap(
          spacing: 8.0, // Space between chips
          runSpacing: 4.0, // Space between rows
          children: bookingSlots.map<Widget>((slot) {
            return Chip(
              label: Text(slot.toString()),
              backgroundColor: Colors.green[100],
            );
          }).toList(),
        ),
      ],
    );
  }

  // Method to build the Cancelled Slots section
  Widget _buildBookingStatus(List<dynamic> bookingSlots) {
    return bookingSlots.isEmpty
        ? Container() // Return an empty container if bookingSlots is empty
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cancelled Slots',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red[700]),
        ),
        SizedBox(height: 10),
        Wrap(
          spacing: 8.0, // Space between chips
          runSpacing: 4.0, // Space between rows
          children: bookingSlots.map<Widget>((slot) {
            return Chip(
              label: Text(slot.toString()),
              backgroundColor: Colors.red[100],
            );
          }).toList(),
        ),
      ],
    );
  }

  // Fetch user and booking details from Firestore
  Future<Map<String, dynamic>> _fetchUserAndBookingDetails(String userId, String bookingId, String turfId) async {
    try {
      // Fetch user details from Firestore
      var userSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      var userData = userSnapshot.data();

      // Fetch booking details using turfId and bookingId
      var bookingSnapshot = await FirebaseFirestore.instance
          .collection('turfs')
          .doc(turfId) // Use turfId to access the correct document
          .collection('bookings')
          .doc(bookingId)
          .get();

      var bookingData = bookingSnapshot.data();

      // Return a map containing both user and booking data
      return {
        'userData': {
          'userId': userId,
          'name': userData?['name'] ?? 'N/A',
          'email': userData?['email'] ?? 'N/A',
          'mobile': userData?['mobile'] ?? 'N/A',
        },
        'bookingData': {
          'amount': bookingData?['amount'] ?? 0,
          'bookingDate': bookingData?['bookingDate'] ?? 'N/A',
          'bookingSlots': bookingData?['bookingSlots'] ?? [],
          'bookingStatus': bookingData?['bookingStatus'] ?? [],
          'selectedGround': bookingData?['selectedGround'] ?? 'N/A',
          'totalHours': bookingData?['totalHours'] ?? 0,
          'turfId': turfId,
          'turfName': bookingData?['turfName'] ?? 'N/A',
          'paymentMethod': bookingData?['paymentMethod'] ?? 'N/A', // Add paymentMethod
        },
      };
    } catch (e) {
      throw Exception('Error fetching details: $e');
    }
  }
}