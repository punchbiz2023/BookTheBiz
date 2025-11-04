import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';

class EventBookingsPage extends StatefulWidget {
  final User? user;
  EventBookingsPage({super.key, this.user});

  @override
  _EventBookingsPageState createState() => _EventBookingsPageState();
}

class _EventBookingsPageState extends State<EventBookingsPage> 
    with TickerProviderStateMixin {
  String searchQuery = '';
  List<Map<String, dynamic>> ownerEvents = [];
  Map<String, dynamic>? currentUserData;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _slideController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    
    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..repeat();
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.elasticOut,
      ),
    );
    
    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeInOut,
      ),
    );
    
    _fadeController.forward();
    _slideController.forward();
    
    _loadOwnerEvents();
    _loadCurrentUserData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadOwnerEvents() async {
    try {
      final eventsQuery = await FirebaseFirestore.instance
          .collection('spot_events')
          .where('ownerId', isEqualTo: widget.user?.uid)
          .get();

      setState(() {
        ownerEvents = eventsQuery.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      print('Error loading owner events: $e');
    }
  }

  Future<void> _loadCurrentUserData() async {
    try {
      if (widget.user?.uid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user?.uid)
            .get();
        
        if (userDoc.exists) {
          setState(() {
            currentUserData = userDoc.data();
          });
        }
      }
    } catch (e) {
      print('Error loading current user data: $e');
    }
  }

  Future<int> _getBookingCount(String eventId) async {
    try {
      final bookingsQuery = await FirebaseFirestore.instance
          .collection('event_registrations')
          .where('eventId', isEqualTo: eventId)
          .get();
      
      return bookingsQuery.docs.length;
    } catch (e) {
      print('Error getting booking count: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'My Events',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            fontSize: 21,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.teal.shade900.withOpacity(0.8),
                Colors.teal.shade700.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.cyan.shade50,
              Colors.teal.shade50,
              Colors.grey.shade100,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                SizedBox(height: 20),
                // Search Bar with enhanced glass effect
                AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  margin: EdgeInsets.only(top: 90, left: 16, right: 16, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 25,
                        offset: Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.7),
                                Colors.cyan.shade50.withOpacity(0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.grey.shade200.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyan.withOpacity(0.1),
                                blurRadius: 15,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value.toLowerCase();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search events by name...',
                              prefixIcon: Icon(Icons.search, color: Colors.teal.shade700),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Events List
                Expanded(
                  child: ownerEvents.isEmpty
                      ? Center(
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 500),
                            padding: EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 25,
                                  offset: Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event_busy,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No events created yet',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Create events to start managing bookings',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: ownerEvents.length,
                          itemBuilder: (context, index) {
                            final event = ownerEvents[index];
                            
                            // Apply search filter
                            if (searchQuery.isNotEmpty && 
                                !(event['name']?.toLowerCase().contains(searchQuery) ?? false)) {
                              return SizedBox.shrink();
                            }
                            
                            return FutureBuilder<int>(
                              future: _getBookingCount(event['id']),
                              builder: (context, snapshot) {
                                final bookingCount = snapshot.data ?? 0;
                                
                                return AnimatedContainer(
                                  duration: Duration(milliseconds: 500),
                                  curve: Curves.elasticOut,
                                  margin: EdgeInsets.only(bottom: 20),
                                  child: FadeTransition(
                                    opacity: AlwaysStoppedAnimation(1.0),
                                    child: _buildEventCard(event, bookingCount),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> eventData, int bookingCount) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Column(
            children: [
              // Event Image with shimmer effect
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16/9,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.cyan.shade300,
                              Colors.teal.shade400,
                            ],
                          ),
                        ),
                        child: eventData['imageUrl'] != null
                            ? Image.network(
                                eventData['imageUrl'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.cyan.shade300,
                                          Colors.teal.shade400,
                                        ],
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.event,
                                      color: Colors.white,
                                      size: 60,
                                    ),
                                  );
                                },
                              )
                            : Icon(
                                Icons.event,
                                color: Colors.white,
                                size: 60,
                              ),
                      ),
                    ),
                  ),
                  // Shimmer effect
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      child: AnimatedBuilder(
                        animation: _shimmerAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: 0.3,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-1.0 + _shimmerAnimation.value * 2, 0.0),
                                  end: Alignment(0.0 + _shimmerAnimation.value * 2, 0.0),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Event type badge
                  Positioned(
                    top: 16,
                    right: 16,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.8),
                            Colors.cyan.shade50.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.6),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        eventData['eventType'] ?? 'General',
                        style: TextStyle(
                          color: Colors.teal.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Event details
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eventData['name'] ?? 'Unnamed Event',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: Colors.teal.shade600,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    _formatEventDate(eventData['eventDate']),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Icon(
                                    Icons.access_time,
                                    color: Colors.teal.shade600,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    eventData['eventTime'] != null 
                                        ? _formatEventTime(eventData['eventTime'])
                                        : 'N/A',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.teal.shade100.withOpacity(0.8),
                                Colors.cyan.shade100.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.teal.shade300.withOpacity(0.4),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withOpacity(0.2),
                                blurRadius: 12,
                                spreadRadius: 0,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people,
                                color: Colors.teal.shade700,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '$bookingCount',
                                style: TextStyle(
                                  color: Colors.teal.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.teal.shade600,
                                  Colors.cyan.shade500,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.withOpacity(0.4),
                                  blurRadius: 15,
                                  spreadRadius: 0,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _viewEventBookings(eventData),
                              icon: Icon(Icons.visibility, size: 18),
                              label: Text('View Bookings'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewEventBookings(Map<String, dynamic> eventData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventBookingsDetailPage(
          user: widget.user,
          eventData: eventData,
        ),
      ),
    );
  }

  String _formatEventDate(dynamic date) {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return date.toString();
  }

  String _formatEventTime(String? time) {
    if (time == null) return 'N/A';
    
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      
      return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return time;
    }
  }
}

class EventBookingsDetailPage extends StatefulWidget {
  final User? user;
  final Map<String, dynamic> eventData;
  
  EventBookingsDetailPage({
    super.key,
    required this.user,
    required this.eventData,
  });

  @override
  _EventBookingsDetailPageState createState() => _EventBookingsDetailPageState();
}

class _EventBookingsDetailPageState extends State<EventBookingsDetailPage> 
    with TickerProviderStateMixin {
  String searchQuery = '';
  String sortBy = 'name'; // Default sorting by name
  bool sortAscending = true;
  Map<String, dynamic> usersData = {};
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _slideController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    
    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..repeat();
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.elasticOut,
      ),
    );
    
    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeInOut,
      ),
    );
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    if (usersData.containsKey(userId)) {
      return usersData[userId];
    }
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        setState(() {
          usersData[userId] = userData;
        });
        return userData;
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
    
    return null;
  }

  List<QueryDocumentSnapshot> _sortBookings(List<QueryDocumentSnapshot> bookings) {
    List<QueryDocumentSnapshot> sortedBookings = List.from(bookings);
    
    sortedBookings.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      
      int comparison;
      
      switch (sortBy) {
        case 'name':
          final aName = (aData['userName'] ?? '').toLowerCase();
          final bName = (bData['userName'] ?? '').toLowerCase();
          comparison = aName.compareTo(bName);
          break;
        case 'date':
          final aDate = aData['registeredAt'] as Timestamp?;
          final bDate = bData['registeredAt'] as Timestamp?;
          if (aDate == null && bDate == null) {
            comparison = 0;
          } else if (aDate == null) {
            comparison = 1;
          } else if (bDate == null) {
            comparison = -1;
          } else {
            comparison = aDate.compareTo(bDate);
          }
          break;
        case 'email':
          final aEmail = (aData['userEmail'] ?? '').toLowerCase();
          final bEmail = (bData['userEmail'] ?? '').toLowerCase();
          comparison = aEmail.compareTo(bEmail);
          break;
        default:
          comparison = 0;
      }
      
      return sortAscending ? comparison : -comparison;
    });
    
    return sortedBookings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Bookings for ${widget.eventData['name']}',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            fontSize: 21,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.teal.shade900.withOpacity(0.7),
                Colors.teal.shade700.withOpacity(0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.cyan.shade50,
              Colors.teal.shade50,
              Colors.grey.shade100,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                SizedBox(height: 20),
                // Search and Filter Bar with enhanced glass effect
                AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  margin: EdgeInsets.only(top: 90, left: 16, right: 16, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.7),
                                    Colors.cyan.shade50.withOpacity(0.4),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.grey.shade200.withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyan.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextField(
                                onChanged: (value) {
                                  setState(() {
                                    searchQuery = value.toLowerCase();
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search by participant name...',
                                  prefixIcon: Icon(Icons.search, color: Colors.teal.shade700, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.7),
                                          Colors.cyan.shade50.withOpacity(0.4),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.grey.shade200.withOpacity(0.3),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.cyan.withOpacity(0.08),
                                          blurRadius: 12,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: DropdownButtonFormField<String>(
                                      value: sortBy,
                                      decoration: InputDecoration(
                                        labelText: 'Sort by',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: Colors.transparent,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        labelStyle: TextStyle(fontSize: 14),
                                      ),
                                      items: [
                                        DropdownMenuItem<String>(
                                          value: 'name',
                                          child: Text('Name', style: TextStyle(fontSize: 14)),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'date',
                                          child: Text('Registration Date', style: TextStyle(fontSize: 14)),
                                        ),
                                      ],
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          sortBy = newValue!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.7),
                                        Colors.cyan.shade50.withOpacity(0.4),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.grey.shade200.withOpacity(0.3),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.cyan.withOpacity(0.08),
                                        blurRadius: 12,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        sortAscending = !sortAscending;
                                      });
                                    },
                                    icon: Icon(
                                      sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                      color: Colors.teal.shade700,
                                      size: 20,
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
                ),
                
                // Bookings List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('event_registrations')
                        .where('eventId', isEqualTo: widget.eventData['id'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 500),
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyan.withOpacity(0.15),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade700),
                              ),
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 500),
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 40,
                                      color: Colors.red.shade400,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Error loading bookings',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      '${snapshot.error}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 500),
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event_busy,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No bookings for this event',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Bookings will appear here when users register',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      // Apply search filter
                      List<QueryDocumentSnapshot> filteredBookings = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final userName = (data['userName'] ?? '').toLowerCase();
                        final userEmail = (data['userEmail'] ?? '').toLowerCase();
                        
                        // Search filter
                        if (searchQuery.isNotEmpty && 
                            !userName.contains(searchQuery) && 
                            !userEmail.contains(searchQuery)) {
                          return false;
                        }
                        
                        return true;
                      }).toList();

                      // Sort the filtered bookings
                      filteredBookings = _sortBookings(filteredBookings);

                      if (filteredBookings.isEmpty) {
                        return Center(
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 500),
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No bookings found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Try adjusting your search',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredBookings.length,
                        itemBuilder: (context, index) {
                          final booking = filteredBookings[index];
                          final data = booking.data() as Map<String, dynamic>;
                          
                          return FutureBuilder<Map<String, dynamic>?>(
                            future: _getUserData(data['userId'] ?? ''),
                            builder: (context, userSnapshot) {
                              final userData = userSnapshot.data;
                              
                              return AnimatedContainer(
                                duration: Duration(milliseconds: 500),
                                curve: Curves.elasticOut,
                                margin: EdgeInsets.only(bottom: 16),
                                child: FadeTransition(
                                  opacity: AlwaysStoppedAnimation(1.0),
                                  child: _buildBookingCard(data, widget.eventData, booking.id, userData),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> bookingData, Map<String, dynamic> eventData, String bookingId, Map<String, dynamic>? userData) {
    final userName = userData?['name'] ?? bookingData['userName'] ?? 'Unknown User';
    final userEmail = userData?['email'] ?? bookingData['userEmail'] ?? 'No email';
    final userMobile = userData?['mobile'] ?? bookingData['userPhone'] ?? 'No mobile';
    final userImage = userData?['imageUrl'] ?? '';

    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.cyan.shade100.withOpacity(0.8),
                            Colors.teal.shade200.withOpacity(0.4),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.cyan.shade300.withOpacity(0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.withOpacity(0.15),
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: userImage.isNotEmpty
                          ? CircleAvatar(
                              backgroundColor: Colors.transparent,
                              backgroundImage: NetworkImage(userImage),
                              radius: 24,
                            )
                          : CircleAvatar(
                              backgroundColor: Colors.transparent,
                              radius: 24,
                              child: Icon(Icons.person, color: Colors.teal.shade700, size: 24),
                            ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Colors.teal.shade600,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Registered: ${_formatEventDate(bookingData['registeredAt'])}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.green.shade100.withOpacity(0.8),
                            Colors.teal.shade100.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.green.shade300.withOpacity(0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.15),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        'REGISTERED',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.teal.shade600,
                              Colors.cyan.shade500,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 0,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _showParticipantDetails(bookingData, eventData, bookingId, userData),
                          icon: Icon(Icons.visibility, size: 16),
                          label: Text('View Details', style: TextStyle(fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.7),
                              Colors.cyan.shade50.withOpacity(0.4),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.teal.shade600.withOpacity(0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              spreadRadius: 0,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: OutlinedButton.icon(
                          onPressed: () => _contactParticipant(userData),
                          icon: Icon(Icons.email, size: 16),
                          label: Text('Contact', style: TextStyle(fontSize: 14)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal.shade600,
                            backgroundColor: Colors.transparent,
                            side: BorderSide(color: Colors.transparent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
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
  }

  void _showParticipantDetails(Map<String, dynamic> bookingData, Map<String, dynamic> eventData, String bookingId, Map<String, dynamic>? userData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ParticipantDetailsDialog(
        bookingData: bookingData,
        eventData: eventData,
        bookingId: bookingId,
        userData: userData,
      ),
    );
  }

  void _contactParticipant(Map<String, dynamic>? userData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ContactParticipantDialog(
        userData: userData,
      ),
    );
  }

  void _sendEmail(String email) async {
    if (email.isNotEmpty) {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=Event Details&body=Hello,',
      );
      
      try {
        await launchUrl(emailUri);
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Could not open email client',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } else {
      Fluttertoast.showToast(
        msg: 'No email address available',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  }

  void _makeCall(String phone) async {
    if (phone.isNotEmpty) {
      final Uri phoneUri = Uri(scheme: 'tel', path: phone);
      
      try {
        await launchUrl(phoneUri);
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Could not make call',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } else {
      Fluttertoast.showToast(
        msg: 'No phone number available',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  }

  String _formatEventDate(dynamic date) {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return date.toString();
  }

  String _formatEventTime(String? time) {
    if (time == null) return 'N/A';
    
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      
      return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return time;
    }
  }
}

class ParticipantDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final Map<String, dynamic> eventData;
  final String bookingId;
  final Map<String, dynamic>? userData;

  ParticipantDetailsDialog({
    super.key,
    required this.bookingData,
    required this.eventData,
    required this.bookingId,
    required this.userData,
  });

  @override
  _ParticipantDetailsDialogState createState() => _ParticipantDetailsDialogState();
}

class _ParticipantDetailsDialogState extends State<ParticipantDetailsDialog> 
    with TickerProviderStateMixin {
  late AnimationController _sheetController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late Animation<double> _sheetAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    _sheetController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700),
    );
    
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    
    _scaleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900),
    );
    
    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..repeat();
    
    _sheetAnimation = CurvedAnimation(
      parent: _sheetController,
      curve: Curves.elasticOut,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );
    
    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeInOut,
      ),
    );
    
    _sheetController.forward();
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_sheetAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _sheetAnimation.value) * 100),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                margin: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 30,
                      offset: Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated handle with shimmer
                        AnimatedContainer(
                          duration: Duration(milliseconds: 400),
                          width: 40,
                          height: 5,
                          margin: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        
                        // Header with enhanced glass effect
                        Container(
                          padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.cyan.shade50.withOpacity(0.7),
                                Colors.white.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.cyan.shade100.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: Duration(milliseconds: 500),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.cyan.shade600.withOpacity(0.2),
                                      Colors.teal.shade400.withOpacity(0.1),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.cyan.shade600.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.teal.shade700,
                                  size: 22,
                                ),
                              ),
                              SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Participant Details',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal.shade800,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(Icons.close, color: Colors.grey.shade600, size: 20),
                              ),
                            ],
                          ),
                        ),
                        
                        // Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Participant Information with enhanced glass card
                                AnimatedContainer(
                                  duration: Duration(milliseconds: 500),
                                  margin: EdgeInsets.only(bottom: 16),
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.cyan.shade50.withOpacity(0.8),
                                        Colors.white.withOpacity(0.4),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.cyan.shade200.withOpacity(0.4),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.cyan.withOpacity(0.12),
                                        blurRadius: 16,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.cyan.shade100.withOpacity(0.7),
                                                  Colors.teal.shade200.withOpacity(0.3),
                                                ],
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.person_outline,
                                              color: Colors.teal.shade700,
                                              size: 18,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Participant Information',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal.shade800,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 16),
                                      _buildDetailRow('Name', widget.userData?['name'] ?? 'N/A', Icons.person),
                                      _buildDetailRow('Email', widget.userData?['email'] ?? 'N/A', Icons.email),
                                      _buildDetailRow('Mobile', widget.userData?['mobile'] ?? 'N/A', Icons.phone),
                                      _buildDetailRow('Registration Date', _formatEventDate(widget.bookingData['registeredAt']), Icons.calendar_today),
                                    ],
                                  ),
                                ),
                                
                                // Event Information with enhanced glass card
                                AnimatedContainer(
                                  duration: Duration(milliseconds: 500),
                                  margin: EdgeInsets.only(bottom: 16),
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.blue.shade50.withOpacity(0.8),
                                        Colors.white.withOpacity(0.4),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.blue.shade200.withOpacity(0.4),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.12),
                                        blurRadius: 16,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.blue.shade100.withOpacity(0.7),
                                                  Colors.blue.shade200.withOpacity(0.3),
                                                ],
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.event_outlined,
                                              color: Colors.blue.shade700,
                                              size: 18,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Event Information',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue.shade800,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 16),
                                      _buildDetailRow('Event Name', widget.eventData['name'] ?? 'N/A', Icons.event),
                                      _buildDetailRow('Event Date', _formatEventDate(widget.eventData['eventDate']), Icons.calendar_today),
                                      if (widget.eventData['eventTime'] != null)
                                        _buildDetailRow('Event Time', _formatEventTime(widget.eventData['eventTime']), Icons.access_time),
                                      _buildDetailRow('Event Type', widget.eventData['eventType'] ?? 'N/A', Icons.category),
                                      _buildDetailRow('Payment Type', widget.eventData['paymentType'] ?? 'N/A', Icons.payment),
                                      if (widget.eventData['paymentType'] != 'Free' && widget.eventData['price'] != null)
                                        _buildDetailRow('Price', '₹${widget.eventData['price']}', Icons.attach_money),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Footer with enhanced glass effect
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey.shade50.withOpacity(0.8),
                                Colors.white.withOpacity(0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(32),
                              bottomRight: Radius.circular(32),
                            ),
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey.shade200.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade600,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.teal.withOpacity(0.3),
                                ),
                                child: Text(
                                  'Close',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.cyan.shade50.withOpacity(0.8),
                  Colors.teal.shade100.withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.cyan.shade200.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.teal.shade600,
              size: 18,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatEventDate(dynamic date) {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return date.toString();
  }

  String _formatEventTime(String? time) {
    if (time == null) return 'N/A';
    
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      
      return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return time;
    }
  }
}

