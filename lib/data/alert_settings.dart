import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات التنبيهات الإضافية: قبل الأذان، الإقامة، والأذان في الوضع الصامت.
class AlertSettings {
  AlertSettings._();

  static const _preKey = 'pre_adhan_minutes';
  static const _iqamaKey = 'iqama_reminder';
  static const _silentKey = 'adhan_in_silent';

  /// الخيارات المتاحة للتنبيه قبل الأذان (0 = بدون).
  static const List<int> preAdhanOptions = [0, 5, 10, 15, 20, 30];

  static Future<int> preAdhanMinutes() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_preKey) ?? 0;
  }

  static Future<void> setPreAdhanMinutes(int minutes) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_preKey, minutes);
  }

  static Future<bool> iqamaReminder() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_iqamaKey) ?? false;
  }

  static Future<void> setIqamaReminder(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_iqamaKey, v);
  }

  static Future<bool> adhanInSilent() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_silentKey) ?? false;
  }

  static Future<void> setAdhanInSilent(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_silentKey, v);
  }
}
