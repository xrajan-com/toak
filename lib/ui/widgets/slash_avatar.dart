import 'dart:math' as math;
import 'dart:ui' as ui show lerpDouble, MaskFilter, BlurStyle;

import 'package:flutter/material.dart';

// Keep every dealer skin anchored at the same chair/table position (original Renoir/Slash).
const double _kDealerSeatCenterY = 0.72;
// Custom-painted skins need a slight lift to match the original Renoir posture.
const double _kCustomSeatCenterY = 0.78;
// Buckethead sits a touch higher so the torso rests against the chair, not the rail.
const double _kBucketheadSeatCenterY = 0.72;
const double _kBucketheadLiftPx = 32;
const double _kBucketheadBodyRaisePx = 32;
const double _kBucketheadHandDropPx = 16;
// Redrix sits in line with Buckethead so the torso rests on the chair back.
const double _kRedrixSeatCenterY = 0.72;
const double _kRedrixLiftPx = 32; // nudge upward in pixels

/// Shared Renoir-style hands: tapered palms with simple finger hints + card fan.
void _paintRenoirHands(Canvas canvas, Size size, double phase,
    {double handYOffset = -0.04,
    double spreadFactor = 0.22,
    bool drawCards = true,
    double handScale = 1.0,
    double fingerSpread = 1.0,
    Color handColor = const Color(0xFFE4C7A3),
    Color fingerColor = const Color(0xFFD9B484)}) {
  final double bobY = size.height * 0.012 * math.sin(phase * 1.2);
  final double handY = size.height * handYOffset + bobY;
  final double palmWidth = 26 * handScale;
  final double baseSpread = palmWidth * 0.08; // hands nearly touching
  final double spread =
      baseSpread + size.width * spreadFactor * 0.08 + math.sin(phase) * 4;
  final Paint hand = Paint()..color = handColor;

  final double palmHeight = 18 * handScale;

  void drawHand(double dir) {
    final double x = spread * dir;
    final RRect palm = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, handY),
        width: palmWidth,
        height: palmHeight,
      ),
      Radius.circular(8 * handScale),
    );
    canvas.drawRRect(palm, hand);
    final Paint finger = Paint()
      ..color = fingerColor
      ..strokeWidth = 2.2 * handScale
      ..strokeCap = StrokeCap.round;
    final List<double> fingers = <double>[
      -palmWidth * 0.28,
      -palmWidth * 0.12,
      palmWidth * 0.08,
      palmWidth * 0.26,
    ].map((v) => v * fingerSpread).toList();
    for (final fx in fingers) {
      canvas.drawLine(
        Offset(x + fx, handY + 4 * handScale),
        Offset(x + fx, handY - 7 * handScale),
        finger,
      );
    }
  }

  drawHand(-1);
  drawHand(1);

  if (drawCards) {
    final Paint cards = Paint()..color = const Color(0xFFEFEFEF);
    final Path cardFan = Path()
      ..moveTo(-spread * 0.26, handY - 6)
      ..relativeLineTo(spread * 0.52, 0)
      ..relativeLineTo(-spread * 0.26, 30)
      ..close();
    canvas.save();
    canvas.translate(0, handY - 12);
    canvas.rotate(math.sin(phase * 1.4) * 0.05);
    canvas.drawPath(cardFan, cards);
    canvas.restore();
  }
}

/// Available looks (skins) for the single dealer, Renoir.
enum DealerAvatarStyle {
  /// Uses the Renoir PNG sprites (idle + shuffle frames).
  classic,

  /// Slash-inspired custom-painted dealer. Premium-only.
  slash,

  // Kingdom-specific free skins (20 total; 1 per venue).
  baroda,
  hyderabad,
  indore,
  jaipur,
  marathaEmpire,
  mysore,
  newDelhi,
  sikhEmpire,
  sikkim,
  travancore,
  africa,
  southAmerica,
  northAmerica,
  arabia,
  australia,
  china,
  europe,
  india,
  russia,
  asia,
}

/// Color palettes for the Slash avatar's tuxedo.
enum SlashJacketTone {
  black,
  darkBlue,
  lightBlue,
  white,
  beige,
  wineRed,
  khakhi,
  olive,
}

extension DealerAvatarStyleX on DealerAvatarStyle {
  bool get usesSpriteAssets => this == DealerAvatarStyle.classic;
  bool get usesCustomPainter => !usesSpriteAssets;
  bool get isPremiumOnly => this == DealerAvatarStyle.slash;
}

int _fnv1a32(String input) {
  int hash = 0x811C9DC5;
  for (final int unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

Color _lerpColor(Color a, Color b, double t) {
  final clamped = t.clamp(0.0, 1.0);
  return Color.fromARGB(
    (a.alpha + ((b.alpha - a.alpha) * clamped)).round().clamp(0, 255),
    (a.red + ((b.red - a.red) * clamped)).round().clamp(0, 255),
    (a.green + ((b.green - a.green) * clamped)).round().clamp(0, 255),
    (a.blue + ((b.blue - a.blue) * clamped)).round().clamp(0, 255),
  );
}

Color _darken(Color c, double t) => _lerpColor(c, const Color(0xFF000000), t);
Color _lighten(Color c, double t) => _lerpColor(c, const Color(0xFFFFFFFF), t);

enum _HairStyle {
  short,
  spikes,
  afro,
  long,
  bun,
  shaved,
  fade,
  bald,
  thinning,
}
enum _HatStyle {
  none,
  brim,
  cap,
  crown,
  band,
  turban,
  bucket,
  mouse,
  keffiyeh,
  helmet,
  boxingHelmet,
}
enum _GlassesStyle { none, round, square, aviator }
enum _FacialHair { none, moustache, beard, goatee }

enum DealerGender { male, female }

class _DealerPersonaOverride {
  const _DealerPersonaOverride({
    this.gender,
    this.skin,
    this.hair,
    this.headgear,
    this.headgearAccent,
    this.hairStyle,
    this.hatStyle,
    this.glassesStyle,
    this.facialHair,
  });

  final DealerGender? gender;
  final Color? skin;
  final Color? hair;
  final Color? headgear;
  final Color? headgearAccent;
  final _HairStyle? hairStyle;
  final _HatStyle? hatStyle;
  final _GlassesStyle? glassesStyle;
  final _FacialHair? facialHair;
}

// Fill these to match the real-life inspirations (skin tone, hair, head-gear, etc.).
//
// Note: these are stylized caricatures; we only encode broad visual traits.
const Map<DealerAvatarStyle, _DealerPersonaOverride> _dealerPersonaOverrides =
    <DealerAvatarStyle, _DealerPersonaOverride>{
  // India (10 kingdoms)
  // Jaipur → Maharana Pratap
  DealerAvatarStyle.jaipur: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFC9976B),
    hair: Color(0xFF1D1B18),
    headgear: Color(0xFFD4AF37),
    headgearAccent: Color(0xFFFFE08A),
    hairStyle: _HairStyle.long,
    hatStyle: _HatStyle.crown,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.moustache,
  ),

  // Baroda → Narendra Modi
  DealerAvatarStyle.baroda: _DealerPersonaOverride(
    gender: DealerGender.male,
    // Baroda → Mahatma Gandhi (user direction)
    skin: Color(0xFFC9976B),
    hair: Color(0xFF6B4E2E), // brown (salt/pepper is painted in facial hair)
    hairStyle: _HairStyle.bald,
    hatStyle: _HatStyle.none,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.moustache,
  ),

  // Sikkim → Mary Kom (female boxer)
  DealerAvatarStyle.sikkim: _DealerPersonaOverride(
    gender: DealerGender.female,
    skin: Color(0xFFF2D6C1), // fair
    hair: Color(0xFF0D0D12),
    headgear: Color(0xFFE1202E), // red boxing helmet
    headgearAccent: Color(0xFFF2F2F6),
    hairStyle: _HairStyle.bald,
    hatStyle: _HatStyle.boxingHelmet,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.none,
  ),

  // Sikh Empire → Sidhu Moosewala
  DealerAvatarStyle.sikhEmpire: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFDDB38C),
    hair: Color(0xFF0D0D12),
    headgear: Color(0xFFF9C74F), // yellow turban
    headgearAccent: Color(0xFFD99A00),
    hairStyle: _HairStyle.short,
    hatStyle: _HatStyle.turban,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.none, // clean shaved
  ),

  // Maratha Empire → Dharmendra
  DealerAvatarStyle.marathaEmpire: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFF2D6C1), // fair
    hair: Color(0xFF0D0D12),
    headgear: Color(0xFF66B7FF), // sky blue baseball cap
    headgearAccent: Color(0xFFD7F0FF),
    hairStyle: _HairStyle.short,
    hatStyle: _HatStyle.cap,
    glassesStyle: _GlassesStyle.aviator, // black sunglasses
    facialHair: _FacialHair.none, // clean shaven
  ),

  // New Delhi → Narendra Modi
  DealerAvatarStyle.newDelhi: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFDDB38C),
    hair: Color(0xFFD7D9DE),
    hairStyle: _HairStyle.thinning,
    hatStyle: _HatStyle.none,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.beard,
  ),

  // Travancore → Kimi Räikkönen (Ferrari F1 helmet)
  DealerAvatarStyle.travancore: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFF2D6C1),
    hair: Color(0xFF0D0D12),
    headgear: Color(0xFFE1202E), // Ferrari red
    headgearAccent: Color(0xFFF2F2F6),
    hairStyle: _HairStyle.bald,
    hatStyle: _HatStyle.helmet,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.none,
  ),

  // Mysore → Vijay Mallya
  DealerAvatarStyle.mysore: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFDDB38C),
    hair: Color(0xFFF2F2F6), // long white hair
    hairStyle: _HairStyle.long,
    hatStyle: _HatStyle.none,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.moustache, // french cut (moustache + goatee) is painted below
  ),

  // Hyderabad → Rihanna (female singer)
  DealerAvatarStyle.hyderabad: _DealerPersonaOverride(
    gender: DealerGender.female,
    skin: Color(0xFF845035), // sizzling tanned brown
    hair: Color(0xFFB21F2D), // long red hair
    hairStyle: _HairStyle.long,
    hatStyle: _HatStyle.none,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.none,
  ),

  // Indore → Amitabh Bachchan (current/older)
  DealerAvatarStyle.indore: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFECC7A9),
    // Salt-and-pepper hair.
    hair: Color(0xFF7E7F86),
    hairStyle: _HairStyle.short,
    hatStyle: _HatStyle.none,
    glassesStyle: _GlassesStyle.square,
    facialHair: _FacialHair.beard,
  ),

  // International (10 venues)
  // N. America → Buckethead
  DealerAvatarStyle.northAmerica: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFF2F2F6), // mask
    hair: Color(0xFF0D0D12),
    headgear: Color(0xFFF7F7FA), // bucket
    headgearAccent: Color(0xFFB21F2D),
    hairStyle: _HairStyle.shaved,
    hatStyle: _HatStyle.bucket,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.none,
  ),

  // S. America → The Undertaker (young)
  DealerAvatarStyle.southAmerica: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFE8C9B2),
    hair: Color(0xFF0D0D12),
    headgear: Color(0xFF0D0D12),
    headgearAccent: Color(0xFF2A2A35),
    hairStyle: _HairStyle.long,
    hatStyle: _HatStyle.brim,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.goatee,
  ),

  // Africa → Jimi Hendrix
  DealerAvatarStyle.africa: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFF845035),
    hair: Color(0xFF0D0D12),
    headgear: Color(0xFF6A2C91), // headband
    headgearAccent: Color(0xFFE0C15E),
    hairStyle: _HairStyle.afro,
    hatStyle: _HatStyle.band,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.moustache,
  ),

  // Australia → Angus Young
  DealerAvatarStyle.australia: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFF2D6C1),
    hair: Color(0xFF3B2B1B),
    headgear: Color(0xFF101116), // school-cap vibe
    headgearAccent: Color(0xFFF2F2F6),
    hairStyle: _HairStyle.short,
    hatStyle: _HatStyle.cap,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.none,
  ),

  // Arabia → King Abdullah
  DealerAvatarStyle.arabia: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFDDB38C),
    hair: Color(0xFF0D0D12),
    headgear: Color(0xFFF7F7FA), // ghutra
    headgearAccent: Color(0xFF0D0D12), // agal
    hairStyle: _HairStyle.short,
    hatStyle: _HatStyle.keffiyeh,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.beard,
  ),

  // India → A. P. J. Abdul Kalam
  DealerAvatarStyle.india: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFC9976B),
    hair: Color(0xFFBFC4C9),
    hairStyle: _HairStyle.long,
    hatStyle: _HatStyle.none,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.none,
  ),

  // Europe → Deadmau5
  DealerAvatarStyle.europe: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFECC7A9),
    hair: Color(0xFF0D0D12),
    headgear: Color(0xFFE1202E), // helmet
    headgearAccent: Color(0xFF111216), // eyes
    hairStyle: _HairStyle.shaved,
    hatStyle: _HatStyle.mouse,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.none,
  ),

  // Asia → Ichika Nito
  DealerAvatarStyle.asia: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFF2D6C1),
    hair: Color(0xFF0D0D12),
    hairStyle: _HairStyle.long,
    hatStyle: _HatStyle.none,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.none,
  ),

  // China → Kim Jong Un
  DealerAvatarStyle.china: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFECC7A9),
    hair: Color(0xFF0D0D12),
    hairStyle: _HairStyle.fade,
    hatStyle: _HatStyle.none,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.none,
  ),

  // Russia → blonde spikes
  DealerAvatarStyle.russia: _DealerPersonaOverride(
    gender: DealerGender.male,
    skin: Color(0xFFF2D6C1),
    hair: Color(0xFFB69B74),
    hairStyle: _HairStyle.spikes,
    hatStyle: _HatStyle.none,
    glassesStyle: _GlassesStyle.none,
    facialHair: _FacialHair.none,
  ),
};

class _DealerPersona {
  const _DealerPersona({
    required this.gender,
    required this.skin,
    required this.hair,
    required this.headgear,
    required this.headgearAccent,
    required this.hairStyle,
    required this.hatStyle,
    required this.glassesStyle,
    required this.facialHair,
  });

  final DealerGender gender;
  final Color skin;
  final Color hair;
  final Color headgear;
  final Color headgearAccent;
  final _HairStyle hairStyle;
  final _HatStyle hatStyle;
  final _GlassesStyle glassesStyle;
  final _FacialHair facialHair;

  bool get isFemale => gender == DealerGender.female;
}

// Edit this set as you decide which of the 20 skins are female.
const Set<DealerAvatarStyle> _femaleDealerSkins = <DealerAvatarStyle>{
  DealerAvatarStyle.sikkim, // Mary Kom
  DealerAvatarStyle.hyderabad, // Rihanna
};

DealerGender _genderForStyle(DealerAvatarStyle style) {
  final override = _dealerPersonaOverrides[style];
  if (override?.gender != null) return override!.gender!;
  if (_femaleDealerSkins.contains(style)) return DealerGender.female;
  return DealerGender.male;
}

_DealerPersona _personaForStyle(DealerAvatarStyle style) {
  final int seed = _fnv1a32(style.name);

  const skinTones = <Color>[
    Color(0xFFF2D6C1),
    Color(0xFFECC7A9),
    Color(0xFFDDB38C),
    Color(0xFFC9976B),
    Color(0xFFB57D55),
    Color(0xFF9D6543),
    Color(0xFF845035),
    Color(0xFF6C3E2B),
  ];

  const hairTones = <Color>[
    Color(0xFF0D0D12),
    Color(0xFF1D1B18),
    Color(0xFF2E2217),
    Color(0xFF3B2B1B),
    Color(0xFF6B4E2E),
    Color(0xFF9C7A52),
    Color(0xFFB69B74),
  ];

  const headgearTones = <Color>[
    Color(0xFF0D0D12),
    Color(0xFF1A1A22),
    Color(0xFF2E2217),
    Color(0xFF3B2B1B),
    Color(0xFF0F2547), // dark blue
    Color(0xFF556B2F), // olive
    Color(0xFF5A1A24), // wine red
    Color(0xFFC2B280), // khakhi
  ];

  final skin = skinTones[seed % skinTones.length];
  final hair = hairTones[(seed >> 6) % hairTones.length];
  final DealerGender gender = _genderForStyle(style);
  const baseHairStyles = <_HairStyle>[
    _HairStyle.short,
    _HairStyle.afro,
    _HairStyle.long,
    _HairStyle.bun,
    _HairStyle.shaved,
  ];
  _HairStyle hairStyle = baseHairStyles[(seed >> 10) % baseHairStyles.length];
  if (gender == DealerGender.female && hairStyle == _HairStyle.shaved) {
    hairStyle = _HairStyle.bun;
  }
  const baseHatStyles = <_HatStyle>[
    _HatStyle.none,
    _HatStyle.brim,
    _HatStyle.cap,
    _HatStyle.crown,
    _HatStyle.band,
  ];
  final hatStyle = baseHatStyles[(seed >> 14) % baseHatStyles.length];
  final glassesStyle =
      _GlassesStyle.values[(seed >> 18) % _GlassesStyle.values.length];
  _FacialHair facialHair =
      _FacialHair.values[(seed >> 22) % _FacialHair.values.length];
  if (gender == DealerGender.female) facialHair = _FacialHair.none;

  final headgear =
      headgearTones[(seed >> 12) % headgearTones.length];
  final headgearAccent = _lighten(headgear, 0.42);

  final override = _dealerPersonaOverrides[style];

  return _DealerPersona(
    gender: override?.gender ?? gender,
    skin: override?.skin ?? skin,
    hair: override?.hair ?? hair,
    headgear: override?.headgear ?? headgear,
    headgearAccent: override?.headgearAccent ?? headgearAccent,
    hairStyle: override?.hairStyle ?? hairStyle,
    hatStyle: override?.hatStyle ?? hatStyle,
    glassesStyle: override?.glassesStyle ?? glassesStyle,
    facialHair: override?.facialHair ?? facialHair,
  );
}

class KingdomDealerAvatar extends StatelessWidget {
  final DealerAvatarStyle style;
  final double height;
  final double pose;
  final SlashJacketTone jacketTone;
  final Color? feltColor;
  final Color? railLightColor;
  final Color? railMidColor;
  final Color? railDarkColor;

  const KingdomDealerAvatar({
    super.key,
    required this.style,
    required this.height,
    required this.pose,
    this.jacketTone = SlashJacketTone.black,
    this.feltColor,
    this.railLightColor,
    this.railMidColor,
    this.railDarkColor,
  });

