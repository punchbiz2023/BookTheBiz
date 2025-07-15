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
  const HomePage1({super.key, this.user});

  @override
  _HomePage1State createState() => _HomePage1State();
}

class _HomePage1State extends State<HomePage1>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  String _searchText = '';
  String _selectedSportType = '';
  final TextEditingController _searchController = TextEditingController();
  String selectedTab = 'active';
  final String _pastBookingSearchText = '';
  final String _sortOrder = 'Ascending';
  DateTime? _customDate;
  bool selectionMode = false;
  List<Map<String, dynamic>> selectedBookings = [];
  //Set<String> _selectedGroundFilters = {};
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _showPriceFilterSheet = false;
  bool _showAllTurfs = false;
  final Set<String> _selectedGroundFilters = {};
  String _selectedLocation = 'All Areas';
  List<String> _availableLocations = ['All Areas'];
  final Map<String, String> _locationCache = {}; // docId -> address
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


  String? get _currentUserId => widget.user?.uid;
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
    if (prices.isEmpty) {
      return [
      {'label': 'All', 'min': null, 'max': null},
    ];
    }

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
  List<Map<String, dynamic>> _priceBuckets = [];
  bool _priceBucketsInitialized = false;
  // 2. Add this field to your _HomePage1State class:
  String _selectedPriceBucket = 'All';

  // Add this to your _HomePage1State class:
  Map<String, String> _docIdToLocality = {}; // docId -> locality

  // Add this Set to your state:
  Set<String> _likedTurfs = {};

  // Mapping of sport type to asset image
  final Map<String, String> _sportTypeImages = {
    'Badminton Court': 'lib/assets/badminton_court.jpg',
    'Football Field': 'lib/assets/football_field.jpg',
    'Cricket Ground': 'lib/assets/cricket_ground.jpg',
    'Shuttlecock': 'lib/assets/shuttle_cock.jpg',
    'Swimming Pool': 'lib/assets/swimming_pool.jpg',
    'Tennis Court': 'lib/assets/tennis_court.jpg',
    'Volleyball Court': 'lib/assets/volleyball_court.jpg',
    'Basketball Court': 'lib/assets/basket_ball.jpg',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeLocation();
    _loadUserLikes();
    _loadAvailableLocations(); // Make sure this is called!
  }

  Future<void> _loadUserLikes() async {
    final user = widget.user;
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
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<Map<String, dynamic>>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<Map<String, dynamic>>.empty();
            }

            final allTurfsSnapshot =
                await FirebaseFirestore.instance.collection('turfs').get();

            final filtered = allTurfsSnapshot.docs.where((doc) {
              final name = (doc['name'] ?? '').toString().toLowerCase();
              return name.contains(textEditingValue.text.toLowerCase());
            }).map((doc) => {
                  'id': doc.id,
                  'name': doc['name'] ?? '',
                  'imageUrl': doc['imageUrl'] ?? '',
                  'description': doc['description'] ?? '',
                }).toList();

            return filtered;
          },
          displayStringForOption: (option) => option['name'] ?? '',
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return StatefulBuilder(
              builder: (context, setState) {
                controller.addListener(() => setState(() {}));

                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    style: TextStyle(color: Colors.black87, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search for turfs...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.search, color: Colors.teal),
                      suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.cancel, color: Colors.grey[600]),
                              onPressed: () {
                                controller.clear();
                                focusNode.unfocus();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
        ),
      ),
    );
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: EdgeInsets.only(top: 10),
                  width: MediaQuery.of(context).size.width - 32,
                  constraints: BoxConstraints(maxHeight: 350),
            decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                ),
              ],
            ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 72,
                      color: Colors.grey[200],
                    ),
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                        },
                        splashColor: Colors.teal.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Hero(
                                tag: option['id'],
            child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.teal.shade50,
                                  backgroundImage: option['imageUrl'] != null &&
                                          option['imageUrl']
                                              .toString()
                                              .isNotEmpty
                                      ? NetworkImage(option['imageUrl'])
                                      : null,
                                  child: option['imageUrl'] == null ||
                                          option['imageUrl']
                                              .toString()
                                              .isEmpty
                                      ? Icon(Icons.sports_soccer,
                                          color: Colors.teal)
                                      : null,
                                ),
                              ),
                              SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(option['name'] ?? '',
            style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        )),
                                    if (option['description'] != null &&
                                        option['description']
                                            .toString()
                                            .isNotEmpty)
                                      Text(
                                        option['description'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (option) {
                  Navigator.push(
                    context,
              MaterialPageRoute(
                builder: (context) => DetailsPage(
                  documentId: option['id'],
                  documentname: option['name'],
                ),
              ),
                  );
                },
              ),
      ],
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
                style: TextButton.styleFrom(
                  foregroundColor: Colors.teal,
                ),
                child: Text('Open Settings'),
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
    return FutureBuilder<DocumentSnapshot>(
      future: widget.user != null
          ? FirebaseFirestore.instance.collection('users').doc(widget.user!.uid).get()
          : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            body: Center(child: Text('User data not found. Please contact support.')),
          );
        }
        // User data exists, show the main UI
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(64),
            child: AppBar(
              elevation: 0.5,
              backgroundColor: Colors.white,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: Row(
                children: [
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Turf Booking',
                      style: TextStyle(
                        color: Color(0xFF17494D),
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        letterSpacing: 0.5,
                        fontFamily: 'Montserrat',
                        shadows: [
                          Shadow(
                            color: Colors.teal.withOpacity(0.08),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfilePage(user: widget.user),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.teal.shade100, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.teal.shade50,
                        radius: 22,
                        child: Icon(Icons.person, color: Colors.teal.shade700, size: 28),
                      ),
                    ),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(1.5),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade50, Colors.grey.shade200],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  height: 1.5,
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildDashboardTab(),
                _buildSearchTab(),
                _buildDiscoverTurfsTab(),
                BookingsPage(),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNavigationBar(),
        );
      },
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Search';
      case 2:
        return 'Discover Turfs';
      case 3:
        return 'Bookings';
      default:
        return '';
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      margin: EdgeInsets.only(left: 24, right: 24, bottom: 24), // Floating effect
      decoration: BoxDecoration(
        color: Colors.teal.shade600,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navBarItem(Icons.dashboard, '', 0),
          _navBarItem(Icons.search, '', 1),
          _navBarItem(Icons.sports_soccer, '', 2),
          _navBarItem(Icons.confirmation_number, '', 3),
        ],
      ),
    );
  }

  Widget _navBarItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: isSelected ? 8 : 0),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Color(0xFF181828) : Colors.white, size: 26),
              if (isSelected) ...[
                Text(label, style: TextStyle(color: Color(0xFF181828), fontWeight: FontWeight.bold, fontSize: 16)),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          SizedBox(height: 10),
          _buildMostRecentBookedTurf(),
          SizedBox(height: 20),
          Row(
            children: const [
              Icon(Icons.near_me, color: Colors.teal, size: 28),
              SizedBox(width: 8),
              Text('Nearby Turfs', style: TextStyle(color: Colors.teal, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 15),
          _buildNearbyTurfs(),
          _buildFavouriteTurfs(),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    // Enhanced: Elegant 2x4 grid for 8 sport types
    return Container(
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 12),
          _buildSearchBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Row(
              children: [
                Icon(Icons.sports, color: Colors.teal.shade700, size: 30),
                SizedBox(width: 10),
                Text(
              'Sport Types',
              style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.teal.shade900,
                    fontSize: 28,
                    letterSpacing: 0.3,
                    fontFamily: 'Montserrat',
                    shadows: [
                      Shadow(
                        color: Colors.teal.withOpacity(0.08),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
              ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildElegantSportTypesGrid()),
        ],
      ),
    );
  }

  Widget _buildElegantSportTypesGrid() {
    // Define the 8 sport types and their assets/icons
    final List<Map<String, dynamic>> sportTypes = [
      {
        'name': 'Badminton Court',
        'image': 'lib/assets/badminton_court.jpg',
        'icon': Icons.sports_tennis,
      },
      {
        'name': 'Football Field',
        'image': 'lib/assets/football_field.jpg',
        'icon': Icons.sports_soccer,
      },
      {
        'name': 'Cricket Ground',
        'image': 'lib/assets/cricket_ground.jpg',
        'icon': Icons.sports_cricket,
      },
      {
        'name': 'Shuttlecock',
        'image': 'lib/assets/shuttle_cock.jpg',
        'icon': Icons.sports,
      },
      {
        'name': 'Swimming Pool',
        'image': 'lib/assets/swimming_pool.jpg',
        'icon': Icons.pool,
      },
      {
        'name': 'Tennis Court',
        'image': 'lib/assets/tennis_court.jpg',
        'icon': Icons.sports_tennis,
      },
      {
        'name': 'Volleyball Court',
        'image': 'lib/assets/volleyball_court.jpg',
        'icon': Icons.sports_volleyball,
      },
      {
        'name': 'Basketball Court',
        'image': 'lib/assets/basket_ball.jpg',
        'icon': Icons.sports_basketball,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardHeight = (constraints.maxHeight - 48) / 4; // 4 rows
          return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: sportTypes.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            childAspectRatio: 1.15,
            ),
            itemBuilder: (context, idx) {
            final sport = sportTypes[idx];
            return _SportTypeCard(
              name: sport['name'],
              imagePath: sport['image'],
              icon: sport['icon'],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SportTypeTurfsPage(
                      sportType: sport['name'],
                      imagePath: sport['image'],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
    );
  }

  Widget _buildDiscoverTurfsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location Filter Dropdown
          Container(
            margin: EdgeInsets.symmetric(vertical: 10),
            padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.07),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.teal.shade50,
                child: Icon(Icons.location_on, color: Colors.teal.shade700),
              ),
              title: Text(
                'Select Area',
                style: TextStyle(
                  color: Colors.teal.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedLocation,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.teal.shade700),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  style: TextStyle(
                    color: Colors.teal.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  items: _getUniqueLocations().map((String location) {
                    final displayText = location == 'All Areas'
                        ? 'All Areas'
                        : location.split('|')[0];
                    return DropdownMenuItem<String>(
                      value: location,
                      child: Row(
                        children: [
                          Icon(
                            location == 'All Areas'
                                ? Icons.public
                                : Icons.place,
                            color: Colors.teal.shade400,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              displayText,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.teal.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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
              trailing: AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                child: _selectedLocation == 'All Areas'
                    ? Icon(Icons.public, color: Colors.teal, key: ValueKey('all'))
                    : Icon(Icons.place, color: Colors.teal, key: ValueKey('place')),
              ),
            ),
          ),
          // Price Filter and Sort
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('Price Filter', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                Spacer(),
                ElevatedButton.icon(
                  icon: Icon(Icons.filter_alt, color: Colors.white),
                  label: Text(
                    _selectedPriceBucket == 'All'
                        ? 'All'
                        : _selectedPriceBucket,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    elevation: 2,
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  onPressed: () async {
                    // Generate price buckets if not already
                    final turfsSnap = await FirebaseFirestore.instance.collection('turfs').get();
                    if (!_priceBucketsInitialized) {
                    setState(() {
                        _priceBuckets = _generatePriceBuckets(turfsSnap.docs);
                        _priceBucketsInitialized = true;
                      });
                    }
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              SizedBox(height: 18),
                              Text(
                                'Select Price Range',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                  fontSize: 20,
                                ),
                              ),
                              SizedBox(height: 18),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: _priceBuckets.map((bucket) {
                                  final isSelected = _selectedPriceBucket == bucket['label'];
                                  IconData icon;
                                  final label = bucket['label'] as String;
                                  if (label.startsWith('Low')) {
                                    icon = Icons.currency_rupee;
                                  } else if (label.startsWith('Medium')) {
                                    icon = Icons.trending_flat;
                                  } else if (label.startsWith('High')) {
                                    icon = Icons.trending_up;
                                  } else if (label.startsWith('Premium')) {
                                    icon = Icons.workspace_premium;
                      } else {
                                    icon = Icons.all_inclusive;
                                  }
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedPriceBucket = bucket['label'];
                                        _minPriceFilter = bucket['min'] as double?;
                                        _maxPriceFilter = bucket['max'] as double?;
                                      });
                                      Navigator.pop(context);
                                    },
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? LinearGradient(
                                                colors: [Colors.teal.shade400, Colors.teal.shade700],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : LinearGradient(
                                                colors: [Colors.grey.shade200, Colors.grey.shade100],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: Colors.teal.withOpacity(0.18),
                                                  blurRadius: 10,
                                                  offset: Offset(0, 4),
                                                ),
                                              ]
                                            : [],
                                        border: Border.all(
                                          color: isSelected ? Colors.teal.shade700 : Colors.grey.shade300,
                                          width: isSelected ? 2.2 : 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            icon,
                                            size: 22,
                                            color: isSelected ? Colors.white : Colors.teal.shade700,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            bucket['label'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: isSelected ? Colors.white : Colors.teal.shade800,
                                              fontSize: 16,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              if (_selectedPriceBucket != 'All') ...[
                                SizedBox(height: 24),
                                Center(
                                  child: TextButton.icon(
                                    icon: Icon(Icons.clear, color: Colors.teal),
                                    onPressed: () {
                                      setState(() {
                                        _selectedPriceBucket = 'All';
                                        _minPriceFilter = null;
                                        _maxPriceFilter = null;
                                      });
                                      Navigator.pop(context);
                                    },
                                    label: Text('Reset', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                              SizedBox(height: 10),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          // Show active filter chip if not 'All'
          if (_selectedPriceBucket != 'All')
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0, left: 8.0),
              child: Row(
                children: [
                  Icon(Icons.filter_alt, color: Colors.teal, size: 20),
                  SizedBox(width: 6),
                  Chip(
                    label: Text(
                      _selectedPriceBucket,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Colors.teal,
                    avatar: Icon(Icons.tune, color: Colors.white, size: 18),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  ),
                  SizedBox(width: 8),
                  TextButton.icon(
                    icon: Icon(Icons.clear, color: Colors.teal),
                    onPressed: () {
                      setState(() {
                        _selectedPriceBucket = 'All';
                        _minPriceFilter = null;
                        _maxPriceFilter = null;
                      });
                    },
                    label: Text('Clear', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          // All Turfs Grid with Filtering
          FutureBuilder<List<DocumentSnapshot>>(
            future: _getFilteredTurfs(),
            builder: (context, filteredSnapshot) {
              if (!filteredSnapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              var filteredTurfs = filteredSnapshot.data!;
              // Apply price range filter
              double minPrice = double.infinity;
              double maxPrice = 0;
              for (final doc in filteredTurfs) {
                final turfData = doc.data() as Map<String, dynamic>;
                final low = _extractLowestPrice(turfData['price']);
                final high = _extractHighestPrice(turfData['price']);
                if (low != null && low < minPrice) minPrice = low;
                if (high != null && high > maxPrice) maxPrice = high;
              }
              if (minPrice == double.infinity) minPrice = 0;
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
                  child: Text('No turfs found in selected location or price range',
                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                );
              }
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                childAspectRatio: 0.75,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                padding: EdgeInsets.all(10),
                children: filteredTurfs.map((doc) {
                  final turfData = doc.data() as Map<String, dynamic>;
                  return _buildTurfCard(doc, turfData);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

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

  // --- Restore missing methods for tabbed navigation ---

  Widget _buildNearbyTurfs() {
    if (_isLoadingLocation) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading nearby turfs...', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            ],
          ),
        ),
      );
    }
    if (_currentPosition == null) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text('Location access required', style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Enable location services to see nearby turfs', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
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
          return Center(child: Text('No turfs available nearby', style: TextStyle(color: Colors.grey[600], fontSize: 16)));
        }
        final turfs = snapshot.data!.docs;
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
          return Center(child: Text('No turfs with location data available', style: TextStyle(color: Colors.grey[600], fontSize: 16)));
        }
        final showTurfs = nearbyTurfs.take(4).toList();
        return SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: showTurfs.length + 1,
            separatorBuilder: (context, index) => SizedBox(width: 18),
            itemBuilder: (context, index) {
              if (index == showTurfs.length) {
                // View More Turfs card
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllNearbyTurfsPage(
                          nearbyTurfs: nearbyTurfs,
                          likedTurfs: _likedTurfs,
                          currentUserId: widget.user?.uid ?? '',
                          getPriceDisplay: _getPriceDisplay,
                          calculateDistance: _calculateDistance,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 170,
                    margin: EdgeInsets.only(right: 12),
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      color: Colors.teal.shade50,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward, color: Colors.teal, size: 36),
                            SizedBox(height: 10),
                            Text('View More Turfs', style: TextStyle(color: Colors.teal[800], fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              final doc = showTurfs[index];
              final turfData = doc.data() as Map<String, dynamic>;
              final priceDisplay = _getPriceDisplay(turfData['price']);
              final distance = _calculateDistance(turfData['location'] ?? '');
              final distanceText = distance < 1000 ? '${distance.toStringAsFixed(0)}m' : '${(distance / 1000).toStringAsFixed(1)}km';
              final isLiked = _likedTurfs.contains(doc.id);
              return Container(
                width: 170,
                margin: EdgeInsets.only(left: index == 0 ? 12 : 0, right: 0),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  clipBehavior: Clip.antiAlias,
                  shadowColor: Colors.teal.withOpacity(0.18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsPage(documentId: doc.id, documentname: turfData['name'] ?? ''),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 240,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: FadeInImage.assetNetwork(
                              placeholder: 'lib/assets/static/undraw_empty_4zx0.png',
                              image: turfData['imageUrl'] ?? '',
                              fit: BoxFit.cover,
                              fadeInDuration: Duration(milliseconds: 400),
                              fadeOutDuration: Duration(milliseconds: 200),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.82)],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 14,
                          left: 14,
                          child: GestureDetector(
                            onTap: () async {
                              final user = widget.user;
                              if (user == null) return;
                              final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
                              if (isLiked) {
                                await userDoc.update({'likes.${doc.id}': FieldValue.delete()});
                                setState(() {
                                  _likedTurfs.remove(doc.id);
                                });
                                await showLikeDialog(
                                  context: context,
                                  isLiked: false,
                                  turfName: turfData['name'] ?? '',
                                );
                              } else {
                                await userDoc.set({'likes': {doc.id: true}}, SetOptions(merge: true));
                                setState(() {
                                  _likedTurfs.add(doc.id);
                                });
                                await showLikeDialog(
                                  context: context,
                                  isLiked: true,
                                  turfName: turfData['name'] ?? '',
                                );
                              }
                            },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.95),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              padding: EdgeInsets.all(4),
                              child: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.teal, size: 22),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, color: Colors.white, size: 15),
                                SizedBox(width: 3),
                                Text(distanceText, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  turfData['name'] ?? 'Unknown Turf',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 19,
                                    letterSpacing: 0.1,
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
                                SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.92),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                                    ),
                                    child: Text(
                                      priceDisplay,
                                      style: TextStyle(
                                        color: Colors.teal[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
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
            },
          ),
        );
      },
    );
  }

  Widget _buildFavouriteTurfs() {
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
                Text('Favourite Turfs', style: TextStyle(color: Colors.red[700], fontSize: 24, fontWeight: FontWeight.bold)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailsPage(documentId: doc.id, documentname: turfData['name'] ?? ''),
                          ),
                        );
                      },
                      child: Stack(
                        children: [
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
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                                ),
                              ),
                            ),
                          ),
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
                                  Text(turfData['name'] ?? 'Unknown Turf', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                  SizedBox(height: 4),
                                  Text(turfData['description'] ?? 'No description available', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w400), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  SizedBox(height: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(14)),
                                    child: Text(priceDisplay, style: TextStyle(color: Colors.teal[800], fontWeight: FontWeight.bold, fontSize: 13)),
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
        final displayTurfs = _showAllTurfs ? turfs : turfs.take(4).toList();
        final hasMoreTurfs = turfs.length > 4 && !_showAllTurfs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  label: Text('View All ${turfs.length} Turfs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTurfCard(DocumentSnapshot doc, Map<String, dynamic> turfData) {
    final priceDisplay = _getPriceDisplay(turfData['price']);
    final isLiked = _likedTurfs.contains(doc.id);
    return AnimatedContainer(
      duration: Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Card(
        elevation: 7,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailsPage(documentId: doc.id, documentname: turfData['name'] ?? ''),
              ),
            );
          },
          child: Stack(
            children: [
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
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                    ),
                  ),
                ),
              ),
              // Like button (interactive)
              Positioned(
                top: 12,
                left: 12,
                child: GestureDetector(
                  onTap: () async {
                    final user = widget.user;
                    if (user == null) return;
                    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
                    if (isLiked) {
                      // Unlike
                      await userDoc.update({'likes.${doc.id}': FieldValue.delete()});
                      setState(() {
                        _likedTurfs.remove(doc.id);
                      });
                      await showLikeDialog(
                        context: context,
                        isLiked: false,
                        turfName: turfData['name'] ?? '',
                      );
                    } else {
                      // Like
                      await userDoc.set({'likes': {doc.id: true}}, SetOptions(merge: true));
                      setState(() {
                        _likedTurfs.add(doc.id);
                      });
                      await showLikeDialog(
                        context: context,
                        isLiked: true,
                        turfName: turfData['name'] ?? '',
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.92),
                    ),
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.teal,
                      size: 20,
                    ),
                  ),
                ),
              ),
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
                      Text(turfData['name'] ?? 'Unknown Turf', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      SizedBox(height: 4),
                      Text(turfData['description'] ?? 'No description available', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w400), maxLines: 2, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(14)),
                        child: Text(priceDisplay, style: TextStyle(color: Colors.teal[800], fontWeight: FontWeight.bold, fontSize: 13)),
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
  }

  // Add this method to filter turfs by selected location
  Future<List<DocumentSnapshot>> _filterTurfsByLocation(List<DocumentSnapshot> turfs) async {
    if (_selectedLocation == 'All Areas') {
      return turfs;
    }
    // If the selected location contains coordinates (current location), filter by proximity (e.g., within 5km)
    if (_selectedLocation.contains('|')) {
      final parts = _selectedLocation.split('|');
      if (parts.length == 2) {
        final coords = parts[1].split(',');
        if (coords.length == 2) {
          final lat = double.tryParse(coords[0]);
          final lng = double.tryParse(coords[1]);
          if (lat != null && lng != null) {
            // Filter turfs within 5km radius
            return turfs.where((doc) {
              final turfData = doc.data() as Map<String, dynamic>;
              final turfLoc = turfData['location']?.toString() ?? '';
              if (turfLoc.isEmpty || !turfLoc.contains(',')) return false;
              final turfCoords = turfLoc.split(',');
              if (turfCoords.length != 2) return false;
              final turfLat = double.tryParse(turfCoords[0]);
              final turfLng = double.tryParse(turfCoords[1]);
              if (turfLat == null || turfLng == null) return false;
              final distance = Geolocator.distanceBetween(lat, lng, turfLat, turfLng);
              return distance <= 5000; // 5km radius
            }).toList();
          }
        }
      }
    }
    // Otherwise, filter by locality name
    final selectedLocality = _selectedLocation.split('|')[0].trim();
    return turfs.where((doc) {
      final docId = doc.id;
      final locality = _docIdToLocality[docId];
      return locality == selectedLocality;
    }).toList();
  }

  // Add this helper for Discover Turfs tab
  Future<List<DocumentSnapshot>> _getFilteredTurfs() async {
    final turfs = await FirebaseFirestore.instance.collection('turfs').get();
    return _filterTurfsByLocation(turfs.docs);
  }
}

// 2. Add this new SupportPage widget (place it at the end of this file):

class SupportPage extends StatefulWidget {
  final User? user;
  const SupportPage({super.key, this.user});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _isSubmitting = false;
  String _buttonText = 'Submit Ticket';
  bool _showRocket = false;

  late AnimationController _rocketController;
  late Animation<Offset> _rocketOffset;

  User? _currentUser;

  @override
  void initState() {
    super.initState();

    _currentUser = widget.user ?? FirebaseAuth.instance.currentUser;

    _rocketController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700),
    );

    _rocketOffset = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(1.5, -2),
    ).animate(CurvedAnimation(parent: _rocketController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _rocketController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _buttonText = 'Sending Ticket...';
      _showRocket = true;
    });

    _rocketController.forward();

    try {
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId': _currentUser?.uid ?? '',
        'userEmail': _currentUser?.email ?? '',
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await Future.delayed(Duration(milliseconds: 1400));
      setState(() {
        _buttonText = 'Sent!';
        _showRocket = false;
      });

      await Future.delayed(Duration(seconds: 1));
      setState(() {
        _buttonText = 'Submit Ticket';
        _isSubmitting = false;
      });

      _subjectController.clear();
      _messageController.clear();
      _rocketController.reset();
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _showRocket = false;
        _buttonText = 'Submit Ticket';
      });
      _rocketController.reset();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed. Please try again later.')),
      );
    }
  }

  Stream<QuerySnapshot> getUserTicketsStream() {
    return FirebaseFirestore.instance
        .collection('support_tickets')
        .where('userId', isEqualTo: _currentUser?.uid ?? '')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(64),
        child: AppBar(
          elevation: 0.5,
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Row(
            children: [
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Turf Booking',
                  style: TextStyle(
                    color: Color(0xFF17494D), // deep teal/dark gray
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    letterSpacing: 0.5,
                    fontFamily: 'Montserrat', // Use GoogleFonts if available
                    shadows: [
                      Shadow(
                        color: Colors.teal.withOpacity(0.08),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfilePage(user: widget.user),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal.shade100, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.teal.shade50,
                    radius: 22,
                    child: Icon(Icons.person, color: Colors.teal.shade700, size: 28),
                  ),
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1.5),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade50, Colors.grey.shade200],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              height: 1.5,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Raise a Support Ticket',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal[800])),
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
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Please enter a subject'
                            : null,
                      ),
                      SizedBox(height: 16),
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
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Please enter your message'
                            : null,
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.teal.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isSubmitting ? null : _submitTicket,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (_showRocket)
                                    SlideTransition(
                                      position: _rocketOffset,
                                      child: Icon(Icons.rocket_launch, size: 22),
                                    )
                                  else
                                    Icon(Icons.send_rounded),
                                ],
                              ),
                              SizedBox(width: 10),
                              Text(_buttonText, style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 28),
            Text('Need urgent help?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal[700])),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.email, color: Colors.teal),
                      SizedBox(width: 8),
                      SelectableText(
                        'thepunchbiz@gmail.com',
                        style: TextStyle(color: Colors.teal[900], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.phone, color: Colors.teal),
                      SizedBox(width: 8),
                      SelectableText(
                        '+91 94894 45922',
                        style: TextStyle(color: Colors.teal[900], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Previous Tickets",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal[800])),
            ),
            SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: getUserTicketsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final tickets = snapshot.data!.docs;

                if (tickets.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("No previous tickets found."),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(Icons.support_agent, color: Colors.teal),
                        title: Text(ticket['subject'] ?? 'No Subject'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(ticket['message'] ?? ''),
                            SizedBox(height: 4),
                            Text(
                              "Status: ${ticket['status']}",
                              style: TextStyle(color: Colors.grey[700], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: isLiked ? Colors.teal[50] : Colors.red[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isLiked
                    ? [Colors.teal.shade400, Colors.teal.shade700]
                    : [Colors.red.shade400, Colors.red.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isLiked ? Colors.teal : Colors.red).withOpacity(0.18),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: EdgeInsets.all(22),
            child: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
              size: 48,
            ),
          ),
          SizedBox(height: 22),
          Text(
            isLiked ? 'Added to Likes' : 'Removed from Likes',
            style: TextStyle(
              color: isLiked ? Colors.teal[800] : Colors.red[800],
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 10),
          Text(
            turfName,
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 16),
          Text(
            isLiked
                ? 'This turf has been added to your favorites!'
                : 'This turf has been removed from your favorites.',
            style: TextStyle(
              color: isLiked ? Colors.teal[900] : Colors.red[900],
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton.icon(
          icon: Icon(
            Icons.check_circle,
            color: isLiked ? Colors.teal : Colors.red,
          ),
          label: Text(
            'OK',
            style: TextStyle(
              color: isLiked ? Colors.teal : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: isLiked ? Colors.teal : Colors.red,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    ),
  );
}

class SportTypeTurfsPage extends StatelessWidget {
  final String sportType;
  final String imagePath;
  const SportTypeTurfsPage({Key? key, required this.sportType, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.teal.shade800),
        title: Text(
          sportType,
          style: TextStyle(
            color: Colors.teal.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Sport image banner
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Row(
              children: [
                Icon(Icons.sports, color: Colors.teal.shade700),
                SizedBox(width: 8),
                Text(
                  'Turfs for $sportType',
                  style: TextStyle(
                    color: Colors.teal.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('turfs').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final turfs = snapshot.data!.docs.where((doc) {
                  final turfData = doc.data() as Map<String, dynamic>;
                  final grounds = List<String>.from(turfData['availableGrounds'] ?? []);
                  return grounds.contains(sportType);
                }).toList();
                if (turfs.isEmpty) {
                  return Center(
                    child: Text(
                      'No turfs found for $sportType',
                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: turfs.length,
                  itemBuilder: (context, idx) {
                    final doc = turfs[idx];
                    final turfData = doc.data() as Map<String, dynamic>;
                    return Card(
                      elevation: 5,
                      margin: EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: ListTile(
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
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: turfData['imageUrl'] != null && turfData['imageUrl'].toString().isNotEmpty
                              ? Image.network(
                                  turfData['imageUrl'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.teal.shade50,
                                  child: Icon(Icons.sports_soccer, color: Colors.teal, size: 32),
                                ),
                        ),
                        title: Text(
                          turfData['name'] ?? '',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        subtitle: Text(
                          turfData['description'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, color: Colors.teal.shade400, size: 20),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SportTypeCard extends StatefulWidget {
  final String name;
  final String imagePath;
  final IconData icon;
  final VoidCallback onTap;
  const _SportTypeCard({
    required this.name,
    required this.imagePath,
    required this.icon,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  State<_SportTypeCard> createState() => _SportTypeCardState();
}

class _SportTypeCardState extends State<_SportTypeCard> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.08,
    )..addListener(() {
        setState(() {
          _scale = 1 - _controller.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.10),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background image with gradient overlay
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    Image.asset(
                      widget.imagePath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.08),
                            Colors.teal.withOpacity(0.10),
                            Colors.black.withOpacity(0.38),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Sport icon badge
              Positioned(
                top: 18,
                left: 18,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.10),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(7),
                  child: Icon(widget.icon, color: Colors.teal.shade700, size: 24),
                ),
              ),
              // Sport name at the bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.82),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18.5,
                        letterSpacing: 0.3,
                        fontFamily: 'Montserrat',
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 8,
                          ),
                          Shadow(
                            color: Colors.teal.withOpacity(0.18),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
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

class AllNearbyTurfsPage extends StatefulWidget {
  final List<DocumentSnapshot> nearbyTurfs;
  final Set<String> likedTurfs;
  final String currentUserId;
  final String Function(dynamic price) getPriceDisplay;
  final double Function(String location) calculateDistance;
  const AllNearbyTurfsPage({Key? key, required this.nearbyTurfs, required this.likedTurfs, required this.currentUserId, required this.getPriceDisplay, required this.calculateDistance}) : super(key: key);

  @override
  State<AllNearbyTurfsPage> createState() => _AllNearbyTurfsPageState();
}

class _AllNearbyTurfsPageState extends State<AllNearbyTurfsPage> {
  late Set<String> _likedTurfs;

  @override
  void initState() {
    super.initState();
    _likedTurfs = Set<String>.from(widget.likedTurfs);
  }

  Future<void> _toggleLike(String turfId, Map<String, dynamic> turfData) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(widget.currentUserId);
    final isLiked = _likedTurfs.contains(turfId);
    if (isLiked) {
      await userDoc.update({'likes.$turfId': FieldValue.delete()});
      setState(() {
        _likedTurfs.remove(turfId);
      });
      await showLikeDialog(context: context, isLiked: false, turfName: turfData['name'] ?? '');
    } else {
      await userDoc.set({'likes': {turfId: true}}, SetOptions(merge: true));
      setState(() {
        _likedTurfs.add(turfId);
      });
      await showLikeDialog(context: context, isLiked: true, turfName: turfData['name'] ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.teal.shade800),
        title: Text('All Nearby Turfs', style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[100],
      body: ListView.separated(
        padding: EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        itemCount: widget.nearbyTurfs.length,
        separatorBuilder: (context, index) => SizedBox(height: 18),
        itemBuilder: (context, index) {
          final doc = widget.nearbyTurfs[index];
          final turfData = doc.data() as Map<String, dynamic>;
          final priceDisplay = widget.getPriceDisplay(turfData['price']);
          final distance = widget.calculateDistance(turfData['location']?.toString() ?? '');
          final distanceText = distance < 1000 ? '${distance.toStringAsFixed(0)}m' : '${(distance / 1000).toStringAsFixed(1)}km';
          final isLiked = _likedTurfs.contains(doc.id);
          return Card(
            elevation: 7,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsPage(documentId: doc.id, documentname: turfData['name'] ?? ''),
                  ),
                );
              },
              child: Stack(
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: FadeInImage.assetNetwork(
                        placeholder: 'lib/assets/static/undraw_empty_4zx0.png',
                        image: turfData['imageUrl'] ?? '',
                        fit: BoxFit.cover,
                        fadeInDuration: Duration(milliseconds: 400),
                        fadeOutDuration: Duration(milliseconds: 200),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.82)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: GestureDetector(
                      onTap: () => _toggleLike(doc.id, turfData),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.95),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        padding: EdgeInsets.all(4),
                        child: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.teal, size: 22),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, color: Colors.white, size: 15),
                          SizedBox(width: 3),
                          Text(distanceText, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            turfData['name'] ?? 'Unknown Turf',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                              letterSpacing: 0.1,
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
                          SizedBox(height: 10),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.92),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                              ),
                              child: Text(
                                priceDisplay,
                                style: TextStyle(
                                  color: Colors.teal[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
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
          );
        },
      ),
    );
  }
}
