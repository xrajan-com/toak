import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/core/aup.dart' show formatAup;
import 'package:ten_of_a_kind_poker/core/daily_tribute.dart';
import 'package:ten_of_a_kind_poker/services/game_analytics.dart';
import 'package:ten_of_a_kind_poker/services/reminders/reminder_platform.dart';
import 'package:ten_of_a_kind_poker/services/reminders/reminder_platform_stub.dart'
    if (dart.library.io) 'package:ten_of_a_kind_poker/services/reminders/reminder_platform_native.dart';

export 'package:ten_of_a_kind_poker/services/reminders/reminder_platform.dart'
    show PlannedReminder, ReminderPlatform;

/// Local reminders that bring players back: the daily tribute, and a nudge
/// after a few days away.
///
/// Every reminder is scheduled on the phone, never pushed from a server, and
/// is replaced each time the home screen opens, so a player who comes back
/// on their own never sees one. At most two are pending at once. Nothing is
/// scheduled until the player has said yes (after their first tribute, or in
/// Settings).
class ReturnReminders {
  ReturnReminders({
    ReminderPlatform? platform,
    bool? supported,
  })  : _platform = platform,
        _supported = supported ??
            (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS));

  static final ReturnReminders instance = ReturnReminders();

  /// Today's or tomorrow's tribute.
  static const int tributeId = 101;

  /// A nudge after [awayDays] days without opening the game.
  static const int comebackId = 102;
  static const int awayDays = 3;

  /// The player's choice (Settings, or the tribute dialog). Default on, but
  /// nothing is scheduled before [askedKey] is set.
  static const String enabledKey = 'reminders.enabled.v1';

  /// Whether the player has been offered reminders yet.
  static const String askedKey = 'reminders.offered.v1';

  // Reminders keep to waking hours, near the hour the player last played.
  static const int earliestHour = 9;
  static const int latestHour = 21;

  /// An unclaimed tribute is reminded about this evening, at [sameDayHour],
  /// if the player leaves before [sameDayCutoffHour].
  static const int sameDayCutoffHour = 18;
  static const int sameDayHour = 20;

  ReminderPlatform? _platform;
  final bool _supported;
  Future<bool>? _ready;

  bool get supported => _supported;

  /// What should be pending, given the tribute and the moment ([now]) the
  /// player is in the game. Pure: tested without a phone.
  static List<PlannedReminder> plan(DailyTributeState tribute, DateTime now) {
    final int hour = now.hour.clamp(earliestHour, latestHour);
    final List<PlannedReminder> out = <PlannedReminder>[];

    if (tribute.canClaim && now.hour < sameDayCutoffHour) {
      // Not claimed yet today: one reminder this evening.
      final int streak = tribute.streakIfClaimed;
      out.add(PlannedReminder(
        id: tributeId,
        at: DateTime(now.year, now.month, now.day, sameDayHour),
        title: streak > 1
            ? 'Keep your $streak-day run'
            : "Today's tribute is waiting",
        body: 'Claim ${formatAup(tribute.amountToday)} AUP before midnight.',
      ));
    } else {
      // Claimed, or too late in the day to nag: tomorrow, near this hour.
      final int nextStreak =
          tribute.claimedToday ? tribute.lastStreak + 1 : 1;
      final String amount = formatAup(dailyTributeAmount(nextStreak));
      out.add(PlannedReminder(
        id: tributeId,
        at: DateTime(now.year, now.month, now.day + 1, hour),
        title: nextStreak > 1
            ? 'Day $nextStreak tribute is ready'
            : 'Your daily tribute is ready',
        body: nextStreak > 1
            ? 'Claim $amount AUP and keep your run going.'
            : 'Claim $amount AUP and take on a fort.',
      ));
    }

    out.add(PlannedReminder(
      id: comebackId,
      at: DateTime(now.year, now.month, now.day + awayDays, hour),
      title: 'Your seat is open',
      body: 'The forts are still standing. Come back and take one.',
    ));
    return out;
  }

  Future<bool> _init() => _ready ??= _initialize();

  Future<bool> _initialize() async {
    if (!_supported) return false;
    try {
      final ReminderPlatform platform =
          _platform ??= createReminderPlatform();
      final bool ready = await platform.initialize();
      final int? openedBy = await platform.launchedFromReminderId();
      if (openedBy != null) {
        unawaited(GameAnalytics.reminderOpened(id: openedBy));
      }
      return ready;
    } catch (error) {
      debugPrint('Reminders unavailable: $error');
      return false;
    }
  }

  Future<bool> _flag(String key, {required bool fallback}) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _setFlag(String key, bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  Future<bool> isEnabled() => _flag(enabledKey, fallback: true);

  /// Whether the player has not yet been offered reminders.
  Future<bool> shouldOffer() async =>
      _supported && !await _flag(askedKey, fallback: false);

  /// The player's answer to the offer, or the Settings switch. A yes asks
  /// the system for permission; a no cancels anything pending.
  Future<bool> setEnabled(bool value) async {
    await _setFlag(askedKey, true);
    await _setFlag(enabledKey, value);
    if (!value) {
      await cancelAll();
      return false;
    }
    return requestPermission();
  }

  /// Replaces whatever is pending with [plan] for this moment.
  Future<void> refresh(DailyTributeState tribute, {DateTime? now}) async {
    if (!_supported) return;
    if (!await _flag(askedKey, fallback: false)) return;
    if (!await isEnabled()) return;
    if (!await _init()) return;
    final ReminderPlatform platform = _platform!;
    final DateTime at = now ?? DateTime.now();
    try {
      for (final PlannedReminder reminder in plan(tribute, at)) {
        await platform.cancel(reminder.id);
        if (reminder.at.isAfter(at)) await platform.schedule(reminder);
      }
    } catch (error) {
      debugPrint('Reminder scheduling failed: $error');
    }
  }

  Future<void> cancelAll() async {
    if (!_supported || !await _init()) return;
    try {
      await _platform!.cancel(tributeId);
      await _platform!.cancel(comebackId);
    } catch (_) {}
  }

  /// Asks the system to allow notifications. Returns whether they are.
  Future<bool> requestPermission() async {
    if (!_supported || !await _init()) return false;
    bool granted = false;
    try {
      granted = await _platform!.requestPermission();
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
    }
    unawaited(GameAnalytics.reminderPermission(granted: granted));
    return granted;
  }
}
