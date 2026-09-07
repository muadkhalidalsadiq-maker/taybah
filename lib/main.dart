import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'data/notification_service.dart';
import 'data/shared_prefs_helper.dart';
import 'presentation/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const TaybahApp());
}

class TaybahApp extends StatelessWidget {
  const TaybahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..loadSettings(),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'طيبة',
            debugShowCheckedModeBanner: false,
            theme: TaybahTheme.lightTheme,
            darkTheme: TaybahTheme.darkTheme,
            themeMode: appState.themeMode,
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
          );
        },
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  int _hijriAdjustment = 0;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  int get hijriAdjustment => _hijriAdjustment;

  Future<void> loadSettings() async {
    final isDarkPref = await SharedPrefsHelper.instance.isDarkMode();
    _themeMode = isDarkPref ? ThemeMode.dark : ThemeMode.light;
    _hijriAdjustment = await SharedPrefsHelper.instance.getHijriAdjustment();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    await SharedPrefsHelper.instance.setDarkMode(isDark);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await SharedPrefsHelper.instance.setDarkMode(mode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> updateHijriAdjustment(int days) async {
    _hijriAdjustment = days;
    await SharedPrefsHelper.instance.setHijriAdjustment(days);
    notifyListeners();
  }
}

