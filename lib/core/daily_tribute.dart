// The daily tribute: AUP for coming back, once per calendar day.
//
// The server decides (backend/src/economy/tribute.js); this file mirrors its
// rules so the home screen can say what today's claim would pay, and when
// the next one opens, without asking it.

/// What claiming on day 1, 2, … 7 of a run pays; day 7 onwards pays the top
/// step. Mirrors DAILY_TRIBUTE_LADDER in backend/src/economy/constants.js.
const List<int> kDailyTributeLadder = <int>[
  50000,
  75000,
  100000,
  125000,
  150000,
  200000,
  300000,
];

/// What a claim on day [streak] of a run pays.
int dailyTributeAmount(int streak) {
  final int step = streak.clamp(1, kDailyTributeLadder.length);
  return kDailyTributeLadder[step - 1];
}

/// A calendar day as the server writes it: YYYY-MM-DD.
String tributeDayKey(DateTime day) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${day.year.toString().padLeft(4, '0')}-${two(day.month)}-'
      '${two(day.day)}';
}

/// The tribute as the player sees it at a given moment.
class DailyTributeState {
  /// The run the last claim reached (0: never claimed).
  final int lastStreak;

  /// The player's day of the last claim (YYYY-MM-DD), or ''.
  final String lastDayKey;

  /// The moment of the local reading.
  final DateTime now;

  const DailyTributeState({
    required this.lastStreak,
    required this.lastDayKey,
    required this.now,
  });

  String get todayKey => tributeDayKey(now);
  String get yesterdayKey =>
      tributeDayKey(DateTime(now.year, now.month, now.day - 1));

  /// Today's tribute is already in the wallet.
  bool get claimedToday => lastDayKey.isNotEmpty && lastDayKey == todayKey;

  /// Today's tribute is waiting. (The server can still refuse a claim made
  /// minutes after one under another time zone; the app then shows it as
  /// claimed.)
  bool get canClaim =>
      lastDayKey.isEmpty || lastDayKey.compareTo(todayKey) < 0;

  /// The run a claim today reaches: one more than yesterday's, or day 1.
  int get streakIfClaimed {
    if (claimedToday) return lastStreak;
    if (lastStreak > 0 && lastDayKey == yesterdayKey) return lastStreak + 1;
    return 1;
  }

  /// What today's claim pays.
  int get amountToday => dailyTributeAmount(streakIfClaimed);

  /// The run shown on the home screen: today's claim, or the one already made.
  int get displayStreak => canClaim ? streakIfClaimed : lastStreak;

  /// What tomorrow's claim pays, if the run is kept.
  int get amountTomorrow => dailyTributeAmount(displayStreak + 1);

  /// The next local midnight: when tomorrow's tribute opens.
  DateTime get nextOpensAt => DateTime(now.year, now.month, now.day + 1);

  /// A run of at least two days that a missed today would break.
  bool get streakAtRisk => canClaim && streakIfClaimed > 1;
}
