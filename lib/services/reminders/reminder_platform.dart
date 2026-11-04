import 'package:flutter/foundation.dart';

/// One reminder the phone should show later.
@immutable
class PlannedReminder {
  final int id;
  final DateTime at;
  final String title;
  final String body;

  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  @override
  String toString() => 'PlannedReminder($id, $at, $title)';
}

/// The phone's notification system, as [ReturnReminders] uses it. The
/// native version lives in reminder_platform_native.dart; the web build gets
/// the stub, which does nothing.
abstract class ReminderPlatform {
  /// Sets the plugin up. Returns whether reminders can be scheduled.
  Future<bool> initialize();

  /// The id of the reminder that opened the app, if one did.
  Future<int?> launchedFromReminderId();

  Future<void> schedule(PlannedReminder reminder);

  Future<void> cancel(int id);

  /// Asks the system to allow notifications (Android 13+, iOS); returns
  /// whether they are allowed.
  Future<bool> requestPermission();
}
