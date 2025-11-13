import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpotEventsPage extends StatefulWidget {
  final User? user;
  SpotEventsPage({super.key, this.user});

  @override
  _SpotEventsPageState createState() => _SpotEventsPageState();
}

class _SpotEventsPageState extends State<SpotEventsPage> 
    with TickerProviderStateMixin {
  String searchQuery = '';
  String selectedFilter = 'All';
  late AnimationController _animationController;
  late AnimationController _shimmerController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<Offset> _floatAnimation;
  Map<String, bool> _registrationStatus = {};
  List<Map<String, dynamic>> _cachedUpcomingEvents = [];
  String? _userProfileName;
  String? _userProfileEmail;
  String? _userProfilePhone;
  String? _userProfileImageUrl;
  Future<void>? _profileFuture;
  bool _hasLoadedProfile = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();
    _floatController = AnimationController(
      duration: Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    
    _floatAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(0, -0.02),
    ).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
    
    _animationController.forward();

    if (widget.user != null) {
      _profileFuture = _loadUserProfile();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shimmerController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFB),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF0F9FF),
                  Color(0xFFF8FAFB),
                  Color(0xFFEFF6FF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Floating background elements
          Positioned.fill(
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: 100 + _floatAnimation.value.dy * 100,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF00897B).withOpacity(0.05),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00897B).withOpacity(0.1),
                              blurRadius: 60,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 100,
                  left: -80,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF26A69A).withOpacity(0.03),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF26A69A).withOpacity(0.08),
                          blurRadius: 80,
                          spreadRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildPremiumAppBar(),
                  SizedBox(height: 24),
                  _buildSearchAndFilterBar(),
                  Expanded(child: _buildEventsStream()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumAppBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.85),
                  Colors.white.withOpacity(0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Color(0xFF00897B).withOpacity(0.1),
                  blurRadius: 15,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF00897B).withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(Icons.event_rounded, color: Colors.white, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Book Your Spot Events ⌛',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.teal, letterSpacing: 0.5),
                  ),
                ),
                
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Color(0xFF00897B).withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: Color(0xFF00897B).withOpacity(0.08),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search events...',
                hintStyle: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Container(
                  margin: EdgeInsets.all(12),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.search_rounded, color: Colors.white, size: 18),
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? Container(
                        margin: EdgeInsets.all(8),
                        child: IconButton(
                          icon: Icon(Icons.clear_rounded, 
                            color: Color(0xFF64748B), size: 20),
                          onPressed: () => setState(() => searchQuery = ''),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
          SizedBox(height: 16),
          // Filter Chips
          Row(
            children: [
              _buildFilterChip('All'),
              SizedBox(width: 12),
              _buildFilterChip('Upcoming'),
              SizedBox(width: 12),
              _buildFilterChip('Past'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = selectedFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedFilter = filter),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected 
                ? LinearGradient(
                    colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [Colors.white, Colors.white.withOpacity(0.95)],
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? Colors.transparent 
                  : Color(0xFF00897B).withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Color(0xFF00897B).withOpacity(0.25),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              filter,
              style: TextStyle(
                color: isSelected ? Colors.white : Color(0xFF475569),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  DateTime? _parseEventDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String _normalizeEventType(dynamic value) {
    if (value == null) return '';
    return value.toString().trim().toLowerCase();
  }

  Widget _buildEventsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spot_events')
          .where('status', isEqualTo: 'approved')
          .where('isBookingOpen', isEqualTo: true)
          .orderBy('eventDate', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _buildLoadingState();
        if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

        List<QueryDocumentSnapshot> filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final eventName = (data['name'] ?? '').toLowerCase();
          final eventDate = data['eventDate'];

          if (searchQuery.isNotEmpty && !eventName.contains(searchQuery)) return false;

          if (selectedFilter != 'All') {
            final now = DateTime.now();
            final eventDateTime = _parseEventDateTime(eventDate);
            if (eventDateTime != null) {
              if (selectedFilter == 'Upcoming' && eventDateTime.isBefore(now)) return false;
              if (selectedFilter == 'Past' && eventDateTime.isAfter(now)) return false;
            }
          }
          return true;
        }).toList();

        if (filteredDocs.isEmpty) return _buildNoResultsState();

        final now = DateTime.now();
        final upcomingDocs = <QueryDocumentSnapshot>[];
        final pastDocs = <QueryDocumentSnapshot>[];

        for (final doc in filteredDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final eventDateTime = _parseEventDateTime(data['eventDate']);
          if (eventDateTime != null && eventDateTime.isBefore(now)) {
            pastDocs.add(doc);
          } else {
            upcomingDocs.add(doc);
          }
        }

        int compareByEventDate(QueryDocumentSnapshot a, QueryDocumentSnapshot b, {bool ascending = true}) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final dateA = _parseEventDateTime(dataA['eventDate']) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = _parseEventDateTime(dataB['eventDate']) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final result = dateA.compareTo(dateB);
          return ascending ? result : -result;
        }

        upcomingDocs.sort((a, b) => compareByEventDate(a, b, ascending: true));
        pastDocs.sort((a, b) => compareByEventDate(a, b, ascending: false));

        _cachedUpcomingEvents = upcomingDocs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
          return {
            'id': doc.id,
            'data': data,
            'type': _normalizeEventType(data['eventType']),
          };
        }).toList();

        final combinedDocs = [...upcomingDocs, ...pastDocs];

        if (combinedDocs.isEmpty) return _buildNoResultsState();

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: combinedDocs.length,
          itemBuilder: (context, index) {
            final eventDoc = combinedDocs[index];
            final data = Map<String, dynamic>.from(eventDoc.data() as Map<String, dynamic>);
            final eventDateTime = _parseEventDateTime(data['eventDate']);
            final isUpcoming = !(eventDateTime != null && eventDateTime.isBefore(now));

            return TweenAnimationBuilder(
              duration: Duration(milliseconds: 400 + (index * 100)),
              tween: Tween<double>(begin: 0, end: 1),
              curve: Curves.easeOutCubic,
              builder: (context, double value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 16),
                child: _buildEventCard(data, eventDoc.id, isUpcoming: isUpcoming),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> eventData, String eventId, {required bool isUpcoming}) {
    final eventDate = eventData['eventDate'];
    DateTime? eventDateTime;
    
    if (eventDate != null) {
      eventDateTime = _parseEventDateTime(eventDate);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Color(0xFF00897B).withOpacity(0.06),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEventDetailsBottomSheet(eventData, eventId, isUpcoming: isUpcoming),
          borderRadius: BorderRadius.circular(20),
          splashColor: Color(0xFF00897B).withOpacity(0.1),
          highlightColor: Color(0xFF00897B).withOpacity(0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              Container(
                height: 160,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      child: Image.network(
                        eventData['imageUrl'] ?? 'https://picsum.photos/400/200',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFE0F2F1),
                                Color(0xFFB2DFDB),
                                Color(0xFF80CBC4),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_rounded, 
                                  size: 48, color: Color(0xFF00897B)),
                                SizedBox(height: 8),
                                Text(
                                  'Event Image',
                                  style: TextStyle(
                                    color: Color(0xFF00897B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.5),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.4, 0.7, 1.0],
                        ),
                      ),
                    ),
                    // Status Badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isUpcoming
                                ? [Color(0xFF00C853), Color(0xFF64DD17)]
                                : [Color(0xFF757575), Color(0xFF9E9E9E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (isUpcoming ? Color(0xFF00C853) : Colors.grey).withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUpcoming ? Icons.lock_open_rounded : Icons.lock_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              isUpcoming ? 'UPCOMING' : 'PAST',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Event Type Badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00897B).withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          eventData['eventType'] ?? 'Event',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content Section
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventData['name'] ?? 'Unnamed Event',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Color(0xFF1E293B),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Text(
                      eventData['description'] ?? 'No description',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 16),
                    // Info Row
                    Row(
                      children: [
                        _buildInfoChip(Icons.calendar_today_rounded, 
                          _formatEventDate(eventData['eventDate'])),
                        SizedBox(width: 8),
                        _buildInfoChip(Icons.access_time_rounded, 
                          _formatEventTime(eventData['eventTime'])),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        _buildInfoChip(Icons.location_on_rounded, 
                          eventData['location'] ?? 'TBA'),
                        SizedBox(width: 8),
                        _buildInfoChip(
                          Icons.payments_rounded,
                          eventData['price'] != null && eventData['price'] > 0
                              ? '₹${eventData['price']}'
                              : 'Free',
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Action Button
                    Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF00897B).withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showEventDetailsBottomSheet(eventData, eventId, isUpcoming: isUpcoming),
                          borderRadius: BorderRadius.circular(12),
                          splashColor: Colors.white.withOpacity(0.3),
                          highlightColor: Colors.white.withOpacity(0.2),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'View Details',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildInfoChip(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE0F2F1),
              Color(0xFFB2DFDB),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Color(0xFF00897B).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Color(0xFF00897B)),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00897B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF00897B),
                      Color(0xFF26A69A),
                      Color(0xFF4DB6AC),
                      Color(0xFF00897B),
                    ],
                    stops: [
                      _shimmerAnimation.value - 0.3,
                      _shimmerAnimation.value,
                      _shimmerAnimation.value + 0.3,
                      _shimmerAnimation.value + 0.6,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF00897B).withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 24),
          Text(
            'Loading Events...',
            style: TextStyle(
              color: Color(0xFF00897B),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(32),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.red.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 48, color: Colors.red),
            ),
            SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.w800, 
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Color(0xFF64748B), 
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() {}),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      'Try Again',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(32),
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Color(0xFF00897B).withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE0F2F1), Color(0xFFB2DFDB)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF00897B).withOpacity(0.2),
                    blurRadius: 15,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(Icons.event_busy_rounded, 
                size: 56, color: Color(0xFF00897B)),
            ),
            SizedBox(height: 20),
            Text(
              'No Events Available',
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.w800, 
                color: Color(0xFF1E293B),
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check back later for exciting events!',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(32),
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded, 
                size: 56, color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            Text(
              'No Events Found',
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.w800, 
                color: Color(0xFF1E293B),
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try different search criteria',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetailsBottomSheet(Map<String, dynamic> eventData, String eventId, {required bool isUpcoming}) {
    if (!isUpcoming) {
      _showPastEventInfoSheet(eventData, eventId);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PremiumEventDetailsBottomSheet(
        eventData: eventData,
        eventId: eventId,
        user: widget.user,
        isUpcoming: isUpcoming,
      ),
    );
  }

  void _showPastEventInfoSheet(Map<String, dynamic> eventData, String eventId) {
    final eventDate = _parseEventDateTime(eventData['eventDate']);
    final formattedDate = eventDate != null
        ? DateFormat('MMMM dd, yyyy').format(eventDate)
        : 'an earlier date';

    final currentType = _normalizeEventType(eventData['eventType']);

    final similarEvents = _cachedUpcomingEvents.where((entry) {
      final id = entry['id'] as String;
      if (id == eventId) return false;

      if (currentType.isEmpty) {
        // If the source event has no type, just surface upcoming events excluding itself
        return true;
      }

      final entryType = entry['type'] as String? ?? _normalizeEventType((entry['data'] as Map<String, dynamic>)['eventType']);
      return entryType == currentType;
    }).toList();

    final displayEvents = similarEvents.take(3).toList();
    final hasMore = similarEvents.length > displayEvents.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.75,
          minChildSize: 0.4,
          builder: (context, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: ListView(
                  controller: controller,
                  children: [
                    Center(
                      child: Container(
                        height: 5,
                        width: 46,
                        decoration: BoxDecoration(
                          color: Color(0xFFB2DFDB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.history_rounded, color: Color(0xFFD32F2F)),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Missed This One 🪦',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'This event already wrapped up on $formattedDate.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Discover similar upcoming events',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00897B),
                      ),
                    ),
                    SizedBox(height: 16),
                    if (displayEvents.isEmpty)
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_available, color: Color(0xFF00897B)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'We will add more events like this soon. Stay tuned!'
                                ,
                                style: TextStyle(
                                  color: Color(0xFF006064),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 160,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: displayEvents.length,
                              separatorBuilder: (_, __) => SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final event = displayEvents[index];
                                final data = event['data'] as Map<String, dynamic>;
                                final id = event['id'] as String;
                                return _buildSimilarEventCard(data, id);
                              },
                            ),
                          ),
                          if (hasMore)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _openSimilarEventsPage(
                                    title: 'Events you may be interested in',
                                    events: similarEvents,
                                  );
                                },
                                icon: Icon(Icons.arrow_forward_rounded, color: Color(0xFF00897B)),
                                label: Text(
                                  'View more',
                                  style: TextStyle(
                                    color: Color(0xFF00897B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openSimilarEventsPage(
                          title: 'Fresh events you may love',
                          events: similarEvents,
                        );
                      },
                      icon: Icon(Icons.explore_outlined, color: Color(0xFF00897B)),
                      label: Text(
                        'Explore other events',
                        style: TextStyle(
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFF00897B).withOpacity(0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSimilarEventCard(Map<String, dynamic> data, String eventId) {
    return GestureDetector(
      onTap: () => _showEventDetailsBottomSheet(data, eventId, isUpcoming: true),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              child: Image.network(
                data['imageUrl'] ?? 'https://picsum.photos/200/120',
                height: 90,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE0F2F1), Color(0xFFB2DFDB)],
                    ),
                  ),
                  child: Icon(Icons.event_rounded, color: Color(0xFF00897B)),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'Event',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Text(
                      _formatEventDate(data['eventDate']),
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSimilarEventsPage({required String title, required List<dynamic> events}) {
    final upcomingEvents = events.whereType<Map<String, dynamic>>().toList();
    if (upcomingEvents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No similar events available right now. Stay tuned!'),
        ),
      );
      return;
    }

    upcomingEvents.sort((a, b) {
      final dataA = a['data'] as Map<String, dynamic>;
      final dataB = b['data'] as Map<String, dynamic>;
      final dtA = _parseEventDateTime(dataA['eventDate']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dtB = _parseEventDateTime(dataB['eventDate']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dtA.compareTo(dtB);
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimilarEventsPage(
          title: title,
          events: upcomingEvents,
          onEventSelected: (event) {
            Navigator.of(context).pop();
            final data = event['data'] as Map<String, dynamic>;
            final id = event['id'] as String;
            _showEventDetailsBottomSheet(data, id, isUpcoming: true);
          },
        ),
      ),
    );
  }

  String _formatEventDate(dynamic date) {
    if (date == null) return 'TBA';
    try {
      DateTime dateTime = date is Timestamp ? date.toDate() : DateTime.parse(date.toString());
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      return date.toString();
    }
  }

  String _formatEventTime(dynamic time) {
    if (time == null) return 'TBA';
    
    try {
      if (time is String) {
        final parts = time.split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);
          
          String period = hour >= 12 ? 'PM' : 'AM';
          hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
          
          return '$hour:${minute.toString().padLeft(2, '0')} $period';
        }
      }
    } catch (e) {
      print('Error formatting time: $e');
    }
    
    return time.toString();
  }

  Future<void> _ensureUserProfileLoaded() async {
    if (_hasLoadedProfile) return;
    _profileFuture ??= _loadUserProfile();
    await _profileFuture;
  }

  Future<void> _loadUserProfile() async {
    if (widget.user == null) {
      _hasLoadedProfile = true;
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(widget.user!.uid).get();
      final data = snapshot.data();

      String? name;
      if (data != null) {
        final rawName = (data['name'] ?? data['fullName']) as String?;
        if (rawName != null && rawName.trim().isNotEmpty) {
          name = rawName.trim();
        }
      }

      String? email;
      if (data != null) {
        final rawEmail = (data['email'] ?? data['userEmail']) as String?;
        if (rawEmail != null && rawEmail.trim().isNotEmpty) {
          email = rawEmail.trim();
        }
      }

      String? phone;
      if (data != null) {
        final rawPhone = (data['mobile'] ?? data['phoneNumber']) as String?;
        if (rawPhone != null && rawPhone.trim().isNotEmpty) {
          phone = rawPhone.trim();
        }
      }

      String? imageUrl;
      if (data != null) {
        final rawImage = (data['imageUrl'] ?? data['photoUrl']) as String?;
        if (rawImage != null && rawImage.trim().isNotEmpty) {
          imageUrl = rawImage.trim();
        }
      }

      if (!mounted) {
        _hasLoadedProfile = true;
        return;
      }

      setState(() {
        _userProfileName = name;
        _userProfileEmail = email;
        _userProfilePhone = phone;
        _userProfileImageUrl = imageUrl;
        _hasLoadedProfile = true;
      });
    } catch (e) {
      if (!mounted) {
        _hasLoadedProfile = true;
        return;
      }
      setState(() {
        _hasLoadedProfile = true;
      });
      print('[EventProfile] Failed to load user profile: $e');
    }
  }

  String _resolveUserName() {
    if (_userProfileName != null && _userProfileName!.isNotEmpty) {
      return _userProfileName!;
    }
    final displayName = widget.user?.displayName;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    final email = widget.user?.email;
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'User';
  }

  String _resolveUserEmail() {
    if (_userProfileEmail != null && _userProfileEmail!.isNotEmpty) {
      return _userProfileEmail!;
    }
    return widget.user?.email ?? '';
  }

  String _resolveUserPhone() {
    if (_userProfilePhone != null && _userProfilePhone!.isNotEmpty) {
      return _userProfilePhone!;
    }
    return widget.user?.phoneNumber ?? '';
  }
}

class PremiumEventDetailsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> eventData;
  final String eventId;
  final User? user;
  final bool isUpcoming;

  const PremiumEventDetailsBottomSheet({
    Key? key,
    required this.eventData,
    required this.eventId,
    required this.user,
    required this.isUpcoming,
  }) : super(key: key);

  @override
  State<PremiumEventDetailsBottomSheet> createState() => _PremiumEventDetailsBottomSheetState();
}

class _PremiumEventDetailsBottomSheetState extends State<PremiumEventDetailsBottomSheet> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _scaleController;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  bool _isRegistered = false;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  late Razorpay _razorpay;
  
  // User profile state
  String? _userProfileName;
  String? _userProfileEmail;
  String? _userProfilePhone;
  String? _userProfileImageUrl;
  bool _hasLoadedProfile = false;
  Future<void>? _profileFuture;
  
  // Payment calculation helpers (same as turf bookings)
  double _platformProfit(double eventPrice) {
    if (eventPrice <= 1000) {
      return eventPrice * 0.15;
    } else if (eventPrice <= 3000) {
      return 110;
    } else {
      return 210;
    }
  }
  
  double _razorpayFeePercent() {
    return 0.02 * 1.18; // 2% + 18% GST = 2.36%
  }
  
  double _totalToCharge(double eventPrice) {
    double profit = _platformProfit(eventPrice);
    double feePercent = _razorpayFeePercent();
    return (eventPrice + profit) / (1 - feePercent);
  }
  
  // Convert dynamic date (Timestamp | DateTime | String) to YYYY-MM-DD for JSON-safe payloads
  String _toYmdString(dynamic date) {
    try {
      DateTime dt;
      if (date is Timestamp) {
        dt = date.toDate();
      } else if (date is DateTime) {
        dt = date;
      } else if (date is String) {
        // Attempt to parse; if fails, return as-is
        try {
          dt = DateTime.parse(date);
        } catch (_) {
          return date;
        }
      } else {
        return '';
      }
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {
      return '';
    }
  }

  // ===================================================================
  // USER PROFILE LOADING & RESOLUTION
  // ===================================================================

  Future<void> _ensureUserProfileLoaded() async {
    if (_hasLoadedProfile) return;
    _profileFuture ??= _loadUserProfile();
    await _profileFuture;
  }

  Future<void> _loadUserProfile() async {
    if (widget.user == null) {
      _hasLoadedProfile = true;
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(widget.user!.uid).get();
      final data = snapshot.data();

      String? name;
      if (data != null) {
        final rawName = (data['name'] ?? data['fullName']) as String?;
        if (rawName != null && rawName.trim().isNotEmpty) {
          name = rawName.trim();
        }
      }

      String? email;
      if (data != null) {
        final rawEmail = (data['email'] ?? data['userEmail']) as String?;
        if (rawEmail != null && rawEmail.trim().isNotEmpty) {
          email = rawEmail.trim();
        }
      }

      String? phone;
      if (data != null) {
        final rawPhone = (data['mobile'] ?? data['phoneNumber']) as String?;
        if (rawPhone != null && rawPhone.trim().isNotEmpty) {
          phone = rawPhone.trim();
        }
      }

      String? imageUrl;
      if (data != null) {
        final rawImage = (data['imageUrl'] ?? data['photoUrl']) as String?;
        if (rawImage != null && rawImage.trim().isNotEmpty) {
          imageUrl = rawImage.trim();
        }
      }

      if (!mounted) {
        _hasLoadedProfile = true;
        return;
      }

      setState(() {
        _userProfileName = name;
        _userProfileEmail = email;
        _userProfilePhone = phone;
        _userProfileImageUrl = imageUrl;
        _hasLoadedProfile = true;
      });
    } catch (e) {
      if (!mounted) {
        _hasLoadedProfile = true;
        return;
      }
      setState(() {
        _hasLoadedProfile = true;
      });
      print('[EventProfile] Failed to load user profile: $e');
    }
  }

  String _resolveUserName() {
    if (_userProfileName != null && _userProfileName!.isNotEmpty) {
      return _userProfileName!;
    }
    final displayName = widget.user?.displayName;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    final email = widget.user?.email;
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'User';
  }

  String _resolveUserEmail() {
    if (_userProfileEmail != null && _userProfileEmail!.isNotEmpty) {
      return _userProfileEmail!;
    }
    return widget.user?.email ?? '';
  }

  String _resolveUserPhone() {
    if (_userProfilePhone != null && _userProfilePhone!.isNotEmpty) {
      return _userProfilePhone!;
    }
    return widget.user?.phoneNumber ?? '';
  }

  // ===================================================================
  // PAYMENT PERSISTENCE & RECOVERY FUNCTIONS
  // ===================================================================

  Future<void> _savePendingEventPayment(String orderId, Map<String, dynamic> registrationData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_event_order_id', orderId);
      await prefs.setString('pending_event_registration_data', jsonEncode(registrationData));
      await prefs.setInt('pending_event_payment_timestamp', DateTime.now().millisecondsSinceEpoch);
      print('[EventPaymentPersistence] Saved pending payment: $orderId');
    } catch (e) {
      print('[EventPaymentPersistence] Error saving: $e');
    }
  }

  Future<void> _clearPendingEventPayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_event_order_id');
      await prefs.remove('pending_event_registration_data');
      await prefs.remove('pending_event_payment_timestamp');
      print('[EventPaymentPersistence] Cleared pending payment');
    } catch (e) {
      print('[EventPaymentPersistence] Error clearing: $e');
    }
  }


  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
    
    _animationController.forward();
    _scaleController.forward();
    _checkRegistrationStatus();
    
    // Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scaleController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _checkRegistrationStatus() async {
    if (widget.user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('event_registrations')
          .where('userId', isEqualTo: widget.user!.uid)
          .where('eventId', isEqualTo: widget.eventId)
          .get();

      setState(() {
        _isRegistered = snapshot.docs.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, MediaQuery.of(context).size.height * _slideAnimation.value),
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: child,
          ),
        );
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Stack(
          children: [
            // Background with enhanced glassmorphism
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.95),
                          Colors.white.withOpacity(0.9),
                          Colors.white.withOpacity(0.85),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 30,
                          offset: Offset(0, -15),
                        ),
                        BoxShadow(
                          color: Color(0xFF00897B).withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, -10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Content
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              child: Column(
                children: [
                  // Handle Bar
                  Container(
                    margin: EdgeInsets.only(top: 16),
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF00897B).withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero Image
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                widget.eventData['imageUrl'] ?? '',
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFE0F2F1),
                                        Color(0xFFB2DFDB),
                                        Color(0xFF80CBC4),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.event_rounded, 
                                          size: 64, color: Color(0xFF00897B)),
                                        SizedBox(height: 12),
                                        Text(
                                          'Event Image',
                                          style: TextStyle(
                                            color: Color(0xFF00897B),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                          // Event Name
                          Text(
                            widget.eventData['name'] ?? 'Unnamed Event',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                              letterSpacing: 0.3,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 16),
                          // Description
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFF8FAFB),
                                  Color(0xFFF1F5F9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Color(0xFF00897B).withOpacity(0.15),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.eventData['description'] ?? 'No description available',
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.6,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                          // Details Grid
                          _buildDetailTile(Icons.calendar_today_rounded, 
                            'Date', _formatEventDate(widget.eventData['eventDate'])),
                          _buildDetailTile(Icons.access_time_rounded, 
                            'Time', _formatEventTime(widget.eventData['eventTime'])),
                          _buildDetailTile(Icons.location_on_rounded, 
                            'Location', widget.eventData['location'] ?? 'TBA'),
                          _buildDetailTile(Icons.category_rounded, 
                            'Type', widget.eventData['eventType'] ?? 'General'),
                          _buildDetailTile(Icons.payments_rounded, 
                            'Price', widget.eventData['price'] != null && widget.eventData['price'] > 0 
                                ? '₹${widget.eventData['price']}' 
                                : 'Free Entry'),
                          _buildDetailTile(Icons.people_rounded, 
                            'Max Participants', '${widget.eventData['maxParticipants'] ?? 'Unlimited'}'),
                          SizedBox(height: 24),
                          // Register Button
                          _isLoading || _isProcessingPayment
                              ? Center(
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF00897B).withOpacity(0.3),
                                          blurRadius: 15,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: double.infinity,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: _isRegistered
                                        ? LinearGradient(
                                            colors: [Colors.grey, Colors.grey[600]!],
                                          )
                                        : LinearGradient(
                                            colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isRegistered ? Colors.grey : Color(0xFF00897B)).withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _isRegistered || _isProcessingPayment ? null : () => _registerForEvent(),
                                      borderRadius: BorderRadius.circular(16),
                                      splashColor: Colors.white.withOpacity(0.3),
                                      highlightColor: Colors.white.withOpacity(0.2),
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _isRegistered ? Icons.check_circle_rounded : Icons.app_registration_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              _isRegistered ? 'Already Registered' : (widget.eventData['price'] != null && widget.eventData['price'] > 0 ? 'Pay & Register' : 'Register Now'),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          SizedBox(height: 20),
                        ],
                      ),
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

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFF00897B).withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0xFF00897B).withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF00897B).withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registerForEvent() async {
    if (widget.user == null) {
      _showPremiumSnackBar(
        'Please login to register',
        Colors.orange,
        Icons.warning_rounded,
      );
      return;
    }

    final eventPrice = (widget.eventData['price'] ?? 0).toDouble();
    final isPaidEvent = eventPrice > 0;

    if (isPaidEvent) {
      // Handle paid event registration with Razorpay
      await _handlePaidEventRegistration(eventPrice);
    } else {
      // Handle free event registration
      await _handleFreeEventRegistration();
    }
  }

  Future<void> _handleFreeEventRegistration() async {
    try {
      setState(() => _isProcessingPayment = true);
      await _ensureUserProfileLoaded();

      final userName = _resolveUserName();
      final userEmail = _resolveUserEmail();
      final userPhone = _resolveUserPhone();
      final userImage = _userProfileImageUrl ?? '';

      final registrationsCollection = FirebaseFirestore.instance.collection('event_registrations');
      final registrationRef = await registrationsCollection.add({
        'eventId': widget.eventId,
        'eventName': widget.eventData['name'],
        'eventDate': widget.eventData['eventDate'],
        'eventTime': widget.eventData['eventTime'],
        'eventLocation': widget.eventData['location'] ?? '',
        'eventType': widget.eventData['eventType'] ?? '',
        'userId': widget.user!.uid,
        'userName': userName,
        'userEmail': userEmail,
        'userPhone': userPhone,
        'userImageUrl': userImage,
        'paymentType': 'Free',
        'price': 0,
        'status': 'confirmed',
        'paymentMethod': 'Free',
        'registeredAt': Timestamp.now(),
      });

      // Send confirmation email for free events too
      try {
        final HttpsCallable emailFn = FirebaseFunctions.instance.httpsCallable('sendEventRegistrationConfirmationEmail');
        await emailFn({
          'to': userEmail,
          'userName': userName,
          'userEmail': userEmail,
          'userPhone': userPhone,
          'registrationId': registrationRef.id,
          'eventName': widget.eventData['name'],
          'eventDate': _toYmdString(widget.eventData['eventDate']), // Convert Timestamp to string for Cloud Function
          'eventTime': widget.eventData['eventTime'],
          'eventLocation': widget.eventData['location'] ?? '',
          'eventType': widget.eventData['eventType'] ?? '',
          'amount': 0,
          'paymentMethod': 'Free',
          'paymentReference': '',
        });
      } catch (e) {
        print('[FreeEventEmail] Error sending confirmation email: $e');
        print('[FreeEventEmail] Error details: ${e.toString()}');
        // Don't fail the registration if email fails, but log it
      }

      Navigator.pop(context);
      _showPremiumSnackBar(
        'Successfully registered! 🎉',
        Color(0xFF00C853),
        Icons.check_circle_rounded,
      );
    } catch (e) {
      setState(() => _isProcessingPayment = false);
      _showPremiumSnackBar(
        'Registration failed: ${e.toString()}',
        Colors.red,
        Icons.error_rounded,
      );
    }
  }

  Future<void> _handlePaidEventRegistration(double eventPrice) async {
    try {
      setState(() => _isProcessingPayment = true);
      await _ensureUserProfileLoaded();

      final userName = _resolveUserName();
      final userEmail = _resolveUserEmail();
      final userPhone = _resolveUserPhone();
      final userImage = _userProfileImageUrl ?? '';

      // Get event owner account ID
      final eventDoc = await FirebaseFirestore.instance.collection('spot_events').doc(widget.eventId).get();
      if (!eventDoc.exists) {
        throw Exception('Event not found');
      }

      final eventData = eventDoc.data()!;
      final ownerId = eventData['ownerId'];
      
      String? ownerAccountId;
      if (ownerId != null) {
        final ownerDoc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
        if (ownerDoc.exists) {
          ownerAccountId = ownerDoc.data()?['razorpayAccountId'];
        }
      }

      if (ownerAccountId == null || !ownerAccountId.toString().startsWith('acc_')) {
        setState(() => _isProcessingPayment = false);
        _showPremiumSnackBar(
          'Event owner does not have a valid Razorpay Account ID. Please contact support.',
          Colors.red,
          Icons.error_rounded,
        );
        return;
      }

      // Calculate amounts
      final baseAmount = eventPrice;
      final payableAmount = _totalToCharge(baseAmount);
      final registrationId = '${widget.eventId}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Prepare registration data for recovery
      // Note: All values must be JSON-safe (String, int, double, bool, List, Map, null)
      // Timestamp objects cannot be passed directly to Cloud Functions
      final registrationData = {
        'userId': widget.user!.uid,
        'eventId': widget.eventId,
        'eventName': widget.eventData['name'],
        'eventLocation': widget.eventData['location'] ?? '',
        'eventType': widget.eventData['eventType'] ?? '',
        'ownerId': ownerId,
        // Use JSON-safe string for callable payloads
        'eventDate': _toYmdString(widget.eventData['eventDate']),
        'eventTime': widget.eventData['eventTime'],
        'baseAmount': baseAmount,
        'payableAmount': payableAmount,
        'userName': userName,
        'userEmail': userEmail,
        'userPhone': userPhone,
        'userImageUrl': userImage,
        'paymentType': 'Paid',
        'price': eventPrice,
        'status': 'confirmed',
        'paymentMethod': 'Online',
        'registeredAt': DateTime.now().toIso8601String(), // Convert to ISO string for Cloud Function
      };

      // Create Razorpay order with transfer
      final HttpsCallable orderFn = FirebaseFunctions.instance.httpsCallable('createRazorpayOrderWithTransferForEvent');
      final orderResult = await orderFn({
        'totalAmount': baseAmount,
        'payableAmount': payableAmount,
        'ownerAccountId': ownerAccountId,
        'registrationId': registrationId,
        'eventId': widget.eventId,
        'userId': widget.user!.uid,
        'registrationData': registrationData, // Store registration data for recovery
      });

      final orderId = orderResult.data['orderId'];
      if (orderId == null) {
        setState(() => _isProcessingPayment = false);
        _showPremiumSnackBar(
          'Failed to create payment order. Please try again.',
          Colors.red,
          Icons.error_rounded,
        );
        return;
      }

      // ✅ SAVE PAYMENT DATA LOCALLY BEFORE OPENING RAZORPAY (backup)
      await _savePendingEventPayment(orderId, registrationData);

      print('[EventPayment] Saved pending payment data locally');

      // Open Razorpay checkout
      var options = {
        'key': 'rzp_live_lUkgWvIy2IHCWA',
        'amount': (payableAmount * 100).round(),
        'name': widget.eventData['name'] ?? 'Event Registration',
        'description': 'Event Registration: ${widget.eventData['name']} - Total: ₹${payableAmount.toStringAsFixed(2)}',
        'order_id': orderId,
        'prefill': {
          'contact': userPhone,
          'email': userEmail,
        },
        'theme': {
          'color': '#00897B',
        },
      };

      try {
        print('[EventPayment] Opening Razorpay payment...');
        _razorpay.open(options);
      } catch (e) {
        print('[Razorpay] Error opening: $e');
        await _clearPendingEventPayment();
        setState(() => _isProcessingPayment = false);
        _showPremiumSnackBar(
          'Failed to open payment. Please try again.',
          Colors.red,
          Icons.error_rounded,
        );
      }
      
    } catch (e) {
      setState(() => _isProcessingPayment = false);
      _showPremiumSnackBar(
        'Error during registration: ${e.toString()}',
        Colors.red,
        Icons.error_rounded,
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      setState(() => _isProcessingPayment = true);
      
      print('[EventPaymentSuccess] Payment response: ${response.paymentId}');
      
      // ✅ CLEAR PENDING PAYMENT IMMEDIATELY ON SUCCESS
      await _clearPendingEventPayment();

      // Get event details
      final eventPrice = (widget.eventData['price'] ?? 0).toDouble();
      final baseAmount = eventPrice;
      final payableAmount = _totalToCharge(baseAmount);

      // Get event owner account ID
      final eventDoc = await FirebaseFirestore.instance.collection('spot_events').doc(widget.eventId).get();
      final eventData = eventDoc.data()!;
      final ownerId = eventData['ownerId'];

      String? ownerAccountId;
      if (ownerId != null) {
        final ownerDoc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
        if (ownerDoc.exists) {
          ownerAccountId = ownerDoc.data()?['razorpayAccountId'];
        }
      }

      // Confirm registration and write to Firestore with timeout handling
      final HttpsCallable confirmFn = FirebaseFunctions.instance.httpsCallable('confirmEventRegistrationAndWrite');
      
      final confirmResult = await confirmFn({
        'orderId': response.orderId,
        'paymentId': response.paymentId,
        'userId': widget.user!.uid,
        'eventId': widget.eventId,
        'eventName': widget.eventData['name'],
        'ownerId': ownerId,
        // JSON-safe date string for callable payloads
        'eventDate': _toYmdString(widget.eventData['eventDate']),
        'eventTime': widget.eventData['eventTime'],
        'baseAmount': baseAmount,
        'payableAmount': payableAmount,
        'userName': widget.user!.displayName ?? 'User',
        'userEmail': widget.user!.email ?? '',
        'userPhone': widget.user!.phoneNumber ?? '',
        'eventLocation': widget.eventData['location'] ?? '',
        'eventType': widget.eventData['eventType'] ?? '',
        'paymentReference': response.paymentId ?? '',
      }).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Registration confirmation timed out. Please check your booking status or contact support.');
        },
      );

      if (confirmResult.data['ok'] == true) {
        // Send confirmation email with error handling (don't fail if email fails)
        try {
          // Ensure user profile is loaded for email
          await _ensureUserProfileLoaded();
          final emailUserName = _resolveUserName();
          final emailUserEmail = _resolveUserEmail();
          final emailUserPhone = _resolveUserPhone();
          
          final HttpsCallable emailFn = FirebaseFunctions.instance.httpsCallable('sendEventRegistrationConfirmationEmail');
          await emailFn.call({
            'to': emailUserEmail,
            'userName': emailUserName,
            'userEmail': emailUserEmail,
            'userPhone': emailUserPhone,
            'registrationId': confirmResult.data['registrationId'] ?? '',
            'eventName': widget.eventData['name'],
            'eventDate': _toYmdString(widget.eventData['eventDate']), // Convert Timestamp to string for Cloud Function
            'eventTime': widget.eventData['eventTime'],
            'eventLocation': widget.eventData['location'] ?? '',
            'eventType': widget.eventData['eventType'] ?? '',
            'amount': payableAmount,
            'paymentMethod': 'Online',
            'paymentReference': response.paymentId ?? '',
          }).timeout(Duration(seconds: 15));
        } catch (e) {
          // Don't fail the whole process if email fails
          print('[PaidEventEmail] Email notification failed: $e');
          print('[PaidEventEmail] Error details: ${e.toString()}');
        }

        Navigator.pop(context);
        _showPremiumSnackBar(
          'Successfully registered! 🎉',
          Color(0xFF00C853),
          Icons.check_circle_rounded,
        );
      } else {
        setState(() => _isProcessingPayment = false);
        _showPremiumSnackBar(
          'Registration confirmation failed. Please contact support.',
          Colors.red,
          Icons.error_rounded,
        );
      }
    } on TimeoutException catch (e) {
      setState(() => _isProcessingPayment = false);
      _showPremiumSnackBar(
        e.message ?? 'Request timed out. Please check your booking status or contact support.',
        Colors.orange,
        Icons.warning_rounded,
      );
    } catch (e) {
      setState(() => _isProcessingPayment = false);
      _showPremiumSnackBar(
        'Error processing payment: ${e.toString()}',
        Colors.red,
        Icons.error_rounded,
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('[EventPaymentError] Payment failed: ${response.message}');
    print('[EventPaymentError] Code: ${response.code}');
    
    setState(() => _isProcessingPayment = false);
    _showPremiumSnackBar(
      'Payment failed: ${response.message ?? 'Unknown error'}',
      Colors.red,
      Icons.error_rounded,
    );
    // DO NOT clear pending payment - user can retry
    // Payment data is still in SharedPreferences for recovery
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showPremiumSnackBar(
      'External wallet selected: ${response.walletName}',
      Colors.blue,
      Icons.account_balance_wallet_rounded,
    );
  }

  void _showPremiumSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _formatEventDate(dynamic date) {
    if (date == null) return 'TBA';
    try {
      DateTime dateTime = date is Timestamp ? date.toDate() : DateTime.parse(date.toString());
      return DateFormat('EEEE, MMMM dd, yyyy').format(dateTime);
    } catch (e) {
      return date.toString();
    }
  }

  String _formatEventTime(dynamic time) {
    if (time == null) return 'TBA';
    
    try {
      if (time is String) {
        final parts = time.split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);
          
          String period = hour >= 12 ? 'PM' : 'AM';
          hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
          
          return '$hour:${minute.toString().padLeft(2, '0')} $period';
        }
      }
    } catch (e) {
      print('Error formatting time: $e');
    }
    
    return time.toString();
  }
}

