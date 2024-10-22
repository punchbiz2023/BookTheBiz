import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TurfDetails extends StatelessWidget {
  final String turfId;

  TurfDetails({required this.turfId});

  Future<void> _updateTurfStatus(BuildContext context, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('turfs').doc(turfId).update({
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
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('turfs').doc(turfId).snapshots(),
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
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
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
                        'Price: \₹${turfData['price']?.toStringAsFixed(2) ?? '0.00'}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),

                      Text(
                        'Facilities:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      ...List.generate(
                        turfData['facilities']?.length ?? 0,
                            (index) => Text(turfData['facilities'][index] ?? 'No Facility'),
                      ),
                      SizedBox(height: 16),

                      Text(
                        'Available Grounds:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      ...List.generate(
                        turfData['availableGrounds']?.length ?? 0,
                            (index) => Text(turfData['availableGrounds'][index] ?? 'No Ground'),
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
                              foregroundColor: Colors.white, backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                              textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ).copyWith(elevation: MaterialStateProperty.all(8)),
                          ),
                          ElevatedButton(
                            onPressed: () => _updateTurfStatus(context, 'Closed'),
                            child: Text('Close'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white, backgroundColor: Colors.red,
                              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                              textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ).copyWith(elevation: MaterialStateProperty.all(8)),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      Text(
                        'Bookings:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('turfs')
                            .doc(turfId)
                            .collection('bookings')
                            .snapshots(),
                        builder: (context, AsyncSnapshot<QuerySnapshot> bookingSnapshot) {
                          if (bookingSnapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (bookingSnapshot.hasError) {
                            return Text('Error loading bookings.');
                          }

                          if (!bookingSnapshot.hasData || bookingSnapshot.data!.docs.isEmpty) {
                            return Text('No bookings available.');
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: bookingSnapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              var bookingData = bookingSnapshot.data!.docs[index].data() as Map<String, dynamic>;

                              return Card(
                                elevation: 4,
                                margin: EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  title: Text('Booking by: ${bookingData['userName'] ?? 'N/A'}'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Amount: ₹${bookingData['amount']?.toStringAsFixed(2) ?? 'N/A'}'),
                                      Text('Booking Date: ${bookingData['bookingDate'] ?? 'N/A'}'),
                                      Text('Selected Ground: ${bookingData['selectedGround'] ?? 'N/A'}'),
                                      Text('Total Hours: ${bookingData['totalHours'] ?? 'N/A'}'),
                                      SizedBox(height: 4),
                                      Text('Slots:'),
                                      ...List.generate(
                                        bookingData['bookingSlots']?.length ?? 0,
                                            (slotIndex) => Text(bookingData['bookingSlots'][slotIndex] ?? 'N/A'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
