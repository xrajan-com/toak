/// "So close" lines for the end-of-game screen: how near the player came
/// to the prize or to first place, and how far along the journey they are.
/// Losing stings less, and the next game has a reason, when the screen
/// says how close it was.
class FinishNotes {
  FinishNotes._();

  /// A line about how close the finish was, or null when there is nothing
  /// encouraging and true to say (a win needs none).
  static String? closeCall({
    required int rank,
    required int totalPlayers,
    required int paidPlaces,
  }) {
    if (rank <= 1) return null;
    if (paidPlaces > 0 && rank == paidPlaces + 1) {
      return 'ONE PLACE FROM THE PRIZE.';
    }
    if (rank == 2) return 'ONE PLACE FROM FIRST.';
    if (paidPlaces > 0 && rank == paidPlaces + 2) {
      return 'TWO PLACES FROM THE PRIZE.';
    }
    final int outlasted = totalPlayers - rank;
    if (outlasted >= 2) return 'YOU OUTLASTED $outlasted PLAYERS.';
    return null;
  }

  /// Where the player stands on the journey after a career game.
  static String progress({
    required String kingdom,
    required bool titleGame,
    required int kingdomCleared,
    required int kingdomTotal,
    required int overallCleared,
    required int overallTotal,
    required int titlesWon,
    required int titlesTotal,
  }) {
    final String k = kingdom.trim().toUpperCase();
    if (titleGame) {
      return 'TITLES: $titlesWon OF $titlesTotal · '
          'FORTS: $overallCleared OF $overallTotal';
    }
    if (kingdomTotal > 0 && kingdomCleared >= kingdomTotal) {
      return '$k: ALL $kingdomTotal FORTS CLEARED. THE TITLE MATCH AWAITS.';
    }
    return '$k: $kingdomCleared OF $kingdomTotal FORTS · '
        '$overallCleared OF $overallTotal OVERALL';
  }
}
