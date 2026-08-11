// lib/ui/screens/game_screen/dealer_pot.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/* ============================================================================
 * Legacy Renoir Dealer (disabled by default; overlay dealer is primary)
 * ==========================================================================*/
enum _DealerAct { idle, shuffle, bow }

class LegacyRenoirDealer extends StatefulWidget {
  final String asset;
  final double railWidth;
  final double height;
  final Duration shuffleLoop;
  final Duration bowDuration;
  final double bowAngle;
  final Color cardColor;
  final double cardOpacity;
  final bool enabled;
  final double liftPx;

  const LegacyRenoirDealer({
    super.key,
    required this.asset,
    required this.railWidth,
    this.height = 220,
    this.shuffleLoop = const Duration(milliseconds: 700),
    this.bowDuration = const Duration(milliseconds: 900),
    this.bowAngle = -0.18,
    this.cardColor = Colors.white,
    this.cardOpacity = 0.85,
    this.enabled = false,
    this.liftPx = 0,
  });

  @override
  State<LegacyRenoirDealer> createState() => LegacyRenoirDealerState();
}

class LegacyRenoirDealerState extends State<LegacyRenoirDealer>
    with TickerProviderStateMixin {
  _DealerAct _act = _DealerAct.idle;

  late final AnimationController _idleCtrl;
  late final AnimationController _shuffleCtrl;
  late final AnimationController _bowCtrl;

  @override
  void initState() {
    super.initState();
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _shuffleCtrl =
        AnimationController(vsync: this, duration: widget.shuffleLoop);
    _bowCtrl = AnimationController(vsync: this, duration: widget.bowDuration);
  }

  @override
  void dispose() {
    _idleCtrl.dispose();
    _shuffleCtrl.dispose();
    _bowCtrl.dispose();
    super.dispose();
  }

  Future<void> shuffle({int? loops}) async {
    if (!mounted) return;
    setState(() => _act = _DealerAct.shuffle);
    _shuffleCtrl.stop();
    if (loops == null) {
      _shuffleCtrl.repeat();
      return;
    }
    for (int i = 0; i < loops; i++) {
      await _shuffleCtrl.forward(from: 0);
      if (!mounted) return;
    }
    stop();
  }

  void stop() {
    if (!mounted) return;
    _shuffleCtrl.stop();
    setState(() => _act = _DealerAct.idle);
  }

  Future<void> bow() async {
    if (!mounted) return;
    _shuffleCtrl.stop();
    setState(() => _act = _DealerAct.bow);
    await _bowCtrl.forward(from: 0);
    if (!mounted) return;
    await _bowCtrl.reverse();
    if (mounted) setState(() => _act = _DealerAct.idle);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    final double kissRail = widget.railWidth / 2;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Transform.translate(
          offset: Offset(0, -(kissRail + widget.liftPx)),
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_idleCtrl, _bowCtrl, _shuffleCtrl]),
              builder: (_, __) {
                // Subtle idle bob/tilt
                final double s = _idleCtrl.value * 2 * math.pi;
                final double idleBob = math.sin(s) * 1.6;
                final double idleTilt = math.sin(s) * 0.01;

                // Bow ease: down then up
                final bool bowing = _act == _DealerAct.bow;
                final double bowT = bowing ? _bowCtrl.value : 0.0;
                final double bowAngle = widget.bowAngle *
                    (bowT <= 0.5 ? (bowT * 2) : (1 - (bowT - 0.5) * 2));

                final m = Matrix4.identity()
                  ..translate(0.0, idleBob)
                  ..rotateZ(idleTilt)
                  ..setEntry(3, 2, -0.0018) // subtle perspective
                  ..rotateX(bowAngle);

                return Transform(
                  alignment: Alignment.bottomCenter,
                  transform: m,
                  child: SizedBox(
                    height: widget.height,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Dealer image
                        Semantics(
                          label: 'Renoir dealer',
                          child: Image.asset(
                            widget.asset,
                            height: widget.height,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) => SizedBox(
                              height: widget.height,
                              child: const Center(
                                child: Icon(Icons.person,
                                    size: 40, color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                        // Simple shuffle stripes overlay
                        if (_act == _DealerAct.shuffle)
                          _ShuffleStrips(
                            t: _shuffleCtrl.value,
                            width: widget.height * 0.90,
                            height: widget.height * 0.38,
                            color: widget.cardColor
                                .withValues(alpha: widget.cardOpacity),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ShuffleStrips extends StatelessWidget {
  final double t;
  final double width;
  final double height;
  final Color color;
  const _ShuffleStrips({
    required this.t,
    required this.width,
    required this.height,
    required this.color,
  });

  double _ease(double x) => 0.5 - 0.5 * math.cos(x.clamp(0.0, 1.0) * math.pi);

  @override
  Widget build(BuildContext context) {
    final cardW = width * 0.18;
    final cardH = height * 0.55;
    final gapY = height * 0.10;
    final a = _ease(t);
    final b = _ease((t + 0.5) % 1.0);
    final leftX = -width * 0.42 + a * (width * 0.42);
    final rightX = width * 0.42 - b * (width * 0.42);

    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _strip(x: leftX, y: -gapY, w: cardW, h: cardH, tilt: -0.08),
            _strip(x: rightX, y: gapY, w: cardW, h: cardH, tilt: 0.08),
          ],
        ),
      ),
    );
  }

  Widget _strip({
    required double x,
    required double y,
    required double w,
    required double h,
    required double tilt,
  }) {
    return Transform.translate(
      offset: Offset(x, y),
      child: Transform.rotate(
        angle: tilt,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

/* ============================================================================
 * Pot chip (used by UI on the bottom rail)
 * ==========================================================================*/
class PotChip extends StatelessWidget {
  final double pot;
  final bool compact; // if true, round to whole; otherwise show full double
  final double? currentBet;
  final int? activePlayers;

  const PotChip({
    super.key,
    required this.pot,
    this.compact = true,
    this.currentBet,
    this.activePlayers,
  });

  String _fmt(double v) {
    if (compact) {
      // 12.3K, 1.2M etc.
      final nf = NumberFormat.compact();
      return nf.format(v);
    }
    final nf = NumberFormat.decimalPattern();
    return nf.format(v);
  }

  @override
  Widget build(BuildContext context) {
    final label = 'Pot ${_fmt(pot)}';
    final String? meta = _buildMetaLine();
    return Semantics(
      label: meta == null ? 'Pot amount $label' : '$label, $meta',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              offset: Offset(0, 2),
              blurRadius: 6,
              spreadRadius: 1,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.4,
              ),
            ),
            if (meta != null) ...[
              const SizedBox(height: 2),
              Text(
                meta,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _buildMetaLine() {
    final pieces = <String>[];
    final double? bet = currentBet;
    if (bet != null && bet > 0) {
      pieces.add('Bet ${_fmt(bet)}');
    }
    final int? players = activePlayers;
    if (players != null && players > 0) {
      pieces.add('$players in');
    }
    if (pieces.isEmpty) return null;
    return pieces.join(' • ');
  }
}

/* ============================================================================
 * PotRailCapsule — optional helper that auto-matches rail height
 *    Use when embedding directly as TableFelt.bottomRailChild
 * ==========================================================================*/
class PotRailCapsule extends StatelessWidget {
  final int pot; // integer chips
  final double railThickness; // pass TableFelt.railWidth

  const PotRailCapsule({
    super.key,
    required this.pot,
    required this.railThickness,
  });

  String _fmt(int v) => NumberFormat.compact().format(v);

  @override
  Widget build(BuildContext context) {
    final label = 'Pot ${_fmt(pot)}';
    return SizedBox(
      height: railThickness, // exact visual height as the wooden rail
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(railThickness / 2),
            border: Border.all(
              color: Colors.white70.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                offset: Offset(0, 2),
                blurRadius: 6,
                spreadRadius: 1,
              )
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
