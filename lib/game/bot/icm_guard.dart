// lib/game/bot/icm_guard.dart
//
// Converts chip-EV bot decisions into ICM-aware ones for genuine
// tournament-life spots (hero shoving, or a call that would leave hero
// with ~0 chips), and applies the aura-scaled noise model from
// docs/BOT_HUMAN_INTELLIGENCE_AURA_SPEC.md: the ICM-correct read is a
// mean to deviate around, not a rule to enforce uniformly. How far a bot
// strays from it is governed by `1 - auraSkill`, not by a fixed
// directional bias — a low-aura bot can end up too tight OR too loose on
// the same spot on different hands; a high-aura bot stays close to
// correct.
//
// This guard is a no-op unless ALL of the following hold:
//   - the table is configured with a payout table / payout callback
//     (tournament mode — plain cash-style configs are untouched), and
//   - the decision at hand is actually a tournament-life spot for HERO
//     (hero would be shoving all/most of their stack, or a call would put
//     hero all-in), and
//   - it's a clean two-way pot (exactly one other live seat still
//     contesting the hand) — see tournament_context.dart's documented
//     multiway simplification.
//
// Everything else passes through completely unchanged.

import 'dart:math' show min, pow;

import 'package:ten_of_a_kind_poker/game/bot/tournament_context.dart'
    show IcmDecision, StackThreat, TableStanding;
import 'package:ten_of_a_kind_poker/game/core.dart' show ActionType;
import 'package:ten_of_a_kind_poker/game/game_engine.dart' show GameEngine;
import 'package:ten_of_a_kind_poker/game/models.dart' show BotTemperament;

class BotIcmGuard {
  /// Noise spread at auraSkill == 0, in units of "fraction of chips at
  /// risk." At auraSkill == 1.0 the spread is ~0 — a top bot plays close
  /// to the ICM-correct line. This is deliberately wide at the bottom: it
  /// should be able to flip a moderately-clear decision either way, not
  /// just nudge a coin-flip.
  static const double _sigmaMax = 0.85;

  /// How sharply the spread shrinks as aura rises. >1 keeps mid-aura bots
  /// closer to the low end (still noisy) and only tightens up sharply near
  /// the top, which matches the aura-band shape used elsewhere (e.g. the
  /// river-bluff-chance tiers in advisor.dart).
  static const double _sigmaShapePower = 1.4;

