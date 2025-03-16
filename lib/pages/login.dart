import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:odp/pages/Turf%20owner/Main%20Func/owner_home.dart';
import 'package:odp/pages/admincontroller.dart';
import 'package:odp/pages/home_page.dart';
import 'package:odp/pages/sign_up_page.dart';

class LoginApp extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginApp> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);

    try {
      final UserCredential userCredential =
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        await Firebase.initializeApp();
        final FirebaseFirestore firestore = FirebaseFirestore.instance;
        final DocumentReference userRef =
        firestore.collection('users').doc(userCredential.user!.uid);
        final userData = await userRef.get().then((ds) => ds.data() as Map<String, dynamic>?);

        if (userData != null) {
          String userType = userData['userType'];

          if (userType == 'adminuser') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AdminControllersPage()),
            );
          } else if (userType == 'Turf Owner') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage2()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => HomePage1(user: userCredential.user)),
            );
          }

          Fluttertoast.showToast(msg: 'Login Successful');
        } else {
          Fluttertoast.showToast(msg: 'User data not found');
        }
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
      setState(() => _loading = false);
    }
  }



  Future<void> _forgotPassword() async {
    String email = _emailController.text.trim();
    if (email.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter your email address');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      Fluttertoast.showToast(msg: 'Password reset email sent!');
    } catch (e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'user-not-found') {
          Fluttertoast.showToast(msg: 'No user found for that email.');
        } else if (e.code == 'invalid-email') {
          Fluttertoast.showToast(msg: 'Invalid email format.');
        } else {
          Fluttertoast.showToast(msg: 'Error: ${e.message}');
        }
      } else {
        Fluttertoast.showToast(msg: 'Error: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar with teal background and "TURFY" title
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Image.asset(
          'lib/assets/logo.png', // Ensure logo.png is added to assets folder and mentioned in pubspec.yaml
          height: 40, // Adjust height as needed
          fit: BoxFit.contain,
        ),
      ),
      // White background for a clean, professional look
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Center(
          // Center vertically and horizontally
          child: Column(
            mainAxisSize: MainAxisSize.min, // Minimize vertical space usage
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Heading
              Text(
                'Login',
                style: TextStyle(
                  color: Colors.teal.shade800,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center, // Center the text horizontally
              ),
              const SizedBox(height: 30),

              // Email TextField
              _buildTextField(
                iconData: Icons.email_outlined,
                hintText: 'Email',
                controller: _emailController,
                isObscure: false,
              ),
              const SizedBox(height: 20),

              // Password TextField
              _buildTextField(
                iconData: Icons.lock_outline,
                hintText: 'Password',
                controller: _passwordController,
                isObscure: true,
              ),
              const SizedBox(height: 10),

              // Forgot Password
              GestureDetector(
                onTap: _forgotPassword,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Login Button
              ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 12),

              // Sign Up Button
              OutlinedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignupPage()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.teal.shade600, width: 2),
                  foregroundColor: Colors.teal.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable TextField widget
  Widget _buildTextField({
    required IconData iconData,
    required String hintText,
    required TextEditingController controller,
    required bool isObscure,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        style: TextStyle(color: Colors.teal.shade900),
        cursorColor: Colors.teal.shade900,
        decoration: InputDecoration(
          prefixIcon: Icon(iconData, color: Colors.teal.shade800),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.teal.shade400),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}
