import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../data/asset_loader.dart';

class RuqyahScreen extends StatefulWidget {
  const RuqyahScreen({super.key});

  @override
  State<RuqyahScreen> createState() => _RuqyahScreenState();
}

class _RuqyahScreenState extends State<RuqyahScreen> {
  Map<String, dynamic>? _ruqyahData;
  bool _loading = true;
  final Map<String, int> _progress = {}; // key: "secIndex_itemIndex" -> remaining count

  @override
  void initState() {
    super.initState();
    _loadRuqyah();
  }

  Future<void> _loadRuqyah() async {
    final data = await AssetLoader.loadRuqyah();
    final sections = (data['sections'] as List<dynamic>?) ?? [];
    for (int s = 0; s < sections.length; s++) {
      final items = (sections[s]['items'] as List<dynamic>?) ?? [];
      for (int i = 0; i < items.length; i++) {
        final repeat = items[i]['repeat'] ?? 1;
        _progress['${s}_$i'] = repeat as int;
      }
    }
    setState(() {
      _ruqyahData = data;
      _loading = false;
    });
  }

  void _tapItem(int s, int i, int originalRepeat) {
    final key = '${s}_$i';
    final current = _progress[key] ?? originalRepeat;
    if (current > 0) {
      HapticFeedback.lightImpact();
      setState(() {
        _progress[key] = current - 1;
      });
    } else {
      // Reset if already completed
      setState(() {
        _progress[key] = originalRepeat;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = (_ruqyahData?['sections'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('الرقية الشرعية'),
        actions: [
          IconButton(
            tooltip: 'إعادة ضبط العدادات',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                for (int s = 0; s < sections.length; s++) {
                  final items = (sections[s]['items'] as List<dynamic>?) ?? [];
                  for (int i = 0; i < items.length; i++) {
                    final repeat = items[i]['repeat'] ?? 1;
                    _progress['${s}_$i'] = repeat as int;
                  }
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تمت إعادة ضبط جميع عدادات التكرار', style: GoogleFonts.cairo()),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [TaybahColors.darkSurface, TaybahColors.darkSurfaceMuted]
                          : [TaybahColors.primary, TaybahColors.primaryMedium],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: TaybahColors.primary.withAlpha(35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: TaybahColors.gold.withAlpha(40),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_rounded, color: TaybahColors.goldLight, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تحصين وشفاء بإذن الله',
                                  style: GoogleFonts.cairo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: TaybahColors.goldLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'آيات وأدعية الرقية المأثورة عن النبي ﷺ للحفظ والشفاء',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '💡 اضغط على البطاقة لتسجيل القراءة وإنقاص العداد تلقائياً',
                          style: GoogleFonts.cairo(fontSize: 12, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Sections
                for (int s = 0; s < sections.length; s++) ...[
                  _buildSectionHeader(sections[s]['title'] ?? '', isDark),
                  const SizedBox(height: 8),
                  for (int i = 0; i < (sections[s]['items'] as List<dynamic>? ?? []).length; i++) ...[
                    _buildRuqyahCard(s, i, sections[s]['items'][i], isDark),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: TaybahColors.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? TaybahColors.goldLight : TaybahColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuqyahCard(int s, int i, Map<String, dynamic> item, bool isDark) {
    final key = '${s}_$i';
    final repeat = item['repeat'] as int? ?? 1;
    final remaining = _progress[key] ?? repeat;
    final isDone = remaining == 0;

    return InkWell(
      onTap: () => _tapItem(s, i, repeat),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDone
              ? (isDark ? const Color(0xFF0F2618) : const Color(0xFFE8F5E9))
              : (isDark ? TaybahColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDone
                ? const Color(0xFF4CAF50)
                : (isDark ? TaybahColors.darkBorder : TaybahColors.border),
            width: isDone ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 25 : 8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Text of Ayah or Dua
            Text(
              item['text'] ?? '',
              style: GoogleFonts.amiri(
                fontSize: 20,
                height: 2.0,
                color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Reference and Counter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'نسخ',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: '${item['text']}\n[${item['ref']}]'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم النسخ للحافظة', style: GoogleFonts.cairo()),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    Text(
                      item['ref'] ?? '',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                      ),
                    ),
                  ],
                ),
                // Counter Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFF4CAF50)
                        : (isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.goldSoft),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDone ? const Color(0xFF4CAF50) : TaybahColors.gold,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDone ? Icons.check_circle_rounded : Icons.repeat_rounded,
                        size: 16,
                        color: isDone ? Colors.white : TaybahColors.primaryDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isDone ? 'تم التكرار' : 'المتبقي: $remaining / $repeat',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDone ? Colors.white : TaybahColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
