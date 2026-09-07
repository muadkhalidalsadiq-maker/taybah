import 'package:flutter_test/flutter_test.dart';
import 'package:taybah/data/asset_loader.dart';
import 'package:taybah/data/prayer_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Quran Qaloon dataset contains 114 surahs', () async {
    final surahs = await AssetLoader.loadQuranSurahs();
    expect(surahs.length, 114);
    expect(surahs.first['name'], 'الفَاتِحة');
    expect(surahs.last['name'], 'النَّاس');
  });

  test('Libyan cities list contains Zintan and other cities', () async {
    final cities = await AssetLoader.loadCitiesLibya();
    expect(cities.isNotEmpty, true);
    final zintan = cities.firstWhere((c) => c['ar_name'].toString().contains('زنتان'));
    expect(zintan, isNotNull);
    expect(zintan['slug'], contains('zintan'));
  });

  test('Next prayer calculation works correctly', () {
    final timings = {
      'Fajr': '04:25',
      'Sunrise': '05:50',
      'Dhuhr': '12:13',
      'Asr': '15:42',
      'Maghrib': '18:32',
      'Isha': '19:53',
    };
    final next = PrayerApi.calculateNextPrayer(timings);
    expect(next['name'], isNotNull);
    expect(next['time'], isNotNull);
    expect(next['remaining'], isNotNull);
  });
}
