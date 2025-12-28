// packages/ten_card_fronts/test/ten_card_fronts_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_card_fronts/ten_card_fronts.dart';

void main() {
  group('rankCode()', () {
    test('maps all ranks to canonical strings', () {
      expect(rankCode(Rank.rA), 'A');
      expect(rankCode(Rank.rK), 'K');
      expect(rankCode(Rank.rQ), 'Q');
      expect(rankCode(Rank.rJ), 'J');
      expect(rankCode(Rank.r10), '10');
      expect(rankCode(Rank.r9), '9');
      expect(rankCode(Rank.r8), '8');
      expect(rankCode(Rank.r7), '7');
      expect(rankCode(Rank.r6), '6');
      expect(rankCode(Rank.r5), '5');
      expect(rankCode(Rank.r4), '4');
      expect(rankCode(Rank.r3), '3');
      expect(rankCode(Rank.r2), '2');
    });
  });

  group('suitCode()', () {
    test('maps all suits to canonical letters', () {
      expect(suitCode(Suit.spades), 'S');
      expect(suitCode(Suit.hearts), 'H');
      expect(suitCode(Suit.diamonds), 'D');
      expect(suitCode(Suit.clubs), 'C');
    });
  });

  group('canonical code construction', () {
    test('rank + suit code combine correctly', () {
      final as = '${rankCode(Rank.rA)}${suitCode(Suit.spades)}';
      final tenHearts = '${rankCode(Rank.r10)}${suitCode(Suit.hearts)}';
      expect(as, 'AS');
      expect(tenHearts, '10H');
    });
  });

  group('DeckLibrary (no decks registered)', () {
    test('starts with no decks', () {
      final lib = DeckLibrary();
      expect(lib.decks, isEmpty);
      expect(lib.hasDeck('classic'), isFalse);
    });

    test('byCode returns a placeholder when deck missing', () {
      final lib = DeckLibrary();
      const w = 60.0, h = 84.0;
      final wgt = lib.byCode(deck: 'missing', code: 'AS', width: w, height: h);
      expect(wgt, isA<SizedBox>());
      final sb = wgt as SizedBox;
      expect(sb.width, w);
      expect(sb.height, h);
    });

    test('cardFace returns a placeholder when deck missing', () {
      final lib = DeckLibrary();
      const w = 80.0, h = 112.0;
      final wgt = lib.cardFace(
        deck: 'missing',
        rank: Rank.rK,
        suit: Suit.diamonds,
        width: w,
        height: h,
      );
      expect(wgt, isA<SizedBox>());
      final sb = wgt as SizedBox;
      expect(sb.width, w);
      expect(sb.height, h);
    });
  });
}