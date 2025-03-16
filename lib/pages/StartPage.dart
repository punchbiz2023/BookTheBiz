import 'package:flutter/material.dart';
import 'package:odp/pages/login.dart';
import 'package:odp/pages/sign_up_page.dart';

class StartPage extends StatelessWidget {
  const StartPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1) White background
          Container(color: Colors.white),

          // 2) Teal swirl behind the player image
          CustomPaint(
            painter: TealSwirlPainter(),
            // Fill the entire screen to paint the swirl
            child: Container(
              height: size.height,
              width: size.width,
            ),
          ),

          // 3) Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Optional: App brand/name at top-left (like “TURFY”)
                  // You can remove this if not needed
                  Text(
                    'BOOKTHEBIZ',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),

                  // Spacing from top
                  SizedBox(height: 30),

                  // Player image in the center
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        'lib/assets/profile.png',
                        height: 280,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Main heading
                  Text(
                    'CLAIM YOUR TURF TODAY',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: 12),

                  // Subtext
                  Text(
                    'Book your turf, schedule your game, and play your way—all from your smartphone',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),

                  // Push buttons to the bottom
                  Spacer(),

                  // Row with Login & Register buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LoginApp()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.teal.shade900,
                            backgroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.teal.shade900, width: 2),
                          ),
                          child: Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SignupPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.teal.shade900,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A CustomPainter that draws a teal swirl/star shape in the background.
/// Adjust the path below to fine-tune the shape to your liking.
class TealSwirlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Paint settings
    final paint = Paint()..color = Colors.teal.shade100;

    // Start a path that simulates a “swirl/star” behind the image
    final path = Path();

    // Example shape: a star-like swirl from top-right to bottom-left
    path.moveTo(size.width * 0.75, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.3);
    path.lineTo(size.width * 0.5, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, size.height * 0.7);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
