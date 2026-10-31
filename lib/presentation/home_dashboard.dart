import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import '../core/brand.dart';
import '../core/theme.dart';
import '../data/prayer_api.dart';
import '../data/shared_prefs_helper.dart';
import '../data/notification_service.dart';

import 'adhkar_screen.dart';
import 'asma_allah_screen.dart';
import 'duas_screen.dart';
import 'hadith_screen.dart';
import 'prayer_screen.dart';
import 'qibla_screen.dart';
import 'quran_screen.dart';
import 'ruqyah_screen.dart';
import 'settings_screen.dart';

import 'widgets/city_picker_sheet.dart';
import 'widgets/glass.dart';
import 'widgets/ui_kit.dart';

class TaybahDashboard extends StatefulWidget {
  const TaybahDashboard({super.key});

  @override
  State<TaybahDashboard> createState() => TaybahDashboardState();
}

class TaybahDashboardState extends State<TaybahDashboard> {
  int selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void setTab(int index) {
    if (selectedIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeTab(onSwitchTab: setTab),
      const QuranScreen(),
      const PrayerScreen(),
      const AdhkarScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Smooth PageView with Horizontal Slide Transition
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => selectedIndex = i),
            children: pages,
          ),

          // Floating Glassmorphic Bottom Navigation Bar (Ultra-clean, calm & simple)
          Positioned(
            left: 22,
            right: 22,
            bottom: 18 + MediaQuery.of(context).padding.bottom,
            child: _buildFloatingGlassBar(),
          ),
        ],
      ),
    );
  }

  /// الشريط السفلي بزجاج سائل: كبسولة للأقسام + دائرة منفصلة للقبلة.
  Widget _buildFloatingGlassBar() {
    final dark = TaybahColors.isDark;
    const items = [
      ('الرئيسية', Icons.home_rounded, Icons.home_outlined),
      ('القرآن', Icons.menu_book_rounded, Icons.menu_book_outlined),
      ('الصلاة', Icons.access_time_filled_rounded, Icons.access_time_rounded),
      ('الأذكار', Icons.auto_stories_rounded, Icons.auto_stories_outlined),
    ];
    final active = dark ? TaybahColors.goldLight : TaybahColors.forest;
    final idle = dark ? Colors.white.withAlpha(190) : const Color(0xFF26352B);

    return Row(
      children: [
        Expanded(
          child: GlassContainer(
            height: 62,
            grouped: false,
            blur: 18,
            elevation: 1.2,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(31)),
            child: Row(
              children: List.generate(items.length, (i) {
                final selected = selectedIndex == i;
                final (label, on, off) = items[i];
                return Expanded(
                  child: Tooltip(
                    message: label,
                    child: Semantics(
                      label: label,
                      selected: selected,
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setTab(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: selected
                                ? (dark
                                    ? Colors.white.withAlpha(30)
                                    : Colors.white.withAlpha(185))
                                : Colors.transparent,
                            boxShadow: selected && !dark
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(14),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 220),
                              scale: selected ? 1.08 : 1,
                              child: Icon(
                                selected ? on : off,
                                size: 25,
                                color: selected ? active : idle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Tooltip(
          message: 'اتجاه القبلة',
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QiblaScreen()),
              );
            },
            child: GlassContainer(
              width: 62,
              height: 62,
              grouped: false,
              blur: 18,
              elevation: 1.2,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Center(
                child: Icon(Icons.explore_outlined, size: 26, color: idle),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class HomeTab extends StatefulWidget {
  final ValueChanged<int> onSwitchTab;

  const HomeTab({super.key, required this.onSwitchTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Map<String, dynamic> _timings = {};
  String _cityName = PrayerApi.defaultCityName;
  String _citySlug = PrayerApi.defaultCitySlug;
  int _hijriAdjustment = 0;
  Map<String, dynamic>? _lastRead;
  Map<String, bool> _prayerTracker = {};
  Map<String, bool> _nawafilTracker = {};
  Timer? _countdownTimer;

  static const List<Map<String, String>> namesOfAllah = [
    {'name': 'الرَّحْمَٰنُ', 'meaning': 'كثير الرحمة بجميع خلقه في الدنيا والآخرة'},
    {'name': 'الرَّحِيمُ', 'meaning': 'المنعم برحمته الخاصة على عباده المؤمنين'},
    {'name': 'المَلِكُ', 'meaning': 'المتصرف في ملكه كيف يشاء، لا راد لقضائه'},
    {'name': 'القُدُّوسُ', 'meaning': 'المنزه عن كل عيب ونقص، الطاهر المطلق'},
    {'name': 'السَّلَامُ', 'meaning': 'السالم من كل آفة ونقص، وواهب الأمان والسلام'},
    {'name': 'المُؤْمِنُ', 'meaning': 'المصدق لرسله، المفيض بالأمن على عباده'},
    {'name': 'المُهَيْمِنُ', 'meaning': 'الشهيد والرقيب على كل شيء، القائم على خلقه'},
    {'name': 'العَزِيزُ', 'meaning': 'القوي الغالب الذي لا يقهر ولا يغلب أبداً'},
    {'name': 'الجَبَّارُ', 'meaning': 'الذي يجبر قلوب المنكسرين ويقهر المتكبرين'},
    {'name': 'المُتَكَبِّرُ', 'meaning': 'المتعالي عن صفات الخلق وعن كل سوء'},
    {'name': 'الخَالِقُ', 'meaning': 'الموجد للأشياء من العدم ومقدرها بحكمته'},
    {'name': 'البَارِئُ', 'meaning': 'المنفذ لما خلقه ومخرجه إلى الوجود على أكمل وجه'},
    {'name': 'المُصَوِّرُ', 'meaning': 'المعطي لكل مخلوق صورته وشكله المتميز'},
    {'name': 'الغَفَّارُ', 'meaning': 'الستار لذنوب عباده المتجاوز عن خطاياهم'},
    {'name': 'القَهَّارُ', 'meaning': 'الذي خضعت له الرقاب وذلت له الكائنات'},
    {'name': 'الوَهَّابُ', 'meaning': 'الكثير الهبات والعطايا دون مقابل ولا عوض'},
    {'name': 'الرَّزَّاقُ', 'meaning': 'المتكفل بأرزاق العباد والخلائق أجمعين'},
    {'name': 'الفَتَّاحُ', 'meaning': 'الحاكم بين عباده، وفاتح أبواب الرحمة والخير'},
    {'name': 'العَلِيمُ', 'meaning': 'المحيط بكل شيء ظاهره وباطنه وما كان وما يكون'},
    {'name': 'اللَّطِيفُ', 'meaning': 'البر بعباده الموصل إليهم مصالحهم برفق وخفاء'},
  ];

  static const List<Map<String, String>> dailyHadiths = [
    {
      'hadith': '«كَلِمَتَانِ خَفِيفَتَانِ عَلَى اللِّسَانِ، ثَقِيلَتَانِ فِي الْمِيزَانِ، حَبِيبَتَانِ إِلَى الرَّحْمَٰنِ: سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ»',
      'source': 'صحيح البخاري ومسلم • عن أبي هريرة رضي الله عنه',
    },
    {
      'hadith': '«مَنْ سَلَكَ طَرِيقًا يَلْتَمِسُ فِيهِ عِلْمًا، سَهَّلَ اللَّهُ لَهُ بِهِ طَرِيقًا إِلَى الْجَنَّةِ»',
      'source': 'صحيح مسلم • عن أبي هريرة رضي الله عنه',
    },
    {
      'hadith': '«خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ»',
      'source': 'صحيح البخاري • عن عثمان بن عفان رضي الله عنه',
    },
    {
      'hadith': '«الْمُسْلِمُ مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ»',
      'source': 'صحيح البخاري ومسلم • عن عبد الله بن عمرو رضي الله عنهما',
    },
    {
      'hadith': '«لاَ يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ»',
      'source': 'صحيح البخاري ومسلم • عن أنس بن مالك رضي الله عنه',
    },
  ];

  Map<String, String> _getDailyHadith() {
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return dailyHadiths[dayOfYear % dailyHadiths.length];
  }


  static const List<String> dailyAdhkar = [
    '﴿أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ﴾\n- سورة الرعد',
    '﴿وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا وَيَرْزُقْهُ مِنْ حَيْثُ لَا يَحْتَسِبُ﴾\n- سورة الطلاق',
    '﴿فَإِنَّ مَعَ الْعُسْرِ يُسْرًا • إِنَّ مَعَ الْعُسْرِ يُسْرًا﴾\n- سورة الشرح',
    '﴿وَقُل رَّبِّ زِدْنِي عِلْمًا﴾\n- سورة طه',
    '﴿إِنَّ اللَّهَ مَعَ الصَّابِرِينَ﴾\n- سورة البقرة',
    '﴿وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ﴾\n- سورة الطلاق',
    '﴿رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ﴾\n- سورة البقرة',
  ];

  String _getDailyZikr() {
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return dailyAdhkar[dayOfYear % dailyAdhkar.length];
  }

  Map<String, String> _getDailyNameOfAllah() {
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return namesOfAllah[dayOfYear % namesOfAllah.length];
  }

  String _getHijriDateApprox() {
    final d = DateTime.now().add(Duration(days: _hijriAdjustment));
    try {
      final h = HijriCalendar.fromDate(d);
      return '${h.hDay} ${_hijriMonths[h.hMonth - 1]} ${h.hYear}هـ';
    } catch (_) {
      return '';
    }
  }

  static const List<String> _hijriMonths = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}_${now.month}_${now.day}';
  }

  @override
  void initState() {
    super.initState();
    _handleFirstLaunchAndLoad();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // عند دخول يوم جديد نعيد تحميل مواقيت اليوم الجديد تلقائياً
      final today = DateTime.now().day;
      if (_loadedDay != null && _loadedDay != today) {
        _loadedDay = today;
        _loadData();
        return;
      }
      if (_timings.isNotEmpty) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleFirstLaunchAndLoad() async {
    final isFirst = await SharedPrefsHelper.instance.isFirstLaunch();
    if (isFirst) {
      final detected = await PrayerApi.autoDetectAndSetNearestCity();
      if (detected != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'أهلاً بك! تم تحديد مدينتك تلقائياً بالـ GPS: ${detected['ar_name']}',
              style: TextStyle(fontFamily: TaybahFonts.ui, fontWeight: FontWeight.bold),
            ),
            backgroundColor: TaybahColors.primary,
          ),
        );
      }
      await SharedPrefsHelper.instance.setFirstLaunchCompleted();
    }

    await _loadData();
    // طلب إذن الإشعارات (أندرويد 13+ و iOS) حتى يصل الأذان فعلاً
    await NotificationService.instance.requestPermissions(askExactAlarm: isFirst);
    NotificationService.instance.rescheduleAll();
    if (isFirst) await _askBatteryExemption();
  }

  /// شرح بسيط ثم طلب استثناء التطبيق من توفير البطارية (أندرويد) حتى لا يتأخر الأذان.
  Future<void> _askBatteryExemption() async {
    final svc = NotificationService.instance;
    if (await svc.batteryUnrestricted() || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TaybahColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.battery_alert_rounded,
            color: TaybahColors.gold, size: 36),
        title: Text(
          'حتى يصلك الأذان في وقته',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: TaybahFonts.ui, 
              fontWeight: FontWeight.bold, color: TaybahColors.textPrimary),
        ),
        content: Text(
          'بعض الهواتف توقف التنبيهات لتوفير البطارية فيتأخر الأذان أو لا يصل. '
          'اسمح لتطبيق طيبة بالعمل بدون قيود البطارية.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: TaybahFonts.ui, 
              fontSize: 13.5, color: TaybahColors.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('لاحقاً',
                style: TextStyle(fontFamily: TaybahFonts.ui, color: TaybahColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('سماح'),
          ),
        ],
      ),
    );
    if (ok == true) await svc.requestBatteryUnrestricted();
  }

  int? _loadedDay;

  Future<void> _loadData() async {
    _loadedDay = DateTime.now().day;
    final name = await SharedPrefsHelper.instance.getSelectedCityName();
    final slug = await SharedPrefsHelper.instance.getSelectedCitySlug();
    final lr = await SharedPrefsHelper.instance.getLastRead();
    final pTrack = await SharedPrefsHelper.instance.getDailyPrayerTracker(_getTodayKey());
    final nTrack = await SharedPrefsHelper.instance.getDailyNawafilTracker(_getTodayKey());
    final hijriAdj = await SharedPrefsHelper.instance.getHijriAdjustment();

    if (!mounted) return;
    setState(() {
      _cityName = name;
      _citySlug = slug;
      _lastRead = lr;
      _prayerTracker = pTrack;
      _nawafilTracker = nTrack;
      _hijriAdjustment = hijriAdj;
    });

    final times = await PrayerApi.getPrayerTimesFromAlAwail(
      slug: _citySlug,
      cityName: name,
      isSummer: await SharedPrefsHelper.instance.isSummerTime(),
    );

    if (mounted) {
      setState(() => _timings = times);
      NotificationService.instance.scheduleDailyPrayers(times);
    }
  }

  void _openCityPicker() async {
    final selected = await CityPickerSheet.show(
      context,
      currentCityName: _cityName,
    );
    if (selected != null) {
      await _loadData();
    }
  }

  Future<void> _togglePrayer(String prayerKey) async {
    HapticFeedback.lightImpact();
    await SharedPrefsHelper.instance.togglePrayerTracker(_getTodayKey(), prayerKey);
    final pTrack = await SharedPrefsHelper.instance.getDailyPrayerTracker(_getTodayKey());
    if (mounted) setState(() => _prayerTracker = pTrack);
  }

  Future<void> _toggleNafl(String naflKey) async {
    HapticFeedback.lightImpact();
    await SharedPrefsHelper.instance.toggleNaflTracker(_getTodayKey(), naflKey);
    final nTrack = await SharedPrefsHelper.instance.getDailyNawafilTracker(_getTodayKey());
    if (mounted) setState(() => _nawafilTracker = nTrack);
  }

  static const _weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  @override
  Widget build(BuildContext context) {
    final next = PrayerApi.calculateNextPrayer(_timings);
    final dark = TaybahColors.isDark;

    return Scaffold(
      backgroundColor: TaybahColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
          children: [
            _header(dark),
            const SizedBox(height: 18),
            _heroPrayerCard(next, dark),
            const SectionTitle('صلواتي اليوم'),
            _prayerTrackerCard(),
            const SizedBox(height: 12),
            _contextAdhkarCard(),
            const SizedBox(height: 12),
            _continueReadingCard(),
            SectionTitle('السنن والنوافل'),
            _nawafilCard(),
            const SectionTitle('الأقسام'),
            _sectionsGrid(),
            const SectionTitle('من نور الوحي'),
            _dailyLightCard(),
          ],
        ),
      ),
    );
  }

  // ─── الرأس ───
  Widget _header(bool dark) {
    final now = DateTime.now();
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.asset(TaybahBrand.logoAsset, width: 44, height: 44),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('طيبة', style: tStyle(20, weight: FontWeight.w800, height: 1.15)),
              Text(
                '${_weekdays[now.weekday - 1]} • ${_getHijriDateApprox()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tStyle(12.5,
                    weight: FontWeight.w500, color: TaybahColors.textMuted),
              ),
            ],
          ),
        ),
        Material(
          color: dark ? Colors.white.withAlpha(14) : TaybahColors.surface,
          shape: StadiumBorder(
            side: BorderSide(
                color: dark ? Colors.white.withAlpha(20) : TaybahColors.border),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: _openCityPicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place_outlined,
                      size: 16,
                      color: dark ? TaybahColors.goldLight : TaybahColors.forest),
                  const SizedBox(width: 4),
                  Text(_cityName, style: tStyle(13, weight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'الإعدادات',
          icon: Icon(Icons.settings_outlined, color: TaybahColors.textSecondary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ).then((_) => _loadData()),
        ),
      ],
    );
  }

  // ─── بطاقة الصلاة القادمة ───
  Widget _heroPrayerCard(Map<String, dynamic> next, bool dark) {
    final inIqama = next['isBetweenAdhanAndIqama'] == true;
    final progress = ((next['progress'] as num?) ?? 0).toDouble().clamp(0.0, 1.0);
    const keys = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    const names = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

    return GestureDetector(
      onTap: () => widget.onSwitchTab(2),
      child: GlassContainer(
        tint: dark ? const Color(0x8C0E2A1B) : const Color(0xD9183D24),
        elevation: 1.4,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: GeometricPattern(
                    color: TaybahColors.goldLight.withAlpha(dark ? 14 : 20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        inIqama ? 'وقت الإقامة' : 'الصلاة القادمة',
                        style: tStyle(13,
                            weight: FontWeight.w500, color: Colors.white70),
                      ),
                      const Spacer(),
                      if (inIqama)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: TaybahColors.goldLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('حان الأذان',
                              style: tStyle(11.5,
                                  weight: FontWeight.w700,
                                  color: TaybahColors.forestDeep)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          next['name']?.toString() ?? '',
                          style: tStyle(34,
                              weight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2),
                        ),
                      ),
                      Text(
                        next['time12']?.toString() ?? '--:--',
                        style: tStyle(26,
                            weight: FontWeight.w700,
                            color: TaybahColors.goldLight,
                            height: 1.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 16, color: Colors.white.withAlpha(170)),
                      const SizedBox(width: 6),
                      Text(
                        inIqama
                            ? 'الإقامة بعد ${next['iqamaRemaining']}'
                            : 'بعد ${next['remaining']}',
                        style: tStyle(15,
                            weight: FontWeight.w600, color: Colors.white)
                            .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                      const Spacer(),
                      Text(
                        'الإقامة ${next['iqamaTime12']}',
                        style: tStyle(12.5,
                            weight: FontWeight.w500, color: Colors.white60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: Colors.white.withAlpha(30),
                      color: TaybahColors.goldLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (var i = 0; i < keys.length; i++)
                        Expanded(
                          child: _miniTime(
                            names[i],
                            _timings[keys[i]],
                            next['key'] == keys[i],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniTime(String name, dynamic time, bool isNext) {
    final t = PrayerApi.formatTo12Hour(time).replaceAll(' ص', '').replaceAll(' م', '');
    return Column(
      children: [
        Text(name,
            style: tStyle(11.5,
                weight: isNext ? FontWeight.w700 : FontWeight.w500,
                color: isNext ? TaybahColors.goldLight : Colors.white60)),
        const SizedBox(height: 2),
        Text(t,
            style: tStyle(12.5,
                weight: FontWeight.w700,
                color: isNext ? Colors.white : Colors.white70)),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: isNext ? 16 : 0,
          height: 2,
          decoration: BoxDecoration(
            color: TaybahColors.goldLight,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  // ─── سجل الصلوات ───
  Widget _prayerTrackerCard() {
    const items = [
      ['Fajr', 'الفجر'],
      ['Dhuhr', 'الظهر'],
      ['Asr', 'العصر'],
      ['Maghrib', 'المغرب'],
      ['Isha', 'العشاء'],
    ];
    final done = _prayerTracker.values.where((v) => v).length;
    return TCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  done == 5
                      ? 'أتممت صلوات اليوم، تقبّل الله منك'
                      : 'سجّل ما أدّيت من الفرائض',
                  style: tStyle(13, color: TaybahColors.textSecondary),
                ),
              ),
              Text('$done من 5',
                  style: tStyle(13,
                      weight: FontWeight.w700,
                      color: TaybahColors.isDark
                          ? TaybahColors.goldLight
                          : TaybahColors.forest)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final it in items) _prayerCheck(it[0], it[1]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _prayerCheck(String key, String label) {
    final isDone = _prayerTracker[key] ?? false;
    final dark = TaybahColors.isDark;
    return GestureDetector(
      onTap: () => _togglePrayer(key),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDone
                  ? TaybahColors.forest
                  : (dark ? Colors.white.withAlpha(10) : TaybahColors.surfaceMuted),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone
                    ? TaybahColors.gold
                    : (dark ? Colors.white.withAlpha(24) : TaybahColors.border),
                width: 1.4,
              ),
            ),
            child: Icon(
              isDone ? Icons.check_rounded : null,
              size: 22,
              color: TaybahColors.goldLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: tStyle(12,
                  weight: isDone ? FontWeight.w700 : FontWeight.w500,
                  color: isDone ? TaybahColors.textPrimary : TaybahColors.textMuted)),
        ],
      ),
    );
  }

  // ─── أذكار الوقت ───
  Widget _contextAdhkarCard() {
    final hour = DateTime.now().hour;
    late String title, subtitle;
    late IconData icon;
    if (hour >= 4 && hour < 12) {
      title = 'أذكار الصباح';
      subtitle = 'أصبحنا وأصبح الملك لله';
      icon = Icons.wb_sunny_outlined;
    } else if (hour >= 12 && hour < 19) {
      title = 'أذكار المساء';
      subtitle = 'أمسينا وأمسى الملك لله';
      icon = Icons.nights_stay_outlined;
    } else {
      title = 'أذكار النوم';
      subtitle = 'باسمك ربي وضعت جنبي وبك أرفعه';
      icon = Icons.bedtime_outlined;
    }
    return TCard(
      onTap: () => widget.onSwitchTab(3),
      child: Row(
        children: [
          TIconBox(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tStyle(15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: tStyle(12.5, color: TaybahColors.textMuted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: TaybahColors.textMuted),
        ],
      ),
    );
  }

  // ─── متابعة القراءة ───
  Widget _continueReadingCard() {
    final jozz = ((_lastRead?['jozz'] ?? 1) as num).toInt();
    return TCard(
      onTap: () => widget.onSwitchTab(1),
      child: Row(
        children: [
          const TIconBox(icon: Icons.menu_book_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تابع القراءة',
                    style: tStyle(12, color: TaybahColors.textMuted)),
                Text(
                  'سورة ${_lastRead?['surahName'] ?? 'الفَاتِحة'}',
                  style: GoogleFonts.amiri(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: TaybahColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (jozz / 30).clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: TaybahColors.isDark
                              ? Colors.white.withAlpha(16)
                              : TaybahColors.surfaceMuted,
                          color: TaybahColors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('الجزء $jozz من 30',
                        style: tStyle(11.5, color: TaybahColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: TaybahColors.textMuted),
        ],
      ),
    );
  }

  // ─── السنن والنوافل ───
  Widget _nawafilCard() {
    const items = [
      ['fajr_sunnah', 'سنة الفجر'],
      ['duha', 'الضحى'],
      ['dhuhr_rawatib', 'رواتب الظهر'],
      ['maghrib_sunnah', 'سنة المغرب'],
      ['witr', 'الوتر'],
    ];
    final dark = TaybahColors.isDark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final it in items)
          Builder(builder: (context) {
            final done = _nawafilTracker[it[0]] ?? false;
            return GestureDetector(
              onTap: () => _toggleNafl(it[0]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: done ? TaybahColors.forest : TaybahColors.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: done
                        ? TaybahColors.forest
                        : (dark ? Colors.white.withAlpha(20) : TaybahColors.border),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(done ? Icons.check_rounded : Icons.add_rounded,
                        size: 16,
                        color: done ? TaybahColors.goldLight : TaybahColors.textMuted),
                    const SizedBox(width: 6),
                    Text(it[1],
                        style: tStyle(13,
                            weight: FontWeight.w600,
                            color: done ? Colors.white : TaybahColors.textPrimary)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ─── الأقسام ───
  Widget _sectionsGrid() {
    void push(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    final items = <(String, IconData?, Widget?, VoidCallback)>[
      ('القرآن الكريم', Icons.menu_book_outlined, null, () => widget.onSwitchTab(1)),
      ('مواقيت الصلاة', Icons.access_time_rounded, null, () => widget.onSwitchTab(2)),
      ('الأذكار', Icons.auto_stories_outlined, null, () => widget.onSwitchTab(3)),
      ('القبلة', Icons.explore_outlined, null, () => push(const QiblaScreen())),
      ('أسماء الله', null, null, () => push(const AsmaAllahScreen())),
      ('الأدعية', Icons.volunteer_activism_outlined, null, () => push(const DuasScreen())),
      ('الحديث', Icons.format_quote_rounded, null, () => push(const HadithScreen())),
      ('الرقية', Icons.shield_outlined, null, () => push(const RuqyahScreen())),
      ('الإعدادات', Icons.tune_rounded, null, () => push(const SettingsScreen())),
    ];
    final dark = TaybahColors.isDark;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.08,
      children: [
        for (final (title, icon, _, onTap) in items)
          TCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TIconBox(
                  icon: icon,
                  size: 42,
                  custom: icon == null
                      ? AsmaAllahIcon(
                          size: 22,
                          color: dark ? TaybahColors.goldLight : TaybahColors.forest)
                      : null,
                ),
                const SizedBox(height: 8),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tStyle(12.5, weight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }

  // ─── من نور الوحي: آية، حديث، اسم من أسماء الله ───
  Widget _dailyLightCard() {
    final hadith = _getDailyHadith();
    final name = _getDailyNameOfAllah();
    final zikr = _getDailyZikr().split('\n');
    final quote = GoogleFonts.amiri(
      fontSize: 19,
      height: 1.9,
      color: TaybahColors.textPrimary,
    );
    Widget label(String t) => Text(t,
        style: tStyle(12,
            weight: FontWeight.w700,
            color: TaybahColors.isDark ? TaybahColors.goldLight : TaybahColors.primaryAccent));
    Widget divider() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Divider(
              height: 1,
              color: TaybahColors.isDark
                  ? Colors.white.withAlpha(16)
                  : TaybahColors.border),
        );

    return TCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label('آية'),
          const SizedBox(height: 6),
          Text(zikr.first, style: quote),
          if (zikr.length > 1)
            Text(zikr.last.replaceAll('- ', ''),
                style: tStyle(12, color: TaybahColors.textMuted)),
          divider(),
          label('حديث'),
          const SizedBox(height: 6),
          Text(hadith['hadith'] ?? '', style: quote),
          Text(hadith['source'] ?? '',
              style: tStyle(12, color: TaybahColors.textMuted)),
          divider(),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AsmaAllahScreen()),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label('من أسماء الله الحسنى'),
                      const SizedBox(height: 4),
                      Text(name['name'] ?? '',
                          style: GoogleFonts.amiri(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: TaybahColors.textPrimary)),
                      Text(name['meaning'] ?? '',
                          style: tStyle(12.5,
                              color: TaybahColors.textSecondary, height: 1.6)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: TaybahColors.textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