  @override
  Widget build(BuildContext context) {
    final double width = height * 0.72;
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _KingdomDealerPainter(
          pose,
          style,
          jacketTone,
          feltColor: feltColor,
          railLightColor: railLightColor,
          railMidColor: railMidColor,
          railDarkColor: railDarkColor,
        ),
      ),
    );
  }
}

class _KingdomDealerPainter extends CustomPainter {
  _KingdomDealerPainter(
    this.pose,
    this.style,
    this.jacketTone, {
    Color? feltColor,
    Color? railLightColor,
    Color? railMidColor,
    Color? railDarkColor,
  })  : persona = _personaForStyle(style),
        tux = _jacketPaletteForTone(jacketTone),
        felt = feltColor ?? const Color(0xFF13321E),
        railLight = railLightColor ?? const Color(0xFF5A241C),
        railMid = railMidColor ?? const Color(0xFF3E140F),
        railDark = railDarkColor ?? const Color(0xFF2C0E0B);

  final double pose;
  final DealerAvatarStyle style;
  final SlashJacketTone jacketTone;
  final _DealerPersona persona;
  final _JacketPalette tux;
  final Color felt;
  final Color railLight;
  final Color railMid;
  final Color railDark;

  @override
  void paint(Canvas canvas, Size size) {
    final double phase = pose * 2 * math.pi;
    final double sway = math.sin(phase) * 0.035;
    final double bob = size.height * 0.008 * math.sin(phase * 1.15);

    final Offset seatCenter =
        Offset(size.width / 2, size.height * _kCustomSeatCenterY + bob);
    final Offset bodyCenter = seatCenter.translate(0, -size.height * 0.20);
    final Offset handCenter = seatCenter.translate(0, -size.height * 0.05);

    _paintGlow(canvas, size, seatCenter);
    _paintTable(canvas, size);
    _paintChair(canvas, size);

    canvas.save();
    // Keep the torso "behind" the real table rail/felt by clipping the lower
    // body so the UI rail can visually sit in front.
    final double torsoClipY = size.height * 0.64;
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, torsoClipY));
    canvas.translate(bodyCenter.dx, bodyCenter.dy);
    canvas.rotate(sway);
    _paintBody(canvas, size);
    canvas.restore();

    canvas.save();
    canvas.translate(handCenter.dx, handCenter.dy);
    canvas.rotate(sway);
    _paintHands(canvas, size, phase);
    canvas.restore();

    canvas.save();
    canvas.translate(bodyCenter.dx, bodyCenter.dy);
    canvas.rotate(sway);
    _paintHead(canvas, size);
    canvas.restore();
  }

  void _paintGlow(Canvas canvas, Size size, Offset center) {
    // Intentionally no glow (matches Slash) so the UI logo stays clean.
  }

  void _paintTable(Canvas canvas, Size size) {
    // Intentionally empty: dealer table/rail is drawn by the main UI.
    // (We keep the method so future skins can opt-in without touching callers.)
  }

  void _paintChair(Canvas canvas, Size size) {
    // Intentionally empty: chair can overlap the rail in the current layout.
  }

  void _paintBody(Canvas canvas, Size size) {
    final bool female = persona.isFemale;
    final double bodyW = size.width * 0.56;
    final double bodyH = size.height * 0.40;
    final Rect jacketRect = Rect.fromCenter(
      center: Offset(0, bodyH * 0.05),
      width: bodyW,
      height: bodyH,
    );

    final Paint jacket = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          tux.top,
          tux.bottom,
        ],
      ).createShader(jacketRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(jacketRect, const Radius.circular(22)),
      jacket,
    );

    final Paint lapel = Paint()..color = tux.lapel;
    final Path lapelL = Path()
      ..moveTo(-bodyW * 0.22, -bodyH * 0.35)
      ..quadraticBezierTo(-bodyW * 0.06, -bodyH * 0.22, -bodyW * 0.02, -bodyH * 0.04)
      ..quadraticBezierTo(-bodyW * 0.04, bodyH * 0.08, -bodyW * 0.14, bodyH * 0.14)
      ..quadraticBezierTo(-bodyW * 0.26, bodyH * 0.10, -bodyW * 0.30, -bodyH * 0.06)
      ..close();
    final Path lapelR = Path()
      ..moveTo(bodyW * 0.22, -bodyH * 0.35)
      ..quadraticBezierTo(bodyW * 0.06, -bodyH * 0.22, bodyW * 0.02, -bodyH * 0.04)
      ..quadraticBezierTo(bodyW * 0.04, bodyH * 0.08, bodyW * 0.14, bodyH * 0.14)
      ..quadraticBezierTo(bodyW * 0.26, bodyH * 0.10, bodyW * 0.30, -bodyH * 0.06)
      ..close();
    canvas.drawPath(lapelL, lapel);
    canvas.drawPath(lapelR, lapel);

    final Rect shirtRect = Rect.fromCenter(
      center: Offset(0, bodyH * 0.06),
      width: bodyW * 0.28,
      height: bodyH * 0.70,
    );
    if (female) {
      _paintFemaleTop(canvas, bodyW: bodyW, bodyH: bodyH, innerRect: shirtRect);
    } else {
      const Color shirtColor = Color(0xFFF2F2F6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(shirtRect, const Radius.circular(12)),
        Paint()..color = shirtColor,
      );

      final Paint tie = Paint()..color = const Color(0xFF111216);
      final Path tiePath = Path()
        ..moveTo(0, -bodyH * 0.25)
        ..quadraticBezierTo(-6, -bodyH * 0.14, -2, -bodyH * 0.04)
        ..quadraticBezierTo(-7, bodyH * 0.18, 0, bodyH * 0.32)
        ..quadraticBezierTo(7, bodyH * 0.18, 2, -bodyH * 0.04)
        ..quadraticBezierTo(6, -bodyH * 0.14, 0, -bodyH * 0.25)
        ..close();
      canvas.drawPath(tiePath, tie);
    }
  }

  void _paintFemaleTop(Canvas canvas,
      {required double bodyW, required double bodyH, required Rect innerRect}) {
    final RRect clip =
        RRect.fromRectAndRadius(innerRect, const Radius.circular(12));
    canvas.save();
    canvas.clipRRect(clip);

    // A simple evening top (no collar) with a deep V neckline.
    final Paint top = Paint()..color = const Color(0xFF101116);
    canvas.drawRRect(clip, top);

    final double neckTop = innerRect.top + innerRect.height * 0.10;
    final double neckDepth = innerRect.top + innerRect.height * 0.40;
    final double neckHalfW = innerRect.width * 0.40;

    final Path vNeck = Path()
      ..moveTo(-neckHalfW, neckTop)
      ..lineTo(neckHalfW, neckTop)
      ..quadraticBezierTo(0, neckTop + innerRect.height * 0.05, 0, neckDepth)
      ..close();

    // Show a bit of skin inside the neckline (stylized; no explicit detail).
    canvas.drawPath(vNeck, Paint()..color = persona.skin);

    final Offset left = Offset(-innerRect.width * 0.18, neckDepth + bodyH * 0.04);
    final Offset right = Offset(innerRect.width * 0.18, neckDepth + bodyH * 0.04);
    final double rx = innerRect.width * 0.26;
    final double ry = innerRect.height * 0.22;

    Paint bustShade(Offset c) => Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.00),
          const Color(0x1A000000),
          const Color(0x2A000000),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2));

    canvas.drawOval(
      Rect.fromCenter(center: left, width: rx * 2, height: ry * 2),
      bustShade(left),
    );
    canvas.drawOval(
      Rect.fromCenter(center: right, width: rx * 2, height: ry * 2),
      bustShade(right),
    );

    final Paint highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: left.translate(0, -ry * 0.20),
        width: rx * 1.55,
        height: ry * 1.45,
      ),
      math.pi,
      math.pi,
      false,
      highlight,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: right.translate(0, -ry * 0.20),
        width: rx * 1.55,
        height: ry * 1.45,
      ),
      math.pi,
      math.pi,
      false,
      highlight,
    );

    final Paint seam = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(vNeck, seam);

    canvas.restore();
  }

  void _paintHands(Canvas canvas, Size size, double phase) {
    _paintRenoirHands(
      canvas,
      size,
      phase,
      handYOffset: -0.03,
      spreadFactor: 0.21,
      drawCards: true,
      handScale: persona.isFemale ? 0.94 : 1.05,
      fingerSpread: 1.0,
      handColor: persona.skin,
      fingerColor: _darken(persona.skin, 0.10),
    );
  }

  Rect _faceRect(double headR) {
    double faceW = headR * 1.65;
    double faceH = headR * 1.95;

    if (style == DealerAvatarStyle.marathaEmpire) {
      faceW = headR * 1.45;
      faceH = headR * 2.25;
    } else if (style == DealerAvatarStyle.asia) {
      // Ichika Nito: a slightly slimmer face.
      faceW = headR * 1.58;
      faceH = headR * 2.02;
    } else if (style == DealerAvatarStyle.china) {
      // Kim Jong Un: rounder/wider face.
      faceW = headR * 1.88;
      faceH = headR * 1.88;
    }

    return Rect.fromCenter(
      center: const Offset(0, 0),
      width: faceW,
      height: faceH,
    );
  }

  void _paintHead(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(0, -size.height * 0.14);

    final double headR = size.width * 0.14;
    final Rect face = _faceRect(headR);
    final bool hairBehindFace =
        persona.hairStyle == _HairStyle.long || persona.hairStyle == _HairStyle.afro;
    if (hairBehindFace) {
      _paintHair(canvas, size, headR);
    }

    canvas.drawOval(face, Paint()..color = persona.skin);

    if (!hairBehindFace) {
      _paintHair(canvas, size, headR);
    }
    _paintHat(canvas, size, headR);
    _paintFaceDetails(canvas, size, headR);

    canvas.restore();
  }

  void _paintHair(Canvas canvas, Size size, double headR) {
    final Paint hair = Paint()..color = persona.hair;
    switch (persona.hairStyle) {
      case _HairStyle.bald:
        return;
      case _HairStyle.thinning:
        // A receding / thinning hairline (horseshoe) for older male skins.
        final Rect face = _faceRect(headR);
        final Path cutFace = Path()..addOval(face.inflate(headR * 0.12));

        final Path outer = Path()
          ..addOval(Rect.fromCircle(
              center: Offset(0, -headR * 0.56), radius: headR * 1.24));
        final Path scalp = Path()
          ..addOval(Rect.fromCircle(
              center: Offset(0, -headR * 0.74), radius: headR * 0.95));
        final Path recedeMask = Path()
          ..addRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(0, -headR * 1.06),
              width: headR * 1.55,
              height: headR * 0.78,
            ),
            Radius.circular(headR * 0.34),
          ));

        Path p = Path.combine(PathOperation.difference, outer, scalp);
        p = Path.combine(PathOperation.difference, p, recedeMask);
        p = Path.combine(PathOperation.difference, p, cutFace);
        canvas.drawPath(p, hair);

        // Wispy strands near the hairline (thinning look).
        final Paint wisps = Paint()
          ..color = _lighten(persona.hair, 0.20).withValues(alpha: 0.75)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        for (final double dx in <double>[-0.62, -0.50, -0.38, 0.38, 0.50, 0.62]) {
          canvas.drawLine(
            Offset(dx * headR, -headR * 1.02),
            Offset(dx * headR * 0.90, -headR * 0.78),
            wisps,
          );
        }
        return;
      case _HairStyle.shaved:
        canvas.drawArc(
          Rect.fromCircle(center: Offset(0, -headR * 0.30), radius: headR * 1.05),
          math.pi,
          math.pi,
          true,
          hair..color = _lighten(persona.hair, 0.12),
        );
        break;
      case _HairStyle.short:
        canvas.drawArc(
          Rect.fromCircle(center: Offset(0, -headR * 0.36), radius: headR * 1.18),
          math.pi,
          math.pi,
          true,
          hair,
        );
        if (style == DealerAvatarStyle.indore) {
          final Paint salt = Paint()
            ..color = Colors.white.withValues(alpha: 0.48)
            ..strokeWidth = headR * 0.10
            ..strokeCap = StrokeCap.round;
          final Paint pepper = Paint()
            ..color = _darken(persona.hair, 0.55).withValues(alpha: 0.65)
            ..strokeWidth = headR * 0.10
            ..strokeCap = StrokeCap.round;

          final double yTop = -headR * 1.38;
          final double yBottom = -headR * 0.52;
          for (int i = -4; i <= 4; i++) {
            final double x = i * headR * 0.22;
            final Paint p = (i.isEven ? salt : pepper);
            canvas.drawLine(
              Offset(x, yTop),
              Offset(x * 0.82, yBottom),
              p,
            );
          }
        }
        break;
      case _HairStyle.spikes:
        // Spiky hair silhouette (used for Russia venue).
        canvas.drawArc(
          Rect.fromCircle(center: Offset(0, -headR * 0.36), radius: headR * 1.18),
          math.pi,
          math.pi,
          true,
          hair,
        );

        final int spikeCount = 7;
        final double leftX = -headR * 1.05;
        final double rightX = headR * 1.05;
        final double baseY = -headR * 1.28;
        final double topY = -headR * 1.72;
        final double step = (rightX - leftX) / spikeCount;

        final Path spikes = Path()..moveTo(leftX, baseY);
        for (int i = 0; i < spikeCount; i++) {
          final double x0 = leftX + step * i;
          final double xMid = x0 + step * 0.5;
          final double x1 = x0 + step;
          final double tipY = topY + ((i.isEven) ? 0.0 : headR * 0.10);
          spikes
            ..lineTo(xMid, tipY)
            ..lineTo(x1, baseY);
        }
        spikes.close();
        canvas.drawPath(spikes, hair);
        break;
      case _HairStyle.afro:
        final Rect face = _faceRect(headR);
        final Path afro = Path()
          ..addOval(
            Rect.fromCircle(
                center: Offset(0, -headR * 0.55), radius: headR * 1.25),
          );
        final Path cut = Path()..addOval(face.inflate(headR * 0.10));
        canvas.drawPath(
          Path.combine(PathOperation.difference, afro, cut),
          hair,
        );
        break;
      case _HairStyle.long:
        final Rect face = _faceRect(headR);
        final bool isAsia = style == DealerAvatarStyle.asia;
        final double topRadius = isAsia ? headR * 1.12 : headR * 1.18;
        final double topCenterY = isAsia ? -headR * 0.52 : -headR * 0.45;
        final double bodyW = isAsia ? headR * 1.82 : headR * 1.95;
        final double bodyH = isAsia ? headR * 1.65 : headR * 1.75;
        final double bodyCenterY = isAsia ? headR * 0.28 : headR * 0.25;
        final double cutInflate = isAsia ? headR * 0.06 : headR * 0.10;
        final Path p = Path()
          ..addOval(Rect.fromCircle(center: Offset(0, topCenterY), radius: topRadius))
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(0, bodyCenterY),
                width: bodyW,
                height: bodyH,
              ),
              Radius.circular(headR * 0.55),
            ),
          );
        final Path cut = Path()..addOval(face.inflate(cutInflate));
        canvas.drawPath(Path.combine(PathOperation.difference, p, cut), hair);

        // Add a subtle hairline so the top doesn't look hollow.
        final Offset hairlineCenter = Offset(0, isAsia ? -headR * 0.48 : -headR * 0.42);
        final Rect hairlineRect =
            Rect.fromCircle(center: hairlineCenter, radius: headR * 1.10);
        final Path hairline = Path()
          ..moveTo(hairlineCenter.dx, hairlineCenter.dy)
          ..addArc(hairlineRect, math.pi, math.pi)
          ..close();
        canvas.drawPath(
          Path.combine(PathOperation.difference, hairline, cut),
          Paint()..color = _darken(persona.hair, 0.06),
        );

        if (isAsia) {
          // Center-part + bangs (thin strokes so skin tone stays clean).
          final Paint strand = Paint()
            ..color = _darken(persona.hair, 0.12).withValues(alpha: 0.48)
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round;
          final List<List<Offset>> strands = <List<Offset>>[
            [Offset(-headR * 0.58, -headR * 0.74), Offset(-headR * 0.20, -headR * 0.38)],
            [Offset(-headR * 0.24, -headR * 0.82), Offset(-headR * 0.02, -headR * 0.40)],
            [Offset(0, -headR * 0.86), Offset(headR * 0.10, -headR * 0.42)],
            [Offset(headR * 0.24, -headR * 0.82), Offset(headR * 0.02, -headR * 0.40)],
            [Offset(headR * 0.58, -headR * 0.74), Offset(headR * 0.20, -headR * 0.38)],
          ];
          for (final seg in strands) {
            canvas.drawLine(seg[0], seg[1], strand);
          }

          canvas.drawLine(
            Offset(0, -headR * 1.10),
            Offset(0, -headR * 0.62),
            strand..color = strand.color.withValues(alpha: 0.28),
          );
        }
        break;
      case _HairStyle.bun:
        canvas.drawArc(
          Rect.fromCircle(center: Offset(0, -headR * 0.42), radius: headR * 1.15),
          math.pi,
          math.pi,
          true,
          hair,
        );
        canvas.drawCircle(Offset(0, -headR * 1.20), headR * 0.35, hair);
        break;
      case _HairStyle.fade:
        if (style == DealerAvatarStyle.china) {
          // Kim Jong Un haircut: flat top + shaved sides.
          final Rect topRect = Rect.fromCenter(
            center: Offset(0, -headR * 0.96),
            width: headR * 2.22,
            height: headR * 0.82,
          );
          final RRect top = RRect.fromRectAndRadius(
            topRect,
            Radius.circular(headR * 0.26),
          );
          canvas.drawRRect(
            top,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _lighten(persona.hair, 0.18),
                  persona.hair,
                  _darken(persona.hair, 0.14),
                ],
                stops: const [0.0, 0.55, 1.0],
              ).createShader(topRect),
          );

          // Front shelf (straight hairline feel).
          final Rect shelfRect = Rect.fromCenter(
            center: Offset(0, -headR * 0.62),
            width: headR * 2.16,
            height: headR * 0.22,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(shelfRect, Radius.circular(headR * 0.12)),
            Paint()..color = _darken(persona.hair, 0.06),
          );

          // Side fade shading.
          final Paint fade = Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _lighten(persona.hair, 0.45).withValues(alpha: 0.70),
                _lighten(persona.hair, 0.45).withValues(alpha: 0.00),
              ],
            ).createShader(Rect.fromLTWH(-headR * 1.40, -headR * 1.10, headR * 2.80, headR * 1.45));
          final RRect sideL = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(-headR * 1.05, -headR * 0.44),
              width: headR * 0.70,
              height: headR * 1.10,
            ),
            Radius.circular(headR * 0.38),
          );
          final RRect sideR = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(headR * 1.05, -headR * 0.44),
              width: headR * 0.70,
              height: headR * 1.10,
            ),
            Radius.circular(headR * 0.38),
          );
          canvas.drawRRect(sideL, fade);
          canvas.drawRRect(sideR, fade);

          // Part line hint.
          final Paint part = Paint()
            ..color = Colors.white.withValues(alpha: 0.16)
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(headR * 0.58, -headR * 1.18),
            Offset(headR * 0.42, -headR * 0.64),
            part,
          );
          break;
        }
        // High fade with a fuller top.
        final Path top = Path()
          ..moveTo(-headR * 0.98, -headR * 0.62)
          ..quadraticBezierTo(0, -headR * 1.18, headR * 0.98, -headR * 0.62)
          ..quadraticBezierTo(headR * 0.72, -headR * 0.08, 0, -headR * 0.10)
          ..quadraticBezierTo(-headR * 0.72, -headR * 0.08, -headR * 0.98, -headR * 0.62)
          ..close();
        canvas.drawPath(top, hair);

        final Paint fadeShade = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _lighten(persona.hair, 0.25),
              persona.hair.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCenter(
              center: Offset(0, -headR * 0.22),
              width: headR * 2.20,
              height: headR * 1.20));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(0, -headR * 0.18),
              width: headR * 2.05,
              height: headR * 1.05,
            ),
            Radius.circular(headR * 0.50),
          ),
          fadeShade,
        );
        break;
    }
  }

  void _paintHat(Canvas canvas, Size size, double headR) {
    final Paint hat = Paint()..color = persona.headgear;
    final Paint trim = Paint()..color = persona.headgearAccent;

    switch (persona.hatStyle) {
      case _HatStyle.none:
        return;
      case _HatStyle.brim:
        final Rect brim = Rect.fromCenter(
          center: Offset(0, -headR * 0.88),
          width: headR * 2.20,
          height: headR * 0.38,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(brim, Radius.circular(headR)), hat);
        final Rect crown = Rect.fromCenter(
          center: Offset(0, -headR * 1.22),
          width: headR * 1.35,
          height: headR * 0.85,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(crown, Radius.circular(headR * 0.35)), hat);
        canvas.drawRRect(
          RRect.fromRectAndRadius(brim.deflate(2.0), Radius.circular(headR)),
          trim..color = trim.color.withValues(alpha: 0.55),
        );
        break;
      case _HatStyle.cap:
        canvas.drawArc(
          Rect.fromCircle(center: Offset(0, -headR * 0.95), radius: headR * 1.10),
          math.pi,
          math.pi,
          true,
          hat,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(0, -headR * 0.72),
            width: headR * 1.55,
            height: headR * 0.18,
          ),
          hat,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(0, -headR * 0.72),
            width: headR * 1.55,
            height: headR * 0.10,
          ),
          trim..color = trim.color.withValues(alpha: 0.6),
        );
        break;
      case _HatStyle.crown:
        // A more "proper" crown silhouette: band + five rounded spikes + jewels.
        final Rect bandRect = Rect.fromCenter(
          center: Offset(0, -headR * 0.88),
          width: headR * 2.30,
          height: headR * 0.52,
        );
        final Paint band = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _lighten(persona.headgear, 0.28),
              _darken(persona.headgear, 0.08),
            ],
          ).createShader(bandRect);
        canvas.drawRRect(
          RRect.fromRectAndRadius(bandRect, Radius.circular(headR * 0.28)),
          band,
        );

        final double halfW = bandRect.width / 2;
        final double valleyY = bandRect.top + headR * 0.10;
        final double tipY = bandRect.top - headR * 0.72;
        final double step = bandRect.width / 5;
        final Rect crownRect =
            Rect.fromLTRB(bandRect.left, tipY, bandRect.right, valleyY);
        final Paint crownFill = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _lighten(persona.headgear, 0.36),
              _lighten(persona.headgear, 0.12),
            ],
          ).createShader(crownRect);
        final Paint outline = Paint()
          ..color = _darken(persona.headgearAccent, 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        final Path spikes = Path()..moveTo(-halfW, valleyY);
        for (int i = 0; i < 5; i++) {
          final double x1 = -halfW + step * i;
          final double x2 = x1 + step;
          final double xTip = x1 + step * 0.50;
          spikes
            ..quadraticBezierTo(
              x1 + step * 0.25,
              valleyY - headR * 0.24,
              xTip,
              tipY,
            )
            ..quadraticBezierTo(
              x1 + step * 0.75,
              valleyY - headR * 0.24,
              x2,
              valleyY,
            );
        }
        spikes
          ..lineTo(halfW, bandRect.top + headR * 0.22)
          ..lineTo(-halfW, bandRect.top + headR * 0.22)
          ..close();

        canvas.drawPath(spikes, crownFill);
        canvas.drawPath(spikes, outline);

        // Crown band trim.
        canvas.drawRRect(
          RRect.fromRectAndRadius(bandRect.deflate(2.0), Radius.circular(headR * 0.28)),
          Paint()
            ..color = persona.headgearAccent.withValues(alpha: 0.40)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );

        // Jewels (3 on band, 1 on each outer spike, 1 large center jewel).
        const gems = <Color>[
          Color(0xFFE1202E), // ruby
          Color(0xFF16A34A), // emerald
          Color(0xFF2563EB), // sapphire
        ];
        final Paint jewelStroke = Paint()
          ..color = _darken(persona.headgearAccent, 0.05).withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        for (int i = 1; i <= 3; i++) {
          final double x = -halfW + step * i;
          final Offset c = Offset(x, bandRect.center.dy + headR * 0.02);
          final Color col = gems[(i - 1) % gems.length];
          canvas.drawCircle(c, headR * 0.10, Paint()..color = col);
          canvas.drawCircle(c, headR * 0.10, jewelStroke);
        }

        // Tip jewels.
        final List<double> tipXs = <double>[
          -halfW + step * 0.50,
          0,
          halfW - step * 0.50,
        ];
        for (int i = 0; i < tipXs.length; i++) {
          final Offset c = Offset(tipXs[i], tipY + headR * 0.07);
          canvas.drawCircle(
            c,
            i == 1 ? headR * 0.14 : headR * 0.11,
            Paint()..color = gems[(i + 1) % gems.length],
          );
          canvas.drawCircle(
            c,
            i == 1 ? headR * 0.14 : headR * 0.11,
            jewelStroke,
          );
        }
        break;
      case _HatStyle.band:
        final Rect band = Rect.fromCenter(
          center: Offset(0, -headR * 0.95),
          width: headR * 2.20,
          height: headR * 0.45,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(band, Radius.circular(headR)), hat);
        for (int i = -2; i <= 2; i++) {
          final double y = -headR * 0.98 + i * headR * 0.10;
          canvas.drawLine(
            Offset(-headR * 1.02, y),
            Offset(headR * 1.02, y),
            trim
              ..color = trim.color.withValues(alpha: 0.22)
              ..strokeWidth = 2.0,
          );
        }
        break;
      case _HatStyle.turban:
        // Sikh turban (stylized folds).
        final Rect bandRect = Rect.fromCenter(
          center: Offset(0, -headR * 0.88),
          width: headR * 2.38,
          height: headR * 0.62,
        );
        final RRect band = RRect.fromRectAndRadius(
          bandRect,
          Radius.circular(headR * 0.40),
        );

        final Rect topRect = Rect.fromCenter(
          center: Offset(0, -headR * 1.32),
          width: headR * 2.10,
          height: headR * 1.30,
        );
        final RRect top = RRect.fromRectAndRadius(
          topRect,
          Radius.circular(headR * 0.75),
        );

        final Paint turban = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _lighten(persona.headgear, 0.22),
              persona.headgear,
              _darken(persona.headgear, 0.14),
            ],
            stops: const [0.0, 0.60, 1.0],
          ).createShader(topRect.expandToInclude(bandRect));
        canvas.drawRRect(top, turban);
        canvas.drawRRect(band, turban);

        // Fold lines.
        final Paint fold = Paint()
          ..color = _darken(persona.headgearAccent, 0.02).withValues(alpha: 0.38)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        for (int i = -4; i <= 4; i++) {
          final double x1 = i * headR * 0.26;
          final double y1 = -headR * 1.30;
          final double x2 = x1 * 0.55;
          final double y2 = -headR * 0.76;
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), fold);
        }
        for (int i = -5; i <= 5; i++) {
          final double x = i * headR * 0.22;
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(x * 0.30, -headR * 0.92),
              width: headR * 1.60,
              height: headR * 0.82,
            ),
            math.pi,
            math.pi,
            false,
            fold..color = fold.color.withValues(alpha: 0.18),
          );
        }

        // Small front knot.
        final Offset knot = Offset(0, -headR * 0.76);
        canvas.drawCircle(knot, headR * 0.13, Paint()..color = _darken(persona.headgear, 0.10));
        canvas.drawCircle(
          knot,
          headR * 0.13,
          Paint()
            ..color = persona.headgearAccent.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
        break;
      case _HatStyle.bucket:
        // Buckethead bucket: a deeper bucket (not a tiny hat).
        final double topY = -headR * 2.05;
        final double rimY = -headR * 0.55;
        final double topW = headR * 2.25;
        final double rimW = headR * 2.62;
        final double midY = (topY + rimY) / 2;

        final Path body = Path()
          ..moveTo(-topW / 2, topY)
          ..quadraticBezierTo(-rimW / 2, midY, -rimW / 2, rimY)
          ..lineTo(rimW / 2, rimY)
          ..quadraticBezierTo(topW / 2, midY, topW / 2, topY)
          ..close();

        final Rect bodyRect = Rect.fromLTRB(-rimW / 2, topY, rimW / 2, rimY);
        final Paint bodyPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _lighten(persona.headgear, 0.24),
              persona.headgear,
              _darken(persona.headgear, 0.12),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(bodyRect);
        canvas.drawPath(body, bodyPaint);
        canvas.drawPath(
          body,
          Paint()
            ..color = _darken(persona.headgearAccent, 0.10).withValues(alpha: 0.28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );

        // Top cap (closed bottom of the bucket).
        final Rect topOval = Rect.fromCenter(
          center: Offset(0, topY + headR * 0.08),
          width: topW * 0.98,
          height: headR * 0.44,
        );
        canvas.drawOval(
          topOval,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _lighten(persona.headgear, 0.26),
                _darken(persona.headgear, 0.10),
              ],
            ).createShader(topOval),
        );
        canvas.drawOval(
          topOval,
          Paint()
            ..color = _darken(persona.headgear, 0.22).withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );

        // Bottom rim (elliptical ring).
        final Rect rimOuter = Rect.fromCenter(
          center: Offset(0, rimY),
          width: rimW,
          height: headR * 0.54,
        );
        final Rect rimInner = Rect.fromCenter(
          center: Offset(0, rimY - headR * 0.04),
          width: rimW * 0.78,
          height: headR * 0.36,
        );
        final Path rimRing = Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(rimOuter)
          ..addOval(rimInner);
        canvas.drawPath(
          rimRing,
          Paint()..color = _darken(persona.headgear, 0.06),
        );
        canvas.drawOval(
          rimInner,
          Paint()..color = const Color(0xFF121214).withValues(alpha: 0.30),
        );

        // Subtle vertical ribs.
        final Paint rib = Paint()
          ..color = Colors.white.withValues(alpha: 0.14)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        for (int i = -3; i <= 3; i++) {
          final double t = i / 3.0;
          final double x = t * rimW * 0.22;
          canvas.drawLine(Offset(x, topY + headR * 0.22), Offset(x, rimY - headR * 0.10), rib);
        }

        // Red label patch (accent) on the front.
        final RRect label = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, topY + (rimY - topY) * 0.62),
            width: headR * 1.18,
            height: headR * 0.62,
          ),
          Radius.circular(headR * 0.16),
        );
        canvas.drawRRect(label, Paint()..color = persona.headgearAccent);
        // Thin white stripes to hint at branding without copying any logo.
        final Paint stripe = Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..strokeWidth = 2.0;
        for (int i = -2; i <= 2; i++) {
          final double x = label.center.dx + i * headR * 0.18;
          canvas.drawLine(Offset(x, label.top + headR * 0.10), Offset(x, label.bottom - headR * 0.10),
              stripe..color = stripe.color.withValues(alpha: i.isEven ? 0.55 : 0.30));
        }

        // Side rivets.
        final Paint rivet = Paint()..color = _darken(persona.headgear, 0.25).withValues(alpha: 0.25);
        final double rivetY = topY + (rimY - topY) * 0.38;
        canvas.drawCircle(Offset(-rimW * 0.40, rivetY), headR * 0.05, rivet);
        canvas.drawCircle(Offset(rimW * 0.40, rivetY), headR * 0.05, rivet);

        // Light grime speckles for a more "real" bucket.
        final Paint speck = Paint()..color = const Color(0xFF121214).withValues(alpha: 0.06);
        for (final o in <Offset>[
          Offset(-headR * 0.62, topY + headR * 0.52),
          Offset(headR * 0.34, topY + headR * 0.60),
          Offset(-headR * 0.18, topY + headR * 0.92),
          Offset(headR * 0.52, topY + headR * 1.08),
          Offset(-headR * 0.44, topY + headR * 1.18),
        ]) {
          canvas.drawCircle(o, headR * 0.045, speck);
        }
        break;
      case _HatStyle.mouse:
        // Deadmau5-style helmet (covers the face).
        final Offset c = Offset(0, -headR * 0.10);
        final double r = headR * 1.30;
        final Rect main = Rect.fromCircle(center: c, radius: r);
        final Rect earL =
            Rect.fromCircle(center: Offset(-headR * 1.05, -headR * 1.10), radius: headR * 0.62);
        final Rect earR =
            Rect.fromCircle(center: Offset(headR * 1.05, -headR * 1.10), radius: headR * 0.62);
        final Path helmetPath = Path()
          ..addOval(main)
          ..addOval(earL)
          ..addOval(earR);
        final Paint outline = Paint()
          ..color = _lighten(persona.headgear, 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4;

        canvas.drawPath(helmetPath, hat);

        // Extra color for the Europe (deadmau5) skin.
        if (style == DealerAvatarStyle.europe) {
          const palette = <Color>[
            Color(0xFF00D1FF), // cyan
            Color(0xFFFFD166), // yellow
            Color(0xFF9B5DE5), // purple
            Color(0xFF00F5D4), // mint
            Color(0xFFFF006E), // hot pink
          ];
          canvas.save();
          canvas.clipPath(helmetPath);

          for (int i = -4; i <= 4; i++) {
            final Color col = palette[(i + 4) % palette.length];
            final Paint stripe = Paint()
              ..color = col.withValues(alpha: 0.22)
              ..strokeWidth = headR * 0.30
              ..strokeCap = StrokeCap.round;
            canvas.drawLine(
              Offset(-headR * 2.10 + i * headR * 0.34, -headR * 1.90),
              Offset(headR * 2.10 + i * headR * 0.34, headR * 1.70),
              stripe,
            );
          }

          final List<Offset> dots = <Offset>[
            Offset(-headR * 0.62, -headR * 0.78),
            Offset(headR * 0.64, -headR * 0.70),
            Offset(-headR * 0.18, -headR * 0.18),
            Offset(headR * 0.28, headR * 0.42),
            Offset(-headR * 0.72, headR * 0.54),
          ];
          for (int i = 0; i < dots.length; i++) {
            final Color col = palette[(i + 2) % palette.length];
            canvas.drawCircle(
              dots[i],
              headR * 0.12,
              Paint()..color = col.withValues(alpha: 0.32),
            );
          }
          canvas.restore();
        }

        canvas.drawPath(helmetPath, outline);

        // Eyes on the helmet.
        final Paint eye = Paint()..color = persona.headgearAccent;
        canvas.drawCircle(Offset(-headR * 0.46, -headR * 0.06), headR * 0.30, eye);
        canvas.drawCircle(Offset(headR * 0.46, -headR * 0.06), headR * 0.30, eye);
        canvas.drawCircle(
          Offset(-headR * 0.54, -headR * 0.14),
          headR * 0.08,
          Paint()..color = Colors.white.withValues(alpha: 0.65),
        );
        canvas.drawCircle(
          Offset(headR * 0.38, -headR * 0.14),
          headR * 0.08,
          Paint()..color = Colors.white.withValues(alpha: 0.65),
        );
        break;
      case _HatStyle.keffiyeh:
        // Ghutra + agal (stylized).
        final Path scarf = Path()
          ..moveTo(-headR * 1.05, -headR * 0.85)
          ..quadraticBezierTo(0, -headR * 1.72, headR * 1.05, -headR * 0.85)
          ..quadraticBezierTo(headR * 0.98, -headR * 0.05, headR * 0.55, headR * 0.18)
          ..quadraticBezierTo(0, headR * 0.38, -headR * 0.55, headR * 0.18)
          ..quadraticBezierTo(-headR * 0.98, -headR * 0.05, -headR * 1.05, -headR * 0.85)
          ..close();
        canvas.drawPath(scarf, hat);

        // Pattern (Arabia: red/white checkered).
        final bool isArabia = style == DealerAvatarStyle.arabia;
        final Color patternColor =
            isArabia ? const Color(0xFFE1202E) : trim.color;
        final Paint pattern = Paint()
          ..color = patternColor.withValues(alpha: isArabia ? 0.22 : 0.10)
          ..strokeWidth = 1.6;
        canvas.save();
        canvas.clipPath(scarf);
        final Rect b = scarf.getBounds();
        final double step = headR * (isArabia ? 0.18 : 0.24);
        for (double x = b.left; x <= b.right; x += step) {
          canvas.drawLine(Offset(x, b.top), Offset(x, b.bottom), pattern);
        }
        for (double y = b.top; y <= b.bottom; y += step) {
          canvas.drawLine(Offset(b.left, y), Offset(b.right, y), pattern);
        }
        canvas.restore();

        // Agal ring.
        final Paint agal = Paint()
          ..color = trim.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = headR * 0.18;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, -headR * 0.98),
            width: headR * 1.70,
            height: headR * 0.50,
          ),
          agal,
        );
        break;
      case _HatStyle.helmet:
        // Racing helmet (stylized).
        final Offset c = Offset(0, -headR * 0.05);
        final Rect shellRect = Rect.fromCenter(
          center: c,
          width: headR * 2.35,
          height: headR * 2.70,
        );
        final RRect shell =
            RRect.fromRectAndRadius(shellRect, Radius.circular(headR * 0.95));

        final Paint shellPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _lighten(persona.headgear, 0.24),
              persona.headgear,
              _darken(persona.headgear, 0.18),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(shellRect);
        canvas.drawRRect(shell, shellPaint);

        // Chin guard.
        final Rect chinRect = Rect.fromCenter(
          center: Offset(0, headR * 0.78),
          width: headR * 1.70,
          height: headR * 1.05,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(chinRect, Radius.circular(headR * 0.58)),
          Paint()..color = _darken(persona.headgear, 0.18),
        );

        // Accent stripe.
        final Rect stripeRect = Rect.fromCenter(
          center: Offset(0, -headR * 0.70),
          width: headR * 0.28,
          height: headR * 2.20,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(stripeRect, Radius.circular(headR * 0.16)),
          Paint()..color = persona.headgearAccent.withValues(alpha: 0.55),
        );

        // Visor.
        final Rect visorRect = Rect.fromCenter(
          center: Offset(0, -headR * 0.12),
          width: headR * 1.68,
          height: headR * 0.88,
        );
        final RRect visor =
            RRect.fromRectAndRadius(visorRect, Radius.circular(headR * 0.34));
        canvas.drawRRect(
          visor,
          Paint()..color = const Color(0xFF121214).withValues(alpha: 0.68),
        );
        canvas.drawRRect(
          visor,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
        canvas.drawArc(
          visorRect.deflate(headR * 0.14),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );
        break;
      case _HatStyle.boxingHelmet:
        // Boxing head-gear (open face).
        final Rect outer = Rect.fromCenter(
          center: Offset(0, -headR * 0.10),
          width: headR * 2.55,
          height: headR * 2.78,
        );
        final Rect opening = Rect.fromCenter(
          center: Offset(0, -headR * 0.02),
          width: headR * 1.90,
          height: headR * 2.18,
        );
        final Path ring = Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(outer)
          ..addOval(opening);

        final Paint pad = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _lighten(persona.headgear, 0.20),
              persona.headgear,
              _darken(persona.headgear, 0.18),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(outer);
        canvas.drawPath(ring, pad);

        canvas.drawPath(
          ring,
          Paint()
            ..color = persona.headgearAccent.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );

        // Brow pad (extra thickness).
        canvas.save();
        canvas.clipPath(ring);
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(0, -headR * 0.74),
            width: headR * 2.20,
            height: headR * 1.35,
          ),
          math.pi,
          -math.pi,
          false,
          Paint()
            ..color = _darken(persona.headgear, 0.10)
            ..style = PaintingStyle.stroke
            ..strokeWidth = headR * 0.30
            ..strokeCap = StrokeCap.round,
        );
        canvas.restore();

        // Chin strap.
        final RRect strap = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, headR * 1.16),
            width: headR * 1.25,
            height: headR * 0.24,
          ),
          Radius.circular(headR * 0.18),
        );
        canvas.drawRRect(strap, Paint()..color = _darken(persona.headgear, 0.22));
        canvas.drawRRect(
          strap,
          Paint()
            ..color = persona.headgearAccent.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
        break;
    }
  }

  void _paintFaceDetails(Canvas canvas, Size size, double headR) {
    if (persona.hatStyle == _HatStyle.mouse) return;
    if (persona.hatStyle == _HatStyle.helmet) return;
    if (style == DealerAvatarStyle.northAmerica) {
      // Mask-like face (Buckethead).
      final Paint eyeHole = Paint()..color = const Color(0xFF121214);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-headR * 0.30, -headR * 0.10),
          width: headR * 0.26,
          height: headR * 0.20,
        ),
        eyeHole,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(headR * 0.30, -headR * 0.10),
          width: headR * 0.26,
          height: headR * 0.20,
        ),
        eyeHole,
      );

      final Paint slit = Paint()
        ..color = const Color(0xFF121214).withValues(alpha: 0.55)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(-headR * 0.20, headR * 0.46),
        Offset(headR * 0.20, headR * 0.46),
        slit,
      );
      return;
    }

    final double eyeX = style == DealerAvatarStyle.china
        ? headR * 0.34
        : (style == DealerAvatarStyle.asia ? headR * 0.29 : headR * 0.30);
    final double eyeY = -headR * 0.10;
    final double eyeR = style == DealerAvatarStyle.china ? headR * 0.085 : headR * 0.10;

    final Paint eye = Paint()..color = const Color(0xFF121214);
    canvas.drawCircle(Offset(-eyeX, eyeY), eyeR, eye);
    canvas.drawCircle(Offset(eyeX, eyeY), eyeR, eye);
    final Paint eyeGlint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(
      Offset(-eyeX - eyeR * 0.35, eyeY - eyeR * 0.35),
      eyeR * 0.40,
      eyeGlint,
    );
    canvas.drawCircle(
      Offset(eyeX - eyeR * 0.35, eyeY - eyeR * 0.35),
      eyeR * 0.40,
      eyeGlint,
    );

    if (style == DealerAvatarStyle.asia || style == DealerAvatarStyle.china) {
      final Paint brow = Paint()
        ..color = _darken(persona.hair, 0.10)
            .withValues(alpha: style == DealerAvatarStyle.asia ? 0.38 : 0.70)
        ..strokeWidth = style == DealerAvatarStyle.china ? 3.2 : 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final double browY =
          style == DealerAvatarStyle.china ? -headR * 0.34 : -headR * 0.30;
      final double browW =
          style == DealerAvatarStyle.china ? headR * 0.70 : headR * 0.58;

      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(-eyeX, browY),
          width: browW,
          height: headR * 0.26,
        ),
        math.pi,
        math.pi,
        false,
        brow,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(eyeX, browY),
          width: browW,
          height: headR * 0.26,
        ),
        math.pi,
        math.pi,
        false,
        brow,
      );
    }

    final Paint nose = Paint()
      ..color = _darken(persona.skin, 0.18)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, -headR * 0.02),
      Offset(0, headR * 0.22),
      nose,
    );

    final Paint mouth = Paint()
      ..color = _darken(persona.skin, 0.28)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, headR * 0.42),
        width: headR * 0.70,
        height: headR * 0.45,
      ),
      0,
      math.pi,
      false,
      mouth,
    );

    if (persona.isFemale) {
      final Paint lash = Paint()
        ..color = const Color(0xFF1A1A1F)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          Offset(-headR * 0.42, -headR * 0.20),
          Offset(-headR * 0.34, -headR * 0.24),
          lash);
      canvas.drawLine(
          Offset(headR * 0.34, -headR * 0.24),
          Offset(headR * 0.42, -headR * 0.20),
          lash);

      final Paint lip = Paint()
        ..color = const Color(0xFFB03A48).withValues(alpha: 0.65)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(0, headR * 0.44),
          width: headR * 0.72,
          height: headR * 0.34,
        ),
        0,
        math.pi,
        false,
        lip,
      );
    }

    _paintGlasses(canvas, headR);
    _paintFacialHair(canvas, headR);
  }

  void _paintGlasses(Canvas canvas, double headR) {
    if (persona.glassesStyle == _GlassesStyle.none) return;
    final Paint g = Paint()
      ..color = _darken(persona.hair, 0.10)
      ..strokeWidth = style == DealerAvatarStyle.marathaEmpire ? 2.8 : 2.2
      ..style = PaintingStyle.stroke;
    final Paint lens = Paint()
      ..color = const Color(0xFF121214).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final double y = -headR * 0.10;
    switch (persona.glassesStyle) {
      case _GlassesStyle.none:
        return;
      case _GlassesStyle.round:
        canvas.drawCircle(Offset(-headR * 0.30, y), headR * 0.22, g);
        canvas.drawCircle(Offset(headR * 0.30, y), headR * 0.22, g);
        break;
      case _GlassesStyle.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(-headR * 0.30, y),
              width: headR * 0.48,
              height: headR * 0.36,
            ),
            Radius.circular(headR * 0.10),
          ),
          g,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(headR * 0.30, y),
              width: headR * 0.48,
              height: headR * 0.36,
            ),
            Radius.circular(headR * 0.10),
          ),
          g,
        );
        break;
      case _GlassesStyle.aviator:
        final double lensW =
            style == DealerAvatarStyle.marathaEmpire ? headR * 0.66 : headR * 0.52;
        final double lensH =
            style == DealerAvatarStyle.marathaEmpire ? headR * 0.50 : headR * 0.40;
        final double lensX =
            style == DealerAvatarStyle.marathaEmpire ? headR * 0.33 : headR * 0.30;
        final double lensR =
            style == DealerAvatarStyle.marathaEmpire ? headR * 0.26 : headR * 0.22;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(-lensX, y),
              width: lensW,
              height: lensH,
            ),
            Radius.circular(lensR),
          ),
          lens,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(lensX, y),
              width: lensW,
              height: lensH,
            ),
            Radius.circular(lensR),
          ),
          lens,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(-lensX, y),
              width: lensW,
              height: lensH,
            ),
            Radius.circular(lensR),
          ),
          g,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(lensX, y),
              width: lensW,
              height: lensH,
            ),
            Radius.circular(lensR),
          ),
          g,
        );
        break;
    }

    canvas.drawLine(Offset(-headR * 0.06, y), Offset(headR * 0.06, y), g);
  }

  void _paintFacialHair(Canvas canvas, double headR) {
    final Color baseFacialHair =
        style == DealerAvatarStyle.mysore ? persona.hair : _darken(persona.hair, 0.10);
    final Paint hair = Paint()..color = baseFacialHair;
    switch (persona.facialHair) {
      case _FacialHair.none:
        return;
      case _FacialHair.moustache:
        final RRect moustache = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, headR * 0.22),
            width: headR * 0.70,
            height: headR * 0.18,
          ),
          Radius.circular(headR * 0.10),
        );
        canvas.drawRRect(moustache, hair);

        // Salt-and-pepper moustache for the Baroda Gandhi skin.
        if (style == DealerAvatarStyle.baroda) {
          final Paint pepper = Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round;
          for (final dx in <double>[-0.26, -0.12, 0.0, 0.12, 0.26]) {
            canvas.drawLine(
              Offset(dx * headR, headR * 0.16),
              Offset(dx * headR, headR * 0.28),
              pepper,
            );
          }
        }

        // White "french cut" beard for Mysore (moustache + goatee).
        if (style == DealerAvatarStyle.mysore) {
          final Path goatee = Path()
            ..moveTo(-headR * 0.14, headR * 0.36)
            ..lineTo(headR * 0.14, headR * 0.36)
            ..lineTo(headR * 0.20, headR * 0.66)
            ..quadraticBezierTo(0, headR * 0.84, -headR * 0.20, headR * 0.66)
            ..close();
          canvas.drawPath(goatee, hair);
        }
        break;
      case _FacialHair.beard:
        final bool smallerBeard = style == DealerAvatarStyle.arabia;
        final Rect beard = Rect.fromCenter(
          center: Offset(0, headR * (smallerBeard ? 0.48 : 0.55)),
          width: headR * (smallerBeard ? 0.98 : 1.15),
          height: headR * (smallerBeard ? 0.62 : 0.85),
        );
        final Color beardColor = style == DealerAvatarStyle.newDelhi
            ? Colors.white.withValues(alpha: 0.90)
            : hair.color.withValues(alpha: 0.95);
        canvas.drawRRect(
          RRect.fromRectAndRadius(beard, Radius.circular(headR * 0.45)),
          Paint()..color = beardColor,
        );
        break;
      case _FacialHair.goatee:
        final Path g = Path()
          ..moveTo(-headR * 0.12, headR * 0.36)
          ..lineTo(headR * 0.12, headR * 0.36)
          ..lineTo(headR * 0.18, headR * 0.62)
          ..quadraticBezierTo(0, headR * 0.78, -headR * 0.18, headR * 0.62)
          ..close();
        canvas.drawPath(g, hair);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _KingdomDealerPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.style != style ||
        oldDelegate.felt != felt ||
        oldDelegate.railLight != railLight ||
        oldDelegate.railMid != railMid ||
        oldDelegate.railDark != railDark;
  }
}

