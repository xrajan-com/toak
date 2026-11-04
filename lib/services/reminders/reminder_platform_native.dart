import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminder_platform.dart';

/// Android and iOS: local notifications scheduled on the phone.
ReminderPlatform createReminderPlatform() => _LocalNotifications();

class _LocalNotifications implements ReminderPlatform {
  static const String _channelId = 'daily_tribute';
  static const String _channelName = 'Daily tribute';
  static const String _channelDescription =
      'When your daily AUP tribute is ready, and when the forts miss you.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<bool> initialize() async {
    final bool? ready = await _plugin.initialize(
      const InitializationSettings(
        // res/drawable/ic_stat_x.xml: the X, white on transparent, as the
        // status bar requires.
        android: AndroidInitializationSettings('ic_stat_x'),
        iOS: DarwinInitializationSettings(
          // Permission is asked for at a moment that explains it (after the
          // first tribute), never at launch.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    return ready ?? false;
  }

  @override
  Future<int?> launchedFromReminderId() async {
    final NotificationAppLaunchDetails? launch =
        await _plugin.getNotificationAppLaunchDetails();
    if (launch == null || !launch.didNotificationLaunchApp) return null;
    return launch.notificationResponse?.id ?? 0;
  }

  @override
  Future<void> schedule(PlannedReminder reminder) {
    return _plugin.zonedSchedule(
      reminder.id,
      reminder.title,
      reminder.body,
      // An absolute moment: the plan was already made in the player's own
      // time, so no zone database is needed here.
      tz.TZDateTime.from(reminder.at.toUtc(), tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact: needs no exact-alarm permission, and a few minutes either
      // way does not matter for a daily reminder.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<bool> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final IOSFlutterLocalNotificationsPlugin? ios =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }
}
