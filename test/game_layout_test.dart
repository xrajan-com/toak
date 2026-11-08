import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/action_bar.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/game_layout.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/viewport.dart';

/// Screens in logical pixels (landscape), with their safe-area insets.
const List<({String name, Size size, EdgeInsets insets, bool phone})>
    _devices = <({String name, Size size, EdgeInsets insets, bool phone})>[
  (
    name: 'small phone 568x320',
    size: Size(568, 320),
    insets: EdgeInsets.zero,
    phone: true,
  ),
  (
    name: '16:9 phone 640x360',
    size: Size(640, 360),
    insets: EdgeInsets.zero,
    phone: true,
  ),
  (
    name: '20:9 phone 800x360',
    size: Size(800, 360),
    insets: EdgeInsets.zero,
    phone: true,
  ),
  (
    name: 'iPhone 844x390',
    size: Size(844, 390),
    insets: EdgeInsets.fromLTRB(47, 0, 34, 21),
    phone: true,
  ),
  (
    name: 'Android 915x412',
    size: Size(915, 412),
    insets: EdgeInsets.fromLTRB(32, 0, 16, 24),
    phone: true,
  ),
  (
    name: 'web 1024x576',
    size: Size(1024, 576),
    insets: EdgeInsets.zero,
    phone: false,
  ),
  (
    name: 'laptop browser 1440x760',
    size: Size(1440, 760),
    insets: EdgeInsets.zero,
    phone: false,
  ),
  (
    name: 'Android tablet 1280x800',
    size: Size(1280, 800),
    insets: EdgeInsets.zero,
    phone: false,
  ),
  (
    name: 'iPad 1180x820',
    size: Size(1180, 820),
    insets: EdgeInsets.fromLTRB(0, 24, 0, 20),
    phone: false,
  ),
  (
    name: 'desktop 1920x969',
    size: Size(1920, 969),
    insets: EdgeInsets.zero,
    phone: false,
  ),
];

void main() {
  final GameLayout phoneReference = GameLayout.resolve(const Size(1280, 576));
  final GameLayout narrowest = GameLayout.resolve(const Size(1024, 576));

  test('without a viewport scale, the phone layout is used', () {
    expect(GameLayout.controlScaleFor(null), 1.0);
    expect(phoneReference.controlScale, 1.0);
    expect(phoneReference.contentScale, 1.0);
  });

  for (final device in _devices) {
    test('${device.name}: controls by the finger, table fills the rest', () {
      final GameViewportGeometry viewport = GameViewportGeometry.resolve(
        viewportSize: device.size,
        viewPadding: device.insets,
      );
      final double s = viewport.scale;
      final Size canvas = viewport.designSize;
      final GameLayout layout = GameLayout.resolve(canvas, viewportScale: s);
      final double c = layout.controlScale;

      // A hero button's face, and its tap target, on screen.
      final double faceDp = kActionButtonFaceHeight * c * s;
      expect(faceDp, greaterThanOrEqualTo(GameLayout.minFaceDp - 1e-9));
      expect(faceDp, lessThanOrEqualTo(GameLayout.maxFaceDp + 1e-9));
      final double tapDp = math.max(70.0, 44.0 / (s * c)) * c * s;
      expect(tapDp, greaterThanOrEqualTo(44.0 - 1e-9));

      // The bar keeps its shape: never wider, in its own units, than a
      // phone's, and never past the share of the width it may take.
      expect(layout.actionBarMaxWidth / c,
          lessThanOrEqualTo(GameLayout.barMaxWidth + 1e-9));
      expect(
        layout.actionBarMaxWidth,
        lessThanOrEqualTo(canvas.width * GameLayout.barMaxWidthShare + 1e-9),
      );

      // The table's top rail stays where it always was.
      final double h = canvas.height;
      final double anchor = (h * 0.59).clamp(260.0, 780.0).toDouble();
      final double lift = (h * 0.024).clamp(12.0, 24.0).toDouble();
      expect(
        layout.tableTop,
        closeTo(h / 2 - lift - anchor * GameLayout.tableVisualScale / 2, 1e-9),
      );

      // Its bottom comes down to just above the raised controls, and the
      // raised controls (with the slider open) are what was measured.
      expect(
        layout.tableBottom,
        closeTo(layout.raisedControlsTop - GameLayout.tableClearance, 1e-6),
      );
      final double raised = actionBarHeight(
            raising: true,
            viewportScale: s * c,
          ) *
          c;
      expect(
        layout.raisedControlsTop,
        closeTo(h - GameLayout.barBottomMargin - raised, 1e-6),
      );
      expect(
        layout.tableTop + layout.tableHeight * GameLayout.tableVisualScale / 2,
        closeTo(h / 2 + layout.tableVerticalShift, 1e-9),
      );

      // Seats and cards: never below their phone size, at most 1.3x, and
      // never more crowded across the table than on the narrowest canvas.
      expect(layout.contentScale, inInclusiveRange(1.0, 1.3));
      expect(
        layout.contentScale * narrowest.tableWidth,
        lessThanOrEqualTo(layout.tableWidth + 1e-9),
      );

      if (device.phone) {
        // Phones keep the layout they had.
        expect(layout.contentScale, 1.0);
        expect(c, inInclusiveRange(1.0, 1.2));
        expect(
          layout.tableHeight,
          closeTo(phoneReference.tableHeight,
              phoneReference.tableHeight * 0.05),
        );
      } else {
        // Bigger screens give the room to the table, not to the buttons.
        expect(c, lessThan(1.0));
        expect(
          layout.tableHeight * GameLayout.tableVisualScale / h,
          greaterThan(phoneReference.tableHeight *
              GameLayout.tableVisualScale /
              576),
        );
      }
    });
  }

  testWidgets('a scaled cluster lays out, draws and takes taps at its size',
      (tester) async {
    int taps = 0;
    const Key inner = ValueKey<String>('inner');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ScaledLayout(
            scale: 0.5,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(key: inner, width: 200, height: 100),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(ScaledLayout)), const Size(100, 50));
    expect(tester.getRect(find.byKey(inner)),
        const Rect.fromLTWH(0, 0, 100, 50));

    await tester.tapAt(const Offset(90, 45));
    expect(taps, 1);
    await tester.tapAt(const Offset(150, 75));
    expect(taps, 1, reason: 'outside the drawn cluster');
  });

  testWidgets('a scaled cluster fills tight room by laying out larger',
      (tester) async {
    const Key inner = ValueKey<String>('inner');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 100,
            child: ScaledLayout(
              scale: 1.5,
              child: SizedBox.expand(key: inner),
            ),
          ),
        ),
      ),
    );

    final RenderBox box = tester.renderObject<RenderBox>(find.byKey(inner));
    expect(box.size, const Size(200, 100 / 1.5));
    expect(tester.getRect(find.byKey(inner)),
        const Rect.fromLTWH(0, 0, 300, 100));
  });
}
