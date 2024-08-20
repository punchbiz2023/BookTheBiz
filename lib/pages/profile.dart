import 'dart:io'; // For working with File

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:odp/pages/home_page.dart';

class ProfilePage extends StatefulWidget {
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

  @override
  Widget build(BuildContext context) {
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomePage1()),
            );
          },
        ),
      ),
      backgroundColor: Color(0xff192028),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
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
                      : AssetImage('assets/profile_picture.png')
                          as ImageProvider,
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
              'Username', // Placeholder text
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'email@example.com', // Placeholder text
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
              ),
            ),
            SizedBox(height: 30),
            // Add a profile details section
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Me',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'This is a brief description about the user. You can add more details here.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
