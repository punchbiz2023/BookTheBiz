import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:odp/pages/Turf%20owner/turfadd.dart';
import 'package:permission_handler/permission_handler.dart';
import '../bookingpage.dart';
import '../home_page.dart';
import '../login.dart';
import '../profile.dart';
import '../settings.dart';

class HomePage2 extends StatefulWidget {
  final User? user;

  const HomePage2({Key? key, this.user}) : super(key: key);

  @override
  _HomePage2State createState() => _HomePage2State();
}

class _HomePage2State extends State<HomePage2> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Position? _currentPosition;
  String? turfOwnerTurfId;

  @override
  void initState() {
    super.initState();
    _fetchTurfId();
    _checkAndFetchLocation();
  }

  Future<void> _fetchTurfId() async {
    try {
      // Fetch the turf owner's turfId from the Firestore database (Assuming it's stored in 'users' collection)
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user?.uid)
          .get();
      setState(() {
        turfOwnerTurfId = userSnapshot['turfId'];
      });
    } catch (e) {
      print('Error fetching turfId: $e');
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

  Stream<List<DocumentSnapshot>> _fetchPastBookings() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('turfId', isEqualTo: widget.user?.uid) // Fetch bookings for the logged-in turf owner
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.isNotEmpty ? snapshot.docs : []; // Return an empty list if no bookings found
    });
  }


  Widget _buildPastBookingsWidget() {
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
          return Center(child: Text('No previous bookings.'));
        }

        var pastBookings = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: pastBookings.length,
          itemBuilder: (context, index) {
            var booking = pastBookings[index].data() as Map<String, dynamic>;
            return Card(
              color: Colors.grey[850],
              child: ListTile(
                title: Text(
                  booking['userName'] ?? 'Unknown User', // Displaying userName of the booking
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Date: ${booking['bookingDate'] ?? 'N/A'}\nFrom: ${booking['bookingFromTime'] ?? 'N/A'}',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          },
        );
      },
    );
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
            Text(
              'Quick Access',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            _buildImageCards(),
            SizedBox(height: 20),
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
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Past Bookings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildPastBookingsWidget(),
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
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildImageCards() {
    return Container(
      height: 250,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FirebaseImageCard(
            imagePath: 'Turf images test/turf 2.jpeg',
            title: 'Turf 1',
            description: 'Description for Turf 1',
          ),
          FirebaseImageCard(
            imagePath: 'Turf images test/turf 3.jpeg',
            title: 'Turf 2',
            description: 'Description for Turf 2',
          ),
          FirebaseImageCard(
            imagePath: 'Turf images test/turf 4.jpeg',
            title: 'Turf 3',
            description: 'Description for Turf 3',
          ),
        ],
      ),
    );
  }
}

class FirebaseImageCard extends StatefulWidget {
  final String imagePath;
  final String title;
  final String description;

  const FirebaseImageCard({
    Key? key,
    required this.imagePath,
    required this.title,
    required this.description,
  }) : super(key: key);

  @override
  _FirebaseImageCardState createState() => _FirebaseImageCardState();
}

class _FirebaseImageCardState extends State<FirebaseImageCard> {
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      fs.Reference ref = fs.FirebaseStorage.instance.ref().child(widget.imagePath);
      String url = await ref.getDownloadURL();
      setState(() {
        imageUrl = url;
      });
    } catch (e) {
      print('Error loading image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: imageUrl != null
                ? ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
              ),
            )
                : Center(child: CircularProgressIndicator()),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  widget.description,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
