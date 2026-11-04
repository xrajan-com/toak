import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/core/daily_tribute.dart';
import 'package:ten_of_a_kind_poker/services/economy_api_service.dart';
import 'package:ten_of_a_kind_poker/services/return_reminders.dart';

DailyTributeState _state(int streak, String lastDay, DateTime now) =>
    DailyTributeState(lastStreak: streak, lastDayKey: lastDay, now: now);

class _FakePlatform implements ReminderPlatform {
  final Map<int, PlannedReminder> pending = <int, PlannedReminder>{};
  int permissionAsks = 0;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<int?> launchedFromReminderId() async => null;

  @override
  Future<void> schedule(PlannedReminder reminder) async {
    pending[reminder.id] = reminder;
  }

  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
  }

  @override
  Future<bool> requestPermission() async {
    permissionAsks += 1;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ladder', () {
    test('matches the server, which is the one that pays', () {
      final String js =
          File('backend/src/economy/constants.js').readAsStringSync();
      final RegExpMatch match = RegExp(
        r'DAILY_TRIBUTE_LADDER = Object\.freeze\(\[([^\]]*)\]',
      ).firstMatch(js)!;
      final List<int> server = match
          .group(1)!
          .split(',')
          .map((String v) => v.trim())
          .where((String v) => v.isNotEmpty)
          .map(int.parse)
          .toList();
      expect(kDailyTributeLadder, server);
    });

    test('climbs for seven days, then pays the top step', () {
      expect(dailyTributeAmount(1), 50000);
      expect(dailyTributeAmount(7), 300000);
      expect(dailyTributeAmount(40), 300000);
      expect(dailyTributeAmount(0), 50000);
    });
  });

  group('state', () {
    final DateTime now = DateTime(2026, 11, 4, 10);

    test('a first-time player can claim day 1', () {
      final DailyTributeState s = _state(0, '', now);
      expect(s.canClaim, isTrue);
      expect(s.streakIfClaimed, 1);
      expect(s.amountToday, 50000);
    });

    test('claimed yesterday: today continues the run', () {
      final DailyTributeState s = _state(3, '2026-11-03', now);
      expect(s.canClaim, isTrue);
      expect(s.streakIfClaimed, 4);
      expect(s.amountToday, 125000);
      expect(s.streakAtRisk, isTrue);
    });

    test('a missed day starts again at day 1', () {
      final DailyTributeState s = _state(5, '2026-11-02', now);
      expect(s.streakIfClaimed, 1);
      expect(s.streakAtRisk, isFalse);
    });

    test('claimed today: nothing to claim, tomorrow climbs', () {
      final DailyTributeState s = _state(4, '2026-11-04', now);
      expect(s.claimedToday, isTrue);
      expect(s.canClaim, isFalse);
      expect(s.displayStreak, 4);
      expect(s.amountTomorrow, 150000);
    });

    test('yesterday works across month and year ends', () {
      expect(
        _state(2, '2026-12-31', DateTime(2027, 1, 1, 9)).streakIfClaimed,
        3,
      );
      expect(
        _state(2, '2026-10-31', DateTime(2026, 11, 1, 9)).streakIfClaimed,
        3,
      );
    });

    test('a claim under a time zone ahead of the phone reads as claimed', () {
      final DailyTributeState s = _state(2, '2026-11-05', now);
      expect(s.canClaim, isFalse);
      expect(s.displayStreak, 2);
    });
  });

  group('reminder plan', () {
    test('unclaimed in the morning: a reminder this evening', () {
      final DateTime now = DateTime(2026, 11, 4, 10, 15);
      final List<PlannedReminder> plan =
          ReturnReminders.plan(_state(2, '2026-11-03', now), now);
      final PlannedReminder tribute =
          plan.firstWhere((r) => r.id == ReturnReminders.tributeId);
      expect(tribute.at, DateTime(2026, 11, 4, 20));
      expect(tribute.title, contains('3-day run'));
    });

    test('claimed: tomorrow near the hour the player plays', () {
      final DateTime now = DateTime(2026, 11, 4, 13, 40);
      final List<PlannedReminder> plan =
          ReturnReminders.plan(_state(3, '2026-11-04', now), now);
      final PlannedReminder tribute =
          plan.firstWhere((r) => r.id == ReturnReminders.tributeId);
      expect(tribute.at, DateTime(2026, 11, 5, 13));
      expect(tribute.title, 'Day 4 tribute is ready');
    });

    test('late at night the reminder waits for waking hours', () {
      final DateTime now = DateTime(2026, 11, 4, 23, 50);
      final PlannedReminder tribute = ReturnReminders.plan(
        _state(1, '2026-11-04', now),
        now,
      ).firstWhere((r) => r.id == ReturnReminders.tributeId);
      expect(tribute.at, DateTime(2026, 11, 5, ReturnReminders.latestHour));

      final DateTime early = DateTime(2026, 11, 4, 6);
      final PlannedReminder morning = ReturnReminders.plan(
        _state(1, '2026-11-04', early),
        early,
      ).firstWhere((r) => r.id == ReturnReminders.tributeId);
      expect(morning.at.hour, ReturnReminders.earliestHour);
    });

    test('there is always one comeback nudge, three days out', () {
      final DateTime now = DateTime(2026, 11, 4, 19);
      final List<PlannedReminder> plan =
          ReturnReminders.plan(_state(0, '', now), now);
      expect(plan, hasLength(2));
      final PlannedReminder comeback =
          plan.firstWhere((r) => r.id == ReturnReminders.comebackId);
      expect(comeback.at, DateTime(2026, 11, 7, 19));
    });
  });

  group('reminders', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
    });

    test('nothing is scheduled before the player says yes', () async {
      final _FakePlatform platform = _FakePlatform();
      final ReturnReminders reminders =
          ReturnReminders(platform: platform, supported: true);
      final DateTime now = DateTime(2026, 11, 4, 12);

      expect(await reminders.shouldOffer(), isTrue);
      await reminders.refresh(_state(1, '2026-11-04', now), now: now);
      expect(platform.pending, isEmpty);

      expect(await reminders.setEnabled(true), isTrue);
      expect(platform.permissionAsks, 1);
      expect(await reminders.shouldOffer(), isFalse);
      await reminders.refresh(_state(1, '2026-11-04', now), now: now);
      expect(platform.pending.keys, unorderedEquals(<int>[101, 102]));
    });

    test('a no cancels what is pending and keeps it off', () async {
      final _FakePlatform platform = _FakePlatform();
      final ReturnReminders reminders =
          ReturnReminders(platform: platform, supported: true);
      final DateTime now = DateTime(2026, 11, 4, 12);
      await reminders.setEnabled(true);
      await reminders.refresh(_state(1, '2026-11-04', now), now: now);
      expect(platform.pending, isNotEmpty);

      await reminders.setEnabled(false);
      expect(platform.pending, isEmpty);
      await reminders.refresh(_state(1, '2026-11-04', now), now: now);
      expect(platform.pending, isEmpty);
      expect(await reminders.shouldOffer(), isFalse);
    });

    test('the web and desktop schedule nothing', () async {
      final ReturnReminders reminders = ReturnReminders(supported: false);
      expect(await reminders.shouldOffer(), isFalse);
      expect(await reminders.requestPermission(), isFalse);
    });
  });

  test('the wallet snapshot carries the tribute', () {
    final EconomyProgressSnapshot snapshot = EconomyProgressSnapshot.fromJson(
      <String, dynamic>{
        'indiaAup': 1,
        'internationalAup': 0,
        'awardedEventIds': <String>[],
        'lastActiveAtMs': 0,
        'prevActiveAtMs': 0,
        'lastActiveDayKey': '',
        'activityScore': 0,
        'abandonedGames': 0,
        'matchesPlayed': 0,
        'finishPermilleSum': 0,
        'registeredStarterGranted': true,
        'tributeStreak': 3,
        'tributeLastDayKey': '2026-11-04',
        'tributeLastClaimAtMs': 1793772548969,
        'tributeLastAmount': 100000,
      },
    );
    expect(snapshot.tributeStreak, 3);
    expect(snapshot.tributeLastDayKey, '2026-11-04');
    expect(snapshot.tributeLastAmount, 100000);
  });
}
