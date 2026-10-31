import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme.dart';
import '../../data/adhan_voices.dart';
import '../../data/notification_service.dart';

/// نافذة اختيار صوت المؤذن مع معاينة فورية لكل صوت.
class AdhanVoicePickerSheet extends StatefulWidget {
  const AdhanVoicePickerSheet({super.key});

  /// تعرض النافذة وترجع الصوت المختار (أو null إذا أُغلقت بدون تغيير).
  static Future<AdhanVoice?> show(BuildContext context) {
    return showModalBottomSheet<AdhanVoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdhanVoicePickerSheet(),
    );
  }

  @override
  State<AdhanVoicePickerSheet> createState() => _AdhanVoicePickerSheetState();
}

class _AdhanVoicePickerSheetState extends State<AdhanVoicePickerSheet> {
  String _selectedId = AdhanVoices.defaultId;
  String? _playingId;
  bool _loading = false;
  String _previewPrayer = 'Dhuhr';
  StreamSubscription<PlayerState>? _sub;

  final _service = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    AdhanVoices.getSelected().then((v) {
      if (mounted) setState(() => _selectedId = v.id);
    });
    _sub = _service.adhanAudioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed ||
          (!state.playing && state.processingState == ProcessingState.idle)) {
        setState(() => _playingId = null);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _service.stopAdhanAudio();
    super.dispose();
  }

  Future<void> _togglePreview(AdhanVoice voice) async {
    HapticFeedback.selectionClick();
    if (_playingId == voice.id) {
      await _service.stopAdhanAudio();
      setState(() => _playingId = null);
      return;
    }
    setState(() {
      _playingId = voice.id;
      _loading = true;
    });
    await _service.previewVoice(voice.id, prayerKey: _previewPrayer);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _select(AdhanVoice voice) async {
    HapticFeedback.mediumImpact();
    setState(() => _selectedId = voice.id);
    await _service.stopAdhanAudio();
    await _service.setAdhanVoice(voice.id);
    if (mounted) Navigator.pop(context, voice);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = TaybahColors.isDark;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: TaybahColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottom),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [TaybahColors.primaryAccent, TaybahColors.forest],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.record_voice_over_rounded,
                    color: TaybahColors.goldLight, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'صوت الأذان',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: TaybahColors.textPrimary,
                      ),
                    ),
                    Text(
                      'يبدأ كل أذان بعبارة «حان الآن موعد أذان صلاة ...»',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        color: TaybahColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // اختيار الصلاة للمعاينة (الفجر يختلف بـ«الصلاة خير من النوم»)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in AdhanVoices.adhanPrayers)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(
                        NotificationService.prayerNames[p]!,
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _previewPrayer == p
                              ? Colors.white
                              : TaybahColors.textSecondary,
                        ),
                      ),
                      selected: _previewPrayer == p,
                      showCheckmark: false,
                      selectedColor: TaybahColors.primary,
                      backgroundColor: TaybahColors.surfaceMuted,
                      side: BorderSide(color: TaybahColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onSelected: (_) async {
                        setState(() => _previewPrayer = p);
                        final playing = _playingId;
                        if (playing != null) {
                          await _service.previewVoice(playing, prayerKey: p);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: AdhanVoices.all.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final voice = AdhanVoices.all[i];
                final isSelected = voice.id == _selectedId;
                final isPlaying = voice.id == _playingId;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? TaybahColors.primaryTint
                        : TaybahColors.surfaceMuted.withAlpha(isDark ? 255 : 140),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? TaybahColors.gold
                          : TaybahColors.border,
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _select(voice),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          // زر المعاينة
                          Material(
                            color: isPlaying
                                ? TaybahColors.gold
                                : TaybahColors.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _togglePreview(voice),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: isPlaying && _loading
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        isPlaying
                                            ? Icons.stop_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  voice.name,
                                  style: GoogleFonts.cairo(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: TaybahColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  isPlaying ? 'يُشغَّل الآن…' : voice.subtitle,
                                  style: GoogleFonts.cairo(
                                    fontSize: 11.5,
                                    color: isPlaying
                                        ? TaybahColors.gold
                                        : TaybahColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: isSelected
                                ? const Icon(Icons.check_circle_rounded,
                                    key: ValueKey('on'),
                                    color: TaybahColors.gold,
                                    size: 26)
                                : Icon(Icons.radio_button_unchecked_rounded,
                                    key: const ValueKey('off'),
                                    color: TaybahColors.textMuted,
                                    size: 24),
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
