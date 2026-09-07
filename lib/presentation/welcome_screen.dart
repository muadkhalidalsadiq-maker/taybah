import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import 'home_dashboard.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  String _getGregorianDate() {
    final now = DateTime.now();
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}م';
  }

  String _getHijriDateApprox() {
    final now = DateTime.now();
    final gregorianDays = now.difference(DateTime(622, 7, 16)).inDays;
    final hijriYear = (gregorianDays / 354.36667).floor();
    final daysInYear = (gregorianDays % 354.36667).floor();
    final hijriMonth = (daysInYear / 29.53).floor() + 1;
    final hijriDay = (daysInYear % 29.53).floor() + 1;
    const hijriMonths = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الثاني',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة'
    ];
    final monthName = hijriMonths[(hijriMonth - 1).clamp(0, 11)];
    return '$hijriDay $monthName $hijriYearهـ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaybahColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Official Logo with glowing backdrop
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: TaybahColors.primary.withAlpha(35),
                        blurRadius: 36,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: TaybahColors.gold.withAlpha(20),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Bismillah
              Text(
                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                style: GoogleFonts.amiri(
                  fontSize: 24,
                  color: TaybahColors.gold,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'تطبيق طيبة الإسلامي الشامل',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: TaybahColors.primaryDark,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              Text(
                'القرآن الكريم برواية قالون • مواقيت الصلاة (الأوائل) • أذكار وأدعية',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: TaybahColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              // Date card (Clean Pearl Card)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: TaybahColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          'التاريخ الهجري',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: TaybahColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getHijriDateApprox(),
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: TaybahColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 32,
                      width: 1,
                      color: TaybahColors.border,
                    ),
                    Column(
                      children: [
                        Text(
                          'التاريخ الميلادي',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: TaybahColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getGregorianDate(),
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: TaybahColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Primary Action Button
              SizedBox(
                height: 56,
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
                    backgroundColor: TaybahColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 4,
                    shadowColor: TaybahColors.primary.withAlpha(80),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ادخل واذكر الله',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_back_rounded, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
