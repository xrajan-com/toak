import 'dart:math' as math;

import 'package:flutter/material.dart';

const Color _kSmokeColor = Color(0xCCB0B0B0);

/// Animated splatter used to mark busted seats on the felt beneath cards.
class SeatBloodStain extends StatelessWidget {
  final bool visible;
  final int seed;

  const SeatBloodStain({
    super.key,
    required this.visible,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 550),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeInOutQuad,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: visible
            ? BloodSplatter(key: ValueKey('blood-$seed'), seed: seed)
            : SizedBox.expand(key: ValueKey('blood-empty-$seed')),
      ),
    );
  }
}

class BloodSplatter extends StatefulWidget {
  final int seed;

  const BloodSplatter({super.key, required this.seed});

  @override
  State<BloodSplatter> createState() => _BloodSplatterState();
}

class _BloodSplatterState extends State<BloodSplatter>
    with TickerProviderStateMixin {
  // Darker, dried-blood palette with subtle edge highlight.
  static const Color _baseColor = Color(0xFF3B0505);
  static const Color _highlightColor = Color(0xFF7A1A1A);

  late final AnimationController _controller;
  late final AnimationController _life;
  late final Animation<double> _pulse;
  late final List<_Drip> _drips;
  late final List<_SmokePlume> _smoke;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _life = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..forward();
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _drips = _generateDrips(widget.seed);
    _smoke = _generateSmoke(widget.seed);
  }

  @override
  void dispose() {
    _controller.dispose();
    _life.dispose();
    super.dispose();
  }

  List<_Drip> _generateDrips(int seed) {
    final rand = math.Random(seed);
    final drops = <_Drip>[
      _Drip(
        position: const Offset(0.48, 0.55),
        radiusFrac: 0.42 + rand.nextDouble() * 0.12,
        stretch: 1.0,
        rotation: 0.0,
      ),
    ];
    final trailCount = 3 + rand.nextInt(3);
    for (int i = 0; i < trailCount; i++) {
      drops.add(
        _Drip(
          position: Offset(
              0.2 + rand.nextDouble() * 0.6, 0.15 + rand.nextDouble() * 0.7),
          radiusFrac: 0.08 + rand.nextDouble() * 0.12,
          stretch: 1.0,
          rotation: 0.0,
        ),
      );
    }
    return drops;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _life]),
        builder: (context, _) {
          final double life = _life.value.clamp(0.0, 1.0);
          final scale = 0.92 + (_pulse.value * 0.14);
          final double fade = (1.0 - life).clamp(0.0, 1.0);
          final opacity = (0.65 + (1 - _pulse.value) * 0.25) * fade;
          final smokeOpacity = (1.0 - life * 1.2).clamp(0.0, 1.0);
          return SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _SmokePainter(
                    plumes: _smoke,
                    opacity: smokeOpacity,
                  ),
                ),
                Transform.scale(
                  scale: scale,
                  child: CustomPaint(
                    painter: _BloodSplatterPainter(
                      drips: _drips,
                      fill: _baseColor.withOpacity(opacity),
                      highlight: _highlightColor.withOpacity(opacity * 0.35),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Drip {
  final Offset position;
  final double radiusFrac;
  final double stretch;
  final double rotation;

  const _Drip({
    required this.position,
    required this.radiusFrac,
    required this.stretch,
    required this.rotation,
  });
}

class _BloodSplatterPainter extends CustomPainter {
  final List<_Drip> drips;
  final Color fill;
  final Color highlight;

  _BloodSplatterPainter({
    required this.drips,
    required this.fill,
    required this.highlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shortest = math.min(size.width, size.height);
    final fillPaint = Paint()..color = fill;
    final highlightPaint = Paint()
      ..color = highlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = shortest * 0.012;

    for (final drip in drips) {
      final center = Offset(
        drip.position.dx * size.width,
        drip.position.dy * size.height,
      );
      final radius = drip.radiusFrac * shortest;
      canvas.drawCircle(center, radius, fillPaint);
      canvas.drawCircle(center, radius * 0.92, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BloodSplatterPainter oldDelegate) {
    return oldDelegate.drips != drips ||
        oldDelegate.fill != fill ||
        oldDelegate.highlight != highlight;
  }
}

class _SmokePlume {
  final Offset position;
  final double radiusFrac;
  final double blur;

  const _SmokePlume({
    required this.position,
    required this.radiusFrac,
    required this.blur,
  });
}

List<_SmokePlume> _generateSmoke(int seed) {
  final rand = math.Random(seed * 73 + 11);
  final plumes = <_SmokePlume>[];
  final int count = 4 + rand.nextInt(3);
  for (int i = 0; i < count; i++) {
    plumes.add(
      _SmokePlume(
        position: Offset(
            0.25 + rand.nextDouble() * 0.5, 0.1 + rand.nextDouble() * 0.4),
        radiusFrac: 0.12 + rand.nextDouble() * 0.14,
        blur: 10 + rand.nextDouble() * 10,
      ),
    );
  }
  return plumes;
}

class _SmokePainter extends CustomPainter {
  final List<_SmokePlume> plumes;
  final double opacity;

  _SmokePainter({required this.plumes, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || opacity <= 0) return;
    for (final plume in plumes) {
      final center = Offset(
        plume.position.dx * size.width,
        plume.position.dy * size.height,
      );
      final double r = plume.radiusFrac * math.min(size.width, size.height);
      final double yLift = size.height * 0.08;
      final paint = Paint()
        ..color = _kSmokeColor.withOpacity(opacity * 0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, plume.blur);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy - yLift),
          width: r * 1.3,
          height: r * 1.8,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SmokePainter oldDelegate) {
    return oldDelegate.plumes != plumes || oldDelegate.opacity != opacity;
  }
}
