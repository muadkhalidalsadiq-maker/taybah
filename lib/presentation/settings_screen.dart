import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/notification_service.dart';
import '../data/prayer_api.dart';
import '../data/shared_prefs_helper.dart';
import '../main.dart';
import 'asma_allah_screen.dart';
import 'qibla_screen.dart';
import 'ruqyah_screen.dart';
import 'widgets/city_picker_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _cityName = PrayerApi.defaultCityName;
  bool _isSummer = true;
  bool _isNotificationsMaster = true;
  bool _isMorningReminder = true;
  bool _isEveningReminder = true;
  bool _isSleepReminder = true;
  double _quranFontSize = 26.0;
  bool _isGpsDetecting = false;
  int _hijriAdjustment = 0;
  String _adhanSound = 'default';

  Map<String, int> _offsets = {
    'Fajr': 0,
    'Sunrise': 0,
    'Dhuhr': 0,
    'Asr': 0,
    'Maghrib': 0,
    'Isha': 0,
  };

  final Map<String, bool> _prayerAlerts = {
    'Fajr': true,
    'Sunrise': false,
    'Dhuhr': true,
    'Asr': true,
    'Maghrib': true,
    'Isha': true,
  };

  final List<Map<String, String>> _prayerKeys = [
    {'key': 'Fajr', 'name': 'صلاة الفجر'},
    {'key': 'Sunrise', 'name': 'وقت الشروق'},
    {'key': 'Dhuhr', 'name': 'صلاة الظهر'},
    {'key': 'Asr', 'name': 'صلاة العصر'},
    {'key': 'Maghrib', 'name': 'صلاة المغرب'},
    {'key': 'Isha', 'name': 'صلاة العشاء'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    final name = await SharedPrefsHelper.instance.getSelectedCityName();
    final summer = await SharedPrefsHelper.instance.isSummerTime();
    final notif = await SharedPrefsHelper.instance.getNotificationsEnabled();
    final fSize = await SharedPrefsHelper.instance.getQuranFontSize();
    final offsets = await SharedPrefsHelper.instance.getAllPrayerOffsets();
    final morning =
        await SharedPrefsHelper.instance.isMorningAdhkarReminderEnabled();
    final evening =
        await SharedPrefsHelper.instance.isEveningAdhkarReminderEnabled();
    final sleep =
        await SharedPrefsHelper.instance.isSleepAdhkarReminderEnabled();

    for (final p in _prayerAlerts.keys) {
      _prayerAlerts[p] =
          await NotificationService.instance.isPrayerNotificationEnabled(p);
    }

    final hijri = await SharedPrefsHelper.instance.getHijriAdjustment();
    final adhan = await SharedPrefsHelper.instance.getAdhanSound();

    if (mounted) {
      setState(() {
        _cityName = name;
        _isSummer = summer;
        _isNotificationsMaster = notif;
        _quranFontSize = fSize;
        _offsets = offsets;
        _isMorningReminder = morning;
        _isEveningReminder = evening;
        _isSleepReminder = sleep;
        _hijriAdjustment = hijri;
        _adhanSound = adhan;
      });
    }
  }

  Future<void> _updateHijriAdjustment(int days) async {
    setState(() => _hijriAdjustment = days);
    await SharedPrefsHelper.instance.setHijriAdjustment(days);
    if (mounted) {
      context.read<AppState>().updateHijriAdjustment(days);
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _updateAdhanSound(String sound) async {
    setState(() => _adhanSound = sound);
    await SharedPrefsHelper.instance.setAdhanSound(sound);
    HapticFeedback.lightImpact();
  }

  Future<void> _openCityPicker() async {
    final selected = await CityPickerSheet.show(
      context,
      currentCityName: _cityName,
    );
    if (selected != null) {
      await _loadAllSettings();
    }
  }

  Future<void> _autoDetectGps() async {
    setState(() => _isGpsDetecting = true);
    final nearest = await PrayerApi.autoDetectAndSetNearestCity();
    setState(() => _isGpsDetecting = false);

    if (!mounted) return;

    if (nearest != null) {
      await _loadAllSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديد أقرب مدينة بالـ GPS بنجاح: $_cityName',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaybahColors.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر الوصول لنظام الـ GPS، يرجى تفعيل إذن الموقع.'),
        ),
      );
    }
  }

  Future<void> _toggleSummer(bool val) async {
    setState(() => _isSummer = val);
    await SharedPrefsHelper.instance.setSummerTime(val);
  }

  Future<void> _changeOffset(String key, int delta) async {
    final current = _offsets[key] ?? 0;
    final next = (current + delta).clamp(-30, 30);
    setState(() => _offsets[key] = next);
    await SharedPrefsHelper.instance.setPrayerOffset(key, next);
    HapticFeedback.lightImpact();
  }

  Future<void> _resetOffsets() async {
    for (final k in _offsets.keys) {
      await SharedPrefsHelper.instance.setPrayerOffset(k, 0);
    }
    setState(() {
      _offsets = {
        'Fajr': 0,
        'Sunrise': 0,
        'Dhuhr': 0,
        'Asr': 0,
        'Maghrib': 0,
        'Isha': 0,
      };
    });
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تمت استعادة تعديلات مواقيت الصلاة الافتراضية.'),
      ),
    );
  }

  Future<void> _togglePrayerAlert(String key, bool val) async {
    setState(() => _prayerAlerts[key] = val);
    await NotificationService.instance.togglePrayerNotification(key);
  }

  Future<void> _testAdhan() async {
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.sendAdhanTestNotification('الظهر');
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded,
                color: TaybahColors.gold),
            const SizedBox(width: 10),
            Text(
              'تنبيه الأذان يعمل بنجاح!',
              style:
                  GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تم إرسال إشعار أذان تجريبي الآن.',
              style: GoogleFonts.cairo(
                  fontSize: 14, color: TaybahColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'ستصلك تنبيهات الصلوات في موعد كل أذان بدقة بحسب مدينتك مع الصوت والاهتزاز.',
              style:
                  GoogleFonts.cairo(fontSize: 12, color: TaybahColors.textMuted),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تم التجربة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? TaybahColors.darkBg : TaybahColors.background,
      appBar: AppBar(
        title: Text(
          'الإعدادات',
          style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 50),
        children: [
          // ──── Appearance & Dark Mode Section ────
          _buildSectionHeader('المظهر والوضع الليلي', Icons.palette_rounded),
          Consumer<AppState>(
            builder: (context, appState, child) {
              final isDark = appState.isDark;
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? TaybahColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? TaybahColors.gold.withAlpha(40)
                                : TaybahColors.primaryTint,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: isDark ? TaybahColors.goldLight : TaybahColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDark ? 'الوضع الليلي الفاخر (مفعّل)' : 'الوضع النهاري المضيء',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                              ),
                            ),
                            Text(
                              isDark ? 'تصميم زمردي مريح للعين ليلاً' : 'ألوان هادئة ونقية ومشرقة',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: isDark,
                      activeThumbColor: TaybahColors.gold,
                      activeTrackColor: TaybahColors.primaryAccent,
                      onChanged: (_) => appState.toggleTheme(),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 22),

          // City & Location Section
          _buildSectionHeader('المدينة والموقع الجغرافي', Icons.location_on_rounded),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? TaybahColors.darkSurface
                  : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? TaybahColors.darkBorder
                    : TaybahColors.border,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المدينة المعتمدة الحالية',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: TaybahColors.textMuted,
                          ),
                        ),
                        Text(
                          'ليبيا - $_cityName',
                          style: GoogleFonts.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: TaybahColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _openCityPicker,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TaybahColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'تغيير المدينة',
                        style: GoogleFonts.cairo(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: TaybahColors.border),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isGpsDetecting ? null : _autoDetectGps,
                    icon: _isGpsDetecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: TaybahColors.primary,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded, size: 16),
                    label: Text(
                      _isGpsDetecting
                          ? 'جاري فحص الـ GPS...'
                          : 'تحديد المدينة الأقرب تلقائياً بالـ GPS',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: TaybahColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: TaybahColors.primaryLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Prayer Times & Timing Adjustments Section
          _buildSectionHeader('ضبط وتعديل مواقيت الصلاة', Icons.access_time_filled_rounded),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: TaybahColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summer time switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isSummer
                              ? Icons.wb_sunny_rounded
                              : Icons.ac_unit_rounded,
                          size: 20,
                          color: _isSummer
                              ? TaybahColors.gold
                              : const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSummer
                                  ? 'التوقيت الصيفي (الأوائل ?s=2)'
                                  : 'التوقيت الشتوي (الأوائل ?s=1)',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: TaybahColors.textPrimary,
                              ),
                            ),
                            Text(
                              _isSummer
                                  ? 'إضافة ساعة واحدة للمواقيت (المعتمد حالياً)'
                                  : 'التوقيت الشتوي الأصلي',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: TaybahColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _isSummer,
                      activeTrackColor: TaybahColors.primary,
                      onChanged: _toggleSummer,
                    ),
                  ],
                ),

                const Divider(height: 24, color: TaybahColors.border),

                // Manual minutes offset
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تعديل يدوي بالدقائق (+/- دقيقة)',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: TaybahColors.primaryDark,
                      ),
                    ),
                    TextButton(
                      onPressed: _resetOffsets,
                      child: Text(
                        'استعادة 0 دقيقة',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: TaybahColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                ..._prayerKeys.map((p) {
                  final key = p['key']!;
                  final name = p['name']!;
                  final offset = _offsets[key] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: TaybahColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded,
                                  size: 20),
                              color: TaybahColors.primary,
                              onPressed: () => _changeOffset(key, -1),
                            ),
                            Container(
                              width: 60,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: offset == 0
                                    ? TaybahColors.surfaceMuted
                                    : TaybahColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                offset == 0
                                    ? '0 د'
                                    : offset > 0
                                        ? '+$offset د'
                                        : '$offset د',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: offset == 0
                                      ? TaybahColors.textMuted
                                      : TaybahColors.primaryDark,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded,
                                  size: 20),
                              color: TaybahColors.primary,
                              onPressed: () => _changeOffset(key, 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ──── Hijri Calendar Adjustment Section ────
          _buildSectionHeader('التقويم الهجري وتعديل الأيام', Icons.calendar_month_rounded),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? TaybahColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تعديل التاريخ الهجري',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                          ),
                        ),
                        Text(
                          'لمطابقة رؤية الهلال الرسمية في ليبيا',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.goldSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TaybahColors.gold.withAlpha(100)),
                      ),
                      child: Text(
                        _hijriAdjustment == 0
                            ? 'بدون تعديل'
                            : (_hijriAdjustment > 0 ? '+$_hijriAdjustment يوم' : '$_hijriAdjustment يوم'),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: TaybahColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [-2, -1, 0, 1, 2].map((adj) {
                    final isSelected = _hijriAdjustment == adj;
                    return ChoiceChip(
                      label: Text(
                        adj == 0 ? '0' : (adj > 0 ? '+$adj' : '$adj'),
                        style: GoogleFonts.cairo(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: TaybahColors.primaryAccent,
                      backgroundColor: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.surfaceMuted,
                      onSelected: (_) => _updateHijriAdjustment(adj),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Adhan & Notifications Section
          _buildSectionHeader('الأذان والتنبيهات الإيمانية', Icons.notifications_active_rounded),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? TaybahColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
              ),
            ),
            child: Column(
              children: [
                // Master Notification Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_rounded,
                            color: TaybahColors.gold, size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تفعيل تنبيهات الأذان',
                              style: GoogleFonts.cairo(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                              ),
                            ),
                            Text(
                              'إشعار حي عند دخول وقت الصلاة',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _isNotificationsMaster,
                      activeThumbColor: TaybahColors.gold,
                      activeTrackColor: TaybahColors.primaryAccent,
                      onChanged: (val) async {
                        setState(() => _isNotificationsMaster = val);
                        await SharedPrefsHelper.instance
                            .setNotificationsEnabled(val);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Adhan Sound Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'صوت الأذان المفضل',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                      ),
                    ),
                    DropdownButton<String>(
                      value: _adhanSound,
                      dropdownColor: isDark ? TaybahColors.darkSurface : Colors.white,
                      underline: const SizedBox(),
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: TaybahColors.gold,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'default', child: Text('الأذان الافتراضي')),
                        DropdownMenuItem(value: 'makkah', child: Text('أذان الحرم المكي')),
                        DropdownMenuItem(value: 'madinah', child: Text('أذان الحرم المدني')),
                        DropdownMenuItem(value: 'aqsa', child: Text('أذان المسجد الأقصى')),
                      ],
                      onChanged: (val) {
                        if (val != null) _updateAdhanSound(val);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Instant Adhan Test Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _testAdhan,
                    icon: const Icon(Icons.volume_up_rounded, size: 16),
                    label: const Text('تجربة تنبيه الأذان الآن'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TaybahColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                  ),
                ),

                const Divider(height: 24, color: TaybahColors.border),

                // Per-prayer toggles
                Text(
                  'تنبيهات الصلوات المنفردة:',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: TaybahColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),

                ..._prayerKeys.map((p) {
                  final key = p['key']!;
                  final name = p['name']!;
                  final enabled = _prayerAlerts[key] ?? true;

                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      name,
                      style: GoogleFonts.cairo(fontSize: 13),
                    ),
                    value: enabled,
                    activeTrackColor: TaybahColors.primary,
                    onChanged: (val) => _togglePrayerAlert(key, val),
                  );
                }),

                const Divider(height: 20, color: TaybahColors.border),

                // Adhkar reminders
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    'تذكير أذكار الصباح (عند الإشراق)',
                    style: GoogleFonts.cairo(fontSize: 13),
                  ),
                  value: _isMorningReminder,
                  activeTrackColor: TaybahColors.primary,
                  onChanged: (val) async {
                    setState(() => _isMorningReminder = val);
                    await SharedPrefsHelper.instance
                        .setMorningAdhkarReminderEnabled(val);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    'تذكير أذكار المساء (بعد العصر)',
                    style: GoogleFonts.cairo(fontSize: 13),
                  ),
                  value: _isEveningReminder,
                  activeTrackColor: TaybahColors.primary,
                  onChanged: (val) async {
                    setState(() => _isEveningReminder = val);
                    await SharedPrefsHelper.instance
                        .setEveningAdhkarReminderEnabled(val);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    'تذكير أذكار النوم وسورة الملك',
                    style: GoogleFonts.cairo(fontSize: 13),
                  ),
                  value: _isSleepReminder,
                  activeTrackColor: TaybahColors.primary,
                  onChanged: (val) async {
                    setState(() => _isSleepReminder = val);
                    await SharedPrefsHelper.instance
                        .setSleepAdhkarReminderEnabled(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Quran Reading & Font Size Settings Section
          _buildSectionHeader('قراءة وتلاوة القرآن الكريم', Icons.menu_book_rounded),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: TaybahColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'حجم خط المصحف الشريف',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: TaybahColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${_quranFontSize.toInt()} نقطة',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: TaybahColors.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _quranFontSize,
                  min: 20.0,
                  max: 36.0,
                  divisions: 8,
                  activeColor: TaybahColors.primary,
                  onChanged: (val) {
                    setState(() => _quranFontSize = val);
                    SharedPrefsHelper.instance.setQuranFontSize(val);
                  },
                ),
                // Live preview box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TaybahColors.primaryTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ • الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
                    style: GoogleFonts.amiri(
                      fontSize: _quranFontSize,
                      height: 1.8,
                      color: TaybahColors.primaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ──── Additional Islamic Services Section ────
          _buildSectionHeader('خدمات وأقسام إيمانية مميزة', Icons.auto_awesome_rounded),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? TaybahColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.goldSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.explore_rounded, color: TaybahColors.gold, size: 22),
                  ),
                  title: Text(
                    'بوصلة القبلة الشريفة',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'تحديد اتجاه الكعبة والمسافة الفلكية بالدرجات',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QiblaScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.goldSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.stars_rounded, color: TaybahColors.gold, size: 22),
                  ),
                  title: Text(
                    'أسماء الله الحسنى (99 اسماً)',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '«مَنْ أَحْصَاهَا دَخَلَ الجَنَّةَ» مع الشرح والمعاني',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AsmaAllahScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.goldSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded, color: TaybahColors.gold, size: 22),
                  ),
                  title: Text(
                    'الرقية الشرعية',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'آيات وأدعية الشفاء والتحصين مع عدادات التكرار',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RuqyahScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // About App & Credits Section
          _buildSectionHeader('حول التطبيق والهوية', Icons.info_outline_rounded),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? TaybahColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/images/logo.png'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تطبيق طيبة الإسلامي (V3)',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
                            ),
                          ),
                          Text(
                            'رواية قالون عن نافع • مواقيت الأوائل • بوصلة القبلة • أسماء الله',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text(
                  'تطبيق إسلامي شامل صدقة جارية، يهدف لخدمة كتاب الله وسنة رسوله وتيسير العبادات اليومية في ليبيا والعالم الإسلامي.',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: isDark ? TaybahColors.darkTextSecondary : TaybahColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: TaybahColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: TaybahColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
