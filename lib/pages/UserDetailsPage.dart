import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';
import 'dart:ui';
import 'package:open_file/open_file.dart';
import 'package:pdfx/pdfx.dart';
import 'package:http/http.dart' as http;

class UserDetailsPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const UserDetailsPage({Key? key, required this.userData}) : super(key: key);

  @override
  _UserDetailsPageState createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = false;
  bool isPdfLoading = true;
  PdfController? _pdfController;
  Map<String, dynamic>? documentData;
  List<Map<String, dynamic>> userTurfs = [];
  bool isDocumentsLoading = true;
  bool isTurfsLoading = true;
  Map<String, dynamic>? fullUserData;

  @override
  void initState() {
    super.initState();
    _fetchFullUserData();
    _fetchUserDocuments();
    _fetchUserTurfs();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _fetchFullUserData() async {
    try {
      final String userId = widget.userData['userId'] ?? '';
      if (userId.isNotEmpty) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          setState(() {
            fullUserData = userDoc.data();
          });
        }
      }
    } catch (e) {
      print('Error fetching full user data: $e');
    }
  }

  Future<void> _fetchUserDocuments() async {
    try {
      final String userId = widget.userData['userId'] ?? '';
      if (userId.isNotEmpty) {
        final querySnapshot = await _firestore
            .collection('documents')
            .where('userId', isEqualTo: userId)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          setState(() {
            documentData = querySnapshot.docs.first.data();
            isDocumentsLoading = false;
          });
        } else {
          setState(() {
            isDocumentsLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching documents: $e');
      setState(() {
        isDocumentsLoading = false;
      });
    }
  }

  Future<void> _fetchUserTurfs() async {
    try {
      final String userId = widget.userData['userId'] ?? '';
      if (userId.isNotEmpty) {
        final querySnapshot = await _firestore
            .collection('turfs')
            .where('ownerId', isEqualTo: userId)
            .get();
        
        List<Map<String, dynamic>> turfs = [];
        for (var doc in querySnapshot.docs) {
          turfs.add(doc.data());
        }
        
        setState(() {
          userTurfs = turfs;
          isTurfsLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching turfs: $e');
      setState(() {
        isTurfsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = widget.userData;
    final String userId = userData['userId'] ?? '';
    final String name = userData['name'] ?? 'Unknown';
    final String email = userData['email'] ?? 'Unknown';
    final String mobile = userData['mobile'] ?? 'Unknown';
    final String gstNumber = userData['gst'] ?? 'Not Provided';
    final bool isConfirmed = userData['status'] == 'yes';
    
    // Get document data
    final String? aadharUrl = documentData?['aadhar'];
    final String? panBase64 = documentData?['pan'];
    final String? aadharFileName = documentData?['aadharFileName'];
    final String? aadhar = documentData?['aadhar'];
    
    // Get profile image URL
    final String? profileImageUrl = fullUserData?['imageUrl'];

    return Scaffold(
      appBar: AppBar(
        title: Text('User Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[600],
        elevation: 0,
        actions: [
          if (!isConfirmed)
            IconButton(
              icon: Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _approveUser(userData['userId']),
              tooltip: 'Approve User',
            ),
          if (!isConfirmed)
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _showRejectionDialog(userData['userId']),
              tooltip: 'Reject User',
            ),
        ],
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
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Card with Glassmorphism
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 5,
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.8),
                      Colors.white.withOpacity(0.4),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal[400]!, Colors.teal[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Profile Image with elegant border
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.8),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: profileImageUrl != null && profileImageUrl.isNotEmpty
                                      ? Image.network(
                                          profileImageUrl,
                                          fit: BoxFit.cover,
                                          width: 84,
                                          height: 84,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 84,
                                              height: 84,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.3),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 40,
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          width: 84,
                                          height: 84,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.3),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    if (isConfirmed)
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.verified, color: Colors.white, size: 16),
                                            SizedBox(width: 4),
                                            Text(
                                              'VERIFIED',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24),
                          
                          // Email Card
                          Container(
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white.withOpacity(0.2),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.email, color: Colors.white, size: 24),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Email Address',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          email,
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
                          ),
                          
                          // Phone Card
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white.withOpacity(0.2),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.phone, color: Colors.white, size: 24),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Phone Number',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          mobile,
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),

              // GST Card with Glassmorphism
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.8),
                      Colors.white.withOpacity(0.5),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.receipt, color: Colors.teal, size: 28),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GST Number',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  gstNumber,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30),

              // Documents Section with Glassmorphism
              Text(
                'Documents',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),

              // Aadhaar Document with Glassmorphism
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.8),
                      Colors.white.withOpacity(0.5),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Aadhaar Document',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          if (isDocumentsLoading)
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (aadharUrl != null && aadharUrl.isNotEmpty) ...[
                            // Modern Aadhaar Document Display
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.teal.shade100.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.picture_as_pdf, color: Colors.red, size: 40),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          aadharFileName ?? 'Aadhaar Document',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Tap to view the full document',
                                          style: TextStyle(
                                            color: Colors.teal.shade700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AadhaarPdfFullScreenPage(
                                            pdfUrl: aadharUrl,
                                            fileName: aadharFileName ?? 'Aadhaar Document',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: Icon(Icons.open_in_new, color: Colors.white, size: 18),
                                    label: Text('View', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),
                            if (aadharFileName != null && aadharFileName.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AadhaarPdfFullScreenPage(pdfUrl: aadharUrl, fileName: aadharFileName),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100]?.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[300]!.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.description, color: Colors.grey[600], size: 20),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          aadharFileName,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.open_in_new, color: Colors.teal, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                          ] else ...[
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red[50]?.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red[200]!.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error, color: Colors.red, size: 20),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Aadhaar document not uploaded',
                                      style: TextStyle(color: Colors.red[700]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // PAN Document with Glassmorphism
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.8),
                      Colors.white.withOpacity(0.5),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.credit_card, color: Colors.blue, size: 28),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'PAN Card',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          if (isDocumentsLoading)
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (panBase64 != null && panBase64.isNotEmpty) ...[
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
                              ),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                    child: Image.memory(
                                      base64Decode(panBase64),
                                      fit: BoxFit.cover,
                                      height: 200,
                                      width: double.infinity,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 200,
                                          color: Colors.blue.shade50,
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.credit_card, color: Colors.blue, size: 48),
                                                SizedBox(height: 12),
                                                Text(
                                                  'PAN Card Image',
                                                  style: TextStyle(
                                                    color: Colors.blue.shade700,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Error loading image',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50.withOpacity(0.7),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.zoom_in, color: Colors.blue, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'PAN Card Preview',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red[50]?.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red[200]!.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error, color: Colors.red, size: 20),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'PAN card not uploaded',
                                      style: TextStyle(color: Colors.red[700]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30),

              // User Turfs Section with Glassmorphism
              Text(
                'Turfs Managed by User',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              
              if (isTurfsLoading)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (userTurfs.isEmpty)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.8),
                        Colors.white.withOpacity(0.5),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.sports_soccer, color: Colors.grey, size: 48),
                              SizedBox(height: 16),
                              Text(
                                'No turfs found for this user',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: userTurfs.map((turf) => _buildTurfCard(turf)).toList(),
                ),
              
              SizedBox(height: 30),

              // Action Buttons (only for unconfirmed users)
              if (!isConfirmed) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : () => _approveUser(userData['userId']),
                        icon: isLoading
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(Icons.check_circle, color: Colors.white),
                        label: Text(
                          isLoading ? 'Processing...' : 'Approve User',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : () => _showRejectionDialog(userData['userId']),
                        icon: Icon(Icons.cancel, color: Colors.white),
                        label: Text(
                          'Reject User',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTurfCard(Map<String, dynamic> turf) {
    final String name = turf['name'] ?? 'Unknown Turf';
    final String description = turf['description'] ?? 'No description available';
    final String location = turf['location'] ?? 'Location not specified';
    final String turfStatus = turf['turf_status'] ?? 'Unknown';
    final String? imageUrl = turf['imageUrl'];
    final List<dynamic> availableGrounds = turf['availableGrounds'] ?? [];
    final List<dynamic> facilities = turf['facilities'] ?? [];
    final Map<String, dynamic> price = turf['price'] ?? {};
    
    // Determine status color
    Color statusColor;
    if (turfStatus == 'Approved') {
      statusColor = Colors.green;
    } else if (turfStatus == 'Disapproved' || turfStatus == 'Disagree') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.orange;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.8),
            Colors.white.withOpacity(0.5),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Turf Image
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Image.network(
                    imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 160,
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                              SizedBox(height: 8),
                              Text(
                                'Image not available',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              
              // Turf Details
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Turf Name and Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            turfStatus,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    
                    // Turf Description
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),
                    
                    // Location
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.location_on, color: Colors.teal, size: 18),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    
                    // Available Grounds
                    if (availableGrounds.isNotEmpty) ...[
                      Text(
                        'Available Grounds',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: availableGrounds.map((ground) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              ground.toString(),
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 12),
                    ],
                    
                    // Facilities
                    if (facilities.isNotEmpty) ...[
                      Text(
                        'Facilities',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: facilities.map((facility) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.purple.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              facility.toString(),
                              style: TextStyle(
                                color: Colors.purple.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 12),
                    ],
                    
                    // Price Information
                    if (price.isNotEmpty) ...[
                      Text(
                        'Price Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 6),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: price.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '₹${entry.value}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveUser(String userID) async {
    setState(() => isLoading = true);
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        final adminData = userDoc.data();
        if (adminData != null) {
          final customerDoc = await _firestore.collection('users').doc(userID).get();
          final customerData = customerDoc.data();
          String? razorpayId = customerData?['razorpayAccountId'];
          
          if (razorpayId == null || !razorpayId.toString().trim().startsWith('acc_')) {
            final TextEditingController rzpController = TextEditingController();
            bool valid = false;
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) {
                return StatefulBuilder(
                  builder: (context, setState) {
                    return AlertDialog(
                      title: Text('Enter Razorpay Account ID'),
                      content: TextField(
                        controller: rzpController,
                        decoration: InputDecoration(
                          labelText: 'Razorpay Account ID (acc_...)',
                          hintText: 'acc_1234567890abcdef',
                          errorText: valid || rzpController.text.isEmpty || rzpController.text.startsWith('acc_') ? null : 'Must start with acc_',
                        ),
                        onChanged: (val) {
                          setState(() {
                            valid = val.trim().startsWith('acc_');
                          });
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (rzpController.text.trim().startsWith('acc_')) {
                              await _firestore.collection('users').doc(userID).update({
                                'razorpayAccountId': rzpController.text.trim(),
                              });
                              Navigator.pop(ctx);
                            }
                          },
                          child: Text('Save'),
                        ),
                      ],
                    );
                  },
                );
              },
            );
            final updatedDoc = await _firestore.collection('users').doc(userID).get();
            razorpayId = updatedDoc.data()?['razorpayAccountId'];
          }
          
          if (razorpayId != null && razorpayId.toString().trim().startsWith('acc_')) {
            await _firestore.collection('users').doc(userID).update({
              'status': 'yes',
              'verifiedby': {
                'id': currentUser.uid,
                'name': adminData['name'],
                'mobile': adminData['mobile'],
              }
            });
            Fluttertoast.showToast(msg: 'User approved successfully!');
            Navigator.pop(context);
          } else {
            Fluttertoast.showToast(msg: 'Approval requires a valid Razorpay Account ID.');
          }
        } else {
          Fluttertoast.showToast(msg: 'Admin data not found');
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error approving user: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _showRejectionDialog(String userID) async {
    final TextEditingController reasonController = TextEditingController();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.cancel, color: Colors.red),
              SizedBox(width: 8),
              Text('Rejection Reason'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please provide a reason for rejecting this user:'),
              SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isNotEmpty) {
                  await _rejectUser(userID, reasonController.text.trim());
                  Navigator.pop(ctx);
                } else {
                  Fluttertoast.showToast(msg: 'Please provide a rejection reason');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _rejectUser(String userID, String reason) async {
    setState(() => isLoading = true);
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        final userData = userDoc.data();

        if (userData != null) {
          await _firestore.collection('users').doc(userID).update({
            'status': 'Disagree',
            'rejectionReason': reason,
            'verifiedby': {
              'id': currentUser.uid,
              'name': userData['name'],
              'mobile': userData['mobile'],
            }
          });

          Fluttertoast.showToast(msg: 'User rejected successfully!');
          Navigator.pop(context);
        } else {
          Fluttertoast.showToast(msg: 'User data not found');
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error rejecting user: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }
}

// Aadhaar Document Preview Widget
class AadhaarPdfPreview extends StatelessWidget {
  final String url;
  const AadhaarPdfPreview({required this.url});
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PdfDocument>(
      future: _loadPdf(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.red, size: 48),
                SizedBox(height: 8),
                Text('Error loading PDF'),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AadhaarPdfFullScreenPage(
                          pdfUrl: url,
                          fileName: 'Aadhaar Document',
                        ),
                      ),
                    );
                  },
                  child: Text('Try opening in full screen'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.red, size: 48),
                SizedBox(height: 8),
                Text('PDF not available'),
              ],
            ),
          );
        }
        return SizedBox(
          height: 160,
          child: PdfView(
            controller: PdfController(document: Future.value(snapshot.data!)),
            builders: PdfViewBuilders<DefaultBuilderOptions>(
              options: DefaultBuilderOptions(),
              documentLoaderBuilder: (_) => Center(child: CircularProgressIndicator()),
              pageLoaderBuilder: (_) => Center(child: CircularProgressIndicator()),
              errorBuilder: (_, error) => Center(child: Text('Failed to load PDF')),
            ),
            scrollDirection: Axis.horizontal,
          ),
        );
      },
    );
  }
  
  static Future<PdfDocument> _loadPdf(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return PdfDocument.openData(response.bodyBytes);
      } else {
        throw Exception('Failed to load PDF: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading PDF: $e');
    }
  }
}