/// Helper used by the Renoir dealer widgets to render custom skins.
Widget buildDealerSkinAvatar({
  required DealerAvatarStyle style,
  required double height,
  required double pose,
  required SlashJacketTone jacketTone,
  Color? feltColor,
  Color? railLightColor,
  Color? railMidColor,
  Color? railDarkColor,
}) {
  switch (style) {
    case DealerAvatarStyle.slash:
      return SlashAvatar(
        height: height,
        pose: pose,
        jacketTone: jacketTone,
        feltColor: feltColor,
        railLightColor: railLightColor,
        railMidColor: railMidColor,
        railDarkColor: railDarkColor,
      );
    case DealerAvatarStyle.classic:
      return const SizedBox.shrink();
    default:
      return KingdomDealerAvatar(
        style: style,
        height: height,
        pose: pose,
        jacketTone: jacketTone,
        feltColor: feltColor,
        railLightColor: railLightColor,
        railMidColor: railMidColor,
        railDarkColor: railDarkColor,
      );
  }
}

class _JacketPalette {
  const _JacketPalette({
    required this.top,
    required this.bottom,
    required this.lapel,
    required this.lapelEdge,
    required this.button,
    required this.sleeveTop,
    required this.sleeveBottom,
  });

  final Color top;
  final Color bottom;
  final Color lapel;
  final Color lapelEdge;
  final Color button;
  final Color sleeveTop;
  final Color sleeveBottom;
}

