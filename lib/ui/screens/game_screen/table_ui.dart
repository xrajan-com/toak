// ===============================
// lib/ui/screens/game_screen/table_ui.dart
// Seats "kiss" the rail (no overlap):
//  - Inner layout rect is felt deflated by a tiny visual margin (≈1px).
//  - Seats are clamped inside that rect so they never bleed onto wood.
//  - All geometry (boardCenter, seatTargets, origin) stays in FELT space.
// ===============================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'seat_layout.dart' show stadiumSeatTopLeftPositions;
import 'seat_card_layout.dart' show seatAvatarVisualRect;
import 'table.dart' show TableFelt, WoodType, playerSafeFeltRRect;
import 'players.dart' show Seat, SeatWidget, seatFallbackAsset;
import 'renoir_ui.dart' show RenoirSignals;

/* --------------------------------- API ---------------------------------- */

enum BlindChipPlacement {
  felt,
  rail,
}

class TableGeometry {
  final double railWidth;
  final Rect feltRect; // inside-rail rect in local space
  final RRect playerSafeRRect; // inside the visible inset felt line
  final Offset origin; // deck origin in FELT space
  final List<Offset> seatTargets; // per-seat target centers in FELT space
  final Offset boardCenter; // community row center in FELT space

  const TableGeometry({
    required this.railWidth,
    required this.feltRect,
    required this.playerSafeRRect,
    required this.origin,
    required this.seatTargets,
    required this.boardCenter,
  });
}

class GameTableLayer extends StatefulWidget {
  const GameTableLayer({
    super.key,
    // Size
    required this.width,
    required this.height,
    this.railWidth = 34.0,

    // Visuals
    required this.felt,
    required this.wood,
    this.watermarkSvgAsset,
    this.watermarkOpacity = 0.18,
    this.watermarkAlignment = Alignment.center,
    this.tintWhite = false,
    this.watermarkColor,

    // Pot
    required this.pot,
    required this.potPulse,

    // Seats / state
    required this.seats,
    required this.heroIndex,
    required this.currentTurn,
    this.dealerIndex = -1,
    required this.sbIndex,
    required this.bbIndex,
    this.hiddenSeatIdx = const {},

    // Seat visuals / sizing hints (forwarded to SeatWidget)
    required this.defaultProfileAsset,
    required this.seatMaxW,
    required this.seatH,
    required this.baseCardW,
    required this.baseCardH,
    required this.cardBackAsset,
    this.showToggleVisible = false,
    this.heroShow = false,

    // Layout tuning
    this.communityRowTopFrac = 0.30,
    this.topGapRadians = math.pi / 3,
    this.softBandRadians = math.pi / 10,
    this.pushDownFrac = 0.10,

    // Cards layer slot
    this.midFeltOverlay,
    this.paintSeats = true,

    // NEW: tiny keep-off-rail guard (px). Set 0.0 for literal edge contact.
    this.seatVisualMarginPx = 1.0,

    // Table adornments
    this.showBlindChips = true,
    this.blindChipPlacement = BlindChipPlacement.felt,

    // Callback
    this.onGeometryChanged,
  });

  // Size
  final double width;
  final double height;
  final double railWidth;

  // Visuals
  final Color felt;
  final WoodType wood;
  final String? watermarkSvgAsset;
  final double watermarkOpacity;
  final Alignment watermarkAlignment;
  final bool tintWhite;
  final Color? watermarkColor;

  // Pot
  final double pot;
  final Animation<double> potPulse;

  // Seats / state
  final List<Seat> seats;
  final int currentTurn, dealerIndex, sbIndex, bbIndex, heroIndex;
  final Set<int> hiddenSeatIdx;

  // Seat visuals / sizing hints
  final String defaultProfileAsset;
  final double seatMaxW, seatH;
  final double baseCardW, baseCardH;
  final String cardBackAsset;
  final bool showToggleVisible, heroShow;

  // Layout tuning
  final double communityRowTopFrac;
  final double topGapRadians;
  final double softBandRadians;
  final double pushDownFrac;

  // Cards layer slot
  final Widget? midFeltOverlay;
  final bool paintSeats;

  /// Minimal clearance between seat outer bounds and the felt edge (px).
  /// Use 0.0 to *literally* touch; keep ≥1.0 if your seats cast shadows/glows.
  final double seatVisualMarginPx;

