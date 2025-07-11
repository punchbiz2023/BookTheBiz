import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // Import Lottie package
import 'home_page.dart';

class BookingFailedPage extends StatelessWidget {
  const BookingFailedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.network(
              'https://lottie.host/7c1cebac-5af7-4b12-8a2b-d61b749fb5ce/XEIb6NoIEU.json', // Lottie animation URL
              height: 350, // Adjust the height as needed
              width: 350, // Adjust the width as needed
            ),
            SizedBox(height: 20),
            Text(
              'Oops Failed Try Again Later!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,color: Colors.red),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Go to Home',style: TextStyle(
                color: Colors.red, // Set text color to bright green
                fontSize: 18, // Adjust font size as needed
              ),),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage1()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
