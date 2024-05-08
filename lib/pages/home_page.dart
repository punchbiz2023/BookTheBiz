// Home Page
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class HomePage1 extends StatefulWidget {
  @override
  _HomePage1State createState() => _HomePage1State();
}

class _HomePage1State extends State<HomePage1> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _bookingCount = 3; // Example booking count

  bool _isDrawerOpen = false;
  double _xOffset = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      backgroundColor: Color(0xff192028),
      body: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            _xOffset += details.delta.dx;
            if (_xOffset > 200) {
              _isDrawerOpen = true;
            } else {
              _isDrawerOpen = false;
            }
          });
        },
        onHorizontalDragEnd: (details) {
          setState(() {
            if (_xOffset > 100) {
              _xOffset = 250;
              _isDrawerOpen = true;
            } else {
              _xOffset = 0;
              _isDrawerOpen = false;
            }
          });
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  Text(
                    'Bookings for ${_selectedDay?.day}/${_selectedDay?.month}/${_selectedDay?.year}',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  SizedBox(height: 10),
                  TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) {
                      if (_selectedDay == null) {
                        return false;
                      }
                      return isSameDay(day, _selectedDay!);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                    },
                    headerStyle: HeaderStyle(
                      titleTextStyle: TextStyle(
                        color: Colors.white, // Change the color of the header text
                      ),
                      leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white), // Change the color of the left arrow
                      rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white), // Change the color of the right arrow
                    ),
                    calendarStyle: CalendarStyle(
                      defaultTextStyle: TextStyle(
                        color: Colors.white, // Change the color of the default text
                      ),
                      weekendTextStyle: TextStyle(
                        color: Colors.white, // Change the color of the weekend text
                      ),
                      outsideTextStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5), // Change the color of the outside text
                      ),
                      selectedTextStyle: TextStyle(
                        color: Colors.white, // Change the color of the selected text
                      ),
                      todayTextStyle: TextStyle(
                        color: Colors.white, // Change the color of the today text
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Welcome to ODx App!',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  // Add booking details below the calendar
                  for (int i = 0; i < _bookingCount; i++)
                    BookingCard(),
                ],
              ),
            ),
            if (_isDrawerOpen)
              Container(
                color: Colors.white.withOpacity(0.5),
                width: 200,
              ),
          ],
        ),
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.blue, // Example color
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Booking',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
              ),
              onPressed: () {
                // Add action on arrow button pressed
              },
            ),
          ],
        ),
      ),
    );
  }
}
