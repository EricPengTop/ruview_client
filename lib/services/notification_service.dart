import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const macOSInit = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    const settings = InitializationSettings(
      android: androidInit,
      macOS: macOSInit,
    );
    await _plugin.initialize(settings);
  }

  static Future<void> show(String title, String body) async {
    const platformDetails = NotificationDetails(
      macOS: DarwinNotificationDetails(),
      android: AndroidNotificationDetails(
        'ruview_alerts',
        'RuView 告警',
        channelDescription: 'RuView 感知事件告警通知',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      0,
      title,
      body,
      platformDetails,
    );
  }
}
