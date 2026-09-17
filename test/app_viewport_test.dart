import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/viewport.dart';

void main() {
  // The bug this guards against: a widget pinned to a logical pixel width fills
  // ~55% of a small browser window and ~27% of a large one, so the same build
  // looks different depending only on how big the window happened to be.
  const double kAuthCardWidth = 520;

  test('canvas keeps a fixed-width card at one fraction of the window', () {
    const List<Size> sameShapeWindows = <Size>[
      Size(944, 636),
      Size(1888, 1272),
      Size(2560, 1724),
    ];

    final List<double> fractions = <double>[
      for (final Size window in sameShapeWindows)
        (kAuthCardWidth *
                GameViewportGeometry.resolve(viewportSize: window).scale) /
            window.width,
    ];

    for (final double fraction in fractions) {
      expect(fraction, closeTo(fractions.first, 0.001));
    }
  });

  test('canvas keeps the card readable across extreme window shapes', () {
    const List<Size> windows = <Size>[
      Size(1024, 768), // 4:3
      Size(1440, 900), // 16:10
      Size(1920, 1080), // 16:9
      Size(3440, 1440), // 21:9 ultrawide
      Size(3840, 2160), // 4K
    ];

    for (final Size window in windows) {
      final GameViewportGeometry geometry =
          GameViewportGeometry.resolve(viewportSize: window);
      final double fraction =
          (kAuthCardWidth * geometry.scale) / window.width;

      // Before the canvas this ranged from 0.14 (4K) to 0.55 (laptop).
      expect(fraction, greaterThan(0.2));
      expect(fraction, lessThan(0.6));
    }
  });
}
