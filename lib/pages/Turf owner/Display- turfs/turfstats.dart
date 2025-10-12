import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class Turfstats extends StatefulWidget {
  final String turfId;

  const Turfstats({super.key, required this.turfId});

  @override
  _BookingCalendarState createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<Turfstats> {
  DateTime _selectedDate = DateTime.now();
  Map<String, List<String>> _occupiedSlotsByGround = {};
  List<String> _availableGrounds = [];
  bool _isLoading = false;
  Map<String, dynamic>? _turfData;

  @override
  void initState() {
    super.initState();
    _fetchTurfData();
  }

  Future<void> _fetchTurfData() async {
    setState(() { _isLoading = true; });
    
    try {
      // Fetch turf document to get available grounds
      final turfDoc = await FirebaseFirestore.instance
          .collection('turfs')
          .doc(widget.turfId)
          .get();
      
      if (turfDoc.exists) {
        final turfData = turfDoc.data() as Map<String, dynamic>;
        _turfData = turfData;
        _availableGrounds = List<String>.from(turfData['availableGrounds'] ?? []);
        
        // Now fetch bookings for each ground
        await _fetchOccupiedSlotsForAllGrounds();
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching turf data: $e')),
      );
    }
  }

  Future<void> _fetchOccupiedSlotsForAllGrounds() async {
    String formattedDate =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    
    Map<String, List<String>> occupiedSlots = {};
    
    // Initialize with empty lists for each ground
    for (var ground in _availableGrounds) {
      occupiedSlots[ground] = [];
    }
    
    try {
      // Fetch all bookings for the selected date
      final snapshot = await FirebaseFirestore.instance
          .collection('turfs')
          .doc(widget.turfId)
          .collection('bookings')
          .where('bookingDate', isEqualTo: formattedDate)
          .get();
      
      // Group bookings by ground
      for (var doc in snapshot.docs) {
        final bookingData = doc.data() as Map<String, dynamic>;
        final ground = bookingData['selectedGround'] as String?;
        final slots = bookingData['bookingSlots'] as List<dynamic>?;
        
        if (ground != null && slots != null && _availableGrounds.contains(ground)) {
          occupiedSlots[ground]!.addAll(slots.map((slot) => slot.toString()).toList());
        }
      }
      
      setState(() {
        _occupiedSlotsByGround = occupiedSlots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching bookings: $e')),
      );
    }
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 8),
            Text('Booked', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(width: 24),
          Row(children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 8),
            Text('Available', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }

  Widget _buildGroundTabs() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableGrounds.length,
        itemBuilder: (context, index) {
          final ground = _availableGrounds[index];
          final isSelected = index == 0; // For simplicity, first ground is selected
          
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                // Handle ground selection if needed
              },
              borderRadius: BorderRadius.circular(25),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? Colors.green.withOpacity(0.1) 
                    : Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected 
                      ? Colors.green 
                      : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
                ),
                child: Center(
                  child: Text(
                    ground,
                    style: TextStyle(
                      color: isSelected ? Colors.green[800] : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotGrid() {
    if (_availableGrounds.isEmpty) {
      return Center(
        child: Text(
          'No grounds available',
          style: TextStyle(color: Colors.grey[700], fontSize: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegend(),
        const SizedBox(height: 20),
        
        // Header row with ground names
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              // First row of grounds (max 2)
              Row(
                children: [
                  // Time slot column (empty header)
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Time Slot',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  // First 2 ground columns
                  ..._availableGrounds.take(2).map((ground) => Expanded(
                    flex: 1,
                    child: Center(
                      child: Text(
                        ground,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )).toList(),
                ],
              ),
              
              // Second row of grounds (if more than 2)
              if (_availableGrounds.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      // Empty space to align with time slot column
                      const Expanded(flex: 2, child: SizedBox()),
                      // Remaining ground columns
                      ..._availableGrounds.skip(2).map((ground) => Expanded(
                        flex: 1,
                        child: Center(
                          child: Text(
                            ground,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )).toList(),
                    ],
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Time slot rows
        ..._getAllTimeSlots().map((timeSlot) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                // First row with time slot and first 2 grounds
                Row(
                  children: [
                    // Time slot
                    Expanded(
                      flex: 2,
                      child: Text(
                        timeSlot,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // First 2 ground status columns
                    ..._availableGrounds.take(2).map((ground) {
                      final isBooked = _occupiedSlotsByGround[ground]?.contains(timeSlot) ?? false;
                      return Expanded(
                        flex: 1,
                        child: Center(
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isBooked ? Colors.grey[600] : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isBooked 
                                ? null 
                                : Border.all(color: Colors.green, width: 2),
                            ),
                            child: isBooked 
                              ? const Icon(Icons.lock, size: 14, color: Colors.white)
                              : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
                
                // Second row with remaining grounds (if any)
                if (_availableGrounds.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        // Empty space to align with time slot column
                        const Expanded(flex: 2, child: SizedBox()),
                        // Remaining ground status columns
                        ..._availableGrounds.skip(2).map((ground) {
                          final isBooked = _occupiedSlotsByGround[ground]?.contains(timeSlot) ?? false;
                          return Expanded(
                            flex: 1,
                            child: Center(
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isBooked ? Colors.grey[600] : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isBooked 
                                    ? null 
                                    : Border.all(color: Colors.green, width: 2),
                                ),
                                child: isBooked 
                                  ? const Icon(Icons.lock, size: 14, color: Colors.white)
                                  : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  List<String> _getAllTimeSlots() {
    return [
      '12:00 AM - 1:00 AM',
      '1:00 AM - 2:00 AM',
      '2:00 AM - 3:00 AM',
      '3:00 AM - 4:00 AM',
      '4:00 AM - 5:00 AM',
      '5:00 AM - 6:00 AM',
      '6:00 AM - 7:00 AM',
      '7:00 AM - 8:00 AM',
      '8:00 AM - 9:00 AM',
      '9:00 AM - 10:00 AM',
      '10:00 AM - 11:00 AM',
      '11:00 AM - 12:00 PM',
      '12:00 PM - 1:00 PM',
      '1:00 PM - 2:00 PM',
      '2:00 PM - 3:00 PM',
      '3:00 PM - 4:00 PM',
      '4:00 PM - 5:00 PM',
      '5:00 PM - 6:00 PM',
      '6:00 PM - 7:00 PM',
      '7:00 PM - 8:00 PM',
      '8:00 PM - 9:00 PM',
      '9:00 PM - 10:00 PM',
      '10:00 PM - 11:00 PM',
      '11:00 PM - 12:00 AM',
    ];
  }

  Widget _buildSlotCategory(String title, List<String> timeSlots) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          ...timeSlots.map((timeSlot) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeSlot,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // First row of grounds (max 2)
                  Row(
                    children: _availableGrounds.take(2).map((ground) {
                      final isBooked = _occupiedSlotsByGround[ground]?.contains(timeSlot) ?? false;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isBooked 
                              ? Colors.grey[600] 
                              : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: isBooked 
                              ? null 
                              : Border.all(color: Colors.green, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isBooked)
                                const Icon(Icons.lock, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  ground,
                                  style: TextStyle(
                                    color: isBooked ? Colors.white : Colors.green[800],
                                    fontSize: 12,
                                    fontWeight: isBooked ? FontWeight.normal : FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  // Second row of grounds (if more than 2)
                  if (_availableGrounds.length > 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: _availableGrounds.skip(2).map((ground) {
                          final isBooked = _occupiedSlotsByGround[ground]?.contains(timeSlot) ?? false;
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: isBooked 
                                  ? Colors.grey[600] 
                                  : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: isBooked 
                                  ? null 
                                  : Border.all(color: Colors.green, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isBooked)
                                    const Icon(Icons.lock, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      ground,
                                      style: TextStyle(
                                        color: isBooked ? Colors.white : Colors.green[800],
                                        fontSize: 12,
                                        fontWeight: isBooked ? FontWeight.normal : FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSlotSelectionByCategory() {
    if (_availableGrounds.isEmpty) {
      return Center(
        child: Text(
          'No grounds available',
          style: TextStyle(color: Colors.grey[700], fontSize: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegend(),
        const SizedBox(height: 20),
        _buildSlotCategory('Early Morning', [
          '12:00 AM - 1:00 AM',
          '1:00 AM - 2:00 AM',
          '2:00 AM - 3:00 AM',
          '3:00 AM - 4:00 AM',
          '4:00 AM - 5:00 AM',
        ]),
        _buildSlotCategory('Morning', [
          '5:00 AM - 6:00 AM',
          '6:00 AM - 7:00 AM',
          '7:00 AM - 8:00 AM',
          '8:00 AM - 9:00 AM',
          '9:00 AM - 10:00 AM',
          '10:00 AM - 11:00 AM',
        ]),
        _buildSlotCategory('Afternoon', [
          '12:00 PM - 1:00 PM',
          '1:00 PM - 2:00 PM',
          '2:00 PM - 3:00 PM',
          '3:00 PM - 4:00 PM',
          '4:00 PM - 5:00 PM',
        ]),
        _buildSlotCategory('Evening', [
          '5:00 PM - 6:00 PM',
          '6:00 PM - 7:00 PM',
          '7:00 PM - 8:00 PM',
          '8:00 PM - 9:00 PM',
          '9:00 PM - 10:00 PM',
          '10:00 PM - 11:00 PM',
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Calendar Widget with clean white design
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TableCalendar(
                    firstDay: DateTime(2000),
                    lastDay: DateTime(2100),
                    focusedDay: _selectedDate,
                    selectedDayPredicate: (day) => isSameDay(day, _selectedDate),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDate = selectedDay;
                      });
                      _fetchOccupiedSlotsForAllGrounds();
                    },
                    calendarStyle: CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      todayDecoration: BoxDecoration(
                        color: Colors.blue[50],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue[300]!, width: 1),
                      ),
                      selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      todayTextStyle: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
                      defaultTextStyle: TextStyle(color: Colors.grey[800]),
                      weekendTextStyle: TextStyle(color: Colors.grey[600]),
                      holidayTextStyle: TextStyle(color: Colors.grey[600]),
                      rangeHighlightColor: Colors.green.withOpacity(0.2),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold),
                      leftChevronIcon: Icon(Icons.chevron_left, color: Colors.grey[700]),
                      rightChevronIcon: Icon(Icons.chevron_right, color: Colors.grey[700]),
                      headerPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold),
                      weekendStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                _isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: SpinKitFadingCircle(
                          color: Colors.grey[600],
                          size: 40.0,
                        ),
                      )
                    : _buildSlotSelectionByCategory(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}