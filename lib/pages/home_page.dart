import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:odp/widgets/firebaseimagecard.dart';
import 'package:permission_handler/permission_handler.dart';

import 'bookingpage.dart';
import 'login.dart';
import 'profile.dart';
import 'settings.dart';

class HomePage1 extends StatefulWidget {
  final User? user;

  const HomePage1({Key? key, this.user}) : super(key: key);

  @override
  _HomePage1State createState() => _HomePage1State();
}

class _HomePage1State extends State<HomePage1> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String userType = 'User'; // Default user type
  Position? _currentPosition;
  List<DocumentSnapshot> _turfs = []; // List to store fetched turfs

  @override
  void initState() {
    super.initState();
    _fetchUserType();
    _checkAndFetchLocation();
    _fetchTurfs();
  }

  Future<void> _fetchUserType() async {
    if (widget.user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user!.uid)
            .get();

        String fetchedUserType = userDoc.get('userType') ?? 'User';
        setState(() {
          userType = fetchedUserType;
        });
      } catch (e) {
        print('Error fetching user type: $e');
      }
    }
  }

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

  Future<void> _fetchTurfs() async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('turfs').get();

      setState(() {
        _turfs = querySnapshot.docs;
      });
    } catch (e) {
      print('Error fetching turfs: $e');
    }
  }

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
      drawer: Drawer(
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
                          builder: (context) => ProfilePage(user: widget.user),
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
      ),
      backgroundColor: Color(0xff192028),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Access',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            if (userType == 'User')
              Container(
                height: 250, // Adjust height as needed
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _turfs.length,
                  itemBuilder: (context, index) {
                    var turf = _turfs[index].data() as Map<String, dynamic>;
                    return FirebaseImageCard(
                      imageUrl: turf[
                          'imageUrl'], // Ensure this matches your Firestore field name
                      title: turf[
                          'name'], // Ensure this matches your Firestore field name
                      description: turf[
                          'description'], // Ensure this matches your Firestore field name
                    );
                  },
                ),
              )
            else if (userType == 'Turf Owner')
              Container(
                height: 120,
                child: Card(
                  color: Colors.grey[800],
                  child: Center(
                    child: Text(
                      'No content available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BookingPage()),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildLocationWidget() {
    if (_currentPosition == null) {
      return CircularProgressIndicator();
    }
    return Text(
      '${_currentPosition!.latitude.toStringAsFixed(2)}, ${_currentPosition!.longitude.toStringAsFixed(2)}',
      style: TextStyle(color: Colors.white, fontSize: 16),
    );
  }

  Widget _createDrawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      onTap: onTap,
    );
  }
}
