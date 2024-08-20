import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:odp/pages/home_page.dart'; // Home page
import 'package:odp/pages/login.dart'; // Login page
import 'package:odp/pages/profile.dart'; // Profile page

import 'firebase_options.dart'; // Firebase options

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully.');
  } catch (e) {
    print('Error initializing Firebase: $e');
  }

  runApp(MyApp());
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
