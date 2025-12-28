// ===============================
// lib/ui/screens/game_screen/ui.dart
// ===============================

import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui show TextDirection;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'clock.dart' show DayDateClock;
import 'models.dart' show GCard;
import 'table.dart' show WoodType; // wood visuals
import 'action_bar.dart';
import 'action_burst.dart';
import 'players.dart'
    show
        Seat,
        SeatWidget,
        kSeatDiameterPx,
        seatFallbackAsset,
        seatPositionsWithGapAndPush;
import 'overlays.dart' as go; // contains Winner dialog + Renoir voice
import 'scoreboard_button.dart' as scoreboard_sheet;
import 'pacing.dart' as pace;
import 'package:ten_of_a_kind_poker/ui/widgets/slash_avatar.dart'
    show DealerAvatarStyle;
import 'blood_splatter.dart' show SeatBloodStain;

// Layers
import 'table_ui.dart'
    show BlindChipPlacement, GameTableLayer, TableGeometry, buildBlindChips;
import 'renoir_ui.dart' show RenoirLayer, RenoirSignals;
import 'cards.dart' show ActionGate, PlayingCard, CardVisibilityGate;
import 'package:playing_cards/playing_cards.dart' as pc;
import '../../../game/events.dart' show EngineEvent;

/* ------------------------------ Tunables --------------------------------- */

const double _kSeatMinW = kSeatDiameterPx * 0.8;
const double _kSeatMinH = kSeatDiameterPx * 0.8;
const double _kSeatVisualMarginPx = 1.0;
const BlindChipPlacement _kBlindChipPlacement = BlindChipPlacement.felt;
const double _kPushDownFrac = 0.10;
const double _kInfoPillHeight = 96.0;

/// Snapshot of a seat's most recent action for UI display.
class SeatActionSnapshot {
  final int seatIndex;
  final String label;
  final int chips;
  const SeatActionSnapshot({
    required this.seatIndex,
    required this.label,
    required this.chips,
  });
}

/* ------------------------------- Metrics --------------------------------- */
class _Ui {
  final double tableW, tableH;
  final double seatMaxW, seatH;
  final double cardW, cardH;
  final double renoirR;
  final EdgeInsets tableTopPadding;

  _Ui(double w, double h)
      : // Stretch across the screen while keeping a thin horizontal margin
        tableW = (() {
          final double adaptiveMargin =
              (w * (w < 900 ? 0.03 : 0.02)).clamp(16.0, 48.0);
          final double raw = w - adaptiveMargin * 2;
          final double minWidth = math.min(320.0, w);
          final double maxWidth = math.min(1820.0, w);
          return raw.clamp(minWidth, maxWidth).toDouble();
        })(),
        tableH = (h * (h < 720 ? 0.62 : 0.64)).clamp(280.0, 880.0).toDouble(),
        cardW = (w / 1280 * 66).clamp(52.0, 88.0).toDouble(),
        cardH = (w / 1280 * 92).clamp(76.0, 128.0).toDouble(),
        seatMaxW = kSeatDiameterPx * 0.8,
        seatH = kSeatDiameterPx * 0.8,
        renoirR = (w / 1280 * 40).clamp(30.0, 52.0).toDouble(),
        tableTopPadding = const EdgeInsets.only(top: 14);
}

/* ----------------------------- GameScreenUI ------------------------------- */
class GameScreenUI extends StatefulWidget {
  final Color bg;
  final String venueName;
  final String flagPath;
  final String? monumentPath;
  final String? renoirAsset;
  final String defaultProfileAsset;
  final String cardBackAsset;
  final VoidCallback onShowHandRankings;
  final int startingStack;

  final Color felt;
  final WoodType wood;
  final bool showDealerBadge;

  final DealerAvatarStyle dealerAvatarStyle;
  final double pot;
  final List<GCard> board;
  final List<Seat> seats;
  final Set<int> activeBloodStains;
  final int currentTurn, sbIndex, bbIndex, heroIndex;
  final List<SeatActionSnapshot> recentActions;
  final bool isHeroTurn;
  final int toCall;

  // Cards / animation control (compat flags; RenoirLayer owns shuffle policy)
  final bool showShuffle; // kept for call-site compatibility
  final bool showDeckPile; // reserved
  final bool showToggleVisible;
  final bool heroShow;

  final Animation<double> potPulse;
  final double? deckHeightPx; // compat (unused)
  final Offset? deckOffset; // compat (unused)
  final double deckScale; // compat (unused)
  final bool playIntroWelcome;

  // Betting controls
  final double raiseAmount, minRaise, maxRaise;
  final ValueChanged<double> onRaiseAmountChanged;

  // Scripted laps (when no engine)
  final ValueChanged<int>? onScriptLap;

  final VoidCallback onCheckOrCall, onFold, onBetOrRaise, onAllIn, onToggleShow;

  // Renoir sprite alignment
  final double renoirLiftPx;

  // Chrome
  final int venueOffsetMinutes;

  // Engine (optional)
  final Stream<EngineEvent>? engineEvents;
  final dynamic /*GameEngine?*/ engine;
  final bool? canSkipToWinner;
  final bool? canShowdown;
  final VoidCallback? onSkipToWinner;
  final VoidCallback? onShowdown;
  final VoidCallback? onRenoirShuffle;

  const GameScreenUI({
    super.key,
    required this.bg,
    required this.venueName,
    required this.flagPath,
    required this.onShowHandRankings,
    required this.felt,
    required this.wood,
    required this.monumentPath,
    this.renoirAsset,
    this.showDealerBadge = false,
    required this.dealerAvatarStyle,
    required this.defaultProfileAsset,
    required this.cardBackAsset,
    required this.pot,
    required this.board,
    required this.seats,
    required this.activeBloodStains,
    required this.currentTurn,
    required this.sbIndex,
    required this.bbIndex,
    required this.heroIndex,
    required this.recentActions,
    required this.isHeroTurn,
    required this.toCall,
    required this.showShuffle,
    required this.showDeckPile,
    required this.showToggleVisible,
    required this.heroShow,
    required this.potPulse,
    required this.raiseAmount,
    required this.minRaise,
    required this.maxRaise,
    required this.onRaiseAmountChanged,
    required this.onCheckOrCall,
    required this.onFold,
    required this.onBetOrRaise,
    required this.onAllIn,
    required this.onToggleShow,
    required this.startingStack,
    this.renoirLiftPx = 0,
    required this.venueOffsetMinutes,
    this.engineEvents,
    this.onScriptLap,
    this.engine,
    this.canSkipToWinner,
    this.canShowdown,
    this.onSkipToWinner,
    this.onShowdown,
    this.deckHeightPx,
    this.deckOffset,
    this.deckScale = 1.0,
    this.playIntroWelcome = true,
    this.onRenoirShuffle,
  });

  @override
  State<GameScreenUI> createState() => _GameScreenUIState();
}

