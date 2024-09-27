import 'package:flutter/material.dart';

import '../pages/details.dart';

class FirebaseImageCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String description;
  final String documentId;
  final String docname;
  final List<String> chips;

  const FirebaseImageCard({
    Key? key,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.documentId,
    required this.docname,
    required this.chips,
  }) : super(key: key);

  void _navigateToDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsPage(
          documentId: documentId,
          documentname: docname,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToDetails(context),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        margin: EdgeInsets.only(right: 10),
        child: Stack(
          children: [
            // Background Image
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: imageUrl.isNotEmpty
                      ? NetworkImage(imageUrl)
                      : AssetImage('assets/placeholder.png') as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Gradient overlay for better text visibility
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            // Chips overlayed on the image
            Positioned(
              top: 10,
              left: 10,
              child: Wrap(
                spacing: 6.0,
                children: chips.map((chip) => _buildChip(chip)).toList(),
              ),
            ),
            // Turf Title and Description at the bottom
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Transparent modern chip design
  Widget _buildChip(String label) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.black.withOpacity(0.3),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
      ),
    );
  }
}
