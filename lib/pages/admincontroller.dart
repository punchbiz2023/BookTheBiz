import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'clawback.dart';
import 'login.dart';
import 'AdminSupportTicketsPage.dart';
import 'UserDetailsPage.dart';
import 'EventManager.dart';

class AdminControllersPage extends StatefulWidget {
  const AdminControllersPage({super.key});

  @override
  _AdminControllersPageState createState() => _AdminControllersPageState();
}

class _AdminControllersPageState extends State<AdminControllersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EventManager _eventManager = EventManager();
  
  // State for users
  bool isLoadingUsers = true;
  String userSearchQuery = '';
  DateTime? userFilterDate;
  
  // State for turfs
  bool isLoadingTurfs = true;
  String turfSearchQuery = '';
  DateTime? turfFilterDate;
  bool turfFilterByName = true; // true = filter by name, false = filter by approval date
  
  // State for refund requests
  bool isLoadingRefunds = true;
  String refundSearchQuery = '';
  DateTime? refundFilterDate;
  
  // State for events
  bool isLoadingEvents = true;
  String eventSearchQuery = '';
  DateTime? eventFilterDate;
  
  // Current selected page
  String currentPage = 'pendingUsers';
  
  // Drawer items
    final List<Map<String, dynamic>> drawerItems = [
      {'id': 'pendingUsers', 'title': 'Pending Users', 'icon': Icons.person},
      {'id': 'verifiedUsers', 'title': 'Verified Users', 'icon': Icons.verified_user},
      {'id': 'pendingTurfs', 'title': 'Pending Turfs', 'icon': Icons.stadium},
      {'id': 'verifiedTurfs', 'title': 'Verified Turfs', 'icon': Icons.verified},
        {'id': 'pendingEvents', 'title': 'Pending Events', 'icon': Icons.event_outlined},
        {'id': 'approvedEvents', 'title': 'Approved Events', 'icon': Icons.event_available},
        {'id': 'eventAnalytics', 'title': 'Event Analytics', 'icon': Icons.analytics},
        {'id': 'refundRequests', 'title': 'Refund Requests', 'icon': Icons.replay},
        {'id': 'overdueClawbacks', 'title': 'Overdue Clawbacks', 'icon': Icons.money_off},
    ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
  }

  // Build user list with StreamBuilder for real-time updates
  Widget _buildUserList({required bool showPending}) {
    Query query = _firestore.collection('users');
    
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.teal),
                SizedBox(height: 20),
                Text(
                  'Loading Users...',
                  style: TextStyle(fontSize: 18, color: Colors.teal[700], fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red),
                SizedBox(height: 20),
                Text(
                  'Error loading users',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                SizedBox(height: 10),
                Text(
                  'Please try again later.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        List<Map<String, dynamic>> users = [];
        
        for (var userDoc in snapshot.data!.docs) {
          var userData = userDoc.data() as Map<String, dynamic>;
          String userId = userDoc.id;
          userData['userId'] = userId;
          
          // Filter based on status
          bool statusMatch = false;
          if (showPending && userData['status'] == 'Not Confirmed') {
            statusMatch = true;
          } else if (!showPending && userData['status'] == 'yes') {
            statusMatch = true;
          }
          
          // Filter based on search query
          bool searchMatch = userSearchQuery.isEmpty || 
            (userData['name']?.toString().toLowerCase().contains(userSearchQuery.toLowerCase()) ?? false) ||
            (userData['email']?.toString().toLowerCase().contains(userSearchQuery.toLowerCase()) ?? false);
          
          // Filter based on date if specified
          bool dateMatch = true;
          if (userFilterDate != null) {
            DateTime? verifiedDate;
            
            if (userData['verifiedby'] != null && userData['verifiedby']['timestamp'] != null) {
              verifiedDate = (userData['verifiedby']['timestamp'] as Timestamp).toDate();
            }
            
            if (verifiedDate != null) {
              dateMatch = verifiedDate.year == userFilterDate!.year && 
                         verifiedDate.month == userFilterDate!.month && 
                         verifiedDate.day == userFilterDate!.day;
            } else {
              dateMatch = false;
            }
          }
          
          if (statusMatch && searchMatch && dateMatch) {
            users.add(userData);
          }
        }

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(showPending ? Icons.person_off : Icons.verified_user, size: 80, color: Colors.blueAccent),
                SizedBox(height: 20),
                Text(
                  showPending ? 'No pending users found' : 'No verified users found',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                SizedBox(height: 10),
                Text(
                  (userSearchQuery.isNotEmpty || userFilterDate != null)
                    ? 'Try adjusting your search criteria.' 
                    : 'Please try again later or refresh.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            var userData = users[index];
            return _buildUserCard(userData);
          },
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> userData) {
    String name = userData['name'] ?? 'Unknown';
    String email = userData['email'] ?? 'Unknown';
    String mobile = userData['mobile'] ?? 'Unknown';
    bool isConfirmed = userData['status'] == 'yes';

    return GlassmorphismCard(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailsPage(userData: userData),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isConfirmed ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isConfirmed ? Icons.check_circle : Icons.pending,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 18, 
                              color: Colors.black87
                            ),
                          ),
                        ),
                        if (isConfirmed)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'VERIFIED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 2),
                    Text(
                      mobile,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build turf list with StreamBuilder for real-time updates
  Widget _buildTurfList({required bool showPending}) {
    Query query = _firestore.collection('turfs');
    
    if (showPending) {
      query = query.where('turf_status', isEqualTo: 'Not Verified');
    } else {
      query = query.where('turf_status', isEqualTo: 'Verified');
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.teal));
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red),
                SizedBox(height: 20),
                Text(
                  'Error loading turfs',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                SizedBox(height: 10),
                Text(
                  'Please try again later.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        List<Map<String, dynamic>> turfs = [];
        
        for (var turfDoc in snapshot.data!.docs) {
          var turfData = turfDoc.data() as Map<String, dynamic>;
          turfData['id'] = turfDoc.id;
          
          // Filter based on search query or date
          bool filterMatch = true;
          
          if (turfFilterByName) {
            // Filter by name
            filterMatch = turfSearchQuery.isEmpty || 
              (turfData['name']?.toString().toLowerCase().contains(turfSearchQuery.toLowerCase()) ?? false) ||
              (turfData['location']?.toString().toLowerCase().contains(turfSearchQuery.toLowerCase()) ?? false);
          } else {
            // Filter by approval date
            if (turfFilterDate != null) {
              DateTime? approvedDate;
              DateTime? rejectedDate;
              
              if (turfData['approvedAt'] != null) {
                approvedDate = (turfData['approvedAt'] as Timestamp).toDate();
              }
              
              if (turfData['rejectedAt'] != null) {
                rejectedDate = (turfData['rejectedAt'] as Timestamp).toDate();
              }
              
              if (approvedDate != null) {
                filterMatch = approvedDate.year == turfFilterDate!.year && 
                           approvedDate.month == turfFilterDate!.month && 
                           approvedDate.day == turfFilterDate!.day;
              } else if (rejectedDate != null) {
                filterMatch = rejectedDate.year == turfFilterDate!.year && 
                           rejectedDate.month == turfFilterDate!.month && 
                           rejectedDate.day == turfFilterDate!.day;
              } else {
                filterMatch = false;
              }
            }
          }
          
          if (filterMatch) {
            turfs.add(turfData);
          }
        }

        if (turfs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stadium, size: 80, color: Colors.blueAccent),
                SizedBox(height: 20),
                Text(
                  showPending ? 'No pending turfs found' : 'No verified turfs found',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                SizedBox(height: 10),
                Text(
                  (turfSearchQuery.isNotEmpty || turfFilterDate != null)
                    ? 'Try adjusting your search criteria.' 
                    : 'All turfs have been processed.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: turfs.length,
          itemBuilder: (context, idx) {
            final turf = turfs[idx];
            return _buildTurfCard(turf, isPending: showPending);
          },
        );
      },
    );
  }

  Widget _buildTurfCard(Map<String, dynamic> turf, {required bool isPending}) {
    return GlassmorphismCard(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: turf['imageUrl'] != null && turf['imageUrl'].toString().isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(turf['imageUrl'], width: 60, height: 60, fit: BoxFit.cover),
              )
            : Container(width: 60, height: 60, color: Colors.teal.shade50, child: Icon(Icons.sports_soccer, color: Colors.teal)),
        title: Text(turf['name'] ?? 'Unknown Turf', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(turf['ownerId']).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text('Loading owner info...', style: TextStyle(fontSize: 12, color: Colors.grey[600]));
            }
            if (snapshot.hasData && snapshot.data!.exists) {
              final ownerData = snapshot.data!.data() as Map<String, dynamic>;
              final ownerName = ownerData['name'] ?? 'Unknown Owner';
              final ownerEmail = ownerData['email'] ?? 'No email';
              return FutureBuilder<String>(
                future: _getLocationName(turf['location'] ?? 'Unknown'),
                builder: (context, locationSnapshot) {
                  String location = locationSnapshot.data ?? turf['location'] ?? 'N/A';
                  return Text(
                    'Owner: $ownerName\nEmail: $ownerEmail\nLocation: $location',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  );
                },
              );
            } else {
              return FutureBuilder<String>(
                future: _getLocationName(turf['location'] ?? 'Unknown'),
                builder: (context, locationSnapshot) {
                  String location = locationSnapshot.data ?? turf['location'] ?? 'N/A';
                  return Text(
                    'Owner: Unknown\nLocation: $location',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  );
                },
              );
            }
          },
        ),
        trailing: isPending
            ? ElevatedButton(
                onPressed: () => _showTurfDetailsDialog(turf, isPending: true),
                child: Text('Review',style: TextStyle(color: Colors.white),),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              )
            : IconButton(
                onPressed: () => _showTurfDetailsDialog(turf, isPending: false),
                icon: Icon(Icons.visibility, color: Colors.teal),
                tooltip: 'View Details',
              ),
      ),
    );
  }

  // Get location name from coordinates using geocoding
  Future<String> _getLocationName(dynamic locationData) async {
    try {
      String locationString;
      
      if (locationData is Map) {
        // If it's a map with latitude and longitude
        double latitude = locationData['latitude']?.toDouble() ?? 0.0;
        double longitude = locationData['longitude']?.toDouble() ?? 0.0;
        
        if (latitude != 0.0 && longitude != 0.0) {
          List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
          if (placemarks.isNotEmpty) {
            Placemark placemark = placemarks.first;
            locationString = "${placemark.name ?? ''}, ${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}";
            return locationString.isNotEmpty ? locationString : "Lat: $latitude, Lng: $longitude";
          }
        }
        return "Lat: $latitude, Lng: $longitude";
      } else if (locationData is String) {
        // If it's already a string
        return locationData;
      } else {
        // Default case
        return 'Unknown Location';
      }
    } catch (e) {
      print('Error getting location name: $e');
      return locationData?.toString() ?? 'Unknown Location';
    }
  }

  // Build refund requests list with StreamBuilder for real-time updates
  Widget _buildRefundRequestsList() {
    Query query = _firestore.collection('refund_requests').orderBy('requestedAt', descending: true);
    
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.teal),
                SizedBox(height: 20),
                Text(
                  'Loading Refund Requests...',
                  style: TextStyle(fontSize: 18, color: Colors.teal[700], fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red),
                SizedBox(height: 20),
                Text(
                  'Error loading refund requests',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                SizedBox(height: 10),
                Text(
                  'Please try again later.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        List<Map<String, dynamic>> refundRequests = [];
        
        for (var refundDoc in snapshot.data!.docs) {
          var refundData = refundDoc.data() as Map<String, dynamic>;
          refundData['id'] = refundDoc.id;
          
          // Filter based on search query
          bool searchMatch = refundSearchQuery.isEmpty || 
            (refundData['turfName']?.toString().toLowerCase().contains(refundSearchQuery.toLowerCase()) ?? false);
          
          // Filter based on date if specified
          bool dateMatch = true;
          if (refundFilterDate != null) {
            DateTime? requestedDate;
            
            if (refundData['requestedAt'] != null) {
              requestedDate = (refundData['requestedAt'] as Timestamp).toDate();
            }
            
            if (requestedDate != null) {
              dateMatch = requestedDate.year == refundFilterDate!.year && 
                         requestedDate.month == refundFilterDate!.month && 
                         requestedDate.day == refundFilterDate!.day;
            } else {
              dateMatch = false;
            }
          }
          
          if (searchMatch && dateMatch) {
            refundRequests.add(refundData);
          }
        }

        if (refundRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.money_off, size: 80, color: Colors.blueAccent),
                SizedBox(height: 20),
                Text(
                  'No refund requests found',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                SizedBox(height: 10),
                Text(
                  (refundSearchQuery.isNotEmpty || refundFilterDate != null)
                    ? 'Try adjusting your search criteria.' 
                    : 'All refund requests have been processed.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: refundRequests.length,
          itemBuilder: (context, index) {
            final refund = refundRequests[index];
            return _buildRefundRequestCard(refund);
          },
        );
      },
    );
  }

  Widget _buildRefundRequestCard(Map<String, dynamic> refund) {
    String status = refund['status'] ?? 'pending';
    Color statusColor = _getRefundStatusColor(status);
    IconData statusIcon = _getRefundStatusIcon(status);

    return GlassmorphismCard(
      margin: EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () => _showRefundDetailsDialog(refund),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Refund Request #${refund['id'].substring(0, 8)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        SizedBox(width: 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(refund['userId']).get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text('Loading user info...'),
                      ],
                    );
                  }
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                    final userName = userData['name'] ?? 'Unknown User';
                    return Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Expanded(child: Text('User: $userName')),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text('User: Unknown'),
                      ],
                    );
                  }
                },
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(child: Text('Turf: ${refund['turfName'] ?? 'Unknown'}')),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text('Date: ${refund['bookingDate'] ?? 'Unknown'}'),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16, color: Colors.green[600]),
                  SizedBox(width: 8),
                  Text(
                    'Amount: ₹${refund['amount']?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                  ),
                ],
              ),
              if (status == 'pending') ...[
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _processRefund(refund['id'], 'approve'),
                        icon: Icon(Icons.check, color: Colors.white),
                        label: Text('Approve', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showRejectDialog(refund['id']),
                        icon: Icon(Icons.close, color: Colors.white),
                        label: Text('Reject', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // Show detailed refund information dialog
  void _showRefundDetailsDialog(Map<String, dynamic> refund) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with refund ID and status
                  Row(
                    children: [
                      Icon(Icons.replay, color: Colors.teal, size: 28),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Refund Request #${refund['id']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 22, 
                            color: Colors.teal.shade900
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getRefundStatusColor(refund['status'] ?? 'pending').withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getRefundStatusColor(refund['status'] ?? 'pending')),
                        ),
                        child: Text(
                          (refund['status'] ?? 'pending').toUpperCase(),
                          style: TextStyle(
                            color: _getRefundStatusColor(refund['status'] ?? 'pending'),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 20, color: Colors.grey.shade300),
                  
                  // User Information Section
                  GlassmorphismCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, color: Colors.blue.shade700),
                              SizedBox(width: 8),
                              Text('User Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade800)),
                            ],
                          ),
                          SizedBox(height: 12),
                          FutureBuilder<DocumentSnapshot>(
                            future: _firestore.collection('users').doc(refund['userId']).get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Text('Loading user info...', style: TextStyle(color: Colors.grey.shade600));
                              }
                              if (snapshot.hasData && snapshot.data!.exists) {
                                final userData = snapshot.data!.data() as Map<String, dynamic>;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow('User ID', refund['userId'] ?? 'Unknown'),
                                    _buildInfoRow('Name', userData['name'] ?? 'Unknown'),
                                    _buildInfoRow('Email', userData['email'] ?? 'Unknown'),
                                    _buildInfoRow('Phone', userData['mobile'] ?? 'Unknown'),
                                  ],
                                );
                              } else {
                                return Text('User information not available', style: TextStyle(color: Colors.grey.shade600));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Booking Information Section
                  GlassmorphismCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event, color: Colors.green.shade700),
                              SizedBox(width: 8),
                              Text('Booking Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade800)),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildInfoRow('Booking ID', refund['bookingId'] ?? 'Unknown'),
                          _buildInfoRow('Turf Name', refund['turfName'] ?? 'Unknown'),
                          _buildInfoRow('Ground', refund['ground'] ?? 'Unknown'),
                          _buildInfoRow('Booking Date', refund['bookingDate'] ?? 'Unknown'),
                          _buildInfoRow('Time Slots', (refund['slots'] as List?)?.join(', ') ?? 'Unknown'),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Payment Information Section
                  GlassmorphismCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.payment, color: Colors.purple.shade700),
                              SizedBox(width: 8),
                              Text('Payment Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple.shade800)),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildInfoRow('Payment ID', refund['paymentId'] ?? 'Unknown'),
                          _buildInfoRow('Total Amount', '₹${refund['amount']?.toStringAsFixed(2) ?? '0.00'}'),
                          _buildInfoRow('Base Amount', '₹${refund['baseAmount']?.toStringAsFixed(2) ?? '0.00'}'),
                          if (refund['refundBreakdown'] != null) ...[
                            _buildInfoRow('Platform Fees', '₹${refund['refundBreakdown']['platformAmount']?.toStringAsFixed(2) ?? '0.00'}'),
                            _buildInfoRow('Turf Owner Recovered', '${refund['refundBreakdown']['turfOwnerRecovered'] == true ? 'Yes' : 'No'}'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Timeline Section
                  GlassmorphismCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.timeline, color: Colors.indigo.shade700),
                              SizedBox(width: 8),
                              Text('Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo.shade800)),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildInfoRow('Requested At', _formatTimestamp(refund['requestedAt'])),
                          if (refund['processedAt'] != null)
                            _buildInfoRow('Processed At', _formatTimestamp(refund['processedAt'])),
                          if (refund['refundId'] != null)
                            _buildInfoRow('Refund ID', refund['refundId']),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Reason and Notes Section
                  GlassmorphismCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notes, color: Colors.orange.shade700),
                              SizedBox(width: 8),
                              Text('Reason and Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange.shade800)),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildInfoRow('Reason', refund['reason'] ?? 'No reason provided', maxLines: 3),
                          if (refund['adminNotes'] != null && refund['adminNotes'].isNotEmpty)
                            _buildInfoRow('Admin Notes', refund['adminNotes'], maxLines: 3),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Action buttons
                  if (refund['status'] == 'pending')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _processRefund(refund['id'], 'approve');
                            },
                            icon: Icon(Icons.check, color: Colors.white),
                            label: Text('Approve',style: TextStyle(color: Colors.white),),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showRejectDialog(refund['id']);
                            },
                            icon: Icon(Icons.cancel, color: Colors.white),
                            label: Text('Reject',style: TextStyle(color: Colors.white),),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close),
                        label: Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'N/A';
    }
    
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }
  
  Widget _buildInfoRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade800),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRefundStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'processed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'failed':
        return Colors.red[800]!;
      default:
        return Colors.grey;
    }
  }

  IconData _getRefundStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.check_circle;
      case 'processed':
        return Icons.done_all;
      case 'rejected':
        return Icons.cancel;
      case 'failed':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Future<void> _processRefund(String refundRequestId, String action) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Processing refund...'),
              ],
            ),
          );
        },
      );

      // Call Cloud Function to process refund
      final HttpsCallable processRefund = FirebaseFunctions.instance.httpsCallable('processRefund');
      
      final result = await processRefund({
        'refundRequestId': refundRequestId,
        'action': action,
        'adminNotes': action == 'approve' ? 'Refund approved by admin' : 'Refund rejected by admin'
      });

      // Close loading dialog
      Navigator.of(context).pop();

      if (result.data['success'] == true) {
        Fluttertoast.showToast(
          msg: action == 'approve' ? 'Refund approved successfully!' : 'Refund rejected successfully!',
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: action == 'approve' ? Colors.green : Colors.red,
          textColor: Colors.white,
        );
      } else {
        throw Exception('Failed to process refund: ${result.data['message'] ?? 'Unknown error'}');
      }

    } on FirebaseFunctionsException catch (e) {
      Navigator.of(context).pop();
      final code = e.code;
      final message = e.message ?? 'Unknown error';
      print('Refund failed: $code - $message');
      Fluttertoast.showToast(
        msg: '$code: $message',
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      Navigator.of(context).pop();
      print('Error processing refund: $e');
      Fluttertoast.showToast(
        msg: e.toString(),
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _showRejectDialog(String refundRequestId) {
    final TextEditingController notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reject Refund Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please provide a reason for rejecting this refund request:'),
              SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _processRefund(refundRequestId, 'reject');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Show turf details dialog
  void _showTurfDetailsDialog(Map<String, dynamic> turf, {required bool isPending}) async {
    // Fetch owner details
    Map<String, dynamic>? ownerData;
    if (turf['ownerId'] != null) {
      final ownerDoc = await _firestore.collection('users').doc(turf['ownerId']).get();
      if (ownerDoc.exists) ownerData = ownerDoc.data() as Map<String, dynamic>?;
    }
    
    // Fetch booking statistics for verified turfs
    Map<String, dynamic>? bookingStats;
    if (!isPending) {
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('turfId', isEqualTo: turf['id'])
          .get();
      
      int totalBookings = bookingsSnapshot.docs.length;
      double totalRevenue = 0;
      int confirmedBookings = 0;
      
      for (var doc in bookingsSnapshot.docs) {
        final booking = doc.data() as Map<String, dynamic>;
        if (booking['status'] == 'confirmed') {
          confirmedBookings++;
          totalRevenue += (booking['amount'] ?? 0).toDouble();
        }
      }
      
      bookingStats = {
        'totalBookings': totalBookings,
        'confirmedBookings': confirmedBookings,
        'totalRevenue': totalRevenue,
      };
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with turf name and status
                  Row(
                    children: [
                      Icon(Icons.sports_soccer, color: Colors.teal, size: 28),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(turf['name'] ?? 'Unknown Turf', 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.teal.shade900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPending ? Colors.orange : Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isPending ? 'PENDING' : 'VERIFIED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 20, color: Colors.grey.shade300),
                  
                  // Main image
                  if (turf['imageUrl'] != null && turf['imageUrl'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(turf['imageUrl'], height: 180, width: double.infinity, fit: BoxFit.cover),
                    ),
                  
                  SizedBox(height: 16),
                  
                  // Owner Information Section
                  GlassmorphismCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, color: Colors.blue.shade700),
                              SizedBox(width: 8),
                              Text('Owner Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade800)),
                            ],
                          ),
                          SizedBox(height: 12),
                          if (ownerData != null) ...[
                            _buildInfoRow('Name', ownerData['name'] ?? ''),
                            _buildInfoRow('Email', ownerData['email'] ?? ''),
                            _buildInfoRow('Phone', ownerData['mobile'] ?? ''),
                            _buildInfoRow('GST', ownerData['gst'] ?? 'N/A'),
                            _buildInfoRow('Razorpay ID', ownerData['razorpayAccountId'] ?? 'N/A'),
                          ] else
                            Text('Owner information not available', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Turf Details Section
                  GlassmorphismCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.green.shade700),
                              SizedBox(width: 8),
                              Text('Turf Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade800)),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildInfoRow('Turf ID', turf['turfId'] ?? 'N/A'),
                          FutureBuilder<String>(
                            future: _getLocationName(turf['location']),
                            builder: (context, snapshot) {
                              String location = snapshot.data ?? turf['location']?.toString() ?? 'N/A';
                              return _buildInfoRow('Location', location);
                            },
                          ),
                          _buildInfoRow('Status', turf['turf_status'] ?? 'N/A'),
                          _buildInfoRow('Description', turf['description'] ?? 'N/A', maxLines: 3),
                          _buildInfoRow('On-Spot Payment', turf['isosp'] == true ? 'Enabled' : 'Disabled'),
                          _buildInfoRow('Has Location', turf['hasLocation'] == true ? 'Yes' : 'No'),
                        ],
                      ),
                    ),
                  ),
                  
                  // Available Grounds Section
                  if (turf['availableGrounds'] != null && (turf['availableGrounds'] as List).isNotEmpty) ...[
                    SizedBox(height: 16),
                    GlassmorphismCard(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.grass, color: Colors.brown.shade700),
                                SizedBox(width: 8),
                                Text('Available Grounds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown.shade800)),
                              ],
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (turf['availableGrounds'] as List).map<Widget>((ground) => 
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.brown.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.brown.shade300),
                                  ),
                                  child: Text(
                                    ground.toString(),
                                    style: TextStyle(color: Colors.brown.shade800),
                                  ),
                                )
                              ).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  // Pricing Information Section
                  if (turf['price'] != null) ...[
                    SizedBox(height: 16),
                    GlassmorphismCard(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.currency_rupee, color: Colors.purple.shade700),
                                SizedBox(width: 8),
                                Text('Pricing Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple.shade800)),
                              ],
                            ),
                            SizedBox(height: 12),
                            if (turf['price'] is Map) ...[
                              ...((turf['price'] as Map).entries.map((entry) => 
                                _buildInfoRow(entry.key, '₹${entry.value.toString()}')
                              ).toList()),
                            ] else ...[
                              _buildInfoRow('Price', '₹${turf['price'].toString()}'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  // Available Time Slots Section
                  if (turf['selectedSlots'] != null && (turf['selectedSlots'] as List).isNotEmpty) ...[
                    SizedBox(height: 16),
                    GlassmorphismCard(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time, color: Colors.indigo.shade700),
                                SizedBox(width: 8),
                                Text('Available Time Slots', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo.shade800)),
                              ],
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (turf['selectedSlots'] as List).map<Widget>((slot) => 
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.indigo.shade300),
                                  ),
                                  child: Text(
                                    slot.toString(),
                                    style: TextStyle(color: Colors.indigo.shade800),
                                  ),
                                )
                              ).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  // Facilities Section
                  if (turf['facilities'] != null && (turf['facilities'] as List).isNotEmpty) ...[
                    SizedBox(height: 16),
                    GlassmorphismCard(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber.shade700),
                                SizedBox(width: 8),
                                Text('Facilities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber.shade800)),
                              ],
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (turf['facilities'] as List).map<Widget>((facility) => 
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.amber.shade300),
                                  ),
                                  child: Text(
                                    facility.toString(),
                                    style: TextStyle(color: Colors.amber.shade800),
                                  ),
                                )
                              ).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  // Location Coordinates Section
                  if (turf['latitude'] != null && turf['longitude'] != null) ...[
                    SizedBox(height: 16),
                    GlassmorphismCard(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.red.shade700),
                                SizedBox(width: 8),
                                Text('Location Coordinates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade800)),
                              ],
                            ),
                            SizedBox(height: 12),
                            _buildInfoRow('Latitude', turf['latitude'].toString()),
                            _buildInfoRow('Longitude', turf['longitude'].toString()),
                            FutureBuilder<String>(
                              future: _getLocationName({
                                'latitude': turf['latitude'],
                                'longitude': turf['longitude']
                              }),
                              builder: (context, snapshot) {
                                String location = snapshot.data ?? 'Unknown';
                                return _buildInfoRow('Address', location, maxLines: 2);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  // Booking Statistics for Verified Turfs
                  if (!isPending && bookingStats != null) ...[
                    SizedBox(height: 16),
                    GlassmorphismCard(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.bar_chart, color: Colors.purple.shade700),
                                SizedBox(width: 8),
                                Text('Booking Statistics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple.shade800)),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatCard('Total Bookings', bookingStats['totalBookings'].toString(), Icons.book_online),
                                _buildStatCard('Confirmed', bookingStats['confirmedBookings'].toString(), Icons.check_circle),
                                _buildStatCard('Revenue', '₹${bookingStats['totalRevenue'].toStringAsFixed(0)}', Icons.currency_rupee),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  // Image Gallery
                  if (turf['turfimages'] != null && (turf['turfimages'] as List).isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text('Gallery:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: (turf['turfimages'] as List).map<Widget>((img) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(img, width: 120, height: 120, fit: BoxFit.cover),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                  
                  // Approval/Rejection Information
                  if (turf['approvedAt'] != null || turf['rejectedAt'] != null) ...[
                    SizedBox(height: 16),
                    GlassmorphismCard(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.history, color: Colors.teal.shade700),
                                SizedBox(width: 8),
                                Text('Approval History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade800)),
                              ],
                            ),
                            SizedBox(height: 12),
                            if (turf['approvedAt'] != null) ...[
                              _buildInfoRow('Approved At', _formatTimestamp(turf['approvedAt'])),
                              _buildInfoRow('Approved By', 'Punchbiz Team'),
                            ],
                            if (turf['rejectedAt'] != null) ...[
                              _buildInfoRow('Rejected At', _formatTimestamp(turf['rejectedAt'])),
                              _buildInfoRow('Rejected By', turf['rejectedBy'] ?? 'Admin'),
                              _buildInfoRow('Rejection Reason', turf['rejectionReason'] ?? 'N/A', maxLines: 3),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 24),
                  
                  // Action buttons
                  if (isPending)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveTurf(turf['id']),
                            icon: Icon(Icons.check, color: Colors.white),
                            label: Text('Approve',style: TextStyle(color: Colors.white),),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showTurfRejectionDialog(turf['id']),
                            icon: Icon(Icons.cancel, color: Colors.white),
                            label: Text('Disapprove',style: TextStyle(color: Colors.white),),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close),
                        label: Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.purple.shade600, size: 24),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // Approve turf
  Future<void> _approveTurf(String turfId) async {
    try {
      await _firestore.collection('turfs').doc(turfId).update({
        'turf_status': 'Verified',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUser?.uid ?? 'admin',
      });
      
      Fluttertoast.showToast(
        msg: 'Turf approved successfully! Now visible to users.',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error approving turf: ${e.toString()}',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // Disapprove turf with professional dialog
  void _showTurfRejectionDialog(String turfId) {
    final TextEditingController reasonController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [Colors.red.shade50, Colors.orange.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cancel_outlined,
                      color: Colors.red.shade700,
                      size: 32,
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Title
                  Text(
                    'Turf Rejection',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  // Subtitle
                  Text(
                    'Please provide a detailed reason for rejection',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  
                  // Reason input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: reasonController,
                      maxLines: 5,
                      style: TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Enter detailed reason for rejection...\n\nExample:\n• Image quality issues\n• Missing required information\n• Location details unclear\n• Pricing information incomplete',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                        ),
                        contentPadding: EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please provide a reason for rejection';
                        }
                        if (value.trim().length < 20) {
                          return 'Please provide a more detailed reason (at least 20 characters)';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              try {
                                await _firestore.collection('turfs').doc(turfId).update({
                                  'turf_status': 'Disapproved',
                                  'rejectionReason': reasonController.text.trim(),
                                  'rejectedAt': FieldValue.serverTimestamp(),
                                  'rejectedBy': _auth.currentUser?.uid ?? 'admin',
                                });
                                
                                Fluttertoast.showToast(
                                  msg: 'Turf rejected. Owner will be notified with the reason.',
                                  backgroundColor: Colors.orange,
                                  textColor: Colors.white,
                                );
                                Navigator.pop(ctx);
                                Navigator.pop(context);
                              } catch (e) {
                                Fluttertoast.showToast(
                                  msg: 'Error rejecting turf: ${e.toString()}',
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            'Reject Turf',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
        );
      },
    );
  }

  void _showUserDetails(Map<String, dynamic> userData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserDetailsPage(userData: userData),
      ),
    );
  }

  // Show sign out confirmation dialog
  Future<bool> _showSignOutConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [Colors.red.shade50, Colors.orange.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout,
                    color: Colors.red.shade700,
                    size: 32,
                  ),
                ),
                SizedBox(height: 20),
                
                // Title
                Text(
                  'Sign Out?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
                SizedBox(height: 8),
                
                // Subtitle
                Text(
                  'Are you sure you want to sign out of your admin account?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
    ) ?? false;
  }

  Future<void> _handleLogout(BuildContext context) async {
    bool confirmed = await _showSignOutConfirmationDialog();
    if (confirmed) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginApp()));
    }
  }

  // Get the current page content based on selection
  Widget _getCurrentPageContent() {
    switch (currentPage) {
      case 'pendingUsers':
        return _buildUserList(showPending: true);
      case 'verifiedUsers':
        return _buildUserList(showPending: false);
      case 'pendingTurfs':
        return _buildTurfList(showPending: true);
      case 'verifiedTurfs':
        return _buildTurfList(showPending: false);
        case 'pendingEvents':
          return _eventManager.buildEventList(showPending: true, eventSearchQuery: eventSearchQuery, eventFilterDate: eventFilterDate, context: context);
        case 'approvedEvents':
          return _eventManager.buildEventList(showPending: false, eventSearchQuery: eventSearchQuery, eventFilterDate: eventFilterDate, context: context);
        case 'eventAnalytics':
          return _eventManager.buildEventAnalytics();
      case 'refundRequests':
        return _buildRefundRequestsList();
      default:
        return _buildUserList(showPending: true);
    }
  }

  // Build search bar for users
  Widget _buildUserSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search field
          TextField(
            onChanged: (value) {
              setState(() {
                userSearchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: Icon(Icons.search, color: Colors.teal),
              suffixIcon: userSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          userSearchQuery = '';
                          userFilterDate = null;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
          ),
          SizedBox(height: 12),
          // Date picker
          Row(
            children: [
              Expanded(
                child: _buildDatePickerButton(
                  selectedDate: userFilterDate,
                  onDateSelected: (date) {
                    setState(() {
                      userFilterDate = date;
                    });
                  },
                  label: 'Filter by verification date',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build search bar for turfs
  Widget _buildTurfSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Toggle between name and date filter
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      turfFilterByName = true;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: turfFilterByName ? Colors.teal.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: turfFilterByName ? Colors.teal : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          color: turfFilterByName ? Colors.teal : Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Filter by Name',
                          style: TextStyle(
                            color: turfFilterByName ? Colors.teal : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      turfFilterByName = false;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !turfFilterByName ? Colors.teal.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !turfFilterByName ? Colors.teal : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: !turfFilterByName ? Colors.teal : Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Filter by Date',
                          style: TextStyle(
                            color: !turfFilterByName ? Colors.teal : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Search field or date picker based on selection
          if (turfFilterByName)
            TextField(
              onChanged: (value) {
                setState(() {
                  turfSearchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by turf name or location...',
                prefixIcon: Icon(Icons.search, color: Colors.teal),
                suffixIcon: turfSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            turfSearchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            )
          else
            _buildDatePickerButton(
              selectedDate: turfFilterDate,
              onDateSelected: (date) {
                setState(() {
                  turfFilterDate = date;
                });
              },
              label: 'Filter by approval date',
            ),
        ],
      ),
    );
  }

  // Build search bar for refund requests
  Widget _buildRefundSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search field
          TextField(
            onChanged: (value) {
              setState(() {
                refundSearchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by turf name...',
              prefixIcon: Icon(Icons.search, color: Colors.teal),
              suffixIcon: refundSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          refundSearchQuery = '';
                          refundFilterDate = null;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
          ),
          SizedBox(height: 12),
          // Date picker
          Row(
            children: [
              Expanded(
                child: _buildDatePickerButton(
                  selectedDate: refundFilterDate,
                  onDateSelected: (date) {
                    setState(() {
                      refundFilterDate = date;
                    });
                  },
                  label: 'Filter by request date',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build date picker button
  Widget _buildDatePickerButton({required DateTime? selectedDate, required Function(DateTime?) onDateSelected, String? label}) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.teal, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  Text(
                    selectedDate != null
                        ? DateFormat('dd/MM/yyyy').format(selectedDate)
                        : 'Select Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (selectedDate != null)
              InkWell(
                onTap: () => onDateSelected(null),
                child: Icon(Icons.clear, color: Colors.grey, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // Build drawer widget
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.teal[50],
        child: Column(
          children: [
            // Drawer Header with improved visibility
            Container(
              padding: EdgeInsets.fromLTRB(16, 40, 16, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal[600]!, Colors.teal[800]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.dashboard, color: Colors.white, size: 32),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Panel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'BookTheBiz Management',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Drawer Menu Items
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(top: 16),
                itemCount: drawerItems.length,
                itemBuilder: (context, index) {
                  final item = drawerItems[index];
                  final isSelected = currentPage == item['id'];
                  
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: GlassmorphismCard(
                      child: ListTile(
                        selected: isSelected,
                        selectedTileColor: Colors.teal.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.teal.withOpacity(0.2) : Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item['icon'],
                            color: isSelected ? Colors.teal[800] : Colors.teal[600],
                            size: 24,
                          ),
                        ),
                        title: Text(
                          item['title'],
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.teal[800] : Colors.teal[600],
                            fontSize: 16,
                          ),
                        ),
                        onTap: () async {
                          setState(() {
                            currentPage = item['id'];
                            // Reset filters when changing tabs
                            userSearchQuery = '';
                            userFilterDate = null;
                            turfSearchQuery = '';
                            turfFilterDate = null;
                            turfFilterByName = true;
                            refundSearchQuery = '';
                            refundFilterDate = null;
                          });
                          Navigator.pop(context); // Close the drawer

                          // ADD THIS: Navigate to separate page for overdue clawbacks
                          if (item['id'] == 'overdueClawbacks') {
                            await Future.delayed(Duration(milliseconds: 230)); // Wait for drawer close animation
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => OverdueClawbacksPage()),
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Drawer Footer
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Divider(color: Colors.teal[200]),
                  SizedBox(height: 8),
                  Text(
                    'BookTheBiz Admin v1.0',
                    style: TextStyle(
                      color: Colors.teal[400],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '© 2023 Punchbiz',
                    style: TextStyle(
                      color: Colors.teal[300],
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.teal[600],
        title: Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.support_agent, color: Colors.amberAccent, size: 28),
            tooltip: 'Support Tickets',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminSupportTicketsPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.red),
            tooltip: 'Logout',
            onPressed: () {
              _handleLogout(context);
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Search and filter section
            Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: _buildSearchAndFilterForCurrentPage(),
            ),
            // Content section
            Expanded(
              child: _getCurrentPageContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterForCurrentPage() {
    switch (currentPage) {
      case 'pendingUsers':
      case 'verifiedUsers':
        return _buildUserSearchBar();
        
      case 'pendingTurfs':
      case 'verifiedTurfs':
        return _buildTurfSearchBar();
        
        case 'pendingEvents':
        case 'approvedEvents':
          return _eventManager.buildEventSearchBar(
            onSearchChanged: (value) {
              setState(() {
                eventSearchQuery = value.toLowerCase();
              });
            },
            onDateChanged: (date) {
              setState(() {
                eventFilterDate = date;
              });
            },
            eventSearchQuery: eventSearchQuery,
            eventFilterDate: eventFilterDate,
            context: context,
          );
        case 'eventAnalytics':
          return Container(); // No search bar for analytics
        
      case 'refundRequests':
        return _buildRefundSearchBar();
        
      default:
        return Container();
    }
  }





}

// Glassmorphism Card Widget
class GlassmorphismCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? color;

  const GlassmorphismCard({
    Key? key,
    required this.child,
    this.margin,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.6),
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}