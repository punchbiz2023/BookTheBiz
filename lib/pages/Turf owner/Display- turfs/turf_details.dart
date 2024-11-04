import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:odp/pages/Turf%20owner/Display-%20turfs/turfstats.dart';
import 'booking_details.dart';

class TurfDetails extends StatefulWidget {
  final String turfId;

  TurfDetails({required this.turfId});

  @override
  _TurfDetailsState createState() => _TurfDetailsState();
}

class _TurfDetailsState extends State<TurfDetails> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateTurfStatus(BuildContext context, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).update({'status': newStatus});
      Fluttertoast.showToast(
        msg: "Turf status updated to $newStatus",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error updating turf status.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Widget _buildTurfDetails(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).snapshots(),
      builder: (context, snapshot) {
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image section
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage(turfData['imageUrl'] ?? ''),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: turfData['imageUrl'] == null
                          ? Center(child: Icon(Icons.image, size: 100, color: Colors.grey))
                          : null,
                    ),
                    SizedBox(height: 16),
                    Text(
                      turfData['name'] ?? 'No Name',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    SizedBox(height: 8),
                    Text(
                      turfData['description'] ?? 'No Description',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Price: ₹${turfData['price']?.toStringAsFixed(2) ?? '0.00'}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Facilities:',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: List.generate(
                        turfData['facilities']?.length ?? 0,
                            (index) => Chip(
                          label: Text(turfData['facilities'][index] ?? 'No Facility'),
                          avatar: Icon(Icons.check_circle, size: 16, color: Colors.green),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Available Grounds:',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: List.generate(
                        turfData['availableGrounds']?.length ?? 0,
                            (index) => Chip(
                          label: Text(turfData['availableGrounds'][index] ?? 'No Ground'),
                          avatar: Icon(Icons.sports_soccer, size: 16, color: Colors.blue),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Enhanced Current Status section
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: turfData['status'] == 'Open' ? Colors.green[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: turfData['status'] == 'Open' ? Colors.green : Colors.red, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Current Status: ${turfData['status'] ?? 'Opened'}',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: turfData['status'] == 'Open' ? Colors.green : Colors.red),
                          ),
                          Icon(
                            turfData['status'] == 'Open' ? Icons.check_circle : Icons.cancel,
                            color: turfData['status'] == 'Open' ? Colors.green : Colors.red,
                            size: 30,
                          ),
                        ],
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Turf Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
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
                Tab(text: 'Details'),
                Tab(text: 'Bookings'),
                Tab(text: 'Stats'), // New tab for Stats
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTurfDetails(context),
          BookingDetailsPage(turfId: widget.turfId, bookingData: {}), // Existing booking details page
          Turfstats(turfId: widget.turfId) // Updated to use Turfstats
        ],
      ),
    );
  }
}
