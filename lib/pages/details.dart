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
      // Fetch the document from Firestore using documentId
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(documentname),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
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

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display the image
                    imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            height: 250,
                            color: Colors.grey,
                            child: Center(
                              child: Text(
                                'Image not available',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                    SizedBox(height: 16),

                    // Display Available Grounds as Chips
                    Text(
                      'Available Grounds:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: availableGrounds
                          .map((ground) => Chip(
                                label: Text(ground),
                                backgroundColor: Colors.blueAccent,
                                labelStyle: TextStyle(color: Colors.white),
                              ))
                          .toList(),
                    ),
                    SizedBox(height: 16),

                    // Display Facilities as Chips
                    Text(
                      'Facilities:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: facilities
                          .map((facility) => Chip(
                                label: Text(facility),
                                backgroundColor: Colors.greenAccent,
                                labelStyle: TextStyle(color: Colors.black),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(child: Text('No data found for $documentId'));
        },
      ),
    );
  }
}
