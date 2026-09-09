import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/players.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/seat_layout.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/table.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/table_ui.dart';

List<Seat> _dummySeats(int n, {required int heroIndex}) {
  return List<Seat>.generate(n, (i) {
    return Seat(
      name: i == heroIndex ? 'You' : 'Bot $i',
      chips: 20000,
      startChips: 20000,
      bet: 0,
      isHero: i == heroIndex,
      kingdom: 'K',
      about: '-',
      avatarKey: 'bot',
      avatarAssetFolder: null,
    );
  });
}

double _minPairwiseDistance(List<Offset> pts) {
  double minD = double.infinity;
  for (int i = 0; i < pts.length; i++) {
    for (int j = i + 1; j < pts.length; j++) {
      minD = math.min(minD, (pts[i] - pts[j]).distance);
    }
  }
  return minD;
}

void _expectCircularFootprintInside({
  required RRect boundary,
  required Offset center,
  required double radius,
  required String reason,
}) {
  const int sampleCount = 360;
  for (int sample = 0; sample < sampleCount; sample++) {
    final double angle = 2 * math.pi * sample / sampleCount;
    final Offset point = center +
        Offset(
          radius * math.cos(angle),
          radius * math.sin(angle),
        );
    expect(
      boundary.contains(point),
      isTrue,
      reason: '$reason; footprint point $sample at $point crossed '
          '${boundary.outerRect}',
    );
  }
}

