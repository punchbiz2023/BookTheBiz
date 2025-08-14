import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:reorderables/reorderables.dart';

class AddTurfPage extends StatefulWidget {
  const AddTurfPage({super.key});

  @override
  _AddTurfPageState createState() => _AddTurfPageState();
}

class _AddTurfPageState extends State<AddTurfPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final List<File> _imageFiles = [];
  bool _isLoading = false;
  Position? _currentPosition;
  bool _isGettingLocation = false;
  final Map<String, double> _selectedGroundPrices = {};
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isosp = false;
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;

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
  final List<String> _selectedMorningSlots = [];
  final List<String> _selectedEveningSlots = [];
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

  final List<String> _selectedAvailableGrounds = [];
  String _selectedSlotType = 'Morning Slots';

  // 1. Add these fields to your _AddTurfPageState:
  int? _anchorImageIndex; // For spotlight image

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
      setState(() {
      _isGettingLocation = true;
    });

    try {
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
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Location Permission Required'),
            content: Text('Location permission is permanently denied. Please enable it in settings to get current location.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Geolocator.openAppSettings();
                },
                child: Text('Open Settings'),
              ),
            ],
          ),
        );
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enable location services to get current location'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _locationController.text = '${position.latitude}, ${position.longitude}';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _pickImages() async {
    final pickedImages = await _picker.pickMultiImage();
    if (pickedImages.isNotEmpty) {
      setState(() {
        _imageFiles.addAll(pickedImages.map((x) => File(x.path)));
        if (_anchorImageIndex == null && _imageFiles.isNotEmpty) {
          _anchorImageIndex = 0; // Default to first image
        }
      });
      if (_imageFiles.length > 1) {
        await _showAnchorImageDialog();
      }
    }
  }

  // 3. Add this method to show anchor/spotlight image selection dialog:
  Future<void> _showAnchorImageDialog() async {
    int? selected = _anchorImageIndex ?? 0;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Spotlight Image'),
          content: SizedBox(
            width: 320,
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageFiles.length,
              itemBuilder: (context, idx) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selected = idx;
                    });
                    Navigator.of(context).pop();
                    setState(() {
                      _anchorImageIndex = selected;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected == idx ? Colors.teal : Colors.transparent,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _imageFiles[idx],
                            width: 120,
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (selected == idx)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(Icons.star, color: Colors.amber, size: 28),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<List<String>> _uploadImages(List<File> images) async {
    List<String> urls = [];
    for (int i = 0; i < images.length; i++) {
      final image = images[i];
    try {
      Reference storageRef = _firebaseStorage
          .ref()
            .child('turf_images/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
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

  Future<void> _submitTurf() async {
    if (_nameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _imageFiles.isEmpty ||
        _selectedFacilities.isEmpty ||
        _selectedAvailableGrounds.isEmpty ||
        _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please complete all fields including location and images')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> imageUrls = await _uploadImages(_imageFiles);
      String userId = _auth.currentUser!.uid;
      DocumentReference turfRef = _firestore.collection('turfs').doc();
      String turfId = turfRef.id;

      // Spotlight image is always the first image
      String imageUrl = imageUrls.isNotEmpty ? imageUrls.first : '';
      List<String> turfImages = imageUrls.length > 1 ? imageUrls.sublist(1) : [];

      Map<String, dynamic> turfData = {
        'turfId': turfId,
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': _selectedGroundPrices,
        'imageUrl': imageUrl, // Spotlight image as string
        'turfimages': turfImages, // Remaining images as List<String>
        'facilities': _selectedFacilities,
        'availableGrounds': _selectedAvailableGrounds,
        'ownerId': userId,
        'isosp': _isosp,
        'location': _locationController.text,
        'hasLocation': true,
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
      };
      List<String> selectedSlots = [];
      selectedSlots.addAll(_selectedMorningSlots);
      selectedSlots.addAll(_selectedEveningSlots);
      selectedSlots.addAll(_customSlots);
      if (selectedSlots.isNotEmpty) {
        turfData['selectedSlots'] = selectedSlots;
      }

      await turfRef.set(turfData);

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

  Future<void> _showLocationPickerDialog() async {
    final TextEditingController manualLocationController = TextEditingController();
    String selectedArea = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Choose Location'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.my_location, color: Colors.teal),
                  title: Text('Use Current Location'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _getCurrentLocation();
                  },
                ),
                Divider(),
                Text(
                  'Popular Areas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildLocationOption('Koramangala', setState, selectedArea),
                        _buildLocationOption('Indiranagar', setState, selectedArea),
                        _buildLocationOption('Whitefield', setState, selectedArea),
                        _buildLocationOption('Electronic City', setState, selectedArea),
                        _buildLocationOption('Marathahalli', setState, selectedArea),
                        _buildLocationOption('HSR Layout', setState, selectedArea),
                        _buildLocationOption('BTM Layout', setState, selectedArea),
                        _buildLocationOption('Jayanagar', setState, selectedArea),
                        _buildLocationOption('JP Nagar', setState, selectedArea),
                        _buildLocationOption('Bannerghatta', setState, selectedArea),
                      ],
                    ),
                  ),
                ),
                Divider(),
                Text(
                  'Or Enter Location Manually',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: manualLocationController,
                  decoration: InputDecoration(
                    hintText: 'Enter your location',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.location_on, color: Colors.teal),
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
              onPressed: () {
                if (selectedArea.isNotEmpty) {
                  _locationController.text = selectedArea;
                  Navigator.pop(context);
                } else if (manualLocationController.text.isNotEmpty) {
                  _locationController.text = manualLocationController.text;
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please select or enter a location'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationOption(String location, StateSetter setState, String selectedArea) {
    bool isSelected = location == selectedArea;
    return InkWell(
      onTap: () {
        setState(() {
          selectedArea = location;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.teal : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on,
              color: isSelected ? Colors.teal : Colors.grey,
              size: 20,
            ),
            SizedBox(width: 12),
            Text(
              location,
              style: TextStyle(
                color: isSelected ? Colors.teal.shade700 : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.teal,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50, // Light teal background for contrast
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.teal.shade700,
            title: Text(
              'Add Turf',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            floating: true,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildImagePicker(),
                      SizedBox(height: 16),

                      _buildGlassTextField(
                        controller: _nameController,
                        label: 'Turf Name',
                      ),
                      SizedBox(height: 16),

                      _buildGlassTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        maxLines: 3,
                      ),
                      SizedBox(height: 16),

                      _buildLocationSection(),
                      SizedBox(height: 16),

                      _buildTopicTitle('Available Grounds'),
                      _buildGlassContainer(_buildAvailableGroundsChips()),
                      SizedBox(height: 16),

                      _buildTopicTitle('Facilities'),
                      _buildGlassContainer(_buildFacilitiesChips()),
                      SizedBox(height: 16),

                      _buildDropdown(),
                      SizedBox(height: 16),

                      _buildGlassContainer(_buildSlotChips()),
                      SizedBox(height: 16),

                      _buildIsospCheckbox(),
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

// 🟢 Glassmorphic Text Field
  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15), // Glass effect
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.teal.withOpacity(0.5), width: 2), // Stronger border
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade200.withOpacity(0.2), // Darker outer shadow
            blurRadius: 12,
            spreadRadius: 2,
            offset: Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.teal.withOpacity(0.2), // Soft inner glow
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(-2, -2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintText: label,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15),
          border: InputBorder.none,
        ),
        enabled: enabled,
      ),
    );
  }

// 🟢 Glassmorphic Container (Reusable for sections)
  Widget _buildGlassContainer(Widget child) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade900.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(2, 4),
          ),
        ],
      ),
      child: child,
    );
  }

// 🟢 Topic Title Styling
  Widget _buildTopicTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.teal.shade700,
      ),
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Slot Type",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedSlotType,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        if (_selectedSlotType == 'Morning Slots')
          _buildChips(_morningSlots, _selectedMorningSlots)
        else if (_selectedSlotType == 'Evening Slots')
          _buildChips(_eveningSlots, _selectedEveningSlots)
        else
          _buildCustomSlotSection(),
      ],
    );
  }

  Widget _buildChips(List<String> slots, List<String> selectedSlots) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: slots.map((slot) {
        return ChoiceChip(
          label: Text(slot),
          selected: selectedSlots.contains(slot),
          shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade400)),
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
        if (_customSlots.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _customSlots.map((slot) {
                  return Chip(
                    label: Text(slot),
                    deleteIcon: Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _customSlots.remove(slot);
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _showCustomSlotDialog,
          icon: Icon(Icons.add),
          label: Text("Add Custom Slot"),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          title: Text("Select Custom Slot"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.access_time),
                    title: Text("Start Time"),
                    trailing: Text(
                      startTime != null ? startTime!.format(context) : "Select",
                      style: TextStyle(fontWeight: FontWeight.w600),
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
                    leading: Icon(Icons.access_time),
                    title: Text("End Time"),
                    trailing: Text(
                      endTime != null ? endTime!.format(context) : "Select",
                      style: TextStyle(fontWeight: FontWeight.w600),
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
                  String formattedSlot =
                      "${startTime!.format(context)} - ${endTime!.format(context)}";
                  setState(() {
                    _customSlots.add(formattedSlot);
                  });
                }
                Navigator.pop(context);
              },
              child: Text("Add"),
            ),
          ],
        );
      },
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

// 🟢 Enhanced Image Picker with Glassmorphic Effect
  Widget _buildImagePicker() {
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
        if (_imageFiles.isNotEmpty)
          Column(
            children: [
              // Spotlight image (always the first image)
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
                child: Stack(
          children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(
                        _imageFiles.first,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 180,
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.star, color: Colors.white, size: 20),
                            SizedBox(width: 6),
            Text(
                              'Spotlight Image',
              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
              ),
            ),
          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // All images as reorderable thumbnails (including the spotlight image)
              ReorderableWrap(
                spacing: 10,
                runSpacing: 10,
                needsLongPressDraggable: true,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    final img = _imageFiles.removeAt(oldIndex);
                    _imageFiles.insert(newIndex, img);
                  });
                },
                children: [
                  ..._imageFiles.asMap().entries.map((entry) {
                    int idx = entry.key;
                    File img = entry.value;
                    return Stack(
                      key: ValueKey(img.path),
                      children: [
                        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
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
                                _imageFiles.removeAt(idx);
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
                        // Drag handle
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


// 🟢 Enhanced Choice Chips with Gradient & Shadow
  Widget _buildFacilitiesChips() {
    return Wrap(
      spacing: 8,
      children: _facilities.map((facility) {
        final isSelected = _selectedFacilities.contains(facility);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedFacilities.remove(facility);
              } else {
                _selectedFacilities.add(facility);
              }
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            margin: EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                colors: [Colors.teal.shade600, Colors.teal.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null, // Apply gradient only when selected
              color: isSelected ? null : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.teal.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.2),
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: Offset(2, 4),
                ),
              ],
            ),
            child: Text(
              facility,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.teal.shade700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }


// 🟢 Enhanced Available Grounds Chips with Gradient & Hover Effect
  Widget _buildAvailableGroundsChips() {
    return Wrap(
      spacing: 8.0,
      children: _availableGrounds.map((ground) {
        return ChoiceChip(
          label: Text(
            ground,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _selectedAvailableGrounds.contains(ground) ? Colors.white : Colors.teal.shade700,
            ),
          ),
          selected: _selectedAvailableGrounds.contains(ground),
          selectedColor: Colors.teal.shade500,
          backgroundColor: Colors.white.withOpacity(0.3),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.teal.shade300),
          ),
          onSelected: (bool selected) async {
            if (selected) {
              await _fetchPriceForGround(ground);
            } else {
              setState(() {
                _selectedAvailableGrounds.remove(ground);
                _selectedGroundPrices.remove(ground);
              });
            }
          },
        );
      }).toList(),
    );
  }



  Future<void> _fetchPriceForGround(String ground) async {
    double? price = await showDialog<double>(
      context: context,
      builder: (context) => _PriceInputDialog(
        groundName: ground,
        previousPrice: _selectedGroundPrices.isNotEmpty
            ? _selectedGroundPrices.values.last
            : null,
      ),
    );

    if (price != null) {
      setState(() {
        _selectedAvailableGrounds.add(ground);
        _selectedGroundPrices[ground] = price;
      });
    }
  }

  Widget _buildIsospCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _isosp,
          onChanged: (value) async {
            if (value == true) {
              bool acknowledged = await _showIsospWarning();
              if (acknowledged) {
                setState(() {
                  _isosp = true;
                });
              }
            } else {
              setState(() {
                _isosp = false;
              });
            }
          },
        ),
        Text('Accept On Spot Payment'),
      ],
    );
  }

  Future<bool> _showIsospWarning() async {
    Completer<bool> completer = Completer();
    bool acknowledged = false;
    int countdown = 5; // Initial countdown value

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing the dialog by tapping outside
      builder: (context) {
        // Timer to update the countdown every second
        Timer.periodic(Duration(seconds: 1), (timer) {
          if (countdown > 0) {
            setState(() {
              countdown--;
            });
          } else {
            timer.cancel(); // Stop the timer when countdown reaches 0
          }
        });

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.red[50], // Light red background
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red, width: 2), // Red border
              ),
              title: Row(
                children: const [
                  Icon(Icons.warning, color: Colors.red), // Warning icon
                  SizedBox(width: 8),
                  Text(
                    'Warning',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 16),
                  if (countdown > 0)
                    Text(
                      'By enabling On-the-Spot Payment (OSP), you acknowledge that if a user books a turf using OSP and fails to show up, you are fully responsible for any losses or inconveniences caused. ',
                      style: TextStyle(
                        color: Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                    completer.complete(false); // Return false for cancellation
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: countdown == 5
                      ? () {
                    acknowledged = true;
                    Navigator.of(context).pop(); // Close the dialog
                    completer.complete(true); // Return true for acknowledgment
                  }
                      : null, // Disable the button if countdown > 0
                  child: Text(
                    'Acknowledge',
                    style: TextStyle(
                      color: Colors.green, // Green when enabled, grey when disabled
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    return completer.future.then((value) => acknowledged);
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _submitTurf,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.teal.shade700, Colors.teal.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.shade900.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Submit',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
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
                child: _buildGlassTextField(
                  controller: _locationController,
                  label: 'Enter Location',
                  enabled: !_isGettingLocation,
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
                    : Icon(Icons.location_on, color: Colors.teal.shade700),
                tooltip: 'Choose Location',
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Choose your turf location from popular areas or enter manually',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceInputDialog extends StatelessWidget {
  final String groundName;
  final double? previousPrice;

  const _PriceInputDialog({required this.groundName, this.previousPrice});

  @override
  Widget build(BuildContext context) {
    final TextEditingController priceController = TextEditingController();
    bool isChecked = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Set Price for $groundName',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
            textAlign: TextAlign.center,
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Enter Price',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.teal),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.teal, width: 2),
                    ),
                  ),
                ),
                if (previousPrice != null)
                  Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        onChanged: (value) {
                          setState(() {
                            isChecked = value ?? false;
                            if (isChecked) {
                              priceController.text = previousPrice!.toStringAsFixed(2);
                            } else {
                              priceController.clear();
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Same as ${previousPrice!.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, null);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                double? price = double.tryParse(priceController.text);
                if (price != null) {
                  Navigator.pop(context, price);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                previousPrice == null ? 'Next' : 'Finish',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}