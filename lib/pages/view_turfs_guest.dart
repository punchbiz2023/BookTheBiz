import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:odp/pages/login.dart';
import 'package:odp/pages/sign_up_page.dart';
import 'package:shimmer/shimmer.dart';

// --- Turf Details Page ---
class TurfDetailsGuestPage extends StatelessWidget {
  final Map<String, dynamic> turfData;
  final String address;

  const TurfDetailsGuestPage({super.key, required this.turfData, required this.address});

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
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              title: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade800.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
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
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.5, 1.0],
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
              child: _buildGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.location_on, address, Colors.teal.shade400),
                      SizedBox(height: 16),
                      _buildInfoRow(Icons.currency_rupee, priceDisplay, Colors.teal.shade800, isPrice: true),
                      SizedBox(height: 20),
                      _buildSectionTitle('Available Grounds'),
                      SizedBox(height: 10),
                      groundsList.isNotEmpty
                          ? Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: groundsList
                                  .map<Widget>((g) => _buildGlassChip(g))
                                  .toList(),
                            )
                          : Text('Not specified', style: TextStyle(color: Colors.grey[800], fontSize: 15)),
                      SizedBox(height: 20),
                      _buildSectionTitle('Facilities'),
                      SizedBox(height: 10),
                      facilitiesList.isNotEmpty
                          ? Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: facilitiesList
                                  .map<Widget>((f) => _buildGlassChip(f))
                                  .toList(),
                            )
                          : Text('Not specified', style: TextStyle(color: Colors.grey[800], fontSize: 15)),
                      if (description.isNotEmpty) ...[
                        SizedBox(height: 20),
                        _buildSectionTitle('Description'),
                        SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(color: Colors.grey[800], fontSize: 15),
                        ),
                      ],
                      SizedBox(height: 30),
                      Center(
                        child: _buildAnimatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignupPage()),
                            );
                          },
                          icon: Icons.lock_outline,
                          label: 'Login/Register to Book',
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

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.8),
            Colors.white.withOpacity(0.5),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.7),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color, {bool isPrice = false}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isPrice ? 18 : 16, 
              color: isPrice ? color : Colors.grey[800], 
              fontWeight: isPrice ? FontWeight.bold : FontWeight.w500
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold, 
        color: Colors.teal.shade800, 
        fontSize: 18
      ),
    );
  }

  Widget _buildGlassChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.teal.shade50.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.shade100.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.teal.shade900, 
          fontWeight: FontWeight.w600
        ),
      ),
    );
  }

  Widget _buildAnimatedButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.teal.shade200,
          highlightColor: Colors.teal.shade100,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade600, Colors.teal.shade800],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Main Guest Turfs Page ---
class ViewTurfsGuestPage extends StatefulWidget {
  const ViewTurfsGuestPage({super.key});

  @override
  _ViewTurfsGuestPageState createState() => _ViewTurfsGuestPageState();
}

class _ViewTurfsGuestPageState extends State<ViewTurfsGuestPage> {
  String _searchText = '';
  final Set<String> _selectedGroundFilters = {};
  String _selectedLocation = 'All Areas';
  List<String> _availableLocations = ['All Areas'];
  final Map<String, String> _locationCache = {};
  final Map<String, String> _localityToLatLng = {};
  Map<String, String> _docIdToLocality = {};

  @override
  void initState() {
    super.initState();
    _loadAvailableLocations();
  }

