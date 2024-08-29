import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingPage extends StatefulWidget {
  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  bool isCardExpanded = false;
  DateTime? selectedDate;
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book Your Turf',
            style:
                TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  isCardExpanded = !isCardExpanded;
                });
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueAccent, Colors.lightBlueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text(
                    selectedDate != null
                        ? 'Selected Date: ${DateFormat('dd-MM-yyyy').format(selectedDate!)}'
                        : 'Select Date',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: Icon(
                    isCardExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (isCardExpanded) _buildCalendar(),
            if (selectedDate != null) _buildTimeSelector(),
            Spacer(),
            if (selectedStartTime != null && selectedEndTime != null)
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    _navigateToPreviewBooking(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 5,
                    textStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Text('Preview Booking'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CalendarDatePicker(
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(DateTime.now().year + 1),
          onDateChanged: (date) {
            setState(() {
              selectedDate = date;
              isCardExpanded = false;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      children: [
        SizedBox(height: 20),
        GestureDetector(
          onTap: () async {
            final startTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (startTime != null) {
              setState(() {
                selectedStartTime = startTime;
              });
            }
          },
          child: _buildTimeCard(
            title: selectedStartTime != null
                ? 'Selected Start Time: ${selectedStartTime!.format(context)}'
                : 'Select Start Time',
          ),
        ),
        GestureDetector(
          onTap: () async {
            final endTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (endTime != null) {
              setState(() {
                selectedEndTime = endTime;
              });
            }
          },
          child: _buildTimeCard(
            title: selectedEndTime != null
                ? 'Selected End Time: ${selectedEndTime!.format(context)}'
                : 'Select End Time',
          ),
        ),
      ],
    );
  }

  Widget _buildTimeCard({required String title}) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent, Colors.lightBlueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Icon(Icons.access_time, color: Colors.white),
      ),
    );
  }

  void _navigateToPreviewBooking(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewBookingPage(
          selectedDate: selectedDate!,
          selectedStartTime: selectedStartTime!,
          selectedEndTime: selectedEndTime!,
        ),
      ),
    );
  }
}

class PreviewBookingPage extends StatelessWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedStartTime;
  final TimeOfDay selectedEndTime;

  PreviewBookingPage({
    required this.selectedDate,
    required this.selectedStartTime,
    required this.selectedEndTime,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview Booking',
            style:
                TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              title: 'Date:',
              value: DateFormat('dd-MM-yyyy').format(selectedDate),
            ),
            SizedBox(height: 10),
            _buildInfoRow(
              title: 'Start Time:',
              value: selectedStartTime.format(context),
            ),
            SizedBox(height: 10),
            _buildInfoRow(
              title: 'End Time:',
              value: selectedEndTime.format(context),
            ),
            Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Trigger Razorpay payment here
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 5,
                  textStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text('Proceed to Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({required String title, required String value}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(width: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
