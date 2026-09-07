import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
            left: 20,
            right: 20,
            bottom: 20,
            child: _buildFloatingGlassBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingGlassBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      {
        'label': 'الرئيسية',
        'icon': Icons.home_rounded,
        'unselected': Icons.home_outlined,
      },
      {
        'label': 'القرآن',
        'icon': Icons.menu_book_rounded,
        'unselected': Icons.menu_book_outlined,
      },
      {
        'label': 'الصلاة',
        'icon': Icons.mosque_rounded,
        'unselected': Icons.mosque_outlined,
      },
      {
        'label': 'الأذكار',
        'icon': Icons.auto_stories_rounded,
        'unselected': Icons.auto_stories_outlined,
      },
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: isDark ? TaybahColors.darkSurface.withAlpha(225) : Colors.white.withAlpha(225),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? TaybahColors.darkBorder : Colors.white.withAlpha(240),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 50 : 14),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: (isDark ? TaybahColors.gold : TaybahColors.primary).withAlpha(12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isSelected = selectedIndex == i;
              final item = items[i];

              return Expanded(
                child: InkWell(
                  onTap: () => setTab(i),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected
                            ? (item['icon'] as IconData)
                            : (item['unselected'] as IconData),
                        size: 19,
                        color: isSelected
                            ? (isDark ? TaybahColors.goldLight : TaybahColors.primary)
                            : (isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['label'] as String,
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? TaybahColors.goldLight : TaybahColors.primary)
                              : (isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Subtle gold indicator dot
                      Container(
                        width: isSelected ? 10 : 0,
                        height: 2.0,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? TaybahColors.gold
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
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
  bool _isSummer = true;
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

  // Interactive Quick-Tasbeeh on Home screen
  int _homeTasbeehCount = 0;
  static const List<String> _homeDhikrOptions = [
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    'سُبْحَانَ اللَّهِ الْعَظِيمِ',
    'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
    'لَا إِلَٰهَ إِلَّا اللَّهُ',
    'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
    'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
  ];
  int _selectedHomeDhikrIndex = 0;

  void _incrementHomeTasbeeh() {
    HapticFeedback.lightImpact();
    setState(() {
      _homeTasbeehCount++;
      if (_homeTasbeehCount % 33 == 0) {
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _cycleHomeDhikr() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedHomeDhikrIndex =
          (_selectedHomeDhikrIndex + 1) % _homeDhikrOptions.length;
    });
  }

  void _resetHomeTasbeeh() {
    HapticFeedback.mediumImpact();
    setState(() => _homeTasbeehCount = 0);
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) return 'صباح الخير والبركة';
    if (hour >= 12 && hour < 17) return 'طاب يومك بذكر الله';
    return 'مساء الخير والسكينة';
  }

  String _getHijriDateApprox() {
    final now = DateTime.now().add(Duration(days: _hijriAdjustment));
    final gregorianDays = now.difference(DateTime(622, 7, 16)).inDays;
    final hijriYear = (gregorianDays / 354.36667).floor();
    final daysInYear = (gregorianDays % 354.36667).floor();
    final hijriMonth = (daysInYear / 29.53).floor() + 1;
    final hijriDay = (daysInYear % 29.53).floor() + 1;
    const hijriMonths = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الثاني',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة'
    ];
    final monthName = hijriMonths[(hijriMonth - 1).clamp(0, 11)];
    return '$hijriDay $monthName $hijriYearهـ';
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}_${now.month}_${now.day}';
  }

  @override
  void initState() {
    super.initState();
    _handleFirstLaunchAndLoad();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _timings.isNotEmpty) {
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
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            backgroundColor: TaybahColors.primary,
          ),
        );
      }
      await SharedPrefsHelper.instance.setFirstLaunchCompleted();
    }

    await _loadData();
  }

  Future<void> _loadData() async {
    final name = await SharedPrefsHelper.instance.getSelectedCityName();
    final slug = await SharedPrefsHelper.instance.getSelectedCitySlug();
    final summer = await SharedPrefsHelper.instance.isSummerTime();
    final lr = await SharedPrefsHelper.instance.getLastRead();
    final pTrack = await SharedPrefsHelper.instance.getDailyPrayerTracker(_getTodayKey());
    final nTrack = await SharedPrefsHelper.instance.getDailyNawafilTracker(_getTodayKey());
    final hijriAdj = await SharedPrefsHelper.instance.getHijriAdjustment();

    setState(() {
      _cityName = name;
      _citySlug = slug;
      _isSummer = summer;
      _lastRead = lr;
      _prayerTracker = pTrack;
      _nawafilTracker = nTrack;
      _hijriAdjustment = hijriAdj;
    });

    final times = await PrayerApi.getPrayerTimesFromAlAwail(
      slug: _citySlug,
      cityName: name,
      isSummer: summer,
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
    setState(() => _prayerTracker = pTrack);
  }

  Future<void> _toggleNafl(String naflKey) async {
    HapticFeedback.lightImpact();
    await SharedPrefsHelper.instance.toggleNaflTracker(_getTodayKey(), naflKey);
    final nTrack = await SharedPrefsHelper.instance.getDailyNawafilTracker(_getTodayKey());
    setState(() => _nawafilTracker = nTrack);
  }

  @override
  Widget build(BuildContext context) {
    final nextPrayer = PrayerApi.calculateNextPrayer(_timings);
    final nameOfAllah = _getDailyNameOfAllah();
    final completedPrayers = _prayerTracker.values.where((v) => v).length;

    return Scaffold(
      backgroundColor: TaybahColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header with Official Logo Emblem
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Official Logo Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: TaybahColors.borderGlow,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: TaybahColors.primary.withAlpha(25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: TaybahColors.primaryDark,
                            ),
                          ),
                          Text(
                            _getHijriDateApprox(),
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: TaybahColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Actions: City Badge & Settings Button
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _openCityPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: TaybahColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(6),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: TaybahColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _cityName,
                                style: GoogleFonts.cairo(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: TaybahColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: _isSummer
                                      ? TaybahColors.primaryLight
                                      : TaybahColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _isSummer ? 'صيفي' : 'شتوي',
                                  style: GoogleFonts.cairo(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: TaybahColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Settings Button
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                          _loadData();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: TaybahColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(6),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.settings_outlined,
                            size: 19,
                            color: TaybahColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Hero Al-Awail Next Prayer Card (12-Hour Format & Visual Dominance)
              GestureDetector(
                onTap: () => widget.onSwitchTab(2), // Navigate to Prayer Tab
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        TaybahColors.primaryDark,
                        TaybahColors.primaryMedium,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: TaybahColors.primaryDark.withAlpha(55),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(30),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(40),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.access_time_filled_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الصلاة القادمة (مواقيت الأوائل)',
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    nextPrayer['name'] ?? '',
                                    style: GoogleFonts.cairo(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // 12-Hour formatted time (e.g. 04:42 م)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(35),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: TaybahColors.gold.withAlpha(80),
                                  ),
                                ),
                                child: Text(
                                  nextPrayer['time12'] ?? nextPrayer['time'] ?? '--:--',
                                  style: GoogleFonts.cairo(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: TaybahColors.goldLight,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'متبقي ${nextPrayer['remaining']}',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                      const SizedBox(height: 16),
                      // Mini Timetable Bar (All in 12-hour format)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(30),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMiniPrayer('الفجر', _timings['Fajr'], nextPrayer['name'] == 'الفجر'),
                            _buildMiniPrayer('الشروق', _timings['Sunrise'], false),
                            _buildMiniPrayer('الظهر', _timings['Dhuhr'], nextPrayer['name'] == 'الظهر'),
                            _buildMiniPrayer('العصر', _timings['Asr'], nextPrayer['name'] == 'العصر'),
                            _buildMiniPrayer('المغرب', _timings['Maghrib'], nextPrayer['name'] == 'المغرب'),
                            _buildMiniPrayer('العشاء', _timings['Isha'], nextPrayer['name'] == 'العشاء'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Daily Prayers Tracker (سجل الصلوات الخمس اليومي)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: TaybahColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: TaybahColors.primaryTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.fact_check_rounded,
                                size: 18,
                                color: TaybahColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'سجل صلوات اليوم المفروضة',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: TaybahColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: completedPrayers == 5
                                ? const Color(0xFFDCFCE7)
                                : TaybahColors.primaryTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$completedPrayers من 5 صلوات',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: completedPrayers == 5
                                  ? const Color(0xFF15803D)
                                  : TaybahColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPrayerCheckButton('Fajr', 'الفجر'),
                        _buildPrayerCheckButton('Dhuhr', 'الظهر'),
                        _buildPrayerCheckButton('Asr', 'العصر'),
                        _buildPrayerCheckButton('Maghrib', 'المغرب'),
                        _buildPrayerCheckButton('Isha', 'العشاء'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Time-based Dhikr Banner
              _buildTimeBasedDhikrBanner(),

              const SizedBox(height: 16),

              // Quran Bookmark / Khatmah Card
              GestureDetector(
                onTap: () => widget.onSwitchTab(1), // Quran Tab
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              TaybahColors.primary,
                              TaybahColors.primaryAccent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: TaybahColors.primary.withAlpha(40),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.bookmark_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'متابعة قراءة القرآن (رواية قالون)',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: TaybahColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'سورة ${_lastRead?['surahName'] ?? 'الفَاتِحة'}',
                              style: GoogleFonts.amiri(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: TaybahColors.textPrimary,
                              ),
                            ),
                            Text(
                              'الجزء ${_lastRead?['jozz'] ?? 1} • الآية ${_lastRead?['verseId'] ?? 1}',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: TaybahColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (((_lastRead?['jozz'] ?? 1) as int) / 30.0).clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: TaybahColors.surfaceMuted,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  TaybahColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: TaybahColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'متابعة',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Interactive Quick-Tasbeeh Card (المسبحة السريعة اليومية)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: TaybahColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: TaybahColors.primaryTint,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.touch_app_rounded,
                                color: TaybahColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المسبحة السريعة',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: TaybahColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'المس للشروع في التسبيح فوراً',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: TaybahColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                              tooltip: 'تغيير صيغة الذكر',
                              color: TaybahColors.primary,
                              onPressed: _cycleHomeDhikr,
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              tooltip: 'تصفير العداد',
                              color: TaybahColors.textMuted,
                              onPressed: _resetHomeTasbeeh,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _incrementHomeTasbeeh,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              TaybahColors.primaryTint,
                              TaybahColors.surfaceMuted,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: TaybahColors.borderGlow),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _homeDhikrOptions[_selectedHomeDhikrIndex],
                                    style: GoogleFonts.amiri(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: TaybahColors.primaryDark,
                                    ),
                                  ),
                                  Text(
                                    'اضغط هنا لزيادة العداد',
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: TaybahColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: TaybahColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: TaybahColors.primary.withAlpha(60),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '$_homeTasbeehCount',
                                  style: GoogleFonts.cairo(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Daily Sunan & Nawafil Checklist
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: TaybahColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: TaybahColors.goldSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.volunteer_activism_rounded,
                            size: 18,
                            color: TaybahColors.gold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'السنن والنوافل اليومية',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: TaybahColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildNaflChip('fajr_sunnah', 'سنة الفجر'),
                        _buildNaflChip('duha', 'صلاة الضحى'),
                        _buildNaflChip('dhuhr_rawatib', 'رواتب الظهر'),
                        _buildNaflChip('maghrib_sunnah', 'سنة المغرب'),
                        _buildNaflChip('witr', 'الوتر وقيام الليل'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quick Access Grid Header
              Text(
                'الأقسام الرئيسية',
                style: GoogleFonts.cairo(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: TaybahColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
                children: [
                  _buildQuickCard(
                    title: 'القرآن الكريم',
                    icon: Icons.menu_book_rounded,
                    gradient: const [TaybahColors.primary, TaybahColors.primaryAccent],
                    onTap: () => widget.onSwitchTab(1),
                  ),
                  _buildQuickCard(
                    title: 'مواقيت الصلاة',
                    icon: Icons.mosque_rounded,
                    gradient: const [TaybahColors.primaryDark, TaybahColors.primaryMedium],
                    onTap: () => widget.onSwitchTab(2),
                  ),
                  _buildQuickCard(
                    title: 'الأذكار (135 باباً)',
                    icon: Icons.auto_stories_rounded,
                    gradient: const [Color(0xFF0284C7), Color(0xFF38BDF8)],
                    onTap: () => widget.onSwitchTab(3),
                  ),
                  _buildQuickCard(
                    title: 'المسبحة',
                    icon: Icons.touch_app_rounded,
                    gradient: const [Color(0xFF7C3AED), Color(0xFFA78BFA)],
                    onTap: () => widget.onSwitchTab(4),
                  ),
                  _buildQuickCard(
                    title: 'أدعية الأنبياء',
                    icon: Icons.volunteer_activism_rounded,
                    gradient: const [Color(0xFFC49A32), Color(0xFFDFB651)],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DuasScreen()),
                      );
                    },
                  ),
                  _buildQuickCard(
                    title: 'الحديث الشريف',
                    icon: Icons.menu_book_sharp,
                    gradient: const [Color(0xFFE11D48), Color(0xFFFB7185)],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HadithScreen(),
                        ),
                      );
                    },
                  ),
                  _buildQuickCard(
                    title: 'اتجاه القبلة',
                    icon: Icons.explore_rounded,
                    gradient: const [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QiblaScreen(),
                        ),
                      );
                    },
                  ),
                  _buildQuickCard(
                    title: 'أسماء الله الحسنى',
                    icon: Icons.auto_awesome_rounded,
                    gradient: const [Color(0xFFB45309), Color(0xFFF59E0B)],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AsmaAllahScreen(),
                        ),
                      );
                    },
                  ),
                  _buildQuickCard(
                    title: 'الرقية الشرعية',
                    icon: Icons.shield_rounded,
                    gradient: const [Color(0xFF15803D), Color(0xFF22C55E)],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RuqyahScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Name of Allah of the Day Card
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AsmaAllahScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
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
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            TaybahColors.primaryTint,
                            TaybahColors.primaryLight,
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: TaybahColors.primary.withAlpha(40),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          nameOfAllah['name'] ?? '',
                          style: GoogleFonts.amiri(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: TaybahColors.primaryDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اسم من أسماء الله الحسنى',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: TaybahColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nameOfAllah['meaning'] ?? '',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: TaybahColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

              const SizedBox(height: 16),

              // Prophetic Hadith Card (حديث اليوم النبوي الشريف)
              Builder(builder: (context) {
                final hadithData = _getDailyHadith();
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: TaybahColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: TaybahColors.primaryTint,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.menu_book_sharp,
                                  size: 18,
                                  color: TaybahColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'حديث اليوم النبوي الشريف',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: TaybahColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            color: TaybahColors.primary,
                            tooltip: 'نسخ الحديث',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                text: '${hadithData['hadith']}\n[${hadithData['source']}]',
                              ));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم نسخ الحديث الشريف بنجاح ✓'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        hadithData['hadith'] ?? '',
                        style: GoogleFonts.amiri(
                          fontSize: 18,
                          height: 1.8,
                          fontWeight: FontWeight.bold,
                          color: TaybahColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hadithData['source'] ?? '',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: TaybahColors.gold,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Daily Ayat / Zikr Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: TaybahColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: TaybahColors.gold,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'آية وذكر اليوم',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: TaybahColors.gold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.auto_awesome,
                          color: TaybahColors.gold,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getDailyZikr(),
                      style: GoogleFonts.amiri(
                        fontSize: 18,
                        height: 1.8,
                        color: TaybahColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniPrayer(String name, dynamic time, bool isNext) {
    // 12-hour format for mini prayers
    final time12 = PrayerApi.formatTo12Hour(time);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 1,
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: isNext ? TaybahColors.goldLight : Colors.white70,
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              time12,
              style: GoogleFonts.cairo(
                fontSize: 10.5,
                fontWeight: isNext ? FontWeight.w900 : FontWeight.w600,
                color: isNext ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerCheckButton(String key, String label) {
    final isDone = _prayerTracker[key] ?? false;

    return GestureDetector(
      onTap: () => _togglePrayer(key),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: isDone
                  ? const LinearGradient(
                      colors: [
                        TaybahColors.primary,
                        TaybahColors.primaryAccent,
                      ],
                    )
                  : null,
              color: isDone ? null : TaybahColors.surfaceMuted,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone ? TaybahColors.primary : TaybahColors.border,
                width: 1.5,
              ),
              boxShadow: isDone
                  ? [
                      BoxShadow(
                        color: TaybahColors.primary.withAlpha(50),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isDone ? Icons.check_rounded : Icons.radio_button_unchecked,
              size: 22,
              color: isDone ? Colors.white : TaybahColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
              color: isDone ? TaybahColors.primaryDark : TaybahColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNaflChip(String key, String label) {
    final isDone = _nawafilTracker[key] ?? false;

    return GestureDetector(
      onTap: () => _toggleNafl(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFDCFCE7) : TaybahColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDone ? const Color(0xFF86EFAC) : TaybahColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDone ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
              size: 14,
              color: isDone ? const Color(0xFF15803D) : TaybahColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                color: isDone ? const Color(0xFF15803D) : TaybahColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBasedDhikrBanner() {
    final hour = DateTime.now().hour;
    String title;
    String subtitle;
    IconData icon;
    Color color;

    if (hour >= 4 && hour < 12) {
      title = 'أذكار الصباح';
      subtitle = 'حصنك الحصين لبداية يوم مبارك مليء بالبركة';
      icon = Icons.wb_sunny_rounded;
      color = TaybahColors.gold;
    } else if (hour >= 12 && hour < 19) {
      title = 'أذكار المساء';
      subtitle = 'ألا بذكر الله تطمئن القلوب وتنشرح الصدور';
      icon = Icons.nights_stay_rounded;
      color = TaybahColors.primaryMedium;
    } else {
      title = 'أذكار النوم وسورة الملك';
      subtitle = 'باسمك ربي وضعت جنبي وبك أرفعه';
      icon = Icons.bedtime_rounded;
      color = const Color(0xFF6366F1);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(40),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: TaybahColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: TaybahColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => widget.onSwitchTab(3), // Adhkar tab
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              'قراءة',
              style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCard({
    required String title,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TaybahColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withAlpha(50),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: TaybahColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
