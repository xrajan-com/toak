// lib/ui/screens/game_screen/deal_layer.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;
import 'package:flutter/material.dart';

/// A single flying card in the deal timeline.
/// Coordinates are in FELT space (0,0 = top-left of felt inside the rail).
class DealFlight {
  final Offset from; // dealer hand position (felt coords)
  final Offset to; // target anchor (felt coords)
  final double settleAngleRad; // tiny final fan angle (radians)
  final Duration startDelay; // delay before this flight starts
  final Duration duration; // flight time
  final int seatIndex; // which seat this card is going to
  final int pass; // 1 or 2 (first or second card)
  final bool faceUp; // show face instead of back (hero, etc.)
  final Object? payload; // optional: anything your faceBuilder needs

  const DealFlight({
    required this.from,
    required this.to,
    required this.settleAngleRad,
    required this.startDelay,
    required this.duration,
    required this.seatIndex,
    required this.pass,
    this.faceUp = false,
    this.payload,
  });

  DealFlight shifted(Duration addDelay, {Offset by = Offset.zero}) =>
      DealFlight(
        from: from,
        to: to + by,
        settleAngleRad: settleAngleRad,
        startDelay: startDelay + addDelay,
        duration: duration,
        seatIndex: seatIndex,
        pass: pass,
        faceUp: faceUp,
        payload: payload,
      );
}

/// Builds a sequence of DealFlight entries for common dealing patterns.
class DealPlan {
  /// One clockwise round: each player gets exactly one card.
  ///
  /// [dealerIndex] → button; SB starts = (dealerIndex + 1) % n
  /// [heroIndex] → which seat should fly face-up (if provided / >= 0)
  /// [pass] → 1 or 2 (lets you differentiate payloads/offsets in your faceBuilder)
  static List<DealFlight> oneRoundClockwise({
    required Offset from,
    required List<Offset> toAnchors,
    required int dealerIndex,
    required int pass,
    int heroIndex = -1,
    Duration baseDelay = const Duration(milliseconds: 90),
    Duration fly = const Duration(milliseconds: 360),
    double fanAngle = 0.10, // ~6°
    Offset secondCardStackOffset = const Offset(10, -6),
    List<Object?> payloads = const [], // optional: per-seat payload for faces
  }) {
    if (toAnchors.isEmpty) return const [];
    final n = toAnchors.length;
    final sb = (dealerIndex + 1) % n; // small blind starts
    final order = List<int>.generate(n, (i) => (sb + i) % n);
    final flights = <DealFlight>[];

    for (int k = 0; k < order.length; k++) {
      final seat = order[k];
      final baseTo = toAnchors[seat];
      // Tiny offset to stack pass #2 slightly
      final to = pass == 2 ? (baseTo + secondCardStackOffset) : baseTo;

      flights.add(
        DealFlight(
          from: from,
          to: to,
          settleAngleRad:
              (seat.isEven ? fanAngle : -fanAngle) * (pass == 1 ? 0.9 : 1.2),
          startDelay: baseDelay * k,
          duration: fly,
          seatIndex: seat,
          pass: pass,
          faceUp: (seat == heroIndex),
          payload: (payloads.length == n) ? payloads[seat] : null,
        ),
      );
    }
    return flights;
  }

  /// Convenience: build both rounds as one list, with round 2 delayed to start
  /// after round 1 finishes (visual “two-pass” effect in a single batch).
  static List<DealFlight> twoRoundsClockwise({
    required Offset from,
    required List<Offset> toAnchors,
    required int dealerIndex,
    int heroIndex = -1,
    Duration baseDelay = const Duration(milliseconds: 90),
    Duration fly = const Duration(milliseconds: 360),
    double fanAngle = 0.10,
    Offset secondCardStackOffset = const Offset(10, -6),
    List<Object?> payloadsPass1 = const [],
    List<Object?> payloadsPass2 = const [],
  }) {
    final r1 = oneRoundClockwise(
      from: from,
      toAnchors: toAnchors,
      dealerIndex: dealerIndex,
      pass: 1,
      heroIndex: heroIndex,
      baseDelay: baseDelay,
      fly: fly,
      fanAngle: fanAngle,
      secondCardStackOffset: secondCardStackOffset, // ignored for pass 1
      payloads: payloadsPass1,
    );

    // Start round2 after round1’s last start delay.
    final r1Span = baseDelay * toAnchors.length;
    final r2Base = oneRoundClockwise(
      from: from,
      toAnchors: toAnchors,
      dealerIndex: dealerIndex,
      pass: 2,
      heroIndex: heroIndex,
      baseDelay: baseDelay,
      fly: fly,
      fanAngle: fanAngle,
      secondCardStackOffset: secondCardStackOffset,
      payloads: payloadsPass2,
    );

    final r2 = [for (final f in r2Base) f.shifted(r1Span)];
    return [...r1, ...r2];
  }