void main() {
  group('player-safe stadium seat layout', () {
    const double maximumVisualScale = 1.10;
    final List<
        ({
          int seatCount,
          int heroIndex,
          Size tableSize,
          double railWidth,
          double seatSize,
        })> cases = [
      (
        seatCount: 2,
        heroIndex: 0,
        tableSize: const Size(900, 500),
        railWidth: 30,
        seatSize: 94,
      ),
      (
        seatCount: 6,
        heroIndex: 2,
        tableSize: const Size(1080, 580),
        railWidth: 34,
        seatSize: 100,
      ),
      (
        seatCount: 8,
        heroIndex: 3,
        tableSize: const Size(1220, 640),
        railWidth: 36,
        seatSize: 102,
      ),
      (
        seatCount: 10,
        heroIndex: 7,
        tableSize: const Size(1360, 700),
        railWidth: 38,
        seatSize: 104,
      ),
    ];

    for (final testCase in cases) {
      test(
          '${testCase.seatCount} maximum-scale seat circles stay '
          'inside the inner felt line', () {
        final RRect safeBoundary = playerSafeFeltRRect(
          testCase.tableSize,
          testCase.railWidth,
        );
        final List<Offset> positions = stadiumSeatTopLeftPositions(
          safeStadiumRect: safeBoundary.outerRect,
          seatCount: testCase.seatCount,
          heroIndex: testCase.heroIndex,
          seatSize: testCase.seatSize,
          maximumVisualScale: maximumVisualScale,
        );

        expect(positions, hasLength(testCase.seatCount));

        final double visualRadius = testCase.seatSize * maximumVisualScale / 2;
        for (int index = 0; index < positions.length; index++) {
          final Offset center = positions[index] +
              Offset(testCase.seatSize / 2, testCase.seatSize / 2);
          _expectCircularFootprintInside(
            boundary: safeBoundary,
            center: center,
            radius: visualRadius,
            reason: 'seat $index of ${testCase.seatCount}',
          );
        }

        final Offset heroCenter = positions[testCase.heroIndex] +
            Offset(testCase.seatSize / 2, testCase.seatSize / 2);
        expect(
          heroCenter.dx,
          greaterThan(safeBoundary.outerRect.center.dx),
          reason: 'hero sits half a seat clockwise of bottom-centre, so it '
              'belongs in the right half of the table',
        );
        expect(
          heroCenter.dy,
          greaterThan(safeBoundary.outerRect.center.dy),
          reason: 'hero must be on the bottom side of the table',
        );
        expect(
          safeBoundary.outerRect.bottom - (heroCenter.dy + visualRadius),
          closeTo(1.0, 0.001),
          reason: 'hero footprint should retain the requested boundary gap',
        );
      });
    }

    test('seats are equidistant and even tables are mirror-symmetric', () {
      for (final int seatCount in <int>[2, 4, 6, 8, 10]) {
        final List<double> fractions =
            balancedSeatArcFractions(seatCount: seatCount, heroIndex: 0);
        expect(fractions, hasLength(seatCount));

        final List<double> sorted = List<double>.from(fractions)..sort();
        final double step = 1.0 / seatCount;
        for (int i = 0; i < sorted.length - 1; i++) {
          expect(sorted[i + 1] - sorted[i], closeTo(step, 1e-9),
              reason: 'gap $i of $seatCount seats must equal one slice');
        }

        // Mirroring a fraction about bottom-centre must land on another seat.
        for (final double f in fractions) {
          expect(
            fractions.any((double other) => (1.0 - f - other).abs() < 1e-9),
            isTrue,
            reason: '$seatCount seats must be symmetric about bottom-centre',
          );
        }

        expect(fractions.first, lessThan(0.5),
            reason: 'hero sits clockwise of bottom-centre (right half)');
        expect(fractions.first, closeTo(0.5 - step / 2, 1e-9));
      }
    });

    test('player-safe boundary sits wholly inside the painted felt band', () {
      const Size tableSize = Size(1080, 580);
      const double railWidth = 34;
      final Rect innerBand = innerFeltBandRect(tableSize, railWidth);
      final RRect safeBoundary = playerSafeFeltRRect(tableSize, railWidth);
      const double expectedGuard = kInnerFeltBandStrokeWidth / 2;

      expect(
        safeBoundary.outerRect,
        Rect.fromLTRB(
          innerBand.left + expectedGuard,
          innerBand.top + expectedGuard,
          innerBand.right - expectedGuard,
          innerBand.bottom - expectedGuard,
        ),
      );
    });
  });

  testWidgets('Table geometry keeps 10 seats reasonably spaced',
      (tester) async {
    TableGeometry? geom;

    const int seatCount = 10;
    const int heroIndex = 1;
    const double seatSide = 102.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: GameTableLayer(
            width: 1100,
            height: 680,
            railWidth: 34,
            felt: const Color(0xFF13321E),
            wood: WoodType.values.first,
            pot: 0,
            potPulse: const AlwaysStoppedAnimation<double>(0),
            seats: _dummySeats(seatCount, heroIndex: heroIndex),
            heroIndex: heroIndex,
            currentTurn: heroIndex,
            sbIndex: 0,
            bbIndex: 2,
            hiddenSeatIdx: const <int>{},
            defaultProfileAsset: 'assets/images/default_profile.png',
            seatMaxW: seatSide,
            seatH: seatSide,
            baseCardW: 66,
            baseCardH: 92,
            cardBackAsset: 'assets/images/cards/back_custom_01.webp',
            showBlindChips: false,
            paintSeats: false,
            onGeometryChanged: (g) => geom = g,
          ),
        ),
      ),
    );
    await tester.pump(); // allow post-frame geometry callback

    expect(geom, isNotNull);
    expect(geom!.seatTargets.length, seatCount);

    final minDist = _minPairwiseDistance(geom!.seatTargets);
    // This is a coarse guard: seats should not fully overlap at full tables.
    expect(minDist, greaterThan(seatSide * 0.45));

    final heroTarget = geom!.seatTargets[heroIndex];
    // Hero now sits half a seat clockwise of bottom-centre (right half of
    // the table, closest seat to centre), not dead-centre — see
    // balancedSeatArcFractions in seat_layout.dart.
    expect(
      heroTarget.dx,
      greaterThan(geom!.feltRect.center.dx),
      reason: 'hero sits half a seat clockwise of bottom-centre, so it '
          'belongs in the right half of the table',
    );
    expect(
      heroTarget.dy,
      greaterThan(geom!.feltRect.center.dy),
      reason: 'hero must be on the bottom side of the table',
    );
  });

  testWidgets('Table geometry keeps 8 seats reasonably spaced', (tester) async {
    TableGeometry? geom;

    const int seatCount = 8;
    const int heroIndex = 1;
    const double seatSide = 102.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: GameTableLayer(
            width: 980,
            height: 600,
            railWidth: 34,
            felt: const Color(0xFF13321E),
            wood: WoodType.values.first,
            pot: 0,
            potPulse: const AlwaysStoppedAnimation<double>(0),
            seats: _dummySeats(seatCount, heroIndex: heroIndex),
            heroIndex: heroIndex,
            currentTurn: heroIndex,
            sbIndex: 0,
            bbIndex: 2,
            hiddenSeatIdx: const <int>{},
            defaultProfileAsset: 'assets/images/default_profile.png',
            seatMaxW: seatSide,
            seatH: seatSide,
            baseCardW: 66,
            baseCardH: 92,
            cardBackAsset: 'assets/images/cards/back_custom_01.webp',
            showBlindChips: false,
            paintSeats: false,
            onGeometryChanged: (g) => geom = g,
          ),
        ),
      ),
    );
    await tester.pump(); // allow post-frame geometry callback

    expect(geom, isNotNull);
    expect(geom!.seatTargets.length, seatCount);

    final minDist = _minPairwiseDistance(geom!.seatTargets);
    expect(minDist, greaterThan(seatSide * 0.45));
  });

  testWidgets('table shows dealer, small blind, and big blind tags',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: GameTableLayer(
            width: 980,
            height: 600,
            railWidth: 34,
            felt: const Color(0xFF13321E),
            wood: WoodType.values.first,
            pot: 0,
            potPulse: const AlwaysStoppedAnimation<double>(0),
            seats: _dummySeats(6, heroIndex: 1),
            heroIndex: 1,
            currentTurn: 1,
            dealerIndex: 4,
            sbIndex: 5,
            bbIndex: 0,
            hiddenSeatIdx: const <int>{},
            defaultProfileAsset: 'assets/images/default_profile.png',
            seatMaxW: 102,
            seatH: 102,
            baseCardW: 66,
            baseCardH: 92,
            cardBackAsset: 'assets/images/cards/back_custom_01.webp',
            paintSeats: false,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('D'), findsOneWidget);
    expect(find.text('SB'), findsOneWidget);
    expect(find.text('BB'), findsOneWidget);
  });

  testWidgets('position chip stays visibly attached to its owning seat',
      (tester) async {
    const Offset heroTopLeft = Offset(250, 300);
    const double seatSide = 80;
    const double chipSize = 30;
    const Key chipKey = ValueKey<String>('position-chip-smallBlind-0');

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              height: 400,
              child: Stack(
                children: buildBlindChips(
                  seats: _dummySeats(1, heroIndex: 0),
                  hiddenSeatIdx: const <int>{},
                  seatPositions: const <Offset>[heroTopLeft],
                  seatSide: seatSide,
                  tableCenter: const Offset(290, 150),
                  clampRect: const Rect.fromLTWH(20, 20, 560, 360),
                  chipSize: chipSize,
                  sbIndex: 0,
                  bbIndex: -1,
                  heroIndex: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final Positioned chip = tester.widget<Positioned>(find.byKey(chipKey));
    final Offset chipCenter = Offset(
      chip.left! + chipSize / 2,
      chip.top! + chipSize / 2,
    );
    final Offset ownerCenter = Offset(
      heroTopLeft.dx + seatSide / 2,
      heroTopLeft.dy + seatSide / 2,
    );
    expect(
      (chipCenter - ownerCenter).distance,
      lessThan(seatSide * 0.65),
    );
    expect(chipCenter.dy, lessThan(ownerCenter.dy));
    expect(chipCenter.dx, greaterThan(ownerCenter.dx));
    expect(
      find.bySemanticsLabel('Small blind for You'),
      findsOneWidget,
    );
  });

  testWidgets('heads-up dealer and small blind share one seat without overlap',
      (tester) async {
    const double seatSide = 84;
    const double chipSize = 28;
    const Offset buttonSeat = Offset(120, 180);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 500,
              height: 360,
              child: Stack(
                children: buildBlindChips(
                  seats: _dummySeats(2, heroIndex: 0),
                  hiddenSeatIdx: const <int>{},
                  seatPositions: const <Offset>[
                    buttonSeat,
                    Offset(300, 180),
                  ],
                  seatSide: seatSide,
                  tableCenter: const Offset(250, 160),
                  clampRect: const Rect.fromLTWH(20, 20, 460, 320),
                  chipSize: chipSize,
                  dealerIndex: 0,
                  sbIndex: 0,
                  bbIndex: 1,
                  heroIndex: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final Rect dealerRect =
        tester.getRect(find.byKey(const ValueKey('position-chip-dealer-0')));
    final Rect smallBlindRect = tester
        .getRect(find.byKey(const ValueKey('position-chip-smallBlind-0')));
    final Rect bigBlindRect =
        tester.getRect(find.byKey(const ValueKey('position-chip-bigBlind-1')));

    expect(dealerRect.overlaps(smallBlindRect), isFalse);
    expect(
      (dealerRect.center -
              Offset(
                buttonSeat.dx + seatSide / 2,
                buttonSeat.dy + seatSide / 2,
              ))
          .distance,
      lessThan(seatSide * 0.8),
    );
    expect(bigBlindRect.center.dx, greaterThan(250));
  });
}
