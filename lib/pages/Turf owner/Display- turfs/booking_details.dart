import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bkuserdetails.dart';

class BookingDetailsPage extends StatefulWidget {
  final String turfId;

  BookingDetailsPage({required this.turfId, required Map bookingData});

  @override
  _BookingDetailsPageState createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
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
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('turfs')
                  .doc(widget.turfId)
                  .collection('bookings')
                  .orderBy('bookingDate', descending: true)
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

                // Filter bookings based on the search query
                var filteredBookings = bookingSnapshot.data!.docs.where((doc) {
                  var bookingData = doc.data() as Map<String, dynamic>;
                  return bookingData['userName']?.toLowerCase().contains(_searchQuery) ?? false;
                }).toList();

                return ListView.builder(
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    var bookingData = filteredBookings[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: ListTile(
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
                                bookingId: filteredBookings[index].id,
                                userId: bookingData['userId'],
                                turfId: widget.turfId,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
