import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditTurfPage extends StatefulWidget {
  final String turfId;

  EditTurfPage({required this.turfId});

  @override
  _EditTurfPageState createState() => _EditTurfPageState();
}

class _EditTurfPageState extends State<EditTurfPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTurfDetails();
  }

  Future<void> _loadTurfDetails() async {
    var doc = await FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).get();
    var turfData = doc.data() as Map<String, dynamic>;
    _nameController.text = turfData['name'] ?? '';
    _descriptionController.text = turfData['description'] ?? '';
    _priceController.text = turfData['price']?.toString() ?? '';
  }

  Future<void> _saveTurfDetails() async {
    try {
      await FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).update({
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
      });
      Navigator.pop(context);
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Turf Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveTurfDetails,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Turf Name'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }
}
