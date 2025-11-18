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
  final TextEditingController _customGroundController = TextEditingController();
  final List<String> _customAvailableGrounds = [];

  // Monthly Subscription Variables
  bool _supportsMonthlySubscription = false;
  String _selectedRefundPolicy = '';
  final TextEditingController _refundPolicyController = TextEditingController();
  final Map<String, double> _monthlySubscriptionPrices = {}; // Changed to Map for per-ground pricing
  final List<String> _selectedWorkingDays = [];

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
  
  // Slot definitions as in turfstats.dart
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
  final List<String> _selectedSlots = [];
  final List<String> _selectedAvailableGrounds = [];
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

  // Refund Policy Options
  final List<String> _refundPolicyOptions = [
    'No Refunds at the Time of Cancellation',
    '100% Refund at the Time of Cancellation',
    'No Cancellation between the Month Days',
    '50% - 75% Refund at the Time of Cancellations based on slots played'
  ];

  // Working Days Options
  final List<String> _workingDaysOptions = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
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

  String _selectedSlotType = 'Morning Slots';
  int? _anchorImageIndex;

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
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
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
          _anchorImageIndex = 0;
        }
      });
      if (_imageFiles.length > 1) {
        await _showAnchorImageDialog();
      }
    }
  }

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

    // Additional validation for monthly subscription
    if (_supportsMonthlySubscription) {
      if (_selectedRefundPolicy.isEmpty || _selectedWorkingDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please complete all monthly subscription fields')),
        );
        return;
      }
      
      // Check if all selected grounds have monthly prices
      bool allGroundsHavePrices = _selectedAvailableGrounds.every((ground) => 
          _monthlySubscriptionPrices.containsKey(ground));
      
      if (!allGroundsHavePrices) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please set monthly subscription price for all selected grounds')),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> imageUrls = await _uploadImages(_imageFiles);
      String userId = _auth.currentUser!.uid;
      DocumentReference turfRef = _firestore.collection('turfs').doc();
      String turfId = turfRef.id;

      String imageUrl = imageUrls.isNotEmpty ? imageUrls.first : '';
      List<String> turfImages = imageUrls.length > 1 ? imageUrls.sublist(1) : [];

      Map<String, dynamic> turfData = {
        'turfId': turfId,
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': _selectedGroundPrices,
        'imageUrl': imageUrl,
        'turfimages': turfImages,
        'facilities': _selectedFacilities,
        'availableGrounds': _selectedAvailableGrounds,
        'ownerId': userId,
        'isosp': _isosp,
        'location': _locationController.text,
        'hasLocation': true,
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
        'turf_status': 'Not Verified',
        'selectedSlots': _selectedSlots,
        // Monthly Subscription Fields
        'supportsMonthlySubscription': _supportsMonthlySubscription,
        'monthlySubscription': _supportsMonthlySubscription ? {
          'refundPolicy': _selectedRefundPolicy,
          'customRefundPolicy': _refundPolicyController.text.trim(),
          'monthlyPrices': _monthlySubscriptionPrices, // Store per-ground prices
          'workingDays': _selectedWorkingDays,
        } : null,
      };

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
                  style: TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Enter your location',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
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
    return WillPopScope(
      onWillPop: () async => await _showExitWarning(),
      child: Scaffold(
        backgroundColor: Colors.teal.shade50,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.teal.shade700,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () async {
                  bool shouldLeave = await _showExitWarning();
                  if (shouldLeave) Navigator.pop(context);
                },
              ),
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

                        _buildTopicTitle('Available Slots'),
                        _buildGlassContainer(_buildGroupedSlotChips()),
                        SizedBox(height: 16),

                        // Monthly Subscription Section
                        _buildMonthlySubscriptionSection(),
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
      ),
    );
  }

  // Monthly Subscription Section
  Widget _buildMonthlySubscriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopicTitle('Monthly Subscription'),
        _buildGlassContainer(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monthly Subscription Toggle
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support Monthly Subscription',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Allow customers to purchase monthly subscriptions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _supportsMonthlySubscription,
                      onChanged: (value) {
                        setState(() {
                          _supportsMonthlySubscription = value;
                          if (!value) {
                            _selectedRefundPolicy = '';
                            _refundPolicyController.clear();
                            _monthlySubscriptionPrices.clear();
                            _selectedWorkingDays.clear();
                          }
                        });
                      },
                      activeColor: Colors.teal,
                    ),
                  ],
                ),
              ),

              if (_supportsMonthlySubscription) ...[
                SizedBox(height: 16),

                // Refund Policy Section
                Text(
                  'Refund Policy',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                SizedBox(height: 8),

                // Quick Access Refund Policy Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _refundPolicyOptions.map((policy) {
                    final isSelected = _selectedRefundPolicy == policy;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRefundPolicy = policy;
                          _refundPolicyController.clear();
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                            colors: [Colors.teal.shade600, Colors.teal.shade400],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                              : null,
                          color: isSelected ? null : Colors.white.withOpacity(0.7),
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
                          policy,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.teal.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                SizedBox(height: 12),

                // Custom Refund Policy Input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.teal.withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.shade200.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: Offset(4, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _refundPolicyController,
                    maxLines: 3,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      hintText: 'Or write custom refund policy...',
                      hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _selectedRefundPolicy = '';
                      });
                    },
                  ),
                ),

                SizedBox(height: 16),

                // Monthly Subscription Prices for Each Ground
                Text(
                  'Monthly Subscription Prices',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                SizedBox(height: 8),

                // Display selected grounds with their monthly prices
                if (_selectedAvailableGrounds.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.teal.withOpacity(0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.shade200.withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: Offset(4, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: _selectedAvailableGrounds.map((ground) {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.teal.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  ground,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _monthlySubscriptionPrices.containsKey(ground)
                                      ? '₹${_monthlySubscriptionPrices[ground]?.toStringAsFixed(2)}'
                                      : 'Not set',
                                  style: TextStyle(
                                    color: _monthlySubscriptionPrices.containsKey(ground)
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Colors.teal,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  double? price = await showDialog<double>(
                                    context: context,
                                    builder: (context) => _MonthlyPriceInputDialog(
                                      groundName: ground,
                                      currentPrice: _monthlySubscriptionPrices[ground],
                                    ),
                                  );
                                  if (price != null) {
                                    setState(() {
                                      _monthlySubscriptionPrices[ground] = price;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 12),
                ] else ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade700),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please select grounds first to set monthly subscription prices',
                            style: TextStyle(
                              color: Colors.amber.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                ],

                SizedBox(height: 16),

                // Working Days Selection
                Text(
                  'Working Days',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _workingDaysOptions.map((day) {
                    final isSelected = _selectedWorkingDays.contains(day);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedWorkingDays.remove(day);
                          } else {
                            _selectedWorkingDays.add(day);
                          }
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                            colors: [Colors.teal.shade600, Colors.teal.shade400],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                              : null,
                          color: isSelected ? null : Colors.white.withOpacity(0.7),
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
                          day.substring(0, 3), // Show first 3 letters
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.teal.shade700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.teal.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade200.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 2,
            offset: Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.teal.withOpacity(0.2),
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
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintText: label,
          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          border: InputBorder.none,
        ),
        enabled: enabled,
      ),
    );
  }

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
          _buildChips(_morningSlots, _selectedSlots)
        else
          _buildChips(_eveningSlots, _selectedSlots),
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

  Widget _buildGroupedSlotChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            final isSelected = _selectedSlots.contains(slot);
            return FilterChip(
              label: Text(slot, style: TextStyle(color: isSelected ? Colors.white : Colors.teal)),
              selected: isSelected,
              selectedColor: Colors.teal,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSlots.add(slot);
                  } else {
                    _selectedSlots.remove(slot);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

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
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Icon(Icons.drag_handle, color: Colors.teal.shade700, size: 18),
                        ),
                      ],
                    );
                  }),
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
                  : null,
              color: isSelected ? null : Colors.white.withOpacity(0.7),
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

  Widget _buildAvailableGroundsChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8.0,
          children: [
            ..._availableGrounds.map((ground) {
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
                backgroundColor: Colors.white.withOpacity(0.7),
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
                      // Also remove monthly subscription price for this ground
                      _monthlySubscriptionPrices.remove(ground);
                    });
                  }
                },
              );
            }).toList(),
            ..._customAvailableGrounds.map((ground) {
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ground,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _selectedAvailableGrounds.contains(ground) ? Colors.white : Colors.teal.shade700,
                      ),
                    ),
                    SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _customAvailableGrounds.remove(ground);
                          _selectedAvailableGrounds.remove(ground);
                          _selectedGroundPrices.remove(ground);
                          // Also remove monthly subscription price for this ground
                          _monthlySubscriptionPrices.remove(ground);
                        });
                      },
                      child: Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ],
                ),
                selected: _selectedAvailableGrounds.contains(ground),
                selectedColor: Colors.teal.shade500,
                backgroundColor: Colors.white.withOpacity(0.7),
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
                      // Also remove monthly subscription price for this ground
                      _monthlySubscriptionPrices.remove(ground);
                    });
                  }
                },
              );
            }).toList(),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customGroundController,
                style: TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Add custom ground',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final customGround = _customGroundController.text.trim();
                if (customGround.isNotEmpty &&
                    !_availableGrounds.contains(customGround) &&
                    !_customAvailableGrounds.contains(customGround)) {
                  double? price = await showDialog<double>(
                    context: context,
                    builder: (context) => _PriceInputDialog(
                      groundName: customGround,
                      previousPrice: _selectedGroundPrices.isNotEmpty
                          ? _selectedGroundPrices.values.last
                          : null,
                    ),
                  );
                  if (price != null) {
                    setState(() {
                      _customAvailableGrounds.add(customGround);
                      _selectedAvailableGrounds.add(customGround);
                      _selectedGroundPrices[customGround] = price;
                    });
                    _customGroundController.clear();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
      ],
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
        
        // If monthly subscription is enabled, also ask for monthly price
        if (_supportsMonthlySubscription) {
          _fetchMonthlyPriceForGround(ground);
        }
      });
    }
  }

  // New method to fetch monthly subscription price for a ground
  Future<void> _fetchMonthlyPriceForGround(String ground) async {
    double? monthlyPrice = await showDialog<double>(
      context: context,
      builder: (context) => _MonthlyPriceInputDialog(
        groundName: ground,
        currentPrice: _monthlySubscriptionPrices[ground],
      ),
    );

    if (monthlyPrice != null) {
      setState(() {
        _monthlySubscriptionPrices[ground] = monthlyPrice;
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
    int countdown = 5;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Timer.periodic(Duration(seconds: 1), (timer) {
          if (countdown > 0) {
            setState(() {
              countdown--;
            });
          } else {
            timer.cancel();
          }
        });

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.red[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red, width: 2),
              ),
              title: Row(
                children: const [
                  Icon(Icons.warning, color: Colors.red),
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
                    Navigator.of(context).pop();
                    completer.complete(false);
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
                    Navigator.of(context).pop();
                    completer.complete(true);
                  }
                      : null,
                  child: Text(
                    'Acknowledge',
                    style: TextStyle(
                      color: Colors.green,
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
            'You have unsaved changes. If you go back now, your input will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Stay', style: TextStyle(color: Colors.teal)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Leave',style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    return result ?? false;
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
                  style: TextStyle(color: Colors.black87, fontSize: 16),
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

// New dialog for monthly subscription price input
class _MonthlyPriceInputDialog extends StatelessWidget {
  final String groundName;
  final double? currentPrice;

  const _MonthlyPriceInputDialog({required this.groundName, this.currentPrice});

  @override
  Widget build(BuildContext context) {
    final TextEditingController priceController = TextEditingController(
      text: currentPrice?.toStringAsFixed(2) ?? '',
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Monthly Subscription Price for $groundName',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
        textAlign: TextAlign.center,
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: TextField(
          controller: priceController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: Colors.black87, fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Enter Monthly Subscription Price',
            labelStyle: TextStyle(color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.teal),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.teal, width: 2),
            ),
            prefixText: '₹ ',
            prefixStyle: TextStyle(color: Colors.black87, fontSize: 16),
          ),
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
            'Set Price',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}