import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../data/asset_loader.dart';
import '../data/prayer_api.dart';
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
  bool _isGpsActive = false;

  // Compass Stream & Heading
  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _deviceHeading;
  bool _hasCompass = true;
  bool _wasAligned = false;

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

    _initCompass();
    _loadDataAndGps();
  }

  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (!mounted) return;
      final heading = event.heading;
      if (heading != null) {
        final relQibla = (_qiblaAngle - heading) % 360;
        final diff = (relQibla > 180 ? 360 - relQibla : relQibla).abs();
        final isAligned = diff < 4.0;

        if (isAligned && !_wasAligned) {
          HapticFeedback.mediumImpact();
          _wasAligned = true;
        } else if (!isAligned && _wasAligned) {
          _wasAligned = false;
        }

        setState(() {
          _deviceHeading = heading;
          _hasCompass = true;
        });
      }
    }, onError: (e) {
      debugPrint('Compass error: $e');
      if (mounted) setState(() => _hasCompass = false);
    });
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDataAndGps() async {
    final cityName = await SharedPrefsHelper.instance.getSelectedCityName();
    final cities = await AssetLoader.loadCitiesLibya();

    if (mounted) {
      setState(() {
        _cities = cities;
        _selectedCityName = cityName;
      });
    }

    // Attempt GPS detection first
    await _detectGpsLocation(fallbackCityName: cityName);
  }

  Future<void> _detectGpsLocation({String? fallbackCityName}) async {
    final pos = await PrayerApi.getCurrentPosition();
    if (pos != null && mounted) {
      final bearing = _calculateQibla(pos.latitude, pos.longitude);
      final distance = _calculateDistance(pos.latitude, pos.longitude, _meccaLat, _meccaLng);
      setState(() {
        _cityLat = pos.latitude;
        _cityLng = pos.longitude;
        _qiblaAngle = bearing;
        _distanceKm = distance;
        _isGpsActive = true;
        _loading = false;
      });
    } else {
      _updateCityCoords(fallbackCityName ?? _selectedCityName);
    }
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

    if (mounted) {
      setState(() {
        _selectedCityName = cityName;
        _cityLat = lat;
        _cityLng = lng;
        _qiblaAngle = bearing;
        _distanceKm = distance;
        _isGpsActive = false;
        _loading = false;
      });
    }
  }

  // Bearing from coordinates to Mecca in degrees (0 = North, 90 = East, 180 = South, 270 = West)
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
    final heading = _deviceHeading ?? 0.0;

    // Angle of needle relative to phone orientation
    final double relativeQibla = ((_qiblaAngle - heading) % 360 + 360) % 360;
    final double diffFromQibla = (relativeQibla > 180 ? 360 - relativeQibla : relativeQibla).abs();
    final bool isAligned = diffFromQibla < 4.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('بوصلة القبلة الشريفة'),
        actions: [
          IconButton(
            tooltip: 'تحديث الموقع بالـ GPS',
            icon: Icon(
              _isGpsActive ? Icons.my_location_rounded : Icons.location_searching_rounded,
              color: _isGpsActive ? TaybahColors.gold : null,
            ),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('جاري جلب إحداثيات موقعك بالـ GPS...'),
                  duration: Duration(seconds: 2),
                ),
              );
              await _detectGpsLocation();
            },
          ),
          IconButton(
            tooltip: 'تغيير المدينة يدوياً',
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
                  // City & GPS Info Card
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
                                    Icon(
                                      _isGpsActive ? Icons.gps_fixed_rounded : Icons.location_on_rounded,
                                      color: TaybahColors.goldLight,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isGpsActive ? 'موقعك الدقيق (GPS)' : _selectedCityName,
                                      style: GoogleFonts.cairo(
                                        fontSize: 20,
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isAligned
                                    ? Colors.green.withAlpha(180)
                                    : Colors.white.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isAligned ? Colors.greenAccent : Colors.white24,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAligned ? Icons.check_circle_rounded : Icons.compass_calibration_rounded,
                                    color: isAligned ? Colors.white : TaybahColors.goldLight,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isAligned ? 'مواجه للقبلة' : '${heading.toStringAsFixed(0)}° بوصلة',
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
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
                              label: 'زاوية القبلة',
                              value: '${_qiblaAngle.toStringAsFixed(1)}°',
                              subtitle: _getDirectionText(_qiblaAngle),
                              icon: Icons.explore_rounded,
                            ),
                            Container(width: 1, height: 36, color: Colors.white24),
                            _buildQuickStat(
                              label: 'المسافة لمكة',
                              value: '${_distanceKm.toStringAsFixed(0)} كم',
                              subtitle: 'مكة المكرمة',
                              icon: Icons.straighten_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Alignment Status Banner
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isAligned
                          ? Colors.green.withAlpha(35)
                          : (isDark ? TaybahColors.darkSurface : TaybahColors.primaryTint),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAligned ? Colors.green : TaybahColors.gold.withAlpha(80),
                        width: isAligned ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isAligned ? Icons.check_circle_rounded : Icons.explore_rounded,
                          color: isAligned ? Colors.green : TaybahColors.gold,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAligned
                              ? 'أنت باتجاه القبلة المشرفة تماماً ✓'
                              : (_hasCompass
                                  ? 'أدر الهاتف حتى يشير السهم الذهبي إلى الأعلى'
                                  : 'وجّه الهاتف بزاوية ${_qiblaAngle.toStringAsFixed(0)}° بالنسبة للشمال'),
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isAligned
                                ? Colors.green
                                : (isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // The Dynamic Compass Visual Display
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: SizedBox(
                      width: 290,
                      height: 290,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Golden Decorative Ring with glowing alignment
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
                                  color: (isAligned ? Colors.green : TaybahColors.gold)
                                      .withAlpha(isDark ? 80 : 50),
                                  blurRadius: isAligned ? 36 : 24,
                                  spreadRadius: isAligned ? 6 : 2,
                                ),
                              ],
                            ),
                          ),

                          // Compass Rose Dial (Rotates opposite to device heading so North stays True North)
                          Transform.rotate(
                            angle: -heading * (math.pi / 180.0),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Dial Border with Gold Accents
                                Container(
                                  width: 275,
                                  height: 275,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isAligned ? Colors.green : TaybahColors.gold.withAlpha(150),
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
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Dynamic Qibla Pointer Arm (Points towards Kaaba relative to device)
                          Transform.rotate(
                            angle: relativeQibla * (math.pi / 180.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Kaaba Emblem at Pointer Tip
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isAligned ? Colors.green : TaybahColors.gold,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isAligned ? Colors.greenAccent : TaybahColors.gold)
                                            .withAlpha(200),
                                        blurRadius: 14,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.mosque_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                // Needle Body
                                Container(
                                  width: 4,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isAligned
                                          ? [Colors.green, Colors.greenAccent]
                                          : [TaybahColors.gold, Colors.redAccent],
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
                              color: isAligned ? Colors.green.shade800 : TaybahColors.primaryDark,
                              border: Border.all(
                                color: isAligned ? Colors.greenAccent : TaybahColors.gold,
                                width: 3,
                              ),
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

                  const SizedBox(height: 24),

                  // Instructions Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? TaybahColors.darkSurface : TaybahColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: TaybahColors.gold, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'إرشادات لدقة اتجاه القبلة',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• ضع الهاتف بشكل أفقي مستوٍ في راحة يدك أو على طاولة مستوية.\n'
                          '• ابتعد عن الأجهزة الإلكترونية والمعادن لتجنب تشويش البوصلة.\n'
                          '• إذا كانت البوصلة غير دقيقة، حرّك الهاتف في الهواء على شكل رقم (8) لمعايرتها.',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : TaybahColors.textSecondary,
                            height: 1.6,
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
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: TaybahColors.goldLight, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.cairo(
            fontSize: 11,
            color: Colors.white70,
          ),
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
