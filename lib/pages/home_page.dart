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
  Position? _currentPosition;
  String _searchText = ''; // This will hold the search text

  @override
  void initState() {
    super.initState();
    _checkAndFetchLocation();
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

  Stream<List<DocumentSnapshot>> _fetchTurfs() {
    return FirebaseFirestore.instance
        .collection('turfs')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Stream<List<DocumentSnapshot>> _fetchPastBookings() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: widget.user?.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs);
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
              // Search bar integrated here
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.0),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchText = value;
                      });
                    },
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search turfs...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Colors.grey[800],
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              // _buildLocationWidget(),
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
            _buildSectionTitle('Turfs'),
            _buildTurfsSection(),
            SizedBox(height: 20),
            _buildSectionTitle('Past Bookings'),
            _buildPastBookingsSection(),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  Widget _buildTurfsSection() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _fetchTurfs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching turfs'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No turfs available'));
        }

        var turfs = snapshot.data!;
        var filteredTurfs = turfs.where((turf) {
          var turfData = turf.data() as Map<String, dynamic>;
          return turfData['name']
              .toString()
              .toLowerCase()
              .contains(_searchText.toLowerCase());
        }).toList();

        if (filteredTurfs.isEmpty) {
          return Center(child: Text('No turfs match your search'));
        }

        return Container(
          height: 250, // Adjust height as needed
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: filteredTurfs.length,
            itemBuilder: (context, index) {
              var turfData = filteredTurfs[index].data() as Map<String, dynamic>;

              // Assuming 'availableGrounds' is a field in Firestore that stores a list of grounds
              List<String> availableGrounds = List<String>.from(turfData['availableGrounds'] ?? []);

              return FirebaseImageCard(
                imageUrl: turfData['imageUrl'],
                title: turfData['name'],
                description: turfData['description'],
                documentId: filteredTurfs[index].id,
                docname: turfData['name'],
                chips: availableGrounds, // Pass the fetched available grounds here
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPastBookingsSection() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _fetchPastBookings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching past bookings'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No past bookings found'));
        }

        var pastBookings = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: pastBookings.length,
          itemBuilder: (context, index) {
            var bookingData =
            pastBookings[index].data() as Map<String, dynamic>;
            return Card(
              color: Colors.grey[850],
              child: ListTile(
                title: Text(
                  bookingData['turfName'] ?? 'Unknown Turf',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Date: ${bookingData['bookingDate'] ?? 'N/A'}',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          },
        );
      },
    );
  }

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
                      MaterialPageRoute(builder: (context) => HomePage1()),
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
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _createDrawerItem(
      {required IconData icon, required String text, required GestureTapCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(text, style: TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }

//   Widget _buildLocationWidget() {
//     return Text(
//       _currentPosition != null
//           ? 'Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}'
//           : 'Fetching location...',
//       style: TextStyle(color: Colors.white),
//     );
//   }
}
