// lib/game/bot/aura_variance.dart
//
// Aura in every decision: how far a bot's read of its own hand strays from
// the truth.
//
// Every decision in BotAdvisor.suggest compares the bot's hand against a
// threshold: is this worth opening, is the equity enough for the price, is
// it strong enough to call an all-in. Before this module, Aura only nudged
// a few of those thresholds one way, so a weak bot was predictably loose: a
// difficulty slider, not a person.
//
// Here Aura sets the size of a zero-mean error on the bot's *read*, the
// equity it believes it has. The error is applied once, before any
// threshold is checked, so every comparison downstream inherits the same
// misjudgement and the decision stays internally consistent: a bot that
// overrates its hand calls a little too wide and bets a little too thin;
// one that underrates it folds a little too much, in the same session.
//
//   readError = sigma(aura) * (sqrt(h) * zHand + sqrt(1 - h) * zDecision)
//   sigma(aura) = sigmaMax * (1 - auraSkill) ^ shapePower
//
// zHand is drawn once per bot per hand, so a misread persists across the
// streets of that hand the way a human sticks with "I put him on a bluff".
// zDecision is fresh every decision. Both are approximately standard normal
// (Irwin-Hall, three uniforms) and seeded from the table, hand and spot, so
// the same spot always plays the same way: replays, tests and the decision
// cache all stay deterministic.
//
// The curve matches the ICM guard's (sigmaMax 0.85 on its own scale, power
// 1.4): Aura 95 is about +-0.2% equity, Aura 50 about +-3.8%, Aura 20 about
// +-7.3% (one standard deviation). Fear/greed (memory.dart) stays the
// direction; this is only the spread. See
// docs/BOT_HUMAN_INTELLIGENCE_AURA_SPEC.md, "Aura in every decision".

import 'dart:math' show pow, sqrt;

class BotAuraVariance {
  BotAuraVariance._();

  /// One standard deviation of read error, in equity, at Aura 0.
  static const double sigmaMax = 0.10;

  /// How fast the error shrinks as Aura rises; same curve as BotIcmGuard.
  static const double shapePower = 1.4;

  /// Share of the error's variance that persists for the whole hand.
  static const double handShare = 0.6;

  /// Turns the read error off. Only the simulation report sets it, to play
  /// the same seeded tables with and without Aura variance side by side
  /// (test/bot_aura_simulation_report_test.dart). Never set in the app.
  static bool debugDisabledForReport = false;

  /// One standard deviation of read error for [auraSkill] (0..1).
  static double sigmaFor(double auraSkill) {
    final double gap = 1.0 - auraSkill.clamp(0.0, 1.0);
    return sigmaMax * pow(gap, shapePower).toDouble();
  }

  /// The bot's read error for one decision, in equity units. Zero mean;
  /// at most about three [sigmaFor] either way.
  ///
  /// [handKey] must be the same for every decision of one bot in one hand;
  /// [decisionKey] must differ between decisions.
  static double readError({
    required double auraSkill,
    required String handKey,
    required String decisionKey,
  }) {
    if (debugDisabledForReport) return 0.0;
    final double sigma = sigmaFor(auraSkill);
    if (sigma <= 0) return 0.0;
    final double zHand = unitNormal('$handKey|aura_hand_read');
    final double zDecision = unitNormal('$decisionKey|aura_decision_read');
    return sigma *
        (sqrt(handShare) * zHand + sqrt(1.0 - handShare) * zDecision);
  }

  /// An approximately standard-normal draw (mean 0, variance 1, range +-3)
  /// seeded by [key]: the sum of three seeded uniforms, recentred.
  static double unitNormal(String key) {
    final double sum = _unit('$key|1') + _unit('$key|2') + _unit('$key|3');
    return sum * 2.0 - 3.0;
  }

  /// A seeded uniform in [0, 1]: FNV-1a over the key, then the MurmurHash3
  /// finaliser so keys that differ only in their last character still land
  /// far apart (plain FNV leaves them within a fraction of a percent).
  static double _unit(String key) {
    int hash = 0x811C9DC5;
    for (int i = 0; i < key.length; i++) {
      hash = _mul32(hash ^ key.codeUnitAt(i), 0x01000193);
    }
    hash ^= hash >> 16;
    hash = _mul32(hash, 0x85EBCA6B);
    hash ^= hash >> 13;
    hash = _mul32(hash, 0xC2B2AE35);
    hash ^= hash >> 16;
    return (hash & 0xFFFFFFFF) / 0xFFFFFFFF;
  }

  /// 32-bit multiply that stays exact on the web, where ints are doubles and
  /// a full 32x32-bit product would lose its low bits.
  static int _mul32(int a, int b) {
    final int aLo = a & 0xFFFF;
    final int aHi = (a >> 16) & 0xFFFF;
    return ((aLo * b) + (((aHi * b) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }
}
