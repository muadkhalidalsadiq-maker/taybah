import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../core/theme.dart';
import '../data/asset_loader.dart';
import '../data/quran_audio.dart';
import '../data/shared_prefs_helper.dart';

class SurahReaderScreen extends StatefulWidget {
  final Map<String, dynamic> surahMeta;
  final int? initialVerseId;

  const SurahReaderScreen({
    super.key,
    required this.surahMeta,
    this.initialVerseId,
  });

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _surahData;
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  bool _audioReady = false; // تم تحميل مصدر التلاوة وجاهز للتشغيل/الاستكمال
  QuranReciter _reciter = QuranAudio.reciters.first;
  double _fontSize = 26.0;
  bool _isMushafMode = true; // true: continuous mushaf, false: verse-by-verse

  @override
  void initState() {
    super.initState();
    _loadSurah();
    _loadSettings();

    QuranAudio.getSelectedReciter().then((r) {
      if (mounted) setState(() => _reciter = r);
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        // انتهت السورة: نرجع للبداية ونوقف التشغيل
        _audioPlayer.pause();
        _audioPlayer.seek(Duration.zero);
      }
      setState(() {
        _isPlaying = state.playing &&
            state.processingState != ProcessingState.completed;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final size = await SharedPrefsHelper.instance.getQuranFontSize();
    if (mounted) setState(() => _fontSize = size);
  }

  Future<void> _loadSurah() async {
    final sId = widget.surahMeta['id'] as int;
    final fullData = await AssetLoader.loadSurahVerses(sId);
    if (mounted) {
      setState(() {
        _surahData = fullData;
        _isLoading = false;
        if (widget.initialVerseId != null) {
          _isMushafMode = false;
        }
      });

      // Save bookmark as last read
      SharedPrefsHelper.instance.setLastRead(
        surahId: sId,
        surahName: widget.surahMeta['name'] ?? '',
        verseId: widget.initialVerseId ?? 1,
        jozz: widget.surahMeta['jozz'] ?? 1,
      );

      if (widget.initialVerseId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final targetIdx = widget.initialVerseId! - 1;
            final offset = (targetIdx * 150.0).clamp(0.0, _scrollController.position.maxScrollExtent);
            _scrollController.animateTo(
              offset,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    }
  }

  Future<void> _toggleAudio() async {
    if (_isLoadingAudio) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    // استكمال التلاوة من حيث توقفت بدون إعادة التحميل
    if (_audioReady) {
      _audioPlayer.play();
      return;
    }

    setState(() => _isLoadingAudio = true);
    try {
      final sId = (widget.surahMeta['id'] as num).toInt();
      await _audioPlayer
          .setUrl(_reciter.urlForSurah(sId))
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _audioReady = true;
        _isLoadingAudio = false;
      });
      // لا ننتظر play() لأنها لا تنتهي إلا بانتهاء التلاوة
      _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
          _audioReady = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر تشغيل تلاوة ${_reciter.name}. تأكد من الاتصال بالإنترنت أو جرّب قارئاً آخر.',
              style: GoogleFonts.cairo(fontSize: 13),
            ),
            action: SnackBarAction(
              label: 'تغيير القارئ',
              onPressed: _showReciterPicker,
            ),
          ),
        );
      }
    }
  }

  Future<void> _changeReciter(QuranReciter reciter) async {
    await QuranAudio.setSelectedReciter(reciter.id);
    await _audioPlayer.stop();
    if (!mounted) return;
    setState(() {
      _reciter = reciter;
      _audioReady = false;
      _isPlaying = false;
    });
    await _toggleAudio();
  }

  void _showReciterPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? TaybahColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text(
              'اختر القارئ • رواية قالون عن نافع',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in QuranAudio.reciters)
                    ListTile(
                      leading: Icon(
                        r.id == _reciter.id
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: r.id == _reciter.id
                            ? TaybahColors.gold
                            : (isDark
                                ? TaybahColors.darkTextMuted
                                : TaybahColors.textMuted),
                      ),
                      title: Text(
                        r.name,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: r.id == _reciter.id
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isDark
                              ? TaybahColors.darkTextPrimary
                              : TaybahColors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _changeReciter(r);
                      },
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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$sec' : '$m:$sec';
  }

  /// شريط مشغّل التلاوة أسفل الشاشة
  Widget _buildAudioBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? TaybahColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<Duration>(
                stream: _audioPlayer.positionStream,
                builder: (context, snapshot) {
                  final total = _audioPlayer.duration ?? Duration.zero;
                  var position = snapshot.data ?? Duration.zero;
                  if (position > total) position = total;
                  final maxMs = total.inMilliseconds.toDouble();
                  return Row(
                    children: [
                      Text(
                        _formatDuration(position),
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: isDark
                              ? TaybahColors.darkTextMuted
                              : TaybahColors.textMuted,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                          ),
                          child: Slider(
                            min: 0,
                            max: maxMs > 0 ? maxMs : 1.0,
                            value: maxMs > 0
                                ? position.inMilliseconds
                                    .toDouble()
                                    .clamp(0.0, maxMs)
                                    .toDouble()
                                : 0.0,
                            activeColor: TaybahColors.gold,
                            inactiveColor: isDark
                                ? TaybahColors.darkBorder
                                : TaybahColors.primaryLight,
                            onChanged: maxMs > 0
                                ? (v) => _audioPlayer
                                    .seek(Duration(milliseconds: v.round()))
                                : null,
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(total),
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: isDark
                              ? TaybahColors.darkTextMuted
                              : TaybahColors.textMuted,
                        ),
                      ),
                    ],
                  );
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showReciterPicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.record_voice_over_rounded,
                              size: 18,
                              color: TaybahColors.gold,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _reciter.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? TaybahColors.darkTextPrimary
                                      : TaybahColors.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                              color: isDark
                                  ? TaybahColors.darkTextMuted
                                  : TaybahColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'رجوع 10 ثوانٍ',
                    icon: const Icon(Icons.replay_10_rounded),
                    onPressed: () {
                      final target =
                          _audioPlayer.position - const Duration(seconds: 10);
                      _audioPlayer.seek(
                        target < Duration.zero ? Duration.zero : target,
                      );
                    },
                  ),
                  IconButton(
                    tooltip: _isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                    iconSize: 40,
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      color: isDark
                          ? TaybahColors.goldLight
                          : TaybahColors.primary,
                    ),
                    onPressed: _toggleAudio,
                  ),
                  IconButton(
                    tooltip: 'تقديم 10 ثوانٍ',
                    icon: const Icon(Icons.forward_10_rounded),
                    onPressed: () {
                      final total = _audioPlayer.duration;
                      var target =
                          _audioPlayer.position + const Duration(seconds: 10);
                      if (total != null && target > total) target = total;
                      _audioPlayer.seek(target);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFontSizeDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? TaybahColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'حجم خط القرآن الكريم',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'أصغر',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: 20.0,
                        max: 42.0,
                        divisions: 11,
                        activeColor: TaybahColors.gold,
                        inactiveColor: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.primaryTint,
                        onChanged: (val) {
                          setModalState(() => _fontSize = val);
                          setState(() => _fontSize = val);
                          SharedPrefsHelper.instance.setQuranFontSize(val);
                        },
                      ),
                    ),
                    Text(
                      'أكبر',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: GoogleFonts.amiri(
                    fontSize: _fontSize,
                    color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surahName = widget.surahMeta['name'] ?? '';
    final surahId = widget.surahMeta['id'] ?? 1;
    final typeAr = widget.surahMeta['type_ar'] ??
        (widget.surahMeta['type'] == 'medinan' ? 'مدنية' : 'مكية');
    final versesCount = widget.surahMeta['total_verses'] ??
        (_surahData?['verses'] as List?)?.length ??
        0;

    return Scaffold(
      bottomNavigationBar: _audioReady ? _buildAudioBar() : null,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'سورة $surahName',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'رواية قالون عن نافع • $typeAr • $versesCount آية',
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: Theme.of(context).brightness == Brightness.dark
                    ? TaybahColors.darkTextMuted
                    : TaybahColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isMushafMode
                  ? Icons.format_list_bulleted_rounded
                  : Icons.menu_book_rounded,
            ),
            tooltip: _isMushafMode ? 'عرض آية بآية' : 'عرض المصحف المتتابع',
            onPressed: () => setState(() => _isMushafMode = !_isMushafMode),
          ),
          IconButton(
            icon: const Icon(Icons.format_size_rounded),
            tooltip: 'تغيير حجم الخط',
            onPressed: _showFontSizeDialog,
          ),
          IconButton(
            icon: _isLoadingAudio
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: TaybahColors.primary,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    size: 28,
                    color: TaybahColors.gold,
                  ),
            tooltip: 'تلاوة السورة (${_reciter.name} - قالون)',
            onPressed: _toggleAudio,
          ),

          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TaybahColors.primary),
            )
          : _isMushafMode
              ? _buildContinuousMushafView(surahId)
              : _buildVerseByVerseView(surahId),
    );
  }

  Widget _buildContinuousMushafView(int surahId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final verses = (_surahData?['verses'] as List<dynamic>?) ?? [];

    final StringBuffer fullText = StringBuffer();
    for (var verse in verses) {
      final vId = verse['id'];
      final text = (verse['text'] as String).trim();
      fullText.write('$text \u06DD$vId ');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? TaybahColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? TaybahColors.darkBorder : TaybahColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 8),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          children: [
            // Surah Header Ornament
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.primaryTint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? TaybahColors.gold.withAlpha(80) : TaybahColors.primary.withAlpha(50),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'سورة ${widget.surahMeta['name']}',
                    style: GoogleFonts.amiri(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
                    ),
                  ),
                  Text(
                    'رواية قالون عن نافع المدني',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: TaybahColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Bismillah
            if (surahId != 1 && surahId != 9)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: GoogleFonts.amiri(
                    fontSize: _fontSize + 2,
                    fontWeight: FontWeight.bold,
                    color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Quran Verses Text
            SelectableText(
              fullText.toString(),
              style: GoogleFonts.amiri(
                fontSize: _fontSize,
                color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                height: 2.3,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.justify,
              textDirection: TextDirection.rtl,
            ),

            const SizedBox(height: 24),

            // End ornament
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 1,
                  width: 60,
                  color: TaybahColors.border,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'صدق الله العظيم',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: TaybahColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  height: 1,
                  width: 60,
                  color: TaybahColors.border,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerseByVerseView(int surahId) {
    final verses = (_surahData?['verses'] as List<dynamic>?) ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: verses.length + (surahId != 1 && surahId != 9 ? 1 : 0),
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, index) {
        // Bismillah row for surahs other than Fatiha and Tawbah
        if (surahId != 1 && surahId != 9 && index == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              style: GoogleFonts.amiri(
                fontSize: _fontSize,
                fontWeight: FontWeight.bold,
                color: isDark ? TaybahColors.goldLight : TaybahColors.primaryDark,
              ),
            ),
          );
        }

        final actualIndex = (surahId != 1 && surahId != 9) ? index - 1 : index;
        final verse = verses[actualIndex];
        final vId = verse['id'] as int;
        final text = (verse['text'] as String).trim();
        final isTarget = widget.initialVerseId == vId;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isTarget
                ? (isDark ? const Color(0xFF1E3F28) : TaybahColors.primaryTint)
                : (isDark ? TaybahColors.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isTarget
                  ? TaybahColors.gold
                  : (isDark ? TaybahColors.darkBorder : TaybahColors.border),
              width: isTarget ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isTarget
                          ? TaybahColors.gold
                          : (isDark ? TaybahColors.darkSurfaceMuted : TaybahColors.primaryLight),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$vId',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isTarget
                              ? Colors.black
                              : (isDark ? TaybahColors.goldLight : TaybahColors.primaryDark),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share_rounded, size: 18),
                        color: TaybahColors.gold,
                        tooltip: 'مشاركة الآية',
                        onPressed: () => _showShareVerseModal(context, vId, text),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        color: isDark ? TaybahColors.darkTextMuted : TaybahColors.textMuted,
                        tooltip: 'نسخ الآية',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: '﴿$text﴾ [${widget.surahMeta['name']}: $vId]'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم نسخ الآية الكريمة', style: GoogleFonts.cairo()),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                text,
                style: GoogleFonts.amiri(
                  fontSize: _fontSize,
                  color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.textPrimary,
                  height: 2.1,
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShareVerseModal(BuildContext context, int vId, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surahName = widget.surahMeta['name'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? TaybahColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'مشاركة الآية الكريمة',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? TaybahColors.darkTextPrimary : TaybahColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            // Card Preview
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [TaybahColors.darkSurfaceMuted, TaybahColors.darkSurface]
                      : [TaybahColors.primary, TaybahColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: TaybahColors.gold.withAlpha(120), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                    style: GoogleFonts.amiri(
                      fontSize: 16,
                      color: TaybahColors.goldLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '﴿ $text ﴾',
                    style: GoogleFonts.amiri(
                      fontSize: 20,
                      color: Colors.white,
                      height: 1.9,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'سورة $surahName | آية $vId',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: TaybahColors.goldLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'تطبيق طـيـبـة (قالون)',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final shareText = '﴿ $text ﴾\n'
                          '[سورة $surahName - آية $vId - رواية قالون]\n\n'
                          'تطبيق طيبة - الرفيق الإسلامي في ليبيا';
                      Clipboard.setData(ClipboardData(text: shareText));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم نسخ نص الآية مع التوثيق للمشاركة', style: GoogleFonts.cairo()),
                          backgroundColor: TaybahColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text('نسخ للمشاركة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
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
}

