import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:odp/pages/profile.dart';
import 'package:odp/widgets/firebaseimagecard.dart';
import 'bkdetails.dart';
import 'bookings_history_page.dart'; // Import the renamed page

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

  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: Icon(Icons.person, color: Colors.teal),
              onPressed: _navigateToProfile,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(Icons.confirmation_number, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => BookingsPage()),
                );
              },
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            _buildSearchBar(),

            // Popular Turfs Section
            SizedBox(height: 20),
            _buildSectionTitle(' Turfs'),
            _buildPopularTurfs(),

            // Bookings Section
            SizedBox(height: 20),
            _buildSectionTitle('Bookings'),
            _buildPastBookingsSearchBar(),
            SizedBox(height: 10),
            DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: selectedTab == 'active'
                        ? Colors.teal
                        : selectedTab == 'past'
                            ? Colors.blue
                            : Colors.red,
                    labelColor: selectedTab == 'active'
                        ? Colors.teal
                        : selectedTab == 'past'
                            ? Colors.blue
                            : Colors.red,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: 'Active'),
                      Tab(text: 'Past'),
                      Tab(text: 'Cancelled'),
                    ],
                    onTap: (index) {
                      setState(() {
                        if (index == 0) {
                          selectedTab = 'active';
                        } else if (index == 1) {
                          selectedTab = 'past';
                        } else {
                          selectedTab = 'cancelled';
                        }
                      });
                    },
                  ),
                  SizedBox(height: 10),
                  IndexedStack(
                    index: selectedTab == 'active'
                        ? 0
                        : selectedTab == 'past'
                            ? 1
                            : 2,
                    children: [
                      _buildPastBookingsSection('active'),
                      _buildPastBookingsSection('past'),
                      _buildPastBookingsSection('cancelled'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

        // Filter turfs based on search text
        final filteredTurfs = turfs.where((doc) {
          final turfData = doc.data() as Map<String, dynamic>;
          final turfName = turfData['name']?.toString().toLowerCase() ?? '';
          return turfName.contains(_searchText.toLowerCase());
        }).toList();

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          childAspectRatio: 0.72,
          mainAxisSpacing: 21,
          crossAxisSpacing: 20,
          padding: EdgeInsets.all(10),
          children: filteredTurfs.map((doc) {
            final turfData = doc.data() as Map<String, dynamic>;

            final price = turfData['price'] is Map<String, dynamic>
                ? turfData['price']['value'] ?? 'N/A'
                : turfData['price'].toString();

            return FirebaseImageCard(
              imageUrl: turfData['imageUrl'] ?? '',
              title: turfData['name'] ?? 'Unknown Turf',
              description:
                  turfData['description'] ?? 'No description available',
              documentId: doc.id,
              docname: turfData['name'] ?? 'Unknown Turf',
              chips: List<String>.from(turfData['availableGrounds'] ?? []),
              price: price,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPastBookingsSearchBar() {
    return TextFormField(
      onChanged: (value) {
        setState(() {
          _pastBookingSearchText = value;
        });
      },
      style: TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: 'Search bookings...',
        hintStyle: TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.black54),
        ),
      ),
    );
  }

  Widget _buildPastBookingsSection(String state) {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _fetchPastBookings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching past bookings'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No past bookings found'));
        }
        var pastBookings = snapshot.data!;
        var filteredBookings = pastBookings.where((booking) {
          var bookingData = booking.data() as Map<String, dynamic>;
          return bookingData['userId'] == _currentUserId &&
              bookingData['turfName']
                  .toString()
                  .toLowerCase()
                  .contains(_pastBookingSearchText.toLowerCase());
        }).toList();

        if (_customDate != null) {
          filteredBookings = filteredBookings.where((booking) {
            var bookingData = booking.data() as Map<String, dynamic>;
            var bookingDate = DateTime.parse(bookingData['bookingDate']);
            return bookingDate.isAtSameMomentAs(_customDate!);
          }).toList();
        }

        var activeBookings = filteredBookings.where((booking) {
          var bookingData = booking.data() as Map<String, dynamic>;
          var bookingDate = DateTime.parse(bookingData['bookingDate']);
          return bookingDate.isAfter(DateTime.now());
        }).toList();

        var pastBookingsList = filteredBookings.where((booking) {
          var bookingData = booking.data() as Map<String, dynamic>;
          var bookingDate = DateTime.parse(bookingData['bookingDate']);
          return bookingDate.isBefore(DateTime.now());
        }).toList();






        if (_sortOrder == 'Ascending') {
          activeBookings.sort((a, b) {
            var dateA = DateTime.parse(
                (a.data() as Map<String, dynamic>)['bookingDate']);
            var dateB = DateTime.parse(
                (b.data() as Map<String, dynamic>)['bookingDate']);
            return dateA.compareTo(dateB);
          });

          pastBookingsList.sort((a, b) {
            var dateA = DateTime.parse(
                (a.data() as Map<String, dynamic>)['bookingDate']);
            var dateB = DateTime.parse(
                (b.data() as Map<String, dynamic>)['bookingDate']);
            return dateA.compareTo(dateB);
          });
        } else {
          activeBookings.sort((a, b) {
            var dateA = DateTime.parse(
                (a.data() as Map<String, dynamic>)['bookingDate']);
            var dateB = DateTime.parse(
                (b.data() as Map<String, dynamic>)['bookingDate']);
            return dateB.compareTo(dateA);
          });

          pastBookingsList.sort((a, b) {
            var dateA = DateTime.parse(
                (a.data() as Map<String, dynamic>)['bookingDate']);
            var dateB = DateTime.parse(
                (b.data() as Map<String, dynamic>)['bookingDate']);
            return dateB.compareTo(dateA);
          });
        }

        return Column(
          children: [
            if (selectedTab == 'active') ...[
              if (activeBookings.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No new bookings.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  itemCount: activeBookings.length,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    var bookingData =
                        activeBookings[index].data() as Map<String, dynamic>;
                    bookingData['bookID'] = activeBookings[index].id;

                    if (bookingData['bookingSlots'] == null ||
                        bookingData['bookingSlots'].isEmpty) {
                      return SizedBox();
                    }
                    return GestureDetector(
                      child: Card(
                        elevation: 2,
                        margin: EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          title: Text(
                            bookingData['turfName'] ?? 'No Turf Name',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                              bookingData['bookingDate'] ?? 'No Booking Date'),
                          trailing: Text(
                            '${bookingData['amount']} INR',
                            style: TextStyle(color: Colors.teal),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookingDetailsPage1(
                                  bookingData: bookingData,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
            ],
            if (selectedTab == 'cancelled') ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Text(
                    'Long Press on the turf to select & delete',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              ListView.builder(
                itemCount: activeBookings.length,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  var bookingData =
                      activeBookings[index].data() as Map<String, dynamic>;
                  bookingData['bookID'] = activeBookings[index].id;

                  if (bookingData['bookingSlots'] == null ||
                      bookingData['bookingSlots'].isEmpty) {
                    return GestureDetector(
                      onLongPress: () =>
                          _enableSelectionMode(bookingData, 'cancelled'),
                      child: Card(
                        elevation: 2,
                        margin: EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          title: Text(
                            bookingData['turfName'] ?? 'No Turf Name',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          subtitle: Text(
                              bookingData['bookingDate'] ?? 'No Booking Date'),
                          trailing: selectionMode &&
                                  selectedBookings.any((selectedBooking) {
                                    bool allFieldsMatch = true;
                                    List<String> fieldsToCheck = [
                                      'turfId',
                                      'bookingDate',
                                      'bookingSlots',
                                      'userId'
                                    ];
                                    for (String key in fieldsToCheck) {
                                      if (key == 'bookingSlots') {
                                        if (selectedBooking['data'][key]
                                                is List &&
                                            bookingData[key] is List) {
                                          if (selectedBooking['data'][key]
                                                  .length !=
                                              bookingData[key].length) {
                                            allFieldsMatch = false;
                                            break;
                                          }
                                        }
                                      } else if (selectedBooking['data'][key] !=
                                          bookingData[key]) {
                                        allFieldsMatch = false;
                                        break;
                                      }
                                    }
                                    return allFieldsMatch;
                                  })
                              ? CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.red,
                                  child: Icon(Icons.check,
                                      color: Colors.white, size: 16),
                                )
                              : Text(
                                  '${bookingData['amount']} INR',
                                  style: TextStyle(color: Colors.red),
                                ),
                          onTap: () {
                            if (!selectionMode) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookingDetailsPage1(
                                    bookingData: bookingData,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  } else {
                    return SizedBox();
                  }
                },
              ),
            ],
            if (selectedTab == 'past') ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Text(
                    'Long Press on the turf to select & delete',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              ListView.builder(
                itemCount: pastBookingsList.length,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  var bookingData =
                      pastBookingsList[index].data() as Map<String, dynamic>;
                  bookingData['bookID'] = pastBookingsList[index].id;
                  return GestureDetector(
                    onLongPress: () =>
                        _enableSelectionMode(bookingData, 'past'),
                    child: Card(
                      elevation: 2,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        title: Text(
                          bookingData['turfName'],
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600),
                        ),
                        subtitle: Text(bookingData['bookingDate']),
                        trailing: selectionMode &&
                                selectedBookings.any((selectedBooking) {
                                  bool allFieldsMatch = true;
                                  List<String> fieldsToCheck = [
                                    'turfId',
                                    'bookingDate',
                                    'bookingSlots',
                                    'userId'
                                  ];
                                  for (String key in fieldsToCheck) {
                                    if (key == 'bookingSlots') {
                                      if (selectedBooking['data'][key]
                                              is List &&
                                          bookingData[key] is List) {
                                        if (selectedBooking['data'][key]
                                                .length !=
                                            bookingData[key].length) {
                                          allFieldsMatch = false;
                                          break;
                                        }
                                      }
                                    } else if (selectedBooking['data'][key] !=
                                        bookingData[key]) {
                                      allFieldsMatch = false;
                                      break;
                                    }
                                  }
                                  return allFieldsMatch;
                                })
                            ? CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.teal,
                                child: Icon(Icons.check,
                                    color: Colors.white, size: 16),
                              )
                            : Text(
                                '${bookingData['amount']} INR',
                                style: TextStyle(color: Colors.teal),
                              ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookingDetailsPage1(
                                bookingData: bookingData,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
            if (selectionMode)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _resetSelectedBookings();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(
                            vertical: 13, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _deleteSelectedBookings();
                      },
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text(
                        "Delete Selected Bookings",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  void _enableSelectionMode(
      Map<String, dynamic> bookingData, String bookingType) {
    setState(() {
      selectionMode = true;
      selectedBookings.add({
        'bookID': bookingData['bookID'],
        'data': bookingData,
        'type': bookingType,
      });
    });
  }

  void _resetSelectedBookings() {
    setState(() {
      selectedBookings.clear();
      selectionMode = false;
    });
  }

  void _deleteSelectedBookings() async {
    bool deletionSuccessful = true;

    for (var booking in selectedBookings) {
      String bookID = booking['bookID'];

      try {
        var bookingRef =
            FirebaseFirestore.instance.collection('bookings').doc(bookID);
        await bookingRef.delete();
        print('Booking with ID: $bookID has been deleted successfully');
      } catch (e) {
        print('Failed to delete booking with ID: $bookID');
        deletionSuccessful = false;
      }
    }

    if (deletionSuccessful) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Selected bookings have been deleted successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Some bookings failed to delete')),
      );
    }

    setState(() {
      selectionMode = false;
      selectedBookings.clear();
    });
  }
}
