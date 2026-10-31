import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// خلفية التطبيق في الوضع الليلي: صورة المسجد النبوي بشفافية خفيفة جداً،
/// تحت طبقة ليلية داكنة، وتطفو فوقها البطاقات شبه الشفافة.
///
/// الصورة: Muhammad Mahdi Karim / www.micro2macro.net — رخصة الفن الحر (Free Art License).
class TaybahBackdrop extends StatelessWidget {
  final bool dark;
  final Widget child;

  const TaybahBackdrop({super.key, required this.dark, required this.child});

  static const String imageAsset = 'assets/images/nabawi_bg.jpg';

  @override
  Widget build(BuildContext context) {
    if (!dark) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: TaybahColors.darkBg),
        // الصورة بألوان هادئة وشفافية ضعيفة جداً
        Opacity(
          opacity: 0.24,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              // تقليل التشبع قليلاً مع ميل خفيف للأخضر
              0.55, 0.30, 0.10, 0, 0,
              0.20, 0.65, 0.15, 0, 0,
              0.15, 0.30, 0.45, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: Image.asset(
              imageAsset,
              fit: BoxFit.cover,
              alignment: const Alignment(0.2, 0.3),
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        // تدرج ليلي من الأعلى والأسفل حتى تبقى النصوص واضحة
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCC07110C),
                Color(0x6607110C),
                Color(0x8007110C),
                Color(0xF207110C),
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
