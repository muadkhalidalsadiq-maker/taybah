import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'asset_loader.dart';
import 'shared_prefs_helper.dart';

class PrayerApi {
  static const String _baseUrl = 'https://www.al-awail.com/prayers/';

  /// Default city is Zintan as requested
  static const String defaultCitySlug =
      '1478488_ly_zintan-(%D8%B2%D9%86%D8%AA%D8%A7%D9%86).html';
  static const String defaultCityName = 'زنتان';

  /// Fetches prayer times from Al-Awail website using Summer time (?s=2) by default
  static Future<Map<String, dynamic>> getPrayerTimesFromAlAwail({
    String slug = defaultCitySlug,
    String cityName = defaultCityName,
    bool isSummer = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final summerParam = isSummer ? '2' : '1';
    final cacheKey = 'alawail_prayer_${slug}_s$summerParam';

    try {
      final cleanSlug = slug.contains('?') ? slug.split('?')[0] : slug;
      final url = Uri.parse('$_baseUrl$cleanSlug?s=$summerParam');
      final response = await http.get(
        url,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final html = utf8.decode(response.bodyBytes, allowMalformed: true);
        final timings = _parseAlAwailHtml(html);

        if (timings.isNotEmpty) {
          final toCache = {
            'timings': timings,
            'cityName': cityName,
            'slug': cleanSlug,
            'isSummer': isSummer,
            'date': DateTime.now().toIso8601String(),
          };
          await prefs.setString(cacheKey, json.encode(toCache));
          return await applyManualOffsets(timings);
        }
      }
    } catch (e) {
      // Network error or timeout: fall back to cache
    }

    // Cache fallback
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      try {
        final decoded = json.decode(cached);
        if (decoded['timings'] != null) {
          final t = Map<String, dynamic>.from(decoded['timings']);
          return await applyManualOffsets(t);
        }
      } catch (_) {}
    }

    // Offline summer fallback times for Libya (+1 hour offset for summer)
    final fallback = isSummer
        ? getOfflineSummerFallbackTimes()
        : getOfflineFallbackTimes();
    return await applyManualOffsets(fallback);
  }

  /// Applies user manual minute adjustments (+/- minutes)
  static Future<Map<String, dynamic>> applyManualOffsets(
    Map<String, dynamic> raw,
  ) async {
    final offsets = await SharedPrefsHelper.instance.getAllPrayerOffsets();
    final adjusted = Map<String, dynamic>.from(raw);
    for (final e in offsets.entries) {
      if (e.value != 0 && adjusted[e.key] != null) {
        adjusted[e.key] = addMinutesToTime(adjusted[e.key].toString(), e.value);
      }
    }
    return adjusted;
  }

  /// Adds or subtracts minutes from a "HH:mm" time string
  static String addMinutesToTime(String timeStr, int minutesToAdd) {
    if (!timeStr.contains(':')) return timeStr;
    final parts = timeStr.split(':');
    int h = int.tryParse(parts[0]) ?? 0;
    int m = int.tryParse(parts[1]) ?? 0;
    int total = h * 60 + m + minutesToAdd;
    total = (total % 1440 + 1440) % 1440;
    final newH = (total ~/ 60).toString().padLeft(2, '0');
    final newM = (total % 60).toString().padLeft(2, '0');
    return '$newH:$newM';
  }

