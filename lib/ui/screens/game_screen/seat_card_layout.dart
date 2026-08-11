import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bot hole cards are intentionally compact so they read as seat-owned cards,
/// not as a second community-card row.
const double kBotHoleCardScale = 0.50;
const double kHeroHoleCardScale = 1.375;
const double kSeatCardTargetVisibleFraction = 0.65;
const double kSeatCardMinVisibleFraction = 0.50;
const double kSeatCardMaxVisibleFraction = 0.80;
const double kHeroSeatCardMinimumScale = 0.78;

class SeatCardFanLayout {
  const SeatCardFanLayout({
    required this.anchor,
    required this.scale,
    required this.step,
    required this.bounds,
    required this.visibleFraction,
    required this.visibleFractionAtMaximumAvatarScale,
    required this.inwardDirection,
  });

  final Offset anchor;
  final double scale;
  final double step;
  final Rect bounds;

  /// Exposure with the avatar at its normal rendered size.
  final double visibleFraction;

  /// Exposure while the owner avatar is at its maximum animated scale.
  final double visibleFractionAtMaximumAvatarScale;
  final Offset inwardDirection;
}

Rect seatAvatarVisualRect(
  Rect seatRect, {
  double avatarScale = 0.85,
}) {
  final double pillH = seatRect.height;
  final double avatarBaseSize = (pillH * 0.94).clamp(40.0, pillH).toDouble();
  final double avatarSize =
      (avatarBaseSize * avatarScale).clamp(34.0, pillH).toDouble();
  final double avatarInset =
      ((pillH - avatarSize) / 2).clamp(2.0, pillH * 0.18).toDouble();
  return Rect.fromLTWH(
    seatRect.left + avatarInset,
    seatRect.top + avatarInset,
    avatarSize,
    avatarSize,
  );
}

List<Offset> centeredFanCardCenters({
  required Offset anchor,
  required int cardCount,
  required double step,
}) {
  return List<Offset>.generate(
    cardCount,
    (int index) => Offset(
      anchor.dx + (index - (cardCount - 1) / 2) * step,
      anchor.dy,
    ),
    growable: false,
  );
}

