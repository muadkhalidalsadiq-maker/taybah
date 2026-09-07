import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../data/asset_loader.dart';
import '../data/notification_service.dart';
import '../data/prayer_api.dart';
import '../data/shared_prefs_helper.dart';
import 'widgets/city_picker_sheet.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _nawafil = [];
  Map<String, dynamic> _timings = {};
  String _cityName = PrayerApi.defaultCityName;
  String _citySlug = PrayerApi.defaultCitySlug;
  bool _isLoading = true;
  Timer? _countdownTimer;

  // Qibla & Compass heading
  double _qiblaAngle = 104.0; // Typical Libya Qibla angle
  StreamSubscription<CompassEvent>? _compassSub;
  double? _deviceHeading;

  // Prayer notification toggles
  final Map<String, bool> _prayerAlerts = {
    'Fajr': true,
    'Sunrise': false,
    'Dhuhr': true,
    'Asr': true,
    'Maghrib': true,
    'Isha': true,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSavedCityAndTimes();
    _loadNawafil();
    _loadPrayerAlerts();

    _compassSub = FlutterCompass.events?.listen((event) {
      if (mounted) setState(() => _deviceHeading = event.heading);
    });

    // Refresh countdown every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _timings.isNotEmpty) {
        setState(() {});
      }
    });
  }

  Future<void> _loadPrayerAlerts() async {
    for (final key in _prayerAlerts.keys) {
      final enabled =
          await NotificationService.instance.isPrayerNotificationEnabled(key);
      _prayerAlerts[key] = enabled;
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleAlert(String key) async {
    final next =
        await NotificationService.instance.togglePrayerNotification(key);
    setState(() => _prayerAlerts[key] = next);
    if (_timings.isNotEmpty) {
      NotificationService.instance.scheduleDailyPrayers(_timings);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          next ? 'تم تفعيل إشعار أذان صلاة $key بنجاح ✓' : 'تم كتم إشعار صلاة $key',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: next ? TaybahColors.primary : TaybahColors.textSecondary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _testAdhanNotification(String prayerName) async {
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.sendAdhanTestNotification(prayerName);
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
              'تم إرسال إشعار تجريبي وتشغيل أذان $prayerName الآن.',
              style: GoogleFonts.cairo(
                  fontSize: 14, color: TaybahColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'ستصلك تنبيهات الأذان في موعد كل صلاة بدقة بحسب توقيت مدينتك، مع الصوت والاهتزاز.',
              style:
                  GoogleFonts.cairo(fontSize: 12, color: TaybahColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              NotificationService.instance.stopAdhanAudio();
            },
            child: Text(
              'إيقاف الأذان',
              style: GoogleFonts.cairo(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              NotificationService.instance.stopAdhanAudio();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TaybahColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _countdownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  bool _isSummer = true;

  Future<void> _loadSavedCityAndTimes() async {
    final name = await SharedPrefsHelper.instance.getSelectedCityName();
    final slug = await SharedPrefsHelper.instance.getSelectedCitySlug();
    final summer = await SharedPrefsHelper.instance.isSummerTime();
    setState(() {
      _cityName = name;
      _citySlug = slug;
      _isSummer = summer;
    });
    await _loadPrayerTimes();
  }

  Future<void> _loadPrayerTimes() async {
    setState(() => _isLoading = true);
    final times = await PrayerApi.getPrayerTimesFromAlAwail(
      slug: _citySlug,
      cityName: _cityName,
      isSummer: _isSummer,
    );
    if (mounted) {
      setState(() {
        _timings = times;
        _isLoading = false;
      });
      NotificationService.instance.scheduleDailyPrayers(times);
    }
  }

  Future<void> _loadNawafil() async {
    final data = await AssetLoader.loadNawafil();
    if (mounted) setState(() => _nawafil = data);
  }

  void _openCityPicker() async {
    final selected = await CityPickerSheet.show(
      context,
      currentCityName: _cityName,
    );
    if (selected != null) {
      await _loadSavedCityAndTimes();
    }
  }

  Future<void> _toggleSummer() async {
    final nextVal = !_isSummer;
    setState(() => _isSummer = nextVal);
    await SharedPrefsHelper.instance.setSummerTime(nextVal);
    await _loadPrayerTimes();
  }

  Future<void> _detectLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري تحديد موقعك والمدينة الأقرب بالـ GPS...'),
        duration: Duration(seconds: 2),
      ),
    );
    final nearest = await PrayerApi.autoDetectAndSetNearestCity();
    final position = await PrayerApi.getCurrentPosition();

    if (position != null) {
      final angle = PrayerApi.calculateQiblaAngle(
        position.latitude,
        position.longitude,
      );
      if (mounted) {
        setState(() => _qiblaAngle = angle);
      }
    }

    if (nearest != null) {
      await _loadSavedCityAndTimes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديد أقرب مدينة بالـ GPS: $_cityName، وتحديث المواقيت.',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaybahColors.primary,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر الوصول إلى نظام GPS، تم الإبقاء على المدينة المختارة.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaybahColors.background,
      appBar: AppBar(
        title: Text(
          'مواقيت الصلاة',
          style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: TaybahColors.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: TaybahColors.primary,
          unselectedLabelColor: TaybahColors.textMuted,
          labelStyle: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: 'المواقيت'),
            Tab(text: 'القبلة'),
            Tab(text: 'النوافل والسنن'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSummer ? Icons.wb_sunny_rounded : Icons.ac_unit_rounded,
              color: _isSummer ? TaybahColors.gold : TaybahColors.primary,
            ),
            tooltip: _isSummer ? 'التوقيت الصيفي (اضغط للتبديل)' : 'التوقيت الشتوي (اضغط للتبديل)',
            onPressed: _toggleSummer,
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'تحديد المدينة الأقرب بالـ GPS',
            onPressed: _detectLocation,
          ),
          IconButton(
            icon: const Icon(Icons.location_city_rounded),
            tooltip: 'تغيير المدينة',
            onPressed: _openCityPicker,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrayerTimesTab(),
          _buildQiblaTab(),
          _buildNawafilTab(),
        ],
      ),
    );
  }

  Widget _buildPrayerTimesTab() {
    final nextPrayer = PrayerApi.calculateNextPrayer(_timings);

    final prayers = [
      {'key': 'Fajr', 'name': 'الفجر', 'icon': Icons.wb_twilight_rounded},
      {'key': 'Sunrise', 'name': 'الشروق', 'icon': Icons.wb_sunny_outlined},
      {'key': 'Dhuhr', 'name': 'الظهر', 'icon': Icons.wb_sunny_rounded},
      {'key': 'Asr', 'name': 'العصر', 'icon': Icons.sunny_snowing},
      {'key': 'Maghrib', 'name': 'المغرب', 'icon': Icons.nights_stay_outlined},
      {'key': 'Isha', 'name': 'العشاء', 'icon': Icons.nights_stay_rounded},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        // City Selector Card
        GestureDetector(
          onTap: _openCityPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: TaybahColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TaybahColors.primaryTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: TaybahColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المدينة المحددة (مواقيت الأوائل)',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: TaybahColors.textMuted,
                        ),
                      ),
                      Text(
                        'ليبيا - $_cityName',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: TaybahColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: TaybahColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'تغيير',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: TaybahColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Hero Next Prayer Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: TaybahColors.primaryDark,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: TaybahColors.primaryDark.withAlpha(50),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
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
                        'الصلاة القادمة',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextPrayer['name'] ?? '',
                        style: GoogleFonts.cairo(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: TaybahColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      nextPrayer['time12'] ?? nextPrayer['time'] ?? '',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (nextPrayer['progress'] as double?) ?? 0.0,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    TaybahColors.goldLight,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'متبقي على الأذان',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    nextPrayer['remaining'] ?? '00:00:00',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TaybahColors.goldLight,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Adhan Notification Control Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TaybahColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TaybahColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: TaybahColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نظام الأذان والإشعارات الحي',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: TaybahColors.textPrimary,
                      ),
                    ),
                    Text(
                      'تنبيهات الأذان تعمل تلقائياً لكل صلاة',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: TaybahColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _testAdhanNotification(
                  nextPrayer['name'] ?? 'الصلاة',
                ),
                icon: const Icon(Icons.volume_up_rounded, size: 15),
                label: const Text('تجربة الأذان'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TaybahColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'جدول الصلوات اليوم',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: TaybahColors.textPrimary,
          ),
        ),

        const SizedBox(height: 12),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: TaybahColors.primary),
            ),
          )
        else
          ...prayers.map((p) {
            final key = p['key'] as String;
            final isNext = (p['name'] == nextPrayer['name']);
            final rawTime = _timings[key] ?? '--:--';
            final timeValue = PrayerApi.formatTo12Hour(rawTime);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: isNext ? TaybahColors.primaryTint : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isNext
                      ? TaybahColors.primary
                      : TaybahColors.border,
                  width: isNext ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isNext
                          ? TaybahColors.primary
                          : TaybahColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      p['icon'] as IconData,
                      size: 20,
                      color: isNext ? Colors.white : TaybahColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      p['name'] as String,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
                        color: isNext
                            ? TaybahColors.primaryDark
                            : TaybahColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isNext)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: TaybahColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'القادمة',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Text(
                    timeValue,
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isNext
                          ? TaybahColors.primaryDark
                          : TaybahColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _toggleAlert(key),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (_prayerAlerts[key] ?? true)
                            ? TaybahColors.primaryTint
                            : TaybahColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        (_prayerAlerts[key] ?? true)
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_outlined,
                        size: 18,
                        color: (_prayerAlerts[key] ?? true)
                            ? TaybahColors.gold
                            : TaybahColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildQiblaTab() {
    final heading = _deviceHeading ?? 0.0;
    final relQibla = ((_qiblaAngle - heading) % 360 + 360) % 360;
    final diff = (relQibla > 180 ? 360 - relQibla : relQibla).abs();
    final isAligned = diff < 4.0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Compass Container
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: isAligned ? Colors.green : TaybahColors.border,
                  width: isAligned ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isAligned ? Colors.green : Colors.black).withAlpha(isAligned ? 60 : 15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Compass Ring
                  Transform.rotate(
                    angle: relQibla * (math.pi / 180.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isAligned ? Colors.green : TaybahColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.navigation_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 60),
                        Container(
                          width: 4,
                          height: 40,
                          color: (isAligned ? Colors.green : TaybahColors.primary).withAlpha(100),
                        ),
                      ],
                    ),
                  ),
                  // Central Kaaba Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isAligned ? Colors.green.withAlpha(30) : TaybahColors.primaryTint,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isAligned ? Colors.green : TaybahColors.primary,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.mosque_rounded,
                        color: isAligned ? Colors.green : TaybahColors.primary,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'اتجاه القبلة',
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: TaybahColors.textPrimary,
              ),
            ),

            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: TaybahColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'الزاوية: ${_qiblaAngle.toStringAsFixed(1)}° بالنسبة للشمال',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: TaybahColors.primaryDark,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'اتجاه الكعبة المشرفة بالنسبة لمدينة $_cityName. ضع هاتفك بشكل أفقي لتحديد الاتجاه بدقة.',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: TaybahColors.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _detectLocation,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة ضبط بالـ GPS'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNawafilTab() {
    if (_nawafil.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: TaybahColors.primary),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: _nawafil.length,
      itemBuilder: (ctx, i) {
        final n = _nawafil[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TaybahColors.border),
          ),
          child: ExpansionTile(
            shape: Border.all(color: Colors.transparent),
            collapsedShape: Border.all(color: Colors.transparent),
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: TaybahColors.primaryTint,
              child: Text(
                '${i + 1}',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: TaybahColors.primary,
                ),
              ),
            ),
            title: Text(
              n['name'] ?? '',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: TaybahColors.textPrimary,
              ),
            ),
            subtitle: Text(
              n['ruling'] ?? '',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: TaybahColors.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      n['description'] ?? '',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: TaybahColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TaybahColors.primaryTint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: TaybahColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              n['reward'] ?? '',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: TaybahColors.primaryDark,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