  /// Parses Al-Awail HTML table for the 6 prayer times
  static Map<String, dynamic> _parseAlAwailHtml(String html) {
    final Map<String, dynamic> timings = {};
    final prayerKeys = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    for (int i = 0; i < prayerKeys.length; i++) {
      final key = prayerKeys[i];
      final regExp = RegExp(
        "id=['\"]prayer_$i['\"][^>]*>.*?<td>(\\d{1,2}:\\d{2})<\\/td>",
        dotAll: true,
      );
      final match = regExp.firstMatch(html);
      if (match != null && match.groupCount >= 1) {
        timings[key] = match.group(1)!.trim();
      }
    }

    if (timings.length < 5) {
      final metaRegex = RegExp(r"""name=['"][Dd]escription['"]\s+content=['"](.*?)['"]""");
      final metaMatch = metaRegex.firstMatch(html);
      if (metaMatch != null) {
        final content = metaMatch.group(1) ?? '';
        final pFajr = RegExp(r'الفجر:\s*(\d{1,2}:\d{2})').firstMatch(content);
        final pDhuhr = RegExp(r'الظهر:\s*(\d{1,2}:\d{2})').firstMatch(content);
        final pAsr = RegExp(r'العصر:\s*(\d{1,2}:\d{2})').firstMatch(content);
        final pMaghrib = RegExp(r'المغرب:\s*(\d{1,2}:\d{2})').firstMatch(content);
        final pIsha = RegExp(r'العشاء:\s*(\d{1,2}:\d{2})').firstMatch(content);

        if (pFajr != null) timings['Fajr'] = pFajr.group(1);
        if (pDhuhr != null) timings['Dhuhr'] = pDhuhr.group(1);
        if (pAsr != null) timings['Asr'] = pAsr.group(1);
        if (pMaghrib != null) timings['Maghrib'] = pMaghrib.group(1);
        if (pIsha != null) timings['Isha'] = pIsha.group(1);
      }
    }

    return timings;
  }

  /// Finds the nearest Libyan city in Al-Awail dataset based on user GPS coordinates
  static Future<Map<String, dynamic>> findNearestCity(
    double userLat,
    double userLng,
  ) async {
    final cities = await AssetLoader.loadCitiesLibya();
    if (cities.isEmpty) {
      return {
        'ar_name': defaultCityName,
        'slug': defaultCitySlug,
      };
    }

    Map<String, dynamic> nearest = cities.first;
    double minDistance = double.infinity;

    for (var city in cities) {
      final cLat = (city['lat'] as num?)?.toDouble() ?? 32.8872;
      final cLng = (city['lng'] as num?)?.toDouble() ?? 13.1913;

      // Euclidean distance in degrees (sufficiently accurate for city matching in Libya)
      final dist = math.sqrt(
        math.pow(userLat - cLat, 2) + math.pow(userLng - cLng, 2),
      );

      if (dist < minDistance) {
        minDistance = dist;
        nearest = city;
      }
    }

    return nearest;
  }

  /// Automatically requests GPS location and sets the nearest Libyan city on first launch
  static Future<Map<String, dynamic>?> autoDetectAndSetNearestCity() async {
    final position = await getCurrentPosition();
    if (position != null) {
      final nearest = await findNearestCity(
        position.latitude,
        position.longitude,
      );
      final cityName = nearest['ar_name'] ?? defaultCityName;
      final citySlug = nearest['slug'] ?? defaultCitySlug;

      await SharedPrefsHelper.instance.setSelectedCity(cityName, citySlug);
      return nearest;
    }
    return null;
  }

  /// Summer time fallback (+1 hour)
  static Map<String, dynamic> getOfflineSummerFallbackTimes() {
    return {
      'Fajr': '05:25',
      'Sunrise': '06:50',
      'Dhuhr': '13:13',
      'Asr': '16:42',
      'Maghrib': '19:32',
      'Isha': '20:53',
    };
  }

  /// Winter time fallback
  static Map<String, dynamic> getOfflineFallbackTimes() {
    return {
      'Fajr': '04:25',
      'Sunrise': '05:50',
      'Dhuhr': '12:13',
      'Asr': '15:42',
      'Maghrib': '18:32',
      'Isha': '19:53',
    };
  }