  static ({ActionType action, int toAmount, double confidence, double strength})
      adjust({
    required GameEngine eng,
    required int idx,
    required ({
      ActionType action,
      int toAmount,
      double confidence,
      double strength
    }) decision,
    required double auraSkill,
    required BotTemperament temperament,
    required bool hasToCall,
    required int toCall,
  }) {
    if (eng.config.payoutTable == null && eng.config.payoutForRank == null) {
      return decision;
    }

    final int stack = eng.players[idx].chips;
    if (stack <= 0) return decision;

    final bool heroWouldShove = decision.action == ActionType.allIn ||
        ((decision.action == ActionType.raise ||
                decision.action == ActionType.bet) &&
            decision.toAmount >= stack);
    final bool heroCallWouldBeAllIn =
        hasToCall && toCall > 0 && toCall >= stack;

    if (!heroWouldShove && !heroCallWouldBeAllIn) return decision;

    // Only model this as a clean two-way stack-off for now (see the
    // multiway note on IcmDecision.evaluate).
    final List<int> liveOthers = <int>[
      for (int i = 0; i < eng.players.length; i++)
        if (i != idx &&
            !eng.players[i].folded &&
            !eng.players[i].sittingOut &&
            !eng.players[i].isOut)
          i,
    ];
    if (liveOthers.length != 1) return decision;
    final int villainSeat = liveOthers.first;

    final int atRisk = min(stack, hasToCall ? toCall : stack);
    if (atRisk <= 0) return decision;
    final int potIfWon = eng.pot + atRisk;
    // v1 simplification: reuse the hand-strength/showdown-strength proxy
    // already carried on the decision as a stand-in for win probability.
    // This captures the equity dimension of the shove/call correctly; it
    // does not yet fold bluff fold-equity into the ICM comparison itself
    // (a bluff shove's real edge partly comes from villain folding, not
    // from showdown equity) — see the spec doc for that as a follow-up.
    final double winProb = decision.strength.clamp(0.0, 1.0);

    final IcmDecision? icm = IcmDecision.evaluate(
      eng: eng,
      heroSeat: idx,
      villainSeat: villainSeat,
      atRisk: atRisk,
      potIfWon: potIfWon,
      winProb: winProb,
    );
    if (icm == null) return decision;

    final TableStanding? standing = TableStanding.compute(eng, idx);

    // Goal mode, read off live standings rather than hardcoded: sitting
    // right on a payout jump leans toward locking it up; a very short
    // stack with little left to protect leans toward gambling for the
    // top, since folding only delays an already-likely elimination.
    double goalBias = 0.0;
    if (standing != null) {
      if (standing.bubbleFactor >= 0.5) {
        goalBias -= 0.22 * standing.bubbleFactor;
      }
      if (standing.threat == StackThreat.crippled) {
        goalBias += 0.18;
      }
      if (standing.isChipLeader) {
        goalBias -= 0.05;
      }
    }
    switch (temperament) {
      case BotTemperament.aggressive:
        goalBias += 0.06;
        break;
      case BotTemperament.stoic:
        goalBias -= 0.05;
        break;
      case BotTemperament.worldChamp:
        break;
    }

    // Normalize the $ equity delta against what's actually at risk so the
    // noise term below is comparable across wildly different stack/pot
    // sizes instead of being dominated by whichever spot has bigger chips.
    final double normalizer = atRisk.toDouble().clamp(1.0, double.infinity);
    double signal = (icm.equityDeltaVsFold / normalizer) + goalBias;

    final double sigma = _sigmaMax *
        pow(1.0 - auraSkill.clamp(0.0, 1.0), _sigmaShapePower).toDouble();
    signal += _seededSignedUnit(eng, idx) * sigma;

    ActionType action = decision.action;
    int toAmount = decision.toAmount;
    double confidence = decision.confidence;

    final bool wantsToContinue = action == ActionType.call ||
        action == ActionType.raise ||
        action == ActionType.bet ||
        action == ActionType.allIn;

    if (wantsToContinue && signal < 0) {
      // ICM (plus this bot's aura-scaled read of it) says this stack-off
      // isn't worth it right now, even though the base chip-EV logic
      // wanted to continue.
      action = ActionType.fold;
      toAmount = 0;
      confidence = (confidence * 0.7).clamp(0.05, 0.9);
    } else if (!wantsToContinue && heroCallWouldBeAllIn && signal > 0) {
      // ICM (plus noise) says this is actually clear enough that folding
      // leaves real equity on the table — the "short stack must gamble"
      // read.
      final legal = eng.legalActionsFor(idx);
      if (legal.contains(ActionType.allIn)) {
        action = ActionType.allIn;
        toAmount = 0;
        confidence = (confidence * 0.7 + 0.15).clamp(0.1, 0.9);
      } else if (legal.contains(ActionType.call)) {
        action = ActionType.call;
        toAmount = toCall;
        confidence = (confidence * 0.7 + 0.15).clamp(0.1, 0.9);
      }
    }

    if (!eng.legalActionsFor(idx).contains(action)) {
      return decision; // never hand back something illegal
    }

    return (
      action: action,
      toAmount: toAmount,
      confidence: confidence,
      strength: decision.strength,
    );
  }

  static double _seededUnit(String key) {
    const double maxUint32 = 0xFFFFFFFF;
    final int hash = _fnv1a32(key) & 0xFFFFFFFF;
    return (hash / maxUint32).clamp(0.0, 1.0);
  }

  static int _fnv1a32(String input) {
    const int fnvPrime = 0x01000193;
    const int offsetBasis = 0x811C9DC5;
    int hash = offsetBasis;
    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Deterministic pseudo-random value in [-1, 1), seeded from the exact
  /// decision state (same pattern as advisor.dart's `_decisionUnit`, kept
  /// as a local copy here to avoid exposing advisor.dart's private
  /// helpers). Deterministic given game state, so this is reproducible in
  /// tests and doesn't consume the shared gameplay RNG stream.
  static double _seededSignedUnit(GameEngine eng, int idx) {
    final p = eng.players[idx];
    final String key = '${eng.tableSeed}|${eng.handNumber}|${eng.phase.index}|'
        '${eng.currentBet}|${eng.pot}|$idx|${p.name}|icm_noise';
    return _seededUnit(key) * 2 - 1;
  }
}
