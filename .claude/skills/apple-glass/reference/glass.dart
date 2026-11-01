// زجاج ابل — Apple Liquid Glass for Flutter. Self-contained; copy into any project.
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

class Glass {
  Glass._();

  /// Blur + saturation boost (≈1.35), like real glass over colour.
  static ui.ImageFilter filter({double sigma = 22}) => ui.ImageFilter.compose(
        outer: const ui.ColorFilter.matrix(<double>[
          1.24, -0.21, -0.03, 0, 0,
          -0.07, 1.10, -0.03, 0, 0,
          -0.07, -0.21, 1.28, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        inner: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      );

  static Color fill(bool dark, {Color? tint}) =>
      tint ??
      (dark
          ? const Color.fromRGBO(18, 32, 25, 0.42)
          : const Color.fromRGBO(255, 255, 255, 0.58));

  static List<BoxShadow> shadows(bool dark, {double elevation = 1}) => dark
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

/// Drop-in replacement for Container that renders as Liquid Glass.
/// Reads borderRadius / circle shape from [decoration].
class GlassContainer extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding, margin;
  final double? width, height;
  final AlignmentGeometry? alignment;
  final BoxConstraints? constraints;
  final Decoration? decoration;
  final Color? tint;
  final double blur, elevation;

  /// true = share the app-level backdrop (cheap, for static cards).
  /// false = blur live content underneath (for bars floating over scrolling lists).
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
    final dark = _isDark(context);
    final deco = decoration is BoxDecoration ? decoration as BoxDecoration : null;
    final circle = deco?.shape == BoxShape.circle;
    final radius = circle
        ? null
        : (deco?.borderRadius?.resolve(Directionality.of(context)) ??
            BorderRadius.circular(22));
    final shape = circle ? BoxShape.circle : BoxShape.rectangle;

    // Two layers: fill, then sheen (a gradient would override the colour if combined).
    final body = DecoratedBox(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: radius,
        color: Glass.fill(dark, tint: tint),
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
            colors: dark
                ? [Colors.white.withAlpha(20), Colors.white.withAlpha(0)]
                : [Colors.white.withAlpha(70), Colors.white.withAlpha(0)],
          ),
        ),
        foregroundDecoration: _GlassRim(radius: radius, circle: circle, dark: dark),
        child: child,
      ),
    );

    final f = Glass.filter(sigma: blur);
    final filtered = grouped
        ? BackdropFilter.grouped(filter: f, child: body)
        : BackdropFilter(filter: f, child: body);

    return Container(
      margin: margin,
      width: width,
      height: height,
      constraints: constraints,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: radius,
        boxShadow: Glass.shadows(dark, elevation: elevation),
      ),
      child: circle
          ? ClipOval(child: filtered)
          : ClipRRect(borderRadius: radius!, child: filtered),
    );
  }
}

class _GlassRim extends Decoration {
  final BorderRadius? radius;
  final bool circle, dark;
  const _GlassRim({this.radius, this.circle = false, this.dark = false});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _GlassRimPainter(radius, circle, dark);
}

class _GlassRimPainter extends BoxPainter {
  final BorderRadius? radius;
  final bool circle, dark;
  _GlassRimPainter(this.radius, this.circle, this.dark);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final size = cfg.size;
    if (size == null) return;
    final rect = (offset & size).deflate(0.6);
    final rrect = circle
        ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2))
        : (radius ?? BorderRadius.circular(22)).toRRect(rect);
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

/// App-level backdrop: optional photo at low opacity under a colour wash,
/// plus a BackdropGroup so all grouped glass shares one backdrop read.
class GlassBackdrop extends StatelessWidget {
  final Widget child;
  final ImageProvider? image;
  final Color lightBase, darkBase;
  final double lightOpacity, darkOpacity;

  const GlassBackdrop({
    super.key,
    required this.child,
    this.image,
    this.lightBase = const Color(0xFFF4F7F2),
    this.darkBase = const Color(0xFF07110C),
    this.lightOpacity = 0.30,
    this.darkOpacity = 0.26,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final base = dark ? darkBase : lightBase;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: base),
        if (image != null)
          Opacity(
            opacity: dark ? darkOpacity : lightOpacity,
            child: Image(image: image!, fit: BoxFit.cover),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                base.withAlpha(dark ? 204 : 230),
                base.withAlpha(dark ? 102 : 153),
                base.withAlpha(dark ? 128 : 128),
                base.withAlpha(dark ? 242 : 217),
              ],
              stops: const [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
        BackdropGroup(child: child),
      ],
    );
  }
}

/// Floating glass tab bar: capsule of icon tabs + separate glass circle action.
class GlassTabBar extends StatelessWidget {
  final List<(String label, IconData selected, IconData idle)> items;
  final int index;
  final ValueChanged<int> onTap;
  final (String label, IconData icon, VoidCallback onTap)? action;
  final Color? activeColor;

  const GlassTabBar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
    this.action,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final active = activeColor ?? Theme.of(context).colorScheme.primary;
    final idle = dark ? Colors.white.withAlpha(190) : const Color(0xFF26352B);
    return Row(
      children: [
        Expanded(
          child: GlassContainer(
            height: 62,
            grouped: false,
            blur: 18,
            elevation: 1.2,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(31)),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: Tooltip(
                      message: items[i].$1,
                      child: Semantics(
                        label: items[i].$1,
                        selected: i == index,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              color: i == index
                                  ? (dark
                                      ? Colors.white.withAlpha(30)
                                      : Colors.white.withAlpha(185))
                                  : Colors.transparent,
                            ),
                            child: Center(
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 220),
                                scale: i == index ? 1.08 : 1,
                                child: Icon(
                                  i == index ? items[i].$2 : items[i].$3,
                                  size: 25,
                                  color: i == index ? active : idle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 14),
          Tooltip(
            message: action!.$1,
            child: GestureDetector(
              onTap: action!.$3,
              child: GlassContainer(
                width: 62,
                height: 62,
                grouped: false,
                blur: 18,
                elevation: 1.2,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Center(child: Icon(action!.$2, size: 26, color: idle)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
