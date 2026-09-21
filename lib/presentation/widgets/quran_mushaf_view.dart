import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../data/asset_loader.dart';
import '../../data/shared_prefs_helper.dart';

class QuranMushafView extends StatefulWidget {
  final int initialPage;
  final ValueChanged<int>? onPageChanged;

  const QuranMushafView({
    super.key,
    this.initialPage = 1,
    this.onPageChanged,
  });

  @override
  State<QuranMushafView> createState() => QuranMushafViewState();
}

class QuranMushafViewState extends State<QuranMushafView> {
  late final PageController _pageController;
  int _currentPage = 1;
  Map<int, List<Map<String, dynamic>>> _pageVersesMap = {};
  bool _isLoading = true;
  double _fontSize = 22.0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, 604);
    _pageController = PageController(initialPage: _currentPage - 1);
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final fullQuran = await AssetLoader.loadFullQuran();
    final fSize = await SharedPrefsHelper.instance.getQuranFontSize();

    // Map all verses by page (1-604)
    final Map<int, List<Map<String, dynamic>>> map = {};
    for (final surah in fullQuran) {
      final sId = surah['id'] as int;
      final sName = surah['name'] as String;
      final typeAr = surah['type_ar'] ?? (surah['type'] == 'medinan' ? 'مدنية' : 'مكية');
      final verses = (surah['verses'] as List<dynamic>?) ?? [];

      for (final v in verses) {
        final p = (v['page'] as int?) ?? 1;
        final verseMap = {
          'surahId': sId,
          'surahName': sName,
          'typeAr': typeAr,
          'verseId': v['id'] as int,
          'text': v['text'] as String,
          'jozz': v['jozz'] as int,
          'page': p,
        };
        map.putIfAbsent(p, () => []).add(verseMap);
      }
    }

    if (mounted) {
      setState(() {
        _pageVersesMap = map;
        _fontSize = fSize;
        _isLoading = false;
      });
    }
  }

  void jumpToPage(int page) {
    final p = page.clamp(1, 604);
    setState(() => _currentPage = p);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(p - 1);
    }
  }

  void _showJumpDialog() {
    final textController = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'انتقال إلى صفحة في المصحف',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أدخل رقم الصفحة (من 1 إلى 604):',
              style: GoogleFonts.cairo(fontSize: 13, color: TaybahColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: TaybahColors.gold, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TaybahColors.primary),
            onPressed: () {
              final p = int.tryParse(textController.text);
              if (p != null && p >= 1 && p <= 604) {
                Navigator.pop(ctx);
                jumpToPage(p);
              }
            },
            child: Text('انتقال', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: TaybahColors.gold));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Top Page Header (Surah name, Page, Juz)
        _buildPageHeader(isDark),

        // Quran Mushaf Page View
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: 604,
            onPageChanged: (idx) {
              final newPage = idx + 1;
              setState(() => _currentPage = newPage);
              widget.onPageChanged?.call(newPage);

              // Update last read bookmark
              final verses = _pageVersesMap[newPage];
              if (verses != null && verses.isNotEmpty) {
                final first = verses.first;
                SharedPrefsHelper.instance.setLastRead(
                  surahId: first['surahId'] as int,
                  surahName: first['surahName'] as String,
                  verseId: first['verseId'] as int,
                  jozz: first['jozz'] as int,
                );
              }
            },
            itemBuilder: (context, pageIdx) {
              final pageNum = pageIdx + 1;
              final verses = _pageVersesMap[pageNum] ?? [];
              return _buildMushafSinglePage(pageNum, verses, isDark);
            },
          ),
        ),

        // Bottom Navigation & Controls Bar
        _buildPageFooter(isDark),
      ],
    );
  }

  Widget _buildPageHeader(bool isDark) {
    final verses = _pageVersesMap[_currentPage] ?? [];
    String surahTitle = 'القرآن الكريم';
    int jozzNum = 1;

    if (verses.isNotEmpty) {
      final first = verses.first;
      surahTitle = 'سورة ${first['surahName']}';
      jozzNum = first['jozz'] as int;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.primaryTint,
        border: Border(
          bottom: BorderSide(
            color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'الجُزْءُ $jozzNum',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
            ),
          ),
          Text(
            surahTitle,
            style: GoogleFonts.amiri(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
            ),
          ),
          InkWell(
            onTap: _showJumpDialog,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: TaybahColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'صفحة $_currentPage',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMushafSinglePage(int pageNum, List<Map<String, dynamic>> verses, bool isDark) {
    if (verses.isEmpty) {
      return Center(
        child: Text('جاري تحميل الصفحة $pageNum...', style: GoogleFonts.cairo()),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? TaybahColors.darkSurface : const Color(0xFFFFFDF9), // Creamy authentic paper tone
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? TaybahColors.gold.withAlpha(60) : TaybahColors.gold.withAlpha(120),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 40 : 10),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _buildPageContentElements(verses, isDark),
        ),
      ),
    );
  }

  List<Widget> _buildPageContentElements(List<Map<String, dynamic>> verses, bool isDark) {
    final List<Widget> widgets = [];
    int currentSurahId = -1;

    // Buffer verses for rich paragraph rendering
    final StringBuffer paragraphBuffer = StringBuffer();

    void flushParagraph() {
      if (paragraphBuffer.isNotEmpty) {
        final text = paragraphBuffer.toString();
        paragraphBuffer.clear();
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SelectableText(
              text,
              style: GoogleFonts.amiri(
                fontSize: _fontSize,
                fontWeight: FontWeight.normal,
                color: isDark ? TaybahColors.darkTextPrimary : const Color(0xFF1E293B),
                height: 2.25,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.justify,
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      }
    }

    for (final v in verses) {
      final sId = v['surahId'] as int;
      final sName = v['surahName'] as String;
      final typeAr = v['typeAr'] as String;
      final vId = v['verseId'] as int;
      final text = v['text'] as String;

      // When a new Surah starts on this page
      if (sId != currentSurahId) {
        flushParagraph();
        currentSurahId = sId;

        // Surah Banner Header
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.primaryTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: TaybahColors.gold.withAlpha(100),
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'سورة $sName',
                  style: GoogleFonts.amiri(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
                  ),
                ),
                Text(
                  'رواية قالون عن نافع • $typeAr',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: TaybahColors.gold,
                  ),
                ),
              ],
            ),
          ),
        );

        // Bismillah Header for surahs other than Fatiha and Tawbah
        if (sId != 1 && sId != 9 && vId == 1) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                style: GoogleFonts.amiri(
                  fontSize: _fontSize + 1,
                  fontWeight: FontWeight.bold,
                  color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
      }

      paragraphBuffer.write('$text ');
    }

    flushParagraph();

    return widgets;
  }

  Widget _buildPageFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? TaybahColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Page Button
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            color: _currentPage > 1 ? TaybahColors.primary : Colors.grey,
            tooltip: 'الصفحة السابقة',
            onPressed: _currentPage > 1 ? () => jumpToPage(_currentPage - 1) : null,
          ),

          // Slider to quick scrub pages
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                trackHeight: 3,
                activeTrackColor: TaybahColors.gold,
                inactiveTrackColor: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.primaryTint,
                thumbColor: TaybahColors.gold,
              ),
              child: Slider(
                value: _currentPage.toDouble(),
                min: 1.0,
                max: 604.0,
                onChanged: (val) {
                  jumpToPage(val.toInt());
                },
              ),
            ),
          ),

          // Next Page Button
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            color: _currentPage < 604 ? TaybahColors.primary : Colors.grey,
            tooltip: 'الصفحة التالية',
            onPressed: _currentPage < 604 ? () => jumpToPage(_currentPage + 1) : null,
          ),
        ],
      ),
    );
  }
}
