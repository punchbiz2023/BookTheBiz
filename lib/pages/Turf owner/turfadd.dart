import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';

class AddTurfPage extends StatefulWidget {
  @override
  _AddTurfPageState createState() => _AddTurfPageState();
}

class _AddTurfPageState extends State<AddTurfPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  LatLng? _pickedLocation;
  File? _imageFile;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  // Function to pick image from gallery
  Future<void> _pickImage() async {
    final pickedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _imageFile = File(pickedImage.path);
      });
    }
  }

  // Function to open Google Maps and select location
  Future<void> _pickLocation() async {
    Location location = Location();
    var currentLocation = await location.getLocation();
    LatLng initialPosition =
        LatLng(currentLocation.latitude!, currentLocation.longitude!);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectLocationPage(
          initialPosition: initialPosition,
          onSelectLocation: (selectedLocation) {
            setState(() {
              _pickedLocation = selectedLocation;
            });
          },
        ),
      ),
    );
  }

  // Function to upload image to Firebase Storage
  Future<String> _uploadImage(File image) async {
    Reference storageRef = _firebaseStorage
        .ref()
        .child('turf_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
    UploadTask uploadTask = storageRef.putFile(image);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Function to submit the turf details
  Future<void> _submitTurf() async {
    if (_nameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _pickedLocation == null ||
        _imageFile == null) {
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
        'location':
            GeoPoint(_pickedLocation!.latitude, _pickedLocation!.longitude),
        'imageUrl': imageUrl,
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
      backgroundColor: Color(0xff192028),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Add Turf', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding:
            EdgeInsets.symmetric(horizontal: size.width * 0.05, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Turf Name',
              maxLines: 1,
            ),
            SizedBox(height: 20),
            _buildLocationPicker(),
            SizedBox(height: 20),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              maxLines: 3,
            ),
            SizedBox(height: 20),
            _buildImagePicker(),
            SizedBox(height: 30),
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildLocationPicker() {
    return GestureDetector(
      onTap: _pickLocation,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white54),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            _pickedLocation == null
                ? 'Select Location (via Maps)'
                : 'Location Selected',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white54),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _imageFile == null
            ? Center(
                child: Text(
                  'Pick an Image',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  _imageFile!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submitTurf,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 15),
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        'Submit Turf',
        style: TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }
}

// Map Selection Page
class SelectLocationPage extends StatefulWidget {
  final LatLng initialPosition;
  final Function(LatLng) onSelectLocation;
  SelectLocationPage({
    required this.initialPosition,
    required this.onSelectLocation,
  });
  @override
  _SelectLocationPageState createState() => _SelectLocationPageState();
}

class _SelectLocationPageState extends State<SelectLocationPage> {
  LatLng? _pickedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Location'),
        backgroundColor: Colors.blueAccent,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.initialPosition,
          zoom: 16,
        ),
        onTap: (location) {
          setState(() {
            _pickedLocation = location;
          });
        },
        markers: _pickedLocation == null
            ? {}
            : {
                Marker(
                  markerId: MarkerId('picked-location'),
                  position: _pickedLocation!,
                ),
              },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.check),
        onPressed: () {
          if (_pickedLocation != null) {
            widget.onSelectLocation(_pickedLocation!);
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}
