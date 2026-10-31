import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'data/notification_service.dart';
import 'data/quran_player.dart';
import 'data/shared_prefs_helper.dart';
import 'presentation/welcome_screen.dart';
import 'presentation/widgets/taybah_backdrop.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppAudio.init();
  await NotificationService.instance.init();
  // نقرأ المظهر قبل أول إطار حتى لا يظهر وميض أبيض في الوضع الليلي
  final appState = AppState();
  await appState.loadSettings();
  runApp(TaybahApp(appState: appState));
}

class TaybahApp extends StatefulWidget {
  final AppState appState;
  const TaybahApp({super.key, required this.appState});

  @override
  State<TaybahApp> createState() => _TaybahAppState();
}

class _TaybahAppState extends State<TaybahApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    widget.appState.syncWithPlatform();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.appState,
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'طيبة للأذكار والصلاة',
            debugShowCheckedModeBanner: false,
            theme: TaybahTheme.lightTheme,
            darkTheme: TaybahTheme.darkTheme,
            themeMode: appState.isDark ? ThemeMode.dark : ThemeMode.light,
            themeAnimationDuration: const Duration(milliseconds: 250),
            locale: const Locale('ar'),
            supportedLocales: const [
              Locale('ar'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const WelcomeScreen(),
            builder: (context, child) => TaybahBackdrop(
              dark: appState.isDark,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  int _hijriAdjustment = 0;
  bool _isDark = false;

  /// الوضع الذي اختاره المستخدم (فاتح / ليلي / تلقائي حسب الهاتف).
  ThemeMode get themeMode => _themeMode;

  /// هل الواجهة الآن بالوضع الليلي فعلاً.
  bool get isDark => _isDark;
  int get hijriAdjustment => _hijriAdjustment;

  bool _computeDark() {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themeKey);
      if (saved != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => ThemeMode.light,
        );
      } else {
        final legacyDark = await SharedPrefsHelper.instance.isDarkMode();
        _themeMode = legacyDark ? ThemeMode.dark : ThemeMode.light;
      }
    } catch (_) {}
    _hijriAdjustment = await SharedPrefsHelper.instance.getHijriAdjustment();
    _apply(rebuild: false);
  }

  /// يطبق الألوان المتكيفة ويعيد بناء كل الشاشات المفتوحة.
  void _apply({bool rebuild = true}) {
    _isDark = _computeDark();
    TaybahColors.isDark = _isDark;
    SystemChrome.setSystemUIOverlayStyle(
      _isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    notifyListeners();
    if (rebuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    }
  }

  /// كثير من الشاشات تقرأ ألوان TaybahColors مباشرة، فنعيد بنائها كلها
  /// عند تغيير المظهر بدون فقدان حالتها (الصفحة المفتوحة، التمرير...).
  static void _rebuildAll() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return;
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }
    root.visitChildren(visit);
  }

  void syncWithPlatform() {
    if (_themeMode == ThemeMode.system && _computeDark() != _isDark) {
      _apply();
    }
  }

  Future<void> toggleTheme() =>
      setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _apply();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.name);
      await SharedPrefsHelper.instance.setDarkMode(mode == ThemeMode.dark);
    } catch (_) {}
  }

  Future<void> updateHijriAdjustment(int days) async {
    _hijriAdjustment = days;
    await SharedPrefsHelper.instance.setHijriAdjustment(days);
    notifyListeners();
  }
}
