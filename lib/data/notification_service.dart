import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'adhan_voices.dart';
import 'alert_settings.dart';
import 'home_widget_service.dart';
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
  static const String preAdhanChannelId = 'taybah_pre_adhan_v1';
  static const String iqamaChannelId = 'taybah_iqama_v1';
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

  /// معرّف القناة يتضمن الصوت ونوع الصوت (إشعار عادي / منبّه يعمل في الوضع الصامت)
  /// لأن أندرويد لا يسمح بتغيير صوت القناة بعد إنشائها.
  static String _channelId(AdhanVoice voice, String prayerKey, bool alarm) =>
      '$_channelPrefix${voice.id}_${prayerKey.toLowerCase()}${alarm ? '_alarm' : ''}_$_channelVersion';

  bool _alarmStream = false;

  /// منطقة ليبيا الزمنية: مواقيت التطبيق كلها بتوقيت ليبيا، فنجدول على أساسها
  /// حتى يصل التنبيه في اللحظة الصحيحة حتى لو كان الهاتف بمنطقة زمنية أخرى.
  static tz.Location get libya {
    try {
      return tz.getLocation('Africa/Tripoli');
    } catch (_) {
      return tz.local;
    }
  }

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

      _alarmStream = await AlertSettings.adhanInSilent();
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
      final alarm = _alarmStream;
      final wanted = <String>{
        for (final p in AdhanVoices.adhanPrayers) _channelId(voice, p, alarm),
        sunriseChannelId,
        remindersChannelId,
        preAdhanChannelId,
        iqamaChannelId,
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
            _channelId(voice, p, alarm),
            'أذان ${prayerNames[p]} • ${voice.name}',
            description: 'تنبيه دخول وقت صلاة ${prayerNames[p]}',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            audioAttributesUsage: alarm
                ? AudioAttributesUsage.alarm
                : AudioAttributesUsage.notification,
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
          preAdhanChannelId,
          'تنبيه قبل الأذان',
          description: 'تذكير قبل دخول وقت الصلاة بدقائق',
          importance: Importance.high,
          playSound: true,
        ),
      );

      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          iqamaChannelId,
          'تنبيه الإقامة',
          description: 'تذكير بموعد إقامة الصلاة',
          importance: Importance.high,
          playSound: true,
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

  /// تشغيل الأذان حتى والهاتف على الوضع الصامت (يستعمل صوت المنبه).
  Future<void> setAdhanInSilent(bool value) async {
    await AlertSettings.setAdhanInSilent(value);
    _alarmStream = value;
    if (_isAndroid) {
      await _setupAndroidChannels(await AdhanVoices.getSelected());
    }
    await rescheduleAll();
  }

  // ──── فحص جاهزية التنبيهات ────

  Future<bool> notificationsAllowed() async {
    try {
      if (_isAndroid) {
        return await _android?.areNotificationsEnabled() ?? true;
      }
      if (_isApple) {
        final status = await Permission.notification.status;
        return status.isGranted || status.isProvisional;
      }
    } catch (_) {}
    return true;
  }

  Future<bool> exactAlarmsAllowed() async {
    if (!_isAndroid) return true;
    try {
      return await _android?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// هل التطبيق مستثنى من توفير البطارية (أندرويد فقط).
  Future<bool> batteryUnrestricted() async {
    if (!_isAndroid) return true;
    try {
      return await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (_) {
      return true;
    }
  }

  Future<void> requestBatteryUnrestricted() async {
    if (!_isAndroid) return;
    try {
      await Permission.ignoreBatteryOptimizations.request();
    } catch (e) {
      debugPrint('Battery optimization request failed: $e');
    }
  }

  Future<void> requestExactAlarms() async {
    if (!_isAndroid) return;
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
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
    final channelId = isSunrise
        ? sunriseChannelId
        : _channelId(voice, prayerKey, _alarmStream);
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
      audioAttributesUsage: !isSunrise && _alarmStream
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
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

    // iOS: مقطع أقصر من 30 ثانية (يبدأ بـ«حان الآن...») مضمّن في حزمة التطبيق
    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: '${AdhanVoices.rawName(voice, prayerKey)}.caf',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  NotificationDetails _simpleDetails(String channelId, String channelName) {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_taybah',
      color: const Color(0xFF183D24),
      styleInformation: const BigTextStyleInformation(''),
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
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
      ? 'حان الآن وقت الشروق'
      : 'الله أكبر • حان الآن موعد أذان ${prayerNames[key]}';

  String _prayerBody(String key) => key == 'Sunrise'
      ? 'انتهى وقت صلاة الفجر • فاذكروا الله'
      : 'حيّ على الصلاة، حيّ على الفلاح • تقبل الله طاعتكم';

  /// عدد الأيام القادمة التي تُجدول تنبيهاتها بمواقيت كل يوم بدقة.
  static const int _scheduleDays = 8;

  bool _isScheduling = false;
  Map<String, dynamic>? _pendingTimings;

  /// يجدول تنبيهات الصلوات الخمس + الشروق والتنبيهات المرافقة لعدة أيام قادمة،
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
      final today = await PrayerApi.getTimingsForDate(_libyaToday());
      await scheduleDailyPrayers(today);
    } catch (e) {
      debugPrint('Error rescheduling: $e');
    }
  }

  /// تاريخ اليوم بتوقيت ليبيا.
  DateTime _libyaToday() {
    final n = tz.TZDateTime.now(libya);
    return DateTime(n.year, n.month, n.day);
  }

  static const List<String> _prayerOrder = [
    'Fajr',
    'Sunrise',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  // نطاقات معرّفات الإشعارات (لا تتداخل)
  static int _adhanId(int d, int p) => 1000 + d * 10 + p;
  static int _preId(int d, int p) => 3000 + d * 10 + p;
  static int _iqamaId(int d, int p) => 5000 + d * 10 + p;
  static int _azkarId(int d, int k) => 7000 + d * 10 + k;

  Future<void> _scheduleDailyPrayersInternal(
    Map<String, dynamic> timings,
  ) async {
    final now = tz.TZDateTime.now(libya);
    final today = _libyaToday();
    final masterEnabled =
        await SharedPrefsHelper.instance.getNotificationsEnabled();
    final voice = await AdhanVoices.getSelected();
    final preMinutes = await AlertSettings.preAdhanMinutes();
    final iqamaOn = await AlertSettings.iqamaReminder();

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

    // ودجت الشاشة الرئيسية: مواقيت اليوم والغد
    unawaited(HomeWidgetService.update(
      today: dayTimings[0],
      tomorrow: dayTimings.length > 1 ? dayTimings[1] : dayTimings[0],
    ));

    for (var pIdx = 0; pIdx < _prayerOrder.length; pIdx++) {
      final key = _prayerOrder[pIdx];
      final legacyId = 101 + pIdx;
      final isSunrise = key == 'Sunrise';

      // إلغاء كل ما سبق جدولته لهذه الصلاة
      await _safeCancel(legacyId);
      for (var d = 0; d <= _scheduleDays; d++) {
        await _safeCancel(_adhanId(d, pIdx));
        await _safeCancel(_preId(d, pIdx));
        await _safeCancel(_iqamaId(d, pIdx));
      }

      if (!masterEnabled) continue;
      final adhanOn = await isPrayerNotificationEnabled(key);

      for (var d = 0; d <= _scheduleDays; d++) {
        final when =
            _timeFor(today.add(Duration(days: d)), dayTimings[d][key]);
        if (when == null) continue;
        final name = prayerNames[key]!;

        // 1) الأذان نفسه
        if (adhanOn && when.isAfter(now)) {
          final isFallbackDay = d == _scheduleDays;
          // اليوم الأخير: تنبيه يومي متكرر احتياطي إذا لم يُفتح التطبيق لمدة طويلة
          // (على iOS المتكرر يبدأ من اليوم فيتكرر التنبيه، لذلك نتركه لأندرويد فقط)
          if (!(isFallbackDay && _isApple)) {
            await _scheduleOne(
              id: isFallbackDay ? legacyId : _adhanId(d, pIdx),
              title: _prayerTitle(key),
              body: _prayerBody(key),
              when: when,
              details: _prayerDetails(voice, key),
              payload: 'prayer_$key',
              repeatDaily: isFallbackDay,
            );
          }
        }

        if (isSunrise || d == _scheduleDays) continue;

        // 2) تنبيه قبل الأذان
        if (preMinutes > 0) {
          final pre = when.subtract(Duration(minutes: preMinutes));
          if (pre.isAfter(now)) {
            await _scheduleOne(
              id: _preId(d, pIdx),
              title: 'بقي $preMinutes دقيقة على أذان $name',
              body: 'استعد للصلاة وتوضأ • ﴿إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِنِينَ كِتَابًا مَّوْقُوتًا﴾',
              when: pre,
              details: _simpleDetails(preAdhanChannelId, 'تنبيه قبل الأذان'),
              payload: 'pre_$key',
            );
          }
        }

        // 3) تنبيه الإقامة
        if (iqamaOn) {
          final offset = PrayerApi.defaultIqamaOffsets[key] ?? 15;
          final iqama = when.add(Duration(minutes: offset));
          if (iqama.isAfter(now)) {
            await _scheduleOne(
              id: _iqamaId(d, pIdx),
              title: 'حان موعد إقامة صلاة $name',
              body: 'قد قامت الصلاة • أقيموا صفوفكم',
              when: iqama,
              details: _simpleDetails(iqamaChannelId, 'تنبيه الإقامة'),
              payload: 'iqama_$key',
            );
          }
        }
      }
    }

    await _scheduleAzkar(dayTimings, now, today, masterEnabled);
  }

  /// يُبقى للتوافق مع الشاشات: يعيد جدولة كل شيء بما فيه الأذكار.
  Future<void> scheduleDailyAzkarReminders() => rescheduleAll();

  /// أذكار الصباح بعد الفجر، والمساء بعد العصر، والنوم بعد العشاء —
  /// كل يوم حسب مواقيت مدينة المستخدم.
  Future<void> _scheduleAzkar(
    List<Map<String, dynamic>> dayTimings,
    tz.TZDateTime now,
    DateTime today,
    bool master,
  ) async {
    final prefs = SharedPrefsHelper.instance;
    final items = [
      (
        await prefs.isMorningAdhkarReminderEnabled(),
        'Fajr',
        30,
        'أذكار الصباح',
        'ابدأ يومك بذكر الله وطمأنينة القلب',
        'adhkar_morning',
      ),
      (
        await prefs.isEveningAdhkarReminderEnabled(),
        'Asr',
        20,
        'أذكار المساء',
        '﴿أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ﴾',
        'adhkar_evening',
      ),
      (
        await prefs.isSleepAdhkarReminderEnabled(),
        'Isha',
        120,
        'أذكار النوم وسورة الملك',
        'اختم يومك بأذكار النوم وقراءة سورة الملك',
        'adhkar_sleep',
      ),
    ];

    // التذكيرات اليومية القديمة (من الإصدارات السابقة)
    for (final id in const [201, 202, 203]) {
      await _safeCancel(id);
    }

    for (var k = 0; k < items.length; k++) {
      final (enabled, prayer, after, title, body, payload) = items[k];
      for (var d = 0; d < _scheduleDays; d++) {
        await _safeCancel(_azkarId(d, k));
        if (!master || !enabled) continue;
        final base = _timeFor(today.add(Duration(days: d)), dayTimings[d][prayer]);
        if (base == null) continue;
        final when = base.add(Duration(minutes: after));
        if (!when.isAfter(now)) continue;
        await _scheduleOne(
          id: _azkarId(d, k),
          title: title,
          body: body,
          when: when,
          details: _reminderDetails(),
          payload: payload,
          exact: false,
        );
      }
    }
  }

  Future<void> _safeCancel(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (_) {}
  }

  /// يحوّل "HH:mm" (بتوقيت ليبيا) إلى لحظة زمنية دقيقة.
  tz.TZDateTime? _timeFor(DateTime day, dynamic timeStr) {
    final s = timeStr?.toString() ?? '';
    if (!s.contains(':')) return null;
    final parts = s.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return tz.TZDateTime(libya, day.year, day.month, day.day, hour, minute);
  }

  /// يجدول تنبيهاً واحداً بالوقت الدقيق، وإذا رفض النظام المنبهات الدقيقة
  /// (أندرويد 12+ بدون إذن) يرجع للجدولة التقريبية بدل أن يفشل التنبيه.
  Future<void> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    required String payload,
    bool repeatDaily = false,
    bool exact = true,
  }) async {
    final modes = exact
        ? const [
            AndroidScheduleMode.exactAllowWhileIdle,
            AndroidScheduleMode.inexactAllowWhileIdle,
          ]
        : const [AndroidScheduleMode.inexactAllowWhileIdle];
    for (final mode in modes) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          when,
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
