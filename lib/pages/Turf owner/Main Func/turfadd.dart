import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  File? _imageFile;
  bool _isLoading = false;
  final Map<String, double> _selectedGroundPrices = {};
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isosp = false;

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
    '6 AM - 7 AM',
    '7 AM - 8 AM',
    '8 AM - 9 AM',
    '9 AM - 10 AM',
    '10 AM - 11 AM',
    '11 AM - 12 PM',
  ];

  final List<String> _eveningSlots = [
    '4 PM - 5 PM',
    '5 PM - 6 PM',
    '6 PM - 7 PM',
    '7 PM - 8 PM',
    '8 PM - 9 PM',
    '9 PM - 10 PM',
  ];

  final List<String> _customSlots = [];

  final List<String> _selectedAvailableGrounds = [];
  String _selectedSlotType = 'Morning Slots';
  Future<void> _pickImage() async {
    final pickedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _imageFile = File(pickedImage.path);
      });
    }
  }

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

  // IconData _getIconForItem(String item) {
  //   switch (item.toLowerCase()) {
  //     case 'football field':
  //       return Icons.sports_soccer;
  //     case 'volleyball court':
  //       return Icons.sports_volleyball;
  //     case 'cricket ground':
  //       return Icons.sports_cricket;
  //     case 'basketball court':
  //       return Icons.sports_basketball;
  //     case 'swimming pool':
  //       return Icons.pool;
  //     case 'shuttlecock':
  //       return Icons.sports_tennis;
  //     case 'tennis court':
  //       return Icons.sports_tennis;
  //     case 'badminton court':
  //       return Icons.sports_tennis;
  //     case 'parking':
  //       return Icons.local_parking;
  //     case 'restroom':
  //       return Icons.wc;
  //     case 'cafeteria':
  //       return Icons.restaurant;
  //     case 'lighting':
  //       return Icons.lightbulb;
  //     case 'seating':
  //       return Icons.event_seat;
  //     case 'shower':
  //       return Icons.shower;
  //     case 'changing room':
  //       return Icons.room_preferences;
  //     case 'wi-fi':
  //       return Icons.wifi;
  //     default:
  //       return Icons.help;
  //   }
  // }

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
      String imageUrl = await _uploadImage(_imageFile!);
      String userId = _auth.currentUser!.uid;
      DocumentReference turfRef = _firestore.collection('turfs').doc();
      String turfId = turfRef.id;

      Map<String, dynamic> turfData = {
        'turfId': turfId,
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': _selectedGroundPrices,
        'imageUrl': imageUrl,
        'facilities': _selectedFacilities,
        'availableGrounds': _selectedAvailableGrounds,
        'ownerId': userId,
        'isosp': _isosp,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            title: Text('Add Turf', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
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
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildImagePicker(),
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
                      SizedBox(height: 16),
                      _buildDropdown(),
                      SizedBox(height: 16),
                      _buildSlotChips(),
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
                children: [
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
    return ElevatedButton(
      onPressed: _submitTurf,
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
                              _priceController.text = previousPrice!.toStringAsFixed(2);
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