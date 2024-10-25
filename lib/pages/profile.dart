import 'dart:io'; // For working with File
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'login.dart';

class ProfilePage extends StatefulWidget {
  final User? user; // User object to hold Firebase user information

  const ProfilePage({Key? key, this.user}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginApp()),
            (Route<dynamic> route) => false, // Remove all previous routes
      );
    } catch (e) {
      print('Error logging out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user ?? FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // Return to the previous screen
          },
        ),
      ),
      backgroundColor: Color(0xff192028),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: user?.email)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text('User not found'));
            }

            final userData = snapshot.data!.docs.first.data() as Map<String, dynamic>;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 80,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : AssetImage('assets/profile_picture.png') as ImageProvider,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.camera_alt, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Name: ' + userData['name'] ?? 'Username', // Display user's name
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Email: ' + (user?.email ?? 'email@example.com'),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                  ),
                ),

                SizedBox(height: 10),
                Text(
                  'Mobile Number: '+userData['mobile'] ?? 'Mobile number not available', // Display mobile number
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 10),
                // Text(
                //   userData['userType'] ?? 'User Type', // Display user's type
                //   style: TextStyle(
                //     color: Colors.grey[400],
                //     fontSize: 16,
                //   ),
                // ),
                SizedBox(height: 30),
                // Container(
                //   padding: EdgeInsets.all(16),
                //   decoration: BoxDecoration(
                //     color: Colors.black54,
                //     borderRadius: BorderRadius.circular(10),
                //   ),
                //   // child: Column(
                //   //   crossAxisAlignment: CrossAxisAlignment.start,
                //   //   children: [
                //   //     Text(
                //   //       'About Me',
                //   //       style: TextStyle(
                //   //         color: Colors.white,
                //   //         fontSize: 22,
                //   //         fontWeight: FontWeight.bold,
                //   //       ),
                //   //     ),
                //   //     SizedBox(height: 10),
                //   //     Text(
                //   //       'This is a brief description about the user. You can add more details here.',
                //   //       style: TextStyle(
                //   //         color: Colors.white70,
                //   //         fontSize: 16,
                //   //       ),
                //   //     ),
                //   //   ],
                //   // ),
                // ),Container(
                //   padding: EdgeInsets.all(16),
                //   decoration: BoxDecoration(
                //     color: Colors.black54,
                //     borderRadius: BorderRadius.circular(10),
                //   ),
                //   // child: Column(
                //   //   crossAxisAlignment: CrossAxisAlignment.start,
                //   //   children: [
                //   //     Text(
                //   //       'About Me',
                //   //       style: TextStyle(
                //   //         color: Colors.white,
                //   //         fontSize: 22,
                //   //         fontWeight: FontWeight.bold,
                //   //       ),
                //   //     ),
                //   //     SizedBox(height: 10),
                //   //     Text(
                //   //       'This is a brief description about the user. You can add more details here.',
                //   //       style: TextStyle(
                //   //         color: Colors.white70,
                //   //         fontSize: 16,
                //   //       ),
                //   //     ),
                //   //   ],
                //   // ),
                // ),
                SizedBox(height: 30),
                Center(
                  child: ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
