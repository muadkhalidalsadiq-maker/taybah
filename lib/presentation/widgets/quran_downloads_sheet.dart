import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../data/quran_downloads.dart';
import '../../data/quran_player.dart';
import 'quran_audio_bar.dart';

/// إدارة تحميل التلاوات للاستماع بدون إنترنت (للقارئ المختار).
class QuranDownloadsSheet extends StatefulWidget {
  const QuranDownloadsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuranDownloadsSheet(),
    );
  }

  @override
  State<QuranDownloadsSheet> createState() => _QuranDownloadsSheetState();
}

class _QuranDownloadsSheetState extends State<QuranDownloadsSheet> {
  final _dl = QuranDownloads.instance;
  final _player = QuranPlayer.instance;
  double _size = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await _player.loadSaved();
    await _dl.scan(_player.reciter);
    final s = await _dl.sizeMb(_player.reciter);
    if (mounted) setState(() => _size = s);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_dl, _player]),
      builder: (context, _) {
        final r = _player.reciter;
        final count = _dl.downloadedCount(r);
        final busy = _dl.isBusy;
        return Container(
          decoration: BoxDecoration(
            color: TaybahColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              18, 10, 18, 18 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: TaybahColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.download_for_offline_rounded,
                      color: TaybahColors.gold, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الاستماع بدون إنترنت',
                            style: GoogleFonts.cairo(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: TaybahColors.textPrimary)),
                        Text('حمّل التلاوات مرة واحدة واستمع في أي وقت',
                            style: GoogleFonts.cairo(
                                fontSize: 11.5,
                                color: TaybahColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Material(
                color: TaybahColors.primaryTint,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  leading: Icon(Icons.record_voice_over_rounded,
                      color: TaybahColors.primary),
                  title: Text(r.name,
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          color: TaybahColors.textPrimary)),
                  subtitle: Text(
                      '$count من 114 سورة محمّلة • ${_size.toStringAsFixed(0)} ميجابايت',
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: TaybahColors.textMuted)),
                  trailing: Text('تغيير',
                      style: GoogleFonts.cairo(
                          color: TaybahColors.gold,
                          fontWeight: FontWeight.bold)),
                  onTap: () async {
                    await ReciterPickerSheet.show(context);
                    _refresh();
                  },
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: count / 114,
                  minHeight: 8,
                  backgroundColor: TaybahColors.surfaceMuted,
                  color: TaybahColors.gold,
                ),
              ),
              if (busy) ...[
                const SizedBox(height: 8),
                Text(
                  'جارٍ التحميل… (${_dl.queueLength + 1} سورة متبقية)',
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: TaybahColors.textSecondary),
                ),
              ],
              const SizedBox(height: 14),
              if (busy)
                OutlinedButton.icon(
                  onPressed: () {
                    _dl.cancelAll();
                    _refresh();
                  },
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text('إيقاف التحميل',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                )
              else if (count < 114)
                ElevatedButton.icon(
                  onPressed: () => _dl.downloadAll(r),
                  icon: const Icon(Icons.download_rounded),
                  label: Text('تحميل المصحف كاملاً بصوت ${r.name}'),
                ),
              if (count > 0 && !busy) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    await _dl.deleteAll(r);
                    _refresh();
                  },
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent),
                  label: Text('حذف تلاوات هذا القارئ من الجهاز',
                      style: GoogleFonts.cairo(color: Colors.redAccent)),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'المصحف كاملاً يأخذ عادة بين 300 و900 ميجابايت حسب القارئ. يمكنك أيضاً تحميل سورة واحدة من زر التحميل بجانبها.',
                style: GoogleFonts.cairo(
                    fontSize: 11, color: TaybahColors.textMuted, height: 1.6),
              ),
            ],
          ),
        );
      },
    );
  }
}
