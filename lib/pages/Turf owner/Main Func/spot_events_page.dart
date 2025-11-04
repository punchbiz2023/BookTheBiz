import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:ui';

class SpotEventsPage extends StatefulWidget {
  final User? user;

  SpotEventsPage({super.key, this.user});

  @override
  _SpotEventsPageState createState() => _SpotEventsPageState();
}

class _SpotEventsPageState extends State<SpotEventsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  Stream<QuerySnapshot>? _eventsStream;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _setupEventsStream();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupEventsStream() {
    setState(() {
      _eventsStream = FirebaseFirestore.instance
          .collection('spot_events')
          .where('ownerId', isEqualTo: widget.user?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: const [
            Text(
              "Spot Events",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 24,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.event_outlined, color: Colors.white),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () => _showCreateEventDialog(),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.teal.shade700.withOpacity(0.85),
                Colors.teal.shade500.withOpacity(0.85),
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.teal.shade50,
                    Colors.grey.shade100,
                  ],
                ),
              ),
            ),
            // Content
            Column(
              children: [
                // Header Section with Glassmorphism
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.fromLTRB(16, 100, 16, 20),
                  padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.1),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Column(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                            ),
                            child: Icon(
                              Icons.event_outlined,
                              color: Colors.teal.shade700,
                              size: 36,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Manage Your Events',
                            style: TextStyle(
                              color: Colors.teal.shade800,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Create and manage public spot events for your turf',
                            style: TextStyle(
                              color: Colors.teal.shade700,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Search Bar with Glassmorphism
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withOpacity(0.7),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value.toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search events...',
                            prefixIcon: Icon(Icons.search, color: Colors.teal.shade600),
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
                    ),
                  ),
                ),
                SizedBox(height: 20),
                
                // Events List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _eventsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade600),
                              ),
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      final events = snapshot.data!.docs.where((doc) {
                        if (searchQuery.isEmpty) return true;
                        final eventData = doc.data() as Map<String, dynamic>;
                        final eventName = (eventData['name']?.toString() ?? '').toLowerCase();
                        final eventDescription = (eventData['description']?.toString() ?? '').toLowerCase();
                        final eventLocation = (eventData['location']?.toString() ?? '').toLowerCase();
                        return eventName.contains(searchQuery) || 
                               eventDescription.contains(searchQuery) ||
                               eventLocation.contains(searchQuery);
                      }).toList();

                      if (events.isEmpty) {
                        return _buildNoSearchResults();
                      }

