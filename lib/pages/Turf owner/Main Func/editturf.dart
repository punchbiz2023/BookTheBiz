import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:reorderables/reorderables.dart';

class EditTurfPage extends StatefulWidget {
  final String turfId;

  const EditTurfPage({super.key, required this.turfId});

  @override
  _EditTurfPageState createState() => _EditTurfPageState();
}

class _EditTurfPageState extends State<EditTurfPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  String? _imageUrl;
  File? _newImageFile;
  List<String> _turfImages = [];
  List<File> _newImageFiles = [];
  bool _isosp = false;
  bool _isPriceMap = false;
  bool _isGettingLocation = false;
  bool _hasMultipleImages = false;
  Map<String, int> _price = {};
  final Map<String, TextEditingController> _priceControllers = {};
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
  String _selectedSlotType = 'Morning Slots';
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
  final List<String> _selectedMorningSlots = [];
  final List<String> _selectedEveningSlots = [];
  final List<String> _morningSlots = [
    '6:00 AM - 7:00 AM',
    '7:00 AM - 8:00 AM',
    '8:00 AM - 9:00 AM',
    '9:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
    '11:00 AM - 12:00 PM',
  ];

  final List<String> _eveningSlots = [
    '4:00 PM - 5:00 PM',
    '5:00 PM - 6:00 PM',
    '6:00 PM - 7:00 PM',
    '7:00 PM - 8:00 PM',
    '8:00 PM - 9:00 PM',
    '9:00 PM - 10:00 PM',
    
  ];

  final List<String> _customSlots = [];
  Set<String> selectedFacilities = {};
  Set<String> selectedGrounds = {};
  Set<String> selectedCustomSlots = {};
  Set<String> selectedMorningSlots = {};
  Set<String> selectedEveningSlots = {};
  List<dynamic> _allImages = [];

  @override
  void initState() {
    super.initState();
    _loadTurfDetails();
  }

  Future<void> _loadTurfDetails() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).get();
      if (!doc.exists) return;
      var turfData = doc.data() as Map<String, dynamic>;

      setState(() {
        _nameController.text = turfData['name'] ?? '';
        _descriptionController.text = turfData['description'] ?? '';
        _locationController.text = turfData['location'] ?? '';

        var priceData = turfData['price'];
        if (priceData is num) {
          _isPriceMap = false;
          _priceController.text = priceData.toString();
          _price.clear();
          _priceControllers.clear();
        } else if (priceData is Map<String, dynamic>) {
          _isPriceMap = true;
          _price = priceData.map((key, value) => MapEntry(key, (value as num).toInt()));
          _priceControllers.clear();
          _price.forEach((key, value) {
            _priceControllers[key] = TextEditingController(text: value.toString());
          });
        }

        _imageUrl = turfData['imageUrl'] ?? '';
        _turfImages = turfData['turfimages'] != null ? List<String>.from(turfData['turfimages']) : [];
        _hasMultipleImages = turfData.containsKey('turfimages');
        _isosp = turfData['isosp'] ?? false;
        selectedFacilities = turfData['facilities'] != null ? Set<String>.from(turfData['facilities']) : {};
        selectedGrounds = turfData['availableGrounds'] != null ? Set<String>.from(turfData['availableGrounds']) : {};

        // Fetch selected slots if they exist
        List<String>? fetchedSlots = turfData['selectedSlots'] != null
            ? List<String>.from(turfData['selectedSlots'])
            : null;

        // Assign fetched slots or initialize all slots if not found
        selectedMorningSlots = fetchedSlots != null
            ? Set<String>.from(fetchedSlots.where((slot) => _morningSlots.contains(slot)))
            : Set<String>.from(_morningSlots);

        selectedEveningSlots = fetchedSlots != null
            ? Set<String>.from(fetchedSlots.where((slot) => _eveningSlots.contains(slot)))
            : Set<String>.from(_eveningSlots);

        selectedCustomSlots = fetchedSlots != null
            ? Set<String>.from(fetchedSlots.where((slot) => !_morningSlots.contains(slot) && !_eveningSlots.contains(slot)))
            : {};

        // Build _allImages list
        _allImages = [];
        if (_imageUrl != null && _imageUrl!.isNotEmpty) _allImages.add(_imageUrl!);
        _allImages.addAll(_turfImages);
        _allImages.addAll(_newImageFiles);
      });
    } catch (e) {
      debugPrint('Error loading turf details: $e');
    }
  }

  Future<void> _pickImages() async {
    final pickedImages = await ImagePicker().pickMultiImage();
    if (pickedImages.isNotEmpty) {
      setState(() {
        final files = pickedImages.map((x) => File(x.path)).toList();
        _newImageFiles.addAll(files);
        _allImages.addAll(files);
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newImageFile = File(pickedFile.path);
        // If only one image mode, replace spotlight
        if (!_hasMultipleImages) {
          _allImages = [_newImageFile!];
        }
      });
    }
  }

  Future<List<String>> _uploadImages(List<File> images) async {
    List<String> urls = [];
    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      try {
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('turf_images/${widget.turfId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        UploadTask uploadTask = storageRef.putFile(image);
        TaskSnapshot snapshot = await uploadTask;
        String url = await snapshot.ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        throw Exception('Failed to upload image: $e');
      }
    }
    return urls;
  }

  Future<void> _saveTurfDetails() async {
    try {
      // --- Refactored image save logic ---
      // Separate images into URLs and Files
      List<String> urlImages = _allImages.whereType<String>().toList();
      List<File> fileImages = _allImages.whereType<File>().toList();
      // Upload new images
      List<String> uploadedUrls = [];
      if (fileImages.isNotEmpty) {
        uploadedUrls = await _uploadImages(fileImages);
      }
      // Merge URLs: keep order, replace File with uploaded URL
      List<String> finalImages = [];
      int uploadIdx = 0;
      for (var img in _allImages) {
        if (img is String) {
          finalImages.add(img);
        } else if (img is File) {
          finalImages.add(uploadedUrls[uploadIdx]);
          uploadIdx++;
        }
      }
      String? newImageUrl = finalImages.isNotEmpty ? finalImages.first : null;
      List<String> newTurfImages = finalImages.length > 1 ? finalImages.sublist(1) : [];
      // Save price as either a single number or a map of ground prices
      dynamic priceData;
      if (_price.isEmpty && _priceController.text.isNotEmpty) {
        priceData = double.tryParse(_priceController.text) ?? 0.0;
      } else {
        priceData = _price;
      }
      List<String> allSelectedSlots = [
        ...selectedMorningSlots,
        ...selectedEveningSlots,
        ...selectedCustomSlots,
      ];
      Map<String, dynamic> updateData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': priceData,
        'facilities': selectedFacilities.toList(),
        'availableGrounds': selectedGrounds.toList(),
        'isosp': _isosp,
        if (newImageUrl != null) 'imageUrl': newImageUrl,
        if (_hasMultipleImages) 'turfimages': newTurfImages,
        if (allSelectedSlots.isNotEmpty) 'selectedSlots': allSelectedSlots,
      };
      await FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).update(updateData);

      // Show success dialog instead of snackbar
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Turf details have been updated successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Return to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      // Show error dialog instead of snackbar
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Failed to save turf details. Please try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showLocationPickerDialog() async {
    final TextEditingController manualLocationController = TextEditingController();
    bool isGettingLocation = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Set Turf Location'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.my_location, color: Colors.teal),
                  title: Text('Use Current Location'),
                  subtitle: Text('Get precise location using GPS'),
                  onTap: () async {
      Navigator.pop(context);
                    await _updateLocation(useCurrentLocation: true);
                  },
                ),
                Divider(),
                Text(
                  'Enter Location Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: manualLocationController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter complete address (e.g., Street, Area, City, State)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.location_on, color: Colors.teal),
                    helperText: 'Please provide a detailed address for better visibility',
                    helperStyle: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tip: A detailed address helps users find your turf easily',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (manualLocationController.text.isNotEmpty) {
                  await _updateLocation(locationText: manualLocationController.text);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a location'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: Text('Save Location'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateLocation({bool useCurrentLocation = false, String? locationText}) async {
    try {
      if (useCurrentLocation) {
        // Check location permission first
        LocationPermission permission = await Geolocator.checkPermission();
        
        if (permission == LocationPermission.denied) {
          // Request permission
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Location permission is required to get current location'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          // Show dialog to open settings
          bool? shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_off,
                        color: Colors.orange,
                        size: 40,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Location Access Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Location permission is permanently denied. Please enable it in settings to get current location.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Open Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );

          if (shouldOpenSettings == true) {
            await Geolocator.openAppSettings();
          }
          return;
        }

        // Check if location services are enabled
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_disabled,
                        color: Colors.orange,
                        size: 40,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Location Services Disabled',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Please enable location services to get current location.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          return;
        }

        setState(() {
          _isGettingLocation = true;
        });

        // Get current position
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        locationText = '${position.latitude}, ${position.longitude}';
      }

      if (locationText != null) {
        await FirebaseFirestore.instance
            .collection('turfs')
            .doc(widget.turfId)
            .update({
          'location': locationText,
          'hasLocation': true,
        });

        setState(() {
          _locationController.text = locationText!;
        });

        // Show success dialog
        await showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 40,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Location Updated',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Your turf location has been successfully updated.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Widget _buildImageEditSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Turf Images',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade700,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        if (_allImages.isNotEmpty)
          Column(
            children: [
              // Spotlight image (first image, shown big)
              Container(
                width: double.infinity,
                height: 180,
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.amber, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.shade900.withOpacity(0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: Offset(2, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _allImages.first is String
                      ? Image.network(
                          _allImages.first,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                        )
                      : Image.file(
                          _allImages.first,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                        ),
                ),
              ),
              // All images as reorderable thumbnails (including the spotlight image)
              ReorderableWrap(
                spacing: 10,
                runSpacing: 10,
                needsLongPressDraggable: true,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    final img = _allImages.removeAt(oldIndex);
                    _allImages.insert(newIndex, img);
                  });
                },
                children: [
                  ..._allImages.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var img = entry.value;
                    return Stack(
                      key: ValueKey(img is String ? img : img.path),
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: img is String
                              ? Image.network(
                                  img,
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                )
                              : Image.file(
                                  img,
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _allImages.removeAt(idx);
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Icon(Icons.drag_handle, color: Colors.teal.shade700, size: 18),
                        ),
                      ],
                    );
                  }),
                  // Add image button at the end
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade300, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.shade900.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: Offset(2, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(Icons.add_a_photo, size: 28, color: Colors.teal.shade700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          // If no images, show only the add button
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.teal.shade300, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.shade900.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: Offset(2, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(Icons.add_a_photo, size: 36, color: Colors.teal.shade700),
              ),
            ),
          ),
        SizedBox(height: 8),
        Text(
          'Drag and drop to reorder images. The first image is the spotlight image.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Turf Details',style: TextStyle(color:Colors.white)),
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
              _hasMultipleImages
                  ? _buildImageEditSection()
                  : GestureDetector(
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
              _isPriceMap ? _buildMultiPriceFields() : _buildTextField(_priceController, 'Price'),
              SizedBox(height: 16),
              _buildFacilitiesSelection(),
              SizedBox(height: 16),
              _buildGroundsSelection(),
              SizedBox(height: 16),
              _buildDropdown(),
              SizedBox(height: 16),
              _buildSlotChips(),
              SizedBox(height: 16),
              SizedBox(height: 16),
              _buildIsospSwitch(),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _locationController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Enter location',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: Icon(Icons.location_on, color: Colors.teal),
                            ),
                            readOnly: true,
                          ),
                        ),
                        SizedBox(width: 10),
                        IconButton(
                          onPressed: _isGettingLocation ? null : _showLocationPickerDialog,
                          icon: _isGettingLocation
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                                  ),
                                )
                              : Icon(Icons.edit_location, color: Colors.teal.shade700),
                          tooltip: 'Edit Location',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Slot Type",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedSlotType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: ['Morning Slots', 'Evening Slots', 'Custom Slots']
              .map((type) => DropdownMenuItem(
            value: type,
            child: Text(type),
          ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedSlotType = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSlotChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedSlotType,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
        ),
        SizedBox(height: 8),
        if (_selectedSlotType == 'Morning Slots')
          _buildChips(_morningSlots, selectedMorningSlots)
        else if (_selectedSlotType == 'Evening Slots')
          _buildChips(_eveningSlots, selectedEveningSlots)
        else
          _buildCustomSlotSection(),
      ],
    );
  }

  Widget _buildChips(List<String> slots, Set<String> selectedSlots) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 6.0,
      children: slots.map((slot) {
        return ChoiceChip(
          label: Text(slot, style: TextStyle(fontWeight: FontWeight.w600)),
          selected: selectedSlots.contains(slot),
          selectedColor: Colors.teal.shade100,
          backgroundColor: Colors.white.withOpacity(0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.teal.shade200)),
          onSelected: (bool selected) {
            setState(() {
              if (selected) {
                selectedSlots.add(slot);
              } else {
                selectedSlots.remove(slot);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildCustomSlotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedCustomSlots.isNotEmpty)
          Wrap(
            spacing: 8.0,
            runSpacing: 6.0,
            children: selectedCustomSlots.map((slot) {
              return Chip(
                label: Text(slot, style: TextStyle(fontWeight: FontWeight.w600)),
                backgroundColor: Colors.teal.shade100,
                deleteIcon: Icon(Icons.close, size: 18, color: Colors.teal.shade900),
                onDeleted: () {
                  setState(() {
                    selectedCustomSlots.remove(slot);
                  });
                },
              );
            }).toList(),
          ),
        SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _showCustomSlotDialog,
          icon: Icon(Icons.add, color: Colors.white),
          label: Text("Add Custom Slot", style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _showCustomSlotDialog() async {
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("Select Custom Slot", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.access_time, color: Colors.teal),
                    title: Text("Start Time", style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text(
                      startTime != null ? startTime!.format(context) : "Select",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                    ),
                    onTap: () async {
                      TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startTime = picked;
                        });
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.access_time, color: Colors.teal),
                    title: Text("End Time", style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text(
                      endTime != null ? endTime!.format(context) : "Select",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                    ),
                    onTap: () async {
                      TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          endTime = picked;
                        });
                      }
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (startTime != null && endTime != null) {
                  String formattedSlot = "${startTime!.format(context)} - ${endTime!.format(context)}";
                  setState(() {
                    selectedCustomSlots.add(formattedSlot);
                  });
                }
                Navigator.pop(context);
              },
              child: Text("Add", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMultiPriceFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Prices for Different Grounds:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
        ..._priceControllers.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              controller: entry.value,
              decoration: InputDecoration(
                labelText: '${entry.key} Price',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          );
        }),
      ],
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
              label: Text(
                '$ground${_price.containsKey(ground) ? '\n(${_price[ground]})' : ''}',
                textAlign: TextAlign.center,
              ),
              selected: selectedGrounds.contains(ground),
              onSelected: (selected) async {
                if (selected) {
                  if (!_price.containsKey(ground)) {
                    int? enteredPrice = await _showPriceDialog(ground);
                    if (enteredPrice != null) {
                      setState(() {
                        _price[ground] = enteredPrice;
                        selectedGrounds.add(ground);
                      });
                    }
                  } else {
                    setState(() {
                      selectedGrounds.add(ground);
                    });
                  }
                } else {
                  setState(() {
                    selectedGrounds.remove(ground);
                    _price.remove(ground);
                  });
                }
              },
              backgroundColor: Colors.grey[300],
              selectedColor: Colors.teal,
              labelStyle: TextStyle(
                color: selectedGrounds.contains(ground) ? Colors.white : Colors.black,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  int? _getGroundPrice(String ground) {
    return _price[ground];
  }

  Future<int?> _showPriceDialog(String ground) async {
    TextEditingController priceController = TextEditingController();

    return await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.attach_money,
                    color: Colors.teal,
                    size: 40,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Set Price',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Enter price for $ground',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20),
                TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter amount',
                    prefixIcon: Icon(Icons.currency_rupee, color: Colors.teal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
          ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.teal, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
            ),
                    SizedBox(width: 10),
                    ElevatedButton(
              onPressed: () {
                int? price = int.tryParse(priceController.text);
                if (price != null && price > 0) {
                  Navigator.pop(context, price);
                } else {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Container(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(15),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.orange,
                                        size: 40,
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                    Text(
                                      'Invalid Price',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Please enter a valid price greater than 0',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'OK',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                  );
                }
              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ],
                ),
              ],
            ),
          ),
        );
      },
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