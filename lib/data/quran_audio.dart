import 'package:shared_preferences/shared_preferences.dart';

/// قارئ للمصحف المرتل برواية قالون عن نافع.
class QuranReciter {
  final String id;
  final String name;

  /// رابط مجلد التلاوات؛ ملف كل سورة باسم ثلاثي الأرقام مثل 001.mp3
  final String server;

  const QuranReciter({
    required this.id,
    required this.name,
    required this.server,
  });

  String urlForSurah(int surahId) =>
      '$server${surahId.toString().padLeft(3, '0')}.mp3';
}

/// مصادر التلاوة الصوتية (mp3quran.net) — كلها مصاحف كاملة برواية قالون.
class QuranAudio {
  QuranAudio._();

  static const String defaultReciterId = 'dokali';
  static const String _prefKey = 'quran_reciter_id';

  static const List<QuranReciter> reciters = [
    QuranReciter(
      id: 'dokali',
      name: 'الدوكالي محمد العالم',
      server: 'https://server7.mp3quran.net/dokali/',
    ),
    QuranReciter(
      id: 'huthifi',
      name: 'علي بن عبدالرحمن الحذيفي',
      server: 'https://server9.mp3quran.net/huthifi_qalon/',
    ),
    QuranReciter(
      id: 'husary',
      name: 'محمود خليل الحصري',
      server: 'https://server13.mp3quran.net/husr/Rewayat-Qalon-A-n-Nafi/',
    ),
    QuranReciter(
      id: 'trablsi',
      name: 'أحمد الطرابلسي',
      server: 'https://server10.mp3quran.net/trablsi/',
    ),
    QuranReciter(
      id: 'tareq',
      name: 'طارق عبدالغني دعوب',
      server: 'https://server10.mp3quran.net/tareq/',
    ),
    QuranReciter(
      id: 'qeniwa',
      name: 'محمد الأمين قنيوة',
      server: 'https://server16.mp3quran.net/qeniwa/Rewayat-Qalon-A-n-Nafi/',
    ),
    QuranReciter(
      id: 'kshidan',
      name: 'إبراهيم كشيدان',
      server: 'https://server16.mp3quran.net/i_kshidan/Rewayat-Qalon-A-n-Nafi/',
    ),
  ];

  static QuranReciter reciterById(String? id) {
    for (final r in reciters) {
      if (r.id == id) return r;
    }
    return reciters.first;
  }

  static Future<QuranReciter> getSelectedReciter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return reciterById(prefs.getString(_prefKey) ?? defaultReciterId);
    } catch (_) {
      return reciters.first;
    }
  }

  static Future<void> setSelectedReciter(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, id);
  }
}
