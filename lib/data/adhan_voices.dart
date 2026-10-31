import 'package:shared_preferences/shared_preferences.dart';

/// صوت أذان (مؤذن). كل صوت له ملف لكل صلاة في موارد أندرويد (res/raw)،
/// يبدأ بعبارة «حان الآن موعد أذان صلاة ...» ثم الأذان كاملاً،
/// وأذان الفجر فيه «الصلاة خير من النوم».
class AdhanVoice {
  final String id;
  final String name;
  final String subtitle;

  /// true = أذان كامل، false = تنبيه صوتي قصير فقط.
  final bool fullAdhan;

  const AdhanVoice({
    required this.id,
    required this.name,
    required this.subtitle,
    this.fullAdhan = true,
  });
}

class AdhanVoices {
  AdhanVoices._();

  static const String _prefKey = 'adhan_voice_id';
  static const String defaultId = 'afasy';

  /// اسم الصوت الخاص بالتنبيه القصير فقط (بدون أذان).
  static const String announceOnlyId = 'announce';

  static const List<AdhanVoice> all = [
    AdhanVoice(
      id: 'afasy',
      name: 'مشاري راشد العفاسي',
      subtitle: 'أذان خاشع بمقام هادئ',
    ),
    AdhanVoice(
      id: 'qatami',
      name: 'ناصر القطامي',
      subtitle: 'أذان قصير وواضح',
    ),
    AdhanVoice(
      id: 'kazabri',
      name: 'عمر القزابري',
      subtitle: 'أذان بالطريقة المغاربية',
    ),
    AdhanVoice(
      id: 'zahrani',
      name: 'الزهراني',
      subtitle: 'أذان بالطريقة الحجازية',
    ),
    AdhanVoice(
      id: announceOnlyId,
      name: 'التنبيه الصوتي فقط',
      subtitle: '«حان الآن موعد أذان الصلاة» بدون أذان',
      fullAdhan: false,
    ),
  ];

  /// مفاتيح الصلوات التي لها أذان.
  static const List<String> adhanPrayers = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  static AdhanVoice byId(String? id) {
    for (final v in all) {
      if (v.id == id) return v;
    }
    return all.first;
  }

  static Future<AdhanVoice> getSelected() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return byId(prefs.getString(_prefKey) ?? defaultId);
    } catch (_) {
      return all.first;
    }
  }

  static Future<void> setSelected(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, id);
  }

  /// اسم ملف المورد (بدون امتداد) في android/app/src/main/res/raw
  static String rawName(AdhanVoice voice, String prayerKey) {
    final p = prayerKey.toLowerCase();
    if (prayerKey == 'Sunrise' || !voice.fullAdhan) return 'announce_$p';
    return 'adhan_${voice.id}_$p';
  }
}
