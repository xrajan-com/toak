// lib/game/bot/think_time.dart
//
// How long a bot appears to think, and why.
//
// The old model multiplied a base delay by hand strength and by
// `_estimateConfidence`, which is itself a hand-strength proxy — so think
// time was essentially a function of hole cards, doubled. A bot dwelt on a
// trivial weak-hand fold and snap-acted a genuinely agonising call, and it
// leaked the same amount about its holding whether it was a 95-aura pro or
// a 20-aura fish.
//
// This module replaces that with two ideas, both pure and testable:
//
//  1. CALIBRATION. Aura does not set speed, it sets how well time is
//     matched to how hard the decision actually is. A strong player snaps
//     the obvious and genuinely tanks the close ones — precisely because
//     they can *see* that it is close. A weak player's timing is flat, and
//     what slowness they have lands in the wrong places. So aura widens
//     the gap between easy and hard rather than shortening everything.
//
//  2. LEAKAGE. How much think-time reveals about hand strength scales
//     *inversely* with aura. A low-aura bot's tank genuinely means "I am
//     weak" — a readable, exploitable tell. A pro's tank means only "this
//     spot is close" and says nothing about which way, because a strong
//     player balances their timing. Learning to tell those apart is the
//     read the human player gets to develop.
//
// Mood rides on top: a steaming bot is impulsive and fast, a rattled one
// agonises. See docs/BOT_HUMAN_INTELLIGENCE_AURA_SPEC.md.

import 'dart:math' show max;

class BotThinkTime {
  /// Below this much distance between win probability and the equity the
  /// spot requires, a decision starts to feel close. A quarter of the
  /// equity range away in either direction is a snap call or a snap fold.
  static const double _marginSpan = 0.22;

  /// How genuinely close and consequential a decision is: 0.0 trivial,
  /// 1.0 agonising.
  ///
  /// [winProb] is the bot's estimated equity, [requiredEquity] what this
  /// spot actually demands — the distance between them is the honest
  /// measure of difficulty, and is exactly what a hand-strength proxy
  /// cannot express. [stackFrac] is the fraction of the stack at risk, so
  /// the same marginal call is harder when it can bust you.
  static double difficultyFor({
    required bool hasToCall,
    required double winProb,
    required double requiredEquity,
    required double stackFrac,
    required bool facingAllIn,
  }) {
    final double margin = (winProb - requiredEquity).abs();
    double difficulty =
        (1.0 - (margin / _marginSpan)).clamp(0.0, 1.0).toDouble();

    // Checking back for free is nearly always trivial, whatever the cards.
    if (!hasToCall) difficulty *= 0.45;

    // Stakes sharpen deliberation: people agonise over decisions that can
    // end their tournament, and shrug off decisions that cannot.
    difficulty *= 0.75 + 0.55 * stackFrac.clamp(0.0, 1.0);
    if (facingAllIn) difficulty += 0.15;

    return difficulty.clamp(0.0, 1.0).toDouble();
  }

  /// Multiplier applied to a bot's baseline tempo.
  ///
  /// [difficulty] from [difficultyFor]; [auraSkill] 0..1; [strength] the
  /// hand-strength proxy (used only for leakage, and only for low-aura
  /// bots); [fearGreedSigned] -1 (rattled) .. +1 (steaming).
  static double delayFactor({
    required double difficulty,
    required double auraSkill,
    required double strength,
    required double fearGreedSigned,
  }) {
    final double d = difficulty.clamp(0.0, 1.0).toDouble();
    final double a = auraSkill.clamp(0.0, 1.0).toDouble();

    // CALIBRATION. `range` is how much difficulty moves the needle at all,
    // `centre` the bot's overall pace. A high-aura bot has a wide range and
    // a quicker centre: very fast on the obvious, slower than anyone on the
    // genuinely close. A low-aura bot's range is narrow — its timing barely
    // distinguishes a trivial fold from a coin-flip for its stack.
    // The centre slope is deliberately gentle. A steeper one made a pro's
    // factor on a *hard* decision dip just below a weak bot's, so the
    // "expert tanks longer on close spots" behaviour survived only because
    // high-aura seats happen to carry a slower baseline tempo. Flattening
    // that baseline would then have silently inverted the model, so the
    // ordering is encoded here instead of being inherited by luck.
    final double range = 0.35 + 0.95 * a;
    final double centre = 1.05 - 0.15 * a;
    double factor = centre * (1.0 - range * 0.5 + range * d);

    // LEAKAGE. The classic tell — slow means weak — but only from players
    // who cannot help it. At high aura this term vanishes entirely, so a
    // pro's timing carries no information about their holding.
    final double leak = 1.0 - a;
    final double strengthTell =
        (0.5 - strength.clamp(0.0, 1.0)) * 0.45 * leak;
    factor *= 1.0 + strengthTell;

    // MOOD. Greed is impulsive, fear stalls. Tilt should be visible in the
    // tempo, not only in the decisions.
    factor *= 1.0 - fearGreedSigned.clamp(-1.0, 1.0) * 0.16;

    return max(0.05, factor);
  }

  /// Timing jitter scaling. A composed bot's tempo is steady; an
  /// undisciplined one is erratic hand to hand, which is itself a tell.
  static double jitterScaleForAura(double auraSkill) =>
      0.60 + 0.80 * (1.0 - auraSkill.clamp(0.0, 1.0));

  /// Lower bound on think time, interpolated by difficulty: a trivial
  /// decision is allowed to genuinely snap, while a hard one keeps the
  /// full floor so the table never feels rushed at the moments that matter.
  static int floorMsFor({
    required double difficulty,
    required int trivialFloorMs,
    required int normalFloorMs,
  }) {
    final double d = difficulty.clamp(0.0, 1.0).toDouble();
    return (trivialFloorMs + (normalFloorMs - trivialFloorMs) * d).round();
  }
}