  Future<void> _loadAvailableLocations() async {
    try {
      final turfs = await FirebaseFirestore.instance.collection('turfs').where('turf_status', isEqualTo: 'Verified').get();
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
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginApp()),
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Explore Turfs',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          backgroundColor: Colors.teal.shade800,
          elevation: 0,
          actions: [
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  'Guest Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.0,
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
              child: _buildGlassSearchBar(),
            ),
            // Location Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildGlassDropdown(),
            ),
            // Sports Type Filter
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('turfs').where('turf_status', isEqualTo: 'Verified').snapshots(),
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
                        _buildGlassChoiceChip(
                          label: 'All',
                          isSelected: _selectedGroundFilters.isEmpty,
                          onSelected: (selected) {
                            setState(() {
                              _selectedGroundFilters.clear();
                            });
                          },
                        ),
                        ...groundsList.map((ground) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: _buildGlassChoiceChip(
                            label: ground,
                            isSelected: _selectedGroundFilters.contains(ground),
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
                stream: FirebaseFirestore.instance.collection('turfs').where('turf_status', isEqualTo: 'Verified').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildShimmerEffect();
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
                      child: Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.teal.shade100),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.teal.shade300),
                            SizedBox(height: 16),
                            Text(
                              'No turfs found for your filters.',
                              style: TextStyle(
                                color: Colors.grey[600], 
                                fontSize: 16,
                                fontWeight: FontWeight.w500
                              ),
                            ),
                          ],
                        ),
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
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            margin: EdgeInsets.only(bottom: 20),
                            child: _buildGlassTurfCard(
                              turfData: turfData,
                              address: address,
                              priceDisplay: priceDisplay,
                              description: description,
                              grounds: grounds,
                              onTap: () => _navigateToTurfDetails(turfData, address),
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
              child: _buildInfoBanner(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.8),
            Colors.white.withOpacity(0.5),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.7),
          width: 1.5,
        ),
      ),
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
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(Icons.search, color: Colors.teal),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.teal),
                  onPressed: () {
                    setState(() {
                      _searchText = '';
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildGlassDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.8),
            Colors.white.withOpacity(0.5),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.7),
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedLocation,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Location',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          prefixIcon: Icon(Icons.location_on, color: Colors.teal),
        ),
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
        dropdownColor: Colors.white.withOpacity(0.9),
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
    );
  }

  Widget _buildGlassChoiceChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: onSelected,
        backgroundColor: Colors.white.withOpacity(0.5),
        selectedColor: Colors.teal.shade100.withOpacity(0.7),
        labelStyle: TextStyle(
          color: isSelected ? Colors.teal.shade900 : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.teal.shade300 : Colors.white.withOpacity(0.5),
          ),
        ),
        elevation: isSelected ? 2 : 0,
        shadowColor: Colors.teal.withOpacity(0.2),
      ),
    );
  }

  Widget _buildGlassTurfCard({
    required Map<String, dynamic> turfData,
    required String address,
    required String priceDisplay,
    required String description,
    required String grounds,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: Colors.teal.shade100,
      highlightColor: Colors.teal.shade50,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.8),
              Colors.white.withOpacity(0.5),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.7),
            width: 1.5,
          ),
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
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
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
                    SizedBox(height: 8),
                    _buildDetailRow(Icons.location_on, address),
                    if (grounds.isNotEmpty) ...[
                      SizedBox(height: 6),
                      _buildDetailRow(Icons.sports, grounds),
                    ],
                    if (description.isNotEmpty) ...[
                      SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.currency_rupee, size: 16, color: Colors.teal.shade400),
                            SizedBox(width: 4),
                            Text(
                              priceDisplay,
                              style: TextStyle(
                                fontSize: 16, 
                                color: Colors.teal.shade800, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ],
                        ),
                        _buildBookButton(),
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

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.teal.shade50.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: Colors.teal.shade400),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBookButton() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please login or register to book this turf.'),
            backgroundColor: Colors.teal.shade800,
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade600, Colors.teal.shade800],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withOpacity(0.3),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              'Book',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.teal.shade50.withOpacity(0.8),
            Colors.teal.shade100.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.teal.shade100.withOpacity(0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade100.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.info_outline, color: Colors.teal.shade800),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Create an account or log in to BookTheBiz to book your turf before slots get filled!',
              style: TextStyle(
                color: Colors.teal.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: EdgeInsets.only(bottom: 20),
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
    );
  }
}