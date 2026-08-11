import 'dart:async';
import 'package:flutter/material.dart';

import 'slash_avatar.dart' show DealerAvatarStyle, SlashAvatar, SlashJacketTone;

enum DealerAct { idle, shuffle }

class RenoirDealer extends StatefulWidget {
  /// Current act.
  final DealerAct act;

  /// Height of the rendered dealer (keeps aspect pleasant on all screens).
  final double height;

  /// If true, shuffle loops forever; if false, it plays [loops] times then returns to idle.
  final bool loopShuffle;

  /// How many loops to play when [loopShuffle] is false.
  final int loops;

  /// Frame duration for the shuffle (lower = faster).
  final Duration frameDuration;

  /// Called when a non-looping shuffle finishes and the widget auto-reverts to idle.
  final VoidCallback? onShuffleFinished;

  /// Controls the visual style of the dealer sprite.
  final DealerAvatarStyle avatarStyle;
  final SlashJacketTone jacketTone;

  const RenoirDealer({
    super.key,
    required this.act,
    this.height = 200,
    this.loopShuffle = false,
    this.loops = 2,
    this.frameDuration = const Duration(milliseconds: 55),
    this.onShuffleFinished,
    this.avatarStyle = DealerAvatarStyle.classic,
    this.jacketTone = SlashJacketTone.black,
  });

  @override
  State<RenoirDealer> createState() => _RenoirDealerState();
}

class _RenoirDealerState extends State<RenoirDealer> {
  static const _idlePath = 'assets/images/renoir_tux.png';
  static const _shufflePaths = <String>[
    'assets/images/renoir_tux.png',
  ];

  static const List<double> _slashTimeline = <double>[
    0.00,
    0.08,
    0.16,
    0.24,
    0.32,
    0.40,
    0.48,
    0.56,
    0.64,
    0.72,
    0.80,
    0.88,
    0.96,
  ];

  Image? _idle;
  List<Image>? _shuffleFrames;

  int _frameIndex = 0;
  Timer? _timer;
  int _completedLoops = 0;
  DealerAct _currentAct = DealerAct.idle;

  @override
  void initState() {
    super.initState();
    if (!_usesCustomAvatar) {
      _idle = Image.asset(_idlePath,
          filterQuality: FilterQuality.high, isAntiAlias: true);
      _shuffleFrames = _shufflePaths
          .map((p) => Image.asset(p,
              filterQuality: FilterQuality.high, isAntiAlias: true))
          .toList();
    }
    _currentAct = widget.act;
  }

  @override
  void didChangeDependencies() {
    // Precache for stutter-free swaps.
    if (!_usesCustomAvatar) {
      final idle = _idle;
      final frames = _shuffleFrames;
      if (idle != null) precacheImage(idle.image, context);
      if (frames != null) {
        for (final f in frames) {
          precacheImage(f.image, context);
        }
      }
    }
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant RenoirDealer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.avatarStyle != oldWidget.avatarStyle) {
      _stopTimer();
      _frameIndex = 0;
      _completedLoops = 0;
      if (!_usesCustomAvatar) {
        _idle ??= Image.asset(_idlePath,
            filterQuality: FilterQuality.high, isAntiAlias: true);
        _shuffleFrames ??= _shufflePaths
            .map((p) => Image.asset(p,
                filterQuality: FilterQuality.high, isAntiAlias: true))
            .toList();
      } else {
        _idle = null;
        _shuffleFrames = null;
      }
      _switchAct(widget.act, restart: false);
      if (widget.act == DealerAct.shuffle) {
        _startShuffleTimer();
      }
    } else if (widget.act != _currentAct) {
      _switchAct(widget.act);
    } else if (widget.frameDuration != oldWidget.frameDuration ||
        widget.loopShuffle != oldWidget.loopShuffle ||
        widget.loops != oldWidget.loops) {
      // Rebuild timer if shuffle params changed while shuffling
      if (_currentAct == DealerAct.shuffle) {
        _startShuffleTimer();
      }
    }
  }

  void _switchAct(DealerAct next, {bool restart = true}) {
    _stopTimer();
    setState(() {
      _currentAct = next;
      _frameIndex = 0;
      _completedLoops = 0;
    });
    if (restart && next == DealerAct.shuffle) {
      _startShuffleTimer();
    }
  }

  bool get _usesSlash => widget.avatarStyle == DealerAvatarStyle.slash;
  bool get _usesCustomAvatar => _usesSlash;

  int get _frameCount {
    if (_usesCustomAvatar) return _slashTimeline.length;
    final frames = _shuffleFrames;
    return frames == null || frames.isEmpty ? 0 : frames.length;
  }

  double get _slashPose {
    if (_frameCount == 0) return 0;
    return _slashTimeline[_frameIndex % _slashTimeline.length];
  }

  void _startShuffleTimer() {
    _stopTimer();
    if (_frameCount == 0) return;
    Duration tick = widget.frameDuration;
    if (_usesCustomAvatar) {
      int micro = widget.frameDuration.inMicroseconds ~/ 3;
      if (micro <= 0) micro = 1;
      tick = Duration(microseconds: micro);
    }
    _timer = Timer.periodic(tick, (t) {
      setState(() {
        final int frames = _frameCount;
        if (frames == 0) return;
        _frameIndex = (_frameIndex + 1) % frames;
        if (_frameIndex == 0) {
          _completedLoops++;
          if (!widget.loopShuffle && _completedLoops >= widget.loops) {
            // End shuffle → idle
            _stopTimer();
            _currentAct = DealerAct.idle;
            widget.onShuffleFinished?.call();
          }
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    late final Widget child;
    switch (_currentAct) {
      case DealerAct.idle:
        if (_usesSlash) {
          child = SlashAvatar(
            height: widget.height,
            pose: 0,
            jacketTone: widget.jacketTone,
          );
        } else {
          child = _idle ?? const SizedBox.shrink();
        }
        break;
      case DealerAct.shuffle:
        if (_usesCustomAvatar) {
          child = SlashAvatar(
            height: widget.height,
            pose: _slashPose,
            jacketTone: widget.jacketTone,
          );
        } else {
          final frames = _shuffleFrames;
          child = (frames != null && frames.isNotEmpty)
              ? frames[_frameIndex % frames.length]
              : const SizedBox.shrink();
        }
        break;
    }

    // Keeps transparent PNG edges crisp and scales nicely on small screens.
    return SizedBox(
      height: widget.height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: child,
      ),
    );
  }
}
