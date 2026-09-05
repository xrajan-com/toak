// lib/ui/screens/game_screen/table_felt.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

/*───────────────────────────────────────────────
 🪵 Wood Palette Definitions
───────────────────────────────────────────────*/
class WoodPalette {
  final Color light, mid, dark, pore;
  const WoodPalette(this.light, this.mid, this.dark, this.pore);
}

enum WoodType { redwood, ebony, teak, walnut }

extension WoodTypeX on WoodType {
  WoodPalette get palette {
    switch (this) {
      case WoodType.redwood:
        return const WoodPalette(
          Color(0xFF5A241C),
          Color(0xFF3E140F),
          Color(0xFF2C0E0B),
          Color(0xFF6C3A33),
        );
      case WoodType.ebony:
        return const WoodPalette(
          Color(0xFF2A2A2A),
          Color(0xFF1E1E1E),
          Color(0xFF121212),
          Color(0xFF3A3A3A),
        );
      case WoodType.teak:
        return const WoodPalette(
          Color(0xFF8B6B3E),
          Color(0xFF6E4F2E),
          Color(0xFF50381E),
          Color(0xFF9C7A4B),
        );
      case WoodType.walnut:
        return const WoodPalette(
          Color(0xFF7A4A2A),
          Color(0xFF5C3620),
          Color(0xFF3E2416),
          Color(0xFF8A5834),
        );
    }
  }
}

/*───────────────────────────────────────────────
 👑 Kingdom Watermarks
───────────────────────────────────────────────*/
enum KingdomMark {
  baroda,
  jaipur,
  hyderabad,
  indore,
  travancore,
  sikhEmpire,
  newDelhi,
  mysore,
  marathaEmpire,
  sikkim,
}

extension KingdomMarkX on KingdomMark {
  String get assetPath {
    final snake = name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => '_${m[1]!.toLowerCase()}',
    );
    return 'assets/images/watermarks/$snake.svg';
  }
}

String _normaliseAssetPath(String raw) {
  String p = raw.trim().replaceFirst(RegExp(r'^(assets/)+'), 'assets/');
  return p.replaceFirst(
    RegExp(r'^assets/images/monuments/'),
    'assets/images/watermarks/',
  );
}

Future<bool> _assetLoadable(String asset) async {
  try {
    await rootBundle.load(asset);
    return true;
  } catch (_) {
    return false;
  }
}

