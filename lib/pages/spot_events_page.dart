import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart';

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
            if (eventDate != null) {
              DateTime eventDateTime = eventDate is Timestamp 
                  ? eventDate.toDate() 
                  : DateTime.parse(eventDate.toString());
              
              if (selectedFilter == 'Upcoming' && eventDateTime.isBefore(now)) return false;
              if (selectedFilter == 'Past' && eventDateTime.isAfter(now)) return false;
            }
          }
          return true;
        }).toList();

        if (filteredDocs.isEmpty) return _buildNoResultsState();

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final eventData = filteredDocs[index];
            final data = eventData.data() as Map<String, dynamic>;
            
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
                child: _buildEventCard(data, eventData.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> eventData, String eventId) {
    final eventDate = eventData['eventDate'];
    DateTime? eventDateTime;
    bool isUpcoming = true;
    
    if (eventDate != null) {
      eventDateTime = eventDate is Timestamp ? eventDate.toDate() : DateTime.parse(eventDate.toString());
      isUpcoming = eventDateTime.isAfter(DateTime.now());
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
          onTap: () => _showEventDetailsBottomSheet(eventData, eventId),
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
                          onTap: () => _showEventDetailsBottomSheet(eventData, eventId),
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

  void _showEventDetailsBottomSheet(Map<String, dynamic> eventData, String eventId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PremiumEventDetailsBottomSheet(
        eventData: eventData,
        eventId: eventId,
        user: widget.user,
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
}

class PremiumEventDetailsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> eventData;
  final String eventId;
  final User? user;

  const PremiumEventDetailsBottomSheet({
    Key? key,
    required this.eventData,
    required this.eventId,
    required this.user,
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scaleController.dispose();
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
                          _isLoading
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
                                      onTap: _isRegistered ? null : () => _registerForEvent(),
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
                                              _isRegistered ? 'Already Registered' : 'Register Now',
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

    try {
      await FirebaseFirestore.instance.collection('event_registrations').add({
        'eventId': widget.eventId,
        'eventName': widget.eventData['name'],
        'eventDate': widget.eventData['eventDate'],
        'eventTime': widget.eventData['eventTime'],
        'userId': widget.user!.uid,
        'userName': widget.user!.displayName ?? 'User',
        'userEmail': widget.user!.email,
        'paymentType': widget.eventData['price'] != null && widget.eventData['price'] > 0 ? 'Paid' : 'Free',
        'price': widget.eventData['price'] ?? 0,
        'status': 'registered',
        'registeredAt': Timestamp.now(),
      });

      Navigator.pop(context);
      _showPremiumSnackBar(
        'Successfully registered! 🎉',
        Color(0xFF00C853),
        Icons.check_circle_rounded,
      );
    } catch (e) {
      _showPremiumSnackBar(
        'Registration failed: ${e.toString()}',
        Colors.red,
        Icons.error_rounded,
      );
    }
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