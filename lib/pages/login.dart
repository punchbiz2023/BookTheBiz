import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:odp/pages/Turf%20owner/owner_home.dart';
import 'package:odp/pages/home_page.dart';
import 'package:odp/pages/sign_up_page.dart';

class LoginApp extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginApp> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;

  late AnimationController controller1;
  late AnimationController controller2;
  late Animation<double> animation1;
  late Animation<double> animation2;
  late Animation<double> animation3;
  late Animation<double> animation4;

  @override
  void initState() {
    super.initState();

    controller1 = AnimationController(
      vsync: this,
      duration: Duration(seconds: 5),
    );
    animation1 = Tween<double>(begin: .1, end: .15).animate(
      CurvedAnimation(
        parent: controller1,
        curve: Curves.easeInOut,
      ),
    )
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          controller1.reverse();
        } else if (status == AnimationStatus.dismissed) {
          controller1.forward();
        }
      });
    animation2 = Tween<double>(begin: .02, end: .04).animate(
      CurvedAnimation(
        parent: controller1,
        curve: Curves.easeInOut,
      ),
    )..addListener(() {
        setState(() {});
      });

    controller2 = AnimationController(
      vsync: this,
      duration: Duration(seconds: 5),
    );
    animation3 = Tween<double>(begin: .41, end: .38).animate(CurvedAnimation(
      parent: controller2,
      curve: Curves.easeInOut,
    ))
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          controller2.reverse();
        } else if (status == AnimationStatus.dismissed) {
          controller2.forward();
        }
      });
    animation4 = Tween<double>(begin: 170, end: 190).animate(
      CurvedAnimation(
        parent: controller2,
        curve: Curves.easeInOut,
      ),
    )..addListener(() {
        setState(() {});
      });

    Timer(Duration(milliseconds: 2500), () {
      controller1.forward();
    });

    controller2.forward();
  }

  @override
  void dispose() {
    controller1.dispose();
    controller2.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
    });

    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim());

      if (userCredential.user != null) {
        // Get the user type
        await Firebase.initializeApp(); // Initialize Firebase
        final FirebaseFirestore firestore = FirebaseFirestore
            .instance; // Get a reference to the Firestore database
        final DocumentReference userRef = firestore.collection('users').doc(
            userCredential.user!.uid); // Get a reference to the user's document
        Map<String, dynamic> userData = await userRef
            .get()
            .then((DocumentSnapshot ds) => ds.data() as Map<String, dynamic>);

        // String emailPattern =
        //     r"/^([a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})$/";
        // RegExp regex = RegExp(emailPattern);
        // String email = _emailController.text.trim();
        //
        // if (!regex.hasMatch(email)) {
        //   Fluttertoast.showToast(msg: 'Invalid email format');
        //   return;
        // }

        if (userData['userType'] == 'Turf Owner') {
          // Navigate to the custom page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage2()),
          );
        } else {
          // Navigate to the other page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage1()),
          );
        }
        Fluttertoast.showToast(msg: 'Login Successful');
      }
    } catch (e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'user-not-found') {
          Fluttertoast.showToast(msg: 'User not found');
        } else if (e.code == 'invalid-email') {
          Fluttertoast.showToast(msg: 'Invalid email format');
        } else if (e.code == 'wrong-password') {
          Fluttertoast.showToast(msg: 'Wrong password');
        } else {
          Fluttertoast.showToast(msg: 'Login error: ${e.message}');
        }
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Color(0xff192028),
      body: Stack(
        children: [
          Positioned(
            top: size.height * (animation2.value + .58),
            left: size.width * .21,
            child: CustomPaint(
              painter: MyPainter(50),
            ),
          ),
          Positioned(
            top: size.height * .98,
            left: size.width * .1,
            child: CustomPaint(
              painter: MyPainter(animation4.value - 30),
            ),
          ),
          Positioned(
            top: size.height * .5,
            left: size.width * (animation2.value + .8),
            child: CustomPaint(
              painter: MyPainter(30),
            ),
          ),
          Positioned(
            top: size.height * animation3.value,
            left: size.width * (animation1.value + .1),
            child: CustomPaint(
              painter: MyPainter(60),
            ),
          ),
          Positioned(
            top: size.height * .1,
            left: size.width * .8,
            child: CustomPaint(
              painter: MyPainter(animation4.value),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(size.width * 0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Login',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.7),
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    wordSpacing: 4,
                  ),
                ),
                const SizedBox(height: 30),
                component1(Icons.email_outlined, 'Email...', false, true,
                    _emailController),
                const SizedBox(height: 20),
                component1(Icons.lock_outline, 'Password...', true, false,
                    _passwordController),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.grey.withOpacity(0.3), // Text color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0, // Remove shadow if desired
                    padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12), // Adjust padding as needed
                  ),
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Login',
                          style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignupPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.grey.withOpacity(0.3), // Text color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0, // Remove shadow if desired
                    padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12), // Adjust padding as needed
                  ),
                  child: const Text('Create New Account',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget component1(IconData icon, String hintText, bool isPassword,
      bool isEmail, TextEditingController controller) {
    Size size = MediaQuery.of(context).size;

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaY: 15,
          sigmaX: 15,
        ),
        child: Container(
          height: size.width / 8,
          width: size.width / 1.2,
          alignment: Alignment.center,
          padding: EdgeInsets.only(right: size.width / 30),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.05),
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(color: Colors.white.withOpacity(.8)),
            cursorColor: Colors.white,
            obscureText: isPassword,
            keyboardType:
                isEmail ? TextInputType.emailAddress : TextInputType.text,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Colors.white.withOpacity(.7),
              ),
              border: InputBorder.none,
              hintMaxLines: 1,
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.white.withOpacity(.5)),
            ),
          ),
        ),
      ),
    );
  }
}

class MyPainter extends CustomPainter {
  final double radius;

  MyPainter(this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Color(0xffFD5E3D), Color(0xffC43990)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(
        center: Offset(0, 0),
        radius: radius,
      ));

    canvas.drawCircle(Offset.zero, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class MyBehavior extends ScrollBehavior {
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }

  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
