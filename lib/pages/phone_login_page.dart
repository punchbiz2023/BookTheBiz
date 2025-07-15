import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page_via_otp.dart';
import 'package:odp/pages/Turf owner/Main Func/owner_home_via_otp.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  _PhoneLoginPageState createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  String? _verificationId;
  bool _otpSent = false;
  bool _isLoading = false;

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Future<void> _sendOTP() async {
    setState(() => _isLoading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: "+91${_phoneController.text.trim()}",
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await _redirectBasedOnUserType();
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Verification failed: ${e.message}')));
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _isLoading = false;
        });
        FocusScope.of(context).requestFocus(_focusNodes[0]);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyOTP() async {
    setState(() => _isLoading = true);
    try {
      String otp = _otpControllers.map((e) => e.text).join();
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await _redirectBasedOnUserType();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Invalid OTP')));
    }
  }

  Future<void> _redirectBasedOnUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed. Please try again.')),
      );
      return;
    }

    String enteredNumber = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');

    // 1. Search for user by phone number
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    DocumentSnapshot? matchedDoc;
    for (var doc in usersSnapshot.docs) {
      String? mobile = doc['mobile'];
      if (mobile != null) {
        String normalizedMobile = mobile.replaceAll(RegExp(r'\D'), '');
        if (normalizedMobile.endsWith(enteredNumber)) {
          matchedDoc = doc;
          break;
        }
      }
    }

    if (matchedDoc != null) {
      final userType = matchedDoc['userType'] ?? 'User';
      setState(() => _isLoading = false);
      if (userType == 'Turf Owner') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage2(userData: matchedDoc!.data() as Map<String, dynamic>),
          ),
        );
      } else if (userType == 'User') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage1(userData: matchedDoc!.data() as Map<String, dynamic>),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User type not recognized. Please contact support.')),
        );
      }
      return;
    }

    // 2. If not found, prompt for user details
    final newUserData = await _showUserRegistrationDialog(user.uid, enteredNumber);
    if (newUserData == null) {
      setState(() => _isLoading = false);
      return;
    }
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(newUserData);
    setState(() => _isLoading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage1(userData: newUserData),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showUserRegistrationDialog(String uid, String mobile) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String userType = 'User';
    bool acceptedTerms = false;
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Complete Registration'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                    DropdownButton<String>(
                      value: userType,
                      items: ['User', 'Turf Owner']
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => userType = val ?? 'User'),
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: acceptedTerms,
                          onChanged: (val) => setState(() => acceptedTerms = val ?? false),
                        ),
                        Expanded(child: Text('I accept the terms and conditions')),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isEmpty ||
                        emailController.text.isEmpty ||
                        passwordController.text.isEmpty ||
                        !acceptedTerms) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please fill all fields and accept terms.')),
                      );
                      return;
                    }
                    Navigator.of(context).pop({
                      'uid': uid,
                      'mobile': mobile,
                      'userType': userType,
                      'name': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'acceptedTerms': acceptedTerms,
                      'imageUrl': '',
                      'likes': {},
                    });
                  },
                  child: Text('Register'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.teal[50],
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.teal, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.teal[800]!, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
          } else if (value.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal[50],
      appBar: AppBar(
        title: Text('Phone Login', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal[700],
        centerTitle: true,
        elevation: 10,
        shadowColor: Colors.teal.withOpacity(0.5),
      ),
      body: Center(
        child: Container(
          padding: EdgeInsets.all(24),
          margin: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _otpSent ? 'Enter OTP sent to your phone' : 'Enter your phone number',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: Colors.teal[800]),
              ),
              SizedBox(height: 20),
              _otpSent
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (index) => _buildOtpBox(index)),
                    )
                  : TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        prefixText: '+91 ',
                        labelText: 'Phone Number',
                        filled: true,
                        fillColor: Colors.teal[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _otpSent
                          ? _verifyOTP
                          : _sendOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    shadowColor: Colors.tealAccent,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _otpSent ? 'Verify OTP' : 'Send OTP',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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