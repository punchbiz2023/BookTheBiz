import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'statusfile.dart';
import '../../bookingpage.dart';
import '../../home_page.dart';
import '../../login.dart';
import '../../profile.dart';
import '../../settings.dart';
import 'turfadd.dart';
import '../Display- turfs/turf_details.dart';

class HomePage2 extends StatefulWidget {
  User? user;

  HomePage2({Key? key, this.user}) : super(key: key);

  @override
  _HomePage2State createState() => _HomePage2State();
}

class _HomePage2State extends State<HomePage2> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Position? _currentPosition;
  Stream<QuerySnapshot>? _turfsStream;
  int activeTurfs = 0;
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text;
        // Refresh the stream dynamically
      });
    });
    _checkCurrentUser();
    _setupTurfStream();
  }
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setupTurfStream() {
    setState(() {
      _turfsStream = (searchQuery.isEmpty)
          ? FirebaseFirestore.instance
          .collection('turfs')
          .where('ownerId', isEqualTo: widget.user?.uid)
          .snapshots()
          : FirebaseFirestore.instance
          .collection('turfs')
          .where('ownerId', isEqualTo: widget.user?.uid)
          .where('name', isGreaterThanOrEqualTo: searchQuery)
          .where('name', isLessThanOrEqualTo: searchQuery + '\uf8ff')
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
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.black87),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Text(
              "Turf Owner ",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            Icon(Icons.sports_soccer, color: Colors.white), // Replace with your desired icon
          ],
        ),
      ),
      backgroundColor: Colors.white,
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dark Blue Banner
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 230, // Adjust as needed
                            width: MediaQuery.of(context).size.width,
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade900,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(40),
                                bottomRight: Radius.circular(40),
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 30, horizontal: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Hi, $userName",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      "Manage your Turfs",
                                      style: TextStyle(color: Colors.white70, fontSize: 16),
                                    ),
                                    SizedBox(height: 20),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 120,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      top: 50,
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
                                          String formattedDate = "${today.year}-${today.month}-${today.day}"; // Ensure your date format matches Firestore format

                                          return StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('bookings')
                                                .where('turfId', isEqualTo: currentUserId)
                                                .where('bookingDate', isEqualTo: formattedDate) // Assuming 'bookingDate' is stored as a string in Firestore
                                                .snapshots(),
                                            builder: (context, bookingSnapshot) {
                                              int todayBookings = bookingSnapshot.hasData ? bookingSnapshot.data!.docs.length : 0;

                                              return Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                children: [
                                                  _buildDashboardCard("Active Turfs", activeTurfs, Colors.teal.shade900, Colors.grey.shade100),
                                                  _buildDashboardCard("Today's Bookings", todayBookings, Colors.teal.shade900, Colors.grey.shade100),
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


                SizedBox(height: 20),

                // Add Turf Button
                Center(
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
                      backgroundColor: isTurfOwner && isStatusYes ? Colors.teal : Colors.grey,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text('Add Turf', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Search Bar
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search Turf...',
                    hintStyle: TextStyle(color: Colors.black54),
                    prefixIcon: Icon(Icons.search, color: Colors.black87),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.black87),
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
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                SizedBox(height: 20),

                // Your Turfs Title
                Text(
                  'Your Turfs',
                  style: TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold),
                ),

                // Turf List
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
                      final turfData = doc.data() as Map<String, dynamic>;
                      final turfName = turfData['name']?.toString() ?? '';
                      return searchQuery.isEmpty || turfName.contains(searchQuery);
                    }).toList();

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
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboardCard(String title, int count, Color color1, Color color2) {
    return Container(
      padding: EdgeInsets.all(16),
      width: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color1, color2]),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 1),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count.toString(),
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white,fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }


  // Sidebar Drawer
  Widget _buildSidebar() {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.teal.shade900.withOpacity(0.9),
              Colors.teal.withOpacity(0.9),
            ],
          ),
        ),
        child: Column(
          children: [
            // Header with App Title
            Container(
              padding: EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white54, width: 1)),
              ),
              child: Text(
                'Turf Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // Menu List
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(top: 20),
                children: [
                  _buildSidebarItem(Icons.home, 'Home', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage2(user: widget.user)));
                  }),
                  _buildSidebarItem(Icons.person, 'Profile', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage(user: widget.user)));
                  }),
                ],
              ),
            ),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _buildSidebarItem(Icons.logout, 'Logout', () {
                // Handle logout
              }, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }


// Sidebar Item Helper Function
  Widget _buildSidebarItem(IconData icon, String title, VoidCallback onTap, {Color color = Colors.white}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      splashColor: Colors.white.withOpacity(0.2), // Smooth splash effect
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }



  // Turf Card UI
  Widget _buildTurfCard(Map<String, dynamic> turfData) {
    String turfId = turfData['turfId'] ?? ''; // Default to an empty
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 8,
      margin: EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10), // Rounded corners for the image
          child: Image.network(
            turfData['imageUrl'] ?? 'https://via.placeholder.com/80',
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 40, color: Colors.grey),
          ),
        ),
        title: Text(
          turfData['name'] ?? 'Unnamed Turf',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          turfData['description'] ?? 'No description available',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.teal[700]),
      ),
    )
    );
  }

  // Placeholder for Horizontal Cards
  Widget _buildPlaceholderCard() {
    return Container(width: 120, height: 100, color: Colors.grey[700], margin: EdgeInsets.only(right: 10));
  }
}
