import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TaybahColors {
  // Deep Royal Islamic Forest Emerald Palette (Darker, more prestigious & majestic)
  static const Color primary = Color(0xFF183D24); // Deep Royal Forest Green
  static const Color primaryDark = Color(0xFF0C2314); // Midnight Forest Green
  static const Color primaryMedium = Color(0xFF1E4D2E); // Rich Pine Green
  static const Color primaryAccent = Color(0xFF2D6E42); // Vibrant Emerald Accent
  static const Color primaryLight = Color(0xFFCDE4D4); // Soft Mint Sage Light
  static const Color primaryTint = Color(0xFFEBF5EF); // Ultra soft Forest Tint

  // Noble Imperial Gold Accents
  static const Color gold = Color(0xFFD4AF37); // Radiant Imperial Gold
  static const Color goldLight = Color(0xFFE9C86A); // Shimmering Gold
  static const Color goldSoft = Color(0xFFFAF3DF); // Soft Warm Gold Tint

  // Neutral Background & Surface
  static const Color background = Color(0xFFF7FAF8); // Crisp Pearl Off-White
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFEFF4F0);
  static const Color border = Color(0xFFDFE8E1);
  static const Color borderGlow = Color(0xFFB8D4C0);

  // Typography
  static const Color textPrimary = Color(0xFF0F1E14); // Deep Rich Dark
  static const Color textSecondary = Color(0xFF384A3D);
  static const Color textMuted = Color(0xFF6E8073);

  // ──── Dark Theme Colors ────
  static const Color darkBg = Color(0xFF0A1A10); // Deep midnight emerald
  static const Color darkSurface = Color(0xFF12261A); // Dark forest card
  static const Color darkSurfaceMuted = Color(0xFF1A3324); // Slightly lighter
  static const Color darkBorder = Color(0xFF264D34); // Subtle emerald border
  static const Color darkTextPrimary = Color(0xFFE8F0EA); // Bright text
  static const Color darkTextSecondary = Color(0xFFB0C4B7);
  static const Color darkTextMuted = Color(0xFF6E8A78);
}

class TaybahTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.cairoTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: TaybahColors.background,
      primaryColor: TaybahColors.primary,
      colorScheme: const ColorScheme.light(
        primary: TaybahColors.primary,
        onPrimary: Colors.white,
        primaryContainer: TaybahColors.primaryLight,
        onPrimaryContainer: TaybahColors.primaryDark,
        secondary: TaybahColors.gold,
        onSecondary: Colors.white,
        secondaryContainer: TaybahColors.goldSoft,
        onSecondaryContainer: TaybahColors.gold,
        surface: TaybahColors.surface,
        onSurface: TaybahColors.textPrimary,
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.cairo(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: TaybahColors.textPrimary,
        ),
        displayMedium: GoogleFonts.cairo(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: TaybahColors.textPrimary,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: TaybahColors.textPrimary,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: TaybahColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          color: TaybahColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: TaybahColors.textSecondary,
        ),
        labelLarge: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: TaybahColors.surface,
        foregroundColor: TaybahColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: TaybahColors.textPrimary,
        ),
        iconTheme: const IconThemeData(
          color: TaybahColors.primary,
        ),
      ),
      cardTheme: CardThemeData(
        color: TaybahColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: TaybahColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: TaybahColors.surface,
        elevation: 10,
        shadowColor: Colors.black.withAlpha(25),
        indicatorColor: TaybahColors.primaryLight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? TaybahColors.primaryDark : TaybahColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected ? TaybahColors.primaryDark : TaybahColors.textMuted,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TaybahColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: TaybahColors.primary.withAlpha(60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TaybahColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: TaybahColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: TaybahColors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.cairo(
          fontSize: 14,
          color: TaybahColors.textMuted,
        ),
      ),
    );
  }

  // ──── Dark Theme (Emerald Night Mode) ────
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TaybahColors.darkBg,
      cardColor: TaybahColors.darkSurface,
      dialogTheme: const DialogThemeData(backgroundColor: TaybahColors.darkSurface),
      canvasColor: TaybahColors.darkBg,
      dividerColor: TaybahColors.darkBorder,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TaybahColors.darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      primaryColor: TaybahColors.primaryAccent,
      colorScheme: const ColorScheme.dark(
        primary: TaybahColors.primaryAccent,
        onPrimary: Colors.white,
        primaryContainer: TaybahColors.primaryMedium,
        onPrimaryContainer: TaybahColors.primaryLight,
        secondary: TaybahColors.gold,
        onSecondary: Colors.black,
        secondaryContainer: Color(0xFF3D3010),
        onSecondaryContainer: TaybahColors.goldLight,
        surface: TaybahColors.darkSurface,
        onSurface: TaybahColors.darkTextPrimary,
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.cairo(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: TaybahColors.darkTextPrimary,
        ),
        displayMedium: GoogleFonts.cairo(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: TaybahColors.darkTextPrimary,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: TaybahColors.darkTextPrimary,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: TaybahColors.darkTextPrimary,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          color: TaybahColors.darkTextPrimary,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: TaybahColors.darkTextSecondary,
        ),
        labelLarge: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: TaybahColors.darkSurface,
        foregroundColor: TaybahColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: TaybahColors.darkTextPrimary,
        ),
        iconTheme: const IconThemeData(
          color: TaybahColors.goldLight,
        ),
      ),
      cardTheme: CardThemeData(
        color: TaybahColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: TaybahColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TaybahColors.primaryAccent,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: TaybahColors.primaryAccent.withAlpha(60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TaybahColors.darkSurfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: TaybahColors.darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: TaybahColors.primaryAccent, width: 1.5),
        ),
        hintStyle: GoogleFonts.cairo(
          fontSize: 14,
          color: TaybahColors.darkTextMuted,
        ),
      ),
    );
  }
}

