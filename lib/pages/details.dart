import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DetailsPage extends StatelessWidget {
  final String documentId;
  final String documentname;

  const DetailsPage({
    Key? key,
    required this.documentId,
    required this.documentname,
  }) : super(key: key);

  Future<Map<String, dynamic>?> _fetchDetails() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> documentSnapshot =
          await FirebaseFirestore.instance
              .collection('turfs') // Replace with your collection
              .doc(documentId)
              .get();

      if (documentSnapshot.exists) {
        return documentSnapshot.data();
      } else {
        print('Document does not exist');
        return null;
      }
    } catch (e) {
      print('Error fetching document: $e');
      return null;
    }
  }

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

  Widget _buildChipList(String title, List<dynamic> items,
      Color backgroundColor, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title:',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
                    labelStyle: TextStyle(
                      color: labelColor,
                    ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>?>(
        // Note the removal of the AppBar from here
        future: _fetchDetails(),
        builder: (BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error fetching details'));
          }

          if (snapshot.hasData && snapshot.data != null) {
            // Extract imageUrl, availableGrounds, and facilities
            String imageUrl = snapshot.data!['imageUrl'] ?? '';
            List<dynamic> availableGrounds =
                snapshot.data!['availableGrounds'] ?? [];
            List<dynamic> facilities = snapshot.data!['facilities'] ?? [];

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(documentname),
                    background: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: Colors.grey,
                            child: Center(
                              child: Text(
                                'Image not available',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildChipList(
                              'Available Grounds',
                              availableGrounds,
                              Colors.blueAccent,
                              Colors.white,
                            ),
                            _buildChipList(
                              'Facilities',
                              facilities,
                              Colors.green,
                              Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Center(child: Text('No data found for $documentId'));
        },
      ),
    );
  }
}
