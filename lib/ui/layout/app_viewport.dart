import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:ten_of_a_kind_poker/ui/screens/game_screen/viewport.dart';

/// Whether the whole app renders inside one uniformly scaled design canvas.
///
/// Web only, deliberately. Browser windows vary far more than phone screens:
/// the same build is handed a ~944pt-wide window on a laptop and a 3840pt-wide
/// one on a desktop monitor. Every screen that pins a widget to a logical pixel
/// width - the auth card is 520, its dialogs are 440 - then occupies a totally
/// different fraction of the viewport, which is why the same build looks
/// generous in one window and stranded in a black void in another.
///
/// Native builds keep their current responsive behaviour on purpose. Phones sit
/// in a narrow band of sizes, and the poker table already locks its own canvas
/// through [GameViewport], so there is no equivalent drift to fix there. Flip
/// this to `true` to extend the canvas to Android and iOS as well.
const bool kAppViewportCanvasEnabled = kIsWeb;

/// Lays the entire app out on one uniformly scaled canvas.
///
/// Reuses [GameViewportGeometry] so the shell and the poker table agree on how
/// a design surface is fitted. The canvas adapts its aspect ratio to the safe
/// area within [kGameMinAdaptiveAspectRatio]..[kGameMaxAdaptiveAspectRatio],
/// which preserves uniform scaling without letterboxing ordinary window shapes.
class AppViewport extends StatelessWidget {
  const AppViewport({super.key, required this.child});

  static const Key surfaceKey = ValueKey<String>('app-design-surface');

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kAppViewportCanvasEnabled) return child;

    final MediaQueryData outerMedia = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size viewportSize = Size(
          constraints.hasBoundedWidth
              ? constraints.maxWidth
              : outerMedia.size.width,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : outerMedia.size.height,
        );

        // The whole app is designed landscape. Locking a landscape canvas onto
        // a portrait phone browser would shrink it to a third of its size
        // between two fat black bars, so portrait keeps today's responsive
        // layout and only landscape gets the deterministic canvas.
        if (viewportSize.height > viewportSize.width) return child;

        final GameViewportGeometry geometry = GameViewportGeometry.resolve(
          viewportSize: viewportSize,
          viewPadding: outerMedia.viewPadding,
        );

        // Never blank the shell out on a degenerate frame; fall back to the
        // plain responsive layout instead.
        if (geometry.scale <= 0 || geometry.sceneRect.isEmpty) return child;

        // Preserve accessibility text enlargement inside the fixed canvas. A
        // bounded scale honours the preference without bursting the surface.
        final double requestedTextScale = outerMedia.textScaler.scale(16) / 16;
        final double canvasTextScale =
            requestedTextScale.clamp(0.8, 1.6).toDouble();

        final MediaQueryData canvasMedia = outerMedia.copyWith(
          size: geometry.designSize,
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
          // Keyboard insets arrive in real pixels. Express them in design
          // pixels so text fields still scroll into view inside the canvas.
          viewInsets: outerMedia.viewInsets / geometry.scale,
          systemGestureInsets: EdgeInsets.zero,
          textScaler: TextScaler.linear(canvasTextScale),
        );

        return ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned.fromRect(
                rect: geometry.sceneRect,
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      key: surfaceKey,
                      width: geometry.designSize.width,
                      height: geometry.designSize.height,
                      child: MediaQuery(data: canvasMedia, child: child),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
