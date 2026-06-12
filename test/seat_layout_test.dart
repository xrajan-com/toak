import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/players.dart';
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

void main() {
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
            defaultProfileAsset: 'assets/images/profile.png',
            seatMaxW: seatSide,
            seatH: seatSide,
            baseCardW: 66,
            baseCardH: 92,
            cardBackAsset: 'assets/images/cards/back.webp',
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
    expect(
      (heroTarget.dx - geom!.feltRect.center.dx).abs(),
      lessThan(seatSide * 0.08),
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
            defaultProfileAsset: 'assets/images/profile.png',
            seatMaxW: seatSide,
            seatH: seatSide,
            baseCardW: 66,
            baseCardH: 92,
            cardBackAsset: 'assets/images/cards/back.webp',
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
            defaultProfileAsset: 'assets/images/profile.png',
            seatMaxW: 102,
            seatH: 102,
            baseCardW: 66,
            baseCardH: 92,
            cardBackAsset: 'assets/images/cards/back.webp',
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
}
