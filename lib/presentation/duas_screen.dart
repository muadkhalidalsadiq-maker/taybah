import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../data/asset_loader.dart';

class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key});

  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen> {
  List<dynamic> _duas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await AssetLoader.loadDuas();
    if (mounted) {
      setState(() {
        _duas = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaybahColors.background,
      appBar: AppBar(
        title: Text(
          'أدعية الأنبياء والمرسلين',
          style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TaybahColors.primary),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _duas.length,
              separatorBuilder: (_, index) => const SizedBox(height: 14),
              itemBuilder: (ctx, i) {
                final dua = _duas[i];
                final prophet = dua['prophet'] ?? '';
                final text = dua['dua'] ?? '';
                final surah = dua['surah'] ?? '';

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: TaybahColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Prophet badge & Copy icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: TaybahColors.primaryTint,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: TaybahColors.primary.withAlpha(40),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.auto_stories_rounded,
                                  size: 16,
                                  color: TaybahColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'دعاء $prophet',
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    color: TaybahColors.primaryDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            color: TaybahColors.textMuted,
                            tooltip: 'نسخ الدعاء',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم نسخ الدعاء المستجاب'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Dua text
                      Text(
                        text,
                        style: GoogleFonts.amiri(
                          fontSize: 22,
                          height: 2.0,
                          color: TaybahColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                      ),

                      const SizedBox(height: 12),

                      // Source / Surah
                      Row(
                        children: [
                          const Icon(
                            Icons.bookmark_outline_rounded,
                            size: 16,
                            color: TaybahColors.gold,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            surah,
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
                );
              },
            ),
    );
  }
}
