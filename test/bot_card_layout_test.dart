import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/seat_card_layout.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/seat_layout.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/table.dart';

void main() {
  const Rect safeRect = Rect.fromLTWH(30, 30, 740, 440);
  final RRect safeBoundary = RRect.fromRectAndRadius(
    safeRect,
    Radius.circular(safeRect.height / 2),
  );
  const Offset tableCenter = Offset(400, 250);

  test('bot cards use the requested compact scale', () {
    expect(kBotHoleCardScale, 0.50);
    expect(kBotHoleCardScale, lessThan(0.62));
  });

  test('two-card fan centers are symmetric around their owner anchor', () {
    const Offset anchor = Offset(240, 180);
    final List<Offset> centers = centeredFanCardCenters(
      anchor: anchor,
      cardCount: 2,
      step: 18,
    );

    expect(centers, hasLength(2));
    expect(centers.first.dx, 231);
    expect(centers.last.dx, 249);
    expect((centers.first.dx + centers.last.dx) / 2, anchor.dx);
  });

  test(
    'two-card bot fans stay tucked behind their owner around the table',
    () {
      const Map<String, Rect> seats = <String, Rect>{
        'top': Rect.fromLTWH(360, 50, 80, 80),
        'bottom': Rect.fromLTWH(360, 370, 80, 80),
        'left': Rect.fromLTWH(50, 210, 80, 80),
        'right': Rect.fromLTWH(670, 210, 80, 80),
        'top-left diagonal': Rect.fromLTWH(145, 80, 80, 80),
        'bottom-right diagonal': Rect.fromLTWH(575, 340, 80, 80),
      };

      for (final MapEntry<String, Rect> entry in seats.entries) {
        final List<Rect> otherSeats = seats.entries
            .where((MapEntry<String, Rect> other) => other.key != entry.key)
            .map((MapEntry<String, Rect> other) => other.value)
            .toList(growable: false);
        final Rect avatar = seatAvatarVisualRect(entry.value);
        final SeatCardFanLayout layout = fitBotCardFanNearSeat(
          seatRect: entry.value,
          obstacleRects: otherSeats,
          tableCenter: tableCenter,
          safeBoundary: safeBoundary,
          cardCount: 2,
          cardW: 40,
          cardH: 56,
          fanOverlap: 0.50,
          totalFanAngleRadians: 0.10,
        );

        expect(
          layout.visibleFraction,
          inInclusiveRange(
            kSeatCardMinVisibleFraction,
            kSeatCardMaxVisibleFraction,
          ),
          reason: '${entry.key} fan must remain 50–80% visible',
        );
        expect(
          layout.visibleFractionAtMaximumAvatarScale,
          inInclusiveRange(
            kSeatCardMinVisibleFraction,
            kSeatCardMaxVisibleFraction,
          ),
          reason:
              '${entry.key} fan must remain 50–80% visible while the seat grows',
        );
        expect(
          layout.bounds.overlaps(avatar),
          isTrue,
          reason: '${entry.key} fan must tuck behind its own avatar',
        );
        _expectRectInsideRRect(
          layout.bounds,
          safeBoundary,
          reason: '${entry.key} fan must stay inside the felt line',
        );
        for (final Rect obstacle in otherSeats) {
          expect(
            layout.bounds.overlaps(obstacle.inflate(4)),
            isFalse,
            reason: '${entry.key} fan must avoid every other seat',
          );
        }
      }
    },
  );

  test(
    'bottom hero fan is symmetric, tucked, and remains below the midpoint',
    () {
      const Rect heroSeat = Rect.fromLTWH(360, 370, 80, 80);
      const double tableMidpointY = 250;
      final Rect avatar = seatAvatarVisualRect(heroSeat);
      final SeatCardFanLayout layout = fitHeroCardRow(
        seatRect: heroSeat,
        tableCenter: tableCenter,
        safeBoundary: safeBoundary,
        tableMidpointY: tableMidpointY,
        cardCount: 2,
        cardW: 72,
        cardH: 102,
        stepFactor: 1.05,
      );
      final List<Offset> centers = centeredFanCardCenters(
        anchor: layout.anchor,
        cardCount: 2,
        step: layout.step,
      );

      expect(centers, hasLength(2));
      expect(
        (centers.first.dx + centers.last.dx) / 2,
        closeTo(avatar.center.dx, 0.001),
      );
      expect(
        avatar.center.dx - centers.first.dx,
        closeTo(centers.last.dx - avatar.center.dx, 0.001),
      );
      expect(layout.scale, 1);
      expect(layout.bounds.overlaps(avatar), isTrue);
      expect(
        layout.bounds.top,
        greaterThanOrEqualTo(tableMidpointY - 0.001),
      );
      _expectRectInsideRRect(
        layout.bounds,
        safeBoundary,
        reason: 'hero fan must stay inside the felt line',
      );
    },
  );

  test('minimum-height Android table still satisfies every hard boundary', () {
    const Size tableSize = Size(900, 260);
    const double railWidth = 24.48;
    const double seatSize = 82.25;
    const int seatCount = 6;
    const int heroIndex = 0;
    final RRect runtimeBoundary = playerSafeFeltRRect(tableSize, railWidth);
    final double avatarSize = seatAvatarVisualRect(
      const Rect.fromLTWH(0, 0, seatSize, seatSize),
    ).width;
    final List<Offset> positions = stadiumSeatTopLeftPositions(
      safeStadiumRect: runtimeBoundary.outerRect,
      seatCount: seatCount,
      heroIndex: heroIndex,
      seatSize: seatSize,
      visualFootprintSize: avatarSize,
      maximumVisualScale: 1.10,
      boundaryGap: 5,
    );
    final List<Rect> seatRects = <Rect>[
      for (final Offset position in positions)
        Rect.fromLTWH(position.dx, position.dy, seatSize, seatSize),
    ];
    final Rect heroAvatar = seatAvatarVisualRect(seatRects[heroIndex]);
    final SeatCardFanLayout heroLayout = fitHeroCardRow(
      seatRect: seatRects[heroIndex],
      tableCenter: tableSize.center(Offset.zero),
      safeBoundary: runtimeBoundary,
      tableMidpointY: tableSize.height / 2,
      cardCount: 2,
      cardW: 52 * kHeroHoleCardScale,
      cardH: 76 * kHeroHoleCardScale,
      stepFactor: 1.05,
    );

    expect(heroLayout.bounds.top, greaterThanOrEqualTo(130 - 0.001));
    expect(
      heroLayout.bounds.center.dx,
      closeTo(heroAvatar.center.dx, 0.001),
    );
    expect(
      heroLayout.scale,
      greaterThan(0.90),
      reason: 'the primary cards must remain readable on short phones',
    );
    _expectRectInsideRRect(
      heroLayout.bounds,
      runtimeBoundary,
      reason: 'minimum-height hero fan must stay inside the felt line',
    );

    final List<Rect> placedFans = <Rect>[heroLayout.bounds];
    for (int seatIndex = 1; seatIndex < seatRects.length; seatIndex++) {
      final List<Rect> obstacles = <Rect>[
        for (int otherIndex = 0; otherIndex < seatRects.length; otherIndex++)
          if (otherIndex != seatIndex) seatRects[otherIndex],
        ...placedFans,
      ];
      final SeatCardFanLayout botLayout = fitBotCardFanNearSeat(
        seatRect: seatRects[seatIndex],
        obstacleRects: obstacles,
        tableCenter: tableSize.center(Offset.zero),
        safeBoundary: runtimeBoundary,
        cardCount: 2,
        cardW: 52,
        cardH: 76,
        fanOverlap: 0.50,
        totalFanAngleRadians: 0.14,
      );

      expect(
        botLayout.visibleFraction,
        inInclusiveRange(
          kSeatCardMinVisibleFraction,
          kSeatCardMaxVisibleFraction,
        ),
      );
      expect(
        botLayout.visibleFractionAtMaximumAvatarScale,
        inInclusiveRange(
          kSeatCardMinVisibleFraction,
          kSeatCardMaxVisibleFraction,
        ),
      );
      _expectRectInsideRRect(
        botLayout.bounds,
        runtimeBoundary,
        reason: 'face-up bot $seatIndex must stay inside the felt line',
      );
      for (final Rect obstacle in obstacles) {
        expect(
          botLayout.bounds.overlaps(obstacle.inflate(4)),
          isFalse,
          reason: 'face-up bot $seatIndex must avoid seats and settled fans',
        );
      }
      placedFans.add(botLayout.bounds);
    }
  });
}

void _expectRectInsideRRect(
  Rect rect,
  RRect boundary, {
  required String reason,
}) {
  for (final Offset corner in <Offset>[
    rect.topLeft,
    rect.topRight,
    rect.bottomLeft,
    rect.bottomRight,
  ]) {
    expect(boundary.contains(corner), isTrue, reason: reason);
  }
}
