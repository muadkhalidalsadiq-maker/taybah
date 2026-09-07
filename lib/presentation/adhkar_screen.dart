import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../data/asset_loader.dart';

class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({super.key});

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  List<dynamic> _allCategories = [];
  List<dynamic> _filteredCategories = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await AssetLoader.loadAdhkar();
    if (mounted) {
      setState(() {
        _allCategories = data;
        _filteredCategories = data;
        _isLoading = false;
      });
    }
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredCategories = _allCategories;
      } else {
        _filteredCategories = _allCategories.where((cat) {
          final catName = (cat['category'] ?? '').toString().toLowerCase();
          final items = (cat['items'] as List?) ?? [];
          final matchesItem = items.any((item) =>
              (item['text'] ?? '').toString().toLowerCase().contains(q));
          return catName.contains(q) || matchesItem;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaybahColors.background,
      appBar: AppBar(
        title: Text(
          'حصن المسلم والأذكار (${_allCategories.length} باباً)',
          style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TaybahColors.primary),
            )
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: 'ابحث في 135 باباً من أذكار حصن المسلم...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: TaybahColors.primary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _filter('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // Categories List
                Expanded(
                  child: _filteredCategories.isEmpty
                      ? Center(
                          child: Text(
                            'لا توجد أذكار مطابقة للبحث',
                            style: GoogleFonts.cairo(color: TaybahColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                          itemCount: _filteredCategories.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final cat = _filteredCategories[i];
                            return _buildCategoryCard(cat);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat) {
    final categoryName = cat['category'] as String;
    final items = (cat['items'] as List<dynamic>?) ?? [];

    IconData icon = Icons.auto_stories_rounded;
    Color iconColor = TaybahColors.primary;

    if (categoryName.contains('الصباح')) {
      icon = Icons.wb_sunny_rounded;
      iconColor = TaybahColors.gold;
    } else if (categoryName.contains('المساء')) {
      icon = Icons.nights_stay_rounded;
      iconColor = TaybahColors.primaryMedium;
    } else if (categoryName.contains('النوم')) {
      icon = Icons.bedtime_rounded;
      iconColor = const Color(0xFF6366F1);
    } else if (categoryName.contains('الصلاة')) {
      icon = Icons.mosque_rounded;
      iconColor = TaybahColors.primaryDark;
    } else if (categoryName.contains('الهم') || categoryName.contains('الكرب')) {
      icon = Icons.healing_rounded;
      iconColor = const Color(0xFF0284C7);
    } else if (categoryName.contains('السفر')) {
      icon = Icons.flight_takeoff_rounded;
      iconColor = const Color(0xFF10B981);
    } else if (categoryName.contains('الطعام')) {
      icon = Icons.restaurant_rounded;
      iconColor = const Color(0xFFF97316);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TaybahColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdhkarDetailScreen(
                categoryName: categoryName,
                items: items,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: TaybahColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${items.length} أذكار مأثورة',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: TaybahColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: TaybahColors.textMuted,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdhkarDetailScreen extends StatefulWidget {
  final String categoryName;
  final List<dynamic> items;

  const AdhkarDetailScreen({
    super.key,
    required this.categoryName,
    required this.items,
  });

  @override
  State<AdhkarDetailScreen> createState() => _AdhkarDetailScreenState();
}

class _AdhkarDetailScreenState extends State<AdhkarDetailScreen> {
  late List<int> _remainingCounts;

  @override
  void initState() {
    super.initState();
    _remainingCounts =
        widget.items.map<int>((item) => (item['count'] as int?) ?? 1).toList();
  }

  int get _completedCount => _remainingCounts.where((c) => c <= 0).length;

  @override
  Widget build(BuildContext context) {
    final progress = widget.items.isEmpty
        ? 0.0
        : _completedCount / widget.items.length;

    return Scaffold(
      backgroundColor: TaybahColors.background,
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Progress Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الإنجاز: $_completedCount من ${widget.items.length}',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: TaybahColors.primaryDark,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: TaybahColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: TaybahColors.surfaceMuted,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      TaybahColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.items.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final item = widget.items[i];
                final done = _remainingCounts[i] <= 0;
                final text = (item['text'] as String?) ?? '';
                final description = (item['description'] as String?) ?? '';
                final reference = (item['reference'] as String?) ?? '';

                return Container(
                  decoration: BoxDecoration(
                    color: done ? TaybahColors.surfaceMuted : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: done
                          ? TaybahColors.border
                          : TaybahColors.primary.withAlpha(40),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      if (!done) {
                        HapticFeedback.lightImpact();
                        setState(() => _remainingCounts[i]--);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            text,
                            style: GoogleFonts.amiri(
                              fontSize: 20,
                              height: 1.9,
                              color: done
                                  ? TaybahColors.textMuted
                                  : TaybahColors.textPrimary,
                            ),
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: TaybahColors.primaryTint,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                description,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: TaybahColors.primaryDark,
                                  height: 1.4,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ],
                          if (reference.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              reference,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: TaybahColors.gold,
                                fontWeight: FontWeight.bold,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: done
                                      ? const Color(0xFFDCFCE7)
                                      : TaybahColors.primaryTint,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  done
                                      ? 'مكتمل ✓'
                                      : 'المتبقي: ${_remainingCounts[i]}',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: done
                                        ? const Color(0xFF15803D)
                                        : TaybahColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy_rounded,
                                      size: 18,
                                    ),
                                    color: TaybahColors.textMuted,
                                    tooltip: 'نسخ الذكر',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: text));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('تم نسخ الذكر'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                  if (!done)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: TaybahColors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'المس للعد',
                                        style: GoogleFonts.cairo(
                                          fontSize: 11,
                                          color: TaybahColors.textMuted,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