/// Fits the hero's side-by-side row in the protected lower felt band.
///
/// The bot fan solver below intentionally reasons about radial exposure of a
/// compact, overlapped fan. That one-dimensional proxy is not valid for the
/// hero's wide side-by-side row: the avatar covers only the two inner card
/// edges. Sending the hero through that solver caused common landscape phones
/// to shrink the primary cards to 40%.
///
/// This analytic layout keeps the card bottoms on the protected felt boundary,
/// keeps the row below [tableMidpointY] whenever the requested cards fit, and
/// applies a hard readability floor if a future caller supplies impossible
/// geometry. The canonical game viewport keeps normal runtime geometry at
/// scale 1.
SeatCardFanLayout fitHeroCardRow({
  required Rect seatRect,
  required Offset tableCenter,
  required RRect safeBoundary,
  required double tableMidpointY,
  required int cardCount,
  required double cardW,
  required double cardH,
  required double stepFactor,
  double minimumScale = kHeroSeatCardMinimumScale,
  double maximumAvatarScale = 1.10,
}) {
  final int count = cardCount.clamp(1, 2);
  final Rect avatarRect = seatAvatarVisualRect(seatRect);
  final Rect safeRect = safeBoundary.outerRect;
  final double safeCardW = math.max(1.0, cardW);
  final double safeCardH = math.max(1.0, cardH);
  final double safeStepFactor = math.max(0.0, stepFactor);
  final double nominalStep = safeCardW * safeStepFactor;
  final double nominalFanWidth =
      safeCardW + math.max(0, count - 1) * nominalStep;

  // At the very bottom of an RRect, only the straight center segment is valid.
  // Keeping the card corners inside this span guarantees the full row remains
  // inside the curved player-safe boundary.
  final double bottomSpanLeft = safeRect.left + safeBoundary.blRadiusX;
  final double bottomSpanRight = safeRect.right - safeBoundary.brRadiusX;
  final double bottomSpanWidth =
      math.max(0.0, bottomSpanRight - bottomSpanLeft);
  // Rect/RRect containment treats the bottom edge as exclusive.
  const double boundaryEpsilon = 0.001;
  final double availableHeight =
      math.max(0.0, safeRect.bottom - boundaryEpsilon - tableMidpointY);
  final double fitScale = math.min(
    1.0,
    math.min(
      availableHeight / safeCardH,
      bottomSpanWidth / math.max(1.0, nominalFanWidth),
    ),
  );
  final double readableFloor = minimumScale.clamp(0.1, 1.0).toDouble();
  final double scale = math.max(readableFloor, fitScale);
  final double fittedW = safeCardW * scale;
  final double fittedH = safeCardH * scale;
  final double step = nominalStep * scale;
  final double fanWidth = fittedW + math.max(0, count - 1) * step;
  final double halfFanWidth = fanWidth / 2;

  final double minCenterX = bottomSpanLeft + halfFanWidth;
  final double maxCenterX = bottomSpanRight - halfFanWidth;
  final double anchorX = minCenterX <= maxCenterX
      ? avatarRect.center.dx.clamp(minCenterX, maxCenterX).toDouble()
      : safeRect.center.dx;
  final double anchorY = safeRect.bottom - boundaryEpsilon - fittedH / 2;
  final Offset anchor = Offset(anchorX, anchorY);
  final Rect bounds = Rect.fromCenter(
    center: anchor,
    width: fanWidth,
    height: fittedH,
  );
  final Offset inwardDirection = _unitVector(tableCenter - avatarRect.center);

  return SeatCardFanLayout(
    anchor: anchor,
    scale: scale,
    step: step,
    bounds: bounds,
    visibleFraction: _visibleFractionBeyondAvatar(
      fanBounds: bounds,
      avatarRect: avatarRect,
      inwardDirection: inwardDirection,
    ),
    visibleFractionAtMaximumAvatarScale: _visibleFractionBeyondAvatar(
      fanBounds: bounds,
      avatarRect: avatarRect,
      inwardDirection: inwardDirection,
      avatarRadiusScale: math.max(1.0, maximumAvatarScale),
    ),
    inwardDirection: inwardDirection,
  );
}

