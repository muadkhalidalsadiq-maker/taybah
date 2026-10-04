import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'asset_loader.dart';
import 'prayer_calculator.dart';
import 'shared_prefs_helper.dart';

class PrayerApi {
  static const String _baseUrl = 'https://www.al-awail.com/prayers/';

  /// Default city is Zintan as requested
  static const String defaultCitySlug =
      '1478488_ly_zintan-(%D8%B2%D9%86%D8%AA%D8%A7%D9%86).html';
  static const String defaultCityName = 'زنتان';

  /// Standard Iqama delay offsets in minutes (Sunnah / Libyan standard)
  static const Map<String, int> defaultIqamaOffsets = {
    'Fajr': 20,
    'Sunrise': 0,
    'Dhuhr': 15,
    'Asr': 15,
    'Maghrib': 10,
    'Isha': 15,
  };

  /// ليبيا تعمل بتوقيت ثابت UTC+2 (وضع «صيفي» في موقع الأوائل).
  static const double libyaUtcOffset = 2.0;

  /// مصدر آخر مواقيت تم إرجاعها: 'alawail' (من الموقع/المخزن) أو 'calc' (حساب داخلي).
  static String lastSource = 'calc';

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// رقم المدينة في موقع الأوائل (الجزء الأول من الرابط) — ثابت مهما كان ترميز الرابط.
  static String _cityId(String slug) {
    final i = slug.indexOf('_');
    return i > 0 ? slug.substring(0, i) : slug;
  }

  static Future<Map<String, dynamic>?> _findCityBySlug(String slug) async {
    try {
      final id = _cityId(slug);
      final cities = await AssetLoader.loadCitiesLibya();
      for (final c in cities) {
        if (_cityId((c['slug'] ?? '').toString()) == id) return c;
      }
    } catch (_) {}
    return null;
  }

  /// حساب المواقيت داخل التطبيق بدون إنترنت (معاير على موقع الأوائل).
  static Future<Map<String, dynamic>> calculateOffline({
    String slug = defaultCitySlug,
    DateTime? date,
    bool isSummer = true,
  }) async {
    final city = await _findCityBySlug(slug);
    final lat = (city?['lat'] as num?)?.toDouble() ?? 31.9317;
    final lng = (city?['lng'] as num?)?.toDouble() ?? 12.2533;
    final name = (city?['ar_name'] ?? '').toString();
    final usesSecondFajr = name.contains('فجر2');
    return PrayerCalculator.compute(
      date ?? DateTime.now(),
      lat,
      lng,
      tzHours: isSummer ? libyaUtcOffset : libyaUtcOffset - 1.0,
      fajrAngle: usesSecondFajr
          ? PrayerCalculator.secondFajrAngle
          : PrayerCalculator.defaultFajrAngle,
    );
  }

  static String _daysCacheKey(String slug, bool isSummer) =>
      'alawail_days_${_cityId(slug)}_s${isSummer ? '2' : '1'}';

