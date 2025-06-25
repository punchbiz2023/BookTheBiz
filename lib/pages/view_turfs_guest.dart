import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

// --- Turf Details Page ---
class TurfDetailsGuestPage extends StatelessWidget {
  final Map<String, dynamic> turfData;
  final String address;

  const TurfDetailsGuestPage({Key? key, required this.turfData, required this.address}) : super(key: key);

  String _getPriceDisplay(dynamic price) {
    if (price is Map<String, dynamic>) {
      double? lowestPrice;
      price.forEach((key, value) {
        if (value is num) {
          if (lowestPrice == null || value < lowestPrice!) {
            lowestPrice = value.toDouble();
          }
        }
      });
      return lowestPrice != null ? '${lowestPrice?.toStringAsFixed(0)}/hr' : 'N/A';
    } else if (price is num) {
      return '₹${price.toStringAsFixed(0)}/hr';
    } else if (price is String) {
      try {
        final numPrice = double.parse(price);
        return '₹${numPrice.toStringAsFixed(0)}/hr';
      } catch (e) {
        return 'N/A';
      }
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final groundsList = (turfData['availableGrounds'] as List?) ?? [];
    final facilitiesList = (turfData['facilities'] as List?) ?? [];
    final description = turfData['description'] ?? '';
    final price = turfData['price'];
    final priceDisplay = _getPriceDisplay(price);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.teal.shade800,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                turfData['name'] ?? 'Turf Details',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  turfData['imageUrl'] != null && turfData['imageUrl'].toString().isNotEmpty
                      ? Image.network(
                          turfData['imageUrl'],
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.teal.shade100,
                          child: Center(
                            child: Icon(Icons.sports_soccer, color: Colors.teal, size: 80),
                          ),
                        ),
                  // Add gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.teal.shade400, size: 20),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              address,
                              style: TextStyle(fontSize: 16, color: Colors.grey[800], fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(Icons.currency_rupee, color: Colors.teal.shade400, size: 20),
                          SizedBox(width: 6),
                          Text(
                            priceDisplay,
                            style: TextStyle(fontSize: 17, color: Colors.teal.shade800, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 18),
                      Text(
                        'Available Grounds',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      groundsList.isNotEmpty
                          ? Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: groundsList
                                  .map<Widget>((g) => Chip(
                                        label: Text(g.toString()),
                                        backgroundColor: Colors.teal.shade50,
                                        labelStyle: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.w600),
                                      ))
                                  .toList(),
                            )
                          : Text('Not specified', style: TextStyle(color: Colors.grey[800], fontSize: 15)),
                      SizedBox(height: 18),
                      Text(
                        'Facilities',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      facilitiesList.isNotEmpty
                          ? Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: facilitiesList
                                  .map<Widget>((f) => Chip(
                                        label: Text(f.toString()),
                                        backgroundColor: Colors.teal.shade50,
                                        labelStyle: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.w600),
                                      ))
                                  .toList(),
                            )
                          : Text('Not specified', style: TextStyle(color: Colors.grey[800], fontSize: 15)),
                      if (description.isNotEmpty) ...[
                        SizedBox(height: 18),
                        Text(
                          'Description',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800, fontSize: 16),
                        ),
                        SizedBox(height: 6),
                        Text(
                          description,
                          style: TextStyle(color: Colors.grey[800], fontSize: 15),
                        ),
                      ],
                      SizedBox(height: 28),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Please login or register to book this turf.'),
                                backgroundColor: Colors.teal.shade800,
                              ),
                            );
                          },
                          icon: Icon(Icons.lock_outline),
                          label: Text('Login/Register to Book'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Main Guest Turfs Page ---
class ViewTurfsGuestPage extends StatefulWidget {
  @override
  _ViewTurfsGuestPageState createState() => _ViewTurfsGuestPageState();
}

class _ViewTurfsGuestPageState extends State<ViewTurfsGuestPage> {
  String _searchText = '';
  Set<String> _selectedGroundFilters = {};
  String _selectedLocation = 'All Areas';
  List<String> _availableLocations = ['All Areas'];
  Map<String, String> _locationCache = {}; // docId -> address
  Map<String, String> _localityToLatLng = {}; // locality -> latlng string
  Map<String, String> _docIdToLocality = {}; // docId -> locality

  @override
  void initState() {
    super.initState();
    _loadAvailableLocations();
  }

  Future<void> _loadAvailableLocations() async {
    try {
      final turfs = await FirebaseFirestore.instance.collection('turfs').get();
      final Set<String> localities = {};
      final Map<String, String> docIdToLocality = {};

      for (var doc in turfs.docs) {
        final turfData = doc.data();
        String? latlng;
        if (turfData['latlng'] != null && turfData['latlng'].toString().isNotEmpty) {
          latlng = turfData['latlng'].toString();
        } else if (turfData['location'] != null && turfData['location'].toString().isNotEmpty) {
          latlng = turfData['location'].toString();
        }
        if (latlng != null && latlng.contains(',')) {
          try {
            final parts = latlng.split(',');
            final lat = double.parse(parts[0]);
            final lng = double.parse(parts[1]);
            final placemarks = await placemarkFromCoordinates(lat, lng);
            if (placemarks.isNotEmpty) {
              final locality = placemarks.first.locality ?? '';
              if (locality.isNotEmpty) {
                localities.add(locality);
                docIdToLocality[doc.id] = locality;
              }
            }
          } catch (e) {
            // ignore
          }
        }
      }

      setState(() {
        _availableLocations = ['All Areas', ...localities];
        _docIdToLocality = docIdToLocality;
        if (!_availableLocations.contains(_selectedLocation)) {
          _selectedLocation = 'All Areas';
        }
      });
    } catch (e) {
      // Handle error if needed
    }
  }

  String _getPriceDisplay(dynamic price) {
    if (price is Map<String, dynamic>) {
      double? lowestPrice;
      price.forEach((key, value) {
        if (value is num) {
          if (lowestPrice == null || value < lowestPrice!) {
            lowestPrice = value.toDouble();
          }
        }
      });
      return lowestPrice != null ? '₹${lowestPrice?.toStringAsFixed(0)}/hr' : 'N/A';
    } else if (price is num) {
      return '₹${price.toStringAsFixed(0)}/hr';
    } else if (price is String) {
      try {
        final numPrice = double.parse(price);
        return '₹${numPrice.toStringAsFixed(0)}/hr';
      } catch (e) {
        return 'N/A';
      }
    }
    return 'N/A';
  }

  Future<String> _getAddressFromLatLng(dynamic locationData, String docId) async {
    if (locationData == null) return 'Location not available';
    if (_locationCache.containsKey(docId)) return _locationCache[docId]!;

    try {
      double? lat, lng;
      if (locationData is String && locationData.contains(',')) {
        final parts = locationData.split(',');
        lat = double.tryParse(parts[0]);
        lng = double.tryParse(parts[1]);
      } else if (locationData is Map<String, dynamic>) {
        lat = locationData['lat']?.toDouble();
        lng = locationData['lng']?.toDouble();
      }
      if (lat == null || lng == null) return 'Location not available';

      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String address = [
          place.name,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        _locationCache[docId] = address;
        return address.isNotEmpty ? address : 'Location not available';
      }
    } catch (e) {
      return 'Location not available';
    }
    return 'Location not available';
  }

  void _navigateToTurfDetails(Map<String, dynamic> turfData, String address) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TurfDetailsGuestPage(turfData: turfData, address: address),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Explore Turfs',style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.teal.shade800,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Center(
              child: Text(
                'Guest Mode',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(30),
              child: TextFormField(
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Search turfs...',
                  hintStyle: TextStyle(color: Colors.black54),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.teal),
                ),
              ),
            ),
          ),
          // Location Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedLocation,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _availableLocations.map((location) {
                return DropdownMenuItem<String>(
                  value: location,
                  child: Text(location),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedLocation = value;
                  });
                }
              },
            ),
          ),
          // Sports Type Filter
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('turfs').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return SizedBox.shrink();
              final turfs = snapshot.data!.docs;
              final Set<String> allGrounds = {};
              for (var doc in turfs) {
                final turfData = doc.data() as Map<String, dynamic>;
                final grounds = List<String>.from(turfData['availableGrounds'] ?? []);
                allGrounds.addAll(grounds);
              }
              final groundsList = allGrounds.toList();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('All'),
                        selected: _selectedGroundFilters.isEmpty,
                        onSelected: (selected) {
                          setState(() {
                            _selectedGroundFilters.clear();
                          });
                        },
                      ),
                      ...groundsList.map((ground) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(ground),
                          selected: _selectedGroundFilters.contains(ground),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedGroundFilters.add(ground);
                              } else {
                                _selectedGroundFilters.remove(ground);
                              }
                            });
                          },
                        ),
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('turfs').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No turfs available'));
                }
                final turfs = snapshot.data!.docs;

                // --- Filtering logic ---
                final filteredTurfs = turfs.where((doc) {
                  final turfData = doc.data() as Map<String, dynamic>;
                  final turfName = turfData['name']?.toString().toLowerCase() ?? '';
                  final grounds = List<String>.from(turfData['availableGrounds'] ?? []);
                  final matchesSearch = turfName.contains(_searchText.toLowerCase());
                  final matchesGround = _selectedGroundFilters.isEmpty ||
                      _selectedGroundFilters.any((g) => grounds.contains(g));

                  // Location filtering (fuzzy match)
                  bool matchesLocation = true;
                  if (_selectedLocation != 'All Areas') {
                    final locality = _docIdToLocality[doc.id] ?? '';
                    matchesLocation = locality.toLowerCase().contains(_selectedLocation.toLowerCase());
                  }

                  return matchesSearch && matchesGround && matchesLocation;
                }).toList();

                if (filteredTurfs.isEmpty) {
                  return Center(
                    child: Text(
                      'No turfs found for your filters.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  );
                }

                
                return ListView.builder(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  itemCount: filteredTurfs.length,
  itemBuilder: (context, index) {
    final doc = filteredTurfs[index];
    final turfData = doc.data() as Map<String, dynamic>;
    final priceDisplay = _getPriceDisplay(turfData['price']);
    final description = turfData['description'] ?? '';
    final grounds = (turfData['availableGrounds'] as List?)?.join(', ') ?? '';
    final locationData = turfData['latlng'] ?? turfData['location'];
    final docId = doc.id;

    return FutureBuilder<String>(
      future: _getAddressFromLatLng(locationData, docId),
      builder: (context, snapshot) {
        final address = snapshot.data ?? 'Loading location...';
        return GestureDetector(
          onTap: () => _navigateToTurfDetails(turfData, address),
          child: Container(
            margin: EdgeInsets.only(bottom: 20),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Turf Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: turfData['imageUrl'] != null && turfData['imageUrl'].toString().isNotEmpty
                            ? Image.network(
                                turfData['imageUrl'],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 100,
                                height: 100,
                                color: Colors.teal.shade50,
                                child: Icon(Icons.sports_soccer, color: Colors.teal, size: 40),
                              ),
                      ),
                      SizedBox(width: 18),
                      // Turf Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              turfData['name'] ?? 'Unknown Turf',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.teal.shade900,
                              ),
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.teal.shade400),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    address,
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (grounds.isNotEmpty) ...[
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.sports, size: 16, color: Colors.teal.shade400),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      grounds,
                                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (description.isNotEmpty) ...[
                              SizedBox(height: 4),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.currency_rupee, size: 16, color: Colors.teal.shade400),
                                SizedBox(width: 4),
                                Text(
                                  priceDisplay,
                                  style: TextStyle(fontSize: 15, color: Colors.teal.shade800, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Please login or register to book this turf.'),
                                      backgroundColor: Colors.teal.shade800,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade600,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(Icons.lock_outline, size: 18),
                                label: Text('Book'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  },
);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.teal.shade800),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Create an account or log in to BookTheBiz to book your turf before slots get filled!',
                        style: TextStyle(
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}