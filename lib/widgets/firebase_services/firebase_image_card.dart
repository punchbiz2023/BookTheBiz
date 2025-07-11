import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class FirebaseImageCard extends StatelessWidget {
  final String imagePath;

  const FirebaseImageCard({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadImage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError || !snapshot.hasData) {
          return _buildPlaceholder();
        } else {
          return _buildImage(snapshot.data!);
        }
      },
    );
  }

  Future<String> _loadImage() async {
    try {
      final ref = FirebaseStorage.instance.ref().child(imagePath);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      throw Exception('Failed to load image');
    }
  }

  Widget _buildImage(String url) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8.0),
      child: Image.network(
        url,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8.0),
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 60,
        ),
      ),
    );
  }
}
