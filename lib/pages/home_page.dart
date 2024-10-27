import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:odp/pages/profile.dart';
import 'package:odp/widgets/firebaseimagecard.dart';
import 'bkdetails.dart';

class HomePage1 extends StatefulWidget {
  final User? user;

  const HomePage1({Key? key, this.user}) : super(key: key);

  @override
  _HomePage1State createState() => _HomePage1State();
}

class _HomePage1State extends State<HomePage1> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Position? _currentPosition;
  String _searchText = '';

  Future<void> _fetchCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(user: widget.user),
      ),
    );
  }

  Stream<List<DocumentSnapshot>> _fetchTurfs() {
    return FirebaseFirestore.instance.collection('turfs').snapshots().map((snapshot) => snapshot.docs);
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
                icon: Icon(Icons.person, color: Colors.white),
                onPressed: _navigateToProfile,
              ),
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
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
              _buildLocationWidget(),
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
            _buildSectionTitle('Turfs'),
            _buildTurfsSection(),
            SizedBox(height: 20),
            _buildSectionTitle('Past Bookings'),
            _buildPastBookingsSection(),
          ],
        ),
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

        filteredTurfs = filteredTurfs.where((turf) {
          var turfData = turf.data() as Map<String, dynamic>;
          return turfData['imageUrl'] != null && turfData['imageUrl'].isNotEmpty;
        }).toList();

        if (filteredTurfs.isEmpty) {
          return Center(child: Text('No turfs match your search'));
        }

        return Container(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: filteredTurfs.length,
            itemBuilder: (context, index) {
              var turfData = filteredTurfs[index].data() as Map<String, dynamic>;
              String imageUrl = turfData['imageUrl'] ?? '';
              String name = turfData['name'] ?? 'Unknown Turf';
              String description = turfData['description'] ?? 'No description available';
              List<String> availableGrounds = List<String>.from(turfData['availableGrounds'] ?? []);

              return FirebaseImageCard(
                imageUrl: imageUrl,
                title: name,
                description: description,
                documentId: filteredTurfs[index].id,
                docname: name,
                chips: availableGrounds,
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
            var bookingData = pastBookings[index].data() as Map<String, dynamic>;
            // Add turfId to bookingData
            bookingData['turfId'] = pastBookings[index].get('turfId');

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
                onTap: () {
                  // Navigate to the BookingDetailsPage
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookingDetailsPage(
                        bookingData: bookingData,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLocationWidget() {
    return Text(
      _currentPosition != null
          ? 'Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}'
          : 'Fetching location...',
      style: TextStyle(color: Colors.white),
    );
  }
}