class SimilarEventsPage extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> events;
  final void Function(Map<String, dynamic> event) onEventSelected;

  const SimilarEventsPage({
    Key? key,
    required this.title,
    required this.events,
    required this.onEventSelected,
  }) : super(key: key);

  String _formatDate(dynamic value) {
    if (value == null) return 'TBA';
    try {
      DateTime dateTime;
      if (value is Timestamp) {
        dateTime = value.toDate();
      } else if (value is DateTime) {
        dateTime = value;
      } else {
        dateTime = DateTime.parse(value.toString());
      }
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF00897B)),
        title: Text(
          title,
          style: TextStyle(
            color: Color(0xFF00897B),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: events.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_available, size: 48, color: Color(0xFF00897B)),
                    SizedBox(height: 12),
                    Text(
                      'No similar events available at the moment.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.all(20),
              separatorBuilder: (_, __) => SizedBox(height: 16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final data = event['data'] as Map<String, dynamic>;
                final id = event['id'] as String;

                return GestureDetector(
                  onTap: () => onEventSelected(event),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          child: Image.network(
                            data['imageUrl'] ?? 'https://picsum.photos/300/180',
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 180,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFE0F2F1), Color(0xFFB2DFDB)],
                                ),
                              ),
                              child: Center(
                                child: Icon(Icons.event, color: Color(0xFF00897B), size: 40),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFE0F7FA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      data['eventType'] ?? 'Event',
                                      style: TextStyle(
                                        color: Color(0xFF00897B),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Spacer(),
                                  Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(
                                data['name'] ?? 'Event Name',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Color(0xFF00897B)),
                                  SizedBox(width: 6),
                                  Text(
                                    _formatDate(data['eventDate']),
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Color(0xFF00897B)),
                                  SizedBox(width: 6),
                                  Text(
                                    data['eventTime'] ?? 'TBA',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 16, color: Color(0xFF00897B)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      data['location'] ?? 'Location TBD',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(
                                data['description'] ?? 'No description available',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}