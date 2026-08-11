// ===============================
// lib/ui/screens/game_screen/renoir_ui.dart
// ===============================

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/ui/utils/author_flash_gate.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/slash_avatar.dart'
    show DealerAvatarStyle, SlashJacketTone;

import 'overlays.dart' as go;
import 'overlays.dart' show WinnersBus;
import 'models.dart' show GCard;
import 'players.dart' show Seat;
import 'cards.dart' as cardui show PlayingCard, CardBack;
import 'cards.dart' show CardVisibilityGate, ActionGate;
import '../../../game/events.dart' show CardDealt, EngineEvent;
import 'pacing.dart' as pace;
import 'seat_card_layout.dart'
    show
        SeatCardFanLayout,
        centeredFanCardCenters,
        fitHeroCardRow,
        fitSeatCardFanBehindAvatar,
        kHeroHoleCardScale,
        kBotHoleCardScale;
import 'table.dart'
    show
        PlayerSafeFeltClipper,
        WoodPalette,
        WoodType,
        WoodTypeX,
        playerSafeFeltRRect;

/// Public signals for table/players UI to react to Renoir flow.
/// Listen to these to know when hole cards are visible and when acting is allowed.
class RenoirSignals {
  /// True once hole cards are revealed on the table; false during shuffle/deal/overlay.
  static final ValueNotifier<bool> holeCardsVisible =
      ValueNotifier<bool>(false);

  /// True when players are allowed to act (set shortly after hole cards reveal).
  static final ValueNotifier<bool> canAct = ValueNotifier<bool>(false);

  /// True while Renoir is actively dealing (any card flight in progress).
  static final ValueNotifier<bool> dealingActive = ValueNotifier<bool>(false);
}

class _PresentationTimer {
  _PresentationTimer(
    Duration duration,
    this._callback, {
    bool startPaused = false,
  }) : _remaining = duration {
    if (!startPaused) _schedule();
  }

  final VoidCallback _callback;
  Duration _remaining;
  Timer? _timer;
  DateTime? _deadline;
  bool _cancelled = false;

  void _schedule() {
    if (_cancelled || _timer != null) return;
    _deadline = DateTime.now().add(_remaining);
    _timer = Timer(_remaining, () {
      _timer = null;
      _deadline = null;
      if (_cancelled) return;
      _cancelled = true;
      _callback();
    });
  }

  void pause() {
    final Timer? timer = _timer;
    final DateTime? deadline = _deadline;
    if (timer == null || deadline == null) return;
    final Duration left = deadline.difference(DateTime.now());
    _remaining = left.isNegative ? Duration.zero : left;
    timer.cancel();
    _timer = null;
    _deadline = null;
  }

  void resume() => _schedule();

  void cancel() {
    _cancelled = true;
    _timer?.cancel();
    _timer = null;
    _deadline = null;
  }
}

// Global constant: number of shuffle loops (controls total shuffle duration)
const int kRenoirShuffleLoops = 5; // was 6; shorter overall duration

// Best-hand outline colors used during the winners overlay.
const Color _kHeroWinOutline = Color(0xFF24B6FF); // blue
const Color _kBotWinOutline = Color(0xFFFF2800); // red
const Color _kHandHighlightOutline = Color(0xFFFFD100); // yellow

String _normRank(String raw) {
  final u = raw.trim().toUpperCase();
  switch (u) {
    case 'ACE':
      return 'A';
    case 'KING':
      return 'K';
    case 'QUEEN':
      return 'Q';
    case 'JACK':
      return 'J';
    case 'T':
      return '10';
    default:
      return u;
  }
}

String _normSuit(String raw) {
  final s = raw.trim();
  final u = s.toUpperCase();
  if (s == '♠' || u == 'S' || u.startsWith('SPADE')) return 'S';
  if (s == '♥' || u == 'H' || u.startsWith('HEART')) return 'H';
  if (s == '♦' || u == 'D' || u.startsWith('DIAMOND')) return 'D';
  if (s == '♣' || u == 'C' || u.startsWith('CLUB')) return 'C';
  return u.isNotEmpty ? u[0] : '';
}

String _cardCode(String rank, String suit) =>
    '${_normRank(rank)}${_normSuit(suit)}';

/* ----------------------------- Public API -------------------------------- */

/// Draws the Renoir dealer, handles shuffle/deal flights, seat hole-cards,
/// and community row. Can be run in "cards-only" mode, in which the dealer
/// sprite/badge/dimmer are omitted here and mounted in [RenoirDealerOverlay].
class RenoirLayer extends StatefulWidget {
  // --- Visuals (dealer art) ---
  final String? renoirAsset; // idle PNG path
  final bool playIntroWelcome;
  final bool showDealerBadge;
  final double renoirRadius;
  final double renoirLiftPx;
  final DealerAvatarStyle avatarStyle;
  final double railWidth;
  final Color feltColor;
  final WoodType wood;

  // --- Geometry (felt space) ---
  final Offset origin; // deck origin in felt coords
  final List<Offset> seatTargets; // per-seat target centers (felt)
  final List<Offset> seatPanelPositions; // table-space seat rects
  final double seatPanelWidth;
  final double seatPanelHeight;
  final Offset boardTarget; // center Y for community lane (felt)

  // --- Card art / size ---
  final String cardBackAsset;
  final double cardW;
  final double cardH;

  // --- Table state / reveal rules ---
  final List<Seat> seats;
  final List<GCard> board;
  final int heroIndex;
  final bool showHandHighlight;
  final List<GCard> handHighlightCards;
  final Set<int> hiddenSeats; // seats that shouldn't show cards (e.g., empty)
  final bool showToggleVisible; // global “Show” toggle
  final bool heroShow; // whether hero shows when Show is on
  final bool paused;
  final bool reduceMotion;

  // --- Engine (optional) ---
  final Stream<EngineEvent>? engineEvents;

  // --- Welcome toast ---
  final bool showWelcomeOnInit;
  final String welcomeTitle;
  final String welcomeSubtitle;

  // --- Scripted laps callback (fallback dealing) ---
  final ValueChanged<int>? onScriptLap;

  /// If true, render **only the card UI** (flights + community + hole cards).
  /// Dealer sprite, badge and shuffle dimmer are **not** painted in this widget.
  final bool cardsOnly;

  /// Optional external key to the dealer if the sprite is hosted in an overlay
  /// outside this widget. If null, an internal key is used.
  final GlobalKey<go.RenoirDealerState>? dealerKey;

  /// Notifies when Renoir shuffle is requested (start of hand).
  final VoidCallback? onShuffle;

  /// Notifies when any dealing animation is active (true when a flight is in progress).
  final ValueChanged<bool>? onDealingActive;

  const RenoirLayer({
    super.key,
    required this.renoirAsset,
    this.playIntroWelcome = true,
    required this.showDealerBadge,
    required this.renoirRadius,
    required this.renoirLiftPx,
    this.avatarStyle = DealerAvatarStyle.classic,
    required this.railWidth,
    required this.feltColor,
    required this.wood,
    required this.origin,
    required this.seatTargets,
    this.seatPanelPositions = const <Offset>[],
    this.seatPanelWidth = 0,
    this.seatPanelHeight = 0,
    required this.boardTarget,
    required this.cardBackAsset,
    required this.cardW,
    required this.cardH,
    required this.seats,
    required this.board,
    required this.heroIndex,
    this.showHandHighlight = false,
    this.handHighlightCards = const <GCard>[],
    required this.hiddenSeats,
    required this.showToggleVisible,
    required this.heroShow,
    this.paused = false,
    this.reduceMotion = false,
    this.engineEvents,
    this.showWelcomeOnInit = true,
    this.welcomeTitle = 'Ladies and gentlemen, welcome to the table.',
    this.welcomeSubtitle = 'The game begins. Shuffle up and deal.',
    this.onScriptLap,
    this.cardsOnly = false,
    this.dealerKey,
    this.onShuffle,
    this.onDealingActive,
  });

  static const double kRenoirHandAnchor = 0.92;

  @override
  State<RenoirLayer> createState() => _RenoirLayerState();
}

/* --------------------------- Cards Layer (mid) --------------------------- */

