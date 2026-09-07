import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../data/asset_loader.dart';

class AsmaAllahScreen extends StatefulWidget {
  const AsmaAllahScreen({super.key});

  @override
  State<AsmaAllahScreen> createState() => _AsmaAllahScreenState();
}

class _AsmaAllahScreenState extends State<AsmaAllahScreen> {
  List<Map<String, dynamic>> _allNames = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _searchQuery = '';
  bool _isGrid = true;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    final names = await AssetLoader.loadAsmaAllah();
    setState(() {
      _allNames = names;
      _filtered = names;
      _loading = false;
    });
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query.trim();
      if (_searchQuery.isEmpty) {
        _filtered = _allNames;
      } else {
        _filtered = _allNames.where((n) {
          final name = (n['name'] ?? '').toString();
          final meaning = (n['meaning'] ?? '').toString();
          return name.contains(_searchQuery) || meaning.contains(_searchQuery);
        }).toList();
      }
    });
  }

  void _showDetailModal(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? TaybahColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 20),
            // Number badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: TaybahColors.goldSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: TaybahColors.gold.withAlpha(120)),
              ),
              child: Text(
                'الاسم رقم ${item['id']} من 99',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: TaybahColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // The Name
            Text(
              item['name'] ?? '',
              style: GoogleFonts.amiri(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: isDark ? TaybahColors.goldLight : TaybahColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Meaning
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'المعنى والدلالة:',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? TaybahColors.goldLight : TaybahColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                item['meaning'] ?? '',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  height: 1.8,
                  color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(height: 20),
            // Action Button
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final text = '﴿وَلِلَّهِ الْأَسْمَاءُ الْحُسْنَىٰ فَادْعُوهُ بِهَا﴾\n'
                          'اسم الله: ${item['name']}\n'
                          'المعنى: ${item['meaning']}\n\n'
                          'من تطبيق طيبة - الرفيق الإسلامي';
                      Clipboard.setData(ClipboardData(text: text));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم نسخ اسم ${item['name']} وشرحه بنجاح',
                            style: GoogleFonts.cairo(),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: TaybahColors.primary,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text('نسخ الاسم والمعنى', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('أسماء الله الحسنى'),
        actions: [
          IconButton(
            tooltip: _isGrid ? 'عرض كقائمة' : 'عرض كشبكة',
            icon: Icon(_isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [TaybahColors.darkSurface, TaybahColors.darkSurfaceMuted]
                          : [TaybahColors.primary, TaybahColors.primaryMedium],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: TaybahColors.primary.withAlpha(35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: TaybahColors.gold.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: TaybahColors.goldLight, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '«مَنْ أَحْصَاهَا دَخَلَ الجَنَّةَ»',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: TaybahColors.goldLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '99 اسماً مباركاً مع المعاني والشروحات الجليلة',
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
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن اسم أو معنى...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () => _filter(''),
                            )
                          : null,
                    ),
                  ),
                ),

                // Names Grid / List
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'لم يتم العثور على نتائج للبحث',
                            style: GoogleFonts.cairo(color: Colors.grey),
                          ),
                        )
                      : _isGrid
                          ? GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 1.05,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) {
                                final item = _filtered[i];
                                return _buildGridItem(item, isDark);
                              },
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) {
                                final item = _filtered[i];
                                return _buildListItem(item, isDark);
                              },
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildGridItem(Map<String, dynamic> item, bool isDark) {
    return InkWell(
      onTap: () => _showDetailModal(item),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? TaybahColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.goldSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${item['id']}',
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: TaybahColors.gold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item['name'] ?? '',
                style: GoogleFonts.amiri(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? TaybahColors.goldLight : TaybahColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> item, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.goldSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TaybahColors.gold.withAlpha(100)),
          ),
          child: Text(
            '${item['id']}',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: TaybahColors.gold,
            ),
          ),
        ),
        title: Text(
          item['name'] ?? '',
          style: GoogleFonts.amiri(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? TaybahColors.goldLight : TaybahColors.primary,
          ),
        ),
        subtitle: Text(
          item['meaning'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: isDark ? TaybahColors.darkTextSecondary : TaybahColors.textSecondary,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        onTap: () => _showDetailModal(item),
      ),
    );
  }
}
