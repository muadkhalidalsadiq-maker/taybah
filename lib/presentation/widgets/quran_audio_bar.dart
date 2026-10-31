import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../data/quran_audio.dart';
import '../../data/quran_player.dart';

String _fmt(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// شريط التلاوة: يظهر أسفل شاشات القرآن عند تشغيل أي سورة.
class QuranAudioBar extends StatelessWidget {
  const QuranAudioBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = QuranPlayer.instance;
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final visible = player.isActive || player.error != null;
        return AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: visible ? _Bar(player: player) : const SizedBox(width: double.infinity),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  final QuranPlayer player;
  const _Bar({required this.player});

  @override
  Widget build(BuildContext context) {
    final isDark = TaybahColors.isDark;
    final id = player.surahId;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF14281D), Color(0xFF0B1711)]
                : const [TaybahColors.primaryAccent, TaybahColors.forest],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? TaybahColors.darkBorder : Colors.white.withAlpha(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 90 : 45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (player.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: TaybahColors.goldLight, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        player.error!,
                        style: GoogleFonts.cairo(
                            fontSize: 11.5, color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: () => player.playSurah(id ?? 1),
                      child: Text('إعادة',
                          style: GoogleFonts.cairo(
                              color: TaybahColors.goldLight,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                // معلومات السورة والقارئ
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => ReciterPickerSheet.show(context),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.graphic_eq_rounded,
                              color: TaybahColors.goldLight),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                id == null
                                    ? 'تلاوة القرآن الكريم'
                                    : 'سورة ${player.surahName(id)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      player.reciter.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.cairo(
                                        fontSize: 11.5,
                                        color: TaybahColors.goldLight,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.expand_more_rounded,
                                      size: 16, color: TaybahColors.goldLight),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _iconBtn(
                  icon: Icons.more_horiz_rounded,
                  tooltip: 'خيارات التلاوة',
                  onTap: () => _showOptions(context),
                ),
                _iconBtn(
                  icon: Icons.close_rounded,
                  tooltip: 'إيقاف وإغلاق',
                  onTap: player.stop,
                ),
              ],
            ),
            // شريط التقدم
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final total = player.duration ?? Duration.zero;
                final max = total.inMilliseconds.toDouble();
                final value = max <= 0
                    ? 0.0
                    : pos.inMilliseconds.clamp(0, total.inMilliseconds).toDouble();
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                  children: [
                    Text(_fmt(pos),
                        style: GoogleFonts.cairo(
                            fontSize: 10.5, color: Colors.white70)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14),
                          activeTrackColor: TaybahColors.goldLight,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: TaybahColors.goldLight,
                        ),
                        child: Slider(
                          value: value,
                          max: max <= 0 ? 1 : max,
                          onChanged: max <= 0
                              ? null
                              : (v) => player
                                  .seek(Duration(milliseconds: v.toInt())),
                        ),
                      ),
                    ),
                    Text(_fmt(total),
                        style: GoogleFonts.cairo(
                            fontSize: 10.5, color: Colors.white70)),
                  ],
                  ),
                );
              },
            ),
            // أزرار التحكم (اتجاه وسائط قياسي من اليسار لليمين)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _iconBtn(
                    icon: player.sleepAt != null
                        ? Icons.bedtime_rounded
                        : Icons.bedtime_outlined,
                    tooltip: 'مؤقت النوم',
                    color: player.sleepAt != null
                        ? TaybahColors.goldLight
                        : Colors.white54,
                    onTap: () => _showSleepTimer(context),
                  ),
                  _iconBtn(
                    icon: Icons.skip_previous_rounded,
                    tooltip: 'السورة السابقة',
                    onTap: player.previous,
                  ),
                  _iconBtn(
                    icon: Icons.replay_10_rounded,
                    tooltip: 'رجوع 10 ثوانٍ',
                    onTap: () => player.seekBy(-10),
                  ),
                  _playButton(),
                  _iconBtn(
                    icon: Icons.forward_10_rounded,
                    tooltip: 'تقديم 10 ثوانٍ',
                    onTap: () => player.seekBy(10),
                  ),
                  _iconBtn(
                    icon: Icons.skip_next_rounded,
                    tooltip: 'السورة التالية',
                    onTap: player.next,
                  ),
                  _iconBtn(
                    icon: player.repeat == QuranRepeat.surah
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    tooltip: switch (player.repeat) {
                      QuranRepeat.off => 'بدون تكرار',
                      QuranRepeat.surah => 'تكرار السورة',
                      QuranRepeat.all => 'تكرار المصحف',
                    },
                    color: player.repeat == QuranRepeat.off
                        ? Colors.white54
                        : TaybahColors.goldLight,
                    onTap: player.cycleRepeat,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playButton() {
    return Material(
      color: TaybahColors.goldLight,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          player.togglePlay();
        },
        child: SizedBox(
          width: 48,
          height: 48,
          child: player.isBuffering
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: TaybahColors.forest),
                )
              : Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: TaybahColors.forest,
                  size: 30,
                ),
        ),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: color, size: 24),
      onPressed: onTap,
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AnimatedBuilder(
        animation: player,
        builder: (ctx, _) => _SheetFrame(
          title: 'خيارات التلاوة',
          children: [
            ListTile(
              leading: Icon(Icons.record_voice_over_rounded,
                  color: TaybahColors.primary),
              title: Text('تغيير القارئ',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: TaybahColors.textPrimary)),
              subtitle: Text(player.reciter.name,
                  style: GoogleFonts.cairo(color: TaybahColors.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                ReciterPickerSheet.show(context);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('سرعة التلاوة',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: TaybahColors.textPrimary)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final s in const [0.75, 1.0, 1.25, 1.5])
                    ChoiceChip(
                      label: Text('×$s',
                          style: GoogleFonts.cairo(
                              color: player.speed == s
                                  ? Colors.white
                                  : TaybahColors.textSecondary)),
                      selected: player.speed == s,
                      showCheckmark: false,
                      selectedColor: TaybahColors.primary,
                      backgroundColor: TaybahColors.surfaceMuted,
                      onSelected: (_) => player.setSpeed(s),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSleepTimer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetFrame(
        title: 'مؤقت النوم',
        children: [
          for (final m in const [10, 15, 30, 45, 60])
            ListTile(
              leading: Icon(Icons.timer_outlined, color: TaybahColors.primary),
              title: Text('إيقاف التلاوة بعد $m دقيقة',
                  style: GoogleFonts.cairo(color: TaybahColors.textPrimary)),
              onTap: () {
                player.setSleepTimer(Duration(minutes: m));
                Navigator.pop(ctx);
              },
            ),
          if (player.sleepAt != null)
            ListTile(
              leading: const Icon(Icons.timer_off_outlined,
                  color: Colors.redAccent),
              title: Text('إلغاء المؤقت',
                  style: GoogleFonts.cairo(color: Colors.redAccent)),
              onTap: () {
                player.cancelSleepTimer();
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SheetFrame({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TaybahColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
          top: 10, bottom: 12 + MediaQuery.of(context).padding.bottom),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(title,
                style: GoogleFonts.cairo(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: TaybahColors.textPrimary)),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// اختيار القارئ: قراء قالون ثم قراء حفص، مع بحث.
class ReciterPickerSheet extends StatefulWidget {
  const ReciterPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReciterPickerSheet(),
    );
  }

  @override
  State<ReciterPickerSheet> createState() => _ReciterPickerSheetState();
}

class _ReciterPickerSheetState extends State<ReciterPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final player = QuranPlayer.instance;
    final current = player.reciter.id;
    final groups = [
      for (final r in QuranRiwaya.values)
        (
          r,
          QuranAudio.byRiwaya(r)
              .where((e) => _query.isEmpty || e.name.contains(_query))
              .toList()
        ),
    ];

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: TaybahColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
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
          Text('اختر القارئ',
              style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: TaybahColors.textPrimary)),
          Text('المصحف المكتوب في التطبيق برواية قالون عن نافع',
              style: GoogleFonts.cairo(
                  fontSize: 11.5, color: TaybahColors.textMuted)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            style: GoogleFonts.cairo(color: TaybahColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'ابحث عن قارئ...',
              prefixIcon: Icon(Icons.search_rounded, color: TaybahColors.textMuted),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final (riwaya, list) in groups)
                  if (list.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: TaybahColors.gold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(riwaya.label,
                              style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: TaybahColors.gold)),
                        ],
                      ),
                    ),
                    for (final r in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: r.id == current
                              ? TaybahColors.primaryTint
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: r.id == current
                                    ? TaybahColors.gold
                                    : TaybahColors.border,
                              ),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: TaybahColors.primary,
                              child: Text(
                                r.name.characters.first,
                                style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(r.name,
                                style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: TaybahColors.textPrimary)),
                            trailing: r.id == current
                                ? const Icon(Icons.check_circle_rounded,
                                    color: TaybahColors.gold)
                                : null,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(context);
                              player.changeReciter(r);
                            },
                          ),
                        ),
                      ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
