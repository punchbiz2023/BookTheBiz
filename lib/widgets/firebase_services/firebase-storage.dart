import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class FirebaseImageCard extends StatelessWidget {
  final String imagePath;

  FirebaseImageCard({required this.imagePath});

  Future<String> _getImageUrl() async {
    try {
      final ref = FirebaseStorage.instance.ref().child(imagePath);
      final url = await ref.getDownloadURL();
      print('Image URL: $url'); // Debugging statement
      return url;
    } catch (e) {
      print('Error fetching image URL: $e'); // Debugging statement
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getImageUrl(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Snapshot error: ${snapshot.error}'); // Debugging statement
          return Center(child: Text('Error fetching image'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No image found'));
        }

        final imageUrl = snapshot.data!;

        return Card(
          color: Colors.black54,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: 200, // Adjust width as needed
              height: 120, // Adjust height as needed
            ),
          ),
        );
      },
    );
  }
}
