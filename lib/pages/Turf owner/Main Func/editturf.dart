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
  bool _isosp = false; // New variable for isosp

  // Sample data for facilities and grounds
  List<String> facilities = [
    'Parking',
    'Restroom',
    'Cafeteria',
    'Lighting',
    'Shower',
    'Changing Room',
    'Wi-Fi',
    'Seating',
  ];
  List<String> availableGrounds = [
    'Volleyball Court',
    'Swimming Pool',
    'Shuttlecock',
    'Cricket Ground',
    'Badminton Court',
    'Tennis Court',
    'Football Field',
    'Basketball Court',
  ];

  // Selected states
  Set<String> selectedFacilities = {};
  Set<String> selectedGrounds = {};

  @override
  void initState() {
    super.initState();
    _loadTurfDetails();
  }

  Future<void> _loadTurfDetails() async {
    var doc = await FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).get();
    var turfData = doc.data() as Map<String, dynamic>;
    setState(() {
      _nameController.text = turfData['name'] ?? '';
      _descriptionController.text = turfData['description'] ?? '';
      _priceController.text = turfData['price']?.toString() ?? '';
      _imageUrl = turfData['imageUrl'];
      _isosp = turfData['isosp'] ?? false; // Load isosp value

      // Load selected facilities and grounds from Firestore data
      selectedFacilities = Set<String>.from(turfData['facilities'] ?? []);
      selectedGrounds = Set<String>.from(turfData['availableGrounds'] ?? []);
    });
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
        'facilities': selectedFacilities.toList(),
        'availableGrounds': selectedGrounds.toList(),
        'isosp': _isosp, // Save isosp value
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
        backgroundColor: Colors.teal,
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
                    ? Image.file(
                  _newImageFile!,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
                    : _imageUrl != null
                    ? Image.network(
                  _imageUrl!,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
                    : Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_a_photo,
                    size: 50,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildTextField(_nameController, 'Turf Name'),
              SizedBox(height: 16),
              _buildTextField(_descriptionController, 'Description'),
              SizedBox(height: 16),
              _buildTextField(_priceController, 'Price', keyboardType: TextInputType.number),
              SizedBox(height: 16),
              _buildFacilitiesSelection(),
              SizedBox(height: 16),
              _buildGroundsSelection(),
              SizedBox(height: 16),
              _buildIsospSwitch(), // Add the Switch for isosp
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      keyboardType: keyboardType,
    );
  }

  Widget _buildFacilitiesSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Facilities:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: facilities.map((facility) {
            return ChoiceChip(
              label: Text(facility),
              selected: selectedFacilities.contains(facility),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedFacilities.add(facility);
                  } else {
                    selectedFacilities.remove(facility);
                  }
                });
              },
              backgroundColor: Colors.grey[300],
              selectedColor: Colors.teal,
              labelStyle: TextStyle(color: selectedFacilities.contains(facility) ? Colors.white : Colors.black),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGroundsSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Grounds:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: availableGrounds.map((ground) {
            return ChoiceChip(
              label: Text(ground),
              selected: selectedGrounds.contains(ground),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedGrounds.add(ground);
                  } else {
                    selectedGrounds.remove(ground);
                  }
                });
              },
              backgroundColor: Colors.grey[300],
              selectedColor: Colors.teal,
              labelStyle: TextStyle(color: selectedGrounds.contains(ground) ? Colors.white : Colors.black),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIsospSwitch() {
    return Row(
      children: [
        Text(
          'Onspot payment:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
        ),
        SizedBox(width: 16),
        Switch(
          value: _isosp,
          onChanged: (value) {
            setState(() {
              _isosp = value;
            });
          },
          activeColor: Colors.teal,
        ),
      ],
    );
  }
}