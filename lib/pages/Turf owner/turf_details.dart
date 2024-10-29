import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'bkuserdetails.dart';

class TurfDetails extends StatefulWidget {
  final String turfId;

  TurfDetails({required this.turfId});

  @override
  _TurfDetailsState createState() => _TurfDetailsState();
}

class _TurfDetailsState extends State<TurfDetails> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateTurfStatus(BuildContext context, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).update({
        'status': newStatus,
      });
      Fluttertoast.showToast(
        msg: "Turf status updated to $newStatus",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error updating turf status.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Turf Details'),
        backgroundColor: Colors.blueAccent,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.0),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blueAccent,
              indicatorWeight: 3.0,
              tabs: [
                Tab(
                  text: 'Details',
                ),
                Tab(
                  text: 'Bookings',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTurfDetails(context),
          _buildBookingsList(),
        ],
      ),
    );
  }

  Widget _buildTurfDetails(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).snapshots(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error fetching turf details.'));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('Turf not found.'));
        }

        var turfData = snapshot.data!.data() as Map<String, dynamic>;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.5), width: 2),
                        image: DecorationImage(
                          image: NetworkImage(turfData['imageUrl'] ?? ''),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: turfData['imageUrl'] == null
                          ? Icon(Icons.image, size: 100, color: Colors.grey)
                          : null,
                    ),
                    SizedBox(height: 16),
                    Text(
                      turfData['name'] ?? 'No Name',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    SizedBox(height: 8),
                    Text(
                      turfData['description'] ?? 'No Description',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Price: ₹${turfData['price']?.toStringAsFixed(2) ?? '0.00'}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Facilities:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    ...List.generate(
                      turfData['facilities']?.length ?? 0,
                          (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(turfData['facilities'][index] ?? 'No Facility'),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Available Grounds:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    ...List.generate(
                      turfData['availableGrounds']?.length ?? 0,
                          (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(turfData['availableGrounds'][index] ?? 'No Ground'),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Current Status: ${turfData['status'] ?? 'Opened'}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => _updateTurfStatus(context, 'Open'),
                          child: Text('Open'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _updateTurfStatus(context, 'Closed'),
                          child: Text('Close'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookingsList() {
    return Column(
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
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Booked Time Slots:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('turfs')
                .doc(widget.turfId)
                .collection('bookings')
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
                    elevation: 4,
                    child: ListTile(
                      title: Text(bookingData['userName'] ?? 'Unknown User'),
                      subtitle: Text('Date: ${bookingData['bookingDate']}\n'),
                      trailing: Text('₹${bookingData['amount']?.toStringAsFixed(2) ?? '0.00'}'),
                      onTap: () {
                        // Navigate to the bkUserDetails screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => bkUserDetails(
                              bookingId: filteredBookings[index].id, // Pass the booking ID
                              userId: bookingData['userId'], // Pass the user ID
                              turfId: widget.turfId, // Pass the turf ID
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
    );
  }

}