  static Map<String, Map<String, dynamic>> _readDaysCache(
    SharedPreferences prefs,
    String key,
  ) {
    final out = <String, Map<String, dynamic>>{};
    final raw = prefs.getString(key);
    if (raw == null) return out;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        decoded.forEach((k, v) {
          if (v is Map) out[k.toString()] = Map<String, dynamic>.from(v);
        });
      }
    } catch (_) {}
    return out;
  }

  static int _toMinutes(dynamic timeStr) => _parseTimeToSeconds(timeStr) ~/ 60;

  /// يتأكد أن المواقيت المقروءة من الموقع منطقية بمقارنتها بالحساب الداخلي
  /// (يحمي من تغيّر تصميم الصفحة أو قراءة أرقام خاطئة).
  static bool _isPlausible(
    Map<String, dynamic> parsed,
    Map<String, dynamic> calc,
  ) {
    const required = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final key in required) {
      final p = parsed[key]?.toString() ?? '';
      final c = calc[key]?.toString() ?? '';
      if (!p.contains(':') || !c.contains(':')) return false;
      final diff = (_toMinutes(p) - _toMinutes(c)).abs();
      final limit = key == 'Fajr' ? 30 : 8;
      if (diff > limit) return false;
    }
    return true;
  }

  static String _pad(String timeStr) {
    final parts = timeStr.trim().split(':');
    if (parts.length < 2) return timeStr;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  /// يقرأ الجدول الأسبوعي من صفحة الأوائل: تاريخ ثم ستة أوقات.
  static Map<String, Map<String, dynamic>> _parseWeekRows(String html) {
    final out = <String, Map<String, dynamic>>{};
    const keys = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final dateRe = RegExp(r'(20\d{2})-(\d{2})-(\d{2})');
    final timeRe = RegExp(r'\b(\d{1,2}):(\d{2})\b');
    final matches = dateRe.allMatches(html).toList();
    for (var i = 0; i < matches.length; i++) {
      final start = matches[i].end;
      var end = i + 1 < matches.length ? matches[i + 1].start : html.length;
      if (end - start > 1500) end = start + 1500;
      if (end <= start) continue;
      final chunk = html.substring(start, end);
      final times = timeRe.allMatches(chunk).take(6).toList();
      if (times.length < 6) continue;
      final row = <String, dynamic>{};
      for (var k = 0; k < 6; k++) {
        row[keys[k]] = _pad('${times[k].group(1)}:${times[k].group(2)}');
      }
      out[matches[i].group(0)!] = row;
    }
    return out;
  }

  /// يجلب مواقيت اليوم + الأسبوع من موقع الأوائل ويخزنها حسب التاريخ.
  /// لا يرمي أي استثناء؛ عند الفشل يرجع المخزن كما هو.
  static Future<Map<String, Map<String, dynamic>>> _refreshFromAlAwail({
    required String slug,
    required String cityName,
    required bool isSummer,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _daysCacheKey(slug, isSummer);
    final days = _readDaysCache(prefs, cacheKey);
    try {
      final cleanSlug = slug.contains('?') ? slug.split('?')[0] : slug;
      final url = Uri.parse('$_baseUrl$cleanSlug?s=${isSummer ? '2' : '1'}');
      final response = await http.get(
        url,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return days;
      final html = utf8.decode(response.bodyBytes, allowMalformed: true);
      final now = DateTime.now();

      // 1) الجدول الأسبوعي
      final week = _parseWeekRows(html);
      for (final entry in week.entries) {
        final date = DateTime.tryParse(entry.key);
        if (date == null) continue;
        final calc = await calculateOffline(
          slug: slug,
          date: date,
          isSummer: isSummer,
        );
        if (_isPlausible(entry.value, calc)) days[entry.key] = entry.value;
      }

      // 2) مواقيت اليوم (القراءة الأدق من جدول اليوم)
      final todayParsed = _parseAlAwailHtml(html);
      if (todayParsed.isNotEmpty) {
        final calc = await calculateOffline(
          slug: slug,
          date: now,
          isSummer: isSummer,
        );
        if (_isPlausible(todayParsed, calc)) {
          final fixed = <String, dynamic>{};
          for (final key in PrayerCalculator.prayerKeys) {
            final v = todayParsed[key] ?? calc[key];
            if (v != null) fixed[key] = _pad(v.toString());
          }
          days[dateKey(now)] = fixed;
        }
      }

      // حذف الأيام القديمة من المخزن
      final yesterday = dateKey(now.subtract(const Duration(days: 1)));
      days.removeWhere((k, _) => k.compareTo(yesterday) < 0);
      await prefs.setString(cacheKey, json.encode(days));
    } catch (_) {
      // لا يوجد إنترنت أو انتهت المهلة: نكمل بالمخزن أو الحساب الداخلي
    }
    return days;
  }

  /// مواقيت اليوم: تعمل بدون إنترنت دائماً.
  /// الترتيب: المخزن من موقع الأوائل ← جلب من الموقع (إن وُجد نت) ← حساب داخلي معاير.
  static Future<Map<String, dynamic>> getPrayerTimesFromAlAwail({
    String slug = defaultCitySlug,
    String cityName = defaultCityName,
    bool isSummer = true,
  }) async {
    final now = DateTime.now();
    final todayKey = dateKey(now);
    final tomorrowKey = dateKey(now.add(const Duration(days: 1)));
    Map<String, dynamic>? result;

    try {
      final prefs = await SharedPreferences.getInstance();
      final days = _readDaysCache(prefs, _daysCacheKey(slug, isSummer));
      result = days[todayKey];

      if (result == null) {
        final fresh = await _refreshFromAlAwail(
          slug: slug,
          cityName: cityName,
          isSummer: isSummer,
        );
        result = fresh[todayKey];
      } else if (!days.containsKey(tomorrowKey)) {
        // المخزن ينتهي اليوم: نحدّثه في الخلفية بدون تعطيل الواجهة
        unawaited(_refreshFromAlAwail(
          slug: slug,
          cityName: cityName,
          isSummer: isSummer,
        ));
      }
    } catch (_) {}

    lastSource = result != null ? 'alawail' : 'calc';
    final Map<String, dynamic> finalTimings = result ??
        await calculateOffline(slug: slug, date: now, isSummer: isSummer);
    return await applyManualOffsets(finalTimings);
  }

  /// مواقيت أي يوم للمدينة المختارة (تستعمل لجدولة تنبيهات الأيام القادمة).
  static Future<Map<String, dynamic>> getTimingsForDate(DateTime date) async {
    final slug = await SharedPrefsHelper.instance.getSelectedCitySlug();
    final isSummer = await SharedPrefsHelper.instance.isSummerTime();
    Map<String, dynamic>? result;
    try {
      final prefs = await SharedPreferences.getInstance();
      final days = _readDaysCache(prefs, _daysCacheKey(slug, isSummer));
      result = days[dateKey(date)];
    } catch (_) {}
    final Map<String, dynamic> finalTimings = result ??
        await calculateOffline(slug: slug, date: date, isSummer: isSummer);
    return await applyManualOffsets(finalTimings);
  }

  /// للتوافق مع النسخ السابقة: مواقيت احتياطية محسوبة للمدينة الافتراضية.
  static Map<String, dynamic> getOfflineSummerFallbackTimes() =>
      PrayerCalculator.compute(DateTime.now(), 31.9317, 12.2533, tzHours: 2.0);

  static Map<String, dynamic> getOfflineFallbackTimes() =>
      PrayerCalculator.compute(DateTime.now(), 31.9317, 12.2533, tzHours: 1.0);

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

  /// Calculates Iqama time string for a prayer
  static String getIqamaTime(String prayerKey, String adhanTimeStr) {
    if (!adhanTimeStr.contains(':')) return adhanTimeStr;
    final offset = defaultIqamaOffsets[prayerKey] ?? 15;
    return addMinutesToTime(adhanTimeStr, offset);
  }

  /// Parses Al-Awail HTML table
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

  /// Finds nearest Libyan city by coordinates
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

  /// Auto detect GPS city on first launch
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

  /// Computes next prayer, Iqama time, and precise live countdowns
  static Map<String, dynamic> calculateNextPrayer(Map<String, dynamic> timings) {
    if (timings.isEmpty) {
      return {
        'name': 'جاري التحميل...',
        'key': 'Fajr',
        'time': '--:--',
        'time12': '--:--',
        'iqamaTime': '--:--',
        'iqamaTime12': '--:--',
        'remaining': '00:00:00',
        'iqamaRemaining': '00:00',
        'isBetweenAdhanAndIqama': false,
        'progress': 0.0,
      };
    }

    final now = DateTime.now();
    final currentSeconds = (now.hour * 3600) + (now.minute * 60) + now.second;

    final prayers = [
      {'key': 'Fajr', 'name': 'الفجر', 'iqamaDelay': 20},
      {'key': 'Sunrise', 'name': 'الشروق', 'iqamaDelay': 0},
      {'key': 'Dhuhr', 'name': 'الظهر', 'iqamaDelay': 15},
      {'key': 'Asr', 'name': 'العصر', 'iqamaDelay': 15},
      {'key': 'Maghrib', 'name': 'المغرب', 'iqamaDelay': 10},
      {'key': 'Isha', 'name': 'العشاء', 'iqamaDelay': 15},
    ];

    int? nextIndex;
    int nextPrayerSecs = 0;
    int prevPrayerSecs = 0;
    bool isBetweenAdhanAndIqama = false;
    int iqamaRemainingSecs = 0;

    for (int i = 0; i < prayers.length; i++) {
      final key = prayers[i]['key'] as String;
      final delay = prayers[i]['iqamaDelay'] as int;
      final timeStr = timings[key]?.toString() ?? '';

      if (timeStr.contains(':')) {
        final adhanSecs = _parseTimeToSeconds(timeStr);
        final iqamaSecs = adhanSecs + (delay * 60);

        // Check if currently between Adhan and Iqama
        if (key != 'Sunrise' && currentSeconds >= adhanSecs && currentSeconds < iqamaSecs) {
          nextIndex = i;
          nextPrayerSecs = adhanSecs;
          isBetweenAdhanAndIqama = true;
          iqamaRemainingSecs = iqamaSecs - currentSeconds;
          break;
        }

        if (adhanSecs > currentSeconds) {
          nextIndex = i;
          nextPrayerSecs = adhanSecs;
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
      nextPrayerSecs = (24 * 3600) + (fh * 60 + fm) * 60;
      prevPrayerSecs = _parseTimeToSeconds(timings['Isha']);
    }

    final selectedKey = prayers[nextIndex]['key'] as String;
    final delayMinutes = prayers[nextIndex]['iqamaDelay'] as int;
    final adhanRaw = timings[selectedKey]?.toString() ?? '00:00';
    final iqamaRaw = addMinutesToTime(adhanRaw, delayMinutes);

    final diffSeconds = (nextPrayerSecs - currentSeconds).clamp(0, 86400);
    final hours = diffSeconds ~/ 3600;
    final minutes = (diffSeconds % 3600) ~/ 60;
    final seconds = diffSeconds % 60;

    final remainingFormatted =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final iqMins = iqamaRemainingSecs ~/ 60;
    final iqSecs = iqamaRemainingSecs % 60;
    final iqamaRemainingFormatted = '${iqMins.toString().padLeft(2, '0')}:${iqSecs.toString().padLeft(2, '0')}';

    final totalWindow = (nextPrayerSecs - prevPrayerSecs).clamp(1, 86400);
    final elapsed = (currentSeconds - prevPrayerSecs).clamp(0, totalWindow);
    final progress = (elapsed / totalWindow).clamp(0.0, 1.0);

    return {
      'name': prayers[nextIndex]['name'],
      'key': selectedKey,
      'time': adhanRaw,
      'time12': formatTo12Hour(adhanRaw),
      'iqamaTime': iqamaRaw,
      'iqamaTime12': formatTo12Hour(iqamaRaw),
      'iqamaDelayMinutes': delayMinutes,
      'remaining': remainingFormatted,
      'iqamaRemaining': iqamaRemainingFormatted,
      'isBetweenAdhanAndIqama': isBetweenAdhanAndIqama,
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
    return (h * 3600) + (m * 60);
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

      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) return lastKnown;
      } catch (_) {}

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
