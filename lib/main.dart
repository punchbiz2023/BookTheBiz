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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SplashScreen(), // Start with splash screen
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _iconAnimation;
  late AnimationController _textController;
  late Animation<double> _textFadeAnimation;
  late AnimationController _subtitleController;
  late Animation<double> _subtitleFadeAnimation;

  @override
  void initState() {
    super.initState();

    // Icon Animation: scales in with an easeOutBack effect
    _iconController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    _iconAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeOutBack),
    );
    _iconController.forward();

    // Title fade-in Animation (staggered by 500ms)
    _textController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    Future.delayed(Duration(milliseconds: 500), () {
      _textController.forward();
    });

    // Subtitle fade-in Animation (staggered by 1000ms)
    _subtitleController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    _subtitleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeIn),
    );
    Future.delayed(Duration(milliseconds: 1000), () {
      _subtitleController.forward();
    });

    // Navigate to AuthWrapper after 5 seconds
    Future.delayed(Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AuthWrapper()),
      );
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    _textController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradient background with premium teal shades
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade900, Colors.teal.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated sports icon using ScaleTransition
              ScaleTransition(
                scale: _iconAnimation,
                child: Icon(
                  Icons.sports_soccer,
                  size: 120,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              // Fade-in title text
              FadeTransition(
                opacity: _textFadeAnimation,
                child: Text(
                  'Turf Booking App',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black26,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              // Fade-in subtitle text
              FadeTransition(
                opacity: _subtitleFadeAnimation,
                child: Text(
                  'Experience Premium Turf Booking',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
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