/*───────────────────────────────────────────────
 🏛️ Venue → Monument Map
───────────────────────────────────────────────*/
const Map<String, String> _monumentForVenue = {
  // India
  'Baroda': 'assets/images/watermarks/baroda.svg',
  'New Delhi': 'assets/images/watermarks/new_delhi.svg',
  'Hyderabad': 'assets/images/watermarks/hyderabad.svg',
  'Indore': 'assets/images/watermarks/indore.svg',
  'Jaipur': 'assets/images/watermarks/jaipur.svg',
  'Maratha Empire': 'assets/images/watermarks/maratha_empire.svg',
  'Mysore': 'assets/images/watermarks/mysore.svg',
  'Sikh Empire': 'assets/images/watermarks/sikh_empire.svg',
  'Sikkim': 'assets/images/watermarks/sikkim.svg',
  'Travancore': 'assets/images/watermarks/travancore.svg',
  // International
  'India': 'assets/images/watermarks/india.svg',
  'China': 'assets/images/watermarks/china.svg',
  'America': 'assets/images/watermarks/america.svg',
  'N. America': 'assets/images/watermarks/n_america.svg',
  'Australia': 'assets/images/watermarks/australia.svg',
  'Russia': 'assets/images/watermarks/russia.svg',
  'Arabia': 'assets/images/watermarks/arabia.svg',
  'Persia': 'assets/images/watermarks/persia.svg',
  'Africa': 'assets/images/watermarks/africa.svg',
  'Amazon': 'assets/images/watermarks/amazon.svg',
  'S. America': 'assets/images/watermarks/s_america.svg',
  'Europe': 'assets/images/watermarks/europe.svg',
  'European Marches': 'assets/images/watermarks/europe.svg',
  'Far East': 'assets/images/watermarks/far_east.svg',
  'Asia Rest': 'assets/images/watermarks/asia_rest.svg',
  'Central Asia': 'assets/images/watermarks/central_asia.svg',
  'Asia': 'assets/images/watermarks/southeast.svg',
  // Backward-compat alias.
  'Southeast': 'assets/images/watermarks/southeast.svg',
  // Euro
  'Britain': 'assets/images/watermarks/britain.svg',
  'France': 'assets/images/watermarks/france.svg',
  'Italy': 'assets/images/watermarks/italy.svg',
  'Spain': 'assets/images/watermarks/spain.svg',
  'Portugal': 'assets/images/watermarks/portugal.svg',
  'North Sea': 'assets/images/watermarks/north_sea.svg',
  'Scandinavia': 'assets/images/watermarks/scandinavia.svg',
  'Baltic Marches': 'assets/images/watermarks/baltic_marches.svg',
  'Russia & Siberia': 'assets/images/watermarks/russia_siberia.svg',
  'Mediterranean': 'assets/images/watermarks/mediterranean.svg',
  // Oceania
  'Alaska': 'assets/images/watermarks/alaska.svg',
  'Caribbean': 'assets/images/watermarks/caribbean.svg',
  'Dragonland': 'assets/images/watermarks/dragonland.svg',
  'Straits': 'assets/images/watermarks/straits.svg',
  'Indian Ocean': 'assets/images/watermarks/indian_ocean.svg',
  'Pacific': 'assets/images/watermarks/pacific.svg',
  'British Isles': 'assets/images/watermarks/british_isles.svg',
  'French Isles': 'assets/images/watermarks/french_isles.svg',
  'Dutch Isles': 'assets/images/watermarks/dutch_isles.svg',
  'American Isles': 'assets/images/watermarks/american_isles.svg',
  // North American circuit
  'Dominion of Canada': 'assets/images/watermarks/n_america.svg',
  'Massachusetts': 'assets/images/watermarks/n_america.svg',
  'New York': 'assets/images/watermarks/n_america.svg',
  'Virginia': 'assets/images/watermarks/n_america.svg',
  'Illinois': 'assets/images/watermarks/n_america.svg',
  'Florida': 'assets/images/watermarks/n_america.svg',
  'Texas': 'assets/images/watermarks/n_america.svg',
  'Kansas': 'assets/images/watermarks/n_america.svg',
  'Colorado': 'assets/images/watermarks/n_america.svg',
  'California': 'assets/images/watermarks/n_america.svg',
  // Final five-circuit catalog.
  'Britain & Ireland': 'assets/images/watermarks/britain.svg',
  'Iberia': 'assets/images/watermarks/spain.svg',
  'Low Countries': 'assets/images/watermarks/north_sea.svg',
  'Central Europe': 'assets/images/watermarks/europe.svg',
  'Balkans & Mediterranean': 'assets/images/watermarks/mediterranean.svg',
  'Canada': 'assets/images/watermarks/n_america.svg',
  'Northeast USA': 'assets/images/watermarks/n_america.svg',
  'Atlantic USA': 'assets/images/watermarks/n_america.svg',
  'Southern USA': 'assets/images/watermarks/n_america.svg',
  'Western USA': 'assets/images/watermarks/n_america.svg',
  'Mexico & Central America': 'assets/images/watermarks/n_america.svg',
  'Brazil': 'assets/images/watermarks/s_america.svg',
  'Andes': 'assets/images/watermarks/s_america.svg',
  'Southern Cone': 'assets/images/watermarks/s_america.svg',
  'Japan': 'assets/images/watermarks/far_east.svg',
  'Korea': 'assets/images/watermarks/far_east.svg',
  'Taiwan': 'assets/images/watermarks/dragonland.svg',
  'Vietnam': 'assets/images/watermarks/asia_rest.svg',
  'Mekong': 'assets/images/watermarks/southeast.svg',
  'Philippines': 'assets/images/watermarks/american_isles.svg',
  'Indonesia': 'assets/images/watermarks/straits.svg',
  'North Africa': 'assets/images/watermarks/africa.svg',
  'Sub-Saharan Africa': 'assets/images/watermarks/africa.svg',
  'Persia & Mesopotamia': 'assets/images/watermarks/persia.svg',
  'Indian Ocean Isles': 'assets/images/watermarks/indian_ocean.svg',
  'Atlantic Isles': 'assets/images/watermarks/british_isles.svg',
  'French & Dutch Isles': 'assets/images/watermarks/dutch_isles.svg',
  'Arctic': 'assets/images/watermarks/alaska.svg',
};

