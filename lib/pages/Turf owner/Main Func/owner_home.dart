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
import 'package:flutter/services.dart';
import 'spot_events_page.dart';
import 'event_bookings_page.dart';
import 'PendingClawbackDetailsPage.dart';
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
  /// Build pending clawback warning card
Widget buildPendingClawbackWarningCard() {
  final userId = widget.user?.uid;
  if (userId == null) return SizedBox();

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('manual_clawback_payments')
        .where('ownerId', isEqualTo: userId)
        .where('status', whereIn: ['pending_payment', 'overdue'])
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return SizedBox(); // No pending clawbacks
      }

      List<Map<String, dynamic>> pendingClawbacks = [];
      double totalAmount = 0;

      for (var doc in snapshot.data!.docs) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        pendingClawbacks.add(data);
        totalAmount += (data['amount'] ?? 0).toDouble();
      }

      // Calculate days overdue
      int maxDaysOverdue = 0;
      for (var clawback in pendingClawbacks) {
        if (clawback['createdAt'] != null) {
          DateTime createdDate = (clawback['createdAt'] as Timestamp).toDate();
          int days = DateTime.now().difference(createdDate).inDays;
          if (days > maxDaysOverdue) maxDaysOverdue = days;
        }
      }

      bool isUrgent = maxDaysOverdue > 10; // Red alert after 10 days

      return Container(
        margin: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isUrgent
                ? [Colors.red[700]!, Colors.red[500]!]
                : [Colors.orange[700]!, Colors.orange[500]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isUrgent ? Colors.red : Colors.orange).withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PendingClawbackDetailsPage(
                    pendingClawbacks: pendingClawbacks,
                    totalAmount: totalAmount,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isUrgent ? Icons.error : Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUrgent ? '🚨 URGENT ACTION REQUIRED' : '⚠️ Payment Required',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Pending for $maxDaysOverdue days',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Amount Section
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Outstanding Balance',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '₹${totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${pendingClawbacks.length} pending transaction(s)',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Warning Message
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isUrgent
                              ? 'Your account will be suspended if not paid immediately'
                              : 'Customer cancellations require settlement to continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PendingClawbackDetailsPage(
                                  pendingClawbacks: pendingClawbacks,
                                  totalAmount: totalAmount,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: isUrgent ? Colors.red[700] : Colors.orange[700],
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Pay Now',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PendingClawbackDetailsPage(
                                  pendingClawbacks: pendingClawbacks,
                                  totalAmount: totalAmount,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: BorderSide(color: Colors.white, width: 2),
                          ),
                          child: Text(
                            'Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
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
    return WillPopScope(
      onWillPop: () async {
        // Only show dialog if on root (not in a pushed page)
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.exit_to_app, color: Colors.red, size: 28),
                SizedBox(width: 10),
                Text('Exit App?'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sentiment_very_dissatisfied, color: Colors.orange, size: 48),
                SizedBox(height: 16),
                Text('Are you sure you want to leave this app?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Stay Here', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: Icon(Icons.exit_to_app, color: Colors.white),
                label: Text('Yes, Exit',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold,),),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
          return false;
        }
        return false;
      },
      child: Scaffold(
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
              final String? imageUrl = userData['imageUrl'];
              final bool isTurfOwner = userData['userType'] == 'Turf Owner';
              final bool isStatusYes = userData['status'] == 'yes';

              return FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Enhanced Banner ---
                    Container(
                      width: double.infinity,
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
                            color: Colors.teal.withOpacity(0.2),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 12,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                                    ? NetworkImage(imageUrl)
                                    : AssetImage('assets/default_profile.png') as ImageProvider,
                              ),
                            ),
                          ),
                          SizedBox(height: 18),
                          Center(
                            child: Text(
                              "Welcome back,",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(height: 4),
                          Center(
                            child: Text(
                              'Heyy! $userName',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          Center(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.sports_soccer, color: Colors.white, size: 22),
                                  SizedBox(width: 8),
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
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 28),
                    // --- Stats Cards ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
                                    child: Card(
                                      elevation: 7,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.sports_soccer, color: Colors.teal.shade700, size: 32),
                                            SizedBox(height: 10),
                                            Text(
                                              activeTurfs.toString(),
                                              style: TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal.shade800,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                            SizedBox(height: 6),
                                            Text(
                                              "Active Turfs",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.teal.shade700,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 18),
                                  Expanded(
                                    child: Card(
                                      elevation: 7,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.calendar_today, color: Colors.teal.shade600, size: 32),
                                            SizedBox(height: 10),
                                            Text(
                                              todayBookings.toString(),
                                              style: TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal.shade800,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                            SizedBox(height: 6),
                                            Text(
                                              "Today's Bookings",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.teal.shade700,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 28),
                    buildPendingClawbackWarningCard(),
                    SizedBox(height: 30),
                    // --- Add Turf Button ---
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => StatusFilePage()),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (isTurfOwner && isStatusYes)
                                ? Colors.teal.shade600
                                : Colors.grey,
                            padding: EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 8,
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
                    SizedBox(height: 28),
                    // --- Search Bar ---
                    
                    // --- Section Title ---
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
                    // --- Turf List ---
                    StreamBuilder<QuerySnapshot>(
                      stream: _turfsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 20),
        // Placeholder icon with subtle background
        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.teal.shade50,
          ),
          child: Icon(
            Icons.sports_soccer,
            size: 64,
            color: Colors.teal.shade400,
          ),
        ),

        const SizedBox(height: 20),

        // Main title
        Text(
          'No Turfs Available',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade800,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 10),

        // Subtitle / hint text
        Text(
          'Try searching with different filters\nor explore nearby locations.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 25),

        // Refresh / Explore button
        ElevatedButton.icon(
          onPressed: () {
            // Add refresh or navigation logic
          },
          icon: Icon(Icons.explore_outlined, size: 18),
          label: Text("Explore Again"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
          ),
        ),
      ],
    ),
  );
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
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(widget.user?.uid).get(),
      builder: (context, snapshot) {
        String userName = 'User';
        String? imageUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          userName = userData['name'] ?? 'User';
          imageUrl = userData['imageUrl'];
        }
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
                // --- Enhanced Header with Profile Image and Hey! ---
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
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                            ? NetworkImage(imageUrl)
                            : null,
                        child: (imageUrl == null || imageUrl.isEmpty)
                            ? Icon(Icons.person, color: Colors.white, size: 44)
                            : null,
                      ),
                      SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Hey! ',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              userName,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Turf Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Owner Dashboard',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // --- Menu List ---
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
      Icons.event_outlined,
      'Add Spot Events',
      () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SpotEventsPage(user: widget.user)),
        );
      },
    ),
    _buildSidebarItem(
      Icons.event_available,
      'Event Bookings',
      () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EventBookingsPage(user: widget.user)),
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
                                                    'ownersbtb@gmail.com',
                                                  ),
                                                  SizedBox(height: 10),
                                                  _buildContactItem(
                                                    Icons.phone_outlined,
                                                    'Phone',
                                                    '+91-8248708300',
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
                // --- Sign Out Button at Bottom ---
                Padding(
                  padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24, top: 8),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: Icon(Icons.logout, color: Colors.white),
                    label: Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => LoginApp()),
                        (route) => false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    String status = (turfData['turf_status'] ?? 'Not Verified').toString();

    // Status-based color logic
    Color cardColor;
    Color accentColor;
    IconData statusIcon;
    String statusText;
    
    switch (status.toLowerCase()) {
      case 'verified':
        cardColor = Colors.green.shade50;
        accentColor = Colors.green.shade600;
        statusIcon = Icons.check_circle;
        statusText = 'Verified';
        break;
      case 'not verified':
        cardColor = Colors.orange.shade50;
        accentColor = Colors.orange.shade600;
        statusIcon = Icons.pending;
        statusText = 'Pending Review';
        break;
      case 'disapproved':
        cardColor = Colors.red.shade50;
        accentColor = Colors.red.shade600;
        statusIcon = Icons.cancel;
        statusText = 'Disapproved';
        break;
      default:
        cardColor = Colors.grey.shade100;
        accentColor = Colors.grey.shade600;
        statusIcon = Icons.help;
        statusText = status;
    }

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
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
          border: Border(
            left: BorderSide(color: accentColor, width: 6),
          ),
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
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    statusIcon,
                                    color: accentColor,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      color: accentColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
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
                  // Show rejection reason if turf is disapproved
                  if (status.toLowerCase() == 'disapproved' && turfData['rejectionReason'] != null)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.red.shade700, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Rejection Reason:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            turfData['rejectionReason'],
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 12,
                            ),
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