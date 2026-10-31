import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// زجاج سائل على طريقة Apple (Liquid Glass):
/// تمويه لما خلف العنصر + تشبع لوني خفيف + طبقة لمعان + حافة مضيئة متدرجة + ظل ناعم.
class Glass {
  Glass._();

  static ui.ImageFilter filter({double sigma = 22}) => ui.ImageFilter.compose(
        outer: const ui.ColorFilter.matrix(<double>[
          // زيادة التشبع قليلاً (1.35) كما يفعل الزجاج الحقيقي مع الألوان خلفه
          1.24, -0.21, -0.03, 0, 0,
          -0.07, 1.10, -0.03, 0, 0,
          -0.07, -0.21, 1.28, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        inner: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      );

  /// لون تعبئة الزجاج.
  static Color fill({Color? tint, double strength = 1}) {
    if (tint != null) return tint;
    return TaybahColors.isDark
        ? Color.fromRGBO(18, 32, 25, 0.42 * strength)
        : Color.fromRGBO(255, 255, 255, 0.58 * strength);
  }

  static List<BoxShadow> shadows({double elevation = 1}) => TaybahColors.isDark
      ? [
          BoxShadow(
            color: Colors.black.withAlpha((90 * elevation).round()),
            blurRadius: 28 * elevation,
            offset: Offset(0, 12 * elevation),
          ),
        ]
      : [
          BoxShadow(
            color: const Color(0xFF14321F).withAlpha((22 * elevation).round()),
            blurRadius: 26 * elevation,
            offset: Offset(0, 10 * elevation),
          ),
          BoxShadow(
            color: Colors.white.withAlpha(120),
            blurRadius: 1,
            offset: const Offset(0, -0.5),
          ),
        ];
}

/// بديل مباشر لـ Container ببطاقة زجاجية. يأخذ نصف القطر من [decoration].
class GlassContainer extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final BoxConstraints? constraints;
  final Decoration? decoration;
  final Color? tint;
  final double blur;
  final double elevation;
  final bool grouped;

  const GlassContainer({
    super.key,
    this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.alignment,
    this.constraints,
    this.decoration,
    this.tint,
    this.blur = 22,
    this.elevation = 1,
    this.grouped = true,
  });

  @override
  Widget build(BuildContext context) {
    final deco = decoration is BoxDecoration ? decoration as BoxDecoration : null;
    final isCircle = deco?.shape == BoxShape.circle;
    final radius = isCircle
        ? null
        : (deco?.borderRadius?.resolve(Directionality.of(context)) ??
            BorderRadius.circular(20));
    // لون مخصص صريح غير لون السطح العادي يُحترم كلون للزجاج
    final customTint = deco?.color != null &&
            deco!.color != TaybahColors.surface &&
            deco.color != Colors.transparent
        ? deco.color!.withAlpha(((deco.color!.a * 255) * 0.82).round())
        : null;

    final shape = isCircle ? BoxShape.circle : BoxShape.rectangle;
    // طبقتان: لون الزجاج، ثم لمعة متدرجة فوقه (التدرج في Flutter يلغي اللون إذا اجتمعا)
    final glassBody = DecoratedBox(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: radius,
        color: Glass.fill(tint: tint ?? customTint),
      ),
      child: Container(
        padding: padding,
        alignment: alignment,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: TaybahColors.isDark
                ? [Colors.white.withAlpha(20), Colors.white.withAlpha(0)]
                : [Colors.white.withAlpha(70), Colors.white.withAlpha(0)],
          ),
        ),
        foregroundDecoration: _GlassRim(radius: radius, circle: isCircle),
        child: child,
      ),
    );

    final filter = Glass.filter(sigma: blur);
    final clipped = isCircle
        ? ClipOval(
            child: grouped
                ? BackdropFilter.grouped(filter: filter, child: glassBody)
                : BackdropFilter(filter: filter, child: glassBody),
          )
        : ClipRRect(
            borderRadius: radius!,
            child: grouped
                ? BackdropFilter.grouped(filter: filter, child: glassBody)
                : BackdropFilter(filter: filter, child: glassBody),
          );

    return Container(
      margin: margin,
      width: width,
      height: height,
      constraints: constraints,
      decoration: BoxDecoration(
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius,
        boxShadow: Glass.shadows(elevation: elevation),
      ),
      child: clipped,
    );
  }
}

/// حافة الزجاج: خط رفيع مضيء من الأعلى ويتلاشى للأسفل، مع لمعة سفلية خفيفة.
class _GlassRim extends Decoration {
  final BorderRadius? radius;
  final bool circle;
  const _GlassRim({this.radius, this.circle = false});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _GlassRimPainter(radius, circle);
}

class _GlassRimPainter extends BoxPainter {
  final BorderRadius? radius;
  final bool circle;
  _GlassRimPainter(this.radius, this.circle);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final size = cfg.size;
    if (size == null) return;
    final rect = (offset & size).deflate(0.6);
    final rrect = circle
        ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2))
        : (radius ?? BorderRadius.circular(20)).toRRect(rect);
    final dark = TaybahColors.isDark;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? [
                Colors.white.withAlpha(95),
                Colors.white.withAlpha(14),
                Colors.white.withAlpha(10),
                Colors.white.withAlpha(45),
              ]
            : [
                Colors.white.withAlpha(250),
                Colors.white.withAlpha(110),
                Colors.white.withAlpha(60),
                Colors.white.withAlpha(200),
              ],
        stops: const [0.0, 0.4, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }
}