_JacketPalette _jacketPaletteForTone(SlashJacketTone tone) {
  switch (tone) {
    case SlashJacketTone.darkBlue:
      return const _JacketPalette(
        top: Color(0xFF0F2547),
        bottom: Color(0xFF070F24),
        lapel: Color(0xFF050C1C),
        lapelEdge: Color(0xFF2B4D7A),
        button: Color(0xFF0A142B),
        sleeveTop: Color(0xFF0F2547),
        sleeveBottom: Color(0xFF070F24),
      );
    case SlashJacketTone.lightBlue:
      return const _JacketPalette(
        top: Color(0xFF356BB8),
        bottom: Color(0xFF1A3566),
        lapel: Color(0xFF132E5A),
        lapelEdge: Color(0xFF8FB6FF),
        button: Color(0xFF162A50),
        sleeveTop: Color(0xFF356BB8),
        sleeveBottom: Color(0xFF1A3566),
      );
    case SlashJacketTone.white:
      return const _JacketPalette(
        top: Color(0xFFF4F4F8),
        bottom: Color(0xFFD6D6DE),
        lapel: Color(0xFFE4E4EE),
        lapelEdge: Color(0xFFFFFFFF),
        button: Color(0xFFB7B7C2),
        sleeveTop: Color(0xFFF4F4F8),
        sleeveBottom: Color(0xFFD6D6DE),
      );
    case SlashJacketTone.beige:
      return const _JacketPalette(
        top: Color(0xFFEBDCC7),
        bottom: Color(0xFFCBB08A),
        lapel: Color(0xFFCEB081),
        lapelEdge: Color(0xFFF3E5C9),
        button: Color(0xFFB8945D),
        sleeveTop: Color(0xFFEBDCC7),
        sleeveBottom: Color(0xFFC3A476),
      );
    case SlashJacketTone.wineRed:
      return const _JacketPalette(
        top: Color(0xFF5A1A24),
        bottom: Color(0xFF2B070C),
        lapel: Color(0xFF2D080D),
        lapelEdge: Color(0xFF8C3642),
        button: Color(0xFF200407),
        sleeveTop: Color(0xFF5A1A24),
        sleeveBottom: Color(0xFF2B070C),
      );
    case SlashJacketTone.khakhi:
      return const _JacketPalette(
        top: Color(0xFFC2B280),
        bottom: Color(0xFF8C7A4B),
        lapel: Color(0xFF9A8856),
        lapelEdge: Color(0xFFE1D5AA),
        button: Color(0xFF6E603B),
        sleeveTop: Color(0xFFC2B280),
        sleeveBottom: Color(0xFF8C7A4B),
      );
    case SlashJacketTone.olive:
      return const _JacketPalette(
        top: Color(0xFF556B2F),
        bottom: Color(0xFF2D3918),
        lapel: Color(0xFF233010),
        lapelEdge: Color(0xFF82995A),
        button: Color(0xFF1E2A0D),
        sleeveTop: Color(0xFF556B2F),
        sleeveBottom: Color(0xFF2D3918),
      );
    case SlashJacketTone.black:
    default:
      return const _JacketPalette(
        top: Color(0xFF15161C),
        bottom: Color(0xFF090A0F),
        lapel: Color(0xFF050608),
        lapelEdge: Color(0xFF2E3139),
        button: Color(0xFF0B0D12),
        sleeveTop: Color(0xFF151722),
        sleeveBottom: Color(0xFF06070D),
      );
  }
}

/// CustomPaint avatar inspired by Slash (Guns N' Roses).
///
/// This variant seats him behind the dealer position, suited in a black tuxedo
/// with cards fanned between his hands. A subtle looping animation makes the
/// hands breathe as if mid-shuffle while the upper body sways gently.
class SlashAvatar extends StatelessWidget {
  final double height;
  final double pose; // 0 → idle; [0, 1] maps to a guitar swing cycle.
  final SlashJacketTone jacketTone;
  final Color? feltColor;
  final Color? railLightColor;
  final Color? railMidColor;
  final Color? railDarkColor;

  const SlashAvatar({
    super.key,
    required this.height,
    required this.pose,
    this.jacketTone = SlashJacketTone.black,
    this.feltColor,
    this.railLightColor,
    this.railMidColor,
    this.railDarkColor,
  });

  @override
  Widget build(BuildContext context) {
    final double width = height * 0.72;
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _SlashAvatarPainter(
          pose,
          jacketTone,
          feltColor: feltColor,
          railLightColor: railLightColor,
          railMidColor: railMidColor,
          railDarkColor: railDarkColor,
        ),
      ),
    );
  }

}

/// Stylized Buckethead-inspired avatar.
///
/// Shares the same pose semantics as [SlashAvatar] so the existing shuffle
/// timeline can drive a gentle sway/breathing loop.
class BucketheadAvatar extends StatelessWidget {
  final double height;
  final double pose; // 0 → idle; [0, 1] maps to a guitar swing cycle.
  final Color? feltColor;
  final Color? railLightColor;
  final Color? railMidColor;
  final Color? railDarkColor;

