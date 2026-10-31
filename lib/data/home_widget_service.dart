import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'shared_prefs_helper.dart';

/// يحدّث ودجت «الصلاة القادمة» على الشاشة الرئيسية (أندرويد).
/// الودجت يحسب الصلاة القادمة والعد التنازلي بنفسه من مواقيت اليوم والغد،
/// فيبقى صحيحاً حتى لو لم يُفتح التطبيق.
class HomeWidgetService {
  HomeWidgetService._();

  static const _provider = 'com.muadalsadiq.taybah.PrayerWidgetProvider';
  static const _keys = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  static Map<String, String> _pick(Map<String, dynamic> t) => {
        for (final k in _keys) k: (t[k] ?? '').toString(),
      };

  static Future<void> update({
    required Map<String, dynamic> today,
    required Map<String, dynamic> tomorrow,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final city = await SharedPrefsHelper.instance.getSelectedCityName();
      final now = DateTime.now().toUtc().add(const Duration(hours: 2));
      final dateKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await HomeWidget.saveWidgetData<String>('city', city);
      await HomeWidget.saveWidgetData<String>('date', dateKey);
      await HomeWidget.saveWidgetData<String>('today', jsonEncode(_pick(today)));
      await HomeWidget.saveWidgetData<String>(
          'tomorrow', jsonEncode(_pick(tomorrow)));
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (e) {
      debugPrint('Home widget update failed: $e');
    }
  }
}
