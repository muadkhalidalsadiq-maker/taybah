import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/alert_settings.dart';
import '../../data/notification_service.dart';

/// بطاقة «موثوقية الأذان»: فحص الأذونات + خيارات التنبيه قبل الأذان والإقامة والوضع الصامت.
class AdhanReliabilityCard extends StatefulWidget {
  const AdhanReliabilityCard({super.key});

  @override
  State<AdhanReliabilityCard> createState() => _AdhanReliabilityCardState();
}

class _AdhanReliabilityCardState extends State<AdhanReliabilityCard>
    with WidgetsBindingObserver {
  final _svc = NotificationService.instance;
  bool _notif = true, _exact = true, _battery = true;
  int _pre = 0;
  bool _iqama = false, _silent = false;
  bool _loaded = false;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // بعد الرجوع من صفحة إعدادات النظام نعيد الفحص
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final n = await _svc.notificationsAllowed();
    final e = await _svc.exactAlarmsAllowed();
    final b = await _svc.batteryUnrestricted();
    final pre = await AlertSettings.preAdhanMinutes();
    final iq = await AlertSettings.iqamaReminder();
    final si = await AlertSettings.adhanInSilent();
    if (!mounted) return;
    setState(() {
      _notif = n;
      _exact = e;
      _battery = b;
      _pre = pre;
      _iqama = iq;
      _silent = si;
      _loaded = true;
    });
  }

  Widget _check(String title, String hint, bool ok, VoidCallback fix) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            color: ok ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontFamily: TaybahFonts.ui, 
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: TaybahColors.textPrimary)),
                if (!ok)
                  Text(hint,
                      style: TextStyle(fontFamily: TaybahFonts.ui, 
                          fontSize: 11, color: TaybahColors.textMuted)),
              ],
            ),
          ),
          if (!ok)
            TextButton(
              onPressed: fix,
              style: TextButton.styleFrom(
                backgroundColor: TaybahColors.gold.withAlpha(40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('إصلاح',
                  style: TextStyle(fontFamily: TaybahFonts.ui, 
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: TaybahColors.gold)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 60);
    final allOk = _notif && _exact && _battery;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TaybahColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: allOk ? TaybahColors.border : TaybahColors.gold.withAlpha(140),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                allOk ? Icons.verified_rounded : Icons.warning_amber_rounded,
                color: allOk ? const Color(0xFF22C55E) : TaybahColors.gold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  allOk
                      ? 'الأذان جاهز ويصل في وقته'
                      : 'يوجد ما قد يمنع وصول الأذان في وقته',
                  style: TextStyle(fontFamily: TaybahFonts.ui, 
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: TaybahColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _check(
            'إذن الإشعارات',
            'بدونه لن يظهر الأذان إطلاقاً',
            _notif,
            () async {
              await _svc.requestPermissions(askExactAlarm: false);
              _load();
            },
          ),
          if (_isAndroid) ...[
            _check(
              'المنبهات الدقيقة',
              'حتى يؤذن في الدقيقة نفسها بلا تأخير',
              _exact,
              () async {
                await _svc.requestExactAlarms();
                _load();
              },
            ),
            _check(
              'استثناء من توفير البطارية',
              'بعض الهواتف (شاومي، سامسونج، هواوي) توقف التنبيهات لتوفير البطارية',
              _battery,
              () async {
                await _svc.requestBatteryUnrestricted();
                _load();
              },
            ),
          ],
          Divider(height: 22, color: TaybahColors.border),

          // تنبيه قبل الأذان
          Row(
            children: [
              Icon(Icons.timer_outlined, color: TaybahColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('تنبيه قبل الأذان',
                    style: TextStyle(fontFamily: TaybahFonts.ui, 
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: TaybahColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in AlertSettings.preAdhanOptions)
                ChoiceChip(
                  label: Text(m == 0 ? 'بدون' : '$m د',
                      style: TextStyle(fontFamily: TaybahFonts.ui, 
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _pre == m
                              ? Colors.white
                              : TaybahColors.textSecondary)),
                  selected: _pre == m,
                  showCheckmark: false,
                  selectedColor: TaybahColors.primary,
                  backgroundColor: TaybahColors.surfaceMuted,
                  side: BorderSide(color: TaybahColors.border),
                  onSelected: (_) async {
                    setState(() => _pre = m);
                    await AlertSettings.setPreAdhanMinutes(m);
                    _svc.rescheduleAll();
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            secondary: Icon(Icons.groups_rounded, color: TaybahColors.primary),
            title: Text('تنبيه وقت الإقامة',
                style: TextStyle(fontFamily: TaybahFonts.ui, 
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: TaybahColors.textPrimary)),
            subtitle: Text('الفجر +20 د، المغرب +10 د، والباقي +15 د',
                style: TextStyle(fontFamily: TaybahFonts.ui, 
                    fontSize: 11, color: TaybahColors.textMuted)),
            value: _iqama,
            activeTrackColor: TaybahColors.primary,
            onChanged: (v) async {
              setState(() => _iqama = v);
              await AlertSettings.setIqamaReminder(v);
              _svc.rescheduleAll();
            },
          ),
          if (_isAndroid)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary:
                  Icon(Icons.volume_off_rounded, color: TaybahColors.primary),
              title: Text('الأذان حتى في الوضع الصامت',
                  style: TextStyle(fontFamily: TaybahFonts.ui, 
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: TaybahColors.textPrimary)),
              subtitle: Text('يُشغَّل بصوت المنبه بدل صوت الإشعارات',
                  style: TextStyle(fontFamily: TaybahFonts.ui, 
                      fontSize: 11, color: TaybahColors.textMuted)),
              value: _silent,
              activeTrackColor: TaybahColors.primary,
              onChanged: (v) async {
                setState(() => _silent = v);
                await _svc.setAdhanInSilent(v);
              },
            ),
        ],
      ),
    );
  }
}
