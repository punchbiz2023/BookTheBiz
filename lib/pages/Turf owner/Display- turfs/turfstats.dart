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
  List<String> _occupiedSlots = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchOccupiedSlots();
  }

  void _fetchOccupiedSlots() async {
    setState(() { _isLoading = true; });
    String formattedDate =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('turfs')
          .doc(widget.turfId)
          .collection('bookings')
          .where('bookingDate', isEqualTo: formattedDate)
          .get();
      setState(() {
        _occupiedSlots = snapshot.docs
            .map((doc) => (doc.data())['bookingSlots'] as List<dynamic>?)
            .where((slots) => slots != null)
            .expand((slots) => slots!)
            .map((slot) => slot.toString())
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(Icons.lock, color: Colors.grey[600], size: 18),
            SizedBox(width: 4),
            Text('Booked', style: TextStyle(color: Colors.grey[600])),
          ]),
          SizedBox(width: 16),
          Row(children: [
            Container(width: 18, height: 18, decoration: BoxDecoration(border: Border.all(color: Colors.green, width: 2), borderRadius: BorderRadius.circular(9))),
            SizedBox(width: 4),
            Text('Available', style: TextStyle(color: Colors.green)),
          ]),
        ],
      ),
    );
  }

  Column _buildSlotSelectionColumn(List<String> bookedSlots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        _buildLegend(),
        _buildSlotChips('Early Morning', '12 AM - 5 AM', [
          '12:00 AM - 1:00 AM',
          '1:00 AM - 2:00 AM',
          '2:00 AM - 3:00 AM',
          '3:00 AM - 4:00 AM',
          '4:00 AM - 5:00 AM',
        ], bookedSlots),
        SizedBox(height: 10),
        _buildSlotChips('Morning', '5 AM - 11 AM', [
          '5:00 AM - 6:00 AM',
          '6:00 AM - 7:00 AM',
          '7:00 AM - 8:00 AM',
          '8:00 AM - 9:00 AM',
          '9:00 AM - 10:00 AM',
          '10:00 AM - 11:00 AM',
        ], bookedSlots),
        SizedBox(height: 10),
        _buildSlotChips('Afternoon', '12 PM - 5 PM', [
          '12:00 PM - 1:00 PM',
          '1:00 PM - 2:00 PM',
          '2:00 PM - 3:00 PM',
          '3:00 PM - 4:00 PM',
          '4:00 PM - 5:00 PM',
        ], bookedSlots),
        SizedBox(height: 10),
        _buildSlotChips('Evening', '5 PM - 11 PM', [
          '5:00 PM - 6:00 PM',
          '6:00 PM - 7:00 PM',
          '7:00 PM - 8:00 PM',
          '8:00 PM - 9:00 PM',
          '9:00 PM - 10:00 PM',
          '10:00 PM - 11:00 PM',
        ], bookedSlots),
      ],
    );
  }

  Widget _buildSlotChips(String title, String subtitle, List<String> slots, List<String> bookedSlots) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
          Text(subtitle, style: TextStyle(color: Colors.grey[600])),
          Wrap(
            spacing: 8.0,
            children: slots.map((slot) {
              bool isBooked = bookedSlots.contains(slot);
              return Chip(
                avatar: isBooked ? Icon(Icons.lock, size: 18, color: Colors.white) : null,
                label: Text(
                  slot,
                  style: TextStyle(
                    color: isBooked ? Colors.white : Colors.black,
                  ),
                ),
                backgroundColor: isBooked ? Colors.grey[500] : Colors.white,
                shape: StadiumBorder(side: isBooked ? BorderSide.none : BorderSide(color: Colors.green, width: 1.5)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.lightBlue[100]!, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Calendar Widget
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 7,
                      offset: Offset(0, 3),
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
                    _fetchOccupiedSlots();
                  },
                  calendarStyle: CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.lightBlue,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    todayTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
              ),
            ),
            _isLoading
                ? Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: SpinKitFadingCircle(
                      color: Colors.green,
                      size: 40.0,
                    ),
                  )
                : _buildSlotSelectionColumn(_occupiedSlots),
          ],
        ),
      ),
    );
  }
}
