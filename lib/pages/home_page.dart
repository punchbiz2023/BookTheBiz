import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:odp/pages/profile.dart';
import 'package:odp/widgets/firebaseimagecard.dart';
import 'bkdetails.dart';
import 'package:collection/collection.dart';

class HomePage1 extends StatefulWidget {
  final User? user;

  const HomePage1({Key? key, this.user}) : super(key: key);

  @override
  _HomePage1State createState() => _HomePage1State();
}

class _HomePage1State extends State<HomePage1> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Position? _currentPosition;
  String _searchText = '';
  String _pastBookingSearchText = '';
  String _sortOrder = 'Ascending';
  DateTime? _customDate; // Added custom date variable
  bool selectionMode = false; // Define the variable here
  List<Map<String, dynamic>> selectedBookings = [];
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  void clearFilters() {
    setState(() {
      _searchText = '';
      _pastBookingSearchText = '';
      _sortOrder = 'Ascending';
      _customDate = null; // Reset custom date
    });
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(user: widget.user),
      ),
    );
  }

  Stream<List<DocumentSnapshot>> _fetchTurfs() {
    return FirebaseFirestore.instance.collection('turfs').snapshots().map((snapshot) => snapshot.docs);
  }

  Stream<List<DocumentSnapshot>> _fetchPastBookings() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 0,
        flexibleSpace: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.person, color: Colors.white),
                onPressed: _navigateToProfile,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Turfs'),
            _buildTurfsSection(),
            SizedBox(height: 20),
            _buildSectionTitle('Bookings'),

            // Search bar for past bookings
            _buildPastBookingsSearchBar(),
            SizedBox(height: 10),

            // Row for filter options
            Row(
              children: [
                // Ascending/Descending dropdown
                Expanded(child: _buildSortDropdown()),

                // Spacer to create space between the dropdown and custom date button
                SizedBox(width: 0),

                // Spacer between custom date button and clear filter button
                SizedBox(width: 0),

                // Clear filters button
                IconButton(
                  icon: Icon(Icons.clear_all, color: Colors.teal),
                  onPressed: clearFilters, // Clear filters on button press
                ),
              ],
            ),
            SizedBox(height: 10),
            _buildPastBookingsSection(),
          ],
        ),
      ),
    );
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

  Widget _buildTurfsSection() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _fetchTurfs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching turfs'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No turfs available'));
        }

        var turfs = snapshot.data!;
        var filteredTurfs = turfs.where((turf) {
          var turfData = turf.data() as Map<String, dynamic>;
          return turfData['name']
              .toString()
              .toLowerCase()
              .contains(_searchText.toLowerCase());
        }).toList();

        filteredTurfs = filteredTurfs.where((turf) {
          var turfData = turf.data() as Map<String, dynamic>;
          return turfData['imageUrl'] != null && turfData['imageUrl'].isNotEmpty;
        }).toList();

        if (filteredTurfs.isEmpty) {
          return Center(child: Text('No turfs match your search'));
        }

        return Container(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: filteredTurfs.length,
            itemBuilder: (context, index) {
              var turfData = filteredTurfs[index].data() as Map<String, dynamic>;
              String imageUrl = turfData['imageUrl'] ?? '';
              String name = turfData['name'] ?? 'Unknown Turf';
              String description = turfData['description'] ?? 'No description available';
              List<String> availableGrounds = List<String>.from(turfData['availableGrounds'] ?? []);

              return FirebaseImageCard(
                imageUrl: imageUrl,
                title: name,
                description: description,
                documentId: filteredTurfs[index].id,
                docname: name,
                chips: availableGrounds,
              );
            },
          ),
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

  Widget _buildSortDropdown() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Sort dropdown
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortOrder,
                icon: Icon(Icons.filter_list, color: Colors.teal),
                style: TextStyle(color: Colors.black),
                onChanged: (String? newValue) {
                  setState(() {
                    _sortOrder = newValue!;
                  });
                },
                items: [
                  DropdownMenuItem<String>(
                    value: 'Ascending',
                    child: Container(
                      width: 100, // Set a fixed width for the dropdown item
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(Icons.arrow_upward, color: Colors.teal),
                          SizedBox(width: 5),
                          Text('old to new'), // Add text for clarity
                        ],
                      ),
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Descending',
                    child: Container(
                      width: 100, // Set a fixed width for the dropdown item
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(Icons.arrow_downward, color: Colors.teal),
                          SizedBox(width: 1),
                          Text('new to old'), // Add text for clarity
                        ],
                      ),
                    ),
                  ),
                ],
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        SizedBox(width: 10), // Space between dropdown and button
        // Custom date button
        ElevatedButton.icon(
          onPressed: () async {
            DateTime? selectedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (selectedDate != null) {
              setState(() {
                _customDate = selectedDate; // Set the selected custom date
              });
            }
          },
          icon: Icon(Icons.calendar_today, color: Colors.white),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          label: Text(''), // Add label to the button
        ),
      ],
    );
  }



  Widget _buildPastBookingsSection() {
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

        // Filter bookings based on user and search text
        var filteredBookings = pastBookings.where((booking) {
          var bookingData = booking.data() as Map<String, dynamic>;
          return bookingData['userId'] == _currentUserId && bookingData['turfName']
              .toString()
              .toLowerCase()
              .contains(_pastBookingSearchText.toLowerCase());
        }).toList();

        // Filter based on custom date
        if (_customDate != null) {
          filteredBookings = filteredBookings.where((booking) {
            var bookingData = booking.data() as Map<String, dynamic>;
            var bookingDate = DateTime.parse(bookingData['bookingDate']);
            return bookingDate.isAtSameMomentAs(_customDate!);
          }).toList();
        }

        // Separate bookings into active and past bookings
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

        // Sorting active and past bookings
        if (_sortOrder == 'Ascending') {
          activeBookings.sort((a, b) {
            var dateA = DateTime.parse((a.data() as Map<String, dynamic>)['bookingDate']);
            var dateB = DateTime.parse((b.data() as Map<String, dynamic>)['bookingDate']);
            return dateA.compareTo(dateB);
          });

          pastBookingsList.sort((a, b) {
            var dateA = DateTime.parse((a.data() as Map<String, dynamic>)['bookingDate']);
            var dateB = DateTime.parse((b.data() as Map<String, dynamic>)['bookingDate']);
            return dateA.compareTo(dateB);
          });
        } else {
          activeBookings.sort((a, b) {
            var dateA = DateTime.parse((a.data() as Map<String, dynamic>)['bookingDate']);
            var dateB = DateTime.parse((b.data() as Map<String, dynamic>)['bookingDate']);
            return dateB.compareTo(dateA);
          });

          pastBookingsList.sort((a, b) {
            var dateA = DateTime.parse((a.data() as Map<String, dynamic>)['bookingDate']);
            var dateB = DateTime.parse((b.data() as Map<String, dynamic>)['bookingDate']);
            return dateB.compareTo(dateA);
          });
        }

        // Function to check if booking is cancelled
        bool _isBookingCancelled(Map<String, dynamic> bookingData) {
          var bookingSlots = bookingData['bookingSlots'] as List<dynamic>;
          var bookingStatus = (bookingData['bookingStatus'] as List<dynamic>?) ?? ['defaultStatus'];
          // Ensure bookingStatus is not greater than bookingSlots
          if (bookingStatus.length > bookingSlots.length) {
            return true; // Treat as cancelled if bookingStatus exceeds bookingSlots
          }

          // Check if the lengths of bookingSlots and bookingStatus match
          if (bookingSlots.length != bookingStatus.length) {
            return false; // If they don't match, the booking is active
          }

          // Compare each slot with its corresponding cancelled status
          for (int i = 0; i < bookingSlots.length; i++) {
            var slot = bookingSlots[i];
            var status = bookingStatus[i];

            if (status['status'] == 'Cancelled') {
              // Check if the slot time matches with the cancellation time range
              if (slot == "${status['startTime']} - ${status['endTime']}") {
                return true; // If the status is "Cancelled" and times match, it's cancelled
              }
            }
          }

          return false; // If no cancellation found, return false
        }

        // Returning the list view with two sections: Active and Past bookings
        return Column(
          children: [
            // Active Bookings Section
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
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Active Bookings..! ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
            ListView.builder(
              itemCount: activeBookings.length,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                var bookingData = activeBookings[index].data() as Map<String, dynamic>;
                bookingData['bookID'] = activeBookings[index].id;

                // Check if bookingSlots is empty to treat it as cancelled
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
                      subtitle: Text(bookingData['bookingDate'] ?? 'No Booking Date'),
                      trailing: selectionMode && selectedBookings.contains(bookingData)
                          ? CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.check, color: Colors.white, size: 16),
                      )
                          : Text(
                        '${bookingData['amount']} INR',
                        style: TextStyle(color: Colors.teal),
                      ),
                      onTap: () {
                        if (!selectionMode) {
                          // Navigate if not in selection mode
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
              },
            ),

            // Cancelled Bookings Section
            if (activeBookings.any((booking) {
              var bookingData = booking.data() as Map<String, dynamic>;
              return bookingData['bookingSlots'] == null ||
                  bookingData['bookingSlots'].isEmpty;
            }))
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Cancelled Bookings!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ListView.builder(
              itemCount: activeBookings.length,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                var bookingData = activeBookings[index].data() as Map<String, dynamic>;
                bookingData['bookID'] = activeBookings[index].id;

                // Treat bookings with empty slots as canceled
                if (bookingData['bookingSlots'] == null ||
                    bookingData['bookingSlots'].isEmpty) {
                  return GestureDetector(
                    onLongPress: () => _enableSelectionMode(bookingData, 'cancelled'),
                    child: Card(
                      elevation: 2,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        title: Text(
                          bookingData['turfName'] ?? 'No Turf Name',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        subtitle: Text(bookingData['bookingDate'] ?? 'No Booking Date'),
                        trailing: selectionMode && selectedBookings.any((selectedBooking) {
                          bool allFieldsMatch = true;
                          List<String> fieldsToCheck = ['turfId', 'bookingDate', 'bookingSlots', 'userId'];
                          for (String key in fieldsToCheck) {
                            if (key == 'bookingSlots') {
                              if (selectedBooking['data'][key] is List &&
                                  bookingData[key] is List) {
                                if (selectedBooking['data'][key].length !=
                                    bookingData[key].length) {
                                  allFieldsMatch = false;
                                  break;
                                }
                              }
                            } else if (selectedBooking['data'][key] != bookingData[key]) {
                              allFieldsMatch = false;
                              break;
                            }
                          }
                          return allFieldsMatch;
                        })
                            ? CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.check, color: Colors.white, size: 16),
                        )
                            : Text(
                          '${bookingData['amount']} INR',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () {
                          if (!selectionMode) {
                            // Navigate to details
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

            if (pastBookingsList.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Past Bookings..! ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
            ListView.builder(
              itemCount: pastBookingsList.length,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                var bookingData = pastBookingsList[index].data() as Map<String, dynamic>;
                bookingData['bookID'] = pastBookingsList[index].id;
                return GestureDetector(
                  onLongPress: () => _enableSelectionMode(bookingData, 'past'),
                  child: Card(
                    elevation: 2,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      title: Text(
                        bookingData['turfName'],
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                      ),
                      subtitle: Text(bookingData['bookingDate']),
                      trailing: selectionMode && selectedBookings.any((selectedBooking) {
                        // Initialize the flag to track if the selected fields match
                        bool allFieldsMatch = true;
                        List<String> fieldsToCheck = ['turfId', 'bookingDate', 'bookingSlots', 'userId'];

                        for (String key in fieldsToCheck) {

                          if (key == 'bookingSlots') {
                            // Compare 'bookingSlots' list
                            if (selectedBooking['data'][key] is List && bookingData[key] is List) {
                              if (selectedBooking['data'][key].length != bookingData[key].length) {
                                allFieldsMatch = false;
                                break;
                              } else {
                                // Compare each item in the list
                                for (int i = 0; i < selectedBooking['data'][key].length; i++) {
                                  if (selectedBooking['data'][key][i] != bookingData[key][i]) {
                                    allFieldsMatch = false;
                                    break;
                                  }
                                }
                              }
                            }
                          } else {
                            // Basic comparison for other fields
                            if (selectedBooking['data'][key] != bookingData[key]) {
                              allFieldsMatch = false;
                              break; // Exit as soon as a mismatch is found
                            }
                          }
                        }

                        // Return whether all fields match
                        return allFieldsMatch;
                      })
                          ? CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.check, color: Colors.white, size: 16),
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
            if (selectionMode)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute buttons
                  children: [
                    // Cancel Button
                    ElevatedButton(
                      onPressed: () {
                        _resetSelectedBookings(); // Reset the selected bookings
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey, // Grey background for cancel button
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8), // Rounded corners
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800), // White text color
                      ),
                    ),

                    // Delete Button
                    ElevatedButton.icon(
                      onPressed: () {
                        _deleteSelectedBookings();
                      },
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.white, // Icon color
                      ),
                      label: const Text(
                        "Delete Selected Bookings",
                        style: TextStyle(
                          color: Colors.white, // Text color
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, // Red background for delete button
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8), // Rounded corners
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
// Check for mismatch between bookingStatus and bookingSlots
  void _enableSelectionMode(Map<String, dynamic> bookingData, String bookingType) {
    setState(() {
      selectionMode = true;

      // Add booking data with bookID as the key
      selectedBookings.add({
        'bookID': bookingData['bookID'], // Use bookID as the index
        'data': bookingData,
        'type': bookingType,
      });

    });
  }
  void _resetSelectedBookings() {
    setState(() {
      selectedBookings.clear();  // Clear the selected bookings list
      selectionMode = false;  // Optionally reset the selection mode
    });
  }


  // Check if the booking status is mismatched (for cancelled bookings)
  bool _hasStatusMismatch(Map<String, dynamic> bookingData) {
    if (bookingData['bookingStatus'] != null && bookingData['bookingSlots'] != null) {
      var bookingStatus = bookingData['bookingStatus'] as List;
      var bookingSlots = bookingData['bookingSlots'] as List;

      // Compare the values in bookingStatus and bookingSlots
      for (int i = 0; i < bookingStatus.length; i++) {
        if (bookingStatus[i] != bookingSlots[i]) {
          return true; // Mismatch found
        }
      }
    }
    return false; // No mismatch
  }

  // Delete selected bookings
  void _deleteSelectedBookings() async {
    bool deletionSuccessful = true;

    for (var booking in selectedBookings) {
      // Get the bookID
      String bookID = booking['bookID'];

      try {
        // Reference to the Firestore bookings collection
        var bookingRef = FirebaseFirestore.instance.collection('bookings').doc(bookID);

        // Attempt to delete the document
        await bookingRef.delete();

        print('Booking with ID: $bookID has been deleted successfully');
      } catch (e) {
        print('Failed to delete booking with ID: $bookID');
        deletionSuccessful = false;
      }
    }

    if (deletionSuccessful) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected bookings have been deleted successfully')),
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



