import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ten_of_a_kind_poker/ui/art/fort_style.dart';

/// A fort drawn as a flat silhouette, for the watermark on the felt: two
/// towers, a wall and a gatehouse with its gate open, in the kingdom's
/// [style]. [seed] (see [stableArtSeed]) varies the tower and gate heights
/// so neighbouring forts are not identical.
///
/// It replaces the icon-library pictures that stood in for forts (a grill,
/// a lobster, a jeep), so every table shows a fort. Size it with the box it
/// is given: it fills [widthFraction] of the width, or less to fit the
/// height, at an aspect of 1 : 0.62.
class FortEmblem extends StatelessWidget {
  const FortEmblem({
    super.key,
    required this.style,
    this.color = const Color(0xFFFFFFFF),
    this.seed = 0,
    this.widthFraction = 0.55,
  });

  final FortStyle style;
  final Color color;
  final int seed;
  final double widthFraction;

  static const double aspect = 0.62;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double maxW = c.maxWidth.isFinite ? c.maxWidth : 400;
          final double maxH = c.maxHeight.isFinite ? c.maxHeight : 250;
          final double w =
              math.max(0.0, math.min(maxW * widthFraction, maxH * 0.8 / aspect));
          return Center(
            child: CustomPaint(
              size: Size(w, w * aspect),
              painter: FortEmblemPainter(style: style, color: color, seed: seed),
            ),
          );
        },
      ),
    );
  }
}

class FortEmblemPainter extends CustomPainter {
  const FortEmblemPainter({
    required this.style,
    required this.color,
    this.seed = 0,
  });

  final FortStyle style;
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final math.Random rng = math.Random(seed);
    final double towerJitter = (rng.nextDouble() - 0.5) * 0.06 * h;
    final double gateJitter = (rng.nextDouble() - 0.5) * 0.04 * h;

    // Shapes go on a layer so the gate and windows can be cut out of them.
    canvas.saveLayer(Offset.zero & size, Paint());
    final Paint fill = Paint()..color = color;
    final Paint cut = Paint()..blendMode = BlendMode.clear;

