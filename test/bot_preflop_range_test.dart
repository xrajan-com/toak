import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/bot/preflop_range.dart';
import 'package:ten_of_a_kind_poker/game/core.dart';
import 'package:ten_of_a_kind_poker/game/models.dart';

const _aa = [Card(Rank.ace, Suit.spades), Card(Rank.ace, Suit.hearts)];
const _sevenTwo = [Card(Rank.seven, Suit.spades), Card(Rank.two, Suit.hearts)];

double _share(int aura, {int fromButton = 2, int raises = 0}) =>
    BotPreflopRange.targetShare(
      aura: aura,
      temperament: BotTemperament.stoic,
      skill: BotSkill.killer,
      seatsFromButton: fromButton,
      isSmallBlind: false,
      isBigBlind: false,
      raisesFaced: raises,
      fearGreed: 0,
    );

void main() {
  test('the Aura curve hits the agreed targets', () {
    expect(BotPreflopRange.baseShareForAura(95), closeTo(0.20, 1e-9));
    expect(BotPreflopRange.baseShareForAura(80), closeTo(0.25, 1e-9));
    expect(BotPreflopRange.baseShareForAura(50), closeTo(0.35, 1e-9));
    expect(BotPreflopRange.baseShareForAura(20), closeTo(0.50, 1e-9));
    expect(
      BotPreflopRange.baseShareForAura(65),
      closeTo((0.35 + 0.25) / 2, 1e-9),
    );
  });

  test('ranking covers every starting hand once, best first', () {
    expect(BotPreflopRange.topShareOfEquity(1.0), 0.0);
    expect(BotPreflopRange.topShareOfEquity(-1.0), closeTo(1.0, 1e-9));
    final aa = BotPreflopRange.handEquity(_aa)!;
    final junk = BotPreflopRange.handEquity(_sevenTwo)!;
    expect(BotPreflopRange.topShareOfEquity(aa), 0.0);
    expect(BotPreflopRange.topShareOfEquity(junk), greaterThan(0.85));
  });

  test('aces are always played and 7-2 offsuit almost never', () {
    for (final aura in [0, 20, 50, 80, 95, 100]) {
      expect(
        BotPreflopRange.inRange(hole: _aa, share: _share(aura, raises: 2)),
        isTrue,
      );
      expect(
        BotPreflopRange.inRange(hole: _sevenTwo, share: _share(aura)),
        isFalse,
      );
    }
  });

  test('position, raises and temperament move the range the right way', () {
    expect(_share(50, fromButton: 0), greaterThan(_share(50, fromButton: 3)));
    expect(_share(50, raises: 1), lessThan(_share(50)));
    expect(_share(50, raises: 2), lessThan(_share(50, raises: 1)));
    double by(BotTemperament t) => BotPreflopRange.targetShare(
          aura: 50,
          temperament: t,
          skill: BotSkill.killer,
          seatsFromButton: 2,
          isSmallBlind: false,
          isBigBlind: false,
          raisesFaced: 0,
          fearGreed: 0,
        );
    expect(by(BotTemperament.aggressive), greaterThan(by(BotTemperament.stoic)));
    expect(by(BotTemperament.stoic), greaterThan(by(BotTemperament.worldChamp)));
  });
}
