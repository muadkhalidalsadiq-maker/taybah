import 'dart:math' as math;
import 'package:flutter/material.dart';

/// عناصر الهوية البصرية لتطبيق «طيبة للأذكار والصلاة».
class TaybahBrand {
  TaybahBrand._();

  static const String appName = 'طيبة للأذكار والصلاة';
  static const String shortName = 'طيبة';
  static const String tagline = 'طيبة لمن طاب قلبه بذكر الله';
  static const String logoAsset = 'assets/images/logo.png';
}

/// أيقونة «أسماء الله الحسنى»: نجمة ثمانية (ربع الحزب) بداخلها هلال.
/// مرسومة بالكود حتى تبقى حادة في كل المقاسات وتتلون حسب الحاجة.
class AsmaAllahIcon extends StatelessWidget {
  final double size;
  final Color color;

  const AsmaAllahIcon({
    super.key,
    this.size = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AsmaAllahIconPainter(color)),
    );
  }
}

class _AsmaAllahIconPainter extends CustomPainter {
  final Color color;

  _AsmaAllahIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2);
    final r = s * 0.47;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // مربعان متقاطعان = نجمة ثمانية
    for (final start in [math.pi / 4, 0.0]) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = start + i * math.pi / 2;
        final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, stroke);
    }

    // هلال في المركز
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final outer = Path()
      ..addOval(Rect.fromCircle(center: c, radius: s * 0.17));
    final inner = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(c.dx + s * 0.065, c.dy - s * 0.04),
          radius: s * 0.135,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, inner),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _AsmaAllahIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
