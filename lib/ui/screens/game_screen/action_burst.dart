import 'dart:math' as math;

import 'package:flutter/material.dart';

const Duration _kBurstDuration = Duration(milliseconds: 1800);
const double _kBurstConfettiAlphaScale = 0.88;
const double _kBurstFireworkAlphaScale = 1.0;

double winnerBurstIntensityForRemainingPlayers(int remainingPlayers) =>
    remainingPlayers > 0 && remainingPlayers <= 3 ? 2.0 : 1.0;

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

  @visibleForTesting
  int get debugParticleCount => _particles.length;

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

  void burstAt(Offset localPosition, {double intensity = 1.0}) {
    burstAtMany(<Offset>[localPosition], intensity: intensity);
  }

  void burstAtMany(
    Iterable<Offset> localPositions, {
    double intensity = 1.0,
  }) {
    final origins = <Offset>[
      for (final o in localPositions)
        if (o.dx.isFinite && o.dy.isFinite) o,
    ];
    if (origins.isEmpty) return;

    final rng = _trySecureRandom();

    final List<_BurstParticle> parts = <_BurstParticle>[];

    final double intensityMultiplier = intensity.clamp(1.0, 2.0).toDouble();
    final int particleMultiplier = intensityMultiplier >= 1.5 ? 2 : 1;
    final double density = 1.0 / math.sqrt(origins.length.toDouble());
    int scaledCount(int base, int min, int max) =>
        (base * density).round().clamp(min, max) * particleMultiplier;

    // Saturated colours stay readable over the black table while the white
    // entries provide hot highlights in additive paint passes.
    final List<Color> confettiPalette = <Color>[
      const Color(0xFFFFD100),
      const Color(0xFF24B6FF),
      const Color(0xFFFF2800),
      const Color(0xFF3BB143),
      const Color(0xFFB000FF),
      const Color(0xFFFF4FD8),
      const Color(0xFF00F5D4),
      const Color(0xFFFF7A00),
      const Color(0xFFFFFFFF),
    ];
    final List<Color> fireworkPalette = <Color>[
      const Color(0xFFFFD100),
      const Color(0xFFFF5A36),
      const Color(0xFFFF2D95),
      const Color(0xFFC13CFF),
      const Color(0xFF7B61FF),
      const Color(0xFF24B6FF),
      const Color(0xFF00E5FF),
      const Color(0xFF00F5A0),
      const Color(0xFF7CFF4F),
      const Color(0xFFFFFFFF),
    ];

    final int smokeCount = scaledCount(6, 3, 6);
    final int confettiCount = scaledCount(32, 16, 32);
    final int cometCount = scaledCount(12, 7, 12);
    final int sparkCount = scaledCount(42, 22, 42);
    final int starCount = scaledCount(8, 5, 8);
    final int burstWaveCount = particleMultiplier;

    for (int originIndex = 0; originIndex < origins.length; originIndex++) {
      final origin = origins[originIndex];
      final double originDelay = originIndex * 0.035;

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
          delay: originDelay,
          life: 0.52 + rng.nextDouble() * 0.16,
          gravity: 0,
        ));
      }

      for (int i = 0; i < confettiCount; i++) {
        final vx = (rng.nextDouble() - 0.5) * 260;
        final vy = -(360 + rng.nextDouble() * 260);
        final size = 3.6 + rng.nextDouble() * 3.2;
        parts.add(_BurstParticle(
          origin: origin + Offset((rng.nextDouble() - 0.5) * 18, 0),
          velocity: Offset(vx, vy),
          color: confettiPalette[rng.nextInt(confettiPalette.length)]
              .withValues(alpha: 0.98 - rng.nextDouble() * 0.16),
          size: size,
          thickness: 1.0,
          spin: (rng.nextDouble() * 2 - 1) * 10.0,
          kind: _ParticleKind.confetti,
          delay: originDelay + rng.nextDouble() * 0.055,
          life: 0.72 + rng.nextDouble() * 0.18,
          gravity: 760,
        ));
      }

      // Bright launch comets connect the action bar to the delayed starbursts.
      for (int i = 0; i < cometCount; i++) {
        final vx = (rng.nextDouble() - 0.5) * 170;
        final vy = -(700 + rng.nextDouble() * 480);
        final len = 26.0 + rng.nextDouble() * 28.0;
        parts.add(_BurstParticle(
          origin: origin + Offset((rng.nextDouble() - 0.5) * 24, 0),
          velocity: Offset(vx, vy),
          color: fireworkPalette[rng.nextInt(fireworkPalette.length)]
              .withValues(alpha: 0.98),
          size: len,
          thickness: 2.0 + rng.nextDouble() * 1.0,
          spin: 0.0,
          kind: _ParticleKind.comet,
          delay: originDelay + (i / cometCount) * 0.075,
          life: 0.42 + rng.nextDouble() * 0.14,
          gravity: 560,
        ));
      }

      final int baseBurstColor = rng.nextInt(fireworkPalette.length);
      for (int wave = 0; wave < burstWaveCount; wave++) {
        final int sparksInWave = sparkCount ~/ burstWaveCount +
            (wave < sparkCount % burstWaveCount ? 1 : 0);
        final int starsInWave = starCount ~/ burstWaveCount +
            (wave < starCount % burstWaveCount ? 1 : 0);
        final Offset burstCenter = origin +
            Offset(
              (rng.nextDouble() - 0.5) * 125,
              -(165 + rng.nextDouble() * 125 + wave * 26),
            );
        final double burstDelay = 0.14 +
            (originIndex * 0.055) +
            (wave * 0.075) +
            rng.nextDouble() * 0.03;
        final Color burstColor = fireworkPalette[
            (baseBurstColor + wave * 3) % fireworkPalette.length];

        // Even angular spacing makes the explosion read as a firework rather
        // than another upward spray; small jitter keeps it organic.
        for (int i = 0; i < sparksInWave; i++) {
          final double angle = (math.pi * 2 * i / sparksInWave) +
              (rng.nextDouble() - 0.5) * 0.16;
          final double speed = 170 + rng.nextDouble() * 280;
          final Color color = rng.nextDouble() < 0.58
              ? burstColor
              : fireworkPalette[rng.nextInt(fireworkPalette.length)];
          parts.add(_BurstParticle(
            origin: burstCenter,
            velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
            color: color.withValues(alpha: 0.98),
            size: 13.0 + rng.nextDouble() * 17.0,
            thickness: 1.35 + rng.nextDouble() * 1.1,
            spin: 0.0,
            kind: _ParticleKind.spark,
            delay: burstDelay + rng.nextDouble() * 0.025,
            life: 0.52 + rng.nextDouble() * 0.18,
            gravity: 190,
          ));
        }

        for (int i = 0; i < starsInWave; i++) {
          final double angle = (math.pi * 2 * i / starsInWave) + 0.22;
          final double speed = 80 + rng.nextDouble() * 150;
          parts.add(_BurstParticle(
            origin: burstCenter,
            velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
            color: fireworkPalette[rng.nextInt(fireworkPalette.length)]
                .withValues(alpha: 1),
            size: 4.6 + rng.nextDouble() * 3.4,
            thickness: 1.4 + rng.nextDouble() * 0.7,
            spin: (rng.nextDouble() * 2 - 1) * 4.5,
            kind: _ParticleKind.star,
            delay: burstDelay + 0.02 + rng.nextDouble() * 0.035,
            life: 0.58 + rng.nextDouble() * 0.16,
            gravity: 125,
          ));
        }
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
        isComplex: true,
        willChange: true,
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

enum _ParticleKind { smoke, confetti, comet, spark, star }

class _BurstParticle {
  final Offset origin;
  final Offset velocity;
  final Color color;
  final double size;
  final double thickness;
  final double spin;
  final _ParticleKind kind;
  final double delay;
  final double life;
  final double gravity;

  const _BurstParticle({
    required this.origin,
    required this.velocity,
    required this.color,
    required this.size,
    required this.thickness,
    required this.spin,
    required this.kind,
    required this.delay,
    required this.life,
    required this.gravity,
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

    final double globalProgress = progress.value.clamp(0.0, 1.0);
    final Paint smokePaint = Paint()..style = PaintingStyle.fill;
    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint glowStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    final Paint colorStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Paint hotStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;

    // Smoke first so sparks/confetti stay crisp on top.
    for (final p in particles) {
      if (p.kind != _ParticleKind.smoke) continue;
      final double? localProgress = _localProgress(p, globalProgress);
      if (localProgress == null) continue;

      final double time = localProgress * lifeSec * p.life;
      final dx = p.velocity.dx * time;
      final dy = p.velocity.dy * time;
      final Offset center = p.origin + Offset(dx, dy);

      final double smokeT = Curves.easeOutCubic.transform(localProgress);
      final double r = p.size + p.thickness * smokeT;
      final double a =
          (p.color.a * _particleFade(localProgress) * (1.0 - smokeT * 0.35))
              .clamp(0.0, 0.35);
      if (a <= 0.001) continue;

      final Color c = p.color.withValues(alpha: a);
      canvas.drawCircle(
        center,
        r * 1.05,
        smokePaint..color = c.withValues(alpha: a * 0.50),
      );
      canvas.drawCircle(
        center,
        r * 0.72,
        smokePaint..color = c.withValues(alpha: a * 0.78),
      );
    }

    for (final p in particles) {
      if (p.kind == _ParticleKind.smoke) continue;
      final double? localProgress = _localProgress(p, globalProgress);
      if (localProgress == null) continue;

      final double time = localProgress * lifeSec * p.life;
      final dx = p.velocity.dx * time;
      final dy = p.velocity.dy * time + 0.5 * p.gravity * time * time;
      final Offset pos = p.origin + Offset(dx, dy);

      final double kindAlphaScale = switch (p.kind) {
        _ParticleKind.confetti => _kBurstConfettiAlphaScale,
        _ParticleKind.comet ||
        _ParticleKind.spark ||
        _ParticleKind.star =>
          _kBurstFireworkAlphaScale,
        _ParticleKind.smoke => 1.0,
      };
      final double fade = _particleFade(localProgress);
      final Color color = p.color.withValues(
        alpha: (p.color.a * fade * kindAlphaScale).clamp(0.0, 1.0),
      );

      switch (p.kind) {
        case _ParticleKind.smoke:
          // Handled in the smoke pass above.
          break;
        case _ParticleKind.confetti:
          canvas.save();
          final double ang = p.spin * time;
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(ang);
          final double flutter =
              0.60 + 0.40 * math.sin((localProgress * math.pi * 7) + p.spin);
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: p.size * 1.45 * flutter.abs().clamp(0.35, 1.0),
            height: p.size * 0.85,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(p.size * 0.18)),
            fillPaint
              ..color = color
              ..style = PaintingStyle.fill
              ..blendMode = BlendMode.srcOver,
          );
          canvas.drawLine(
            Offset(-rect.width * 0.28, 0),
            Offset(rect.width * 0.28, 0),
            hotStroke
              ..color = Colors.white.withValues(alpha: fade * 0.55)
              ..strokeWidth = 0.55,
          );
          canvas.restore();
          break;
        case _ParticleKind.comet:
          final Offset direction = Offset(
            p.velocity.dx,
            p.velocity.dy + p.gravity * time,
          );
          _drawTrail(
            canvas,
            head: pos,
            direction: direction,
            length: p.size * (1.0 - localProgress * 0.22),
            thickness: p.thickness,
            color: color,
            fade: fade,
            glowStroke: glowStroke,
            colorStroke: colorStroke,
            hotStroke: hotStroke,
            glowScale: 4.2,
          );
          break;
        case _ParticleKind.spark:
          final Offset direction = Offset(
            p.velocity.dx,
            p.velocity.dy + p.gravity * time,
          );
          _drawTrail(
            canvas,
            head: pos,
            direction: direction,
            length: p.size * (1.0 - localProgress * 0.36),
            thickness: p.thickness,
            color: color,
            fade: fade,
            glowStroke: glowStroke,
            colorStroke: colorStroke,
            hotStroke: hotStroke,
            glowScale: 3.2,
          );
          break;
        case _ParticleKind.star:
          _drawStar(
            canvas,
            center: pos,
            radius: p.size * (0.86 + fade * 0.22),
            rotation: p.spin * time,
            color: color,
            thickness: p.thickness,
            fade: fade,
            glowStroke: glowStroke,
            fillPaint: fillPaint,
          );
          break;
      }
    }
  }

  double? _localProgress(_BurstParticle particle, double globalProgress) {
    if (globalProgress < particle.delay) return null;
    final double value = (globalProgress - particle.delay) / particle.life;
    if (value < 0 || value > 1) return null;
    return value.clamp(0.0, 1.0);
  }

  double _particleFade(double progress) {
    final double fadeIn = (progress / 0.055).clamp(0.0, 1.0);
    final double fadeOut =
        1.0 - Curves.easeInCubic.transform(progress.clamp(0.0, 1.0));
    return (fadeIn * fadeOut).clamp(0.0, 1.0);
  }

  void _drawTrail(
    Canvas canvas, {
    required Offset head,
    required Offset direction,
    required double length,
    required double thickness,
    required Color color,
    required double fade,
    required Paint glowStroke,
    required Paint colorStroke,
    required Paint hotStroke,
    required double glowScale,
  }) {
    final Offset unit = direction.distance <= 0.001
        ? const Offset(0, -1)
        : direction / direction.distance;
    final Offset tail = head - unit * length.clamp(2.0, 60.0);

    // Layered additive strokes are significantly cheaper than applying a blur
    // mask to every particle on every frame, while retaining a bright halo.
    canvas.drawLine(
      tail,
      head,
      glowStroke
        ..color = color.withValues(alpha: color.a * 0.24)
        ..strokeWidth = thickness * glowScale,
    );
    canvas.drawLine(
      tail,
      head,
      colorStroke
        ..color = color
        ..strokeWidth = thickness * 1.45,
    );
    canvas.drawLine(
      tail + unit * (length * 0.18),
      head,
      hotStroke
        ..color = const Color(0xFFFFFFFF)
            .withValues(alpha: (fade * 0.92).clamp(0.0, 0.92))
        ..strokeWidth = thickness * 0.62,
    );
    canvas.drawCircle(
      head,
      thickness * 2.4,
      glowStroke
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: color.a * 0.22),
    );
    glowStroke.style = PaintingStyle.stroke;
    canvas.drawCircle(
      head,
      thickness * 0.95,
      hotStroke
        ..color = const Color(0xFFFFFFFF)
            .withValues(alpha: (fade * 0.96).clamp(0.0, 0.96))
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.plus,
    );
    hotStroke.style = PaintingStyle.stroke;
  }

  void _drawStar(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double rotation,
    required Color color,
    required double thickness,
    required double fade,
    required Paint glowStroke,
    required Paint fillPaint,
  }) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final double angle = rotation - math.pi / 2 + i * math.pi / 4;
      final double r = i.isEven ? radius : radius * 0.34;
      final Offset point =
          center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawCircle(
      center,
      radius * 1.35,
      fillPaint
        ..color = color.withValues(alpha: color.a * 0.14)
        ..blendMode = BlendMode.plus,
    );
    canvas.drawPath(
      path,
      glowStroke
        ..color = color.withValues(alpha: color.a * 0.55)
        ..strokeWidth = thickness * 3.2,
    );
    canvas.drawPath(
      path,
      fillPaint
        ..color = color
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.plus,
    );
    canvas.drawCircle(
      center,
      thickness * 0.9,
      fillPaint
        ..color = Colors.white.withValues(alpha: fade * 0.95)
        ..blendMode = BlendMode.plus,
    );
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
