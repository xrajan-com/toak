import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:ten_of_a_kind_poker/ui/art/fort_style.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

/// Where a fort scene is shown.
enum FortSceneKind {
  /// The first screen: the whole fort, with its gate open.
  welcome,

  /// Behind the poker table: only the parapet above the rail and the floor
  /// below it show, so the scene is laid out around the table's rectangle.
  table,
}

/// The layout of one fort scene at one size: where the wall, towers, gate,
/// torches and sentry go. Kept apart from the painter so the welcome screen
/// can stand Renoir in the gate ([arch], [archPath]).
///
/// The art direction (docs/ART_DIRECTION.md): the world is drawn, people are
/// portraits. Dusk, with the red side (Ferrari Red, torches, sunset) on the
/// left and the blue side (Miami Blue, moonlight, a sentry) on the right,
/// the same split as the app icon.
@immutable
class FortGeometry {
  const FortGeometry._({
    required this.kind,
    required this.size,
    required this.style,
    required this.table,
    required this.unit,
    required this.wallTop,
    required this.merlonW,
    required this.merlonGap,
    required this.merlonH,
    required this.towerW,
    required this.towerTop,
    required this.gate,
    required this.arch,
    required this.archTop,
    required this.floorTop,
    required this.torches,
    required this.sentryX,
    required this.sentryH,
    required this.showMoon,
  });

  /// The whole fort, for a screen of [size]. Wide screens put the gate on
  /// the right and leave the left for text; tall ones put it at the top.
  factory FortGeometry.welcome(
    Size size, {
    FortStyle style = FortStyle.classic,
  }) {
    final double w = size.width, h = size.height;
    final bool tall = w / math.max(1, h) < 1.1;
    final double unit = math.min(w, h) / 400;
    final double mW = math.max(12.0, w / 30);
    final double mH = mW * _merlonAspect(style);
    final double gateW = (tall ? 0.58 : 0.30) * w;
    final double gateCx = (tall ? 0.50 : 0.71) * w;
    final double gateTop = (tall ? 0.17 : 0.18) * h;
    final double floorTop = (tall ? 0.60 : 0.86) * h;
    return FortGeometry._withArch(
      kind: FortSceneKind.welcome,
      size: size,
      style: style,
      table: null,
      unit: unit,
      wallTop: (tall ? 0.22 : 0.36) * h,
      merlonW: mW,
      merlonH: mH,
      towerW: (tall ? 0.15 : 0.09) * w,
      towerTop: (tall ? 0.12 : 0.16) * h,
      gateRect: Rect.fromLTWH(gateCx - gateW / 2, gateTop, gateW, h - gateTop),
      floorTop: floorTop,
      torches: tall
          ? <Offset>[Offset(0.10 * w, 0.33 * h)]
          : <Offset>[Offset(0.13 * w, 0.47 * h), Offset(0.52 * w, 0.47 * h)],
      sentryX: (tall ? 0.88 : 0.92) * w,
      sentryH: (tall ? 0.10 : 0.14) * h,
      showMoon: true,
    );
  }

  /// The fort behind a poker table drawn at [table] (in the same
  /// coordinates as [size]). The parapet sits in the band above the rail,
  /// the gate behind the dealer, and the floor under the action bar.
  factory FortGeometry.table(
    Size size, {
    required Rect table,
    FortStyle style = FortStyle.classic,
  }) {
    final double w = size.width, h = size.height;
    final double unit = math.min(w, h) / 400;
    final double band = math.max(18.0, table.top);
    final double aspect = _merlonAspect(style);
    double mW = (w / 30).clamp(12.0, 30.0).toDouble();
    double mH = mW * aspect;
    if (mH > band * 0.42) {
      mH = band * 0.42;
      mW = math.max(6.0, mH / aspect);
    }
    final double wallTop = math.max(2.0, band - mH - band * 0.22);
    final double wallBodyTop = wallTop + mH;
    final double gateW = 0.16 * w;
    final double gateTop = math.max(0.0, wallTop - mH * 1.1);
    final double torchY = wallBodyTop + band * 0.11;
    return FortGeometry._withArch(
      kind: FortSceneKind.table,
      size: size,
      style: style,
      table: table,
      unit: unit,
      wallTop: wallTop,
      merlonW: mW,
      merlonH: mH,
      towerW: 0.075 * w,
      towerTop: wallTop - band * 0.5,
      gateRect: Rect.fromLTWH(w / 2 - gateW / 2, gateTop, gateW, h - gateTop),
      floorTop: table.bottom - table.height * 0.08,
      torches: <Offset>[Offset(0.19 * w, torchY), Offset(0.355 * w, torchY)],
      sentryX: 0.66 * w,
      sentryH: wallBodyTop * 0.92,
      showMoon: false,
    );
  }

