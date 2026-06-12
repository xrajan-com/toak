import 'dart:math' as math;

import 'package:flutter/material.dart';

const Duration _kBurstDuration = Duration(milliseconds: 1160);
const double _kBurstConfettiAlphaScale = 0.68;
const double _kBurstFireworkAlphaScale = 1.0;

class ActionBurstOverlay extends StatefulWidget {
  const ActionBurstOverlay({super.key});

  @override
  State<ActionBurstOverlay> createState() => ActionBurstOverlayState();
}

class ActionBurstOverlayState extends State<ActionBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _active = false;
  List<_BurstParticle> _particles = const <_BurstParticle>[];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _kBurstDuration,
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() {
            _active = false;
            _particles = const <_BurstParticle>[];
          });
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void burstAt(Offset localPosition) {
    burstAtMany(<Offset>[localPosition]);
  }

  void burstAtMany(Iterable<Offset> localPositions) {
    final origins = <Offset>[
      for (final o in localPositions)
        if (o.dx.isFinite && o.dy.isFinite) o,
    ];
    if (origins.isEmpty) return;

    final rng = _trySecureRandom();

    final List<_BurstParticle> parts = <_BurstParticle>[];

    final double density = 1.0 / math.sqrt(origins.length.toDouble());
    int scaledCount(int base, int min, int max) =>
        (base * density).round().clamp(min, max);

    // Keep the confetti light, but let the pyro read clearly above the bar.
    final List<Color> confettiPalette = <Color>[
      const Color(0xFFFFD100),
      const Color(0xFF24B6FF),
      const Color(0xFFFF2800),
      const Color(0xFF3BB143),
      const Color(0xFFB000FF),
      const Color(0xFFFF4FD8),
      const Color(0xFFFFFFFF),
    ];
    final List<Color> fireworkPalette = <Color>[
      const Color(0xFFFFF7C2),
      const Color(0xFFFFD100),
      const Color(0xFFFFB300),
      const Color(0xFFFF8A00),
      const Color(0xFFFF5A1F),
    ];

    final int smokeCount = scaledCount(10, 4, 10);
    final int confettiCount = scaledCount(30, 12, 30);
    final int fireworkCount = scaledCount(30, 14, 30);

    for (final origin in origins) {
      for (int i = 0; i < smokeCount; i++) {
        final vx = (rng.nextDouble() - 0.5) * 90;
        final vy = -(90 + rng.nextDouble() * 90);
        final baseR = 10.0 + rng.nextDouble() * 8.0;
        final grow = 18.0 + rng.nextDouble() * 26.0;
        parts.add(_BurstParticle(
          origin: origin +
              Offset(
                (rng.nextDouble() - 0.5) * 10,
                (rng.nextDouble() - 0.5) * 8,
              ),
          velocity: Offset(vx, vy),
          color: const Color(0xFFECECEC).withValues(
            alpha: 0.18 - rng.nextDouble() * 0.06,
          ),
          size: baseR,
          thickness: grow,
          spin: 0.0,
          kind: _ParticleKind.smoke,
        ));
      }

      for (int i = 0; i < confettiCount; i++) {
        final vx = (rng.nextDouble() - 0.5) * 260;
        final vy = -(360 + rng.nextDouble() * 260);
        final size = 3.0 + rng.nextDouble() * 2.8;
        parts.add(_BurstParticle(
          origin: origin,
          velocity: Offset(vx, vy),
          color: confettiPalette[rng.nextInt(confettiPalette.length)]
              .withValues(alpha: 0.92 - rng.nextDouble() * 0.25),
          size: size,
          thickness: 1.0,
          spin: (rng.nextDouble() * 2 - 1) * 10.0,
          kind: _ParticleKind.confetti,
        ));
      }

      for (int i = 0; i < fireworkCount; i++) {
        // Mostly vertical launch with a small sideways variance.
        final vx = (rng.nextDouble() - 0.5) * 140;
        final vy = -(640 + rng.nextDouble() * 520);
        final len = 24.0 + rng.nextDouble() * 28.0;
        parts.add(_BurstParticle(
          origin: origin,
          velocity: Offset(vx, vy),
          color: fireworkPalette[rng.nextInt(fireworkPalette.length)]
              .withValues(alpha: 0.96 - rng.nextDouble() * 0.10),
          size: len,
          thickness: 2.4 + rng.nextDouble() * 0.9,
          spin: 0.0,
          kind: _ParticleKind.firework,
        ));
      }
    }

    setState(() {
      _active = true;
      _particles = parts;
    });
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ActionBurstPainter(
          progress: _ctrl,
          particles: _particles,
          lifeSec: _kBurstDuration.inMilliseconds / 1000.0,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

enum _ParticleKind { smoke, confetti, firework }

class _BurstParticle {
  final Offset origin;
  final Offset velocity;
  final Color color;
  final double size;
  final double thickness;
  final double spin;
  final _ParticleKind kind;

  const _BurstParticle({
    required this.origin,
    required this.velocity,
    required this.color,
    required this.size,
    required this.thickness,
    required this.spin,
    required this.kind,
  });
}

class _ActionBurstPainter extends CustomPainter {
  final Animation<double> progress;
  final List<_BurstParticle> particles;
  final double lifeSec;

  _ActionBurstPainter({
    required this.progress,
    required this.particles,
    required this.lifeSec,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;

    final double t = progress.value.clamp(0.0, 1.0);
    final double tt = Curves.easeOutCubic.transform(t);
    final double time = tt * lifeSec;
    final double gravity = 820.0;
    final double fade = (1.0 - Curves.easeInQuad.transform(t)).clamp(0.0, 1.0);

    // Smoke first so sparks/confetti stay crisp on top.
    for (final p in particles) {
      if (p.kind != _ParticleKind.smoke) continue;

      final dx = p.velocity.dx * time;
      final dy = p.velocity.dy * time;
      final Offset center = p.origin + Offset(dx, dy);

      final double smokeT = Curves.easeOutCubic.transform(t);
      final double r = p.size + p.thickness * smokeT;
      final double a =
          (p.color.a * fade * (1.0 - smokeT * 0.35)).clamp(0.0, 0.35);
      if (a <= 0.001) continue;

      final Color c = p.color.withValues(alpha: a);
      final paint = Paint()..color = c;
      canvas.drawCircle(
        center,
        r * 1.05,
        paint..color = c.withValues(alpha: a * 0.55),
      );
      canvas.drawCircle(
        center,
        r * 0.72,
        paint..color = c.withValues(alpha: a * 0.80),
      );
    }

    for (final p in particles) {
      if (p.kind == _ParticleKind.smoke) continue;
      final dx = p.velocity.dx * time;
      final dy = p.velocity.dy * time + 0.5 * gravity * time * time;
      final Offset pos = p.origin + Offset(dx, dy);

      final double kindAlphaScale = switch (p.kind) {
        _ParticleKind.confetti => _kBurstConfettiAlphaScale,
        _ParticleKind.firework => _kBurstFireworkAlphaScale,
        _ParticleKind.smoke => 1.0,
      };
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.color.a * fade * kindAlphaScale)
        ..style = PaintingStyle.fill;

      switch (p.kind) {
        case _ParticleKind.smoke:
          // Handled in the smoke pass above.
          break;
        case _ParticleKind.confetti:
          canvas.save();
          final double ang = p.spin * time;
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(ang);
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: p.size * 1.35,
            height: p.size * 0.85,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(p.size * 0.18)),
            paint,
          );
          canvas.restore();
          break;
        case _ParticleKind.firework:
          final Offset dir =
              (p.velocity.distance <= 0.001) ? const Offset(0, -1) : p.velocity;
          final Offset unit = dir / dir.distance;
          final Offset tail = pos - unit * p.size;
          final Color c = paint.color;
          // Stronger fire glow so the pyro reads above the winner bar.
          final glowPaint = Paint()
            ..color = c.withValues(alpha: c.a * 0.82)
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.thickness * 4.8
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
          canvas.drawLine(tail, pos, glowPaint);
          canvas.drawCircle(
            pos,
            p.thickness * 3.0,
            Paint()
              ..color = c.withValues(alpha: c.a * 0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );

          final hotCorePaint = Paint()
            ..color = const Color(0xFFFFFBE6)
                .withValues(alpha: (0.9 * fade).clamp(0.0, 0.9))
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.thickness * 1.3
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(tail, pos, hotCorePaint);

          final sparkPaint = Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.thickness * 1.15
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(tail, pos, sparkPaint);
          canvas.drawCircle(
            pos,
            p.thickness * 1.45,
            Paint()..color = const Color(0xFFFFF7C2).withValues(alpha: c.a),
          );
          canvas.drawCircle(pos, p.thickness * 0.9, Paint()..color = c);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ActionBurstPainter oldDelegate) {
    return oldDelegate.particles != particles;
  }
}

math.Random _trySecureRandom() {
  try {
    return math.Random.secure();
  } catch (_) {
    return math.Random();
  }
}
