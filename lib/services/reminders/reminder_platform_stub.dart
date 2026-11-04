import 'reminder_platform.dart';

/// Builds without a notification system (the web) schedule nothing.
ReminderPlatform createReminderPlatform() => const _NoReminders();

class _NoReminders implements ReminderPlatform {
  const _NoReminders();

  @override
  Future<bool> initialize() async => false;

  @override
  Future<int?> launchedFromReminderId() async => null;

  @override
  Future<void> schedule(PlannedReminder reminder) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<bool> requestPermission() async => false;
}