  factory FortGeometry._withArch({
    required FortSceneKind kind,
    required Size size,
    required FortStyle style,
    required Rect? table,
    required double unit,
    required double wallTop,
    required double merlonW,
    required double merlonH,
    required double towerW,
    required double towerTop,
    required Rect gateRect,
    required double floorTop,
    required List<Offset> torches,
    required double sentryX,
    required double sentryH,
    required bool showMoon,
  }) {
    final double archW = gateRect.width * 0.58;
    final double archTop = gateRect.top + merlonH + gateRect.width * 0.16;
    final double peak = style == FortStyle.domed ? archW * 0.12 : 0;
    final Rect arch = Rect.fromLTRB(
      gateRect.center.dx - archW / 2,
      archTop - peak,
      gateRect.center.dx + archW / 2,
      math.max(archTop + archW / 2, floorTop),
    );
    return FortGeometry._(
      kind: kind,
      size: size,
      style: style,
      table: table,
      unit: unit,
      wallTop: wallTop,
      merlonW: merlonW,
      merlonGap: merlonW * 0.75,
      merlonH: merlonH,
      towerW: towerW,
      towerTop: towerTop,
      gate: gateRect,
      arch: arch,
      archTop: archTop,
      floorTop: floorTop,
      torches: torches,
      sentryX: sentryX,
      sentryH: sentryH,
      showMoon: showMoon,
    );
  }

  static double _merlonAspect(FortStyle style) => switch (style) {
        FortStyle.classic => 0.95,
        FortStyle.domed => 1.15,
        FortStyle.eastern => 0.80,
      };

  final FortSceneKind kind;
  final Size size;
  final FortStyle style;
  final Rect? table;

  /// 1.0 on a screen whose short side is 400 px; sizes small details.
  final double unit;
  final double wallTop;
  final double merlonW, merlonGap, merlonH;
  final double towerW, towerTop;

  /// The gatehouse block, top at its merlon tops.
  final Rect gate;

  /// The gate's opening, from the arch's peak to the floor.
  final Rect arch;

  /// Where the arch's curve starts (below its peak on a pointed arch).
  final double archTop;
  final double floorTop;
  final List<Offset> torches;
  final double sentryX, sentryH;
  final bool showMoon;

  double get wallBodyTop => wallTop + merlonH;

  /// The gate's opening as a path in scene coordinates; shift it by
  /// `-arch.topLeft` to clip something placed at [arch].
  Path archPath() {
    final double left = arch.left, right = arch.right, bottom = arch.bottom;
    final double aw = arch.width;
    final Path p = Path()
      ..moveTo(left, bottom)
      ..lineTo(left, archTop + aw / 2);
    if (style == FortStyle.domed) {
      p
        ..quadraticBezierTo(left, archTop, arch.center.dx, arch.top)
        ..quadraticBezierTo(right, archTop, right, archTop + aw / 2);
    } else {
      p.arcToPoint(
        Offset(right, archTop + aw / 2),
        radius: Radius.circular(aw / 2),
        clockwise: true,
      );
    }
    return p
      ..lineTo(right, bottom)
      ..close();
  }

  @override
  bool operator ==(Object other) =>
      other is FortGeometry &&
      other.kind == kind &&
      other.size == size &&
      other.style == style &&
      other.table == table;

  @override
  int get hashCode => Object.hash(kind, size, style, table);
}

/// The fort at dusk, drawn in code: sky, wall, towers, an open gate, banners
/// in [bannerColors] (left of the gate, then right; one colour serves both),
/// torches on the red side and a sentry on the blue side. Static: it paints
/// once per size, so it costs nothing while the game runs.
class FortBackdrop extends StatelessWidget {
  const FortBackdrop({
    super.key,
    required this.geometry,
    this.bannerColors = const <Color>[],
  });

