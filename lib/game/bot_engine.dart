// lib/game/bot_engine.dart
part of 'game_engine.dart';

extension GameEngineBotLogic on GameEngine {
  /// Progresses bot actions until a non-bot acts or hand ends.
  /// A player is considered a bot if `Player.isBot == true`.
  void tickBots({int maxSteps = 50}) {
    int steps = 0;
    while (steps++ < maxSteps) {
      if (phase == GamePhase.handOver || phase == GamePhase.showdown) return;
      if (players.isEmpty) return;
      final p = players[actingIndex];
      if (!p.isBot) return; // stop on human

      final advice = BotAdvisor.suggest(this, actingIndex);
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
}

/* ==================== Simple Bot Advisor (Heuristic) ==================== */
/// Lightweight, deterministic heuristics to mimic solid human play without RNG.
/// Uses position, stack, pot odds, and street for coarse decisions.
enum _BotTemperament { champion, defensive, aggressive }

class BotAdvisor {
  static ({ActionType action, int toAmount, double confidence, double strength})
      suggest(GameEngine eng, int idx) {
    final p = eng.players[idx];
    final int auraRaw = p.aura;
    final _BotTemperament temperament =
        (auraRaw >= 93 || (auraRaw != 0 && auraRaw % 10 == 0))
            ? _BotTemperament.champion
            : (auraRaw.isOdd
                ? _BotTemperament.aggressive
                : _BotTemperament.defensive);

    double auraSkill = auraRaw.clamp(0, 100) / 100.0;
    // World champions always play "clean" regardless of their raw aura number.
    if (temperament == _BotTemperament.champion) {
      auraSkill = max(auraSkill, 0.88);
    }
    final bool highAura = auraSkill >= 0.7;
    final bool lowAura = auraSkill <= 0.4;
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

    final endurance = p.enduranceMinutes;
    final bool longRun = endurance >= 30;
    final bool shortRun = endurance > 0 && endurance <= 10;

    // Stack & risk comfort tuned per endurance profile.
    final invested = p.betThisStreet;
    final stackRemaining = p.chips;
    final int comfortPct = longRun
        ? 25
        : shortRun
            ? 45
            : 35;
    final comfortWagerRaw = (stackRemaining * comfortPct) ~/ 100;
    final comfortWager =
        min(stackRemaining, max(eng.bigBlind, comfortWagerRaw));
    final comfortCap = invested + comfortWager;

    int? planRaise(int wish) => _boundedTo(eng, idx, wish, comfortCap);

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
    if (longRun) aggro -= 1;
    if (shortRun) aggro += 1;
    if (highAura) aggro -= 1; // strong players act less splashy
    if (lowAura) aggro += 1; // weaker players over-aggro occasionally
    switch (temperament) {
      case _BotTemperament.champion:
        // Champions are composed: not spewy, but willing to apply pressure.
        aggro = aggro.clamp(-1, 1);
        break;
      case _BotTemperament.defensive:
        aggro -= 2;
        break;
      case _BotTemperament.aggressive:
        aggro += 2;
        break;
    }

    // Thresholds
    final strongPair = pocketPair && hi >= rankValue(Rank.ten);
    final strongBroadway =
        hi >= rankValue(Rank.ace) && lo >= rankValue(Rank.ten);
    bool playable =
        strongPair || strongBroadway || (suited && hi >= rankValue(Rank.queen));
    if (shortRun && !playable) {
      playable = hi >= rankValue(Rank.jack) && lo >= rankValue(Rank.nine);
    }
    if (longRun) {
      playable = playable && hi >= rankValue(Rank.jack);
    }
    if (highAura) {
      playable = playable && hi >= rankValue(Rank.queen);
    } else if (lowAura && !playable) {
      playable =
          (hi >= rankValue(Rank.ten) && lo >= rankValue(Rank.seven)) || suited;
    }
    // Temperament overrides (aura parity / multiples of 10).
    if (temperament == _BotTemperament.champion) {
      // Tight, world-class starting range.
      playable = playable && (pocketPair || hi >= rankValue(Rank.queen));
    } else if (temperament == _BotTemperament.defensive) {
      // Defensive players avoid marginal spots.
      playable = playable && (pocketPair || hi >= rankValue(Rank.jack));
    } else if (temperament == _BotTemperament.aggressive && !playable) {
      // Aggressive players widen their range.
      playable =
          (hi >= rankValue(Rank.ten) && lo >= rankValue(Rank.seven)) || suited;
    }
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
    confidence = (confidence + (auraSkill - 0.5) * 0.12).clamp(0.05, 0.98);
    final double handStrength = _estimateStrength(
      eng: eng,
      idx: idx,
      hi: hi,
      lo: lo,
      pocketPair: pocketPair,
      suited: suited,
      playable: playable,
      evaluated: madeRank,
    );
    double strength = handStrength;
    strength = (strength * (0.9 + auraSkill * 0.25) + (auraSkill - 0.5) * 0.08)
        .clamp(0.05, 0.98);

    if (!hasToCall) {
      // Option to check / bet
      if (playable && aggro + posScore >= 1) {
        final int baseOpenFactor = shortRun
            ? 3
            : longRun
                ? 2
                : 2;
        final int openFactor = switch (temperament) {
          _BotTemperament.aggressive => min(4, baseOpenFactor + 1),
          _BotTemperament.defensive => max(1, baseOpenFactor - 1),
          _BotTemperament.champion => baseOpenFactor,
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
        base: (
          action: ActionType.check,
          toAmount: 0,
          confidence: (confidence * 0.85).clamp(0.05, 0.95),
          strength: strength,
        ),
      );
    } else {
      // Facing a bet: evaluate pot odds crudely
      final Set<ActionType> legal = eng.legalActionsFor(idx);
      int oddsFactor = longRun
          ? 2
          : shortRun
              ? 4
              : 3;
      // River decisions should be tighter for composed, high-aura bots.
      if (eng.phase == GamePhase.river &&
          (temperament == _BotTemperament.champion || highAura)) {
        oddsFactor += 1;
      }
      if (temperament == _BotTemperament.aggressive && lowAura) {
        oddsFactor -= 1;
      }
      oddsFactor = oddsFactor.clamp(2, 5);
      final callOk = (toCall * oddsFactor <= pot);
      final int priceyPct = longRun
          ? 30
          : shortRun
              ? 55
              : 40;
      final int priceyBlindMult = longRun
          ? 3
          : shortRun
              ? 5
              : 4;
      int priceyPctAdj = priceyPct;
      if (temperament == _BotTemperament.champion || highAura) {
        priceyPctAdj = max(18, priceyPctAdj - 8);
      } else if (temperament == _BotTemperament.aggressive && lowAura) {
        priceyPctAdj = min(70, priceyPctAdj + 8);
      }
      final priceyCall = toCall >
          max(stackRemaining * priceyPctAdj ~/ 100,
              eng.bigBlind * priceyBlindMult);
      final canCover = stackRemaining >= toCall;

      // Good players (high aura / champions) fold more when facing meaningful pressure.
      if ((eng.phase == GamePhase.flop ||
              eng.phase == GamePhase.turn ||
              eng.phase == GamePhase.river) &&
          (highAura || temperament == _BotTemperament.champion) &&
          legal.contains(ActionType.fold) &&
          canCover &&
          toCall > 0) {
        final int livePlayers = eng.players
            .where((pp) => !pp.folded && !pp.sittingOut && !pp.isOut)
            .length;
        final double stackFrac = stackRemaining > 0
            ? (toCall / stackRemaining).clamp(0.0, 1.0).toDouble()
            : 1.0;
        final double potOdds =
            pot > 0 ? (toCall / pot).clamp(0.0, 1.0).toDouble() : 1.0;
        final bool mediumPressure = stackFrac >= 0.18 || toCall >= eng.bigBlind * 3;
        if (mediumPressure) {
          final bool bigPressure = stackFrac >= 0.30 || toCall >= eng.bigBlind * 6;
          final bool allInPressure = stackFrac >= 0.75;

          double minStrengthToContinue = allInPressure
              ? 0.46
              : bigPressure
                  ? 0.40
                  : 0.30;

          if (temperament == _BotTemperament.champion) {
            minStrengthToContinue += 0.05;
          } else if (temperament == _BotTemperament.defensive) {
            minStrengthToContinue += 0.04;
          } else if (temperament == _BotTemperament.aggressive) {
            minStrengthToContinue -= 0.02;
          }

          if (livePlayers >= 4) minStrengthToContinue += 0.03;
          if (longRun) minStrengthToContinue += 0.02;
          if (shortRun) minStrengthToContinue -= 0.03;

          // Great pot odds lets some weaker hands continue.
          if (potOdds <= 0.18) minStrengthToContinue -= 0.07;
          if (potOdds <= 0.12) minStrengthToContinue -= 0.05;
          minStrengthToContinue = minStrengthToContinue.clamp(0.24, 0.70);

          if (handStrength < minStrengthToContinue) {
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
        final double stackFrac =
            stackRemaining > 0 ? (toCall / stackRemaining) : 1.0;
        final double potOdds =
            pot > 0 ? (toCall / pot).clamp(0.0, 1.0).toDouble() : 1.0;
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
          if (temperament == _BotTemperament.champion) {
            requiredCat = max(requiredCat, HandCategory.straight.index);
          } else if (temperament == _BotTemperament.defensive) {
            requiredCat = max(requiredCat, HandCategory.threeKind.index);
          } else if (temperament == _BotTemperament.aggressive && lowAura) {
            requiredCat = max(HandCategory.twoPair.index, requiredCat - 1);
          }
          if (highAura) {
            requiredCat = max(requiredCat, HandCategory.threeKind.index);
          }
          if (shortRun) {
            requiredCat = max(HandCategory.pair.index, requiredCat - 1);
          }

          // Great pot odds lets some weaker hands continue.
          if (potOdds <= 0.18) {
            requiredCat = max(HandCategory.pair.index, requiredCat - 1);
          }

          if (madeRank.category.index < requiredCat &&
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

      if (strongPair) {
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
            base: (
              action: ActionType.raise,
              toAmount: target,
              confidence: confidence.clamp(0.1, 0.95),
              strength: strength,
            ),
          );
        }
      }

      final bool madeMonster =
          madeRank != null && madeRank.category.index >= HandCategory.flush.index;
      final bool madeStrong =
          madeRank != null && madeRank.category.index >= HandCategory.threeKind.index;
      final bool equityOk = handStrength >= 0.24;
      final double stackFrac =
          stackRemaining > 0 ? (toCall / stackRemaining).toDouble() : 1.0;
      final bool meaningfulCall = toCall >= eng.bigBlind * 2 || stackFrac >= 0.15;
      final bool requireEquity = (highAura || temperament == _BotTemperament.champion) &&
          (eng.phase == GamePhase.flop || eng.phase == GamePhase.turn) &&
          meaningfulCall;
      final bool callWorthy = (eng.phase != GamePhase.river && !priceyCall)
          ? (requireEquity ? equityOk : (playable || equityOk))
          : equityOk;

      if (callWorthy &&
          (callOk || madeMonster) &&
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
          base: (
            action: ActionType.call,
            toAmount: 0,
            confidence: (confidence * 0.95).clamp(0.1, 0.95),
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
    double score = 0.25;
    final double hiScore = hi / rankValue(Rank.ace).toDouble();
    final double loScore = lo / rankValue(Rank.ace).toDouble();
    score += hiScore * 0.4;
    score += loScore * 0.2;
    if (pocketPair) score += 0.15;
    if (suited) score += 0.05;
    if (playable) score += 0.1;
    if (board.isNotEmpty) {
      // Small bump for any board presence to feel “committed”
      score += 0.05;
    }
    final double base = score.clamp(0.05, 0.9);
    if (eng.phase == GamePhase.flop || eng.phase == GamePhase.turn) {
      return max(base, _estimateDrawPotential(eng: eng, idx: idx))
          .clamp(0.05, 0.92);
    }
    return base;
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
    final double straightScore =
        openEnded ? 0.32 : gutshot ? 0.25 : 0.0;

    return max(flushScore, straightScore).clamp(0.0, 0.50);
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
    required _BotTemperament temperament,
    required ({
      ActionType action,
      int toAmount,
      double confidence,
      double strength
    }) base,
  }) {
    final Set<ActionType> legal = eng.legalActionsFor(idx);
    final double auraLooseness = (1 - auraSkill) * 0.7;
    double looseness =
        auraLooseness + (shortRun ? 0.15 : 0) - (longRun ? 0.1 : 0);
    switch (temperament) {
      case _BotTemperament.champion:
        looseness -= 0.18;
        break;
      case _BotTemperament.defensive:
        looseness -= 0.25;
        break;
      case _BotTemperament.aggressive:
        looseness += 0.30;
        break;
    }
    looseness = looseness.clamp(0.15, 0.85);
    double confidence = (base.confidence +
            ((eng._handRng.nextDouble() - 0.5) *
                (shortRun
                    ? 0.18
                    : longRun
                        ? 0.08
                        : 0.12)))
        .clamp(0.05, 0.95);
    double strengthScore =
        (base.strength + ((eng._handRng.nextDouble() - 0.5) * 0.08))
            .clamp(0.05, 0.98);

    ActionType action = base.action;
    int toAmount = base.toAmount;

    final int stackRemaining = eng.players[idx].chips;
    final int foldableSeats = eng.players
        .where((p) => !p.folded && !p.allIn && !p.sittingOut && !p.isOut)
        .length;
    final bool isFlopOrTurn =
        eng.phase == GamePhase.flop || eng.phase == GamePhase.turn;
    final bool multiway = foldableSeats >= 3;

    final bool cheapCall = hasToCall &&
        toCall > 0 &&
        toCall <= max(eng.bigBlind * 2, comfortCap ~/ 8);

    // Occasional hero calls when facing a small bet.
    if (action == ActionType.fold &&
        cheapCall &&
        legal.contains(ActionType.call) &&
        eng._handRng.nextDouble() < (0.06 + looseness * 0.35)) {
      action = ActionType.call;
      toAmount = 0;
      confidence = (confidence * 0.7 + 0.2).clamp(0.05, 0.75);
    }

    // Slow-play strong holdings occasionally.
    if ((action == ActionType.raise || action == ActionType.bet) &&
        strengthScore > 0.7 &&
        eng._handRng.nextDouble() < (0.08 + (1 - looseness) * 0.25)) {
      if (hasToCall && legal.contains(ActionType.call)) {
        action = ActionType.call;
        toAmount = 0;
      } else if (!hasToCall && legal.contains(ActionType.check)) {
        action = ActionType.check;
        toAmount = 0;
      }
      confidence = (confidence * 0.9).clamp(0.05, 0.9);
    }

    // Overfold weak confidence spots to mimic cautious humans.
    if (action == ActionType.call &&
        confidence < 0.4 &&
        eng._handRng.nextDouble() < (0.14 + (1 - looseness) * 0.2) &&
        legal.contains(ActionType.fold)) {
      action = ActionType.fold;
      toAmount = 0;
      confidence = (confidence * 0.85).clamp(0.05, 0.8);
    }

    // Value / protection bets when checked to postflop.
    if (action == ActionType.check &&
        !hasToCall &&
        isFlopOrTurn &&
        legal.contains(ActionType.bet)) {
      double valueThreshold = switch (temperament) {
        _BotTemperament.champion => 0.34,
        _BotTemperament.defensive => 0.38,
        _BotTemperament.aggressive => 0.30,
      };
      if (auraSkill >= 0.75) valueThreshold -= 0.02;
      if (shortRun) valueThreshold -= 0.02;
      valueThreshold = valueThreshold.clamp(0.22, 0.60);

      if (strengthScore >= valueThreshold) {
        double valueChance = switch (temperament) {
          _BotTemperament.champion => 0.38,
          _BotTemperament.defensive => 0.26,
          _BotTemperament.aggressive => 0.48,
        };
        if (multiway) valueChance *= 1.12;
        valueChance *= (0.65 + auraSkill * 0.65);
        valueChance *= (0.55 + strengthScore);
        valueChance = valueChance.clamp(0.0, 0.85);

        if (eng._handRng.nextDouble() < valueChance) {
          double frac = strengthScore >= 0.78
              ? 0.62
              : strengthScore >= 0.60
                  ? 0.48
                  : 0.34;
          switch (temperament) {
            case _BotTemperament.aggressive:
              frac += 0.06;
              break;
            case _BotTemperament.defensive:
              frac -= 0.06;
              break;
            case _BotTemperament.champion:
              break;
          }
          if (multiway) frac += 0.03;
          frac = frac.clamp(0.22, 0.78);

          int snap(int v) =>
              ((v / _kRaiseIncrement).round() * _kRaiseIncrement);
          final int potNow = max(0, eng.pot);
          final int wish = snap(max(eng.bigBlind, (potNow * frac).round()));
          final int altWish =
              eng.bigBlind * (eng.phase == GamePhase.turn ? 3 : 2);
          final int? betTo =
              _boundedTo(eng, idx, wish, comfortCap) ??
                  _boundedTo(eng, idx, altWish, comfortCap);
          if (betTo != null) {
            action = ActionType.bet;
            toAmount = betTo;
            confidence = (confidence * 0.92 + 0.08).clamp(0.06, 0.95);
          }
        }
      }
    }

    // Bluff stabs when checked to.
    if (action == ActionType.check &&
        !hasToCall &&
        legal.contains(ActionType.bet)) {
      double stabChance =
          (0.06 + looseness * 0.2) * (0.8 + auraLooseness * 0.6);
      switch (temperament) {
        case _BotTemperament.champion:
          stabChance *= 0.85;
          break;
        case _BotTemperament.defensive:
          stabChance *= 0.55;
          break;
        case _BotTemperament.aggressive:
          stabChance *= 1.75;
          break;
      }
      stabChance = stabChance.clamp(0.0, 0.85);
      if (eng._handRng.nextDouble() < stabChance) {
        final int wish = eng.bigBlind * (shortRun ? 2 : 1);
        final int? stabTo = _boundedTo(eng, idx, wish, comfortCap);
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
      final double stackFrac =
          stackRemaining > 0 ? (toCall / stackRemaining).toDouble() : 1.0;
      final bool canAffordPressure = stackFrac <=
          switch (temperament) {
            _BotTemperament.aggressive => 0.30,
            _BotTemperament.champion => 0.26,
            _BotTemperament.defensive => 0.22,
          };
      final bool callNotTooBig = toCall <= max(eng.bigBlind * 3, comfortCap ~/ 10);

      double raiseThreshold = switch (temperament) {
        _BotTemperament.champion => 0.46,
        _BotTemperament.defensive => 0.56,
        _BotTemperament.aggressive => 0.40,
      };
      if (auraSkill <= 0.40) raiseThreshold += 0.04;
      if (auraSkill >= 0.75) raiseThreshold -= 0.03;
      if (shortRun) raiseThreshold -= 0.03;
      raiseThreshold = raiseThreshold.clamp(0.34, 0.70);

      if (multiway &&
          canAffordPressure &&
          callNotTooBig &&
          strengthScore >= raiseThreshold) {
        double raiseChance = switch (temperament) {
          _BotTemperament.champion => 0.12,
          _BotTemperament.defensive => 0.07,
          _BotTemperament.aggressive => 0.16,
        };
        raiseChance *= (0.60 + auraSkill * 0.80);
        raiseChance *= (0.55 + strengthScore);
        final double headroom =
            ((strengthScore - raiseThreshold) / 0.34).clamp(0.0, 1.0);
        raiseChance *= (0.35 + headroom * 0.85);
        raiseChance = raiseChance.clamp(0.0, 0.65);

        if (eng._handRng.nextDouble() < raiseChance) {
          int snap(int v) =>
              ((v / _kRaiseIncrement).round() * _kRaiseIncrement);
          int wish = eng.currentBet + eng.minRaiseSize();
          if (temperament == _BotTemperament.aggressive &&
              strengthScore >= 0.72 &&
              foldableSeats >= 4) {
            wish += eng.bigBlind;
          }
          wish = snap(wish);
          final int? raiseTo = _boundedTo(eng, idx, wish, comfortCap);
          if (raiseTo != null && raiseTo > eng.currentBet) {
            action = ActionType.raise;
            toAmount = raiseTo;
            confidence = (confidence * 0.95 + 0.10).clamp(0.06, 0.92);
          }
        }
      }
    }

    return (
      action: action,
      toAmount: toAmount,
      confidence: confidence,
      strength: strengthScore,
    );
  }
}
