// ===============================
// lib/ui/screens/game_screen/table_ui.dart
// Seats "kiss" the rail (no overlap):
//  - Inner layout rect is felt deflated by a tiny visual margin (≈1px).
//  - Seats are clamped inside that rect so they never bleed onto wood.
//  - All geometry (boardCenter, seatTargets, origin) stays in FELT space.
// ===============================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'table.dart' show TableFelt, WoodType;
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
  final Offset origin; // deck origin in FELT space
  final List<Offset> seatTargets; // per-seat target centers in FELT space
  final Offset boardCenter; // community row center in FELT space

  const TableGeometry({
    required this.railWidth,
    required this.feltRect,
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

    // Pot
    required this.pot,
    required this.potPulse,

    // Seats / state
    required this.seats,
    required this.heroIndex,
    required this.currentTurn,
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

  // Pot
  final double pot;
  final Animation<double> potPulse;

  // Seats / state
  final List<Seat> seats;
  final int currentTurn, sbIndex, bbIndex, heroIndex;
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

    // Racetrack arc layout (matches top-layer seats): ~60–65% arc, bottom-centered,
    // hero anchored to slot index 4 (5th from left/clockwise).
    final int seatCount = widget.seats.length;
    final List<Offset> seatPositions = <Offset>[];
    if (seatCount > 0) {
      const double baseReservedTopFraction = 0.40;
      const double minReservedTopFraction = 0.35;
      const double superellipseN = 4.0;
      final double radius = seatSide / 2;
      final double cx = feltRect.center.dx;
      final double cy = feltRect.center.dy;
      final double a = math.max(radius, feltRect.width / 2 + railW - radius);
      final double b = math.max(radius, feltRect.height / 2 + railW - radius);

      double reservedTopFraction = baseReservedTopFraction;
      if (seatCount > 1) {
        final double minSpacing = seatSide * 1.05;
        final double rEff = math.min(a, b);
        final double stepNeeded =
            2 * math.asin((minSpacing / 2) / math.max(rEff, 1e-3));
        final double requiredAngle = stepNeeded * seatCount;
        final double candidateReserved = 1 - (requiredAngle / (2 * math.pi));
        reservedTopFraction = math.max(
          minReservedTopFraction,
          math.min(baseReservedTopFraction, candidateReserved),
        );
      }

      final double reservedAngle = reservedTopFraction * 2 * math.pi;
      final double availableAngle = (2 * math.pi) - reservedAngle;
      final double start = (math.pi / 2) - (availableAngle / 2);

      Offset pointAt(double theta) {
        final double cosT = math.cos(theta);
        final double sinT = math.sin(theta);
        final double px = a *
            math.pow(cosT.abs(), 2 / superellipseN).toDouble() *
            (cosT >= 0 ? 1 : -1);
        final double py = b *
            math.pow(sinT.abs(), 2 / superellipseN).toDouble() *
            (sinT >= 0 ? 1 : -1);
        return Offset(cx + px - radius, cy + py - radius);
      }

      const int samples = 400;
      final List<double> angles = List<double>.generate(
        samples,
        (i) => start + (availableAngle * i) / (samples - 1),
      );
      final List<Offset> pts = [for (final ang in angles) pointAt(ang)];

      final List<double> cumDist = [0];
      for (int i = 1; i < pts.length; i++) {
        cumDist.add(cumDist.last + (pts[i] - pts[i - 1]).distance);
      }
      final double totalLen = cumDist.last;

      final List<Offset> slots = <Offset>[];
      for (int i = 0; i < seatCount; i++) {
        final double target =
            seatCount == 1 ? 0.0 : (totalLen * i) / (seatCount - 1);
        int idx = cumDist.indexWhere((d) => d >= target);
        if (idx <= 0) {
          slots.add(pts.first);
        } else if (idx == -1 || idx >= cumDist.length) {
          slots.add(pts.last);
        } else {
          final double prevD = cumDist[idx - 1];
          final double nextD = cumDist[idx];
          final double t = (nextD - prevD).abs() < 1e-6
              ? 0.0
              : ((target - prevD) / (nextD - prevD)).clamp(0.0, 1.0);
          final Offset p = Offset.lerp(pts[idx - 1], pts[idx], t)!;
          slots.add(p);
        }
      }

      final int heroIdx =
          (widget.heroIndex >= 0 && widget.heroIndex < seatCount)
              ? widget.heroIndex
              : -1;
      final int heroSlot = seatCount > 4 ? 4 : math.max(0, seatCount - 1);
      int shift = 0;
      if (heroIdx != -1 && seatCount > 0) {
        shift = (heroSlot - heroIdx) % seatCount;
        if (shift < 0) shift += seatCount;
      }

      for (int i = 0; i < seatCount; i++) {
        final int slotIdx = (i + shift) % seatCount;
        seatPositions.add(slots[slotIdx]);
      }
    }

    // 6) Seat card targets (a bit above seat mid)
    final seatTargets = <Offset>[
      for (final p in seatPositions)
        Offset(p.dx + seatSide * 0.5, p.dy + seatSide * 0.32),
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
    final double chipSize = (seatSide * 0.46).clamp(26.0, 52.0).toDouble();
    final bool chipsOnRail =
        widget.blindChipPlacement == BlindChipPlacement.rail;
    final Rect chipClampRect = chipsOnRail ? Rect.fromLTWH(0, 0, w, h) : inner;
    final List<Widget> blindChips = widget.showBlindChips
        ? buildBlindChips(
            seats: widget.seats,
            hiddenSeatIdx: widget.hiddenSeatIdx,
            seatPositions: seatPositions,
            seatSide: seatSide,
            boardCenter: boardCenter,
            feltRect: feltRect,
            clampRect: chipClampRect,
            chipSize: chipSize,
            placement: widget.blindChipPlacement,
            railWidth: railW,
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
                child: const SizedBox.expand(),
              ),

              // Logo locked to rail, under everything except Renoir/hands.
              Positioned(
                left: railW,
                right: railW,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: true,
                  child: SizedBox(
                    height: railW, // exact rail height
                    child: Center(
                      child: Transform.scale(
                        scaleX: 1.0,
                        scaleY:
                            1.21, // +10% height boost over previous (≈21% vs base)
                        child: _RailBrandBadge(
                          heroTurnActive:
                              canAct && widget.currentTurn == widget.heroIndex,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 2) MID FELT OVERLAY (cards layer) — inside felt, below seats
              if (widget.midFeltOverlay != null)
                Positioned.fromRect(
                  rect: feltRect,
                  child: widget.midFeltOverlay!,
                ),

              // 3) SB / BB chips on the felt, tucked near their seats
              ...blindChips,

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
                          seatMaxWidth: seatSide,
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
  required Offset boardCenter,
  required Rect feltRect,
  required Rect clampRect,
  required double chipSize,
  required BlindChipPlacement placement,
  required double railWidth,
  required int sbIndex,
  required int bbIndex,
  required int heroIndex,
}) {
  if (seatPositions.isEmpty || chipSize <= 0) return const <Widget>[];

  final List<Widget> chips = [];

  void addChip(int seatIdx, bool isSB) {
    if (seatIdx < 0 ||
        seatIdx >= seatPositions.length ||
        seatIdx >= seats.length) {
      return;
    }
    if (hiddenSeatIdx.contains(seatIdx)) return;

    final seat = seats[seatIdx];
    if (seat.busted) return;

    final Offset? center = _resolveBlindChipCenter(
      seatTopLeft: seatPositions[seatIdx],
      seatSide: seatSide,
      boardCenter: boardCenter,
      clampRect: clampRect,
      chipSize: chipSize,
      feltRect: feltRect,
      placement: placement,
      railWidth: railWidth,
      heroSeat: seatIdx == heroIndex,
    );
    if (center == null) return;

    chips.add(
      Positioned(
        left: center.dx - chipSize / 2,
        top: center.dy - chipSize / 2,
        child: _BlindChip(
          label: isSB ? 'SB' : 'BB',
          isSmallBlind: isSB,
          size: chipSize,
        ),
      ),
    );
  }

  addChip(sbIndex, true);
  addChip(bbIndex, false);
  return chips;
}

Offset? _resolveBlindChipCenter({
  required Offset seatTopLeft,
  required double seatSide,
  required Offset boardCenter,
  required Rect clampRect,
  required double chipSize,
  required Rect feltRect,
  required BlindChipPlacement placement,
  required double railWidth,
  required bool heroSeat,
}) {
  final Offset seatCenter =
      Offset(seatTopLeft.dx + seatSide / 2, seatTopLeft.dy + seatSide / 2);

  // Slide the tag toward the table center so it sits between the seat and the felt center.
  final Offset toCenter = boardCenter - seatCenter;
  final double dist = toCenter.distance;
  if (dist <= 1e-3) return null;
  final Offset dir = toCenter / dist;
  final double travel = seatSide * 0.55;
  final Offset desired = seatCenter + dir * travel;

  final double minDx = clampRect.left + chipSize / 2;
  final double maxDx = clampRect.right - chipSize / 2;
  final double minDy = clampRect.top + chipSize / 2;
  final double maxDy = clampRect.bottom - chipSize / 2;

  final double clampedX = desired.dx.clamp(minDx, math.max(minDx, maxDx));
  final double clampedY = desired.dy.clamp(minDy, math.max(minDy, maxDy));
  return Offset(clampedX, clampedY);
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

class _BlindChip extends StatelessWidget {
  const _BlindChip({
    required this.label,
    required this.isSmallBlind,
    required this.size,
  });

  final String label;
  final bool isSmallBlind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final List<Color> gradient = isSmallBlind
        ? const [Color(0xFFFFE0B2), Color(0xFFFF9800)]
        : const [Color(0xFFFFD180), Color(0xFFFB8C00)];
    const Color textColor = Color(0xFF2C1600);

    return IgnorePointer(
      child: Opacity(
        opacity: 0.5,
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
              color: Colors.white.withValues(alpha: 0.78),
              width: size * 0.08,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: size * 0.32,
                offset: const Offset(0, 6),
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
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _RailBrandBadge extends StatelessWidget {
  const _RailBrandBadge({required this.heroTurnActive});

  final bool heroTurnActive;

  @override
  Widget build(BuildContext context) {
    final Color bg =
        heroTurnActive ? const Color(0xFF24B6FF) : const Color(0xFFFF2800);
    final Color fg = heroTurnActive ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        boxShadow: const [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ten of a Kind',
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
