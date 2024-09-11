import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:odp/pages/Turf%20owner/turfadd.dart';
import 'package:odp/pages/home_page.dart';
import 'package:odp/pages/login.dart';
import 'package:odp/pages/profile.dart';
import 'package:odp/pages/settings.dart';

import 'firebase_options.dart'; // Firebase options file

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
        '/': (context) => LoginApp(),
        '/home': (context) => HomePage1(),
        '/profile': (context) => ProfilePage(),
        '/settings': (context) => SettingsPage(),
        '/addTurf': (context) => AddTurfPage(),
      },
      initialRoute: '/',
    );
  }
}