  /// Show SB / BB chips and choose where they live (felt or rail).
  final bool showBlindChips;
  final BlindChipPlacement blindChipPlacement;

  // Geometry callback
  final ValueChanged<TableGeometry>? onGeometryChanged;

  @override
  State<GameTableLayer> createState() => _GameTableLayerState();
}

class _GameTableLayerState extends State<GameTableLayer> {
  TableGeometry? _lastGeom;

  bool _geomsEqual(TableGeometry a, TableGeometry b) {
    if (a.railWidth != b.railWidth) return false;
    if (a.feltRect != b.feltRect) return false;
    if (a.playerSafeRRect != b.playerSafeRRect) return false;
    if (a.origin != b.origin) return false;
    if (a.boardCenter != b.boardCenter) return false;
    final t1 = a.seatTargets, t2 = b.seatTargets;
    if (t1.length != t2.length) return false;
    for (int i = 0; i < t1.length; i++) {
      if (t1[i] != t2[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = widget.height;
    final railW = widget.railWidth;

    // 0) Felt rect (inside the rail)
    final feltW = (w - railW * 2).clamp(1.0, w);
    final feltH = (h - railW * 2).clamp(1.0, h);
    final feltRect = Rect.fromLTWH(railW, railW, feltW, feltH);

    // 1) Inner rect used for seat placement (just a hair inside the felt)
    final double pad = widget.seatVisualMarginPx.clamp(0.0, 12.0);
    final Rect inner = _deflateClamped(feltRect, pad);
    final innerW = inner.width;
    final innerH = inner.height;

    // Seat sizing
    final seatW = widget.seatMaxW;
    final seatHpx = widget.seatH;
    final seatSide = math.min(seatW, seatHpx);
    final int seatCount = widget.seats.length;
    final RRect playerSafeBoundary = playerSafeFeltRRect(Size(w, h), railW);
    final List<Offset> seatPositions = stadiumSeatTopLeftPositions(
      safeStadiumRect: playerSafeBoundary.outerRect,
      seatCount: seatCount,
      heroIndex: widget.heroIndex,
      seatSize: seatSide,
      visualFootprintSize: seatAvatarVisualRect(
        Rect.fromLTWH(0, 0, seatSide, seatSide),
      ).width,
      maximumVisualScale: 1.10,
      boundaryGap: widget.seatVisualMarginPx,
    );

    // 6) Deal targets use the visible avatar centre.
    final seatTargets = <Offset>[
      for (final p in seatPositions)
        Offset(p.dx + seatSide * 0.5, p.dy + seatSide * 0.5),
    ];

    // 7) Board center — respects inner (so it won’t collide with rail either)
    final boardTopInInner =
        (innerH * widget.communityRowTopFrac - widget.baseCardH / 2)
            .clamp(0.0, innerH - widget.baseCardH);
    final boardCenter = Offset(inner.left + innerW / 2,
        inner.top + boardTopInInner + widget.baseCardH / 2);

    // 8) Deck origin (slightly above the top rail, centered)
    final origin = Offset(feltRect.center.dx, feltRect.top - railW * 0.05);

    final geom = TableGeometry(
      railWidth: railW,
      feltRect: feltRect,
      playerSafeRRect: playerSafeBoundary,
      origin: origin,
      seatTargets: seatTargets,
      boardCenter: boardCenter,
    );

    // Defer geometry notifications until after this frame to avoid
    // "setState() called during build" in parents.
    if (widget.onGeometryChanged != null) {
      final last = _lastGeom;
      if (last == null || !_geomsEqual(last, geom)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Double-check again in case build/layout changed rapidly.
          if (_lastGeom == null || !_geomsEqual(_lastGeom!, geom)) {
            _lastGeom = geom; // cache without triggering rebuild
            widget.onGeometryChanged!(geom);
          }
        });
      }
    }

    final leaderIndex = _leaderIndex(widget.seats, widget.hiddenSeatIdx);
    final double chipSize = (seatSide * 0.34).clamp(24.0, 40.0).toDouble();
    final bool chipsOnRail =
        widget.blindChipPlacement == BlindChipPlacement.rail;
    final Rect chipClampRect = chipsOnRail ? Rect.fromLTWH(0, 0, w, h) : inner;
    final List<Widget> blindChips = widget.showBlindChips
        ? buildBlindChips(
            seats: widget.seats,
            hiddenSeatIdx: widget.hiddenSeatIdx,
            seatPositions: seatPositions,
            seatSide: seatSide,
            tableCenter: feltRect.center,
            clampRect: chipClampRect,
            chipSize: chipSize,
            dealerIndex: widget.dealerIndex,
            sbIndex: widget.sbIndex,
            bbIndex: widget.bbIndex,
            heroIndex: widget.heroIndex,
          )
        : const [];

    // Build
    return ValueListenableBuilder<bool>(
      valueListenable: RenoirSignals.canAct,
      builder: (context, canAct, _) {
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1) Rail + felt + watermark
              TableFelt(
                width: w,
                height: h,
                felt: widget.felt,
                wood: widget.wood,
                railWidth: railW,
                watermarkSvgAsset: (widget.watermarkSvgAsset != null &&
                        widget.watermarkSvgAsset!.isNotEmpty)
                    ? widget.watermarkSvgAsset
                    : null,
                watermarkOpacity: widget.watermarkOpacity,
                watermarkAlignment: widget.watermarkAlignment,
                tintWhite: widget.tintWhite,
                watermarkColor: widget.watermarkColor,
                child: const SizedBox.expand(),
              ),

              // 2) MID FELT OVERLAY (cards layer) — inside felt, below seats
              if (widget.midFeltOverlay != null)
                Positioned.fromRect(
                  rect: feltRect,
                  child: widget.midFeltOverlay!,
                ),

              // 3) D / SB / BB chips on the felt, tucked near their seats
              ...blindChips,

              // 3b) POT — upper-left of the felt, on the dealer's side.
              // `pot` and `potPulse` were passed into this widget but never
              // drawn, so the table had no pot figure at all and every bet
              // was buried inside a nameplate as "· 200".
              Positioned(
                left: feltRect.left + feltRect.width * 0.055,
                top: feltRect.top + feltRect.height * 0.085,
                child: _PotPill(
                  pot: widget.pot,
                  streetBets: widget.seats.fold<int>(
                    0,
                    (int sum, Seat s) => sum + (s.bet > 0 ? s.bet : 0),
                  ),
                  height: (feltRect.height * 0.085)
                      .clamp(22.0, 44.0)
                      .toDouble(),
                ),
              ),

              // 4) SEATS — placed so they "kiss" the felt edge (no rail overlap)
              if (widget.paintSeats)
                for (final e in seatPositions.asMap().entries)
                  if (!widget.hiddenSeatIdx.contains(e.key))
                    Positioned(
                      left: e.value.dx,
                      top: e.value.dy,
                      child: SizedBox(
                        width: seatSide,
                        height: seatSide,
                        child: SeatWidget(
                          seat: widget.seats[e.key],
                          isLeader: leaderIndex == e.key,
                          growWhenOthersGone:
                              widget.seats.any((s) => s.busted) ||
                                  widget.hiddenSeatIdx.isNotEmpty,
                          onFadeDone: null,
                          isTurn: canAct && (e.key == widget.currentTurn),
                          isSB: e.key == widget.sbIndex,
                          isBB: e.key == widget.bbIndex,
                          fallbackAvatarAsset: seatFallbackAsset(
                            widget.seats[e.key],
                            widget.defaultProfileAsset,
                          ),
                          seatMaxWidth: widget.seatMaxW,
                          seatHeight: seatSide,
                        ),
                      ),
                    ),

              // DEBUG: visualize inner boundary used for seats
              // Positioned.fromRect(
              //   rect: inner,
              //   child: IgnorePointer(
              //     child: Container(
              //       decoration: BoxDecoration(
              //         border: Border.all(color: Colors.white24, width: 1,
              //           strokeAlign: BorderSide.strokeAlignInside),
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        );
      },
    );
  }

  /* ----------------------------- Helpers -------------------------------- */

  int? _leaderIndex(List<Seat> seats, Set<int> hidden) {
    int? idx;
    int maxChips = -1;
    for (int i = 0; i < seats.length; i++) {
      final s = seats[i];
      if (hidden.contains(i)) continue;
      if (s.busted) continue;
      if (s.chips > maxChips) {
        maxChips = s.chips;
        idx = i;
      }
    }
    if (idx == null) return null;

    final ties = seats.asMap().entries.where((e) {
      final i = e.key;
      final s = e.value;
      return !hidden.contains(i) && !s.busted && s.chips == maxChips;
    }).length;

    if (ties > 1) return null;
    return idx;
  }
}