  final FortGeometry geometry;
  final List<Color> bannerColors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: geometry.size,
          isComplex: true,
          painter: FortBackdropPainter(
            geometry: geometry,
            bannerColors: bannerColors,
          ),
        ),
      ),
    );
  }
}

class FortBackdropPainter extends CustomPainter {
  const FortBackdropPainter({
    required this.geometry,
    this.bannerColors = const <Color>[],
  });

  final FortGeometry geometry;
  final List<Color> bannerColors;

  // Stone: warm where the torches and sunset reach, cool under the moon.
  static const Color _stoneWarm = Color(0xFF33170F);
  static const Color _stoneMid = Color(0xFF1A0F0C);
  static const Color _stoneCool = Color(0xFF0B151A);
  static const Color _silhouette = Color(0xFF040A0D);
  static const Color _torchGlow = Color(0x8CFFAA46);
  static const Color _torchGlowMid = Color(0x38FF6E1E);
  static const Color _torchGlowEdge = Color(0x00FF5A14);

  @override
  void paint(Canvas canvas, Size size) {
    final FortGeometry g = geometry;
    final double w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final double u = g.unit;
    final double big = math.max(w, h);
    final Rect full = Offset.zero & size;

    // 1. Sky: night above, the sunset on the red (left) side, moonlight on
    //    the blue (right) side.
    canvas.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          const <Color>[Color(0xFF02080C), Color(0xFF061820), Color(0xFF0B2630)],
          const <double>[0, 0.45, 1],
        ),
    );
    canvas.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(0, h * 0.62),
          big * 0.85,
          <Color>[
            AppColors.red.withValues(alpha: 0.62),
            const Color(0x4DFF6E1E),
            const Color(0x0FFF6E1E),
            const Color(0x00000000),
          ],
          const <double>[0, 0.28, 0.62, 1],
        ),
    );
    canvas.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w, h * 0.18),
          big * 0.65,
          <Color>[
            AppColors.blue.withValues(alpha: 0.30),
            AppColors.blue.withValues(alpha: 0.08),
            const Color(0x00000000),
          ],
          const <double>[0, 0.5, 1],
        ),
    );

    // 2. Stars over the blue side.
    final math.Random rng = math.Random(7);
    final Paint star = Paint();
    for (int i = 0; i < 46; i++) {
      final double x = w * (0.42 + rng.nextDouble() * 0.58);
      final double y = g.wallTop * rng.nextDouble() * 0.95;
      star.color =
          Color.fromRGBO(220, 245, 255, 0.25 + rng.nextDouble() * 0.55);
      canvas.drawCircle(Offset(x, y), (0.5 + rng.nextDouble()) * u, star);
    }

    // 3. The moon.
    if (g.showMoon) {
      final bool tall = w / h < 1.1;
      final Offset moon = Offset(w * 0.88, h * (tall ? 0.08 : 0.12));
      final double r = 14 * u;
      canvas.drawCircle(
        moon,
        r * 5,
        Paint()
          ..shader = ui.Gradient.radial(moon, r * 5, <Color>[
            AppColors.blue.withValues(alpha: 0.35),
            const Color(0x00000000),
          ]),
      );
      canvas.drawCircle(moon, r, Paint()..color = const Color(0xFFE8FBFF));
    }

    // 4. The wall: merlons (or a roof) along the top, stone courses below.
    final Paint stone = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(w, 0),
        const <Color>[_stoneWarm, _stoneMid, _stoneCool],
        const <double>[0, 0.42, 1],
      );
    final double bodyTop = g.wallBodyTop;
    final Path wall = Path();
    if (g.style == FortStyle.eastern) {
      _addRoof(wall, -w * 0.05, w * 1.05, g.wallTop, bodyTop);
    } else {
      for (double x = -g.merlonGap * 0.5;
          x < w + g.merlonW;
          x += g.merlonW + g.merlonGap) {
        _addMerlon(wall, x, g.wallTop, g.merlonW, g.merlonH);
      }
    }
    wall.addRect(Rect.fromLTWH(0, bodyTop - 0.5, w, h - bodyTop + 0.5));
    canvas.drawPath(wall, stone);
    canvas.drawRect(
      Rect.fromLTWH(0, bodyTop, w, h - bodyTop),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, bodyTop),
          Offset(0, h),
          const <Color>[Color(0x00000000), Color(0x8C000000)],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, bodyTop, w, math.max(1.5, 3 * u)),
      Paint()..color = const Color(0x1AFFBE8C),
    );
    final Paint joint = Paint()
      ..color = const Color(0x59000000)
      ..strokeWidth = math.max(1.0, 1.1 * u);
    final double course = 19.2 * u;
    int row = 0;
    for (double y = bodyTop + course; y < h; y += course, row++) {
      canvas.drawLine(Offset(0, y), Offset(w, y), joint);
      final double block = course * 2.4;
      for (double x = (row.isOdd ? block / 2 : 0); x < w; x += block) {
        canvas.drawLine(Offset(x, y - course), Offset(x, y), joint);
      }
    }

    // 5. A tower at each edge.
    for (final bool left in <bool>[true, false]) {
      final double x0 = left ? 0 : w - g.towerW;
      final Paint towerPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x0, 0),
          Offset(x0 + g.towerW, 0),
          left
              ? const <Color>[Color(0xFF3A1A10), Color(0xFF22120D)]
              : const <Color>[Color(0xFF0D1A20), Color(0xFF081115)],
        );
      final Path tower = Path()
        ..addRect(Rect.fromLTWH(x0, g.towerTop + g.merlonH, g.towerW, h));
      _addCrown(tower, x0, g.towerW, g.towerTop, g.merlonH, pieces: 5);
      canvas.drawPath(tower, towerPaint);
      if (g.style == FortStyle.domed) {
        _drawDome(canvas, x0 + g.towerW / 2, g.towerTop, g.towerW, towerPaint);
      }
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x0 + g.towerW / 2, g.towerTop + g.merlonH + 33 * u),
          width: 4 * u,
          height: 14 * u,
        ),
        Paint()
          ..color = left
              ? const Color(0xD9FF963C)
              : AppColors.blue.withValues(alpha: 0.55),
      );
    }

    // 6. The gatehouse and its open gate, lit from inside.
    final Rect gate = g.gate;
    final Path house = Path()
      ..addRect(Rect.fromLTWH(
        gate.left,
        gate.top + g.merlonH,
        gate.width,
        h - gate.top - g.merlonH,
      ));
    _addCrown(house, gate.left, gate.width, gate.top, g.merlonH, pieces: 7);
    final Paint housePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(gate.left, 0),
        Offset(gate.right, 0),
        const <Color>[Color(0xFF2A140E), Color(0xFF0E1519)],
      );
    canvas.drawPath(house, housePaint);
    final Path arch = g.archPath();
    canvas.drawPath(arch, Paint()..color = const Color(0xFF050302));
    canvas.save();
    canvas.clipPath(arch);
    canvas.drawRect(
      g.arch,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(g.arch.center.dx, g.arch.bottom),
          g.arch.width * 1.1,
          const <Color>[Color(0x47FF7828), Color(0x00000000)],
        ),
    );
    canvas.restore();
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * u
        ..color = const Color(0x24FFC896),
    );

    // 7. Banners in the kingdom's colours, either side of the gate.
    if (bannerColors.isNotEmpty) {
      final double bw = math.min(26 * u, gate.width * 0.17);
      final double bh = bw * 2.7;
      final double top = gate.top + g.merlonH + 2 * u;
      final List<double> xs = <double>[
        gate.center.dx - gate.width * 0.39,
        gate.center.dx + gate.width * 0.39,
      ];
      for (int i = 0; i < xs.length; i++) {
        _drawBanner(canvas, xs[i], top, bw, bh, u,
            bannerColors[i % bannerColors.length]);
      }
    }

    // 8. A sentry with a spear on the blue side, rim-lit by the moon.
    if (g.sentryH > 8) _drawSentry(canvas, g.sentryX, bodyTop, g.sentryH);

    // 9. Torches on the red side.
    for (final Offset t in g.torches) {
      _drawTorch(canvas, t, u);
    }

    // 10. The floor.
    final double fy = g.floorTop;
    if (fy < h) {
      canvas.drawRect(
        Rect.fromLTWH(0, fy, w, h - fy),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, fy),
            Offset(0, h),
            const <Color>[Color(0xFF120C0A), Color(0xFF060404)],
          ),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, fy, w, math.max(1.0, 2 * u)),
        Paint()..color = const Color(0x14FFBE8C),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, fy, w, h - fy),
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(w * 0.2, fy),
            w * 0.5,
            const <Color>[Color(0x29FF7828), Color(0x00000000)],
          ),
      );
    }

    // 11. Vignette.
    canvas.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w / 2, h / 2),
          big * 0.75,
          const <Color>[Color(0x00000000), Color(0x00000000), Color(0x8C000000)],
          const <double>[0, 0.35, 1],
        ),
    );
  }

  /// One merlon (or a rounded kangura on domed forts) at [x].
  void _addMerlon(Path path, double x, double top, double mw, double mh) {
    if (geometry.style == FortStyle.domed) {
      final double r = mw / 2;
      path
        ..addRect(Rect.fromLTWH(x, top + r, mw, math.max(0.0, mh - r)))
        ..addOval(Rect.fromCircle(center: Offset(x + r, top + r), radius: r));
    } else {
      path.addRect(Rect.fromLTWH(x, top, mw, mh));
    }
  }

  /// The top of a tower or gatehouse: alternate merlons across [width], or
  /// a roof on eastern forts.
  void _addCrown(
    Path path,
    double x0,
    double width,
    double top,
    double mh, {
    required int pieces,
  }) {
    if (geometry.style == FortStyle.eastern) {
      _addRoof(path, x0 - width * 0.16, x0 + width * 1.16, top, top + mh);
      return;
    }
    final double piece = width / pieces;
    for (int i = 0; i < pieces; i += 2) {
      _addMerlon(path, x0 + i * piece, top, piece, mh);
    }
  }

  /// A tiled roof from [left] to [right] whose ridge is at [top] and eaves
  /// at [bottom], with the eave tips turned up.
  void _addRoof(Path path, double left, double right, double top, double bottom) {
    final double span = right - left;
    final double lift = (bottom - top) * 0.45;
    path
      ..moveTo(left, bottom - lift)
      ..quadraticBezierTo(left + span * 0.08, bottom, left + span * 0.16, bottom)
      ..lineTo(right - span * 0.16, bottom)
      ..quadraticBezierTo(right - span * 0.08, bottom, right, bottom - lift)
      ..lineTo(right - span * 0.22, top)
      ..lineTo(left + span * 0.22, top)
      ..close();
  }

  /// A domed pavilion (chhatri) on top of a tower.
  void _drawDome(Canvas canvas, double cx, double top, double towerW, Paint p) {
    final double dw = towerW * 0.62, dh = towerW * 0.42;
    final Path dome = Path()
      ..addRect(Rect.fromLTWH(cx - dw * 0.62, top - dh * 0.18, dw * 1.24, dh * 0.18))
      ..moveTo(cx - dw / 2, top - dh * 0.18)
      ..quadraticBezierTo(cx - dw / 2, top - dh * 1.25, cx, top - dh * 1.35)
      ..quadraticBezierTo(cx + dw / 2, top - dh * 1.25, cx + dw / 2, top - dh * 0.18)
      ..close();
    canvas.drawPath(dome, p);
    canvas.drawLine(
      Offset(cx, top - dh * 1.35),
      Offset(cx, top - dh * 1.75),
      Paint()
        ..color = const Color(0xFF22120D)
        ..strokeWidth = math.max(1.0, towerW * 0.04),
    );
  }

  void _drawBanner(Canvas canvas, double x, double top, double bw, double bh,
      double u, Color color) {
    final Path banner = Path()
      ..moveTo(x - bw / 2, top)
      ..lineTo(x + bw / 2, top)
      ..lineTo(x + bw / 2, top + bh)
      ..lineTo(x, top + bh - bw * 0.46)
      ..lineTo(x - bw / 2, top + bh)
      ..close();
    canvas.drawPath(
      banner,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x - bw / 2, 0),
          Offset(x + bw / 2, 0),
          <Color>[
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.45),
          ],
          const <double>[0, 0.5, 1],
        ),
    );
    canvas.drawPath(
      banner,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, top + bh),
          const <Color>[Color(0x00000000), Color(0x73000000)],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(x - bw / 2 - 3 * u, top - 2 * u, bw + 6 * u, 3 * u),
      Paint()..color = const Color(0xFF1B1210),
    );
    final double s = bw * 0.23, cy = top + bh * 0.42;
    final Paint mark = Paint()
      ..color = const Color(0xD9FFFFFF)
      ..strokeWidth = bw * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x - s, cy - s), Offset(x + s, cy + s), mark);
    canvas.drawLine(Offset(x + s, cy - s), Offset(x - s, cy + s), mark);
  }

  /// A soldier with helmet, shield and spear, feet on [base], [height] tall.
  void _drawSentry(Canvas canvas, double x, double base, double height) {
    final double s = height / 100;
    canvas.save();
    canvas.translate(x, base - height);
    final Path body = Path()
      ..moveTo(-7 * s, 14 * s)
      ..arcToPoint(Offset(7 * s, 14 * s),
          radius: Radius.circular(7 * s), clockwise: true)
      ..lineTo(9 * s, 16 * s)
      ..lineTo(-9 * s, 16 * s)
      ..close()
      ..addRect(Rect.fromLTWH(-5 * s, 16 * s, 10 * s, 6 * s))
      ..moveTo(-12 * s, 24 * s)
      ..lineTo(12 * s, 24 * s)
      ..lineTo(9 * s, 58 * s)
      ..lineTo(-9 * s, 58 * s)
      ..close()
      ..addRect(Rect.fromLTWH(-8 * s, 58 * s, 6.5 * s, 42 * s))
      ..addRect(Rect.fromLTWH(1.5 * s, 58 * s, 6.5 * s, 42 * s))
      ..moveTo(-20 * s, 30 * s)
      ..lineTo(-8 * s, 30 * s)
      ..lineTo(-9 * s, 52 * s)
      ..quadraticBezierTo(-14 * s, 60 * s, -19 * s, 52 * s)
      ..close();
    final Paint dark = Paint()..color = _silhouette;
    canvas.drawPath(body, dark);
    canvas.drawLine(
      Offset(14 * s, 100 * s),
      Offset(14 * s, -8 * s),
      Paint()
        ..color = _silhouette
        ..strokeWidth = 2.2 * s,
    );
    canvas.drawPath(
      Path()
        ..moveTo(14 * s, -20 * s)
        ..lineTo(17.5 * s, -8 * s)
        ..lineTo(10.5 * s, -8 * s)
        ..close(),
      dark,
    );
    final Paint rim = Paint()
      ..color = AppColors.blue.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, 1.2 * s);
    canvas.drawLine(Offset(12 * s, 24 * s), Offset(9 * s, 58 * s), rim);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, 14 * s), radius: 7 * s),
      -math.pi / 2,
      math.pi / 2,
      false,
      rim,
    );
    canvas.drawLine(Offset(15.2 * s, 98 * s), Offset(15.2 * s, -8 * s), rim);
    canvas.restore();
  }

  void _drawTorch(Canvas canvas, Offset at, double u) {
    final double x = at.dx, y = at.dy;
    final double glowR = 70 * u;
    canvas.drawCircle(
      at,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(
          at,
          glowR,
          const <Color>[_torchGlow, _torchGlowMid, _torchGlowEdge],
          const <double>[0, 0.35, 1],
        ),
    );
    final Paint iron = Paint()..color = const Color(0xFF0E0806);
    canvas.drawRect(Rect.fromLTWH(x - 2.2 * u, y + 4 * u, 4.4 * u, 16 * u), iron);
    canvas.drawRect(Rect.fromLTWH(x - 6 * u, y + 3 * u, 12 * u, 3 * u), iron);
    final double fh = 16 * u, fw = 7 * u;
    final Path flame = Path()
      ..moveTo(x, y - fh)
      ..quadraticBezierTo(x + fw, y - fh * 0.2, x, y + 3 * u)
      ..quadraticBezierTo(x - fw, y - fh * 0.2, x, y - fh)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, y - fh),
          Offset(x, y + 3 * u),
          const <Color>[Color(0xF2FFF0AA), Color(0xF2FFA028), Color(0xE6FF5A14)],
          const <double>[0, 0.5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant FortBackdropPainter old) =>
      old.geometry != geometry || !_sameColors(old.bannerColors, bannerColors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