  /// Community row (flop/turn/river) from dealer to a center anchor.
  static List<DealFlight> communityRow({
    required Offset from,
    required Offset rowCenter,
    required int count, // 3 (flop), 1 (turn/river)
    required double cardGap, // horizontal gap between cards
    Duration baseDelay = const Duration(milliseconds: 90),
    Duration fly = const Duration(milliseconds: 360),
  }) {
    if (count <= 0) return const [];
    final flights = <DealFlight>[];
    final totalW = (count - 1) * cardGap;
    final startX = rowCenter.dx - totalW / 2;

    for (int i = 0; i < count; i++) {
      final to = Offset(startX + i * cardGap, rowCenter.dy);
      flights.add(DealFlight(
        from: from,
        to: to,
        settleAngleRad: 0.0,
        startDelay: baseDelay * i,
        duration: fly,
        seatIndex: -1,
        pass: 0,
        faceUp: true, // community flips face-up
      ));
    }
    return flights;
  }
}

/// Controller to start/pause/resume/stop a batch of DealFlights.
class DealController {
  Future<void> Function(
    List<DealFlight>, {
    String? backAsset,
    double speed,
  })? _onStart;

  VoidCallback? _onStop;
  VoidCallback? _onPause;
  VoidCallback? _onResume;

  bool get isAttached => _onStart != null;

  Future<void> start(
    List<DealFlight> flights, {
    String? backAsset,
    double speed = 1.0, // 0.2x..3.0x
  }) async {
    final fn = _onStart;
    if (fn != null) {
      await fn(
        flights,
        backAsset: backAsset,
        speed: speed.clamp(0.2, 3.0),
      );
    }
  }

  void stop() => _onStop?.call();
  void pause() => _onPause?.call();
  void resume() => _onResume?.call();
}

/// DealLayer renders flying cards above the felt.
/// Provide an optional [faceBuilder] to draw face-up cards (hero).
class DealLayer extends StatefulWidget {
  final DealController controller;

  /// Felt size in px (content area inside the rail).
  final Size feltSize;

  /// Visual card dimensions (should match your seat/front sizing).
  final double cardW;
  final double cardH;

  /// Shadow strength baseline.
  final double elevation;

  /// Fallback back asset used if none is passed to `start()`.
  final String defaultBackAsset;

  /// Optional: corner radius for card rects.
  final double cornerRadius;

  /// Optional: builds a face widget when a flight wants to be face-up.
  /// If null, face-up flights will still render the back.
  ///
  /// - You receive the DealFlight (includes seatIndex and pass).
  /// - Use `flight.payload` if you want to pipe rank/suit etc.
  final Widget Function(BuildContext ctx, DealFlight flight, double w, double h,
      double cornerRadius)? faceBuilder;

  const DealLayer({
    super.key,
    required this.controller,
    required this.feltSize,
    required this.cardW,
    required this.cardH,
    required this.defaultBackAsset,
    this.elevation = 10,
    this.cornerRadius = 8,
    this.faceBuilder,
  });

  @override
  State<DealLayer> createState() => _DealLayerState();
}

