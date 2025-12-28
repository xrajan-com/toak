import 'dart:math' as math;

import 'core.dart' show Card, GamePhase;
import 'hand_evaluator.dart' show HandRank;

/* ===================== Payout helpers ===================== */

class PayoutTable {
  /// 1-based rank mapping -> amount (index 0 == rank 1)
  final List<int> byRank;
  const PayoutTable(this.byRank);

  int pays(int rank) {
    if (rank < 1 || rank > byRank.length) return 0;
    return byRank[rank - 1];
  }

  /// Absolute amounts. Index 0 = 1st place.
  factory PayoutTable.fixed(List<int> amounts) =>
      PayoutTable(List<int>.from(amounts));

  /// From percentages (e.g., [0.5, 0.3, 0.2]) of a total prize pool.
  /// Remainder chips distributed 1-by-1 from 1st downward.
  factory PayoutTable.fromPercentages(int total, List<double> percents) {
    if (total < 0) throw ArgumentError('total must be >= 0');
    if (percents.isEmpty) return const PayoutTable([]);
    final raw = <int>[];
    int sum = 0;
    for (final p in percents) {
      final v = (total * p).floor();
      raw.add(v);
      sum += v;
    }
    int remainder = total - sum, i = 0;
    while (remainder-- > 0) {
      raw[i++ % raw.length] += 1;
    }
    return PayoutTable(raw);
  }

  /// Inverse-rank weighted distribution for `places`. Power controls top-heaviness.
  factory PayoutTable.inverseRankWeighted({
    required int total,
    required int places,
    double power = 1.0,
  }) {
    if (places <= 0 || total <= 0) return const PayoutTable([]);
    final weights = <double>[
      for (int i = 1; i <= places; i++) 1.0 / math.pow(i, power).toDouble()
    ];
    final wsum = weights.fold<double>(0, (a, b) => a + b);

    final raw = <int>[];
    int acc = 0;
    for (final w in weights) {
      final v = (total * (w / wsum)).floor();
      raw.add(v);
      acc += v;
    }

    int remainder = total - acc, idx = 0;
    while (remainder-- > 0) {
      raw[idx++ % raw.length] += 1;
    }
    return PayoutTable(raw);
  }

  /// Classic top-3 50/30/20.
  factory PayoutTable.top3Classic(int total) =>
      PayoutTable.fromPercentages(total, const [0.5, 0.3, 0.2]);

  /// Top-heavy for N places using inverse rank with mild power.
  factory PayoutTable.topHeavy(int total, int places) =>
      PayoutTable.inverseRankWeighted(total: total, places: places, power: 1.2);
}

/* ===================== Config ===================== */

class BlindLevel {
  final int smallBlind;
  final int bigBlind;
  const BlindLevel({
    required this.smallBlind,
    required this.bigBlind,
  })  : assert(smallBlind > 0),
        assert(bigBlind > 0),
        assert(bigBlind >= smallBlind);
}

/// Tournament-style blind progression driven by completed dealer orbits.
///
/// - Level 0 is `levels.first`.
/// - The engine may cap at `levels.last`.
class BlindSchedule {
  /// Ordered list of blind levels, lowest → highest.
  final List<BlindLevel> levels;

  /// How many *completed dealer orbits* each level lasts.
  ///
  /// An "orbit" increments when the dealer button wraps around the table
  /// (skipping ineligible seats).
  final int orbitsPerLevel;

  const BlindSchedule({
    required this.levels,
    this.orbitsPerLevel = 5,
  }) : assert(orbitsPerLevel > 0);
}

class GameConfig {
  final int smallBlind;
  final int bigBlind;
  final int maxPlayers;
  final int minPlayersToStart;
  final int ante;
  final bool allowButtonStraddle;
  final int? tableSeed;

  /// Optional blind schedule for tournament pacing.
  /// If provided, the engine uses `levels.first` as the starting blinds and
  /// advances based on completed dealer orbits.
  final BlindSchedule? blindSchedule;

  /// Optional tournament payout hooks.
  final PayoutTable? payoutTable; // if provided, used first
  final int Function(int rank)? payoutForRank; // fallback callback

  const GameConfig({
    this.smallBlind = 50,
    this.bigBlind = 100,
    this.maxPlayers = 10,
    this.minPlayersToStart = 2,
    this.ante = 0,
    this.allowButtonStraddle = false,
    this.tableSeed,
    this.blindSchedule,
    this.payoutTable,
    this.payoutForRank,
  })  : assert(bigBlind > 0),
        assert(smallBlind > 0),
        assert(maxPlayers >= 2);
}

/* ===================== Player & Snapshots ===================== */

class Player {
  final String id;
  final String name;
  int chips;
  int enduranceMinutes;
  int aura;
  final bool isBot;

  // Hand state
  bool folded = false;
  bool allIn = false;
  int betThisStreet = 0;
  int contributedThisHand = 0;
  List<Card> hole = const [];

  // Showdown info
  HandRank? best;

  // Seat state
  bool sittingOut = false;

  // Tournament elimination state (persists across hands)
  bool isOut = false;

  Player({
    required this.id,
    required this.name,
    required this.chips,
    this.enduranceMinutes = 15,
    this.aura = 60,
    this.isBot = false,
  });

  void resetForNewHand() {
    folded = false;
    allIn = false;
    betThisStreet = 0;
    contributedThisHand = 0;
    hole = const [];
    best = null;
    // isOut is NOT reset here; call resetTournament() if needed.
  }

  @override
  String toString() => '$name(chips:$chips${isOut ? ", OUT" : ''})';
}

class GameSnapshot {
  final GamePhase phase;
  final int handNumber;
  final int dealerIndex;
  final int actingIndex;
  final int currentBet;
  final int pot;
  final List<Card> community;
  final List<PlayerSnapshot> players;
  const GameSnapshot({
    required this.phase,
    required this.handNumber,
    required this.dealerIndex,
    required this.actingIndex,
    required this.currentBet,
    required this.pot,
    required this.community,
    required this.players,
  });
}

class PlayerSnapshot {
  final String id;
  final String name;
  final int chips;
  final bool folded;
  final bool allIn;
  final bool sittingOut;
  final int betThisStreet;
  final int contributedThisHand;
  final List<Card> hole;
  final HandRank? best;
  final int enduranceMinutes;
  final int aura;
  const PlayerSnapshot({
    required this.id,
    required this.name,
    required this.chips,
    required this.folded,
    required this.allIn,
    required this.sittingOut,
    required this.betThisStreet,
    required this.contributedThisHand,
    required this.hole,
    required this.best,
    required this.enduranceMinutes,
    required this.aura,
  });
}

/* ===================== Pots & Payout DTOs ===================== */

class PotSlice {
  int amount;
  final Set<int> eligibles;
  PotSlice(this.amount, this.eligibles);
}

class Payout {
  final int playerIndex;
  final int amount;
  final HandRank? best; // null if no showdown
  const Payout({required this.playerIndex, required this.amount, this.best});
}
