import 'dart:io'; // For working with File
// For base64 encoding
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Add this import
import 'login.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// This painter draws a gradient from teal to dark,
/// plus a subtle dotted pattern on top.
class DottedBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw a vertical gradient
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF0C6157), // Teal at the top
        Color(0xFF192028), // Dark color at the bottom
      ],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // Draw a dotted pattern
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.05);
    const double dotRadius = 2.0;
    const double dotSpacing = 15.0;

    for (double y = dotSpacing / 2; y < size.height; y += dotSpacing) {
      for (double x = dotSpacing / 2; x < size.width; x += dotSpacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(DottedBackgroundPainter oldDelegate) => false;
}

class ProfilePage extends StatefulWidget {
  final User? user; // User object to hold Firebase user information

  const ProfilePage({super.key, this.user});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;
  bool _isEditing = false;
  bool _showSupport = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _supportSubjectController = TextEditingController();
  final TextEditingController _supportMessageController = TextEditingController();
  final GlobalKey<FormState> _supportFormKey = GlobalKey<FormState>();
  bool _isSubmittingSupport = false;
  Map<String, dynamic>? _userData;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() {
    final user = widget.user ?? FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .then((doc) {
        if (doc.exists) {
          setState(() {
            _userData = doc.data();
            _nameController.text = _userData?['name'] ?? '';
            _mobileController.text = _userData?['mobile'] ?? '';
          });
        }
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image. Please try again.')),
      );
    }
  }

  Future<String?> _uploadProfileImage(String uid, File imageFile) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  void _showEditRestrictionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.red.shade50,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
            SizedBox(width: 10),
            Text('Edit Restricted', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'To change your mobile number or email, please raise a support ticket. We will respond in 3–4 business days.',
          style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() { _isSaving = true; });
    final user = widget.user ?? FirebaseAuth.instance.currentUser;
    if (user != null) {
      String? imageUrl = _userData?['imageUrl'];
      if (_profileImage != null) {
        imageUrl = await _uploadProfileImage(user.uid, _profileImage!);
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _nameController.text,
        'imageUrl': imageUrl,
      });
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      _fetchUserData();
    } else {
      setState(() { _isSaving = false; });
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginApp()),
        (Route<dynamic> route) => false, // Remove all previous routes
      );
    } catch (e) {
      print('Error logging out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  Future<void> _showLogoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Logout'),
          ],
        ),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (result == true) {
      _logout();
    }
  }

  Future<void> _sendSupportAcknowledgementEmail(String email, String subject) async {
    final url = Uri.parse('https://cloud-functions-vnxv.onrender.com/sendSupportAck');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'subject': subject}),
      );
      if (response.statusCode != 200) {
        print('Failed to send acknowledgement email: ${response.body}');
      }
    } catch (e) {
      print('Failed to send acknowledgement email: ${e.toString()}');
    }
  }

  Future<void> _submitSupportTicket() async {
    if (!_supportFormKey.currentState!.validate()) return;
    setState(() => _isSubmittingSupport = true);
    final user = widget.user ?? FirebaseAuth.instance.currentUser;
    try {
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId': user?.uid ?? '',
        'userEmail': user?.email ?? '',
        'subject': _supportSubjectController.text.trim(),
        'message': _supportMessageController.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your query will be answered in 3 business days & sent to your registered email/phone number.'),
          backgroundColor: Colors.teal,
        ),
      );
      if (user?.email != null && user!.email!.isNotEmpty) {
        await _sendSupportAcknowledgementEmail(user.email!, _supportSubjectController.text.trim());
      }
      _supportSubjectController.clear();
      _supportMessageController.clear();
      setState(() => _showSupport = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed. Please try again later.')),
      );
    } finally {
      setState(() => _isSubmittingSupport = false);
    }
  }

  void _showLegalPoliciesModal() {
    final userType = _userData?['userType'] ?? 'User';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return DefaultTabController(
          length: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.teal.shade700,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: EdgeInsets.symmetric(vertical: 24, horizontal: 18),
                width: double.infinity,
                child: Row(
                  children: [
                    Icon(Icons.policy, color: Colors.white, size: 32),
                    SizedBox(width: 14),
                    Text('Legal & Policies', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 0.2)),
                  ],
                ),
              ),
              TabBar(
                labelColor: Colors.teal.shade800,
                unselectedLabelColor: Colors.teal.shade300,
                indicatorColor: Colors.teal.shade700,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                tabs: [
                  Tab(icon: Icon(Icons.privacy_tip), text: 'Privacy Policy'),
                  Tab(icon: Icon(Icons.gavel), text: 'General Terms'),
                  Tab(icon: Icon(Icons.article), text: userType == 'Turf Owner' ? 'Owner Terms' : 'User Terms'),
                ],
              ),
              Container(
                height: MediaQuery.of(context).size.height * 0.55,
                child: TabBarView(
                  children: [
                    _buildLegalText(_privacyPolicy),
                    _buildLegalText(_generalTerms),
                    _buildLegalText(userType == 'Turf Owner' ? _ownerTerms : _userTerms),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegalText(String text) {
    final lines = text.split('\n');
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.map((line) {
            if (line.trim().isEmpty) return SizedBox(height: 10);
            if (line.trim().toUpperCase() == line.trim() && line.length < 60) {
              // Section header
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 6),
                child: Text(line, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.teal.shade900)),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: TextStyle(fontSize: 15, color: Colors.teal.shade900, height: 1.5)),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Placeholders for legal text (replace with your full content)
  final String _privacyPolicy = '''
PRIVACY STATEMENT

SECTION 1 - WHAT DO WE DO WITH YOUR INFORMATION?

When you purchase something/service from our App, as part of the buying and selling process, we collect the personal information you give us such as your name, address and email address.

When you browse our App, we also automatically receive your computer’s internet protocol (IP) address in order to provide us with information that helps us learn about your browser and operating system, if Necessary.

Email marketing (if applicable): With your permission, we may send you emails about our App/store, new products, Services and other updates.

SECTION 2 - CONSENT

How do you get my consent?
When you provide us with personal information to complete a transaction, verify your credit card, place an order or arrange for a delivery or return a purchase or use our service, we imply that you consent to our collecting it and using it for that specific reason only.
If we ask for your personal information for a secondary reason, like marketing, we will either ask you directly for your expressed consent, or provide you with an opportunity to say no.

How do I withdraw my consent?
If after you opt-in, you change your mind, you may withdraw your consent for us to contact you, for the continued collection, use or disclosure of your information, at anytime, by contacting/mailing us at btbowners@gmail.com for turf owners and btbcustomers@gmail.com for customers.

SECTION 3 - DISCLOSURE
We may disclose your personal information if we are required by law to do so or if you violate our Terms of Service.

SECTION 4 - PAYMENT
We use Razorpay for processing payments. We/Razorpay do not store your card data on their servers. The data is encrypted through the Payment Card Industry Data Security Standard (PCI-DSS) when processing payment. Your purchase transaction data is only used as long as is necessary to complete your purchase transaction. After that is complete, your purchase transaction information is not saved.
Our payment gateway adheres to the standards set by PCI-DSS as managed by the PCI Security Standards Council, which is a joint effort of brands like Visa, MasterCard, American Express and Discover.
PCI-DSS requirements help ensure the secure handling of credit card information by our store and its service providers.
For more insight, you may also want to read terms and conditions of razorpay on https://razorpay.com

SECTION 5 - THIRD-PARTY SERVICES
In general, the third-party providers used by us will only collect, use and disclose your information to the extent necessary to allow them to perform the services they provide to us.
However, certain third-party service providers, such as payment gateways and other payment transaction processors, have their own privacy policies in respect to the information we are required to provide to them for your purchase-related transactions.
For these providers, we recommend that you read their privacy policies so you can understand the manner in which your personal information will be handled by these providers.
In particular, remember that certain providers may be located in or have facilities that are located in a different jurisdiction than either you or us. So if you elect to proceed with a transaction that involves the services of a third-party service provider, then your information may become subject to the laws of the jurisdiction(s) in which that service provider or its facilities are located.
Once you leave our App/site or are redirected to a third-party website or application, you are no longer governed by this Privacy Policy or our website’s Terms of Service.
Links
When you click on links on our App/site, they may direct you away from our site. We are not responsible for the privacy practices of other sites and encourage you to read their privacy statements.

SECTION 6 - SECURITY
To protect your personal information, we take reasonable precautions and follow industry best practices to make sure it is not inappropriately lost, misused, accessed, disclosed, altered or destroyed.

SECTION 7 - COOKIES
We use cookies to maintain the session of your user. It is not used to personally identify you on other websites.

SECTION 8 - AGE OF CONSENT
By using this site, you represent that you are at least the age of majority in your state or province of residence, or that you are the age of majority in your state or province of residence and you have given us your consent to allow any of your minor dependents to use this App/site.

SECTION 9 - CHANGES TO THIS PRIVACY POLICY
We reserve the right to modify this privacy policy at any time, so please review it frequently. Changes and clarifications will take effect immediately upon their posting on the App/website. If we make material changes to this policy, we will notify you here that it has been updated, so that you are aware of what information we collect, how we use it, and under what circumstances, if any, we use and/or disclose it.
If our Company/App/Services is acquired or merged with another company, your information may be transferred to the new owners so that we may continue to sell products to you.

QUESTIONS AND CONTACT INFORMATION
If you would like to: access, correct, amend or delete any personal information we have about you, register a complaint, or simply want more information, kindly contact/mail us at btbowners@gmail.com for turf owners and btbcustomers@gmail.com for customers.
''';

  final String _generalTerms = '''
TERMS OF SERVICE

Effective Date: 01/04/2025
Last Updated: 01/04/2025
-----

OVERVIEW
This website is operated by PunchBiz. Throughout the site, the terms “we”, “us” and “our” refer to PunchBiz. PunchBiz offers this website, including all information, tools and services available from this site to you, the user, conditioned upon your acceptance of all terms, conditions, policies and notices stated here.

By visiting our site/App and/or purchasing something from us, you engage in our “Service” and agree to be bound by the following terms and conditions (“Terms of Service”, “Terms”), including those additional terms and conditions and policies referenced herein and/or available by hyperlink. These Terms of Service apply to all users of the site, including without limitation users who are browsers, vendors, customers, merchants, and/or contributors of content.

Please read these Terms of Service carefully before accessing or using our website. By accessing or using any part of the site, you agree to be bound by these Terms of Service. If you do not agree to all the terms and conditions of this agreement, then you may not access the website or use any services. If these Terms of Service are considered an offer, acceptance is expressly limited to these Terms of Service.

Any new features or tools which are added to the current store shall also be subject to the Terms of Service. You can review the most current version of the Terms of Service at any time on this page. We reserve the right to update, change or replace any part of these Terms of Service by posting updates and/or changes to our website/App. It is your responsibility to check this page periodically for changes. Your continued use of or access to the website/App following the posting of any changes constitutes acceptance of those changes.

SECTION 1 - ONLINE STORE TERMS
By agreeing to these Terms of Service, you represent that you are at least the age of majority in your state or province of residence, or that you are the age of majority in your state or province of residence and you have given us your consent to allow any of your minor dependents to use this site.
You may not use our products for any illegal or unauthorized purpose nor may you, in the use of the Service, violate any laws in your jurisdiction (including but not limited to copyright laws).
You must not transmit any worms or viruses or any code of a destructive nature.
A breach or violation of any of the Terms will result in an immediate termination of your Services.

SECTION 2 - GENERAL CONDITIONS
We reserve the right to refuse service to anyone for any reason at any time.
You understand that your content (not including credit card information), may be transferred unencrypted and involve (a) transmissions over various networks; and (b) changes to conform and adapt to technical requirements of connecting networks or devices. Credit card information is always encrypted during transfer over networks.
You agree not to reproduce, duplicate, copy, sell, resell or exploit any portion of the Service, use of the Service, or access to the Service or any contact on the website/App through which the service is provided, without express written permission by us.
The headings used in this agreement are included for convenience only and will not limit or otherwise affect these Terms.

SECTION 3 - ACCURACY, COMPLETENESS AND TIMELINESS OF INFORMATION
We are not responsible if information made available on this site is not accurate, complete or current. The material on this site is provided for general information only and should not be relied upon or used as the sole basis for making decisions without consulting primary, more accurate, more complete or more timely sources of information. Any reliance on the material on this site/App is at your own risk.
This site/App may contain certain historical information. Historical information, necessarily, is not current and is provided for your reference only. We reserve the right to modify the contents of this site/App at any time, but we have no obligation to update any information on our site/App. You agree that it is your responsibility to monitor changes to our site/App.

SECTION 4 - MODIFICATIONS TO THE SERVICE AND PRICES
Prices for our products are subject to change without notice.
We reserve the right at any time to modify or discontinue the Service (or any part or content thereof) without notice at any time.
We shall not be liable to you or to any third-party for any modification, price change, suspension or discontinuance of the Service.

SECTION 5 - PRODUCTS OR SERVICES
Certain products or services may be available exclusively online through the website/App. These products or services may have limited quantities and are subject to return or exchange only according to our Return Policy.
We have made every effort to display as accurately as possible the colors and images of our products that appear at the store. We cannot guarantee that your computer monitor's display of any color will be accurate.
We reserve the right, but are not obligated, to limit the sales of our products or Services to any person, geographic region or jurisdiction. We may exercise this right on a case-by-case basis. We reserve the right to limit the quantities of any products or services that we offer. All descriptions of products or product pricing are subject to change at any time without notice, at the sole discretion of us. We reserve the right to discontinue any product at any time. Any offer for any product or service made on this site is void where prohibited.
We do not warrant that the quality of any products, services, information, or other material purchased or obtained by you will meet your expectations, or that any errors in the Service will be corrected.

SECTION 6 - ACCURACY OF BILLING AND ACCOUNT INFORMATION
We reserve the right to refuse any order or service you place with us. We may, in our sole discretion, limit or cancel quantities purchased per person, per household or per order. These restrictions may include orders or services placed by or under the same customer account, the same credit card, and/or orders that use the same billing and/or shipping address. In the event that we make a change to or cancel an order, we may attempt to notify you by contacting the e-mail and/or billing address/phone number provided at the time the order was made. We reserve the right to limit or prohibit orders that, in our sole judgment, appear to be placed by dealers, resellers or distributors.
You agree to provide current, complete and accurate purchase and account information for all purchases made at our store. You agree to promptly update your account and other information, including your email address and credit card numbers and expiration dates, so that we can complete your transactions and contact you as needed.
For more detail, please review our Returns Policy on particular pages in the site/App.

SECTION 7 - OPTIONAL TOOLS
We may provide you with access to third-party tools over which we neither monitor nor have any control nor input.
You acknowledge and agree that we provide access to such tools ”as is” and “as available” without any warranties, representations or conditions of any kind and without any endorsement. We shall have no liability whatsoever arising from or relating to your use of optional third-party tools.
Any use by you of optional tools offered through the site/App is entirely at your own risk and discretion and you should ensure that you are familiar with and approve of the terms on which tools are provided by the relevant third-party provider(s).
We may also, in the future, offer new services and/or features through the website/App (including, the release of new tools and resources). Such new features and/or services shall also be subject to these Terms of Service.

SECTION 8 - THIRD-PARTY LINKS
Certain content, products and services available via our Service may include materials from third-parties.
Third-party links on this site may direct you to third-party websites/Apps that are not affiliated with us. We are not responsible for examining or evaluating the content or accuracy and we do not warrant and will not have any liability or responsibility for any third-party materials or websites/Apps, or for any other materials, products, or services of third-parties.
We are not liable for any harm or damages related to the purchase or use of goods, services, resources, content, or any other transactions made in connection with any third-party websites/Apps. Please review carefully the third-party's policies and practices and make sure you understand them before you engage in any transaction. Complaints, claims, concerns, or questions regarding third-party products should be directed to the third-party.

SECTION 9 - USER COMMENTS, FEEDBACK AND OTHER SUBMISSIONS
If, at our request, you send certain specific submissions (for example contest entries) or without a request from us you send creative ideas, suggestions, proposals, plans, or other materials, whether online, by email, by postal mail, or otherwise (collectively, 'comments'), you agree that we may, at any time, without restriction, edit, copy, publish, distribute, translate and otherwise use in any medium any comments that you forward to us. We are and shall be under no obligation (1) to maintain any comments in confidence; (2) to pay compensation for any comments; or (3) to respond to any comments.
We may, but have no obligation to, monitor, edit or remove content that we determine in our sole discretion are unlawful, offensive, threatening, libelous, defamatory, pornographic, obscene or otherwise objectionable or violates any party’s intellectual property or these Terms of Service.
You agree that your comments will not violate any right of any third-party, including copyright, trademark, privacy, personality or other personal or proprietary right. You further agree that your comments will not contain libelous or otherwise unlawful, abusive or obscene material, or contain any computer virus or other malware that could in any way affect the operation of the Service or any related website/App. You may not use a false e-mail address, pretend to be someone other than yourself, or otherwise mislead us or third-parties as to the origin of any comments. You are solely responsible for any comments you make and their accuracy. We take no responsibility and assume no liability for any comments posted by you or any third-party.

SECTION 10 - PERSONAL INFORMATION
Your submission of personal information through the store is governed by our Privacy Policy.

SECTION 11 - ERRORS, INACCURACIES AND OMISSIONS
Occasionally there may be information on our site or in the Service that contains typographical errors, inaccuracies or omissions that may relate to product descriptions, pricing, promotions, offers, product shipping charges, transit times and availability. We reserve the right to correct any errors, inaccuracies or omissions, and to change or update information or cancel orders if any information in the Service or on any related website/App is inaccurate at any time without prior notice (including after you have submitted your order).
We undertake no obligation to update, amend or clarify information in the Service or on any related website/App, including without limitation, pricing information, except as required by law. No specified update or refresh date applied in the Service or on any related website/App, should be taken to indicate that all information in the Service or on any related website/App has been modified or updated.

SECTION 12 - PROHIBITED USES
In addition to other prohibitions as set forth in the Terms of Service, you are prohibited from using the site/App or its content: (a) for any unlawful purpose; (b) to solicit others to perform or participate in any unlawful acts; (c) to violate any international, federal, provincial or state regulations, rules, laws, or local ordinances; (d) to infringe upon or violate our intellectual property rights or the intellectual property rights of others; (e) to harass, abuse, insult, harm, defame, slander, disparage, intimidate, or discriminate based on gender, sexual orientation, religion, ethnicity, race, age, national origin, or disability; (f) to submit false or misleading information; (g) to upload or transmit viruses or any other type of malicious code that will or may be used in any way that will affect the functionality or operation of the Service or of any related website, other websites, or the Internet; (h) to collect or track the personal information of others; (i) to spam, phish, pharm, pretext, spider, crawl, or scrape; (j) for any obscene or immoral purpose; or (k) to interfere with or circumvent the security features of the Service or any related website, other websites, or the Internet. We reserve the right to terminate your use of the Service or any related website for violating any of the prohibited uses.

SECTION 13 - DISCLAIMER OF WARRANTIES; LIMITATION OF LIABILITY
We do not guarantee, represent or warrant that your use of our service will be uninterrupted, timely, secure or error-free.
We do not warrant that the results that may be obtained from the use of the service will be accurate or reliable.
You agree that from time to time we may remove the service for indefinite periods of time or cancel the service at any time, without notice to you.
You expressly agree that your use of, or inability to use, the service is at your sole risk. The service and all products and services delivered to you through the service are (except as expressly stated by us) provided 'as is' and 'as available' for your use, without any representation, warranties or conditions of any kind, either express or implied, including all implied warranties or conditions of merchantability, merchantable quality, fitness for a particular purpose, durability, title, and non-infringement.
In no case shall PunchBiz, our directors, officers, employees, affiliates, agents, contractors, interns, suppliers, service providers or licensors be liable for any injury, loss, claim, or any direct, indirect, incidental, punitive, special, or consequential damages of any kind, including, without limitation lost profits, lost revenue, lost savings, loss of data, replacement costs, or any similar damages, whether based in contract, tort (including negligence), strict liability or otherwise, arising from your use of any of the service or any products procured using the service, or for any other claim related in any way to your use of the service or any product, including, but not limited to, any errors or omissions in any content, or any loss or damage of any kind incurred as a result of the use of the service or any content (or product) posted, transmitted, or otherwise made available via the service, even if advised of their possibility. Because some states or jurisdictions do not allow the exclusion or the limitation of liability for consequential or incidental damages, in such states or jurisdictions, our liability shall be limited to the maximum extent permitted by law.

SECTION 14 - INDEMNIFICATION
You agree to indemnify, defend and hold harmless PunchBiz and our parent, subsidiaries, affiliates, partners, officers, directors, agents, contractors, licensors, service providers, subcontractors, suppliers, interns and employees, harmless from any claim or demand, including reasonable attorneys’ fees, made by any third-party due to or arising out of your breach of these Terms of Service or the documents they incorporate by reference, or your violation of any law or the rights of a third-party.

SECTION 15 - SEVERABILITY
In the event that any provision of these Terms of Service is determined to be unlawful, void or unenforceable, such provision shall nonetheless be enforceable to the fullest extent permitted by applicable law, and the unenforceable portion shall be deemed to be severed from these Terms of Service, such determination shall not affect the validity and enforceability of any other remaining provisions.

SECTION 16 - TERMINATION
The obligations and liabilities of the parties incurred prior to the termination date shall survive the termination of this agreement for all purposes.
These Terms of Service are effective unless and until terminated by either you or us. You may terminate these Terms of Service at any time by notifying us that you no longer wish to use our Services, or when you cease using our site/App.
If in our sole judgment you fail, or we suspect that you have failed, to comply with any term or provision of these Terms of Service, we also may terminate this agreement at any time without notice and you will remain liable for all amounts due up to and including the date of termination; and/or accordingly may deny you access to our Services (or any part thereof).

SECTION 17 - ENTIRE AGREEMENT
The failure of us to exercise or enforce any right or provision of these Terms of Service shall not constitute a waiver of such right or provision.
These Terms of Service and any policies or operating rules posted by us on this site/App or in respect to The Service constitutes the entire agreement and understanding between you and us and govern your use of the Service, superseding any prior or contemporaneous agreements, communications and proposals, whether oral or written, between you and us (including, but not limited to, any prior versions of the Terms of Service).
Any ambiguities in the interpretation of these Terms of Service shall not be construed against the drafting party.

SECTION 18 - GOVERNING LAW
These Terms of Service and any separate agreements whereby we provide you Services shall be governed by and construed in accordance with the laws of India and jurisdiction of Salem, Tamil Nadu

SECTION 19 - CHANGES TO TERMS OF SERVICE
You can review the most current version of the Terms of Service at any time at this page.
We reserve the right, at our sole discretion, to update, change or replace any part of these Terms of Service by posting updates and changes to our website. It is your responsibility to check our website/App periodically for changes. Your continued use of or access to our website/App or the Service following the posting of any changes to these Terms of Service constitutes acceptance of those changes.

SECTION 20 - CONTACT INFORMATION
Questions about the Terms of Service should be sent to us at thepunchbiz@gmail.com.

-------------------------------------
''';

  final String _ownerTerms = '''
TERMS AND CONDITIONS FOR TURF OWNERS – BOOKTHEBIZ (INDIA)
Effective Date: 01/04/2025
Last Updated: 01/04/2025

1. ELIGIBILITY
To list your turf on BooktheBiz, you must:
Be at least 18 years of age.
Be the lawful owner of the property or have legal authority to manage and lease the turf.
Provide accurate identity proof and property documentation when requested.

2. TURF LISTING AND RESPONSIBILITIES
By listing your turf, you agree to:
Provide complete, accurate, and up-to-date information including:
Turf name and location
Pricing, availability, photos
Features (lighting, seating, washrooms, etc.)
Ensure the turf is clean, well-maintained, and safe for use.
Keep your listing updated with accurate availability and pricing.
Comply with all applicable local and state laws, including zoning, fire safety, noise restrictions, and municipal approvals.

3. BOOKING PROCESS AND CANCELLATIONS
All bookings must be processed exclusively through the BooktheBiz platform.
You may choose between auto-approval or manual approval of bookings.
You must honour all confirmed bookings unless cancelled under genuine circumstances (e.g., weather, maintenance, natural disaster and so on).
Cancellations by turf owners must be made promptly and full refunds should be initiated immediately. Frequent cancellations may result in penalties or listing suspension.

4. PRICING, PAYMENTS & TAXES
You are free to set your own hourly or slot-based pricing.
BooktheBiz will deduct a platform service fee (percentage to be communicated separately) from every successful booking.
Payouts will be made via UPI, bank transfer, or other supported methods within 3–7 business days after the booking is completed.
You are solely responsible for declaring and paying any applicable GST, income tax, or other government levies related to your earnings.

5. CUSTOMER EXPERIENCE AND CONDUCT
You agree to:
Provide a professional, respectful experience to all users.
Avoid discriminatory or inappropriate behavior.
Provide access to the turf as per the booked schedule and ensure that amenities listed are functional.

6. LIABILITY AND INSURANCE
You are responsible for the safety, maintenance, and management of your premises.
BooktheBiz is not liable for any damage, injury, loss, theft, or third-party claims arising from incidents on your property.
It is advised to carry appropriate property and liability insurance to cover unforeseen events.

7. REVIEWS AND FEEDBACK
Customers may leave reviews after their booking. Turf owners cannot alter or remove reviews.
Repeated negative reviews may result in account review or listing deactivation after internal verification.

8. TERMINATION AND ACCOUNT SUSPENSION
Your account or listing may be suspended or terminated under the following circumstances:
Misrepresentation or fraudulent listings
Multiple user complaints
Non-compliance with Indian laws or platform policies
Safety or hygiene violations
Repeated booking failures or misuse of the platform

9. INTELLECTUAL PROPERTY AND MARKETING USE
By listing your turf, you allow BooktheBiz to use your turf’s name, images, and description for platform promotion, advertisements, and social media marketing.
You retain ownership of your content but grant us a non-exclusive license to use it for the duration of your listing.

10. DISPUTE RESOLUTION
In case of disputes between turf owners and users, BooktheBiz will mediate to the best of its ability.
Any legal disputes shall be subject to the jurisdiction of the courts of Salem, Tamil Nadu, India.

11. CHANGES TO TERMS
BooktheBiz reserves the right to update or modify these Terms at any time. You will be notified through the app or email. Continued use of the platform constitutes acceptance of the revised Terms.

12. CONTACT INFORMATION
For queries, assistance, or complaints, please contact us at:
Email: btbowners@gmail.com
Phone: +91-8248708300 (Mon-Fri 10.00 A.M - 6.00 P.M)
''';

  final String _userTerms = '''
Terms and Conditions for Customers – BooktheBiz (India)
Effective Date: 01/04/2025
Last Updated: 01/04/2025
These Terms and Conditions ("Terms") govern the use of the BooktheBiz platform ("we", "us", "our") by customers ("you", "your", "user") who wish to book sports turfs and recreational spaces listed by turf owners. By using the BooktheBiz app or website, you agree to comply with these Terms.

1. ACCOUNT REGISTRATION
To book a turf on BooktheBiz, you must:
Be at least 16 years of age. (Minors may participate under adult supervision.)
Provide accurate personal details (name, contact info, payment method).
Maintain the security of your account and not share your login credentials.

2. BOOKING TERMS
All bookings must be made through the BooktheBiz platform.
You are responsible for reviewing turf details, availability, and pricing before confirming a booking.
Upon booking, you will receive a confirmation message via SMS, email, or in-app notification.
Some turfs may require prepayment or partial payment to confirm your slot.

3. PAYMENT POLICY
Prices are displayed per hour or per slot as set by the turf owner.
Payments can be made via UPI, debit/credit card, wallet, or net banking.
A service fee may be added at the time of booking.
All payments are processed securely through our payment partners.

4. CANCELLATION AND REFUND POLICY
Cancellations must be made within the cancellation window defined on the turf listing.
Refund eligibility depends on the turf owner’s policy (e.g., full refund if cancelled 8 hours in advance).
No-shows or late arrivals are not eligible for refunds.
Refunds, if applicable, will be processed within 5–7 business days.

5. USAGE CONDUCT
By using a turf through BooktheBiz, you agree to:
Arrive on time and vacate the turf at the end of your booking.
Follow all on-site rules and regulations as set by the turf owner or staff.
Maintain cleanliness and avoid damaging property or equipment.
Respect others’ bookings and not engage in disruptive behavior.
Avoid illegal, hazardous, or inappropriate activities on the premises.

6. LIABILITY
BooktheBiz is a booking platform and does not manage or operate the turfs.
Turf owners are solely responsible for the safety and maintenance of their facilities.
You acknowledge that any injuries, accidents, or losses incurred on-site are not the liability of BooktheBiz.
You participate at your own risk and are encouraged to wear proper sports gear.

7. REVIEWS AND RATINGS
You may leave honest feedback about your turf experience.
Reviews should be respectful and fact-based.
BooktheBiz may remove reviews that contain offensive, defamatory, or misleading content.

8. TERMINATION OF ACCOUNT
Your account may be suspended or terminated for:
Repeated no-shows or cancellations
Misuse of turfs or abusive behavior
Attempting to bypass the platform to book directly
Providing false information or fraudulent activity

9. PLATFORM USAGE
You agree not to misuse the BooktheBiz app or website (e.g., hacking, scraping, spamming).
All app content, listings, logos, and systems are protected intellectual property of BooktheBiz.

10. CHANGES TO TERMS
BooktheBiz reserves the right to update these Terms at any time. Updated versions will be made available on the platform, and continued use constitutes your acceptance of the changes.

11. GOVERNING LAW
These Terms are governed by the laws of India. Any disputes shall be subject to the jurisdiction of the courts of Salem, Tamil Nadu, India.

12. CONTACT US
For support or complaints, reach out to:
Email: btbcustomers@gmail.com
Phone: +918248708300 (Mon-Fri 10.00 A.M - 6.00 P.M)
''';

  @override
  Widget build(BuildContext context) {
    final user = widget.user ?? FirebaseAuth.instance.currentUser;
    final extraTopPadding =
        MediaQuery.of(context).padding.top + kToolbarHeight + 15;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'MY PROFILE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          Tooltip(
            message: _isEditing ? 'Cancel Edit' : 'Edit Profile',
            child: IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                });
              },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomPaint(
        painter: DottedBackgroundPainter(),
            child: Container(),
          ),
          SafeArea(
          child: SingleChildScrollView(
            child: Padding(
                padding: EdgeInsets.only(top: extraTopPadding, bottom: 90),
              child: Column(
                children: [
                    // Top section with profile info
                  Container(
                    width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : (_userData?['imageUrl'] != null && _userData!['imageUrl'] != ""
                                      ? NetworkImage(_userData!['imageUrl'])
                                        : const AssetImage('lib/assets/profile.png') as ImageProvider),
                            ),
                            if (_isEditing)
                                Positioned(
                                  bottom: 0,
                                  right: 4,
                                  child: GestureDetector(
                                onTap: _pickImage,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.black54,
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 18,
                                      ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _isEditing
                            ? Container(
                                width: double.infinity,
                                alignment: Alignment.center,
                                child: TextField(
                                  controller: _nameController,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Username',
                                    hintStyle: TextStyle(color: Colors.white),
                                    border: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.white),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.white),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.white),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              )
                            : Text(
                                _userData?['name'] ?? 'Username',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                  // Card-like section for Personal Information
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Full Name
                        const Text(
                          'FULL NAME',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _isEditing
                            ? TextField(
                                controller: _nameController,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                                decoration: const InputDecoration(
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.teal),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.teal),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.teal),
                                  ),
                                ),
                              )
                            : Text(
                                _userData?['name'] ?? 'Username',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                        const SizedBox(height: 16),
                        // Email Address
                        const Text(
                          'EMAIL ADDRESS',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _showEditRestrictionDialog,
                          child: AbsorbPointer(
                            child: TextField(
                              controller: TextEditingController(text: user?.email ?? 'email@example.com'),
                              readOnly: true,
                              style: const TextStyle(color: Colors.black, fontSize: 16),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Phone Number
                        const Text(
                          'PHONE NUMBER',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _showEditRestrictionDialog,
                          child: AbsorbPointer(
                            child: TextField(
                              controller: TextEditingController(text: _userData?['mobile'] ?? 'Mobile number not available'),
                              readOnly: true,
                              style: const TextStyle(color: Colors.black, fontSize: 16),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // "SAVE CHANGES" button
                        _isEditing
                            ? SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _saveChanges,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0C6157),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: _isSaving
                                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text(
                                    'SAVE CHANGES',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            : Container(),
                      ],
                    ),
                  ),
                    const SizedBox(height: 24),
                    // Support Section (hide when editing)
                    if (!_isEditing)
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.verified_user, color: Colors.white),
                                    label: Text('Legal & Policies', style: TextStyle(fontSize: 16, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade600,
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: _showLegalPoliciesModal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ExpansionTile(
                                initiallyExpanded: _showSupport,
                                onExpansionChanged: (expanded) => setState(() => _showSupport = expanded),
                                leading: Icon(Icons.support_agent, color: Colors.teal[700]),
                                title: Text('Support', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[800])),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Form(
                                      key: _supportFormKey,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          TextFormField(
                                            controller: _supportSubjectController,
                                            decoration: InputDecoration(
                                              labelText: 'Subject',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                              prefixIcon: Icon(Icons.subject),
                                              filled: true,
                                              fillColor: Colors.grey[100],
                                            ),
                                            validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a subject' : null,
                                          ),
                                          const SizedBox(height: 16),
                                          TextFormField(
                                            controller: _supportMessageController,
                                            decoration: InputDecoration(
                                              labelText: 'Message',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                              prefixIcon: Icon(Icons.message),
                                              filled: true,
                                              fillColor: Colors.grey[100],
                                            ),
                                            minLines: 4,
                                            maxLines: 8,
                                            validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your message' : null,
                                          ),
                                          const SizedBox(height: 20),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              icon: _isSubmittingSupport
                                                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                  : Icon(Icons.send),
                                              label: Text(_isSubmittingSupport ? 'Submitting...' : 'Submit Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.teal,
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(vertical: 16),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              onPressed: _isSubmittingSupport ? null : _submitSupportTicket,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Previous Tickets Section
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Divider(),
                                        Text('Previous Tickets', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[800], fontSize: 16)),
                                        const SizedBox(height: 8),
                                        StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('support_tickets')
                                              .where('userId', isEqualTo: user?.uid ?? '')
                                              .orderBy('createdAt', descending: true)
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData) {
                                              return Center(child: Padding(
                                                padding: EdgeInsets.all(8),
                                                child: CircularProgressIndicator(),
                                              ));
                                            }
                                            final tickets = snapshot.data!.docs;
                                            if (tickets.isEmpty) {
                                              return Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text("No previous tickets found."),
                                              );
                                            }
                                            return ListView.builder(
                                              shrinkWrap: true,
                                              physics: NeverScrollableScrollPhysics(),
                                              itemCount: tickets.length,
                                              itemBuilder: (context, index) {
                                                final ticket = tickets[index];
                                                final createdAt = ticket['createdAt'] != null && ticket['createdAt'] is Timestamp
                                                    ? (ticket['createdAt'] as Timestamp).toDate()
                                                    : null;
                                                return Card(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  margin: EdgeInsets.only(bottom: 12),
                                                  child: ListTile(
                                                    leading: Icon(Icons.support_agent, color: Colors.teal),
                                                    title: Text(ticket['subject'] ?? 'No Subject'),
                                                    subtitle: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        SizedBox(height: 4),
                                                        Text(ticket['message'] ?? ''),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          "Status: "+(ticket['status'] ?? 'open'),
                                                          style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                                        ),
                                                        if (createdAt != null)
                                                          Text(
                                                            "Created: "+createdAt.toString(),
                                                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Sign Out Button at Bottom
          Positioned(
  left: 0,
  right: 0,
  bottom: 0,
  child: Builder(
    builder: (context) {
      final mediaQuery = MediaQuery.of(context);
      final viewInsets = mediaQuery.viewInsets.bottom; // Keyboard height
      final bottomPadding = mediaQuery.padding.bottom;

      // Detect gesture navigation
      final isGestureNav = bottomPadding > 20;

      // Decide bottom margin
      final bottomMargin = viewInsets > 0
          ? viewInsets // Keyboard open → match keyboard height
          : isGestureNav
              ? bottomPadding // Gesture nav → use safe area
              : 10.0; // Traditional nav → small fixed margin

      return Padding(
        padding: EdgeInsets.only(bottom: bottomMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                      ),
                      onPressed: _showLogoutDialog,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  ),
),
        ],
      ),
    );
  }
}
