import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart' show FireworkSound;

/// How long the classic show runs. Every other show takes as long as its
/// last spark needs.
const Duration _kBurstDuration = Duration(milliseconds: 1800);
const double _kClassicSec = 1.8;
const double _kBurstConfettiAlphaScale = 0.88;
const double _kBurstFireworkAlphaScale = 1.0;

/// Air-resistance coefficient for the explosion particles, in 1/s.
///
/// Real shell sparks shed most of their speed almost at once, which is what
/// makes a firework bloom outward and settle. Integrating v0*e^(-k*t) gives
/// that curve in closed form, so position stays a pure function of time and
/// the painter still keeps no per-frame state. Total reach is v0/k.
const double _kSparkDrag = 2.2;

/// The most sounds one show plays: a launch and up to three bursts, or two
/// bursts and a crackle. Seven rockets do not need seven booms.
const int kFireworkMaxSoundsPerShow = 4;

/// Two bursts closer than this are heard as one.
const double _kMinBurstSoundGapSec = 0.16;

/// Shows in the game-win finale, and the gap between their starts.
const int kFireworkFinaleShowCount = 3;
const double _kFinaleGapSec = 0.95;

double winnerBurstIntensityForRemainingPlayers(int remainingPlayers) =>
    remainingPlayers > 0 && remainingPlayers <= 3 ? 2.0 : 1.0;

/// The fireworks a win can get. A hand win plays one, picked at random; a
/// game win plays [kFireworkFinaleShowCount] of them back to back.
///
/// Every show keeps two promises the tests hold it to: doubling the
/// intensity (the final three players) exactly doubles its particles, and a
/// show is over in under three seconds, so it never outlasts the winners
/// overlay it decorates.
enum FireworkShow {
  /// Three launch sprays and starbursts from the action bar, with confetti.
  classic,

  /// A Ferrari red shell on the left and a Miami Blue one on the right.
  redAndBlue,

  /// Gold willows whose long trails droop over the table.
  goldenWillow,

  /// A few thick fronds that arc over and fall, on heavy rising trails.
  palmGrove,

  /// One big round shell with a gold heart.
  chrysanthemum,

  /// Crisp rings in red, orange and gold.
  ringOfFire,

  /// A silver sphere inside a tilted blue ring.
  saturn,

  /// Stars that split into four mid-flight.
  crossette,

  /// Airbursts of twinkling silver glitter, no rockets.
  glitterStrobe,

  /// Seven rockets up from the bottom edge, left to right.
  rocketSalvo,

  /// Gold and silver fountains spraying up from behind the action bar.
  fountains,

  /// Confetti blasted up and inward from both bottom corners.
  confettiCannons,

  /// One big crown of dense, twinkling gold glitter.
  kamuro,

  /// Fewer, bolder petals in sunset colours.
  dahlias,

  /// A line of high bursts whose silver falls like a curtain.
  waterfall,

  /// Gold shells that crackle with white pops after they open.
  crackle,

  /// Spiral pinwheels in neon, turning opposite ways.
  pinwheels,

  /// Red rockets from the left corner, blue from the right; the trails cross.
  crossfire,
}

/// Picks the next show: every show plays once before any repeats, and the
/// same show never plays twice in a row, even across a reshuffle.
class FireworkShowPicker {
  FireworkShowPicker([math.Random? random])
      : _random = random ?? _trySecureRandom();

  final math.Random _random;
  final List<FireworkShow> _bag = <FireworkShow>[];
  FireworkShow? _last;

  FireworkShow? get last => _last;

  FireworkShow next() {
    if (_bag.isEmpty) {
      _bag
        ..addAll(FireworkShow.values)
        ..shuffle(_random);
      // The bag is drawn from the end.
      final int top = _bag.length - 1;
      if (top > 0 && _bag[top] == _last) {
        final FireworkShow swap = _bag[0];
        _bag[0] = _bag[top];
        _bag[top] = swap;
      }
    }
    final FireworkShow show = _bag.removeLast();
    _last = show;
    return show;
  }

  /// [count] different shows, none of them the one that played last.
  List<FireworkShow> nextDistinct(int count) {
    final FireworkShow? before = _last;
    final int wanted = count.clamp(
        0, FireworkShow.values.length - (before == null ? 0 : 1));
    final List<FireworkShow> out = <FireworkShow>[];
    while (out.length < wanted) {
      final FireworkShow show = next();
      if (show != before && !out.contains(show)) out.add(show);
    }
    return out;
  }
}

/// App-wide, so a new game doesn't start the rotation over.
final FireworkShowPicker fireworkShowPicker = FireworkShowPicker();

class ActionBurstOverlay extends StatefulWidget {
  const ActionBurstOverlay({super.key, this.onFinished, this.onSound});

  /// Called each time a show has fully played out.
  final VoidCallback? onFinished;

  /// Plays a firework sound as the show reaches a launch or a burst; only
  /// for shows started with `sound: true`.
  final void Function(FireworkSound sound)? onSound;

  @override
  State<ActionBurstOverlay> createState() => ActionBurstOverlayState();
}

