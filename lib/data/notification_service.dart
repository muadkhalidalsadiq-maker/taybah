import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
          AndroidInitializationSettings('@mipmap/ic_launcher');

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

  /// Schedule daily notifications for the 5 prayers + sunrise
  Future<void> scheduleDailyPrayers(Map<String, dynamic> timings) async {
    if (timings.isEmpty) return;
    await init();

    final prayerData = [
      {'key': 'Fajr', 'name': 'الفجر', 'id': 101},
      {'key': 'Sunrise', 'name': 'الشروق', 'id': 102},
      {'key': 'Dhuhr', 'name': 'الظهر', 'id': 103},
      {'key': 'Asr', 'name': 'العصر', 'id': 104},
      {'key': 'Maghrib', 'name': 'المغرب', 'id': 105},
      {'key': 'Isha', 'name': 'العشاء', 'id': 106},
    ];

    final now = DateTime.now();

    for (final p in prayerData) {
      final key = p['key'] as String;
      final name = p['name'] as String;
      final id = p['id'] as int;

      final isEnabled = await isPrayerNotificationEnabled(key);
      if (!isEnabled) {
        await _notificationsPlugin.cancel(id);
        continue;
      }

      final timeStr = timings[key]?.toString();
      if (timeStr == null || !timeStr.contains(':')) continue;

      final parts = timeStr.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      // Calculate scheduled date in local timezone
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);

      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          'الله أكبر • حان الآن موعد أذان $name',
          'حيّ على الصلاة، حيّ على الفلاح • تقبل الله طاعتكم',
          tzScheduled,
          _getAdhanNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'prayer_$key',
        );
        debugPrint('Scheduled prayer $name at $timeStr (ID: $id)');
      } catch (e) {
        debugPrint('Error scheduling prayer $name: $e');
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
