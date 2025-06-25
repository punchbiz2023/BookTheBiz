import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:odp/pages/profile.dart';
import 'package:odp/widgets/firebaseimagecard.dart';
import 'bkdetails.dart';
import 'bookings_history_page.dart'; // Import the renamed page
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:odp/pages/details.dart';
class HomePage1 extends StatefulWidget {
  final User? user;
  const HomePage1({Key? key, this.user}) : super(key: key);

  @override
  _HomePage1State createState() => _HomePage1State();
}

class _HomePage1State extends State<HomePage1>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String selectedTab = 'active';
  String _searchText = '';
  String _pastBookingSearchText = '';
  String _sortOrder = 'Ascending';
  DateTime? _customDate;
  bool selectionMode = false;
  List<Map<String, dynamic>> selectedBookings = [];
  //Set<String> _selectedGroundFilters = {};
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _showAllTurfs = false;
  Set<String> _selectedGroundFilters = {};
  String _selectedLocation = 'All Areas';
  List<String> _availableLocations = ['All Areas'];
  Map<String, String> _locationCache = {}; // docId -> address
  Map<String, String> _localityToLatLng = {}; // locality -> latlng string

  // Returns a unique list of available locations (removes duplicates)
  List<String> _getUniqueLocations() {
    final seen = <String>{};
    final unique = <String>[];
    for (final loc in _availableLocations) {
      final key = loc.split('|')[0].trim();
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(loc);
      }
    }
    return unique;
  }


  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  late TabController _tabController;

  // Cache for location names
  final Map<String, String> _locationNameCache = {};

  // New variable to track price sort order
  String _priceSortOrder = 'none';

  // Add these fields to _HomePage1State:
  double? _minPriceFilter;
  double? _maxPriceFilter;

  // 1. Add this helper method inside your _HomePage1State class:
  List<Map<String, dynamic>> _generatePriceBuckets(List<DocumentSnapshot> turfs) {
    List<double> prices = [];
    for (final doc in turfs) {
      final turfData = doc.data() as Map<String, dynamic>;
      final low = _extractLowestPrice(turfData['price']);
      if (low != null) prices.add(low);
    }
    if (prices.isEmpty) return [
      {'label': 'All', 'min': null, 'max': null},
    ];

    prices.sort();
    double min = prices.first;
    double max = prices.last;
    double step = ((max - min) / 4).clamp(1, double.infinity);

    return [
      {'label': 'All', 'min': null, 'max': null},
      {'label': 'Low (< ₹${(min + step).toStringAsFixed(0)})', 'min': min, 'max': min + step},
      {'label': 'Medium (₹${(min + step).toStringAsFixed(0)} - ₹${(min + 2 * step).toStringAsFixed(0)})', 'min': min + step, 'max': min + 2 * step},
      {'label': 'High (₹${(min + 2 * step).toStringAsFixed(0)} - ₹${(min + 3 * step).toStringAsFixed(0)})', 'min': min + 2 * step, 'max': min + 3 * step},
      {'label': 'Premium (₹${(min + 3 * step).toStringAsFixed(0)}+)', 'min': min + 3 * step, 'max': null},
    ];
  }

  // 2. Add this field to your _HomePage1State class:
  String _selectedPriceBucket = 'All';

  // Add this to your _HomePage1State class:
  Map<String, String> _docIdToLocality = {}; // docId -> locality

  // Add this Set to your state:
  Set<String> _likedTurfs = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeLocation();
    _loadUserLikes();
    _loadAvailableLocations(); // Make sure this is called!
  }

  Future<void> _loadUserLikes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final likes = userDoc.data()?['likes'] as Map<String, dynamic>? ?? {};
      setState(() {
        _likedTurfs = likes.keys.toSet();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(user: widget.user),
      ),
    );
  }

  Stream<List<DocumentSnapshot>> _fetchPastBookings() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.teal,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
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
          fillColor: Colors.grey[200],
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Future<void> _initializeLocation() async {
    await _getCurrentLocation();
    await _loadAvailableLocations();
  }

  Future<void> _loadAvailableLocations() async {
    try {
      final turfs = await FirebaseFirestore.instance.collection('turfs').get();
      final Set<String> localities = {};
      final Map<String, String> localityToLatLng = {};
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
                localityToLatLng.putIfAbsent(locality, () => latlng!);
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
        _localityToLatLng = localityToLatLng;
        _docIdToLocality = docIdToLocality;
        if (!_availableLocations.contains(_selectedLocation)) {
          _selectedLocation = 'All Areas';
        }
      });
    } catch (e) {
      // Handle error if needed
    }
  }
  
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location services are disabled. Please enable them to see nearby turfs.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permission is required to see nearby turfs.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        bool? shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Location Permission Required'),
            content: Text('Location permission is permanently denied. Please enable it in settings to see nearby turfs.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Open Settings'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.teal,
                ),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await Geolocator.openAppSettings();
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String address = '';
          
          // Add sub-locality or locality
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            address += place.subLocality!;
          } else if (place.locality != null && place.locality!.isNotEmpty) {
            address += place.locality!;
          }
          
          // Add administrative area (city)
          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
            if (address.isNotEmpty) address += ', ';
            address += place.subAdministrativeArea!;
          }
          
          // Store the coordinates with the address
          final locationWithCoords = '$address|${position.latitude},${position.longitude}';
          
          setState(() {
            // Only add current location if it's not already in the list
            if (!_availableLocations.contains(locationWithCoords)) {
              _availableLocations.insert(1, locationWithCoords);
            }
            _selectedLocation = locationWithCoords;
          });
        }
      } catch (e) {
        print('Error getting address: $e');
      }

    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _calculateDistance(String turfLocation) {
    if (_currentPosition == null || turfLocation.isEmpty) return double.infinity;
    
    try {
      final coords = turfLocation.split(',');
      if (coords.length != 2) return double.infinity;
      
      final turfLat = double.parse(coords[0].trim());
      final turfLng = double.parse(coords[1].trim());
      
      return Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        turfLat,
        turfLng,
      );
    } catch (e) {
      return double.infinity;
    }
  }

  String _getPriceDisplay(dynamic price) {
    if (price is Map<String, dynamic>) {
      // Find the lowest price from the map
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

  // Helper to extract the lowest price from price (Map, String, or num)
  double? _extractLowestPrice(dynamic price) {
    if (price is Map<String, dynamic>) {
      double? lowest;
      price.forEach((key, value) {
        if (value is num) {
          if (lowest == null || value < lowest!) lowest = value.toDouble();
        } else if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null && (lowest == null || parsed < lowest!)) lowest = parsed;
        }
      });
      return lowest;
    } else if (price is num) {
      return price.toDouble();
    } else if (price is String) {
      return double.tryParse(price);
    }
    return null;
  }

  // Helper to extract the highest price from price (Map, String, or num)
  double? _extractHighestPrice(dynamic price) {
    if (price is Map<String, dynamic>) {
      double? highest;
      price.forEach((key, value) {
        if (value is num) {
          if (highest == null || value > highest!) highest = value.toDouble();
        } else if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null && (highest == null || parsed > highest!)) highest = parsed;
        }
      });
      return highest;
    } else if (price is num) {
      return price.toDouble();
    } else if (price is String) {
      return double.tryParse(price);
    }
    return null;
  }

  @override
