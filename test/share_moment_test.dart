import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/hand_evaluator.dart'
    show HandCategory;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/models.dart'
    show GCard;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/share_hand.dart';

ShareMoment _moment({
  required bool won,
  required HandCategory hero,
  HandCategory? opponent = HandCategory.pair,
  int pot = 12400,
}) =>
    ShareMoment(
      board: const [
        GCard('K', '♠'),
        GCard('9', '♥'),
        GCard('5', '♣'),
        GCard('2', '♦'),
        GCard('Q', '♣'),
      ],
      heroHole: const [GCard('A', '♣'), GCard('J', '♣')],
      opponentHole: const [GCard('9', '♠'), GCard('9', '♦')],
      opponentName: 'Peter Power',
      heroWon: won,
      pot: pot,
      heroHand: hero,
      opponentHand: opponent,
    );

void main() {
  test('headlines read like the hand', () {
    expect(
      _moment(won: true, hero: HandCategory.flush).headline,
      'WON 12,400 CHIPS WITH A FLUSH',
    );
    expect(
      _moment(
        won: false,
        hero: HandCategory.fullHouse,
        opponent: HandCategory.fourKind,
      ).headline,
      'BAD BEAT: A FULL HOUSE LOST TO FOUR OF A KIND',
    );
    expect(
      _moment(won: false, hero: HandCategory.pair, opponent: HandCategory.flush)
          .headline,
      'LOST 12,400 CHIPS TO A FLUSH',
    );
  });

  test('bad beats and strong wins are worth more than a plain loss', () {
    final win = _moment(won: true, hero: HandCategory.flush);
    final beat = _moment(won: false, hero: HandCategory.fullHouse);
    final loss = _moment(won: false, hero: HandCategory.pair);
    expect(beat.badBeat, isTrue);
    expect(loss.badBeat, isFalse);
    expect(beat.score, greaterThan(loss.score));
    expect(win.score, greaterThan(loss.score));
    expect(
      _moment(won: true, hero: HandCategory.pair, pot: 50000).score,
      greaterThan(_moment(won: true, hero: HandCategory.pair, pot: 5000).score),
    );
  });
}