String _toSnake(String s) =>
    s.trim().replaceAll(RegExp(r'\s+|-'), '_').toLowerCase();

String? monumentPathForVenue(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  return _monumentForVenue[name.trim()] ??
      'assets/images/watermarks/${_toSnake(name)}.svg';
}

/*───────────────────────────────────────────────
 🧭 Geometry Helpers
───────────────────────────────────────────────*/
Path _stadiumPath(Rect r) =>
    Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(r.height / 2)));

const double kInnerFeltBandStrokeWidth = 1.4;

double innerFeltBandInsetForRail(double railWidth) =>
    math.max(6.0, railWidth * 0.18);

Rect innerFeltBandRect(Size size, double railWidth) {
  final Rect tableRect = Offset.zero & size;
  final Rect feltRect = tableRect.deflate(math.max(0.0, railWidth));
  return feltRect.deflate(innerFeltBandInsetForRail(railWidth));
}

/// Hard boundary for player avatars and settled hole cards. The extra
/// half-stroke guard keeps pixels off the visible inset line itself.
RRect playerSafeFeltRRect(
  Size size,
  double railWidth, {
  double extraGuard = kInnerFeltBandStrokeWidth / 2,
}) {
  final Rect safeRect =
      innerFeltBandRect(size, railWidth).deflate(math.max(0.0, extraGuard));
  return RRect.fromRectAndRadius(
    safeRect,
    Radius.circular(math.max(0.0, safeRect.height / 2)),
  );
}

class PlayerSafeFeltClipper extends CustomClipper<Path> {
  const PlayerSafeFeltClipper({
    required this.railWidth,
    this.extraGuard = kInnerFeltBandStrokeWidth / 2,
  });

  final double railWidth;
  final double extraGuard;

  @override
  Path getClip(Size size) => Path()
    ..addRRect(
      playerSafeFeltRRect(
        size,
        railWidth,
        extraGuard: extraGuard,
      ),
    );

  @override
  bool shouldReclip(covariant PlayerSafeFeltClipper oldClipper) =>
      railWidth != oldClipper.railWidth || extraGuard != oldClipper.extraGuard;
}

/*───────────────────────────────────────────────
 🎨 Table Painter
───────────────────────────────────────────────*/
class RacetrackTablePainter extends CustomPainter {
  final Color felt;
  final WoodType wood;
  final double railWidth;
  final double lipHighlight;

  const RacetrackTablePainter({
    required this.felt,
    required this.wood,
    this.railWidth = 34,
    this.lipHighlight = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final innerRect = rect.deflate(railWidth);
    final innerInsetRect = innerFeltBandRect(size, railWidth);

    final outer = _stadiumPath(rect);
    final inner = _stadiumPath(innerRect);
    final innerInset = _stadiumPath(innerInsetRect);
    final railPath = Path.combine(PathOperation.difference, outer, inner);
    final pal = wood.palette;

    final Color feltEdge = Color.lerp(felt, Colors.black, 0.24)!;
    final Color feltCenter = Color.lerp(felt, Colors.white, 0.06)!;

    // 🌲 Wood rail
    final railShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(pal.light, Colors.white, 0.06)!,
        pal.light,
        pal.mid,
        pal.dark,
      ],
      stops: const [0.0, 0.22, 0.58, 1.0],
    ).createShader(rect);
    final railPaint = Paint()..shader = railShader;
    final porePaint = Paint()
      ..color = pal.pore
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final railGlossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.28, 0.62],
      ).createShader(
        Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.46),
      );

    // 🕳️ Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.52)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 24);
    final railDropShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    // 🟢 Felt
    final feltPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.12),
        radius: 1.15,
        colors: [feltCenter.withValues(alpha: 0.96), felt, feltEdge],
        stops: const [0.0, 0.56, 1.0],
      ).createShader(innerRect);
    final innerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.2, railWidth * 0.085)
      ..color = Colors.white.withValues(alpha: 0.12);
    final feltBandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kInnerFeltBandStrokeWidth
      ..color = Colors.white.withValues(alpha: 0.08);
    final feltShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(6.0, railWidth * 0.22)
      ..color = Colors.black.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // 💡 Lip + Stripe
    final lipPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lipHighlight
      ..color = Colors.white.withValues(alpha: 0.12);
    final stripePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.09);

    // Draw sequence
    canvas.drawPath(outer, shadowPaint);
    canvas.drawPath(railPath, railDropShadowPaint);
    canvas.drawPath(railPath, railPaint);
    canvas.drawPath(railPath, railGlossPaint);
    canvas.drawPath(railPath, porePaint);
    canvas.drawPath(inner, feltPaint);
    canvas.drawPath(inner, feltShadowPaint);
    canvas.drawPath(inner, innerRimPaint);
    canvas.drawPath(innerInset, feltBandPaint);
    if (lipHighlight > 0) {
      canvas.drawPath(inner, lipPaint);
      canvas.drawPath(_stadiumPath(innerRect.deflate(16)), stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant RacetrackTablePainter old) =>
      felt != old.felt ||
      wood != old.wood ||
      railWidth != old.railWidth ||
      lipHighlight != old.lipHighlight;
}

