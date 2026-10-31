import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taybah/core/theme.dart';
import 'package:taybah/data/adhan_voices.dart';
import 'package:taybah/data/prayer_calculator.dart';
import 'package:taybah/data/quran_audio.dart';

void main() {
  test('كل صوت أذان له ملف صوتي لكل صلاة في موارد أندرويد', () {
    for (final voice in AdhanVoices.all) {
      for (final p in [...AdhanVoices.adhanPrayers, 'Sunrise']) {
        final name = AdhanVoices.rawName(voice, p);
        final file = File('android/app/src/main/res/raw/$name.ogg');
        expect(file.existsSync(), isTrue, reason: 'missing $name.ogg');
      }
    }
  });

  test('أذان الفجر ملف مختلف عن باقي الصلوات', () {
    final afasy = AdhanVoices.byId('afasy');
    expect(AdhanVoices.rawName(afasy, 'Fajr'), 'adhan_afasy_fajr');
    expect(AdhanVoices.rawName(afasy, 'Asr'), 'adhan_afasy_asr');
    expect(
      AdhanVoices.rawName(AdhanVoices.byId(AdhanVoices.announceOnlyId), 'Asr'),
      'announce_asr',
    );
  });

  test('روابط القراء صحيحة ومعرفاتهم غير مكررة', () {
    final ids = QuranAudio.reciters.map((r) => r.id).toSet();
    expect(ids.length, QuranAudio.reciters.length);
    for (final r in QuranAudio.reciters) {
      expect(r.urlForSurah(1), endsWith('/001.mp3'));
      expect(r.urlForSurah(114), endsWith('/114.mp3'));
    }
    expect(QuranAudio.byRiwaya(QuranRiwaya.qaloon), isNotEmpty);
  });

  test('ألوان الوضع الليلي تتبدل', () {
    TaybahColors.isDark = false;
    final light = TaybahColors.background;
    TaybahColors.isDark = true;
    expect(TaybahColors.background, isNot(light));
    expect(TaybahColors.background, TaybahColors.darkBg);
    TaybahColors.isDark = false;
  });

  test('ترتيب مواقيت الصلاة منطقي (طرابلس)', () {
    final t = PrayerCalculator.compute(
      DateTime(2026, 10, 31),
      32.8872,
      13.1913,
      tzHours: 2.0,
    );
    int m(String k) {
      final p = t[k].toString().split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    expect(m('Fajr') < m('Sunrise'), isTrue);
    expect(m('Sunrise') < m('Dhuhr'), isTrue);
    expect(m('Dhuhr') < m('Asr'), isTrue);
    expect(m('Asr') < m('Maghrib'), isTrue);
    expect(m('Maghrib') < m('Isha'), isTrue);
  });
}