                      return ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final eventData = events[index].data() as Map<String, dynamic>;
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _buildEventCard(eventData, events[index].id),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 140,
            width: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.7),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(70),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Icon(
                  Icons.event_outlined,
                  size: 70,
                  color: Colors.teal.shade400,
                ),
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Events Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.teal.shade800,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Create your first spot event to attract more customers',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          SizedBox(height: 30),
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            child: ElevatedButton.icon(
              onPressed: () => _showCreateEventDialog(),
              icon: Icon(Icons.add_circle_outline, size: 20),
              label: Text("Create Event"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600.withOpacity(0.9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                shadowColor: Colors.teal.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.7),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Icon(
                  Icons.search_off,
                  size: 50,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No events found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Try different search terms',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> eventData, String eventId) {
    String status = eventData['status'] ?? 'pending';
    bool isBookingOpen = eventData['isBookingOpen'] ?? true;
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green.shade600;
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      case 'rejected':
        statusColor = Colors.red.shade600;
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      case 'pending':
      default:
        statusColor = Colors.orange.shade600;
        statusIcon = Icons.pending;
        statusText = 'Pending Review';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.7),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showEventDetails(eventData, eventId),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Hero(
                          tag: 'event-image-$eventId',
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white.withOpacity(0.5),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                eventData['imageUrl'] ?? 'https://via.placeholder.com/80',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[200],
                                  child: Icon(Icons.event_outlined, size: 40, color: Colors.grey[400]),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eventData['name'] ?? 'Unnamed Event',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      eventData['location'] ?? 'No location',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                eventData['description'] ?? 'No description available',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    statusIcon,
                                    color: statusColor,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (status.toLowerCase() == 'approved') ...[
                                    SizedBox(width: 12),
                                    Icon(
                                      isBookingOpen ? Icons.lock_open : Icons.lock,
                                      color: isBookingOpen ? Colors.green.shade600 : Colors.red.shade600,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      isBookingOpen ? 'Bookings Open' : 'Bookings Closed',
                                      style: TextStyle(
                                        color: isBookingOpen ? Colors.green.shade600 : Colors.red.shade600,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _showEditEventDialog(eventData, eventId);
                                break;
                              case 'delete':
                                _showDeleteConfirmation(eventId);
                                break;
                              case 'view':
                                _showEventDetails(eventData, eventId);
                                break;
                              case 'toggle_booking':
                                _toggleBookingStatus(eventId, !isBookingOpen);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility, color: Colors.teal.shade600),
                                  SizedBox(width: 8),
                                  Text('View Details'),
                                ],
                              ),
                            ),
                            if (status.toLowerCase() == 'approved')
                              PopupMenuItem(
                                value: 'toggle_booking',
                                child: Row(
                                  children: [
                                    Icon(
                                      isBookingOpen ? Icons.lock : Icons.lock_open,
                                      color: isBookingOpen ? Colors.red.shade600 : Colors.green.shade600,
                                    ),
                                    SizedBox(width: 8),
                                    Text(isBookingOpen ? 'Close Bookings' : 'Open Bookings'),
                                  ],
                                ),
                              ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.blue.shade600),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red.shade600),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                          child: Icon(
                            Icons.more_vert,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    if (status.toLowerCase() == 'rejected' && eventData['rejectionReason'] != null)
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        margin: EdgeInsets.only(top: 12),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.red.shade700, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Rejection Reason:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                eventData['rejectionReason'],
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 12,
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
      ),
    );
  }

  void _showCreateEventDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateEventDialog(
        user: widget.user,
        onEventCreated: () {
          _setupEventsStream();
        },
      ),
    );
  }

  void _showEditEventDialog(Map<String, dynamic> eventData, String eventId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateEventDialog(
        user: widget.user,
        eventData: eventData,
        eventId: eventId,
        isEditing: true,
        onEventCreated: () {
          _setupEventsStream();
        },
      ),
    );
  }

  void _showEventDetails(Map<String, dynamic> eventData, String eventId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventDetailsDialog(
        eventData: eventData,
        eventId: eventId,
        onBookingToggle: (bool isOpen) {
          _toggleBookingStatus(eventId, isOpen);
        },
      ),
    );
  }

  void _toggleBookingStatus(String eventId, bool isOpen) async {
    try {
      await FirebaseFirestore.instance
          .collection('spot_events')
          .doc(eventId)
          .update({'isBookingOpen': isOpen});
      
      Fluttertoast.showToast(
        msg: isOpen ? 'Bookings opened successfully' : 'Bookings closed successfully',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error updating booking status: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _showDeleteConfirmation(String eventId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.warning, color: Colors.red, size: 28),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Delete Event',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  'Are you sure you want to delete this event? This action cannot be undone.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _deleteEvent(eventId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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

  Future<void> _deleteEvent(String eventId) async {
    try {
      await FirebaseFirestore.instance
          .collection('spot_events')
          .doc(eventId)
          .delete();
      
      Fluttertoast.showToast(
        msg: 'Event deleted successfully',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error deleting event: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
}

class CreateEventDialog extends StatefulWidget {
  final User? user;
  final Map<String, dynamic>? eventData;
  final String? eventId;
  final bool isEditing;
  final VoidCallback onEventCreated;

  CreateEventDialog({
    super.key,
    required this.user,
    this.eventData,
    this.eventId,
    this.isEditing = false,
    required this.onEventCreated,
  });

  @override
  _CreateEventDialogState createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<CreateEventDialog> 
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  
  String _selectedEventType = 'Marathon';
  String _selectedPaymentType = 'Free';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  File? _selectedImage;
  bool _isLoading = false;
  
  late AnimationController _sheetController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _sheetAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final List<String> _eventTypes = [
    'Marathon',
    'Hackathon',
    'Marriage Function',
    'Ceremony',
    'Sports Tournament',
    'Cultural Event',
    'Workshop',
    'Other'
  ];

  final List<String> _paymentTypes = [
    'Free',
    'Paid',
    'On-Spot Payment'
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _sheetController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    
    _scaleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _sheetAnimation = CurvedAnimation(
      parent: _sheetController,
      curve: Curves.easeOutQuart,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );
    
    _sheetController.forward();
    _fadeController.forward();
    _scaleController.forward();
    
    if (widget.isEditing && widget.eventData != null) {
      _nameController.text = widget.eventData!['name'] ?? '';
      _descriptionController.text = widget.eventData!['description'] ?? '';
      _contentController.text = widget.eventData!['content'] ?? '';
      _locationController.text = widget.eventData!['location'] ?? '';
      _priceController.text = widget.eventData!['price']?.toString() ?? '';
      _maxParticipantsController.text = widget.eventData!['maxParticipants']?.toString() ?? '';
      _selectedEventType = widget.eventData!['eventType'] ?? 'Marathon';
      _selectedPaymentType = widget.eventData!['paymentType'] ?? 'Free';
      
      if (widget.eventData!['eventDate'] != null) {
        final timestamp = widget.eventData!['eventDate'] as Timestamp;
        _selectedDate = timestamp.toDate();
      }
      
      if (widget.eventData!['eventTime'] != null) {
        final timeString = widget.eventData!['eventTime'] as String;
        final timeParts = timeString.split(':');
        _selectedTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      }
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _maxParticipantsController.dispose();
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
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                margin: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: Offset(0, 15),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated handle
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
                        
                        // Header with glass effect
                        Container(
                          padding: EdgeInsets.fromLTRB(24, 8, 24, 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.teal.shade50.withOpacity(0.7),
                                Colors.white.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.teal.shade100.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: Duration(milliseconds: 500),
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.teal.shade600.withOpacity(0.2),
                                      Colors.teal.shade400.withOpacity(0.1),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.teal.shade600.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  widget.isEditing ? Icons.edit : Icons.add_circle_outline,
                                  color: Colors.teal.shade700,
                                  size: 28,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  widget.isEditing ? 'Edit Event' : 'Create New Event',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Form
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Event Image
                                  _buildImagePicker(),
                                  SizedBox(height: 20),
                                  
                                  // Event Name
                                  _buildRequiredTextField(
                                    controller: _nameController,
                                    label: 'Event Name',
                                    hint: 'Enter event name',
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter event name';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  
                                  // Location
                                  _buildRequiredTextField(
                                    controller: _locationController,
                                    label: 'Location',
                                    hint: 'Enter event location',
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter event location';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  
                                  // Event Type
                                  _buildRequiredDropdown(
                                    label: 'Event Type',
                                    value: _selectedEventType,
                                    items: _eventTypes,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedEventType = value!;
                                      });
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  
                                  // Description
                                  _buildRequiredTextField(
                                    controller: _descriptionController,
                                    label: 'Description',
                                    hint: 'Enter event description',
                                    maxLines: 3,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter event description';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  
                                  // Content
                                  _buildRequiredTextField(
                                    controller: _contentController,
                                    label: 'Event Content',
                                    hint: 'Enter detailed event content and agenda',
                                    maxLines: 4,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter event content';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  
                                  // Payment Type
                                  _buildRequiredDropdown(
                                    label: 'Payment Type',
                                    value: _selectedPaymentType,
                                    items: _paymentTypes,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedPaymentType = value!;
                                      });
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  
                                  // Price (if paid)
                                  if (_selectedPaymentType != 'Free')
                                    Column(
                                      children: [
                                        _buildRequiredTextField(
                                          controller: _priceController,
                                          label: 'Price (₹)',
                                          hint: 'Enter event price',
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          validator: (value) {
                                            if (_selectedPaymentType != 'Free' && (value == null || value.trim().isEmpty)) {
                                              return 'Please enter event price';
                                            }
                                            if (value != null && value.isNotEmpty) {
                                              final price = double.tryParse(value);
                                              if (price == null || price <= 0) {
                                                return 'Please enter a valid price';
                                              }
                                            }
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: 16),
                                      ],
                                    ),
                                  
                                  // Max Participants
                                  _buildRequiredTextField(
                                    controller: _maxParticipantsController,
                                    label: 'Max Participants',
                                    hint: 'Enter maximum number of participants',
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter max participants';
                                      }
                                      final participants = int.tryParse(value);
                                      if (participants == null || participants <= 0) {
                                        return 'Please enter a valid number greater than 0';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  
                                  // Event Date
                                  _buildRequiredDatePicker(),
                                  SizedBox(height: 16),
                                  
                                  // Event Time
                                  _buildRequiredTimePicker(),
                                  SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Footer with glass effect
                        Container(
                          padding: EdgeInsets.all(24),
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
                              bottomLeft: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey.shade200.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _saveEvent,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade600,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                      shadowColor: Colors.teal.withOpacity(0.3),
                                    ),
                                    child: _isLoading
                                        ? SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Text(
                                            widget.isEditing ? 'Update Event' : 'Create Event',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Event Image',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey.shade100.withOpacity(0.8),
                  Colors.white.withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade300.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : widget.isEditing && widget.eventData != null && widget.eventData!['imageUrl'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          widget.eventData!['imageUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                        ),
                      )
                    : _buildImagePlaceholder(),
          ),
        ),
        if (!_hasImage())
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Event image is required',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  bool _hasImage() {
    return _selectedImage != null || 
           (widget.isEditing && widget.eventData != null && widget.eventData!['imageUrl'] != null);
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 40,
          color: Colors.grey.shade400,
        ),
        SizedBox(height: 8),
        Text(
          'Tap to add image',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildRequiredTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.teal.shade600),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.7),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildRequiredDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select an option';
            }
            return null;
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.teal.shade600),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.7),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRequiredDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Event Date',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.8),
                  Colors.grey.shade50.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedDate == null ? Colors.red.shade300 : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.teal.shade600),
                SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Select event date',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedDate != null ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedDate == null)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Please select event date',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRequiredTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Event Time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _selectTime,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.8),
                  Colors.grey.shade50.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedTime == null ? Colors.red.shade300 : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.teal.shade600),
                SizedBox(width: 12),
                Text(
                  _selectedTime != null
                      ? _selectedTime!.format(context)
                      : 'Select event time',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedTime != null ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedTime == null)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Please select event time',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasImage()) {
      Fluttertoast.showToast(
        msg: 'Please select an event image',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (_selectedDate == null) {
      Fluttertoast.showToast(
        msg: 'Please select event date',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (_selectedTime == null) {
      Fluttertoast.showToast(
        msg: 'Please select event time',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl;
      
      // Upload image if selected
      if (_selectedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('spot_events')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        
        await storageRef.putFile(_selectedImage!);
        imageUrl = await storageRef.getDownloadURL();
      } else if (widget.isEditing && widget.eventData != null && widget.eventData!['imageUrl'] != null) {
        imageUrl = widget.eventData!['imageUrl'];
      }

      // Prepare event data
      final eventData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'content': _contentController.text.trim(),
        'location': _locationController.text.trim(),
        'eventType': _selectedEventType,
        'paymentType': _selectedPaymentType,
        'price': _selectedPaymentType != 'Free' ? double.tryParse(_priceController.text) ?? 0 : 0,
        'maxParticipants': int.tryParse(_maxParticipantsController.text) ?? 0,
        'eventDate': Timestamp.fromDate(_selectedDate!),
        'eventTime': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
        'imageUrl': imageUrl,
        'ownerId': widget.user?.uid,
        'status': 'pending', // Always set to pending for new and edited events
        'isBookingOpen': widget.isEditing ? widget.eventData!['isBookingOpen'] ?? true : true,
        'createdAt': widget.isEditing ? widget.eventData!['createdAt'] : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.isEditing && widget.eventId != null) {
        // Update existing event
        await FirebaseFirestore.instance
            .collection('spot_events')
            .doc(widget.eventId)
            .update(eventData);
        
        Fluttertoast.showToast(
          msg: 'Event updated successfully and sent for re-approval',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        // Create new event
        await FirebaseFirestore.instance
            .collection('spot_events')
            .add(eventData);
        
        Fluttertoast.showToast(
          msg: 'Event created successfully and sent for approval',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      }

      Navigator.pop(context);
      widget.onEventCreated();
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error saving event: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class EventDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> eventData;
  final String? eventId;
  final Function(bool)? onBookingToggle;

  EventDetailsDialog({
    super.key, 
    required this.eventData,
    this.eventId,
    this.onBookingToggle,
  });

  @override
  _EventDetailsDialogState createState() => _EventDetailsDialogState();
}

class _EventDetailsDialogState extends State<EventDetailsDialog> 
    with TickerProviderStateMixin {
  late AnimationController _sheetController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _sheetAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool isBookingOpen = true;

  @override
  void initState() {
    super.initState();
    isBookingOpen = widget.eventData['isBookingOpen'] ?? true;
    
    _sheetController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    
    _scaleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _sheetAnimation = CurvedAnimation(
      parent: _sheetController,
      curve: Curves.easeOutQuart,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String status = widget.eventData['status'] ?? 'pending';
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green.shade600;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Approved';
        break;
      case 'rejected':
        statusColor = Colors.red.shade600;
        statusIcon = Icons.cancel_outlined;
        statusText = 'Rejected';
        break;
      case 'pending':
      default:
        statusColor = Colors.orange.shade600;
        statusIcon = Icons.schedule_outlined;
        statusText = 'Pending Review';
    }

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
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                margin: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: Offset(0, 15),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated handle bar
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
                        
                        // Header with glass effect
                        Container(
                          padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.teal.shade50.withOpacity(0.7),
                                Colors.white.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.teal.shade100.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: Duration(milliseconds: 500),
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.teal.shade600.withOpacity(0.2),
                                      Colors.teal.shade400.withOpacity(0.1),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.teal.shade600.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.event_outlined,
                                  color: Colors.teal.shade700,
                                  size: 22,
                                ),
                              ),
                              SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  widget.eventData['name'] ?? 'Event Details',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                                // Event Image with glass overlay
                                if (widget.eventData['imageUrl'] != null)
                                  AnimatedContainer(
                                    duration: Duration(milliseconds: 500),
                                    width: double.infinity,
                                    height: 180,
                                    margin: EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 20,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Stack(
                                        children: [
                                          Image.network(
                                            widget.eventData['imageUrl'],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: Colors.grey.shade100,
                                              child: Icon(
                                                Icons.event_outlined, 
                                                size: 48, 
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                          // Glass overlay
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black.withOpacity(0.4),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                
                                // Status and Booking Status with animated cards
                                AnimatedContainer(
                                  duration: Duration(milliseconds: 400),
                                  margin: EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: AnimatedContainer(
                                          duration: Duration(milliseconds: 300),
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                statusColor.withOpacity(0.1),
                                                statusColor.withOpacity(0.05),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: statusColor.withOpacity(0.3),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: statusColor.withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AnimatedSwitcher(
                                                duration: Duration(milliseconds: 300),
                                                child: Icon(
                                                  statusIcon,
                                                  color: statusColor,
                                                  size: 16,
                                                  key: ValueKey(statusText),
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                statusText,
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (status.toLowerCase() == 'approved') ...[
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: InkWell(
                                            onTap: widget.onBookingToggle != null
                                                ? () {
                                                    setState(() {
                                                      isBookingOpen = !isBookingOpen;
                                                    });
                                                    widget.onBookingToggle!(isBookingOpen);
                                                  }
                                                : null,
                                            borderRadius: BorderRadius.circular(12),
                                            child: AnimatedContainer(
                                              duration: Duration(milliseconds: 300),
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: isBookingOpen 
                                                      ? [
                                                          Colors.green.shade50.withOpacity(0.7),
                                                          Colors.green.shade100.withOpacity(0.3),
                                                        ]
                                                      : [
                                                          Colors.red.shade50.withOpacity(0.7),
                                                          Colors.red.shade100.withOpacity(0.3),
                                                        ],
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isBookingOpen 
                                                      ? Colors.green.shade300.withOpacity(0.4) 
                                                      : Colors.red.shade300.withOpacity(0.4),
                                                  width: 1,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: isBookingOpen 
                                                        ? Colors.green.shade200.withOpacity(0.3) 
                                                        : Colors.red.shade200.withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  AnimatedSwitcher(
                                                    duration: Duration(milliseconds: 300),
                                                    child: Icon(
                                                      isBookingOpen ? Icons.lock_open_outlined : Icons.lock_outline,
                                                      color: isBookingOpen ? Colors.green.shade600 : Colors.red.shade600,
                                                      size: 16,
                                                      key: ValueKey(isBookingOpen),
                                                    ),
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    isBookingOpen ? 'Open' : 'Closed',
                                                    style: TextStyle(
                                                      color: isBookingOpen ? Colors.green.shade600 : Colors.red.shade600,
                                                      fontWeight: FontWeight.w500,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                
                                // Event Details Grid with glass cards
                                Container(
                                  margin: EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    children: [
                                      _buildDetailRow(Icons.category, 'Type', widget.eventData['eventType'] ?? 'N/A'),
                                      _buildDetailRow(Icons.location_on_outlined, 'Location', widget.eventData['location'] ?? 'N/A'),
                                      _buildDetailRow(Icons.payment_outlined, 'Payment', widget.eventData['paymentType'] ?? 'N/A'),
                                      if (widget.eventData['price'] != null && widget.eventData['price'] > 0)
                                        _buildDetailRow(Icons.attach_money_outlined, 'Price', '₹${widget.eventData['price']}'),
                                      _buildDetailRow(Icons.group_outlined, 'Participants', widget.eventData['maxParticipants']?.toString() ?? 'N/A'),
                                      if (widget.eventData['eventDate'] != null)
                                        _buildDetailRow(Icons.calendar_today_outlined, 'Date', _formatDate(widget.eventData['eventDate'])),
                                      if (widget.eventData['eventTime'] != null)
                                        _buildDetailRow(Icons.access_time_outlined, 'Time', widget.eventData['eventTime']),
                                    ],
                                  ),
                                ),
                                
                                // Description with glass card
                                if (widget.eventData['description'] != null && widget.eventData['description'].isNotEmpty)
                                  AnimatedContainer(
                                    duration: Duration(milliseconds: 500),
                                    margin: EdgeInsets.only(bottom: 16),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.grey.shade50.withOpacity(0.8),
                                          Colors.white.withOpacity(0.4),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade200.withOpacity(0.4),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.08),
                                          blurRadius: 15,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Colors.teal.shade100.withOpacity(0.7),
                                                    Colors.teal.shade200.withOpacity(0.3),
                                                  ],
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.description_outlined,
                                                color: Colors.teal.shade700,
                                                size: 16,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Description',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          widget.eventData['description'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                // Content with glass card
                                if (widget.eventData['content'] != null && widget.eventData['content'].isNotEmpty)
                                  AnimatedContainer(
                                    duration: Duration(milliseconds: 500),
                                    margin: EdgeInsets.only(bottom: 16),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.grey.shade50.withOpacity(0.8),
                                          Colors.white.withOpacity(0.4),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade200.withOpacity(0.4),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.08),
                                          blurRadius: 15,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Colors.teal.shade100.withOpacity(0.7),
                                                    Colors.teal.shade200.withOpacity(0.3),
                                                  ],
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.article_outlined,
                                                color: Colors.teal.shade700,
                                                size: 16,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Details',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          widget.eventData['content'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                // Rejection Reason with glass card
                                if (status.toLowerCase() == 'rejected' && widget.eventData['rejectionReason'] != null)
                                  AnimatedContainer(
                                    duration: Duration(milliseconds: 500),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.red.shade50.withOpacity(0.8),
                                          Colors.red.shade100.withOpacity(0.3),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.red.shade200.withOpacity(0.4),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.1),
                                          blurRadius: 15,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Colors.red.shade100.withOpacity(0.7),
                                                    Colors.red.shade200.withOpacity(0.3),
                                                  ],
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.info_outline,
                                                color: Colors.red.shade700,
                                                size: 16,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Rejection Reason',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.red.shade700,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          widget.eventData['rejectionReason'],
                                          style: TextStyle(
                                            color: Colors.red.shade800,
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Footer with glass effect
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
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
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
                                    borderRadius: BorderRadius.circular(12),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 12),
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
                  Colors.teal.shade50.withOpacity(0.8),
                  Colors.teal.shade100.withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.teal.shade200.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.teal.shade600,
              size: 18,
            ),
          ),
          SizedBox(width: 12),
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
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
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

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return date.toString();
  }
}