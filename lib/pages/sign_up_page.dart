import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:odp/pages/login.dart'; // Import your login page
import 'package:shared_preferences/shared_preferences.dart';

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

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  bool _loading = false;
  String _userType = 'User';
  String? _errorMessage; // <-- Add this line

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _saveCredentials(String email, String password) async {
    final prefs = await _prefs;
    await prefs.setString('savedEmail', email);
    await prefs.setString('savedPassword', password);
  }

  Future<void> _signup() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // --- Check for duplicate mobile number before creating user ---
      String enteredMobile = _mobileController.text.trim().replaceAll(RegExp(r'\D'), '');
      final usersSnapshot = await _firestore.collection('users').get();
      bool mobileExists = false;
      for (var doc in usersSnapshot.docs) {
        String? mobile = doc['mobile'];
        if (mobile != null) {
          String normalizedMobile = mobile.replaceAll(RegExp(r'\D'), '');
          // Compare only the last 10 digits (for Indian numbers)
          if (normalizedMobile.endsWith(enteredMobile)) {
            mobileExists = true;
            break;
          }
        }
      }
      if (mobileExists) {
        setState(() => _loading = false);
        _showErrorDialog('This mobile number is already registered.');
        return;
      }

      // --- Show Terms and Conditions Dialog ---
      final agreed = await _showTermsAndConditionsDialog(isTurfOwner: _userType == 'Turf Owner');
      if (!agreed) {
        setState(() => _loading = false);
        Fluttertoast.showToast(
          msg: 'You must agree to the Terms and Conditions to register.',
          backgroundColor: Colors.red.shade700,
        );
        return;
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      // Save user data in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'userType': _userType,
      });

      Fluttertoast.showToast(
        msg: 'Verification email sent. Please check your inbox.',
      );

      // Ask to save credentials
      if (!mounted) return;
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.teal.shade50,
          title: Row(
            children: [
              Icon(Icons.save_alt_rounded, color: Colors.teal.shade700, size: 28),
              SizedBox(width: 10),
              Text(
                'Save Login Details?',
                style: TextStyle(
                  color: Colors.teal.shade800,
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
                'Would you like to save your email and password for faster login next time?',
                style: TextStyle(fontSize: 16, color: Colors.teal.shade900),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 18),
              Icon(Icons.lock_outline, color: Colors.teal.shade400, size: 40),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Not Now',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: Icon(Icons.save, color: Colors.white),
              label: Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ) ?? false;

      if (shouldSave) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('savedEmail', _emailController.text.trim());
        await prefs.setString('savedPassword', _passwordController.text.trim());
        Fluttertoast.showToast(
          msg: 'Login details saved successfully',
          backgroundColor: Colors.teal.shade800,
        );
      }

      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _mobileController.clear();

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showErrorDialog('This email is already registered.');
      } else if (e.code == 'invalid-email') {
        _showErrorDialog('Invalid email format.');
      } else if (e.code == 'weak-password') {
        _showErrorDialog('Password is too weak.');
      } else {
        _showErrorDialog('Signup Failed: ${e.message}');
      }
    } catch (e) {
      _showErrorDialog('Signup Failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
          content: Container(
            width: double.maxFinite,
            height: 350,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
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
              onPressed: () => Navigator.pop(context, true),
              icon: Icon(Icons.check_circle, color: Colors.white),
              label: Text('Agree', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
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
• Provide complete, accurate, and up-to-date information including turf name, location, pricing, availability, photos, and features.
• Ensure the turf is clean, well-maintained, and safe for use.
• Keep your listing updated with accurate availability and pricing.
• Comply with all applicable local and state laws.

3. BOOKING PROCESS AND CANCELLATIONS
• All bookings must be processed exclusively through the BooktheBiz platform.
• You may choose between auto-approval or manual approval of bookings.
• You must honour all confirmed bookings unless cancelled under genuine circumstances.
• Cancellations by turf owners must be made promptly. Frequent cancellations may result in penalties or listing suspension.

4. PRICING, PAYMENTS & TAXES
• You are free to set your own hourly or slot-based pricing.
• BooktheBiz will deduct a platform service fee from every successful booking.
• Payouts will be made within 3–7 business days after the booking is completed.
• You are solely responsible for declaring and paying any applicable taxes.

5. CUSTOMER EXPERIENCE AND CONDUCT
• Provide a professional, respectful experience to all users.
• Avoid discriminatory or inappropriate behavior.
• Provide access to the turf as per the booked schedule and ensure amenities are functional.

6. LIABILITY AND INSURANCE
• You are responsible for the safety, maintenance, and management of your premises.
• BooktheBiz is not liable for any damage, injury, loss, theft, or third-party claims.
• It is advised to carry appropriate property and liability insurance.

7. REVIEWS AND FEEDBACK
• Customers may leave reviews after their booking. Turf owners cannot alter or remove reviews.
• Repeated negative reviews may result in account review or listing deactivation.

8. TERMINATION AND ACCOUNT SUSPENSION
• Your account or listing may be suspended or terminated for misrepresentation, complaints, non-compliance, safety violations, or misuse.

9. INTELLECTUAL PROPERTY AND MARKETING USE
• By listing your turf, you allow BooktheBiz to use your turf’s name, images, and description for promotion.

10. DISPUTE RESOLUTION
• BooktheBiz will mediate disputes. Legal disputes are subject to the courts of Salem, Tamil Nadu, India.

11. CHANGES TO TERMS
• BooktheBiz may update these Terms at any time. Continued use constitutes acceptance.

12. CONTACT INFORMATION
Email: bookthebiza@gmail.com
Phone: +91-8248708300 (Mon-Fri 10.00 A.M - 6.00 P.M)
''';

  final String _customerTerms = '''
Terms and Conditions for Customers – BooktheBiz (India)
Effective Date: 01/04/2025
Last Updated: 01/04/2025

1. ACCOUNT REGISTRATION
• Be at least 16 years of age. (Minors may participate under adult supervision.)
• Provide accurate personal details.
• Maintain the security of your account.

2. BOOKING TERMS
• All bookings must be made through the BooktheBiz platform.
• Review turf details, availability, and pricing before confirming.
• You will receive a confirmation message upon booking.
• Some turfs may require prepayment.

3. PAYMENT POLICY
• Prices are set by the turf owner.
• Payments can be made via UPI, card, wallet, or net banking.
• A service fee may be added at booking.
• All payments are processed securely.

4. CANCELLATION AND REFUND POLICY
• Cancellations must be made within the defined window.
• Refund eligibility depends on the turf owner’s policy.
• No-shows or late arrivals are not eligible for refunds.
• Refunds, if applicable, will be processed within 5–7 business days.

5. USAGE CONDUCT
• Arrive on time and vacate the turf at the end of your booking.
• Follow all on-site rules and regulations.
• Maintain cleanliness and avoid damage.
• Respect others’ bookings.
• Avoid illegal or inappropriate activities.

6. LIABILITY
• BooktheBiz is a booking platform and does not manage turfs.
• Turf owners are responsible for their facilities.
• You participate at your own risk.

7. REVIEWS AND RATINGS
• You may leave honest feedback.
• Reviews should be respectful and fact-based.
• BooktheBiz may remove offensive or misleading reviews.

8. TERMINATION OF ACCOUNT
• Your account may be suspended for repeated no-shows, misuse, or fraudulent activity.

9. PLATFORM USAGE
• Do not misuse the BooktheBiz app or website.
• All content is protected intellectual property.

10. CHANGES TO TERMS
• BooktheBiz may update these Terms at any time. Continued use constitutes acceptance.

11. GOVERNING LAW
• These Terms are governed by the laws of India. Disputes are subject to the courts of Salem, Tamil Nadu, India.

12. CONTACT US
Email: customersbtb@gmail.com
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
