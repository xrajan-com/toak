// lib/game/bot/tournament_context.dart
//
// Live table standings and ICM-based tournament awareness for bots.
//
// This is the "who's ahead, who's challenging, what is my current prize
// position actually worth" layer described in
// docs/BOT_HUMAN_INTELLIGENCE_AURA_SPEC.md. It reads only public
// GameEngine/Player state (chip counts, elimination flags, the configured
// payout table) and never mutates anything, so it's safe to call from UI
// code or tests as well as from bot decision logic.
//
// Everything here is a no-op (returns null / a neutral value) when the
// table has no payout table configured — i.e. plain cash-style play is
// completely unaffected.

import 'dart:math' show max;

import 'package:ten_of_a_kind_poker/game/bot/icm.dart'
    show icmEquities, icmEquityFor;
import 'package:ten_of_a_kind_poker/game/game_engine.dart' show GameEngine;
import 'package:ten_of_a_kind_poker/game/models.dart' show Player;

/// How dangerous/vulnerable a stack looks relative to the rest of the live
/// field. This is the primitive "who's ahead, who's challenged" reads key
/// off — both for a bot's own standing and for reading an opponent.
enum StackThreat { chipLeader, bigStack, mediumStack, shortStack, crippled }

/// A snapshot of one seat's competitive position at the table, independent
/// of any single hand's cards. Recompute per decision — it's cheap (a sort
/// over the live seats) and always reflects the current chip counts.
class TableStanding {
  final int seatIndex;

  /// 1 = chip leader among currently-alive players.
  final int rank;
  final int totalAlive;
  final int heroStack;
  final int leaderStack;
  final int averageStack;
  final double stackToAverage;
  final bool isChipLeader;
  final StackThreat threat;

  /// How many of the currently-alive players would be paid something if
  /// the tournament ended on the next elimination.
  final int paidAlive;

  /// 0.0 = far from any payout-count change, 1.0 = exactly one elimination
  /// away from crossing a payout boundary (the "money bubble" or a pay
  /// jump). Used to bias toward locking up a position vs. gambling for a
  /// better one.
  final double bubbleFactor;

  const TableStanding({
    required this.seatIndex,
    required this.rank,
    required this.totalAlive,
    required this.heroStack,
    required this.leaderStack,
    required this.averageStack,
    required this.stackToAverage,
    required this.isChipLeader,
    required this.threat,
    required this.paidAlive,
    required this.bubbleFactor,
  });

  // Deliberately NOT `&& chips > 0`: a player mid-all-in this hand has
  // chips == 0 *before the hand resolves*, but is very much still alive in
  // the tournament (`isOut` is only ever set at hand settlement, once a
  // bust is final). Standings/ICM must count them, or every all-in
  // decision would compute against a field that's silently missing the
  // one seat actually contesting the pot with hero.
  static List<int> _aliveSeats(GameEngine eng) => <int>[
        for (int i = 0; i < eng.players.length; i++)
          if (!eng.players[i].isOut) i,
      ];

  static StackThreat classify(int stack, int averageStack, int bigBlind) {
    if (bigBlind > 0 && stack <= bigBlind * 10) return StackThreat.crippled;
    if (averageStack <= 0) return StackThreat.mediumStack;
    final double ratio = stack / averageStack;
    if (ratio <= 0.5) return StackThreat.shortStack;
    if (ratio >= 2.0) return StackThreat.bigStack;
    return StackThreat.mediumStack;
  }

  /// Builds the standing for [seatIndex] from the engine's current live
  /// state. Returns null when there's no payout table configured (nothing
  /// tournament-shaped to reason about) or the seat isn't currently alive.
  static TableStanding? compute(GameEngine eng, int seatIndex) {
    if (eng.config.payoutTable == null && eng.config.payoutForRank == null) {
      return null;
    }
    if (seatIndex < 0 || seatIndex >= eng.players.length) return null;
    final Player hero = eng.players[seatIndex];
    if (hero.isOut) return null;

    final List<int> aliveIdx = _aliveSeats(eng);
    if (aliveIdx.isEmpty || !aliveIdx.contains(seatIndex)) return null;

    final List<int> stacks =
        aliveIdx.map((i) => eng.players[i].chips).toList(growable: false);
    final int totalAlive = aliveIdx.length;
    final int totalChips = stacks.fold<int>(0, (a, b) => a + b);
    final int averageStack =
        totalAlive > 0 ? (totalChips / totalAlive).round() : 0;
    final int leaderStack =
        stacks.isEmpty ? 0 : stacks.reduce((a, b) => a > b ? a : b);

    final List<int> orderedAlive = List<int>.from(aliveIdx)
      ..sort((a, b) {
        final int c = eng.players[b].chips.compareTo(eng.players[a].chips);
        if (c != 0) return c;
        return a.compareTo(b); // stable tie-break
      });
    final int rank = orderedAlive.indexOf(seatIndex) + 1;

    int paidAlive = 0;
    for (int r = 1; r <= totalAlive; r++) {
      if (eng.payoutForRank(r) > 0) paidAlive++;
    }
    // A winner-take-all structure has no bubble at all: busting 2nd and
    // busting last both pay zero, so surviving one more elimination is
    // worth nothing in $ terms and ICM reduces exactly to chip EV. Only a
    // structure paying more than one live place can create real bubble
    // pressure. Without the `paidAlive < 2` guard, 1/(totalAlive - 1)
    // spikes to 1.0 three- and two-handed in every winner-take-all game —
    // biasing bots to fold at the final table, which is precisely where
    // they should be gambling to win. That's the live default for this
    // app whenever no explicit payout table is configured, so this guard
    // is load-bearing, not defensive.
    final int distanceToJump = (totalAlive - paidAlive).clamp(0, totalAlive);
    final double bubbleFactor = (paidAlive < 2 || distanceToJump <= 0)
        ? 0.0
        : (1.0 / distanceToJump).clamp(0.0, 1.0).toDouble();

    final int heroStack = hero.chips;
    final double stackToAverage =
        averageStack > 0 ? heroStack / averageStack : 1.0;

    return TableStanding(
      seatIndex: seatIndex,
      rank: rank,
      totalAlive: totalAlive,
      heroStack: heroStack,
      leaderStack: leaderStack,
      averageStack: averageStack,
      stackToAverage: stackToAverage,
      isChipLeader: rank == 1,
      threat: classify(heroStack, averageStack, eng.bigBlind),
      paidAlive: paidAlive,
      bubbleFactor: bubbleFactor,
    );
  }

