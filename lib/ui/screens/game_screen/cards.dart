// lib/ui/screens/game_screen/cards.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart' as pc;
import 'package:ten_of_a_kind_poker/config/card_backs.dart';

/* =============================================================
 * Global visibility gate (driven by Renoir)
 * =========================================================== */

class CardVisibilityGate {
  /// If false, **no cards render** (hole, hero, community, backs)
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  static void show() => enabled.value = true;
  static void hide() => enabled.value = false;
}

/* =============================================================
 * Global action gate (driven by Renoir / flow)
 * =========================================================== */
class ActionGate {
  /// When true, table may act (yellow seat + ActionBar enabled).
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
  static void enable() => enabled.value = true;
  static void disable() => enabled.value = false;
}

/* ──────────────────────────────────────────────────────────────────────────
   Card visuals & helpers (no overlays here)
   - Renders NOTHING for null/invalid cards (prevents phantom cards before deal)
   - Back image only when explicitly requested
   - Continuous corners, gapless image playback, DPI-aware caching
   ────────────────────────────────────────────────────────────────────────── */

/* =============================================================
 * Geometry
 * =========================================================== */

const double _kCornerFactor = 0.30; // softened rounding so fronts/backs match without clipping ranks
const double _kCardAspect = 1.4;     // height = width * aspect
// Slight inset so face art doesn't get its rounded corners clipped relative to backs.
const double _kFaceZoom = 0.98;
// Slight zoom-in to reduce baked-in white border on back assets.
const double _kBackZoom = 1.03;
double _cornerRadiusFor(double w, double h) => math.min(w, h) * _kCornerFactor;

/* =============================================================
 * Random back theme (one per game)
 * =========================================================== */

class CardBackTheme {
  static const List<String> _backs = kCardBackAssets;

  static final math.Random _rng = math.Random();
  static String _current = _backs.first;

  /// The per-game selected back.
  static String get current => _current;

  /// Call once per GameScreen init; stays fixed for the whole game.
  static void nextGame() {
    _current = _backs[_rng.nextInt(_backs.length)];
  }

  /// Force a specific back (useful for debugging).
  static void set(String assetPath) {
    _current = assetPath;
  }
}

/// ✅ Fallback image (must exist in assets)
const String _kFallbackBackAsset = kFallbackCardBackAsset;

/* =============================================================
 * Corner style
 * =========================================================== */

enum CornerStyle { rounded, continuous }
const CornerStyle _kCornerStyle = CornerStyle.continuous;

ShapeBorder _cardShape(double radius, CornerStyle style) {
  switch (style) {
    case CornerStyle.continuous:
      return ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      );
    case CornerStyle.rounded:
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      );
  }
}

