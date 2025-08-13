import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'package:odp/pages/Turf owner/Main Func/owner_home.dart';
import 'dart:async';
import 'package:sms_autofill/sms_autofill.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  _PhoneLoginPageState createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> with SingleTickerProviderStateMixin, CodeAutoFill {
  final TextEditingController _phoneController = TextEditingController();
  String? _verificationId;
  bool _otpSent = false;
  bool _isLoading = false;
  String? _receivedCode;

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // Animation
  late AnimationController _cardAnimController;
  late Animation<double> _cardScaleAnim;

  // OTP Timer
  int _otpSecondsRemaining = 60;
  Timer? _otpTimer;
  bool _canResendOtp = false;
  bool _didInitSmsListener = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only call once
    if (!_didInitSmsListener && _otpSent && Theme.of(context).platform == TargetPlatform.android) {
      SmsAutoFill().unregisterListener();
      listenForCode();
      _didInitSmsListener = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _cardScaleAnim = CurvedAnimation(
      parent: _cardAnimController,
      curve: Curves.elasticOut,
    );
    _cardAnimController.forward();
    // Do NOT use Theme.of(context) here!
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _otpTimer?.cancel();
    _cardAnimController.dispose();
    cancel(); // Dispose sms_autofill listener
    super.dispose();
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    setState(() {
      _otpSecondsRemaining = 60;
      _canResendOtp = false;
    });
    _otpTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_otpSecondsRemaining == 1) {
        timer.cancel();
        setState(() {
          _canResendOtp = true;
          _otpSecondsRemaining = 0;
        });
      } else {
        setState(() {
          _otpSecondsRemaining--;
        });
      }
    });
  }

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
            .showSnackBar(SnackBar(content: Text('Verification failed:  {e.message}')));
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _isLoading = false;
          _didInitSmsListener = false;
        });
        _startOtpTimer();
        FocusScope.of(context).requestFocus(_focusNodes[0]);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  void _resendOtp() async {
    setState(() { _isLoading = true; });
    await _sendOTP();
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

    // Fetch user document from Firestore using UID
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    setState(() => _isLoading = false);

    if (!userDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No user profile found. Please sign up first.')),
      );
      return;
    }

    final userType = userDoc['userType'] ?? 'User';

    if (userType == 'Turf Owner') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage2(),
        ),
      );
    } else if (userType == 'User') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage1(user: user),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User type not recognized. Please contact support.')),
      );
    }
  }

  // Called when code is received
  @override
  void codeUpdated() {
    setState(() {
      _receivedCode = code;
      if (_receivedCode != null && _receivedCode!.length == 6) {
        for (int i = 0; i < 6; i++) {
          _otpControllers[i].text = _receivedCode![i];
        }
      }
    });
  }

  Widget _buildOtpBox(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 48,
      height: 56,
      margin: EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _focusNodes[index].hasFocus ? Colors.teal.shade700 : Colors.teal.shade200,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
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
      body: Stack(
        children: [
          // Gradient background
          AnimatedContainer(
            duration: Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0C6157), Color(0xFF192028), Colors.teal.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: _cardScaleAnim,
        child: Container(
                padding: EdgeInsets.all(28),
          margin: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.98),
                  borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                      color: Colors.teal.withOpacity(0.13),
                      blurRadius: 32,
                      offset: Offset(0, 12),
              )
            ],
          ),
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.45,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: IntrinsicHeight(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                          AnimatedSwitcher(
                            duration: Duration(milliseconds: 400),
                            child: _otpSent
                                ? Column(
                                    key: ValueKey('otp'),
                                    children: [
                                Icon(Icons.lock_clock, color: Colors.teal.shade400, size: 38),
                                SizedBox(height: 10),
                                Text(
                                  'Enter OTP sent to',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade700,
                                    fontSize: 17,
                                  ),
                                ),
                                SizedBox(height: 2),
              Text(
                                  '+91 ${_phoneController.text.trim()}',
                style: TextStyle(
                                    color: Colors.teal.shade900,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                SizedBox(height: 18),
                                // Only render PinFieldAutoFill once for Android, else render the row of boxes
                                if (_otpSent && Theme.of(context).platform == TargetPlatform.android)
                                  Container(
                                    margin: EdgeInsets.symmetric(vertical: 8),
                                    child: PinFieldAutoFill(
                                      codeLength: 6,
                                      currentCode: _receivedCode,
                                      onCodeChanged: (code) {
                                        if (code != null && code.length == 6) {
                                          setState(() {
                                            _receivedCode = code;
                                            for (int i = 0; i < 6; i++) {
                                              _otpControllers[i].text = code[i];
                                            }
                                          });
                                        }
                                      },
                                      decoration: UnderlineDecoration(
                                        textStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                                        colorBuilder: FixedColorBuilder(Colors.teal.shade400),
                                        bgColorBuilder: FixedColorBuilder(Colors.white),
                                        gapSpace: 12,
                                        lineHeight: 2,
                                      ),
                                    ),
                                  )
                                else
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(6, (index) => _buildOtpBox(index)),
                                  ),
                                SizedBox(height: 18),
                                AnimatedSwitcher(
                                  duration: Duration(milliseconds: 400),
                                  child: _otpSecondsRemaining > 0
                                      ? Text(
                                          'Expires in 00:${_otpSecondsRemaining.toString().padLeft(2, '0')}',
                                          key: ValueKey(_otpSecondsRemaining),
                                          style: TextStyle(
                                            color: Colors.red.shade400,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            letterSpacing: 1.2,
                                          ),
                                        )
                                      : Text(
                                          'OTP expired',
                                          key: ValueKey('expired'),
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                                SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _verifyOTP,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade600,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 4,
                                    ),
                                    child: _isLoading
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(color: Colors.white),
                                          )
                                        : Text('Verify OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                SizedBox(height: 10),
                                AnimatedOpacity(
                                  opacity: _canResendOtp ? 1.0 : 0.5,
                                  duration: Duration(milliseconds: 400),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: _canResendOtp
                                            ? [Colors.teal.shade400, Colors.teal.shade700]
                                            : [Colors.grey.shade300, Colors.grey.shade400],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.teal.withOpacity(0.10),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: OutlinedButton.icon(
                                      onPressed: _canResendOtp && !_isLoading ? _resendOtp : null,
                                      icon: Icon(Icons.refresh,
                                        color: _canResendOtp ? Colors.white : Colors.grey.shade400,
                                        size: 22,
                                      ),
                                      label: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                                        child: Text(
                                          'Retry OTP',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15.5,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: Colors.transparent),
                                        backgroundColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        padding: EdgeInsets.symmetric(vertical: 13, horizontal: 18),
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              key: ValueKey('phone'),
                              children: [
                                Icon(Icons.phone_android, color: Colors.teal.shade400, size: 38),
                                SizedBox(height: 10),
                                Text(
                                  'Enter your phone number',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade700,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 18),
                                TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                                  style: TextStyle(fontSize: 18, color: Colors.teal.shade900, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        prefixText: '+91 ',
                        labelText: 'Enter only 10 digits',
                                    labelStyle: TextStyle(color: Colors.teal.shade700),
                        filled: true,
                        fillColor: Colors.teal[50],
                        border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
                        ),
                      ),
                    ),
                                SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                                    onPressed: _isLoading ? null : _sendOTP,
                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade600,
                    foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 4,
                                    ),
                                    child: _isLoading
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(color: Colors.white),
                                          )
                                        : Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}