/*───────────────────────────────────────────────
 🧩 TableFelt Widget
───────────────────────────────────────────────*/
class TableFelt extends StatelessWidget {
  final double width, height;
  final Color felt;
  final WoodType wood;
  final double railWidth;
  final Widget child;
  final Widget? bottomRailChild;
  final double bottomRailYOffset;
  final String? watermarkPngAsset, watermarkSvgAsset;
  final KingdomMark? watermarkKingdom;
  final String? monumentVenueName;
  final bool tintWhite;
  final double watermarkWidth, watermarkOpacity, watermarkRotationDeg;
  final Alignment watermarkAlignment;
  final Color? watermarkColor;
  final EdgeInsets watermarkPadding;
  final String? edgeMarkAsset;
  final double edgeMarkSize;
  final Alignment edgeMarkAlignment;
  final EdgeInsets edgeMarkNudge;

  const TableFelt({
    super.key,
    required this.width,
    required this.height,
    required this.felt,
    required this.wood,
    required this.child,
    this.railWidth = 34,
    this.bottomRailChild,
    this.bottomRailYOffset = 0.0,
    this.watermarkPngAsset,
    this.watermarkSvgAsset,
    this.watermarkKingdom,
    this.monumentVenueName,
    this.tintWhite = false,
    this.watermarkWidth = 520,
    this.watermarkOpacity = 0.5,
    this.watermarkAlignment = Alignment.center,
    this.watermarkColor,
    this.watermarkRotationDeg = 0.0,
    this.watermarkPadding = EdgeInsets.zero,
    this.edgeMarkAsset,
    this.edgeMarkSize = 36,
    this.edgeMarkAlignment = Alignment.topCenter,
    this.edgeMarkNudge = EdgeInsets.zero,
  }) : assert(
          ((watermarkPngAsset != null) ? 1 : 0) +
                  ((watermarkSvgAsset != null) ? 1 : 0) +
                  ((watermarkKingdom != null) ? 1 : 0) +
                  ((monumentVenueName != null) ? 1 : 0) <=
              1,
          'Provide at most one watermark source',
        );

  @override
  Widget build(BuildContext context) {
    final resolvedSvg = watermarkSvgAsset ??
        watermarkKingdom?.assetPath ??
        monumentPathForVenue(monumentVenueName);

    final feltRect = Rect.fromLTWH(
      railWidth,
      railWidth,
      width - railWidth * 2,
      height - railWidth * 2,
    );

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: RacetrackTablePainter(
                felt: felt, wood: wood, railWidth: railWidth),
          ),
          if (edgeMarkAsset != null)
            _EdgeMark(
              asset: edgeMarkAsset!,
              size: edgeMarkSize,
              railWidth: railWidth,
              alignment: edgeMarkAlignment,
              nudge: edgeMarkNudge,
            ),
          Positioned.fromRect(
            rect: feltRect,
            child: ClipPath(
              clipper: const _StadiumClipper(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (watermarkPngAsset != null || resolvedSvg != null)
                    Padding(
                      padding: watermarkPadding + EdgeInsets.all(railWidth),
                      child: _SafeWatermark(
                        pngAsset: watermarkPngAsset,
                        svgAsset: resolvedSvg,
                        width: watermarkWidth,
                        opacity: watermarkOpacity,
                        alignment: watermarkAlignment,
                        color: watermarkColor,
                        tintWhite: tintWhite,
                        rotationDeg: watermarkRotationDeg,
                      ),
                    ),
                  child,
                ],
              ),
            ),
          ),
          if (bottomRailChild != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: (railWidth * 0.25) + bottomRailYOffset,
              child: Center(child: bottomRailChild),
            ),
        ],
      ),
    );
  }
}

