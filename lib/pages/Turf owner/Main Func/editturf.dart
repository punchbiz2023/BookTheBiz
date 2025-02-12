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
  bool _isosp = false;
  bool _isPriceMap = false;
  Map<String, int> _price = {};
  Map<String, TextEditingController> _priceControllers = {};
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
  Set<String> selectedFacilities = {};
  Set<String> selectedGrounds = {};
  Set<String> selectedCustomSlots = {};
  Set<String> selectedMorningSlots = {};
  Set<String> selectedEveningSlots = {};

  @override
  void initState() {
    super.initState();
    _loadTurfDetails();
  }

  Future<void> _loadTurfDetails() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).get();
      if (!doc.exists) {
        return;
      }
      var turfData = doc.data() as Map<String, dynamic>;

      setState(() {
        _nameController.text = turfData['name'] ?? '';
        _descriptionController.text = turfData['description'] ?? '';

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
      });
    } catch (e) {
      debugPrint('Error loading turf details: $e');
    }
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

      // Upload new image if changed
      if (_newImageFile != null) {
        if (_imageUrl != null) {
          var oldImageRef = FirebaseStorage.instance.refFromURL(_imageUrl!);
          await oldImageRef.delete();
        }

        var storageRef = FirebaseStorage.instance.ref().child('turfs/${widget.turfId}/image.jpg');
        await storageRef.putFile(_newImageFile!);
        newImageUrl = await storageRef.getDownloadURL();
      }

      // Save price as either a single number or a map of ground prices
      dynamic priceData;
      if (_price.isEmpty && _priceController.text.isNotEmpty) {
        priceData = double.tryParse(_priceController.text) ?? 0.0;
      } else {
        priceData = _price; // Store price as a map if multiple prices exist
      }

      // Merge all selected slots
      List<String> allSelectedSlots = [
        ...selectedMorningSlots,
        ...selectedEveningSlots,
        ...selectedCustomSlots,
      ];

      // Prepare Firestore update data
      Map<String, dynamic> updateData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': priceData,
        'facilities': selectedFacilities.toList(),
        'availableGrounds': selectedGrounds.toList(),
        'isosp': _isosp,
        if (newImageUrl != null) 'imageUrl': newImageUrl,
        if (allSelectedSlots.isNotEmpty) 'selectedSlots': allSelectedSlots, // ✅ Only update if not empty
      };

      await FirebaseFirestore.instance.collection('turfs').doc(widget.turfId).update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Turf details updated successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
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
              _buildIsospSwitch(), // Add the Switch for isosp
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
        }).toList(),
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


// Retrieve price for a ground
  int? _getGroundPrice(String ground) {
    return _price[ground];
  }

// Show a dialog for entering a new price
  Future<int?> _showPriceDialog(String ground) async {
    TextEditingController priceController = TextEditingController();

    return await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Price for $ground'),
          content: TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'Enter price'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                int? price = int.tryParse(priceController.text);
                if (price != null && price > 0) {
                  Navigator.pop(context, price);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a valid price')),
                  );
                }
              },
              child: Text('OK'),
            ),
          ],
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