class AadhaarPdfFullScreenPage extends StatefulWidget {
  final String pdfUrl;
  final String fileName;
  const AadhaarPdfFullScreenPage({required this.pdfUrl, required this.fileName});
  
  @override
  State<AadhaarPdfFullScreenPage> createState() => _AadhaarPdfFullScreenPageState();
}

class _AadhaarPdfFullScreenPageState extends State<AadhaarPdfFullScreenPage> {
  PdfController? _controller;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final document = await AadhaarPdfPreview._loadPdf(widget.pdfUrl);
      setState(() {
        _controller = PdfController(document: Future.value(document));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loading = true;
                _errorMessage = null;
              });
              _loadPdf();
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Failed to load PDF',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Try to open in external viewer
                          OpenFile.open(widget.pdfUrl);
                        },
                        icon: Icon(Icons.open_in_new),
                        label: Text('Open in External Viewer'),
                      ),
                    ],
                  ),
                )
              : _controller == null
                  ? Center(child: Text('PDF controller not initialized'))
                  : PdfView(
                      controller: _controller!,
                      scrollDirection: Axis.vertical,
                      builders: PdfViewBuilders<DefaultBuilderOptions>(
                        options: DefaultBuilderOptions(),
                        documentLoaderBuilder: (_) => Center(child: CircularProgressIndicator()),
                        pageLoaderBuilder: (_) => Center(child: CircularProgressIndicator()),
                        errorBuilder: (_, error) => Center(child: Text('Failed to load PDF')),
                      ),
                    ),
    );
  }
}