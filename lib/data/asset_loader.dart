import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class AssetLoader {
  static List<Map<String, dynamic>>? _cachedSurahIndex;
  static List<Map<String, dynamic>>? _cachedFullQuran;
  static List<Map<String, dynamic>>? _cachedCities;
  static List<dynamic>? _cachedAdhkar;
  static List<dynamic>? _cachedHadith;
  static List<dynamic>? _cachedDuas;
  static List<dynamic>? _cachedNawafil;
  static List<dynamic>? _cachedTasbeeh;
  static List<Map<String, dynamic>>? _cachedAsmaAllah;
  static Map<String, dynamic>? _cachedRuqyah;

  /// Loads the lightweight metadata list of all 114 surahs
  static Future<List<Map<String, dynamic>>> loadQuranSurahs() async {
    if (_cachedSurahIndex != null) return _cachedSurahIndex!;
    final response = await rootBundle.loadString('assets/data/quran_surahs.json');
    final List<dynamic> decoded = json.decode(response);
    _cachedSurahIndex = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    return _cachedSurahIndex!;
  }

  /// Loads full Quran data in Qaloon narration
  static Future<List<Map<String, dynamic>>> loadFullQuran() async {
    if (_cachedFullQuran != null) return _cachedFullQuran!;
    final response = await rootBundle.loadString('assets/data/quran_qaloon.json');
    final List<dynamic> decoded = json.decode(response);
    _cachedFullQuran = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    return _cachedFullQuran!;
  }

  /// Loads verses for a specific surah (1-114) in Qaloon narration
  static Future<Map<String, dynamic>?> loadSurahVerses(int surahId) async {
    final allSurahs = await loadFullQuran();
    return allSurahs.firstWhere(
      (s) => s['id'] == surahId,
      orElse: () => allSurahs.first,
    );
  }

  /// Loads Libyan cities from Al-Awail list
  static Future<List<Map<String, dynamic>>> loadCitiesLibya() async {
    if (_cachedCities != null) return _cachedCities!;
    final response = await rootBundle.loadString('assets/data/cities_libya.json');
    final List<dynamic> decoded = json.decode(response);
    _cachedCities = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    return _cachedCities!;
  }

  static Future<List<dynamic>> loadAdhkar() async {
    if (_cachedAdhkar != null) return _cachedAdhkar!;
    final response = await rootBundle.loadString('assets/data/adhkar.json');
    _cachedAdhkar = json.decode(response);
    return _cachedAdhkar!;
  }

  static Future<List<dynamic>> loadHadith() async {
    if (_cachedHadith != null) return _cachedHadith!;
    final response = await rootBundle.loadString('assets/data/hadith.json');
    _cachedHadith = json.decode(response);
    return _cachedHadith!;
  }

  static Future<List<dynamic>> loadDuas() async {
    if (_cachedDuas != null) return _cachedDuas!;
    final response = await rootBundle.loadString('assets/data/duas.json');
    _cachedDuas = json.decode(response);
    return _cachedDuas!;
  }

  static Future<List<dynamic>> loadNawafil() async {
    if (_cachedNawafil != null) return _cachedNawafil!;
    final response = await rootBundle.loadString('assets/data/nawafil.json');
    _cachedNawafil = json.decode(response);
    return _cachedNawafil!;
  }

  static Future<List<dynamic>> loadTasbeeh() async {
    if (_cachedTasbeeh != null) return _cachedTasbeeh!;
    final response = await rootBundle.loadString('assets/data/tasbeeh.json');
    _cachedTasbeeh = json.decode(response);
    return _cachedTasbeeh!;
  }

  static Future<List<dynamic>> loadQuran() async {
    return loadQuranSurahs();
  }

  /// Loads 99 Names of Allah with meanings
  static Future<List<Map<String, dynamic>>> loadAsmaAllah() async {
    if (_cachedAsmaAllah != null) return _cachedAsmaAllah!;
    final response = await rootBundle.loadString('assets/data/asma_allah.json');
    final List<dynamic> decoded = json.decode(response);
    _cachedAsmaAllah = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    return _cachedAsmaAllah!;
  }

  /// Loads Ruqyah Shariah sections
  static Future<Map<String, dynamic>> loadRuqyah() async {
    if (_cachedRuqyah != null) return _cachedRuqyah!;
    final response = await rootBundle.loadString('assets/data/ruqyah.json');
    _cachedRuqyah = Map<String, dynamic>.from(json.decode(response));
    return _cachedRuqyah!;
  }
}