  const BucketheadAvatar({
    super.key,
    required this.height,
    required this.pose,
    this.feltColor,
    this.railLightColor,
    this.railMidColor,
    this.railDarkColor,
  });

  @override
  Widget build(BuildContext context) {
    final double width = height * 0.72;
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _BucketheadPainter(
          pose,
          feltColor: feltColor,
          railLightColor: railLightColor,
          railMidColor: railMidColor,
          railDarkColor: railDarkColor,
        ),
      ),
    );
  }
}

/// Stylized Dharmendra-inspired avatar (tuxedo, confident moustache).
///
/// Uses the same pose semantics as [SlashAvatar] so shuffle timing stays in sync.
class DharmaAvatar extends StatelessWidget {
  final double height;
  final double pose;
  final Color? feltColor;
  final Color? railLightColor;
  final Color? railMidColor;
  final Color? railDarkColor;

  const DharmaAvatar({
    super.key,
    required this.height,
    required this.pose,
    this.feltColor,
    this.railLightColor,
    this.railMidColor,
    this.railDarkColor,
  });

  @override
  Widget build(BuildContext context) {
    final double width = height * 0.72;
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _DharmaPainter(
          pose,
          feltColor: feltColor,
          railLightColor: railLightColor,
          railMidColor: railMidColor,
          railDarkColor: railDarkColor,
        ),
      ),
    );
  }
}

/// Stylized Jimi Hendrix-inspired avatar ("Redrix") with a bold tux + afro/hat.
///
/// Shares pose semantics with Slash/Buckethead/Dharma for shuffle timing.
class RedrixAvatar extends StatelessWidget {
  final double height;
  final double pose;
  final Color? feltColor;
  final Color? railLightColor;
  final Color? railMidColor;
  final Color? railDarkColor;

  const RedrixAvatar({
    super.key,
    required this.height,
    required this.pose,
    this.feltColor,
    this.railLightColor,
    this.railMidColor,
    this.railDarkColor,
  });

  @override
  Widget build(BuildContext context) {
    final double width = height * 0.72;
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _RedrixPainter(
          pose,
          feltColor: feltColor,
          railLightColor: railLightColor,
          railMidColor: railMidColor,
          railDarkColor: railDarkColor,
        ),
      ),
    );
  }
}

/// Stylized Avicii-inspired avatar ("Revicii") with a clean tux + cap/earphones vibe.
///
/// Shares pose semantics with other custom avatars for shuffle timing.
class ReviciiAvatar extends StatelessWidget {
  final double height;
  final double pose;
  final Color? feltColor;
  final Color? railLightColor;
  final Color? railMidColor;
  final Color? railDarkColor;

  const ReviciiAvatar({
    super.key,
    required this.height,
    required this.pose,
    this.feltColor,
    this.railLightColor,
    this.railMidColor,
    this.railDarkColor,
  });

  @override
  Widget build(BuildContext context) {
    final double width = height * 0.72;
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _ReviciiPainter(
          pose,
          feltColor: feltColor,
          railLightColor: railLightColor,
          railMidColor: railMidColor,
          railDarkColor: railDarkColor,
        ),
      ),
    );
  }
}

class _SlashAvatarPainter extends CustomPainter {
  final double pose;
  final SlashJacketTone tone;
  final _JacketPalette palette;
  final Color felt;
  final Color railLight;
  final Color railMid;
  final Color railDark;

  _SlashAvatarPainter(
    this.pose,
    this.tone, {
    Color? feltColor,
    Color? railLightColor,
    Color? railMidColor,
    Color? railDarkColor,
  })  : palette = _jacketPaletteForTone(tone),
        felt = feltColor ?? const Color(0xFF13321E),
        railLight = railLightColor ?? const Color(0xFF5A241C),
        railMid = railMidColor ?? const Color(0xFF3E140F),
        railDark = railDarkColor ?? const Color(0xFF2C0E0B);

  @override
  void paint(Canvas canvas, Size size) {
    final double phase = pose * 2 * math.pi;
    final double sway = math.sin(phase);
    final double lean = sway * 0.05;
    final double liftPulse = (math.sin(phase - math.pi / 2) + 1) / 2;

    const double shuffleEnd = 0.55;
    const double dealStart = 0.60;
    double shufflePhase = 0.0;
    if (pose < shuffleEnd) {
      shufflePhase = (pose / shuffleEnd).clamp(0.0, 1.0);
    } else if (pose < dealStart) {
      shufflePhase =
          1.0 - ((pose - shuffleEnd) / (dealStart - shuffleEnd)).clamp(0.0, 1.0);
    }
    final double dealPhase = pose <= dealStart
        ? 0.0
        : ((pose - dealStart) / (1.0 - dealStart)).clamp(0.0, 1.0);

    final Offset seatCenter = Offset(size.width / 2, size.height * _kDealerSeatCenterY);

    _paintGlow(canvas, size, seatCenter);
    _paintChair(canvas, size);
    _paintBody(canvas, size, lean);
    _paintTable(canvas, size);
    _paintForearmsOnTable(canvas, size, shufflePhase, liftPulse);
    _paintHandsOverTable(canvas, size, shufflePhase, dealPhase);
    _paintHead(canvas, size, lean);
  }

  void _paintGlow(Canvas canvas, Size size, Offset center) {
    // Intentionally no glow to avoid the oval behind the dealer.
  }

  void _paintChair(Canvas canvas, Size size) {
    // Chair removed to avoid the wooden block above the rail.
  }

  void _paintTable(Canvas canvas, Size size) {
    // Skip Slash's painted table/rail so it doesn't obscure the UI logo.
  }

