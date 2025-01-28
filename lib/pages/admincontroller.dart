import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login.dart';

class AdminControllersPage extends StatefulWidget {
  @override
  _AdminControllersPageState createState() => _AdminControllersPageState();
}

class _AdminControllersPageState extends State<AdminControllersPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lists for users with different statuses
  List<Map<String, dynamic>> notConfirmedUsers = [];
  List<Map<String, dynamic>> confirmedUsers = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

    List<Map<String, dynamic>> tempNotConfirmed = [];
    List<Map<String, dynamic>> tempConfirmed = [];

    for (var userDoc in usersSnapshot.docs) {
      var userData = userDoc.data() as Map<String, dynamic>;
      String userId = userDoc.id;

      var documentData = await _fetchDocumentData(userId);

      if (documentData != null) {
        userData['userId'] = userId;
        userData['gst'] = documentData['gst'] ?? 'Not Provided';
        userData['aadhar'] = documentData['aadhar'] ?? null;
        userData['pan'] = documentData['pan'] ?? null;
      }

      if (userData['status'] == 'Not Confirmed') {
        tempNotConfirmed.add(userData);
      } else if (userData['status'] == 'yes') {
        tempConfirmed.add(userData);
      }
    }

    setState(() {
      notConfirmedUsers = tempNotConfirmed;
      confirmedUsers = tempConfirmed;
    });
  }

  Future<Map<String, dynamic>?> _fetchDocumentData(String userId) async {
    DocumentSnapshot documentSnapshot =
    await _firestore.collection('documents').doc(userId).get();

    if (documentSnapshot.exists) {
      return documentSnapshot.data() as Map<String, dynamic>;
    }
    return null;
  }

  void _showUserDetails(Map<String, dynamic> userData) {
    String? aadharBase64 = userData['aadhar'];
    String? panBase64 = userData['pan'];
    final String userID = userData['userId'];

    Widget aadharImageWidget = aadharBase64 != null
        ? ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        base64Decode(aadharBase64),
        fit: BoxFit.cover,
        height: 150,
        width: double.infinity,
      ),
    )
        : Text('Aadhar not available',
        style: TextStyle(
            color: Colors.teal[300], fontStyle: FontStyle.italic));

    Widget panImageWidget = panBase64 != null
        ? ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        base64Decode(panBase64),
        fit: BoxFit.cover,
        height: 150,
        width: double.infinity,
      ),
    )
        : Text('PAN not available',
        style: TextStyle(
            color: Colors.teal[300], fontStyle: FontStyle.italic));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 16,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal[400]!, Colors.teal[600]!],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Documents',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 20),
                Text('Aadhar Card:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 10),
                aadharImageWidget,
                SizedBox(height: 20),
                Text('PAN Card:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 10),
                panImageWidget,
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _firestore.collection('users').doc(userID).update({
                          'status': 'yes',
                        });
                        Navigator.pop(context);
                        fetchUserData();
                      },
                      icon: Icon(Icons.check, color: Colors.white),
                      label:
                      Text('Approve', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _firestore.collection('users').doc(userID).update({
                          'status': 'Not Confirmed',
                        });
                        Navigator.pop(context);
                        fetchUserData();
                      },
                      icon: Icon(Icons.cancel, color: Colors.white),
                      label:
                      Text('Disagree', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.1),
              ),
              padding: EdgeInsets.all(20),
              child: Icon(
                Icons.person_off,
                size: 80,
                color: Colors.blueAccent,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Please try again later or refresh.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    } else {
      return ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          var userData = users[index];
          String name = userData['name'] ?? 'Unknown';
          String email = userData['email'] ?? 'Unknown';
          String mobile = userData['mobile'] ?? 'Unknown';
          String gstNumber = userData['gst'] ?? 'Not Provided';
          bool isConfirmed = userData['status'] == 'yes';

          return Card(
            margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.teal[500],
                    child: Text(
                      name[0].toUpperCase(),
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                            if (isConfirmed) ...[
                              SizedBox(width: 8),
                              Icon(
                                Icons.check_circle,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ]
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.teal[600],
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          mobile,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.teal[600],
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'GST: $gstNumber',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.teal[600],
                          ),
                        ),
                        if (isConfirmed)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.remove_red_eye,
                      color: Colors.teal[700],
                      size: 28,
                    ),
                    onPressed: () {
                      _showUserDetails(userData);
                    },
                    tooltip: 'View Details',
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Perform logout operations, such as clearing user session data
    // For example, if using Firebase Authentication:
    await FirebaseAuth.instance.signOut();

    // Navigate to the login screen and remove all previous routes
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginApp()),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal[600],
        title: Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Not Confirmed'),
            Tab(text: 'Confirmed'),
          ],
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.teal[800],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          labelStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          overlayColor: MaterialStateProperty.all(Colors.transparent),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            style: IconButton.styleFrom(
              foregroundColor: Colors.red, // Set the icon color to red
            ),
            onPressed: () {
              _handleLogout(context);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(notConfirmedUsers),
          _buildUserList(confirmedUsers),
        ],
      ),
    );
  }
}