SeatCardFanLayout fitSeatCardFanBehindAvatar({
  required Rect seatRect,
  required List<Rect> obstacleRects,
  required Offset tableCenter,
  required RRect safeBoundary,
  required int cardCount,
  required double cardW,
  required double cardH,
  required double stepFactor,
  required double totalFanAngleRadians,
  double targetVisibleFraction = kSeatCardTargetVisibleFraction,
  double minimumVisibleFraction = kSeatCardMinVisibleFraction,
  double maximumVisibleFraction = kSeatCardMaxVisibleFraction,
  double maximumAvatarScale = 1.10,
  double minimumScale = 0.78,
  double? minimumBoundsTop,
}) {
  final int count = cardCount.clamp(1, 2);
  final Rect avatarRect = seatAvatarVisualRect(seatRect);
  final Offset inwardDirection = _unitVector(tableCenter - avatarRect.center);
  final double targetVisible = targetVisibleFraction
      .clamp(minimumVisibleFraction, maximumVisibleFraction)
      .toDouble();
  final List<double> visibleAttempts = <double>[
    targetVisible,
    for (double q = targetVisible + 0.05;
        q <= maximumVisibleFraction + 0.001;
        q += 0.05)
      q.clamp(minimumVisibleFraction, maximumVisibleFraction).toDouble(),
    for (double q = targetVisible - 0.05;
        q >= minimumVisibleFraction - 0.001;
        q -= 0.05)
      q.clamp(minimumVisibleFraction, maximumVisibleFraction).toDouble(),
  ];
  // Fine-grained attempts keep any required reduction close to the minimum.
  const int scaleAttempts = 21;

  SeatCardFanLayout? best;
  double bestPenalty = double.infinity;

  for (int attempt = 0; attempt < scaleAttempts; attempt++) {
    final double t = attempt / (scaleAttempts - 1);
    final double scale = 1.0 - (1.0 - minimumScale.clamp(0.1, 1.0)) * t;
    final double fittedW = cardW * scale;
    final double fittedH = cardH * scale;
    final double step = fittedW * stepFactor;
    final double startAngle = count > 1 ? -totalFanAngleRadians / 2 : 0;
    final double angleStep = count > 1 ? totalFanAngleRadians / (count - 1) : 0;
    final Rect localBounds = _rotatedFanBounds(
      cardCount: count,
      cardW: fittedW,
      cardH: fittedH,
      step: step,
      startAngle: startAngle,
      angleStep: angleStep,
    );

    final double fanHalfExtent =
        _rectHalfExtentAlong(localBounds, inwardDirection);
    final double avatarRadius = avatarRect.shortestSide / 2;
    final double maximumAvatarRadius =
        avatarRadius * math.max(1.0, maximumAvatarScale);

    for (int visibleIndex = 0;
        visibleIndex < visibleAttempts.length;
        visibleIndex++) {
      final double requestedVisible = visibleAttempts[visibleIndex];
      final double radialDistance =
          maximumAvatarRadius + (2 * requestedVisible - 1) * fanHalfExtent;
      final Offset desiredCenter =
          avatarRect.center + inwardDirection * radialDistance;
      final Offset anchor = desiredCenter - localBounds.center;
      final Rect bounds = localBounds.shift(anchor);
      final bool insideBoundary = _rrectContainsRect(safeBoundary, bounds);
      final bool aboveMinimum =
          minimumBoundsTop == null || bounds.top >= minimumBoundsTop - 0.001;
      double overlap = 0;
      for (final Rect obstacle in obstacleRects) {
        overlap += _overlapArea(bounds, obstacle.inflate(4.0));
      }

      final double visibleFraction = _visibleFractionBeyondAvatar(
        fanBounds: bounds,
        avatarRect: avatarRect,
        inwardDirection: inwardDirection,
      );
      final double maximumScaleVisibleFraction = _visibleFractionBeyondAvatar(
        fanBounds: bounds,
        avatarRect: avatarRect,
        inwardDirection: inwardDirection,
        avatarRadiusScale: math.max(1.0, maximumAvatarScale),
      );
      final double rangePenalty = visibleFraction <
                  minimumVisibleFraction - 0.001 ||
              visibleFraction > maximumVisibleFraction + 0.001 ||
              maximumScaleVisibleFraction < minimumVisibleFraction - 0.001 ||
              maximumScaleVisibleFraction > maximumVisibleFraction + 0.001
          ? 100000
          : 0;
      final double penalty = (insideBoundary ? 0 : 1000000) +
          (aboveMinimum ? 0 : 1000000) +
          overlap * 100 +
          rangePenalty +
          (maximumScaleVisibleFraction - targetVisible).abs() * 100 +
          visibleIndex * 0.2 +
          attempt * 0.5;
      final SeatCardFanLayout layout = SeatCardFanLayout(
        anchor: anchor,
        scale: scale,
        step: step,
        bounds: bounds,
        visibleFraction: visibleFraction,
        visibleFractionAtMaximumAvatarScale: maximumScaleVisibleFraction,
        inwardDirection: inwardDirection,
      );
      if (penalty < bestPenalty) {
        bestPenalty = penalty;
        best = layout;
      }
      if (insideBoundary &&
          aboveMinimum &&
          overlap <= 0.001 &&
          visibleFraction >= minimumVisibleFraction - 0.001 &&
          visibleFraction <= maximumVisibleFraction + 0.001 &&
          maximumScaleVisibleFraction >= minimumVisibleFraction - 0.001 &&
          maximumScaleVisibleFraction <= maximumVisibleFraction + 0.001) {
        return layout;
      }
    }
  }

  return best ??
      SeatCardFanLayout(
        anchor: avatarRect.center,
        scale: minimumScale,
        step: cardW * minimumScale * stepFactor,
        bounds: Rect.fromCenter(
          center: avatarRect.center,
          width: cardW * minimumScale,
          height: cardH * minimumScale,
        ),
        visibleFraction: minimumVisibleFraction,
        visibleFractionAtMaximumAvatarScale: minimumVisibleFraction,
        inwardDirection: inwardDirection,
      );
}

