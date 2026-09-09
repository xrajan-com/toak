import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fractions along the seating arc, one per seat, hero first.
///
/// Every seat gets an identical slice, and the hero sits half a slice
/// *clockwise* of bottom-centre rather than on it. That half-step is what
/// makes an even table read as symmetric: the vertical axis falls between
/// two seats, so six players sit three-a-side with two genuinely across the
/// felt from the hero.
///
/// The previous version pinned the hero to exactly 0.5 and then scaled each
/// side by its own seat count, so six seats came out as
/// `[0.5, 0.667, 0.833, 1.0, 0.0, 0.25]` — three seats sharing one side's
/// arc and two sharing the other, at visibly different spacings. Seats were
/// never actually equidistant.
List<double> balancedSeatArcFractions({
  required int seatCount,
  required int heroIndex,
}) {
  if (seatCount <= 0) return const <double>[];
  // A lone seat has no ring to be symmetric about; put it at the bottom.
  if (seatCount == 1) return const <double>[0.5];

  final int normalizedHero =
      (heroIndex >= 0 && heroIndex < seatCount) ? heroIndex : 0;

  final double step = 1.0 / seatCount;
  final double heroFraction = 0.5 - step / 2;

  return List<double>.generate(seatCount, (int seatIndex) {
    // Seat order runs clockwise from the hero, which on screen places the
    // next seat to the hero's left — the same direction as turn order.
    final int offset = (seatIndex - normalizedHero + seatCount) % seatCount;
    final double raw = heroFraction + offset * step;
    return raw - raw.floorToDouble();
  }, growable: false);
}

double _horizontalStadiumPerimeter(Rect rect) {
  final double radius = math.max(0.0, rect.height / 2);
  final double straight = math.max(0.0, rect.width - 2 * radius);
  return 2 * straight + 2 * math.pi * radius;
}

/// Point on a horizontal stadium perimeter, starting at top-centre and moving
/// clockwise. [fraction] wraps into the 0–1 range.
Offset horizontalStadiumPointAtFraction(Rect rect, double fraction) {
  if (rect.width <= 0 || rect.height <= 0) return rect.center;
  if (rect.width < rect.height) {
    final Rect transposed = Rect.fromCenter(
      center: Offset(rect.center.dy, rect.center.dx),
      width: rect.height,
      height: rect.width,
    );
    final Offset p = horizontalStadiumPointAtFraction(transposed, fraction);
    return Offset(p.dy, p.dx);
  }

  final double radius = rect.height / 2;
  final double straight = math.max(0.0, rect.width - 2 * radius);
  final double perimeter = _horizontalStadiumPerimeter(rect);
  if (perimeter <= 0) return rect.center;
  double distance = ((fraction % 1) + 1) % 1 * perimeter;
  final double rightCenterX = rect.right - radius;
  final double leftCenterX = rect.left + radius;

  final double topRightHalf = straight / 2;
  if (distance <= topRightHalf) {
    return Offset(rect.center.dx + distance, rect.top);
  }
  distance -= topRightHalf;

  final double semicircle = math.pi * radius;
  if (distance <= semicircle && radius > 0) {
    final double angle = -math.pi / 2 + distance / radius;
    return Offset(
      rightCenterX + radius * math.cos(angle),
      rect.center.dy + radius * math.sin(angle),
    );
  }
  distance -= semicircle;

  if (distance <= straight) {
    return Offset(rightCenterX - distance, rect.bottom);
  }
  distance -= straight;

  if (distance <= semicircle && radius > 0) {
    final double angle = math.pi / 2 + distance / radius;
    return Offset(
      leftCenterX + radius * math.cos(angle),
      rect.center.dy + radius * math.sin(angle),
    );
  }
  distance -= semicircle;

  return Offset(leftCenterX + distance.clamp(0.0, topRightHalf), rect.top);
}

/// Places circular player images wholly inside a stadium boundary. When the
/// widget is larger than its visible avatar, [visualFootprintSize] keeps the
/// avatar against the line without reserving space for transparent padding.
/// The top segment remains reserved for the dealer, while the hero stays
/// bottom-centre.
List<Offset> stadiumSeatTopLeftPositions({
  required Rect safeStadiumRect,
  required int seatCount,
  required int heroIndex,
  required double seatSize,
  double? visualFootprintSize,
  double maximumVisualScale = 1.10,
  double boundaryGap = 1.0,
  double baseReservedTopFraction = 0.40,
  double minimumReservedTopFraction = 0.35,
}) {
  if (seatCount <= 0 || seatSize <= 0 || safeStadiumRect.isEmpty) {
    return const <Offset>[];
  }

  final double footprintDiameter =
      (visualFootprintSize ?? seatSize).clamp(1.0, seatSize).toDouble();
  final double footprintRadius =
      footprintDiameter * math.max(1.0, maximumVisualScale) / 2 +
          math.max(0.0, boundaryGap);
  final Rect centerTrack = safeStadiumRect.deflate(footprintRadius);
  if (centerTrack.width <= 0 || centerTrack.height <= 0) {
    final Offset topLeft =
        safeStadiumRect.center - Offset(seatSize / 2, seatSize / 2);
    return List<Offset>.filled(seatCount, topLeft, growable: false);
  }

  final double perimeter = _horizontalStadiumPerimeter(centerTrack);
  final double requiredAvailableFraction = perimeter <= 0
      ? 1.0
      : (seatCount * seatSize * 1.10 / perimeter).clamp(0.0, 1.0);
  final double reservedTopFraction = math.max(
    minimumReservedTopFraction,
    math.min(baseReservedTopFraction, 1 - requiredAvailableFraction),
  );
  final double availableFraction = 1 - reservedTopFraction;
  final List<double> arcFractions = balancedSeatArcFractions(
    seatCount: seatCount,
    heroIndex: heroIndex,
  );

  return List<Offset>.generate(
    seatCount,
    (int index) {
      final double perimeterFraction =
          reservedTopFraction / 2 + availableFraction * arcFractions[index];
      final Offset center =
          horizontalStadiumPointAtFraction(centerTrack, perimeterFraction);
      return center - Offset(seatSize / 2, seatSize / 2);
    },
    growable: false,
  );
}
