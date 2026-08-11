import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/seat_card_layout.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/table.dart';

void main() {
  const double railWidth = 24.48;
  const double seatSize = 82.25;

  SeatCardFanLayout layoutFor({
    required Size tableSize,
    required double cardWidth,
    required double cardHeight,
  }) {
    final RRect boundary = playerSafeFeltRRect(tableSize, railWidth);
    final Rect safeRect = boundary.outerRect;
    final Rect heroSeat = Rect.fromLTWH(
      safeRect.center.dx - seatSize / 2,
      safeRect.bottom - seatSize - 5,
      seatSize,
      seatSize,
    );
    return fitHeroCardRow(
      seatRect: heroSeat,
      tableCenter: tableSize.center(Offset.zero),
      safeBoundary: boundary,
      tableMidpointY: tableSize.height / 2,
      cardCount: 2,
      cardW: cardWidth,
      cardH: cardHeight,
      stepFactor: 1.05,
    );
  }

  test('short landscape phone keeps the hero row readable', () {
    const Size tableSize = Size(700, 260);
    const double cardWidth = 52 * kHeroHoleCardScale;
    const double cardHeight = 76 * kHeroHoleCardScale;
    final SeatCardFanLayout layout = layoutFor(
      tableSize: tableSize,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
    );
    final RRect boundary = playerSafeFeltRRect(tableSize, railWidth);
    final double availableHeight =
        boundary.outerRect.bottom - 0.001 - tableSize.height / 2;

    expect(
      layout.scale,
      closeTo(availableHeight / cardHeight, 0.0001),
    );
    expect(layout.scale, greaterThan(0.90));
    expect(layout.scale, greaterThan(kHeroSeatCardMinimumScale));
    expect(layout.bounds.top, greaterThanOrEqualTo(tableSize.height / 2));
    expect(
      layout.bounds.bottom,
      closeTo(boundary.outerRect.bottom, 0.01),
    );
    _expectRectInsideRRect(layout.bounds, boundary);
  });

  test('responsive Chrome table keeps the hero row at full size', () {
    const Size tableSize = Size(939.45856, 339.84);
    const double cardWidth = 52.8 * kHeroHoleCardScale;
    const double cardHeight = 76 * kHeroHoleCardScale;
    final SeatCardFanLayout layout = layoutFor(
      tableSize: tableSize,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
    );

    expect(layout.scale, 1);
    expect(layout.bounds.height, closeTo(cardHeight, 0.0001));
    expect(layout.bounds.center.dx, closeTo(tableSize.width / 2, 0.0001));
  });

  test('hero row quality is stable across supported table sizes', () {
    const cases = <({
      Size tableSize,
      double cardWidth,
      double cardHeight,
    })>[
      (
        tableSize: Size(700, 260),
        cardWidth: 52 * kHeroHoleCardScale,
        cardHeight: 76 * kHeroHoleCardScale,
      ),
      (
        tableSize: Size(939.45856, 339.84),
        cardWidth: 52.8 * kHeroHoleCardScale,
        cardHeight: 76 * kHeroHoleCardScale,
      ),
      (
        tableSize: Size(1167, 437.76),
        cardWidth: 66 * kHeroHoleCardScale,
        cardHeight: 92 * kHeroHoleCardScale,
      ),
      (
        tableSize: Size(1751, 656.64),
        cardWidth: 88 * kHeroHoleCardScale,
        cardHeight: 128 * kHeroHoleCardScale,
      ),
    ];

    for (final item in cases) {
      final SeatCardFanLayout layout = layoutFor(
        tableSize: item.tableSize,
        cardWidth: item.cardWidth,
        cardHeight: item.cardHeight,
      );
      final RRect boundary = playerSafeFeltRRect(item.tableSize, railWidth);

      expect(
        layout.scale,
        greaterThanOrEqualTo(0.90),
        reason: '${item.tableSize} must not degrade the primary cards',
      );
      expect(
        layout.bounds.top,
        greaterThanOrEqualTo(item.tableSize.height / 2 - 0.001),
      );
      _expectRectInsideRRect(layout.bounds, boundary);
    }
  });
}

void _expectRectInsideRRect(Rect rect, RRect boundary) {
  for (final Offset corner in <Offset>[
    rect.topLeft,
    rect.topRight,
    rect.bottomLeft,
    rect.bottomRight,
  ]) {
    expect(
      boundary.contains(corner),
      isTrue,
      reason: '$corner must stay inside ${boundary.outerRect}',
    );
  }
}