List<Widget> buildBlindChips({
  required List<Seat> seats,
  required Set<int> hiddenSeatIdx,
  required List<Offset> seatPositions,
  required double seatSide,
  required Offset tableCenter,
  required Rect clampRect,
  required double chipSize,
  int dealerIndex = -1,
  required int sbIndex,
  required int bbIndex,
  required int heroIndex,
}) {
  if (seatPositions.isEmpty || chipSize <= 0) return const <Widget>[];

  final List<Widget> chips = [];

  final Map<int, List<_PositionChipKind>> seatTags =
      <int, List<_PositionChipKind>>{};

  void addTag(int seatIdx, _PositionChipKind kind) {
    if (seatIdx < 0 ||
        seatIdx >= seatPositions.length ||
        seatIdx >= seats.length) {
      return;
    }
    seatTags.putIfAbsent(seatIdx, () => <_PositionChipKind>[]).add(kind);
  }

  addTag(dealerIndex, _PositionChipKind.dealer);
  addTag(sbIndex, _PositionChipKind.smallBlind);
  addTag(bbIndex, _PositionChipKind.bigBlind);

  for (final entry in seatTags.entries) {
    final int seatIdx = entry.key;
    if (hiddenSeatIdx.contains(seatIdx)) continue;

    final Seat seat = seats[seatIdx];
    if (seat.busted) continue;

    final List<Offset> centers = positionChipCentersForSeat(
      seatTopLeft: seatPositions[seatIdx],
      seatSide: seatSide,
      tableCenter: tableCenter,
      clampRect: clampRect,
      chipSize: chipSize,
      tagCount: entry.value.length,
    );
    final List<_PositionChipKind> kinds = entry.value;

    for (int i = 0; i < kinds.length; i++) {
      final Offset center = centers[i];

      chips.add(
        Positioned(
          key: ValueKey<String>(
            'position-chip-${kinds[i].name}-$seatIdx',
          ),
          left: center.dx - chipSize / 2,
          top: center.dy - chipSize / 2,
          child: _PositionChip(
            kind: kinds[i],
            size: chipSize,
            playerName: seat.name,
          ),
        ),
      );
    }
  }

  return chips;
}

