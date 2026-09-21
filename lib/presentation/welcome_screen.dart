import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_dashboard.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Elegant ivory cream background matching reference design
    const backgroundColor = Color(0xFFF6F3EC);
    const darkGreenColor = Color(0xFF2D5A46);
    const mutedTextColor = Color(0xFF7D8B83);
    const lineAccentColor = Color(0xFFC5BCAE);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle geometric watermark pattern overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.035,
                child: CustomPaint(
                  painter: _GeometricPatternPainter(),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // Title: "طيبة"
                  Text(
                    'طيبة',
                    style: GoogleFonts.cairo(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B2A22),
                      height: 1.1,
                      letterSpacing: -1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Divider line below "طيبة"
                  Container(
                    width: 76,
                    height: 1.5,
                    color: lineAccentColor,
                  ),

                  const SizedBox(height: 36),

                  // Subtitle: "حياكم الله"
                  Text(
                    'حياكم الله',
                    style: GoogleFonts.cairo(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: darkGreenColor,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  // Tagline: "طيبة لمن طاب قلبه بذكر الله"
                  Text(
                    'طيبة لمن طاب قلبه بذكر الله',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: mutedTextColor,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 4),

                  // Action Button: "الدخول إلى طيبة"
                  Center(
                    child: SizedBox(
                      width: 250,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TaybahDashboard(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkGreenColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Text(
                          'الدخول إلى طيبة',
                          style: GoogleFonts.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for subtle background geometric pattern
class _GeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const step = 60.0;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        canvas.drawRect(Rect.fromLTWH(x, y, step, step), paint);
        canvas.drawCircle(Offset(x + step / 2, y + step / 2), step / 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
