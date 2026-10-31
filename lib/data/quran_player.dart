import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'asset_loader.dart';
import 'quran_audio.dart';
import 'quran_downloads.dart';

/// مشغل الصوت الوحيد في التطبيق (just_audio_background يدعم مشغلاً واحداً فقط).
/// يُستعمل لتلاوة القرآن ولمعاينة أصوات الأذان.
class AppAudio {
  AppAudio._();
  static AudioPlayer? _player;
  static AudioPlayer get player => _player ??= AudioPlayer();

  /// يجب استدعاؤها في main قبل إنشاء المشغل.
  static Future<void> init() async {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.muadalsadiq.taybah.quran_audio',
        androidNotificationChannelName: 'تلاوة القرآن الكريم',
        androidNotificationIcon: 'drawable/ic_stat_taybah',
        androidNotificationOngoing: true,
      );
    } catch (e) {
      debugPrint('JustAudioBackground init error: $e');
    }
  }
}

enum QuranRepeat { off, surah, all }

/// تشغيل المصحف المرتل: سورة تلو سورة، مع حفظ آخر موضع وإعادة المحاولة عند ضعف الشبكة.
class QuranPlayer extends ChangeNotifier {
  QuranPlayer._() {
    _subs.add(_player.playerStateStream.listen((s) {
      if (!_ownsPlayer) return;
      _playing = s.playing;
      _buffering = s.processingState == ProcessingState.loading ||
          s.processingState == ProcessingState.buffering;
      if (s.processingState == ProcessingState.completed) {
        _playing = false;
      }
      notifyListeners();
    }));
    _subs.add(_player.currentIndexStream.listen((i) {
      if (!_ownsPlayer || i == null) return;
      final id = i + 1;
      if (id != _surahId) {
        _surahId = id;
        _saveState();
        notifyListeners();
      }
    }));
    _subs.add(_player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        if (!_ownsPlayer) return;
        _error = 'تعذر تحميل التلاوة. تحقق من الاتصال بالإنترنت.';
        _buffering = false;
        notifyListeners();
      },
    ));
  }

  static final QuranPlayer instance = QuranPlayer._();

  AudioPlayer get _player => AppAudio.player;
  final List<StreamSubscription> _subs = [];

  List<Map<String, dynamic>> _surahs = [];
  QuranReciter _reciter = QuranAudio.reciters.first;
  int? _surahId;
  bool _playing = false;
  bool _buffering = false;
  bool _loading = false;
  bool _ownsPlayer = false;
  String? _error;
  QuranRepeat _repeat = QuranRepeat.off;
  double _speed = 1.0;
  Timer? _sleepTimer;
  DateTime? _sleepAt;

  QuranReciter get reciter => _reciter;
  int? get surahId => _surahId;
  bool get isActive => _ownsPlayer && _surahId != null;
  bool get isPlaying => _ownsPlayer && _playing;
  bool get isBuffering => _ownsPlayer && (_buffering || _loading);
  String? get error => _error;
  QuranRepeat get repeat => _repeat;
  double get speed => _speed;
  DateTime? get sleepAt => _sleepAt;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedStream => _player.bufferedPositionStream;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  String surahName(int id) {
    if (id < 1 || id > _surahs.length) return 'سورة $id';
    return (_surahs[id - 1]['name'] ?? '').toString();
  }

  Future<void> _ensureMeta() async {
    if (_surahs.isEmpty) {
      try {
        _surahs = await AssetLoader.loadQuranSurahs();
      } catch (_) {}
    }
  }

  /// يحمّل القارئ المحفوظ (يُستدعى عند فتح شاشات القرآن).
  Future<void> loadSaved() async {
    _reciter = await QuranAudio.getSelectedReciter();
    await _ensureMeta();
    notifyListeners();
    QuranDownloads.instance.scan(_reciter);
  }

  /// يتخلى عن المشغل لصالح استعمال آخر (مثل معاينة الأذان).
  void releasePlayer() {
    if (!_ownsPlayer) return;
    _ownsPlayer = false;
    _playing = false;
    notifyListeners();
  }

  /// قائمة السور: الملف المحمّل على الجهاز إن وُجد، وإلا البث من الإنترنت.
  Future<List<AudioSource>> _buildPlaylist(QuranReciter r) async {
    final dl = QuranDownloads.instance;
    await dl.scan(r);
    final local = <int, String>{};
    for (var id = 1; id <= 114; id++) {
      final path = await dl.localPath(r, id);
      if (path != null) local[id] = path;
    }
    return List.generate(114, (i) {
      final id = i + 1;
      final path = local[id];
      return AudioSource.uri(
        path != null ? Uri.file(path) : Uri.parse(r.urlForSurah(id)),
        tag: MediaItem(
          id: '${r.id}_$id',
          title: 'سورة ${surahName(id)}',
          artist: r.name,
          album: 'القرآن الكريم • ${r.riwaya.label}',
        ),
      );
    });
  }

  /// تشغيل سورة (ويكمل بعدها السور التالية تلقائياً).
  Future<void> playSurah(int surahId, {QuranReciter? reciter, Duration? from}) async {
    if (_loading) return;
    surahId = surahId.clamp(1, 114);
    if (reciter != null) {
      _reciter = reciter;
      await QuranAudio.setSelectedReciter(reciter.id);
    }
    await _ensureMeta();

    // نفس السورة ونفس القارئ: استكمال فقط
    if (_ownsPlayer && _surahId == surahId && _player.audioSource != null &&
        _player.processingState != ProcessingState.idle && reciter == null) {
      _player.play();
      return;
    }

    _loading = true;
    _error = null;
    _ownsPlayer = true;
    _surahId = surahId;
    notifyListeners();

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _player.stop();
        await _player.setAudioSources(
          await _buildPlaylist(_reciter),
          initialIndex: surahId - 1,
          initialPosition: from ?? Duration.zero,
        ).timeout(const Duration(seconds: 45));
        await _player.setSpeed(_speed);
        await _applyRepeat();
        _loading = false;
        _error = null;
        notifyListeners();
        _player.play();
        _saveState();
        return;
      } catch (e) {
        debugPrint('Quran audio load error (attempt $attempt): $e');
      }
    }
    _loading = false;
    _error = 'تعذر تشغيل تلاوة ${_reciter.name}. تأكد من الاتصال بالإنترنت أو جرّب قارئاً آخر.';
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if (!isActive) {
      final saved = await _savedSurah();
      await playSurah(saved ?? 1);
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      _player.play();
    }
  }

  Future<void> pause() async {
    if (_ownsPlayer) await _player.pause();
  }

  Future<void> stop() async {
    if (_ownsPlayer) await _player.stop();
    _ownsPlayer = false;
    _playing = false;
    _surahId = null;
    cancelSleepTimer();
    notifyListeners();
  }

  Future<void> next() async {
    if (!isActive) return;
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  Future<void> previous() async {
    if (!isActive) return;
    // إذا تقدمت التلاوة أكثر من 5 ثوانٍ نعيد السورة من أولها
    if (_player.position > const Duration(seconds: 5) || !_player.hasPrevious) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  Future<void> seek(Duration d) async {
    if (!isActive) return;
    final total = _player.duration;
    var target = d < Duration.zero ? Duration.zero : d;
    if (total != null && target > total) target = total;
    await _player.seek(target);
  }

  Future<void> seekBy(int seconds) =>
      seek(_player.position + Duration(seconds: seconds));

  Future<void> changeReciter(QuranReciter r) async {
    final id = _surahId;
    _reciter = r;
    await QuranAudio.setSelectedReciter(r.id);
    notifyListeners();
    QuranDownloads.instance.scan(r);
    if (id != null && _ownsPlayer) await playSurah(id, reciter: r);
  }

  Future<void> cycleRepeat() async {
    _repeat = QuranRepeat.values[(_repeat.index + 1) % QuranRepeat.values.length];
    await _applyRepeat();
    notifyListeners();
  }

  Future<void> _applyRepeat() async {
    switch (_repeat) {
      case QuranRepeat.off:
        await _player.setLoopMode(LoopMode.off);
      case QuranRepeat.surah:
        await _player.setLoopMode(LoopMode.one);
      case QuranRepeat.all:
        await _player.setLoopMode(LoopMode.all);
    }
  }

  Future<void> setSpeed(double s) async {
    _speed = s;
    if (_ownsPlayer) await _player.setSpeed(s);
    notifyListeners();
  }

  /// مؤقت النوم: يوقف التلاوة بعد المدة المحددة.
  void setSleepTimer(Duration d) {
    _sleepTimer?.cancel();
    _sleepAt = DateTime.now().add(d);
    _sleepTimer = Timer(d, () {
      pause();
      _sleepAt = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepAt = null;
    notifyListeners();
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_surahId != null) await prefs.setInt('quran_audio_last_surah', _surahId!);
    } catch (_) {}
  }

  Future<int?> _savedSurah() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('quran_audio_last_surah');
    } catch (_) {
      return null;
    }
  }
}
