import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:odp/pages/login.dart'; // Import your login page
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Import for Timer
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

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

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  bool _loading = false;
  String _userType = 'User';
  String? _errorMessage;
  bool _showOtpStep = false;
  String? _verificationId;
  final TextEditingController _otpController = TextEditingController();

  // Add these fields to _SignUpPageState:
  int _otpSecondsRemaining = 60;
  Timer? _otpTimer;
  bool _canResendOtp = false;

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

  void _resendOtp() async {
    setState(() { _loading = true; });
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: "+91" + _mobileController.text.trim(),
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {},
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _loading = false;
            _errorMessage = 'Phone verification failed: \n"+(e.message ?? e.code);';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _loading = false;
            _verificationId = verificationId;
            _showOtpStep = true;
            _errorMessage = null;
          });
          _startOtpTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
      );
    } catch (e) {
      setState(() { _loading = false; _errorMessage = e.toString(); });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    _otpTimer?.cancel(); // Add this line
    super.dispose();
  }

  Future<void> _saveCredentials(String email, String password) async {
    final prefs = await _prefs;
    await prefs.setString('savedEmail', email);
    await prefs.setString('savedPassword', password);
  }

  Future<void> _signup() async {
    print('Signup started');
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    // Input validation before checking for duplicate mobile
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String mobile = _mobileController.text.trim();

    if (name.isEmpty) {
      setState(() => _loading = false);
      _showErrorDialog('Please enter your name.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _loading = false);
      _showErrorDialog('Please enter your email.');
      return;
    }
    if (!RegExp(r'^.+@.+\..+').hasMatch(email)) {
      setState(() => _loading = false);
      _showErrorDialog('Please enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _loading = false);
      _showErrorDialog('Please enter your password.');
      return;
    }
    if (mobile.isEmpty) {
      setState(() => _loading = false);
      _showErrorDialog('Please enter your mobile number.');
      return;
    }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      setState(() => _loading = false);
      _showErrorDialog('Please enter a valid 10-digit mobile number.');
      return;
    }

    try {
      // --- Check for duplicate mobile number before creating user ---
      String enteredMobile = mobile.replaceAll(RegExp(r'\D'), '');
      print('Checking for duplicate mobile: ' + enteredMobile);
      final usersSnapshot = await _firestore.collection('users').get();
      bool mobileExists = false;
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        if (data != null && data.containsKey('mobile')) {
          String? mob = data['mobile'];
          if (mob != null) {
            String normalizedMobile = mob.replaceAll(RegExp(r'\D'), '');
            if (normalizedMobile.endsWith(enteredMobile)) {
              mobileExists = true;
              break;
            }
          }
        }
      }
      print('Mobile exists: ' + mobileExists.toString());
      if (mobileExists) {
        setState(() => _loading = false);
        print('Duplicate mobile found, showing error dialog');
        _showErrorDialog('This mobile number is already registered.');
        return;
      }

      // --- Show Terms and Conditions Dialog ---
      print('Showing Terms and Conditions dialog');
      final agreed = await _showTermsAndConditionsDialog(isTurfOwner: _userType == 'Turf Owner');
      print('User agreed to terms: ' + agreed.toString());
      if (!agreed) {
        setState(() => _loading = false);
        Fluttertoast.showToast(
          msg: 'You must agree to the Terms and Conditions to register.',
          backgroundColor: Colors.red.shade700,
        );
        print('User did not agree to terms, aborting signup');
        return;
      }

      // 1. Create user with email/password
      print('Creating user with email: ' + email);
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('User created: ' + userCredential.user!.uid);

      // 2. Start phone verification
      print('Starting phone verification for: +91$mobile');
      await _auth.verifyPhoneNumber(
        phoneNumber: "+91"+mobile,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('Phone verification completed (auto-verification)');
          try {
            await userCredential.user!.linkWithCredential(credential);
            print('Phone credential linked to user');
            await _saveUserData(userCredential.user!);
            print('User data saved after auto-verification');
            _showSuccess();
          } catch (e) {
            print('Error during auto-verification: ' + e.toString());
            setState(() {
              _loading = false;
              _errorMessage = 'Auto-verification failed: ' + e.toString();
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Phone verification failed: ' + (e.message ?? e.code));
          setState(() {
            _loading = false;
            _errorMessage = 'Phone verification failed: \n${e.message}';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          print('OTP code sent. VerificationId: ' + verificationId);
          setState(() {
            _loading = false;
            _showOtpStep = true;
            _verificationId = verificationId;
            _errorMessage = null; // Clear previous error
          });
          _startOtpTimer(); // Add this line
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Code auto retrieval timeout. VerificationId: ' + verificationId);
          setState(() {
            _verificationId = verificationId;
          });
        },
      );
      print('verifyPhoneNumber call finished');
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ' + (e.message ?? e.code));
      setState(() {
        _loading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      print('Exception during signup: ' + e.toString());
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _verifyOtpAndLink() async {
    print('Verifying OTP and linking phone');
    if (_verificationId == null) {
      print('No verificationId present');
      return;
    }
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not found");
      print('Current user: ' + user.uid);
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      print('Linking credential to user');
      await user.linkWithCredential(credential);
      print('Credential linked, saving user data');
      await _saveUserData(user);
      print('User data saved, showing success');
      _showSuccess();
    } on FirebaseAuthException catch (e) {
      print('OTP verification failed: ' + (e.message ?? e.code));
      setState(() {
        _loading = false;
        _errorMessage = "OTP verification failed: \n${e.message}";
      });
    } catch (e) {
      print('Exception during OTP verification: ' + e.toString());
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _saveUserData(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'mobile': _mobileController.text.trim(),
      'userType': _userType,
      'uid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _showSuccess() {
    setState(() {
      _loading = false;
      _showOtpStep = false;
    });
    Fluttertoast.showToast(
      msg: 'Signup successful! You can now login.',
      backgroundColor: Colors.teal,
    );
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _mobileController.clear();
    _otpController.clear();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginApp()),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.red.shade50,
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 28),
            SizedBox(width: 10),
            Text(
              'Registration Error',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextStyle(
                color: Colors.red.shade900,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 18),
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade300, size: 40),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
  required IconData iconData,
  required String hintText,
  required TextEditingController controller,
  bool isPassword = false,
}) {
  return StatefulBuilder(
    builder: (context, setState) {
      bool _obscureText = isPassword;

      return Container(
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: controller,
          obscureText: isPassword ? _obscureText : false,
          style: TextStyle(color: Colors.teal.shade900),
          cursorColor: Colors.teal.shade900,
          decoration: InputDecoration(
            prefixIcon: Icon(iconData, color: Colors.teal.shade800),
            suffixIcon: isPassword
                ? StatefulBuilder(
                    builder: (context, setIconState) {
                      return GestureDetector(
                        onTap: () {
                          setIconState(() {
                            _obscureText = !_obscureText;
                          });
                          setState(() {}); // rebuild textfield with new obscureText
                        },
                        child: Icon(
                          _obscureText ? Icons.visibility_off : Icons.visibility,
                          color: Colors.teal.shade800,
                        ),
                      );
                    },
                  )
                : null,
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.teal.shade400),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      );
    },
  );
}

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
  

  Future<bool> _showTermsAndConditionsDialog({required bool isTurfOwner}) async {
    bool hasScrolledToEnd = false;
    final ScrollController scrollController = ScrollController();
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _onScroll() {
              if (!hasScrolledToEnd && scrollController.position.atEdge && scrollController.position.pixels == scrollController.position.maxScrollExtent) {
                setState(() {
                  hasScrolledToEnd = true;
                });
              }
            }
            scrollController.removeListener(_onScroll);
            scrollController.addListener(_onScroll);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  Icon(Icons.article_rounded, color: Colors.teal.shade700, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        isTurfOwner ? _turfOwnerTerms : _customerTerms,
                        style: TextStyle(
                          color: Colors.teal.shade900,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Decline',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: hasScrolledToEnd ? () => Navigator.pop(context, true) : null,
                  icon: Icon(Icons.check_circle, color: Colors.white),
                  label: Text('Agree', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasScrolledToEnd ? Colors.teal.shade700 : Colors.teal.shade200,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        );
      },
    ) ?? false;
  }

  // Place these at the top of your _SignupPageState class:
  final String _turfOwnerTerms = '''
TERMS AND CONDITIONS FOR TURF OWNERS – BOOKTHEBIZ (INDIA)
Effective Date: 01/04/2025
Last Updated: 01/04/2025

1. ELIGIBILITY
To list your turf on BooktheBiz, you must:
• Be at least 18 years of age.
• Be the lawful owner of the property or have legal authority to manage and lease the turf.
• Provide accurate identity proof and property documentation when requested.

2. TURF LISTING AND RESPONSIBILITIES
By listing your turf, you agree to:
• Provide complete, accurate, and up-to-date information including:
  - Turf name and location
  - Pricing, availability, photos
  - Features (lighting, seating, washrooms, etc.)
• Ensure the turf is clean, well-maintained, and safe for use.
• Keep your listing updated with accurate availability and pricing.
• Comply with all applicable local and state laws, including zoning, fire safety, noise restrictions, and municipal approvals.

3. BOOKING PROCESS AND CANCELLATIONS
• All bookings must be processed exclusively through the BooktheBiz platform.
• You may choose between auto-approval or manual approval of bookings.
• You must honour all confirmed bookings unless cancelled under genuine circumstances (e.g., weather, maintenance, natural disaster and so on).
• Cancellations by turf owners must be made promptly and full refunds should be initiated immediately. Frequent cancellations may result in penalties or listing suspension.

4. PRICING, PAYMENTS & TAXES
• You are free to set your own hourly or slot-based pricing.
• BooktheBiz will deduct a platform service fee (percentage to be communicated separately) from every successful booking.
• Payouts will be made via UPI, bank transfer, or other supported methods within 3–7 business days after the booking is completed.
• You are solely responsible for declaring and paying any applicable GST, income tax, or other government levies related to your earnings.

5. CUSTOMER EXPERIENCE AND CONDUCT
You agree to:
• Provide a professional, respectful experience to all users.
• Avoid discriminatory or inappropriate behavior.
• Provide access to the turf as per the booked schedule and ensure that amenities listed are functional.

6. LIABILITY AND INSURANCE
• You are responsible for the safety, maintenance, and management of your premises.
• BooktheBiz is not liable for any damage, injury, loss, theft, or third-party claims arising from incidents on your property.
• It is advised to carry appropriate property and liability insurance to cover unforeseen events.

7. REVIEWS AND FEEDBACK
• Customers may leave reviews after their booking. Turf owners cannot alter or remove reviews.
• Repeated negative reviews may result in account review or listing deactivation after internal verification.

8. TERMINATION AND ACCOUNT SUSPENSION
Your account or listing may be suspended or terminated under the following circumstances:
• Misrepresentation or fraudulent listings
• Multiple user complaints
• Non-compliance with Indian laws or platform policies
• Safety or hygiene violations
• Repeated booking failures or misuse of the platform

9. INTELLECTUAL PROPERTY AND MARKETING USE
• By listing your turf, you allow BooktheBiz to use your turf’s name, images, and description for platform promotion, advertisements, and social media marketing.
• You retain ownership of your content but grant us a non-exclusive license to use it for the duration of your listing.

10. DISPUTE RESOLUTION
• In case of disputes between turf owners and users, BooktheBiz will mediate to the best of its ability.
• Any legal disputes shall be subject to the jurisdiction of the courts of Salem, Tamil Nadu, India.

11. CHANGES TO TERMS
• BooktheBiz reserves the right to update or modify these Terms at any time. You will be notified through the app or email. Continued use of the platform constitutes acceptance of the revised Terms.

12. CONTACT INFORMATION
For queries, assistance, or complaints, please contact us at:
Email: btbowners@gmail.com
Phone: +91-8248708300 (Mon-Fri 10.00 A.M - 6.00 P.M)
''';

  final String _customerTerms = '''
Terms and Conditions for Customers – BooktheBiz (India)
Effective Date: 01/04/2025
Last Updated: 01/04/2025
These Terms and Conditions ("Terms") govern the use of the BooktheBiz platform ("we", "us", "our") by customers ("you", "your", "user") who wish to book sports turfs and recreational spaces listed by turf owners. By using the BooktheBiz app or website, you agree to comply with these Terms.

1. ACCOUNT REGISTRATION
To book a turf on BooktheBiz, you must:
• Be at least 16 years of age. (Minors may participate under adult supervision.)
• Provide accurate personal details (name, contact info, payment method).
• Maintain the security of your account and not share your login credentials.

2. BOOKING TERMS
• All bookings must be made through the BooktheBiz platform.
• You are responsible for reviewing turf details, availability, and pricing before confirming a booking.
• Upon booking, you will receive a confirmation message via SMS, email, or in-app notification.
• Some turfs may require prepayment or partial payment to confirm your slot.

3. PAYMENT POLICY
• Prices are displayed per hour or per slot as set by the turf owner.
• Payments can be made via UPI, debit/credit card, wallet, or net banking.
• A service fee may be added at the time of booking.
• All payments are processed securely through our payment partners.

4. CANCELLATION AND REFUND POLICY
• Cancellations must be made within the cancellation window defined on the turf listing.
• Refund eligibility depends on the turf owner’s policy (e.g., full refund if cancelled 8 hours in advance).
• No-shows or late arrivals are not eligible for refunds.
• Refunds, if applicable, will be processed within 5–7 business days.

5. USAGE CONDUCT
By using a turf through BooktheBiz, you agree to:
• Arrive on time and vacate the turf at the end of your booking.
• Follow all on-site rules and regulations as set by the turf owner or staff.
• Maintain cleanliness and avoid damaging property or equipment.
• Respect others’ bookings and not engage in disruptive behavior.
• Avoid illegal, hazardous, or inappropriate activities on the premises.

6. LIABILITY
• BooktheBiz is a booking platform and does not manage or operate the turfs.
• Turf owners are solely responsible for the safety and maintenance of their facilities.
• You acknowledge that any injuries, accidents, or losses incurred on-site are not the liability of BooktheBiz.
• You participate at your own risk and are encouraged to wear proper sports gear.

7. REVIEWS AND RATINGS
• You may leave honest feedback about your turf experience.
• Reviews should be respectful and fact-based.
• BooktheBiz may remove reviews that contain offensive, defamatory, or misleading content.

8. TERMINATION OF ACCOUNT
Your account may be suspended or terminated for:
• Repeated no-shows or cancellations
• Misuse of turfs or abusive behavior
• Attempting to bypass the platform to book directly
• Providing false information or fraudulent activity

9. PLATFORM USAGE
• You agree not to misuse the BooktheBiz app or website (e.g., hacking, scraping, spamming).
• All app content, listings, logos, and systems are protected intellectual property of BooktheBiz.

10. CHANGES TO TERMS
• BooktheBiz reserves the right to update these Terms at any time. Updated versions will be made available on the platform, and continued use constitutes your acceptance of the changes.

11. GOVERNING LAW
• These Terms are governed by the laws of India. Any disputes shall be subject to the jurisdiction of the courts of Salem, Tamil Nadu, India.

12. CONTACT US
For support or complaints, reach out to:
Email: btbcustomers@gmail.com
Phone: +918248708300 (Mon-Fri 10.00 A.M - 6.00 P.M)
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Image.asset(
          'lib/assets/logo.png', // Ensure logo.png is added to assets folder and mentioned in pubspec.yaml
          height: 40, // Adjust height as needed
          fit: BoxFit.contain,
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Register new account',
              style: TextStyle(
                color: Colors.teal.shade800,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) // <-- Show error message if present
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

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

            CustomTextField(
  iconData: Icons.lock,
  hintText: "Enter Password",
  controller: _passwordController,
  isPassword: true,
),

            const SizedBox(height: 20),

            _buildTextField(
              iconData: Icons.phone_outlined,
              hintText: 'Enter only 10 digits',
              controller: _mobileController,
            ),
            const SizedBox(height: 30),

            // OTP Step: Show OTP input and button together, else show Sign Up button
            if (_showOtpStep) ...[
              SizedBox(height: 20),
              AnimatedContainer(
                duration: Duration(milliseconds: 500),
                curve: Curves.easeOutExpo,
                padding: const EdgeInsets.all(0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade50, Colors.teal.shade100, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.teal.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.shade100.withOpacity(0.18),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.lock_clock, color: Colors.teal.shade400, size: 38),
                      SizedBox(height: 10),
                      Text(
                        'Enter the OTP sent to +91 ${_mobileController.text.trim()}',
                        style: TextStyle(
                          color: Colors.teal.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
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
                                textAlign: TextAlign.center,
                              )
                            : Text(
                                'OTP expired',
                                key: ValueKey('expired'),
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                      SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.shade100),
                        ),
                        child: TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Colors.teal.shade900, letterSpacing: 2, fontWeight: FontWeight.bold),
                          cursorColor: Colors.teal.shade900,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.lock_clock, color: Colors.teal.shade800),
                            hintText: 'OTP',
                            hintStyle: TextStyle(color: Colors.teal.shade400),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                      SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _loading ? null : _verifyOtpAndLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white),
                              )
                            : Text(
                                'Verify OTP',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      SizedBox(height: 10),
                      AnimatedOpacity(
                        opacity: _canResendOtp ? 1.0 : 0.5,
                        duration: Duration(milliseconds: 400),
                        child: ElevatedButton.icon(
                          onPressed: _canResendOtp && !_loading ? _resendOtp : null,
                          icon: Icon(Icons.refresh, color: Colors.white),
                          label: Text('Retry OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade400,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
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
                    : Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

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

class CustomTextField extends StatelessWidget {
  final IconData iconData;
  final String hintText;
  final TextEditingController controller;
  final bool isPassword;

  const CustomTextField({
    super.key,
    required this.iconData,
    required this.hintText,
    required this.controller,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return isPassword
        ? _PasswordField(
            iconData: iconData,
            hintText: hintText,
            controller: controller,
          )
        : Container(
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: controller,
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
}

class _PasswordField extends StatefulWidget {
  final IconData iconData;
  final String hintText;
  final TextEditingController controller;

  const _PasswordField({
    required this.iconData,
    required this.hintText,
    required this.controller,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: _obscureText,
        style: TextStyle(color: Colors.teal.shade900),
        cursorColor: Colors.teal.shade900,
        decoration: InputDecoration(
          prefixIcon: Icon(widget.iconData, color: Colors.teal.shade800),
          suffixIcon: GestureDetector(
            onTap: () {
              setState(() {
                _obscureText = !_obscureText;
              });
            },
            child: Icon(
              _obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.teal.shade800,
            ),
          ),
          hintText: widget.hintText,
          hintStyle: TextStyle(color: Colors.teal.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}
