import 'dart:io';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'prayer_api.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final AudioPlayer _adhanAudioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isAdhanPlaying = false;

  bool get isAdhanPlaying => _isAdhanPlaying;
  AudioPlayer get adhanAudioPlayer => _adhanAudioPlayer;

  static const String channelId = 'adhan_channel_v3';
  static const String channelName = 'أذان وتنبيهات الصلاة';
  static const String channelDescription =
      'إشعارات وتنبيهات أوقات الصلاة والأذكار اليومية في تطبيق طيبة';

  /// Initialize local notification system and timezones
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone database for scheduling
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('ic_stat_taybah');

      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const linuxSettings =
          LinuxInitializationSettings(defaultActionName: 'open_app');

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      // Create Android Notification Channel with Adhan sound and max importance
      if (!kIsWeb && Platform.isAndroid) {
        const androidChannel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('adhan'),
        );

        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          await androidImpl.createNotificationChannel(androidChannel);
        }
      }

      _adhanAudioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isAdhanPlaying = false;
        }
      });

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully with Adhan sound support');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Request permissions on Android 13+ and iOS
  Future<bool> requestPermissions() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          final granted =
              await androidImpl.requestNotificationsPermission();
          // إذن المنبهات الدقيقة (أندرويد 12+) حتى يصل الأذان في وقته بالدقيقة
          try {
            final canExact =
                await androidImpl.canScheduleExactNotifications();
            if (canExact == false) {
              await androidImpl.requestExactAlarmsPermission();
            }
          } catch (e) {
            debugPrint('Exact alarm permission request failed: $e');
          }
          return granted ?? false;
        }
      } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        final iosImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        if (iosImpl != null) {
          final granted = await iosImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return granted ?? false;
        }
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
    return true;
  }

  /// Play Adhan audio through AudioPlayer (in-app playback)
  Future<void> playAdhanAudio() async {
    try {
      await _adhanAudioPlayer.stop();
      await _adhanAudioPlayer.setAsset('assets/audio/adhan.mp3');
      _isAdhanPlaying = true;
      await _adhanAudioPlayer.play();
    } catch (e) {
      debugPrint('Error playing in-app adhan audio: $e');
      _isAdhanPlaying = false;
    }
  }

  /// Stop currently playing Adhan audio
  Future<void> stopAdhanAudio() async {
    try {
      await _adhanAudioPlayer.stop();
      _isAdhanPlaying = false;
    } catch (e) {
      debugPrint('Error stopping adhan audio: $e');
    }
  }

  /// Notification details configured with custom Adhan sound
  NotificationDetails _getAdhanNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'طيبة',
      icon: 'ic_stat_taybah',
      color: Color(0xFF183D24),
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('adhan'),
      styleInformation: BigTextStyleInformation(''),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'adhan.mp3',
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  /// Show an instant high-priority notification
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await init();
      await _notificationsPlugin.show(
        id,
        title,
        body,
        _getAdhanNotificationDetails(),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing instant notification: $e');
    }
  }

  /// Send instant test Adhan alert and play the audio
  Future<void> sendAdhanTestNotification(String prayerName) async {
    await showInstantNotification(
      id: 999,
      title: 'الله أكبر • حان موعد أذان $prayerName',
      body: 'حيّ على الصلاة، حيّ على الفلاح • تقبل الله طاعتكم ورفع قدركم',
      payload: 'prayer_$prayerName',
    );
    // Also trigger audio playback
    await playAdhanAudio();
  }

  /// عدد الأيام القادمة التي تُجدول تنبيهاتها بمواقيت كل يوم بدقة.
  static const int _scheduleDays = 8;

  /// يجدول تنبيهات الصلوات الخمس + الشروق لعدة أيام قادمة،
  /// كل يوم بميقاته الصحيح (بدل تكرار ميقات اليوم نفسه كل يوم).
  Future<void> scheduleDailyPrayers(Map<String, dynamic> timings) async {
    if (timings.isEmpty || _isScheduling) return;
    _isScheduling = true;
    try {
      await init();
      await _scheduleDailyPrayersInternal(timings);
    } catch (e) {
      debugPrint('Error scheduling prayers: $e');
    } finally {
      _isScheduling = false;
    }
  }

  bool _isScheduling = false;

  Future<void> _scheduleDailyPrayersInternal(
    Map<String, dynamic> timings,
  ) async {
    final prayerData = [
      {'key': 'Fajr', 'name': 'الفجر', 'id': 101},
      {'key': 'Sunrise', 'name': 'الشروق', 'id': 102},
      {'key': 'Dhuhr', 'name': 'الظهر', 'id': 103},
      {'key': 'Asr', 'name': 'العصر', 'id': 104},
      {'key': 'Maghrib', 'name': 'المغرب', 'id': 105},
      {'key': 'Isha', 'name': 'العشاء', 'id': 106},
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isIOS = !kIsWeb && (Platform.isIOS || Platform.isMacOS);

    // مواقيت كل يوم من الأيام القادمة (اليوم = المواقيت المعروضة على الشاشة)
    final dayTimings = <Map<String, dynamic>>[];
    for (var d = 0; d <= _scheduleDays; d++) {
      if (d == 0) {
        dayTimings.add(timings);
        continue;
      }
      try {
        dayTimings.add(
          await PrayerApi.getTimingsForDate(today.add(Duration(days: d))),
        );
      } catch (_) {
        dayTimings.add(timings);
      }
    }

    for (var pIdx = 0; pIdx < prayerData.length; pIdx++) {
      final p = prayerData[pIdx];
      final key = p['key'] as String;
      final name = p['name'] as String;
      final legacyId = p['id'] as int;

      // إلغاء كل ما سبق جدولته لهذه الصلاة
      await _safeCancel(legacyId);
      for (var d = 0; d < _scheduleDays; d++) {
        await _safeCancel(1000 + d * 10 + pIdx);
      }

      final isEnabled = await isPrayerNotificationEnabled(key);
      if (!isEnabled) continue;

      for (var d = 0; d <= _scheduleDays; d++) {
        final when = _dateTimeFor(today.add(Duration(days: d)), dayTimings[d][key]);
        if (when == null || !when.isAfter(now)) continue;

        final isFallbackDay = d == _scheduleDays;
        // اليوم الأخير: تنبيه يومي متكرر احتياطي إذا لم يُفتح التطبيق لمدة طويلة
        // (على iOS المتكرر يبدأ من اليوم فيتكرر التنبيه، لذلك نتركه لأندرويد فقط)
        if (isFallbackDay && isIOS) continue;

        await _scheduleOne(
          id: isFallbackDay ? legacyId : 1000 + d * 10 + pIdx,
          title: 'الله أكبر • حان الآن موعد أذان $name',
          body: 'حيّ على الصلاة، حيّ على الفلاح • تقبل الله طاعتكم',
          when: when,
          payload: 'prayer_$key',
          repeatDaily: isFallbackDay,
        );
      }
    }

    // Also schedule daily Morning & Evening Azkar reminders
    await scheduleDailyAzkarReminders();
  }

  Future<void> _safeCancel(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (_) {}
  }

  DateTime? _dateTimeFor(DateTime day, dynamic timeStr) {
    final s = timeStr?.toString() ?? '';
    if (!s.contains(':')) return null;
    final parts = s.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  /// يجدول تنبيهاً واحداً بالوقت الدقيق، وإذا رفض النظام المنبهات الدقيقة
  /// (أندرويد 12+ بدون إذن) يرجع للجدولة التقريبية بدل أن يفشل التنبيه.
  Future<void> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
    bool repeatDaily = false,
  }) async {
    final tzScheduled = tz.TZDateTime.from(when, tz.local);
    for (final mode in const [
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzScheduled,
          _getAdhanNotificationDetails(),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents:
              repeatDaily ? DateTimeComponents.time : null,
          payload: payload,
        );
        return;
      } catch (e) {
        debugPrint('Error scheduling notification $id ($mode): $e');
      }
    }
  }

  /// Schedule daily Morning & Evening Azkar reminders
  Future<void> scheduleDailyAzkarReminders() async {
    await init();
    final now = DateTime.now();

    final azkarSchedule = [
      {
        'id': 201,
        'title': '☀️ أذكار الصباح • حصن المسلم',
        'body': 'طوبى لمن طاب قلبه بذكر الله • ابدأ يومك بالذكر وطمأنينة القلب',
        'hour': 6,
        'minute': 30,
        'payload': 'adhkar_morning',
      },
      {
        'id': 202,
        'title': '🌙 أذكار المساء • حصن المسلم',
        'body': '﴿أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ﴾ • حان وقت أذكار المساء',
        'hour': 16,
        'minute': 30,
        'payload': 'adhkar_evening',
      },
    ];

    for (final az in azkarSchedule) {
      final id = az['id'] as int;
      final title = az['title'] as String;
      final body = az['body'] as String;
      final hour = az['hour'] as int;
      final minute = az['minute'] as int;
      final payload = az['payload'] as String;

      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);

      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzScheduled,
          _getAdhanNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
        debugPrint('Scheduled Azkar reminder: $title at $hour:$minute');
      } catch (e) {
        debugPrint('Error scheduling Azkar reminder $title: $e');
      }
    }
  }

  /// Check if notifications for a specific prayer are enabled
  Future<bool> isPrayerNotificationEnabled(String prayerKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (prayerKey == 'Sunrise') {
      return prefs.getBool('notif_enabled_Sunrise') ?? false;
    }
    return prefs.getBool('notif_enabled_$prayerKey') ?? true;
  }

  /// Toggle notification for a specific prayer
  Future<bool> togglePrayerNotification(String prayerKey) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await isPrayerNotificationEnabled(prayerKey);
    final next = !current;
    await prefs.setBool('notif_enabled_$prayerKey', next);
    return next;
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
      await stopAdhanAudio();
    } catch (e) {
      debugPrint('Error canceling notifications: $e');
    }
  }
}
