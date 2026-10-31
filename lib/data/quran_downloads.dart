import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'quran_audio.dart';

/// تحميل التلاوات للاستماع بدون إنترنت.
/// الملفات تُحفظ في: <مجلد التطبيق>/quran_audio/<معرف القارئ>/001.mp3
class QuranDownloads extends ChangeNotifier {
  QuranDownloads._();
  static final QuranDownloads instance = QuranDownloads._();

  static bool get supported => !kIsWeb;

  Directory? _root;

  /// السور المحمّلة لكل قارئ.
  final Map<String, Set<int>> _done = {};

  /// تقدم التحميل الجاري: مفتاح "قارئ:سورة" → نسبة 0..1
  final Map<String, double> _progress = {};

  /// قائمة انتظار تحميل المصحف كاملاً.
  final List<(QuranReciter, int)> _queue = [];
  bool _running = false;
  bool _cancelAll = false;
  http.Client? _client;

  Future<Directory> _dir(String reciterId) async {
    _root ??= Directory(
        '${(await getApplicationDocumentsDirectory()).path}/quran_audio');
    final d = Directory('${_root!.path}/$reciterId');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  String _name(int surah) => '${surah.toString().padLeft(3, '0')}.mp3';

  /// يقرأ الملفات الموجودة على الجهاز لقارئ معيّن.
  Future<void> scan(QuranReciter r) async {
    if (!supported) return;
    try {
      final d = await _dir(r.id);
      final set = <int>{};
      await for (final f in d.list()) {
        final n = f.uri.pathSegments.last;
        if (n.endsWith('.mp3')) {
          final id = int.tryParse(n.replaceAll('.mp3', ''));
          if (id != null) set.add(id);
        }
      }
      _done[r.id] = set;
      notifyListeners();
    } catch (_) {}
  }

  bool isDownloaded(QuranReciter r, int surah) =>
      _done[r.id]?.contains(surah) ?? false;

  int downloadedCount(QuranReciter r) => _done[r.id]?.length ?? 0;

  double? progressOf(QuranReciter r, int surah) => _progress['${r.id}:$surah'];

  bool get isBusy => _running;
  int get queueLength => _queue.length;

  /// مسار الملف المحلي إن كانت السورة محمّلة.
  Future<String?> localPath(QuranReciter r, int surah) async {
    if (!supported || !isDownloaded(r, surah)) return null;
    final f = File('${(await _dir(r.id)).path}/${_name(surah)}');
    return await f.exists() ? f.path : null;
  }

  /// تحميل سورة واحدة.
  Future<void> download(QuranReciter r, int surah) async {
    if (!supported || isDownloaded(r, surah)) return;
    _queue.add((r, surah));
    _pump();
  }

  /// تحميل المصحف كاملاً لهذا القارئ.
  Future<void> downloadAll(QuranReciter r) async {
    if (!supported) return;
    await scan(r);
    for (var s = 1; s <= 114; s++) {
      if (!isDownloaded(r, s) && !_queue.any((q) => q.$1.id == r.id && q.$2 == s)) {
        _queue.add((r, s));
      }
    }
    notifyListeners();
    _pump();
  }

  void cancelAll() {
    _cancelAll = true;
    _queue.clear();
    _client?.close();
    notifyListeners();
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    _cancelAll = false;
    notifyListeners();
    while (_queue.isNotEmpty && !_cancelAll) {
      final (r, s) = _queue.removeAt(0);
      await _fetch(r, s);
    }
    _running = false;
    _progress.clear();
    notifyListeners();
  }

  Future<void> _fetch(QuranReciter r, int surah) async {
    final key = '${r.id}:$surah';
    final dir = await _dir(r.id);
    final part = File('${dir.path}/${_name(surah)}.part');
    final target = File('${dir.path}/${_name(surah)}');
    _progress[key] = 0;
    notifyListeners();
    _client = http.Client();
    try {
      final res = await _client!.send(http.Request('GET', Uri.parse(r.urlForSurah(surah))));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final total = res.contentLength ?? 0;
      final sink = part.openWrite();
      var got = 0;
      var lastNotify = DateTime.now();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0 &&
            DateTime.now().difference(lastNotify).inMilliseconds > 250) {
          _progress[key] = got / total;
          lastNotify = DateTime.now();
          notifyListeners();
        }
      }
      await sink.close();
      if (total > 0 && got < total) throw const HttpException('incomplete');
      await part.rename(target.path);
      (_done[r.id] ??= {}).add(surah);
    } catch (e) {
      debugPrint('Quran download failed ($key): $e');
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
    } finally {
      _client?.close();
      _client = null;
      _progress.remove(key);
      notifyListeners();
    }
  }

  /// حذف سورة محمّلة.
  Future<void> delete(QuranReciter r, int surah) async {
    try {
      final f = File('${(await _dir(r.id)).path}/${_name(surah)}');
      if (await f.exists()) await f.delete();
    } catch (_) {}
    _done[r.id]?.remove(surah);
    notifyListeners();
  }

  /// حذف كل تلاوات القارئ من الجهاز.
  Future<void> deleteAll(QuranReciter r) async {
    try {
      final d = await _dir(r.id);
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
    _done[r.id] = {};
    notifyListeners();
  }

  /// المساحة المستعملة لقارئ (بالميجابايت).
  Future<double> sizeMb(QuranReciter r) async {
    if (!supported) return 0;
    var bytes = 0;
    try {
      final d = await _dir(r.id);
      await for (final f in d.list()) {
        if (f is File) bytes += await f.length();
      }
    } catch (_) {}
    return bytes / (1024 * 1024);
  }
}