  void _paintBody(Canvas canvas, Size size, double lean) {
    final double bodyW = size.width * 0.48;
    final double bodyH = size.height * 0.36;
    final double bodyTop = size.height * 0.38;
    final double tableY = size.height * 0.64;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, tableY));

    canvas.translate(size.width / 2, bodyTop + bodyH / 2);
    canvas.rotate(lean);

    // Neck (helps break the “floating head” look and softens geometry)
    final Paint neckPaint = Paint()..color = const Color(0xFFE8C7A3);
    final RRect neck = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -bodyH * 0.60),
        width: bodyW * 0.16,
        height: bodyH * 0.32,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(neck, neckPaint);
    canvas.drawRRect(
      neck.deflate(4),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.20),
            Colors.black.withOpacity(0.12),
          ],
        ).createShader(neck.outerRect),
    );

    final Rect torsoRect = Rect.fromCenter(
      center: Offset.zero,
      width: bodyW,
      height: bodyH,
    );
    final Paint jacket = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          palette.top,
          palette.bottom,
        ],
      ).createShader(torsoRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(28)),
      jacket,
    );

    // Sculpted shoulders/upper arms (less balloon-like than the earlier ovals).
    final Paint shoulderPaintLeft = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          palette.sleeveTop,
          palette.sleeveBottom,
        ],
      ).createShader(
        Rect.fromCenter(
          center: Offset(-bodyW * 0.58, -bodyH * 0.05),
          width: bodyW * 0.45,
          height: bodyH * 0.55,
        ),
      );
    final Path leftShoulder = Path()
      ..moveTo(-bodyW * 0.47, -bodyH * 0.34)
      ..quadraticBezierTo(-bodyW * 0.74, -bodyH * 0.32, -bodyW * 0.78, -bodyH * 0.08)
      ..quadraticBezierTo(-bodyW * 0.80, bodyH * 0.08, -bodyW * 0.60, bodyH * 0.18)
      ..quadraticBezierTo(-bodyW * 0.48, bodyH * 0.12, -bodyW * 0.44, -bodyH * 0.05)
      ..close();
    canvas.drawPath(leftShoulder, shoulderPaintLeft);
    canvas.drawPath(
      leftShoulder,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.black.withOpacity(0.10),
    );

    final Paint shoulderPaintRight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          palette.sleeveTop,
          palette.sleeveBottom,
        ],
      ).createShader(
        Rect.fromCenter(
          center: Offset(bodyW * 0.58, -bodyH * 0.05),
          width: bodyW * 0.45,
          height: bodyH * 0.55,
        ),
      );
    final Path rightShoulder = Path()
      ..moveTo(bodyW * 0.47, -bodyH * 0.34)
      ..quadraticBezierTo(bodyW * 0.74, -bodyH * 0.32, bodyW * 0.78, -bodyH * 0.08)
      ..quadraticBezierTo(bodyW * 0.80, bodyH * 0.08, bodyW * 0.60, bodyH * 0.18)
      ..quadraticBezierTo(bodyW * 0.48, bodyH * 0.12, bodyW * 0.44, -bodyH * 0.05)
      ..close();
    canvas.drawPath(rightShoulder, shoulderPaintRight);
    canvas.drawPath(
      rightShoulder,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.black.withOpacity(0.10),
    );

    final RRect torsoInner = RRect.fromRectAndRadius(
      torsoRect.deflate(bodyW * 0.10),
      const Radius.circular(24),
    );
    final Paint torsoHighlight = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.35),
        radius: 1.0,
        colors: [
          Colors.white.withOpacity(0.20),
          Colors.transparent,
        ],
      ).createShader(torsoRect);
    canvas.drawRRect(torsoInner, torsoHighlight);

    final Paint torsoContour = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withOpacity(0.18),
          Colors.transparent,
          Colors.black.withOpacity(0.18),
        ],
      ).createShader(torsoRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(28)),
      torsoContour,
    );

    final Rect shirtRect = Rect.fromCenter(
      center: Offset(0, bodyH * 0.05),
      width: bodyW * 0.34,
      height: bodyH * 0.90,
    );
    final Paint shirt = Paint()..color = const Color(0xFFEDEDED);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shirtRect, const Radius.circular(16)),
      shirt,
    );

    final Paint lapel = Paint()..color = palette.lapel;
    final Path leftLapel = Path()
      ..moveTo(-bodyW * 0.44, -bodyH * 0.34)
      ..quadraticBezierTo(-bodyW * 0.30, -bodyH * 0.44, -bodyW * 0.18, -bodyH * 0.32)
      ..quadraticBezierTo(-bodyW * 0.05, -bodyH * 0.18, -bodyW * 0.08, -bodyH * 0.02)
      ..quadraticBezierTo(-bodyW * 0.10, bodyH * 0.18, -bodyW * 0.30, bodyH * 0.30)
      ..quadraticBezierTo(-bodyW * 0.44, bodyH * 0.18, -bodyW * 0.45, -bodyH * 0.02)
      ..close();
    final Path rightLapel = Path()
      ..moveTo(bodyW * 0.44, -bodyH * 0.34)
      ..quadraticBezierTo(bodyW * 0.30, -bodyH * 0.44, bodyW * 0.18, -bodyH * 0.32)
      ..quadraticBezierTo(bodyW * 0.05, -bodyH * 0.18, bodyW * 0.08, -bodyH * 0.02)
      ..quadraticBezierTo(bodyW * 0.10, bodyH * 0.18, bodyW * 0.30, bodyH * 0.30)
      ..quadraticBezierTo(bodyW * 0.44, bodyH * 0.18, bodyW * 0.45, -bodyH * 0.02)
      ..close();
    canvas.drawPath(leftLapel, lapel);
    canvas.drawPath(rightLapel, lapel);

    final Paint lapelEdge = Paint()
      ..color = palette.lapelEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(leftLapel, lapelEdge);
    canvas.drawPath(rightLapel, lapelEdge);

    final Paint bowTie = Paint()..color = const Color(0xFF11141C);
    final Path tie = Path()
      ..moveTo(-12, -bodyH * 0.15)
      ..quadraticBezierTo(-30, -bodyH * 0.24, -16, -bodyH * 0.30)
      ..quadraticBezierTo(-6, -bodyH * 0.18, 0, -bodyH * 0.20)
      ..quadraticBezierTo(6, -bodyH * 0.18, 16, -bodyH * 0.30)
      ..quadraticBezierTo(30, -bodyH * 0.24, 12, -bodyH * 0.15)
      ..quadraticBezierTo(6, -bodyH * 0.02, 0, -bodyH * 0.08)
      ..quadraticBezierTo(-6, -bodyH * 0.02, -12, -bodyH * 0.15)
      ..close();
    canvas.drawPath(tie, bowTie);

    final Paint buttons = Paint()
      ..color = palette.button
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 3; i++) {
      final double y = shirtRect.top + (i + 1) * (shirtRect.height / 4);
      canvas.drawCircle(Offset(0, y - shirtRect.center.dy), 3.2, buttons);
    }

    canvas.restore();
  }

  void _paintHead(Canvas canvas, Size size, double headTilt) {
    final Paint skin = Paint()..color = const Color(0xFFE8C7A3);
    final double headR = size.width * 0.16;
    final Offset headCenter = Offset(size.width / 2, size.height * 0.335);

    final Paint glasses = Paint()
      ..color = const Color(0xFFE65F2A)
      ..style = PaintingStyle.fill;
    final Paint frames = Paint()
      ..color = const Color(0xFFE6D29A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final Paint moustache = Paint()..color = const Color(0xFF4B2915);
    final Paint hatBrimPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF15161F),
          Color(0xFF05060A),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: size.width * 0.36));
    final Paint hatCrownPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF202231),
          Color(0xFF07080E),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: size.width * 0.25));

    canvas.save();
    canvas.translate(headCenter.dx, headCenter.dy);
    canvas.rotate(headTilt);

    // Hair halo
    final int segments = 36;
    final double baseR = headR * 1.22;
    final double amp = headR * 0.32;
    final List<Offset> curlsPts = [];
    for (int i = 0; i <= segments; i++) {
      final double t = i / segments;
      final double angle = t * math.pi * 2;
      final double wobble =
          0.5 + 0.5 * math.sin(angle * 3 + math.sin(angle * 1.7));
      final double radius = baseR + amp * wobble;
      final double dx = radius * math.cos(angle);
      final double dy = radius * math.sin(angle) - headR * 0.10;
      curlsPts.add(Offset(dx, dy));
    }

    final Path curls = Path()..moveTo(curlsPts.first.dx, curlsPts.first.dy);
    for (int i = 1; i < curlsPts.length; i++) {
      final Offset prev = curlsPts[i - 1];
      final Offset curr = curlsPts[i];
      final Offset mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      curls.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    final Offset last = curlsPts[curlsPts.length - 1];
    final Offset first = curlsPts.first;
    final Offset closingMid =
        Offset((last.dx + first.dx) / 2, (last.dy + first.dy) / 2);
    curls.quadraticBezierTo(last.dx, last.dy, closingMid.dx, closingMid.dy);
    curls.close();

    final Rect hairBounds = curls.getBounds().inflate(headR * 0.10);
    final Paint hairFill = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.35),
        radius: 1.3,
        colors: const [
          Color(0xFF2A170A),
          Color(0xFF0B0502),
        ],
      ).createShader(hairBounds);
    canvas.drawPath(curls, hairFill);
    final Paint hairStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = headR * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0x66000000),
          Color(0x00000000),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(0, -headR * 0.10),
          radius: baseR + amp,
        ),
      );
    canvas.drawPath(
      curls,
      hairStroke,
    );

    // Ringlet curls hugging the cheeks (distinct coils rather than smooth curves).
    void drawRinglets(bool left) {
      final double dir = left ? -1.0 : 1.0;
      final List<Offset> centers = [
        Offset(dir * headR * 1.10, headR * 0.10),
        Offset(dir * headR * 1.28, headR * 0.48),
        Offset(dir * headR * 1.04, headR * 0.82),
        Offset(dir * headR * 1.22, headR * 1.12),
      ];
      final double baseRadius = headR * 0.34;

      for (int i = 0; i < centers.length; i++) {
        final double scale = 1.0 - i * 0.08;
        final double radius = baseRadius * scale;
        final Offset center = centers[i];
        final Rect bounds = Rect.fromCircle(center: center, radius: radius);

        final Paint ringFill = Paint()
          ..shader = RadialGradient(
            center: left ? const Alignment(0.2, -0.3) : const Alignment(-0.2, -0.3),
            radius: 1.05,
            colors: const [
              Color(0xFF221107),
              Color(0xFF050201),
            ],
          ).createShader(bounds);
        canvas.drawOval(bounds, ringFill);

        canvas.drawOval(
          bounds.deflate(headR * 0.04),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Color(0x22FFFFFF),
                Color(0x00000000),
              ],
            ).createShader(bounds),
        );

        final Paint rim = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = headR * 0.11
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0x33000000),
              Color(0x00000000),
            ],
          ).createShader(bounds);
        canvas.drawArc(bounds, left ? math.pi * 0.25 : -math.pi * 1.25, math.pi * 0.90, false, rim);
      }
    }

    drawRinglets(true);
    drawRinglets(false);

    // Face
    canvas.drawOval(Rect.fromCircle(center: Offset.zero, radius: headR), skin);
    canvas.drawOval(
      Rect.fromCircle(center: Offset(0, -headR * 0.02), radius: headR * 0.88),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(0.22),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: headR)),
    );

    // Sunglasses
    final Rect lensLeft = Rect.fromCenter(
      center: Offset(-headR * 0.45, -headR * 0.15),
      width: headR * 0.95,
      height: headR * 0.55,
    );
    final Rect lensRight = Rect.fromCenter(
      center: Offset(headR * 0.45, -headR * 0.15),
      width: headR * 0.95,
      height: headR * 0.55,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(lensLeft, const Radius.circular(8)), glasses);
    canvas.drawRRect(RRect.fromRectAndRadius(lensRight, const Radius.circular(8)), glasses);
    canvas.drawLine(lensLeft.centerRight, lensRight.centerLeft, frames);
    canvas.drawRect(
      Rect.fromCenter(center: lensLeft.centerLeft, width: 3, height: 8),
      frames,
    );
    canvas.drawRect(
      Rect.fromCenter(center: lensRight.centerRight, width: 3, height: 8),
      frames,
    );

    // Nose
    final Paint nose = Paint()
      ..color = const Color(0xFFD6AC84)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, -headR * 0.10),
      Offset(0, headR * 0.24),
      nose,
    );

    // Lips
    final Paint lipTop = Paint()..color = const Color(0xFFB9686A);
    final Paint lipBottom = Paint()..color = const Color(0xFFD89195);
    final Path topLip = Path()
      ..moveTo(-headR * 0.48, headR * 0.18)
      ..quadraticBezierTo(0, headR * 0.09, headR * 0.48, headR * 0.18)
      ..quadraticBezierTo(0, headR * 0.28, -headR * 0.48, headR * 0.18)
      ..close();
    canvas.drawPath(topLip, lipTop);
    final Path bottomLip = Path()
      ..moveTo(-headR * 0.48, headR * 0.20)
      ..quadraticBezierTo(0, headR * 0.34, headR * 0.48, headR * 0.20)
      ..quadraticBezierTo(0, headR * 0.26, -headR * 0.48, headR * 0.20)
      ..close();
    canvas.drawPath(bottomLip, lipBottom);

    // Moustache (thinner to reveal lips)
    final Path stache = Path()
      ..moveTo(-headR * 0.55, headR * 0.12)
      ..quadraticBezierTo(-headR * 0.18, headR * 0.24, 0, headR * 0.14)
      ..quadraticBezierTo(headR * 0.18, headR * 0.24, headR * 0.55, headR * 0.10)
      ..quadraticBezierTo(headR * 0.16, headR * 0.32, 0, headR * 0.22)
      ..quadraticBezierTo(-headR * 0.16, headR * 0.30, -headR * 0.55, headR * 0.10)
      ..close();
    canvas.drawPath(stache, moustache);

    // Hat brim
    final Rect brim = Rect.fromCenter(
      center: Offset(0, -headR * 0.98),
      width: headR * 3.25,
      height: headR * 0.58,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        brim,
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
      ),
      hatBrimPaint,
    );
    canvas.drawRRect(
      RRect.fromRectXY(brim.deflate(headR * 0.08), headR * 0.22, headR * 0.22),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x26FFFFFF),
            Color(0x00000000),
          ],
        ).createShader(brim),
    );

    // Hat crown
    final Rect crown = Rect.fromCenter(
      center: Offset(0, -headR * 1.62),
      width: headR * 2.05,
      height: headR * 1.72,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(crown, const Radius.circular(14)),
      hatCrownPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(crown.inflate(-headR * 0.06), const Radius.circular(12)),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.05, -0.60),
          radius: 1.0,
          colors: const [
            Color(0x30FFFFFF),
            Color(0x00000000),
          ],
        ).createShader(crown),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, crown.top + headR * 0.18),
        width: crown.width * 0.78,
        height: headR * 0.28,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x33000000),
            Color(0x00000000),
          ],
        ).createShader(
          Rect.fromLTWH(
            -crown.width / 2,
            crown.top,
            crown.width,
            headR * 0.40,
          ),
        ),
    );

    final Paint hatBand = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0xFF5F3B12),
          Color(0xFF2A1808),
        ],
      ).createShader(crown.deflate(headR * 0.30));
    final Rect band = Rect.fromCenter(
      center: Offset(0, -headR * 1.46),
      width: crown.width * 0.95,
      height: headR * 0.34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, const Radius.circular(12)),
      hatBand,
    );

    // Hat studs
    for (int i = -2; i <= 2; i++) {
      final Offset stud = Offset(i * band.width / 5.4, band.center.dy);
      final Rect studRect = Rect.fromCenter(
        center: stud,
        width: headR * 0.20,
        height: headR * 0.12,
      );
      final Paint studFill = Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFFFFE7A6),
            Color(0xFFC99B4B),
          ],
        ).createShader(studRect);
      canvas.drawOval(studRect, studFill);
      canvas.drawOval(
        studRect.translate(0, headR * 0.02),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0x55FFFFFF),
              Color(0x00000000),
            ],
          ).createShader(studRect),
      );
    }

    canvas.restore();
  }
  void _paintForearmsOnTable(
      Canvas canvas, Size size, double shufflePhase, double cardLift) {
    final double tableTop = size.height * 0.60;
    final double forearmThickness = size.height * 0.045;
    final double shoulderY = size.height * 0.46;
    final double shuffleT = math.sin(shufflePhase * math.pi).clamp(0.0, 1.0);
    final double wristLift =
        (cardLift * 0.6 + shuffleT * 0.4) * size.height * 0.02;

    final Rect sleeveBounds = Rect.fromLTRB(
      size.width * 0.20,
      shoulderY,
      size.width * 0.80,
      tableTop + forearmThickness,
    );
    final Paint sleeve = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          palette.sleeveTop,
          palette.sleeveBottom,
        ],
      ).createShader(sleeveBounds);
    final Paint sleeveHighlight = Paint()..color = const Color(0x14000000);
    final Paint cuff = Paint()..color = const Color(0xFFF8F3E9);
    final Paint cuffEdge = Paint()
      ..color = const Color(0xFFD3C2AC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final Paint shadow = Paint()
      ..color = const Color(0x22000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        0,
        size.height * 0.38,
        size.width,
        tableTop + size.height * 0.14,
      ),
    );

    Path _upperSleeve({
      required bool left,
      required double elbowDrop,
    }) {
      if (left) {
        return Path()
          ..moveTo(size.width * 0.42, shoulderY)
          ..quadraticBezierTo(
            size.width * 0.33,
            shoulderY + size.height * 0.05,
            size.width * 0.36,
            tableTop - forearmThickness - elbowDrop,
          )
          ..quadraticBezierTo(
            size.width * 0.40,
            tableTop - forearmThickness * 0.42 - wristLift,
            size.width * 0.47,
            tableTop - forearmThickness * 0.28 - wristLift,
          )
          ..quadraticBezierTo(
            size.width * 0.45,
            shoulderY + size.height * 0.02,
            size.width * 0.42,
            shoulderY,
          )
          ..close();
      }
      return Path()
        ..moveTo(size.width * 0.58, shoulderY)
        ..quadraticBezierTo(
          size.width * 0.67,
          shoulderY + size.height * 0.05,
          size.width * 0.64,
          tableTop - forearmThickness - elbowDrop,
        )
        ..quadraticBezierTo(
          size.width * 0.60,
          tableTop - forearmThickness * 0.40 - wristLift,
          size.width * 0.53,
          tableTop - forearmThickness * 0.26 - wristLift,
        )
        ..quadraticBezierTo(
          size.width * 0.55,
          shoulderY + size.height * 0.02,
          size.width * 0.58,
          shoulderY,
        )
        ..close();
    }

    final double elbowBias = ui.lerpDouble(
          size.height * 0.035,
          size.height * 0.015,
          shuffleT,
        ) ??
        size.height * 0.02;

    canvas.drawPath(
      _upperSleeve(left: true, elbowDrop: elbowBias),
      sleeve,
    );
    canvas.drawPath(
      _upperSleeve(left: false, elbowDrop: elbowBias),
      sleeve,
    );

    canvas.drawPath(
      _upperSleeve(left: true, elbowDrop: elbowBias).shift(const Offset(0, 2)),
      sleeveHighlight,
    );
    canvas.drawPath(
      _upperSleeve(left: false, elbowDrop: elbowBias).shift(const Offset(0, 2)),
      sleeveHighlight,
    );

    void drawForearm(bool left) {
      final double direction = left ? -1 : 1;
      final double reach =
          ui.lerpDouble(size.width * 0.02, size.width * 0.05, shuffleT) ??
              size.width * 0.03;
      final double centerX = left
          ? size.width * 0.47 - reach
          : size.width * 0.53 + reach;
      final double rotation =
          (left ? -0.12 : 0.12) + direction * shuffleT * 0.05;
      final double centerY =
          tableTop - forearmThickness / 2 - wristLift + direction * size.height * 0.0015;
      final double forearmLength =
          ui.lerpDouble(size.width * 0.32, size.width * 0.28, shuffleT) ??
              size.width * 0.30;
      final double cuffWidth = size.width * 0.11;

      // Wrist shadow on felt
      final Rect shadowRect = Rect.fromCenter(
        center: Offset(centerX + direction * forearmLength * 0.32,
            tableTop + size.height * 0.01),
        width: forearmLength * 0.42,
        height: forearmThickness * 0.65,
      );
      canvas.drawOval(shadowRect, shadow);

      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.rotate(rotation);

      final RRect armBlock = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: forearmLength,
          height: forearmThickness,
        ),
        Radius.circular(forearmThickness * 0.45),
      );
      canvas.drawRRect(armBlock, sleeve);

      final Paint highlight = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x22FFFFFF),
            Color(0x00000000),
          ],
        ).createShader(armBlock.outerRect);
      canvas.drawRRect(armBlock, highlight);

      final Paint sleeveRidge = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.transparent,
          ],
        ).createShader(armBlock.outerRect);
      canvas.drawRRect(armBlock.deflate(forearmThickness * 0.18), sleeveRidge);

      final Paint sleeveDeepShadow = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.22),
            Colors.transparent,
          ],
        ).createShader(armBlock.outerRect);
      canvas.drawRRect(armBlock, sleeveDeepShadow);

      final RRect cuffBlock = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(
            forearmLength / 2 - cuffWidth / 2 - size.width * 0.01,
            0,
          ),
          width: cuffWidth,
          height: forearmThickness * 0.65,
        ),
        const Radius.circular(9),
      );
      canvas.drawRRect(cuffBlock, cuff);
      canvas.drawRRect(cuffBlock, cuffEdge);
      canvas.drawRRect(
        cuffBlock.deflate(1.5),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0x33FFFFFF),
              Color(0x00000000),
            ],
          ).createShader(cuffBlock.outerRect),
      );
      canvas.restore();
    }

    drawForearm(true);
    drawForearm(false);
    canvas.restore();
  }

  void _paintHandsOverTable(
      Canvas canvas, Size size, double shufflePhase, double dealPhase) {
    final Paint skin = Paint()..color = const Color(0xFFECD0AF);
    final Paint card = Paint()..color = const Color(0xFFF9F6FF);
    final Paint cardEdge = Paint()..color = const Color(0xFFC9C3D8);
    final Paint accent = Paint()..color = const Color(0xFFE15B59);
    final Paint knuckleShade = Paint()
      ..color = const Color(0xFFD1A578)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final double tableY = size.height * 0.60;
    final double basePalmY = tableY - size.height * 0.006;
    final double palmWidth = size.width * 0.135;
    final double palmHeight = size.height * 0.058;

    final double gather = math.sin(shufflePhase * math.pi).clamp(0.0, 1.0);
    final double release =
        ((shufflePhase - 0.45) / 0.55).clamp(0.0, 1.0);

    final double palmSpread =
        ui.lerpDouble(size.width * 0.17, size.width * 0.09, gather) ??
            size.width * 0.12;
    final double palmRise =
        ui.lerpDouble(0.0, size.height * 0.024, gather) ?? 0.0;
    final double palmDrop = release * size.height * 0.012;
    final double palmYOffset = palmRise - palmDrop;

    final double dealEase =
        math.pow(dealPhase.clamp(0.0, 1.0), 1.4).toDouble();
    final double rightReach =
        ui.lerpDouble(0.0, size.width * 0.06, dealEase) ?? 0.0;
    final double leftWithdraw =
        ui.lerpDouble(0.0, -size.width * 0.025, dealEase) ?? 0.0;

    final Offset leftPalmCenter = Offset(
      size.width * 0.5 - palmSpread + leftWithdraw,
      basePalmY - palmYOffset + release * size.height * 0.006,
    );
    final Offset rightPalmCenter = Offset(
      size.width * 0.5 + palmSpread + rightReach,
      basePalmY - palmYOffset + release * size.height * 0.004,
    );

    final double fingerCurl = ui.lerpDouble(0.98, 0.74, gather) ?? 0.84;
    final double fingerSpreadFactor =
        ui.lerpDouble(0.28, 0.21, gather) ?? 0.24;
    final double fingerLift =
        gather * size.height * 0.014 - release * size.height * 0.010;

    void drawPalm(bool isLeft, Offset center) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      final double palmTiltBase =
          ui.lerpDouble(0.03, 0.09, gather) ?? 0.06;
      final double palmTilt =
          (isLeft ? -1 : 1) * palmTiltBase - (isLeft ? 1 : -1) * release * 0.035;
      canvas.rotate(palmTilt);

      final double squish =
          ui.lerpDouble(1.0, 0.92, gather) ?? 0.95;
      final Rect palmRect = Rect.fromCenter(
        center: Offset.zero,
        width: palmWidth,
        height: palmHeight * squish,
      );
      final RRect palm = RRect.fromRectAndRadius(
        palmRect,
        const Radius.circular(12),
      );
      canvas.drawRRect(palm, skin);
      final Paint palmSheen = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x22FFFFFF),
            Color(0x00000000),
          ],
        ).createShader(palmRect);
      canvas.drawRRect(
        palm,
        palmSheen,
      );
      canvas.drawRRect(
        palm.deflate(palmWidth * 0.25),
        Paint()
          ..shader = RadialGradient(
            colors: const [
              Color(0x18000000),
              Color(0x00000000),
            ],
          ).createShader(palmRect),
      );

      final Path thumb = Path();
      if (isLeft) {
        thumb
          ..moveTo(palm.right - palmWidth * 0.18, palm.top + palmRect.height * 0.28)
          ..quadraticBezierTo(
            palm.right + palmWidth * 0.26,
            palm.top - palmRect.height * 0.25,
            palm.right + palmWidth * 0.12,
            palm.bottom + palmRect.height * 0.32,
          )
          ..quadraticBezierTo(
            palm.right - palmWidth * 0.06,
            palm.bottom + palmRect.height * 0.08,
            palm.right - palmWidth * 0.16,
            palm.bottom - palmRect.height * 0.06,
          )
          ..close();
      } else {
        thumb
          ..moveTo(palm.left + palmWidth * 0.18, palm.top + palmRect.height * 0.26)
          ..quadraticBezierTo(
            palm.left - palmWidth * 0.24,
            palm.top - palmRect.height * 0.24,
            palm.left - palmWidth * 0.10,
            palm.bottom + palmRect.height * 0.32,
          )
          ..quadraticBezierTo(
            palm.left + palmWidth * 0.02,
            palm.bottom + palmRect.height * 0.10,
            palm.left + palmWidth * 0.15,
            palm.bottom - palmRect.height * 0.05,
          )
          ..close();
      }
      canvas.drawPath(thumb, skin);

      final double fingerBaseY =
          palmRect.top - size.height * 0.010 - fingerLift;
      final double fingerWidth =
          palmWidth * (0.16 * (ui.lerpDouble(1.0, 0.9, gather) ?? 0.94));
      final double fingerHeight =
          size.height * 0.088 * fingerCurl;

      for (int f = 0; f < 4; f++) {
        final double t = (f - 1.5) / 3.0;
        final double dx = palmWidth * fingerSpreadFactor * t;
        final Rect fingerRect = Rect.fromCenter(
          center: Offset(dx, fingerBaseY),
          width: fingerWidth,
          height: fingerHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(fingerRect, const Radius.circular(7)),
          skin,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            fingerRect.deflate(fingerRect.width * 0.25),
            const Radius.circular(4),
          ),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Color(0x14FFFFFF),
                Color(0x00000000),
              ],
            ).createShader(fingerRect),
        );
        final Offset knuckleL =
            fingerRect.topLeft + Offset(3, fingerHeight * 0.55);
        final Offset knuckleR =
            fingerRect.topRight + Offset(-3, fingerHeight * 0.55);
        canvas.drawLine(knuckleL, knuckleR, knuckleShade);
      }
      canvas.restore();
    }

    drawPalm(true, leftPalmCenter);
    drawPalm(false, rightPalmCenter);

    final Offset deckCenter = Offset(
      (leftPalmCenter.dx + rightPalmCenter.dx) / 2,
      tableY -
          size.height * 0.020 -
          palmYOffset * 0.35 +
          release * size.height * 0.012,
    );
    final double deckWidth = size.width * 0.20;
    final double deckHeight = size.height * 0.072;
    final double split =
        ui.lerpDouble(deckWidth * 0.44, deckWidth * 0.12, gather) ?? 0.0;
    final double bridgeLift = math.pow(gather, 1.6) * deckHeight * 0.38;
    final double bridgeDrop = release * deckHeight * 0.48;
    final double ripple = math.sin(shufflePhase * math.pi * 2.0) * 0.12;

    void drawDeckHalf(bool left) {
      final double direction = left ? -1 : 1;
      final double lateral = direction *
          (split * 0.5 -
              release * deckWidth * 0.05 +
              ripple * deckWidth * 0.02);
      final double vertical =
          -bridgeLift + bridgeDrop + direction * gather * deckHeight * 0.06;
      final double tilt =
          direction * (0.22 - gather * 0.14 - release * 0.10);

      canvas.save();
      canvas.translate(deckCenter.dx + lateral, deckCenter.dy + vertical);
      canvas.rotate(tilt);

      final Rect bodyRect = Rect.fromCenter(
        center: Offset.zero,
        width: deckWidth * 0.52,
        height: deckHeight,
      );
      final RRect body =
          RRect.fromRectAndRadius(bodyRect, const Radius.circular(6));
      final Paint deckPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFFFDF8FF),
            Color(0xFFE7DFEF),
          ],
        ).createShader(body.outerRect);
      canvas.drawRRect(body, deckPaint);
      canvas.drawRRect(body.deflate(3), cardEdge);
      canvas.drawRRect(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0x22000000),
              Color(0x00000000),
              Color(0x22000000),
            ],
          ).createShader(body.outerRect),
      );
      final Rect stripe = Rect.fromCenter(
        center: Offset(0, bodyRect.height * 0.12),
        width: bodyRect.width * 0.82,
        height: bodyRect.height * 0.22,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(stripe, const Radius.circular(4)),
        Paint()..color = const Color(0xFF3B3458),
      );

      if (release > 0.05) {
        for (int i = 0; i < 5; i++) {
          final double raw = release * 5 - i;
          if (raw <= 0) continue;
          final double t = raw.clamp(0.0, 1.0);
          final double cascadeEase = 0.5 - 0.5 * math.cos(t * math.pi);
          final double cardShift = direction *
              ui.lerpDouble(deckWidth * 0.02, -deckWidth * 0.03, cascadeEase)!;
          final Offset cascadeCenter = Offset(
            cardShift,
            bodyRect.height * 0.5 + deckHeight * 0.10 * cascadeEase,
          );
          final Size cascadeSize = Size(
            deckWidth * 0.38,
            deckHeight * 0.18,
          );
          final RRect cascadeCard = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: cascadeCenter,
              width: cascadeSize.width,
              height: cascadeSize.height,
            ),
            const Radius.circular(4),
          );
          final Paint cascadePaint = Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Color(0xFFFDF5FF),
                Color(0xFFE7DAF1),
              ],
            ).createShader(cascadeCard.outerRect);
          canvas.drawRRect(cascadeCard, cascadePaint);
          canvas.drawRRect(cascadeCard.deflate(1.5), cardEdge);
        }
      }
      canvas.restore();
    }

    drawDeckHalf(true);
    drawDeckHalf(false);

    final List<Offset> dealTargets = <Offset>[
      Offset(-size.width * 0.24, -size.height * 0.10),
      Offset(size.width * 0.24, -size.height * 0.10),
      Offset(-size.width * 0.20, -size.height * 0.02),
      Offset(size.width * 0.20, -size.height * 0.02),
      Offset(0, -size.height * 0.14),
    ];

    final double dealsTotal = dealTargets.length + 0.6;
    for (int i = 0; i < dealTargets.length; i++) {
      final double raw = dealPhase * dealsTotal - i;
      if (raw <= 0) continue;
      final double t = raw.clamp(0.0, 1.0);
      final double ease = 0.5 - 0.5 * math.cos(t * math.pi);
      final Offset start = deckCenter.translate(
        deckWidth * 0.16,
        -deckHeight * 0.20,
      );
      final Offset end = deckCenter + dealTargets[i];
      final Offset pos = Offset(
        ui.lerpDouble(start.dx, end.dx, ease)!,
        ui.lerpDouble(start.dy, end.dy, ease)! -
            size.height * 0.02 * math.sin(t * math.pi),
      );
      final double cardScale = ui.lerpDouble(1.0, 0.88, t)!;
      final Size dealSize =
          Size(deckWidth * 0.45 * cardScale, deckHeight * 0.68 * cardScale);
      final RRect moving = RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: dealSize.width, height: dealSize.height),
        const Radius.circular(6),
      );
      canvas.drawRRect(moving, card);
      canvas.drawRRect(moving.deflate(2.5), cardEdge);
      canvas.drawCircle(
        moving.center.translate(0, -moving.height * 0.18),
        moving.width * 0.12,
        accent,
      );
      canvas.drawCircle(
        moving.center.translate(0, moving.height * 0.18),
        moving.width * 0.095,
        accent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SlashAvatarPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.tone != tone ||
        oldDelegate.felt != felt ||
        oldDelegate.railLight != railLight ||
        oldDelegate.railMid != railMid ||
        oldDelegate.railDark != railDark;
  }
}

