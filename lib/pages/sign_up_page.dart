import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:odp/pages/login.dart'; // Import your login page
// Import your Turf Owner / Home pages if needed
// import 'package:odp/pages/Turf%20owner/Main%20Func/owner_home.dart';
// import 'package:odp/pages/home_page.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController    = TextEditingController();
  final TextEditingController _emailController   = TextEditingController();
  final TextEditingController _passwordController= TextEditingController();
  final TextEditingController _mobileController  = TextEditingController();

  bool _loading = false;
  String _userType = 'User'; // Default user type

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    setState(() {
      _loading = true;
    });
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      // Prepare user data for Firestore
      Map<String, dynamic> userData = {
        'name'     : _nameController.text.trim(),
        'email'    : _emailController.text.trim(),
        'mobile'   : _mobileController.text.trim(),
        'userType' : _userType,
      };

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);

      Fluttertoast.showToast(
        msg: 'Verification email sent. Please check your inbox.',
      );

      // Clear fields after signup
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _mobileController.clear();
    } catch (e) {
      Fluttertoast.showToast(msg: 'Signup Failed: ${e.toString()}');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Reusable TextField widget
  Widget _buildTextField({
    required IconData iconData,
    required String hintText,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(color: Colors.teal.shade900),
        cursorColor: Colors.teal.shade900,
        decoration: InputDecoration(
          prefixIcon: Icon(iconData, color: Colors.teal.shade800),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.teal.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  // User Type selector widget
  Widget _buildUserTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.teal.shade800),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _userType = 'User'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _userType == 'User'
                      ? Colors.teal.shade100
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'User',
                  style: TextStyle(
                    color: Colors.teal.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _userType = 'Turf Owner'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _userType == 'Turf Owner'
                      ? Colors.teal.shade100
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Turf Owner',
                  style: TextStyle(
                    color: Colors.teal.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar with consistent branding
      appBar: AppBar(
        title: const Text(
          'TURFY',
          style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white),
        ),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create an Account',
              style: TextStyle(
                color: Colors.teal.shade800,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildUserTypeSelector(),
            const SizedBox(height: 20),
            _buildTextField(
              iconData: Icons.person_outline,
              hintText: 'Name',
              controller: _nameController,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              iconData: Icons.email_outlined,
              hintText: 'Email',
              controller: _emailController,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              iconData: Icons.lock_outline,
              hintText: 'Password',
              controller: _passwordController,
              isPassword: true,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              iconData: Icons.phone_outlined,
              hintText: 'Mobile Number',
              controller: _mobileController,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _loading ? null : _signup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white),
              )
                  : const Text(
                'Sign Up',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LoginApp()),
                );
              },
              child: Text(
                'Already have an account? Login',
                style: TextStyle(
                  color: Colors.teal.shade600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