class _GameScreenUIState extends State<GameScreenUI>
    with TickerProviderStateMixin, WidgetsBindingObserver {
// Hide all cards (hole + community) while a winners overlay is shown
  bool _hideAllCards = true;
  StreamSubscription<dynamic>? _winnersSub;
  List<_WinnerFanInfo> _winnerFans = const [];
  bool _handWinnerOverlayVisible = false;
  bool _handWinnerIsHero = false;
  String _handWinnerName = '';
  String _handWinnerAbout = '';

  List<_WinChipPop> _winChipPops = <_WinChipPop>[];
  int _winChipSeq = 0;

  final GlobalKey<ActionBurstOverlayState> _actionBurstKey =
      GlobalKey<ActionBurstOverlayState>();
  final GlobalKey _actionBarKey = GlobalKey(debugLabel: 'ActionBar');
  final GlobalKey _actionBarCallButtonKey =
      GlobalKey(debugLabel: 'ActionBarCallButton');
  final GlobalKey _actionBarFoldButtonKey =
      GlobalKey(debugLabel: 'ActionBarFoldButton');
  final GlobalKey _actionBarRaiseButtonKey =
      GlobalKey(debugLabel: 'ActionBarRaiseButton');
  final GlobalKey _actionBarAllInButtonKey =
      GlobalKey(debugLabel: 'ActionBarAllInButton');
  final GlobalKey _actionBarYellowButtonKey =
      GlobalKey(debugLabel: 'ActionBarYellowButton');

  Timer? _recoveryDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ensure engine knows who the hero is (required for canSkipToWinner gate)
    try {
      final e = widget.engine;
      if (e != null) {
        (e as dynamic).heroIndex = widget.heroIndex;
      }
    } catch (_) {}
    // Start with already-busted seats hidden (never hide hero).
    for (int i = 0; i < widget.seats.length; i++) {
      if (i == widget.heroIndex) continue;
      if (widget.seats[i].busted) {
        _hiddenSeatIdx.add(i);
      }
    }
    // Hide cards whenever a winners overlay is shown (centralized UX)
    try {
      _winnersSub = go.WinnersBus.stream.listen((evt) {
        try {
          final shown = (evt as dynamic).shown == true;
          if (shown) {
            final snap = go.LastHandStore.last;
            final winners = (snap?.winners ?? const <go.WinnerLine>[])
                .where((w) => w.amount > 0)
                .toList();

            String winnerName = '';
            String winnerAbout = '';
            bool heroWonTop = false;

            if (winners.isNotEmpty) {
              final int bestAmount =
                  winners.map((w) => w.amount).fold(0, (a, b) => math.max(a, b));
              final topWinners =
                  winners.where((w) => w.amount == bestAmount).toList();

              String? heroName;
              if (widget.heroIndex >= 0 &&
                  widget.heroIndex < widget.seats.length) {
                heroName = widget.seats[widget.heroIndex].name;
              } else {
                for (final s in widget.seats) {
                  if (s.isHero) {
                    heroName = s.name;
                    break;
                  }
                }
              }

              bool sameName(String a, String b) =>
                  a.trim().toLowerCase() == b.trim().toLowerCase();

              heroWonTop = heroName != null &&
                  topWinners.any((w) => sameName(w.playerName, heroName!));

              final picked = heroWonTop
                  ? topWinners.firstWhere(
                      (w) => sameName(w.playerName, heroName!),
                      orElse: () => topWinners.first,
                    )
                  : topWinners.first;

              winnerName =
                  picked.playerName.trim().isNotEmpty ? picked.playerName.trim() : '';
              winnerAbout = picked.about.trim();
            }

            setState(() {
              _hideAllCards = false;
              _handWinnerOverlayVisible = true;
              _handWinnerIsHero = heroWonTop;
              _handWinnerName = winnerName;
              _handWinnerAbout = winnerAbout;
            });
            _startWinChipPops();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _burstWinnerCelebration();
            });
          } else {
            _stopWinChipPops();
            setState(() {
              _winnerFans = const [];
              _handWinnerOverlayVisible = false;
              _handWinnerIsHero = false;
              _handWinnerName = '';
              _handWinnerAbout = '';
            });
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _scheduleRecovery() {
    _recoveryDebounce?.cancel();
    _recoveryDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _recoverCardsIfNeeded();
    });
  }

  void _recoverCardsIfNeeded() {
    // If actions are enabled, the player must be able to see cards. Web can
    // occasionally lose table visibility on tab/window minimize.
    final bool actionsOn =
        ActionGate.enabled.value || RenoirSignals.canAct.value;
    final bool holesVisible = RenoirSignals.holeCardsVisible.value;
    final bool dealingActive = RenoirSignals.dealingActive.value;
    final bool hasDealtCards =
        widget.board.isNotEmpty || widget.seats.any((s) => s.hole.isNotEmpty);

    if (!actionsOn && !holesVisible && !dealingActive && !hasDealtCards) {
      return;
    }

    bool needSet = false;
    if (_hideAllCards) {
      _hideAllCards = false;
      needSet = true;
    }
    if (_hardHideHoleCards) {
      _hardHideHoleCards = false;
      needSet = true;
    }

    if (!CardVisibilityGate.enabled.value) {
      CardVisibilityGate.show();
    }

    final st = _renoirLayerKey.currentState;
    try {
      (st as dynamic).setCardsHidden(false);
    } catch (_) {}

    if (needSet && mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleRecovery();
    }
  }

  @override
  void didChangeMetrics() {
    // Window minimize/restore on web can surface here without lifecycle events.
    _scheduleRecovery();
  }

  void _disposeWinChipPops() {
    for (final p in _winChipPops) {
      try {
        p.controller.dispose();
      } catch (_) {}
    }
    _winChipPops = <_WinChipPop>[];
  }

  void _startWinChipPops() {
    if (!mounted || !_geomReady) return;
    final snap = go.LastHandStore.last;
    if (snap == null || snap.winners.isEmpty) return;

    _winChipSeq += 1;
    _disposeWinChipPops();

    final size = MediaQuery.of(context).size;
    final ui = _Ui(size.width, size.height);

    final winners = snap.winners.where((w) => w.amount > 0).toList();
    if (winners.isEmpty) return;

    final int bestAmount = winners
        .map((w) => w.amount)
        .fold<int>(0, (maxAmt, a) => math.max(maxAmt, a));
    if (bestAmount <= 0) return;

    String? heroName;
    if (widget.heroIndex >= 0 && widget.heroIndex < widget.seats.length) {
      heroName = widget.seats[widget.heroIndex].name;
    } else {
      for (final s in widget.seats) {
        if (s.isHero) {
          heroName = s.name;
          break;
        }
      }
    }

    bool sameName(String a, String b) =>
        a.trim().toLowerCase() == b.trim().toLowerCase();

    final topWinners = winners.where((w) => w.amount == bestAmount);
    final bool heroWonTop = heroName != null &&
        topWinners.any((w) => sameName(w.playerName, heroName!));
    final Color fillColor =
        heroWonTop ? const Color(0xFF24B6FF) : const Color(0xFFFF2800);

    final double labelW = ui.cardW * 2.5;
    final double labelH = ui.cardH * 1.5;
    final double startX = _boardCenter.dx;
    final double startY = _boardCenter.dy;

    // Rest position: centered vertically between the upper wooden rail (felt edge)
    // and the top of the community cards row.
    final double railBottomY = _feltRect.top;
    final double communityTopY = _boardCenter.dy - ui.cardH / 2;
    final double targetCenterY = (railBottomY + communityTopY) / 2;
    final double minCenterY = labelH / 2 + 6;
    final double endY = math.max(minCenterY, targetCenterY);

    final pops = <_WinChipPop>[];
    final c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      reverseDuration: const Duration(milliseconds: 180),
    )..forward();

    pops.add(_WinChipPop(
      text: '+$bestAmount',
      centerX: startX,
      startCenterY: startY,
      endCenterY: endY,
      width: labelW,
      height: labelH,
      fillColor: fillColor,
      controller: c,
    ));

    setState(() {
      _winChipPops = pops;
    });
  }

  void _stopWinChipPops() {
    if (_winChipPops.isEmpty) return;
    final seq = _winChipSeq;

    for (final p in _winChipPops) {
      try {
        p.controller.reverse();
      } catch (_) {}
    }

    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      if (seq != _winChipSeq) return;
      setState(() {
        _disposeWinChipPops();
      });
    });
  }

  Rect? _globalRectForKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox) return null;
    final topLeft = ro.localToGlobal(Offset.zero);
    return topLeft & ro.size;
  }

  void _burstWinnerCelebration() {
    final burst = _actionBurstKey.currentState;
    if (burst == null) return;
    final root = context.findRenderObject();
    if (root is! RenderBox) return;

    final barRectG = _globalRectForKey(_actionBarKey);
    if (barRectG == null) {
      burst.burstAt(Offset(root.size.width / 2, root.size.height - 140));
      return;
    }

    // Place origin INSIDE the bar so the start is hidden behind it.
    final double desiredY = barRectG.top + barRectG.height * 0.28;
    final double y =
        desiredY.clamp(barRectG.top + 2, barRectG.bottom - 2).toDouble();

    const xs = <double>[0.22, 0.50, 0.78];
    final origins = <Offset>[
      for (final f in xs)
        root.globalToLocal(Offset(barRectG.left + barRectG.width * f, y)),
    ];
    burst.burstAtMany(origins);
  }

  List<Widget> _buildWinChipPops() {
    if (_winChipPops.isEmpty) return const <Widget>[];
    final out = <Widget>[];
    for (final p in _winChipPops) {
      out.add(Positioned(
        left: p.centerX - p.width / 2,
        top: 0,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: p.controller,
            child: SizedBox(
              width: p.width,
              height: p.height,
              child: Center(
                child: _OutlinedText(text: p.text, fillColor: p.fillColor),
              ),
            ),
            builder: (_, child) {
              final t = p.controller.value.clamp(0.0, 1.0);
              final moveT = Curves.easeOutCubic.transform(t);
              final scaleT = Curves.easeOutBack.transform(t);
              final double y =
                  p.startCenterY + (p.endCenterY - p.startCenterY) * moveT;
              final double scale = 0.18 + 0.82 * scaleT;
              final double opacity = (t / 0.22).clamp(0.0, 1.0);

              return Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, y - p.height / 2),
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
      ));
    }
    return out;
  }

  // Geometry from GameTableLayer → handed to RenoirLayer and used for seat layout
  bool _geomReady = false;
  double _railW = 34.0;
  Rect _feltRect = Rect.zero;
  Offset _origin = Offset.zero;
  Offset _boardCenter = Offset.zero;
  List<Offset> _seatTargets = const [];

  // Hidden seats bookkeeping (never hide hero)
  final Set<int> _hiddenSeatIdx = <int>{};

  // Key to control RenoirLayer without exposing its private State type
  final GlobalKey _renoirLayerKey = GlobalKey(debugLabel: 'RenoirLayer');

  // Hard hide seat widgets' own hole-card icons until dealing starts
  bool _hardHideHoleCards = true;

  @override
  void didUpdateWidget(covariant GameScreenUI oldWidget) {
    super.didUpdateWidget(oldWidget);

    _hiddenSeatIdx.removeWhere((i) => i < 0 || i >= widget.seats.length);
    _hiddenSeatIdx.remove(widget.heroIndex);

    for (int i = 0; i < widget.seats.length; i++) {
      if (_hiddenSeatIdx.contains(i) && !widget.seats[i].busted) {
        _hiddenSeatIdx.remove(i); // revived
      }
    }
    // Keep engine.heroIndex in sync on rebuilds
    try {
      final e = widget.engine;
      if (e != null) {
        (e as dynamic).heroIndex = widget.heroIndex;
      }
    } catch (_) {}
  }

  int? _leaderIndex(List<Seat> seats, Set<int> hidden, int startingStack) {
    int? idx;
    int maxChips = -1;
    for (int i = 0; i < seats.length; i++) {
      final s = seats[i];
      if (hidden.contains(i) || s.busted) continue;
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
    if (maxChips == startingStack) return null;
    return idx;
  }

  bool _everyoneElseFolded(List<Seat> seats, int heroIdx) {
    bool isFolded(Seat s) {
      final dyn = s as dynamic;
      try {
        if (dyn.folded == true) return true;
      } catch (_) {}
      try {
        if (dyn.hasFolded == true) return true;
      } catch (_) {}
      return false;
    }

    for (int i = 0; i < seats.length; i++) {
      if (i == heroIdx) continue;
      final s = seats[i];
      if (s.busted) continue;
      if (!isFolded(s)) {
        return false; // someone else still active
      }
    }
    return true; // everyone except hero is folded or busted
  }

  // === Hand-end UX glue ===
  // Call this when you have winners to display.
  // It hides hole cards immediately (onShown), then after the dialog closes,
  // Renoir shuffles and the next hand starts (onClosed).
  Future<void> showWinnersDialog({
    required List<go.WinnerLine> winners,
    required int totalPot,
    Duration duration = const Duration(milliseconds: 6500), // +1.5s longer
  }) {
    _prepareWinnerFans(winners);
    return go.showWinnersDialog(
      context,
      winners: winners,
      totalPot: totalPot,
      duration: duration,
      board: widget.board.map((gc) => go.UiCard(gc.rank, gc.suit)).toList(),
      showCommunity: false, // keep community row on table (no movement/resize)
      showArcCongrats: true,
      onShown: () {
        setState(() {
          _hardHideHoleCards = false; // keep seat cards until overlay visible
          _hideAllCards =
              false; // keep base cards; Renoir will hide after overlay shows
        });
        try {
          CardVisibilityGate.show();
          ActionGate.disable();
        } catch (_) {}
        final st = _renoirLayerKey.currentState;
        try {
          (st as dynamic).setCardsHidden(false);
        } catch (_) {}
      },
      onClosed: () {
        // Ensure dealer becomes visible immediately after overlay closes
        setState(() {
          _hideAllCards = false;
          _hardHideHoleCards = false;
          _winnerFans = const [];
        });
        final st = _renoirLayerKey.currentState;
        try {
          (st as dynamic).onWinnersAnnounced();
        } catch (_) {}
        try {
          CardVisibilityGate.hide();
          ActionGate.enable();
        } catch (_) {}
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final ui = _Ui(size.width, size.height);

    final seats = widget.seats;
    final leaderIdx = _leaderIndex(seats, _hiddenSeatIdx, widget.startingStack);
    // Yellow SKIP/SHOW (works with or without engine) - Defensive, no-crash wiring
    final engine = widget.engine;

    bool _engineCanSkip() {
      try {
        return engine != null && ((engine as dynamic).canSkipToWinner == true);
      } catch (_) {
        return false;
      }
    }

    bool _engineCanShow() {
      try {
        return engine != null && ((engine as dynamic).canShowNow == true);
      } catch (_) {
        return false;
      }
    }

    void _engineDoSkip() {
      try {
        if (engine != null) {
          (engine as dynamic).requestSkipToWinner();
        }
      } catch (_) {
        // swallow — UI fallbacks will still allow progress
      }
    }

    void _engineDoShow() {
      try {
        if (engine != null) {
          (engine as dynamic).requestShowNow();
        }
      } catch (_) {
        // swallow — UI fallbacks will still allow progress
      }
    }

    final bool kCanSkip = _engineCanSkip() || (widget.canSkipToWinner ?? false);
    final double maxBet = seats.isEmpty
        ? 0
        : seats.map((s) => s.bet.toDouble()).fold(0, math.max);
    final double maxHandContrib = seats.isEmpty
        ? 0
        : seats.map((s) => s.contributedThisHand.toDouble()).fold(0, math.max);
    final int activePlayers = seats.where((s) => !s.busted && !s.folded).length;

    return Scaffold(
      backgroundColor: widget.bg,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          LayoutBuilder(builder: (context, c) {
            return ValueListenableBuilder<bool>(
              valueListenable: RenoirSignals.canAct,
              builder: (context, canAct, _) {
                final double tableHeight = math.min(c.maxHeight, ui.tableH);
                final double seatMaxW = math.max(ui.seatMaxW, _kSeatMinW);
                final double seatMaxH = math.max(ui.seatH, _kSeatMinH);
                final _SeatPlacement? seatPlacement = _geomReady
                    ? _computeSeatPlacement(
                        feltRect: _feltRect,
                        railW: _railW,
                        seatW: seatMaxW,
                        seatH: seatMaxH,
                      )
                    : null;

                return Center(
                  child: SizedBox(
                    width: ui.tableW,
                    height: tableHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 1) BOTTOM: Felt/Rail/Watermark + Pot (NO seats here)
                        GameTableLayer(
                          paintSeats: false, // seats will be drawn on top
                          width: ui.tableW,
                          height: tableHeight,
                          railWidth: _railW,
                          felt: widget.felt,
                          wood: widget.wood,
                          watermarkSvgAsset:
                              (widget.monumentPath?.isNotEmpty ?? false)
                                  ? widget.monumentPath
                                  : null,
                          watermarkOpacity: 0.18,
                          watermarkAlignment: Alignment.center,
                          tintWhite: false,
                          pot: widget.pot,
                          potPulse: widget.potPulse,

                          // (still pass these so geometry math matches)
                          seats: seats,
                          heroIndex: widget.heroIndex,
                          currentTurn: widget.currentTurn,
                          sbIndex: widget.sbIndex,
                          bbIndex: widget.bbIndex,
                          hiddenSeatIdx: _hiddenSeatIdx,

                          defaultProfileAsset: widget.defaultProfileAsset,
                          seatMaxW: seatMaxW,
                          seatH: seatMaxH,
                          baseCardW: ui.cardW,
                          baseCardH: ui.cardH,
                          cardBackAsset: widget.cardBackAsset,
                          showToggleVisible: widget.showToggleVisible,
                          heroShow: widget.heroShow,
                          seatVisualMarginPx: _kSeatVisualMarginPx,
                          showBlindChips: false,
                          blindChipPlacement: _kBlindChipPlacement,

                          communityRowTopFrac: 0.30,
                          topGapRadians: math.pi / 3,
                          softBandRadians: math.pi / 10,
                          pushDownFrac: 0.10,

                          onGeometryChanged: (TableGeometry g) {
                            _railW = g.railWidth;
                            _feltRect = g.feltRect;
                            _origin = g.origin;
                            _seatTargets = g.seatTargets;
                            _boardCenter = g.boardCenter;
                            if (!_geomReady) {
                              setState(() => _geomReady = true);
                            }
                          },
                        ),

                        // 2) MIDDLE: ALL cards (community + hole + flights)
                        if (_geomReady)
                          RenoirLayer(
                            key:
                                _renoirLayerKey, // <— allows hide/shuffle/next-hand
                            renoirAsset: widget.renoirAsset,
                            playIntroWelcome: widget.playIntroWelcome,
                            showDealerBadge: widget.showDealerBadge,
                            renoirRadius: ui.renoirR,
                            renoirLiftPx: widget.renoirLiftPx,
                            avatarStyle: widget.dealerAvatarStyle,
                            railWidth: _railW,
                            feltColor: widget.felt,
                            wood: widget.wood,

                            // Geometry (felt space)
                            origin: _origin,
                            seatTargets: _seatTargets,
                            boardTarget: _boardCenter,

                            // Card art/size
                            cardBackAsset: widget.cardBackAsset,
                            cardW: ui.cardW,
                            cardH: ui.cardH,

                            // Game state for reveals
                            seats: widget.seats,
                            board:
                                _hideAllCards ? const <GCard>[] : widget.board,
                            heroIndex: widget.heroIndex,
                            hiddenSeats: _hideAllCards
                                ? {
                                    ..._hiddenSeatIdx,
                                    for (int i = 0; i < seats.length; i++) i,
                                  }
                                : _hiddenSeatIdx,
                            showToggleVisible: widget.showToggleVisible,
                            heroShow: widget.heroShow,

                            // Engine integration (optional)
                            engineEvents: widget.engineEvents,
                            onShuffle: () {
                              widget.onRenoirShuffle?.call();
                              // Unhide cards slightly after shuffle starts to sync with RenoirLayer timing
                              Future.delayed(
                                  Duration(
                                      milliseconds: pace.kRevealAfterShuffleMs),
                                  () {
                                if (!mounted) return;
                                setState(() {
                                  _hardHideHoleCards =
                                      false; // seat mini-cards allowed
                                  _hideAllCards =
                                      false; // board + flights allowed
                                });
                              });
                            },
                            onScriptLap: (r) => widget.onScriptLap?.call(r),
                            onDealingActive: (active) {
                              if (active) {
                                // first flight started → allow seat widgets to show their own mini cards again
                                setState(() {
                                  _hardHideHoleCards = false;
                                  _hideAllCards =
                                      false; // unhide board & flights as new hand starts
                                });
                              }
                            },
                          ),

                        // Winner chip amounts (pop out of community cards)
                        if (_geomReady && _winChipPops.isNotEmpty)
                          ..._buildWinChipPops(),

                        // 2b) Info pills near Renoir (side-by-side)
                        if (_geomReady)
                          ..._buildInfoPillsNearRenoir(
                            ui: ui,
                            pot: widget.pot,
                            maxBet: maxBet,
                            activePlayers: activePlayers,
                            seatCount: seats.length,
                            seats: seats,
                            recentActions: widget.recentActions,
                            heroIndex: widget.heroIndex,
                            currentTurn: widget.currentTurn,
                            origin: _origin,
                            feltRect: _feltRect,
                            railWidth: _railW,
                            winnerOverlayVisible: _handWinnerOverlayVisible,
                            winnerName: _handWinnerName,
                            winnerAbout: _handWinnerAbout,
                            winnerIsHero: _handWinnerIsHero,
                          ),

                        // 3) Blood stains for busted seats (same plane as cards)
                        if (_geomReady && seatPlacement != null)
                          ..._buildBloodStains(
                            placement: seatPlacement,
                            seats: seats,
                          ),

                        // 3) Blind chips layered above cards (same plane as seats)
                        if (_geomReady && seatPlacement != null)
                          ..._buildBlindChipsOnTop(
                            placement: seatPlacement,
                            tableWidth: ui.tableW,
                            tableHeight: tableHeight,
                          ),

                        // 4) TOP: Seat widgets
                        if (_geomReady && seatPlacement != null)
                          ..._buildSeatPanelsOnTop(
                            placement: seatPlacement,
                            seats: seats,
                            leaderIdx: leaderIdx,
                            growOthers: _hiddenSeatIdx.isNotEmpty ||
                                seats.any((s) => s.busted),
                            canAct: canAct,
                          ),
                        if (_geomReady &&
                            seatPlacement != null &&
                            _winnerFans.isNotEmpty)
                          ..._buildWinnerFans(
                            placement: seatPlacement,
                            fans: _winnerFans,
                            cardW: ui.cardW,
                            cardH: ui.cardH,
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),

          // ========= ACTION BURST (LIGHT FX) =========
          // Keep it *behind* the ActionBar so bursts look like they pop up from
          // behind the bar.
          Positioned.fill(
            child: IgnorePointer(
              child: ActionBurstOverlay(key: _actionBurstKey),
            ),
          ),

          // ========= VENUE CHIP & CLOCK =========
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: _VenueChip(
                      flagPath: widget.flagPath,
                      venueName: widget.venueName,
                    ),
                  ),
                  DayDateClock(offsetMinutes: widget.venueOffsetMinutes),
                ],
              ),
            ),
          ),

          // ========= ACTION BAR (FLOATING) =========
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Material(
                  color: Colors.transparent,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 64),
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: ActionGate.enabled,
                          builder: (context, actionsOn, _) {
                            final bool heroCardsReady = widget.heroIndex >= 0 &&
                                widget.heroIndex < widget.seats.length &&
                                widget.seats[widget.heroIndex].hole.length >= 2;

                            return ActionBar(
                              key: _actionBarKey,
                              callButtonKey: _actionBarCallButtonKey,
                              foldButtonKey: _actionBarFoldButtonKey,
                              raiseButtonKey: _actionBarRaiseButtonKey,
                              allInButtonKey: _actionBarAllInButtonKey,
                              yellowButtonKey: _actionBarYellowButtonKey,
                              pot: widget.pot.round(),
                              callAmount: widget.toCall,
                              minRaiseTo: widget.minRaise.round(),
                              maxRaiseTo: widget.maxRaise.round(),
                              sliderTo: widget.raiseAmount.round(),
                              canAct: actionsOn &&
                                  widget.isHeroTurn &&
                                  heroCardsReady,
                              onHandExamples: widget.onShowHandRankings,
                              onScoreboard: () {
                                Seat? heroSeat;
                                if (widget.heroIndex >= 0 &&
                                    widget.heroIndex < widget.seats.length) {
                                  heroSeat = widget.seats[widget.heroIndex];
                                }
                                scoreboard_sheet.showScoreboardSheet(
                                  context,
                                  widget.seats,
                                  heroSeat: heroSeat,
                                );
                              },
                              onCall: widget.onCheckOrCall,
                              onFold: widget.onFold,
                              onAllIn: widget.onAllIn,
                              onRaiseToChanged: (v) =>
                                  widget.onRaiseAmountChanged(v.toDouble()),
                              onBetOrRaise: widget.onBetOrRaise,
                              onTips: () => go.showPreviousHandOverlay(context),
                              onSaveExit: () => _saveAndExit(context),
                              canSkipToWinner: kCanSkip,
                              canShowdown: _engineCanShow() ||
                                  (widget.canShowdown ?? false),
                              everyoneElseFolded: _everyoneElseFolded(
                                  widget.seats, widget.heroIndex),
                              onSkipToWinner: widget.engine != null
                                  ? _engineDoSkip
                                  : (widget.onSkipToWinner ?? () {}),
                              onShowdown: widget.engine != null
                                  ? _engineDoShow
                                  : (widget.onShowdown ?? () {}),
                              compact: false,
                              engine: widget.engine,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ----------------------- Seat panels (TOP layer) ----------------------- */

  List<Widget> _buildSeatPanelsOnTop({
    required _SeatPlacement placement,
    required List<Seat> seats,
    required int? leaderIdx,
    required bool growOthers,
    required bool canAct,
  }) {
    final seatSide = placement.seatSide;
    final List<Offset> projected = placement.positions;
    final widgets = <Widget>[];
    for (final e in projected.asMap().entries) {
      final i = e.key;
      if (_hiddenSeatIdx.contains(i)) continue;

      final Offset pos = e.value;

      widgets.add(
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: SizedBox(
            width: seatSide,
            height: seatSide,
            child: SeatWidget(
              seat: seats[i],
              isLeader: leaderIdx != null && i == leaderIdx,
              growWhenOthersGone: growOthers,
              onFadeDone: () {
                if (seats[i].busted && i != widget.heroIndex) {
                  setState(() => _hiddenSeatIdx.add(i));
                }
              },
              isTurn: canAct && (i == widget.currentTurn),
              isSB: i == widget.sbIndex,
              isBB: i == widget.bbIndex,
              fallbackAvatarAsset:
                  seatFallbackAsset(seats[i], widget.defaultProfileAsset),
              seatMaxWidth: seatSide,
              seatHeight: seatSide,
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  void _prepareWinnerFans(List<go.WinnerLine> winners) {
    final List<_WinnerFanInfo> fans = [];
    for (final w in winners) {
      final int seatIdx =
          widget.seats.indexWhere((s) => s.name.trim() == w.playerName.trim());
      if (seatIdx == -1) continue;
      if (seatIdx == widget.heroIndex) continue; // hero unchanged
      if (w.holeCards.isEmpty) continue;
      fans.add(_WinnerFanInfo(
        seatIndex: seatIdx,
        holeCards: w.holeCards.take(2).toList(),
        bestKeys: {
          for (final c in go.winningHandHighlightCards(w.bestFive))
            _winnerCardKey(c),
        },
      ));
    }
    setState(() {
      _winnerFans = fans;
    });
  }

  List<Widget> _buildWinnerFans({
    required _SeatPlacement placement,
    required List<_WinnerFanInfo> fans,
    required double cardW,
    required double cardH,
  }) {
    final widgets = <Widget>[];
    final positions = placement.positions;
    final seatSide = placement.seatSide;

    for (final fan in fans) {
      final int idx = fan.seatIndex;
      if (idx < 0 || idx >= positions.length) continue;
      final bool isHeroWinner =
          idx == widget.heroIndex || (idx < widget.seats.length && widget.seats[idx].isHero);
      final Color outlineColor =
          isHeroWinner ? const Color(0xFF3BB143) : const Color(0xFFFFC857);
      final Offset pos = positions[idx];
      final Offset center =
          Offset(pos.dx + seatSide / 2, pos.dy + seatSide * 0.08);

      final double dx = cardW * 0.32;
      final double dy = cardH * -0.48;
      final hole = fan.holeCards;
      if (hole.isEmpty) continue;

      final cards = <({Offset offset, double angle, go.UiCard card})>[];
      cards.add((offset: Offset(-dx, dy), angle: -0.18, card: hole.first));
      if (hole.length > 1) {
        cards.add((offset: Offset(dx, dy), angle: 0.18, card: hole[1]));
      }

      for (final c in cards) {
        final bool highlight = fan.bestKeys.contains(_winnerCardKey(c.card));
        widgets.add(
          Positioned(
            left: center.dx + c.offset.dx - cardW / 2,
            top: center.dy + c.offset.dy - cardH / 2,
            child: Transform.rotate(
              angle: c.angle,
              child: _WinnerSeatCard(
                card: c.card,
                w: cardW * 1.08,
                h: cardH * 1.08,
                highlight: highlight,
                highlightColor: outlineColor,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  List<Widget> _buildBloodStains({
    required _SeatPlacement placement,
    required List<Seat> seats,
  }) {
    final widgets = <Widget>[];
    final seatSide = placement.seatSide;
    final positions = placement.positions;
    for (final entry in positions.asMap().entries) {
      final int index = entry.key;
      Seat? seat;
      if (index < seats.length) {
        seat = seats[index];
      }
      final bool visible =
          seat != null && widget.activeBloodStains.contains(index);
      final int seed =
          seat == null ? index : Object.hash(index, seat.name, seat.avatarKey);
      widgets.add(
        Positioned(
          left: entry.value.dx,
          top: entry.value.dy,
          child: SizedBox(
            width: seatSide,
            height: seatSide,
            child: SeatBloodStain(
              key: ValueKey('blood-seat-$index'),
              visible: visible,
              seed: seed,
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildBlindChipsOnTop({
    required _SeatPlacement placement,
    required double tableWidth,
    required double tableHeight,
  }) {
    final double chipSize =
        (placement.seatSide * 0.46).clamp(26.0, 52.0).toDouble();
    final bool chipsOnRail = _kBlindChipPlacement == BlindChipPlacement.rail;
    final Rect clampRect = chipsOnRail
        ? Rect.fromLTWH(0, 0, tableWidth, tableHeight)
        : _deflateForSeatPlacement(_feltRect, _kSeatVisualMarginPx);

    return buildBlindChips(
      seats: widget.seats,
      hiddenSeatIdx: _hiddenSeatIdx,
      seatPositions: placement.positions,
      seatSide: placement.seatSide,
      boardCenter: _boardCenter,
      feltRect: _feltRect,
      clampRect: clampRect,
      chipSize: chipSize,
      placement: _kBlindChipPlacement,
      railWidth: _railW,
      sbIndex: widget.sbIndex,
      bbIndex: widget.bbIndex,
      heroIndex: widget.heroIndex,
    );
  }

  /* ----------------------------- UI helpers ------------------------------ */

  _SeatPlacement _computeSeatPlacement({
    required Rect feltRect,
    required double railW,
    required double seatW,
    required double seatH,
  }) {
    final double seatSide = math.min(seatW, seatH);
    if (seatSide <= 0 || feltRect.width <= 0 || feltRect.height <= 0) {
      return const _SeatPlacement(<Offset>[], 0);
    }

    final int seatCount = widget.seats.length;
    if (seatCount == 0) return const _SeatPlacement(<Offset>[], 0);

    // Distribute seats along a racetrack (superellipse) arc covering ~60–65% of the rail,
    // leaving the rest (top) for Renoir. Expand available arc slightly if needed
    // to keep seats from overlapping.
    const double baseReservedTopFraction = 0.40;
    const double minReservedTopFraction =
        0.35; // allows up to ~65% arc when crowded
    const double superellipseN = 4.0; // racetrack exponent

    final double radius = seatSide / 2;
    final double cx = feltRect.center.dx;
    final double cy = feltRect.center.dy;
    final double a = math.max(radius, feltRect.width / 2 + railW - radius);
    final double b = math.max(radius, feltRect.height / 2 + railW - radius);

    // Determine available arc to avoid overlap if seats are wide.
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
    final double start =
        (math.pi / 2) - (availableAngle / 2); // arc centered on bottom
    final double end = start + availableAngle;

    Offset _pointAt(double theta) {
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

    // Sample the arc to approximate equal distances between seats.
    final int samples = 400;
    final List<double> angles = List<double>.generate(
        samples, (i) => start + (availableAngle * i) / (samples - 1));
    final List<Offset> pts = [for (final ang in angles) _pointAt(ang)];

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

    // Rotate slots so hero index lands on slot 4 (5th from left, clockwise).
    final int heroIdx = (widget.heroIndex >= 0 && widget.heroIndex < seatCount)
        ? widget.heroIndex
        : -1;
    final int heroSlot = seatCount > 4 ? 4 : math.max(0, seatCount - 1);
    int shift = 0;
    if (heroIdx != -1 && seatCount > 0) {
      shift = (heroSlot - heroIdx) % seatCount;
      if (shift < 0) shift += seatCount;
    }

    final List<Offset> positions = List<Offset>.generate(seatCount, (i) {
      final int slotIdx = (i + shift) % seatCount;
      return slots[slotIdx];
    });

    return _SeatPlacement(positions, seatSide);
  }

  Rect _deflateForSeatPlacement(Rect r, double pad) {
    if (pad <= 0) return r;
    final double dx = pad.clamp(0.0, r.width / 3);
    final double dy = pad.clamp(0.0, r.height / 3);
    return Rect.fromLTWH(
      r.left + dx,
      r.top + dy,
      (r.width - 2 * dx).clamp(1.0, r.width),
      (r.height - 2 * dy).clamp(1.0, r.height),
    );
  }

  List<Offset> _projectSeatPanelsToRail(
    List<Offset> rects, {
    required double seatSide,
    required Rect feltRect,
    required double railW,
  }) {
    if (rects.isEmpty) return const <Offset>[];

    final double radius = seatSide / 2;
    final Offset feltCenter = feltRect.center;
    final double outerA = feltRect.width / 2 + railW;
    final double outerB = feltRect.height / 2 + railW;
    final double targetA = math.max(radius, outerA - radius);
    final double targetB = math.max(radius, outerB - radius);

    final List<Offset> projected = [];
    for (final rect in rects) {
      final Offset seatCenterLocal = Offset(rect.dx + radius, rect.dy + radius);
      final Offset fromCenter = seatCenterLocal - feltCenter;
      final double dist = fromCenter.distance;
      Offset targetCenterLocal;
      if (dist < 1e-3) {
        targetCenterLocal = seatCenterLocal;
      } else {
        final double denom = math.sqrt(
          (fromCenter.dx * fromCenter.dx) / (targetA * targetA) +
              (fromCenter.dy * fromCenter.dy) / (targetB * targetB),
        );
        if (denom <= 1e-5) {
          targetCenterLocal = seatCenterLocal;
        } else {
          targetCenterLocal = feltCenter + fromCenter / denom;
        }
      }
      final Offset topLeftLocal =
          Offset(targetCenterLocal.dx - radius, targetCenterLocal.dy - radius);
      projected.add(topLeftLocal);
    }

    return projected;
  }

  List<Offset> _resolveSeatOverlaps({
    required List<Offset> positions,
    required double seatSide,
    required double areaWidth,
    required double areaHeight,
    int iterations = 8,
  }) {
    if (positions.length <= 1) return positions;
    final double radius = seatSide / 2;
    final double minX = 0.0;
    final double minY = 0.0;
    final double maxX = math.max(0.0, areaWidth - seatSide);
    final double maxY = math.max(0.0, areaHeight - seatSide);
    final List<Offset> centers = [
      for (final o in positions) Offset(o.dx + radius, o.dy + radius),
    ];

    for (int iter = 0; iter < iterations; iter++) {
      bool moved = false;
      for (int i = 0; i < centers.length; i++) {
        for (int j = i + 1; j < centers.length; j++) {
          Offset delta = centers[j] - centers[i];
          double dist = delta.distance;
          const double epsilon = 1e-3;
          if (dist < epsilon) {
            delta = const Offset(1, 0);
            dist = 1.0;
          }
          final double minDist = seatSide * 0.98;
          if (dist < minDist) {
            final double push = (minDist - dist) / 2;
            final Offset dir = delta / dist;
            centers[i] -= dir * push;
            centers[j] += dir * push;
            moved = true;
          }
        }
      }

      for (int k = 0; k < centers.length; k++) {
        final double cx = centers[k].dx.clamp(minX + radius, maxX + radius);
        final double cy = centers[k].dy.clamp(minY + radius, maxY + radius);
        if (cx != centers[k].dx || cy != centers[k].dy) {
          centers[k] = Offset(cx, cy);
          moved = true;
        } else {
          centers[k] = Offset(cx, cy);
        }
      }
      if (!moved) break;
    }

    return [
      for (final c in centers) Offset(c.dx - radius, c.dy - radius),
    ];
  }

  void _showTips(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Tips',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                '• Tap community cards for hand rankings.\n'
                '• First Bet/Raise tap opens the slider; second tap confirms.\n'
                '• Use Scoreboard to see chip order and busted players.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveAndExit(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Game saved. Exiting...')),
    );
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recoveryDebounce?.cancel();
    _recoveryDebounce = null;
    _disposeWinChipPops();
    try {
      _winnersSub?.cancel();
    } catch (_) {}
    _winnersSub = null;
    super.dispose();
  }
}

class _SeatPlacement {
  const _SeatPlacement(this.positions, this.seatSide);

  final List<Offset> positions;
  final double seatSide;
}

class _WinnerSeatCard extends StatelessWidget {
  final go.UiCard card;
  final double w, h;
  final bool highlight;
  final Color highlightColor;
  const _WinnerSeatCard(
      {required this.card,
      required this.w,
      required this.h,
      this.highlight = false,
      this.highlightColor = const Color(0xFFFFC857)});

  @override
  Widget build(BuildContext context) {
    final borderColor = highlight ? highlightColor : Colors.white24;
    final pc.PlayingCard? mapped = _map(card);
    final Widget face = mapped == null
        ? const SizedBox.shrink()
        : ClipRRect(
            borderRadius: BorderRadius.circular(w * 0.16),
            child: SizedBox(
              width: w,
              height: h,
              child: pc.PlayingCardView(
                card: mapped,
                showBack: false,
              ),
            ),
          );
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.16),
        border: Border.all(color: borderColor, width: highlight ? 3.6 : 1.4),
        boxShadow: [
          if (highlight)
            BoxShadow(
              color: highlightColor.withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 1.5,
            ),
        ],
      ),
      child: face,
    );
  }

  pc.PlayingCard? _map(go.UiCard c) {
    final pc.Suit? suit = _toSuit(c.suit);
    final pc.CardValue? value = _toValue(c.rank);
    if (suit == null || value == null) return null;
    return pc.PlayingCard(suit, value);
  }

  pc.Suit? _toSuit(String raw) {
    final s = raw.trim().toUpperCase();
    switch (s) {
      case 'S':
      case 'SPADES':
      case '♠':
        return pc.Suit.spades;
      case 'H':
      case 'HEARTS':
      case '♥':
        return pc.Suit.hearts;
      case 'D':
      case 'DIAMONDS':
      case '♦':
        return pc.Suit.diamonds;
      case 'C':
      case 'CLUBS':
      case '♣':
        return pc.Suit.clubs;
      default:
        return null;
    }
  }

  pc.CardValue? _toValue(String raw) {
    final r = raw.trim().toUpperCase();
    switch (r) {
      case 'A':
        return pc.CardValue.ace;
      case 'K':
        return pc.CardValue.king;
      case 'Q':
        return pc.CardValue.queen;
      case 'J':
        return pc.CardValue.jack;
      case '10':
      case 'T':
        return pc.CardValue.ten;
      case '9':
        return pc.CardValue.nine;
      case '8':
        return pc.CardValue.eight;
      case '7':
        return pc.CardValue.seven;
      case '6':
        return pc.CardValue.six;
      case '5':
        return pc.CardValue.five;
      case '4':
        return pc.CardValue.four;
      case '3':
        return pc.CardValue.three;
      case '2':
        return pc.CardValue.two;
      default:
        return null;
    }
  }
}

class _WinnerFanInfo {
  final int seatIndex;
  final List<go.UiCard> holeCards;
  final Set<String> bestKeys;
  const _WinnerFanInfo({
    required this.seatIndex,
    required this.holeCards,
    required this.bestKeys,
  });
}

class _WinChipPop {
  final String text;
  final double centerX;
  final double startCenterY;
  final double endCenterY;
  final double width;
  final double height;
  final Color fillColor;
  final AnimationController controller;
  _WinChipPop({
    required this.text,
    required this.centerX,
    required this.startCenterY,
    required this.endCenterY,
    required this.width,
    required this.height,
    required this.fillColor,
    required this.controller,
  });
}

class _OutlinedText extends StatelessWidget {
  final String text;
  final Color fillColor;
  final Color outlineColor;
  final String fontFamily;
  const _OutlinedText({
    required this.text,
    this.fillColor = const Color(0xFF3BB143),
    this.outlineColor = Colors.white,
    this.fontFamily = 'PokerFont',
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _OutlinedTextPainter(
          text: text,
          fillColor: fillColor,
          outlineColor: outlineColor,
          fontFamily: fontFamily,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _OutlinedTextPainter extends CustomPainter {
  final String text;
  final Color fillColor;
  final Color outlineColor;
  final String fontFamily;
  const _OutlinedTextPainter({
    required this.text,
    required this.fillColor,
    required this.outlineColor,
    required this.fontFamily,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = text.trim();
    if (t.isEmpty || size.isEmpty) return;

    final w = size.width;
    final h = size.height;

    // Straight, bold number with outline. ~1.5x bigger than the old curved text.
    var fontSize = (h * 0.45 * 1.5).clamp(12.0, 92.0).toDouble();
    TextStyle base = TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w900,
      fontSize: fontSize,
      height: 1.0,
      letterSpacing: 0.2,
    );

    TextPainter fill = TextPainter(
      text: TextSpan(
        text: t,
        style: base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.fill
            ..color = fillColor,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout();

    final maxW = w * 0.92;
    if (fill.width > maxW && fill.width > 0) {
      final scale = (maxW / fill.width).clamp(0.55, 1.0);
      fontSize = (fontSize * scale).clamp(12.0, 92.0).toDouble();
      base = base.copyWith(fontSize: fontSize);
      fill = TextPainter(
        text: TextSpan(
          text: t,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.fill
              ..color = fillColor,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
      )..layout();
    }

    final double strokeWidth = (fontSize * 0.12).clamp(1.8, 5.8).toDouble();
    final stroke = TextPainter(
      text: TextSpan(
        text: t,
        style: base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeJoin = StrokeJoin.round
            ..color = outlineColor,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout();

    final Offset off = Offset((w - fill.width) / 2, (h - fill.height) / 2);
    stroke.paint(canvas, off);
    fill.paint(canvas, off);
  }

  @override
  bool shouldRepaint(covariant _OutlinedTextPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.fontFamily != fontFamily;
  }
}

String _winnerCardKey(go.UiCard c) {
  final rank = c.rank.trim().toUpperCase();
  final suit = _normalizeSuit(c.suit);
  return '$rank|$suit';
}

String _normalizeSuit(String raw) {
  final s = raw.trim().toUpperCase();
  switch (s) {
    case '♠':
    case 'SPADES':
    case 'S':
      return 'S';
    case '♥':
    case 'HEARTS':
    case 'H':
      return 'H';
    case '♦':
    case 'DIAMONDS':
    case 'D':
      return 'D';
    case '♣':
    case 'CLUBS':
    case 'C':
      return 'C';
    default:
      return s;
  }
}

/* ------------------------- Chrome widgets -------------------------------- */
List<Widget> _buildInfoPillsNearRenoir({
  required _Ui ui,
  required double pot,
  required double maxBet,
  required int activePlayers,
  required int seatCount,
  required List<Seat> seats,
  required List<SeatActionSnapshot> recentActions,
  required int heroIndex,
  required int currentTurn,
  required Offset origin,
  required Rect feltRect,
  required double railWidth,
  double minInset = 28,
  bool winnerOverlayVisible = false,
  String winnerName = '',
  String winnerAbout = '',
  bool winnerIsHero = false,
}) {
  // Position just above the wooden rail (slightly lifted so it doesn't touch).
  final double railTop = feltRect.top - railWidth;
  // Lift the pills a bit higher above the rail; use an estimated height so the row always floats clear.
  const double rowHeightEstimate = _kInfoPillHeight + 2;
  const double gapAboveRail = 10;
  final double topY = railTop - gapAboveRail - rowHeightEstimate;
  // Span the whole table width so pills can hug each side of Renoir.
  final double rowLeft = feltRect.left - railWidth + minInset;
  final double rowRight = minInset;

  Seat? _seatAt(int idx) {
    if (idx < 0 || idx >= seats.length) return null;
    return seats[idx];
  }

  String _firstName(String? full, {String fallback = ''}) {
    if (full == null || full.trim().isEmpty) return fallback;
    final parts = full.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : fallback;
  }

  final Seat? hero = _seatAt(heroIndex);
  final Seat? actor = _seatAt(currentTurn);
  final String heroName = _firstName(hero?.name, fallback: 'Hero');
  final String actorName = _firstName(actor?.name, fallback: 'Waiting…');
  final List<SeatActionSnapshot> history = [
    ...recentActions
        .where((a) => a.seatIndex != currentTurn && a.label.isNotEmpty)
  ];

  SeatActionSnapshot? _historyAt(int pos) {
    if (pos < 0 || pos >= history.length) return null;
    return history[pos];
  }

  SeatActionSnapshot? lastSnap = _historyAt(0);
  SeatActionSnapshot? prevSnap = _historyAt(1);

  String _actionLabelForSeat(int idx) {
    final fromHistory = history.firstWhere(
        (a) => a.seatIndex == idx && a.label.isNotEmpty,
        orElse: () =>
            const SeatActionSnapshot(seatIndex: -1, label: '', chips: 0));
    if (fromHistory.seatIndex == idx) return fromHistory.label;
    final s = _seatAt(idx);
    final raw = s?.lastAction ?? '';
    return raw.isNotEmpty ? raw : '-';
  }

  Color _colorForAction(SeatActionSnapshot? snap, Seat? seat) {
    if (seat?.folded == true ||
        (snap?.label.toLowerCase().startsWith('fold') ?? false)) {
      return const Color(0xFFC41230); // red for folded
    }
    final String label = snap?.label.toLowerCase() ?? '';
    if (label.startsWith('check'))
      return const Color(0xFFFFC857); // yellow for check
    if (label.startsWith('call'))
      return const Color(0xFF3BB143); // call button green
    if (label.startsWith('raise') || label.startsWith('bet'))
      return const Color(0xFF007FFF); // raise blue (matches button)
    if (label.startsWith('all-in'))
      return const Color(0xFFC41230); // all-in red
    return Colors.white70;
  }

  List<_ActionGridRow> _rows() {
    final Seat? snapSeat0 = actor;
    final Seat? snapSeat1 =
        lastSnap != null ? _seatAt(lastSnap!.seatIndex) : null;
    final Seat? snapSeat2 =
        prevSnap != null ? _seatAt(prevSnap!.seatIndex) : null;

    return [
      _ActionGridRow(
        tag: '',
        name: _firstName(snapSeat0?.name, fallback: '-'),
        action: _actionLabelForSeat(currentTurn),
        stack: snapSeat0 != null ? _fmtChips(snapSeat0.chips) : '-',
        color: Colors.white,
      ),
      _ActionGridRow(
        tag: '',
        name: _firstName(snapSeat1?.name, fallback: '-'),
        action: lastSnap?.label.isNotEmpty == true ? lastSnap!.label : '-',
        stack: snapSeat1 != null ? _fmtChips(snapSeat1.chips) : '-',
        color: _colorForAction(lastSnap, snapSeat1),
      ),
      _ActionGridRow(
        tag: '',
        name: _firstName(snapSeat2?.name, fallback: '-'),
        action: prevSnap?.label.isNotEmpty == true ? prevSnap!.label : '-',
        stack: snapSeat2 != null ? _fmtChips(snapSeat2.chips) : '-',
        color: _colorForAction(prevSnap, snapSeat2),
      ),
    ];
  }

  final String winnerNameTrimmed = winnerName.trim();
  if (winnerOverlayVisible && winnerNameTrimmed.isNotEmpty) {
    final Color bgSolid =
        winnerIsHero ? const Color(0xFF24B6FF) : const Color(0xFFFF2800);
    final Color bg = bgSolid.withValues(alpha: 0.40);
    final Color fg = winnerIsHero ? Colors.black : Colors.white;
    final Color border = bgSolid.withValues(alpha: 0.90);
    final String aboutText =
        winnerAbout.trim().isNotEmpty ? winnerAbout.trim() : '-';

    return [
      Positioned(
        left: rowLeft,
        right: rowRight,
        top: topY,
        child: IgnorePointer(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                fit: FlexFit.tight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 230,
                      maxWidth: 336,
                      minHeight: _kInfoPillHeight,
                      maxHeight: _kInfoPillHeight,
                    ),
                    child: _InfoPill(
                      minWidth: 230,
                      maxWidth: 336,
                      backgroundColor: bg,
                      borderColor: border,
                      glowColor: bgSolid,
                      child: Center(
                        child: Text(
                          winnerNameTrimmed,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                fit: FlexFit.tight,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 230,
                      maxWidth: 300,
                      minHeight: _kInfoPillHeight,
                      maxHeight: _kInfoPillHeight,
                    ),
                    child: _InfoPill(
                      minWidth: 230,
                      maxWidth: 300,
                      backgroundColor: bg,
                      borderColor: border,
                      glowColor: bgSolid,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            aboutText,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  return [
    Positioned(
      left: rowLeft,
      right: rowRight,
      top: topY,
      child: IgnorePointer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 230, // further widened for odometer pill
                    maxWidth: 336,
                    minHeight: _kInfoPillHeight,
                    maxHeight: _kInfoPillHeight,
                  ),
                  child: _InfoPill(
                    minWidth: 230,
                    maxWidth: 336,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Players Active',
                                    style: TextStyle(
                                      color: Color(0xFFFFC857),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Call / Bet',
                                    style: TextStyle(
                                      color: Color(0xFFFFC857),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Pot',
                                    style: TextStyle(
                                      color: Color(0xFFFFC857),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _RollingOdometer(
                                        value: '$activePlayers/$seatCount',
                                        digitStyle: const TextStyle(
                                          color: Color(0xFFFFC857),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          letterSpacing: 0.3,
                                        ),
                                        nonDigitStyle: const TextStyle(
                                          color: Color(0xFFFFC857),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          letterSpacing: 0.2,
                                        ),
                                        keyPrefix: 'players',
                                        digitWidth: 15,
                                        digitHeight: 19,
                                      ),
                                      const SizedBox(height: 4),
                                      _RollingOdometer(
                                        value: () {
                                          final double totalMaxBet = maxBet;
                                          final double totalHandBet =
                                              seats.isEmpty
                                                  ? 0
                                                  : seats
                                                      .map((s) => s
                                                          .contributedThisHand
                                                          .toDouble())
                                                      .fold(0, math.max);
                                          final bool showSeat =
                                              activePlayers > 0 &&
                                                  currentTurn >= 0 &&
                                                  currentTurn < seats.length &&
                                                  !seats[currentTurn].busted &&
                                                  !seats[currentTurn].folded;
                                          final double seatBet = showSeat
                                              ? seats[currentTurn]
                                                  .bet
                                                  .toDouble()
                                              : 0.0;
                                          final double toCall = math.max(
                                              0.0, totalMaxBet - seatBet);
                                          return '${_fmtChipsFull(toCall, zeroPad: true)}/${_fmtChipsFull(totalHandBet, zeroPad: true)}';
                                        }(),
                                        digitStyle: const TextStyle(
                                          color: Color(0xFFFFC857),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          letterSpacing: 0.3,
                                        ),
                                        nonDigitStyle: const TextStyle(
                                          color: Color(0xFFFFC857),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                        keyPrefix: 'bet',
                                        digitWidth: 17,
                                        digitHeight: 19,
                                      ),
                                      const SizedBox(height: 4),
                                      _RollingOdometer(
                                        value:
                                            _fmtChipsFull(pot, zeroPad: true),
                                        digitStyle: const TextStyle(
                                          color: Color(0xFFFFC857),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          letterSpacing: 0.3,
                                        ),
                                        nonDigitStyle: const TextStyle(
                                          color: Color(0xFFFFC857),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                        keyPrefix: 'pot',
                                        digitWidth: 17,
                                        digitHeight: 19,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              fit: FlexFit.tight,
              child: Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 230, // align with widened pot info pill
                    maxWidth: 300,
                    minHeight: _kInfoPillHeight,
                    maxHeight: _kInfoPillHeight,
                  ),
                  child: _InfoPill(
                    minWidth: 230,
                    maxWidth: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ..._rows(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ];
}

class _VenueChip extends StatelessWidget {
  final String flagPath;
  final String venueName;
  const _VenueChip(
      {super.key, required this.flagPath, required this.venueName});

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle =
        Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    final Color textColor = labelStyle.color ?? Colors.white;
    final TextStyle textStyle = labelStyle.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: textColor,
    );

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 22, height: 16, child: _Flag(flagPath: flagPath)),
            const SizedBox(width: 8),
            Text(
              venueName,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  final String flagPath;
  const _Flag({required this.flagPath});

  @override
  Widget build(BuildContext context) {
    if (flagPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(flagPath, fit: BoxFit.cover);
    }
    return Image.asset(flagPath, fit: BoxFit.cover);
  }
}

class _AnimatedInfoText extends StatelessWidget {
  const _AnimatedInfoText({
    required this.text,
    required this.style,
    this.align = TextAlign.center,
    this.keyPrefix,
  });

  final String text;
  final TextStyle style;
  final TextAlign align;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.18),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: Text(
        text,
        key: ValueKey('${keyPrefix ?? 'info'}-$text'),
        textAlign: align,
        style: style,
      ),
    );
  }
}

class _RollingOdometer extends StatefulWidget {
  const _RollingOdometer({
    required this.value,
    required this.digitStyle,
    required this.nonDigitStyle,
    this.keyPrefix,
    this.digitWidth = 14.4,
    this.digitHeight = 19.8,
  });

  final String value;
  final TextStyle digitStyle;
  final TextStyle nonDigitStyle;
  final String? keyPrefix;
  final double digitWidth;
  final double digitHeight;

  @override
  State<_RollingOdometer> createState() => _RollingOdometerState();
}

class _RollingOdometerState extends State<_RollingOdometer> {
  @override
  Widget build(BuildContext context) {
    final chars = widget.value.split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < chars.length; i++)
          _RollingGlyph(
            char: chars[i],
            style: widget.digitStyle,
            nonDigitStyle: widget.nonDigitStyle,
            key: ValueKey('${widget.keyPrefix ?? 'odo'}-$i-${chars[i]}'),
            width: widget.digitWidth,
            height: widget.digitHeight,
          ),
      ],
    );
  }
}

class _RollingGlyph extends StatelessWidget {
  const _RollingGlyph({
    required this.char,
    required this.style,
    required this.nonDigitStyle,
    required this.width,
    required this.height,
    super.key,
  });

  final String char;
  final TextStyle style;
  final TextStyle nonDigitStyle;
  final double width;
  final double height;

  bool get _isDigit => RegExp(r'^[0-9]$').hasMatch(char);

  @override
  Widget build(BuildContext context) {
    if (!_isDigit) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Text(
          char,
          style: nonDigitStyle,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 0.4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white70, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return ClipRect(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            ),
          );
        },
        child: Center(
          key: ValueKey(char),
          child: Text(
            char,
            style: style.copyWith(color: Colors.black),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.child,
    this.minWidth = 200,
    this.maxWidth = 320,
    this.backgroundColor,
    this.borderColor,
    this.glowColor,
  });

  final Widget child;
  final double minWidth;
  final double maxWidth;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.white.withOpacity(0.08);
    final bc = borderColor ?? Colors.white70;
    final gc = glowColor;
    final List<BoxShadow>? shadows = gc == null
        ? null
        : <BoxShadow>[
            BoxShadow(
              color: gc.withValues(alpha: 0.55),
              blurRadius: 18,
              spreadRadius: 1,
              offset: Offset.zero,
            ),
            BoxShadow(
              color: gc.withValues(alpha: 0.30),
              blurRadius: 34,
              spreadRadius: 7,
              offset: Offset.zero,
            ),
          ];
    return Container(
      // Extra horizontal padding so text/odometers don’t hug the pill edges.
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: bc, width: 1)),
        color: bg,
        shadows: shadows,
      ),
      child: child,
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool alignCenter;
  const _MiniStat({
    required this.label,
    required this.value,
    this.alignCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignCenter ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: alignCenter ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.3,
          ),
        ),
        Text(
          value,
          textAlign: alignCenter ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _RoleGridRow extends StatelessWidget {
  final String title;
  final String chips;
  final String bet;
  final String tag;
  const _RoleGridRow({
    required this.title,
    required this.chips,
    required this.bet,
    required this.tag,
    this.minWidth = 0,
    this.centerText = false,
  });
  final double minWidth;
  final bool centerText;

  @override
  Widget build(BuildContext context) {
    const TextStyle labelStyle = TextStyle(
      color: Colors.white60,
      fontWeight: FontWeight.w600,
      fontSize: 11,
      letterSpacing: 0.3,
    );
    const TextStyle valueStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      fontSize: 13,
      letterSpacing: 0.2,
    );

    Widget cell(String label, String value) => Column(
          crossAxisAlignment:
              centerText ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle, overflow: TextOverflow.ellipsis),
            Text(value,
                style: valueStyle,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false),
          ],
        );

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: cell(tag, title),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: cell('Bet', bet),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: cell('Stack', chips),
          ),
        ],
      ),
    );
  }
}

class _ActionGridRow extends StatelessWidget {
  final String tag;
  final String name;
  final String action;
  final String stack;
  final Color color;
  const _ActionGridRow({
    required this.tag,
    required this.name,
    required this.action,
    required this.stack,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle body = TextStyle(
      color: color,
      fontWeight: FontWeight.w700,
      fontSize: 12.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name.isNotEmpty ? name : '-',
              style: body,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              action.isNotEmpty ? action : '-',
              style: body,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stack.isNotEmpty ? stack : '-',
              style: body,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtChips(num value) {
  final nf = NumberFormat.compact();
  return nf.format(value);
}

String _fmtChipsFull(num value, {bool zeroPad = false}) {
  final String s = value.round().toString();
  if (zeroPad && s == '0') return '000';
  return s;
}
