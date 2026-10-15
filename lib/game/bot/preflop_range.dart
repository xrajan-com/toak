// lib/game/bot/preflop_range.dart
//
// How many hands a bot plays before the flop.
//
// Measured by test/bot_aura_simulation_report_test.dart, bots voluntarily
// played 81-97% of hands at every Aura level: calling one or two big blinds
// always counted as "cheap", so nearly any two cards limped or called. Real
// players play roughly 15-25% (strong) to 40-60% (weak).
//
// This module gives every bot a target share of starting hands, ranks its
// hand against all 1,326 two-card combinations by six-handed equity (from
// the 50,000-deal preflop table), and turns a voluntary call, bet or raise
// with a hand outside that share into a check or a fold:
//
//   Aura 95 ~20%   Aura 80 ~25%   Aura 50 ~35%   Aura 20 ~50%
//
// scaled by temperament (maniacs looser, rocks tighter), position (the
// button plays far more than first to act), what the bot is facing (a raise
// narrows it, a re-raise more), and mood (greed widens, fear tightens).
// The bot judges its hand through its Aura read error, so the edge of a weak
// bot's range is blurry and a strong bot's is sharp.
//
// It never touches stack-off spots (facing an all-in, or ten big blinds or
// less), which keep their own push/fold logic.

import 'package:ten_of_a_kind_poker/game/core.dart' show Card, Rank, Suit;
import 'package:ten_of_a_kind_poker/game/equity/preflop_equity_table.dart'
    show canonicalPreflopClass, lookupPreflopEquity;
import 'package:ten_of_a_kind_poker/game/models.dart'
    show BotSkill, BotTemperament;

class BotPreflopRange {
  BotPreflopRange._();

  /// Target share of starting hands a bot plays, by Aura (0..100), before
  /// temperament, position and situation. Linear between these points.
  ///
  /// Calibrated against the simulation report so that the *measured* share
  /// across a real mix of temperaments and seats lands on the targets
  /// (Aura 95 ~20%, 80 ~25%, 50 ~35%, 20 ~50%). Weak Aura levels draw more
  /// maniacs and calling stations, so their base sits below the target.
  static const List<(int, double)> _auraCurve = <(int, double)>[
    (0, 0.48),
    (20, 0.42),
    (50, 0.29),
    (80, 0.245),
    (95, 0.225),
    (100, 0.21),
  ];

  static double baseShareForAura(int aura) {
    final int a = aura.clamp(0, 100);
    for (int i = 1; i < _auraCurve.length; i++) {
      final (int x1, double y1) = _auraCurve[i];
      if (a <= x1) {
        final (int x0, double y0) = _auraCurve[i - 1];
        return y0 + (y1 - y0) * (a - x0) / (x1 - x0);
      }
    }
    return _auraCurve.last.$2;
  }

  /// The share of starting hands this bot plays in this spot.
  ///
  /// [seatsFromButton]: 0 on the button, 1 cutoff, 2 hijack, 3+ earlier;
  /// blinds are passed as [isSmallBlind] / [isBigBlind]. [raisesFaced]: 0
  /// unopened (or limped), 1 facing an open raise, 2+ facing a re-raise.
  static double targetShare({
    required int aura,
    required BotTemperament temperament,
    required BotSkill skill,
    required int seatsFromButton,
    required bool isSmallBlind,
    required bool isBigBlind,
    required int raisesFaced,
    required double fearGreed,
  }) {
    double share = baseShareForAura(aura);
    share *= switch (temperament) {
      BotTemperament.aggressive => 1.35,
      BotTemperament.stoic => 1.20,
      BotTemperament.worldChamp => 0.85,
    };
    if (skill == BotSkill.fluke) share *= 1.10;

    final double position = isBigBlind
        ? 1.30
        : isSmallBlind
            ? 0.90
            : switch (seatsFromButton) {
                0 => 1.40,
                1 => 1.15,
                2 => 0.95,
                _ => 0.75,
              };
    share *= position;

    share *= switch (raisesFaced) {
      0 => 1.0,
      1 => 0.50,
      _ => 0.25,
    };
    share *= 1.0 + 0.25 * fearGreed.clamp(-1.0, 1.0);
    return share.clamp(0.03, 0.90).toDouble();
  }

  /// Six-handed equity of [hole] from the preflop table, or null if the
  /// table has no entry.
  static double? handEquity(List<Card> hole) =>
      lookupPreflopEquity(hole, 6)?.equity;

  /// Share of all 1,326 starting combinations at least as strong as a hand
  /// with six-handed [equity]: 0.0 is the best hand, 1.0 the worst.
  static double topShareOfEquity(double equity) {
    final ranking = _ranking();
    double above = 0;
    for (final (double e, int combos) in ranking) {
      if (e > equity) {
        above += combos;
      } else {
        break;
      }
    }
    return above / 1326.0;
  }

  static final Map<String, double> _topShareByClass = <String, double>{};

  /// [topShareOfEquity] for a two-card hand, cached by hand class (AKs,
  /// T9o, 77...). Used when a bot weighs the hands an opponent might hold.
  static double topShareOfHole(List<Card> hole) {
    if (hole.length < 2) return 1.0;
    final String key = canonicalPreflopClass(hole[0], hole[1]);
    return _topShareByClass.putIfAbsent(key, () {
      final double? equity = handEquity(hole);
      return equity == null ? 1.0 : topShareOfEquity(equity);
    });
  }

  /// Whether a bot that reads its hand with [readError] (equity units, see
  /// aura_variance.dart) counts it inside [share].
  static bool inRange({
    required List<Card> hole,
    required double share,
    double readError = 0.0,
  }) {
    final double? equity = handEquity(hole);
    if (equity == null) return true;
    // Scaled so a one-sigma misread moves an Aura-20 bot's hand about ten
    // percentile points (and an Aura-95 bot's well under one).
    return topShareOfEquity(equity + readError * 0.4) < share;
  }

  static List<(double, int)>? _cache;

  /// Every starting-hand class with its six-handed equity and combination
  /// count, strongest first.
  static List<(double, int)> _ranking() {
    final cached = _cache;
    if (cached != null) return cached;
    final out = <(double, int)>[];
    final ranks = Rank.values;
    for (int i = 0; i < ranks.length; i++) {
      for (int j = i; j < ranks.length; j++) {
        if (i == j) {
          final e = handEquity([
            Card(ranks[i], Suit.spades),
            Card(ranks[j], Suit.hearts),
          ]);
          if (e != null) out.add((e, 6));
        } else {
          final suited = handEquity([
            Card(ranks[i], Suit.spades),
            Card(ranks[j], Suit.spades),
          ]);
          final offsuit = handEquity([
            Card(ranks[i], Suit.spades),
            Card(ranks[j], Suit.hearts),
          ]);
          if (suited != null) out.add((suited, 4));
          if (offsuit != null) out.add((offsuit, 12));
        }
      }
    }
    out.sort((a, b) => b.$1.compareTo(a.$1));
    return _cache = out;
  }
}
