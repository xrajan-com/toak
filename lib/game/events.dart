// lib/game/events.dart
// Canonical single-source event model. Imports first; no duplicates.

import 'core.dart' show GamePhase, ActionType, Card;
import 'models.dart' show Payout;

/// Listeners receive concrete EngineEvent objects.
typedef EngineListener = void Function(EngineEvent event);

/// Base class for all engine events.
abstract class EngineEvent {
  const EngineEvent();
}

/* ───────────── Table / Meta ───────────── */

class DealerButtonMoved extends EngineEvent {
  final int dealerIndex; // button seat
  final int sbIndex;
  final int bbIndex;
  const DealerButtonMoved({
    required this.dealerIndex,
    required this.sbIndex,
    required this.bbIndex,
  });
}

/// Emitted once per hand when SB/BB are posted.
class BlindsPosted extends EngineEvent {
  final int sbIndex;
  final int bbIndex;
  final int sbAmount;
  final int bbAmount;
  const BlindsPosted({
    required this.sbIndex,
    required this.bbIndex,
    required this.sbAmount,
    required this.bbAmount,
  });
}

/// Emitted when the configured tournament blind schedule advances.
/// This happens between hands (at hand start) when the dealer button completes
/// enough full orbits.
class BlindLevelChanged extends EngineEvent {
  final int levelIndex;
  final int completedOrbits;
  final int previousSmallBlind;
  final int previousBigBlind;
  final int smallBlind;
  final int bigBlind;
  const BlindLevelChanged({
    required this.levelIndex,
    required this.completedOrbits,
    required this.previousSmallBlind,
    required this.previousBigBlind,
    required this.smallBlind,
    required this.bigBlind,
  });
}

/// Emitted whenever the right to act moves to a new player.
class NextToActChanged extends EngineEvent {
  final int playerIndex;
  const NextToActChanged(this.playerIndex);
}

/* ───────────── Dealing / Streets ───────────── */

/// Fired when a street is fully dealt (flop, turn, river).
class StreetDealt extends EngineEvent {
  final GamePhase phase;
  const StreetDealt(this.phase);
}

/// Fired per card dealt — to a player or to the board.
/// Use seatIndex == -1 with isBoard:true for board cards.
/// (Matches usages in game_engine.dart: CardDealt(seatIndex: …, card: …, isBoard: …))
class CardDealt extends EngineEvent {
  final int seatIndex; // -1 for board cards
  final Card card;
  final bool isBoard;
  const CardDealt({
    required this.seatIndex,
    required this.card,
    required this.isBoard,
  });
}

/* ───────────── Hand Lifecycle ───────────── */

/// Why the hand concluded (used by some engine methods for diagnostics/UI)
enum WinReason { showdown, foldedTo }

class HandStarted extends EngineEvent {
  final int dealerIndex;
  const HandStarted(this.dealerIndex);
}

class HandEnded extends EngineEvent {
  const HandEnded();
}

/* ───────────── Player Actions ───────────── */

class ActionTaken extends EngineEvent {
  final int playerIndex;
  final ActionType type;

  /// For bets/raises this is the "to" amount; for check/call/fold it can be 0.
  final int amountTo;
  const ActionTaken(this.playerIndex, this.type, this.amountTo);
}

enum ActionResult {
  ok,
  notYourTurn,
  illegalAtThisPhase,
  alreadyFoldedOrAllIn,
  cannotCheckFacingBet,
  nothingToCall,
  invalidBetAmount,
  invalidRaiseAmount,
  notEnoughPlayers,
}

/* ───────────── Showdown / Payouts / Busts ───────────── */

class ShowdownEvent extends EngineEvent {
  const ShowdownEvent();
}

class PayoutsEvent extends EngineEvent {
  final List<Payout> payouts;
  const PayoutsEvent(this.payouts);
}

class PlayerBusted extends EngineEvent {
  final int playerIndex;
  final int rank;
  final int winnings;
  const PlayerBusted(this.playerIndex, this.rank, this.winnings);
}

class WinnerDeclared extends EngineEvent {
  final int playerIndex;
  final int prize;
  const WinnerDeclared(this.playerIndex, this.prize);
}

/// Emitted once when the tournament/game fully ends (one champion remains).
class TournamentEnded extends EngineEvent {
  final int championIndex; // seat index of the last remaining player
  final int prize; // optional prize amount (0 if none configured)
  const TournamentEnded(this.championIndex, this.prize);
}

/* ───────────── Optional animation helpers (safe no-ops for engine) ───────── */

class ShuffleStarted extends EngineEvent {
  const ShuffleStarted();
}

class ShuffleTick extends EngineEvent {
  final double progress; // 0..1
  const ShuffleTick(this.progress);
}

class ShuffleEnded extends EngineEvent {
  const ShuffleEnded();
}

/// target ∈ {"hole", "flop", "turn", "river"}
class DealingStarted extends EngineEvent {
  final String target;
  const DealingStarted(this.target);
}

class DealingEnded extends EngineEvent {
  final String target;
  const DealingEnded(this.target);
}

/* ───────────── Control / UI intents ───────────── */

/// Emitted when the user (or UI) explicitly triggers a fast-forward to winner.
/// Purely informational for diagnostics/telemetry; engine may ignore it.
class SkipInvoked extends EngineEvent {
  const SkipInvoked();
}

/* ───────────── Consolidated settlement for UI timing ───────────── */

class HandSettled extends EngineEvent {
  final int handNumber;
  final List<Payout> payouts; // copy of lastPayouts
  final List<int> bustedThisHand; // seat indices that became isOut now
  final Set<int> winners; // seats that gained chips from pots
  final int endedAtMs; // epoch millis
  const HandSettled({
    required this.handNumber,
    required this.payouts,
    required this.bustedThisHand,
    required this.winners,
    required this.endedAtMs,
  });
}
