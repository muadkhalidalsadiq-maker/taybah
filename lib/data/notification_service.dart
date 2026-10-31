import 'dart:io';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'adhan_voices.dart';
import 'prayer_api.dart';
import 'quran_player.dart';
import 'shared_prefs_helper.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  AudioPlayer get _adhanAudioPlayer => AppAudio.player;
  bool _isInitialized = false;
  bool _isAdhanPlaying = false;
  String? _previewingId;

  bool get isAdhanPlaying => _isAdhanPlaying;
  AudioPlayer get adhanAudioPlayer => _adhanAudioPlayer;

  /// معرّف الصوت الذي يُعاين الآن داخل التطبيق (أو null).
  String? get previewingId => _previewingId;

  static const String _packageName = 'com.muadalsadiq.taybah';
  static const String _channelPrefix = 'taybah_adhan_';
  static const String _channelVersion = 'v1';
  static const String sunriseChannelId = 'taybah_sunrise_v1';
  static const String remindersChannelId = 'taybah_reminders_v1';
  static const List<String> _legacyChannels = ['adhan_channel_v3'];

  static const String stopActionId = 'stop_adhan';

  static const Map<String, String> prayerNames = {
    'Fajr': 'الفجر',
    'Sunrise': 'الشروق',
    'Dhuhr': 'الظهر',
    'Asr': 'العصر',
    'Maghrib': 'المغرب',
    'Isha': 'العشاء',
  };

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _isApple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  AndroidFlutterLocalNotificationsPlugin? get _android => _notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static String _channelId(AdhanVoice voice, String prayerKey) =>
      '$_channelPrefix${voice.id}_${prayerKey.toLowerCase()}_$_channelVersion';

  /// Initialize local notification system and timezones
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      try {
        // ليبيا: توقيت ثابت UTC+2 طوال السنة
        tz.setLocalLocation(tz.getLocation('Africa/Tripoli'));
      } catch (_) {}

      const androidSettings = AndroidInitializationSettings('ic_stat_taybah');

      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
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
          if (response.actionId == stopActionId) stopAdhanAudio();
        },
      );

      if (_isAndroid) {
        await _setupAndroidChannels(await AdhanVoices.getSelected());
      }

      _adhanAudioPlayer.playerStateStream.listen((state) {
        if (_previewingId != null &&
            state.processingState == ProcessingState.completed) {
          _isAdhanPlaying = false;
          _previewingId = null;
        }
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// ينشئ قنوات أندرويد للصوت المختار ويحذف قنوات الأصوات الأخرى،
  /// لأن صوت القناة في أندرويد لا يمكن تغييره بعد إنشائها.
  Future<void> _setupAndroidChannels(AdhanVoice voice) async {
    final android = _android;
    if (android == null) return;
    try {
      final wanted = <String>{
        for (final p in AdhanVoices.adhanPrayers) _channelId(voice, p),
        sunriseChannelId,
        remindersChannelId,
      };

      final existing = await android.getNotificationChannels() ?? [];
      for (final ch in existing) {
        final isOurs = ch.id.startsWith(_channelPrefix) ||
            _legacyChannels.contains(ch.id);
        if (isOurs && !wanted.contains(ch.id)) {
          await android.deleteNotificationChannel(ch.id);
        }
      }

      for (final p in AdhanVoices.adhanPrayers) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            _channelId(voice, p),
            'أذان ${prayerNames[p]} • ${voice.name}',
            description: 'تنبيه دخول وقت صلاة ${prayerNames[p]}',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            sound: RawResourceAndroidNotificationSound(
              AdhanVoices.rawName(voice, p),
            ),
          ),
        );
      }

      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          sunriseChannelId,
          'تنبيه وقت الشروق',
          description: 'تنبيه صوتي قصير عند وقت الشروق',
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('announce_sunrise'),
        ),
      );

      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          remindersChannelId,
          'تذكير الأذكار',
          description: 'تذكير أذكار الصباح والمساء والنوم',
          importance: Importance.defaultImportance,
          playSound: true,
        ),
      );
    } catch (e) {
      debugPrint('Error setting up notification channels: $e');
    }
  }

  /// يغيّر صوت الأذان ويعيد جدولة التنبيهات بالصوت الجديد.
  Future<void> setAdhanVoice(String voiceId) async {
    await AdhanVoices.setSelected(voiceId);
    if (_isAndroid) {
      await _setupAndroidChannels(AdhanVoices.byId(voiceId));
    }
    await rescheduleAll();
  }

  /// Request permissions on Android 13+ and iOS
  Future<bool> requestPermissions({bool askExactAlarm = true}) async {
    try {
      if (_isAndroid) {
        final androidImpl = _android;
        if (androidImpl != null) {
          final granted = await androidImpl.requestNotificationsPermission();
          // إذن المنبهات الدقيقة (أندرويد 12+) حتى يصل الأذان في وقته بالدقيقة
          try {
            final canExact = await androidImpl.canScheduleExactNotifications();
            if (canExact == false && askExactAlarm) {
              await androidImpl.requestExactAlarmsPermission();
            }
          } catch (e) {
            debugPrint('Exact alarm permission request failed: $e');
          }
          return granted ?? false;
        }
      } else if (_isApple) {
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

  /// معاينة صوت أذان داخل التطبيق (نفس الملف الذي يُشغَّل مع الإشعار).
  Future<void> previewVoice(String voiceId, {String prayerKey = 'Dhuhr'}) async {
    try {
      QuranPlayer.instance.releasePlayer();
      await _adhanAudioPlayer.stop();
      final voice = AdhanVoices.byId(voiceId);
      final tag = MediaItem(
        id: 'adhan_${voice.id}_$prayerKey',
        title: 'أذان ${prayerNames[prayerKey] ?? ''}',
        artist: voice.name,
        album: 'طيبة للأذكار والصلاة',
      );
      if (_isAndroid) {
        final name = AdhanVoices.rawName(voice, prayerKey);
        await _adhanAudioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse('android.resource://$_packageName/raw/$name'),
            tag: tag,
          ),
        );
      } else {
        await _adhanAudioPlayer.setAudioSource(
          AudioSource.asset('assets/audio/adhan.mp3', tag: tag),
        );
      }
      _isAdhanPlaying = true;
      _previewingId = voiceId;
      _adhanAudioPlayer.play();
    } catch (e) {
      debugPrint('Error previewing adhan voice: $e');
      _isAdhanPlaying = false;
      _previewingId = null;
    }
  }

  /// Play Adhan audio through AudioPlayer (in-app playback)
  Future<void> playAdhanAudio({String prayerKey = 'Dhuhr'}) async {
    final voice = await AdhanVoices.getSelected();
    await previewVoice(voice.id, prayerKey: prayerKey);
  }

  /// Stop currently playing Adhan audio
  Future<void> stopAdhanAudio() async {
    try {
      // لا نوقف تلاوة القرآن إذا كانت هي التي تعمل
      if (_previewingId != null || _isAdhanPlaying) {
        await _adhanAudioPlayer.stop();
      }
    } catch (e) {
      debugPrint('Error stopping adhan audio: $e');
    }
    _isAdhanPlaying = false;
    _previewingId = null;
    // إيقاف صوت إشعار الأذان التجريبي إن كان يعمل
    await _safeCancel(999);
  }

  NotificationDetails _prayerDetails(AdhanVoice voice, String prayerKey) {
    final isSunrise = prayerKey == 'Sunrise';
    final channelId =
        isSunrise ? sunriseChannelId : _channelId(voice, prayerKey);
    final androidDetails = AndroidNotificationDetails(
      channelId,
      isSunrise
          ? 'تنبيه وقت الشروق'
          : 'أذان ${prayerNames[prayerKey]} • ${voice.name}',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: 'طيبة',
      icon: 'ic_stat_taybah',
      color: const Color(0xFF183D24),
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        AdhanVoices.rawName(voice, prayerKey),
      ),
      styleInformation: const BigTextStyleInformation(''),
      actions: isSunrise
          ? null
          : const [
              AndroidNotificationAction(
                stopActionId,
                'إيقاف الأذان',
                cancelNotification: true,
              ),
            ],
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  NotificationDetails _reminderDetails() {
    const androidDetails = AndroidNotificationDetails(
      remindersChannelId,
      'تذكير الأذكار',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: 'ic_stat_taybah',
      color: Color(0xFF183D24),
      styleInformation: BigTextStyleInformation(''),
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  /// Send instant test Adhan alert. على أندرويد صوت الإشعار نفسه هو الأذان،
  /// وعلى الأنظمة الأخرى يُشغَّل الصوت داخل التطبيق.
  Future<void> sendAdhanTestNotification(String prayerName) async {
    await init();
    var key = 'Dhuhr';
    prayerNames.forEach((k, v) {
      if (prayerName.contains(v) || prayerName == k) key = k;
    });
    final voice = await AdhanVoices.getSelected();
    await stopAdhanAudio();
    try {
      await _notificationsPlugin.show(
        999,
        _prayerTitle(key),
        _prayerBody(key),
        _prayerDetails(voice, key),
        payload: 'prayer_$key',
      );
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
    if (!_isAndroid) await playAdhanAudio(prayerKey: key);
  }

  String _prayerTitle(String key) => key == 'Sunrise'
      ? '☀️ حان الآن وقت الشروق'
      : 'الله أكبر • حان الآن موعد أذان ${prayerNames[key]}';

  String _prayerBody(String key) => key == 'Sunrise'
      ? 'انتهى وقت صلاة الفجر • فاذكروا الله'
      : 'حيّ على الصلاة، حيّ على الفلاح • تقبل الله طاعتكم';

  /// عدد الأيام القادمة التي تُجدول تنبيهاتها بمواقيت كل يوم بدقة.
  static const int _scheduleDays = 8;

  bool _isScheduling = false;
  Map<String, dynamic>? _pendingTimings;

  /// يجدول تنبيهات الصلوات الخمس + الشروق لعدة أيام قادمة،
  /// كل يوم بميقاته الصحيح.
  Future<void> scheduleDailyPrayers(Map<String, dynamic> timings) async {
    if (timings.isEmpty) return;
    if (_isScheduling) {
      // طلب جديد أثناء الجدولة: نعيد الجدولة بعد انتهاء الحالية بأحدث مواقيت
      _pendingTimings = timings;
      return;
    }
    _isScheduling = true;
    try {
      await init();
      var next = timings;
      while (true) {
        await _scheduleDailyPrayersInternal(next);
        if (_pendingTimings == null) break;
        next = _pendingTimings!;
        _pendingTimings = null;
      }
    } catch (e) {
      debugPrint('Error scheduling prayers: $e');
    } finally {
      _isScheduling = false;
    }
  }

  /// يعيد جدولة كل التنبيهات من الإعدادات المحفوظة (بعد تغيير أي إعداد).
  Future<void> rescheduleAll() async {
    try {
      final today = await PrayerApi.getTimingsForDate(DateTime.now());
      await scheduleDailyPrayers(today);
    } catch (e) {
      debugPrint('Error rescheduling: $e');
    }
  }

  Future<void> _scheduleDailyPrayersInternal(
    Map<String, dynamic> timings,
  ) async {
    const prayerData = [
      {'key': 'Fajr', 'id': 101},
      {'key': 'Sunrise', 'id': 102},
      {'key': 'Dhuhr', 'id': 103},
      {'key': 'Asr', 'id': 104},
      {'key': 'Maghrib', 'id': 105},
      {'key': 'Isha', 'id': 106},
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final masterEnabled =
        await SharedPrefsHelper.instance.getNotificationsEnabled();
    final voice = await AdhanVoices.getSelected();

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
      final key = prayerData[pIdx]['key'] as String;
      final legacyId = prayerData[pIdx]['id'] as int;

      // إلغاء كل ما سبق جدولته لهذه الصلاة
      await _safeCancel(legacyId);
      for (var d = 0; d <= _scheduleDays; d++) {
        await _safeCancel(1000 + d * 10 + pIdx);
      }

      if (!masterEnabled) continue;
      if (!await isPrayerNotificationEnabled(key)) continue;

      for (var d = 0; d <= _scheduleDays; d++) {
        final when =
            _dateTimeFor(today.add(Duration(days: d)), dayTimings[d][key]);
        if (when == null || !when.isAfter(now)) continue;

        final isFallbackDay = d == _scheduleDays;
        // اليوم الأخير: تنبيه يومي متكرر احتياطي إذا لم يُفتح التطبيق لمدة طويلة
        // (على iOS المتكرر يبدأ من اليوم فيتكرر التنبيه، لذلك نتركه لأندرويد فقط)
        if (isFallbackDay && _isApple) continue;

        await _scheduleOne(
          id: isFallbackDay ? legacyId : 1000 + d * 10 + pIdx,
          title: _prayerTitle(key),
          body: _prayerBody(key),
          when: when,
          details: _prayerDetails(voice, key),
          payload: 'prayer_$key',
          repeatDaily: isFallbackDay,
        );
      }
    }

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
    required NotificationDetails details,
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
          details,
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

  /// تذكير أذكار الصباح والمساء والنوم (حسب اختيار المستخدم في الإعدادات).
  Future<void> scheduleDailyAzkarReminders() async {
    await init();
    final now = DateTime.now();
    final prefs = SharedPrefsHelper.instance;
    final master = await prefs.getNotificationsEnabled();

    final azkarSchedule = [
      {
        'id': 201,
        'enabled': await prefs.isMorningAdhkarReminderEnabled(),
        'title': '☀️ أذكار الصباح',
        'body': 'ابدأ يومك بذكر الله وطمأنينة القلب',
        'hour': 7,
        'minute': 0,
        'payload': 'adhkar_morning',
      },
      {
        'id': 202,
        'enabled': await prefs.isEveningAdhkarReminderEnabled(),
        'title': '🌙 أذكار المساء',
        'body': '﴿أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ﴾',
        'hour': 16,
        'minute': 45,
        'payload': 'adhkar_evening',
      },
      {
        'id': 203,
        'enabled': await prefs.isSleepAdhkarReminderEnabled(),
        'title': '✨ أذكار النوم وسورة الملك',
        'body': 'اختم يومك بأذكار النوم وقراءة سورة الملك',
        'hour': 22,
        'minute': 30,
        'payload': 'adhkar_sleep',
      },
    ];

    for (final az in azkarSchedule) {
      final id = az['id'] as int;
      await _safeCancel(id);
      if (!master || az['enabled'] != true) continue;

      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        az['hour'] as int,
        az['minute'] as int,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          az['title'] as String,
          az['body'] as String,
          tz.TZDateTime.from(scheduledDate, tz.local),
          _reminderDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: az['payload'] as String,
        );
      } catch (e) {
        debugPrint('Error scheduling Azkar reminder $id: $e');
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

  /// يحدد حالة تنبيه صلاة معينة صراحةً ويعيد الجدولة.
  Future<void> setPrayerNotification(String prayerKey, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled_$prayerKey', enabled);
    await rescheduleAll();
  }

  /// Toggle notification for a specific prayer
  Future<bool> togglePrayerNotification(String prayerKey) async {
    final next = !await isPrayerNotificationEnabled(prayerKey);
    await setPrayerNotification(prayerKey, next);
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
