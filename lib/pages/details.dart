import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:carousel_slider/carousel_slider.dart'; // Import for carousel
import 'bookingpage.dart'; // Ensure this import is correct

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

  // Build a list of chips for available grounds or facilities
  Widget _buildChipList(String title, List<dynamic> items, Color backgroundColor, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 6.0,
          runSpacing: 3.0,
          children: items
              .map((item) => Chip(
            label: Text(item),
            avatar: Icon(
              _getIconForItem(item),
              color: Colors.white,
              size: 20,
            ),
            backgroundColor: backgroundColor,
            labelStyle: TextStyle(color: labelColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
          ))
              .toList(),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  // Build a chip to display on-spot payment status
  Widget _buildOnSpotPaymentStatus(bool isosp) {
    return Chip(
      label: Text(
        isosp ? 'On Spot Payment Accepted' : 'On Spot Payment Not Accepted',
        style: TextStyle(
          color: isosp ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: isosp ? Colors.green[50] : Colors.red[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50),
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
        // Automatically open the date picker when the dialog is built
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

        // Immediately call the date picker once the dialog is displayed
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
                            'Bookings less than 1 hour are not allowed. Please visit the turf for manual bookings.'),
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

  // Helper widget for activity/facility cards
  Widget _buildIconCardList(String title, List<dynamic> items, Color color) {
  final bool isActivities = title.toLowerCase().contains('activity');
  final int crossAxisCount = isActivities ? 2 : 3;
  final double iconRadius = isActivities ? 32 : 26;
  final double iconSize = isActivities ? 32 : 28;
  final double fontSize = isActivities ? 15 : 14;
  final double cellHeight = isActivities ? 110 : 90;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, idx) {
          final item = items[idx];
          return Container(
            height: cellHeight,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.18), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.07),
                  blurRadius: 8,
                  offset: Offset(2, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.13),
                  radius: iconRadius,
                  child: Icon(_getIconForItem(item), color: color, size: iconSize),
                ),
                SizedBox(height: 6),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      item,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: fontSize,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      SizedBox(height: 18),
    ],
  );
}

  // Widget for displaying turf images as a carousel
  Widget _buildTurfImagesCarousel(List<dynamic> images, String spotlightImage) {
    final allImages = [spotlightImage, ...images];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gallery',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        SizedBox(height: 10),
        CarouselSlider(
          options: CarouselOptions(
            height: 220,
            enlargeCenterPage: true,
            enableInfiniteScroll: allImages.length > 1,
            viewportFraction: 0.8,
            autoPlay: allImages.length > 1,
            autoPlayInterval: Duration(seconds: 4),
          ),
          items: allImages.map((imgUrl) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10), // Sharper edges
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.13),
                    blurRadius: 12,
                    offset: Offset(2, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10), // Sharper edges
                child: Image.network(
                  imgUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 220,
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                          ? child
                          : Center(child: CircularProgressIndicator()),
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: Icon(Icons.broken_image, color: Colors.grey[600], size: 60),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 18),
      ],
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
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.documentname,
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                color: Colors.black.withOpacity(0.45),
                                colorBlendMode: BlendMode.darken,
                                alignment: Alignment.center,
                                filterQuality: FilterQuality.high,
                              )
                            : Container(
                                color: Colors.grey[700],
                                child: Center(
                                  child: Text(
                                    'Image not available',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Show carousel if turfImages exist
                          if (turfImages.isNotEmpty)
                            _buildTurfImagesCarousel(turfImages, imageUrl),
                          // Activities and Facilities as icon cards
                          _buildIconCardList('Available Activities', availableGrounds, Colors.blue),
                          _buildIconCardList('Facilities', facilities, Colors.green),
                          SizedBox(height: 20),
                          _buildOnSpotPaymentStatus(isosp),
                          SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                if (status.toLowerCase() == 'closed') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Turf is currently unavailable, please check again later!')),
                                  );
                                  return;
                                }

                                User? currentUser = FirebaseAuth.instance.currentUser;
                                if (currentUser == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('User not logged in')),
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
                                backgroundColor: status.toLowerCase() == 'closed' ? Colors.red : Colors.blueAccent,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                elevation: 5,
                              ),
                              child: Text(
                                status.toLowerCase() == 'closed'
                                    ? '⚠️ Turf is unavailable, please check later ⚠️'
                                    : 'Book Now',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
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