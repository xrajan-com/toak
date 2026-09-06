// lib/game/bot/advisor.dart

import 'dart:math' show max, min;

import 'package:ten_of_a_kind_poker/game/bot/icm_guard.dart'
    show BotIcmGuard;
import 'package:ten_of_a_kind_poker/game/bot/tournament_context.dart'
    show StackThreat, TableStanding;
import 'package:ten_of_a_kind_poker/game/bot/memory.dart'
    show BotOpponentMemory, BotStyleState;
import 'package:ten_of_a_kind_poker/game/bot/policy_model.dart'
    show BotPolicyAdjustment, BotPolicyFeatures, kExperimentalBotPolicyModel;
import 'package:ten_of_a_kind_poker/game/bot/safety.dart' show BotSafetyGuard;
import 'package:ten_of_a_kind_poker/game/bot/think_time.dart'
    show BotThinkTime;
import 'package:ten_of_a_kind_poker/game/core.dart'
    show ActionType, Card, GamePhase, Rank, Suit, rankValue;
import 'package:ten_of_a_kind_poker/game/events.dart' show ActionResult;
import 'package:ten_of_a_kind_poker/game/game_engine.dart'
    show GameEngine, kRaiseIncrement;
import 'package:ten_of_a_kind_poker/game/hand_evaluator.dart'
    show HandCategory, HandEvaluator, HandRank;
import 'package:ten_of_a_kind_poker/game/models.dart'
    show BotSkill, BotTemperament, Player;
import 'package:ten_of_a_kind_poker/game/rng.dart' show Pcg32;

extension GameEngineBotLogic on GameEngine {
  double estimateWinProbabilityForSeat(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= players.length) return 0.0;
    return BotAdvisor.estimateWinProbability(
      eng: this,
      idx: seatIndex,
    );
  }

  /// Progresses bot actions until a non-bot acts or hand ends.
  /// A player is considered a bot if `Player.isBot == true`.
  void tickBots({int maxSteps = 50}) {
    int steps = 0;
    while (steps++ < maxSteps) {
      if (skipFastForwardActive) return;
      if (phase == GamePhase.predeal ||
          phase == GamePhase.handOver ||
          phase == GamePhase.showdown) {
        return;
      }
      if (players.isEmpty) return;
      if (actingIndex < 0 || actingIndex >= players.length) return;
      final p = players[actingIndex];
      if (!p.isBot) return; // stop on human

      final advice = prepareBotDecision(actingIndex);
      recordBotDecision(
        seat: actingIndex,
        action: advice.action,
        toAmount: advice.toAmount,
        confidence: advice.confidence,
        strength: advice.strength,
      );
      final res = act(advice.action, amount: advice.toAmount);
      if (res != ActionResult.ok) {
        // Fallback: if illegal, try safer alternatives
        if (canCheck(actingIndex)) {
          act(ActionType.check);
        } else if (toCallFor(actingIndex) > 0) {
          act(ActionType.fold);
        } else {
          // nothing reasonable; break to avoid loops
          return;
        }
      }
    }
  }

  /// Assigns temperament/skill traits to bots using aura-weighted distributions.
  ///
  /// Legacy `worldChamp` bots are now the rock profile. High-stake tables can
  /// still force a couple of those strongest rock-style bots into the lineup.
  void assignBotTraits({
    required bool guaranteeWorldChampKiller,
    int minAuraForGuarantee = 85,
    int minWorldChampKiller = 2,
  }) {
    if (players.isEmpty) return;
    final BigInt seed = tableSeed;

    for (final p in players) {
      if (!p.isBot) continue;
      final traits = _traitsForAura(
        aura: p.aura,
        name: p.name,
        seed: seed,
      );
      p.temperament = traits.temperament;
      p.skill = traits.skill;
    }

    if (!guaranteeWorldChampKiller) return;

    final botIndices = <int>[];
    for (int i = 0; i < players.length; i++) {
      if (players[i].isBot) botIndices.add(i);
    }
    if (botIndices.isEmpty) return;

    int wcKillerCount = 0;
    for (final i in botIndices) {
      final p = players[i];
      if (p.temperament == BotTemperament.worldChamp &&
          p.skill == BotSkill.killer) {
        wcKillerCount++;
      }
    }
    if (wcKillerCount >= minWorldChampKiller) return;

    final eligible = botIndices
        .where((i) => players[i].aura >= minAuraForGuarantee)
        .toList();
    final fallback =
        botIndices.where((i) => players[i].aura < minAuraForGuarantee).toList();

    final ordered = <int>[
      ..._sortedByAuraThenSeed(eligible, players, seed, 'guarantee'),
      ..._sortedByAuraThenSeed(fallback, players, seed, 'guarantee_fallback'),
    ];

    for (final i in ordered) {
      if (wcKillerCount >= minWorldChampKiller) break;
      final p = players[i];
      if (p.temperament == BotTemperament.worldChamp &&
          p.skill == BotSkill.killer) {
        continue;
      }
      p.temperament = BotTemperament.worldChamp;
      p.skill = BotSkill.killer;
      wcKillerCount++;
    }
  }
}

/* ==================== Simple Bot Advisor (Heuristic) ==================== */
/// Lightweight, deterministic heuristics to mimic solid human play without RNG.
/// Uses position, stack, pot odds, and street for coarse decisions.

class _Weighted<T> {
  final T value;
  final double weight;
  const _Weighted(this.value, this.weight);
}

({BotTemperament temperament, BotSkill skill}) _traitsForAura({
  required int aura,
  required String name,
  required BigInt seed,
}) {
  final double tRoll = _seededUnit('$seed|$name|temperament');
  final double sRoll = _seededUnit('$seed|$name|skill');
  return (
    temperament: _temperamentForAura(aura: aura, roll: tRoll),
    skill: _skillForAura(aura: aura, roll: sRoll),
  );
}

BotTemperament _temperamentForAura({
  required int aura,
  required double roll,
}) {
  final List<_Weighted<BotTemperament>> weights;
  if (aura >= 95) {
    weights = const [
      _Weighted(BotTemperament.worldChamp, 0.58),
      _Weighted(BotTemperament.stoic, 0.18),
      _Weighted(BotTemperament.aggressive, 0.24),
    ];
  } else if (aura >= 90) {
    weights = const [
      _Weighted(BotTemperament.worldChamp, 0.48),
      _Weighted(BotTemperament.stoic, 0.20),
      _Weighted(BotTemperament.aggressive, 0.32),
    ];
  } else if (aura >= 80) {
    weights = const [
      _Weighted(BotTemperament.worldChamp, 0.34),
      _Weighted(BotTemperament.stoic, 0.24),
      _Weighted(BotTemperament.aggressive, 0.42),
    ];
  } else if (aura >= 70) {
    weights = const [
      _Weighted(BotTemperament.worldChamp, 0.22),
      _Weighted(BotTemperament.stoic, 0.32),
      _Weighted(BotTemperament.aggressive, 0.46),
    ];
  } else if (aura >= 60) {
    weights = const [
      _Weighted(BotTemperament.worldChamp, 0.14),
      _Weighted(BotTemperament.stoic, 0.40),
      _Weighted(BotTemperament.aggressive, 0.46),
    ];
  } else {
    weights = const [
      _Weighted(BotTemperament.worldChamp, 0.08),
      _Weighted(BotTemperament.stoic, 0.46),
      _Weighted(BotTemperament.aggressive, 0.46),
    ];
  }
  return _pickWeighted(weights, roll);
}

BotSkill _skillForAura({
  required int aura,
  required double roll,
}) {
  final List<_Weighted<BotSkill>> weights;
  if (aura >= 95) {
    weights = const [
      _Weighted(BotSkill.killer, 0.90),
      _Weighted(BotSkill.fluke, 0.10),
    ];
  } else if (aura >= 90) {
    weights = const [
      _Weighted(BotSkill.killer, 0.80),
      _Weighted(BotSkill.fluke, 0.20),
    ];
  } else if (aura >= 80) {
    weights = const [
      _Weighted(BotSkill.killer, 0.60),
      _Weighted(BotSkill.fluke, 0.40),
    ];
  } else if (aura >= 70) {
    weights = const [
      _Weighted(BotSkill.killer, 0.45),
      _Weighted(BotSkill.fluke, 0.55),
    ];
  } else if (aura >= 60) {
    weights = const [
      _Weighted(BotSkill.killer, 0.30),
      _Weighted(BotSkill.fluke, 0.70),
    ];
  } else {
    weights = const [
      _Weighted(BotSkill.killer, 0.20),
      _Weighted(BotSkill.fluke, 0.80),
    ];
  }
  return _pickWeighted(weights, roll);
}

T _pickWeighted<T>(List<_Weighted<T>> weights, double roll) {
  double total = 0.0;
  for (final w in weights) {
    total += w.weight;
  }
  double target = roll * total;
  for (final w in weights) {
    if (target <= w.weight) return w.value;
    target -= w.weight;
  }
  return weights.last.value;
}

List<int> _sortedByAuraThenSeed(
  List<int> indices,
  List<Player> players,
  BigInt seed,
  String salt,
) {
  final out = List<int>.from(indices);
  out.sort((a, b) {
    final pa = players[a];
    final pb = players[b];
    final auraCmp = pb.aura.compareTo(pa.aura);
    if (auraCmp != 0) return auraCmp;
    final ra = _seededUnit('$seed|${pa.name}|$salt');
    final rb = _seededUnit('$seed|${pb.name}|$salt');
    return ra.compareTo(rb);
  });
  return out;
}

double _seededUnit(String key) {
  const double maxUint32 = 0xFFFFFFFF;
  final int hash = _fnv1a32(key) & 0xFFFFFFFF;
  return (hash / maxUint32).clamp(0.0, 1.0);
}