    if (style == FortStyle.eastern) {
      _paintEastern(canvas, w, h, fill, cut, towerJitter);
    } else {
      _paintWalled(canvas, w, h, fill, cut, towerJitter, gateJitter);
    }
    canvas.restore();
  }

  void _paintWalled(Canvas canvas, double w, double h, Paint fill, Paint cut,
      double towerJitter, double gateJitter) {
    final bool domed = style == FortStyle.domed;
    final double ground = 0.96 * h;
    final double wallTop = 0.56 * h;
    final double towerTop = 0.30 * h + towerJitter;
    final double gateTop = 0.40 * h + gateJitter;
    final double tw = 0.16 * w;
    final double piece = w / 28;
    final double crownH = piece * (domed ? 1.25 : 1.0);

    // Wall, with its crown of merlons.
    _crowned(canvas, Rect.fromLTRB(0.14 * w, wallTop, 0.86 * w, ground),
        piece, crownH, fill);
    // Towers.
    for (final double x0 in <double>[0.06 * w, 0.78 * w]) {
      _crowned(canvas, Rect.fromLTRB(x0, towerTop, x0 + tw, ground), tw / 5,
          crownH, fill);
      if (domed) _dome(canvas, x0 + tw / 2, towerTop, tw * 0.70, h * 0.09, fill);
    }
    // Gatehouse.
    final Rect house = Rect.fromLTRB(0.37 * w, gateTop, 0.63 * w, ground);
    _crowned(canvas, house, house.width / 7, crownH, fill);
    if (domed) {
      _dome(canvas, house.center.dx, gateTop, house.width * 0.46, h * 0.14, fill);
    } else {
      // A pennant on the right tower.
      final double px = 0.86 * w, py = towerTop;
      canvas.drawLine(
        Offset(px, py),
        Offset(px, py - 0.16 * h),
        Paint()
          ..color = color
          ..strokeWidth = math.max(1.0, w * 0.008),
      );
      canvas.drawPath(
        Path()
          ..moveTo(px, py - 0.16 * h)
          ..lineTo(px + 0.08 * w, py - 0.125 * h)
          ..lineTo(px, py - 0.09 * h)
          ..close(),
        fill,
      );
    }

    // The open gate.
    final double aw = 0.12 * w, ax = 0.5 * w - aw / 2, aTop = 0.68 * h;
    final Path gate = Path()
      ..moveTo(ax, ground)
      ..lineTo(ax, aTop + aw / 2);
    if (domed) {
      gate
        ..quadraticBezierTo(ax, aTop, 0.5 * w, aTop - aw * 0.18)
        ..quadraticBezierTo(ax + aw, aTop, ax + aw, aTop + aw / 2);
    } else {
      gate.arcToPoint(Offset(ax + aw, aTop + aw / 2),
          radius: Radius.circular(aw / 2), clockwise: true);
    }
    gate
      ..lineTo(ax + aw, ground)
      ..close();
    canvas.drawPath(gate, cut);

    // Arrow slits in the towers, small windows over the gate.
    final double sw = 0.018 * w, sh = 0.08 * h;
    for (final double cx in <double>[0.14 * w, 0.86 * w]) {
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, towerTop + 0.22 * h), width: sw, height: sh),
          cut);
    }
    for (final double cx in <double>[0.44 * w, 0.56 * w]) {
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, gateTop + 0.12 * h),
              width: sw,
              height: sh * 0.7),
          cut);
    }
  }

  void _paintEastern(Canvas canvas, double w, double h, Paint fill, Paint cut,
      double towerJitter) {
    final double ground = 0.96 * h;
    // Sloped stone base.
    canvas.drawPath(
      Path()
        ..moveTo(0.08 * w, ground)
        ..lineTo(0.92 * w, ground)
        ..lineTo(0.84 * w, 0.72 * h)
        ..lineTo(0.16 * w, 0.72 * h)
        ..close(),
      fill,
    );
    // The keep: three tiers, each under an upturned roof.
    final double lift = towerJitter * 0.5;
    final List<List<double>> tiers = <List<double>>[
      // left, right, bottom, top of each tier's wall (fractions)
      <double>[0.27, 0.73, 0.72, 0.56],
      <double>[0.34, 0.66, 0.50, 0.37],
      <double>[0.41, 0.59, 0.31, 0.20],
    ];
    for (final List<double> t in tiers) {
      final double top = t[3] * h + lift;
      canvas.drawRect(Rect.fromLTRB(t[0] * w, top, t[1] * w, t[2] * h + lift), fill);
      final double span = (t[1] - t[0]) * w;
      _roof(canvas, t[0] * w - span * 0.16, t[1] * w + span * 0.16,
          top - 0.07 * h, top + 0.02 * h, fill);
    }
    // Ridge ornaments on the top roof.
    final double ridge = tiers.last[3] * h + lift - 0.07 * h;
    for (final double fx in <double>[0.44 * w, 0.56 * w]) {
      canvas.drawPath(
        Path()
          ..moveTo(fx - 0.012 * w, ridge)
          ..lineTo(fx, ridge - 0.06 * h)
          ..lineTo(fx + 0.012 * w, ridge)
          ..close(),
        fill,
      );
    }
    // Corner turrets on the base.
    for (final double x0 in <double>[0.10 * w, 0.78 * w]) {
      final double top = 0.60 * h;
      canvas.drawRect(Rect.fromLTRB(x0, top, x0 + 0.12 * w, 0.74 * h), fill);
      _roof(canvas, x0 - 0.025 * w, x0 + 0.145 * w, top - 0.06 * h,
          top + 0.015 * h, fill);
    }
    // Windows on each tier, and the gate in the base.
    final double ww = 0.03 * w, wh = 0.045 * h;
    for (final List<double> t in tiers) {
      final double cy = (t[2] * h + t[3] * h) / 2 + lift + 0.01 * h;
      final double l = t[0] * w, r = t[1] * w;
      final int n = math.max(2, ((r - l) / (0.08 * w)).floor());
      for (int i = 0; i < n; i++) {
        final double cx = l + (r - l) * (i + 0.5) / n;
        canvas.drawRect(
            Rect.fromCenter(center: Offset(cx, cy), width: ww, height: wh), cut);
      }
    }
    canvas.drawRect(Rect.fromLTRB(0.45 * w, 0.80 * h, 0.55 * w, ground), cut);
  }

  /// [rect] with alternate merlons of width [piece] standing on its top.
  void _crowned(
      Canvas canvas, Rect rect, double piece, double crownH, Paint fill) {
    canvas.drawRect(Rect.fromLTRB(rect.left, rect.top + crownH, rect.right, rect.bottom), fill);
    final bool domed = style == FortStyle.domed;
    final int pieces = math.max(3, (rect.width / piece).round());
    final double pw = rect.width / pieces;
    for (int i = 0; i < pieces; i += 2) {
      final double x = rect.left + i * pw;
      if (domed) {
        final double r = pw / 2;
        canvas.drawRect(
            Rect.fromLTWH(x, rect.top + r, pw, math.max(0.0, crownH - r + 0.5)),
            fill);
        canvas.drawCircle(Offset(x + r, rect.top + r), r, fill);
      } else {
        canvas.drawRect(Rect.fromLTWH(x, rect.top, pw, crownH + 0.5), fill);
      }
    }
  }

  /// A dome of [width] and [height] sitting on [top], with a finial.
  void _dome(Canvas canvas, double cx, double top, double width, double height,
      Paint fill) {
    final double base = top - height * 0.12;
    canvas.drawRect(
        Rect.fromLTWH(cx - width * 0.56, base, width * 1.12, height * 0.14), fill);
    canvas.drawPath(
      Path()
        ..moveTo(cx - width / 2, base)
        ..quadraticBezierTo(cx - width / 2, top - height, cx, top - height * 1.08)
        ..quadraticBezierTo(cx + width / 2, top - height, cx + width / 2, base)
        ..close(),
      fill,
    );
    canvas.drawLine(
      Offset(cx, top - height * 1.08),
      Offset(cx, top - height * 1.45),
      Paint()
        ..color = color
        ..strokeWidth = math.max(1.0, width * 0.06),
    );
  }

  /// An upturned roof from [left] to [right], ridge at [top], eaves at
  /// [bottom].
  void _roof(Canvas canvas, double left, double right, double top,
      double bottom, Paint fill) {
    final double span = right - left;
    final double tip = (bottom - top) * 0.55;
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - tip)
        ..quadraticBezierTo(left + span * 0.10, bottom, left + span * 0.2, bottom)
        ..lineTo(right - span * 0.2, bottom)
        ..quadraticBezierTo(right - span * 0.10, bottom, right, bottom - tip)
        ..lineTo(right - span * 0.26, top)
        ..lineTo(left + span * 0.26, top)
        ..close(),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant FortEmblemPainter old) =>
      old.style != style || old.color != color || old.seed != seed;
}
