import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  String? _imageUrl;
  File? _newImageFile;

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
    _imageUrl = turfData['imageUrl'];
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveTurfDetails() async {
    try {
      String? newImageUrl;
      if (_newImageFile != null) {
        // Delete the old image from Firebase Storage
        if (_imageUrl != null) {
          var oldImageRef = FirebaseStorage.instance.refFromURL(_imageUrl!);
          await oldImageRef.delete();
        }

        // Upload the new image to Firebase Storage
        var storageRef = FirebaseStorage.instance.ref().child('turfs/${widget.turfId}/image.jpg');
        await storageRef.putFile(_newImageFile!);
        newImageUrl = await storageRef.getDownloadURL();
      }

      // Update Firestore document
      await FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).update({
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        if (newImageUrl != null) 'imageUrl': newImageUrl,
      });

      Navigator.pop(context);
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving details: $e')),
      );
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: _newImageFile != null
                    ? Image.file(_newImageFile!, height: 200, width: double.infinity, fit: BoxFit.cover)
                    : _imageUrl != null
                    ? Image.network(_imageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover)
                    : Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey[700]),
                ),
              ),
              SizedBox(height: 16),
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
      ),
    );
  }
}
