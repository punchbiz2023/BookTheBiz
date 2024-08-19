import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart'; // animation
import 'package:odp/pages/home_page.dart'; //home page
import 'package:odp/pages/login.dart'; //login
import 'package:odp/pages/profile.dart'; //profile
import 'package:permission_handler/permission_handler.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions(); // Request permissions at app start
  runApp(MyApp());
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

// Function to request permissions at the app startup
Future<void> _requestPermissions() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    await Permission.storage.request();
  }
  // Optionally, show a toast message if the permission was denied
  if (status.isDenied) {
    Fluttertoast.showToast(
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      msg: '',
    );
  }
}

// MyApp class
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ODx App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Define routes for navigation
      routes: {
        '/': (context) => LoginApp(), // Set your initial page
        '/home': (context) => HomePage1(),
        '/profile': (context) => ProfilePage(),
        // Add other routes here if needed
      },
      initialRoute: '/',
    );
  }
}
