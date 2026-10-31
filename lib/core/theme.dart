import 'package:flutter/material.dart';

/// الخطوط: Somar Sans للواجهة، وأميري للنص القرآني.
class TaybahFonts {
  TaybahFonts._();
  static const String ui = 'Somar';
}

class TaybahColors {
  /// يحدده AppState عند تغيير الوضع الليلي؛ الألوان المحايدة بالأسفل تتبدل تلقائياً.
  static bool isDark = false;

  // ──── ألوان الهوية الثابتة (لا تتغير بين الوضعين) ────
  static const Color forest = Color(0xFF183D24); // الأخضر الملكي
  static const Color forestDeep = Color(0xFF0C2314); // أخضر منتصف الليل
  static const Color primaryMedium = Color(0xFF1E4D2E);
  static const Color primaryAccent = Color(0xFF2D6E42);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE9C86A);
  static const Color mint = Color(0xFF8FD3A8);

  // ──── ألوان متكيفة (فاتح / ليلي) ────
  static Color get primary =>
      isDark ? const Color(0xFF3E9B66) : const Color(0xFF183D24);
  static Color get primaryDark =>
      isDark ? const Color(0xFFA9DDBB) : const Color(0xFF0C2314);
  static Color get primaryLight =>
      isDark ? const Color(0xFF1F3B2A) : const Color(0xFFCDE4D4);
  static Color get primaryTint =>
      isDark ? const Color(0xFF14261C) : const Color(0xFFEBF5EF);
  static Color get goldSoft =>
      isDark ? const Color(0xFF2B2513) : const Color(0xFFFAF3DF);

  /// خلفية الشاشات. في الوضع الليلي شفافة لتظهر صورة المسجد النبوي خلفها.
  static Color get background =>
      isDark ? Colors.transparent : const Color(0xFFF7FAF8);

  /// البطاقات: في الليلي شبه معتمة فتطفو فوق الصورة.
  static Color get surface => isDark ? const Color(0xE0101E17) : Colors.white;

  /// النوافذ المنبثقة والقوائم السفلية (معتمة دائماً).
  static Color get sheet => isDark ? const Color(0xFF0F1C15) : Colors.white;
  static Color get surfaceMuted =>
      isDark ? darkSurfaceMuted : const Color(0xFFEFF4F0);
  static Color get border => isDark ? darkBorder : const Color(0xFFDFE8E1);
  static Color get borderGlow =>
      isDark ? const Color(0xFF2F5A40) : const Color(0xFFB8D4C0);

  static Color get textPrimary =>
      isDark ? darkTextPrimary : const Color(0xFF0F1E14);
  static Color get textSecondary =>
      isDark ? darkTextSecondary : const Color(0xFF384A3D);
  static Color get textMuted =>
      isDark ? darkTextMuted : const Color(0xFF6E8073);

  // ──── ألوان الوضع الليلي (ليل زمردي عميق) ────
  static const Color darkBg = Color(0xFF07110C);
  static const Color darkSurface = Color(0xFF0F1C15);
  static const Color darkSurfaceMuted = Color(0xFF16261D);
  static const Color darkBorder = Color(0xFF223A2C);
  static const Color darkTextPrimary = Color(0xFFEAF2EC);
  static const Color darkTextSecondary = Color(0xFFB9CBBF);
  static const Color darkTextMuted = Color(0xFF7F978A);
}

class TaybahTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme.apply(fontFamily: TaybahFonts.ui);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7FAF8),
      fontFamily: TaybahFonts.ui,
      primaryColor: TaybahColors.primary,
      colorScheme: ColorScheme.light(
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
        displayLarge: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: TaybahColors.textPrimary,
        ),
        displayMedium: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: TaybahColors.textPrimary,
        ),
        titleLarge: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: TaybahColors.textPrimary,
        ),
        titleMedium: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: TaybahColors.textPrimary,
        ),
        bodyLarge: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 15,
          fontWeight: FontWeight.w300,
          color: TaybahColors.textPrimary,
        ),
        bodyMedium: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 13,
          fontWeight: FontWeight.w300,
          color: TaybahColors.textSecondary,
        ),
        labelLarge: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: TaybahColors.surface,
        foregroundColor: TaybahColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: TaybahColors.textPrimary,
        ),
        iconTheme: IconThemeData(
          color: TaybahColors.primary,
        ),
      ),
      cardTheme: CardThemeData(
        color: TaybahColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: TaybahColors.border, width: 1),
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
          return TextStyle(fontFamily: TaybahFonts.ui, 
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
          textStyle: TextStyle(fontFamily: TaybahFonts.ui, 
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
          borderSide: BorderSide(color: TaybahColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: TaybahColors.primary, width: 1.5),
        ),
        hintStyle: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 14,
          color: TaybahColors.textMuted,
        ),
      ),
    );
  }

  // ──── Dark Theme (Emerald Night Mode) ────
  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme.apply(fontFamily: TaybahFonts.ui);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: TaybahFonts.ui,
      cardColor: TaybahColors.darkSurface,
      dialogTheme: const DialogThemeData(backgroundColor: TaybahColors.darkSurface),
      canvasColor: TaybahColors.darkBg,
      dividerColor: TaybahColors.darkBorder,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TaybahColors.darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      primaryColor: TaybahColors.primaryAccent,
      colorScheme: ColorScheme.dark(
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
        displayLarge: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: TaybahColors.darkTextPrimary,
        ),
        displayMedium: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: TaybahColors.darkTextPrimary,
        ),
        titleLarge: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: TaybahColors.darkTextPrimary,
        ),
        titleMedium: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: TaybahColors.darkTextPrimary,
        ),
        bodyLarge: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 15,
          fontWeight: FontWeight.w300,
          color: TaybahColors.darkTextPrimary,
        ),
        bodyMedium: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 13,
          fontWeight: FontWeight.w300,
          color: TaybahColors.darkTextSecondary,
        ),
        labelLarge: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xB3070F0B),
        foregroundColor: TaybahColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 19,
          fontWeight: FontWeight.w600,
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
          textStyle: TextStyle(fontFamily: TaybahFonts.ui, 
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
        hintStyle: TextStyle(fontFamily: TaybahFonts.ui, 
          fontSize: 14,
          color: TaybahColors.darkTextMuted,
        ),
      ),
    );
  }
}