class _BucketheadPainter extends CustomPainter {
  final double pose;
  final Color felt;
  final Color railLight;
  final Color railMid;
  final Color railDark;

  _BucketheadPainter(
    this.pose, {
    Color? feltColor,
    Color? railLightColor,
    Color? railMidColor,
    Color? railDarkColor,
  })  : felt = feltColor ?? const Color(0xFF13321E),
        railLight = railLightColor ?? const Color(0xFF5A241C),
        railMid = railMidColor ?? const Color(0xFF3E140F),
        railDark = railDarkColor ?? const Color(0xFF2C0E0B);

  @override
  void paint(Canvas canvas, Size size) {
    final double phase = pose * 2 * math.pi;
    const double sway = 0.0; // keep seated position stable
    const double bob = 0.0;

    final Offset seatCenter = Offset(
      size.width / 2,
      size.height * _kBucketheadSeatCenterY + bob - _kBucketheadLiftPx,
    );
    final Offset bodyCenter = seatCenter.translate(0, -_kBucketheadBodyRaisePx);
    final Offset handCenter = seatCenter.translate(0, _kBucketheadHandDropPx);

    _paintGlow(canvas, size, seatCenter);
    _paintChair(canvas, size);

    canvas.save();
    canvas.translate(bodyCenter.dx, bodyCenter.dy);
    canvas.rotate(sway);
    _paintBody(canvas, size);
    canvas.restore();

    _paintTable(canvas, size);

    canvas.save();
    canvas.translate(handCenter.dx, handCenter.dy);
    canvas.rotate(sway);
    _paintHands(canvas, size, phase);
    canvas.restore();

    canvas.save();
    canvas.translate(bodyCenter.dx, bodyCenter.dy);
    canvas.rotate(sway);
    _paintHead(canvas, size, sway);
    canvas.restore();
  }

  void _paintGlow(Canvas canvas, Size size, Offset center) {
    // Intentionally no glow to avoid the oval behind the dealer.
  }

  void _paintChair(Canvas canvas, Size size) {
    final double backTop = size.height * 0.18;
    final double backBottom = size.height * 0.58; // keep chair behind rail/table
    final Rect back = Rect.fromLTRB(
      size.width * 0.20,
      backTop,
      size.width * 0.80,
      backBottom,
    );
    final Paint chair = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF8B5E2E),
          Color(0xFF5D3D1E),
        ],
      ).createShader(back);
    canvas.drawRRect(
      RRect.fromRectAndRadius(back, const Radius.circular(22)),
      chair,
    );
  }

  void _paintTable(Canvas canvas, Size size) {
    final double railHeight = size.height * 0.18;
    final Rect outer = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.70),
      width: size.width * 1.12,
      height: railHeight,
    );
    final Rect inner = outer.deflate(railHeight * 0.34);
    final Path outerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(outer, Radius.circular(outer.height / 2)));
    final Path innerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(inner, Radius.circular(inner.height / 2)));
    final Path rail = Path.combine(PathOperation.difference, outerPath, innerPath);

    final Paint railPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [railLight, railMid, railDark],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(outer);
    canvas.drawPath(rail, railPaint);

    canvas.drawPath(
      rail,
      Paint()
        ..color = railDark.withOpacity(0.26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = railHeight * 0.06,
    );

    final Rect feltRect = inner.deflate(railHeight * 0.14);
    final Paint feltPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.18),
        radius: 1.05,
        colors: [felt.withOpacity(0.92), felt],
      ).createShader(feltRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(feltRect, Radius.circular(feltRect.height / 2)),
      feltPaint,
    );

    final Paint lip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = railHeight * 0.08
      ..color = Colors.white.withOpacity(0.08);
    canvas.drawPath(innerPath, lip);
  }

  void _paintBody(Canvas canvas, Size size) {
    final double bodyW = size.width * 0.42;
    final double bodyH = size.height * 0.38;

    final Rect torso = Rect.fromCenter(
      center: Offset(0, bodyH * 0.26), // lift torso so it rests against the chair back
      width: bodyW,
      height: bodyH,
    );

    final Paint jacket = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF1B1D27),
          Color(0xFF0B0C12),
        ],
      ).createShader(torso);
    canvas.drawRRect(
      RRect.fromRectAndRadius(torso, const Radius.circular(18)),
      jacket,
    );

    final Paint strap = Paint()
      ..color = const Color(0xFFB7410E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;
    final Path strapPath = Path()
      ..moveTo(-bodyW * 0.42, -bodyH * 0.30)
      ..lineTo(bodyW * 0.42, bodyH * 0.45);
    canvas.drawPath(strapPath, strap);

    final Paint shirt = Paint()..color = const Color(0xFFE8E8EC);
    final Rect shirtRect = Rect.fromCenter(
      center: Offset(0, bodyH * 0.02),
      width: bodyW * 0.28,
      height: bodyH * 0.65,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shirtRect, const Radius.circular(10)),
      shirt,
    );
  }

  void _paintHands(Canvas canvas, Size size, double phase) {
    _paintRenoirHands(
      canvas,
      size,
      phase,
      drawCards: false,
    );
  }

  void _paintHead(Canvas canvas, Size size, double tilt) {
    canvas.save();
    canvas.translate(0, -size.height * 0.16);
    canvas.rotate(tilt * 0.6);

    final double headR = size.width * 0.13 * 1.2; // 20% larger head

    // Mask
    final Rect mask = Rect.fromCenter(
      center: Offset(0, 0),
      width: headR * 1.6,
      height: headR * 1.1,
    );
    final Paint maskPaint = Paint()..color = const Color(0xFFFAFAFA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(mask, const Radius.circular(6)),
      maskPaint,
    );

    // Eyes
    final Paint eye = Paint()..color = const Color(0xFF111111);
    canvas.drawCircle(Offset(-headR * 0.35, -headR * 0.10), 3.4, eye);
    canvas.drawCircle(Offset(headR * 0.35, -headR * 0.10), 3.4, eye);

    // Bucket
    final Path bucket = Path()
      ..moveTo(-headR * 0.9, -headR * 1.8)
      ..lineTo(headR * 0.9, -headR * 1.8)
      ..lineTo(headR * 0.7, -headR * 0.5)
      ..lineTo(-headR * 0.7, -headR * 0.5)
      ..close();
    final Paint bucketPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFF6F6F6),
          Color(0xFFE0E0E0),
        ],
      ).createShader(bucket.getBounds());
    canvas.drawPath(bucket, bucketPaint);

    // Bucket stripe
    final Rect stripe = Rect.fromLTRB(
      -headR * 0.9,
      -headR * 1.5,
      headR * 0.9,
      -headR * 1.25,
    );
    canvas.drawRect(stripe, Paint()..color = const Color(0xFFE03A3E));

    // Simple text mark
    final TextPainter mark = TextPainter(
      text: const TextSpan(
        text: 'B',
        style: TextStyle(
          color: Color(0xFF222222),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    mark.paint(
      canvas,
      Offset(-mark.width / 2, -headR * 1.4 - mark.height / 2 + 4),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BucketheadPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.felt != felt ||
        oldDelegate.railLight != railLight ||
        oldDelegate.railMid != railMid ||
        oldDelegate.railDark != railDark;
  }
}

class _DharmaPainter extends CustomPainter {
  final double pose;
  final Color felt;
  final Color railLight;
  final Color railMid;
  final Color railDark;

  _DharmaPainter(
    this.pose, {
    Color? feltColor,
    Color? railLightColor,
    Color? railMidColor,
    Color? railDarkColor,
  })  : felt = feltColor ?? const Color(0xFF13321E),
        railLight = railLightColor ?? const Color(0xFF5A241C),
        railMid = railMidColor ?? const Color(0xFF3E140F),
        railDark = railDarkColor ?? const Color(0xFF2C0E0B);

  @override
  void paint(Canvas canvas, Size size) {
    final double phase = pose * 2 * math.pi;
    const double sway = 0.0; // keep seated position stable
    const double bob = 0.0;

    final Offset seatCenter =
        Offset(size.width / 2, size.height * (_kCustomSeatCenterY - 0.06) + bob);
    const double liftPx = 44; // raise torso/head further (additional 4px)
    final Offset bodyCenter = seatCenter.translate(0, -liftPx);
    final Offset handCenter = seatCenter.translate(0, -20); // lower hands slightly

    _paintGlow(canvas, size, seatCenter);
    _paintChair(canvas, size);

    canvas.save();
    canvas.translate(bodyCenter.dx, bodyCenter.dy);
    canvas.rotate(sway);
    _paintBody(canvas, size);
    canvas.restore();

    _paintTable(canvas, size);

    canvas.save();
    canvas.translate(handCenter.dx, handCenter.dy);
    canvas.rotate(sway);
    _paintHands(canvas, size, phase);
    canvas.restore();

    canvas.save();
    canvas.translate(bodyCenter.dx, bodyCenter.dy);
    canvas.rotate(sway);
    _paintHead(canvas, size, sway);
    canvas.restore();
  }

  void _paintGlow(Canvas canvas, Size size, Offset center) {
    // Intentionally no glow to avoid the oval behind the dealer.
  }

  void _paintChair(Canvas canvas, Size size) {
    final double backTop = size.height * 0.24;
    final double backBottom = size.height * 0.68;
    final Rect back = Rect.fromLTRB(
      size.width * 0.18,
      backTop,
      size.width * 0.82,
      backBottom,
    );
    final Paint chair = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFB88644),
          Color(0xFF7A552A),
        ],
      ).createShader(back);
    canvas.drawRRect(
      RRect.fromRectAndRadius(back, const Radius.circular(20)),
      chair,
    );
  }

  void _paintTable(Canvas canvas, Size size) {
    final double railHeight = size.height * 0.18;
    final Rect outer = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.70),
      width: size.width * 1.12,
      height: railHeight,
    );
    final Rect inner = outer.deflate(railHeight * 0.34);
    final Path outerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(outer, Radius.circular(outer.height / 2)));
    final Path innerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(inner, Radius.circular(inner.height / 2)));
    final Path rail = Path.combine(PathOperation.difference, outerPath, innerPath);

    final Paint railPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [railLight, railMid, railDark],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(outer);
    canvas.drawPath(rail, railPaint);

    canvas.drawPath(
      rail,
      Paint()
        ..color = railDark.withOpacity(0.26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = railHeight * 0.06,
    );

    final Rect feltRect = inner.deflate(railHeight * 0.14);
    final Paint feltPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.18),
        radius: 1.05,
        colors: [felt.withOpacity(0.92), felt],
      ).createShader(feltRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(feltRect, Radius.circular(feltRect.height / 2)),
      feltPaint,
    );

    final Paint lip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = railHeight * 0.08
      ..color = Colors.white.withOpacity(0.08);
    canvas.drawPath(innerPath, lip);
  }

  void _paintBody(Canvas canvas, Size size) {
    final double bodyW = size.width * 0.46;
    final double bodyH = size.height * 0.40;

    final Rect torso = Rect.fromCenter(
      center: Offset(0, bodyH * 0.18),
      width: bodyW,
      height: bodyH,
    );

    final Paint jacket = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFF3E9D9),
          Color(0xFFDCCDB4),
        ],
      ).createShader(torso);
    canvas.drawRRect(
      RRect.fromRectAndRadius(torso, const Radius.circular(18)),
      jacket,
    );

    final Paint lapel = Paint()
      ..color = const Color(0xFFD2C4AC)
      ..style = PaintingStyle.fill;
    final Path leftLapel = Path()
      ..moveTo(-bodyW * 0.42, -bodyH * 0.35)
      ..quadraticBezierTo(-bodyW * 0.32, -bodyH * 0.47, -bodyW * 0.18, -bodyH * 0.32)
      ..quadraticBezierTo(-bodyW * 0.07, -bodyH * 0.12, -bodyW * 0.12, bodyH * 0.08)
      ..quadraticBezierTo(-bodyW * 0.16, bodyH * 0.26, -bodyW * 0.32, bodyH * 0.32)
      ..quadraticBezierTo(-bodyW * 0.42, bodyH * 0.14, -bodyW * 0.44, -bodyH * 0.04)
      ..close();
    final Path rightLapel = Path()
      ..moveTo(bodyW * 0.42, -bodyH * 0.35)
      ..quadraticBezierTo(bodyW * 0.32, -bodyH * 0.47, bodyW * 0.18, -bodyH * 0.32)
      ..quadraticBezierTo(bodyW * 0.07, -bodyH * 0.12, bodyW * 0.12, bodyH * 0.08)
      ..quadraticBezierTo(bodyW * 0.16, bodyH * 0.26, bodyW * 0.32, bodyH * 0.32)
      ..quadraticBezierTo(bodyW * 0.42, bodyH * 0.14, bodyW * 0.44, -bodyH * 0.04)
      ..close();
    canvas.drawPath(leftLapel, lapel);
    canvas.drawPath(rightLapel, lapel);

    final Paint shirt = Paint()..color = const Color(0xFFE8E8EC);
    final Rect shirtRect = Rect.fromCenter(
      center: Offset(0, bodyH * 0.04),
      width: bodyW * 0.26,
      height: bodyH * 0.66,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shirtRect, const Radius.circular(10)),
      shirt,
    );

    final Paint tie = Paint()..color = const Color(0xFFD62828);
    final Path tiePath = Path()
      ..moveTo(0, -bodyH * 0.25)
      ..quadraticBezierTo(-6, -bodyH * 0.12, -2, -bodyH * 0.02)
      ..quadraticBezierTo(-6, bodyH * 0.18, 0, bodyH * 0.30)
      ..quadraticBezierTo(6, bodyH * 0.18, 2, -bodyH * 0.02)
      ..quadraticBezierTo(6, -bodyH * 0.12, 0, -bodyH * 0.25)
      ..close();
    canvas.drawPath(tiePath, tie);
  }

  void _paintHands(Canvas canvas, Size size, double phase) {
    _paintRenoirHands(canvas, size, phase,
        drawCards: false);
  }

  void _paintHead(Canvas canvas, Size size, double tilt) {
    canvas.save();
    canvas.translate(0, -size.height * 0.12);
    canvas.rotate(tilt * 0.5);

    final double headR = size.width * 0.13;

    // Face
    final Paint skin = Paint()..color = const Color(0xFFF1D8BA);
    final Rect face = Rect.fromCenter(
      center: const Offset(0, 0),
      width: headR * 1.6,
      height: headR * 1.9,
    );
    canvas.drawOval(face, skin);

    // Mohawk
    final Path mohawk = Path()
      ..moveTo(-headR * 0.16, -headR * 1.6)
      ..lineTo(headR * 0.16, -headR * 1.6)
      ..lineTo(headR * 0.06, headR * 0.35)
      ..quadraticBezierTo(0, headR * 0.60, -headR * 0.06, headR * 0.35)
      ..close();
    final Paint hawkPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF2E3A70), Color(0xFF101629)],
      ).createShader(mohawk.getBounds());
    canvas.drawPath(mohawk, hawkPaint);

    // Side fade shadow
    final Path fadeL = Path()
      ..moveTo(-headR * 0.9, -headR * 1.05)
      ..quadraticBezierTo(-headR * 0.5, -headR * 1.30, -headR * 0.25, -headR * 1.05)
      ..lineTo(-headR * 0.22, headR * 0.9)
      ..quadraticBezierTo(-headR * 0.6, headR * 1.0, -headR * 0.9, headR * 0.5)
      ..close();
    final Shader fadeShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0x33000000), Colors.transparent],
    ).createShader(fadeL.getBounds());
    canvas.drawPath(fadeL, Paint()..shader = fadeShader);
    final Path fadeR = Path()
      ..moveTo(headR * 0.9, -headR * 1.05)
      ..quadraticBezierTo(headR * 0.5, -headR * 1.30, headR * 0.25, -headR * 1.05)
      ..lineTo(headR * 0.22, headR * 0.9)
      ..quadraticBezierTo(headR * 0.6, headR * 1.0, headR * 0.9, headR * 0.5)
      ..close();
    canvas.drawPath(fadeR, Paint()..shader = fadeShader);

    // Eyes (blue)
    final Paint eyeWhite = Paint()..color = const Color(0xFFFDFDFD);
    final Paint iris = Paint()..color = const Color(0xFF4FA0FF);
    final Paint pupil = Paint()..color = const Color(0xFF0C0C0C);
    void drawEye(double dx) {
      final Offset center = Offset(dx, -headR * 0.08);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: headR * 0.46, height: headR * 0.30),
        eyeWhite,
      );
      canvas.drawCircle(center.translate(0, headR * 0.01), headR * 0.16, iris);
      canvas.drawCircle(center.translate(0, headR * 0.01), headR * 0.09, pupil);
    }
    drawEye(-headR * 0.36);
    drawEye(headR * 0.36);

    // Brows
    final Paint brow = Paint()
      ..color = const Color(0xFF2C1A0F)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-headR * 0.45, -headR * 0.22),
      Offset(-headR * 0.18, -headR * 0.28),
      brow,
    );
    canvas.drawLine(
      Offset(headR * 0.18, -headR * 0.28),
      Offset(headR * 0.45, -headR * 0.22),
      brow,
    );

    // Simple nose bridge
    final Paint nose = Paint()
      ..color = const Color(0xFFE9C8A2)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, headR * 0.02),
      Offset(0, headR * 0.18),
      nose,
    );

    // Mouth
    final Paint mouth = Paint()
      ..color = const Color(0xFF7A3A2A)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-headR * 0.16, headR * 0.32),
      Offset(headR * 0.16, headR * 0.32),
      mouth,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DharmaPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.felt != felt ||
        oldDelegate.railLight != railLight ||
        oldDelegate.railMid != railMid ||
        oldDelegate.railDark != railDark;
  }
}

