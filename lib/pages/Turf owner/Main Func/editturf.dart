import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:reorderables/reorderables.dart';
import 'package:intl/intl.dart';

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
  Set<String> selectedFacilities = {};
  Set<String> selectedGrounds = {};
  final TextEditingController _customGroundController = TextEditingController();
  final List<String> _customAvailableGrounds = [];
  // Slot definitions as in turfadd.dart
  static const List<String> earlyMorningSlots = [
    '12:00 AM - 1:00 AM',
    '1:00 AM - 2:00 AM',
    '2:00 AM - 3:00 AM',
    '3:00 AM - 4:00 AM',
    '4:00 AM - 5:00 AM',
  ];
  static const List<String> morningSlots = [
    '5:00 AM - 6:00 AM',
    '6:00 AM - 7:00 AM',
    '7:00 AM - 8:00 AM',
    '8:00 AM - 9:00 AM',
    '9:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
  ];
  static const List<String> afternoonSlots = [
    '12:00 PM - 1:00 PM',
    '1:00 PM - 2:00 PM',
    '2:00 PM - 3:00 PM',
    '3:00 PM - 4:00 PM',
    '4:00 PM - 5:00 PM',
  ];
  static const List<String> eveningSlots = [
    '5:00 PM - 6:00 PM',
    '6:00 PM - 7:00 PM',
    '7:00 PM - 8:00 PM',
    '8:00 PM - 9:00 PM',
    '9:00 PM - 10:00 PM',
    '10:00 PM - 11:00 PM',
  ];
  Set<String> selectedSlots = {};
  List<dynamic> _allImages = [];
  String? _turfStatus;
  String? _rejectionReason;
  DateTime? _rejectedAt;

  // Store original values to track changes
  String? _originalName;
  String? _originalDescription;
  String? _originalLocation;
  Map<String, int>? _originalPrice;
  Set<String>? _originalFacilities;
  Set<String>? _originalGrounds;
  String? _originalImageUrl;
  List<String>? _originalTurfImages;
  bool? _originalIsosp;
  Set<String>? _originalSlots;

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

        // Store original values
        _originalName = turfData['name'];
        _originalDescription = turfData['description'];
        _originalLocation = turfData['location'];

        var priceData = turfData['price'];
        if (priceData is num) {
          _isPriceMap = false;
          _priceController.text = priceData.toString();
          _price.clear();
          _priceControllers.clear();
          _originalPrice = null;
        } else if (priceData is Map<String, dynamic>) {
          _isPriceMap = true;
          _price = priceData.map((key, value) => MapEntry(key, (value as num).toInt()));
          _priceControllers.clear();
          _price.forEach((key, value) {
            _priceControllers[key] = TextEditingController(text: value.toString());
          });
          // Store original price map
          _originalPrice = Map<String, int>.from(_price);
        }

        _imageUrl = turfData['imageUrl'] ?? '';
        _turfImages = turfData['turfimages'] != null ? List<String>.from(turfData['turfimages']) : [];
        _hasMultipleImages = turfData.containsKey('turfimages');
        _isosp = turfData['isosp'] ?? false;
        
        // Store original values
        _originalImageUrl = turfData['imageUrl'];
        _originalTurfImages = List<String>.from(_turfImages);
        _originalIsosp = _isosp;
        
        selectedFacilities = turfData['facilities'] != null ? Set<String>.from(turfData['facilities']) : {};
        selectedGrounds = turfData['availableGrounds'] != null ? Set<String>.from(turfData['availableGrounds']) : {};
        
        // Store original values
        _originalFacilities = Set<String>.from(selectedFacilities);
        _originalGrounds = Set<String>.from(selectedGrounds);

        // Fetch selected slots if they exist
        List<String>? fetchedSlots = turfData['selectedSlots'] != null
            ? List<String>.from(turfData['selectedSlots'])
            : null;
        selectedSlots = fetchedSlots != null ? Set<String>.from(fetchedSlots) : {};
        
        // Store original slots
        _originalSlots = Set<String>.from(selectedSlots);

        // Load rejection information
        _turfStatus = turfData['turf_status'] ?? 'Not Verified';
        _rejectionReason = turfData['rejectionReason'];
        if (turfData['rejectedAt'] != null) {
          _rejectedAt = (turfData['rejectedAt'] as Timestamp).toDate();
        }

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

  // Check if any critical fields have been changed
  bool _hasCriticalChanges() {
    // Check if name changed
    if (_nameController.text != _originalName) return true;
    
    // Check if description changed
    if (_descriptionController.text != _originalDescription) return true;
    
    // Check if location changed
    if (_locationController.text != _originalLocation) return true;
    
    // Check if facilities changed
    if (!setEquals(selectedFacilities, _originalFacilities ?? {})) return true;
    
    // Check if grounds changed
    if (!setEquals(selectedGrounds, _originalGrounds ?? {})) return true;
    
    // Check if price changed
    if (_isPriceMap) {
      if (_originalPrice == null) return true;
      if (_price.length != _originalPrice!.length) return true;
      for (var ground in _price.keys) {
        if (!_originalPrice!.containsKey(ground) || _originalPrice![ground] != _price[ground]) {
          return true;
        }
      }
    } else {
      if (_originalPrice != null) return true;
      if (double.tryParse(_priceController.text) != double.tryParse(_originalPrice?.toString() ?? '0')) {
        return true;
      }
    }
    
    // Check if on-spot payment changed
    if (_isosp != _originalIsosp) return true;
    
    // Check if slots changed
    if (!setEquals(selectedSlots, _originalSlots ?? {})) return true;
    
    // Check if spotlight image changed
    if (_newImageFile != null) return true;
    
    // Check if gallery images changed
    if (_newImageFiles.isNotEmpty) return true;
    if (_allImages.length != (_originalImageUrl != null ? 1 : 0) + (_originalTurfImages?.length ?? 0)) {
      return true;
    }
    
    return false;
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

  Future<void> _reapplyForApproval() async {
    try {
      await FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).update({
        'turf_status': 'Not Verified',
        'rejectionReason': FieldValue.delete(),
        'rejectedAt': FieldValue.delete(),
        'rejectedBy': FieldValue.delete(),
        'reappliedAt': FieldValue.serverTimestamp(),
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
                  'Re-application Submitted!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Your turf has been re-submitted for admin approval. You will be notified once it\'s reviewed.',
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

      // Reload turf details to update the status
      await _loadTurfDetails();
    } catch (e) {
      // Show error dialog
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
                  'Failed to re-apply for approval. Please try again.',
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

  Future<void> _saveTurfDetails() async {
    try {
      // Ensure latest prices are captured from controllers before saving
      if (_isPriceMap) {
        final Map<String, int> updatedPriceMap = {};
        _priceControllers.forEach((ground, controller) {
          final parsed = int.tryParse(controller.text.trim());
          if (parsed != null) {
            updatedPriceMap[ground] = parsed;
          }
        });
        // Also include any prices added via chips but missing controllers (fallback)
        _price.forEach((ground, value) {
          if (!updatedPriceMap.containsKey(ground)) {
            updatedPriceMap[ground] = value;
          }
        });
        _price = updatedPriceMap;
      }

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
      if (!_isPriceMap) {
        // Single price mode
        priceData = double.tryParse(_priceController.text) ?? 0.0;
      } else {
        // Multi-price mode (per ground)
        priceData = _price;
      }
      List<String> allSelectedSlots = selectedSlots.toList();
      
      // Check if critical changes were made that require re-approval
      bool needsReapproval = _hasCriticalChanges();
      
      Map<String, dynamic> updateData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': priceData,
        'facilities': selectedFacilities.toList(),
        'availableGrounds': selectedGrounds.toList(),
        'isosp': _isosp,
        if (newImageUrl != null) 'imageUrl': newImageUrl,
        if (_hasMultipleImages) 'turfimages': newTurfImages,
        'selectedSlots': allSelectedSlots,
      };
      
      // If critical changes were made and turf was previously verified, change status back to Not Verified
      if (needsReapproval && _turfStatus == 'Verified') {
        updateData['turf_status'] = 'Not Verified';
        updateData['lastModifiedAt'] = FieldValue.serverTimestamp();
      }
      
      await FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).update(updateData);

      // Show success dialog instead of snackbar
      String message;
      if (needsReapproval && _turfStatus == 'Verified') {
        message = 'Turf details have been updated successfully. Since you made changes to critical information, your turf has been set to "Not Verified" status and requires admin approval again.';
      } else {
        message = 'Turf details have been updated successfully.';
      }

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
                    color: needsReapproval && _turfStatus == 'Verified' 
                        ? Colors.orange.shade50 
                        : Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    needsReapproval && _turfStatus == 'Verified' 
                        ? Icons.warning_amber 
                        : Icons.check_circle,
                    color: needsReapproval && _turfStatus == 'Verified' 
                        ? Colors.orange 
                        : Colors.green,
                    size: 40,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  needsReapproval && _turfStatus == 'Verified' 
                      ? 'Update Pending Approval' 
                      : 'Success!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: needsReapproval && _turfStatus == 'Verified' 
                        ? Colors.orange 
                        : Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  message,
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
                    backgroundColor: needsReapproval && _turfStatus == 'Verified' 
                        ? Colors.orange 
                        : Colors.teal,
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

  Widget _buildRejectionReasonCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cancel_outlined,
                  color: Colors.red.shade700,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Turf Rejected',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                    if (_rejectedAt != null)
                      Text(
                        'Rejected on ${DateFormat('MMM dd, yyyy').format(_rejectedAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Rejection reason
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reason for Rejection:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _rejectionReason!,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _reapplyForApproval,
                  icon: Icon(Icons.refresh, color: Colors.white, size: 20),
                  label: Text(
                    'Re-apply for Approval',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Please make the necessary changes based on the feedback above and click "Re-apply for Approval" to submit your turf for review again.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
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
    return WillPopScope(
      onWillPop: () async => await _showExitWarning(),
      child: Scaffold(
      appBar: AppBar(
        title: Text('Edit Turf Details',style: TextStyle(color:Colors.white)),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveTurfDetails,
          ),
        ],
        bottom: _turfStatus != null ? PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _turfStatus == 'Verified' ? Icons.check_circle : 
                  _turfStatus == 'Disapproved' ? Icons.cancel : Icons.pending,
                  color: _turfStatus == 'Verified' ? Colors.green : 
                         _turfStatus == 'Disapproved' ? Colors.red : Colors.orange,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Status: ${_turfStatus ?? 'Unknown'}',
                  style: TextStyle(
                    color: _turfStatus == 'Verified' ? Colors.green : 
                           _turfStatus == 'Disapproved' ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ) : null,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            bool shouldLeave = await _showExitWarning();
            if (shouldLeave) Navigator.pop(context);
          },
        ),
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
              // Show rejection reason if turf is disapproved
              if (_turfStatus == 'Disapproved' && _rejectionReason != null)
                _buildRejectionReasonCard(),
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
              _buildGroupedSlotChips(),
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
      ),
    );
  }

  Widget _buildGroupedSlotChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Available Slots', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
        SizedBox(height: 8),
        _buildSlotChipsGroup('Early Morning', earlyMorningSlots),
        SizedBox(height: 8),
        _buildSlotChipsGroup('Morning', morningSlots),
        SizedBox(height: 8),
        _buildSlotChipsGroup('Afternoon', afternoonSlots),
        SizedBox(height: 8),
        _buildSlotChipsGroup('Evening', eveningSlots),
      ],
    );
  }

  Widget _buildSlotChipsGroup(String label, List<String> slots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
        SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: slots.map((slot) {
            final isSelected = selectedSlots.contains(slot);
            return FilterChip(
              label: Text(slot, style: TextStyle(color: isSelected ? Colors.white : Colors.teal)),
              selected: isSelected,
              selectedColor: Colors.teal,
              onSelected: (selected) {
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
        ),
      ],
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
          children: [
            ...availableGrounds.map((ground) {
              return ChoiceChip(
                label: Text(
                  '$ground\n${_price.containsKey(ground) ? '(${_price[ground]})' : ''}',
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
            }),
            ..._customAvailableGrounds.map((ground) {
              final isSelected = selectedGrounds.contains(ground);
              return InputChip(
                label: Text(
                  '$ground\n${_price.containsKey(ground) ? '(${_price[ground]})' : ''}',
                  textAlign: TextAlign.center,
                ),
                selected: isSelected,
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
                onDeleted: () {
                  setState(() {
                    _customAvailableGrounds.remove(ground);
                    selectedGrounds.remove(ground);
                    _price.remove(ground);
                  });
                },
                deleteIcon: Icon(Icons.close, size: 18, color: Colors.red),
                selectedColor: Colors.teal,
                backgroundColor: Colors.grey[300],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                ),
              );
            }),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customGroundController,
                decoration: InputDecoration(
                  hintText: 'Add custom ground',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final customGround = _customGroundController.text.trim();
                if (customGround.isNotEmpty &&
                    !availableGrounds.contains(customGround) &&
                    !_customAvailableGrounds.contains(customGround)) {
                  int? enteredPrice = await _showPriceDialog(customGround);
                  if (enteredPrice != null) {
                    setState(() {
                      _customAvailableGrounds.add(customGround);
                      selectedGrounds.add(customGround);
                      _price[customGround] = enteredPrice;
                    });
                    _customGroundController.clear();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Add'),
            ),
          ],
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
                    Icons.currency_rupee,
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

  Future<bool> _showExitWarning() async {
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Discard changes?'),
            ],
          ),
          content: Text(
            'You have unsaved changes. If you go back now, your edits will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Stay', style: TextStyle(color: Colors.teal)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Leave', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}