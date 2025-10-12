import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
class bkUserDetails extends StatelessWidget {
  final String bookingId; // Booking ID
  final String userId; // User ID
  final String turfId; // Turf ID

  const bkUserDetails({super.key, required this.bookingId, required this.userId, required this.turfId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Booking & User Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchUserAndBookingDetails(userId, bookingId, turfId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading details...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
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
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(Icons.error_outline, size: 30, color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error fetching details.',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
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
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(Icons.info_outline, size: 30, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No data available.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            );
          }

          var userData = snapshot.data!['userData'] as Map<String, dynamic>;
          var bookingData = snapshot.data!['bookingData'] as Map<String, dynamic>;
          var turfData = snapshot.data!['turfData'] as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Booking Status Badge
                _buildStatusBadge(bookingData['bookingSlots']),
                const SizedBox(height: 20),
                // Booking Details Card
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header
                        _buildSectionHeader('Booking Details', Icons.sports_soccer),
                        const SizedBox(height: 16),
                        // Turf Image
                        if (turfData['imageUrl'] != null && turfData['imageUrl'] != '')
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              turfData['imageUrl'],
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.image, size: 60, color: Colors.grey),
                          ),
                        const SizedBox(height: 16),
                        _buildBookingDataTable(bookingData),
                        const SizedBox(height: 16),
                        _buildBookingSlotsSection(bookingData['bookingSlots'] ?? []),
                        const SizedBox(height: 12),
                        _buildBookingStatus(bookingData['bookingStatus'] ?? []),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // User Details Card
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header
                        _buildSectionHeader('User Details', Icons.person),
                        const SizedBox(height: 16),
                        // User Profile
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.teal.withOpacity(0.1),
                                      Colors.teal.withOpacity(0.3),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.teal.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 38,
                                  backgroundColor: Colors.transparent,
                                  backgroundImage: (userData['imageUrl'] != null && userData['imageUrl'] != '')
                                      ? NetworkImage(userData['imageUrl'])
                                      : null,
                                  child: (userData['imageUrl'] == null || userData['imageUrl'] == '')
                                      ? Icon(Icons.person, size: 40, color: Colors.teal)
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                userData['name'] ?? 'User',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildUserDataTable(userData),
                        const SizedBox(height: 20),
                        _buildContactButtons(context, userData),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Back Button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal, Colors.teal[700]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text(
                      'Back',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Glassmorphism card widget
  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: Colors.teal.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }

  // Section header widget
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.teal, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }

  // Status badge at the top
  Widget _buildStatusBadge(List<dynamic>? bookingSlots) {
    bool isActive = bookingSlots != null && bookingSlots.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive 
            ? [Colors.teal.withOpacity(0.9), Colors.teal[700]!]
            : [Colors.red.withOpacity(0.9), Colors.red[700]!],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (isActive ? Colors.teal : Colors.red).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? Icons.check_circle : Icons.cancel, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              isActive ? 'Active Booking' : 'Booking Cancelled',
              style: const TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold, 
                fontSize: 16
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Contact buttons for user
  Widget _buildContactButtons(BuildContext context, Map<String, dynamic> userData) {
    final String? email = userData['email'];
    final String? phone = userData['mobile'];
    
    return Row(
      children: [
        if (email != null && email != 'N/A')
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: email,
                    );
                    _launchUrl(context, emailLaunchUri.toString());
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.email, color: Colors.teal),
                        const SizedBox(width: 8),
                        Text(
                          'Email',
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (phone != null && phone != 'N/A')
          const SizedBox(width: 12),
        if (phone != null && phone != 'N/A')
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final Uri phoneLaunchUri = Uri(
                      scheme: 'tel',
                      path: phone,
                    );
                    _launchUrl(context, phoneLaunchUri.toString());
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone, color: Colors.teal),
                        const SizedBox(width: 8),
                        Text(
                          'Call',
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Helper to launch url (email/phone)
  void _launchUrl(BuildContext context, String url) async {
    try {
      final Uri uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Show error message if the URL cannot be launched
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Show error message if there's an exception
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error launching URL: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildUserDataTable(Map<String, dynamic> userData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDataRow(Icons.person, 'User Name', userData['name'] ?? 'N/A'),
        const SizedBox(height: 12),
        _buildDataRow(Icons.email, 'Email', userData['email'] ?? 'N/A'),
        const SizedBox(height: 12),
        _buildDataRow(Icons.phone, 'Phone', userData['mobile'] ?? 'N/A'),
      ],
    );
  }

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.teal, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDataTable(Map<String, dynamic> bookingData) {
    final date = bookingData['bookingDate'] ?? 'N/A';
    final formattedDate = date != 'N/A' ? _formatDate(date) : 'N/A';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDataRow(Icons.calendar_today, 'Booking Date', formattedDate),
        const SizedBox(height: 12),
        _buildDataRow(Icons.sports, 'Selected Ground', bookingData['selectedGround'] ?? 'N/A'),
        const SizedBox(height: 12),
        _buildDataRow(Icons.attach_money, 'Amount', '₹${bookingData['amount']?.toStringAsFixed(2) ?? '0.00'}'),
        const SizedBox(height: 12),
        _buildDataRow(Icons.timer, 'Total Hours', '${bookingData['totalHours'] ?? 0}'),
        const SizedBox(height: 12),
        _buildDataRow(Icons.location_on, 'Turf Name', bookingData['turfName'] ?? 'N/A'),
        const SizedBox(height: 12),
        _buildDataRow(Icons.payment, 'Payment Method', bookingData['paymentMethod'] ?? 'N/A'),
      ],
    );
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (e) {
      return date;
    }
  }

  Widget _buildBookingSlotsSection(List<dynamic> bookingSlots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.access_time, color: Colors.teal, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Booking Slots',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        bookingSlots.isEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'All Booking Cancelled',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: bookingSlots.map<Widget>((slot) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    ),
                    child: Text(
                      slot.toString(),
                      style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildBookingStatus(List<dynamic> bookingStatus) {
    if (bookingStatus.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.cancel, color: Colors.red, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Cancelled Slots',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: bookingStatus.map<Widget>((slot) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                slot.toString(),
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _fetchUserAndBookingDetails(String userId, String bookingId, String turfId) async {
    try {
      var userSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      var userData = userSnapshot.data();
      var bookingSnapshot = await FirebaseFirestore.instance
          .collection('turfs')
          .doc(turfId)
          .collection('bookings')
          .doc(bookingId)
          .get();
      var bookingData = bookingSnapshot.data();
      var turfSnapshot = await FirebaseFirestore.instance.collection('turfs').doc(turfId).get();
      var turfData = turfSnapshot.data();
      return {
        'userData': {
          'userId': userId,
          'name': userData?['name'] ?? 'N/A',
          'email': userData?['email'] ?? 'N/A',
          'mobile': userData?['mobile'] ?? 'N/A',
          'imageUrl': userData?['imageUrl'] ?? '',
        },
        'bookingData': {
          'amount': bookingData?['amount'] ?? 0,
          'bookingDate': bookingData?['bookingDate'] ?? 'N/A',
          'bookingSlots': bookingData?['bookingSlots'] ?? [],
          'bookingStatus': bookingData?['bookingStatus'] ?? [],
          'selectedGround': bookingData?['selectedGround'] ?? 'N/A',
          'totalHours': bookingData?['totalHours'] ?? 0,
          'turfId': turfId,
          'turfName': bookingData?['turfName'] ?? 'N/A',
          'paymentMethod': bookingData?['paymentMethod'] ?? 'N/A',
        },
        'turfData': {
          'imageUrl': turfData?['imageUrl'] ?? '',
          'name': turfData?['name'] ?? 'N/A',
        },
      };
    } catch (e) {
      throw Exception('Error fetching details: $e');
    }
  }
}