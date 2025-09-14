import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:open_file/open_file.dart';

class StatusFilePage extends StatefulWidget {
  const StatusFilePage({super.key});

  @override
  _StatusFilePageState createState() => _StatusFilePageState();
}

class _StatusFilePageState extends State<StatusFilePage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _gstController = TextEditingController();
  String? _aadharUrl;
  String? _panBase64;
  String? _aadharFileName;
  bool _isGstValid = false;
  bool _hasGST = false;
  String? _statusMessage;
  String? _rejectionReason;
  bool _isEditing = false;

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
        final rejectionReason = data?['rejectionReason'];

        if (status == 'Disagree') {
          setState(() {
            _statusMessage = "Your account verification was rejected.";
            _rejectionReason = rejectionReason;
          });
          // Load existing data for editing
          await _loadExistingData();
        } else if (status == 'Not Verified') {
          setState(() {
            _statusMessage = "Your verification is denied. Try again later.";
            _rejectionReason = rejectionReason;
          });
          // Load existing data for editing
          await _loadExistingData();
        } else if (status == 'Not Confirmed') {
          setState(() {
            _statusMessage = "Your account is under verification, and it might take a while. You can edit your details while waiting.";
          });
          // Load existing data for editing
          await _loadExistingData();
        } else if (status == 'yes') {
          setState(() {
            _statusMessage = "Your account has been verified successfully!";
          });
        } else {
          setState(() {
            _statusMessage = null;
          });
          // Load existing data if user wants to edit
          await _loadExistingData();
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

  Future<void> _loadExistingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('documents').doc(user.uid).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        setState(() {
          _aadharUrl = data?['aadhar'];
          _panBase64 = data?['pan'];
          _aadharFileName = data?['aadharFileName'];
          _gstController.text = data?['gst'] ?? '';
          _hasGST = data?['gst'] != null && data!['gst'].isNotEmpty;
          _isGstValid = _hasGST && _gstController.text.length == 15;
          _isEditing = true;
        });
      }
    } catch (e) {
      print('Error loading existing data: $e');
    }
  }

  Future<void> _pickImage(String type) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        if (type == 'pan') {
          _panBase64 = base64String;
        }
      });
    }
  }

  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final ref = FirebaseStorage.instance.ref().child('aadhaar_pdfs/${user.uid}/$fileName');
          final uploadTask = await ref.putFile(file);
          final url = await ref.getDownloadURL();
          setState(() {
            _aadharUrl = url;
            _aadharFileName = fileName;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking/uploading PDF: $e')),
      );
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
    
    if (_hasGST && (_gstController.text.isEmpty || !_isGstValid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a valid GST number")),
      );
      return;
    }
    
    if (_aadharUrl == null || _panBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please complete all required fields")),
      );
      return;
    }

    try {
      Map<String, dynamic> documentData = {
        'userId': userId,
        'aadhar': _aadharUrl,
        'pan': _panBase64,
        'aadharFileName': _aadharFileName,
        'submittedAt': FieldValue.serverTimestamp(),
      };
      
      if (_hasGST) {
        documentData['gst'] = _gstController.text;
      }

      await FirebaseFirestore.instance
          .collection('documents')
          .doc(userId)
          .set(documentData);

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'status': 'Not Confirmed',
        'rejectionReason': null, // Clear any previous rejection reason
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? "Details updated successfully" : "Details submitted successfully"),
          backgroundColor: Colors.green,
        ),
      );

      Future.delayed(Duration(seconds: 1), () {
        Navigator.pushReplacementNamed(context, '/homepage1');
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving details: $e")),
      );
    }
  }

  Widget _buildStatusMessage(String message, IconData icon, Color iconColor, Color textColor) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 40),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (_rejectionReason != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rejection Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _rejectionReason!,
                      style: TextStyle(color: Colors.red[600]),
                    ),
                  ],
                ),
              ),
            ],
            // Show edit button for all unapproved statuses (Not Confirmed, Disagree, Not Verified)
            if (_isEditing || _rejectionReason != null) ...[
              SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _statusMessage = null;
                      _rejectionReason = null;
                    });
                  },
                  icon: Icon(Icons.edit, color: Colors.white),
                  label: Text('Edit Details', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String title,
    required TextEditingController controller,
    required bool isValid,
    required Function(String) onChanged,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: title,
            border: InputBorder.none,
            suffixIcon: isValid
                ? Icon(Icons.check_circle, color: Colors.green)
                : null,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildUploadTile(String title, String? url, String type, {String? fileName}) {
    return GestureDetector(
      onTap: () async {
        if (type == 'aadhar') {
          if (url != null) {
            await OpenFile.open(url);
          } else {
            await _pickPDF();
          }
        } else {
          await _pickImage(type);
        }
      },
      child: Card(
        elevation: 2,
        margin: EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      url != null ? Icons.check_circle : (type == 'aadhar' ? Icons.picture_as_pdf : Icons.camera_alt),
                      color: url != null ? Colors.green : Colors.grey[600],
                      size: 28,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (fileName != null && url != null)
                            Text(
                              fileName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                url != null ? "Uploaded" : "Upload",
                style: TextStyle(
                  fontSize: 16,
                  color: url != null ? Colors.green : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGSTOption() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Do you have a GST number?",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                ChoiceChip(
                  label: Text("Yes"),
                  selected: _hasGST,
                  selectedColor: Colors.teal.shade100,
                  onSelected: (selected) {
                    setState(() {
                      _hasGST = true;
                    });
                  },
                ),
                SizedBox(width: 16),
                ChoiceChip(
                  label: Text("No"),
                  selected: !_hasGST,
                  selectedColor: Colors.teal.shade100,
                  onSelected: (selected) {
                    setState(() {
                      _hasGST = false;
                      _gstController.clear();
                      _isGstValid = false;
                    });
                  },
                ),
              ],
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
        title: Text("Account Verification",style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold,),),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: _statusMessage != null
              ? _buildStatusMessage(
                  _statusMessage!,
                  _statusMessage!.toLowerCase().contains('not') || _rejectionReason != null
                      ? Icons.error
                      : Icons.check_circle,
                  _statusMessage!.toLowerCase().contains('not') || _rejectionReason != null
                      ? Colors.red
                      : Colors.green,
                  _statusMessage!.toLowerCase().contains('not') || _rejectionReason != null
                      ? Colors.red
                      : Colors.green,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.teal[400]!, Colors.teal[600]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.verified_user, color: Colors.white, size: 32),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Account Verification",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Upload your Aadhaar PDF and PAN image to proceed with account verification.",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    _buildGSTOption(),

                    if (_hasGST)
                      _buildTextField(
                        title: "Enter GST Number",
                        controller: _gstController,
                        isValid: _isGstValid,
                        onChanged: (value) {
                          setState(() {
                            _isGstValid = value.isNotEmpty && value.length == 15;
                          });
                        },
                      ),

                    _buildUploadTile("Upload Aadhaar PDF", _aadharUrl, "aadhar", fileName: _aadharFileName),
                    _buildUploadTile("Upload PAN Image", _panBase64, "pan"),

                    SizedBox(height: 24),

                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _submitDetails,
                        icon: Icon(_isEditing ? Icons.update : Icons.send, color: Colors.white),
                        label: Text(
                          _isEditing ? "Update Details" : "Submit Details",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}