class _RedrixPainter extends CustomPainter {
  final double pose;
  final Color felt;
  final Color railLight;
  final Color railMid;
  final Color railDark;

  _RedrixPainter(
    this.pose, {
    Color? feltColor,
    Color? railLightColor,
    Color? railMidColor,
    Color? railDarkColor,
  })  : felt = feltColor ?? const Color(0xFF13321E),
        railLight = railLightColor ?? const Color(0xFF5A241C),
        railMid = railMidColor ?? const Color(0xFF3E140F),
        railDark = railDarkColor ?? const Color(0xFF2C0E0B);

  @override
  void paint(Canvas canvas, Size size) {
    final double phase = pose * 2 * math.pi;
    const double sway = 0.0; // keep seated position stable
    const double bob = 0.0;
    const double liftPx = 64.0; // raise torso, head, and hands further

    final Offset seatCenter = Offset(
      size.width / 2,
      size.height * _kRedrixSeatCenterY + bob - _kRedrixLiftPx,
    );
    final Offset bodyCenter = seatCenter.translate(0, -liftPx);

    _paintGlow(canvas, size, seatCenter);
    _paintChair(canvas, size);
    _paintTable(canvas, size);

    canvas.save();
    canvas.translate(bodyCenter.dx, bodyCenter.dy);
    canvas.rotate(sway);
    _paintBody(canvas, size);
    _paintHands(canvas, size, phase);
    _paintHead(canvas, size, sway);
    canvas.restore();
  }

  void _paintGlow(Canvas canvas, Size size, Offset center) {
    // Intentionally no glow to avoid the oval behind the dealer.
  }

  void _paintChair(Canvas canvas, Size size) {
    final double backTop = size.height * 0.24;
    final double backBottom = size.height * 0.68;
    final Rect back = Rect.fromLTRB(
      size.width * 0.18,
      backTop,
      size.width * 0.82,
      backBottom,
    );
    final Paint chair = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFB46A34),
          Color(0xFF7A3E1F),
        ],
      ).createShader(back);
    canvas.drawRRect(
      RRect.fromRectAndRadius(back, const Radius.circular(20)),
      chair,
    );
  }

  void _paintTable(Canvas canvas, Size size) {
    final double railHeight = size.height * 0.18;
    final Rect outer = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.70),
      width: size.width * 1.12,
      height: railHeight,
    );
    final Rect inner = outer.deflate(railHeight * 0.34);
    final Path outerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(outer, Radius.circular(outer.height / 2)));
    final Path innerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(inner, Radius.circular(inner.height / 2)));
    final Path rail = Path.combine(PathOperation.difference, outerPath, innerPath);

    final Paint railPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [railLight, railMid, railDark],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(outer);
    canvas.drawPath(rail, railPaint);

    canvas.drawPath(
      rail,
      Paint()
        ..color = railDark.withOpacity(0.26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = railHeight * 0.06,
    );

    final Rect feltRect = inner.deflate(railHeight * 0.14);
    final Paint feltPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.18),
        radius: 1.05,
        colors: [felt.withOpacity(0.92), felt],
      ).createShader(feltRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(feltRect, Radius.circular(feltRect.height / 2)),
      feltPaint,
    );

    final Paint lip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = railHeight * 0.08
      ..color = Colors.white.withOpacity(0.08);
    canvas.drawPath(innerPath, lip);
  }

  void _paintBody(Canvas canvas, Size size) {
    final double bodyW = size.width * 0.46;
    final double bodyH = size.height * 0.40;

    final Rect torso = Rect.fromCenter(
      center: Offset(0, bodyH * 0.24), // settle torso against chair back
      width: bodyW,
      height: bodyH,
    );

    final Paint jacket = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF2A1B2E),
          Color(0xFF130C16),
        ],
      ).createShader(torso);
    canvas.drawRRect(
      RRect.fromRectAndRadius(torso, const Radius.circular(18)),
      jacket,
    );

    final Paint shirt = Paint()..color = const Color(0xFFD8D9E0);
    final Rect shirtRect = Rect.fromCenter(
      center: Offset(0, bodyH * -0.02),
      width: bodyW * 0.26,
      height: bodyH * 0.56,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shirtRect, const Radius.circular(10)),
      shirt,
    );

    final Paint scarf = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFB3001B),
          Color(0xFFE61A2B),
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(0, bodyH * 0.08),
        width: bodyW * 0.32,
        height: bodyH * 0.50,
      ));
    final Path scarfPath = Path()
      ..moveTo(-bodyW * 0.10, -bodyH * 0.26)
      ..quadraticBezierTo(-bodyW * 0.20, -bodyH * 0.12, -bodyW * 0.08, bodyH * 0.26)
      ..quadraticBezierTo(0, bodyH * 0.36, bodyW * 0.06, bodyH * 0.26)
      ..quadraticBezierTo(bodyW * 0.18, -bodyH * 0.12, bodyW * 0.06, -bodyH * 0.26)
      ..close();
    canvas.drawPath(scarfPath, scarf);

    // Compact bandana knot at collar (no dangling triangle).
    final Rect knotRect = Rect.fromCenter(
      center: Offset(0, -bodyH * 0.06),
      width: bodyW * 0.16,
      height: bodyH * 0.14,
    );
    final Paint knotPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFFB3001B), Color(0xFFE61A2B)],
      ).createShader(knotRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(knotRect, const Radius.circular(6)),
      knotPaint,
    );
  }

  void _paintHands(Canvas canvas, Size size, double phase) {
    _paintRenoirHands(
      canvas,
      size,
      phase,
      drawCards: false,
    );
  }

  void _paintHead(Canvas canvas, Size size, double tilt) {
    canvas.save();
    canvas.translate(0, -size.height * 0.15);
    canvas.rotate(tilt * 0.6);

    final double headR = size.width * 0.13;

    // Face
    final Paint skin = Paint()..color = const Color(0xFFB2743E);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 0),
        width: headR * 1.6,
        height: headR * 1.9,
      ),
      skin,
    );

    // Hair (afro) with red bandana
    final Path hair = Path();
    final double afroR = headR * 1.5;
    hair.addOval(Rect.fromCenter(
      center: Offset(0, -headR * 0.5),
      width: afroR * 1.6,
      height: afroR * 1.4,
    ));
    final Paint hairPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.3),
        radius: 1.2,
        colors: const [Color(0xFF1A0E1A), Color(0xFF090509)],
      ).createShader(hair.getBounds());
    canvas.drawPath(hair, hairPaint);

    // Red bandana across forehead
    final Rect band = Rect.fromCenter(
      center: Offset(0, -headR * 0.95),
      width: afroR * 1.5,
      height: afroR * 0.28,
    );
    final Paint bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [Color(0xFFB3001B), Color(0xFFE61A2B)],
      ).createShader(band);
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, const Radius.circular(8)),
      bandPaint,
    );
    canvas.save();
    canvas.translate(afroR * 0.45, -headR * 0.90);
    canvas.rotate(-0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: headR * 0.7, height: headR * 0.20),
        const Radius.circular(4),
      ),
      bandPaint,
    );
    canvas.restore();

    // Eyes
    final Paint eye = Paint()..color = const Color(0xFF0F0F0F);
    canvas.drawCircle(Offset(-headR * 0.34, -headR * 0.10), 3.4, eye);
    canvas.drawCircle(Offset(headR * 0.34, -headR * 0.10), 3.4, eye);

    // Brows
    final Paint brow = Paint()
      ..color = const Color(0xFF2A1A0F)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-headR * 0.45, -headR * 0.24),
      Offset(-headR * 0.20, -headR * 0.18),
      brow,
    );
    canvas.drawLine(
      Offset(headR * 0.20, -headR * 0.18),
      Offset(headR * 0.45, -headR * 0.24),
      brow,
    );

    // Moustache
    final Paint stache = Paint()
      ..color = const Color(0xFF3C2214)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-headR * 0.25, headR * 0.12),
      Offset(-headR * 0.02, headR * 0.18),
      stache,
    );
    canvas.drawLine(
      Offset(headR * 0.02, headR * 0.18),
      Offset(headR * 0.25, headR * 0.12),
      stache,
    );

    // Chin highlight
    final Paint jaw = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, headR * 0.70),
        width: headR * 1.2,
        height: headR * 0.9,
      ),
      math.pi * 0.15,
      math.pi * 0.70,
      false,
      jaw,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RedrixPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.felt != felt ||
        oldDelegate.railLight != railLight ||
        oldDelegate.railMid != railMid ||
        oldDelegate.railDark != railDark;
  }
}

class _ReviciiPainter extends CustomPainter {
  final double pose;
  final Color felt;
  final Color railLight;
  final Color railMid;
  final Color railDark;

  _ReviciiPainter(
    this.pose, {
    Color? feltColor,
    Color? railLightColor,
    Color? railMidColor,
    Color? railDarkColor,
  })  : felt = feltColor ?? const Color(0xFF13321E),
        railLight = railLightColor ?? const Color(0xFF5A241C),
        railMid = railMidColor ?? const Color(0xFF3E140F),
        railDark = railDarkColor ?? const Color(0xFF2C0E0B);

  @override
  void paint(Canvas canvas, Size size) {
    final double phase = pose * 2 * math.pi;
    const double sway = 0.0; // keep seated position stable
    const double bob = 0.0;
    const double dropPx = 18.0;

    final Offset seatCenter =
        Offset(size.width / 2, size.height * _kCustomSeatCenterY + bob + dropPx);

    _paintGlow(canvas, size, seatCenter);
    _paintChair(canvas, size);
    _paintTable(canvas, size);

    canvas.save();
    canvas.translate(seatCenter.dx, seatCenter.dy);
    canvas.rotate(sway);
    _paintBody(canvas, size);
    _paintHands(canvas, size, phase);
    _paintHead(canvas, size, sway);
    canvas.restore();
  }

  void _paintGlow(Canvas canvas, Size size, Offset center) {
    // Intentionally no glow to avoid the oval behind the dealer.
  }

  void _paintChair(Canvas canvas, Size size) {
    final double backTop = size.height * 0.24;
    final double backBottom = size.height * 0.68;
    final Rect back = Rect.fromLTRB(
      size.width * 0.18,
      backTop,
      size.width * 0.82,
      backBottom,
    );
    final Paint chair = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF9E7840),
          Color(0xFF6A4E2A),
        ],
      ).createShader(back);
    canvas.drawRRect(
      RRect.fromRectAndRadius(back, const Radius.circular(20)),
      chair,
    );
  }

  void _paintTable(Canvas canvas, Size size) {
    final double railHeight = size.height * 0.18;
    final Rect outer = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.70),
      width: size.width * 1.12,
      height: railHeight,
    );
    final Rect inner = outer.deflate(railHeight * 0.34);
    final Path outerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(outer, Radius.circular(outer.height / 2)));
    final Path innerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(inner, Radius.circular(inner.height / 2)));
    final Path rail = Path.combine(PathOperation.difference, outerPath, innerPath);

    final Paint railPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [railLight, railMid, railDark],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(outer);
    canvas.drawPath(rail, railPaint);

    canvas.drawPath(
      rail,
      Paint()
        ..color = railDark.withOpacity(0.26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = railHeight * 0.06,
    );

    final Rect feltRect = inner.deflate(railHeight * 0.14);
    final Paint feltPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.18),
        radius: 1.05,
        colors: [felt.withOpacity(0.92), felt],
      ).createShader(feltRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(feltRect, Radius.circular(feltRect.height / 2)),
      feltPaint,
    );

    final Paint lip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = railHeight * 0.08
      ..color = Colors.white.withOpacity(0.08);
    canvas.drawPath(innerPath, lip);
  }

  void _paintBody(Canvas canvas, Size size) {
    final double bodyW = size.width * 0.46;
    final double bodyH = size.height * 0.40;

    final Rect torso = Rect.fromCenter(
      center: Offset(0, bodyH * 0.18),
      width: bodyW,
      height: bodyH,
    );

    final Paint jacket = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFE9C07C),
          Color(0xFFD3A25B),
        ],
      ).createShader(torso);
    final RRect jacketShape =
        RRect.fromRectAndRadius(torso, const Radius.circular(18));
    canvas.drawRRect(jacketShape, jacket);
    final Paint spot = Paint()..color = const Color(0xFF4B2D1A);
    final math.Random rng = math.Random(11);
    for (int i = 0; i < 22; i++) {
      final double rx = (rng.nextDouble() - 0.5) * bodyW * 0.8;
      final double ry = (rng.nextDouble() - 0.1) * bodyH * 0.9;
      final double r = bodyW * 0.04 * (0.7 + rng.nextDouble() * 0.6);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(rx, ry), width: r * 1.2, height: r),
        spot..color = spot.color.withOpacity(0.9),
      );
    }

    final Paint shirt = Paint()..color = const Color(0xFFE8E8EC);
    final Rect shirtRect = Rect.fromCenter(
      center: Offset(0, bodyH * 0.04),
      width: bodyW * 0.28,
      height: bodyH * 0.66,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shirtRect, const Radius.circular(10)),
      shirt,
    );

    final Paint tie = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF18D8FF),
          Color(0xFF0E8FB7),
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(0, bodyH * 0.08),
        width: bodyW * 0.24,
        height: bodyH * 0.50,
      ));
    final Path tiePath = Path()
      ..moveTo(0, -bodyH * 0.26)
      ..quadraticBezierTo(-6, -bodyH * 0.12, -2, -bodyH * 0.00)
      ..quadraticBezierTo(-6, bodyH * 0.18, 0, bodyH * 0.32)
      ..quadraticBezierTo(6, bodyH * 0.18, 2, -bodyH * 0.00)
      ..quadraticBezierTo(6, -bodyH * 0.12, 0, -bodyH * 0.26)
      ..close();
    canvas.drawPath(tiePath, tie);
  }

  void _paintHands(Canvas canvas, Size size, double phase) {
    final double handY = size.height * 0.14;
    final double spread = size.width * 0.24 + math.sin(phase) * 5;
    final Paint hand = Paint()..color = const Color(0xFFE5C39C);
    canvas.drawCircle(Offset(-spread, handY), 12, hand);
    canvas.drawCircle(Offset(spread, handY), 12, hand);

    final Paint cards = Paint()..color = const Color(0xFFF0EFEF);
    final Path cardFan = Path()
      ..moveTo(-spread * 0.28, handY - 6)
      ..relativeLineTo(spread * 0.56, 0)
      ..relativeLineTo(-spread * 0.28, 30)
      ..close();
    canvas.save();
    canvas.translate(0, handY - 10);
    canvas.rotate(math.sin(phase * 1.3) * 0.05);
    canvas.drawPath(cardFan, cards);
    canvas.restore();
  }

  void _paintHead(Canvas canvas, Size size, double tilt) {
    canvas.save();
    canvas.translate(0, -size.height * 0.12);
    canvas.rotate(tilt * 0.6);

    final double headR = size.width * 0.13;

    // Face
    final Paint skin = Paint()..color = const Color(0xFFE0B889);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 0),
        width: headR * 1.6,
        height: headR * 1.9,
      ),
      skin,
    );

    // Cap
    final Rect cap = Rect.fromCenter(
      center: Offset(0, -headR * 1.0),
      width: headR * 1.9,
      height: headR * 0.8,
    );
    final Paint capPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF1A1D24), Color(0xFF0A0B10)],
      ).createShader(cap);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cap, const Radius.circular(10)),
      capPaint,
    );

    // Cap stripe
    final Rect stripe = Rect.fromCenter(
      center: Offset(0, -headR * 0.82),
      width: headR * 1.8,
      height: headR * 0.20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(stripe, const Radius.circular(8)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [Color(0xFF18D8FF), Color(0xFF0E8FB7)],
        ).createShader(stripe),
    );

    // Headphones band
    final Paint phones = Paint()
      ..color = const Color(0xFF0F1118)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, -headR * 0.2),
        width: headR * 2.2,
        height: headR * 1.8,
      ),
      math.pi * 1.15,
      math.pi * 0.70,
      false,
      phones,
    );

    // Eyes
    final Paint eye = Paint()..color = const Color(0xFF0F0F0F);
    canvas.drawCircle(Offset(-headR * 0.34, -headR * 0.10), 3.4, eye);
    canvas.drawCircle(Offset(headR * 0.34, -headR * 0.10), 3.4, eye);

    // Brows
    final Paint brow = Paint()
      ..color = const Color(0xFF2A1A0F)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-headR * 0.45, -headR * 0.24),
      Offset(-headR * 0.20, -headR * 0.18),
      brow,
    );
    canvas.drawLine(
      Offset(headR * 0.20, -headR * 0.18),
      Offset(headR * 0.45, -headR * 0.24),
      brow,
    );

    // Stubble
    final Paint stubble = Paint()
      ..color = const Color(0xFFB18A64)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-headR * 0.18, headR * 0.14),
      Offset(-headR * 0.10, headR * 0.24),
      stubble,
    );
    canvas.drawLine(
      Offset(headR * 0.10, headR * 0.24),
      Offset(headR * 0.18, headR * 0.14),
      stubble,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReviciiPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.felt != felt ||
        oldDelegate.railLight != railLight ||
        oldDelegate.railMid != railMid ||
        oldDelegate.railDark != railDark;
  }
}