Widget _clipCard({
  required double w,
  required double h,
  required Widget child,
  CornerStyle style = _kCornerStyle,
}) {
  final shape = _cardShape(_cornerRadiusFor(w, h), style);
  return SizedBox(
    width: w,
    height: h,
    child: Material(
      type: MaterialType.transparency,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
}

/* =============================================================
 * Data model for face rendering
 * =========================================================== */

class CardSpec {
  final String rank; // "A,K,Q,J,10..2"
  final String suit; // "S,H,D,C" or symbols
  const CardSpec(this.rank, this.suit);

  bool get isRed => suit == 'H' || suit == 'D' || suit == '♥' || suit == '♦';
  String get code => '$rank$suit';
}

/* =============================================================
 * Back asset safety
 * =========================================================== */

String _safeBackAsset(String? asset) {
  if (asset == null || asset.isEmpty) return CardBackTheme.current;
  final a = asset.trim();
  // For safety, disallow file/URL paths here; only bundled assets.
  if (a.startsWith('file:') || a.startsWith('/') || a.contains('://')) {
    return CardBackTheme.current;
  }
  return a;
}

/* =============================================================
 * Card Back (image only; clipped)
 * =========================================================== */

class CardBack extends StatelessWidget {
  final double w, h;
  /// If null, uses CardBackTheme.current.
  final String? asset;
  final CornerStyle cornerStyle;

  @Deprecated('Radius is computed from size and this is ignored.')
  final BorderRadius? borderRadius; // kept for backward compatibility

  const CardBack({
    super.key,
    required this.w,
    required this.h,
    this.asset,
    this.cornerStyle = _kCornerStyle,
    this.borderRadius, // ignored
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CardVisibilityGate.enabled,
      builder: (_, on, __) {
        if (!on) return const SizedBox.shrink();

        final chosen = _safeBackAsset(asset ?? CardBackTheme.current);
        final dpr = MediaQuery.of(context).devicePixelRatio;

        return _clipCard(
          w: w,
          h: h,
          style: cornerStyle,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0x11000000)), // subtle bg
            child: Transform.scale(
              scale: _kBackZoom,
              child: Image.asset(
                chosen,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                cacheWidth: (w * dpr * _kBackZoom).round(),
                cacheHeight: (h * dpr * _kBackZoom).round(),
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) {
                  debugPrint('CardBack: failed to load "$chosen"; using fallback.');
                  return Image.asset(
                    _kFallbackBackAsset,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    cacheWidth: (w * dpr * _kBackZoom).round(),
                    cacheHeight: (h * dpr * _kBackZoom).round(),
                    errorBuilder: (_, __, ___) {
                      return const ColoredBox(
                        color: Colors.black26,
                        child: Center(
                          child: Icon(Icons.style, color: Colors.white70, size: 28),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/* =============================================================
 * Face Card (vector from playing_cards)
 * =========================================================== */

class FaceCard extends StatelessWidget {
  final double w, h;
  final CardSpec? card; // nullable → renders nothing when absent
  final double zoom;
  final Color bgColor;
  final CornerStyle cornerStyle;

  @Deprecated('Radius is computed from size and this is ignored.')
  final BorderRadius? borderRadius; // kept for backward compatibility

  FaceCard(
    Object? anyCard, {
    super.key,
    required this.w,
    required this.h,
    this.zoom = _kFaceZoom,
    this.bgColor = Colors.transparent,
    this.cornerStyle = _kCornerStyle,
    this.borderRadius,
  }) : card = _coerceToCardSpec(anyCard);

  factory FaceCard.fromCode({
    Key? key,
    required double w,
    required double h,
    required String? code, // nullable now
    double zoom = _kFaceZoom,
    Color bgColor = Colors.transparent,
    CornerStyle cornerStyle = _kCornerStyle,
    BorderRadius? borderRadius,
  }) =>
      FaceCard(
        code == null ? null : _parseCodeOrNull(code),
        key: key,
        w: w,
        h: h,
        zoom: zoom,
        bgColor: bgColor,
        cornerStyle: cornerStyle,
        borderRadius: borderRadius,
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CardVisibilityGate.enabled,
      builder: (_, on, __) {
        if (!on) return const SizedBox.shrink();
        if (card == null) return const SizedBox.shrink();

        final suit = _toSuit(card!.suit);
        final value = _toValue(card!.rank);
        if (suit == null || value == null) {
          return const SizedBox.shrink();
        }
        final pcCard = pc.PlayingCard(suit, value);

        return _clipCard(
          w: w,
          h: h,
          style: cornerStyle,
          child: ColoredBox(
            color: bgColor,
            child: LayoutBuilder(
              builder: (context, c) => Center(
                child: Transform.scale(
                  scale: zoom,
                  child: SizedBox(
                    width: c.maxWidth,
                    height: c.maxHeight,
                    child: pc.PlayingCardView(
                      card: pcCard,
                      showBack: false,
                      // Match the outer clip radius so fronts/backs align.
                      shape: _cardShape(
                        _cornerRadiusFor(w, h),
                        cornerStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* =============================================================
 * Front/Back wrapper
 * =========================================================== */

class PlayingCardWidget extends StatelessWidget {
  final bool faceUp;
  final double w, h;
  final CardSpec? card; // nullable → nothing when absent
  /// Optional override; null → CardBackTheme.current.
  final String? backAsset;
  /// If true and card is null, render a back as a placeholder.
  final bool showBackWhenNull;
  final double zoom;
  final CornerStyle cornerStyle;

  @Deprecated('Radius is computed from size and this is ignored.')
  final BorderRadius? borderRadius; // kept for backward compatibility

  const PlayingCardWidget({
    super.key,
    required this.faceUp,
    required this.w,
    required this.h,
    required this.card,
    this.backAsset,
    this.showBackWhenNull = false, // default: render nothing when null
    this.zoom = _kFaceZoom,
    this.cornerStyle = _kCornerStyle,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CardVisibilityGate.enabled,
      builder: (_, on, __) {
        if (!on) return const SizedBox.shrink();
        if (faceUp) {
          if (card == null) return const SizedBox.shrink();
          final child = FaceCard(card, w: w, h: h, zoom: zoom, cornerStyle: cornerStyle);
          return SizedBox(width: w, height: h, child: child);
        } else {
          if (card == null && !showBackWhenNull) return const SizedBox.shrink();
          final child = CardBack(w: w, h: h, asset: backAsset, cornerStyle: cornerStyle);
          return SizedBox(width: w, height: h, child: child);
        }
      },
    );
  }
}

/* =============================================================
 * Simple Widget API expected by ui.dart
 * =========================================================== */

/// Widget version expected by GameScreen UI code.
/// Usage: `PlayingCard(rank: c.rank, suit: c.suit)`
class PlayingCard extends StatelessWidget {
  final String rank;
  final String suit;
  final double? w; // optional sizing if caller wants to force
  final double? h;
  final double zoom;
  final CornerStyle cornerStyle;

  const PlayingCard({
    super.key,
    required this.rank,
    required this.suit,
    this.w,
    this.h,
    this.zoom = _kFaceZoom,
    this.cornerStyle = _kCornerStyle,
  });

  @override
  Widget build(BuildContext context) {
    // If width/height not provided, let parent (e.g., FittedBox) size us.
    final child = FaceCard(
      CardSpec(rank, suit),
      w: (w ?? 60),
      h: (h ?? 60 * _kCardAspect),
      zoom: zoom,
      cornerStyle: cornerStyle,
    );

    // If no explicit size provided, return the inner without SizedBox wrapper
    if (w == null || h == null) return child;
    return SizedBox(width: w, height: h, child: child);
  }
}

/* =============================================================
 * Suit/value helpers
 * =========================================================== */

CardSpec? _coerceToCardSpec(Object? any) {
  if (any == null) return null;
  if (any is CardSpec) return any;
  if (any is String) return _parseCodeOrNull(any);

  try {
    final d = any as dynamic;
    var rank = (d.rank ?? d.value ?? d.r ?? d.face ?? d.name);
    var suit = (d.suit ?? d.s ?? d.suite ?? d.color);
    if (rank is Enum) rank = rank.name;
    if (suit is Enum) suit = suit.name;
    if (rank == null || suit == null) return null;

    final rU = ('$rank').toUpperCase().trim();
    final r = (rU == 'T')
        ? '10'
        : (const {'ACE': 'A', 'KING': 'K', 'QUEEN': 'Q', 'JACK': 'J'}[rU] ?? rU);

    final s = _normalizeSuit('$suit');
    if (s.isEmpty) return null;

    return CardSpec(r, s);
  } catch (_) {
    return null;
  }
}

CardSpec? _parseCodeOrNull(String code) {
  final raw = code.trim();
  if (raw.isEmpty) return null;

  final first = raw[0];
  final last = raw[raw.length - 1];

  String suit, rank;
  if (_isSuitChar(last)) {
    suit = last;
    rank = raw.substring(0, raw.length - 1);
  } else if (_isSuitChar(first)) {
    suit = first;
    rank = raw.substring(1);
  } else {
    // No suit provided → invalid for our UI (we won’t guess)
    return null;
  }

  final ru = rank.trim().toUpperCase();
  final r = (ru == 'T') ? '10' : ru;
  final s = _normalizeSuit(suit);
  if (s.isEmpty) return null;

  return CardSpec(r, s);
}

// Legacy helper kept for any existing callers:
String _normalizeSuit(String s) {
  final u = s.trim().toUpperCase();
  if (u == 'S' || s == '♠' || u.startsWith('SPADE')) return 'S';
  if (u == 'H' || s == '♥' || u.startsWith('HEART')) return 'H';
  if (u == 'D' || s == '♦' || u.startsWith('DIAMOND')) return 'D';
  if (u == 'C' || s == '♣' || u.startsWith('CLUB')) return 'C';
  return ''; // unknown → invalid → render nothing
}

bool _isSuitChar(String ch) {
  const set = {'S', 'H', 'D', 'C', 's', 'h', 'd', 'c', '♠', '♥', '♦', '♣'};
  return set.contains(ch);
}

pc.Suit? _toSuit(String s) {
  switch (_normalizeSuit(s)) {
    case 'S':
      return pc.Suit.spades;
    case 'H':
      return pc.Suit.hearts;
    case 'D':
      return pc.Suit.diamonds;
    case 'C':
      return pc.Suit.clubs;
  }
  return null;
}

pc.CardValue? _toValue(String r) {
  final u = r.trim().toUpperCase();
  switch (u) {
    case 'A':
      return pc.CardValue.ace;
    case 'K':
      return pc.CardValue.king;
    case 'Q':
      return pc.CardValue.queen;
    case 'J':
      return pc.CardValue.jack;
    case 'T':
    case '10':
      return pc.CardValue.ten;
    case '9':
      return pc.CardValue.nine;
    case '8':
      return pc.CardValue.eight;
    case '7':
      return pc.CardValue.seven;
    case '6':
      return pc.CardValue.six;
    case '5':
      return pc.CardValue.five;
    case '4':
      return pc.CardValue.four;
    case '3':
      return pc.CardValue.three;
    case '2':
      return pc.CardValue.two;
  }
  return null;
}

/* =============================================================
 * HoleCards fan (tight overlap for seat cards)
 * =========================================================== */

/// Compact fan for 2–3 hole cards with configurable overlap.
/// Default overlap = 0.5 (50%), so group width ≈ 1.5 × cardWidth for 2 cards.
class HoleCards extends StatelessWidget {
  /// Provide concrete specs (rank+suit), null entries are ignored.
  final List<CardSpec?> specs;

  /// Render faces (true) or backs (false).
  final bool faceUp;

  /// Size of a single card (width). Height is computed from aspect.
  final double cardWidth;

  /// Card aspect ratio (height = width * aspect). Default matches this file.
  final double aspect;

  /// Overlap fraction between consecutive cards (0.0 = no overlap, 0.5 = 50%).
  final double overlap;

  /// Total spread angle across the fan in degrees. Set 0 for a straight stack.
  final double fanAngleDeg;

  /// Back image to use when faceUp == false.
  final String? backAsset;

  /// Which edge to rotate around (usually left looks natural).
  final Alignment pivot;

  /// If true, rightmost card paints on top (typical for hole cards).
  final bool rightmostOnTop;

  /// Playing card vector zoom.
  final double zoom;

  /// Corner style (continuous by default).
  final CornerStyle cornerStyle;

  const HoleCards({
    super.key,
    required this.specs,
    required this.faceUp,
    required this.cardWidth,
    this.aspect = _kCardAspect,
    this.overlap = 0.5,       // ← 50% as requested
    this.fanAngleDeg = 8,     // small tasteful fan; try 4–10
    this.backAsset,
    this.pivot = Alignment.centerLeft,
    this.rightmostOnTop = true,
    this.zoom = _kFaceZoom,
    this.cornerStyle = _kCornerStyle,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CardVisibilityGate.enabled,
      builder: (_, on, __) {
        if (!on) return const SizedBox.shrink();
        // Filter out nulls so we don't render phantom cards.
        final cards = specs.where((c) => c != null).cast<CardSpec>().toList();
        if (cards.isEmpty) return const SizedBox.shrink();
        final cw = cardWidth;
        final ch = cw * aspect;
        final step = cw * (1 - overlap).clamp(0.0, 1.0);
        final n = cards.length;
        final totalW = cw + (n - 1) * step;
        final totalH = ch;
        final totalAngle = (n > 1) ? (fanAngleDeg * math.pi / 180.0) : 0.0;
        final anglePer = (n > 1) ? (totalAngle / (n - 1)) : 0.0;
        final startAngle = -totalAngle / 2;
        List<Widget> built = List<Widget>.generate(n, (i) {
          final spec = cards[i];
          if (faceUp) {
            return FaceCard(
              spec,
              w: cw,
              h: ch,
              zoom: zoom,
              cornerStyle: cornerStyle,
            );
          } else {
            return CardBack(
              w: cw,
              h: ch,
              asset: backAsset,
              cornerStyle: cornerStyle,
            );
          }
        });
        final indices = List<int>.generate(n, (i) => i);
        final order = rightmostOnTop ? indices : indices.reversed;
        return SizedBox(
          width: totalW,
          height: totalH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final i in order)
                Positioned(
                  left: i * step,
                  top: 0,
                  width: cw,
                  height: ch,
                  child: Transform.rotate(
                    angle: startAngle + i * anglePer,
                    alignment: pivot,
                    child: built[i],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
