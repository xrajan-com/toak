import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/finish_notes.dart';

void main() {
  test('says how close the finish was', () {
    String? close(int rank, {int paid = 3, int total = 6}) =>
        FinishNotes.closeCall(rank: rank, totalPlayers: total, paidPlaces: paid);
    expect(close(1), isNull);
    expect(close(2), 'ONE PLACE FROM FIRST.');
    expect(close(4), 'ONE PLACE FROM THE PRIZE.');
    expect(close(5), 'TWO PLACES FROM THE PRIZE.');
    expect(close(6), isNull);
    expect(close(4, paid: 0, total: 10), 'YOU OUTLASTED 6 PLAYERS.');
    expect(close(2, paid: 1), 'ONE PLACE FROM THE PRIZE.');
  });

  test('shows where the player stands on the journey', () {
    expect(
      FinishNotes.progress(
        kingdom: 'Jaipur',
        titleGame: false,
        kingdomCleared: 4,
        kingdomTotal: 9,
        overallCleared: 128,
        overallTotal: 500,
        titlesWon: 3,
        titlesTotal: 50,
      ),
      'JAIPUR: 4 OF 9 FORTS · 128 OF 500 OVERALL',
    );
    expect(
      FinishNotes.progress(
        kingdom: 'Jaipur',
        titleGame: false,
        kingdomCleared: 9,
        kingdomTotal: 9,
        overallCleared: 133,
        overallTotal: 500,
        titlesWon: 3,
        titlesTotal: 50,
      ),
      'JAIPUR: ALL 9 FORTS CLEARED. THE TITLE MATCH AWAITS.',
    );
    expect(
      FinishNotes.progress(
        kingdom: 'Jaipur',
        titleGame: true,
        kingdomCleared: 9,
        kingdomTotal: 9,
        overallCleared: 133,
        overallTotal: 500,
        titlesWon: 4,
        titlesTotal: 50,
      ),
      'TITLES: 4 OF 50 · FORTS: 133 OF 500',
    );
  });
}
