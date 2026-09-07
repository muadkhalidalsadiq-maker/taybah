import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsHelper {
  static final SharedPrefsHelper instance = SharedPrefsHelper._internal();
  SharedPreferences? _prefs;

  SharedPrefsHelper._internal();

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // First launch check
  Future<bool> isFirstLaunch() async {
    final p = await prefs;
    return p.getBool('is_first_launch') ?? true;
  }

  Future<void> setFirstLaunchCompleted() async {
    final p = await prefs;
    await p.setBool('is_first_launch', false);
  }

  // Summer Time (?s=2) - default true
  Future<bool> isSummerTime() async {
    final p = await prefs;
    return p.getBool('is_summer_time') ?? true;
  }

  Future<void> setSummerTime(bool isSummer) async {
    final p = await prefs;
    await p.setBool('is_summer_time', isSummer);
  }

  // Selected Libyan City
  Future<void> setSelectedCity(String name, String slug) async {
    final p = await prefs;
    await p.setString('selected_city_name', name);
    await p.setString('selected_city_slug', slug);
  }

  Future<String> getSelectedCityName() async {
    final p = await prefs;
    return p.getString('selected_city_name') ?? 'زنتان';
  }

  Future<String> getSelectedCitySlug() async {
    final p = await prefs;
    return p.getString('selected_city_slug') ??
        '1478488_ly_zintan-(%D8%B2%D9%86%D8%AA%D8%A7%D9%86).html';
  }

  // Daily Prayer Tracker (Fajr, Dhuhr, Asr, Maghrib, Isha)
  Future<Map<String, bool>> getDailyPrayerTracker(String dateStr) async {
    final p = await prefs;
    return {
      'Fajr': p.getBool('prayer_${dateStr}_Fajr') ?? false,
      'Dhuhr': p.getBool('prayer_${dateStr}_Dhuhr') ?? false,
      'Asr': p.getBool('prayer_${dateStr}_Asr') ?? false,
      'Maghrib': p.getBool('prayer_${dateStr}_Maghrib') ?? false,
      'Isha': p.getBool('prayer_${dateStr}_Isha') ?? false,
    };
  }

  Future<void> togglePrayerTracker(String dateStr, String prayerKey) async {
    final p = await prefs;
    final current = p.getBool('prayer_${dateStr}_$prayerKey') ?? false;
    await p.setBool('prayer_${dateStr}_$prayerKey', !current);
  }

  // Daily Nawafil Checklist
  Future<Map<String, bool>> getDailyNawafilTracker(String dateStr) async {
    final p = await prefs;
    return {
      'duha': p.getBool('nafl_${dateStr}_duha') ?? false,
      'fajr_sunnah': p.getBool('nafl_${dateStr}_fajr_sunnah') ?? false,
      'dhuhr_rawatib': p.getBool('nafl_${dateStr}_dhuhr_rawatib') ?? false,
      'maghrib_sunnah': p.getBool('nafl_${dateStr}_maghrib_sunnah') ?? false,
      'witr': p.getBool('nafl_${dateStr}_witr') ?? false,
    };
  }

  Future<void> toggleNaflTracker(String dateStr, String naflKey) async {
    final p = await prefs;
    final current = p.getBool('nafl_${dateStr}_$naflKey') ?? false;
    await p.setBool('nafl_${dateStr}_$naflKey', !current);
  }

  // Bookmark / Last Read
  Future<void> setLastRead({
    required int surahId,
    required String surahName,
    required int verseId,
    required int jozz,
  }) async {
    final p = await prefs;
    await p.setInt('last_read_surah_id', surahId);
    await p.setString('last_read_surah_name', surahName);
    await p.setInt('last_read_verse_id', verseId);
    await p.setInt('last_read_jozz', jozz);
  }

  Future<Map<String, dynamic>> getLastRead() async {
    final p = await prefs;
    return {
      'surahId': p.getInt('last_read_surah_id') ?? 1,
      'surahName': p.getString('last_read_surah_name') ?? 'الفَاتِحة',
      'verseId': p.getInt('last_read_verse_id') ?? 1,
      'jozz': p.getInt('last_read_jozz') ?? 1,
    };
  }

  // Quran Font Size
  Future<void> setQuranFontSize(double size) async {
    final p = await prefs;
    await p.setDouble('quran_font_size', size);
  }

  Future<double> getQuranFontSize() async {
    final p = await prefs;
    return p.getDouble('quran_font_size') ?? 26.0;
  }

  // Notifications
  Future<void> setNotificationsEnabled(bool value) async {
    final p = await prefs;
    await p.setBool('notifications_enabled', value);
  }

  Future<bool> getNotificationsEnabled() async {
    final p = await prefs;
    return p.getBool('notifications_enabled') ?? true;
  }

  // Prayer Manual Offsets (minutes: -30 to +30)
  Future<int> getPrayerOffset(String prayerKey) async {
    final p = await prefs;
    return p.getInt('prayer_offset_$prayerKey') ?? 0;
  }

  Future<void> setPrayerOffset(String prayerKey, int offset) async {
    final p = await prefs;
    await p.setInt('prayer_offset_$prayerKey', offset);
  }

  Future<Map<String, int>> getAllPrayerOffsets() async {
    final p = await prefs;
    return {
      'Fajr': p.getInt('prayer_offset_Fajr') ?? 0,
      'Sunrise': p.getInt('prayer_offset_Sunrise') ?? 0,
      'Dhuhr': p.getInt('prayer_offset_Dhuhr') ?? 0,
      'Asr': p.getInt('prayer_offset_Asr') ?? 0,
      'Maghrib': p.getInt('prayer_offset_Maghrib') ?? 0,
      'Isha': p.getInt('prayer_offset_Isha') ?? 0,
    };
  }

  // Daily Adhkar Reminders toggles
  Future<bool> isMorningAdhkarReminderEnabled() async {
    final p = await prefs;
    return p.getBool('reminder_morning_adhkar') ?? true;
  }

  Future<void> setMorningAdhkarReminderEnabled(bool val) async {
    final p = await prefs;
    await p.setBool('reminder_morning_adhkar', val);
  }

  Future<bool> isEveningAdhkarReminderEnabled() async {
    final p = await prefs;
    return p.getBool('reminder_evening_adhkar') ?? true;
  }

  Future<void> setEveningAdhkarReminderEnabled(bool val) async {
    final p = await prefs;
    await p.setBool('reminder_evening_adhkar', val);
  }

  Future<bool> isSleepAdhkarReminderEnabled() async {
    final p = await prefs;
    return p.getBool('reminder_sleep_adhkar') ?? true;
  }

  Future<void> setSleepAdhkarReminderEnabled(bool val) async {
    final p = await prefs;
    await p.setBool('reminder_sleep_adhkar', val);
  }

  // ──── Dark Mode ────
  Future<bool> isDarkMode() async {
    final p = await prefs;
    return p.getBool('is_dark_mode') ?? false;
  }

  Future<void> setDarkMode(bool val) async {
    final p = await prefs;
    await p.setBool('is_dark_mode', val);
  }

  // ──── Hijri Calendar Day Adjustment (-2 to +2) ────
  Future<int> getHijriAdjustment() async {
    final p = await prefs;
    return p.getInt('hijri_adjustment') ?? 0;
  }

  Future<void> setHijriAdjustment(int days) async {
    final p = await prefs;
    await p.setInt('hijri_adjustment', days.clamp(-2, 2));
  }

  // ──── Adhan Sound Selection ────
  Future<String> getAdhanSound() async {
    final p = await prefs;
    return p.getString('adhan_sound') ?? 'default';
  }

  Future<void> setAdhanSound(String sound) async {
    final p = await prefs;
    await p.setString('adhan_sound', sound);
  }

  // ──── Daily Tasbeeh Stats ────
  Future<int> getDailyTasbeehCount(String dateStr) async {
    final p = await prefs;
    return p.getInt('tasbeeh_$dateStr') ?? 0;
  }

  Future<void> addDailyTasbeehCount(String dateStr, int count) async {
    final p = await prefs;
    final current = p.getInt('tasbeeh_$dateStr') ?? 0;
    await p.setInt('tasbeeh_$dateStr', current + count);
  }

  Future<Map<String, int>> getWeeklyTasbeehStats() async {
    final p = await prefs;
    final now = DateTime.now();
    final stats = <String, int>{};
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.year}_${d.month}_${d.day}';
      stats[key] = p.getInt('tasbeeh_$key') ?? 0;
    }
    return stats;
  }

  // ──── Khatmah Progress ────
  Future<int> getKhatmahSurahProgress() async {
    final p = await prefs;
    return p.getInt('khatmah_surah') ?? 1;
  }

  Future<void> setKhatmahSurahProgress(int surahId) async {
    final p = await prefs;
    await p.setInt('khatmah_surah', surahId);
  }
}
