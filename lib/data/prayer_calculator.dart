import 'dart:math' as math;

/// محرك حساب مواقيت الصلاة بدون إنترنت.
///
/// معاير على مواقيت موقع «الأوائل» (al-awail.com) لمدن ليبيا:
/// زاوية الفجر 18.5° وزاوية العشاء 18.5° مع فروق التمكين المستعملة في الموقع
/// (الظهر +4 د تقريباً، المغرب +4 د تقريباً). تمت المطابقة على 5 مدن
/// (طرابلس، الزنتان، بنغازي، سبها، الكفرة) والفرق لا يتجاوز دقيقة واحدة.
class PrayerCalculator {
  PrayerCalculator._();

  /// زاوية الفجر والعشاء المعتمدة.
  static const double defaultFajrAngle = 18.5;
  static const double defaultIshaAngle = 18.5;

  /// زاوية الفجر للمدن المعلّمة «فجر2» في موقع الأوائل (مثل سبها_فجر2).
  static const double secondFajrAngle = 14.7;

  /// انخفاض الشمس عند الشروق والغروب (انكسار + نصف قطر الشمس).
  static const double horizonAngle = 0.833;

  /// فروق المعايرة بالدقائق (تضاف قبل حذف الكسور) لمطابقة موقع الأوائل.
  static const Map<String, double> calibration = {
    'Fajr': 0.5,
    'Sunrise': -0.25,
    'Dhuhr': 3.8,
    'Asr': 0.0,
    'Maghrib': 4.25,
    'Isha': -0.4,
  };

  static const List<String> prayerKeys = [
    'Fajr',
    'Sunrise',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  static double _rad(double deg) => deg * math.pi / 180.0;
  static double _deg(double rad) => rad * 180.0 / math.pi;

  static double _fixAngle(double a) {
    final r = a % 360.0;
    return r < 0 ? r + 360.0 : r;
  }

  static double _fixHour(double h) {
    final r = h % 24.0;
    return r < 0 ? r + 24.0 : r;
  }

  /// اليوم اليولياني عند الساعة 0 بالتوقيت العالمي.
  static double _julian(int year, int month, int day) {
    var y = year;
    var m = month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        day +
        b -
        1524.5;
  }

  /// يرجع [ميل الشمس بالراديان، معادلة الزمن بالساعات].
  static List<double> _sun(double jd) {
    final d = jd - 2451545.0;
    final g = _rad(_fixAngle(357.529 + 0.98560028 * d));
    final q = _fixAngle(280.459 + 0.98564736 * d);
    final l = _rad(
      _fixAngle(q + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g)),
    );
    final e = _rad(23.439 - 0.00000036 * d);
    final ra = _fixHour(
      _deg(math.atan2(math.cos(e) * math.sin(l), math.cos(l))) / 15.0,
    );
    final decl = math.asin(math.sin(e) * math.sin(l));
    var eqt = q / 15.0 - ra;
    eqt = _fixHour(eqt + 12.0) - 12.0;
    return [decl, eqt];
  }

  /// يحسب المواقيت كساعات عشرية بالتوقيت المحلي (قبل التقريب).
  static Map<String, double> computeRaw(
    DateTime date,
    double lat,
    double lng, {
    double tzHours = 2.0,
    double fajrAngle = defaultFajrAngle,
    double ishaAngle = defaultIshaAngle,
  }) {
    final j = _julian(date.year, date.month, date.day) - lng / 360.0;
    final la = _rad(lat);

    double noon(double t) => 12.0 - _sun(j + t / 24.0)[1] - lng / 15.0 + tzHours;

    // وقت بلوغ الشمس ارتفاع (-angle) قبل الزوال (dir = -1) أو بعده (dir = +1)
    double atAngle(double angle, double t, double dir) {
      final decl = _sun(j + t / 24.0)[0];
      var c = (-math.sin(_rad(angle)) - math.sin(la) * math.sin(decl)) /
          (math.cos(la) * math.cos(decl));
      if (c > 1.0) c = 1.0;
      if (c < -1.0) c = -1.0;
      return noon(t) + dir * _deg(math.acos(c)) / 15.0;
    }

    // العصر: ظل الشيء مثله (مذهب الجمهور)
    double asr(double t) {
      final decl = _sun(j + t / 24.0)[0];
      final a = -_deg(math.atan(1.0 / (1.0 + math.tan((la - decl).abs()))));
      return atAngle(a, t, 1.0);
    }

    double solve(double Function(double) f, double guess) {
      var t = guess;
      for (var i = 0; i < 3; i++) {
        t = f(t - tzHours + lng / 15.0);
      }
      return t;
    }

    return {
      'Fajr': solve((t) => atAngle(fajrAngle, t, -1.0), 5.0),
      'Sunrise': solve((t) => atAngle(horizonAngle, t, -1.0), 6.0),
      'Dhuhr': solve(noon, 12.0),
      'Asr': solve(asr, 15.0),
      'Maghrib': solve((t) => atAngle(horizonAngle, t, 1.0), 18.0),
      'Isha': solve((t) => atAngle(ishaAngle, t, 1.0), 19.0),
    };
  }

  /// يحسب المواقيت بصيغة "HH:mm" مطابقة لموقع الأوائل.
  static Map<String, dynamic> compute(
    DateTime date,
    double lat,
    double lng, {
    double tzHours = 2.0,
    double fajrAngle = defaultFajrAngle,
  }) {
    final raw = computeRaw(
      date,
      lat,
      lng,
      tzHours: tzHours,
      fajrAngle: fajrAngle,
    );
    final out = <String, dynamic>{};
    for (final key in prayerKeys) {
      final value = raw[key];
      if (value == null || value.isNaN) continue;
      final mins = (value * 60.0 + (calibration[key] ?? 0.0)).floor();
      final norm = ((mins % 1440) + 1440) % 1440;
      final h = (norm ~/ 60).toString().padLeft(2, '0');
      final m = (norm % 60).toString().padLeft(2, '0');
      out[key] = '$h:$m';
    }
    return out;
  }
}