class ActionBurstOverlayState extends State<ActionBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _active = false;
  List<_BurstParticle> _particles = const <_BurstParticle>[];
  double _lengthSec = _kClassicSec;
  List<_SoundCue> _cues = const <_SoundCue>[];
  int _nextCue = 0;

  @visibleForTesting
  int get debugParticleCount => _particles.length;

  /// The sounds the current show will play, in order, with their times.
  @visibleForTesting
  List<(double, FireworkSound)> get debugSoundCues => <(double, FireworkSound)>[
        for (final _SoundCue c in _cues) (c.at, c.sound),
      ];

  @visibleForTesting
  Duration get debugDuration => _ctrl.duration ?? _kBurstDuration;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _kBurstDuration,
    )
      ..addListener(_playDueSounds)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() {
            _active = false;
            _particles = const <_BurstParticle>[];
          });
          _cues = const <_SoundCue>[];
          widget.onFinished?.call();
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// The area the fireworks can use, in this widget's coordinates.
  Size get stageSize {
    final RenderObject? ro = context.findRenderObject();
    if (ro is RenderBox && ro.hasSize && !ro.size.isEmpty) return ro.size;
    return MediaQuery.maybeSizeOf(context) ?? const Size(800, 400);
  }

  void burstAt(
    Offset localPosition, {
    double intensity = 1.0,
    FireworkShow show = FireworkShow.classic,
    bool sound = false,
  }) {
    burstAtMany(<Offset>[localPosition],
        intensity: intensity, show: show, sound: sound);
  }

  /// Plays [show]. [localPositions] are the launch points (normally three,
  /// inside the action bar); shows that burst high or fire from the edges
  /// place themselves on the stage instead. With [sound], the show's
  /// launches and bursts are heard through [ActionBurstOverlay.onSound].
  void burstAtMany(
    Iterable<Offset> localPositions, {
    double intensity = 1.0,
    FireworkShow show = FireworkShow.classic,
    bool sound = false,
  }) {
    final List<Offset> origins = _finite(localPositions);
    if (origins.isEmpty) return;
    final _ShowBuilder builder = _ShowBuilder(
      rng: _trySecureRandom(),
      stage: stageSize,
      launch: origins,
      multiplier: _multiplierFor(intensity),
    )..build(show);
    _start(builder.particles, builder.lengthSec,
        sound ? builder.soundCues : const <_SoundCue>[]);
  }

  /// The game-win finale: [shows] one after another, each starting
  /// [_kFinaleGapSec] after the one before, so they overlap.
  void playFinale(
    List<FireworkShow> shows,
    Iterable<Offset> launchPoints, {
    double intensity = 1.0,
    bool sound = false,
  }) {
    final List<Offset> origins = _finite(launchPoints);
    if (origins.isEmpty || shows.isEmpty) return;
    final _ShowBuilder builder = _ShowBuilder(
      rng: _trySecureRandom(),
      stage: stageSize,
      launch: origins,
      multiplier: _multiplierFor(intensity),
    );
    for (int i = 0; i < shows.length; i++) {
      builder
        ..at = i * _kFinaleGapSec
        ..build(shows[i]);
    }
    _start(builder.particles, builder.lengthSec,
        sound ? builder.soundCues : const <_SoundCue>[]);
  }

  List<Offset> _finite(Iterable<Offset> points) => <Offset>[
        for (final o in points)
          if (o.dx.isFinite && o.dy.isFinite) o,
      ];

  int _multiplierFor(double intensity) =>
      intensity.clamp(1.0, 2.0).toDouble() >= 1.5 ? 2 : 1;

  void _start(
      List<_BurstParticle> parts, double lengthSec, List<_SoundCue> cues) {
    if (parts.isEmpty || lengthSec <= 0) return;
    _ctrl.duration = Duration(milliseconds: (lengthSec * 1000).round());
    setState(() {
      _active = true;
      _particles = parts;
      _lengthSec = lengthSec;
    });
    _cues = widget.onSound == null ? const <_SoundCue>[] : cues;
    _nextCue = 0;
    _ctrl.forward(from: 0);
  }

  /// Plays every sound whose moment the animation has reached. Driven by the
  /// animation itself, so the sounds stay on the sparks and stop with them.
  void _playDueSounds() {
    final void Function(FireworkSound sound)? play = widget.onSound;
    if (play == null || _nextCue >= _cues.length) return;
    final double elapsed = _ctrl.value * _lengthSec;
    while (_nextCue < _cues.length && _cues[_nextCue].at <= elapsed) {
      play(_cues[_nextCue].sound);
      _nextCue++;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Full size even when idle, so [stageSize] is known before the first show.
    if (!_active) return const SizedBox.expand();
    return RepaintBoundary(
      child: CustomPaint(
        isComplex: true,
        willChange: true,
        painter: _ActionBurstPainter(
          progress: _ctrl,
          particles: _particles,
          lengthSec: _lengthSec,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Full-screen fireworks for a game win: [kFireworkFinaleShowCount]
/// different shows back to back, launched from just below the bottom edge.
/// Meant for an [OverlayEntry]; it ignores touches and calls [onDone] when
/// the last spark is out.
class FireworkFinale extends StatefulWidget {
  const FireworkFinale({super.key, this.shows, this.onDone, this.onSound});

  /// Which shows to play; picked at random when null.
  final List<FireworkShow>? shows;
  final VoidCallback? onDone;

  /// Plays the finale's launches and bursts.
  final void Function(FireworkSound sound)? onSound;

  @override
  State<FireworkFinale> createState() => _FireworkFinaleState();
}

class _FireworkFinaleState extends State<FireworkFinale> {
  final GlobalKey<ActionBurstOverlayState> _burstKey =
      GlobalKey<ActionBurstOverlayState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ActionBurstOverlayState? burst = _burstKey.currentState;
      if (burst == null) {
        widget.onDone?.call();
        return;
      }
      final Size size = burst.stageSize;
      final double y = size.height + 12;
      burst.playFinale(
        widget.shows ??
            fireworkShowPicker.nextDistinct(kFireworkFinaleShowCount),
        <Offset>[
          Offset(size.width * 0.22, y),
          Offset(size.width * 0.50, y),
          Offset(size.width * 0.78, y),
        ],
        sound: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ActionBurstOverlay(
        key: _burstKey,
        onFinished: widget.onDone,
        onSound: widget.onSound,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Colours. Reds are the two brand reds only (tools/verify_palette.sh).

const Color _kFerrari = Color(0xFFFF2800);
const Color _kMiami = Color(0xFF00B5C8);
const Color _kGold = Color(0xFFFFD100);
const Color _kWhite = Color(0xFFFFFFFF);
const Color _kOrange = Color(0xFFFF7A00);
const Color _kPink = Color(0xFFFF2D95);
const Color _kCyan = Color(0xFF00E5FF);

// Saturated colours stay readable over the black table while the white
// entries provide hot highlights in additive paint passes.
const List<Color> _kConfetti = <Color>[
  Color(0xFFFFD100),
  Color(0xFF00B5C8),
  Color(0xFFFF2800),
  Color(0xFF3BB143),
  Color(0xFFB000FF),
  Color(0xFFFF4FD8),
  Color(0xFF00F5D4),
  Color(0xFFFF7A00),
  Color(0xFFFFFFFF),
];
const List<Color> _kRainbow = <Color>[
  Color(0xFFFFD100),
  Color(0xFFFF2800),
  Color(0xFFFF2D95),
  Color(0xFFC13CFF),
  Color(0xFF7B61FF),
  Color(0xFF00B5C8),
  Color(0xFF00E5FF),
  Color(0xFF00F5A0),
  Color(0xFF7CFF4F),
  Color(0xFFFFFFFF),
];
const List<Color> _kGolds = <Color>[
  _kGold,
  Color(0xFFFFB300),
  Color(0xFFFFE7A3),
  _kWhite,
];
const List<Color> _kSilver = <Color>[
  _kWhite,
  Color(0xFFE9E9F0),
  Color(0xFFCFEAFF),
];
const List<Color> _kWarm = <Color>[_kFerrari, _kOrange, _kGold];
const List<Color> _kCool = <Color>[_kMiami, _kCyan, Color(0xFF9CF4FF)];
const List<Color> _kNeon = <Color>[
  _kPink,
  Color(0xFFC13CFF),
  _kCyan,
  Color(0xFF7CFF4F),
  Color(0xFF00F5A0),
];
const List<Color> _kSunset = <Color>[_kFerrari, _kOrange, _kGold, _kPink];
const List<Color> _kGoldWhite = <Color>[_kGold, _kWhite];
const List<Color> _kPopColours = <Color>[
  _kWhite,
  _kGold,
  Color(0xFFFFE7A3),
];
const List<Color> _kPaper = <Color>[
  _kFerrari,
  _kMiami,
  _kGold,
  _kWhite,
  _kOrange,
  _kCyan,
];

// ---------------------------------------------------------------------------
// Building the shows.

/// Turns a [FireworkShow] into particles.
///
/// Times are seconds from the start of the show ([at] shifts a whole show,
/// for the finale). Particle counts never depend on the random generator,
/// only on the show and the multiplier, so doubling the intensity always
/// exactly doubles the particles. Positions, colours and timing jitter are
/// random, so no two plays of a show look the same.
class _ShowBuilder {
  _ShowBuilder({
    required this.rng,
    required this.stage,
    required this.launch,
    required this.multiplier,
  }) : scale = (stage.shortestSide / 400.0).clamp(0.85, 1.5).toDouble();

  final math.Random rng;
  final Size stage;

  /// Launch points, left to right; at least one.
  final List<Offset> launch;

  /// 1, or 2 when the table is down to its final three.
  final int multiplier;

  /// Bigger screens get bigger shells.
  final double scale;

  final List<_BurstParticle> particles = <_BurstParticle>[];

  /// The sounds of everything built so far, in time order, at most
  /// [kFireworkMaxSoundsPerShow] per show.
  final List<_SoundCue> soundCues = <_SoundCue>[];

  /// Every moment the show being built could make a sound; [_settleSounds]
  /// keeps a few of them.
  final List<_SoundCue> _candidates = <_SoundCue>[];

  /// When the show being built starts, in seconds.
  double at = 0;

  /// When the last particle of everything built so far is out.
  double lengthSec = 0;

  double _end = 0;

  Offset get _left => launch.first;
  Offset get _middle => launch[launch.length ~/ 2];
  Offset get _right => launch.last;
  List<Offset> get _three => <Offset>[_left, _middle, _right];

  Offset sky(double fx, double fy) =>
      Offset(stage.width * fx, stage.height * fy);
  double between(double a, double b) => a + rng.nextDouble() * (b - a);
  Color pick(List<Color> palette) => palette[rng.nextInt(palette.length)];

  void build(FireworkShow show) {
    _end = at;
    _candidates.clear();
    switch (show) {
      case FireworkShow.classic:
        _classic();
        _settleSounds();
        // The classic show has always ended at 1.8 s, cutting its last
        // sparks; keep that unless a later show in a finale runs past it.
        lengthSec = math.max(lengthSec, at + _kClassicSec);
        return;
      case FireworkShow.redAndBlue:
        _redAndBlue();
      case FireworkShow.goldenWillow:
        _goldenWillow();
      case FireworkShow.palmGrove:
        _palmGrove();
      case FireworkShow.chrysanthemum:
        _chrysanthemum();
      case FireworkShow.ringOfFire:
        _ringOfFire();
      case FireworkShow.saturn:
        _saturn();
      case FireworkShow.crossette:
        _crossette();
      case FireworkShow.glitterStrobe:
        _glitterStrobe();
      case FireworkShow.rocketSalvo:
        _rocketSalvo();
      case FireworkShow.fountains:
        _fountains();
      case FireworkShow.confettiCannons:
        _confettiCannons();
      case FireworkShow.kamuro:
        _kamuro();
      case FireworkShow.dahlias:
        _dahlias();
      case FireworkShow.waterfall:
        _waterfall();
      case FireworkShow.crackle:
        _crackle();
      case FireworkShow.pinwheels:
        _pinwheels();
      case FireworkShow.crossfire:
        _crossfire();
    }
    _settleSounds();
    lengthSec = math.max(lengthSec, _end + 0.05);
  }

  /// A moment the show could be heard, [t] seconds into it. A bigger
  /// [weight] wins when two bursts are too close to both play.
  void _cue(double t, FireworkSound sound, {double weight = 0}) {
    _candidates.add(_SoundCue(at + t, sound, weight));
  }

  /// Keeps the show's first launch, its bursts spaced far enough apart to be
  /// heard separately (louder shells first), and one crackle, up to
  /// [kFireworkMaxSoundsPerShow] in all.
  void _settleSounds() {
    int byTime(_SoundCue a, _SoundCue b) => a.at.compareTo(b.at);
    final List<_SoundCue> launches = _candidates
        .where((c) => c.sound == FireworkSound.launch)
        .toList()
      ..sort(byTime);
    final List<_SoundCue> crackles = _candidates
        .where((c) => c.sound == FireworkSound.crackle)
        .toList()
      ..sort(byTime);
    final List<_SoundCue> bursts = _candidates
        .where((c) =>
            c.sound == FireworkSound.boom || c.sound == FireworkSound.far)
        .toList()
      ..sort((a, b) {
        final int w = b.weight.compareTo(a.weight);
        return w != 0 ? w : a.at.compareTo(b.at);
      });

    final List<_SoundCue> kept = <_SoundCue>[
      if (launches.isNotEmpty) launches.first,
    ];
    final int burstRoom = kFireworkMaxSoundsPerShow -
        kept.length -
        (crackles.isEmpty ? 0 : 1);
    final List<_SoundCue> keptBursts = <_SoundCue>[];
    for (final _SoundCue c in bursts) {
      if (keptBursts.length >= burstRoom) break;
      final bool clear = keptBursts.every(
          (k) => (k.at - c.at).abs() >= _kMinBurstSoundGapSec);
      if (clear) keptBursts.add(c);
    }
    kept.addAll(keptBursts);
    if (crackles.isNotEmpty && kept.length < kFireworkMaxSoundsPerShow) {
      kept.add(crackles.first);
    }
    kept.sort(byTime);
    soundCues
      ..addAll(kept)
      ..sort(byTime);
  }

  void _add({
    required _ParticleKind kind,
    required Offset origin,
    required Offset velocity,
    required Color color,
    required double size,
    required double thickness,
    required double delay,
    required double life,
    double gravity = 0,
    double spin = 0,
    double drag = 0,
    double twinkle = 0,
    double phase = 0,
    bool followPath = false,
  }) {
    final _BurstParticle p = _BurstParticle(
      origin: origin,
      velocity: velocity,
      color: color,
      size: size,
      thickness: thickness,
      spin: spin,
      kind: kind,
      delay: at + delay,
      life: life,
      gravity: gravity,
      drag: drag,
      twinkle: twinkle,
      phase: phase,
      followPath: followPath,
    );
    particles.add(p);
    _end = math.max(_end, p.delay + p.life);
  }

  // ----- Pieces every show is made of -----

  /// A rising shell from [from] that reaches [to] after [flight] seconds,
  /// slowing as it climbs. Returns the time it gets there.
  double rocket(
    Offset from,
    Offset to, {
    required double t,
    double flight = 0.55,
    Color color = _kGold,
    double thickness = 2.2,
    double length = 34,
    double gravity = 420,
  }) {
    final Offset v = Offset(
      (to.dx - from.dx) / flight,
      (to.dy - from.dy - 0.5 * gravity * flight * flight) / flight,
    );
    _add(
      kind: _ParticleKind.comet,
      origin: from,
      velocity: v,
      color: color.withValues(alpha: 0.98),
      size: length,
      thickness: thickness,
      delay: t,
      life: flight,
      gravity: gravity,
    );
    _cue(t, FireworkSound.launch);
    return t + flight;
  }

  /// A shell opening: [count] trailing sparks spaced evenly round a circle.
  /// [squashY] and [tilt] flatten and turn it into a ring seen at an angle.
  void sparks(
    Offset c, {
    required double t,
    required int count,
    required double speedMin,
    required double speedMax,
    List<Color> colors = _kRainbow,
    Color Function(int i)? colorOf,
    double length = 20,
    double thickness = 1.4,
    double lifeMin = 0.9,
    double lifeMax = 1.15,
    double gravity = 190,
    double drag = _kSparkDrag,
    double angleJitter = 0.16,
    double startAngle = 0,
    double squashY = 1,
    double tilt = 0,
    bool followPath = false,
    double delayJitter = 0.025,
  }) {
    final double ct = math.cos(tilt), st = math.sin(tilt);
    for (int i = 0; i < count; i++) {
      final double a = startAngle +
          math.pi * 2 * i / count +
          (rng.nextDouble() - 0.5) * angleJitter;
      final double speed = between(speedMin, speedMax) * scale;
      final double vx = math.cos(a) * speed;
      final double vy = math.sin(a) * speed * squashY;
      _add(
        kind: _ParticleKind.spark,
        origin: c,
        velocity: Offset(vx * ct - vy * st, vx * st + vy * ct),
        color: (colorOf?.call(i) ?? pick(colors)).withValues(alpha: 0.98),
        size: length * between(0.8, 1.25),
        thickness: thickness * between(0.8, 1.25),
        delay: t + rng.nextDouble() * delayJitter,
        life: between(lifeMin, lifeMax),
        gravity: gravity,
        drag: drag,
        followPath: followPath,
      );
    }
  }

  /// Eight-point stars thrown out among the sparks.
  void stars(
    Offset c, {
    required double t,
    required int count,
    required double speedMin,
    required double speedMax,
    List<Color> colors = _kRainbow,
    double lifeMin = 0.9,
    double lifeMax = 1.15,
    double gravity = 125,
    double size = 5.0,
  }) {
    for (int i = 0; i < count; i++) {
      final double a = math.pi * 2 * i / count + 0.22;
      final double speed = between(speedMin, speedMax) * scale;
      _add(
        kind: _ParticleKind.star,
        origin: c,
        velocity: Offset(math.cos(a) * speed, math.sin(a) * speed),
        color: pick(colors),
        size: size * between(0.85, 1.4),
        thickness: between(1.4, 2.1),
        spin: (rng.nextDouble() * 2 - 1) * 4.5,
        delay: t + 0.02 + rng.nextDouble() * 0.035,
        life: between(lifeMin, lifeMax),
        gravity: gravity,
        drag: _kSparkDrag,
      );
    }
  }

  /// Glitter: small glowing dots, optionally twinkling [twinkle] times a
  /// second. [scatter] spreads their starting points over a disc, so
  /// zero-speed embers become a crackle of pops.
  void embers(
    Offset c, {
    required double t,
    required int count,
    required double speedMin,
    required double speedMax,
    List<Color> colors = _kGolds,
    double lifeMin = 1.0,
    double lifeMax = 1.4,
    double gravity = 70,
    double drag = 2.6,
    double twinkle = 0,
    double sizeMin = 1.3,
    double sizeMax = 2.3,
    double scatter = 0,
    double delayMin = 0,
    double delayMax = 0.04,
  }) {
    // Glitter and pops are heard as a crackle.
    if (twinkle > 0 || scatter > 0) {
      _cue(t + delayMin + 0.05, FireworkSound.crackle);
    }
    for (int i = 0; i < count; i++) {
      final double a = rng.nextDouble() * math.pi * 2;
      final double speed = between(speedMin, speedMax) * scale;
      final double r = scatter * scale * math.sqrt(rng.nextDouble());
      final double sa = rng.nextDouble() * math.pi * 2;
      _add(
        kind: _ParticleKind.ember,
        origin: c + Offset(math.cos(sa) * r, math.sin(sa) * r),
        velocity: Offset(math.cos(a) * speed, math.sin(a) * speed),
        color: pick(colors),
        size: between(sizeMin, sizeMax),
        thickness: 0,
        delay: t + between(delayMin, delayMax),
        life: between(lifeMin, lifeMax),
        gravity: gravity,
        drag: drag,
        twinkle: twinkle,
        phase: rng.nextDouble() * math.pi * 2,
      );
    }
  }

  /// The instant a shell breaks: a soft bloom of light that is gone at once,
  /// and its bang: a big shell booms, a small one sounds far off. The tiny
  /// flashes of a crossette's splits are silent.
  void flash(
    Offset c, {
    required double t,
    Color color = _kWhite,
    double radius = 18,
    double grow = 46,
    double life = 0.24,
  }) {
    if (radius >= 8) {
      _cue(t, radius >= 14 ? FireworkSound.boom : FireworkSound.far,
          weight: radius);
    }
    _add(
      kind: _ParticleKind.flash,
      origin: c,
      velocity: Offset.zero,
      color: Color.lerp(color, _kWhite, 0.55)!,
      size: radius * scale,
      thickness: grow * scale,
      delay: t,
      life: life,
    );
  }

  /// Spent powder hanging where a shell opened. Short-lived on purpose: it
  /// should read as a trace the firework left, not haze over the table.
  void puffs(
    Offset c, {
    required double t,
    required int count,
    Color tint = _kWhite,
  }) {
    for (int i = 0; i < count; i++) {
      final double angle = rng.nextDouble() * math.pi * 2;
      final double drift = 14 + rng.nextDouble() * 26;
      _add(
        kind: _ParticleKind.smoke,
        origin: c +
            Offset(
              (rng.nextDouble() - 0.5) * 26,
              (rng.nextDouble() - 0.5) * 22,
            ),
        velocity: Offset(
          math.cos(angle) * drift,
          math.sin(angle) * drift - 26,
        ),
        color: Color.lerp(tint, const Color(0xFFE9E9F0), 0.80)!
            .withValues(alpha: 0.34 - rng.nextDouble() * 0.09),
        size: 9.0 + rng.nextDouble() * 7.0,
        thickness: 26.0 + rng.nextDouble() * 22.0,
        delay: t + 0.045 + rng.nextDouble() * 0.03,
        life: 0.54 + rng.nextDouble() * 0.18,
      );
    }
  }

  /// Where a dragged particle is after [time] seconds.
  Offset _pathAt(Offset origin, Offset v, double drag, double gravity,
      double time) {
    final double travel =
        drag > 0 ? (1 - math.exp(-drag * time)) / drag : time;
    return origin +
        Offset(v.dx * travel, v.dy * travel + 0.5 * gravity * time * time);
  }

  // ----- The shows -----

  /// The original show, unchanged: three sprays from the action bar, each
  /// with launch comets, confetti and a starburst above it.
  void _classic() {
    final List<Offset> origins = launch;
    const double s = _kClassicSec;
    final double density = 1.0 / math.sqrt(origins.length.toDouble());
    int scaledCount(int base, int min, int max) =>
        (base * density).round().clamp(min, max) * multiplier;

    final int smokeCount = scaledCount(6, 3, 6);
    final int confettiCount = scaledCount(32, 16, 32);
    final int cometCount = scaledCount(12, 7, 12);
    final int sparkCount = scaledCount(42, 22, 42);
    final int starCount = scaledCount(8, 5, 8);
    final int burstSmokeCount = scaledCount(5, 3, 5);
    final int burstWaveCount = multiplier;
    _cue(0, FireworkSound.launch);

    for (int originIndex = 0; originIndex < origins.length; originIndex++) {
      final Offset origin = origins[originIndex];
      final double originDelay = originIndex * 0.035;

      for (int i = 0; i < smokeCount; i++) {
        final double vx = (rng.nextDouble() - 0.5) * 90;
        final double vy = -(90 + rng.nextDouble() * 90);
        final double baseR = 10.0 + rng.nextDouble() * 8.0;
        final double grow = 18.0 + rng.nextDouble() * 26.0;
        _add(
          kind: _ParticleKind.smoke,
          origin: origin +
              Offset(
                (rng.nextDouble() - 0.5) * 10,
                (rng.nextDouble() - 0.5) * 8,
              ),
          velocity: Offset(vx, vy),
          color: const Color(0xFFECECEC).withValues(
            alpha: 0.27 - rng.nextDouble() * 0.07,
          ),
          size: baseR,
          thickness: grow,
          delay: originDelay * s,
          life: (0.52 + rng.nextDouble() * 0.16) * s,
        );
      }

      for (int i = 0; i < confettiCount; i++) {
        final double vx = (rng.nextDouble() - 0.5) * 260;
        final double vy = -(360 + rng.nextDouble() * 260);
        final double size = 3.6 + rng.nextDouble() * 3.2;
        _add(
          kind: _ParticleKind.confetti,
          origin: origin + Offset((rng.nextDouble() - 0.5) * 18, 0),
          velocity: Offset(vx, vy),
          color: _kConfetti[rng.nextInt(_kConfetti.length)]
              .withValues(alpha: 0.98 - rng.nextDouble() * 0.16),
          size: size,
          thickness: 1.0,
          spin: (rng.nextDouble() * 2 - 1) * 10.0,
          delay: (originDelay + rng.nextDouble() * 0.055) * s,
          life: (0.72 + rng.nextDouble() * 0.18) * s,
          gravity: 760,
        );
      }

      // Bright launch comets connect the action bar to the delayed starbursts.
      for (int i = 0; i < cometCount; i++) {
        final double vx = (rng.nextDouble() - 0.5) * 170;
        final double vy = -(700 + rng.nextDouble() * 480);
        final double len = 26.0 + rng.nextDouble() * 28.0;
        _add(
          kind: _ParticleKind.comet,
          origin: origin + Offset((rng.nextDouble() - 0.5) * 24, 0),
          velocity: Offset(vx, vy),
          color: _kRainbow[rng.nextInt(_kRainbow.length)]
              .withValues(alpha: 0.98),
          size: len,
          thickness: 2.0 + rng.nextDouble() * 1.0,
          delay: (originDelay + (i / cometCount) * 0.075) * s,
          life: (0.42 + rng.nextDouble() * 0.14) * s,
          gravity: 560,
        );
      }

      final int baseBurstColor = rng.nextInt(_kRainbow.length);
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
        final Color burstColor =
            _kRainbow[(baseBurstColor + wave * 3) % _kRainbow.length];
        _cue(burstDelay * s, FireworkSound.boom, weight: 18.0 - originIndex);

        // Even angular spacing makes the explosion read as a firework rather
        // than another upward spray; small jitter keeps it organic.
        for (int i = 0; i < sparksInWave; i++) {
          final double angle = (math.pi * 2 * i / sparksInWave) +
              (rng.nextDouble() - 0.5) * 0.16;
          // Faster off the mark than before: drag eats most of it, and the
          // reach that survives (v0/_kSparkDrag) lands near the old radius.
          final double speed = (170 + rng.nextDouble() * 280) * 1.7;
          final Color color = rng.nextDouble() < 0.58
              ? burstColor
              : _kRainbow[rng.nextInt(_kRainbow.length)];
          _add(
            kind: _ParticleKind.spark,
            origin: burstCenter,
            velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
            color: color.withValues(alpha: 0.98),
            size: 13.0 + rng.nextDouble() * 17.0,
            thickness: 1.35 + rng.nextDouble() * 1.1,
            delay: (burstDelay + rng.nextDouble() * 0.025) * s,
            life: (0.52 + rng.nextDouble() * 0.18) * s,
            gravity: 190,
            drag: _kSparkDrag,
          );
        }

        for (int i = 0; i < starsInWave; i++) {
          final double angle = (math.pi * 2 * i / starsInWave) + 0.22;
          final double speed = (80 + rng.nextDouble() * 150) * 1.7;
          _add(
            kind: _ParticleKind.star,
            origin: burstCenter,
            velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
            color: _kRainbow[rng.nextInt(_kRainbow.length)]
                .withValues(alpha: 1),
            size: 4.6 + rng.nextDouble() * 3.4,
            thickness: 1.4 + rng.nextDouble() * 0.7,
            spin: (rng.nextDouble() * 2 - 1) * 4.5,
            delay: (burstDelay + 0.02 + rng.nextDouble() * 0.035) * s,
            life: (0.58 + rng.nextDouble() * 0.16) * s,
            gravity: 125,
            drag: _kSparkDrag,
          );
        }

        // Spent powder, split across waves exactly as the sparks and stars
        // are. Used per wave instead, the puff count would pick up the wave
        // multiplier on top of the particle multiplier and scale 4x at
        // double intensity, breaking the guarantee that doubling intensity
        // doubles the budget.
        final int smokeInWave = burstSmokeCount ~/ burstWaveCount +
            (wave < burstSmokeCount % burstWaveCount ? 1 : 0);
        puffs(burstCenter, t: burstDelay * s, count: smokeInWave,
            tint: burstColor);
      }
    }
  }

  void _redAndBlue() {
    for (int wave = 0; wave < multiplier; wave++) {
      final double t = wave * 0.38;
      final double out = wave * 0.10;
      final double fy = 0.30 - wave * 0.08;
      _brandShell(_left, sky(0.30 - out, fy), t: t, color: _kFerrari);
      _brandShell(_right, sky(0.70 + out, fy), t: t + 0.12, color: _kMiami);
    }
  }

  void _brandShell(Offset from, Offset to,
      {required double t, required Color color}) {
    final double open = rocket(from, to, t: t, color: color);
    flash(to, t: open, color: color);
    sparks(
      to,
      t: open,
      count: 36,
      speedMin: 440,
      speedMax: 540,
      colorOf: (_) => rng.nextDouble() < 0.75 ? color : pick(_kGoldWhite),
      length: 22,
      lifeMin: 0.85,
      lifeMax: 1.05,
    );
    stars(to,
        t: open,
        count: 6,
        speedMin: 180,
        speedMax: 300,
        colors: const <Color>[_kGold]);
    puffs(to, t: open, count: 3, tint: color);
  }

  void _goldenWillow() {
    const List<double> xs = <double>[0.25, 0.50, 0.75];
    const List<double> ys = <double>[0.28, 0.20, 0.28];
    final List<Offset> from = _three;
    for (int wave = 0; wave < multiplier; wave++) {
      for (int i = 0; i < 3; i++) {
        final Offset to = sky(
          xs[i] + (wave == 0 ? 0 : (rng.nextDouble() - 0.5) * 0.12),
          ys[i] + wave * 0.06,
        );
        final double open = rocket(from[i], to,
            t: wave * 0.34 + i * 0.12,
            flight: 0.5,
            color: _kGold,
            thickness: 1.8,
            length: 30);
        flash(to, t: open, color: _kGold, radius: 14, grow: 36);
        sparks(
          to,
          t: open,
          count: 34,
          speedMin: 430,
          speedMax: 560,
          colors: _kGolds,
          length: 44,
          thickness: 1.25,
          lifeMin: 1.25,
          lifeMax: 1.6,
          gravity: 240,
          drag: 3.0,
          angleJitter: 0.3,
          followPath: true,
        );
        embers(
          to,
          t: open + 0.25,
          count: 10,
          speedMin: 40,
          speedMax: 160,
          lifeMin: 0.9,
          lifeMax: 1.25,
          gravity: 110,
          twinkle: 10,
          scatter: 70,
        );
      }
    }
  }

  void _palmGrove() {
    const List<double> xs = <double>[0.22, 0.50, 0.78];
    const List<double> ys = <double>[0.32, 0.24, 0.32];
    final List<Offset> from = _three;
    for (int wave = 0; wave < multiplier; wave++) {
      for (int i = 0; i < 3; i++) {
        final Offset to = sky(
          xs[i] + (wave == 0 ? 0 : (rng.nextDouble() - 0.5) * 0.12),
          ys[i] - wave * 0.06,
        );
        final Color c = _kSunset[(i + wave * 2) % _kSunset.length];
        final double open = rocket(from[i], to,
            t: wave * 0.36 + i * 0.10,
            flight: 0.6,
            color: _kGold,
            thickness: 3.2,
            length: 48);
        flash(to, t: open, color: c, radius: 20, grow: 50);
        // Seven fronds, one standing straight up.
        sparks(
          to,
          t: open,
          count: 7,
          speedMin: 460,
          speedMax: 500,
          colorOf: (_) => c,
          length: 58,
          thickness: 3.4,
          lifeMin: 1.05,
          lifeMax: 1.25,
          gravity: 330,
          drag: 1.9,
          angleJitter: 0.2,
          startAngle: -math.pi / 2,
          followPath: true,
        );
        sparks(
          to,
          t: open + 0.02,
          count: 14,
          speedMin: 180,
          speedMax: 260,
          colors: <Color>[c, _kGold],
          length: 16,
          thickness: 1.3,
          lifeMin: 0.6,
          lifeMax: 0.8,
          gravity: 200,
        );
        puffs(to, t: open, count: 2, tint: c);
      }
    }
  }

  void _chrysanthemum() {
    for (int wave = 0; wave < multiplier; wave++) {
      final Offset to = wave == 0
          ? sky(0.5, 0.34)
          : sky(rng.nextBool() ? 0.28 : 0.72, 0.28);
      final Color main = pick(_kRainbow);
      final double open =
          rocket(_middle, to, t: wave * 0.4, flight: 0.6, color: _kWhite);
      flash(to, t: open, radius: 24, grow: 60);
      sparks(
        to,
        t: open,
        count: 72,
        speedMin: 480,
        speedMax: 540,
        colorOf: (_) => rng.nextDouble() < 0.8 ? main : _kWhite,
        length: 26,
        thickness: 1.3,
        lifeMin: 0.95,
        lifeMax: 1.15,
        angleJitter: 0.08,
      );
      // The gold heart.
      sparks(
        to,
        t: open + 0.04,
        count: 18,
        speedMin: 170,
        speedMax: 220,
        colors: _kGolds,
        length: 12,
        thickness: 1.2,
        lifeMin: 0.7,
        lifeMax: 0.9,
        gravity: 150,
      );
      puffs(to, t: open, count: 4, tint: main);
    }
  }

  void _ringOfFire() {
    const List<double> xs = <double>[0.28, 0.50, 0.72];
    const List<double> ys = <double>[0.32, 0.25, 0.32];
    final List<Offset> from = _three;
    for (int wave = 0; wave < multiplier; wave++) {
      for (int i = 0; i < 3; i++) {
        final Offset to = sky(
          xs[i] + (wave == 0 ? 0 : (rng.nextDouble() - 0.5) * 0.14),
          ys[i] - wave * 0.07,
        );
        final double open =
            rocket(from[i], to, t: wave * 0.34 + i * 0.10, color: _kGold);
        flash(to, t: open, color: _kFerrari, radius: 16, grow: 40);
        // One speed, no jitter: a crisp ring.
        sparks(
          to,
          t: open,
          count: 40,
          speedMin: 470,
          speedMax: 470,
          colorOf: (k) => _kWarm[k % _kWarm.length],
          length: 18,
          thickness: 1.6,
          lifeMin: 0.9,
          lifeMax: 1.0,
          gravity: 120,
          angleJitter: 0,
          startAngle: rng.nextDouble() * math.pi,
          delayJitter: 0,
        );
      }
    }
  }

  void _saturn() {
    final List<Offset> from = <Offset>[_left, _right];
    for (int wave = 0; wave < multiplier; wave++) {
      for (int i = 0; i < 2; i++) {
        final Offset c = wave == 0
            ? sky(i == 0 ? 0.34 : 0.66, 0.30)
            : sky(i == 0 ? 0.18 : 0.82, 0.24);
        final double open = rocket(from[i], c,
            t: wave * 0.36 + i * 0.14, color: _kMiami);
        flash(c, t: open, color: _kMiami);
        sparks(
          c,
          t: open,
          count: 30,
          speedMin: 250,
          speedMax: 330,
          colors: _kSilver,
          length: 16,
          thickness: 1.2,
          lifeMin: 0.8,
          lifeMax: 1.0,
          gravity: 140,
        );
        // The ring: one speed, flattened and tilted.
        sparks(
          c,
          t: open,
          count: 36,
          speedMin: 560,
          speedMax: 560,
          colors: _kCool,
          length: 20,
          thickness: 1.5,
          lifeMin: 0.95,
          lifeMax: 1.05,
          gravity: 110,
          angleJitter: 0,
          delayJitter: 0,
          squashY: 0.32,
          tilt: (i == 0 ? -1 : 1) * between(0.18, 0.38),
        );
      }
    }
  }

  void _crossette() {
    const List<double> xs = <double>[0.25, 0.50, 0.75];
    const List<double> ys = <double>[0.30, 0.24, 0.30];
    final List<Offset> from = _three;
    for (int wave = 0; wave < multiplier; wave++) {
      for (int i = 0; i < 3; i++) {
        final Offset to = sky(
          xs[i] + (wave == 0 ? 0 : (rng.nextDouble() - 0.5) * 0.14),
          ys[i] - wave * 0.07,
        );
        final Color c = _kNeon[(i + 2 * wave) % _kNeon.length];
        final double open =
            rocket(from[i], to, t: wave * 0.36 + i * 0.11, color: c);
        flash(to, t: open, color: c, radius: 14, grow: 34);
        _crossetteShell(to, t: open, color: c);
      }
    }
  }

  /// Eight stars fly out, and each splits into four at [split] seconds.
  void _crossetteShell(Offset c, {required double t, required Color color}) {
    const int arms = 8;
    const double split = 0.36;
    const double drag = 2.0;
    const double gravity = 160;
    final double base = rng.nextDouble() * math.pi;
    // The splits are heard as a crackle.
    _cue(t + split, FireworkSound.crackle);
    for (int i = 0; i < arms; i++) {
      final double a = base + math.pi * 2 * i / arms;
      final double speed = 400 * scale;
      final Offset v = Offset(math.cos(a) * speed, math.sin(a) * speed);
      _add(
        kind: _ParticleKind.spark,
        origin: c,
        velocity: v,
        color: color,
        size: 22,
        thickness: 2.0,
        delay: t,
        life: split,
        gravity: gravity,
        drag: drag,
      );
      final Offset splitAt = _pathAt(c, v, drag, gravity, split);
      flash(splitAt, t: t + split, color: color, radius: 5, grow: 12, life: 0.12);
      for (int k = 0; k < 4; k++) {
        final double b = a + math.pi / 4 + k * math.pi / 2;
        final double s2 = 230 * scale;
        _add(
          kind: _ParticleKind.spark,
          origin: splitAt,
          velocity: Offset(math.cos(b) * s2, math.sin(b) * s2),
          color: k.isEven ? color : _kWhite,
          size: 14,
          thickness: 1.4,
          delay: t + split,
          life: 0.55,
          gravity: gravity,
          drag: drag,
        );
      }
    }
  }

  void _glitterStrobe() {
    const List<Offset> spots = <Offset>[
      Offset(0.24, 0.26),
      Offset(0.62, 0.18),
      Offset(0.40, 0.36),
      Offset(0.78, 0.30),
    ];
    for (int wave = 0; wave < multiplier; wave++) {
      for (int i = 0; i < spots.length; i++) {
        final Offset c = sky(
          spots[i].dx + wave * 0.08 * (i.isEven ? 1 : -1),
          spots[i].dy + wave * 0.05,
        );
        final double t = i * 0.18 + wave * 0.09;
        flash(c, t: t, radius: 12, grow: 30);
        embers(
          c,
          t: t,
          count: 34,
          speedMin: 70,
          speedMax: 300,
          colors: _kSilver,
          lifeMin: 1.1,
          lifeMax: 1.45,
          gravity: 70,
          drag: 2.4,
          twinkle: 13,
          sizeMin: 2.0,
          sizeMax: 3.4,
        );
      }
    }
  }

  void _rocketSalvo() {
    const int n = 7;
    for (int wave = 0; wave < multiplier; wave++) {
      for (int i = 0; i < n; i++) {
        // The second salvo runs back the other way.
        final int k = wave.isEven ? i : n - 1 - i;
        final double x = (k + 0.5) / n;
        final Offset from = Offset(stage.width * x, stage.height + 12);
        final Offset to =
            sky(x + (rng.nextDouble() - 0.5) * 0.05, between(0.16, 0.32));
        final Color c = _kRainbow[(k * 3 + wave) % _kRainbow.length];
        final double open = rocket(from, to,
            t: wave * 0.5 + i * 0.07,
            flight: 0.5,
            color: c,
            thickness: 1.8,
            length: 28);
        flash(to, t: open, color: c, radius: 10, grow: 26);
        sparks(
          to,
          t: open,
          count: 16,
          speedMin: 300,
          speedMax: 380,
          colorOf: (_) => c,
          length: 14,
          thickness: 1.3,
          lifeMin: 0.7,
          lifeMax: 0.85,
          gravity: 170,
        );
      }
    }
  }

  void _fountains() {
    const int perGerb = 60;
    final List<Offset> from = _three;
    final int count = perGerb * multiplier;
    // A fountain is lit, not fired: a low thump, then its crackling spray.
    _cue(0, FireworkSound.launch);
    _cue(0.15, FireworkSound.crackle);
    for (int i = 0; i < 3; i++) {
      final List<Color> colours = i == 1 ? _kGolds : _kSilver;
      for (int k = 0; k < count; k++) {
        final double a = -math.pi / 2 + (rng.nextDouble() - 0.5) * 0.62;
        final double speed = between(560, 760) * scale;
        _add(
          kind: _ParticleKind.spark,
          origin: from[i] + Offset((rng.nextDouble() - 0.5) * 8, 0),
          velocity: Offset(math.cos(a) * speed, math.sin(a) * speed),
          color: pick(colours).withValues(alpha: 0.98),
          size: between(10, 16),
          thickness: between(1.0, 1.6),
          delay: i * 0.06 + (k / count) * 1.15,
          life: between(0.7, 0.9),
          gravity: 900,
          drag: 0.7,
          followPath: true,
        );
      }
    }
  }

  void _confettiCannons() {
    final List<Offset> mouths = <Offset>[
      Offset(0, stage.height),
      Offset(stage.width, stage.height),
    ];
    for (int blast = 0; blast < multiplier; blast++) {
      for (int side = 0; side < 2; side++) {
        // Up and in: 60 degrees from the left corner, 120 from the right.
        final double aim = side == 0 ? -math.pi / 3 : -2 * math.pi / 3;
        final double inward = side == 0 ? 1 : -1;
        final double t = side * 0.08 + blast * 0.45;
        final Offset mouth = mouths[side];
        flash(mouth + Offset(20 * inward, -20),
            t: t, color: _kGold, radius: 22, grow: 60, life: 0.3);
        const int count = 70;
        for (int k = 0; k < count; k++) {
          final double a = aim + (rng.nextDouble() - 0.5) * 0.7;
          final double speed = between(700, 1050) * scale;
          _add(
            kind: _ParticleKind.confetti,
            origin: mouth,
            velocity: Offset(math.cos(a) * speed, math.sin(a) * speed),
            color: pick(_kPaper)
                .withValues(alpha: 0.98 - rng.nextDouble() * 0.16),
            size: between(4.8, 8.4),
            thickness: 1.0,
            spin: (rng.nextDouble() * 2 - 1) * 10.0,
            delay: t + (k / count) * 0.18,
            life: between(1.5, 1.95),
            gravity: 300,
            drag: 1.7,
          );
        }
      }
    }
  }

  void _kamuro() {
    for (int wave = 0; wave < multiplier; wave++) {
      final Offset to = wave == 0
          ? sky(0.5, 0.32)
          : sky(rng.nextBool() ? 0.28 : 0.72, 0.26);
      final double open = rocket(_middle, to,
          t: wave * 0.32, flight: 0.6, color: _kGold, thickness: 1.8);
      flash(to, t: open, color: _kGold, radius: 26, grow: 64, life: 0.3);
      sparks(
        to,
        t: open,
        count: 24,
        speedMin: 520,
        speedMax: 600,
        colors: _kGolds,
        length: 16,
        thickness: 1.0,
        lifeMin: 1.35,
        lifeMax: 1.6,
        gravity: 210,
        drag: 3.4,
        angleJitter: 0.1,
        followPath: true,
      );
      embers(
        to,
        t: open + 0.05,
        count: 64,
        speedMin: 300,
        speedMax: 620,
        lifeMin: 1.4,
        lifeMax: 1.7,
        gravity: 200,
        drag: 3.4,
        twinkle: 8,
        sizeMin: 1.6,
        sizeMax: 2.8,
      );
    }
  }

  void _dahlias() {
    const List<double> xs = <double>[0.24, 0.50, 0.76];
    const List<double> ys = <double>[0.32, 0.26, 0.32];
    final List<Offset> from = _three;
    for (int wave = 0; wave < multiplier; wave++) {
      for (int i = 0; i < 3; i++) {
        final Offset to = sky(
          xs[i] + (wave == 0 ? 0 : (rng.nextDouble() - 0.5) * 0.14),
          ys[i] - wave * 0.07,
        );
        final Color c = _kSunset[(i + wave * 2) % _kSunset.length];
        final double open = rocket(from[i], to,
            t: wave * 0.34 + i * 0.12, color: c, thickness: 2.4);
        flash(to, t: open, color: c, radius: 18, grow: 44);
        sparks(
          to,
          t: open,
          count: 18,
          speedMin: 400,
          speedMax: 440,
          colorOf: (_) => c,
          length: 22,
          thickness: 2.9,
          lifeMin: 0.85,
          lifeMax: 1.0,
          gravity: 200,
          angleJitter: 0.1,
        );
        stars(to,
            t: open, count: 6, speedMin: 160, speedMax: 260, colors: _kGoldWhite);
        puffs(to, t: open, count: 3, tint: c);
      }
    }
  }

  void _waterfall() {
    const int n = 5;
    for (int wave = 0; wave < multiplier; wave++) {
      for (int i = 0; i < n; i++) {
        final Offset c = wave == 0
            ? sky(0.10 + 0.20 * i, 0.10)
            : sky(0.20 + 0.15 * i, 0.16);
        // Opens from the middle outwards.
        final double t = (i - n ~/ 2).abs() * 0.07 + wave * 0.42;
        flash(c, t: t, radius: 10, grow: 26);
        sparks(
          c,
          t: t,
          count: 26,
          speedMin: 130,
          speedMax: 230,
          colors: _kSilver,
          length: 30,
          thickness: 1.2,
          lifeMin: 1.45,
          lifeMax: 1.8,
          gravity: 200,
          drag: 2.8,
          angleJitter: 0.4,
          followPath: true,
        );
        embers(
          c,
          t: t + 0.1,
          count: 6,
          speedMin: 40,
          speedMax: 160,
          lifeMin: 1.1,
          lifeMax: 1.5,
          gravity: 160,
          drag: 2.4,
          twinkle: 11,
        );
      }
    }
  }

  void _crackle() {
    const List<double> xs = <double>[0.26, 0.50, 0.74];
    const List<double> ys = <double>[0.30, 0.24, 0.30];
    final List<Offset> from = _three;
    for (int wave = 0; wave < multiplier; wave++) {
      for (int i = 0; i < 3; i++) {
        final Offset to = sky(
          xs[i] + (wave == 0 ? 0 : (rng.nextDouble() - 0.5) * 0.14),
          ys[i] - wave * 0.07,
        );
        final double open =
            rocket(from[i], to, t: wave * 0.36 + i * 0.12, color: _kGold);
        flash(to, t: open, radius: 16, grow: 40);
        sparks(
          to,
          t: open,
          count: 28,
          speedMin: 380,
          speedMax: 470,
          colors: _kGolds,
          length: 16,
          thickness: 1.3,
          lifeMin: 0.55,
          lifeMax: 0.7,
          gravity: 160,
        );
        // The crackle: still pops scattered where the sparks went.
        embers(
          to,
          t: open,
          count: 34,
          speedMin: 0,
          speedMax: 12,
          colors: _kPopColours,
          lifeMin: 0.08,
          lifeMax: 0.14,
          gravity: 0,
          drag: 0,
          sizeMin: 2.4,
          sizeMax: 3.8,
          scatter: 150,
          delayMin: 0.30,
          delayMax: 0.75,
        );
        puffs(to, t: open, count: 2, tint: _kGold);
      }
    }
  }

  void _pinwheels() {
    const int arms = 5;
    const int steps = 10;
    final List<Offset> from = <Offset>[_left, _right];
    for (int wave = 0; wave < multiplier; wave++) {
      for (int side = 0; side < 2; side++) {
        final Offset c = wave == 0
            ? sky(side == 0 ? 0.32 : 0.68, 0.30)
            : sky(side == 0 ? 0.18 : 0.82, 0.22);
        final double open = rocket(from[side], c,
            t: wave * 0.4 + side * 0.12, color: _kWhite);
        flash(c, t: open, radius: 14, grow: 34);
        // The two wheels turn opposite ways.
        final double dir = side == 0 ? 1 : -1;
        final double base = rng.nextDouble() * math.pi * 2;
        for (int arm = 0; arm < arms; arm++) {
          final Color col = _kNeon[(arm + wave) % _kNeon.length];
          for (int s = 0; s < steps; s++) {
            final double a = base + arm * math.pi * 2 / arms + dir * s * 0.30;
            final double speed = 380 * scale;
            _add(
              kind: _ParticleKind.spark,
              origin: c,
              velocity: Offset(math.cos(a) * speed, math.sin(a) * speed),
              color: col,
              size: 18,
              thickness: 1.6,
              delay: open + s * 0.045,
              life: 0.75,
              gravity: 110,
              drag: 2.4,
            );
          }
        }
      }
    }
  }

  void _crossfire() {
    const int perSide = 3;
    for (int wave = 0; wave < multiplier; wave++) {
      for (int k = 0; k < perSide; k++) {
        for (int side = 0; side < 2; side++) {
          final Offset from =
              Offset(side == 0 ? 0 : stage.width, stage.height + 10);
          // Red climbs from the left corner and opens right of centre, blue
          // the other way, so the trails cross over the table.
          final double x = side == 0 ? 0.42 + k * 0.17 : 0.58 - k * 0.17;
          final Offset to = sky(
            x + (rng.nextDouble() - 0.5) * 0.04,
            0.18 + k * 0.06 + wave * 0.05,
          );
          final Color c = side == 0 ? _kFerrari : _kMiami;
          final double open = rocket(from, to,
              t: wave * 0.5 + k * 0.16 + side * 0.08,
              flight: 0.6,
              color: c,
              thickness: 2.0);
          flash(to, t: open, color: c, radius: 12, grow: 30);
          sparks(
            to,
            t: open,
            count: 22,
            speedMin: 330,
            speedMax: 410,
            colorOf: (_) => rng.nextDouble() < 0.8 ? c : _kWhite,
            length: 16,
            thickness: 1.4,
            lifeMin: 0.75,
            lifeMax: 0.9,
            gravity: 170,
          );
          stars(to,
              t: open,
              count: 3,
              speedMin: 120,
              speedMax: 200,
              colors: const <Color>[_kGold]);
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Painting.

/// One sound of a show, [at] seconds from its start.
class _SoundCue {
  const _SoundCue(this.at, this.sound, this.weight);

  final double at;
  final FireworkSound sound;
  final double weight;
}

enum _ParticleKind { smoke, confetti, comet, spark, star, ember, flash }

class _BurstParticle {
  final Offset origin;
  final Offset velocity;
  final Color color;
  final double size;
  final double thickness;
  final double spin;
  final _ParticleKind kind;

  /// Seconds from the start of the show.
  final double delay;

  /// Seconds.
  final double life;
  final double gravity;

  /// Air resistance in 1/s; 0 keeps its speed (comets, classic confetti).
  final double drag;

  /// Blinks this many times a second (glitter); 0 is steady.
  final double twinkle;
  final double phase;

  /// Point the trail along the slowed, falling path instead of the launch
  /// direction, so willows and waterfalls droop.
  final bool followPath;

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
    this.drag = 0,
    this.twinkle = 0,
    this.phase = 0,
    this.followPath = false,
  });
}

class _ActionBurstPainter extends CustomPainter {
  final Animation<double> progress;
  final List<_BurstParticle> particles;
  final double lengthSec;

  _ActionBurstPainter({
    required this.progress,
    required this.particles,
    required this.lengthSec,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;

    final double elapsed = progress.value.clamp(0.0, 1.0) * lengthSec;
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
      final double? localProgress = _localProgress(p, elapsed);
      if (localProgress == null) continue;

      final double time = localProgress * p.life;
      final Offset center =
          p.origin + Offset(p.velocity.dx * time, p.velocity.dy * time);

      final double smokeT = Curves.easeOutCubic.transform(localProgress);
      final double r = p.size + p.thickness * smokeT;
      final double a =
          (p.color.a * _particleFade(localProgress) * (1.0 - smokeT * 0.35))
              .clamp(0.0, 0.46);
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
      final double? localProgress = _localProgress(p, elapsed);
      if (localProgress == null) continue;

      final double time = localProgress * p.life;
      // Shell sparks drag, so they bloom and ease; a rising comet is a lit
      // charge still under thrust and keeps travelling.
      final double travel = p.drag > 0
          ? (1 - math.exp(-p.drag * time)) / p.drag
          : time;
      final double dx = p.velocity.dx * travel;
      final double dy = p.velocity.dy * travel + 0.5 * p.gravity * time * time;
      final Offset pos = p.origin + Offset(dx, dy);

      if (p.kind == _ParticleKind.flash) {
        _drawFlash(canvas, p, pos, localProgress, fillPaint);
        continue;
      }

      final double kindAlphaScale = switch (p.kind) {
        _ParticleKind.confetti => _kBurstConfettiAlphaScale,
        _ParticleKind.comet ||
        _ParticleKind.spark ||
        _ParticleKind.star ||
        _ParticleKind.ember =>
          _kBurstFireworkAlphaScale,
        _ParticleKind.smoke || _ParticleKind.flash => 1.0,
      };
      final double fade =
          _particleFade(localProgress) * _twinkle(p, time);
      if (fade <= 0.001) continue;
      final Color color = p.color.withValues(
        alpha: (p.color.a * fade * kindAlphaScale).clamp(0.0, 1.0),
      );

      switch (p.kind) {
        case _ParticleKind.smoke:
        case _ParticleKind.flash:
          // Handled above.
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
          _drawTrail(
            canvas,
            head: pos,
            direction: _heading(p, time),
            length: p.size * (1.0 - localProgress * 0.22),
            thickness: p.thickness,
            color: color,
            fade: fade,
            heat: _coolWhite(localProgress),
            glowStroke: glowStroke,
            colorStroke: colorStroke,
            hotStroke: hotStroke,
            glowScale: 4.2,
          );
          break;
        case _ParticleKind.spark:
          _drawTrail(
            canvas,
            head: pos,
            direction: _heading(p, time),
            length: p.size * (1.0 - localProgress * 0.36),
            thickness: p.thickness,
            color: color,
            fade: fade,
            heat: _coolWhite(localProgress),
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
        case _ParticleKind.ember:
          _drawEmber(
            canvas,
            center: pos,
            radius: p.size,
            color: color,
            fade: fade,
            heat: _coolWhite(localProgress),
            fillPaint: fillPaint,
          );
          break;
      }
    }
  }

  double? _localProgress(_BurstParticle particle, double elapsed) {
    if (elapsed < particle.delay || particle.life <= 0) return null;
    final double value = (elapsed - particle.delay) / particle.life;
    if (value < 0 || value > 1) return null;
    return value.clamp(0.0, 1.0);
  }

  /// Which way a trail points: along the launch direction bent by gravity,
  /// or, for [_BurstParticle.followPath], along the slowed path itself.
  Offset _heading(_BurstParticle p, double time) {
    if (p.followPath && p.drag > 0) {
      final double decay = math.exp(-p.drag * time);
      return Offset(
        p.velocity.dx * decay,
        p.velocity.dy * decay + p.gravity * time,
      );
    }
    return Offset(p.velocity.dx, p.velocity.dy + p.gravity * time);
  }

  /// 1 for steady particles; glitter blinks between bright and nearly out.
  double _twinkle(_BurstParticle p, double time) {
    if (p.twinkle <= 0) return 1.0;
    final double w = math.sin(math.pi * 2 * p.twinkle * time + p.phase);
    return w > 0.15 ? 1.0 : 0.12;
  }

  /// How white-hot a spark still is, 1 at ignition falling to 0.
  ///
  /// The additive white core used to run at ~0.95 for a particle's whole life.
  /// With forty sparks overlapping near the middle of a burst that summed to a
  /// flat white smear and the colour was lost exactly where the firework is
  /// brightest. Letting it cool hands the centre back to the palette, which
  /// reads as more colourful, not less bright.
  double _coolWhite(double progress) {
    final double t = (1.0 - progress).clamp(0.0, 1.0);
    return t * t;
  }

  double _particleFade(double progress) {
    final double fadeIn = (progress / 0.055).clamp(0.0, 1.0);
    final double fadeOut =
        1.0 - Curves.easeInCubic.transform(progress.clamp(0.0, 1.0));
    return (fadeIn * fadeOut).clamp(0.0, 1.0);
  }

  /// A shell breaking: bright at once, spreading and gone in a blink.
  void _drawFlash(
    Canvas canvas,
    _BurstParticle p,
    Offset center,
    double progress,
    Paint fillPaint,
  ) {
    final double grow = Curves.easeOutCubic.transform(progress);
    final double r = p.size + p.thickness * grow;
    final double a = (1.0 - progress) * (1.0 - progress) * p.color.a;
    if (a <= 0.001) return;
    fillPaint
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(
        center, r, fillPaint..color = p.color.withValues(alpha: a * 0.10));
    canvas.drawCircle(center, r * 0.55,
        fillPaint..color = p.color.withValues(alpha: a * 0.20));
    canvas.drawCircle(center, r * 0.22,
        fillPaint..color = Colors.white.withValues(alpha: a * 0.55));
  }

  void _drawEmber(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double fade,
    required double heat,
    required Paint fillPaint,
  }) {
    fillPaint
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center, radius * 2.6,
        fillPaint..color = color.withValues(alpha: color.a * 0.26));
    canvas.drawCircle(center, radius, fillPaint..color = color);
    if (heat > 0.04) {
      canvas.drawCircle(
        center,
        radius * 0.55,
        fillPaint
          ..color = Colors.white
              .withValues(alpha: (fade * heat * 0.9).clamp(0.0, 0.9)),
      );
    }
  }

  void _drawTrail(
    Canvas canvas, {
    required Offset head,
    required Offset direction,
    required double length,
    required double thickness,
    required Color color,
    required double fade,
    required double heat,
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
        ..color = color.withValues(alpha: color.a * 0.32)
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
            .withValues(alpha: (fade * 0.92 * heat).clamp(0.0, 0.92))
        ..strokeWidth = thickness * 0.62,
    );
    canvas.drawCircle(
      head,
      thickness * 2.4,
      glowStroke
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: color.a * 0.30),
    );
    glowStroke.style = PaintingStyle.stroke;
    canvas.drawCircle(
      head,
      thickness * 0.95,
      hotStroke
        ..color = const Color(0xFFFFFFFF)
            .withValues(alpha: (fade * 0.96 * heat).clamp(0.0, 0.96))
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
    return oldDelegate.particles != particles ||
        oldDelegate.lengthSec != lengthSec;
  }
}

math.Random _trySecureRandom() {
  try {
    return math.Random.secure();
  } catch (_) {
    return math.Random();
  }
}