Widget build(BuildContext context) {
  return WillPopScope(
    onWillPop: () async => false, // Disable back button
    child: Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(68),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.teal.shade50,
                  child: IconButton(
                    icon: Icon(Icons.person, color: Colors.teal.shade700),
                    onPressed: _navigateToProfile,
                    tooltip: 'Profile',
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '  Turf Booking',
                  style: TextStyle(
                    color: Colors.teal.shade800,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.confirmation_number, color: Colors.teal.shade700),
                tooltip: 'My Bookings',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BookingsPage()),
                  );
                },
              ),
              SizedBox(width: 8),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Container(
              color: Colors.grey[300],
              height: 1,
            ),
          ),
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Search Bar
            Container(
              margin: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.08),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: _buildSearchBar(),
            ),

            // 2. Most Recently Booked Turf
            _buildMostRecentBookedTurf(),

            // 3. Area-based Dropdown
            
            // 4. Nearby Turfs
            if (_currentPosition != null) ...[
              SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.near_me, color: Colors.teal, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Nearby Turfs',
                    style: TextStyle(
                      color: Colors.teal,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              _buildNearbyTurfs(),
            ],

            // 5. Favourite Turfs
            _buildFavouriteTurfs(),
            Container(
              margin: EdgeInsets.symmetric(vertical: 10),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.08),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.teal),
                  SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedLocation,
                      isExpanded: true,
                      underline: SizedBox(),
                      items: _getUniqueLocations().map((String location) {
                        final displayText = location == 'All Areas'
                            ? 'All Areas'
                            : location.split('|')[0];
                        return DropdownMenuItem<String>(
                          value: location,
                          child: Text(
                            displayText,
                            style: TextStyle(color: Colors.black87),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedLocation = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 6. Sports Type Filter
            _buildSportsTypeFilter(),

            // 7. All Turfs
            SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.sports_soccer, color: Colors.teal, size: 28),
                SizedBox(width: 8),
                _buildSectionTitle('All Turfs'),
                Spacer(),
                PopupMenuButton<String>(
                  icon: Icon(Icons.filter_alt, color: Colors.teal),
                  tooltip: 'Filter by Price',
                  onSelected: (value) {
                    setState(() {
                      _priceSortOrder = value;
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'none', child: Text('No Price Filter')),
                    PopupMenuItem(value: 'lowToHigh', child: Text('Price: Low to High')),
                    PopupMenuItem(value: 'highToLow', child: Text('Price: High to Low')),
                  ],
                ),
              ],
            ),
            _buildPopularTurfs(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SupportPage(user: widget.user)),
          );
        },
        child: Icon(Icons.support_agent, color: Colors.white),
        backgroundColor: Colors.teal,
        elevation: 6,
      ),
    ),
  );
}

  Widget _buildSportsTypeFilter() {
    return StreamBuilder<QuerySnapshot>(
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
        return ExpansionTile(
          title: Text('SPORTS TYPE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          children: [
            Wrap(
              spacing: 8,
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
                ...groundsList.map((ground) => ChoiceChip(
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
                )),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildNearbyTurfs() {
    if (_isLoadingLocation) {
      return Container(
        height: 280,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading nearby turfs...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentPosition == null) {
      return Container(
        height: 280,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 48,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'Location access required',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Enable location services to see nearby turfs',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('turfs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No turfs available nearby',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          );
        }

        final turfs = snapshot.data!.docs;
        
        // Filter turfs with valid locations and sort by distance
        final nearbyTurfs = turfs.where((doc) {
          final turfData = doc.data() as Map<String, dynamic>;
          final location = turfData['location']?.toString() ?? '';
          return location.isNotEmpty;
        }).toList();

        nearbyTurfs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDistance = _calculateDistance(aData['location'] ?? '');
          final bDistance = _calculateDistance(bData['location'] ?? '');
          return aDistance.compareTo(bDistance);
        });

        if (nearbyTurfs.isEmpty) {
          return Center(
            child: Text(
              'No turfs with location data available',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          );
        }

        return Container(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: nearbyTurfs.length,
            itemBuilder: (context, index) {
              final doc = nearbyTurfs[index];
              final turfData = doc.data() as Map<String, dynamic>;
              final priceDisplay = _getPriceDisplay(turfData['price']);
              
              final distance = _calculateDistance(turfData['location'] ?? '');
              final distanceText = distance < 1000
                  ? '${distance.toStringAsFixed(0)}m'
                  : '${(distance / 1000).toStringAsFixed(1)}km';

              return Container(
                width: 200,
                margin: EdgeInsets.only(right: 16),
                child: Card(
                  elevation: 7,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsPage(
                            documentId: doc.id,
                            documentname: turfData['name'] ?? '',
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        // Background image with gradient overlay
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            image: DecorationImage(
                              image: NetworkImage(turfData['imageUrl'] ?? ''),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Gradient overlay for better text visibility
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.75),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Favorite icon (top left)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: GestureDetector(
                            onTap: () async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
                                final isLiked = _likedTurfs.contains(doc.id);

                                if (isLiked) {
                                  // Unlike: remove from Firestore and local set
                                  await userRef.set({
                                    'likes': {doc.id: FieldValue.delete()}
                                  }, SetOptions(merge: true));
                                  setState(() {
                                    _likedTurfs.remove(doc.id);
                                  });
                                  await showLikeDialog(
    context: context,
    isLiked: false,
    turfName: turfData['name'] ?? 'Turf',
  );
                                } else {
                                  // Like: add to Firestore and local set
                                  await userRef.set({
                                    'likes': {doc.id: true}
                                  }, SetOptions(merge: true));
                                  setState(() {
                                    _likedTurfs.add(doc.id);
                                  });
                                  await showLikeDialog(
    context: context,
    isLiked: true,
    turfName: turfData['name'] ?? 'Turf',
  );
                                }
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: !_likedTurfs.contains(doc.id)
                                    ? Border.all(color: Colors.teal, width: 2)
                                    : null,
                                color: Colors.white.withOpacity(0.92),
                              ),
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                _likedTurfs.contains(doc.id) ? Icons.favorite : Icons.favorite_border,
                                color: _likedTurfs.contains(doc.id) ? Colors.red : Colors.teal,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        // Distance Badge (top right)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              distanceText,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                        // Turf info at the bottom (no available grounds)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  turfData['name'] ?? 'Unknown Turf',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  turfData['description'] ?? 'No description available',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 8),
                                // Only price badge, no available grounds
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    priceDisplay,
                                    style: TextStyle(
                                      color: Colors.teal[800],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFavouriteTurfs() {
    // Get all liked turf IDs
    final likedIds = _likedTurfs;
    if (likedIds.isEmpty) {
      return SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('turfs').where(FieldPath.documentId, whereIn: likedIds.toList()).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SizedBox.shrink();
        }
        final favTurfs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text(
                  'Favourite Turfs',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              childAspectRatio: 0.75,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              padding: EdgeInsets.all(10),
              children: favTurfs.map((doc) {
                final turfData = doc.data() as Map<String, dynamic>;
                final priceDisplay = _getPriceDisplay(turfData['price']);
                return AnimatedContainer(
                  duration: Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: Card(
                    elevation: 7,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailsPage(
                              documentId: doc.id,
                              documentname: turfData['name'] ?? '',
                            ),
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          // Background image with gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              image: DecorationImage(
                                image: NetworkImage(turfData['imageUrl'] ?? ''),
                                fit: BoxFit.cover,
                              ),
                            ),
                            height: double.infinity,
                            width: double.infinity,
                          ),
                          // Gradient overlay for better text visibility
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.75),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // No favorite icon here!
                          // Turf info at the bottom
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    turfData['name'] ?? 'Unknown Turf',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    turfData['description'] ?? 'No description available',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 8),
                                  // Only price badge
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      priceDisplay,
                                      style: TextStyle(
                                        color: Colors.teal[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopularTurfs() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('turfs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading turfs'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No turfs available'));
        }

        final turfs = snapshot.data!.docs;

        // Calculate min and max prices for all turfs
        double minPrice = double.infinity;
        double maxPrice = 0;
        for (final doc in turfs) {
          final turfData = doc.data() as Map<String, dynamic>;
          final low = _extractLowestPrice(turfData['price']);
          final high = _extractHighestPrice(turfData['price']);
          if (low != null && low < minPrice) minPrice = low;
          if (high != null && high > maxPrice) maxPrice = high;
        }
        if (minPrice == double.infinity) minPrice = 0;

        // Set default filter values if not set
        _minPriceFilter ??= minPrice;
        _maxPriceFilter ??= maxPrice;

        return FutureBuilder<List<DocumentSnapshot>>(
          future: _filterTurfsByLocation(turfs),
          builder: (context, filteredSnapshot) {
            if (!filteredSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }
            var filteredTurfs = filteredSnapshot.data!;

            // Apply price range filter
            filteredTurfs = filteredTurfs.where((doc) {
              final turfData = doc.data() as Map<String, dynamic>;
              final price = _extractLowestPrice(turfData['price']);
              if (price == null) return false;
              return price >= (_minPriceFilter ?? minPrice) && price <= (_maxPriceFilter ?? maxPrice);
            }).toList();

            // Apply price sort order
            if (_priceSortOrder == 'lowToHigh') {
              filteredTurfs.sort((a, b) {
                final aPrice = _extractLowestPrice((a.data() as Map<String, dynamic>)['price']) ?? 0;
                final bPrice = _extractLowestPrice((b.data() as Map<String, dynamic>)['price']) ?? 0;
                return aPrice.compareTo(bPrice);
              });
            } else if (_priceSortOrder == 'highToLow') {
              filteredTurfs.sort((a, b) {
                final aPrice = _extractLowestPrice((a.data() as Map<String, dynamic>)['price']) ?? 0;
                final bPrice = _extractLowestPrice((b.data() as Map<String, dynamic>)['price']) ?? 0;
                return bPrice.compareTo(aPrice);
              });
            }

            if (filteredTurfs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'No turfs found in selected location or price range',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Try selecting a different location or price filter.',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.cancel),
                      label: Text('Clear Price Filter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedPriceBucket = 'All';
                          _minPriceFilter = null;
                          _maxPriceFilter = null;
                        });
                      },
                    ),
                  ],
                ),
              );
            }

            // Show only first 4 turfs initially if not showing all
            final displayTurfs = _showAllTurfs ? filteredTurfs : filteredTurfs.take(4).toList();
            final hasMoreTurfs = filteredTurfs.length > 4 && !_showAllTurfs;

            // --- Replace the RangeSlider UI with this chip-based filter ---
            final priceBuckets = _generatePriceBuckets(filteredTurfs);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price Chip Filter UI
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Price Filter', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                      SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: priceBuckets.map((bucket) {
                            final isSelected = _selectedPriceBucket == bucket['label'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(bucket['label'], style: TextStyle(fontWeight: FontWeight.w600)),
                                selected: isSelected,
                                selectedColor: Colors.teal,
                                backgroundColor: Colors.grey[200],
                                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.teal),
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedPriceBucket = bucket['label'];
                                    _minPriceFilter = bucket['min'] as double?;
                                    _maxPriceFilter = bucket['max'] as double?;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      if (_selectedPriceBucket != 'All')
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedPriceBucket = 'All';
                                _minPriceFilter = null;
                                _maxPriceFilter = null;
                              });
                            },
                            child: Text('Reset', style: TextStyle(color: Colors.teal)),
                          ),
                        ),
                    ],
                  ),
                ),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  childAspectRatio: 0.75,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  padding: EdgeInsets.all(10),
                  children: displayTurfs.map((doc) {
                    final turfData = doc.data() as Map<String, dynamic>;
                    return _buildTurfCard(doc, turfData);
                  }).toList(),
                ),
                if (hasMoreTurfs) ...[
                  SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAllTurfs = true;
                        });
                      },
                      icon: Icon(Icons.grid_view),
                      label: Text('View All ${filteredTurfs.length} Turfs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTurfCard(DocumentSnapshot doc, Map<String, dynamic> turfData) {
    final priceDisplay = _getPriceDisplay(turfData['price']);
    return AnimatedContainer(
      duration: Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Card(
        elevation: 7,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailsPage(
                  documentId: doc.id,
                  documentname: turfData['name'] ?? '',
                ),
              ),
            );
          },
          child: Stack(
            children: [
              // Background image with gradient overlay
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  image: DecorationImage(
                    image: NetworkImage(turfData['imageUrl'] ?? ''),
                    fit: BoxFit.cover,
                  ),
                ),
                height: double.infinity,
                width: double.infinity,
              ),
              // Gradient overlay for better text visibility
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.75),
                      ],
                    ),
                  ),
                ),
              ),
              // Favorite icon (top left)
              Positioned(
                top: 12,
                left: 12,
                child: GestureDetector(
                  onTap: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
                      final isLiked = _likedTurfs.contains(doc.id);

                      if (isLiked) {
                        // Unlike: remove from Firestore and local set
                        await userRef.set({
                          'likes': {doc.id: FieldValue.delete()}
                        }, SetOptions(merge: true));
                        setState(() {
                          _likedTurfs.remove(doc.id);
                        });
                        await showLikeDialog(
    context: context,
    isLiked: false,
    turfName: turfData['name'] ?? 'Turf',
  );
                      } else {
                        // Like: add to Firestore and local set
                        await userRef.set({
                          'likes': {doc.id: true}
                        }, SetOptions(merge: true));
                        setState(() {
                          _likedTurfs.add(doc.id);
                        });
                        await showLikeDialog(
    context: context,
    isLiked: true,
    turfName: turfData['name'] ?? 'Turf',
  );
                      }
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: !_likedTurfs.contains(doc.id)
                          ? Border.all(color: Colors.teal, width: 2)
                          : null,
                      color: Colors.white.withOpacity(0.92),
                    ),
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      _likedTurfs.contains(doc.id) ? Icons.favorite : Icons.favorite_border,
                      color: _likedTurfs.contains(doc.id) ? Colors.red : Colors.teal,
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Turf info at the bottom (no available grounds, no distance badge)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        turfData['name'] ?? 'Unknown Turf',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        turfData['description'] ?? 'No description available',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      // Only price badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          priceDisplay,
                          style: TextStyle(
                            color: Colors.teal[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      )
    );
    }

  // Update your _filterTurfsByLocation logic as below:
  Future<List<DocumentSnapshot>> _filterTurfsByLocation(List<DocumentSnapshot> turfs) async {
    final selectedLocationName = _selectedLocation == 'All Areas'
        ? null
        : _selectedLocation.split('|')[0].trim().toLowerCase();

    List<DocumentSnapshot> filtered = [];
    for (final doc in turfs) {
      final turfData = doc.data() as Map<String, dynamic>;
      final turfName = turfData['name']?.toString().toLowerCase() ?? '';
      final grounds = List<String>.from(turfData['availableGrounds'] ?? []);
      final location = turfData['location']?.toString() ?? '';

      final matchesSearch = turfName.contains(_searchText.toLowerCase());
      final matchesGround = _selectedGroundFilters.isEmpty ||
          _selectedGroundFilters.any((g) => grounds.contains(g));

      // Updated location filtering: fuzzy match on locality
      bool matchesLocation = true;
      if (selectedLocationName != null) {
        final locality = _docIdToLocality[doc.id] ?? '';
        matchesLocation = locality.toLowerCase().contains(selectedLocationName);
      }

      if (matchesSearch && matchesGround && matchesLocation) {
        filtered.add(doc);
      }
    }
    return filtered;
  }

  // Add this widget to your _HomePage1State class if not already present:
  Widget _buildMostRecentBookedTurf() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: _currentUserId)
          .get(),
      builder: (context, bookingSnapshot) {
        if (bookingSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!bookingSnapshot.hasData || bookingSnapshot.data!.docs.isEmpty) {
          return SizedBox.shrink();
        }
        // Sort bookings by bookingDate string descending
        final bookings = bookingSnapshot.data!.docs;
        bookings.sort((a, b) {
          final aDate = a['bookingDate'] ?? '';
          final bDate = b['bookingDate'] ?? '';
          return bDate.compareTo(aDate); // descending
        });
        final bookingDoc = bookings.first;
        final turfId = bookingDoc['turfId'];

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('turfs').doc(turfId).get(),
          builder: (context, turfSnapshot) {
            if (turfSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (!turfSnapshot.hasData || !turfSnapshot.data!.exists) {
              return SizedBox.shrink();
            }
            final turfDoc = turfSnapshot.data!;
            final turfData = turfDoc.data() as Map<String, dynamic>;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.history, color: Colors.teal, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Most Recently Booked Turf',
                      style: TextStyle(
                        color: Colors.teal[700],
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                SizedBox(
                  height: 270,
                  child: _buildTurfCard(turfDoc, turfData),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// 2. Add this new SupportPage widget (place it at the end of this file):

class SupportPage extends StatefulWidget {
  final User? user;
  const SupportPage({Key? key, this.user}) : super(key: key);

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId': widget.user?.uid ?? '',
        'userEmail': widget.user?.email ?? '',
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => _isSubmitting = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.green[50],
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Ticket Submitted', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Your support request has been submitted. Our team will contact you soon.',
            style: TextStyle(color: Colors.green[900], fontWeight: FontWeight.w500),
          ),
          actions: [
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
      _subjectController.clear();
      _messageController.clear();
    } catch (e) {
      setState(() => _isSubmitting = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.red[50],
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Submission Failed', style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'There was an error submitting your ticket. Please try again later.',
            style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.w500),
          ),
          actions: [
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contact Support', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Raise a Support Ticket',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal[800]),
              ),
              SizedBox(height: 18),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.subject),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a subject' : null,
              ),
              SizedBox(height: 18),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.message),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                minLines: 4,
                maxLines: 8,
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your message' : null,
              ),
              SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.send),
                  label: Text(_isSubmitting ? 'Submitting...' : 'Submit Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _submitTicket,
                ),
              ),
              SizedBox(height: 18),
              Divider(),
              SizedBox(height: 10),
              Text(
                'Need urgent help?',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[700]),
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.email, color: Colors.teal, size: 20),
                  SizedBox(width: 8),
                  SelectableText('thepunchbiz@gmail.com', style: TextStyle(color: Colors.teal[900], fontWeight: FontWeight.w500)),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, color: Colors.teal, size: 20),
                  SizedBox(width: 8),
                  SelectableText('+91 94894 45922', style: TextStyle(color: Colors.teal[900], fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Use this function for both like and unlike dialogs
Future<void> showLikeDialog({
  required BuildContext context,
  required bool isLiked,
  required String turfName,
}) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: isLiked ? Colors.teal[50] : Colors.red[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: isLiked ? Colors.teal : Colors.red,
            child: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
            ),
            radius: 22,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLiked ? 'Added to Likes' : 'Removed from Likes',
                  style: TextStyle(
                    color: isLiked ? Colors.teal[800] : Colors.red[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                Text(
                  turfName,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Text(
                  isLiked
                      ? 'This turf has been added to your likes!'
                      : 'This turf has been removed from your likes.',
                  style: TextStyle(
                    color: isLiked ? Colors.teal[900] : Colors.red[900],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          child: Text(
            'OK',
            style: TextStyle(
              color: isLiked ? Colors.teal : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
