import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddTurfPage extends StatefulWidget {
  @override
  _AddTurfPageState createState() => _AddTurfPageState();
}

class _AddTurfPageState extends State<AddTurfPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController =
      TextEditingController(); // Price controller
  File? _imageFile;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  // Facilities list
  final List<String> _facilities = [
    'Parking',
    'Restroom',
    'Cafeteria',
    'Lighting',
    'Seating',
    'Shower',
    'Changing Room',
    'Wi-Fi'
  ];
  final List<String> _selectedFacilities = [];

  // Available Grounds list (Sports types)
  final List<String> _availableGrounds = [
    'Volleyball Court',
    'Swimming Pool',
    'Cricket Ground',
    'Shuttlecock',
    'Football Field',
    'Basketball Court',
    'Tennis Court',
    'Badminton Court'
  ];
  final List<String> _selectedAvailableGrounds = [];

  // Function to pick image from gallery
  Future<void> _pickImage() async {
    final pickedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _imageFile = File(pickedImage.path);
      });
    }
  }

  // Function to upload image to Firebase Storage
  Future<String> _uploadImage(File image) async {
    try {
      Reference storageRef = _firebaseStorage
          .ref()
          .child('turf_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      UploadTask uploadTask = storageRef.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Helper function to return specific icons based on the item name
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
        return Icons.help; // Fallback for unrecognized items
    }
  }

  // Function to submit the turf details
  Future<void> _submitTurf() async {
    if (_nameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _imageFile == null ||
        _priceController.text.isEmpty || // Check if price is empty
        _selectedFacilities.isEmpty ||
        _selectedAvailableGrounds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String imageUrl = await _uploadImage(_imageFile!);
      await _firestore.collection('turfs').add({
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': double.parse(_priceController.text), // Add price to Firestore
        'imageUrl': imageUrl,
        'facilities': _selectedFacilities,
        'availableGrounds': _selectedAvailableGrounds,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Turf added successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding turf: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white, // Background color for white theme
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            title: Text('Add Turf', style: TextStyle(color: Colors.grey[700])),
            centerTitle: true,
            floating: true,
            // Show and hide the app bar based on scrolling
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildImagePicker(),
                      // Image selector at the top
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Turf Name',
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        maxLines: 3,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _priceController,
                        label: 'Price',
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 16),
                      _buildTopicTitle('Facilities'),
                      _buildFacilitiesChips(),
                      // Facilities chip selector
                      SizedBox(height: 16),
                      _buildTopicTitle('Available Grounds'),
                      _buildAvailableGroundsChips(),
                      // Available grounds chip selector
                      SizedBox(height: 24),
                      _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : _buildSubmitButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.black54),
        fillColor: Colors.grey[200],
        // Light background color for white theme
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blueAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[200],
        ),
        child: _imageFile == null
            ? Center(
                child: Text(
                  'Pick an Image',
                  style: TextStyle(color: Colors.black38),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _imageFile!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
      ),
    );
  }

  Widget _buildTopicTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFacilitiesChips() {
    return Wrap(
      spacing: 8.0,
      children: _facilities.map((facility) {
        final isSelected = _selectedFacilities.contains(facility);
        return ChoiceChip(
          avatar: Icon(
            _getIconForItem(facility),
            color: isSelected ? Colors.white : Colors.black54,
            size: 20,
          ),
          label: Text(
            facility,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedFacilities.add(facility);
              } else {
                _selectedFacilities.remove(facility);
              }
            });
          },
          selectedColor: Colors.green,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
            side: isSelected
                ? BorderSide.none // Remove border when selected
                : BorderSide(
                    color: Colors.black26, width: 1), // Border for unselected
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAvailableGroundsChips() {
    return Wrap(
      spacing: 8.0,
      children: _availableGrounds.map((ground) {
        final isSelected = _selectedAvailableGrounds.contains(ground);
        return ChoiceChip(
          avatar: Icon(
            _getIconForItem(ground),
            color: isSelected ? Colors.white : Colors.black54,
            size: 20,
          ),
          label: Text(
            ground,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedAvailableGrounds.add(ground);
              } else {
                _selectedAvailableGrounds.remove(ground);
              }
            });
          },
          selectedColor: Colors.green,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
            side: isSelected
                ? BorderSide.none // Remove border when selected
                : BorderSide(
                    color: Colors.black26, width: 1), // Border for unselected
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submitTurf,
      child: Text(
        'Submit',
        style: TextStyle(
          fontSize: 18, // Font size of the text
          fontWeight: FontWeight.bold, // Font weight of the text
          color: Colors.white, // Text color
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent, // Button background color
        padding: EdgeInsets.symmetric(vertical: 10), // Padding for the button
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50), // Border radius
        ),
      ),
    );
  }
}
