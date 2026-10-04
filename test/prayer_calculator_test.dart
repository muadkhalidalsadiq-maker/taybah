import 'package:flutter_test/flutter_test.dart';
import 'package:taybah/data/prayer_calculator.dart';

int _mins(String t) {
  final p = t.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

void _expectClose(Map<String, dynamic> actual, Map<String, String> expected) {
  expected.forEach((key, value) {
    final diff = (_mins(actual[key].toString()) - _mins(value)).abs();
    expect(diff <= 1, true,
        reason: '$key: got ${actual[key]} expected $value (±1 min)');
  });
}

void main() {
  // القيم المتوقعة مأخوذة من موقع الأوائل (al-awail.com) بتاريخ 2026-10-04، وضع ?s=2
  test('Tripoli matches Al-Awail on 2026-10-04', () {
    final t = PrayerCalculator.compute(DateTime(2026, 10, 4), 32.8872, 13.1913);
    _expectClose(t, {
      'Fajr': '05:39',
      'Sunrise': '07:02',
      'Dhuhr': '12:59',
      'Asr': '16:16',
      'Maghrib': '18:52',
      'Isha': '20:11',
    });
  });

  test('Zintan matches Al-Awail on 2026-10-04', () {
    final t = PrayerCalculator.compute(DateTime(2026, 10, 4), 31.9317, 12.2533);
    _expectClose(t, {
      'Fajr': '05:43',
      'Sunrise': '07:06',
      'Dhuhr': '13:03',
      'Asr': '16:20',
      'Maghrib': '18:56',
      'Isha': '20:15',
    });
  });

  test('Kufra matches Al-Awail on 2026-10-04', () {
    final t = PrayerCalculator.compute(DateTime(2026, 10, 4), 24.1833, 23.3);
    _expectClose(t, {
      'Fajr': '05:02',
      'Sunrise': '06:19',
      'Dhuhr': '12:19',
      'Asr': '15:38',
      'Maghrib': '18:15',
      'Isha': '19:28',
    });
  });

  test('Times are ordered through the year', () {
    for (var month = 1; month <= 12; month++) {
      final t = PrayerCalculator.compute(DateTime(2026, month, 15), 32.8872, 13.1913);
      final order = PrayerCalculator.prayerKeys.map((k) => _mins(t[k].toString())).toList();
      for (var i = 1; i < order.length; i++) {
        expect(order[i] > order[i - 1], true, reason: 'month $month index $i');
      }
    }
  });
}
