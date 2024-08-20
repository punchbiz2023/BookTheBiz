import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreListView extends StatelessWidget {
  final String collectionPath; // Path to the Firestore collection
  final Widget Function(DocumentSnapshot)
      itemBuilder; // Function to build each item

  FirestoreListView({
    required this.collectionPath,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collectionPath).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No data available'));
        }

        final documents = snapshot.data!.docs;

        return ListView.builder(
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final document = documents[index];
            return itemBuilder(document);
          },
        );
      },
    );
  }
}
