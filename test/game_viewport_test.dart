import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/viewport.dart';

void main() {
  test('device matrix expands the game scene across the safe landscape area',
      () {
    const cases = <({
      Size viewport,
      EdgeInsets insets,
    })>[
      (viewport: Size(1024, 576), insets: EdgeInsets.zero),
      (viewport: Size(2048, 1152), insets: EdgeInsets.zero),
      (viewport: Size(784, 384), insets: EdgeInsets.zero),
      (viewport: Size(844, 390), insets: EdgeInsets.fromLTRB(59, 0, 59, 21)),
      (viewport: Size(915, 412), insets: EdgeInsets.fromLTRB(32, 0, 16, 24)),
      (viewport: Size(1194, 834), insets: EdgeInsets.fromLTRB(24, 20, 24, 20)),
    ];

    for (final item in cases) {
      final GameViewportGeometry geometry = GameViewportGeometry.resolve(
        viewportSize: item.viewport,
        viewPadding: item.insets,
      );

      expect(geometry.scale, greaterThan(0));
      expect(
        geometry.designSize.aspectRatio,
        closeTo(
          geometry.sceneRect.width / geometry.sceneRect.height,
          0.000001,
        ),
      );
      expect(
        geometry.sceneRect.center.dx,
        closeTo(geometry.safeRect.center.dx, 0.000001),
        reason: '${item.viewport} must center the responsive composition',
      );
      expect(
        geometry.sceneRect.center.dy,
        closeTo(geometry.safeRect.center.dy, 0.000001),
        reason: '${item.viewport} must center the responsive composition',
      );
      _expectRectContainsRect(geometry.safeRect, geometry.sceneRect);
      expect(
        geometry.sceneRect.width / geometry.designSize.width,
        closeTo(geometry.scale, 0.000001),
      );
      expect(
        geometry.sceneRect.height / geometry.designSize.height,
        closeTo(geometry.scale, 0.000001),
      );
      expect(
        geometry.sceneRect,
        _rectCloseTo(geometry.safeRect),
        reason: '${item.viewport} should not retain avoidable black bars',
      );
    }
  });

  test('wide phones use their full landscape width without stretching', () {
    final GameViewportGeometry geometry = GameViewportGeometry.resolve(
      viewportSize: const Size(784, 384),
    );

    expect(geometry.designSize, const Size(1176, 576));
    expect(geometry.scale, closeTo(2 / 3, 0.000001));
    expect(geometry.sceneRect.height, 384);
    expect(geometry.sceneRect.width, 784);
    expect(geometry.sceneRect.left, 0);
    expect(geometry.sceneRect.right, 784);
  });

  test('extreme landscape aspects retain only intentional centered bars', () {
    final GameViewportGeometry tall = GameViewportGeometry.resolve(
      viewportSize: const Size(1100, 900),
    );
    expect(
      tall.designSize.aspectRatio,
      closeTo(kGameMinAdaptiveAspectRatio, 0.000001),
    );
    expect(tall.sceneRect.width, 1100);
    expect(tall.sceneRect.height, closeTo(825, 0.0001));
    expect(tall.sceneRect.center, tall.safeRect.center);

    final GameViewportGeometry ultrawide = GameViewportGeometry.resolve(
      viewportSize: const Size(2400, 800),
    );
    expect(
      ultrawide.designSize.aspectRatio,
      closeTo(kGameMaxAdaptiveAspectRatio, 0.000001),
    );
    expect(ultrawide.sceneRect.height, 800);
    expect(ultrawide.sceneRect.width, closeTo(1866.6667, 0.001));
    expect(ultrawide.sceneRect.center, ultrawide.safeRect.center);
  });

  test('layout is based on logical size, not device pixel ratio', () {
    const Size logicalSize = Size(844, 390);
    const EdgeInsets safeInsets = EdgeInsets.fromLTRB(47, 0, 34, 21);
    final GameViewportGeometry expected = GameViewportGeometry.resolve(
      viewportSize: logicalSize,
      viewPadding: safeInsets,
    );

    for (final double dpr in <double>[1, 2, 3, 3.5]) {
      final Size physicalSize = logicalSize * dpr;
      final Size recoveredLogical = Size(
        physicalSize.width / dpr,
        physicalSize.height / dpr,
      );
      final GameViewportGeometry actual = GameViewportGeometry.resolve(
        viewportSize: recoveredLogical,
        viewPadding: safeInsets,
      );

      expect(actual.sceneRect, expected.sceneRect);
      expect(actual.designSize, expected.designSize);
      expect(actual.scale, expected.scale);
    }
  });

  testWidgets(
    'descendants receive responsive metrics and normalized positions',
    (WidgetTester tester) async {
      const Key probeKey = ValueKey<String>('normalized-scene-probe');
      const Key squareProbeKey = ValueKey<String>('square-scene-probe');

      Future<void> verify({
        required Size viewport,
        required EdgeInsets insets,
        required double dpr,
      }) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport;

        MediaQueryData? observedMedia;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: viewport,
              devicePixelRatio: dpr,
              padding: insets,
              viewPadding: insets,
              textScaler: const TextScaler.linear(1.8),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: GameViewport(
                backgroundColor: Colors.black,
                child: Builder(
                  builder: (BuildContext context) {
                    observedMedia = MediaQuery.of(context);
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: <Widget>[
                            Positioned(
                              left: constraints.maxWidth * 0.10,
                              top: constraints.maxHeight * 0.10,
                              width: constraints.maxWidth * 0.20,
                              height: constraints.maxHeight * 0.20,
                              child: const ColoredBox(
                                key: probeKey,
                                color: Colors.red,
                              ),
                            ),
                            const Positioned(
                              left: 0,
                              top: 0,
                              width: 100,
                              height: 100,
                              child: ColoredBox(
                                key: squareProbeKey,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );

        expect(observedMedia, isNotNull);
        final GameViewportGeometry expected = GameViewportGeometry.resolve(
          viewportSize: viewport,
          viewPadding: insets,
        );
        expect(observedMedia!.size, expected.designSize);
        expect(observedMedia!.padding, EdgeInsets.zero);
        expect(observedMedia!.viewPadding, EdgeInsets.zero);
        expect(
          observedMedia!.textScaler.scale(20),
          closeTo(32, 0.0001),
          reason: 'game text should preserve bounded accessibility scaling',
        );

        final Rect sceneRect =
            _globalPaintRect(tester, find.byKey(GameViewport.designSurfaceKey));
        final Rect probeRect = _globalPaintRect(tester, find.byKey(probeKey));
        final Rect squareRect =
            _globalPaintRect(tester, find.byKey(squareProbeKey));
        expect(
          (probeRect.left - sceneRect.left) / sceneRect.width,
          closeTo(0.10, 0.0001),
        );
        expect(
          (probeRect.top - sceneRect.top) / sceneRect.height,
          closeTo(0.10, 0.0001),
        );
        expect(probeRect.width / sceneRect.width, closeTo(0.20, 0.0001));
        expect(probeRect.height / sceneRect.height, closeTo(0.20, 0.0001));
        expect(
          squareRect.width,
          closeTo(squareRect.height, 0.0001),
          reason: 'the responsive canvas must still scale objects uniformly',
        );
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await verify(
        viewport: const Size(1024, 576),
        insets: EdgeInsets.zero,
        dpr: 1,
      );
      await verify(
        viewport: const Size(844, 390),
        insets: const EdgeInsets.fromLTRB(47, 0, 34, 21),
        dpr: 3,
      );
    },
  );

  testWidgets('portrait browser viewports require landscape before rendering',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: GameViewport(
          backgroundColor: Colors.black,
          child: ColoredBox(color: Colors.red),
        ),
      ),
    );

    expect(find.byKey(GameViewport.landscapeGuardKey), findsOneWidget);
    expect(find.text('Rotate your device'), findsOneWidget);
    expect(find.byKey(GameViewport.designSurfaceKey), findsNothing);
  });
}

Rect _globalPaintRect(WidgetTester tester, Finder finder) {
  final RenderBox box = tester.renderObject<RenderBox>(finder);
  final Offset topLeft = box.localToGlobal(Offset.zero);
  final Offset bottomRight = box.localToGlobal(
    Offset(box.size.width, box.size.height),
  );
  return Rect.fromPoints(topLeft, bottomRight);
}

void _expectRectContainsRect(Rect outer, Rect inner) {
  expect(inner.left, greaterThanOrEqualTo(outer.left - 0.0001));
  expect(inner.top, greaterThanOrEqualTo(outer.top - 0.0001));
  expect(inner.right, lessThanOrEqualTo(outer.right + 0.0001));
  expect(inner.bottom, lessThanOrEqualTo(outer.bottom + 0.0001));
}

Matcher _rectCloseTo(Rect expected) {
  return predicate<Rect>(
    (actual) =>
        (actual.left - expected.left).abs() < 0.0001 &&
        (actual.top - expected.top).abs() < 0.0001 &&
        (actual.right - expected.right).abs() < 0.0001 &&
        (actual.bottom - expected.bottom).abs() < 0.0001,
    'a rect close to $expected',
  );
}