class _RenoirLayerState extends State<RenoirLayer>
    with TickerProviderStateMixin {
  // Prepare up to 10 players for the welcome panel.
  List<go.PlayerBrief> _welcomePlayers() {
    final out = <go.PlayerBrief>[];
    for (final s in widget.seats) {
      try {
        final name = (s.name).toString();
        String kingdom = '';
        String about = '';
        int aura = 60;
        try {
          final k = (s as dynamic).kingdom;
          if (k is String && k.isNotEmpty) kingdom = k;
        } catch (_) {}
        try {
          final a = (s as dynamic).about;
          if (a is String && a.isNotEmpty) about = a;
        } catch (_) {}
        try {
          final au = (s as dynamic).aura;
          if (au is int) aura = au;
        } catch (_) {}
        out.add(go.PlayerBrief(
          name: name.isNotEmpty ? name : 'Player',
          kingdom: kingdom.isNotEmpty ? kingdom : '—',
          about: about.isNotEmpty ? about : '—',
          aura: aura,
        ));
      } catch (_) {}
      if (out.length >= 10) break;
    }
    return out;
  }

  // Dealer sprite handle (used if cardsOnly == false)
  final GlobalKey<go.RenoirDealerState> _internalDealerKey =
      GlobalKey<go.RenoirDealerState>();
  GlobalKey<go.RenoirDealerState> get _dealerKey =>
      widget.dealerKey ?? _internalDealerKey;

  // Deal controller (scripted flights)
  late final AnimationController _dealCtrl;
  late final AnimationController _handCtrl;
  late final Animation<double> _handCurve;
  List<_Flight> _script = const [];
  final Queue<_HandBeat> _handBeats = ListQueue<_HandBeat>();
  bool _handBeatActive = false;
  double _handBeatAmp = 0.0;

  // Table visibility policy
  bool _hideHoleCards = true; // hard hide until dealing actually starts
  bool _hideSeatHoleCards = false; // used to sweep holes right after winners
  bool _geomReady = false;
  bool _lockVisibility = false; // when true, ignore hides until winners overlay
  bool _shuffledThisHand = false; // ensure shuffle happens only once per hand
  bool _allowReveal =
      false; // becomes true only after shuffle fully ends + delay
  bool _shuffleCuesActive = false; // scripted flights during shuffle window
  bool _playedIntroSound =
      false; // play welcome clip only for the very first shuffle
  bool _dealerMotionActive = false; // keep dealer animated during deal flights

  // Progressive hole dealing: show 0 → 1 → 2 cards per seat as flights complete.
  List<int> _holeDealtCounts = const <int>[]; // per seat: 0..2
  bool _holeDealOrderNormalized = false;

  // Scripted fallback state
  int _dealtRounds = 0; // 0..2
  bool _firstLapQueued = false;

  // Engine-driven queue (dynamic events; no CardDealt dependency)
  StreamSubscription<EngineEvent>? _engineSub;
  final List<dynamic> _pendingEngineDeals = <dynamic>[];
  bool _engineDrainScheduled = false;

  // Winners overlay bus subscription and next-hand timer
  StreamSubscription? _winnersSub;
  _PresentationTimer? _nextHandTimer;
  bool _winnerOverlayVisible = false;
  Set<int> _winningSeats = const {};
  Map<int, Set<String>> _winningHoleCodes = const {};
  Set<String> _winningBoardCodes = const {};
  Color _winningOutlineColor = _kBotWinOutline;
  Map<int, bool> _winnerShowPref = const {};
  bool _nextHandPending = false;
  // Reveals are now tied to the actual end of Renoir's shuffle
  _PresentationTimer? _shuffleWatchTimer;
  _PresentationTimer? _revealTimer;
  _PresentationTimer? _welcomeStartTimer;
  _PresentationTimer? _shuffleFlightTimer;

  // Action gating: open actions only after the initial hole-card deal completes.
  bool _actionOpenScheduled = false;
  _PresentationTimer? _actionOpenTimer;
  _PresentationTimer? _actionSafeguardTimer;
  bool _presentationPaused = false;
  bool _resumeDealAnimation = false;
  bool _resumeHandAnimation = false;

  // Dealer wardrobe
  SlashJacketTone _jacketTone = SlashJacketTone.black;
  final math.Random _jacketRand = math.Random();

  SlashJacketTone get currentJacketTone => _jacketTone;

  @visibleForTesting
  double get debugDealProgress => _dealCtrl.value;

  @visibleForTesting
  bool get debugDealAnimating => _dealCtrl.isAnimating;

  @visibleForTesting
  AnimationStatus get debugDealStatus => _dealCtrl.status;

  @visibleForTesting
  int get debugActiveFlightCount => _script.length;

  @visibleForTesting
  int get debugBoardCardCount => _boardCardCount;

  @visibleForTesting
  int get debugPendingDealCount => _pendingEngineDeals.length;

  @visibleForTesting
  bool get debugRevealAllowed => _allowReveal;

  // Cached geometry
  late Offset _lastOrigin;
  late List<Offset> _lastSeatTargets;
  late Offset _lastBoardTarget;
  int _boardCardCount = 0; // number of community cards visibly on the table

  // Tunables (relaxed pace via pacing.dart)
  int get _kPerCardMs => widget.reduceMotion ? 1 : pace.kDealCardFlightMs;
  int get _kBetweenSeatMs => widget.reduceMotion ? 0 : pace.kDealGapMs;
  int get _shuffleFrameMsReduced => pace.kShuffleFrameMs;

  static const double _kHandSlidePx = 6.0;
  static const double _kHandDipPx = 3.0;
  static const double _kHandTiltRad = 0.02;
  static const bool _kLockRenoirChair = false;
  // Calibration: observed Renoir shuffle ends earlier than theoretical frames*loops
  // Use a bias to align reveal to the *actual* on-screen end. 0.50 ≈ 50% shorter.
  static const double _kShuffleTimingBias = 0.50; // tweak if art/loops change

  // Visual constants
  static const double _kOppSmallScale = kBotHoleCardScale;
  static const double _kOppShowScale = 1.00;
  static const double _kHeroScale = kHeroHoleCardScale;
  static const double _kFanOverlap = 0.50;
  static const double _kHeroFanDeg = 10.0;
  static const double _kOppFanDeg = 8.0;
  static const double _kHiddenFanDeg = 6.0;

  // Demo / test-flow timings
  static const int _kWelcomeExtraDelayMs = 1000; // 1s after welcome
  static const int _kPostShuffleShowDelayMs = 0; // start dealing immediately
  static const int _kSimulatedHandPlayMs = 6000; // time from reveal → winners
  static const int _kWinnersOverlayMs =
      3500; // simulated overlay duration (+1.5s)

  // Dev toggle: disable old simulated hand-cycle in production
  final bool _simulateFlow =
      false; // disable simulated hand-cycle in production

  @override
  void initState() {
    super.initState();
    _presentationPaused = widget.paused;
    _jacketTone = _randomJacketTone();
    CardVisibilityGate.hide(); // start with a blank table

    _dealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1),
    )..addStatusListener(_onDealStatus);

    _handCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _playNextHandBeat();
        }
      });
    _handCurve = CurvedAnimation(parent: _handCtrl, curve: Curves.easeInOut);
    _boardCardCount = widget.board.length;

    _attachEngine();

    // Listen to real hand-winner overlay lifecycle to control next-hand flow
    _winnersSub = WinnersBus.stream.listen((ev) {
      if (!mounted) return;
      if (ev.shown) {
        // Overlay is appearing — keep cards visible but freeze action.
        _winnerOverlayVisible = true;
        _nextHandPending = true; // gate next-hand shuffle until overlay closes
        _hideSeatHoleCards = false;
        _syncWinnersFromStore();
        RenoirSignals.canAct.value = false;
        ActionGate.disable();
        _cancelActionTimers();
        _actionOpenScheduled = false;
      } else {
        // Overlay fully closed → restart next hand after 1s (if pending)
        setState(() {
          _winnerOverlayVisible = false;
          _hideSeatHoleCards = true;
        });
        _queueNextHandAfterOverlay();
      }
    });

    // Welcome toast (only if not cardsOnly)
    if (!widget.cardsOnly &&
        widget.showWelcomeOnInit &&
        (widget.renoirAsset?.isNotEmpty ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await AuthorFlashGate.waitUntilHidden();
        if (!mounted) return;
        await go.showWelcomeRenoir(
          context,
          avatarAsset: widget.renoirAsset,
          heading: widget.welcomeTitle,
          players: _welcomePlayers(),
          duration: const Duration(seconds: 4),
        );
        if (!mounted) return;
        _welcomeStartTimer?.cancel();
        _welcomeStartTimer = _PresentationTimer(
          const Duration(milliseconds: _kWelcomeExtraDelayMs),
          () {
            if (!mounted) return;
            startNewHand();
          },
          startPaused: _presentationPaused,
        );
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _welcomeStartTimer?.cancel();
        _welcomeStartTimer = _PresentationTimer(
          const Duration(milliseconds: _kWelcomeExtraDelayMs),
          () {
            if (!mounted) return;
            startNewHand();
          },
          startPaused: _presentationPaused,
        );
      });
    }
  }

  void _onDealStatus(AnimationStatus s) {
    if (!mounted) return;

    final hadScript = _script.isNotEmpty;
    // Every scripted flight starts with `forward(from: 0)`. When a previous
    // flight left the controller completed, assigning zero can briefly report
    // `dismissed`; that is the *start* of the next flight, not its landing.
    final bool shouldClear = s == AnimationStatus.completed;

    if (shouldClear) {
      final completed = _script;
      final dealtSeats = <int>[];
      int boardDelta = 0;
      for (final f in completed) {
        final int? seat = f.seatIndex;
        if (f.countsAsHoleDeal && seat != null) {
          dealtSeats.add(seat);
        }
        if (f.countsAsBoardDeal) boardDelta += 1;
      }

      final int prevBoard = _boardCardCount;
      final int nextBoard = (prevBoard + boardDelta).clamp(0, 5);

      setState(() {
        _script = const [];
        if (dealtSeats.isNotEmpty) {
          _ensureHoleDealtCountsSize();
          for (final seat in dealtSeats) {
            if (seat < 0 || seat >= _holeDealtCounts.length) continue;
            _holeDealtCounts[seat] = (_holeDealtCounts[seat] + 1).clamp(0, 2);
          }
        }
        if (boardDelta > 0) {
          _boardCardCount = nextBoard;
        }
      });

      if (boardDelta > 0 && !widget.cardsOnly) {
        _triggerBoardHandNudge(
            previousCount: prevBoard, currentCount: nextBoard);
      }

      // Advance scripted laps (fallback only) — never for shuffle cue scripts
      if (widget.engineEvents == null && hadScript && !_shuffleCuesActive) {
        _dealtRounds = (_dealtRounds + 1).clamp(0, 2);
        _safeCallback(() => widget.onScriptLap?.call(_dealtRounds));
        if (_geomReady && _dealtRounds < 2) {
          Future.microtask(_dealNextRound);
        }
      }
      if (_shuffleCuesActive && hadScript) {
        _shuffleCuesActive = false; // cue finished; clear
      }

      // Engine: drain next if queued
      if (widget.engineEvents != null) _drainNextEngineCard();

      // If nothing else is active, notify inactive
      if (_pendingEngineDeals.isEmpty && _script.isEmpty) {
        _notifyDealing(false);
        if (_allowReveal) _ensureDealerMotionOff();
        _maybeOpenActionAfterDeal();
      }
    }
  }

  void _attachEngine() {
    _engineSub?.cancel();
    if (widget.engineEvents == null) return;
    _engineSub = widget.engineEvents!.listen((e) {
      if (e is! CardDealt) return;
      if (e.isBoard) {
        _cancelActionTimers();
        _actionOpenScheduled = false;
        RenoirSignals.canAct.value = false;
        ActionGate.disable();
      }
      _pendingEngineDeals.add(e);
      _scheduleEngineDrain();
    });
  }

  @override
  void didUpdateWidget(covariant RenoirLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) {
      _setPresentationPaused(widget.paused);
    }
    if (widget.reduceMotion && !oldWidget.reduceMotion) {
      _resetHandAnimation();
      _shuffleCuesActive = false;
    }
    if (oldWidget.engineEvents != widget.engineEvents) {
      _attachEngine();
    }
    if (widget.engineEvents == null) {
      if (widget.board.length != _boardCardCount) {
        _boardCardCount = widget.board.length;
      }
    } else {
      // When driven by engine events, let CardDealt drive `_boardCardCount`.
      // Only hard-sync on a reset-to-empty to avoid breaking flop batching.
      final bool idle = _pendingEngineDeals.isEmpty &&
          _script.isEmpty &&
          !_dealCtrl.isAnimating;

      if (widget.board.isEmpty && _boardCardCount != 0 && idle) {
        _boardCardCount = 0;
      } else if (widget.board.length > _boardCardCount && idle) {
        // Skip/fast-forward can update the full board without emitting CardDealt
        // events (and therefore without dealing flights). Keep the table's
        // community row in sync so the winners overlay has a visible board.
        _boardCardCount = widget.board.length;
      }
    }
    if (_winnerOverlayVisible) {
      _syncWinnersFromStore();
    }
  }

  Iterable<_PresentationTimer?> get _presentationTimers sync* {
    yield _nextHandTimer;
    yield _shuffleWatchTimer;
    yield _revealTimer;
    yield _welcomeStartTimer;
    yield _shuffleFlightTimer;
    yield _actionOpenTimer;
    yield _actionSafeguardTimer;
  }

  void _setPresentationPaused(bool paused) {
    if (_presentationPaused == paused) return;
    _presentationPaused = paused;
    if (paused) {
      for (final timer in _presentationTimers) {
        timer?.pause();
      }
      _resumeDealAnimation = _dealCtrl.isAnimating;
      _resumeHandAnimation = _handCtrl.isAnimating;
      if (_resumeDealAnimation) _dealCtrl.stop(canceled: false);
      if (_resumeHandAnimation) _handCtrl.stop(canceled: false);
      try {
        _dealerKey.currentState?.pause();
      } catch (_) {}
      return;
    }

    for (final timer in _presentationTimers) {
      timer?.resume();
    }
    try {
      _dealerKey.currentState?.resume();
    } catch (_) {}
    if (_resumeDealAnimation && _dealCtrl.value < 1) {
      _dealCtrl.forward();
    }
    if (_resumeHandAnimation && _handCtrl.value < 1) {
      _handCtrl.forward();
    }
    _resumeDealAnimation = false;
    _resumeHandAnimation = false;
    _scheduleEngineDrain();
    _maybeOpenActionAfterDeal();
  }

  @override
  void dispose() {
    _ensureDealerMotionOff();
    _engineSub?.cancel();
    _winnersSub?.cancel();
    _winnersSub = null;
    _nextHandTimer?.cancel();
    _nextHandTimer = null;
    _shuffleWatchTimer?.cancel();
    _shuffleWatchTimer = null;
    _revealTimer?.cancel();
    _revealTimer = null;
    _welcomeStartTimer?.cancel();
    _welcomeStartTimer = null;
    _shuffleFlightTimer?.cancel();
    _shuffleFlightTimer = null;
    _cancelActionTimers();
    _resetHandAnimation();
    _dealCtrl.dispose();
    _handCtrl.dispose();
    // Reset signals so listeners don’t hold stale true state if torn down mid-hand
    RenoirSignals.holeCardsVisible.value = false;
    RenoirSignals.canAct.value = false;
    RenoirSignals.dealingActive.value = false;
    super.dispose();
  }

  /* ------------------------ Public control hooks ------------------------- */

  /// Hide absolutely all cards (hole + community) immediately.
  /// If [force] is false and visibility is locked, this is ignored.
  void hideAllCardsNow({bool force = false}) {
    if (!force && _lockVisibility) {
      return; // ignore accidental hides during an active hand
    }
    _ensureDealerMotionOff();
    _resetHandAnimation();
    if (!_hideHoleCards) {
      setState(() => _hideHoleCards = true);
    } else {
      setState(() {}); // ensure repaint
    }
    CardVisibilityGate.hide();
    // Broadcast to observers: cards hidden → no acting
    RenoirSignals.holeCardsVisible.value = false;
    RenoirSignals.canAct.value = false;
    ActionGate.disable();
    _cancelActionTimers();
    _actionOpenScheduled = false;
    _revealTimer?.cancel();
    _revealTimer = null;
  }

  void _cancelActionTimers() {
    _actionOpenTimer?.cancel();
    _actionOpenTimer = null;
    _actionSafeguardTimer?.cancel();
    _actionSafeguardTimer = null;
  }

  void _ensureDealerMotionOn({bool restart = false}) {
    if (widget.reduceMotion) {
      _ensureDealerMotionOff();
      return;
    }
    if (!restart && _dealerMotionActive) return;
    _dealerMotionActive = true;
    try {
      _dealerKey.currentState?.shuffle();
    } catch (_) {}
  }

  void _ensureDealerMotionOff() {
    if (!_dealerMotionActive) return;
    _dealerMotionActive = false;
    try {
      _dealerKey.currentState?.idle();
    } catch (_) {}
  }

  /// Unhide cards for the initial deal, but keep actions locked.
  void showCardsForDealing() {
    // Hard-stop any remaining shuffle cues/loops once the deal begins.
    _shuffleCuesActive = false;
    _ensureDealerMotionOn();
    if (_dealCtrl.isAnimating) {
      _dealCtrl.stop();
    }
    setState(() {
      _script = const [];
      _hideHoleCards = false;
      _hideSeatHoleCards = false;
    });
    _lockVisibility = true;
    CardVisibilityGate.show();
    RenoirSignals.holeCardsVisible.value = true;
    RenoirSignals.canAct.value = false;
    ActionGate.disable();
    _cancelActionTimers();
    _actionOpenScheduled = false;
  }

  void _scheduleActionOpenAfterHumanPause() {
    if (_winnerOverlayVisible) return;
    if (!RenoirSignals.holeCardsVisible.value) return;
    if (RenoirSignals.canAct.value) return;

    _cancelActionTimers();

    // Human-like pause before players may act: 0.8s–2.0s after deal completes
    final int actDelayMs = 800 + math.Random().nextInt(1201); // 800..2000
    _actionOpenTimer = _PresentationTimer(
      Duration(milliseconds: actDelayMs),
      () {
        if (!mounted) return;
        if (_presentationPaused) return;
        if (_winnerOverlayVisible) return;
        if (!RenoirSignals.holeCardsVisible.value) return;
        ActionGate.enable();
        RenoirSignals.canAct.value = true;
      },
      startPaused: _presentationPaused,
    );

    // Web safeguard: if canAct never flips (e.g., web throttling), force-enable after grace.
    _actionSafeguardTimer = _PresentationTimer(
      const Duration(seconds: 3),
      () {
        if (!mounted) return;
        if (_presentationPaused) return;
        if (_winnerOverlayVisible) return;
        if (!RenoirSignals.holeCardsVisible.value) return;
        if (kIsWeb && !RenoirSignals.canAct.value) {
          ActionGate.enable();
          RenoirSignals.canAct.value = true;
        }
      },
      startPaused: _presentationPaused,
    );
  }

  void _maybeOpenActionAfterDeal() {
    if (_actionOpenScheduled) return;
    if (_winnerOverlayVisible) return;
    if (!RenoirSignals.holeCardsVisible.value) return;
    if (RenoirSignals.canAct.value) return;

    // If no hole cards were dealt (edge-case), do nothing.
    if (_holeDealtCounts.isEmpty || _holeDealtCounts.every((c) => c <= 0)) {
      return;
    }

    _actionOpenScheduled = true;
    _scheduleActionOpenAfterHumanPause();
  }

  /// Show cards again (unhide hole + community).
  /// This flips the global gate and clears the local hide flag.
  void showAllCardsNow() {
    // Hard-stop any remaining shuffle cues/loops once holes are visible.
    _shuffleCuesActive = false;
    _ensureDealerMotionOff();
    setState(() {
      _hideHoleCards = false;
      _hideSeatHoleCards = false;
    });
    _lockVisibility = true; // lock until intentionally unlocked before winners
    CardVisibilityGate.show();
    // Broadcast: hole cards are now visible
    RenoirSignals.holeCardsVisible.value = true;
    _actionOpenScheduled = true;
    _scheduleActionOpenAfterHumanPause();
  }

  /// Explicitly set whether cards should be hidden (dealer stays visible).
  void setCardsHidden(bool hide) {
    if (hide) {
      hideAllCardsNow(force: true);
    } else {
      showAllCardsNow();
    }
  }

  /// Hide hole cards immediately (used when winners dialog appears).
  void hideHoleCardsNow() => hideAllCardsNow(force: true);

  /// Call this when **winners are announced** and the dialog closes.
  /// It will keep holes hidden, trigger a shuffle, and start the next hand.
  void onWinnersAnnounced() {
    hideAllCardsNow(force: true);
    _script = const [];
    _dealtRounds = 0;
    _firstLapQueued = false;
    _nextHandPending = true;
    setState(() {});
    // If no overlay close event comes through (edge cases), ensure we still advance
    _queueNextHandAfterOverlay();
  }

  /// Start a fresh hand: hide cards, shuffle, and let _requestShuffle control reveal.
  void startNewHand() {
    _nextHandTimer?.cancel();
    _nextHandTimer = null;
    _shuffleWatchTimer?.cancel();
    _shuffleWatchTimer = null;
    _revealTimer?.cancel();
    _revealTimer = null;
    _nextHandPending = false;
    _lockVisibility = false;
    _allowReveal = false;
    _shuffledThisHand = false;
    _holeDealOrderNormalized = false;
    _hideSeatHoleCards = false;
    _winningSeats = const {};
    _winningHoleCodes = const {};
    _winningBoardCodes = const {};
    _winnerShowPref = const {};
    // Start with a blank table
    hideAllCardsNow(force: true);
    _boardCardCount = 0;
    _holeDealtCounts = List<int>.filled(widget.seats.length, 0);
    // Reset scripted state (not used in test flow, but keep tidy)
    _dealtRounds = 0;
    _firstLapQueued = false;
    // ALWAYS shuffle at the start of EVERY hand
    _requestShuffle();

    // IMPORTANT: Do not schedule any early reveal or scripted laps here.
    // The flow requires: mid-shuffle flight, then reveal as shuffle ends.
    // _requestShuffle() already schedules both the mid-shuffle flight and
    // the post-shuffle reveal (+ optional simulated hand cycle).
    return;
  }

  SlashJacketTone _randomJacketTone({SlashJacketTone? exclude}) {
    final List<SlashJacketTone> tones = SlashJacketTone.values;
    if (exclude != null && tones.length > 1) {
      final filtered = tones.where((t) => t != exclude).toList();
      return filtered[_jacketRand.nextInt(filtered.length)];
    }
    return tones[_jacketRand.nextInt(tones.length)];
  }

  void _notifyDealing(bool active) {
    if (RenoirSignals.dealingActive.value != active) {
      RenoirSignals.dealingActive.value = active;
    }
    _safeCallback(() => widget.onDealingActive?.call(active));
  }

  void _ensureHoleDealtCountsSize() {
    final int need = widget.seats.length;
    if (_holeDealtCounts.length != need) {
      _holeDealtCounts = List<int>.filled(need, 0);
    }
  }

  Offset _centerOfTargets(List<Offset> targets) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in targets) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return Offset.zero;
    }
    return Offset((minX + maxX) / 2, (minY + maxY) / 2);
  }

  List<int> _clockwiseSeatOrder(Iterable<int> seatIndices) {
    final indices = seatIndices.toList(growable: false);
    if (indices.isEmpty) return const <int>[];

    final targets = _lastSeatTargets;
    if (targets.isEmpty) {
      final copy = indices.toList()..sort();
      return copy;
    }

    final center = _centerOfTargets(targets);

    double angleFromTopClockwise(int seat) {
      if (seat < 0 || seat >= targets.length) return 0.0;
      final p = targets[seat];
      final dx = p.dx - center.dx;
      final dy = p.dy - center.dy;
      // Convert atan2 (0 on +x, CCW) → (0 at top, CW).
      var a = math.atan2(dy, dx) + (math.pi / 2);
      if (a < 0) a += 2 * math.pi;
      return a;
    }

    final copy = indices.toList()
      ..sort((a, b) => angleFromTopClockwise(a).compareTo(
            angleFromTopClockwise(b),
          ));
    return copy;
  }

  void _normalizeInitialHoleDealOrderIfNeeded() {
    if (_holeDealOrderNormalized) return;
    if (!_allowReveal) return;
    if (_pendingEngineDeals.isEmpty) return;

    _ensureHoleDealtCountsSize();
    if (_holeDealtCounts.isNotEmpty && !_holeDealtCounts.every((c) => c == 0)) {
      return; // already started dealing
    }

    // Only normalize if the pending queue begins with hole-card deals.
    final firstTgt = _adaptDealTarget(_pendingEngineDeals.first);
    if (firstTgt.isBoard || firstTgt.seat == null) return;

    final holeDeals = <dynamic>[];
    int i = 0;
    while (i < _pendingEngineDeals.length) {
      final tgt = _adaptDealTarget(_pendingEngineDeals[i]);
      if (tgt.isBoard || tgt.seat == null) break;
      holeDeals.add(_pendingEngineDeals[i]);
      i++;
    }
    if (holeDeals.isEmpty) return;

    // Remove the hole-deal prefix and reinsert it in a deterministic clockwise
    // order: one card per seat, then the second card per seat.
    _pendingEngineDeals.removeRange(0, holeDeals.length);

    final Map<int, List<dynamic>> bySeat = <int, List<dynamic>>{};
    for (final d in holeDeals) {
      final seat = _adaptDealTarget(d).seat;
      if (seat == null) continue;
      bySeat.putIfAbsent(seat, () => <dynamic>[]).add(d);
    }
    if (bySeat.isEmpty) return;

    final seatOrder = _clockwiseSeatOrder(bySeat.keys);
    final int maxPerSeat =
        bySeat.values.map((l) => l.length).fold<int>(0, math.max);

    final reordered = <dynamic>[];
    for (int r = 0; r < maxPerSeat; r++) {
      for (final seat in seatOrder) {
        final list = bySeat[seat];
        if (list == null) continue;
        if (r < list.length) reordered.add(list[r]);
      }
    }

    _pendingEngineDeals.insertAll(0, reordered);
    _holeDealOrderNormalized = true;
  }

  void _scheduleEngineDrain() {
    if (_presentationPaused) return;
    if (!_geomReady) return;
    if (widget.engineEvents == null) return;
    if (!_allowReveal) return; // wait until shuffle fully ends (+delay)
    if (_pendingEngineDeals.isEmpty) return;
    if (_script.isNotEmpty || _dealCtrl.isAnimating) return;
    if (_engineDrainScheduled) return;
    _engineDrainScheduled = true;
    Timer.run(() {
      _engineDrainScheduled = false;
      if (!mounted) return;
      if (_presentationPaused) return;
      if (widget.engineEvents == null) return;
      if (!_allowReveal) return;
      if (_pendingEngineDeals.isEmpty) return;
      if (_script.isNotEmpty || _dealCtrl.isAnimating) return;
      _drainNextEngineCard();
    });
  }

  void _scheduleRevealAfter(int ms) {
    _revealTimer?.cancel();
    _revealTimer = _PresentationTimer(
      Duration(milliseconds: ms),
      () {
        if (!mounted) return;
        if (_presentationPaused) return;
        _allowReveal = true;
        if (widget.engineEvents != null) {
          // Start the hole-card deal after shuffle ends.
          showCardsForDealing();
          _normalizeInitialHoleDealOrderIfNeeded();
          if (_pendingEngineDeals.isNotEmpty) {
            _scheduleEngineDrain();
          } else {
            _ensureDealerMotionOff();
            // Safety: if no deal events arrive, still open action.
            _actionOpenScheduled = true;
            _scheduleActionOpenAfterHumanPause();
          }
        } else {
          showAllCardsNow();
        }
      },
      startPaused: _presentationPaused,
    );
  }

  void _queueNextHandAfterOverlay() {
    if (_winnerOverlayVisible || !_nextHandPending) return;
    _nextHandTimer?.cancel();
    _nextHandTimer = _PresentationTimer(
      const Duration(seconds: 1),
      () {
        if (!mounted) return;
        if (_presentationPaused) return;
        _nextHandPending = false;
        startNewHand();
      },
      startPaused: _presentationPaused,
    );
  }

  int? _seatIndexForName(String winnerName) {
    final slug = Seat.slugForName(winnerName);
    for (int i = 0; i < widget.seats.length; i++) {
      if (Seat.slugForName(widget.seats[i].name) == slug) return i;
    }
    return null;
  }

  String _cardKey(String rank, String suit) => _cardCode(rank, suit);

  bool _winnerChoosesToShow(Seat seat, int seed) {
    if (seat.isHero) return true;
    if (!seat.allIn) return true; // standard wins are always shown
    final rnd = math.Random(seed);
    final double tendency = (seat.aura.clamp(0, 100)) / 100.0; // 0..1
    final double bias = 0.35 + tendency * 0.5; // 0.35..0.85
    return rnd.nextDouble() < bias;
  }

  void _syncWinnersFromStore() {
    if (!mounted) return;
    final snap = go.LastHandStore.last;
    if (snap == null || snap.winners.isEmpty) {
      setState(() {
        _winningSeats = const {};
        _winningHoleCodes = const {};
        _winningBoardCodes = const {};
        _winningOutlineColor = _kBotWinOutline;
        _winnerShowPref = const {};
      });
      return;
    }

    final Set<int> winners = {};
    final Map<int, Set<String>> holeCodes = {};
    final Set<String> winningBoard = {};
    final Map<int, bool> winnerShow = {};

    final List<GCard> boardNow = widget.board;
    final Set<String> boardCodes = {
      for (final c in boardNow) _cardKey(c.rank, c.suit),
    };

    for (final w in snap.winners) {
      final idx = _seatIndexForName(w.playerName);
      if (idx == null) continue;
      winners.add(idx);

      final best = go
          .winningHandHighlightCards(w.bestFive)
          .map((c) => _cardKey(c.rank, c.suit))
          .toSet();
      winningBoard.addAll(best.where(boardCodes.contains));

      final holeList = w.holeCards.isNotEmpty
          ? w.holeCards
          : [
              for (final c in widget.seats[idx].hole) go.UiCard(c.rank, c.suit),
            ];
      final Set<String> winningHoles = {};
      for (final c in holeList) {
        final code = _cardKey(c.rank, c.suit);
        if (best.contains(code)) winningHoles.add(code);
      }
      holeCodes[idx] = winningHoles;

      final seed = snap.at.millisecondsSinceEpoch ^
          Seat.slugForName(w.playerName).hashCode;
      winnerShow[idx] = _winnerChoosesToShow(widget.seats[idx], seed);
    }

    final bool heroWon = winners.contains(widget.heroIndex);
    final Color outline = heroWon ? _kHeroWinOutline : _kBotWinOutline;

    setState(() {
      _winningSeats = winners;
      _winningHoleCodes = holeCodes;
      _winningBoardCodes = winningBoard;
      _winningOutlineColor = outline;
      _winnerShowPref = winnerShow;
    });
  }

  // Make the shuffle call robust to mount timing (call now and next frame)
  void _requestShuffle() {
    if (_shuffledThisHand) return; // already shuffled this hand
    _shuffledThisHand = true;
    _lockVisibility = false;
    hideAllCardsNow(force: true);
    if (widget.playIntroWelcome && !_playedIntroSound) {
      _playedIntroSound = true;
      unawaited(SoundFx.instance.playWelcome());
    } else {
      unawaited(SoundFx.instance.playShuffle());
    }
    _ensureDealerMotionOn(restart: true);
    // Notify parent that shuffle has started (to sync visibility outside this layer)
    _safeCallback(() => widget.onShuffle?.call());

    final int totalMs = _shuffleTotalMs();

    // During shuffle: stagger light back-card flights to seats (visual cue only)
    _shuffleFlightTimer?.cancel();
    _shuffleFlightTimer = _PresentationTimer(
      Duration(milliseconds: (totalMs * 0.10).round()),
      () {
        if (!mounted) return;
        if (_presentationPaused || widget.reduceMotion) return;
        _scheduleShuffleFlights(totalMs);
      },
      startPaused: _presentationPaused,
    );

    // Prefer a native dealer callback if available; else fall back to watcher
    _shuffleWatchTimer?.cancel();
    bool hooked = false;
    try {
      final st = _dealerKey.currentState as dynamic;
      // Support either a setter or a method-based API without hard compile coupling
      final void Function()? cb =
          () => _scheduleRevealAfter(_kPostShuffleShowDelayMs);
      try {
        st.onShuffleEnd = cb;
        hooked = true;
      } catch (_) {}
      if (!hooked) {
        try {
          st.setOnShuffleEnd(cb);
          hooked = true;
        } catch (_) {}
      }
    } catch (_) {
      hooked = false;
    }

    if (!hooked) {
      // Fallback: we don't have a reliable "shuffle ended" callback from the
      // dealer widget (and we keep the animation looping while dealing), so we
      // start the first deal a bit *before* the theoretical end to avoid a
      // dead-feel gap between motion and card flights.
      final int dealStartMs = (totalMs * 0.60).round();

      _shuffleWatchTimer?.cancel();
      _shuffleWatchTimer = _PresentationTimer(
        Duration(milliseconds: dealStartMs),
        () {
          if (!mounted) return;
          if (_presentationPaused) return;
          _scheduleRevealAfter(_kPostShuffleShowDelayMs);
        },
        startPaused: _presentationPaused,
      );
    }
  }

  void _scheduleShuffleFlights(int totalMs) {
    if (_presentationPaused || widget.reduceMotion) return;
    if (!_geomReady || _lastSeatTargets.isEmpty) return;

    // Collect visible seats
    final visibleSeats = <int>[];
    for (int i = 0; i < _lastSeatTargets.length; i++) {
      if (!widget.hiddenSeats.contains(i)) visibleSeats.add(i);
    }
    if (visibleSeats.isEmpty) return;
    final orderedSeats = _clockwiseSeatOrder(visibleSeats);

    // Stagger cue flights between 20% and 80% of the shuffle window
    final int startWindow = (totalMs * 0.20).round();
    final int endWindow = (totalMs * 0.80).round();
    final int window = (endWindow - startWindow).clamp(300, totalMs);

    final flights = <_Flight>[];
    final int perGap =
        orderedSeats.length <= 1 ? 0 : (window ~/ (orderedSeats.length - 1));
    for (int idx = 0; idx < orderedSeats.length; idx++) {
      final int seat = orderedSeats[idx];
      final int startMs = startWindow + perGap * idx;
      flights.add(_Flight(
        from: _lastOrigin,
        to: _lastSeatTargets[seat],
        startMs: startMs,
        durMs: _kPerCardMs,
      ));
    }

    final totalScriptMs = flights.isEmpty
        ? 1
        : flights.map((f) => f.startMs + f.durMs).reduce(math.max);

    setState(() {
      _shuffleCuesActive = true;
      _script = flights;
      _dealCtrl.duration =
          Duration(milliseconds: totalScriptMs + pace.kDealControllerPadMs);
    });
    _notifyDealing(true);
    _dealCtrl.forward(from: 0);
  }

  int _shuffleTotalMs() {
    if (widget.reduceMotion) return 1;
    const int frames = 3; // renoir_shuffle1..3 (reduced from 4)
    final raw = frames * _shuffleFrameMsReduced * kRenoirShuffleLoops;
    return (raw * _kShuffleTimingBias).round();
  }

  void _queueHandBeat(
      {Duration duration = const Duration(milliseconds: 220),
      double amplitude = 1.0}) {
    if (widget.reduceMotion) return;
    _handBeats.add(
        _HandBeat(duration: duration, amplitude: amplitude.clamp(0.3, 1.5)));
    if (!_handBeatActive && !_handCtrl.isAnimating) {
      _playNextHandBeat();
    }
  }

  void _playNextHandBeat() {
    if (!mounted) return;
    if (_handBeats.isEmpty) {
      _handBeatActive = false;
      _handBeatAmp = 0.0;
      if (_handCtrl.isAnimating) {
        _handCtrl.stop();
      }
      if (_handCtrl.value != 0.0) {
        _handCtrl.value = 0.0;
      }
      setState(() {});
      return;
    }
    final beat = _handBeats.removeFirst();
    _handBeatActive = true;
    _handBeatAmp = beat.amplitude;
    if (_handCtrl.duration != beat.duration) {
      _handCtrl.duration = beat.duration;
    }
    setState(() {});
    _handCtrl.forward(from: 0);
  }

  void _resetHandAnimation() {
    _handBeats.clear();
    _handBeatActive = false;
    _handBeatAmp = 0.0;
    if (_handCtrl.isAnimating) {
      _handCtrl.stop();
    }
    if (_handCtrl.value != 0.0) {
      _handCtrl.value = 0.0;
    }
  }

  void _triggerBoardHandNudge({
    required int previousCount,
    required int currentCount,
  }) {
    if (currentCount < 3) return;

    int beats = 0;
    Duration duration = const Duration(milliseconds: 260);
    double amplitude = 0.9;

    if (currentCount >= 3 && previousCount < 3) {
      beats = 1;
      duration = const Duration(milliseconds: 360);
      amplitude = 1.05;
    } else if (currentCount == 4 && previousCount < 4) {
      beats = 1;
      duration = const Duration(milliseconds: 260);
      amplitude = 0.9;
    } else if (currentCount == 5 && previousCount < 5) {
      beats = 1;
      duration = const Duration(milliseconds: 240);
      amplitude = 0.85;
    } else {
      return;
    }

    for (int i = 0; i < beats; i++) {
      _queueHandBeat(duration: duration, amplitude: amplitude);
    }
  }

  /* -------------------------------- Build -------------------------------- */

  @override
  Widget build(BuildContext context) {
    // Cache geometry
    _lastOrigin = widget.origin;
    _lastSeatTargets = widget.seatTargets;
    _lastBoardTarget = widget.boardTarget;
    _geomReady = true;
    _ensureHoleDealtCountsSize();

    // Engine: start next queued card
    if (widget.engineEvents != null &&
        _geomReady &&
        _script.isEmpty &&
        !_dealCtrl.isAnimating &&
        _pendingEngineDeals.isNotEmpty &&
        _allowReveal) {
      _scheduleEngineDrain();
    }

    // Dealer sprite is moved to RenoirDealerOverlay when cardsOnly==true.
    final renoirSize =
        (widget.renoirRadius * 4.6).clamp(148.0, 270.0).toDouble();
    final renoirTranslateY = computeRenoirTranslateY(
      railW: widget.railWidth,
      size: renoirSize,
      lift: widget.renoirLiftPx,
      handAnchor: RenoirLayer.kRenoirHandAnchor,
    );
    final headroom = math.max(0.0, -renoirTranslateY + 8.0);
    final bool hasHandMotion = !widget.reduceMotion &&
        !_kLockRenoirChair &&
        (_handBeatActive || _handCtrl.isAnimating);
    final double handPhase = hasHandMotion ? _handCurve.value : 0.0;
    final double handPulse =
        hasHandMotion ? math.sin(handPhase * math.pi) : 0.0;
    final double handDx =
        _kLockRenoirChair ? 0.0 : _handBeatAmp * _kHandSlidePx * handPulse;
    final double handDy =
        _kLockRenoirChair ? 0.0 : _handBeatAmp * _kHandDipPx * handPulse;
    final double handTilt =
        _kLockRenoirChair ? 0.0 : _handBeatAmp * _kHandTiltRad * handPulse;
    final WoodPalette railPalette = widget.wood.palette;

    final bool usesCustomAvatar =
        widget.avatarStyle != DealerAvatarStyle.classic;
    final bool showDealerSprite = !widget.cardsOnly &&
        ((widget.renoirAsset?.isNotEmpty ?? false) || usesCustomAvatar);
    final bool showBadge = !widget.cardsOnly &&
        widget.showDealerBadge &&
        ((widget.renoirAsset?.isNotEmpty ?? false) || usesCustomAvatar);
    final bool handHighlightActive =
        widget.showHandHighlight && !_winnerOverlayVisible;
    final Set<String> handHighlightCodes = handHighlightActive
        ? {
            for (final c in widget.handHighlightCards)
              _cardCode(c.rank, c.suit),
          }
        : const {};
    final Set<String> boardHighlightCodes =
        _winnerOverlayVisible ? _winningBoardCodes : handHighlightCodes;
    final Color boardHighlightColor =
        _winnerOverlayVisible ? _winningOutlineColor : _kHandHighlightOutline;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // --- Community row (inside this layer) ---
        Positioned(
          top: widget.boardTarget.dy + widget.railWidth - widget.cardH / 2,
          left: widget.railWidth,
          right: widget.railWidth,
          child: ValueListenableBuilder<bool>(
            valueListenable: CardVisibilityGate.enabled,
            builder: (_, on, __) {
              if (!on || _hideHoleCards) return const SizedBox.shrink();
              final full = widget.board;
              final int vis = _boardCardCount.clamp(0, full.length);
              final boardCards = full.take(vis).toList(growable: false);
              final double communityW =
                  widget.cardW * _RenoirLayerState._kHeroScale * 0.935;
              final double communityH =
                  widget.cardH * _RenoirLayerState._kHeroScale * 0.935;
              return Center(
                child: communityRowFaceUp(
                  cards: boardCards,
                  cardW: communityW,
                  cardH: communityH,
                  spacing: 10,
                  highlightCodes: boardHighlightCodes,
                  highlightColor: boardHighlightColor,
                ),
              );
            },
          ),
        ),

        // --- Seat hole cards (beneath seat widgets) ---
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: _SeatHoleCardsLayer(
              railW: widget.railWidth,
              seats: widget.seats,
              seatTargets: widget.seatTargets,
              seatPanelPositions: widget.seatPanelPositions,
              seatPanelWidth: widget.seatPanelWidth,
              seatPanelHeight: widget.seatPanelHeight,
              heroIndex: widget.heroIndex,
              hiddenSeats: widget.hiddenSeats,
              showToggleVisible: widget.showToggleVisible && !_hideHoleCards,
              heroShow: widget.heroShow && !_hideHoleCards,
              baseCardW: widget.cardW,
              baseCardH: widget.cardH,
              backAsset: widget.cardBackAsset,
              hideAllHoleCards: _hideHoleCards || _hideSeatHoleCards,
              dealtHoleCounts: _holeDealtCounts,
              winnerOverlayVisible: _winnerOverlayVisible,
              winningSeats: _winningSeats,
              winningHoleCodes: _winningHoleCodes,
              winnerShowPref: _winnerShowPref,
              handHighlightActive: handHighlightActive,
              handHighlightSeat: widget.heroIndex,
              handHighlightCodes: handHighlightCodes,
              handHighlightColor: _kHandHighlightOutline,
            ),
          ),
        ),

        // --- Flights over felt ---
        // Draw above the static card layers so street dealing is always visible.
        if (_script.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _dealCtrl,
                  builder: (context, _) {
                    final durMs = _dealCtrl.duration?.inMilliseconds ?? 0;
                    if (durMs <= 0) return const SizedBox.shrink();
                    final ms = (_dealCtrl.value * durMs).round();
                    return _DealingLayer(
                      tMs: ms,
                      script: _script,
                      cardBackAsset: widget.cardBackAsset,
                      cardW: widget.cardW * 0.95,
                      cardH: widget.cardH * 0.95,
                      ease: _ease,
                      arc: _quad,
                    );
                  },
                ),
              ),
            ),
          ),

        // --- Dealer sprite + badge (only in full mode; otherwise use RenoirDealerOverlay) ---
        if (showDealerSprite)
          Positioned(
            top: -headroom,
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Align(
                alignment: Alignment.topCenter,
                child: Transform.translate(
                  offset: Offset(handDx, renoirTranslateY + headroom + handDy),
                  child: Transform.rotate(
                    angle: handTilt,
                    child: Transform.scale(
                      scaleY: 1.02,
                      child: go.RenoirDealer(
                        key: _dealerKey,
                        idleAsset: widget.renoirAsset ?? '',
                        shuffleAssets: (usesCustomAvatar ||
                                (widget.renoirAsset?.isEmpty ?? true))
                            ? const []
                            : deriveShuffleFrames(widget.renoirAsset!),
                        railWidth: widget.railWidth,
                        size: renoirSize,
                        frameDuration:
                            Duration(milliseconds: _shuffleFrameMsReduced),
                        loopShuffle: true,
                        loops: kRenoirShuffleLoops,
                        avatarStyle: widget.avatarStyle,
                        jacketTone: _jacketTone,
                        feltColor: widget.feltColor,
                        railLightColor: railPalette.light,
                        railMidColor: railPalette.mid,
                        railDarkColor: railPalette.dark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        if (showBadge)
          Positioned(
            top: (widget.railWidth - (widget.renoirRadius * 0.50)) -
                widget.renoirLiftPx,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Center(
                child: Transform.translate(
                  offset: Offset(handDx, handDy * 0.6),
                  child: go.DealerBadge(
                    radius: widget.renoirRadius,
                    asset: widget.renoirAsset,
                    handWon: false,
                    avatarStyle: widget.avatarStyle,
                    jacketTone: _jacketTone,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /* ----------------------- Engine-driven dealing ------------------------ */

  ({int? seat, bool isBoard}) _adaptDealTarget(dynamic d) {
    try {
      // Common fields we try to duck-type:
      //   seatIndex / playerIndex, and isBoard flag.
      final dyn = d as dynamic;
      final bool isBoard = (dyn.isBoard == true);
      final int? seatIndex = dyn.seatIndex is int
          ? dyn.seatIndex as int
          : (dyn.playerIndex as int?);
      if (isBoard || (seatIndex != null && seatIndex < 0)) {
        return (seat: null, isBoard: true);
      }
      if (seatIndex != null) return (seat: seatIndex, isBoard: false);
    } catch (_) {}
    // Fallback: treat as board
    return (seat: null, isBoard: true);
  }

  // NOTE: We never trigger shuffle here; community dealing occurs without shuffle.
  void _drainNextEngineCard() {
    if (_presentationPaused) return;
    if (!_geomReady || _pendingEngineDeals.isEmpty) return;
    if (!_allowReveal) return;

    _normalizeInitialHoleDealOrderIfNeeded();

    final nextDeal = _pendingEngineDeals.first;
    final tgt = _adaptDealTarget(nextDeal);

    Offset target;
    bool flipAtEnd = false;

    if (tgt.isBoard || tgt.seat == null) {
      // Special case: flop is revealed as 3 cards at once, so animate a 3-card fan.
      final int prevCount = _boardCardCount;
      final bool isFlopFan = prevCount == 0 && _pendingEngineDeals.length >= 3;

      if (isFlopFan) {
        int consecutiveBoard = 0;
        while (consecutiveBoard < 3 &&
            consecutiveBoard < _pendingEngineDeals.length) {
          final t = _adaptDealTarget(_pendingEngineDeals[consecutiveBoard]);
          if (!(t.isBoard || t.seat == null)) break;
          consecutiveBoard += 1;
        }

        if (consecutiveBoard >= 3) {
          _pendingEngineDeals.removeRange(0, 3);

          final int nextCount = (prevCount + 3).clamp(0, 5);

          if (_hideHoleCards && _allowReveal) {
            showCardsForDealing();
          }

          final Offset baseFrom = _lastOrigin;

          final double fanFromDx = widget.cardW * 0.18;
          final double fanFromDy = -widget.cardH * 0.04;
          final List<Offset> froms = <Offset>[
            baseFrom + Offset(-fanFromDx, fanFromDy),
            baseFrom,
            baseFrom + Offset(fanFromDx, fanFromDy),
          ];
          const List<double> fanAngles = <double>[-0.22, 0.0, 0.22];

          final flights = <_Flight>[
            for (int i = 0; i < 3; i++)
              _Flight(
                from: froms[i],
                to: _boardCardSlotCenter(
                  totalCards: nextCount,
                  index: prevCount + i,
                ),
                startMs: 0,
                durMs: _kPerCardMs,
                fanAngle: fanAngles[i],
                countsAsBoardDeal: true,
              ),
          ];

          final totalMs =
              flights.map((f) => f.startMs + f.durMs).reduce(math.max);
          setState(() {
            _script = flights;
            _dealCtrl.duration =
                Duration(milliseconds: totalMs + pace.kDealControllerPadMs);
          });

          _ensureDealerMotionOn();
          _notifyDealing(true);
          _dealCtrl.forward(from: 0);
          return;
        }
      }

      // Default: deal a single community card.
      _pendingEngineDeals.removeAt(0);
      final int nextCount = (prevCount + 1).clamp(0, 5);
      target =
          _boardCardSlotCenter(totalCards: nextCount, index: nextCount - 1);
    } else {
      _pendingEngineDeals.removeAt(0);
      final idx = tgt.seat!;
      if (idx < 0 || idx >= _lastSeatTargets.length) {
        // skip unknown seat; try next
        if (_pendingEngineDeals.isNotEmpty) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _drainNextEngineCard());
        } else {
          _notifyDealing(false);
        }
        return;
      }
      if (widget.hiddenSeats.contains(idx)) {
        if (_pendingEngineDeals.isNotEmpty) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _drainNextEngineCard());
        } else {
          _notifyDealing(false);
        }
        return;
      }
      target = _lastSeatTargets[idx];
      flipAtEnd = (idx == widget.heroIndex);
    }

    // Only allow reveal after shuffle has fully ended (+delay)
    if (_hideHoleCards && _allowReveal) {
      showCardsForDealing();
    }

    final bool countsAsHoleDeal = (!tgt.isBoard && tgt.seat != null);
    final flight = _Flight(
      from: _lastOrigin,
      to: target,
      startMs: 0,
      durMs: _kPerCardMs,
      flipAtEnd: flipAtEnd,
      seatIndex: tgt.seat,
      countsAsHoleDeal: countsAsHoleDeal,
      countsAsBoardDeal: tgt.isBoard || tgt.seat == null,
    );

    setState(() {
      _script = [flight];
      _dealCtrl.duration = Duration(
          milliseconds: pace.kDealCardFlightMs + pace.kDealControllerPadMs);
    });

    _ensureDealerMotionOn();
    _notifyDealing(true);
    _dealCtrl.forward(from: 0);
  }

  Offset _boardCardSlotCenter({required int totalCards, required int index}) {
    const double spacing = 10.0; // must match communityRowFaceUp spacing
    final int n = totalCards.clamp(1, 5);
    final int i = index.clamp(0, n - 1);
    final double step = widget.cardW + spacing;
    final double totalW = n * widget.cardW + (n - 1) * spacing;
    final double leftCenterX =
        _lastBoardTarget.dx - totalW / 2 + widget.cardW / 2;
    return Offset(leftCenterX + i * step, _lastBoardTarget.dy);
  }

  /* ----------------------- Scripted fallback laps ----------------------- */

  // NOTE: We never trigger shuffle here; community dealing occurs without shuffle.
  void _dealNextRound() {
    if (_presentationPaused) return;
    if (widget.engineEvents != null) return;
    if (!_geomReady || _dealtRounds >= 2) return;

    // Only allow reveal after shuffle has fully ended (+delay)
    if (_hideHoleCards && _allowReveal) {
      showCardsForDealing();
    }

    final flights = <_Flight>[];
    int t = 0;
    for (int i = 0; i < _lastSeatTargets.length; i++) {
      if (widget.hiddenSeats.contains(i)) continue;
      flights.add(_Flight(
        from: _lastOrigin,
        to: _lastSeatTargets[i],
        startMs: t,
        durMs: _kPerCardMs,
        flipAtEnd: (i == widget.heroIndex),
      ));
      t += _kBetweenSeatMs;
    }

    final totalMs = flights.isEmpty
        ? 1
        : flights.map((f) => f.startMs + f.durMs).reduce(math.max);

    setState(() {
      _script = flights;
      _dealCtrl.duration =
          Duration(milliseconds: totalMs + pace.kDealControllerPadMs);
    });

    _ensureDealerMotionOn();
    _notifyDealing(true);
    _dealCtrl.forward(from: 0);
  }

  /* ----------------------------- Utilities ------------------------------ */

  void _safeCallback(VoidCallback fn) {
    try {
      fn();
    } catch (_) {}
  }
}

/* ------------------------ Dealer Overlay (top) --------------------------- */

/// Paint this ABOVE the seats so Renoir is always visible.
/// This overlay draws ONLY the dealer sprite (+ optional badge and dimmer).
class RenoirDealerOverlay extends StatelessWidget {
  final String? renoirAsset;
  final bool showDealerBadge;
  final double renoirRadius;
  final double renoirLiftPx;
  final double railWidth;
  final DealerAvatarStyle avatarStyle;
  final SlashJacketTone jacketTone;
  final Color feltColor;
  final WoodType wood;

  /// If true, draw the shuffle dimmer on this top layer (dims seats too).
  final bool showShuffleDimmer;

  /// Optional external control: pass in the same key you pass to RenoirLayer.
  final GlobalKey<go.RenoirDealerState>? dealerKey;

  const RenoirDealerOverlay({
    super.key,
    required this.renoirAsset,
    required this.showDealerBadge,
    required this.renoirRadius,
    required this.renoirLiftPx,
    required this.railWidth,
    this.avatarStyle = DealerAvatarStyle.classic,
    this.jacketTone = SlashJacketTone.black,
    this.feltColor = const Color(0xFF13321E),
    this.wood = WoodType.redwood,
    this.showShuffleDimmer = false,
    this.dealerKey,
  });

  @override
  Widget build(BuildContext context) {
    final size = (renoirRadius * 4.6).clamp(148.0, 270.0).toDouble();
    final WoodPalette railPalette = wood.palette;
    final bool usesCustomAvatar = avatarStyle != DealerAvatarStyle.classic;
    final translateY = computeRenoirTranslateY(
      railW: railWidth,
      size: size,
      lift: renoirLiftPx,
      handAnchor: RenoirLayer.kRenoirHandAnchor,
    );
    final headroom = math.max(0.0, -translateY + 8.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showShuffleDimmer)
          const Positioned.fill(
            child: IgnorePointer(child: go.ShuffleOverlay(visible: true)),
          ),
        if ((renoirAsset != null && renoirAsset!.isNotEmpty) ||
            usesCustomAvatar)
          Positioned(
            top: -headroom,
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Align(
                alignment: Alignment.topCenter,
                child: Transform.translate(
                  offset: Offset(0, translateY + headroom),
                  child: Transform.scale(
                    scaleY: 1.02,
                    child: go.RenoirDealer(
                      key: dealerKey,
                      idleAsset: renoirAsset ?? '',
                      shuffleAssets:
                          (usesCustomAvatar || (renoirAsset?.isEmpty ?? true))
                              ? const []
                              : deriveShuffleFrames(renoirAsset!),
                      railWidth: railWidth,
                      size: size,
                      frameDuration:
                          Duration(milliseconds: pace.kShuffleFrameMs),
                      loopShuffle: true,
                      loops: kRenoirShuffleLoops,
                      avatarStyle: avatarStyle,
                      jacketTone: jacketTone,
                      feltColor: feltColor,
                      railLightColor: railPalette.light,
                      railMidColor: railPalette.mid,
                      railDarkColor: railPalette.dark,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (showDealerBadge &&
            ((renoirAsset?.isNotEmpty ?? false) || usesCustomAvatar))
          Positioned(
            top: (railWidth - (renoirRadius * 0.50)) - renoirLiftPx,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Center(
                child: go.DealerBadge(
                  radius: renoirRadius,
                  asset: renoirAsset,
                  handWon: false,
                  avatarStyle: avatarStyle,
                  jacketTone: jacketTone,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/* ------------------------------ Internals -------------------------------- */

class _SeatHoleCardsLayer extends StatelessWidget {
  final double railW;
  final List<Seat> seats;
  final List<Offset> seatTargets; // felt-space centers for card anchor
  final List<Offset> seatPanelPositions; // table-space seat rects
  final double seatPanelWidth;
  final double seatPanelHeight;
  final int heroIndex;
  final Set<int> hiddenSeats;
  final bool hideAllHoleCards;
  final List<int> dealtHoleCounts; // per seat: 0..2
  final bool showToggleVisible;
  final bool heroShow;
  final double baseCardW, baseCardH;
  final String backAsset;
  final bool winnerOverlayVisible;
  final Set<int> winningSeats;
  final Map<int, Set<String>> winningHoleCodes;
  final Map<int, bool> winnerShowPref;
  final bool handHighlightActive;
  final int handHighlightSeat;
  final Set<String> handHighlightCodes;
  final Color handHighlightColor;

  const _SeatHoleCardsLayer({
    required this.railW,
    required this.seats,
    required this.seatTargets,
    required this.seatPanelPositions,
    required this.seatPanelWidth,
    required this.seatPanelHeight,
    required this.heroIndex,
    required this.hiddenSeats,
    required this.showToggleVisible,
    required this.heroShow,
    required this.baseCardW,
    required this.baseCardH,
    required this.backAsset,
    required this.hideAllHoleCards,
    required this.dealtHoleCounts,
    required this.winnerOverlayVisible,
    required this.winningSeats,
    required this.winningHoleCodes,
    required this.winnerShowPref,
    required this.handHighlightActive,
    required this.handHighlightSeat,
    required this.handHighlightCodes,
    required this.handHighlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (hideAllHoleCards) return const SizedBox.shrink(); // draw nothing
    if (seats.isEmpty || seatTargets.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;

        final List<Widget> layers = <Widget>[];
        final List<Rect> placedFanBounds = <Rect>[];
        final List<Rect> seatRects = _seatPanelRects(
          positions: seatPanelPositions,
          seatWidth: seatPanelWidth,
          seatHeight: seatPanelHeight,
        );
        final Offset centerScreen = Offset(w / 2, h / 2);

        final RRect cardSafeBoundary = playerSafeFeltRRect(Size(w, h), railW);

        for (int i = 0; i < seats.length && i < seatTargets.length; i++) {
          if (hiddenSeats.contains(i)) continue;

          final seat = seats[i];
          final isHero = (i == heroIndex);
          final bool winnerMode = winnerOverlayVisible;
          final bool isWinner = winningSeats.contains(i);
          final bool winnerShows = winnerShowPref[i] ?? true;

          final int dealt =
              (i < dealtHoleCounts.length) ? dealtHoleCounts[i] : 0;
          final nToDraw = math.min(2, math.min(dealt, seat.hole.length));
          if (nToDraw == 0) continue;

          // Reveal rules
          final bool revealOpp = showToggleVisible;
          final bool revealHero =
              isHero ? (showToggleVisible ? heroShow : true) : false;
          final bool facesUp = winnerMode
              ? (isHero || (isWinner && winnerShows))
              : (isHero ? revealHero : revealOpp);
          // Face-up cards are rendered by the settled-card layer behind seats.
          if (facesUp) continue;

          // Sizes
          final double cardW = isHero
              ? baseCardW * _RenoirLayerState._kHeroScale
              : (facesUp
                  ? baseCardW * _RenoirLayerState._kOppShowScale
                  : baseCardW * _RenoirLayerState._kOppSmallScale);
          final double cardH = isHero
              ? baseCardH * _RenoirLayerState._kHeroScale
              : (facesUp
                  ? baseCardH * _RenoirLayerState._kOppShowScale
                  : baseCardH * _RenoirLayerState._kOppSmallScale);
          final bool heroSideBySide = isHero && nToDraw > 1;
          final double totalAngleDeg = heroSideBySide
              ? 0.0
              : (facesUp
                  ? (isHero
                      ? _RenoirLayerState._kHeroFanDeg
                      : (winnerMode && isWinner
                          ? _RenoirLayerState._kHeroFanDeg * 0.8
                          : _RenoirLayerState._kOppFanDeg))
                  : _RenoirLayerState._kHiddenFanDeg);
          final double totalAngle = totalAngleDeg * (math.pi / 180.0);
          final double stepFactor =
              heroSideBySide ? 1.05 : 1 - _RenoirLayerState._kFanOverlap;

          Offset anchor;
          double fittedCardW = cardW;
          double fittedCardH = cardH;
          SeatCardFanLayout? fanLayout;
          if (seatRects.length > i) {
            final List<Rect> otherSeatRects = [
              for (int j = 0; j < seatRects.length && j < seats.length; j++)
                if (j != i && !hiddenSeats.contains(j)) seatRects[j],
              ...placedFanBounds,
            ];
            fanLayout = isHero
                ? fitHeroCardRow(
                    seatRect: seatRects[i],
                    tableCenter: centerScreen,
                    safeBoundary: cardSafeBoundary,
                    tableMidpointY: h / 2,
                    cardCount: nToDraw,
                    cardW: cardW,
                    cardH: cardH,
                    stepFactor: stepFactor,
                  )
                : fitSeatCardFanBehindAvatar(
                    seatRect: seatRects[i],
                    obstacleRects: otherSeatRects,
                    tableCenter: centerScreen,
                    safeBoundary: cardSafeBoundary,
                    cardCount: nToDraw,
                    cardW: cardW,
                    cardH: cardH,
                    stepFactor: stepFactor,
                    totalFanAngleRadians: totalAngle,
                    minimumScale: 0.78,
                  );
            anchor = fanLayout.anchor;
            fittedCardW *= fanLayout.scale;
            fittedCardH *= fanLayout.scale;
            placedFanBounds.add(fanLayout.bounds);
          } else {
            anchor = seatTargets[i];
          }

          // Fan
          final double step = fanLayout?.step ?? fittedCardW * stepFactor;
          final double anglePer =
              (nToDraw > 1) ? (totalAngle / (nToDraw - 1)) : 0.0;
          final double startAngle = (nToDraw > 1) ? (-totalAngle / 2) : 0.0;
          final List<Offset> cardCenters = centeredFanCardCenters(
            anchor: anchor,
            cardCount: nToDraw,
            step: step,
          );

          for (int k = 0; k < nToDraw; k++) {
            final double cxRaw = cardCenters[k].dx;
            final double cyRaw = cardCenters[k].dy;

            final double cx = cxRaw;
            final double cy = cyRaw;
            final double ang = startAngle + k * anglePer;

            final String code =
                (k < seat.hole.length) ? _cardKeySeat(seat.hole[k]) : '';
            final bool handHighlight = handHighlightActive &&
                i == handHighlightSeat &&
                facesUp &&
                handHighlightCodes.contains(code);
            final bool highlight = handHighlight;
            final Color highlightColor = handHighlightColor;

            Widget card = (facesUp && k < seat.hole.length)
                ? cardui.PlayingCard(
                    rank: seat.hole[k].rank,
                    suit: seat.hole[k].suit,
                    w: fittedCardW,
                    h: fittedCardH,
                  )
                : cardui.CardBack(
                    w: fittedCardW,
                    h: fittedCardH,
                    asset: backAsset,
                  );

            if (highlight) {
              final double borderW = (fittedCardW * 0.06).clamp(1.5, 4.0) * 1.2;
              card = Stack(
                fit: StackFit.expand,
                children: [
                  card,
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(fittedCardW * 0.18),
                        border: Border.all(
                          color: highlightColor,
                          width: borderW,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: highlightColor.withValues(alpha: 0.6),
                            blurRadius: borderW * 2.2,
                            spreadRadius: borderW * 0.4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            layers.add(
              Positioned(
                left: cx - fittedCardW / 2,
                top: cy - fittedCardH / 2,
                width: fittedCardW,
                height: fittedCardH,
                child: Transform.rotate(
                  key: ValueKey<String>('seat-hole-back-$i-$k'),
                  angle: ang,
                  alignment: Alignment.center,
                  child: card,
                ),
              ),
            );
          }
        }

        return ClipPath(
          clipper: PlayerSafeFeltClipper(railWidth: railW),
          child: Stack(clipBehavior: Clip.none, children: layers),
        );
      },
    );
  }

  String _cardKeySeat(GCard c) => _cardCode(c.rank, c.suit);
}

/* -------------------------------- Flights -------------------------------- */

class _Flight {
  final Offset from, to;
  final int startMs, durMs;
  final bool flipAtEnd;
  final double fanAngle;
  final int? seatIndex;
  final bool countsAsHoleDeal;
  final bool countsAsBoardDeal;
  const _Flight({
    required this.from,
    required this.to,
    required this.startMs,
    required this.durMs,
    this.flipAtEnd = false,
    this.fanAngle = 0.0,
    this.seatIndex,
    this.countsAsHoleDeal = false,
    this.countsAsBoardDeal = false,
  });
}

class _HandBeat {
  final Duration duration;
  final double amplitude;
  const _HandBeat({required this.duration, required this.amplitude});
}

class _DealingLayer extends StatelessWidget {
  final int tMs;
  final List<_Flight> script;
  final String cardBackAsset;
  final double cardW, cardH;
  final double Function(double) ease;
  final Offset Function(Offset, Offset, double, {double rise}) arc;

  const _DealingLayer({
    required this.tMs,
    required this.script,
    required this.cardBackAsset,
    required this.cardW,
    required this.cardH,
    required this.ease,
    required this.arc,
  });

  @override
  Widget build(BuildContext context) {
    if (script.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: [
        for (final f in script)
          _FlightCard(
            nowMs: tMs,
            flight: f,
            cardBackAsset: cardBackAsset,
            w: cardW,
            h: cardH,
            ease: ease,
            arc: arc,
          ),
      ],
    );
  }
}

class _FlightCard extends StatelessWidget {
  final int nowMs;
  final _Flight flight;
  final String cardBackAsset;
  final double w, h;
  final double Function(double) ease;
  final Offset Function(Offset, Offset, double, {double rise}) arc;

  const _FlightCard({
    required this.nowMs,
    required this.flight,
    required this.cardBackAsset,
    required this.w,
    required this.h,
    required this.ease,
    required this.arc,
  });

  @override
  Widget build(BuildContext context) {
    final start = flight.startMs;
    final end = flight.startMs + flight.durMs;
    if (nowMs < start || nowMs > end + 120) return const SizedBox.shrink();

    final clamped = nowMs.clamp(start, end);
    final t = (clamped - start) / (end - start);
    final tt = ease(t);

    final p = arc(flight.from, flight.to, tt);
    final int dir = (flight.to.dx >= flight.from.dx) ? 1 : -1;
    final rot = (1 - tt) * ((0.10 * dir) + flight.fanAngle);
    final scale = 0.96 + 0.08 * tt;

    double flipScaleX = 1.0;
    double extraOpacity = 1.0;
    if (flight.flipAtEnd && nowMs > end) {
      final flipT = ((nowMs - end) / 100).clamp(0.0, 1.0);
      flipScaleX = (flipT < 0.5) ? (1 - flipT * 4) : (-1 + (flipT - 0.5) * 4);
      extraOpacity = 1.0 - (flipT * 0.6);
    }

    return Positioned(
      left: p.dx - w / 2,
      top: p.dy - h / 2,
      child: Opacity(
        opacity: 0.9 * extraOpacity,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(w / 2, h / 2)
            ..rotateZ(rot)
            ..scale(scale, scale)
            ..scale(flipScaleX, 1.0)
            ..translate(-w / 2, -h / 2),
          child: cardui.CardBack(w: w, h: h, asset: cardBackAsset),
        ),
      ),
    );
  }
}

/* ----------------------------- Utilities -------------------------------- */

double computeRenoirTranslateY({
  required double railW,
  required double size,
  required double lift,
  required double handAnchor,
}) {
  final target = railW - handAnchor * size - lift;
  // Keep Renoir slightly lower on compact/mobile layouts so his face remains visible.
  final minY = -(size * 0.52);
  final maxY = railW + size * 0.25;
  return target.clamp(minY, maxY).toDouble();
}

List<String> deriveShuffleFrames(String idleAsset) {
  final i = idleAsset.lastIndexOf('/');
  final base = i >= 0 ? idleAsset.substring(0, i + 1) : '';
  return const [1, 2, 3]
      .map((n) => '${base}renoir_shuffle$n.png')
      .toList(growable: false);
}

Widget communityRowFaceUp({
  required List<GCard> cards,
  required double cardW,
  required double cardH,
  double spacing = 8.0,
  Set<String> highlightCodes = const {},
  Color highlightColor = _kBotWinOutline,
}) {
  if (cards.isEmpty) return const SizedBox.shrink();
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (final c in cards)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: _HighlightedCard(
            child: cardui.PlayingCard(
              rank: c.rank,
              suit: c.suit,
              w: cardW,
              h: cardH,
            ),
            highlight: highlightCodes.contains(_cardCode(c.rank, c.suit)),
            highlightColor: highlightColor,
          ),
        ),
    ],
  );
}

class _HighlightedCard extends StatelessWidget {
  final Widget child;
  final bool highlight;
  final Color highlightColor;
  const _HighlightedCard({
    required this.child,
    required this.highlight,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!highlight) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: highlightColor,
                  width: 3.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: highlightColor.withValues(alpha: 0.7),
                    blurRadius: 10,
                    spreadRadius: 1.2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Offset _quad(Offset a, Offset b, double t, {double rise = 56.0}) {
  final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 - rise);
  final x = (1 - t) * (1 - t) * a.dx + 2 * (1 - t) * t * mid.dx + t * t * b.dx;
  final y = (1 - t) * (1 - t) * a.dy + 2 * (1 - t) * t * mid.dy + t * t * b.dy;
  return Offset(x, y);
}

double _ease(double x) => 0.5 - 0.5 * math.cos(x * math.pi);

List<Rect> _seatPanelRects({
  required List<Offset> positions,
  required double seatWidth,
  required double seatHeight,
}) {
  if (positions.isEmpty || seatWidth <= 0 || seatHeight <= 0) {
    return const <Rect>[];
  }
  return [
    for (final p in positions) Rect.fromLTWH(p.dx, p.dy, seatWidth, seatHeight),
  ];
}
