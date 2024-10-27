import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BookingDetailsPage extends StatelessWidget {
  final Map<String, dynamic> bookingData;

  const BookingDetailsPage({Key? key, required this.bookingData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Details', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fetch and display the turf image
                _buildTurfImage(),
                SizedBox(height: 16),
                _buildDetailRow('Turf Name', bookingData['turfName'] ?? 'Unknown Turf'),
                _buildDetailRow('Date', bookingData['bookingDate'] ?? 'N/A'),
                _buildDetailRow('Amount', 'Rs ${bookingData['amount'] ?? 0} /-'),
                _buildDetailRow('Total Hours', '${bookingData['totalHours'] ?? 0}'),
                _buildDetailRow(
                  'Booked Time Slots',
                  bookingData['bookingSlots']?.join(', ') ?? 'N/A',
                ),
                _buildDetailRow('Selected Ground', bookingData['selectedGround'] ?? 'N/A'),
                _buildDetailRow('User', bookingData['userName'] ?? 'Unknown User'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  FutureBuilder<String> _buildTurfImage() {
    String turfId = bookingData['turfId']; // Get the turfId from bookingData

    return FutureBuilder<String>(
      future: _fetchTurfImageUrl(turfId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error fetching image', style: TextStyle(color: Colors.red));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text('No image available', style: TextStyle(color: Colors.grey));
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            snapshot.data!,
            height: 150, // Set height as needed
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  Future<String> _fetchTurfImageUrl(String turfId) async {
    DocumentSnapshot turfDoc = await FirebaseFirestore.instance
        .collection('turfs')
        .doc(turfId)
        .get();

    if (turfDoc.exists) {
      return turfDoc['imageUrl'] ?? ''; // Return the image URL
    } else {
      throw Exception('Turf not found');
    }
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
