import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:odp/pages/profile.dart';
import 'package:odp/widgets/firebaseimagecard.dart';
import 'bkdetails.dart';
import 'bookings_history_page.dart'; // Import the renamed page

class HomePage1 extends StatefulWidget {
  final User? user;
  const HomePage1({Key? key, this.user}) : super(key: key);

  @override
  _HomePage1State createState() => _HomePage1State();
}

class _HomePage1State extends State<HomePage1>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String selectedTab = 'active';
  String _searchText = '';
  String _pastBookingSearchText = '';
  String _sortOrder = 'Ascending';
  DateTime? _customDate;
  bool selectionMode = false;
  List<Map<String, dynamic>> selectedBookings = [];

  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
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

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(user: widget.user),
      ),
    );
  }

  Stream<List<DocumentSnapshot>> _fetchPastBookings() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs);
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
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
          fillColor: Colors.grey[200],
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: Icon(Icons.person, color: Colors.teal),
              onPressed: _navigateToProfile,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(Icons.confirmation_number, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BookingsPage()),
                );
              },
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            _buildSearchBar(),

            // Popular Turfs Section
            SizedBox(height: 20),
            _buildSectionTitle(' Turfs'),
            _buildPopularTurfs(),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularTurfs() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('turfs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading turfs'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No turfs available'));
        }

        final turfs = snapshot.data!.docs;

        // Filter turfs based on search text
        final filteredTurfs = turfs.where((doc) {
          final turfData = doc.data() as Map<String, dynamic>;
          final turfName = turfData['name']?.toString().toLowerCase() ?? '';
          return turfName.contains(_searchText.toLowerCase());
        }).toList();

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          childAspectRatio: 0.72,
          mainAxisSpacing: 21,
          crossAxisSpacing: 20,
          padding: EdgeInsets.all(10),
          children: filteredTurfs.map((doc) {
            final turfData = doc.data() as Map<String, dynamic>;

            final price = turfData['price'] is Map<String, dynamic>
                ? turfData['price']['value'] ?? 'N/A'
                : turfData['price'].toString();

            return FirebaseImageCard(
              imageUrl: turfData['imageUrl'] ?? '',
              title: turfData['name'] ?? 'Unknown Turf',
              description:
                  turfData['description'] ?? 'No description available',
              documentId: doc.id,
              docname: turfData['name'] ?? 'Unknown Turf',
              chips: List<String>.from(turfData['availableGrounds'] ?? []),
              price: price,
            );
          }).toList(),
        );
      },
    );
  }
}
