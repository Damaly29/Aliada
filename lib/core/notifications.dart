import 'dart:typed_data';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificación de alarma (se ve y vibra aunque la app esté en segundo plano).
class AlarmNotifications {
  AlarmNotifications._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _pattern = Int64List.fromList([0, 900, 400, 900, 400, 900, 400, 900]);

  static const _channelId = 'sos_alerts_v1';

  static Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_aliada'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(AndroidNotificationChannel(
        _channelId,
        'Alertas SOS cercanas',
        description: 'Suena y vibra cuando alguien cerca activa su alarma',
        importance: Importance.max,
        enableVibration: true,
        vibrationPattern: _pattern,
        playSound: true,
      ));
      await android?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<void> showSos({required String title, required String body}) async {
    try {
      await _plugin.show(
        id: 911,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Alertas SOS cercanas',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            icon: 'ic_stat_aliada',
            vibrationPattern: _pattern,
            color: const Color(0xFF765AD0),
            ticker: 'Alerta SOS',
          ),
          iOS: const DarwinNotificationDetails(presentSound: true, interruptionLevel: InterruptionLevel.timeSensitive),
        ),
      );
    } catch (_) {}
  }

  static Future<void> cancel() async {
    try {
      await _plugin.cancel(id: 911);
    } catch (_) {}
  }
}