  /// Computes next prayer information and time left
  static Map<String, dynamic> calculateNextPrayer(Map<String, dynamic> timings) {
    if (timings.isEmpty) {
      return {
        'name': 'جاري التحميل...',
        'time': '--:--',
        'remaining': '00:00:00',
        'progress': 0.0,
      };
    }

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final currentSeconds = currentMinutes * 60 + now.second;

    final prayers = [
      {'key': 'Fajr', 'name': 'الفجر'},
      {'key': 'Sunrise', 'name': 'الشروق'},
      {'key': 'Dhuhr', 'name': 'الظهر'},
      {'key': 'Asr', 'name': 'العصر'},
      {'key': 'Maghrib', 'name': 'المغرب'},
      {'key': 'Isha', 'name': 'العشاء'},
    ];

    int? nextIndex;
    int nextPrayerSecs = 0;
    int prevPrayerSecs = 0;

    for (int i = 0; i < prayers.length; i++) {
      final key = prayers[i]['key'] as String;
      final timeStr = timings[key]?.toString() ?? '';
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final prayerSecs = (h * 60 + m) * 60;

        if (prayerSecs > currentSeconds) {
          nextIndex = i;
          nextPrayerSecs = prayerSecs;
          prevPrayerSecs = i > 0
              ? _parseTimeToSeconds(timings[prayers[i - 1]['key']])
              : 0;
          break;
        }
      }
    }

    if (nextIndex == null) {
      nextIndex = 0;
      final fajrParts = (timings['Fajr'] ?? '05:25').toString().split(':');
      final fh = int.tryParse(fajrParts[0]) ?? 5;
      final fm = int.tryParse(fajrParts[1]) ?? 25;
      nextPrayerSecs = (24 * 60 * 60) + (fh * 60 + fm) * 60;
      prevPrayerSecs = _parseTimeToSeconds(timings['Isha']);
    }

    final diffSeconds = nextPrayerSecs - currentSeconds;
    final hours = diffSeconds ~/ 3600;
    final minutes = (diffSeconds % 3600) ~/ 60;
    final seconds = diffSeconds % 60;

    final remainingFormatted =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final totalWindow = (nextPrayerSecs - prevPrayerSecs).clamp(1, 86400);
    final elapsed = (currentSeconds - prevPrayerSecs).clamp(0, totalWindow);
    final progress = (elapsed / totalWindow).clamp(0.0, 1.0);

    final rawTime = timings[prayers[nextIndex]['key']] ?? '';
    return {
      'name': prayers[nextIndex]['name'],
      'time': rawTime,
      'time12': formatTo12Hour(rawTime),
      'remaining': remainingFormatted,
      'progress': progress,
    };
  }

  /// Formats 24-hour time "13:15" into 12-hour time "01:15 م" or "05:30 ص"
  static String formatTo12Hour(dynamic timeStr, {bool showPeriod = true}) {
    if (timeStr == null) return '--:--';
    final s = timeStr.toString().trim();
    if (!s.contains(':')) return s;
    final parts = s.split(':');
    int h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';

    final period = h >= 12 ? 'م' : 'ص';
    h = h % 12;
    if (h == 0) h = 12;

    final hStr = h.toString().padLeft(2, '0');
    return showPeriod ? '$hStr:$m $period' : '$hStr:$m';
  }

  static int _parseTimeToSeconds(dynamic timeStr) {
    if (timeStr == null) return 0;
    final parts = timeStr.toString().split(':');
    if (parts.length < 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return (h * 60 + m) * 60;
  }

  static double calculateQiblaAngle(double latitude, double longitude) {
    const kaabaLat = 21.422487 * math.pi / 180.0;
    const kaabaLng = 39.826206 * math.pi / 180.0;

    final userLat = latitude * math.pi / 180.0;
    final userLng = longitude * math.pi / 180.0;

    final dLng = kaabaLng - userLng;

    final y = math.sin(dLng);
    final x = math.cos(userLat) * math.tan(kaabaLat) -
        math.sin(userLat) * math.cos(dLng);

    var qiblaDegrees = math.atan2(y, x) * 180.0 / math.pi;
    qiblaDegrees = (qiblaDegrees + 360.0) % 360.0;
    return qiblaDegrees;
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
