import 'package:shared_preferences/shared_preferences.dart';

enum QuranRiwaya { qaloon, hafs }

extension QuranRiwayaLabel on QuranRiwaya {
  String get label => this == QuranRiwaya.qaloon ? 'رواية قالون عن نافع' : 'رواية حفص عن عاصم';
}

/// قارئ لمصحف مرتل كامل (114 سورة).
class QuranReciter {
  final String id;
  final String name;
  final QuranRiwaya riwaya;

  /// رابط مجلد التلاوات؛ ملف كل سورة باسم ثلاثي الأرقام مثل 001.mp3
  final String server;

  const QuranReciter({
    required this.id,
    required this.name,
    required this.riwaya,
    required this.server,
  });

  String urlForSurah(int surahId) =>
      '$server${surahId.toString().padLeft(3, '0')}.mp3';
}

/// مصادر التلاوة الصوتية (mp3quran.net). المصحف المكتوب في التطبيق برواية قالون،
/// لذلك قراء قالون أولاً، ثم قراء حفص المشهورين.
class QuranAudio {
  QuranAudio._();

  static const String _cdn = 'https://cdn.mp3quran.net/audio';
  static const String defaultReciterId = 'dokali';
  static const String _prefKey = 'quran_reciter_id';

  static const List<QuranReciter> reciters = [
    QuranReciter(
      id: 'dokali',
      name: 'الدوكالي محمد العالم',
      riwaya: QuranRiwaya.qaloon,
      server: '$_cdn/dokali-alim/r1/',
    ),
    QuranReciter(
      id: 'huthifi',
      name: 'علي بن عبدالرحمن الحذيفي',
      riwaya: QuranRiwaya.qaloon,
      server: '$_cdn/ali-hudhaifi/r2/',
    ),
    QuranReciter(
      id: 'husary',
      name: 'محمود خليل الحصري',
      riwaya: QuranRiwaya.qaloon,
      server: '$_cdn/mahmoud-husary/r5/',
    ),
    QuranReciter(
      id: 'trablsi',
      name: 'أحمد الطرابلسي',
      riwaya: QuranRiwaya.qaloon,
      server: '$_cdn/ahmad-tarabulsi/r1/',
    ),
    QuranReciter(
      id: 'tareq',
      name: 'طارق عبدالغني دعوب',
      riwaya: QuranRiwaya.qaloon,
      server: '$_cdn/tareq-daawob/r1/',
    ),
    QuranReciter(
      id: 'qeniwa',
      name: 'محمد الأمين قنيوة',
      riwaya: QuranRiwaya.qaloon,
      server: '$_cdn/muhammad-qeniwa/r1/',
    ),
    QuranReciter(
      id: 'kshidan',
      name: 'إبراهيم كشيدان',
      riwaya: QuranRiwaya.qaloon,
      server: '$_cdn/ibrahim-kshidan/r1/',
    ),
    QuranReciter(
      id: 'akri',
      name: 'مروان العكري',
      riwaya: QuranRiwaya.qaloon,
      server: '$_cdn/marwan-akri/r1/',
    ),
    QuranReciter(
      id: 'abusnaina',
      name: 'محمد أبو سنينة',
      riwaya: QuranRiwaya.qaloon,
      server: '$_cdn/muhammad-abusnaina/r1/',
    ),
    QuranReciter(
      id: 'deeban',
      name: 'أحمد ديبان',
      riwaya: QuranRiwaya.qaloon,
      server: '$_cdn/ahmad-deeban/r5/',
    ),
    QuranReciter(
      id: 'naehi',
      name: 'وليد النائحي',
      riwaya: QuranRiwaya.qaloon,
      server: '$_cdn/waleed-naehi/r1/',
    ),
    QuranReciter(
      id: 'afasy',
      name: 'مشاري راشد العفاسي',
      riwaya: QuranRiwaya.hafs,
      server: '$_cdn/mishary-alafasy/r1/',
    ),
    QuranReciter(
      id: 'minshawi',
      name: 'محمد صديق المنشاوي',
      riwaya: QuranRiwaya.hafs,
      server: '$_cdn/muhammad-minshawi/r1/',
    ),
    QuranReciter(
      id: 'abdulbasit',
      name: 'عبدالباسط عبدالصمد',
      riwaya: QuranRiwaya.hafs,
      server: '$_cdn/abdulbasit-abdulsamad/r3/',
    ),
    QuranReciter(
      id: 'husary_hafs',
      name: 'محمود خليل الحصري',
      riwaya: QuranRiwaya.hafs,
      server: '$_cdn/mahmoud-husary/r1/',
    ),
    QuranReciter(
      id: 'sudais',
      name: 'عبدالرحمن السديس',
      riwaya: QuranRiwaya.hafs,
      server: '$_cdn/abdulrahman-sudais/r1/',
    ),
    QuranReciter(
      id: 'maher',
      name: 'ماهر المعيقلي',
      riwaya: QuranRiwaya.hafs,
      server: '$_cdn/maher-muaiqly/r1/',
    ),
    QuranReciter(
      id: 'ghamdi',
      name: 'سعد الغامدي',
      riwaya: QuranRiwaya.hafs,
      server: '$_cdn/saad-ghamdi/r1/',
    ),
    QuranReciter(
      id: 'dosari',
      name: 'ياسر الدوسري',
      riwaya: QuranRiwaya.hafs,
      server: '$_cdn/yasser-dosari/r1/',
    ),
    QuranReciter(
      id: 'qatami',
      name: 'ناصر القطامي',
      riwaya: QuranRiwaya.hafs,
      server: '$_cdn/nasser-qatami/r1/',
    ),
    QuranReciter(
      id: 'abbad',
      name: 'فارس عباد',
      riwaya: QuranRiwaya.hafs,
      server: '$_cdn/fares-abbad/r1/',
    ),
    QuranReciter(
      id: 'abkar',
      name: 'إدريس أبكر',
      riwaya: QuranRiwaya.hafs,
      server: '$_cdn/idrees-abkar/r1/',
    ),
  ];

  static List<QuranReciter> byRiwaya(QuranRiwaya r) =>
      reciters.where((e) => e.riwaya == r).toList();

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
