import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:odp/pages/StartPage.dart';
import 'package:odp/pages/Turf%20owner/Main%20Func/owner_home.dart';
import 'package:odp/pages/admincontroller.dart';
import 'package:odp/pages/home_page.dart';
import 'package:odp/pages/login.dart';
import 'package:odp/pages/view_turfs_guest.dart';
// Make sure to import or define SignupPage() in your project.
import 'package:odp/pages/sign_up_page.dart';
import 'firebase_options.dart';

// -------------- ADD THIS NEW StartPage() FILE OR CODE SNIPPET BELOW --------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
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
      title: 'BookTheBiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routes: {
        '/login': (context) => LoginApp(),
        '/guest': (context) => ViewTurfsGuestPage(),
        // ...other routes...
      },
      home: SplashScreen(), // Start with splash screen
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('Firebase initialized successfully.');
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller.forward();
        
        // Navigate to home page after animation
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => StartPage(), // <-- Show StartPage after splash
              ),
            );
          }
        });
      }
    } catch (e) {
      print('Error initializing Firebase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing app. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _animation,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.sports_soccer,
                    size: 80,
                    color: Colors.teal,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            if (_isInitialized)
              FadeTransition(
                opacity: _animation,
                child: Text(
                  'BookTheBiz',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------- AUTH WRAPPER ----------------------
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // If user is admin
      if (user.email == 'adminpunchbiz@gmail.com') {
        return AdminControllersPage();
      }
      // Otherwise, check user type from Firestore
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // You can reuse the splash screen or show a loader
            return SplashScreen();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading user data'));
          }
          if (snapshot.hasData && snapshot.data != null) {
            var userType = snapshot.data!.get('userType');
            if (userType == 'Turf Owner') {
              return HomePage2();
            } else {
              return HomePage1(user: user);
            }
          }
          // Fallback to StartPage if user data not found
          return StartPage();
        },
      );
    } else {
      // <--- HERE: Navigate to StartPage() instead of LoginApp() --->
      return StartPage();
    }
  }
}

// -----------------------------------------------------------
// Optionally, start a performance trace if you use Firebase Performance
void startPerformanceTrace() async {
  final Trace trace = FirebasePerformance.instance.newTrace('auth_wrapper_trace');
  trace.start();
  await Future.delayed(const Duration(seconds: 1));
  trace.stop();
}
