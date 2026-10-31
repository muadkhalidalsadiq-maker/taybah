import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// خلفية التطبيق: صورة المسجد النبوي بشفافية خفيفة جداً تحت طبقة لونية،
/// وفوقها تطفو البطاقات الزجاجية (Liquid Glass). في النهاري الصورة أخف بكثير،
/// فقط ليعطي الزجاج لوناً ينكسر عليه.
///
/// الصورة: Muhammad Mahdi Karim / www.micro2macro.net — رخصة الفن الحر (Free Art License).
class TaybahBackdrop extends StatelessWidget {
  final bool dark;
  final Widget child;

  const TaybahBackdrop({super.key, required this.dark, required this.child});

  static const String imageAsset = 'assets/images/nabawi_bg.jpg';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
            color: dark ? TaybahColors.darkBg : const Color(0xFFF4F7F2)),
        Opacity(
          opacity: dark ? 0.26 : 0.30,
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(dark
                ? const <double>[
                    0.55, 0.30, 0.10, 0, 0,
                    0.20, 0.65, 0.15, 0, 0,
                    0.15, 0.30, 0.45, 0, 0,
                    0, 0, 0, 1, 0,
                  ]
                : const <double>[
                    0.80, 0.15, 0.05, 0, 0,
                    0.10, 0.85, 0.05, 0, 0,
                    0.10, 0.15, 0.75, 0, 0,
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
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [
                      Color(0xCC07110C),
                      Color(0x6607110C),
                      Color(0x8007110C),
                      Color(0xF207110C),
                    ]
                  : const [
                      Color(0xE6F4F7F2),
                      Color(0x99F4F7F2),
                      Color(0x80F4F7F2),
                      Color(0xD9F4F7F2),
                    ],
              stops: const [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
        // كل البطاقات الزجاجية تشترك في قراءة واحدة للخلفية (أداء أفضل)
        BackdropGroup(child: child),
      ],
    );
  }
}
