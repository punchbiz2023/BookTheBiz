import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class bkUserDetails extends StatelessWidget {
  final String bookingId; // Booking ID
  final String userId; // User ID
  final String turfId; // Turf ID

  const bkUserDetails({super.key, required this.bookingId, required this.userId, required this.turfId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking & User Details',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        elevation: 2,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchUserAndBookingDetails(userId, bookingId, turfId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error fetching details.',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'No data available.',
                style: TextStyle(fontSize: 18),
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
                const SizedBox(height: 16),
                // Booking Details Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                color: Colors.grey[200],
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
                        Row(
                          children: [
                            Icon(Icons.sports_soccer, color: Colors.green[700], size: 28),
                            const SizedBox(width: 8),
                            Text('Booking Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[700])),
                          ],
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
                const SizedBox(height: 24),
                // User Details Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.green[100],
                            backgroundImage: (userData['imageUrl'] != null && userData['imageUrl'] != '')
                                ? NetworkImage(userData['imageUrl'])
                                : null,
                            child: (userData['imageUrl'] == null || userData['imageUrl'] == '')
                                ? Icon(Icons.person, size: 40, color: Colors.green[700])
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.person, color: Colors.green[700], size: 28),
                            const SizedBox(width: 8),
                            Text('User Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[700])),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildUserDataTable(userData),
                        const SizedBox(height: 20),
                        _buildContactButtons(context, userData),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Back Button
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back,color: Colors.white,),
                  label: const Text('Back',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Status badge at the top
  Widget _buildStatusBadge(List<dynamic>? bookingSlots) {
    bool isActive = bookingSlots != null && bookingSlots.isNotEmpty;
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.green[600] : Colors.red[400],
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (isActive ? Colors.green : Colors.red).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? Icons.check_circle : Icons.cancel, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              isActive ? 'Active Booking' : 'Booking Cancelled',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
            child: OutlinedButton.icon(
              onPressed: () {
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: email,
                );
                // ignore: deprecated_member_use
                launchUrl(context, emailLaunchUri.toString());
              },
              icon: const Icon(Icons.email, color: Colors.green),
              label: const Text('Email',style: TextStyle(color: Colors.black),),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.green),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        if (phone != null && phone != 'N/A')
          const SizedBox(width: 12),
        if (phone != null && phone != 'N/A')
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final Uri phoneLaunchUri = Uri(
                  scheme: 'tel',
                  path: phone,
                );
                // ignore: deprecated_member_use
                launchUrl(context, phoneLaunchUri.toString());
              },
              icon: const Icon(Icons.phone, color: Colors.green),
              label: const Text('Call',style: TextStyle(color: Colors.black),),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.green),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
      ],
    );
  }

  // Helper to launch url (email/phone)
  void launchUrl(BuildContext context, String url) async {
    // Use url_launcher in your pubspec.yaml for this to work
    // import 'package:url_launcher/url_launcher.dart';
    // await launch(url);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Launching: $url')),
    );
  }

  Widget _buildUserDataTable(Map<String, dynamic> userData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDataRow(Icons.person, 'User Name', userData['name'] ?? 'N/A'),
        const SizedBox(height: 8),
        _buildDataRow(Icons.email, 'Email', userData['email'] ?? 'N/A'),
        const SizedBox(height: 8),
        _buildDataRow(Icons.phone, 'Phone', userData['mobile'] ?? 'N/A'),
      ],
    );
  }

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.green[700], size: 20),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.black,fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.black,fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildBookingDataTable(Map<String, dynamic> bookingData) {
    final date = bookingData['bookingDate'] ?? 'N/A';
    final formattedDate = date != 'N/A' ? _formatDate(date) : 'N/A';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDataRow(Icons.calendar_today, 'Booking Date', formattedDate),
        const SizedBox(height: 8),
        _buildDataRow(Icons.sports, 'Selected Ground', bookingData['selectedGround'] ?? 'N/A'),
        const SizedBox(height: 8),
        _buildDataRow(Icons.attach_money, 'Amount', '₹${bookingData['amount']?.toStringAsFixed(2) ?? '0.00'}'),
        const SizedBox(height: 8),
        _buildDataRow(Icons.timer, 'Total Hours', '${bookingData['totalHours'] ?? 0}'),
        const SizedBox(height: 8),
        _buildDataRow(Icons.location_on, 'Turf Name', bookingData['turfName'] ?? 'N/A'),
        const SizedBox(height: 8),
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
        Text(
          'Booking Slots',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700]),
        ),
        const SizedBox(height: 10),
        bookingSlots.isEmpty
            ? Chip(
                label: const Text('All Booking Cancelled'),
                backgroundColor: Colors.red[100],
                labelStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              )
            : Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: bookingSlots.map<Widget>((slot) {
                  return Chip(
                    label: Text(slot.toString()),
                    backgroundColor: Colors.green[100],
                    labelStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildBookingStatus(List<dynamic> bookingStatus) {
    return bookingStatus.isEmpty
        ? Container()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cancelled Slots',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[700]),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: bookingStatus.map<Widget>((slot) {
                  return Chip(
                    label: Text(slot.toString()),
                    backgroundColor: Colors.red[100],
                    labelStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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