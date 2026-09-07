import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../data/asset_loader.dart';
import '../data/shared_prefs_helper.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> with SingleTickerProviderStateMixin {
  String _selectedCityName = 'طرابلس';
  double _cityLat = 32.8872;
  double _cityLng = 13.1913;
  double _qiblaAngle = 112.0;
  double _distanceKm = 2860.0;
  List<Map<String, dynamic>> _cities = [];
  bool _loading = true;
  late AnimationController _animController;
  late Animation<double> _pulseAnim;

  // Mecca Coordinates
  static const double _meccaLat = 21.422487;
  static const double _meccaLng = 39.826206;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final cityName = await SharedPrefsHelper.instance.getSelectedCityName();
    final cities = await AssetLoader.loadCitiesLibya();

    setState(() {
      _cities = cities;
      _selectedCityName = cityName;
    });

    _updateCityCoords(cityName);
  }

  void _updateCityCoords(String cityName) {
    Map<String, dynamic>? match;
    for (final c in _cities) {
      if (c['name'] == cityName) {
        match = c;
        break;
      }
    }

    double lat = 32.8872;
    double lng = 13.1913;
    if (match != null && match['lat'] != null && match['lng'] != null) {
      lat = (match['lat'] as num).toDouble();
      lng = (match['lng'] as num).toDouble();
    }

    final bearing = _calculateQibla(lat, lng);
    final distance = _calculateDistance(lat, lng, _meccaLat, _meccaLng);

    setState(() {
      _selectedCityName = cityName;
      _cityLat = lat;
      _cityLng = lng;
      _qiblaAngle = bearing;
      _distanceKm = distance;
      _loading = false;
    });
  }

  // Bearing from city to Mecca in degrees (0 = North, 90 = East, 180 = South, 270 = West)
  double _calculateQibla(double lat, double lng) {
    final phi1 = lat * math.pi / 180.0;
    final phi2 = _meccaLat * math.pi / 180.0;
    final deltaLambda = (_meccaLng - lng) * math.pi / 180.0;

    final y = math.sin(deltaLambda);
    final x = math.cos(phi1) * math.tan(phi2) - math.sin(phi1) * math.cos(deltaLambda);
    var qibla = math.atan2(y, x) * 180.0 / math.pi;
    return (qibla + 360.0) % 360.0;
  }

  // Great-circle distance using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth's radius in km
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  String _getDirectionText(double deg) {
    if (deg >= 22.5 && deg < 67.5) return 'شمال شرق';
    if (deg >= 67.5 && deg < 112.5) return 'شرقاً';
    if (deg >= 112.5 && deg < 157.5) return 'جنوب شرق';
    if (deg >= 157.5 && deg < 202.5) return 'جنوباً';
    if (deg >= 202.5 && deg < 247.5) return 'جنوب غرب';
    if (deg >= 247.5 && deg < 292.5) return 'غرباً';
    if (deg >= 292.5 && deg < 337.5) return 'شمال غرب';
    return 'شمالاً';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('بوصلة القبلة الشريفة'),
        actions: [
          IconButton(
            tooltip: 'تغيير المدينة',
            icon: const Icon(Icons.location_city_rounded),
            onPressed: () => _showCityPicker(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // City & Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [TaybahColors.darkSurface, TaybahColors.darkSurfaceMuted]
                            : [TaybahColors.primary, TaybahColors.primaryMedium],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: TaybahColors.primary.withAlpha(40),
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
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, color: TaybahColors.goldLight, size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      _selectedCityName,
                                      style: GoogleFonts.cairo(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'دائرة: ${_cityLat.toStringAsFixed(2)}° | خط: ${_cityLng.toStringAsFixed(2)}°',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showCityPicker(context),
                              icon: const Icon(Icons.swap_vert_rounded, size: 16, color: TaybahColors.goldLight),
                              label: Text(
                                'تغيير',
                                style: GoogleFonts.cairo(fontSize: 13, color: Colors.white),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: TaybahColors.goldLight),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildQuickStat(
                              icon: Icons.explore_rounded,
                              title: 'زاوية القبلة',
                              value: '${_qiblaAngle.toStringAsFixed(1)}°',
                              subtitle: _getDirectionText(_qiblaAngle),
                            ),
                            Container(width: 1, height: 40, color: Colors.white24),
                            _buildQuickStat(
                              icon: Icons.route_rounded,
                              title: 'المسافة إلى مكة',
                              value: '${_distanceKm.toStringAsFixed(0)} كم',
                              subtitle: 'المسجد الحرام',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // The Compass Visual Display
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: SizedBox(
                      width: 290,
                      height: 290,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Golden Decorative Ring
                          Container(
                            width: 290,
                            height: 290,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  isDark ? TaybahColors.darkSurfaceMuted : Colors.white,
                                  isDark ? TaybahColors.darkSurface : TaybahColors.surfaceMuted,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: TaybahColors.gold.withAlpha(isDark ? 50 : 35),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          // Dial Border with Gold Accents
                          Container(
                            width: 275,
                            height: 275,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: TaybahColors.gold.withAlpha(150),
                                width: 3,
                              ),
                            ),
                          ),
                          // Tick marks
                          CustomPaint(
                            size: const Size(270, 270),
                            painter: _CompassTicksPainter(isDark: isDark),
                          ),
                          // Cardinal Labels
                          Positioned(
                            top: 14,
                            child: Text(
                              'ش (N)',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 14,
                            child: Text(
                              'ج (S)',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 14,
                            child: Text(
                              'ش (E)',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            child: Text(
                              'غ (W)',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Qibla Pointer Arm (Rotated by _qiblaAngle)
                          Transform.rotate(
                            angle: _qiblaAngle * (math.pi / 180.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Kaaba Emblem at Pointer Tip
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: TaybahColors.gold,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: TaybahColors.gold.withAlpha(180),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.mosque_rounded,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                                // Needle Body
                                Container(
                                  width: 4,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [TaybahColors.gold, Colors.redAccent],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 80), // Counter balance
                              ],
                            ),
                          ),
                          // Compass Center Pivot
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: TaybahColors.primaryDark,
                              border: Border.all(color: TaybahColors.gold, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Angle Indicator Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? TaybahColors.darkSurface : TaybahColors.primaryTint,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? TaybahColors.darkBorder : TaybahColors.borderGlow,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.navigation_rounded, color: TaybahColors.primaryAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'وجه جهازك بزاوية ${_qiblaAngle.toStringAsFixed(1)}° (${_getDirectionText(_qiblaAngle)}) باتجاه الكعبة المشرفة',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Hadith / Advice Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? TaybahColors.darkSurfaceMuted : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: TaybahColors.gold, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'استقبال القبلة شرط لصحة الصلاة',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'قال الله تعالى: ﴿فَوَلِّ وَجْهَكَ شَطْرَ الْمَسْجِدِ الْحَرَامِ وَحَيْثُ مَا كُنتُمْ فَوَلُّوا وُجُوهَكُمْ شَطْرَهُ﴾ [البقرة: 144].\nيتم احتساب اتجاه القبلة بدقة فلكية بناءً على الإحداثيات الجغرافية لمدينتك المختارة.',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            height: 1.6,
                            color: isDark ? TaybahColors.darkTextSecondary : TaybahColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Column(
      children: [
        Icon(icon, color: TaybahColors.goldLight, size: 22),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.cairo(fontSize: 11, color: Colors.white70),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          subtitle,
          style: GoogleFonts.cairo(fontSize: 11, color: TaybahColors.goldLight),
        ),
      ],
    );
  }

  void _showCityPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = _cities.where((c) {
              final name = (c['name'] ?? '').toString();
              return name.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? TaybahColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(80),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'اختر المدينة لحساب اتجاه القبلة',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => setModalState(() => query = val),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن مدينة أو منطقة ليبية...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.surfaceMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final city = filtered[i];
                        final name = city['name'] ?? '';
                        final isSelected = name == _selectedCityName;
                        return ListTile(
                          title: Text(
                            name,
                            style: GoogleFonts.cairo(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? TaybahColors.gold : null,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: TaybahColors.gold)
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            _updateCityCoords(name);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CompassTicksPainter extends CustomPainter {
  final bool isDark;
  _CompassTicksPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final tickPaint = Paint()
      ..color = isDark ? Colors.white30 : Colors.black26
      ..strokeWidth = 1.0;
    final majorTickPaint = Paint()
      ..color = TaybahColors.gold
      ..strokeWidth = 2.0;

    for (int deg = 0; deg < 360; deg += 5) {
      final isMajor = deg % 30 == 0;
      final tickLength = isMajor ? 12.0 : 6.0;
      final rad = deg * (math.pi / 180.0);
      final p1 = Offset(
        center.dx + (radius - tickLength) * math.cos(rad),
        center.dy + (radius - tickLength) * math.sin(rad),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(rad),
        center.dy + radius * math.sin(rad),
      );
      canvas.drawLine(p1, p2, isMajor ? majorTickPaint : tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
