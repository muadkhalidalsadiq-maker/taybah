---
name: apple-glass
description: زجاج ابل — Apple Liquid Glass effect for Flutter (and web/CSS) apps. Use when the user says "زجاج ابل", asks for glass / glassmorphism / Liquid Glass / iOS 26-style cards, frosted floating tab bars, or "خللي الكروت زجاجية". Provides a drop-in GlassContainer, a shared backdrop, a floating glass tab bar (capsule + separate circle button), and the visual rules that make it look like Apple's material instead of generic blur.
---

# زجاج ابل (Apple Liquid Glass)

The glass effect built for the طيبة app, packaged so it can be reused in any project.

## What makes it look like Apple (not generic glassmorphism)

Five layers, all required:

1. **Backdrop blur + saturation**: `ImageFilter.compose(outer: ColorFilter saturation ≈1.3, inner: blur σ≈18–24)`. Saturation is what makes it read as glass rather than fog.
2. **Translucent fill**: light `white @ 0.55–0.60`; dark `deep tint @ ~0.40` (for example `rgb(18,32,25)`). Never pure grey.
3. **Sheen**: a diagonal gradient (top-left white @ 0.27 light / 0.08 dark → transparent), painted on a **separate layer** above the fill. In Flutter, `gradient` overrides `color` in the same `BoxDecoration`.
4. **Light rim**: a 1.2px stroke whose gradient is bright at the top-left, fades through the middle, and catches light again at the bottom-right. `Border` cannot take a gradient, so paint it with a `foregroundDecoration` painter.
5. **Soft floating shadow**: large blur (≈26), offset down (≈10), low alpha. In light mode, add a 1px white top highlight.

**Needs something behind it.** Glass over a flat white background looks like nothing. Always place a backdrop behind the UI: a photo at low opacity under a colour wash (طيبة uses the Prophet's Mosque at 0.26 in dark mode and 0.30 under a light wash).

## Flutter recipe

1. Copy `reference/glass.dart` into the project (for example `lib/widgets/glass.dart`). It has no dependencies beyond Flutter.
2. Wrap the app once with the backdrop and a `BackdropGroup` (all grouped glass then shares a single backdrop read, which performs much better):

```dart
MaterialApp(
  builder: (context, child) => GlassBackdrop(
    image: const AssetImage('assets/images/bg.jpg'), // optional
    child: child!,
  ),
)
```

   Set `scaffoldBackgroundColor: Colors.transparent` in **both** themes so the backdrop shows through.
3. Use `GlassContainer` as a **drop-in replacement for `Container`**. It reads `borderRadius` or `shape: BoxShape.circle` from `decoration`:

```dart
GlassContainer(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(borderRadius: BorderRadius.circular(22)),
  child: ...,
)
// tinted glass (brand colour), e.g. a hero card:
GlassContainer(tint: const Color(0xD9183D24), elevation: 1.4, ...)
```

4. **Anything that floats over scrolling content** (tab bar, mini player, app bar) must use `grouped: false`, so it blurs the live content under it instead of the shared backdrop.
5. To convert an existing app in bulk: rename every `Container(` whose `BoxDecoration` uses the card/surface colour to `GlassContainer(`, as long as it only uses the params `padding, margin, width, height, alignment, constraints, decoration, child`. Then run `flutter analyze`.

## Floating tab bar (the Apple Mail / iOS 26 look)

A glass **capsule** holding icon-only tabs, plus a **separate glass circle** for one primary action. See `GlassTabBar` in `reference/glass.dart`:

- Height 62, radius 31, 6px inner padding. The selected tab gets an inner bubble (white @ 0.72 light / 0.12 dark), and its icon scales up to 1.08.
- Circle: 62×62, `shape: BoxShape.circle`, 14px gap from the capsule.
- Position it with `Positioned(left: 22, right: 22, bottom: 18 + safeArea.bottom)` inside a `Stack` over the pages. Give scrollable pages about 110px of bottom padding.
- Icons only, but always wrap each in `Tooltip` + `Semantics(label:)` for accessibility.

## Rules

- Keep sheets, dialogs and long reading surfaces (Quran pages, articles) **opaque**. Glass hurts readability under dense text.
- One accent colour for selected states. Don't add rainbow icon colours on glass.
- Radii: cards 20–24, hero 28, capsule = height/2.
- Text on glass: weight ≥ 500. Use pure white / near-black, never mid-grey.
- Performance: `BackdropFilter.grouped` under one `BackdropGroup` for all static cards; σ ≤ 24. On low-end Android, expose a "reduce transparency" option that sets `blur: 0` and raises the fill alpha to about 0.9.
- Verify by screenshot in **both** light and dark modes (for example a Flutter web build plus Playwright).

## Web / CSS equivalent

```css
.glass {
  background: linear-gradient(135deg, rgb(255 255 255 / .27), rgb(255 255 255 / 0)) ,
              rgb(255 255 255 / .58);
  backdrop-filter: blur(22px) saturate(1.35);
  -webkit-backdrop-filter: blur(22px) saturate(1.35);
  border-radius: 22px;
  border: 1.2px solid transparent;
  background-clip: padding-box;
  box-shadow: 0 10px 26px rgb(20 50 31 / .09), inset 0 1px 0 rgb(255 255 255 / .9);
  position: relative;
}
.glass::before { /* gradient rim */
  content: ""; position: absolute; inset: 0; border-radius: inherit; padding: 1.2px;
  background: linear-gradient(135deg, #fff 0%, rgb(255 255 255 / .43) 40%, rgb(255 255 255 / .23) 65%, rgb(255 255 255 / .78) 100%);
  -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
  -webkit-mask-composite: xor; mask-composite: exclude; pointer-events: none;
}
@media (prefers-color-scheme: dark) {
  .glass { background: linear-gradient(135deg, rgb(255 255 255 / .08), transparent), rgb(18 32 25 / .42);
           box-shadow: 0 12px 28px rgb(0 0 0 / .35); }
}
```
