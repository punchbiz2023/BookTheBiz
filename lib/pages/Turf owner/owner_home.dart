import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../bookingpage.dart';
import '../home_page.dart';
import '../login.dart';
import '../profile.dart';
import '../settings.dart';
import 'turfadd.dart';
import 'turf_details.dart';

class HomePage2 extends StatefulWidget {
  User? user;

  HomePage2({Key? key, this.user}) : super(key: key);

  @override
  _HomePage2State createState() => _HomePage2State();
}

class _HomePage2State extends State<HomePage2> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Position? _currentPosition;
  Stream<QuerySnapshot>? _turfsStream;

  @override
  void initState() {
    super.initState();
    // _checkAndFetchLocation();
    _checkCurrentUser();
    _setupTurfStream();
  }

  // Set up Firestore stream
  void _setupTurfStream() {
    _turfsStream = FirebaseFirestore.instance
        .collection('turfs')
        .where('ownerId', isEqualTo: widget.user?.uid)
        .snapshots();
  }

  // Fetch the current logged-in user
  Future<void> _checkCurrentUser() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      print('User is logged in: ${currentUser.uid}');
      setState(() {
        widget.user = currentUser;
      });
    } else {
      print('No user logged in');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginApp()),
      );
    }
  }

  // Check and fetch location if permission is granted
  // Future<void> _checkAndFetchLocation() async {
  //   if (await Permission.location.request().isGranted) {
  //     _fetchCurrentLocation();
  //   } else {
  //     print('Location permission not granted');
  //   }
  // }

  // Future<void> _fetchCurrentLocation() async {
  //   try {
  //     Position position = await Geolocator.getCurrentPosition(
  //         desiredAccuracy: LocationAccuracy.high);
  //     setState(() {
  //       _currentPosition = position;
  //     });
  //   } catch (e) {
  //     print('Error fetching location: $e');
  //   }
  // }

  // Logout function
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginApp()),
      );
    } catch (e) {
      print('Error logging out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.account_circle, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfilePage(user: widget.user),
                    ),
                  );
                },
              ),
              // _buildLocationWidget(),
            ],
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Color(0xff192028),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add Turf button
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddTurfPage()),
                  );
                },
                child: Text('Add Turf'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blueAccent,
                  padding: EdgeInsets.symmetric(horizontal: 140, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20), // Space after button

            // Listed Turfs heading
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Listed Turfs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Turf Listing
            StreamBuilder<QuerySnapshot>(
              stream: _turfsStream, // Use the stream created in initState
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                      child: Text('No turfs available',
                          style: TextStyle(color: Colors.white)));
                }

                final turfDocs = snapshot.data!.docs;
                return ListView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: turfDocs.length,
                  itemBuilder: (context, index) {
                    final turfData =
                    turfDocs[index].data() as Map<String, dynamic>;
                    return _buildTurfCard(turfData);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Build location widget
  // Widget _buildLocationWidget() {
  //   if (_currentPosition == null) {
  //     return CircularProgressIndicator(); // Placeholder
  //   }
  //   return Text(
  //     '${_currentPosition!.latitude.toStringAsFixed(2)}, ${_currentPosition!.longitude.toStringAsFixed(2)}',
  //     style: TextStyle(color: Colors.white, fontSize: 16),
  //   );
  // }

  // Build turf card
// Build turf card
  Widget _buildTurfCard(Map<String, dynamic> turfData) {
    // Extract the turfId from the turf data
    String turfId = turfData['turfId'] ?? ''; // Default to an empty string if turfId is null

    return GestureDetector(
      onTap: () {
        if (turfId.isNotEmpty) { // Check if turfId is valid
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TurfDetails(turfId: turfId), // Pass the turfId to TurfDetails
            ),
          );
        } else {
          print('Turf ID is missing'); // Debugging information
        }
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 8,
        margin: const EdgeInsets.symmetric(vertical: 10),
        shadowColor: Colors.black.withOpacity(0.2), // Slightly darker shadow
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Increased padding for a spacious feel
          child: Row(
            children: [
              // Turf Image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: turfData['imageUrl'] != null
                    ? Image.network(
                  turfData['imageUrl'],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                )
                    : Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[300], // Placeholder color
                  ),
                  child: Icon(Icons.image, size: 40, color: Colors.grey[600]),
                ),
              ),
              SizedBox(width: 16), // Spacing between image and text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      turfData['name'] ?? 'Unnamed Turf',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18, // Increased font size
                      ),
                    ),
                    SizedBox(height: 4), // Space between title and description
                    Text(
                      turfData['description'] ?? 'No description provided.',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14, // Slightly larger than normal
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.black54,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }


}
