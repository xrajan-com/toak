import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Baseline coordinates for the responsive game composition.
///
/// The logical canvas expands along its longer axis to match the available
/// landscape safe area. That preserves uniform object scaling without leaving
/// 16:9 letterbox bars on common wide phones and browser windows.
const Size kGameDesignSize = Size(1024, 576);
const double kGameMinAdaptiveAspectRatio = 4 / 3;
const double kGameMaxAdaptiveAspectRatio = 21 / 9;

@immutable
class GameViewportGeometry {
  const GameViewportGeometry({
    required this.viewportRect,
    required this.safeRect,
    required this.sceneRect,
    required this.designSize,
    required this.scale,
  });

  final Rect viewportRect;
  final Rect safeRect;
  final Rect sceneRect;
  final Size designSize;
  final double scale;

  static GameViewportGeometry resolve({
    required Size viewportSize,
    EdgeInsets viewPadding = EdgeInsets.zero,
  }) {
    final double viewportWidth =
        viewportSize.width.isFinite ? math.max(0, viewportSize.width) : 0;
    final double viewportHeight =
        viewportSize.height.isFinite ? math.max(0, viewportSize.height) : 0;
    final Rect viewportRect =
        Rect.fromLTWH(0, 0, viewportWidth, viewportHeight);

    final double left = viewPadding.left.clamp(0.0, viewportWidth).toDouble();
    final double top = viewPadding.top.clamp(0.0, viewportHeight).toDouble();
    final double right =
        viewPadding.right.clamp(0.0, viewportWidth - left).toDouble();
    final double bottom =
        viewPadding.bottom.clamp(0.0, viewportHeight - top).toDouble();
    final Rect safeRect = Rect.fromLTWH(
      left,
      top,
      math.max(0, viewportWidth - left - right),
      math.max(0, viewportHeight - top - bottom),
    );

    if (safeRect.isEmpty) {
      return GameViewportGeometry(
        viewportRect: viewportRect,
        safeRect: safeRect,
        sceneRect: Rect.fromCenter(
          center: safeRect.center,
          width: 0,
          height: 0,
        ),
        designSize: Size.zero,
        scale: 0,
      );
    }

    final double safeAspectRatio = safeRect.width / safeRect.height;
    final double designAspectRatio = safeAspectRatio
        .clamp(
          kGameMinAdaptiveAspectRatio,
          kGameMaxAdaptiveAspectRatio,
        )
        .toDouble();
    final Size designSize = designAspectRatio >= kGameDesignSize.aspectRatio
        ? Size(
            kGameDesignSize.height * designAspectRatio, kGameDesignSize.height)
        : Size(
            kGameDesignSize.width, kGameDesignSize.width / designAspectRatio);
    final double scale = math.min(
      safeRect.width / designSize.width,
      safeRect.height / designSize.height,
    );
    final Size sceneSize = designSize * scale;
    final Rect sceneRect = Rect.fromCenter(
      center: safeRect.center,
      width: sceneSize.width,
      height: sceneSize.height,
    );

    return GameViewportGeometry(
      viewportRect: viewportRect,
      safeRect: safeRect,
      sceneRect: sceneRect,
      designSize: designSize,
      scale: scale,
    );
  }
}

/// The uniform scale applied to the canonical game surface.
///
/// Descendants use this only when a control must retain a minimum on-screen
/// touch target after the design surface is fitted to a small phone.
class GameViewportScale extends InheritedWidget {
  const GameViewportScale({
    super.key,
    required this.scale,
    required super.child,
  });

  final double scale;

  static double? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<GameViewportScale>()
        ?.scale;
  }

  @override
  bool updateShouldNotify(GameViewportScale oldWidget) =>
      oldWidget.scale != scale;
}

/// Keeps every game-screen object in one uniformly scaled coordinate system.
///
/// Safe-area handling happens once, here. Descendants see the canonical scene
/// size and zero insets, preventing the table, HUD, and action bar from each
/// responding differently to notches, browser chrome, DPR, or system bars.
class GameViewport extends StatelessWidget {
  const GameViewport({
    super.key,
    required this.backgroundColor,
    required this.child,
  });

  static const Key designSurfaceKey = ValueKey<String>('game-design-surface');
  static const Key landscapeGuardKey = ValueKey<String>('game-landscape-guard');

  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData outerMedia = MediaQuery.of(context);

    return ColoredBox(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size viewportSize = Size(
            constraints.hasBoundedWidth
                ? constraints.maxWidth
                : outerMedia.size.width,
            constraints.hasBoundedHeight
                ? constraints.maxHeight
                : outerMedia.size.height,
          );

          // Browsers may ignore the web manifest's orientation request. Never
          // squeeze the landscape game into a portrait browser tab; native
          // Android and iOS are locked to landscape at the platform layer.
          if (viewportSize.height > viewportSize.width) {
            return _LandscapeGuard(viewPadding: outerMedia.viewPadding);
          }

          final GameViewportGeometry geometry = GameViewportGeometry.resolve(
            viewportSize: viewportSize,
            viewPadding: outerMedia.viewPadding,
          );

          if (geometry.scale <= 0 || geometry.sceneRect.isEmpty) {
            return const SizedBox.expand();
          }

          // Preserve accessibility text enlargement inside the fixed game
          // composition. A bounded scale avoids clipping the entire table while
          // still honoring the user's preference instead of disabling it.
          final double requestedTextScale =
              outerMedia.textScaler.scale(16) / 16;
          final double sceneTextScale =
              requestedTextScale.clamp(0.8, 1.6).toDouble();
          final MediaQueryData sceneMedia = outerMedia.copyWith(
            size: geometry.designSize,
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
            systemGestureInsets: EdgeInsets.zero,
            textScaler: TextScaler.linear(sceneTextScale),
          );

          return Stack(
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
                      key: designSurfaceKey,
                      width: geometry.designSize.width,
                      height: geometry.designSize.height,
                      child: MediaQuery(
                        data: sceneMedia,
                        child: GameViewportScale(
                          scale: geometry.scale,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LandscapeGuard extends StatelessWidget {
  const _LandscapeGuard({required this.viewPadding});

  final EdgeInsets viewPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: GameViewport.landscapeGuardKey,
      padding: viewPadding + const EdgeInsets.all(24),
      child: const Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.screen_rotation_rounded,
                color: Colors.white,
                size: 54,
              ),
              SizedBox(height: 14),
              Text(
                'Rotate your device',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'The game is designed for landscape play.',
                style: TextStyle(
                  color: Color(0xFFD8D8D8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