/// Pot readout on the felt: what is already in the middle, plus whatever is
/// still sitting in front of players on this street.
///
/// White at 75% so the felt reads through it, black for the settled pot and
/// red for money still live on the current street — the two numbers a player
/// actually needs to size a bet.
class _PotPill extends StatelessWidget {
  const _PotPill({
    required this.pot,
    required this.streetBets,
    required this.height,
  });

  final double pot;
  final int streetBets;
  final double height;

  static String _fmt(num v) {
    final int n = v.round();
    if (n >= 1000000) {
      final double m = n / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      final double k = n / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final int settled = pot.round();
    // Nothing on the table yet: a pill reading "POT 0" is noise.
    if (settled <= 0 && streetBets <= 0) return const SizedBox.shrink();

    final double h = height;
    final double fontSize = (h * 0.42).clamp(10.0, 18.0).toDouble();
    final double labelSize = (h * 0.30).clamp(8.0, 12.0).toDouble();

    return IgnorePointer(
      child: Semantics(
        label: streetBets > 0
            ? 'Pot ${_fmt(settled)}, ${_fmt(streetBets)} still in play'
            : 'Pot ${_fmt(settled)}',
        child: ExcludeSemantics(
          child: Container(
            height: h,
            padding: EdgeInsets.symmetric(horizontal: h * 0.42),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(999),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: h * 0.28,
                  offset: Offset(0, h * 0.08),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  'POT',
                  style: TextStyle(
                    color: const Color(0xFF11110F),
                    fontFamily: 'OpenSans',
                    fontWeight: FontWeight.w700,
                    fontSize: labelSize,
                    letterSpacing: 0.8,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: h * 0.22),
                Text(
                  _fmt(settled),
                  style: TextStyle(
                    color: const Color(0xFF11110F),
                    fontFamily: 'OpenSans',
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize,
                    height: 1.0,
                  ),
                ),
                if (streetBets > 0) ...<Widget>[
                  SizedBox(width: h * 0.24),
                  Text(
                    '+${_fmt(streetBets)}',
                    style: TextStyle(
                      color: const Color(0xFFC41230),
                      fontFamily: 'OpenSans',
                      fontWeight: FontWeight.w800,
                      fontSize: fontSize,
                      height: 1.0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Offset _clampChipCenter(
  Offset center, {
  required Rect clampRect,
  required double chipSize,
}) {
  final double minDx = clampRect.left + chipSize / 2;
  final double maxDx = clampRect.right - chipSize / 2;
  final double minDy = clampRect.top + chipSize / 2;
  final double maxDy = clampRect.bottom - chipSize / 2;
  return Offset(
    center.dx.clamp(minDx, math.max(minDx, maxDx)),
    center.dy.clamp(minDy, math.max(minDy, maxDy)),
  );
}

List<Offset> positionChipCentersForSeat({
  required Offset seatTopLeft,
  required double seatSide,
  required Offset tableCenter,
  required Rect clampRect,
  required double chipSize,
  required int tagCount,
}) {
  if (tagCount <= 0) return const <Offset>[];
  final Offset seatCenter =
      Offset(seatTopLeft.dx + seatSide / 2, seatTopLeft.dy + seatSide / 2);
  final double inwardSign = tableCenter.dx >= seatCenter.dx ? 1.0 : -1.0;
  final double edgeX = inwardSign > 0
      ? seatTopLeft.dx + seatSide - chipSize * 0.28
      : seatTopLeft.dx + chipSize * 0.28;
  final double topY = seatTopLeft.dy + chipSize * 0.38;
  final double spacing = chipSize * 1.08;

  return List<Offset>.generate(tagCount, (int index) {
    final double centeredIndex = index - (tagCount - 1) / 2;
    return _clampChipCenter(
      Offset(edgeX + inwardSign * centeredIndex * spacing, topY),
      clampRect: clampRect,
      chipSize: chipSize,
    );
  }, growable: false);
}

Rect _deflateClamped(Rect r, double pad) {
  if (pad <= 0) return r;
  final dx = pad.clamp(0.0, r.width / 3);
  final dy = pad.clamp(0.0, r.height / 3);
  return Rect.fromLTWH(
    r.left + dx,
    r.top + dy,
    (r.width - 2 * dx).clamp(1.0, r.width),
    (r.height - 2 * dy).clamp(1.0, r.height),
  );
}

enum _PositionChipKind {
  dealer,
  smallBlind,
  bigBlind,
}

class _PositionChip extends StatelessWidget {
  const _PositionChip({
    required this.kind,
    required this.size,
    required this.playerName,
  });

  final _PositionChipKind kind;
  final double size;
  final String playerName;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final List<Color> gradient;
    late final Color textColor;
    late final Color glowColor;
    late final Color borderColor;

    switch (kind) {
      case _PositionChipKind.dealer:
        label = 'D';
        gradient = const [Color(0xFFF36BFF), Color(0xFF8D1BFF)];
        textColor = Colors.white;
        glowColor = const Color(0xFFCC33FF);
        borderColor = const Color(0xFFF7C6FF);
        break;
      case _PositionChipKind.smallBlind:
        label = 'SB';
        gradient = const [Color(0xFFFFC61A), Color(0xFFFF6A00)];
        textColor = const Color(0xFF2C1600);
        glowColor = const Color(0xFFFF7A00);
        borderColor = const Color(0xFFFFE0A3);
        break;
      case _PositionChipKind.bigBlind:
        label = 'BB';
        gradient = const [Color(0xFFFF8A00), Color(0xFFE63E00)];
        textColor = Colors.white;
        glowColor = const Color(0xFFFF4D00);
        borderColor = const Color(0xFFFFC27A);
        break;
    }

    final String roleName = switch (kind) {
      _PositionChipKind.dealer => 'Dealer button',
      _PositionChipKind.smallBlind => 'Small blind',
      _PositionChipKind.bigBlind => 'Big blind',
    };

    return IgnorePointer(
      child: Semantics(
        label: '$roleName for $playerName',
        child: ExcludeSemantics(
          child: Opacity(
            opacity: 0.82,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: borderColor.withValues(alpha: 0.9),
                  width: size * 0.08,
                ),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.42),
                    blurRadius: size * 0.32,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.38,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
