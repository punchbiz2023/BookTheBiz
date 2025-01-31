import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class StatusFilePage extends StatefulWidget {
  @override
  _StatusFilePageState createState() => _StatusFilePageState();
}

class _StatusFilePageState extends State<StatusFilePage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _gstController = TextEditingController();
  String? _aadharBase64;
  String? _panBase64;
  bool _isGstValid = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _statusMessage = "User not logged in.";
      });
      return;
    }

    final userId = user.uid;

    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final status = data?['status'];

        if (status == 'Disagree') {
          setState(() {
            _statusMessage = "Your account is not verified. Please try again later.";
          });
        } else if (status == 'Not Verified') {
          setState(() {
            _statusMessage = "Your verification is denied. Try again later.";
          });
        } else if (status == 'Not Confirmed') {
          setState(() {
            _statusMessage = "Your account is under verification, and it might take a while.";
          });
        } else {
          setState(() {
            _statusMessage = null; // Allow the form to be shown
          });
        }
      } else {
        setState(() {
          _statusMessage = "User record not found. Please contact support.";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error fetching status: $e";
      });
    }
  }


  Future<void> _pickImage(String type) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);

      setState(() {
        if (type == 'aadhar') {
          _aadharBase64 = base64String;
        } else if (type == 'pan') {
          _panBase64 = base64String;
        }
      });
    }
  }

  Future<void> _submitDetails() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    final userId = user.uid;

    if (_gstController.text.isEmpty || _aadharBase64 == null || _panBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please complete all fields")),
      );
      return;
    }

    try {
      // Update or create document in `documents` collection
      await FirebaseFirestore.instance.collection('documents').doc(userId).set({
        'userId': userId,
        'gst': _gstController.text,
        'aadhar': _aadharBase64,
        'pan': _panBase64,
      });

      // Update `status` field in `users` collection
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'status': 'Not Confirmed',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Details submitted successfully")),
      );

      setState(() {
        _statusMessage = "Your details have been submitted and are under review.";
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving details: $e")),
      );
    }
  }

  Widget _buildStatusMessage(String message, IconData icon, Color iconColor, Color textColor) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 40),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 16, color: textColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String title,
    required TextEditingController controller,
    required bool isValid,
    required Function(String) onChanged,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? Colors.green : Colors.grey[400]!,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: title,
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
          if (isValid)
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 24,
            ),
        ],
      ),
    );
  }

  Widget _buildUploadTile(String title, String? base64, String type) {
    return GestureDetector(
      onTap: () => _pickImage(type),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: base64 != null ? Colors.green : Colors.grey[400]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  base64 != null ? Icons.check_circle : Icons.camera_alt,
                  color: base64 != null ? Colors.green : Colors.grey[600],
                  size: 28,
                ),
                SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              base64 != null ? "Uploaded" : "Upload",
              style: TextStyle(
                fontSize: 16,
                color: base64 != null ? Colors.green : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Status"),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _statusMessage != null
            ? _buildStatusMessage(
          _statusMessage!,
          _statusMessage!.contains('not') ? Icons.error : Icons.check_circle,
          _statusMessage!.contains('not') ? Colors.red : Colors.green,
          _statusMessage!.contains('not') ? Colors.red : Colors.green,
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heading
            Text(
              "Account Verification Status",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16),

            // Status message
            Text(
              "Upload your GST, Aadhaar, and PAN details to proceed with account verification.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 24),

            // GST Input
            _buildTextField(
              title: "Enter GST Number",
              controller: _gstController,
              isValid: _isGstValid,
              onChanged: (value) {
                setState(() {
                  _isGstValid = value.isNotEmpty && value.length == 15; // Basic validation
                });
              },
            ),

            // Aadhaar and PAN Upload Tiles
            _buildUploadTile("Upload Aadhaar Image", _aadharBase64, "aadhar"),
            _buildUploadTile("Upload PAN Image", _panBase64, "pan"),

            SizedBox(height: 24),

            // Submit button
            Center(
              child: ElevatedButton(
                onPressed: _submitDetails,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.teal,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  "Submit Details",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
