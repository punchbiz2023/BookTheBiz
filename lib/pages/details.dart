import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:carousel_slider/carousel_slider.dart'; // Import for carousel
import 'bookingpage.dart'; // Ensure this import is correct
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';
import 'package:odp/pages/subscriptions_page.dart';

class DetailsPage extends StatefulWidget {
  final String documentId;
  final String documentname;

  const DetailsPage({
    super.key,
    required this.documentId,
    required this.documentname,
  });

  @override
  _DetailsPageState createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedFromTime;
  TimeOfDay? _selectedToTime;
  double price = 0.0;
  double? totalHours = 0.0;

  // Fetch details from Firestore
  Future<Map<String, dynamic>?> _fetchDetails() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> documentSnapshot =
      await FirebaseFirestore.instance
          .collection('turfs') // Replace with your collection
          .doc(widget.documentId)
          .get();

      if (documentSnapshot.exists) {
        dynamic rawPrice = documentSnapshot.data()?['price'];

        // Ensure price is always treated as double
        if (rawPrice is List<dynamic> && rawPrice.isNotEmpty) {
          price = (rawPrice.first is num) ? (rawPrice.first as num).toDouble() : 0.0;
        } else if (rawPrice is Map<String, dynamic> && rawPrice.isNotEmpty) {
          var entry = rawPrice.entries.first;
          price = (entry.value is num) ? (entry.value as num).toDouble() : 0.0;
        } else if (rawPrice is num) {
          price = rawPrice.toDouble();
        } else {
          price = 0.0;
        }

        // Return all data including isosp
        return {
          ...documentSnapshot.data()!,
          'isosp': documentSnapshot.data()?['isosp'] ?? false, // Fetch isosp
        };
      } else {
        print('Document does not exist');
        return null;
      }
    } catch (e) {
      print('Error fetching document: $e');
      return null;
    }
  }

  // Get icon for each item
  IconData _getIconForItem(String item) {
    switch (item.toLowerCase()) {
      case 'football field':
        return Icons.sports_soccer;
      case 'volleyball court':
        return Icons.sports_volleyball;
      case 'cricket ground':
        return Icons.sports_cricket;
      case 'basketball court':
        return Icons.sports_basketball;
      case 'swimming pool':
        return Icons.pool;
      case 'shuttlecock':
        return Icons.sports_tennis;
      case 'tennis court':
        return Icons.sports_tennis;
      case 'badminton court':
        return Icons.sports_tennis;
      case 'parking':
        return Icons.local_parking;
      case 'restroom':
        return Icons.wc;
      case 'cafeteria':
        return Icons.restaurant;
      case 'lighting':
        return Icons.lightbulb;
      case 'seating':
        return Icons.event_seat;
      case 'shower':
        return Icons.shower;
      case 'changing room':
        return Icons.room_preferences;
      case 'wi-fi':
        return Icons.wifi;
      default:
        return Icons.sports;
    }
  }

  // Helper to get image asset for each item (if available)
  String? _getImageForItem(String item) {
    final map = {
      'football field': 'lib/assets/football_field.jpg',
      'volleyball court': 'lib/assets/volleyball_court.jpg',
      'cricket ground': 'lib/assets/cricket_ground.jpg',
      'basketball court': 'lib/assets/basket_ball.jpg',
      'swimming pool': 'lib/assets/swimming_pool.jpg',
      'shuttlecock': 'lib/assets/shuttle_cock.jpg',
      'tennis court': 'lib/assets/tennis_court.jpg',
      'badminton court': 'lib/assets/badminton_court.jpg',
    };
    return map[item.toLowerCase()];
  }

  // Build a list of chips for available grounds or facilities
  Widget _buildChipList(String title, List<dynamic> items, Color backgroundColor, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        SizedBox(height: 2),
        Text(
          'Available',
          style: TextStyle(
            color: backgroundColor.withOpacity(0.85),
            fontWeight: FontWeight.w500,
            fontSize: 13.5,
            letterSpacing: 0.1,
          ),
        ),
        SizedBox(height: 6),
        Wrap(
          spacing: 10.0,
          runSpacing: 8.0,
          children: items.map((item) {
            final img = _getImageForItem(item);
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(0.13),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (img != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        img,
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: backgroundColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_getIconForItem(item), color: backgroundColor, size: 14),
                    ),
                  SizedBox(width: 6),
                  Text(
                    item,
                    style: TextStyle(
                      color: labelColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14.5,
                      letterSpacing: 0.05,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.check_circle, color: backgroundColor.withOpacity(0.7), size: 16),
                ],
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 18),
      ],
    );
  }

  // Build a chip to display on-spot payment status
  Widget _buildOnSpotPaymentStatus(bool isosp) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isosp 
              ? [Colors.green.shade50, Colors.green.shade100] 
              : [Colors.red.shade50, Colors.red.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isosp ? Colors.green.shade200 : Colors.red.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isosp ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isosp ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isosp ? Icons.payments : Icons.money_off,
              color: isosp ? Colors.green.shade700 : Colors.red.shade700,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Option',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  isosp ? 'On Spot Payment Accepted' : 'On Spot Payment Not Accepted',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isosp ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isosp ? Icons.check_circle : Icons.cancel,
            color: isosp ? Colors.green.shade600 : Colors.red.shade600,
            size: 22,
          ),
        ],
      ),
    );
  }

  // Fetch user name from Firestore
  Future<String> _fetchUserName(String userId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> userDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists) {
        return userDoc.data()?['name'] ?? 'Anonymous';
      } else {
        return 'Anonymous';
      }
    } catch (e) {
      print('Error fetching user name: $e');
      return 'Anonymous';
    }
  }

  // Show booking dialog
  void _showBookingDialog() async {
    String userName = 'Anonymous';
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      userName = await _fetchUserName(currentUser.uid);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Automatically open date picker when dialog is built
        Future<void> selectDate(BuildContext context) async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime(2101),
          );
          if (pickedDate != null) {
            setState(() {
              _selectedDate = pickedDate;
            });
          }
        }

        // Immediately call date picker once dialog is displayed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          selectDate(context);
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.grey[900],
          elevation: 10,
          title: Text(
            'Book Now',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: SizedBox(
            width: 800,
            height: 800,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select Date and Time (More than 1 hour)',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  SizedBox(height: 16),
                  // Date Selection Display
                  Card(
                    color: Colors.blueGrey[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      title: Text(
                        _selectedDate != null
                            ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                            : 'Date Not Selected',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      trailing: GestureDetector(
                        onTap: () => selectDate(context),
                        child: Icon(Icons.calendar_today, color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // From Time Selection Card
                  Card(
                    color: Colors.blueGrey[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      title: Text(
                        _selectedFromTime != null
                            ? 'From: ${_selectedFromTime!.format(context)}'
                            : 'Select From Time',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      trailing: Icon(Icons.access_time, color: Colors.white),
                      onTap: () async {
                        TimeOfDay? pickedFromTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (pickedFromTime != null) {
                          setState(() {
                            _selectedFromTime = pickedFromTime;
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  // To Time Selection Card
                  Card(
                    color: Colors.blueGrey[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      title: Text(
                        _selectedToTime != null
                            ? 'To: ${_selectedToTime!.format(context)}'
                            : 'Select To Time',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      trailing: Icon(Icons.access_time, color: Colors.white),
                      onTap: () async {
                        TimeOfDay? pickedToTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (pickedToTime != null) {
                          setState(() {
                            _selectedToTime = pickedToTime;
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_selectedDate == null || _selectedFromTime == null || _selectedToTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select date and time')),
                  );
                  return;
                }

                double? totalHours;
                TimeOfDay fromTime = _selectedFromTime!;
                TimeOfDay toTime = _selectedToTime!;

                final now = DateTime.now();
                DateTime fromDateTime = DateTime(now.year, now.month, now.day, fromTime.hour, fromTime.minute);
                DateTime toDateTime = DateTime(now.year, now.month, now.day, toTime.hour, toTime.minute);

                Duration bookingDuration = toDateTime.difference(fromDateTime);
                double hours = bookingDuration.inMinutes / 60.0;
                int roundedHours = hours.floor();
                totalHours = roundedHours.toDouble();

                if (roundedHours < 1) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Cannot Book'),
                        content: Text(
                            'Bookings less than 1 hour are not allowed. Please visit turf for manual bookings.'),
                        actions: <Widget>[
                          TextButton(
                            child: Text('Okay'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }

                Map<String, dynamic> bookingData = {
                  'userId': currentUser?.uid ?? '',
                  'userName': userName,
                  'bookingDate': DateFormat('yyyy-MM-dd').format(_selectedDate!),
                  'bookingFromTime': _selectedFromTime!.format(context),
                  'bookingToTime': _selectedToTime!.format(context),
                  'turfId': widget.documentId,
                  'turfName': widget.documentname,
                  'totalHoursBooked': totalHours,
                  'amount': totalHours * price,
                };

                try {
                  if (totalHours >= 1) {
                    await FirebaseFirestore.instance.collection('bookings').add(bookingData);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Booking confirmed!')),
                    );
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cannot confirm booking. Total hours must be at least 1 hour.')),
                    );
                  }
                } catch (e) {
                  print('Error saving booking: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to confirm booking')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
              child: Text('Confirm', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  // Fixed widget for activity/facility cards with proper height constraints
  Widget _buildCompactActivityCardList(String title, List<dynamic> items, Color color, {bool isActivities = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with modern design
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isActivities ? Icons.sports_score : Icons.miscellaneous_services,
                color: color,
                size: 26,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${items.length} ${isActivities ? 'activities' : 'facilities'}',
                    style: TextStyle(
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        
        // Fixed height container for horizontal scrollable list
        SizedBox(
          height: 105, // Reduced height to prevent overflow
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.zero, // Removed padding to prevent overflow
            itemBuilder: (context, index) {
              final item = items[index];
              final img = _getImageForItem(item);
              
              return Container(
                width: 140,
                margin: EdgeInsets.only(right: 12, bottom: 0), // Removed bottom margin
                child: Card(
                  elevation: 4,
                  shadowColor: color.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          color.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: color.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    padding: EdgeInsets.all(10), // Reduced padding
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon or Image with animated container
                        Container(
                          width: 45, // Reduced size
                          height: 45, // Reduced size
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.1),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: img != null
                              ? ClipOval(
                                  child: Image.asset(
                                    img,
                                    width: 41, // Reduced size
                                    height: 41, // Reduced size
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  _getIconForItem(item),
                                  color: color,
                                  size: 24, // Reduced size
                                ),
                        ),
                        SizedBox(height: 8), // Reduced spacing
                        // Item name with better typography
                        Expanded(
                          child: Text(
                            item,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13, // Reduced font size
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  // Enhanced widget for displaying turf images as a carousel
  Widget _buildEnhancedTurfImagesCarousel(List<dynamic> images, String spotlightImage) {
    final allImages = [spotlightImage, ...images];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Container(
          margin: EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.photo_library,
                  color: Colors.purple,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gallery',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${allImages.length} photos available',
                    style: TextStyle(
                      color: Colors.purple.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Enhanced Carousel
        CarouselSlider(
          options: CarouselOptions(
            height: 240,
            enlargeCenterPage: true,
            enableInfiniteScroll: allImages.length > 1,
            viewportFraction: 0.85,
            autoPlay: allImages.length > 1,
            autoPlayInterval: Duration(seconds: 4),
            autoPlayAnimationDuration: Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
          ),
          items: allImages.map((imgUrl) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image
                    Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 240,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                                    ),
                                  ),
                                ),
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.grey[600], size: 60),
                            SizedBox(height: 8),
                            Text(
                              'Image not available',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Gradient overlay for better text readability
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    
                    // Image indicator
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${allImages.indexOf(imgUrl) + 1}/${allImages.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  // Enhanced address section widget
  Widget _buildEnhancedAddressSection(Map<String, dynamic> turfData) {
    final address = turfData['location'] ?? '';
    final latitude = turfData['latitude'];
    final longitude = turfData['longitude'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Container(
          margin: EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on,
                  color: Colors.teal,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Find us here',
                    style: TextStyle(
                      color: Colors.teal.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Address Card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.teal.shade50,
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.teal.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.teal.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Address Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Colors.teal,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: latitude != null && longitude != null
                          ? FutureBuilder<String?>(
                              future: _getAddressFromLatLng(latitude, longitude),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Row(children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Fetching address...',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ]);
                                }
                                if (snapshot.hasError) {
                                  return Text(
                                    'Unable to fetch address',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.red,
                                    ),
                                  );
                                }
                                final addr = snapshot.data;
                                return Text(
                                  (addr != null && addr.isNotEmpty)
                                      ? addr
                                      : (address.isNotEmpty ? address : 'No address available'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            )
                          : Text(
                              address.isNotEmpty ? address : 'No address available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ],
                ),
                
                // Maps Button
                if (latitude != null && longitude != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade400,
                            Colors.blue.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.map, color: Colors.white, size: 20),
                        label: Text(
                          'View on Google Maps',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not open Google Maps')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  // Helper to get address from lat/lng using geocoding
  Future<String?> _getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        String composed = '';
        if (p.name != null && p.name!.isNotEmpty) composed += p.name! + ', ';
        if (p.street != null && p.street!.isNotEmpty) composed += p.street! + ', ';
        if (p.subLocality != null && p.subLocality!.isNotEmpty) composed += p.subLocality! + ', ';
        if (p.locality != null && p.locality!.isNotEmpty) composed += p.locality! + ', ';
        if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) composed += p.administrativeArea! + ', ';
        if (p.postalCode != null && p.postalCode!.isNotEmpty) composed += p.postalCode! + ', ';
        if (p.country != null && p.country!.isNotEmpty) composed += p.country!;
        return composed.trim().replaceAll(RegExp(r', *$'), '');
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Find the least price among all subscription prices
  double _findLeastPrice(Map<String, dynamic> monthlyPrices) {
    if (monthlyPrices.isEmpty) return 0.0;
    
    double leastPrice = double.infinity;
    monthlyPrices.forEach((ground, price) {
      if (price is num) {
        double p = price.toDouble();
        if (p < leastPrice) {
          leastPrice = p;
        }
      }
    });
    
    return leastPrice == double.infinity ? 0.0 : leastPrice;
  }

  // Find the ground with the least price
  String _findLeastPriceGround(Map<String, dynamic> monthlyPrices) {
    if (monthlyPrices.isEmpty) return '';
    
    double leastPrice = double.infinity;
    String leastPriceGround = '';
    
    monthlyPrices.forEach((ground, price) {
      if (price is num) {
        double p = price.toDouble();
        if (p < leastPrice) {
          leastPrice = p;
          leastPriceGround = ground;
        }
      }
    });
    
    return leastPriceGround;
  }

  // Gold-themed Monthly Subscription Section with "Show More" button
  Widget _buildGoldMonthlySubscriptionSection(Map<String, dynamic> turfData) {
    if (turfData['supportsMonthlySubscription'] != true || turfData['monthlySubscription'] == null) {
      return SizedBox.shrink();
    }

    final monthlySubData = turfData['monthlySubscription'] as Map<String, dynamic>;
    
    // Check if we have per-ground pricing or single pricing
    bool hasPerGroundPricing = monthlySubData.containsKey('monthlyPrices');
    double monthlyPrice = 0.0;
    String leastPriceGround = '';
    
    if (hasPerGroundPricing) {
      // Find the least price among all grounds
      monthlyPrice = _findLeastPrice(monthlySubData['monthlyPrices'] as Map<String, dynamic>);
      leastPriceGround = _findLeastPriceGround(monthlySubData['monthlyPrices'] as Map<String, dynamic>);
    } else {
      // Use single price
      monthlyPrice = (monthlySubData['monthlyPrice'] as num?)?.toDouble() ?? 0.0;
    }
    
    final workingDays = monthlySubData['workingDays'] as List<dynamic>? ?? [];
    final refundPolicy = monthlySubData['refundPolicy'] as String? ?? '';
    final customRefundPolicy = monthlySubData['customRefundPolicy'] as String? ?? '';
    
    // Calculate discounted price (15% more than actual)
    final discountedPrice = monthlyPrice * 0.85;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Gold gradient background
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFD4AF37), // Gold
                  Color(0xFFFCF4A3), // Light gold
                  Color(0xFFF9E79F), // Pale gold
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with crown icon
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xFFAF4502),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MONTHLY SUBSCRIPTION',
                            style: TextStyle(
                              color: Color(0xFFAF4502),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Exclusive Access',
                            style: TextStyle(
                              color: Color(0xFFAF4502),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 24),
                
                // Price section with discount
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color(0xFFAF4502),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Show the least price ground name if applicable
                          if (hasPerGroundPricing && leastPriceGround.isNotEmpty) ...[
                            Text(
                              'Starting from ',
                              style: TextStyle(
                                color: Color(0xFFAF4502),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                          ],
                          Text(
                            '₹${monthlyPrice.toStringAsFixed(0)}/- Only 🎊',
                            style: TextStyle(
                              color: Color(0xFFAF4502),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Show More button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFD4AF37),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _showSubscriptionDetailsBottomSheet(monthlySubData, monthlyPrice, hasPerGroundPricing),
                    icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFFD4AF37), size: 22),
                    label: Text(
                      'SHOW MORE DETAILS',
                      style: TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFFD4AF37),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Show subscription details in a premium bottom sheet
  void _showSubscriptionDetailsBottomSheet(Map<String, dynamic> monthlySubData, double monthlyPrice, bool hasPerGroundPricing) {
    final workingDays = monthlySubData['workingDays'] as List<dynamic>? ?? [];
    final refundPolicy = monthlySubData['refundPolicy'] as String? ?? '';
    final customRefundPolicy = monthlySubData['customRefundPolicy'] as String? ?? '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header with close button
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFD4AF37),
                      Color(0xFFFCF4A3),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.workspace_premium,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'SUBSCRIPTION DETAILS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Per-ground pricing section if applicable
              if (hasPerGroundPricing) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Per-Ground Pricing',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // Display each ground with its monthly price
                      ...(monthlySubData['monthlyPrices'] as Map<String, dynamic>)
                          .entries.map<Widget>((entry) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Color(0xFFD4AF37).withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFD4AF37).withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Ground Icon
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Color(0xFFD4AF37).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.sports_soccer,
                                  color: Color(0xFFD4AF37),
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 16),
                              
                              // Ground Name and Price
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Monthly Subscription',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Price Display
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFD4AF37),
                                      Color(0xFFD4AF37).withOpacity(0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFFD4AF37).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '₹${(entry.value as num).toDouble().toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                SizedBox(height: 24),
              ],
              
              // Working days section
              if (workingDays.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Days',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: workingDays.map((day) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFD4AF37).withOpacity(0.6),
                                  Color(0xFFD4AF37),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Color(0xFFD4AF37).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              day.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
              ],
              
              // Refund policy section
              if (refundPolicy.isNotEmpty || customRefundPolicy.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refund Policy',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          customRefundPolicy.isNotEmpty ? customRefundPolicy : refundPolicy,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
              ],
              
              // Purchase button
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubscriptionsPage(user: FirebaseAuth.instance.currentUser),
                      ),
                    );
                  },
                  icon: Icon(Icons.verified, color: Colors.white, size: 24),
                  label: Text(
                    'PURCHASE NOW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFD4AF37),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchDetails(),
        builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>?> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error fetching details', style: TextStyle(color: Colors.white)),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            String imageUrl = snapshot.data!['imageUrl'] ?? '';
            List<dynamic> turfImages = snapshot.data!['turfimages'] ?? [];
            List<dynamic> availableGrounds = snapshot.data!['availableGrounds'] ?? [];
            List<dynamic> facilities = snapshot.data!['facilities'] ?? [];
            bool isosp = snapshot.data!['isosp'] ?? false;
            String status = snapshot.data!['status'] ?? 'Opened';

            return CustomScrollView(
              slivers: [
                // Enhanced App Bar with better visuals
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.documentname,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Main Image
                        imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                color: Colors.black.withOpacity(0.3),
                                colorBlendMode: BlendMode.darken,
                                alignment: Alignment.center,
                                filterQuality: FilterQuality.high,
                                loadingBuilder: (context, child, progress) =>
                                    progress == null
                                        ? child
                                        : Container(
                                            color: Colors.grey[800],
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            ),
                                          ),
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey[800],
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.image_not_supported, color: Colors.white, size: 60),
                                        SizedBox(height: 8),
                                        Text(
                                          'Image not available',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.grey[800],
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.sports_soccer, color: Colors.white, size: 60),
                                      SizedBox(height: 8),
                                      Text(
                                        'Image not available',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        // Gradient overlay for better text readability
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        // Status indicator
                        if (status.toLowerCase() == 'closed')
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.cancel,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'CLOSED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
                
                // Main Content
                SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Show enhanced carousel if turfImages exist
                          if (turfImages.isNotEmpty)
                            _buildEnhancedTurfImagesCarousel(turfImages, imageUrl),
                          // Enhanced Address Section
                          if ((snapshot.data!['location'] ?? '').toString().isNotEmpty)
                            _buildEnhancedAddressSection(snapshot.data!),
                          // Fixed Activities and Facilities as compact horizontal cards
                          if (availableGrounds.isNotEmpty)
                            _buildCompactActivityCardList(
                              'Available Activities', 
                              availableGrounds, 
                              Colors.blue,
                              isActivities: true,
                            ),
                          if (facilities.isNotEmpty)
                            _buildCompactActivityCardList(
                              'Facilities', 
                              facilities, 
                              Colors.green,
                              isActivities: false,
                            ),
                          SizedBox(height: 10),
                          // Enhanced On-Spot Payment Status
                          _buildOnSpotPaymentStatus(isosp),
                          SizedBox(height: 24),
                          
                          // Gold-themed Monthly Subscription Section
                          _buildGoldMonthlySubscriptionSection(snapshot.data!),
                          
                          // Enhanced Book Now Button
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: status.toLowerCase() == 'closed'
                                      ? [Colors.red.shade400, Colors.red.shade600]
                                      : [Colors.blue.shade400, Colors.blue.shade600],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                  color: status.toLowerCase() == 'closed'
                                      ? Colors.red.withOpacity(0.3)
                                      : Colors.blue.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                if (status.toLowerCase() == 'closed') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Turf is currently unavailable, please check again later!'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                User? currentUser = FirebaseAuth.instance.currentUser;
                                if (currentUser == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('User not logged in'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                String documentId = widget.documentId;
                                String userId = currentUser.uid;
                                String documentname = widget.documentname;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BookingPage(
                                      documentId: documentId,
                                      documentname: documentname,
                                      userId: userId,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 18),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    status.toLowerCase() == 'closed' ? Icons.warning : Icons.calendar_today,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    status.toLowerCase() == 'closed'
                                        ? '⚠️ Turf is unavailable, please check later ⚠️'
                                        : 'Book Now',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ]),
                ),
              ],
            );
          } else {
            return Center(
              child: Text('No details available', style: TextStyle(color: Colors.white)),
            );
          }
        },
      ),
    );
  }
}