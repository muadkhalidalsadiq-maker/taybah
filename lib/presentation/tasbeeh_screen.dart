import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../data/asset_loader.dart';
import '../data/shared_prefs_helper.dart';

class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> {
  List<dynamic> _tasbeehList = [];
  int _selectedIndex = 0;
  int _counter = 0;
  int _target = 33;
  int _rounds = 0;
  int _todayTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTodayStats();
  }

  Future<void> _load() async {
    final data = await AssetLoader.loadTasbeeh();
    if (mounted) {
      setState(() {
        _tasbeehList = data;
        if (data.isNotEmpty) {
          _target = (data[0]['count'] as int?) ?? 33;
        }
      });
    }
  }

  Future<void> _loadTodayStats() async {
    final now = DateTime.now();
    final dateStr = '${now.year}_${now.month}_${now.day}';
    final count = await SharedPrefsHelper.instance.getDailyTasbeehCount(dateStr);
    if (mounted) {
      setState(() => _todayTotal = count);
    }
  }

  void _increment() {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final dateStr = '${now.year}_${now.month}_${now.day}';
    SharedPrefsHelper.instance.addDailyTasbeehCount(dateStr, 1);

    setState(() {
      _counter++;
      _todayTotal++;
      if (_counter >= _target) {
        HapticFeedback.heavyImpact();
        _rounds++;
        _counter = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'أحسنت! أتممت الدورة رقم $_rounds بنجاح، تقبل الله منك ✓',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            backgroundColor: TaybahColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _reset() {
    setState(() {
      _counter = 0;
      _rounds = 0;
    });
    HapticFeedback.mediumImpact();
  }

  void _showStatsModal(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = await SharedPrefsHelper.instance.getWeeklyTasbeehStats();
    final totalWeek = stats.values.fold(0, (a, b) => a + b);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? TaybahColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'سجل التسبيح الأسبوعي',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.primaryDark,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: TaybahColors.goldSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'المجموع: $totalWeek تسبيحة',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: TaybahColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Simple Bar Chart of 7 Days
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: stats.entries.map((entry) {
                final val = entry.value;
                final maxVal = stats.values.reduce((a, b) => a > b ? a : b);
                final heightFactor = maxVal > 0 ? (val / maxVal).clamp(0.08, 1.0) : 0.08;
                final parts = entry.key.split('_');
                final dayNum = parts.length > 2 ? parts[2] : '';

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$val',
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: val > 0 ? TaybahColors.gold : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 28,
                      height: 100 * heightFactor,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: val > 0
                              ? [TaybahColors.gold, TaybahColors.primaryAccent]
                              : [Colors.grey.withAlpha(50), Colors.grey.withAlpha(30)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayNum,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              '«أَحَبُّ الْأَعْمَالِ إِلَى اللَّهِ أَدْوَمُهَا وَإِنْ قَلَّ»',
              style: GoogleFonts.amiri(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? TaybahColors.goldLight : TaybahColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_tasbeehList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('المسبحة الإلكترونية')),
        body: const Center(child: CircularProgressIndicator(color: TaybahColors.primary)),
      );
    }

    final current = _tasbeehList[_selectedIndex];
    final progress = (_counter / _target).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'المسبحة الإلكترونية',
          style: GoogleFonts.cairo(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: TaybahColors.gold),
            tooltip: 'إحصائيات التسبيح',
            onPressed: () => _showStatsModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تصفير العداد',
            onPressed: _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Horizontal Tasbeeh Chips Selector
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _tasbeehList.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final isSelected = i == _selectedIndex;
                  return ChoiceChip(
                    label: Text(
                      _tasbeehList[i]['text'] ?? '',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: TaybahColors.primaryAccent,
                    backgroundColor: isDark ? TaybahColors.darkSurface : Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? TaybahColors.gold
                          : (isDark ? TaybahColors.darkBorder : TaybahColors.border),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedIndex = i;
                          _counter = 0;
                          _target = (_tasbeehList[i]['count'] as int?) ?? 33;
                        });
                      }
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Current Tasbeeh Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? TaybahColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 30 : 10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      current['text'] ?? '',
                      style: GoogleFonts.amiri(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'الدورات: $_rounds  •  اليوم: $_todayTotal  •  الهدف: $_target',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? TaybahColors.goldLight : TaybahColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Big Circular Interactive Tap Counter Button
            GestureDetector(
              onTap: _increment,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  color: isDark ? TaybahColors.darkSurface : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? TaybahColors.darkBorder : TaybahColors.primaryLight,
                    width: 6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: TaybahColors.primaryAccent.withAlpha(isDark ? 50 : 30),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress Indicator Ring
                    SizedBox(
                      width: 216,
                      height: 216,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.surfaceMuted,
                        valueColor: const AlwaysStoppedAnimation<Color>(TaybahColors.gold),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_counter',
                          style: GoogleFonts.cairo(
                            fontSize: 64,
                            fontWeight: FontWeight.w800,
                            color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.primaryDark,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'من $_target',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.primaryTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'المس للتسبيح',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? TaybahColors.goldLight : TaybahColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Target Quick Selectors: 33 / 100 / 1000
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [33, 100, 1000].map((t) {
                final isCurrent = _target == t;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _target = t;
                        _counter = 0;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isCurrent
                          ? (isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.primaryLight)
                          : (isDark ? TaybahColors.darkSurface : Colors.white),
                      side: BorderSide(
                        color: isCurrent
                            ? TaybahColors.gold
                            : (isDark ? TaybahColors.darkBorder : TaybahColors.border),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    child: Text(
                      '$t',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        color: isCurrent
                            ? TaybahColors.gold
                            : (isDark ? TaybahColors.darkTextSecondary : TaybahColors.textSecondary),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }
}