/*───────────────────────────────────────────────
 🖼️ Helpers
───────────────────────────────────────────────*/
class _SafeWatermark extends StatefulWidget {
  final String? pngAsset, svgAsset;
  final double width, opacity, rotationDeg;
  final Alignment alignment;
  final Color? color;
  final bool tintWhite;

  const _SafeWatermark({
    this.pngAsset,
    this.svgAsset,
    required this.width,
    required this.opacity,
    required this.alignment,
    this.color,
    this.tintWhite = false,
    this.rotationDeg = 0.0,
  });

  @override
  State<_SafeWatermark> createState() => _SafeWatermarkState();
}

class _SafeWatermarkState extends State<_SafeWatermark> {
  String? _rawAsset;
  String? _normalisedAsset;
  Future<bool>? _existsFuture;

  @override
  void initState() {
    super.initState();
    _prepareAsset();
  }

  @override
  void didUpdateWidget(covariant _SafeWatermark oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? nextRaw = widget.svgAsset ?? widget.pngAsset;
    if (nextRaw != _rawAsset) {
      _prepareAsset();
    }
  }

  void _prepareAsset() {
    final raw = widget.svgAsset ?? widget.pngAsset;
    _rawAsset = raw;
    if (raw == null || raw.trim().isEmpty) {
      _normalisedAsset = null;
      _existsFuture = null;
      return;
    }
    _normalisedAsset = _normaliseAssetPath(raw);
    _existsFuture = _assetLoadable(_normalisedAsset!);
  }

  @override
  Widget build(BuildContext context) {
    final asset = _normalisedAsset;
    final future = _existsFuture;
    if (asset == null || future == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<bool>(
      future: future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done || snap.data != true) {
          return const SizedBox.shrink();
        }

        Widget wm;
        if (asset.toLowerCase().endsWith('.svg')) {
          wm = SvgPicture.asset(
            asset,
            width: widget.width,
            fit: BoxFit.contain,
            allowDrawingOutsideViewBox: true,
            colorFilter: widget.color != null
                ? ColorFilter.mode(widget.color!, BlendMode.srcIn)
                : null,
          );
        } else {
          wm = Image.asset(
            asset,
            width: widget.width,
            fit: BoxFit.contain,
            color: widget.tintWhite ? Colors.white : null,
            colorBlendMode: widget.tintWhite ? BlendMode.srcIn : null,
          );
        }

        if (widget.rotationDeg.abs() > 0.01) {
          wm = Transform.rotate(
            angle: widget.rotationDeg * math.pi / 180,
            child: wm,
          );
        }

        return IgnorePointer(
          child: Align(
            alignment: widget.alignment,
            child: Opacity(opacity: widget.opacity, child: wm),
          ),
        );
      },
    );
  }
}

class _EdgeMark extends StatelessWidget {
  final String asset;
  final double size, railWidth;
  final Alignment alignment;
  final EdgeInsets nudge;

  const _EdgeMark({
    required this.asset,
    required this.size,
    required this.railWidth,
    required this.alignment,
    required this.nudge,
  });

  @override
  Widget build(BuildContext context) {
    final offset = (railWidth / 2) - (size / 2);
    final pad = EdgeInsets.only(
      right: alignment.x > 0 ? -offset : 0,
      left: alignment.x < 0 ? -offset : 0,
      bottom: alignment.y > 0 ? -offset : 0,
      top: alignment.y < 0 ? -offset : 0,
    );

    final isSvg = asset.toLowerCase().endsWith('.svg');
    return Align(
      alignment: alignment,
      child: Padding(
        padding: pad + nudge,
        child: SizedBox(
          width: size,
          height: size,
          child: isSvg
              ? SvgPicture.asset(asset, fit: BoxFit.contain)
              : Image.asset(asset, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _StadiumClipper extends CustomClipper<Path> {
  const _StadiumClipper();
  @override
  Path getClip(Size size) => _stadiumPath(Offset.zero & size);
  @override
  bool shouldReclip(_) => false;
}
