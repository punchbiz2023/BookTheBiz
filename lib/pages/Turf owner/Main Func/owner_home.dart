import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'statusfile.dart';
import '../../login.dart';
import '../../profile.dart';
import 'turfadd.dart';
import '../Display- turfs/turf_details.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

class HomePage2 extends StatefulWidget {
  User? user;

  HomePage2({super.key, this.user});

  @override
  _HomePage2State createState() => _HomePage2State();
}

class _HomePage2State extends State<HomePage2> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Position? _currentPosition;
  Stream<QuerySnapshot>? _turfsStream;
  int activeTurfs = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _searchController.addListener(_onSearchChanged);
    _checkCurrentUser();
    _setupTurfStream();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        searchQuery = _searchController.text.trim().toLowerCase();
        _setupTurfStream();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupTurfStream() {
    setState(() {
      _turfsStream = FirebaseFirestore.instance
          .collection('turfs')
          .where('ownerId', isEqualTo: widget.user?.uid)
          .snapshots();
    });
  }

  Future<void> _checkCurrentUser() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        widget.user = currentUser;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginApp()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildSidebar(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade700,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: const [
            Text(
              "Turf Owner ",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
                letterSpacing: 1.2,
              ),
            ),
            Icon(Icons.sports_soccer, color: Colors.white),
          ],
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.user?.uid)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(child: Text('User not found', style: TextStyle(color: Colors.black87)));
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final String userName = userData['name'] ?? 'User';
            final bool isTurfOwner = userData['userType'] == 'Turf Owner';
            final bool isStatusYes = userData['status'] == 'yes';

            return FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Enhanced Banner
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                              height: 320,
                            width: MediaQuery.of(context).size.width,
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.teal.shade800,
                                    Colors.teal.shade600,
                                  ],
                                ),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(40),
                                bottomRight: Radius.circular(40),
                              ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.teal.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                            ),
                          ),
                          Column(
                            children: [
                                // Enhanced Welcome Section
                                Container(
                                  padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.person_outline,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                          SizedBox(width: 15),
                                          Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                                  "Welcome back,",
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  userName,
                                      style: TextStyle(
                                        color: Colors.white,
                                                    fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 25),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(
                                              Icons.sports_soccer,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                            SizedBox(width: 12),
                                    Text(
                                      "Manage your Turfs",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                    ),
                                            ),
                                  ],
                                ),
                              ),
                                    ],
                                  ),
                                ),
                                // Enhanced Stats Cards
                              SizedBox(
                                  height: 180,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                        top: 40,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(40),
                                            topRight: Radius.circular(40),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: StreamBuilder<QuerySnapshot>(
                                        stream: _turfsStream,
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return Center(child: CircularProgressIndicator());
                                          }

                                          int activeTurfs = snapshot.data!.docs.length;
                                          String currentUserId = FirebaseAuth.instance.currentUser!.uid;
                                          DateTime today = DateTime.now();
                                            String formattedDate = "${today.year}-${today.month}-${today.day}";

                                          return StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('bookings')
                                                .where('turfId', isEqualTo: currentUserId)
                                                  .where('bookingDate', isEqualTo: formattedDate)
                                                .snapshots(),
                                            builder: (context, bookingSnapshot) {
                                              int todayBookings = bookingSnapshot.hasData ? bookingSnapshot.data!.docs.length : 0;

                                              return Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [
                                                    Expanded(
                                                      child: _buildDashboardCard(
                                                        "Active Turfs",
                                                        activeTurfs,
                                                        Colors.teal.shade700,
                                                        Colors.teal.shade500,
                                                        Icons.sports_soccer,
                                                      ),
                                                    ),
                                                    SizedBox(width: 15),
                                                    Expanded(
                                                      child: _buildDashboardCard(
                                                        "Today's Bookings",
                                                        todayBookings,
                                                        Colors.teal.shade600,
                                                        Colors.teal.shade400,
                                                        Icons.calendar_today,
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                  SizedBox(height: 25),

                  // Enhanced Add Turf Button
                Center(
                    child: SizedBox(
                      width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isTurfOwner && isStatusYes) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AddTurfPage()),
                        );
                      } else {
                        Fluttertoast.showToast(
                          msg: "Your ID isn't verified by Admin or you are not a Turf Owner.",
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                          fontSize: 16.0,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => StatusFilePage()),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                          backgroundColor: isTurfOwner && isStatusYes ? Colors.teal.shade600 : Colors.grey,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 5,
                          shadowColor: Colors.teal.withOpacity(0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_circle_outline, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'Add New Turf',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                    ),
                  ),
                ),

                  SizedBox(height: 25),

                  // Enhanced Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                        hintText: 'Search your turfs...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.teal.shade600),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.teal.shade600),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          searchQuery = '';
                          _setupTurfStream();
                        });
                      },
                    )
                        : null,
                    filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),

                  SizedBox(height: 25),

                  // Enhanced Section Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Row(
                      children: [
                        Icon(Icons.sports_soccer, color: Colors.teal.shade600, size: 28),
                        SizedBox(width: 10),
                Text(
                  'Your Turfs',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 15),

                  // Enhanced Turf List
                StreamBuilder<QuerySnapshot>(
                  stream: _turfsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No turfs available', style: TextStyle(color: Colors.black87)));
                    }

                    final turfDocs = snapshot.data!.docs.where((doc) {
                      if (searchQuery.isEmpty) return true;
                      
                      final turfData = doc.data() as Map<String, dynamic>;
                      final turfName = (turfData['name']?.toString() ?? '').toLowerCase();
                      final turfDescription = (turfData['description']?.toString() ?? '').toLowerCase();
                      
                      // Search in both name and description
                      return turfName.contains(searchQuery) || turfDescription.contains(searchQuery);
                    }).toList();

                    if (turfDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No turfs found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Try different search terms',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: turfDocs.length,
                      itemBuilder: (context, index) {
                        final turfData = turfDocs[index].data() as Map<String, dynamic>;
                        return _buildTurfCard(turfData);
                      },
                    );
                  },
                ),
              ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboardCard(String title, int count, Color color1, Color color2, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color1.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          SizedBox(height: 10),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced Sidebar Drawer
  Widget _buildSidebar() {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.teal.shade800,
              Colors.teal.shade600,
            ],
          ),
        ),
        child: Column(
          children: [
            // Enhanced Header with User Info
            Container(
              padding: EdgeInsets.only(top: 50, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Icon(
                        Icons.person_outline,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  Text(
                'Turf Management',
                style: TextStyle(
                  color: Colors.white,
                      fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Owner Dashboard',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // Menu List
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: 20),
                children: [
                  _buildSidebarItem(
                    Icons.dashboard_outlined,
                    'Dashboard',
                    () {
                      Navigator.pop(context); // Close drawer
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage2(user: widget.user)),
                      );
                    },
                  ),
                  _buildSidebarItem(
                    Icons.person_outline,
                    'Profile',
                    () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProfilePage(user: widget.user)),
                      );
                    },
                  ),
                  _buildSidebarItem(
                    Icons.help_outline,
                    'Help & Support',
                    () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.8,
                              maxWidth: MediaQuery.of(context).size.width * 0.9,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Header with gradient background
                                Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade700,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                    ),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.help_outline, color: Colors.white, size: 28),
                                      SizedBox(width: 10),
                                      Text(
                                        'Help & Support',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                ],
              ),
            ),

                                // Scrollable content
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Quick Links Section
                                        Text(
                                          'Quick Links',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        _buildHelpItem(
                                          Icons.add_circle_outline,
                                          'Adding a New Turf',
                                          'Add your turf details, facilities, and available grounds through the "Add New Turf" button.',
                                        ),
                                        _buildHelpItem(
                                          Icons.edit_outlined,
                                          'Managing Turfs',
                                          'Edit turf details, update prices, and manage bookings from the turf details page.',
                                        ),
                                        _buildHelpItem(
                                          Icons.calendar_today_outlined,
                                          'Booking Management',
                                          'View and manage all bookings, including today\'s bookings and upcoming schedules.',
                                        ),
                                        
                                        SizedBox(height: 20),
                                        
                                        // Contact Support Section
                                        Text(
                                          'Contact Support',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Container(
                                          padding: EdgeInsets.all(15),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.teal.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildContactItem(
                                                Icons.email_outlined,
                                                'Email',
                                                'thepunchbiz@gmail.com',
                                              ),
                                              SizedBox(height: 10),
                                              _buildContactItem(
                                                Icons.phone_outlined,
                                                'Phone',
                                                '+91 94894 45922',
                                              ),
                                              SizedBox(height: 10),
                                              _buildContactItem(
                                                Icons.access_time_outlined,
                                                'Support Hours',
                                                'Mon-Sat: 9:00 AM - 6:00 PM',
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        SizedBox(height: 20),
                                        
                                        // FAQ Section
                                        Text(
                                          'Frequently Asked Questions',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        _buildFAQItem(
                                          'How do I update my turf details?',
                                          'Go to the turf details page and click the edit icon in the top right corner.',
                                        ),
                                        _buildFAQItem(
                                          'How can I manage bookings?',
                                          'View all bookings in the turf details page under the "Bookings" tab.',
                                        ),
                                        _buildFAQItem(
                                          'What if I need to close my turf temporarily?',
                                          'You can update the turf status to "Closed" from the turf details page.',
                                        ),
                                        
                                        SizedBox(height: 20),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                // Footer with close button
                                Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(20),
                                      bottomRight: Radius.circular(20),
                                    ),
                                    border: Border(
                                      top: BorderSide(color: Colors.grey.shade200),
                                    ),
                                  ),
                                  child: Center(
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal.shade700,
                                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'Close',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
        ),
      ),
    );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced Sidebar Item Helper Function
  Widget _buildSidebarItem(IconData icon, String title, VoidCallback onTap, {Color color = Colors.white}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      splashColor: Colors.white.withOpacity(0.2),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Turf Card UI
  Widget _buildTurfCard(Map<String, dynamic> turfData) {
    String turfId = turfData['turfId'] ?? '';
    bool hasLocation = turfData['hasLocation'] ?? false;
    return GestureDetector(
        onTap: () {
        if (turfId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => TurfDetails(turfId: turfId),
            ),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (turfId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TurfDetails(turfId: turfId),
                    ),
                  );
                }
              },
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            turfData['imageUrl'] ?? 'https://via.placeholder.com/80',
                            width: 80,
                            height: 80,
            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[200],
                              child: Icon(Icons.broken_image, size: 40, color: Colors.grey[400]),
                            ),
                          ),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
          turfData['name'] ?? 'Unnamed Turf',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87,
        ),
                              ),
                              SizedBox(height: 4),
                              Text(
          turfData['description'] ?? 'No description available',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.teal.shade600,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                  if (!hasLocation) _buildLocationWarning(turfId),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Placeholder for Horizontal Cards
  Widget _buildPlaceholderCard() {
    return Container(width: 120, height: 100, color: Colors.grey[700], margin: EdgeInsets.only(right: 10));
  }

  // Help Item Widget
  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.teal.shade600, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Contact Item Widget
  Widget _buildContactItem(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal.shade600, size: 20),
        SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // FAQ Item Widget
  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            answer,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationPickerDialog(String turfId) async {
    final TextEditingController manualLocationController = TextEditingController();
    bool isGettingLocation = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Set Turf Location'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.my_location, color: Colors.teal),
                  title: Text('Use Current Location'),
                  subtitle: Text('Get precise location using GPS'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateTurfLocation(turfId, useCurrentLocation: true);
                  },
                ),
                Divider(),
                Text(
                  'Enter Location Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: manualLocationController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter complete address (e.g., Street, Area, City, State)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.location_on, color: Colors.teal),
                    helperText: 'Please provide a detailed address for better visibility',
                    helperStyle: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tip: A detailed address helps users find your turf easily',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (manualLocationController.text.isNotEmpty) {
                  await _updateTurfLocation(turfId, locationText: manualLocationController.text);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a location'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: Text('Save Location'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateTurfLocation(String turfId, {bool useCurrentLocation = false, String? locationText}) async {
    try {
      if (useCurrentLocation) {
        // Check location permission first
        LocationPermission permission = await Geolocator.checkPermission();
        
        if (permission == LocationPermission.denied) {
          // Request permission
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Location permission is required to get current location'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          // Show dialog to open settings
          bool? shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Location Permission Required'),
              content: Text('Location permission is permanently denied. Please enable it in settings to get current location.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.teal,
                  ),
                  child: Text('Open Settings'),
                ),
              ],
            ),
          );

          if (shouldOpenSettings == true) {
            await Geolocator.openAppSettings();
          }
          return;
        }

        // Check if location services are enabled
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please enable location services to get current location'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Get current position
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        locationText = '${position.latitude}, ${position.longitude}';
      }

      if (locationText != null) {
        await FirebaseFirestore.instance
            .collection('turfs')
            .doc(turfId)
            .update({
          'location': locationText,
          'hasLocation': true,
        });

        // Show success dialog
        await showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 40,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Location Updated',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Your turf location has been successfully updated.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Update the turf card's location warning section
  Widget _buildLocationWarning(String turfId) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(
          top: BorderSide(color: Colors.orange.shade200),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Location not set',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _showLocationPickerDialog(turfId),
            child: Text(
              'Add Now',
              style: TextStyle(
                color: Colors.teal.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
