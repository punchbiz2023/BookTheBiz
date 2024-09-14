import 'package:flutter/material.dart';

import '../pages/details.dart';

class FirebaseImageCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String description;
  final String documentId;

  final String docname; // Pass the documentId to be used for navigation

  const FirebaseImageCard({
    Key? key,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.documentId,
    required this.docname,
  }) : super(key: key);

  void _navigateToDetails(BuildContext context) {
    // Example navigation logic (replace with actual navigation logic)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsPage(
            documentId: documentId,
            documentname: docname), // Pass the documentId
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToDetails(context), // Add the onTap action
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        height: 200,
        margin: EdgeInsets.only(right: 10),
        child: Card(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : Center(child: Text('Image not available')),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  description,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
