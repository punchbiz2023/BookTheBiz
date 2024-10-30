
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odp/pages/Turf%20owner/owner_home.dart';
import 'package:odp/pages/Turf%20owner/turfadd.dart';
import 'package:odp/pages/home_page.dart';
import 'package:odp/pages/login.dart';
import 'package:odp/pages/profile.dart';
import 'package:odp/pages/settings.dart';

import 'firebase_options.dart';


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
      home: AuthWrapper(),  // Use AuthWrapper to determine initial screen
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get the current user
    User? user = FirebaseAuth.instance.currentUser;

    // If the user is signed in, navigate to the respective home page, else login page
    if (user != null) {
      // User is signed in, retrieve user data
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading user data'));
          }
          if (snapshot.hasData && snapshot.data != null) {
            var userType = snapshot.data!.get('userType');
            if (userType == 'Turf Owner') {
              return HomePage2(); // Turf owner home
            } else {
              return HomePage1(user: user,); // Regular user home
            }
          }
          return LoginApp(); // Fallback in case user type is not found
        },
      );
    } else {
      return LoginApp(); // Show login page if no user is signed in
    }
  }
}