class _DealLayerState extends State<DealLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final Stopwatch _clock = Stopwatch();

  List<DealFlight> _flights = const [];
  String? _backAsset;

  Completer<void>? _doneCompleter;
  bool get _isRunning => _doneCompleter != null;

  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (mounted && _isRunning) setState(() {});
      });
    _bindController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant DealLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _unbindController(oldWidget.controller);
      _bindController(widget.controller);
    }
  }

  void _bindController(DealController controller) {
    controller._onStart =
        (flights, {String? backAsset, double speed = 1.0}) async {
      if (!mounted || flights.isEmpty) return;
      if (widget.feltSize.isEmpty || widget.cardW <= 0 || widget.cardH <= 0)
        return;

      _finishBatch(); // stop any running batch immediately

      _backAsset = backAsset ?? widget.defaultBackAsset;
      _flights = flights;
      _speed = speed.clamp(0.2, 3.0);

      _doneCompleter = Completer<void>();
      _clock
        ..reset()
        ..start();

      _ticker.animateTo(
        1.0,
        duration: const Duration(days: 365),
        curve: Curves.linear,
      );
      setState(() {});

      await _doneCompleter!.future;
    };

    controller._onStop = () {
      _finishBatch();
      if (mounted) setState(() {});
    };
    controller._onPause = () {
      if (!_isRunning) return;
      _clock.stop();
      _ticker.stop();
    };
    controller._onResume = () {
      if (!_isRunning) return;
      _clock.start();
      _ticker.animateTo(1.0,
          duration: const Duration(days: 365), curve: Curves.linear);
    };
  }

  void _unbindController(DealController controller) {
    controller._onStart = null;
    controller._onStop = null;
    controller._onPause = null;
    controller._onResume = null;
  }

  void _finishBatch() {
    _flights = const [];
    _clock.stop();
    _ticker.stop();
    _doneCompleter?.complete();
    _doneCompleter = null;
  }

  @override
  void dispose() {
    _finishBatch();
    _unbindController(widget.controller);
    _ticker.dispose();
    super.dispose();
  }

  // Smooth ease for time; keeps the throw snappy but soft.
  double _ease(double x) => 0.5 - 0.5 * math.cos(x * math.pi);

  // Distance-aware quadratic Bezier with perpendicular “lift”.
  Offset _arc(Offset a, Offset b, double t) {
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final d = b - a;
    final len = d.distance;
    if (len == 0) return a;

    // unit left normal
    final n = Offset(-d.dy / len, d.dx / len);
    final bulge = (0.08 + (len / 800.0) * 0.10).clamp(0.08, 0.18);
    final lift = len * bulge;

    final p0 = a;
    final p1 = mid + n * lift;
    final p2 = b;

    final u = 1 - t;
    return (p0 * (u * u)) + (p1 * (2 * u * t)) + (p2 * (t * t));
  }

  @override
  Widget build(BuildContext context) {
    if (_flights.isEmpty) {
      if (_isRunning) _finishBatch();
      return const SizedBox.shrink();
    }

    final elapsedMs = _clock.elapsedMilliseconds / _speed;
    bool allDone = true;

    return IgnorePointer(
      ignoring: true,
      child: RepaintBoundary(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final f in _flights)
              Builder(builder: (_) {
                final start = f.startDelay.inMilliseconds.toDouble();
                final end =
                    (f.startDelay + f.duration).inMilliseconds.toDouble();
                double p;
                if (elapsedMs <= start) {
                  p = 0.0;
                } else if (elapsedMs >= end) {
                  p = 1.0;
                } else {
                  p = ((elapsedMs - start) / (end - start)).clamp(0.0, 1.0);
                  allDone = false;
                }
                return _FlightCard(
                  feltSize: widget.feltSize,
                  cardW: widget.cardW,
                  cardH: widget.cardH,
                  elevation: widget.elevation,
                  backAsset: _backAsset ?? widget.defaultBackAsset,
                  from: f.from,
                  to: f.to,
                  angle: f.settleAngleRad,
                  progress: p,
                  posFn: (t) => _arc(f.from, f.to, _ease(t)),
                  cornerRadius: widget.cornerRadius,
                  faceUp: f.faceUp,
                  faceBuilder: widget.faceBuilder,
                  flight: f,
                );
              }),
            if (allDone)
              FutureBuilder<void>(
                future: Future<void>.microtask(() {
                  if (mounted) _finishBatch();
                }),
                builder: (_, __) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlightCard extends StatelessWidget {
  final Size feltSize;
  final double cardW, cardH;
  final double elevation;
  final String backAsset;
  final Offset from, to;
  final double angle;
  final double progress; // 0..1
  final Offset Function(double t) posFn;
  final double cornerRadius;

  final bool faceUp;
  final Widget Function(BuildContext, DealFlight, double, double, double)?
      faceBuilder;
  final DealFlight flight;

  const _FlightCard({
    required this.feltSize,
    required this.cardW,
    required this.cardH,
    required this.elevation,
    required this.backAsset,
    required this.from,
    required this.to,
    required this.angle,
    required this.progress,
    required this.posFn,
    required this.cornerRadius,
    required this.faceUp,
    required this.faceBuilder,
    required this.flight,
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();

    final t = Curves.easeOutCubic.transform(progress);
    final pos = posFn(t);

    // Subtle settle (scale + rotation) in last 10%
    final settleK = progress > 0.9 ? (progress - 0.9) / 0.1 : 0.0;
    final rot = _lerp(0, angle, t) + (0.02 * settleK); // ~1.1°
    final scale = _lerp(0.86, 1.0, t) + (0.015 * settleK); // +1.5%

    // Shadow peaks mid-flight.
    final peak = (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0);
    final blur = 6 + elevation * peak;

    final left = (pos.dx - cardW / 2)
        .clamp(0.0, math.max(0.0, feltSize.width - cardW))
        .toDouble();
    final top = (pos.dy - cardH / 2)
        .clamp(0.0, math.max(0.0, feltSize.height - cardH))
        .toDouble();

    final Widget cardChild;
    if (faceUp && faceBuilder != null) {
      cardChild = faceBuilder!(context, flight, cardW, cardH, cornerRadius);
    } else {
      cardChild = ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: Image.asset(
          backAsset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    return Positioned(
      left: left,
      top: top,
      child: Transform.rotate(
        angle: rot,
        alignment: Alignment.center,
        child: Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: blur,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 2),
                ),
              ],
              borderRadius: BorderRadius.circular(cornerRadius),
            ),
            child: SizedBox(width: cardW, height: cardH, child: cardChild),
          ),
        ),
      ),
    );
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}