class ContactParticipantDialog extends StatefulWidget {
  final Map<String, dynamic>? userData;

  ContactParticipantDialog({
    super.key,
    required this.userData,
  });

  @override
  _ContactParticipantDialogState createState() => _ContactParticipantDialogState();
}

class _ContactParticipantDialogState extends State<ContactParticipantDialog> 
    with TickerProviderStateMixin {
  late AnimationController _sheetController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late Animation<double> _sheetAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    _sheetController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700),
    );
    
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    
    _scaleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900),
    );
    
    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..repeat();
    
    _sheetAnimation = CurvedAnimation(
      parent: _sheetController,
      curve: Curves.elasticOut,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );
    
    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeInOut,
      ),
    );
    
    _sheetController.forward();
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_sheetAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _sheetAnimation.value) * 100),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                margin: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 30,
                      offset: Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header with enhanced glass effect
                          Container(
                            padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.cyan.shade50.withOpacity(0.7),
                                  Colors.white.withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(32),
                                topRight: Radius.circular(32),
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.cyan.shade100.withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: Duration(milliseconds: 500),
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.cyan.shade600.withOpacity(0.2),
                                        Colors.teal.shade400.withOpacity(0.1),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.cyan.shade600.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.contact_phone,
                                    color: Colors.teal.shade700,
                                    size: 22,
                                  ),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    'Contact Participant',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.teal.shade800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(Icons.close, color: Colors.grey.shade600, size: 20),
                                ),
                              ],
                            ),
                          ),
                          
                          // Contact options
                          SizedBox(height: 20),
                          AnimatedContainer(
                            duration: Duration(milliseconds: 500),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.7),
                                  Colors.cyan.shade50.withOpacity(0.4),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.grey.shade200.withOpacity(0.4),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.blue.shade100.withOpacity(0.8),
                                          Colors.blue.shade200.withOpacity(0.4),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.blue.shade300.withOpacity(0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.email,
                                      color: Colors.blue.shade700,
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    'Send Email',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    widget.userData?['email'] ?? 'No email available',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    _sendEmail(widget.userData?['email'] ?? '');
                                  },
                                ),
                                if (widget.userData?['mobile'] != null)
                                  ListTile(
                                    leading: AnimatedContainer(
                                      duration: Duration(milliseconds: 300),
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.green.shade100.withOpacity(0.8),
                                            Colors.green.shade200.withOpacity(0.4),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.green.shade300.withOpacity(0.4),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.phone,
                                        color: Colors.green.shade700,
                                        size: 24,
                                      ),
                                    ),
                                    title: Text(
                                      'Call',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text(
                                      widget.userData?['mobile'],
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      _makeCall(widget.userData?['mobile'] ?? '');
                                    },
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
            ),
          ),
        );
      },
    );
  }

  void _sendEmail(String email) async {
    if (email.isNotEmpty) {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=Event Details&body=Hello,',
      );
      
      try {
        await launchUrl(emailUri);
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Could not open email client',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } else {
      Fluttertoast.showToast(
        msg: 'No email address available',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  }

  void _makeCall(String phone) async {
    if (phone.isNotEmpty) {
      final Uri phoneUri = Uri(scheme: 'tel', path: phone);
      
      try {
        await launchUrl(phoneUri);
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Could not make call',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } else {
      Fluttertoast.showToast(
        msg: 'No phone number available',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  }
}