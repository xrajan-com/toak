import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/ui/art/fort_backdrop.dart';
import 'package:ten_of_a_kind_poker/ui/art/fort_emblem.dart';
import 'package:ten_of_a_kind_poker/ui/art/fort_style.dart';

void main() {
  test('every kingdom has a fort style, and the regions read right', () {
    for (final VenueGroup group in kVenueGroups) {
      for (final VenueTheme venue in venuesForGroup(group)) {
        expect(FortStyle.values, contains(fortStyleForKingdom(venue.name)));
      }
    }
    expect(fortStyleForKingdom('Baroda'), FortStyle.domed);
    expect(fortStyleForKingdom('Arabia'), FortStyle.domed);
    expect(fortStyleForKingdom('Japan'), FortStyle.eastern);
    expect(fortStyleForKingdom('Vietnam'), FortStyle.eastern);
    expect(fortStyleForKingdom('France'), FortStyle.classic);
    expect(fortStyleForKingdom('Brazil'), FortStyle.classic);
    expect(fortStyleForKingdom(null), FortStyle.classic);
  });

  test('art seeds are stable', () {
    expect(stableArtSeed('Baroda'), stableArtSeed('Baroda'));
    expect(stableArtSeed('Baroda'), isNot(stableArtSeed('Jaipur')));
    expect(stableArtSeed(''), greaterThanOrEqualTo(0));
  });

  test('behind the table, the parapet sits above the rail', () {
    const Size screen = Size(1024, 576);
    final Rect table = Rect.fromLTWH(30, 94, 964, 360);
    for (final FortStyle style in FortStyle.values) {
      final FortGeometry g =
          FortGeometry.table(screen, table: table, style: style);
      expect(g.wallTop, greaterThanOrEqualTo(0));
      expect(g.wallBodyTop, lessThan(table.top));
      for (final Offset torch in g.torches) {
        expect(torch.dy, lessThan(table.top));
      }
      expect(g.gate.center.dx, closeTo(screen.width / 2, 0.01));
    }
  });

  test('on the welcome screen, the gate stands on the floor', () {
    for (final Size size in const <Size>[
      Size(844, 390),
      Size(1280, 720),
      Size(390, 844),
    ]) {
      final FortGeometry g = FortGeometry.welcome(size);
      expect(g.arch.bottom, closeTo(g.floorTop, 0.01));
      expect(g.arch.left, greaterThanOrEqualTo(0));
      expect(g.arch.right, lessThanOrEqualTo(size.width));
      expect(g.archPath().getBounds().height, greaterThan(0));
    }
  });

  testWidgets('the backdrop and the emblems paint at phone and web sizes',
      (WidgetTester tester) async {
    for (final Size size in const <Size>[
      Size(844, 390),
      Size(1024, 576),
      Size(390, 844),
    ]) {
      for (final FortStyle style in FortStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Stack(
              children: <Widget>[
                FortBackdrop(
                  geometry: FortGeometry.welcome(size, style: style),
                  bannerColors: const <Color>[Color(0xFFFF2800)],
                ),
                FortBackdrop(
                  geometry: FortGeometry.table(
                    size,
                    table: Rect.fromLTWH(
                      10,
                      size.height * 0.16,
                      size.width - 20,
                      size.height * 0.62,
                    ),
                    style: style,
                  ),
                ),
                SizedBox(
                  width: 400,
                  height: 220,
                  child: FortEmblem(style: style, seed: 42),
                ),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
