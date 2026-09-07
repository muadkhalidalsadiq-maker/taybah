import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../data/asset_loader.dart';
import '../data/shared_prefs_helper.dart';
import 'surah_reader_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allSurahs = [];
  List<Map<String, dynamic>> _filteredSurahs = [];
  List<Map<String, dynamic>> _fullQuranVerses = [];
  List<Map<String, dynamic>> _verseSearchResults = [];
  bool _isLoading = true;
  bool _isSearchingVerses = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _verseSearchController = TextEditingController();
  Map<String, dynamic>? _lastRead;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _verseSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final surahs = await AssetLoader.loadQuranSurahs();
    final lr = await SharedPrefsHelper.instance.getLastRead();
    if (mounted) {
      setState(() {
        _allSurahs = surahs;
        _filteredSurahs = surahs;
        _lastRead = lr;
        _isLoading = false;
      });
    }
  }

  void _filterSurahs(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredSurahs = _allSurahs;
      } else {
        _filteredSurahs = _allSurahs.where((s) {
          final name = (s['name'] ?? '').toString().toLowerCase();
          final nameEn = (s['name_en'] ?? '').toString().toLowerCase();
          final idStr = s['id'].toString();
          return name.contains(q) || nameEn.contains(q) || idStr == q;
        }).toList();
      }
    });
  }

  String _cleanTashkeel(String s) {
    return s.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
  }

  Future<void> _searchVerses(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() {
        _verseSearchResults = [];
        _isSearchingVerses = false;
      });
      return;
    }

    setState(() => _isSearchingVerses = true);

    if (_fullQuranVerses.isEmpty) {
      _fullQuranVerses = await AssetLoader.loadFullQuran();
    }

    final cleanQuery = _cleanTashkeel(q).toLowerCase();
    final results = <Map<String, dynamic>>[];

    for (final surah in _fullQuranVerses) {
      final sId = surah['id'] as int;
      final sName = surah['name'] as String;
      final verses = (surah['verses'] as List<dynamic>?) ?? [];

      for (final v in verses) {
        final vId = v['id'] as int;
        final vText = (v['text'] as String?) ?? '';
        final cleanText = _cleanTashkeel(vText).toLowerCase();

        if (cleanText.contains(cleanQuery)) {
          results.add({
            'surahId': sId,
            'surahName': sName,
            'verseId': vId,
            'verseText': vText,
            'matchQuery': q,
          });
          if (results.length >= 100) break; // Limit to 100 for fast UI response
        }
      }
      if (results.length >= 100) break;
    }

    if (mounted) {
      setState(() {
        _verseSearchResults = results;
        _isSearchingVerses = false;
      });
    }
  }

  void _openSurah(Map<String, dynamic> surah, {int? targetVerseId}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahReaderScreen(
          surahMeta: surah,
          initialVerseId: targetVerseId,
        ),
      ),
    );
    final lr = await SharedPrefsHelper.instance.getLastRead();
    if (mounted) setState(() => _lastRead = lr);
  }

  void _openVerseResult(Map<String, dynamic> item) {
    final sId = item['surahId'] as int;
    final vId = item['verseId'] as int;
    final found = _allSurahs.firstWhere((s) => s['id'] == sId, orElse: () => _allSurahs.first);
    _openSurah(found, targetVerseId: vId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'القرآن الكريم (رواية قالون)',
          style: GoogleFonts.cairo(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: TaybahColors.gold,
          indicatorWeight: 3,
          labelColor: isDark ? TaybahColors.goldLight : TaybahColors.primary,
          unselectedLabelColor: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
          labelStyle: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13),
          tabs: const [
            Tab(text: 'السور (114)'),
            Tab(text: 'الأجزاء (30)'),
            Tab(text: 'البحث في الآيات 🔍'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: TaybahColors.gold))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSurahTab(isDark),
                _buildJozzTab(isDark),
                _buildVerseSearchTab(isDark),
              ],
            ),
    );
  }

  Widget _buildSurahTab(bool isDark) {
    return Column(
      children: [
        // Search in Surahs
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _filterSurahs,
            decoration: InputDecoration(
              hintText: 'ابحث باسم السورة أو رقمها...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _filterSurahs('');
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Resume Reading Card
        if (_searchController.text.isEmpty && _lastRead != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                final sId = _lastRead!['surahId'] as int;
                final vId = _lastRead!['verseId'] as int?;
                final found = _allSurahs.firstWhere(
                  (s) => s['id'] == sId,
                  orElse: () => _allSurahs.first,
                );
                _openSurah(found, targetVerseId: vId);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [TaybahColors.darkSurfaceMuted, TaybahColors.darkSurface]
                        : [TaybahColors.primaryTint, Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? TaybahColors.darkBorder : TaybahColors.borderGlow,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: TaybahColors.gold,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.bookmark_rounded, color: Colors.black, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'متابعة القراءة الأخيرة',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'سورة ${_lastRead!['surahName'] ?? 'الفاتحة'} (آية ${_lastRead!['verseId'] ?? 1})',
                            style: GoogleFonts.amiri(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: TaybahColors.gold),
                  ],
                ),
              ),
            ),
          ),

        // Surah List
        Expanded(
          child: _filteredSurahs.isEmpty
              ? Center(
                  child: Text('لا توجد سورة مطابقة', style: GoogleFonts.cairo(color: Colors.grey)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  itemCount: _filteredSurahs.length,
                  separatorBuilder: (_, index) => Divider(
                    height: 1,
                    color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
                  ),
                  itemBuilder: (ctx, i) {
                    final surah = _filteredSurahs[i];
                    final id = surah['id'] as int;
                    final name = surah['name'] as String;
                    final typeAr = surah['type_ar'] ?? (surah['type'] == 'medinan' ? 'مدنية' : 'مكية');
                    final versesCount = surah['total_verses'] ?? 0;
                    final page = surah['start_page'] ?? 1;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      onTap: () => _openSurah(surah),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.primaryTint,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? TaybahColors.darkBorder : TaybahColors.primary.withAlpha(40),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$id',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: GoogleFonts.amiri(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '$typeAr • $versesCount آية • صـ $page',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            surah['name_en'] ?? '',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildJozzTab(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: 30,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final jozzNumber = i + 1;
        final surahsInJozz = _allSurahs.where((s) => s['jozz'] == jozzNumber).toList();
        final firstSurahName = surahsInJozz.isNotEmpty ? surahsInJozz.first['name'] : '';

        return Container(
          decoration: BoxDecoration(
            color: isDark ? TaybahColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? TaybahColors.darkBorder : TaybahColors.border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$jozzNumber',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
                  ),
                ),
              ),
            ),
            title: Text(
              'الجزء $jozzNumber',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
              ),
            ),
            subtitle: Text(
              surahsInJozz.isNotEmpty ? 'يبدأ بـ: سورة $firstSurahName' : '',
              style: GoogleFonts.amiri(
                fontSize: 14,
                color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: TaybahColors.gold),
            onTap: () {
              if (surahsInJozz.isNotEmpty) {
                _openSurah(surahsInJozz.first);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildVerseSearchTab(bool isDark) {
    return Column(
      children: [
        // Verse Search Field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _verseSearchController,
            onChanged: _searchVerses,
            decoration: InputDecoration(
              hintText: 'ابحث عن أي كلمة أو جملة في القرآن الكريم...',
              prefixIcon: const Icon(Icons.manage_search_rounded, color: TaybahColors.gold),
              suffixIcon: _verseSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _verseSearchController.clear();
                        _searchVerses('');
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Status or Info Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Row(
            children: [
              Text(
                _isSearchingVerses
                    ? 'جاري البحث في 6,236 آية...'
                    : _verseSearchResults.isNotEmpty
                        ? 'تم العثور على ${_verseSearchResults.length} آية مطابقة'
                        : _verseSearchController.text.isNotEmpty
                            ? 'لا توجد آيات مطابقة للبحث'
                            : 'اكتب كلمتين على الأقل للبحث في نص الآيات',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                ),
              ),
            ],
          ),
        ),

        if (_isSearchingVerses) const LinearProgressIndicator(color: TaybahColors.gold),

        // Results List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            itemCount: _verseSearchResults.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final res = _verseSearchResults[i];
              final sName = res['surahName'] as String;
              final vId = res['verseId'] as int;
              final vText = res['verseText'] as String;

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openVerseResult(res),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? TaybahColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.goldSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: TaybahColors.gold.withAlpha(80)),
                            ),
                            child: Text(
                              'سورة $sName • آية $vId',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'انتقال للآية',
                                style: GoogleFonts.cairo(fontSize: 11, color: TaybahColors.gold),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: TaybahColors.gold),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '﴿ $vText ﴾',
                        style: GoogleFonts.amiri(
                          fontSize: 18,
                          height: 1.9,
                          color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