  /// Classifies a specific seat's stack threat level without building a
  /// full [TableStanding] for it — the cheap way to read "is the player
  /// who's leaning on me actually dangerous, or are they pot-committed and
  /// desperate." Returns null if the seat isn't alive.
  static StackThreat? threatFor(GameEngine eng, int seatIndex) {
    if (seatIndex < 0 || seatIndex >= eng.players.length) return null;
    final Player p = eng.players[seatIndex];
    if (p.isOut) return null;
    final List<int> aliveIdx = _aliveSeats(eng);
    if (aliveIdx.isEmpty) return null;
    final int totalChips =
        aliveIdx.fold<int>(0, (a, i) => a + eng.players[i].chips);
    final int averageStack =
        aliveIdx.isNotEmpty ? (totalChips / aliveIdx.length).round() : 0;
    final int leaderStack = aliveIdx
        .map((i) => eng.players[i].chips)
        .reduce((a, b) => a > b ? a : b);
    if (p.chips > 0 && p.chips == leaderStack && aliveIdx.length > 1) {
      return StackThreat.chipLeader;
    }
    return classify(p.chips, averageStack, eng.bigBlind);
  }
}

/// ICM-flavored evaluation of a stack-threatening decision — shoving, or
/// calling an opponent's all-in — versus folding.
class IcmDecision {
  /// Positive means continuing (call/shove) is worth more in $ equity than
  /// folding; negative means ICM says fold even if chip-EV looks fine.
  final double equityDeltaVsFold;
  final double foldEquity;
  final double continueEquity;

  const IcmDecision({
    required this.equityDeltaVsFold,
    required this.foldEquity,
    required this.continueEquity,
  });

  /// Evaluates a heads-up-style stack-off between [heroSeat] and
  /// [villainSeat]: hero risks [atRisk] chips with [winProb] chance of
  /// winning [potIfWon] total chips (already includes hero's own money in
  /// the pot).
  ///
  /// Known, documented simplification: this models the two players
  /// directly contesting the pot and treats every other live seat's stack
  /// as unchanged. A true multiway all-in (three or more live stacks still
  /// contesting one pot) isn't solved here — see
  /// docs/BOT_HUMAN_INTELLIGENCE_AURA_SPEC.md for why that's an acceptable
  /// v1 scope and what a fuller version would need.
  static IcmDecision? evaluate({
    required GameEngine eng,
    required int heroSeat,
    required int villainSeat,
    required int atRisk,
    required int potIfWon,
    required double winProb,
  }) {
    if (eng.config.payoutTable == null && eng.config.payoutForRank == null) {
      return null;
    }
    if (heroSeat < 0 ||
        heroSeat >= eng.players.length ||
        villainSeat < 0 ||
        villainSeat >= eng.players.length ||
        heroSeat == villainSeat) {
      return null;
    }

    final List<int> aliveIdx = TableStanding._aliveSeats(eng);
    if (!aliveIdx.contains(heroSeat) || !aliveIdx.contains(villainSeat)) {
      return null;
    }

    final int totalAlive = aliveIdx.length;
    final List<int> payouts = <int>[
      for (int r = 1; r <= totalAlive; r++) eng.payoutForRank(r),
    ];

    List<int> stacksAt(int heroDelta, int villainDelta) => <int>[
          for (final int i in aliveIdx)
            if (i == heroSeat)
              max(0, eng.players[i].chips + heroDelta)
            else if (i == villainSeat)
              max(0, eng.players[i].chips + villainDelta)
            else
              eng.players[i].chips,
        ];

    final int heroSlot = aliveIdx.indexOf(heroSeat);

    // Fold: hero's stack is untouched; villain simply collects the pot as
    // it stands right now, uncontested (hero's hypothetical call amount
    // never actually goes in).
    final double foldEquity =
        icmEquityFor(heroSlot, stacksAt(0, eng.pot), payouts);

    // Hero wins the confrontation: hero collects the whole pot (their own
    // call plus everything already in it, net of what they put in).
    // Villain, having already pushed their contribution into the pot
    // before this decision, simply stays at whatever they have left.
    final List<double> winStacks =
        icmEquities(stacksAt(potIfWon - atRisk, 0), payouts);

    // Hero loses: hero's call is gone; villain collects the whole pot on
    // top of whatever they had left.
    final List<double> loseStacks =
        icmEquities(stacksAt(-atRisk, potIfWon), payouts);

    final double winEquity = winStacks[heroSlot];
    final double loseEquity = loseStacks[heroSlot];
    final double clampedWinProb = winProb.clamp(0.0, 1.0);
    final double continueEquity =
        clampedWinProb * winEquity + (1 - clampedWinProb) * loseEquity;

    return IcmDecision(
      equityDeltaVsFold: continueEquity - foldEquity,
      foldEquity: foldEquity,
      continueEquity: continueEquity,
    );
  }
}
