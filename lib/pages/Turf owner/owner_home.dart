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
    _checkAndFetchLocation();
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
  Future<void> _checkAndFetchLocation() async {
    if (await Permission.location.request().isGranted) {
      _fetchCurrentLocation();
    } else {
      print('Location permission not granted');
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

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
                icon: Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              _buildLocationWidget(),
            ],
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      drawer: _buildDrawer(),
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
      // Removed FloatingActionButton here
    );
  }

  // Build location widget
  Widget _buildLocationWidget() {
    if (_currentPosition == null) {
      return CircularProgressIndicator(); // Placeholder
    }
    return Text(
      '${_currentPosition!.latitude.toStringAsFixed(2)}, ${_currentPosition!.longitude.toStringAsFixed(2)}',
      style: TextStyle(color: Colors.white, fontSize: 16),
    );
  }

  // Build drawer with navigation options
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.black,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.purpleAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage('assets/profile_picture.png'),
                ),
                SizedBox(width: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProfilePage(user: widget.user),
                      ),
                    );
                  },
                  child: Text(
                    widget.user?.displayName ?? 'John Doe',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _createDrawerItem(
                  icon: Icons.home,
                  text: 'Home',
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomePage1(user: widget.user),
                      ),
                    );
                  },
                ),
                _createDrawerItem(
                  icon: Icons.settings,
                  text: 'Settings',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsPage()),
                    );
                  },
                ),
                _createDrawerItem(
                  icon: Icons.logout,
                  text: 'Logout',
                  onTap: () {
                    _logout();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build turf card
  Widget _buildTurfCard(Map<String, dynamic> turfData) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shadowColor: Colors.black.withOpacity(0.5),
      elevation: 5.0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: turfData['imageUrl'] != null
                ? Image.network(turfData['imageUrl'],
                width: 50, height: 50, fit: BoxFit.cover)
                : Icon(Icons.image, size: 50, color: Colors.grey),
          ),
          title: Text(
            turfData['name'] ?? 'No Name',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            turfData['description'] ?? 'No Description',
            style: TextStyle(color: Colors.grey),
          ),
          trailing: InkWell(
            onTap: () {
              // Redirect to the turf_details page, passing the turfId
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TurfDetails(turfId: turfData['turfId']),
                ),
              );
            },
            child: Icon(Icons.arrow_forward_ios, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // Drawer item creation helper
  Widget _createDrawerItem({
    required IconData icon,
    required String text,
    required GestureTapCallback onTap,
  }) {
    return ListTile(
      title: Row(
        children: [
          Icon(icon, color: Colors.white),
          Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Text(text, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
