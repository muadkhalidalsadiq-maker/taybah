import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../data/asset_loader.dart';
import '../../data/prayer_api.dart';
import '../../data/shared_prefs_helper.dart';

class CityPickerSheet extends StatefulWidget {
  final String currentCityName;
  final ValueChanged<Map<String, dynamic>> onCitySelected;

  const CityPickerSheet({
    super.key,
    required this.currentCityName,
    required this.onCitySelected,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String currentCityName,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CityPickerSheet(
        currentCityName: currentCityName,
        onCitySelected: (c) => Navigator.pop(ctx, c),
      ),
    );
  }

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  List<Map<String, dynamic>> _allCities = [];
  List<Map<String, dynamic>> _filteredCities = [];
  bool _isLoading = true;
  bool _isDetectingLocation = false;
  bool _isSummerTime = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCities();
    _loadSummerTime();
  }

  Future<void> _loadSummerTime() async {
    final s = await SharedPrefsHelper.instance.isSummerTime();
    if (mounted) setState(() => _isSummerTime = s);
  }

  Future<void> _loadCities() async {
    final cities = await AssetLoader.loadCitiesLibya();
    if (mounted) {
      setState(() {
        _allCities = cities;
        _filteredCities = cities;
        _isLoading = false;
      });
    }
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredCities = _allCities;
      } else {
        _filteredCities = _allCities.where((c) {
          final ar = (c['ar_name'] ?? '').toString().toLowerCase();
          final en = (c['en_name'] ?? '').toString().toLowerCase();
          return ar.contains(q) || en.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _autoDetectGPS() async {
    setState(() => _isDetectingLocation = true);
    final nearest = await PrayerApi.autoDetectAndSetNearestCity();
    setState(() => _isDetectingLocation = false);

    if (nearest != null && mounted) {
      widget.onCitySelected(nearest);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديد أقرب مدينة لموقعك: ${nearest['ar_name']}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: TaybahColors.primary,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديد الموقع، يرجى تفعيل الـ GPS.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: TaybahColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TaybahColors.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
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
                        'اختر المدينة (مواقيت الأوائل)',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: TaybahColors.textPrimary,
                        ),
                      ),
                      Text(
                        'المواقيت المعتمدة رسمياً لـ 63 مدينة ومنطقة في ليبيا',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: TaybahColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: TaybahColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // GPS Auto-detect Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDetectingLocation ? null : _autoDetectGPS,
                icon: _isDetectingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  _isDetectingLocation
                      ? 'جاري تحديد المدينة الأقرب...'
                      : 'تحديد المدينة تلقائياً حسب موقعك (GPS)',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TaybahColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Summer / Winter time toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: TaybahColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isSummerTime
                            ? Icons.wb_sunny_rounded
                            : Icons.ac_unit_rounded,
                        size: 18,
                        color: _isSummerTime
                            ? TaybahColors.gold
                            : const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isSummerTime
                            ? 'التوقيت الصيفي مفعل (الأوائل ?s=2)'
                            : 'التوقيت الشتوي مفعل (الأوائل ?s=1)',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: TaybahColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isSummerTime,
                    activeTrackColor: TaybahColors.primary,
                    onChanged: (val) async {
                      setState(() => _isSummerTime = val);
                      await SharedPrefsHelper.instance.setSummerTime(val);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'ابحث عن مدينة (مثلاً: زنتان، طرابلس، بنغازي...)',
                prefixIcon: const Icon(Icons.search, color: TaybahColors.primary),
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

          const Divider(height: 12),

          // Cities List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: TaybahColors.primary),
                  )
                : _filteredCities.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد مدينة مطابقة للبحث',
                          style: GoogleFonts.cairo(color: TaybahColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        itemCount: _filteredCities.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1, color: TaybahColors.border),
                        itemBuilder: (ctx, i) {
                          final city = _filteredCities[i];
                          final arName = city['ar_name'] ?? '';
                          final isSelected = arName == widget.currentCityName ||
                              widget.currentCityName.contains(arName);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            tileColor: isSelected
                                ? TaybahColors.primaryTint
                                : Colors.transparent,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? TaybahColors.primary
                                    : TaybahColors.surfaceMuted,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.mosque_rounded,
                                size: 18,
                                color: isSelected
                                    ? Colors.white
                                    : TaybahColors.textMuted,
                              ),
                            ),
                            title: Text(
                              arName,
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isSelected
                                    ? TaybahColors.primaryDark
                                    : TaybahColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              city['en_name'] ?? '',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: TaybahColors.textMuted,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: TaybahColors.primary,
                                  )
                                : null,
                            onTap: () async {
                              await SharedPrefsHelper.instance.setSelectedCity(
                                arName,
                                city['slug'] ?? '',
                              );
                              widget.onCitySelected(city);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
