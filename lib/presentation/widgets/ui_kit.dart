import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// عناصر الواجهة المشتركة: بطاقة، عنوان قسم، زخرفة هندسية.
/// الهدف: لغة تصميم واحدة هادئة في كل الشاشات.

TextStyle tStyle(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color? color,
  double? height,
}) =>
    TextStyle(
      fontFamily: TaybahFonts.ui,
      fontSize: size,
      fontWeight: weight,
      color: color ?? TaybahColors.textPrimary,
      height: height,
    );

/// بطاقة أساسية: سطح هادئ بحد رفيع، وفي الليلي شبه شفافة فوق صورة المسجد.
class TCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadius? radius;

  const TCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius ?? BorderRadius.circular(20);
    final dark = TaybahColors.isDark;
    return Container(
      decoration: BoxDecoration(
        color: color ?? TaybahColors.surface,
        borderRadius: r,
        border: Border.all(
          color: dark ? Colors.white.withAlpha(16) : TaybahColors.border,
        ),
        boxShadow: dark
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(70),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF183D24).withAlpha(10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// عنوان قسم بسيط مع إجراء اختياري.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: tStyle(16, weight: FontWeight.w700))),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: tStyle(13,
                    weight: FontWeight.w600,
                    color: TaybahColors.isDark
                        ? TaybahColors.goldLight
                        : TaybahColors.primaryAccent),
              ),
            ),
        ],
      ),
    );
  }
}

/// أيقونة داخل مربع ملوّن خفيف (لون الهوية فقط).
class TIconBox extends StatelessWidget {
  final IconData? icon;
  final Widget? custom;
  final double size;
  final bool filled;

  const TIconBox({
    super.key,
    this.icon,
    this.custom,
    this.size = 44,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = TaybahColors.isDark;
    final bg = filled
        ? TaybahColors.forest
        : (dark ? Colors.white.withAlpha(14) : TaybahColors.primaryTint);
    final fg = filled
        ? TaybahColors.goldLight
        : (dark ? TaybahColors.goldLight : TaybahColors.forest);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Center(
        child: custom ?? Icon(icon, color: fg, size: size * 0.5),
      ),
    );
  }
}

/// زخرفة هندسية (نجمة ثمانية متكررة) بشفافية خفيفة — تُستعمل في البطاقة الرئيسية.
class GeometricPattern extends CustomPainter {
  final Color color;
  final double cell;

  GeometricPattern({required this.color, this.cell = 46});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = cell * 0.34;
    for (double y = -cell; y < size.height + cell; y += cell) {
      for (double x = -cell; x < size.width + cell; x += cell) {
        final c = Offset(x + (((y / cell).round()).isOdd ? cell / 2 : 0), y);
        for (final start in [0.0, math.pi / 4]) {
          final path = Path();
          for (var i = 0; i < 4; i++) {
            final a = start + i * math.pi / 2;
            final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
            i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
          }
          path.close();
          canvas.drawPath(path, p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GeometricPattern old) =>
      old.color != color || old.cell != cell;
}
