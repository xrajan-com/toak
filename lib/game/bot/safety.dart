import 'dart:math' show max;

import 'package:ten_of_a_kind_poker/game/bot/memory.dart' show BotStyleState;
import 'package:ten_of_a_kind_poker/game/core.dart' show ActionType;
import 'package:ten_of_a_kind_poker/game/game_engine.dart' show GameEngine;

class BotSafetyGuard {
  static ({ActionType action, int toAmount, double confidence, double strength})
      enforce({
    required GameEngine eng,
    required int idx,
    required ({
      ActionType action,
      int toAmount,
      double confidence,
      double strength
    }) decision,
    required bool hasToCall,
    required int toCall,
    required int comfortCap,
    required double fieldFoldRate,
    required double fieldAggression,
    required BotStyleState styleState,
  }) {
    final legal = eng.legalActionsFor(idx);
    ActionType action = decision.action;
    int toAmount = decision.toAmount;
    double confidence = decision.confidence.clamp(0.05, 0.98).toDouble();
    final double strength = decision.strength.clamp(0.05, 0.98).toDouble();

    if (!legal.contains(action)) {
      return _fallback(
          eng: eng, idx: idx, confidence: confidence, strength: strength);
    }

    final bool stickyField = fieldFoldRate <= 0.34;
    final bool sharpCounterplay = fieldAggression >= 0.62;
    final int stack = eng.players[idx].chips;
    final double stackFrac =
        stack > 0 ? (toCall / stack).clamp(0.0, 1.0).toDouble() : 1.0;
    final int chipsAfterCall = stack > toCall ? (stack - toCall) : 0;
    final int invested = eng.players[idx].betThisStreet;
    final bool facingOpponentAllIn = hasToCall &&
        toCall > 0 &&
        eng.players.any(
          (p) =>
              p.id != eng.players[idx].id &&
              !p.folded &&
              !p.sittingOut &&
              !p.isOut &&
              p.allIn &&
              p.betThisStreet == eng.currentBet,
        );
    final bool potCommittedCall = hasToCall &&
        toCall > 0 &&
        stack > 0 &&
        !facingOpponentAllIn &&
        invested >= eng.bigBlind * 3 &&
        toCall <= max(eng.bigBlind * 2, invested ~/ 3) &&
        chipsAfterCall <= eng.bigBlind * 2;
    final double caution = styleState.caution;

    if ((action == ActionType.bet ||
            action == ActionType.raise ||
            action == ActionType.allIn) &&
        stickyField &&
        strength < 0.42 &&
        confidence < 0.66) {
      if (hasToCall && legal.contains(ActionType.call)) {
        action = ActionType.call;
        toAmount = 0;
      } else if (!hasToCall && legal.contains(ActionType.check)) {
        action = ActionType.check;
        toAmount = 0;
      }
      confidence = (confidence * 0.86).clamp(0.05, 0.90).toDouble();
    }

    if ((action == ActionType.call || action == ActionType.allIn) &&
        toCall > 0 &&
        stackFrac >= 0.45 &&
        caution >= 0.62 &&
        sharpCounterplay &&
        strength < 0.40 &&
        !potCommittedCall &&
        legal.contains(ActionType.fold)) {
      action = ActionType.fold;
      toAmount = 0;
      confidence = (confidence * 0.82).clamp(0.05, 0.85).toDouble();
    }

    if (action == ActionType.allIn &&
        stack > eng.bigBlind * 12 &&
        strength < 0.60 &&
        confidence < 0.72) {
      if (hasToCall && legal.contains(ActionType.call)) {
        action = ActionType.call;
      } else if (!hasToCall && legal.contains(ActionType.bet)) {
        action = ActionType.bet;
        toAmount = max(eng.bigBlind, eng.pot ~/ 2);
      } else if (legal.contains(ActionType.check)) {
        action = ActionType.check;
        toAmount = 0;
      }
    }

    if (action == ActionType.bet || action == ActionType.raise) {
      final bounds = eng.raiseBoundsTo(idx);
      if (bounds.minTo > bounds.maxTo) {
        return _fallback(
          eng: eng,
          idx: idx,
          confidence: confidence,
          strength: strength,
        );
      }
      final cappedMax = comfortCap < bounds.maxTo ? comfortCap : bounds.maxTo;
      if (cappedMax < bounds.minTo) {
        return _fallback(
          eng: eng,
          idx: idx,
          confidence: confidence,
          strength: strength,
        );
      }
      if (toAmount < bounds.minTo) toAmount = bounds.minTo;
      if (toAmount > cappedMax) toAmount = cappedMax;
    }

    if (potCommittedCall && action == ActionType.fold) {
      if (legal.contains(ActionType.allIn)) {
        action = ActionType.allIn;
        toAmount = 0;
      } else if (legal.contains(ActionType.call)) {
        action = ActionType.call;
        toAmount = 0;
      }
      confidence = confidence.clamp(0.10, 0.98).toDouble();
    }

    return (
      action: action,
      toAmount: toAmount,
      confidence: confidence,
      strength: strength,
    );
  }

  static ({ActionType action, int toAmount, double confidence, double strength})
      _fallback({
    required GameEngine eng,
    required int idx,
    required double confidence,
    required double strength,
  }) {
    if (eng.canCheck(idx)) {
      return (
        action: ActionType.check,
        toAmount: 0,
        confidence: confidence,
        strength: strength,
      );
    }
    if (eng.toCallFor(idx) > 0) {
      return (
        action: ActionType.fold,
        toAmount: 0,
        confidence: confidence,
        strength: strength,
      );
    }
    return (
      action: ActionType.check,
      toAmount: 0,
      confidence: confidence,
      strength: strength,
    );
  }
}
