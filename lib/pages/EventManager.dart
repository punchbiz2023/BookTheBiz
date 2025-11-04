import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

// Glassmorphic Container Widget
class GlassmorphicContainer extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final BoxBorder? border;
  final double? blur;
  final double? opacity;

  const GlassmorphicContainer({
    Key? key,
    this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.border,
    this.blur = 10.0,
    this.opacity = 0.2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(opacity!),
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: border ?? Border.all(
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
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur!, sigmaY: blur!),
          child: child,
        ),
      ),
    );
  }
}

// Glassmorphic Card Widget
class GlassmorphicCard extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final BoxBorder? border;
  final double? blur;
  final double? opacity;

  const GlassmorphicCard({
    Key? key,
    this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.border,
    this.blur = 15.0,
    this.opacity = 0.15,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(opacity!),
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        border: border ?? Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 3,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            spreadRadius: 1,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur!, sigmaY: blur!),
          child: child,
        ),
      ),
    );
  }
}

// Glassmorphic Button Widget
class GlassmorphicButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String? label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? iconColor;
  final String? tooltip;
  final double? width;

  const GlassmorphicButton({
    Key? key,
    required this.onPressed,
    this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.iconColor,
    this.tooltip,
    this.width,
  }) : super(key: key);

  @override
  _GlassmorphicButtonState createState() => _GlassmorphicButtonState();
}

class _GlassmorphicButtonState extends State<GlassmorphicButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  void _onTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    bool isIconOnly = widget.label == null && widget.icon != null;
    bool hasBoth = widget.label != null && widget.icon != null;
    
    return Tooltip(
      message: widget.tooltip ?? '',
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: widget.width,
                padding: isIconOnly 
                    ? EdgeInsets.all(10) 
                    : EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? Colors.teal.shade600,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _isPressed
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null)
                      Icon(
                        widget.icon,
                        color: widget.iconColor ?? Colors.white,
                        size: 18,
                      ),
                    if (hasBoth) SizedBox(width: 8),
                    if (widget.label != null)
                      Flexible(
                        child: Text(
                          widget.label!,
                          style: TextStyle(
                            color: widget.foregroundColor ?? Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Glassmorphic Bottom Sheet Widget
class GlassmorphicBottomSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget child;

  const GlassmorphicBottomSheet({
    Key? key,
    required this.title,
    required this.icon,
    this.iconColor,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 5,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (iconColor ?? Colors.teal.shade600).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor ?? Colors.teal.shade600,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                color: Colors.grey.shade300,
                height: 1,
                indent: 20,
                endIndent: 20,
              ),
              Flexible(
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Glassmorphic Image Widget with animation
class GlassmorphicImage extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  const GlassmorphicImage({
    Key? key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius,
    this.placeholder,
  }) : super(key: key);

  @override
  _GlassmorphicImageState createState() => _GlassmorphicImageState();
}

class _GlassmorphicImageState extends State<GlassmorphicImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    // Start the animation after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            ),
            child: _isLoading
                ? (widget.placeholder ??
                    Center(
                      child: Icon(
                        Icons.event_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                    ))
                : null,
          ),
          if (!_hasError)
            FadeTransition(
              opacity: _fadeAnimation,
              child: Image.network(
                widget.imageUrl,
                width: widget.width,
                height: widget.height,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (frame != null && _isLoading) {
                    // Use a post-frame callback to avoid calling setState during build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    });
                  }
                  return child;
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return SizedBox.shrink();
                },
                errorBuilder: (context, error, stackTrace) {
                  // Use a post-frame callback to avoid calling setState during build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_hasError) {
                      setState(() {
                        _isLoading = false;
                        _hasError = true;
                      });
                    }
                  });
                  return SizedBox.shrink();
                },
              ),
            ),
          if (_hasError)
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.event_outlined,
                size: 40,
                color: Colors.grey.shade400,
              ),
            ),
        ],
      ),
    );
  }
}

class EventManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Build event list with StreamBuilder for real-time updates
  Widget buildEventList({required bool showPending, required String eventSearchQuery, required DateTime? eventFilterDate, required BuildContext context}) {
    Query query = _firestore.collection('spot_events');
    
    if (showPending) {
      query = query.where('status', isEqualTo: 'pending');
    } else {
      query = query.where('status', isEqualTo: 'approved');
    }
    
    // Calculate fixed height for the glass container (50% of screen height)
    double fixedHeight = MediaQuery.of(context).size.height * 0.5;
    
    return GlassmorphicContainer(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: fixedHeight,
        child: StreamBuilder<QuerySnapshot>(
          stream: query.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.teal.shade600,
                        backgroundColor: Colors.teal.shade100,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Loading Events...',
                      style: TextStyle(
                        fontSize: 18, 
                        color: Colors.teal.shade700, 
                        fontWeight: FontWeight.w600,
                      ),
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
                    Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
                    SizedBox(height: 20),
                    Text(
                      'Error loading events',
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.w600, 
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Please try again later.',
                      style: TextStyle(
                        fontSize: 16, 
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      showPending ? Icons.pending_actions : Icons.event_available,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 20),
                    Text(
                      showPending ? 'No Pending Events' : 'No Approved Events',
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.w600, 
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      showPending 
                        ? 'All events have been reviewed.'
                        : 'No events have been approved yet.',
                      style: TextStyle(
                        fontSize: 16, 
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Filter events based on search query and date filter
            List<QueryDocumentSnapshot> filteredEvents = snapshot.data!.docs.where((doc) {
              final eventData = doc.data() as Map<String, dynamic>;
              
              // Search filter
              if (eventSearchQuery.isNotEmpty) {
                final eventName = (eventData['name'] ?? '').toString().toLowerCase();
                final eventDescription = (eventData['description'] ?? '').toString().toLowerCase();
                final eventType = (eventData['eventType'] ?? '').toString().toLowerCase();
                
                if (!eventName.contains(eventSearchQuery) && 
                    !eventDescription.contains(eventSearchQuery) &&
                    !eventType.contains(eventSearchQuery)) {
                  return false;
                }
              }
              
              // Date filter
              if (eventFilterDate != null) {
                final eventDate = eventData['eventDate'] as Timestamp?;
                if (eventDate != null) {
                  final eventDateTime = eventDate.toDate();
                  if (eventDateTime.year != eventFilterDate.year ||
                      eventDateTime.month != eventFilterDate.month ||
                      eventDateTime.day != eventFilterDate.day) {
                    return false;
                  }
                }
              }
              
              return true;
            }).toList();

            if (filteredEvents.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
                    SizedBox(height: 20),
                    Text(
                      'No events found',
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.w600, 
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Try adjusting your search criteria.',
                      style: TextStyle(
                        fontSize: 16, 
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: filteredEvents.length,
              itemBuilder: (context, index) {
                final eventDoc = filteredEvents[index];
                final eventData = eventDoc.data() as Map<String, dynamic>;
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: buildEventCard(eventData, eventDoc.id, showPending, context),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Build individual event card
  Widget buildEventCard(Map<String, dynamic> eventData, String eventId, bool showPending, BuildContext context) {
    String status = eventData['status'] ?? 'pending';
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
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassmorphicCard(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event image centered in first row
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GlassmorphicImage(
                      imageUrl: eventData['imageUrl'] ?? 'https://via.placeholder.com/200',
                      width: double.infinity,
                      height: 180,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Event title and description
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event title with enhanced styling
                  Text(
                    eventData['name'] ?? 'Unnamed Event',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.grey.shade900,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 8),
                  // Event description
                  Text(
                    eventData['description'] ?? 'No description available',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 16),
                  
                  // Status and event type row with proper wrapping
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Status badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusIcon,
                              color: statusColor,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Event type badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Text(
                          eventData['eventType'] ?? 'N/A',
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      // Payment type badge
                      if (eventData['paymentType'] != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            eventData['paymentType'] ?? 'N/A',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              SizedBox(height: 20),
              
              // Divider for visual separation
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.grey.shade300, Colors.transparent],
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Action buttons section
              if (showPending) ...[
                // Approve/Reject buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        child: GlassmorphicButton(
                          onPressed: () => approveEvent(eventId),
                          icon: Icons.check_rounded,
                          label: 'Approve',
                          backgroundColor: Colors.green.shade600,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        child: GlassmorphicButton(
                          onPressed: () => showEventRejectDialog(eventId, context),
                          icon: Icons.close_rounded,
                          label: 'Reject',
                          backgroundColor: Colors.red.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              
              // View Details button
              Container(
                height: 48,
                child: GlassmorphicButton(
                  onPressed: () => showEventDetails(eventData, eventId, context),
                  icon: Icons.visibility_rounded,
                  label: 'View Full Details',
                  backgroundColor: Colors.teal.shade600,
                  width: double.infinity,
                ),
              ),
              
              // Rejection reason section
              if (status.toLowerCase() == 'rejected' && eventData['rejectionReason'] != null) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200.withOpacity(0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.info_outline,
                              color: Colors.red.shade700,
                              size: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rejection Reason',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                                fontSize: 14,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          eventData['rejectionReason'],
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.left,
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
    );
  }

  // Approve event
  Future<void> approveEvent(String eventId) async {
    try {
      await _firestore.collection('spot_events').doc(eventId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUser?.uid,
      });
      
      Fluttertoast.showToast(
        msg: 'Event approved successfully',
        backgroundColor: Colors.green.shade600,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error approving event: $e',
        backgroundColor: Colors.red.shade600,
        textColor: Colors.white,
      );
    }
  }

  // Show event details dialog
  void showEventDetails(Map<String, dynamic> eventData, String eventId, BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassmorphicBottomSheet(
        title: 'Event Details',
        icon: Icons.event_outlined,
        iconColor: Colors.teal.shade600,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Image
                if (eventData['imageUrl'] != null) ...[
                  Center(
                    child: GlassmorphicImage(
                      imageUrl: eventData['imageUrl'],
                      width: double.infinity,
                      height: 200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
                
                // Event Name
                buildDetailRow('Event Name', eventData['name'] ?? 'N/A'),
                
                // Event Type
                buildDetailRow('Event Type', eventData['eventType'] ?? 'N/A'),
                
                // Payment Type
                buildDetailRow('Payment Type', eventData['paymentType'] ?? 'N/A'),
                
                // Price (if applicable)
                if (eventData['paymentType'] != 'Free' && eventData['price'] != null)
                  buildDetailRow('Price', '₹${eventData['price']}'),
                
                // Max Participants
                if (eventData['maxParticipants'] != null)
                  buildDetailRow('Max Participants', '${eventData['maxParticipants']}'),
                
                // Event Date
                if (eventData['eventDate'] != null)
                  buildDetailRow('Event Date', formatEventDate(eventData['eventDate'])),
                
                // Event Time
                if (eventData['eventTime'] != null)
                  buildDetailRow('Event Time', eventData['eventTime']),
                
                // Owner Details
                SizedBox(height: 16),
                Text(
                  'Owner Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade700,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('users').doc(eventData['ownerId']).get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.teal.shade600,
                          ),
                        ),
                      );
                    }
                    
                    if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
                      return GlassmorphicContainer(
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade400),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Owner information not available',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                    final ownerName = userData['name'] ?? 'Unknown';
                    final ownerEmail = userData['email'] ?? 'No email';
                    final ownerMobile = userData['mobile'] ?? 'No mobile';
                    final ownerImage = userData['imageUrl'];
                    
                    return GlassmorphicContainer(
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ownerImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: Image.network(
                                      ownerImage,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.person, size: 24, color: Colors.grey.shade400),
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.person, size: 24, color: Colors.teal.shade600),
                                  ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ownerName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.email, size: 14, color: Colors.grey.shade500),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          ownerEmail,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 14, color: Colors.grey.shade500),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          ownerMobile,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
                    );
                  },
                ),
                
                // Description
                if (eventData['description'] != null && eventData['description'].isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Description:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  GlassmorphicContainer(
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        eventData['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
                
                // Content
                if (eventData['content'] != null && eventData['content'].isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Content:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  GlassmorphicContainer(
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        eventData['content'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
                
                // Status
                SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Status: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade700,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: getStatusColor(eventData['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: getStatusColor(eventData['status']).withOpacity(0.3)),
                      ),
                      child: Text(
                        getStatusText(eventData['status']),
                        style: TextStyle(
                          color: getStatusColor(eventData['status']),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Rejection Reason (if rejected)
                if (eventData['status']?.toLowerCase() == 'rejected' && eventData['rejectionReason'] != null) ...[
                  SizedBox(height: 16),
                  Text(
                    'Rejection Reason:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  GlassmorphicContainer(
                    backgroundColor: Colors.red.shade50.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200.withOpacity(0.5)),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        eventData['rejectionReason'],
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
                
                // Created At
                SizedBox(height: 16),
                buildDetailRow('Created At', formatEventDate(eventData['createdAt'])),
                
                 // Approved/Rejected At
                 if (eventData['approvedAt'] != null)
                   buildDetailRow('Approved At', formatEventDate(eventData['approvedAt'])),
                 if (eventData['rejectedAt'] != null)
                   buildDetailRow('Rejected At', formatEventDate(eventData['rejectedAt'])),
                
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build detail rows
  Widget buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.teal.shade700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get status color
  Color getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green.shade600;
      case 'rejected':
        return Colors.red.shade600;
      case 'pending':
      default:
        return Colors.orange.shade600;
    }
  }

  // Helper method to get status text
  String getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      default:
        return 'Pending Review';
    }
  }

  // Build Event Analytics Dashboard
  Widget buildEventAnalytics() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Analytics Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.teal.shade700,
            ),
          ),
          SizedBox(height: 20),
          
          // Overview Cards
          Row(
            children: [
              Expanded(
                child: buildAnalyticsCard(
                  'Total Events',
                  Icons.event_outlined,
                  Colors.blue,
                  buildTotalEventsStream(),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: buildAnalyticsCard(
                  'Total Bookings',
                  Icons.people,
                  Colors.green,
                  buildTotalRegistrationsStream(),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: buildAnalyticsCard(
                  'Pending Events',
                  Icons.pending,
                  Colors.orange,
                  buildPendingEventsStream(),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: buildAnalyticsCard(
                  'Approved Events',
                  Icons.check_circle,
                  Colors.green,
                  buildApprovedEventsStream(),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          
          // Event Performance Chart
          Text(
            'Event Performance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16),
          buildEventPerformanceChart(),
          SizedBox(height: 24),
          
          // Top Events by Registrations
          Text(
            'Top Events by Registrations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16),
          buildTopEventsList(),
        ],
      ),
    );
  }

  Widget buildAnalyticsCard(String title, IconData icon, Color color, Widget streamWidget) {
    return GlassmorphicCard(
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Center(
              child: streamWidget,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTotalEventsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('spot_events').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 500),
            child: Text(
              '${snapshot.data!.docs.length}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade600,
              ),
            ),
          );
        }
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.blue.shade600,
          ),
        );
      },
    );
  }

  Widget buildTotalRegistrationsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('event_registrations').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 500),
            child: Text(
              '${snapshot.data!.docs.length}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade600,
              ),
            ),
          );
        }
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.green.shade600,
          ),
        );
      },
    );
  }

  Widget buildPendingEventsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spot_events')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 500),
            child: Text(
              '${snapshot.data!.docs.length}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade600,
              ),
            ),
          );
        }
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.orange.shade600,
          ),
        );
      },
    );
  }

  Widget buildApprovedEventsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spot_events')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 500),
            child: Text(
              '${snapshot.data!.docs.length}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade600,
              ),
            ),
          );
        }
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.green.shade600,
          ),
        );
      },
    );
  }

  Widget buildEventPerformanceChart() {
    return GlassmorphicCard(
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('spot_events')
                  .where('status', isEqualTo: 'approved')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.teal.shade600,
                      ),
                    ),
                  );
                }

                List<Map<String, dynamic>> events = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return data;
                }).toList();

                if (events.isEmpty) {
                  return Container(
                    height: 200,
                    child: Center(
                      child: Text(
                        'No approved events found',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }

                return Container(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: events.length > 10 ? 10 : events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return FutureBuilder<int>(
                        future: getEventRegistrationCount(event['id']),
                        builder: (context, registrationSnapshot) {
                          int registrationCount = registrationSnapshot.data ?? 0;
                          int maxParticipants = event['maxParticipants'] ?? 0;
                          double percentage = maxParticipants > 0 
                              ? (registrationCount / maxParticipants) * 100 
                              : 0;

                          return AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            width: 80,
                            margin: EdgeInsets.only(right: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${registrationCount}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                GlassmorphicContainer(
                                  height: 120,
                                  width: 40,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      AnimatedContainer(
                                        duration: Duration(milliseconds: 500),
                                        curve: Curves.easeInOut,
                                        height: (percentage / 100) * 120,
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade400,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  event['name'] ?? 'Event',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTopEventsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spot_events')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.teal.shade600,
            ),
          );
        }

        List<Map<String, dynamic>> events = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        if (events.isEmpty) {
          return GlassmorphicContainer(
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No approved events found',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          children: events.take(5).map((event) {
            return FutureBuilder<int>(
              future: getEventRegistrationCount(event['id']),
              builder: (context, registrationSnapshot) {
                int registrationCount = registrationSnapshot.data ?? 0;
                
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: EdgeInsets.only(bottom: 12),
                  child: GlassmorphicCard(
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            '${registrationCount}',
                            style: TextStyle(
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        event['name'] ?? 'Unnamed Event',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      subtitle: Text(
                        '${event['eventType'] ?? 'N/A'} • ${event['paymentType'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: Text(
                        formatEventDate(event['eventDate']),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Future<int> getEventRegistrationCount(String eventId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('event_registrations')
          .where('eventId', isEqualTo: eventId)
          .get();
      return query.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Show event reject dialog
  void showEventRejectDialog(String eventId, BuildContext context) {
    final TextEditingController reasonController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassmorphicBottomSheet(
        title: 'Reject Event',
        icon: Icons.warning,
        iconColor: Colors.red.shade600,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please provide a reason for rejecting this event:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 20),
              GlassmorphicContainer(
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter rejection reason...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GlassmorphicButton(
                      onPressed: () => Navigator.pop(context),
                      label: 'Cancel',
                      backgroundColor: Colors.grey.shade400,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: GlassmorphicButton(
                      onPressed: () async {
                        if (reasonController.text.trim().isEmpty) {
                          Fluttertoast.showToast(
                            msg: 'Please provide a rejection reason',
                            backgroundColor: Colors.orange.shade600,
                            textColor: Colors.white,
                          );
                          return;
                        }
                        
                        Navigator.pop(context);
                        await rejectEvent(eventId, reasonController.text.trim());
                      },
                      label: 'Reject',
                      backgroundColor: Colors.red.shade600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Reject event
  Future<void> rejectEvent(String eventId, String reason) async {
    try {
      await _firestore.collection('spot_events').doc(eventId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': _auth.currentUser?.uid,
      });
      
      Fluttertoast.showToast(
        msg: 'Event rejected successfully',
        backgroundColor: Colors.red.shade600,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error rejecting event: $e',
        backgroundColor: Colors.red.shade600,
        textColor: Colors.white,
      );
    }
  }

  // Format event date
  String formatEventDate(dynamic date) {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
    return date.toString();
  }

  // Build search bar for events
  Widget buildEventSearchBar({required Function(String) onSearchChanged, required Function(DateTime?) onDateChanged, required String eventSearchQuery, required DateTime? eventFilterDate, required BuildContext context}) {
    return GlassmorphicContainer(
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  prefixIcon: Icon(Icons.search, color: Colors.teal.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                ),
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            SizedBox(width: 12),
            GlassmorphicButton(
              onPressed: () {
                showDatePicker(
                  context: context,
                  initialDate: eventFilterDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(Duration(days: 365)),
                ).then((date) {
                  if (date != null) {
                    onDateChanged(date);
                  }
                });
              },
              icon: Icons.calendar_today,
              iconColor: Colors.teal.shade600,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.teal.shade600,
              tooltip: 'Filter by date',
            ),
            if (eventFilterDate != null)
              GlassmorphicButton(
                onPressed: () {
                  onDateChanged(null);
                },
                icon: Icons.clear,
                iconColor: Colors.red.shade600,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.red.shade600,
                tooltip: 'Clear date filter',
              ),
          ],
        ),
      ),
    );
  }
}