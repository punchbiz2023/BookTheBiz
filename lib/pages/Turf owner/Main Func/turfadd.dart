import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Authentication
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
  final TextEditingController _priceController = TextEditingController(); // Price controller
  File? _imageFile;
  bool _isLoading = false;
  final Map<String, double> _selectedGroundPrices = {};
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Initialize FirebaseAuth

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

  Future<void> _submitTurf() async {
    if (_nameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _imageFile == null ||
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
      // Upload the image and get the URL
      String imageUrl = await _uploadImage(_imageFile!);
      String userId = _auth.currentUser!.uid; // Get the current user UID
      DocumentReference turfRef = _firestore.collection('turfs').doc(); // Create a new document reference
      String turfId = turfRef.id; // Use the document ID as turfId

      // Prepare the data to be saved in Firestore
      Map<String, dynamic> turfData = {
        'turfId': turfId,
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': _selectedGroundPrices,
        'imageUrl': imageUrl,
        'facilities': _selectedFacilities,
        'availableGrounds': _selectedAvailableGrounds,
        'ownerId': userId,
      };

      // Add the document with the turfId as the document ID
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

    @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white, // Background color for white theme
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            title: Text('Add Turf', style: TextStyle(color: Colors.grey[700],fontWeight: FontWeight.bold)),
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
                      _buildTopicTitle('Available Grounds'),
                      _buildAvailableGroundsChips(),

                      SizedBox(height: 16),
                      _buildTopicTitle('Facilities'),
                      _buildFacilitiesChips(),
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
            style: TextStyle(color: Colors.grey[500]),
          ),
        )
            : ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            _imageFile!,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildFacilitiesChips() {
    return Wrap(
      spacing: 8,
      children: _facilities.map((facility) {
        return ChoiceChip(
          label: Text(facility),
          selected: _selectedFacilities.contains(facility),
          onSelected: (isSelected) {
            setState(() {
              if (isSelected) {
                _selectedFacilities.add(facility);
              } else {
                _selectedFacilities.remove(facility);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildAvailableGroundsChips() {
    return Wrap(
      spacing: 8.0,
      children: _availableGrounds.map((ground) {
        return ChoiceChip(
          label: Text(ground),
          selected: _selectedAvailableGrounds.contains(ground),
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
  Widget _buildTopicTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
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
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: () {
        print('Selected Ground Prices:');
        _selectedGroundPrices.forEach((ground, price) {
          print('Ground: $ground, Price: \$${price.toStringAsFixed(2)}');
        });
        _submitTurf(); // Proceed with the submission logic
      },
      child: Text('Submit'),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
class _PriceInputDialog extends StatelessWidget {
  final String groundName;
  final double? previousPrice;

  _PriceInputDialog({required this.groundName, this.previousPrice});

  @override
  Widget build(BuildContext context) {
    final TextEditingController _priceController = TextEditingController();
    bool _isChecked = false;

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
                  controller: _priceController,
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
                        value: _isChecked,
                        onChanged: (value) {
                          setState(() {
                            _isChecked = value ?? false;
                            if (_isChecked) {
                              _priceController.text =
                                  previousPrice!.toStringAsFixed(2);
                            } else {
                              _priceController.clear();
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
                double? price = double.tryParse(_priceController.text);
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





