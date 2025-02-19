import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:odp/pages/Turf%20owner/Display-%20turfs/turfstats.dart';
import '../Main Func/editturf.dart';
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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15), // Softer glass effect
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3), // Dark teal shadow with transparency
                    blurRadius: 12,
                    spreadRadius: 3,
                    offset: Offset(0, 6), // Slight elevation effect
                  ),
                ],
                border: Border.all(color: Colors.teal.shade700.withOpacity(0.4), width: 1.5), // Subtle dark teal border
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Turf Image with Gradient Overlay
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        child: Image.network(
                          turfData['imageUrl'] ?? '',
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withOpacity(0.2), Colors.transparent],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Turf Name
                        Text(
                          turfData['name'] ?? 'No Name',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                        SizedBox(height: 8),
                        // Description
                        Text(
                          turfData['description'] ?? 'No Description',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        SizedBox(height: 16),

                        // Price Section
                        Text(
                          'Pricing:',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: (turfData['price'] is List<dynamic>)
                              ? (turfData['price'] as List<dynamic>).map<Widget>((price) {
                            return Chip(
                              backgroundColor: Colors.green[100],
                              label: Text('₹${price.toStringAsFixed(2)}', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            );
                          }).toList()
                              : (turfData['price'] is Map<String, dynamic>)
                              ? (turfData['price'] as Map<String, dynamic>).entries.map<Widget>((entry) {
                            return Chip(
                              backgroundColor: Colors.green[100],
                              label: Text('${entry.key}: ₹${entry.value.toStringAsFixed(2)}',
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            );
                          }).toList()
                              : [
                            Chip(
                              backgroundColor: Colors.green[100],
                              label: Text('₹${turfData['price']?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Facilities Section
                        Text(
                          'Facilities:',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: (turfData['facilities'] as List<dynamic>?)
                              ?.map((facility) => Chip(
                            label: Text(facility ?? 'No Facility'),
                            avatar: Icon(Icons.check_circle, size: 16, color: Colors.green),
                          ))
                              .toList() ??
                              [Text('No facilities available')],
                        ),
                        SizedBox(height: 16),

                        // Available Grounds
                        Text(
                          'Available Grounds:',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: (turfData['availableGrounds'] as List<dynamic>?)
                              ?.map((ground) => Chip(
                            label: Text(ground ?? 'No Ground'),
                            avatar: Icon(Icons.sports_soccer, size: 16, color: Colors.blue),
                          ))
                              .toList() ??
                              [Text('No grounds available')],
                        ),
                        SizedBox(height: 16),

                        // Selected Slots
                        if (turfData.containsKey('selectedSlots') && (turfData['selectedSlots']?.isNotEmpty ?? false)) ...[
                          Text(
                            'Selected Slots:',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: List.generate(
                              turfData['selectedSlots']?.length ?? 0,
                                  (index) => Chip(
                                label: Text(turfData['selectedSlots'][index] ?? 'No Slot'),
                                avatar: Icon(Icons.access_time, size: 16, color: Colors.green),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                        ],

                        // Status Card
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

                        // Open/Close Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _statusButton(context, 'Open', Colors.green),
                            _statusButton(context, 'Closed', Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

// Custom Button for Open/Close
  Widget _statusButton(BuildContext context, String status, Color color) {
    return ElevatedButton(
      onPressed: () => _updateTurfStatus(context, status),
      child: Text(status),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
        textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50, // Light background for contrast
      appBar: AppBar(
        title: Text(
          'Turf Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white, // Better readability
          ),
        ),
        backgroundColor: Colors.teal.shade900.withOpacity(0.85), // Subtle transparency
        elevation: 4,
        shadowColor: Colors.black26,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditTurfPage(turfId: widget.turfId),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15), // Light glass effect
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.75),

              indicatorSize: TabBarIndicatorSize.label, // Keeps it tight to text width
              labelStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              unselectedLabelStyle: TextStyle(fontSize: 16),
              tabs: [
                Tab(text: 'Details'),
                Tab(text: 'Bookings'),
                Tab(text: 'Stats'),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        padding: EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTurfDetails(context),
            BookingDetailsPage(turfId: widget.turfId, bookingData: {}),
            Turfstats(turfId: widget.turfId),
          ],
        ),
      ),
    );
  }

}