int _fnv1a32(String input) {
  const int fnvPrime = 0x01000193;
  const int offsetBasis = 0x811C9DC5;
  int hash = offsetBasis;
  for (int i = 0; i < input.length; i++) {
    hash ^= input.codeUnitAt(i);
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash;
}

class BotAdvisor {
  static final BigInt _mask64 = BigInt.parse('0xFFFFFFFFFFFFFFFF');

  static double estimateWinProbability({
    required GameEngine eng,
    required int idx,
  }) {
    return _estimateWinProb(eng: eng, idx: idx);
  }

  static ({ActionType action, int toAmount, double confidence, double strength})
      suggest(GameEngine eng, int idx) {
    final p = eng.players[idx];
    // Reset first so a seat can never pace this decision off the leftover
    // difficulty of an earlier street; the real value is recorded below,
    // once this spot's required equity is known.
    eng.recordBotDecisionDifficulty(idx, 0.30);
    final int auraRaw = p.aura;
    final fallbackTraits = _traitsForAura(
      aura: auraRaw,
      name: p.name,
      seed: eng.tableSeed,
    );
    final BotTemperament temperament =
        p.temperament ?? fallbackTraits.temperament;
    final BotSkill skill = p.skill ?? fallbackTraits.skill;
    final bool isManiac = temperament == BotTemperament.aggressive;
    final bool isCallingStation = temperament == BotTemperament.stoic;
    final bool isRock = temperament == BotTemperament.worldChamp;
    final BotStyleState styleState = eng.styleStateForSeat(idx);
    final double styleAggression = styleState.aggressionHeat - 0.5;
    final double styleBluff = styleState.bluffAppetite - 0.5;
    final double styleCaution = styleState.caution - 0.5;
    // The single directional risk axis, -1.0 (scared money) .. +1.0
    // (gambling). Aura governs the *spread* of per-decision noise and how
    // violently/durably this mood moves; fearGreed is which way the bot is
    // leaning right now. It replaces the old confidence/caution pair as the
    // directional term throughout this function, so the emotional arc is one
    // thing that can be reasoned about, tuned, and shown to the player.
    // See docs/BOT_HUMAN_INTELLIGENCE_AURA_SPEC.md.
    final double fearGreed = styleState.fearGreedSigned;
    final double fieldFoldRate = _fieldFoldRate(eng: eng, idx: idx);
    final double fieldAggression = _fieldAggression(eng: eng, idx: idx);
    final int? aggressorIdx = eng.lastAggressorIndex;
    final BotOpponentMemory? aggressorMemory =
        aggressorIdx != null && aggressorIdx >= 0 && aggressorIdx != idx
            ? eng.opponentMemoryForSeat(aggressorIdx)
            : null;
    final double aggressorPressure = aggressorMemory?.pressureHeat ?? 0.0;
    final bool facingRepeatPressure =
        aggressorMemory?.appliesRepeatPressure ?? false;
    final double aggressorAggression = aggressorMemory?.aggressionIndex ?? 0.5;
    final double aggressorSolidity = aggressorMemory?.showdownStrength ?? 0.5;
    final bool revengeSpot = aggressorIdx != null &&
        aggressorIdx >= 0 &&
        aggressorIdx < eng.players.length &&
        aggressorIdx != idx &&
        eng.players[aggressorIdx].id == styleState.revengeTargetId;

    // Table/game awareness: read the aggressor's tournament situation, not
    // just their hand-to-hand tendencies. Gated to tables that actually
    // have a payout table configured (tournament mode) — a no-op for
    // cash-style configs and every existing test, none of which set one.
    // See docs/BOT_HUMAN_INTELLIGENCE_AURA_SPEC.md.
    final bool tournamentAware =
        eng.config.payoutTable != null || eng.config.payoutForRank != null;
    final StackThreat? aggressorThreat = (tournamentAware &&
            aggressorIdx != null &&
            aggressorIdx >= 0 &&
            aggressorIdx != idx)
        ? TableStanding.threatFor(eng, aggressorIdx)
        : null;

    double auraSkill = auraRaw.clamp(0, 100) / 100.0;
    // Rock-profile bots always stay disciplined enough to remain readable.
    if (isRock) {
      auraSkill = max(auraSkill, 0.80);
    }
    final bool highAura = auraSkill >= 0.7;
    final bool lowAura = auraSkill <= 0.4;
    double potOddsBias = (skill == BotSkill.killer ? 0.04 : -0.02) +
        switch (temperament) {
          BotTemperament.aggressive => 0.02,
          BotTemperament.stoic => 0.07,
          BotTemperament.worldChamp => -0.03,
        };
    // Was styleConfidence * 0.03 - styleCaution * 0.04: at +-0.035 combined,
    // a bot that had just been stacked shifted its calling threshold about
    // as much as the static killer/fluke flag it was born with. One axis,
    // roughly twice the weight, and it now persists across hands instead of
    // washing out within an orbit.
    potOddsBias += fearGreed * 0.08;
    potOddsBias += (aggressorAggression - 0.5) * 0.02;
    // A short/crippled aggressor is often shoving or betting out of
    // necessity, not strength — their range is wider, so continuing wider
    // is correct. A chip leader's aggression carries more real threat (and
    // more follow-up pressure if it goes wrong), so it earns more respect.
    potOddsBias += switch (aggressorThreat) {
      StackThreat.crippled => 0.035,
      StackThreat.shortStack => 0.018,
      StackThreat.chipLeader => -0.02,
      StackThreat.bigStack => -0.01,
      StackThreat.mediumStack => 0.0,
      null => 0.0,
    };
    final double raiseSizeBase = switch (temperament) {
      BotTemperament.aggressive => 1.35,
      BotTemperament.stoic => 0.76,
      BotTemperament.worldChamp => 0.82,
    };
    final double raiseSizeFactor =
        (raiseSizeBase *
                (1 +
                    styleAggression * 0.20 +
                    styleBluff * 0.08 +
                    fearGreed * 0.14))
            .clamp(0.70, 1.55)
            .toDouble();
    final bool longRun = isCallingStation || isRock;
    final bool shortRun = isManiac;
    // If player is ineligible to act, just check/fold as safe default
    if (p.folded || p.allIn || p.sittingOut || p.isOut) {
      return (
        action: ActionType.check,
        toAmount: 0,
        confidence: 0.2,
        strength: 0.2,
      );
    }

    // Pot odds approximation
    final toCall = eng.toCallFor(idx);
    final pot = eng.pot + toCall; // if we call, pot becomes pot+toCall
    final hasToCall = toCall > 0;

    // Stack & risk comfort tuned per temperament.
    final invested = p.betThisStreet;
    final stackRemaining = p.chips;
    final int comfortPct = switch (temperament) {
      BotTemperament.aggressive => 60,
      BotTemperament.stoic => 38,
      BotTemperament.worldChamp => 20,
    };
    final comfortWagerRaw = (stackRemaining * comfortPct) ~/ 100;
    final comfortWager =
        min(stackRemaining, max(eng.bigBlind, comfortWagerRaw));
    final comfortCap = invested + comfortWager;

    final double sizeNoise = skill == BotSkill.fluke ? 0.18 : 0.06;
    final double sizeRoll = (eng.handRng.nextDouble() - 0.5) * sizeNoise;
    int scaleWish(int wish) {
      final int current = eng.currentBet;
      final int delta = max(0, wish - current);
      final int scaled =
          current + (delta * (raiseSizeFactor * (1 + sizeRoll))).round();
      if (current == 0) return max(eng.bigBlind, scaled);
      return max(current + eng.minRaiseSize(), scaled);
    }

    int? planRaise(int wish) =>
        _boundedTo(eng, idx, scaleWish(wish), comfortCap);

    // Crude hand strength proxy: high card ranks of hole
    int hi = 0, lo = 0;
    if (p.hole.isNotEmpty) {
      hi = rankValue(p.hole[0].rank);
      lo = p.hole.length > 1 ? rankValue(p.hole[1].rank) : 0;
      if (lo > hi) {
        final t = hi;
        hi = lo;
        lo = t;
      }
    }
    final bool pocketPair =
        (p.hole.length == 2) && (p.hole[0].rank == p.hole[1].rank);
    final bool suited =
        (p.hole.length == 2) && (p.hole[0].suit == p.hole[1].suit);
    final int gap = (hi - lo).abs();
    final bool connectors = !pocketPair && gap == 1;
    final bool oneGap = !pocketPair && gap == 2;
    final bool broadway =
        hi >= rankValue(Rank.ten) && lo >= rankValue(Rank.ten);
    final double preflopScore = _preflopScore(
      hi: hi,
      lo: lo,
      pocketPair: pocketPair,
      suited: suited,
      connectors: connectors,
      oneGap: oneGap,
      broadway: broadway,
    );

    // Postflop: precompute actual made-hand rank when possible.
    final HandRank? madeRank = _tryEvaluateRank(eng, idx);

    // Position: later is better (distance from dealer)
    int posScore = 0;
    if (eng.dealerIndex >= 0) {
      final seats = eng.players.length;
      final rel = (idx - eng.dealerIndex + seats) % seats; // 1..N around table
      // Larger rel -> later position; scale to 0..3
      posScore = (3 * rel) ~/ (seats <= 1 ? 1 : (seats - 1));
    }

    // Street aggression tuning
    int aggro = 0; // -1 passive, 0 neutral, +1 aggressive
    switch (eng.phase) {
      case GamePhase.preflop:
        aggro = 1; // open more preflop in position
        break;
      case GamePhase.flop:
      case GamePhase.turn:
        aggro = 0;
        break;
      case GamePhase.river:
        aggro = 0;
        break;
      default:
        aggro = 0;
    }
    if (highAura) aggro -= 1;
    if (lowAura) aggro += 1;
    switch (temperament) {
      case BotTemperament.worldChamp:
        aggro -= 3;
        break;
      case BotTemperament.stoic:
        aggro -= 1;
        break;
      case BotTemperament.aggressive:
        aggro += 3;
        break;
    }
    if (styleAggression >= 0.12) aggro += 1;
    if (styleCaution >= 0.12) aggro -= 1;
    if (revengeSpot && isManiac) aggro += 1;

    // Thresholds
    final strongPair = pocketPair && hi >= rankValue(Rank.ten);
    final strongBroadway =
        hi >= rankValue(Rank.ace) && lo >= rankValue(Rank.ten);
    double playableThreshold = 0.39;
    switch (temperament) {
      case BotTemperament.worldChamp:
        playableThreshold += 0.08;
        break;
      case BotTemperament.stoic:
        playableThreshold -= 0.06;
        break;
      case BotTemperament.aggressive:
        playableThreshold -= 0.10;
        break;
    }
    if (highAura) playableThreshold += 0.01;
    if (lowAura) playableThreshold -= 0.06;
    playableThreshold -= posScore * 0.03;
    // Greed widens the opening range, fear tightens it. Replaces three
    // overlapping dial terms with one axis at ~1.5x their combined weight,
    // deliberately kept near the largest temperament swing (0.10) so a
    // tilted bot plays loose rather than plays literally everything.
    playableThreshold -= fearGreed * 0.14;
    if (revengeSpot) playableThreshold -= 0.03;
    playableThreshold = playableThreshold.clamp(0.26, 0.70);

    bool playable = preflopScore >= playableThreshold;
    if (strongPair || strongBroadway) playable = true;
    if (lowAura && preflopScore >= playableThreshold - 0.04) playable = true;
    final int minBump =
        eng.minRaiseSize() > eng.bigBlind ? eng.minRaiseSize() : eng.bigBlind;

    // Decision tree
    double confidence = _estimateConfidence(
      hi: hi,
      lo: lo,
      pocketPair: pocketPair,
      suited: suited,
      playable: playable,
      phase: eng.phase,
      toCall: toCall,
      stackRemaining: stackRemaining,
      pot: pot,
      oddsOk: hasToCall ? pot >= toCall : true,
    );
    confidence = (confidence + (auraSkill - 0.5) * 0.12 + fearGreed * 0.10)
        .clamp(0.05, 0.98);
    final double rawStrength = _estimateStrength(
      eng: eng,
      idx: idx,
      hi: hi,
      lo: lo,
      pocketPair: pocketPair,
      suited: suited,
      playable: playable,
      preflopScore: preflopScore,
      evaluated: madeRank,
    );
    final int liveOpp = _liveOpponents(eng: eng, idx: idx);
    final double baseEquity = liveOpp > 0 ? (1.0 / (liveOpp + 1)) : 1.0;
    final double winProb = _estimateWinProb(eng: eng, idx: idx);
    final double winEdge = winProb - baseEquity;
    if (winEdge >= 0.03 ||
        (posScore >= 2 &&
            winEdge >= -0.02 &&
            preflopScore >= playableThreshold - 0.08)) {
      playable = true;
    }
    final double handStrength =
        (rawStrength * 0.4 + winProb * 0.6).clamp(0.05, 0.98);
    double strength = handStrength;
    strength = (strength * (0.9 + auraSkill * 0.25) + (auraSkill - 0.5) * 0.06)
        .clamp(0.05, 0.98);

    final Set<ActionType> legal = eng.legalActionsFor(idx);

    if (!hasToCall) {
      if (eng.phase != GamePhase.preflop) {
        return _humanizeDecision(
          eng: eng,
          idx: idx,
          toCall: toCall,
          hasToCall: hasToCall,
          playable: playable,
          longRun: longRun,
          shortRun: shortRun,
          comfortCap: comfortCap,
          auraSkill: auraSkill,
          temperament: temperament,
          skill: skill,
          base: (
            action: ActionType.check,
            toAmount: 0,
            confidence: (confidence * 0.85).clamp(0.05, 0.95),
            strength: strength,
          ),
        );
      }

      // Option to check / bet
      final bool premiumOpen =
          handStrength >= 0.72 || preflopScore >= playableThreshold + 0.16;
      if (premiumOpen &&
          ((eng.currentBet == 0 && legal.contains(ActionType.bet)) ||
              (eng.currentBet > 0 && legal.contains(ActionType.raise)))) {
        final int wish = eng.currentBet == 0
            ? eng.bigBlind * (shortRun ? 3 : 2)
            : eng.currentBet +
                eng.minRaiseSize() +
                (handStrength >= 0.82 ? eng.bigBlind : 0);
        final int altWish = eng.currentBet == 0
            ? eng.bigBlind * (longRun ? 2 : 3)
            : eng.currentBet + eng.minRaiseSize();
        final target = planRaise(wish) ?? planRaise(altWish);
        if (target != null) {
          final actionType =
              eng.currentBet == 0 ? ActionType.bet : ActionType.raise;
          return _humanizeDecision(
            eng: eng,
            idx: idx,
            toCall: toCall,
            hasToCall: hasToCall,
            playable: playable,
            longRun: longRun,
            shortRun: shortRun,
            comfortCap: comfortCap,
            auraSkill: auraSkill,
            temperament: temperament,
            skill: skill,
            base: (
              action: actionType,
              toAmount: target,
              confidence: confidence.clamp(0.1, 0.95),
              strength: strength,
            ),
          );
        }
      }
      final int openGate = switch (temperament) {
        BotTemperament.aggressive => -1,
        BotTemperament.stoic => 2,
        BotTemperament.worldChamp => 3,
      };
      final bool openAggro = playable && (aggro + posScore >= openGate);
      final bool openStrong = preflopScore >= playableThreshold + 0.12;
      if (openAggro || openStrong) {
        final int baseOpenFactor = shortRun
            ? 3
            : longRun
                ? 2
                : 2;
        final int openFactor = switch (temperament) {
          BotTemperament.aggressive => min(5, baseOpenFactor + 2),
          BotTemperament.stoic => 1,
          BotTemperament.worldChamp => 1,
        };
        final int wish = eng.currentBet == 0
            ? eng.bigBlind * openFactor
            : eng.currentBet + (shortRun ? minBump + eng.bigBlind : minBump);
        final int altWish = eng.currentBet == 0
            ? eng.bigBlind * (longRun ? 1 : 2)
            : eng.currentBet + eng.minRaiseSize();
        final target = planRaise(wish) ?? planRaise(altWish);
        if (target != null) {
          final actionType =
              eng.currentBet == 0 ? ActionType.bet : ActionType.raise;
          return _humanizeDecision(
            eng: eng,
            idx: idx,
            toCall: toCall,
            hasToCall: hasToCall,
            playable: playable,
            longRun: longRun,
            shortRun: shortRun,
            comfortCap: comfortCap,
            auraSkill: auraSkill,
            temperament: temperament,
            skill: skill,
            base: (
              action: actionType,
              toAmount: target,
              confidence: confidence.clamp(0.05, 0.95),
              strength: strength,
            ),
          );
        }
      }
      return _humanizeDecision(
        eng: eng,
        idx: idx,
        toCall: toCall,
        hasToCall: hasToCall,
        playable: playable,
        longRun: longRun,
        shortRun: shortRun,
        comfortCap: comfortCap,
        auraSkill: auraSkill,
        temperament: temperament,
        skill: skill,
        base: (
          action: ActionType.check,
          toAmount: 0,
          confidence: (confidence * 0.85).clamp(0.05, 0.95),
          strength: strength,
        ),
      );
    } else {
      // Facing a bet: evaluate pot odds crudely
      final double potOdds =
          pot > 0 ? (toCall / pot).clamp(0.0, 1.0).toDouble() : 1.0;
      final double effectivePotOdds = (potOdds - potOddsBias).clamp(0.0, 1.0);
      int oddsFactor = isCallingStation
          ? 2
          : isManiac
              ? 4
              : 5;
      // River decisions should be tighter for rock-profile, high-aura bots.
      if (eng.phase == GamePhase.river && (isRock || highAura)) {
        oddsFactor += 1;
      }
      if (isManiac && lowAura) {
        oddsFactor -= 1;
      }
      oddsFactor = oddsFactor.clamp(2, 5);
      final int priceyPct = longRun
          ? 38
          : shortRun
              ? 65
              : 50;
      final int priceyBlindMult = longRun
          ? 3
          : shortRun
              ? 5
              : 4;
      int priceyPctAdj = priceyPct;
      if (isRock || highAura) {
        priceyPctAdj = max(18, priceyPctAdj - 8);
      } else if (isManiac && lowAura) {
        priceyPctAdj = min(70, priceyPctAdj + 8);
      }
      final priceyCall = toCall >
          max(stackRemaining * priceyPctAdj ~/ 100,
              eng.bigBlind * priceyBlindMult);
      final canCover = stackRemaining >= toCall;
      final double stackFrac = stackRemaining > 0
          ? (toCall / stackRemaining).clamp(0.0, 1.0).toDouble()
          : 1.0;
      final int allInOpponents = _activeAllInOpponents(
        eng: eng,
        idx: idx,
      );
      final int currentBetAllInOpponents = _activeAllInOpponents(
        eng: eng,
        idx: idx,
        currentBetOnly: true,
      );
      final bool betIsAllIn = currentBetAllInOpponents > 0;
      final bool allInBetPressure = betIsAllIn &&
          (stackFrac >= 0.45 ||
              toCall >= eng.bigBlind * 4 ||
              allInOpponents >= 2);
      final bool facingAllIn =
          allInBetPressure || !canCover || stackFrac >= 0.95;
      final double breakEvenEquity = _breakEvenEquity(
        potBeforeCall: eng.pot,
        toCall: toCall,
      );
      final double equityBuffer = _callEquityBuffer(
        eng: eng,
        temperament: temperament,
        skill: skill,
        highAura: highAura,
        lowAura: lowAura,
        stackFrac: stackFrac,
        facingAllIn: facingAllIn,
        allInOpponents: allInOpponents,
      );
      // Fear demands more equity before continuing; greed accepts less.
      double memoryEquityShift = -fearGreed * 0.06;
      memoryEquityShift += (aggressorSolidity - 0.5) * 0.08;
      memoryEquityShift -= (aggressorAggression - 0.5) * 0.06;
      if (facingRepeatPressure) {
        memoryEquityShift -=
            (0.05 + aggressorPressure * 0.09).clamp(0.05, 0.14);
      }
      if (revengeSpot && isManiac) memoryEquityShift -= 0.02;
      final double requiredEquity = (breakEvenEquity +
              equityBuffer +
              memoryEquityShift -
              potOddsBias * 0.35)
          .clamp(0.0, 1.0);
      // The honest measure of how hard this decision is: how close the
      // bot's equity sits to what the spot actually demands. This is what
      // think time should key off. `_estimateConfidence` never could —
      // it is a hand-strength proxy, so it cannot tell a trivial fold from
      // an agonising one, and it made bots dwell on their cards rather
      // than on their decision. See lib/game/bot/think_time.dart.
      eng.recordBotDecisionDifficulty(
        idx,
        BotThinkTime.difficultyFor(
          hasToCall: hasToCall,
          winProb: winProb,
          requiredEquity: requiredEquity,
          stackFrac: stackFrac,
          facingAllIn: facingAllIn,
        ),
      );

      final bool rewardOutweighsRisk = !hasToCall || winProb >= requiredEquity;
      final bool callOk = rewardOutweighsRisk ||
          ((toCall * oddsFactor <= pot) && winProb >= breakEvenEquity);
      final bool inBlind =
          idx == eng.smallBlindIndex || idx == eng.bigBlindIndex;

      // Facing an all-in (or near all-in): require real strength to continue.
      if (facingAllIn && legal.contains(ActionType.fold) && toCall > 0) {
        final bool crowdedAllInPot = allInOpponents >= 2;
        double minStrengthToContinue = switch (eng.phase) {
          GamePhase.preflop => 0.52,
          GamePhase.flop => 0.46,
          GamePhase.turn => 0.48,
          GamePhase.river => 0.50,
          _ => 0.48,
        };
        if (isRock) {
          minStrengthToContinue += 0.05;
        } else if (isCallingStation) {
          minStrengthToContinue -= 0.01;
        } else if (isManiac) {
          minStrengthToContinue -= 0.03;
        }
        if (highAura) minStrengthToContinue += 0.04;
        if (lowAura) minStrengthToContinue -= 0.03;
        if (stackFrac >= 0.95) minStrengthToContinue += 0.04;
        if (effectivePotOdds <= 0.18) minStrengthToContinue -= 0.06;
        if (effectivePotOdds >= 0.40) minStrengthToContinue += 0.05;
        if (facingRepeatPressure && !crowdedAllInPot) {
          minStrengthToContinue -= 0.08 + aggressorPressure * 0.05;
        }

        if (eng.phase == GamePhase.preflop) {
          if (pocketPair && hi >= rankValue(Rank.queen)) {
            // Strong pairs should almost never fold preflop all-ins.
            minStrengthToContinue = min(minStrengthToContinue, 0.40);
          } else if (isManiac && preflopScore >= playableThreshold + 0.20) {
            // Maniacs defend wider with premium broadways.
            minStrengthToContinue = min(minStrengthToContinue, 0.36);
          }
        }

        minStrengthToContinue = minStrengthToContinue.clamp(0.26, 0.78);
        double minWinProbToContinue = breakEvenEquity;
        if (crowdedAllInPot) {
          minWinProbToContinue +=
              min(0.18, (allInOpponents - 1).clamp(0, 3) * 0.07);
          if (eng.phase == GamePhase.preflop && eng.handNumber <= 3) {
            minWinProbToContinue += 0.04;
          }
          if (isRock) {
            minWinProbToContinue += 0.03;
          } else if (isCallingStation) {
            minWinProbToContinue -= 0.02;
          } else if (isManiac) {
            minWinProbToContinue -= 0.01;
          }
          if (effectivePotOdds <= 0.18) minWinProbToContinue -= 0.03;
          if (effectivePotOdds >= 0.40) minWinProbToContinue += 0.03;
        }
        if (facingRepeatPressure && !crowdedAllInPot) {
          minWinProbToContinue -= 0.07 + aggressorPressure * 0.05;
        }
        minWinProbToContinue = minWinProbToContinue.clamp(0.28, 0.78);
        final bool probabilitySupportsContinue =
            winProb >= minWinProbToContinue;

        if ((handStrength < minStrengthToContinue && !rewardOutweighsRisk) ||
            (crowdedAllInPot && !probabilitySupportsContinue)) {
          return _humanizeDecision(
            eng: eng,
            idx: idx,
            toCall: toCall,
            hasToCall: hasToCall,
            playable: playable,
            longRun: longRun,
            shortRun: shortRun,
            comfortCap: comfortCap,
            auraSkill: auraSkill,
            temperament: temperament,
            skill: skill,
            base: (
              action: ActionType.fold,
              toAmount: 0,
              confidence: (confidence * 0.62).clamp(0.05, 0.8),
              strength: strength,
            ),
          );
        }
      }

      // Preflop: strong-aura bots fold more low-equity spots instead of bleeding chips.
      if (eng.phase == GamePhase.preflop &&
          (highAura || isRock) &&
          legal.contains(ActionType.fold) &&
          canCover &&
          toCall > 0) {
        final bool pressure = stackFrac >= 0.10 || toCall >= eng.bigBlind * 3;

        double minStrengthToContinue = isRock ? 0.27 : 0.25;
        if (pressure) minStrengthToContinue += 0.02;
        if (effectivePotOdds <= 0.18) minStrengthToContinue -= 0.08;
        if (inBlind) minStrengthToContinue -= 0.03;
        if (longRun) minStrengthToContinue += 0.02;
        if (shortRun) minStrengthToContinue -= 0.03;
        minStrengthToContinue = minStrengthToContinue.clamp(0.22, 0.56);

        if (handStrength < minStrengthToContinue &&
            !rewardOutweighsRisk &&
            (!playable || pressure)) {
          return _humanizeDecision(
            eng: eng,
            idx: idx,
            toCall: toCall,
            hasToCall: hasToCall,
            playable: playable,
            longRun: longRun,
            shortRun: shortRun,
            comfortCap: comfortCap,
            auraSkill: auraSkill,
            temperament: temperament,
            skill: skill,
            base: (
              action: ActionType.fold,
              toAmount: 0,
              confidence: (confidence * 0.6).clamp(0.05, 0.75),
              strength: strength,
            ),
          );
        }
      }

      // Good players (high aura / champions) fold more when facing meaningful pressure.
      if ((eng.phase == GamePhase.flop ||
              eng.phase == GamePhase.turn ||
              eng.phase == GamePhase.river) &&
          (highAura || isRock) &&
          legal.contains(ActionType.fold) &&
          canCover &&
          toCall > 0) {
        final int livePlayers = eng.players
            .where((pp) => !pp.folded && !pp.sittingOut && !pp.isOut)
            .length;
        final bool mediumPressure =
            stackFrac >= 0.18 || toCall >= eng.bigBlind * 3;
        if (mediumPressure) {
          final bool bigPressure =
              stackFrac >= 0.30 || toCall >= eng.bigBlind * 6;
          final bool allInPressure = stackFrac >= 0.75;

          double minStrengthToContinue = allInPressure
              ? 0.40
              : bigPressure
                  ? 0.34
                  : 0.26;

          if (isRock) {
            minStrengthToContinue += 0.05;
          } else if (isCallingStation) {
            minStrengthToContinue -= 0.02;
          } else if (isManiac) {
            minStrengthToContinue -= 0.02;
          }

          if (livePlayers >= 4) minStrengthToContinue += 0.03;
          if (longRun) minStrengthToContinue += 0.02;
          if (shortRun) minStrengthToContinue -= 0.03;

          // Great pot odds lets some weaker hands continue.
          if (effectivePotOdds <= 0.18) minStrengthToContinue -= 0.07;
          if (effectivePotOdds <= 0.12) minStrengthToContinue -= 0.05;
          minStrengthToContinue = minStrengthToContinue.clamp(0.22, 0.64);

          if (handStrength < minStrengthToContinue && !rewardOutweighsRisk) {
            return _humanizeDecision(
              eng: eng,
              idx: idx,
              toCall: toCall,
              hasToCall: hasToCall,
              playable: playable,
              longRun: longRun,
              shortRun: shortRun,
              comfortCap: comfortCap,
              auraSkill: auraSkill,
              temperament: temperament,
              skill: skill,
              base: (
                action: ActionType.fold,
                toAmount: 0,
                confidence: (confidence * 0.62).clamp(0.05, 0.8),
                strength: strength,
              ),
            );
          }
        }
      }

      // River: avoid calling off huge bets with weak showdown value.
      if (eng.phase == GamePhase.river && madeRank != null) {
        final int livePlayers = eng.players
            .where((pp) => !pp.folded && !pp.sittingOut && !pp.isOut)
            .length;
        final bool bigDecision =
            stackFrac >= 0.35 || toCall >= eng.bigBlind * 8;

        if (bigDecision) {
          int requiredCat = HandCategory.twoPair.index;
          if (stackFrac >= 0.50) requiredCat = HandCategory.threeKind.index;
          if (stackFrac >= 0.85) requiredCat = HandCategory.straight.index;

          // Multiway pots need stronger hands to call big river bets.
          if (livePlayers >= 4) {
            requiredCat = min(requiredCat + 1, HandCategory.values.length - 1);
          }

          // Temperament / aura adjustments.
          if (isRock) {
            requiredCat = max(requiredCat, HandCategory.straight.index);
          } else if (isCallingStation) {
            requiredCat = max(HandCategory.pair.index, requiredCat - 1);
          } else if (isManiac && lowAura) {
            requiredCat = max(HandCategory.twoPair.index, requiredCat - 1);
          }
          if (highAura) {
            requiredCat = max(requiredCat, HandCategory.threeKind.index);
          }
          if (shortRun) {
            requiredCat = max(HandCategory.pair.index, requiredCat - 1);
          }

          // Great pot odds lets some weaker hands continue.
          if (effectivePotOdds <= 0.18) {
            requiredCat = max(HandCategory.pair.index, requiredCat - 1);
          }

          if (madeRank.category.index < requiredCat &&
              !rewardOutweighsRisk &&
              legal.contains(ActionType.fold)) {
            return _humanizeDecision(
              eng: eng,
              idx: idx,
              toCall: toCall,
              hasToCall: hasToCall,
              playable: playable,
              longRun: longRun,
              shortRun: shortRun,
              comfortCap: comfortCap,
              auraSkill: auraSkill,
              temperament: temperament,
              skill: skill,
              base: (
                action: ActionType.fold,
                toAmount: 0,
                confidence: (confidence * 0.55).clamp(0.05, 0.7),
                strength: strength,
              ),
            );
          }
        }
      }

      if (eng.phase == GamePhase.preflop &&
          legal.contains(ActionType.raise) &&
          canCover &&
          !priceyCall) {
        final bool strongOpen = preflopScore >= playableThreshold + 0.14;
        final bool latePosOpen =
            posScore >= 2 && preflopScore >= playableThreshold + 0.08;
        final bool maniacPos3Bet = isManiac &&
            posScore >= 2 &&
            preflopScore >= playableThreshold + 0.05;
        if ((strongOpen || (latePosOpen && aggro >= 0) || maniacPos3Bet) &&
            callOk) {
          final int wish =
              eng.currentBet + minBump + (posScore >= 2 ? eng.bigBlind : 0);
          final int? target =
              planRaise(wish) ?? planRaise(eng.currentBet + minBump);
          if (target != null && target > eng.currentBet) {
            return _humanizeDecision(
              eng: eng,
              idx: idx,
              toCall: toCall,
              hasToCall: hasToCall,
              playable: playable,
              longRun: longRun,
              shortRun: shortRun,
              comfortCap: comfortCap,
              auraSkill: auraSkill,
              temperament: temperament,
              skill: skill,
              base: (
                action: ActionType.raise,
                toAmount: target,
                confidence: confidence.clamp(0.08, 0.9),
                strength: strength,
              ),
            );
          }
        }
      }

      if (strongPair && !isCallingStation) {
        final int wish = eng.currentBet + minBump;
        final target = planRaise(wish);
        if (target != null && target > eng.currentBet) {
          return _humanizeDecision(
            eng: eng,
            idx: idx,
            toCall: toCall,
            hasToCall: hasToCall,
            playable: playable,
            longRun: longRun,
            shortRun: shortRun,
            comfortCap: comfortCap,
            auraSkill: auraSkill,
            temperament: temperament,
            skill: skill,
            base: (
              action: ActionType.raise,
              toAmount: target,
              confidence: confidence.clamp(0.1, 0.95),
              strength: strength,
            ),
          );
        }
      }

      final bool madeMonster = madeRank != null &&
          madeRank.category.index >= HandCategory.flush.index;
      final bool madeStrong = madeRank != null &&
          madeRank.category.index >= HandCategory.threeKind.index;
      final bool premiumPressure =
          handStrength >= 0.72 || (madeStrong && handStrength >= 0.66);
      if (premiumPressure &&
          legal.contains(ActionType.raise) &&
          canCover &&
          !priceyCall &&
          !facingAllIn &&
          (!isCallingStation || handStrength >= 0.82)) {
        final int wish = eng.currentBet +
            minBump +
            (handStrength >= 0.82 ? eng.bigBlind : 0);
        final int? target =
            planRaise(wish) ?? planRaise(eng.currentBet + minBump);
        if (target != null && target > eng.currentBet) {
          return _humanizeDecision(
            eng: eng,
            idx: idx,
            toCall: toCall,
            hasToCall: hasToCall,
            playable: playable,
            longRun: longRun,
            shortRun: shortRun,
            comfortCap: comfortCap,
            auraSkill: auraSkill,
            temperament: temperament,
            skill: skill,
            base: (
              action: ActionType.raise,
              toAmount: target,
              confidence: confidence.clamp(0.1, 0.95),
              strength: strength,
            ),
          );
        }
      }

      final bool equityOk = rewardOutweighsRisk;
      final bool meaningfulCall =
          toCall >= eng.bigBlind * 2 || stackFrac >= 0.12;
      final bool requireEquity =
          (eng.phase == GamePhase.flop || eng.phase == GamePhase.turn) &&
              meaningfulCall &&
              (highAura || isRock || stackFrac >= 0.25);
      double callThreshold = playableThreshold - 0.10;
      if (inBlind) callThreshold -= 0.08;
      if (toCall <= eng.bigBlind * 2) callThreshold -= 0.06;
      if (effectivePotOdds <= 0.20) callThreshold -= 0.04;
      if (eng.phase == GamePhase.preflop && liveOpp >= 3) {
        callThreshold -= 0.03;
      }
      callThreshold = callThreshold.clamp(0.20, 0.62);
      final bool preflopStrong = preflopScore >= playableThreshold + 0.12;
      final bool preflopCallOk = preflopScore >= callThreshold;
      final bool cheapPreflopContinue = eng.phase == GamePhase.preflop &&
          canCover &&
          !priceyCall &&
          !facingAllIn &&
          (toCall <= eng.bigBlind * 2 ||
              (inBlind && toCall <= eng.bigBlind * 3));

      final bool callWorthy = eng.phase == GamePhase.preflop
          ? (preflopCallOk &&
              (rewardOutweighsRisk || preflopStrong || cheapPreflopContinue) &&
              (!priceyCall || preflopStrong || cheapPreflopContinue))
          : (eng.phase != GamePhase.river && !priceyCall)
              ? (requireEquity ? equityOk : (playable || equityOk))
              : equityOk;

      if (callWorthy &&
          (rewardOutweighsRisk || madeMonster) &&
          canCover &&
          (!priceyCall || madeStrong || strongPair)) {
        return _humanizeDecision(
          eng: eng,
          idx: idx,
          toCall: toCall,
          hasToCall: hasToCall,
          playable: playable,
          longRun: longRun,
          shortRun: shortRun,
          comfortCap: comfortCap,
          auraSkill: auraSkill,
          temperament: temperament,
          skill: skill,
          base: (
            action: ActionType.call,
            toAmount: 0,
            confidence: (confidence * 0.9).clamp(0.07, 0.9),
            strength: strength,
          ),
        );
      }

      if (strongPair && canCover && (stackRemaining <= toCall || shortRun)) {
        // Short stack with a strong hand: take the gamble.
        return _humanizeDecision(
          eng: eng,
          idx: idx,
          toCall: toCall,
          hasToCall: hasToCall,
          playable: playable,
          longRun: longRun,
          shortRun: shortRun,
          comfortCap: comfortCap,
          auraSkill: auraSkill,
          temperament: temperament,
          skill: skill,
          base: (
            action: ActionType.call,
            toAmount: 0,
            confidence: (confidence * 0.95).clamp(0.1, 0.95),
            strength: strength,
          ),
        );
      }

      final bool cheapSpecCall = toCall > 0 &&
          !priceyCall &&
          canCover &&
          toCall <= (inBlind ? eng.bigBlind * 3 : eng.bigBlind * 2) &&
          (rewardOutweighsRisk ||
              preflopScore >= callThreshold - 0.05 ||
              winProb >= (baseEquity - 0.03)) &&
          legal.contains(ActionType.call);
      if (cheapSpecCall && !facingAllIn) {
        return _humanizeDecision(
          eng: eng,
          idx: idx,
          toCall: toCall,
          hasToCall: hasToCall,
          playable: playable,
          longRun: longRun,
          shortRun: shortRun,
          comfortCap: comfortCap,
          auraSkill: auraSkill,
          temperament: temperament,
          skill: skill,
          base: (
            action: ActionType.call,
            toAmount: 0,
            confidence: (confidence * 0.8).clamp(0.06, 0.85),
            strength: strength,
          ),
        );
      }

      return _humanizeDecision(
        eng: eng,
        idx: idx,
        toCall: toCall,
        hasToCall: hasToCall,
        playable: playable,
        longRun: longRun,
        shortRun: shortRun,
        comfortCap: comfortCap,
        auraSkill: auraSkill,
        temperament: temperament,
        skill: skill,
        base: (
          action: ActionType.fold,
          toAmount: 0,
          confidence: (confidence * 0.6).clamp(0.05, 0.7),
          strength: strength,
        ),
      );
    }
  }

  static double _estimateConfidence({
    required int hi,
    required int lo,
    required bool pocketPair,
    required bool suited,
    required bool playable,
    required GamePhase phase,
    required int toCall,
    required int stackRemaining,
    required int pot,
    required bool oddsOk,
  }) {
    double score = 0.25;
    final double hiScore = hi / rankValue(Rank.ace).toDouble();
    final double loScore = lo / rankValue(Rank.ace).toDouble();
    score += hiScore * 0.4;
    score += loScore * 0.2;
    if (pocketPair) score += 0.15;
    if (suited) score += 0.05;
    if (playable) score += 0.1;

    switch (phase) {
      case GamePhase.preflop:
        score += 0.0;
        break;
      case GamePhase.flop:
        score += 0.05;
        break;
      case GamePhase.turn:
        score += 0.08;
        break;
      case GamePhase.river:
        score += 0.1;
        break;
      default:
        break;
    }

    final double pressure = stackRemaining > 0
        ? (toCall / stackRemaining).clamp(0, 1).toDouble()
        : 0;
    score -= pressure * 0.25;
    if (!oddsOk) score -= 0.1;
    if (pot == 0) {
      score += 0.05;
    }
    return score.clamp(0.05, 0.95);
  }

  static double _estimateStrength({
    required GameEngine eng,
    required int idx,
    required int hi,
    required int lo,
    required bool pocketPair,
    required bool suited,
    required bool playable,
    required double preflopScore,
    HandRank? evaluated,
  }) {
    final p = eng.players[idx];
    final board = eng.community;
    // Postflop: evaluate actual made hand strength
    final HandRank? rank = evaluated ?? _tryEvaluateRank(eng, idx);
    if (rank != null) {
      final double catScore =
          rank.category.index / (HandCategory.values.length - 1);
      final double hiKicker =
          rank.tiebreakers.isEmpty ? 0 : rank.tiebreakers.first / 14.0;
      final double score =
          (catScore * 0.75 + hiKicker * 0.25).clamp(0.05, 0.98);
      if (eng.phase == GamePhase.flop || eng.phase == GamePhase.turn) {
        return max(score, _estimateDrawPotential(eng: eng, idx: idx))
            .clamp(0.05, 0.98);
      }
      return score;
    }

    // Preflop / partial board: reuse coarse heuristic on hole cards
    double score = 0.18 + preflopScore * 0.75;
    if (playable) score += 0.05;
    if (board.isNotEmpty) {
      // Small bump for any board presence to feel “committed”
      score += 0.05;
    }
    final double base = score.clamp(0.05, 0.92);
    if (eng.phase == GamePhase.flop || eng.phase == GamePhase.turn) {
      return max(base, _estimateDrawPotential(eng: eng, idx: idx))
          .clamp(0.05, 0.94);
    }
    return base;
  }

  static double _preflopScore({
    required int hi,
    required int lo,
    required bool pocketPair,
    required bool suited,
    required bool connectors,
    required bool oneGap,
    required bool broadway,
  }) {
    if (hi <= 0 || lo <= 0) return 0.0;
    final double hiScore = hi / rankValue(Rank.ace).toDouble();
    final double loScore = lo / rankValue(Rank.ace).toDouble();
    double score = hiScore * 0.45 + loScore * 0.2;
    if (pocketPair) {
      score += 0.32 + hiScore * 0.1;
    }
    if (suited) score += 0.07;
    if (connectors) score += 0.08;
    if (oneGap) score += 0.04;
    if (broadway) score += 0.08;
    if (hi >= rankValue(Rank.queen) && suited) score += 0.04;
    if (pocketPair && hi <= rankValue(Rank.seven)) score += 0.05;
    return score.clamp(0.05, 0.98);
  }

  static double _estimateDrawPotential({
    required GameEngine eng,
    required int idx,
  }) {
    final p = eng.players[idx];
    final board = eng.community;
    if (board.length < 3 || board.length > 4) return 0.0;
    final cards = <Card>[...p.hole, ...board];

    // Flush draw detection (4 to a suit).
    final suitCounts = <Suit, int>{};
    for (final c in cards) {
      suitCounts[c.suit] = (suitCounts[c.suit] ?? 0) + 1;
    }
    Suit? bestSuit;
    int bestSuitCount = 0;
    for (final e in suitCounts.entries) {
      if (e.value > bestSuitCount) {
        bestSuit = e.key;
        bestSuitCount = e.value;
      }
    }
    bool flushDraw = bestSuit != null && bestSuitCount == 4;
    double flushScore = 0.0;
    if (flushDraw) {
      final holeSuited = p.hole.where((c) => c.suit == bestSuit).toList();
      int hiHole = 0;
      for (final c in holeSuited) {
        hiHole = max(hiHole, rankValue(c.rank));
      }
      if (hiHole >= rankValue(Rank.ace)) {
        flushScore = 0.40;
      } else if (hiHole >= rankValue(Rank.queen)) {
        flushScore = 0.36;
      } else if (hiHole > 0) {
        flushScore = 0.33;
      } else {
        // Board-only flush draw; likely to be shared.
        flushScore = 0.26;
      }
    }

    // Straight draw detection (4 out of 5 consecutive ranks).
    final ranks = <int>{};
    for (final c in cards) {
      final v = rankValue(c.rank);
      ranks.add(v);
      if (v == 14) ranks.add(1); // wheel support
    }
    bool openEnded = false;
    bool gutshot = false;
    for (int start = 1; start <= 10; start++) {
      int count = 0;
      int missing = -1;
      for (int r = start; r < start + 5; r++) {
        if (ranks.contains(r)) {
          count++;
        } else {
          missing = r;
        }
      }
      if (count == 4) {
        if (missing == start || missing == start + 4) {
          openEnded = true;
        } else {
          gutshot = true;
        }
      }
    }
    final double straightScore = openEnded
        ? 0.32
        : gutshot
            ? 0.25
            : 0.0;

    return max(flushScore, straightScore).clamp(0.0, 0.50);
  }

  static double _breakEvenEquity({
    required int potBeforeCall,
    required int toCall,
  }) {
    if (toCall <= 0) return 0.0;
    final int total = potBeforeCall + toCall;
    if (total <= 0) return 1.0;
    return (toCall / total).clamp(0.0, 1.0).toDouble();
  }

  static double _callEquityBuffer({
    required GameEngine eng,
    required BotTemperament temperament,
    required BotSkill skill,
    required bool highAura,
    required bool lowAura,
    required double stackFrac,
    required bool facingAllIn,
    required int allInOpponents,
  }) {
    double buffer = switch (temperament) {
      BotTemperament.worldChamp => 0.04,
      BotTemperament.stoic => -0.04,
      BotTemperament.aggressive => -0.01,
    };
    if (skill == BotSkill.fluke) buffer += 0.015;
    if (skill == BotSkill.killer) buffer -= 0.005;
    if (highAura) buffer -= 0.005;
    if (lowAura) buffer += 0.01;
    if (eng.phase == GamePhase.turn) buffer += 0.01;
    if (eng.phase == GamePhase.river) buffer += 0.015;
    if (stackFrac >= 0.35) buffer += 0.01;
    if (facingAllIn) buffer += 0.015;
    if (allInOpponents >= 2) {
      buffer += min(0.14, (allInOpponents - 1).clamp(0, 3) * 0.045);
      if (eng.phase == GamePhase.preflop && eng.handNumber <= 3) {
        buffer += 0.02;
      }
    }
    return buffer.clamp(-0.03, 0.16);
  }

  static bool _hasWeakShowdownValue(HandRank? rank) {
    if (rank == null) return true;
    return rank.category.index <= HandCategory.pair.index;
  }

  static bool _hasBustedDraw({
    required GameEngine eng,
    required int idx,
    HandRank? evaluated,
  }) {
    if (eng.phase != GamePhase.river) return false;
    final p = eng.players[idx];
    if (p.hole.length < 2 || eng.community.length < 5) return false;
    final HandRank? rank = evaluated ?? _tryEvaluateRank(eng, idx);
    final cards = <Card>[...p.hole, ...eng.community];

    final bool missedFlush = _hasMissedFlushDraw(cards: cards, hole: p.hole) &&
        (rank == null || rank.category.index < HandCategory.flush.index);
    final bool missedStraight =
        _hasMissedStraightDraw(cards: cards, hole: p.hole) &&
            (rank == null || rank.category.index < HandCategory.straight.index);
    return missedFlush || missedStraight;
  }

  static bool _hasMissedFlushDraw({
    required List<Card> cards,
    required List<Card> hole,
  }) {
    final suitCounts = <Suit, int>{};
    for (final c in cards) {
      suitCounts[c.suit] = (suitCounts[c.suit] ?? 0) + 1;
    }
    for (final entry in suitCounts.entries) {
      if (entry.value != 4) continue;
      if (hole.any((c) => c.suit == entry.key)) return true;
    }
    return false;
  }

  static bool _hasMissedStraightDraw({
    required List<Card> cards,
    required List<Card> hole,
  }) {
    final ranks = <int>{};
    final holeRanks = <int>{};
    for (final c in cards) {
      final v = rankValue(c.rank);
      ranks.add(v);
      if (v == 14) ranks.add(1);
    }
    for (final c in hole) {
      final v = rankValue(c.rank);
      holeRanks.add(v);
      if (v == 14) holeRanks.add(1);
    }

    for (int start = 1; start <= 10; start++) {
      int count = 0;
      bool holeParticipates = false;
      for (int r = start; r < start + 5; r++) {
        if (!ranks.contains(r)) continue;
        count++;
        if (holeRanks.contains(r)) holeParticipates = true;
      }
      if (count == 4 && holeParticipates) return true;
    }
    return false;
  }

  /// Base rate for firing a busted draw on the river. This is the *mean*
  /// only — the caller applies aura-scaled spread on top, so how reliably a
  /// bot bluffs at this rate is itself a function of aura.
  ///
  /// Composition order is deliberate and fixed here: aura baseline ->
  /// temperament scale -> skill -> mood -> table context. Each stage
  /// modifies what came before instead of replacing it.
  static double _riverBustedDrawBluffChance({
    required double auraSkill,
    required BotTemperament temperament,
    required BotSkill skill,
    required bool multiway,
    required double fearGreed,
  }) {
    // Continuous in aura rather than three steps: a 0.69-aura bot and a
    // 0.71-aura bot should not bluff at 0.10 and 0.16 with nothing between.
    double chance = 0.05 + 0.12 * auraSkill.clamp(0.0, 1.0);

    // Temperament SCALES the rate rather than overwriting it. The previous
    // form pinned every bot of a temperament to a single number and erased
    // aura outright: `max(chance + 0.24, 0.38)` meant every aggressive bot
    // below 0.70 aura bluffed at exactly 0.38, and `min(chance, 0.02)` did
    // the same to every stoic. Two bots with a 40-point aura gap played
    // this spot identically, which is precisely the tell that they are not
    // people.
    // Multipliers are set so each archetype's *ceiling* at maximum aura
    // lands on the rate the old hard floors/caps encoded (aggressive ~0.40,
    // worldChamp ~0.08, stoic ~0.02). That keeps the established feel of
    // each personality — rocks and calling stations still almost never fire
    // a busted draw — while the aura gradient underneath is new. Raising a
    // ceiling here is a behaviour change to make deliberately, not a side
    // effect of picking a round number.
    chance *= switch (temperament) {
      BotTemperament.aggressive => 2.75,
      BotTemperament.worldChamp => 0.42,
      BotTemperament.stoic => 0.11,
    };

    if (skill == BotSkill.killer) chance += 0.02;
    if (skill == BotSkill.fluke) chance -= 0.01;

    // Mood is the frequency dial: a steaming bot fires far more busted
    // draws, a rattled one gives up on them. The *spots* stay chosen by the
    // board and opponent logic gating this call — a frequency dial on its
    // own would read as random rather than human.
    chance *= 1.0 + fearGreed.clamp(-1.0, 1.0) * 0.55;

    if (multiway) chance -= 0.12;
    return chance.clamp(0.0, 0.45);
  }

  static HandRank? _tryEvaluateRank(GameEngine eng, int idx) {
    final p = eng.players[idx];
    final board = eng.community;
    if (board.length + p.hole.length < 5) return null;
    try {
      return HandEvaluator.evaluate(<Card>[...p.hole, ...board]);
    } catch (_) {
      return null;
    }
  }

  static int _liveOpponents({
    required GameEngine eng,
    required int idx,
  }) {
    int liveOpp = 0;
    for (int i = 0; i < eng.players.length; i++) {
      if (i == idx) continue;
      final op = eng.players[i];
      if (op.folded || op.sittingOut || op.isOut) continue;
      liveOpp++;
    }
    return liveOpp;
  }

  static int _activeAllInOpponents({
    required GameEngine eng,
    required int idx,
    bool currentBetOnly = false,
  }) {
    int count = 0;
    for (int i = 0; i < eng.players.length; i++) {
      if (i == idx) continue;
      final op = eng.players[i];
      if (op.folded || op.sittingOut || op.isOut || !op.allIn) continue;
      if (currentBetOnly && op.betThisStreet != eng.currentBet) continue;
      count++;
    }
    return count;
  }

  static double _fieldFoldRate({
    required GameEngine eng,
    required int idx,
  }) {
    double total = 0.0;
    int seen = 0;
    for (int i = 0; i < eng.players.length; i++) {
      if (i == idx) continue;
      final p = eng.players[i];
      if (p.sittingOut || p.isOut) continue;
      total += eng.opponentMemoryForSeat(i).foldPressure;
      seen += 1;
    }
    if (seen == 0) return 0.5;
    return (total / seen).clamp(0.0, 1.0).toDouble();
  }

  static double _fieldAggression({
    required GameEngine eng,
    required int idx,
  }) {
    double total = 0.0;
    int seen = 0;
    for (int i = 0; i < eng.players.length; i++) {
      if (i == idx) continue;
      final p = eng.players[i];
      if (p.sittingOut || p.isOut) continue;
      total += eng.opponentMemoryForSeat(i).aggressionIndex;
      seen += 1;
    }
    if (seen == 0) return 0.5;
    return (total / seen).clamp(0.0, 1.0).toDouble();
  }

  static double _estimateWinProb({
    required GameEngine eng,
    required int idx,
  }) {
    final p = eng.players[idx];
    if (p.hole.length < 2) return 0.0;

    final int liveOpp = _liveOpponents(eng: eng, idx: idx);
    if (liveOpp <= 0) return 1.0;

    final String key = _winProbCacheKey(
      handNumber: eng.handNumber,
      idx: idx,
      phase: eng.phase,
      hole: p.hole,
      board: eng.community,
      opponents: liveOpp,
    );
    final cached = _winProbCache[key];
    if (cached != null) return cached;

    final int baseIters = switch (eng.phase) {
      GamePhase.preflop => 120,
      GamePhase.flop => 90,
      GamePhase.turn => 70,
      GamePhase.river => 60,
      _ => 90,
    };
    final double oppScale = 1 + (liveOpp - 1) * 0.35;
    int iters = (baseIters / oppScale).round().clamp(40, 140);

    final List<Card> remaining =
        _remainingDeck(exclude: <Card>[...p.hole, ...eng.community]);
    final int needBoard = 5 - eng.community.length;
    final int needOpp = liveOpp * 2;
    final int need = needBoard + needOpp;
    if (need <= 0 || remaining.length < need) {
      return 0.5;
    }

    double score = 0.0;
    final rng = Pcg32(bigSeed: _simulationSeed(eng: eng, idx: idx));
    final List<Card> tmp = List<Card>.from(remaining);

    for (int i = 0; i < iters; i++) {
      _shuffleInPlace(tmp, rng);
      final drawn = tmp.take(need).toList(growable: false);
      int off = 0;
      final List<Card> board = <Card>[
        ...eng.community,
        if (needBoard > 0) ...drawn.sublist(0, needBoard),
      ];
      off += needBoard;

      final heroRank = HandEvaluator.evaluate(<Card>[...p.hole, ...board]);
      bool heroBest = true;
      int ties = 1;

      for (int o = 0; o < liveOpp; o++) {
        final List<Card> oppHole = <Card>[
          drawn[off],
          drawn[off + 1],
        ];
        off += 2;
        final oppRank = HandEvaluator.evaluate(<Card>[...oppHole, ...board]);
        final cmp = oppRank.compareTo(heroRank);
        if (cmp > 0) {
          heroBest = false;
          break;
        } else if (cmp == 0) {
          ties += 1;
        }
      }

      if (heroBest) {
        score += 1.0 / ties;
      }
    }

    final double prob = (score / iters).clamp(0.0, 1.0);
    _winProbCache[key] = prob;
    if (_winProbCache.length > 400) _winProbCache.clear();
    return prob;
  }

  static BigInt _simulationSeed({
    required GameEngine eng,
    required int idx,
  }) {
    BigInt seed = eng.lastHandSeed ^ BigInt.from(idx + 1);
    seed ^= BigInt.from(eng.handNumber + 17) << 11;
    seed ^= BigInt.from(eng.phase.index + 31) << 23;
    for (final c in eng.players[idx].hole) {
      seed = ((seed << 7) ^ BigInt.from(_cardSeed(c))) & _mask64;
    }
    for (final c in eng.community) {
      seed = ((seed << 9) ^ BigInt.from(_cardSeed(c))) & _mask64;
    }
    seed ^= BigInt.from(_liveOpponents(eng: eng, idx: idx)) << 37;
    return seed & _mask64;
  }

  static int _cardSeed(Card card) {
    return ((card.rank.index + 2) * 17) ^ ((card.suit.index + 1) * 131);
  }

  static String _winProbCacheKey({
    required int handNumber,
    required int idx,
    required GamePhase phase,
    required List<Card> hole,
    required List<Card> board,
    required int opponents,
  }) {
    return '$handNumber|$idx|${phase.index}|$opponents|'
        '${_cardsKey(hole)}|${_cardsKey(board)}';
  }

  static String _cardsKey(List<Card> cards) {
    final parts = cards
        .map((c) => '${c.rank.index}${c.suit.index}')
        .toList(growable: false)
      ..sort();
    return parts.join(',');
  }

  static List<Card> _remainingDeck({required List<Card> exclude}) {
    final List<Card> out = <Card>[];
    for (final s in Suit.values) {
      for (final r in Rank.values) {
        final c = Card(r, s);
        bool skip = false;
        for (final k in exclude) {
          if (k.rank == c.rank && k.suit == c.suit) {
            skip = true;
            break;
          }
        }
        if (!skip) out.add(c);
      }
    }
    return out;
  }

  static void _shuffleInPlace(List<Card> list, Pcg32 rng) {
    for (int i = list.length - 1; i > 0; i--) {
      final int j = rng.nextInt(i + 1);
      final Card tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  static final Map<String, double> _winProbCache = <String, double>{};

  static int? _boundedTo(GameEngine eng, int idx, int wish, int comfortCap) {
    final bounds = eng.raiseBoundsTo(idx);
    if (bounds.minTo > bounds.maxTo) return null;
    final int cappedMax = min(bounds.maxTo, comfortCap);
    if (cappedMax < bounds.minTo) return null;
    if (wish < bounds.minTo) return bounds.minTo;
    if (wish > cappedMax) return cappedMax;
    return wish;
  }

  static ({ActionType action, int toAmount, double confidence, double strength})
      _humanizeDecision({
    required GameEngine eng,
    required int idx,
    required int toCall,
    required bool hasToCall,
    required bool playable,
    required bool longRun,
    required bool shortRun,
    required int comfortCap,
    required double auraSkill,
    required BotTemperament temperament,
    required BotSkill skill,
    required ({
      ActionType action,
      int toAmount,
      double confidence,
      double strength
    }) base,
  }) {
    final Set<ActionType> legal = eng.legalActionsFor(idx);
    final bool isManiac = temperament == BotTemperament.aggressive;
    final bool isCallingStation = temperament == BotTemperament.stoic;
    final bool isRock = temperament == BotTemperament.worldChamp;
    final double decisionNoise = skill == BotSkill.killer ? 0.70 : 1.40;
    final double valueSkillBoost = skill == BotSkill.killer ? 0.05 : 0.0;
    final double bluffBias = switch (temperament) {
      BotTemperament.aggressive => 0.18,
      BotTemperament.stoic => -0.16,
      BotTemperament.worldChamp => -0.08,
    };
    final double raiseSizeFactor = switch (temperament) {
      BotTemperament.aggressive => 1.35,
      BotTemperament.stoic => 0.76,
      BotTemperament.worldChamp => 0.82,
    };
    final double sizeNoise = skill == BotSkill.fluke ? 0.18 : 0.06;
    final double sizeRoll = (eng.handRng.nextDouble() - 0.5) * sizeNoise;

    final double auraLooseness = (1 - auraSkill) * 0.7;
    double looseness =
        auraLooseness + (shortRun ? 0.15 : 0) - (longRun ? 0.1 : 0);
    switch (temperament) {
      case BotTemperament.worldChamp:
        looseness -= 0.10;
        break;
      case BotTemperament.stoic:
        looseness += 0.14;
        break;
      case BotTemperament.aggressive:
        looseness += 0.34;
        break;
    }
    if (skill == BotSkill.killer) looseness -= 0.04;
    if (skill == BotSkill.fluke) looseness += 0.08;
    looseness = looseness.clamp(0.15, 0.85);
    final double baseJitter = isManiac
        ? 0.18
        : isRock
            ? 0.08
            : 0.10;
    double confidence = (base.confidence +
            ((eng.handRng.nextDouble() - 0.5) * (baseJitter * decisionNoise)))
        .clamp(0.05, 0.95);
    double strengthScore = (base.strength +
            ((eng.handRng.nextDouble() - 0.5) * (0.08 * decisionNoise)))
        .clamp(0.05, 0.98);

    int scaleWish(int wish) {
      final int current = eng.currentBet;
      final int delta = max(0, wish - current);
      final int scaled =
          current + (delta * (raiseSizeFactor * (1 + sizeRoll))).round();
      if (current == 0) return max(eng.bigBlind, scaled);
      return max(current + eng.minRaiseSize(), scaled);
    }

    int? scaledBoundedTo(int wish) =>
        _boundedTo(eng, idx, scaleWish(wish), comfortCap);

    ActionType action = base.action;
    int toAmount = base.toAmount;
    bool slowPlayed = false;

    final int stackRemaining = eng.players[idx].chips;
    final double stackFrac = stackRemaining > 0
        ? (toCall / stackRemaining).clamp(0.0, 1.0).toDouble()
        : 1.0;
    final bool sameBotAggressedLastStreet = eng.wasAggressorPreviousStreet(idx);
    final bool allInPressure =
        toCall > 0 && (stackFrac >= 0.90 || toCall >= stackRemaining);
    final int foldableSeats = eng.players
        .where((p) => !p.folded && !p.allIn && !p.sittingOut && !p.isOut)
        .length;
    final bool isFlopOrTurn =
        eng.phase == GamePhase.flop || eng.phase == GamePhase.turn;
    final bool multiway = foldableSeats >= 3;

    final bool cheapCall = hasToCall &&
        toCall > 0 &&
        toCall <= max(eng.bigBlind * 2, comfortCap ~/ 8);

    final int liveOpp = _liveOpponents(eng: eng, idx: idx);
    final double baseEquity = liveOpp > 0 ? (1.0 / (liveOpp + 1)) : 1.0;
    final double winProb = _estimateWinProb(eng: eng, idx: idx);
    final double winEdge = winProb - baseEquity;
    final HandRank? madeRank = _tryEvaluateRank(eng, idx);
    final BotStyleState styleState = eng.styleStateForSeat(idx);
    final double styleAggression = styleState.aggressionHeat - 0.5;
    final double styleBluff = styleState.bluffAppetite - 0.5;
    final double styleCaution = styleState.caution - 0.5;
    final double styleConfidence = styleState.confidence - 0.5;
    final double fieldFoldRate = _fieldFoldRate(eng: eng, idx: idx);
    final double fieldAggression = _fieldAggression(eng: eng, idx: idx);
    final int? aggressorIdx = eng.lastAggressorIndex;
    final BotOpponentMemory? aggressorMemory =
        aggressorIdx != null && aggressorIdx >= 0 && aggressorIdx != idx
            ? eng.opponentMemoryForSeat(aggressorIdx)
            : null;
    final bool facingRepeatPressure =
        aggressorMemory?.appliesRepeatPressure ?? false;
    final double aggressorPressure = aggressorMemory?.pressureHeat ?? 0.0;
    final bool revengeSpot = aggressorIdx != null &&
        aggressorIdx >= 0 &&
        aggressorIdx < eng.players.length &&
        aggressorIdx != idx &&
        eng.players[aggressorIdx].id == styleState.revengeTargetId;
    final BotPolicyAdjustment modelAdjustment =
        kExperimentalBotPolicyModel.evaluate(
      BotPolicyFeatures(
        phase: eng.phase,
        temperament: temperament,
        skill: skill,
        auraSkill: auraSkill,
        winProb: winProb,
        baseEquity: baseEquity,
        confidence: confidence,
        strength: strengthScore,
        styleAggression: styleAggression,
        styleBluff: styleBluff,
        styleCaution: styleCaution,
        styleConfidence: styleConfidence,
        fieldFoldRate: fieldFoldRate,
        fieldAggression: fieldAggression,
        aggressorAggression: aggressorMemory?.aggressionIndex ?? 0.5,
        aggressorSolidity: aggressorMemory?.showdownStrength ?? 0.5,
        hasToCall: hasToCall,
        multiway: multiway,
        facingAllIn: allInPressure,
        revengeSpot: revengeSpot,
      ),
    );

    // Do not let a player print chips by repeatedly making large raises. Once
    // recent pressure memory confirms the pattern, playable bluff-catchers
    // defend at a wider—but still price- and hand-strength-aware—threshold.
    if (action == ActionType.fold &&
        hasToCall &&
        facingRepeatPressure &&
        legal.contains(ActionType.call)) {
      double strengthFloor = switch (eng.phase) {
        GamePhase.preflop => 0.44,
        GamePhase.flop => 0.36,
        GamePhase.turn => 0.38,
        GamePhase.river => 0.41,
        _ => 0.44,
      };
      if (isRock) strengthFloor += 0.025;
      if (isCallingStation) strengthFloor -= 0.045;
      if (isManiac) strengthFloor -= 0.025;
      if (multiway) strengthFloor += 0.10;
      if (allInPressure) strengthFloor += 0.025;
      strengthFloor = strengthFloor.clamp(0.30, 0.62);

      final double breakEven = _breakEvenEquity(
        potBeforeCall: eng.pot,
        toCall: toCall,
      );
      double pressureDiscount =
          (0.055 + aggressorPressure * 0.11).clamp(0.055, 0.16);
      if (multiway) pressureDiscount *= 0.45;
      final double neededEquity =
          (breakEven - pressureDiscount).clamp(0.18, 0.70);
      final bool hasMadeBluffCatcher = eng.phase != GamePhase.preflop &&
          madeRank != null &&
          madeRank.category.index >= HandCategory.pair.index;
      final bool credibleDefense = strengthScore >= strengthFloor &&
          winProb >= neededEquity &&
          (playable || hasMadeBluffCatcher || strengthScore >= 0.58);

      if (credibleDefense) {
        action = ActionType.call;
        toAmount = 0;
        confidence =
            (confidence + 0.10 + aggressorPressure * 0.08).clamp(0.10, 0.95);
      }
    }

    // Occasional hero calls when facing a small bet.
    if (action == ActionType.fold &&
        cheapCall &&
        legal.contains(ActionType.call) &&
        !(eng.phase == GamePhase.preflop && !playable) &&
        !allInPressure &&
        eng.handRng.nextDouble() <
            (0.06 + looseness * 0.35 + modelAdjustment.callBias * 0.20)) {
      action = ActionType.call;
      toAmount = 0;
      confidence = (confidence * 0.7 + 0.2).clamp(0.05, 0.75);
    }

    // Slow-play strong holdings occasionally.
    if ((action == ActionType.raise || action == ActionType.bet) &&
        strengthScore > 0.7 &&
        eng.handRng.nextDouble() < (0.04 + (1 - looseness) * 0.12)) {
      if (hasToCall && legal.contains(ActionType.call)) {
        action = ActionType.call;
        toAmount = 0;
      } else if (!hasToCall && legal.contains(ActionType.check)) {
        action = ActionType.check;
        toAmount = 0;
      }
      confidence = (confidence * 0.9).clamp(0.05, 0.9);
      slowPlayed = true;
    }

    // Probe raises with good win probability to test the field.
    if (!slowPlayed &&
        (action == ActionType.call || action == ActionType.check) &&
        !allInPressure) {
      final bool canProbe = hasToCall
          ? legal.contains(ActionType.raise)
          : legal.contains(ActionType.bet);
      final double edgeNeed = eng.phase == GamePhase.preflop ? 0.10 : 0.08;
      final bool goodWinProb = winProb >= (baseEquity + edgeNeed) ||
          winProb >= (eng.phase == GamePhase.preflop ? 0.62 : 0.58);
      if (canProbe && goodWinProb) {
        double probeChance = 0.26 + (winEdge.clamp(0.0, 0.40) * 0.95);
        probeChance += (strengthScore - 0.60).clamp(-0.10, 0.30) * 0.5;
        if (isManiac) probeChance += 0.14;
        if (isCallingStation) probeChance -= 0.12;
        if (isRock) probeChance -= 0.04;
        if (skill == BotSkill.fluke) probeChance += 0.10;
        probeChance += modelAdjustment.raiseBias;
        probeChance = probeChance.clamp(0.0, 0.85);

        if (eng.handRng.nextDouble() < probeChance) {
          if (hasToCall && legal.contains(ActionType.raise)) {
            int wish = eng.currentBet + eng.minRaiseSize();
            if (winProb >= 0.75) wish += eng.bigBlind;
            final int? raiseTo = scaledBoundedTo(wish) ??
                scaledBoundedTo(eng.currentBet + eng.minRaiseSize());
            if (raiseTo != null && raiseTo > eng.currentBet) {
              action = ActionType.raise;
              toAmount = raiseTo;
              confidence = (confidence * 0.93 + 0.07).clamp(0.06, 0.95);
            }
          } else if (!hasToCall && legal.contains(ActionType.bet)) {
            final int potNow = max(0, eng.pot);
            final double frac = winProb >= 0.75 ? 0.50 : 0.35;
            final int wish = max(eng.bigBlind, (potNow * frac).round());
            final int altWish = eng.bigBlind * (winProb >= 0.75 ? 3 : 2);
            final int? betTo =
                scaledBoundedTo(wish) ?? scaledBoundedTo(altWish);
            if (betTo != null) {
              action = ActionType.bet;
              toAmount = betTo;
              confidence = (confidence * 0.92 + 0.08).clamp(0.06, 0.95);
            }
          }
        }
      }
    }

    // Press value with strong holdings more often (avoid excessive checking/calling).
    if ((action == ActionType.call || action == ActionType.check) &&
        strengthScore >= (eng.phase == GamePhase.preflop ? 0.70 : 0.66)) {
      double pushChance = 0.40 + (strengthScore - 0.65) * 0.6;
      if (isManiac) pushChance += 0.10;
      if (isCallingStation) pushChance -= 0.16;
      if (isRock) pushChance -= 0.06;
      if (auraSkill >= 0.75) pushChance += 0.04;
      pushChance += modelAdjustment.valueBias;
      pushChance = pushChance.clamp(0.0, 0.9);

      if (eng.handRng.nextDouble() < pushChance) {
        if (hasToCall && legal.contains(ActionType.raise) && !allInPressure) {
          int wish = eng.currentBet + eng.minRaiseSize();
          if (strengthScore >= 0.82) wish += eng.bigBlind;
          final int? raiseTo = scaledBoundedTo(wish) ??
              scaledBoundedTo(eng.currentBet + eng.minRaiseSize());
          if (raiseTo != null && raiseTo > eng.currentBet) {
            action = ActionType.raise;
            toAmount = raiseTo;
            confidence = (confidence * 0.95 + 0.05).clamp(0.06, 0.95);
          }
        } else if (!hasToCall && legal.contains(ActionType.bet)) {
          final int potNow = max(0, eng.pot);
          final double frac = strengthScore >= 0.8 ? 0.58 : 0.44;
          int wish = max(eng.bigBlind, (potNow * frac).round());
          final int altWish = eng.bigBlind * (strengthScore >= 0.8 ? 3 : 2);
          final int? betTo = scaledBoundedTo(wish) ?? scaledBoundedTo(altWish);
          if (betTo != null) {
            action = ActionType.bet;
            toAmount = betTo;
            confidence = (confidence * 0.94 + 0.06).clamp(0.06, 0.95);
          }
        }
      }
    }

    // Overfold weak confidence spots to mimic cautious humans.
    if (action == ActionType.call &&
        confidence < 0.4 &&
        eng.handRng.nextDouble() <
            (0.03 + (1 - looseness) * 0.05 - modelAdjustment.callBias * 0.10) &&
        legal.contains(ActionType.fold)) {
      action = ActionType.fold;
      toAmount = 0;
      confidence = (confidence * 0.85).clamp(0.05, 0.8);
    }

    // Preflop tightening: seasoned/high-aura bots pass on marginal calls more often.
    if (eng.phase == GamePhase.preflop &&
        action == ActionType.call &&
        hasToCall &&
        legal.contains(ActionType.fold)) {
      double foldBias = 0.0;
      if (!playable) foldBias += 0.09;
      if (auraSkill >= 0.75) foldBias += 0.04;
      if (isRock) foldBias += 0.08;
      if (isCallingStation) foldBias -= 0.08;
      if (longRun) foldBias += 0.03;
      if (shortRun) foldBias -= 0.06;
      if (toCall >= eng.bigBlind * 2) foldBias += 0.04;
      foldBias -= modelAdjustment.callBias * 0.12;
      foldBias = foldBias.clamp(0.0, 0.35);

      final double strengthGate = (0.42 - foldBias * 0.10).clamp(0.20, 0.42);
      if (strengthScore < strengthGate && eng.handRng.nextDouble() < foldBias) {
        action = ActionType.fold;
        toAmount = 0;
        confidence = (confidence * 0.8).clamp(0.05, 0.8);
      }
    }

    // Value / protection bets when checked to postflop.
    if (action == ActionType.check &&
        !hasToCall &&
        isFlopOrTurn &&
        legal.contains(ActionType.bet)) {
      double valueThreshold = switch (temperament) {
        BotTemperament.worldChamp => 0.60,
        BotTemperament.stoic => 0.52,
        BotTemperament.aggressive => 0.24,
      };
      if (auraSkill >= 0.75) valueThreshold -= 0.03;
      if (isManiac) valueThreshold -= 0.02;
      valueThreshold = valueThreshold.clamp(0.22, 0.60);

      if (strengthScore >= valueThreshold) {
        double valueChance = switch (temperament) {
          BotTemperament.worldChamp => 0.22,
          BotTemperament.stoic => 0.18,
          BotTemperament.aggressive => 0.60,
        };
        if (multiway) valueChance *= 1.12;
        valueChance *= (0.65 + auraSkill * 0.65);
        valueChance *= (0.55 + strengthScore);
        final double auraAggroBoost = (0.55 - auraSkill).clamp(-0.1, 0.25);
        valueChance *= (1.0 + auraAggroBoost);
        valueChance = (valueChance + valueSkillBoost).clamp(0.0, 0.90);
        valueChance =
            (valueChance + modelAdjustment.valueBias).clamp(0.0, 0.92);

        if (eng.handRng.nextDouble() < valueChance) {
          double frac = strengthScore >= 0.78
              ? 0.62
              : strengthScore >= 0.60
                  ? 0.48
                  : 0.34;
          switch (temperament) {
            case BotTemperament.aggressive:
              frac += 0.10;
              break;
            case BotTemperament.stoic:
              frac -= 0.10;
              break;
            case BotTemperament.worldChamp:
              frac -= 0.05;
              break;
          }
          if (multiway) frac += 0.03;
          frac *= modelAdjustment.sizeFactor;
          frac = frac.clamp(0.22, 0.78);

          int snap(int v) => ((v / kRaiseIncrement).round() * kRaiseIncrement);
          final int potNow = max(0, eng.pot);
          final int wish = snap(max(eng.bigBlind, (potNow * frac).round()));
          final int altWish =
              eng.bigBlind * (eng.phase == GamePhase.turn ? 3 : 2);
          final int? betTo = scaledBoundedTo(wish) ?? scaledBoundedTo(altWish);
          if (betTo != null) {
            action = ActionType.bet;
            toAmount = betTo;
            confidence = (confidence * 0.92 + 0.08).clamp(0.06, 0.95);
          }
        }
      }
    }

    final bool riverBustedDrawSpot = eng.phase == GamePhase.river &&
        _hasWeakShowdownValue(madeRank) &&
        _hasBustedDraw(eng: eng, idx: idx, evaluated: madeRank);

    // River bluff frequency: high-aura bots bluff a slice of busted draws.
    if (action == ActionType.check &&
        !hasToCall &&
        legal.contains(ActionType.bet) &&
        riverBustedDrawSpot) {
      final double bluffChance = _riverBustedDrawBluffChance(
        auraSkill: auraSkill,
        temperament: temperament,
        skill: skill,
        multiway: multiway,
        fearGreed: styleState.fearGreedSigned,
      );
      // Aura as spread, applied to the bluff rate itself. A top bot's
      // bluffing frequency is stable and therefore genuinely hard to read;
      // a low-aura bot's swings hand to hand, firing far too often one
      // orbit and never the next. Same mean, very different to play against
      // — which is the whole thesis of this system.
      final double bluffRateNoise = _decisionUnit(
            eng: eng,
            idx: idx,
            salt: 'river_bluff_rate_noise',
          ) *
          2 -
          1;
      final double bluffRateSpread = 0.55 * (1.0 - auraSkill.clamp(0.0, 1.0));
      final double adjustedBluffChance =
          (bluffChance * (1.0 + bluffRateNoise * bluffRateSpread) +
                  modelAdjustment.bluffBias)
              .clamp(0.0, 0.55);
      final double bluffRoll = _decisionUnit(
        eng: eng,
        idx: idx,
        salt: 'river_busted_draw_bluff',
      );
      if (bluffRoll < adjustedBluffChance) {
        final int potNow = max(0, eng.pot);
        double frac = switch (temperament) {
          BotTemperament.worldChamp => 0.42,
          BotTemperament.stoic => 0.34,
          BotTemperament.aggressive => 0.85,
        };
        if (multiway) frac -= 0.08;
        frac *= modelAdjustment.sizeFactor;
        frac = frac.clamp(0.30, 0.70);
        final int wish = max(eng.bigBlind, (potNow * frac).round());
        final int altWish = eng.bigBlind * 2;
        final int? bluffTo = scaledBoundedTo(wish) ?? scaledBoundedTo(altWish);
        if (bluffTo != null) {
          action = ActionType.bet;
          toAmount = bluffTo;
          confidence = (confidence * 0.78 + 0.12).clamp(0.06, 0.85);
        }
      }
    }

    // Bluff stabs when checked to.
    if (action == ActionType.check &&
        !hasToCall &&
        legal.contains(ActionType.bet) &&
        !riverBustedDrawSpot) {
      double stabChance =
          (0.14 + looseness * 0.28) * (0.9 + auraLooseness * 0.7);
      switch (temperament) {
        case BotTemperament.worldChamp:
          stabChance *= 0.35;
          break;
        case BotTemperament.stoic:
          stabChance *= 0.22;
          break;
        case BotTemperament.aggressive:
          stabChance *= 2.10;
          break;
      }
      stabChance = (stabChance + bluffBias).clamp(0.0, 0.85);
      stabChance = (stabChance + modelAdjustment.bluffBias).clamp(0.0, 0.88);
      if (skill == BotSkill.fluke) {
        stabChance = (stabChance * 1.35 + 0.08).clamp(0.0, 0.92);
      }
      if (eng.handRng.nextDouble() < stabChance) {
        final int wish = eng.bigBlind * (shortRun ? 2 : 1);
        final int? stabTo = scaledBoundedTo(wish);
        if (stabTo != null) {
          action = ActionType.bet;
          toAmount = stabTo;
          confidence = (confidence * 0.8 + 0.2).clamp(0.06, 0.85);
        }
      }
    }

    // Turn some flop/turn calls into pressure raises to fold out weak ranges.
    if (action == ActionType.call &&
        isFlopOrTurn &&
        legal.contains(ActionType.raise) &&
        toCall > 0) {
      final bool canAffordPressure = stackFrac <=
          switch (temperament) {
            BotTemperament.aggressive => 0.35,
            BotTemperament.worldChamp => 0.18,
            BotTemperament.stoic => 0.12,
          };
      final bool callNotTooBig =
          toCall <= max(eng.bigBlind * 3, comfortCap ~/ 10);
      final bool allowPressure = multiway || skill == BotSkill.fluke;

      double raiseThreshold = switch (temperament) {
        BotTemperament.worldChamp => 0.68,
        BotTemperament.stoic => 0.72,
        BotTemperament.aggressive => 0.36,
      };
      if (auraSkill <= 0.40) raiseThreshold += 0.04;
      if (auraSkill >= 0.75) raiseThreshold -= 0.03;
      if (shortRun) raiseThreshold -= 0.03;
      if (skill == BotSkill.fluke) raiseThreshold -= 0.06;
      raiseThreshold -= modelAdjustment.raiseBias * 0.08;
      raiseThreshold = raiseThreshold.clamp(0.34, 0.70);

      if (allowPressure &&
          canAffordPressure &&
          callNotTooBig &&
          strengthScore >= raiseThreshold) {
        double raiseChance = switch (temperament) {
          BotTemperament.worldChamp => 0.05,
          BotTemperament.stoic => 0.02,
          BotTemperament.aggressive => 0.22,
        };
        if (skill == BotSkill.fluke) raiseChance += 0.10;
        raiseChance *= (0.60 + auraSkill * 0.80);
        raiseChance *= (0.55 + strengthScore);
        final double headroom =
            ((strengthScore - raiseThreshold) / 0.34).clamp(0.0, 1.0);
        raiseChance *= (0.35 + headroom * 0.85);
        raiseChance += modelAdjustment.raiseBias;
        raiseChance = raiseChance.clamp(0.0, 0.65);

        if (eng.handRng.nextDouble() < raiseChance) {
          int snap(int v) => ((v / kRaiseIncrement).round() * kRaiseIncrement);
          int wish = eng.currentBet + eng.minRaiseSize();
          if (isManiac && strengthScore >= 0.72) {
            wish += foldableSeats >= 4 ? eng.bigBlind * 2 : eng.bigBlind;
          }
          wish = snap(wish);
          final int? raiseTo = scaledBoundedTo(wish);
          if (raiseTo != null && raiseTo > eng.currentBet) {
            action = ActionType.raise;
            toAmount = raiseTo;
            confidence = (confidence * 0.95 + 0.10).clamp(0.06, 0.92);
          }
        }
      }
    }

    // Fluke shoves: value jams or occasional bluffy punts.
    if (skill == BotSkill.fluke &&
        legal.contains(ActionType.allIn) &&
        !allInPressure &&
        (action == ActionType.raise ||
            action == ActionType.bet ||
            action == ActionType.call ||
            action == ActionType.check)) {
      final bool valueShove = winProb >= 0.74 || strengthScore >= 0.82;
      final bool bluffShove =
          (eng.phase == GamePhase.flop || eng.phase == GamePhase.turn) &&
              strengthScore < 0.48 &&
              winProb <= (baseEquity - 0.03);
      double shoveChance = 0.0;
      if (valueShove) {
        shoveChance = 0.10 + (winProb - 0.70).clamp(0.0, 0.25) * 0.8;
      }
      if (bluffShove) {
        shoveChance = max(
          shoveChance,
          0.06 + (0.45 - winProb).clamp(0.0, 0.25) * 0.6,
        );
      }
      if (stackRemaining <= eng.bigBlind * 12) shoveChance += 0.05;
      if (action == ActionType.raise || action == ActionType.bet) {
        shoveChance += 0.04;
      }
      shoveChance = shoveChance.clamp(0.0, 0.35);

      if (shoveChance > 0 && eng.handRng.nextDouble() < shoveChance) {
        action = ActionType.allIn;
        toAmount = 0;
        confidence = (confidence * 0.85 + 0.1).clamp(0.08, 0.95);
      }
    }

    if (!hasToCall &&
        eng.currentBet == 0 &&
        sameBotAggressedLastStreet &&
        (action == ActionType.bet || action == ActionType.raise) &&
        legal.contains(ActionType.check)) {
      action = ActionType.check;
      toAmount = 0;
      confidence = (confidence * 0.92).clamp(0.05, 0.95);
    }

    final guarded = BotSafetyGuard.enforce(
      eng: eng,
      idx: idx,
      decision: (
        action: action,
        toAmount: toAmount,
        confidence: confidence,
        strength: strengthScore,
      ),
      hasToCall: hasToCall,
      toCall: toCall,
      comfortCap: comfortCap,
      fieldFoldRate: fieldFoldRate,
      fieldAggression: fieldAggression,
      styleState: styleState,
    );

    // Tournament/ICM layer: only engages for genuine stack-off spots on a
    // table configured with a payout table; a no-op for cash-style
    // configs. See docs/BOT_HUMAN_INTELLIGENCE_AURA_SPEC.md.
    return BotIcmGuard.adjust(
      eng: eng,
      idx: idx,
      decision: guarded,
      auraSkill: auraSkill,
      temperament: temperament,
      hasToCall: hasToCall,
      toCall: toCall,
    );
  }

  static double _decisionUnit({
    required GameEngine eng,
    required int idx,
    required String salt,
  }) {
    final p = eng.players[idx];
    return _seededUnit(
      '${eng.tableSeed}|${eng.handNumber}|${eng.phase.index}|'
      '${eng.currentBet}|${eng.pot}|$idx|${p.name}|$salt|'
      '${_cardsKey(p.hole)}|${_cardsKey(eng.community)}',
    );
  }
}
