// lib/game/bot/style_read.dart
//
// Visible player styles: after watching a player for a while, the table
// shows a short read of how they play ("Calls a lot", "Tight, aggressive").
// Reading opponents is the skill this game rewards most, and new players
// learn it faster when the read is put into words.
//
// Honest by construction: the read comes only from what has been observed at
// this table (BotOpponentMemory, the same record bots use to read each
// other), never from the bot's hidden traits, and it appears only after
// enough hands to mean something.

import 'package:ten_of_a_kind_poker/game/bot/memory.dart'
    show BotOpponentMemory;

class PlayerStyleRead {
  PlayerStyleRead._();

  /// Hands a player must be seen before any read is shown.
  static const int minHands = 8;

  /// A short read of [memory], or null while there is too little to go on
  /// or nothing distinctive to say.
  static String? readFor(BotOpponentMemory memory) {
    if (memory.handsSeen < minHands) return null;
    return readFromStats(
      vpip: memory.vpip,
      pfr: memory.pfr,
      foldToBet: memory.facedBetSpots >= 4 ? memory.foldToBet : null,
    );
  }

  /// The read for raw rates: share of hands played ([vpip]), share raised
  /// before the flop ([pfr]) and, when known, share of bets folded to.
  static String? readFromStats({
    required double vpip,
    required double pfr,
    double? foldToBet,
  }) {
    final bool loose = vpip >= 0.40;
    final bool tight = vpip <= 0.22;
    // Raising more than half the hands played is the aggressive pattern.
    final bool aggressive = vpip > 0 && pfr / vpip >= 0.5 && pfr >= 0.10;
    final bool passive = vpip > 0 && pfr / vpip < 0.3;

    if (loose && aggressive) return 'Loose, aggressive';
    if (loose && passive) return 'Calls a lot';
    if (tight && aggressive) return 'Tight, aggressive';
    if (tight && passive) return 'Plays few hands';
    if (foldToBet != null && foldToBet >= 0.65) return 'Folds to pressure';
    if (foldToBet != null && foldToBet <= 0.20) return 'Hard to bluff';
    if (loose) return 'Plays many hands';
    if (tight) return 'Selective';
    return null;
  }
}