SeatCardFanLayout fitBotCardFanNearSeat({
  required Rect seatRect,
  required List<Rect> obstacleRects,
  required Offset tableCenter,
  required RRect safeBoundary,
  required int cardCount,
  required double cardW,
  required double cardH,
  required double fanOverlap,
  required double totalFanAngleRadians,
}) {
  return fitSeatCardFanBehindAvatar(
    seatRect: seatRect,
    obstacleRects: obstacleRects,
    tableCenter: tableCenter,
    safeBoundary: safeBoundary,
    cardCount: cardCount,
    cardW: cardW,
    cardH: cardH,
    stepFactor: 1 - fanOverlap,
    totalFanAngleRadians: totalFanAngleRadians,
  );
}

Rect _rotatedFanBounds({
  required int cardCount,
  required double cardW,
  required double cardH,
  required double step,
  required double startAngle,
  required double angleStep,
}) {
  Rect? result;
  final List<Offset> centers = centeredFanCardCenters(
    anchor: Offset.zero,
    cardCount: cardCount,
    step: step,
  );
  for (int i = 0; i < cardCount; i++) {
    final double angle = startAngle + i * angleStep;
    final double cosA = math.cos(angle).abs();
    final double sinA = math.sin(angle).abs();
    final double rotatedW = cardW * cosA + cardH * sinA;
    final double rotatedH = cardW * sinA + cardH * cosA;
    final Rect cardBounds = Rect.fromCenter(
      center: centers[i],
      width: rotatedW,
      height: rotatedH,
    );
    result = result == null ? cardBounds : result.expandToInclude(cardBounds);
  }
  return result ?? Rect.zero;
}

Offset _unitVector(Offset vector) {
  final double length =
      math.sqrt(vector.dx * vector.dx + vector.dy * vector.dy);
  if (length <= 0.0001) return const Offset(0, -1);
  return vector / length;
}

double _rectHalfExtentAlong(Rect rect, Offset unitDirection) {
  return unitDirection.dx.abs() * rect.width / 2 +
      unitDirection.dy.abs() * rect.height / 2;
}

double _dot(Offset point, Offset direction) =>
    point.dx * direction.dx + point.dy * direction.dy;

double _visibleFractionBeyondAvatar({
  required Rect fanBounds,
  required Rect avatarRect,
  required Offset inwardDirection,
  double avatarRadiusScale = 1.0,
}) {
  final double halfExtent = _rectHalfExtentAlong(fanBounds, inwardDirection);
  if (halfExtent <= 0.0001) return 0;
  final double fanMax = _dot(fanBounds.center, inwardDirection) + halfExtent;
  final double avatarTangent = _dot(
        avatarRect.center,
        inwardDirection,
      ) +
      avatarRect.shortestSide / 2 * avatarRadiusScale;
  return ((fanMax - avatarTangent) / (2 * halfExtent))
      .clamp(0.0, 1.0)
      .toDouble();
}

bool _rrectContainsRect(RRect boundary, Rect rect) {
  return boundary.contains(rect.topLeft) &&
      boundary.contains(rect.topRight) &&
      boundary.contains(rect.bottomLeft) &&
      boundary.contains(rect.bottomRight);
}

double _overlapArea(Rect a, Rect b) {
  if (!a.overlaps(b)) return 0;
  return math.max(0.0, math.min(a.right, b.right) - math.max(a.left, b.left)) *
      math.max(0.0, math.min(a.bottom, b.bottom) - math.max(a.top, b.top));
}
