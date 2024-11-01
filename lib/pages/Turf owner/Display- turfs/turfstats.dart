import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Turfstats extends StatefulWidget {
  final String turfId;

  Turfstats({required this.turfId});

  @override
  _BookingCalendarState createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<Turfstats> {
  DateTime _selectedDate = DateTime.now();
  List<String> _occupiedSlots = [];

  @override
  void initState() {
    super.initState();
    _fetchOccupiedSlots();
  }

  void _fetchOccupiedSlots() {
    String formattedDate =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    FirebaseFirestore.instance
        .collection('turfs')
        .doc(widget.turfId)
        .collection('bookings')
        .where('bookingDate', isEqualTo: formattedDate)
        .get()
        .then((snapshot) {
      setState(() {
        _occupiedSlots = snapshot.docs
            .map((doc) => (doc.data() as Map<String, dynamic>)['bookingSlots'])
            .expand((slot) => slot)
            .toList()
            .cast<String>();
      });
    });
  }

  Column _buildSlotSelectionColumn(List<String> bookedSlots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
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
                label: Text(slot, style: TextStyle(color: isBooked ? Colors.black : Colors.black)),
                backgroundColor: isBooked ? Colors.greenAccent : Colors.white,
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
                child: CalendarDatePicker(
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  onDateChanged: (date) {
                    setState(() {
                      _selectedDate = date;
                      _fetchOccupiedSlots();
                    });
                  },
                ),
              ),
            ),
            // Call the new slot selection method
            _buildSlotSelectionColumn(_occupiedSlots),
          ],
        ),
      ),
    );
  }
}
