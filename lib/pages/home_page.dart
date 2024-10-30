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
  String _pastBookingSearchText = '';
  String _sortOrder = 'Ascending';

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
    print(FirebaseAuth.instance.currentUser);
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
        backgroundColor: Colors.teal,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: TextFormField(
                    onChanged: (value) {
                      setState(() {
                        _searchText = value;
                      });
                    },
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Search turfs...',
                      hintStyle: TextStyle(color: Colors.black54),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Turfs'),
            _buildTurfsSection(),
            SizedBox(height: 20),
            _buildSectionTitle('Bookings'),
            Row(
              children: [
                Expanded(child: _buildPastBookingsSearchBar()),
                SizedBox(width: 10),
                _buildSortDropdown(),
              ],
            ),
            _buildPastBookingsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.teal,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
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

  Widget _buildPastBookingsSearchBar() {
    return TextFormField(
      onChanged: (value) {
        setState(() {
          _pastBookingSearchText = value;
        });
      },
      style: TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: 'Search bookings...',
        hintStyle: TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.black54),
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortOrder,
          icon: Icon(Icons.filter_list, color: Colors.teal),
          style: TextStyle(color: Colors.black),
          onChanged: (String? newValue) {
            setState(() {
              _sortOrder = newValue!;
            });
          },
          items: [
            DropdownMenuItem<String>(
              value: 'Ascending',
              child: Row(
                children: [
                  Icon(Icons.arrow_upward, color: Colors.teal),
                  SizedBox(width: 5),
                  Text('', style: TextStyle(color: Colors.black)),
                ],
              ),
            ),
            DropdownMenuItem<String>(
              value: 'Descending',
              child: Row(
                children: [
                  Icon(Icons.arrow_downward, color: Colors.teal),
                  SizedBox(width: 5),
                  Text('', style: TextStyle(color: Colors.black)),
                ],
              ),
            ),
          ],
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
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
        var filteredBookings = pastBookings.where((booking) {
          var bookingData = booking.data() as Map<String, dynamic>;
          return bookingData['turfName']
              .toString()
              .toLowerCase()
              .contains(_pastBookingSearchText.toLowerCase());
        }).toList();

        // Debugging: Check the number of filtered bookings
        print('Filtered Bookings Count: ${widget.user?.uid}');
        print('Past Booking Search Text: $_pastBookingSearchText');

        if (_sortOrder == 'Ascending') {
          filteredBookings.sort((a, b) {
            var dateA = DateTime.parse((a.data() as Map<String, dynamic>)['bookingDate']);
            var dateB = DateTime.parse((b.data() as Map<String, dynamic>)['bookingDate']);
            return dateA.compareTo(dateB);
          });
        } else {
          filteredBookings.sort((a, b) {
            var dateA = DateTime.parse((a.data() as Map<String, dynamic>)['bookingDate']);
            var dateB = DateTime.parse((b.data() as Map<String, dynamic>)['bookingDate']);
            return dateB.compareTo(dateA);
          });
        }

        return ListView.builder(
          itemCount: filteredBookings.length,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            var bookingData = filteredBookings[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 2,
              margin: EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                title: Text(bookingData['turfName'], style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(bookingData['bookingDate']),
                trailing: Text('${bookingData['amount']} INR', style: TextStyle(color: Colors.teal)),
                onTap: () {
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
}
