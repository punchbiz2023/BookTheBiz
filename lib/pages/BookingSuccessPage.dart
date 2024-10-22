import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // Import Lottie package
import 'home_page.dart';

class BookingSuccessPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.network(
              'https://lottie.host/a05029af-bd02-4208-8d2d-60612387aad2/ckm6F1hBis.json', // Lottie animation URL
              height: 350, // Adjust the height as needed
              width: 350, // Adjust the width as needed
            ),
            SizedBox(height: 20),
            Text(
              'Your booking was successful!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,color: Colors.green),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Go to Home',style: TextStyle(
                color: Colors.green, // Set text color to bright green
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
