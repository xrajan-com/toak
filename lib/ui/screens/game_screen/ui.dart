// ===============================
// lib/ui/screens/game_screen/ui.dart
// ===============================

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui show TextDirection;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' show SingleTickerProviderStateMixin;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';

import '../../../game/core.dart' as gc show Card, Rank, Suit, rankValue;
import '../../../game/game_engine.dart' show GameEngine, GameEngineBotLogic;
import '../../../game/equity/hero_equity.dart'
    show
        HeroEquityEngine,
        HeroEquityEstimate,
        HeroEquityRequest,
        HeroEquitySeat,
        VisibleOpponentRange;
import '../../../game/equity/hero_action_guidance.dart'
    show HeroActionRecommendation, HeroTablePosition, recommendHeroAction;
import '../../../game/hand_evaluator.dart'
    show HandCategory, HandEvaluator, HandRank;
import 'clock.dart' show DayDateClock, DayDateClockDisplayMode;
import 'models.dart' show GCard;
import 'seat_layout.dart' show stadiumSeatTopLeftPositions;
import 'table.dart'
    show PlayerSafeFeltClipper, WoodType, playerSafeFeltRRect; // wood visuals
import 'action_bar.dart';
import 'action_burst.dart';
import 'players.dart'
    show
        Seat,
        SeatTopBubbleOverlay,
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
import 'hero_messages.dart' show buildVisibleHeroGuidanceMessage;
import 'hand_hud.dart'
    show HandHudSeatState, HandHudSnapshot, buildHandHudSnapshot;
import 'seat_card_layout.dart'
    show
        SeatCardFanLayout,
        centeredFanCardCenters,
        fitHeroCardRow,
        fitSeatCardFanBehindAvatar,
        kHeroHoleCardScale,
        kBotHoleCardScale,
        seatAvatarVisualRect;
import '../../../game/events.dart' show EngineEvent;

/* ------------------------------ Tunables --------------------------------- */

const double _kSeatScale = 0.85;
const double _kTableScale = 0.94;
const double _kTableVisualScale = 1.06;
const double _kSeatMinW = kSeatDiameterPx * 0.7 * _kSeatScale;
const double _kSeatMinH = kSeatDiameterPx * 0.7 * _kSeatScale;
// Nudge seats off the wood rail so avatars just kiss the outer edge.
const double _kSeatVisualMarginPx = 5.0;
const BlindChipPlacement _kBlindChipPlacement = BlindChipPlacement.felt;
const double _kPushDownFrac = 0.10;
const int _kWinnerBlinkCycles = 4;
const double _kRailWidthPx = 34.0 * 0.72;
const String _kPrimaryFontFamily = 'OpenSans';
const TextStyle _kTopPillTextStyle = TextStyle(
  color: Colors.white,
  fontFamily: _kPrimaryFontFamily,
  fontWeight: FontWeight.w700,
  fontSize: 12.8,
  letterSpacing: 0.22,
);
const EdgeInsets _kTopPillPadding =
    EdgeInsets.symmetric(horizontal: 18, vertical: 11);
const Color _kActionCallColor = Color(0xFF3BB143);
const Color _kActionRaiseColor = Color(0xFF007FFF);
const Color _kActionFoldColor = Color(0xFFC41230);
// Hero hole cards are intentionally larger than the base reveal size.
const double _kSeatCardWinnerScale = 0.992;
const double _kSeatCardHeroScale = kHeroHoleCardScale;
const double _kSeatCardOppShowScale = 1.00;
const double _kSeatCardFanOverlap = 0.50;
const double _kSeatCardHeroFanDeg = 10.0;
const double _kSeatCardOppFanDeg = 8.0;
const double _kSeatCardHeroSideBySideGap = 1.05;
const double _kSeatAvatarScale = 0.85;
const Color _kHeroWinOutline = Color(0xFF20D9FF);
const Color _kBotWinOutline = Color(0xFFFF2800);
const Color _kHandHighlightOutline = Color(0xFFFFD100);
const TextStyle _kSidePillTextStyle = TextStyle(
  color: Colors.white,
  fontFamily: _kPrimaryFontFamily,
  fontWeight: FontWeight.w700,
  fontSize: 15.0,
  letterSpacing: 0.24,
  height: 1.0,
);
const String _kPopupFontFamily = _kPrimaryFontFamily;
const Duration _kFoldedSeatCardFadeDuration = Duration(seconds: 2);

String _compactActionLabel(String label) {
  final up = label.toUpperCase().trim();
  return up
      .replaceAll('RAISE TO ', 'RAISE ')
      .replaceAll('ALL-IN ', 'ALL-IN ')
      .replaceAll('  ', ' ');
}

bool _isCountdownLabel(String label) {
  return RegExp(r'^\d+\s*S$').hasMatch(label.trim().toUpperCase());
}

Color _actionColorForLabel(String label) {
  final lower = label.toLowerCase();
  if (lower.startsWith('call') || lower.startsWith('check')) {
    return _kActionCallColor;
  }
  if (lower.startsWith('raise') || lower.startsWith('bet')) {
    return _kActionRaiseColor;
  }
  if (lower.startsWith('all-in') || lower.startsWith('all in')) {
    return _kActionFoldColor;
  }
  if (lower.startsWith('fold')) {
    return _kActionFoldColor;
  }
  return Colors.white;
}

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

class _HeroAggressorInfo {
  final int seatIndex;
  final String name;
  final String label;

  const _HeroAggressorInfo({
    required this.seatIndex,
    required this.name,
    required this.label,
  });
}

class _HeroMessageContext {
  final int livePlayers;
  final _HeroAggressorInfo? aggressor;
  final String handName;
  final String hopeHand;
  final String? boardBestHand;

  const _HeroMessageContext({
    required this.livePlayers,
    required this.aggressor,
    required this.handName,
    required this.hopeHand,
    required this.boardBestHand,
  });
}

class PausedResumeOverlay extends StatelessWidget {
  final VoidCallback onPressed;

  const PausedResumeOverlay({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tap anywhere to resume game',
      onTap: onPressed,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.22),
                  ),
                ),
                Center(
                  child: IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 116,
                          height: 116,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.72),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.50),
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 82,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'TAP ANYWHERE TO RESUME',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: _kPrimaryFontFamily,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.8,
                            shadows: <Shadow>[
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ------------------------------- Metrics --------------------------------- */
class _Ui {
  final double tableW, tableH;
  final double seatMaxW, seatH;
  final double cardW, cardH;
  final double renoirR;
  final double tableVisualScale;
  final double tableVerticalShift;

  _Ui(double w, double h)
      : // The logical viewport adapts to phone/web aspect ratios. A single
        // visual transform then enlarges the complete table group, including
        // every rail, seat, card, badge, effect, and dealer offset.
        tableW = (() {
          final double adaptiveMargin =
              (w * 0.012).clamp(10.0, 30.0).toDouble();
          final double raw = (w - adaptiveMargin * 2) * _kTableScale;
          final double minWidth = math.min(300.0, w);
          final double maxWidth = math.max(minWidth, w - adaptiveMargin * 2);
          return raw.clamp(minWidth, maxWidth).toDouble();
        })(),
        tableH = (() {
          return (h * 0.59).clamp(260.0, 780.0).toDouble();
        })(),
        cardW = (() {
          final double designScale =
              math.min(w / 1024, h / 576).clamp(0.75, 1.75).toDouble();
          return (52.8 * designScale).clamp(52.0, 96.0).toDouble();
        })(),
        cardH = (() {
          final double designScale =
              math.min(w / 1024, h / 576).clamp(0.75, 1.75).toDouble();
          return (76.0 * designScale).clamp(76.0, 132.0).toDouble();
        })(),
        seatH = (() {
          final double designScale =
              math.min(w / 1024, h / 576).clamp(0.75, 1.75).toDouble();
          return kSeatDiameterPx * 0.7 * _kSeatScale * 1.2 * designScale;
        })(),
        seatMaxW = (() {
          final double designScale =
              math.min(w / 1024, h / 576).clamp(0.75, 1.75).toDouble();
          final double seatHeight =
              kSeatDiameterPx * 0.7 * _kSeatScale * 1.2 * designScale;
          return (seatHeight * 2.12)
              .clamp(seatHeight * 1.72, seatHeight * 2.18)
              .toDouble();
        })(),
        renoirR = (() {
          final double designScale =
              math.min(w / 1024, h / 576).clamp(0.75, 1.75).toDouble();
          return (32.0 * designScale).clamp(30.0, 54.0).toDouble();
        })(),
        tableVisualScale = _kTableVisualScale,
        tableVerticalShift = (() {
          final double raw = h * 0.024;
          return -raw.clamp(12.0, 24.0).toDouble();
        })();
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
  final VoidCallback onShowHandExamples;
  final VoidCallback onShowHandRankings;
  final VoidCallback onShowBotLearning;
  final Future<void> Function()? onShowScoreboard;
  final Future<void> Function()? onShowPreviousHand;
  final Future<void> Function()? onShowSettings;
  final bool showBotLearning;
  final int startingStack;

  final Color felt;
  final WoodType wood;
  final bool showDealerBadge;

  final DealerAvatarStyle dealerAvatarStyle;
  final double pot;
  final List<GCard> board;
  final List<Seat> seats;
  final Set<int> activeBloodStains;
  final int currentTurn, dealerIndex, sbIndex, bbIndex, heroIndex;
  final List<SeatActionSnapshot> recentActions;
  final bool isHeroTurn;
  final int? heroTurnSecondsRemaining;
  final bool showHandHighlight;
  final List<GCard> handHighlightCards;
  final bool showActionFlash;
  final String actionFlashName;
  final String actionFlashLabel;
  final String liveAnnouncement;
  final bool paused;
  final bool showPauseOverlay;
  final bool reduceMotion;
  final VoidCallback onTogglePause;
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
  final bool canCallOrCheck, canRaise, canAllIn, canFold;
  final ValueChanged<double> onRaiseAmountChanged;

  // Scripted laps (when no engine)
  final ValueChanged<int>? onScriptLap;

  final VoidCallback onCheckOrCall, onFold, onBetOrRaise, onAllIn, onToggleShow;

  // Renoir sprite alignment
  final double renoirLiftPx;

  // Chrome
  final String venueTimeZoneId;

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
    required this.onShowHandExamples,
    required this.onShowHandRankings,
    required this.onShowBotLearning,
    this.onShowScoreboard,
    this.onShowPreviousHand,
    this.onShowSettings,
    required this.showBotLearning,
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
    required this.dealerIndex,
    required this.sbIndex,
    required this.bbIndex,
    required this.heroIndex,
    required this.recentActions,
    required this.isHeroTurn,
    this.heroTurnSecondsRemaining,
    this.showHandHighlight = false,
    this.handHighlightCards = const <GCard>[],
    this.showActionFlash = false,
    this.actionFlashName = '',
    this.actionFlashLabel = '',
    this.liveAnnouncement = '',
    required this.paused,
    this.showPauseOverlay = true,
    this.reduceMotion = false,
    required this.onTogglePause,
    required this.toCall,
    required this.showShuffle,
    required this.showDeckPile,
    required this.showToggleVisible,
    required this.heroShow,
    required this.potPulse,
    required this.raiseAmount,
    required this.minRaise,
    required this.maxRaise,
    this.canCallOrCheck = true,
    this.canRaise = true,
    this.canAllIn = true,
    this.canFold = true,
    required this.onRaiseAmountChanged,
    required this.onCheckOrCall,
    required this.onFold,
    required this.onBetOrRaise,
    required this.onAllIn,
    required this.onToggleShow,
    required this.startingStack,
    this.renoirLiftPx = 0,
    required this.venueTimeZoneId,
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
  late final AnimationController _winnerBlinkCtl;
  late final Animation<double> _winnerBlink;
  int _winnerBlinkCount = 0;
  List<_WinnerCycleEntry> _winnerCycle = const [];
  int _winnerCycleIndex = 0;

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
  late final AnimationController _heroPillGlowCtl;
  late final Animation<double> _heroPillGlow;
  bool _heroPillGlowActive = false;
  String _heroIdleMessageStable = '';
  String _heroIdleMessageProbabilityKey = '';
  String _heroMessageContextCacheKey = '';
  _HeroMessageContext? _heroMessageContextCache;
  final HeroEquityEngine _heroEquityEngine = const HeroEquityEngine();
  String _heroEquityRequestKey = '';
  HeroEquityEstimate? _heroEquityEstimate;
  int _heroEquityGeneration = 0;

  @override
  void initState() {
    super.initState();
    _heroPillGlowCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _heroPillGlow = CurvedAnimation(
      parent: _heroPillGlowCtl,
      curve: Curves.linear,
    );
    _winnerBlinkCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _winnerBlink = CurvedAnimation(
      parent: _winnerBlinkCtl,
      curve: Curves.easeInOut,
    );
    _winnerBlinkCtl.addStatusListener(_handleWinnerBlinkStatus);
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
            final entries = _buildWinnerCycleEntries(winners);
            final _WinnerCycleEntry? first =
                entries.isNotEmpty ? entries.first : null;

            setState(() {
              _hideAllCards = false;
              _handWinnerOverlayVisible = true;
              _winnerCycle = entries;
              _winnerCycleIndex = 0;
              _handWinnerIsHero = first?.isHero ?? false;
              _handWinnerName = first?.name ?? '';
              _handWinnerAbout = first?.about ?? '';
            });
            _startWinnerBlink();
            _startWinChipPops();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _burstWinnerCelebration();
            });
          } else {
            _stopWinChipPops();
            _stopWinnerBlink();
            setState(() {
              _winnerFans = const [];
              _handWinnerOverlayVisible = false;
              _handWinnerIsHero = false;
              _handWinnerName = '';
              _handWinnerAbout = '';
              _winnerCycle = const [];
              _winnerCycleIndex = 0;
            });
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _syncHeroPillGlow(bool active) {
    if (widget.reduceMotion) active = false;
    if (_heroPillGlowActive == active) return;
    _heroPillGlowActive = active;
    if (active) {
      _heroPillGlowCtl.repeat();
    } else {
      _heroPillGlowCtl.stop();
      _heroPillGlowCtl.value = 0.0;
    }
  }

  String? _resolveHeroName() {
    if (widget.heroIndex >= 0 && widget.heroIndex < widget.seats.length) {
      return widget.seats[widget.heroIndex].name;
    }
    for (final s in widget.seats) {
      if (s.isHero) return s.name;
    }
    return null;
  }

  List<_WinnerCycleEntry> _buildWinnerCycleEntries(
      List<go.WinnerLine> winners) {
    if (winners.isEmpty) return const [];
    final heroName = _resolveHeroName();
    bool sameName(String a, String b) =>
        a.trim().toLowerCase() == b.trim().toLowerCase();

    final seen = <String>{};
    final entries = <_WinnerCycleEntry>[];
    for (final w in winners) {
      final String name =
          w.playerName.trim().isNotEmpty ? w.playerName.trim() : '-';
      final String about = w.about.trim().isNotEmpty ? w.about.trim() : '-';
      final String key = name.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      entries.add(_WinnerCycleEntry(
        name: name,
        about: about,
        isHero: heroName != null && sameName(name, heroName),
      ));
    }
    return entries;
  }

  void _applyWinnerEntry(_WinnerCycleEntry? entry) {
    _handWinnerName = entry?.name ?? '';
    _handWinnerAbout = entry?.about ?? '';
    _handWinnerIsHero = entry?.isHero ?? false;
  }

  void _advanceWinnerCycle() {
    if (_winnerCycle.isEmpty) return;
    _winnerCycleIndex = (_winnerCycleIndex + 1) % _winnerCycle.length;
    _applyWinnerEntry(_winnerCycle[_winnerCycleIndex]);
    if (mounted) setState(() {});
  }

  void _startWinnerBlink() {
    _winnerBlinkCount = 0;
    _winnerBlinkCtl.stop();
    _winnerBlinkCtl.value = 0.0;
    if (widget.reduceMotion ||
        !_handWinnerOverlayVisible ||
        _winnerCycle.isEmpty) {
      return;
    }
    _winnerBlinkCtl.repeat(reverse: true);
  }

  void _stopWinnerBlink() {
    _winnerBlinkCount = 0;
    _winnerBlinkCtl.stop();
    _winnerBlinkCtl.value = 0.0;
  }

  void _handleWinnerBlinkStatus(AnimationStatus status) {
    if (!_handWinnerOverlayVisible || _winnerCycle.isEmpty) return;
    if (status == AnimationStatus.dismissed) {
      _winnerBlinkCount += 1;
      if (_winnerBlinkCount >= _kWinnerBlinkCycles) {
        _winnerBlinkCtl.stop();
        _winnerBlinkCtl.value = 0.0;
        return;
      }
      _advanceWinnerCycle();
    }
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
    final bool hasDealtCards = widget.board.isNotEmpty ||
        widget.seats.any((s) => s.hole.isNotEmpty) ||
        _engineHasDealtCards();

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

    if (!RenoirSignals.holeCardsVisible.value &&
        hasDealtCards &&
        !dealingActive &&
        !_handWinnerOverlayVisible) {
      RenoirSignals.holeCardsVisible.value = true;
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

  void _resetHeroIdleMessageState() {
    _heroIdleMessageStable = '';
    _heroIdleMessageProbabilityKey = '';
  }

  bool _engineHasDealtCards() {
    final e = widget.engine;
    if (e == null) return false;
    try {
      final community = (e as dynamic).community;
      if (community is List && community.isNotEmpty) return true;
    } catch (_) {}
    try {
      final players = (e as dynamic).players;
      if (players is List) {
        for (final p in players) {
          try {
            final hole = (p as dynamic).hole;
            if (hole is List && hole.isNotEmpty) return true;
          } catch (_) {}
        }
      }
    } catch (_) {}
    return false;
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
        heroWonTop ? const Color(0xFF20D9FF) : const Color(0xFFFF2800);

    final double labelW = ui.cardW * 2.5;
    final double labelH = ui.cardH * 1.5;
    final double startX = _boardCenter.dx;
    final double startY = _boardCenter.dy;

    // Rest position: centered vertically between the upper wooden rail (felt edge)
    // and the top of the community cards row.
    final double endY = _boardInfoCenterY(ui: ui, labelH: labelH);

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
    if (widget.reduceMotion) return;
    final burst = _actionBurstKey.currentState;
    if (burst == null) return;
    final root = context.findRenderObject();
    if (root is! RenderBox) return;
    final int remainingPlayers =
        widget.seats.where((seat) => !seat.busted && seat.chips > 0).length;
    final double intensity =
        winnerBurstIntensityForRemainingPlayers(remainingPlayers);

    final barRectG = _globalRectForKey(_actionBarKey);
    if (barRectG == null) {
      burst.burstAt(
        Offset(root.size.width / 2, root.size.height - 140),
        intensity: intensity,
      );
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
    burst.burstAtMany(origins, intensity: intensity);
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

  double _boardInfoCenterY({
    required _Ui ui,
    required double labelH,
  }) {
    final double railBottomY = _feltRect.top;
    final double communityTopY = _boardCenter.dy - ui.cardH / 2;
    final double targetCenterY = (railBottomY + communityTopY) / 2;
    final double minCenterY = labelH / 2 + 6;
    return math.max(minCenterY, targetCenterY);
  }

  HeroEquityRequest? _heroEquityRequest(Seat? heroSeat) {
    if (widget.heroIndex < 0 || widget.heroIndex >= widget.seats.length) {
      return null;
    }
    final List<gc.Card> heroCards = _heroHoleEngineCards(heroSeat);
    if (heroCards.length < 2) return null;
    final List<gc.Card> boardCards = _boardEngineCards();
    final Map<int, String> publicActions = <int, String>{};
    for (final action in widget.recentActions) {
      publicActions.putIfAbsent(action.seatIndex, () => action.label);
    }

    return HeroEquityRequest(
      heroSeatIndex: widget.heroIndex,
      heroHole: heroCards,
      revealedBoard: boardCards,
      visiblePot: widget.pot,
      seats: <HeroEquitySeat>[
        for (int index = 0; index < widget.seats.length; index++)
          HeroEquitySeat(
            seatIndex: index,
            active: !widget.seats[index].busted && !widget.seats[index].folded,
            allIn: widget.seats[index].allIn,
            contribution: math.max(0, widget.seats[index].contributedThisHand),
            range: index == widget.heroIndex
                ? const VisibleOpponentRange.neutral()
                : VisibleOpponentRange.fromPublicAction(
                    publicActions[index],
                    allIn: widget.seats[index].allIn,
                  ),
          ),
      ],
    );
  }

  HeroEquityEstimate? _visibleHeroEquity(Seat? heroSeat) {
    final HeroEquityRequest? request = _heroEquityRequest(heroSeat);
    if (request == null) return null;
    final String key = request.cacheKey;
    if (_heroEquityRequestKey == key) return _heroEquityEstimate;

    final int generation = ++_heroEquityGeneration;
    _heroEquityRequestKey = key;
    final HeroEquityEstimate? immediate =
        _heroEquityEngine.immediateEstimate(request);
    _heroEquityEstimate =
        immediate ?? _heroEquityEngine.previewEstimate(request);
    if (immediate == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _heroEquityGeneration) return;
        unawaited(_calculateVisibleHeroEquity(request, key, generation));
      });
    }
    return _heroEquityEstimate;
  }

  Future<void> _calculateVisibleHeroEquity(
    HeroEquityRequest request,
    String key,
    int generation,
  ) async {
    final HeroEquityEstimate? estimate = await _heroEquityEngine.estimate(
      request,
      shouldCancel: () =>
          !mounted ||
          generation != _heroEquityGeneration ||
          key != _heroEquityRequestKey,
    );
    if (!mounted ||
        estimate == null ||
        generation != _heroEquityGeneration ||
        key != _heroEquityRequestKey) {
      return;
    }
    setState(() {
      _heroEquityEstimate = estimate;
    });
  }

  gc.Rank? _rankFromSymbol(String raw) {
    switch (raw.trim().toUpperCase()) {
      case '2':
        return gc.Rank.two;
      case '3':
        return gc.Rank.three;
      case '4':
        return gc.Rank.four;
      case '5':
        return gc.Rank.five;
      case '6':
        return gc.Rank.six;
      case '7':
        return gc.Rank.seven;
      case '8':
        return gc.Rank.eight;
      case '9':
        return gc.Rank.nine;
      case 'T':
      case '10':
        return gc.Rank.ten;
      case 'J':
        return gc.Rank.jack;
      case 'Q':
        return gc.Rank.queen;
      case 'K':
        return gc.Rank.king;
      case 'A':
        return gc.Rank.ace;
    }
    return null;
  }

  gc.Suit? _suitFromSymbol(String raw) {
    switch (raw.trim()) {
      case '♣':
        return gc.Suit.clubs;
      case '♦':
        return gc.Suit.diamonds;
      case '♥':
        return gc.Suit.hearts;
      case '♠':
        return gc.Suit.spades;
    }
    return null;
  }

  gc.Card? _toEngineCard(GCard card) {
    final gc.Rank? rank = _rankFromSymbol(card.rank);
    final gc.Suit? suit = _suitFromSymbol(card.suit);
    if (rank == null || suit == null) return null;
    return gc.Card(rank, suit);
  }

  String _cardKey(gc.Card card) => '${card.rank.index}:${card.suit.index}';

  List<gc.Card> _boardEngineCards() => widget.board
      .map(_toEngineCard)
      .whereType<gc.Card>()
      .toList(growable: false);

  List<gc.Card> _heroHoleEngineCards(Seat? heroSeat) =>
      (heroSeat?.hole ?? const <GCard>[])
          .map(_toEngineCard)
          .whereType<gc.Card>()
          .toList(growable: false);

  String _shortSeatName(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return 'SOMEONE';
    final String first = trimmed.split(RegExp(r'\s+')).first;
    return first.toUpperCase();
  }

  List<gc.Card> _standardDeck() {
    return <gc.Card>[
      for (final gc.Suit suit in gc.Suit.values)
        for (final gc.Rank rank in gc.Rank.values) gc.Card(rank, suit),
    ];
  }

  _HeroAggressorInfo? _latestAggressorInfo() {
    for (final snap in widget.recentActions) {
      final String label = snap.label.trim().toUpperCase();
      final bool aggressive = label.startsWith('RAISE') ||
          label.startsWith('BET') ||
          label.startsWith('ALL-IN') ||
          label.startsWith('ALL IN');
      if (!aggressive) continue;
      if (snap.seatIndex < 0 || snap.seatIndex >= widget.seats.length) continue;
      return _HeroAggressorInfo(
        seatIndex: snap.seatIndex,
        name: _shortSeatName(widget.seats[snap.seatIndex].name),
        label: label,
      );
    }
    return null;
  }

  String? _latestHeroActionLabel() {
    if (widget.heroIndex < 0 || widget.heroIndex >= widget.seats.length) {
      return null;
    }
    for (final snap in widget.recentActions) {
      if (snap.seatIndex != widget.heroIndex) continue;
      final String label = snap.label.trim();
      if (label.isEmpty || _isCountdownLabel(label)) continue;
      return label;
    }
    return null;
  }

  int _livePlayersInHandCount() {
    return widget.seats.where((seat) => !seat.busted && !seat.folded).length;
  }

  HeroTablePosition _heroTablePosition() {
    final int seatCount = widget.seats.length;
    final int hero = widget.heroIndex;
    if (seatCount < 2 || hero < 0 || hero >= seatCount) {
      return HeroTablePosition.unknown;
    }
    if (hero == widget.dealerIndex) return HeroTablePosition.button;
    if (hero == widget.sbIndex) return HeroTablePosition.smallBlind;
    if (hero == widget.bbIndex) return HeroTablePosition.bigBlind;
    if (widget.bbIndex < 0 || widget.bbIndex >= seatCount) {
      return HeroTablePosition.unknown;
    }

    final List<int> fieldPositions = <int>[];
    int index = (widget.bbIndex + 1) % seatCount;
    for (int step = 0; step < seatCount; step++) {
      if (index == widget.dealerIndex) break;
      if (!widget.seats[index].busted) fieldPositions.add(index);
      index = (index + 1) % seatCount;
    }
    final int ordinal = fieldPositions.indexOf(hero);
    if (ordinal < 0) return HeroTablePosition.unknown;
    if (fieldPositions.length == 1) return HeroTablePosition.late;

    final double progress = ordinal / (fieldPositions.length - 1);
    if (progress <= 0.25) return HeroTablePosition.early;
    if (progress < 0.75) return HeroTablePosition.middle;
    return HeroTablePosition.late;
  }

  bool _boardHasPair(List<gc.Card> boardCards) {
    final Map<int, int> counts = <int, int>{};
    for (final card in boardCards) {
      final int v = gc.rankValue(card.rank);
      counts[v] = (counts[v] ?? 0) + 1;
      if ((counts[v] ?? 0) >= 2) return true;
    }
    return false;
  }

  HandRank? _currentHeroHandRank(
      List<gc.Card> heroCards, List<gc.Card> boardCards) {
    final List<gc.Card> total = <gc.Card>[...heroCards, ...boardCards];
    if (total.length < 5) return null;
    return HandEvaluator.evaluate(total);
  }

  bool _hasHeroFlushDraw(List<gc.Card> heroCards, List<gc.Card> boardCards) {
    final Map<gc.Suit, int> total = <gc.Suit, int>{};
    final Map<gc.Suit, int> hero = <gc.Suit, int>{};
    for (final card in heroCards) {
      total[card.suit] = (total[card.suit] ?? 0) + 1;
      hero[card.suit] = (hero[card.suit] ?? 0) + 1;
    }
    for (final card in boardCards) {
      total[card.suit] = (total[card.suit] ?? 0) + 1;
    }
    for (final gc.Suit suit in total.keys) {
      if ((total[suit] ?? 0) >= 4 && (hero[suit] ?? 0) > 0) {
        return true;
      }
    }
    return false;
  }

  bool _hasHeroStraightDraw(List<gc.Card> heroCards, List<gc.Card> boardCards) {
    final Set<int> ranks = <int>{};
    final Set<int> heroRanks = <int>{};
    for (final card in heroCards) {
      final int v = gc.rankValue(card.rank);
      ranks.add(v);
      heroRanks.add(v);
      if (v == 14) {
        ranks.add(1);
        heroRanks.add(1);
      }
    }
    for (final card in boardCards) {
      final int v = gc.rankValue(card.rank);
      ranks.add(v);
      if (v == 14) ranks.add(1);
    }
    for (int high = 5; high <= 14; high++) {
      final List<int> seq = <int>[high, high - 1, high - 2, high - 3, high - 4];
      final int present = seq.where(ranks.contains).length;
      final bool heroTouches = seq.any(heroRanks.contains);
      if (present >= 4 && heroTouches) return true;
    }
    return false;
  }

  String _preflopHopeHandName(List<gc.Card> heroCards) {
    if (heroCards.length < 2) return 'A CLEAN SPOT';
    final gc.Card a = heroCards[0];
    final gc.Card b = heroCards[1];
    final bool pocketPair = a.rank == b.rank;
    final bool suited = a.suit == b.suit;
    final int gap = (gc.rankValue(a.rank) - gc.rankValue(b.rank)).abs();
    final bool bothBroadway =
        gc.rankValue(a.rank) >= 10 && gc.rankValue(b.rank) >= 10;

    if (pocketPair) {
      return gc.rankValue(a.rank) >= 10 ? 'A SET OR FULL HOUSE' : 'A SET';
    }
    if (suited && gap <= 2) return 'A STRAIGHT OR FLUSH';
    if (suited) return 'A FLUSH';
    if (gap <= 2) return 'A STRAIGHT';
    if (bothBroadway) return 'TOP PAIR OR TWO PAIR';
    return 'A PAIR';
  }

  String _heroHopeHandName(List<gc.Card> heroCards, List<gc.Card> boardCards) {
    if (heroCards.length < 2) return 'A CLEAN SPOT';
    if (boardCards.length < 3) return _preflopHopeHandName(heroCards);

    final HandRank? current = _currentHeroHandRank(heroCards, boardCards);
    final bool flushDraw = _hasHeroFlushDraw(heroCards, boardCards);
    final bool straightDraw = _hasHeroStraightDraw(heroCards, boardCards);

    if (current == null) return _preflopHopeHandName(heroCards);

    switch (current.category) {
      case HandCategory.straightFlush:
        return 'THE NUTS';
      case HandCategory.fourKind:
        return 'FOUR OF A KIND';
      case HandCategory.fullHouse:
        return 'A FULL HOUSE';
      case HandCategory.flush:
        return straightDraw ? 'A STRAIGHT FLUSH' : 'A FLUSH';
      case HandCategory.straight:
        return 'A STRAIGHT';
      case HandCategory.threeKind:
      case HandCategory.twoPair:
        return 'A FULL HOUSE';
      case HandCategory.pair:
        if (flushDraw && straightDraw) return 'A STRAIGHT OR FLUSH';
        if (flushDraw) return 'A FLUSH';
        if (straightDraw) return 'A STRAIGHT';
        return 'TRIPS';
      case HandCategory.highCard:
        if (flushDraw && straightDraw) return 'A STRAIGHT OR FLUSH';
        if (flushDraw) return 'A FLUSH';
        if (straightDraw) return 'A STRAIGHT';
        return _boardHasPair(boardCards) ? 'TWO PAIR' : 'TOP PAIR';
    }
  }

  String _heroDisplayHandName(
      List<gc.Card> heroCards, List<gc.Card> boardCards) {
    final HandRank? current = _currentHeroHandRank(heroCards, boardCards);
    if (current == null) {
      return _preflopHopeHandName(heroCards);
    }

    if (current.category == HandCategory.highCard) {
      final bool flushDraw = _hasHeroFlushDraw(heroCards, boardCards);
      final bool straightDraw = _hasHeroStraightDraw(heroCards, boardCards);
      if (flushDraw && straightDraw) return 'STRAIGHT OR FLUSH DRAW';
      if (flushDraw) return 'FLUSH DRAW';
      if (straightDraw) return 'STRAIGHT DRAW';
    }

    final String name = current.name.trim().toUpperCase();
    if (name == 'ONE PAIR') return 'PAIR';
    return name;
  }

  String? _bestPossibleBoardHandName(
      List<gc.Card> heroCards, List<gc.Card> boardCards) {
    if (boardCards.length < 3) return null;
    final Set<String> excluded = <String>{
      ...boardCards.map(_cardKey),
      ...heroCards.map(_cardKey),
    };
    final List<gc.Card> remaining = _standardDeck()
        .where((card) => !excluded.contains(_cardKey(card)))
        .toList(growable: false);
    HandRank? best;
    for (int i = 0; i < remaining.length; i++) {
      for (int j = i + 1; j < remaining.length; j++) {
        final HandRank rank = HandEvaluator.evaluate(
          <gc.Card>[...boardCards, remaining[i], remaining[j]],
        );
        if (best == null || rank.compareTo(best) > 0) {
          best = rank;
        }
      }
    }
    return best?.name.toUpperCase();
  }

  _HeroMessageContext _heroMessageContext(Seat? heroSeat) {
    final String boardKey = widget.board.map((card) => card.code).join('|');
    final String heroKey =
        (heroSeat?.hole ?? const <GCard>[]).map((card) => card.code).join('|');
    final String actionKey = widget.recentActions
        .take(6)
        .map((a) => '${a.seatIndex}:${a.label}')
        .join('|');
    final String seatKey = widget.seats
        .map((seat) =>
            '${seat.folded ? 1 : 0}${seat.busted ? 1 : 0}${seat.allIn ? 1 : 0}')
        .join();
    final String key = '$boardKey//$heroKey//$actionKey//$seatKey';
    if (_heroMessageContextCacheKey == key &&
        _heroMessageContextCache != null) {
      return _heroMessageContextCache!;
    }

    final List<gc.Card> boardCards = _boardEngineCards();
    final List<gc.Card> heroCards = _heroHoleEngineCards(heroSeat);
    final _HeroMessageContext context = _HeroMessageContext(
      livePlayers: _livePlayersInHandCount(),
      aggressor: _latestAggressorInfo(),
      handName: _heroDisplayHandName(heroCards, boardCards),
      hopeHand: _heroHopeHandName(heroCards, boardCards),
      boardBestHand: null,
    );
    _heroMessageContextCacheKey = key;
    _heroMessageContextCache = context;
    return context;
  }

  String _livePlayersSnippet(int livePlayers, int seed) {
    final List<String> variants = <String>[
      '$livePlayers LIVE.',
      '$livePlayers STILL IN.',
      '$livePlayers LEFT.',
    ];
    return variants[seed.abs() % variants.length];
  }

  String _aggressorSnippet(_HeroAggressorInfo info, int seed) {
    final bool jam =
        info.label.startsWith('ALL-IN') || info.label.startsWith('ALL IN');
    final List<String> variants = jam
        ? <String>[
            '${info.name} JAMMED.',
            '${info.name} IS ALL-IN.',
            'ALL-IN BY ${info.name}.',
          ]
        : <String>[
            '${info.name} RAISED.',
            'LAST RAISE: ${info.name}.',
            '${info.name} APPLIED PRESSURE.',
          ];
    return variants[(seed.abs() + 1) % variants.length];
  }

  String _hopeSnippet(String hopeHand, int seed) {
    final List<String> variants = <String>[
      'DRAW TO $hopeHand.',
      'YOU CAN HIT $hopeHand.',
      'HOPE FOR $hopeHand.',
    ];
    return variants[(seed.abs() + 2) % variants.length];
  }

  String _boardBestSnippet(String bestHand, int seed) {
    final List<String> variants = <String>[
      'BEST POSSIBLE: $bestHand.',
      'BOARD CEILING: $bestHand.',
      'TOP HAND NOW: $bestHand.',
    ];
    return variants[(seed.abs() + 3) % variants.length];
  }

  String _probabilitySnippet(double winProb, int pct, int seed) {
    final List<String> variants;
    if (winProb <= 0.30) {
      variants = <String>[
        '$pct% CHANCE.',
        '$pct% SHOT.',
        '$pct% ONLY.',
      ];
    } else if (winProb < 0.60) {
      variants = <String>[
        '$pct% CHANCE.',
        '$pct% SPOT.',
        '$pct% TO FIGHT.',
      ];
    } else {
      variants = <String>[
        '$pct% EDGE.',
        '$pct% TO WIN.',
        '$pct% FAVOURITE.',
      ];
    }
    return variants[(seed.abs() + 4) % variants.length];
  }

  String _composeHeroIdleMessage({
    required _HeroMessageContext context,
    required int heroChips,
    required double? heroWinProb,
    required bool canCheck,
  }) {
    final int pct = heroWinProb != null
        ? (heroWinProb * 100).round().clamp(0, 100).toInt()
        : 0;
    final int seed = widget.board.length * 7 +
        widget.toCall +
        (widget.currentTurn < 0 ? 0 : widget.currentTurn) +
        (heroChips % 11) +
        context.livePlayers * 3;

    if (context.aggressor != null) {
      final List<String> tails = <String>[
        _hopeSnippet(context.hopeHand, seed),
        _livePlayersSnippet(context.livePlayers, seed),
        if (context.boardBestHand != null)
          _boardBestSnippet(context.boardBestHand!, seed),
        if (heroWinProb != null) _probabilitySnippet(heroWinProb, pct, seed),
      ];
      return '${_aggressorSnippet(context.aggressor!, seed)} '
          '${tails[(seed + 1) % tails.length]}';
    }

    if (context.boardBestHand != null && widget.board.length >= 3) {
      final int mode = seed % 3;
      if (mode == 0) {
        return '${_boardBestSnippet(context.boardBestHand!, seed)} '
            '${_hopeSnippet(context.hopeHand, seed)}';
      }
      if (mode == 1) {
        return '${_livePlayersSnippet(context.livePlayers, seed)} '
            '${_boardBestSnippet(context.boardBestHand!, seed)}';
      }
    }

    if (heroWinProb != null) {
      final List<String> tails = <String>[
        _hopeSnippet(context.hopeHand, seed),
        _livePlayersSnippet(context.livePlayers, seed),
        if (context.boardBestHand != null)
          _boardBestSnippet(context.boardBestHand!, seed),
      ];
      return '${_probabilitySnippet(heroWinProb, pct, seed)} '
          '${tails[(seed + 2) % tails.length]}';
    }

    final String lead = canCheck
        ? _livePlayersSnippet(context.livePlayers, seed)
        : (seed.isEven ? 'BET ON YOU.' : 'PLAN THE PRICE.');
    return '$lead ${_hopeSnippet(context.hopeHand, seed)}';
  }

  String _stabilizeHeroIdleMessage({
    required String messageKey,
    required String candidate,
  }) {
    if (_heroIdleMessageStable.isEmpty) {
      _heroIdleMessageStable = candidate;
      _heroIdleMessageProbabilityKey = messageKey;
      return candidate;
    }
    if (_heroIdleMessageProbabilityKey == messageKey) {
      return _heroIdleMessageStable;
    }
    _heroIdleMessageStable = candidate;
    _heroIdleMessageProbabilityKey = messageKey;
    return _heroIdleMessageStable;
  }

  String _heroProbabilityMessage({
    required double winProb,
    required int heroChips,
    required _HeroMessageContext context,
  }) {
    return _composeHeroIdleMessage(
      context: context,
      heroChips: heroChips,
      heroWinProb: winProb,
      canCheck: widget.toCall <= 0,
    );
  }

  String _heroFallbackContextMessage({
    required _HeroMessageContext context,
    required int heroChips,
    required bool canCheck,
  }) {
    return _composeHeroIdleMessage(
      context: context,
      heroChips: heroChips,
      heroWinProb: null,
      canCheck: canCheck,
    );
  }

  ({
    String message,
    HeroEquityEstimate? equity,
    HeroActionRecommendation? recommendation,
  })? _heroActionBarGuidance() {
    if (_handWinnerOverlayVisible) {
      _resetHeroIdleMessageState();
      return null;
    }
    if (widget.paused) {
      _resetHeroIdleMessageState();
      return (
        message: 'GAME PAUSED. TAP PLAY TO RESUME.',
        equity: null,
        recommendation: null,
      );
    }
    final Seat? heroSeat =
        (widget.heroIndex >= 0 && widget.heroIndex < widget.seats.length)
            ? widget.seats[widget.heroIndex]
            : null;
    if (heroSeat?.folded == true) {
      _resetHeroIdleMessageState();
      return null;
    }
    final _HeroMessageContext context = _heroMessageContext(heroSeat);
    final HeroEquityEstimate? heroEquity = _visibleHeroEquity(heroSeat);
    final HeroActionRecommendation? recommendation = heroEquity == null
        ? null
        : recommendHeroAction(
            equity: heroEquity.equity,
            marginOfError95: heroEquity.marginOfError95,
            potBeforeCall: widget.pot.round(),
            toCall: widget.toCall,
            heroStack: heroSeat?.chips ?? 0,
            startingStack: widget.startingStack,
            livePlayers: context.livePlayers,
            heroHole: _heroHoleEngineCards(heroSeat),
            revealedBoard: _boardEngineCards(),
            tablePosition: _heroTablePosition(),
            facingAggression: context.aggressor != null &&
                context.aggressor!.seatIndex != widget.heroIndex,
          );
    final String? heroRecentActionLabel = _latestHeroActionLabel();
    final String messageKey = <String>[
      heroEquity == null
          ? 'calculating'
          : <String>[
              heroEquity.winProbability.toStringAsFixed(6),
              heroEquity.tieProbability.toStringAsFixed(6),
              heroEquity.equity.toStringAsFixed(6),
              heroEquity.expectedPotShare.toStringAsFixed(6),
              heroEquity.method,
            ].join(':'),
      'live:${context.livePlayers}',
      'check:${widget.toCall <= 0}',
      'board:${widget.board.length}',
      'hand:${context.handName}',
      'aggr:${context.aggressor?.name ?? '-'}',
      'label:${context.aggressor?.label ?? '-'}',
      'hope:${context.hopeHand}',
      'hero:${heroRecentActionLabel ?? '-'}',
    ].join('|');
    final String message = buildVisibleHeroGuidanceMessage(
      livePlayers: context.livePlayers,
      canCheck: widget.toCall <= 0,
      winProbability: heroEquity?.equity,
      equityEstimate: heroEquity,
      useEquityBreakdown: true,
      revealedBoardCount: widget.board.length,
      variantSeed: messageKey.hashCode,
      aggressorName: context.aggressor?.name,
      aggressorAllIn: context.aggressor?.label.startsWith('ALL-IN') == true ||
          context.aggressor?.label.startsWith('ALL IN') == true,
      handName: context.handName,
      improvementHint: context.hopeHand,
      heroRecentActionLabel: heroRecentActionLabel,
    );
    return (
      message: _stabilizeHeroIdleMessage(
        messageKey: messageKey,
        candidate: message,
      ),
      equity: heroEquity,
      recommendation: recommendation,
    );
  }

  _BoardInfoSpec? _activeBoardInfo(bool heroTurnActive) {
    return null;
  }

  List<Widget> _buildBoardInfoOverlay({
    required _Ui ui,
    required _BoardInfoSpec spec,
  }) {
    final size = MediaQuery.of(context).size;
    final double labelH = ui.cardH * spec.boxHeightFactor;
    final double maxViewportWidth = size.width - 20;
    final double safeFeltWidth = (_feltRect.width - kSeatDiameterPx * 1.20)
        .clamp(180.0, maxViewportWidth);
    final double labelW = math.min(
      (ui.tableW * spec.maxWidthFactor).clamp(180.0, maxViewportWidth),
      safeFeltWidth,
    );
    final double centerY = _boardInfoCenterY(ui: ui, labelH: labelH);
    return <Widget>[
      Positioned(
        left: _boardCenter.dx - labelW / 2,
        top: centerY - labelH / 2,
        child: IgnorePointer(
          child: SizedBox(
            width: labelW,
            height: labelH,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                transitionBuilder: (child, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    child: child,
                    builder: (context, child) {
                      final double t =
                          animation.value.clamp(0.0, 1.0).toDouble();
                      final double fadeT =
                          Curves.easeOutCubic.transform(t).clamp(0.0, 1.0);
                      final double popT =
                          Curves.easeOutBack.transform(t).clamp(0.0, 1.08);
                      return Opacity(
                        opacity: fadeT,
                        child: Transform.translate(
                          offset: Offset(0, (1.0 - fadeT) * 14),
                          child: Transform.scale(
                            scale: 0.78 + (0.22 * popT),
                            child: child,
                          ),
                        ),
                      );
                    },
                  );
                },
                child: _OutlinedText(
                  key: ValueKey(
                    'board-info:${spec.text}|${spec.fillColor.value}',
                  ),
                  text: spec.text,
                  fillColor: spec.fillColor,
                  fontFamily: spec.fontFamily,
                  maxLines: spec.maxLines,
                  minFontSize: spec.minFontSize,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildSideInfoPills({required Size screenSize}) {
    final EdgeInsets safePadding = MediaQuery.paddingOf(context);
    final double safeSideInset = math.max(
      safePadding.left,
      safePadding.right,
    );
    final double horizontalInset =
        safeSideInset + math.max(6.0, screenSize.width * 0.006);
    final double leftMaxWidth =
        (screenSize.width * 0.36).clamp(210.0, 360.0).toDouble();
    final double rightMaxWidth =
        (screenSize.width * 0.40).clamp(250.0, 430.0).toDouble();
    final double topInset =
        safePadding.top + (screenSize.height < 700 ? 2.0 : 6.0);

    return <Widget>[
      Positioned(
        top: topInset,
        left: horizontalInset,
        child: IgnorePointer(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: leftMaxWidth),
            child: _VenueClockChip(
              flagPath: widget.flagPath,
              venueName: widget.venueName,
              timeZoneId: widget.venueTimeZoneId,
              glow: _heroPillGlow,
              glowActive: _heroPillGlowActive,
            ),
          ),
        ),
      ),
      Positioned(
        top: topInset,
        right: horizontalInset,
        child: IgnorePointer(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: rightMaxWidth),
            child: _HandHudPill(
              showStateScreen: widget.heroIndex >= 0 &&
                  widget.heroIndex < widget.seats.length &&
                  widget.seats[widget.heroIndex].folded,
              snapshot: buildHandHudSnapshot(
                boardCount: widget.board.length,
                visiblePot: widget.pot,
                toCall: widget.toCall,
                heroSeatIndex: widget.heroIndex,
                showdown: _handWinnerOverlayVisible,
                seats: <HandHudSeatState>[
                  for (final seat in widget.seats)
                    HandHudSeatState(
                      chips: seat.chips,
                      contribution: seat.contributedThisHand,
                      active: !seat.busted && !seat.folded,
                      allIn: seat.allIn,
                    ),
                ],
              ),
              glow: _heroPillGlow,
              glowActive: _heroPillGlowActive,
            ),
          ),
        ),
      ),
    ];
  }

  // Geometry from GameTableLayer → handed to RenoirLayer and used for seat layout
  bool _geomReady = false;
  double _railW = _kRailWidthPx;
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

    if (widget.reduceMotion && !oldWidget.reduceMotion) {
      _heroPillGlowActive = false;
      _heroPillGlowCtl
        ..stop()
        ..value = 0;
      _stopWinnerBlink();
      _stopWinChipPops();
    }

    _hiddenSeatIdx.removeWhere((i) => i < 0 || i >= widget.seats.length);
    _hiddenSeatIdx.remove(widget.heroIndex);

    for (int i = 0; i < widget.seats.length; i++) {
      if (_hiddenSeatIdx.contains(i) && !widget.seats[i].busted) {
        _hiddenSeatIdx.remove(i); // revived
      }
      if (!_hiddenSeatIdx.contains(i) &&
          i != widget.heroIndex &&
          widget.seats[i].busted &&
          !widget.activeBloodStains.contains(i)) {
        _hiddenSeatIdx.add(i);
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
    final List<go.UiCard> boardCards =
        widget.board.map((gc) => go.UiCard(gc.rank, gc.suit)).toList();
    return go.showWinnersDialog(
      context,
      winners: winners,
      totalPot: totalPot,
      duration: duration,
      board: boardCards,
      showCommunity: boardCards.isNotEmpty,
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

  Color _watermarkColorForFelt(Color felt) {
    final double luma = felt.computeLuminance();
    return luma < 0.45 ? Colors.white : Colors.black;
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
        unawaited(SoundFx.instance.stopAnnouncer());
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
    final bool heroTurnActive = widget.heroTurnSecondsRemaining != null &&
        widget.heroTurnSecondsRemaining! > 0 &&
        widget.heroIndex >= 0 &&
        widget.currentTurn == widget.heroIndex;
    _syncHeroPillGlow(heroTurnActive);
    final double maxBet = seats.isEmpty
        ? 0
        : seats.map((s) => s.bet.toDouble()).fold(0, math.max);
    final double maxHandContrib = seats.isEmpty
        ? 0
        : seats.map((s) => s.contributedThisHand.toDouble()).fold(0, math.max);
    final int activePlayers = seats.where((s) => !s.busted && !s.folded).length;
    final double tableLiftPx = ui.tableVerticalShift;
    final Set<String> handHighlightCodes = widget.showHandHighlight
        ? {
            for (final c in widget.handHighlightCards)
              _cardCode(c.rank, c.suit),
          }
        : const <String>{};
    final bool handHighlightActive =
        widget.showHandHighlight && handHighlightCodes.isNotEmpty;
    final _BoardInfoSpec? boardInfo = _activeBoardInfo(heroTurnActive);
    final actionBarGuidance = _heroActionBarGuidance();
    final String idleActionMessage = actionBarGuidance?.message ?? '';

    return Scaffold(
      backgroundColor: widget.bg,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.liveAnnouncement.trim().isNotEmpty)
            Positioned(
              left: 0,
              top: 0,
              child: Semantics(
                container: true,
                liveRegion: true,
                label: widget.liveAnnouncement,
                child: const SizedBox(width: 1, height: 1),
              ),
            ),
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
                final List<Offset> liveSeatPositions =
                    seatPlacement?.positions ?? const <Offset>[];
                final double liveSeatWidth = seatPlacement?.seatWidth ?? 0;
                final double liveSeatHeight = seatPlacement?.seatHeight ?? 0;
                final List<Offset> liveSeatTargets = seatPlacement == null
                    ? const <Offset>[]
                    : <Offset>[
                        for (final Offset position in seatPlacement.positions)
                          seatAvatarVisualRect(
                            Rect.fromLTWH(
                              position.dx,
                              position.dy,
                              liveSeatWidth,
                              liveSeatHeight,
                            ),
                            avatarScale: _kSeatAvatarScale,
                          ).center,
                      ];

                return Center(
                  child: Transform.translate(
                    offset: Offset(0, tableLiftPx),
                    child: Transform.scale(
                      scale: ui.tableVisualScale,
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
                              watermarkColor:
                                  _watermarkColorForFelt(widget.felt),
                              tintWhite: false,
                              pot: widget.pot,
                              potPulse: widget.potPulse,

                              // (still pass these so geometry math matches)
                              seats: seats,
                              heroIndex: widget.heroIndex,
                              currentTurn: widget.currentTurn,
                              dealerIndex: widget.dealerIndex,
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

                              communityRowTopFrac: 0.24,
                              topGapRadians: math.pi / 3,
                              softBandRadians: math.pi / 10,
                              pushDownFrac: 0.10,

                              onGeometryChanged: (TableGeometry g) {
                                if (!mounted) return;
                                setState(() {
                                  _railW = g.railWidth;
                                  _feltRect = g.feltRect;
                                  _origin = g.origin;
                                  _seatTargets = g.seatTargets;
                                  _boardCenter = g.boardCenter;
                                  _geomReady = true;
                                });
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
                                seatTargets: liveSeatTargets,
                                seatPanelPositions: liveSeatPositions,
                                seatPanelWidth: liveSeatWidth,
                                seatPanelHeight: liveSeatHeight,
                                boardTarget: _boardCenter,

                                // Card art/size
                                cardBackAsset: widget.cardBackAsset,
                                cardW: ui.cardW,
                                cardH: ui.cardH,

                                // Game state for reveals
                                seats: widget.seats,
                                board: _hideAllCards
                                    ? const <GCard>[]
                                    : widget.board,
                                heroIndex: widget.heroIndex,
                                showHandHighlight: widget.showHandHighlight,
                                handHighlightCards: widget.handHighlightCards,
                                hiddenSeats: _hideAllCards
                                    ? {
                                        ..._hiddenSeatIdx,
                                        for (int i = 0; i < seats.length; i++)
                                          i,
                                      }
                                    : _hiddenSeatIdx,
                                showToggleVisible: widget.showToggleVisible,
                                heroShow: widget.heroShow,
                                paused: widget.paused,
                                reduceMotion: widget.reduceMotion,

                                // Engine integration (optional)
                                engineEvents: widget.engineEvents,
                                onShuffle: () {
                                  widget.onRenoirShuffle?.call();
                                  // Unhide cards slightly after shuffle starts to sync with RenoirLayer timing
                                  Future.delayed(
                                      Duration(
                                          milliseconds:
                                              pace.kRevealAfterShuffleMs), () {
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

                            if (_geomReady && boardInfo != null)
                              ..._buildBoardInfoOverlay(
                                ui: ui,
                                spec: boardInfo,
                              ),

                            // 3) Blood stains for busted seats (same plane as cards)
                            if (_geomReady && seatPlacement != null)
                              ..._buildBloodStains(
                                placement: seatPlacement,
                                seats: seats,
                              ),

                            // 4) Settled hole cards stay behind their owner.
                            if (_geomReady && _seatTargets.isNotEmpty)
                              Positioned.fill(
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: _SeatFaceUpCardsLayer(
                                    railW: _railW,
                                    seats: seats,
                                    seatTargets: liveSeatTargets,
                                    seatPanelPositions: liveSeatPositions,
                                    seatPanelWidth: liveSeatWidth,
                                    seatPanelHeight: liveSeatHeight,
                                    heroIndex: widget.heroIndex,
                                    hiddenSeats: _hiddenSeatIdx,
                                    showToggleVisible: widget.showToggleVisible,
                                    heroShow: widget.heroShow,
                                    baseCardW: ui.cardW,
                                    baseCardH: ui.cardH,
                                    hideAllHoleCards:
                                        _hideAllCards || _hardHideHoleCards,
                                    winnerOverlayVisible:
                                        _handWinnerOverlayVisible,
                                    handHighlightActive: handHighlightActive,
                                    handHighlightSeat: widget.heroIndex,
                                    handHighlightCodes: handHighlightCodes,
                                    forcedFaceUpSeats: <int>{
                                      for (final fan in _winnerFans)
                                        fan.seatIndex,
                                    },
                                  ),
                                ),
                              ),

                            // 5) Avatars cover the tucked portion of each fan.
                            if (_geomReady && seatPlacement != null)
                              Positioned.fill(
                                child: ClipPath(
                                  clipper:
                                      PlayerSafeFeltClipper(railWidth: _railW),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: _buildSeatPanelsOnTop(
                                      placement: seatPlacement,
                                      seats: seats,
                                      leaderIdx: leaderIdx,
                                      growOthers: _hiddenSeatIdx.isNotEmpty ||
                                          seats.any((s) => s.busted),
                                      canAct: canAct,
                                      includeSeat: (_) => true,
                                    ),
                                  ),
                                ),
                              ),

                            // 6) D / SB / BB tags above both cards and avatars.
                            if (_geomReady && seatPlacement != null)
                              ..._buildBlindChipsOnTop(
                                placement: seatPlacement,
                                tableWidth: ui.tableW,
                                tableHeight: tableHeight,
                              ),

                            // 7) Seat action / busted bubbles above everything.
                            if (_geomReady && seatPlacement != null)
                              ..._buildSeatMessageOverlaysOnTop(
                                placement: seatPlacement,
                                seats: seats,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          ..._buildSideInfoPills(
            screenSize: MediaQuery.of(context).size,
          ),

          // ========= ACTION BURST (LIGHT FX) =========
          // Keep it *behind* the ActionBar so bursts look like they pop up from
          // behind the bar.
          Positioned.fill(
            child: IgnorePointer(
              child: ActionBurstOverlay(key: _actionBurstKey),
            ),
          ),

          // ========= ACTION BAR (FLOATING) =========
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.min(
                    980.0,
                    MediaQuery.sizeOf(context).width * 0.90,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: ActionGate.enabled,
                          builder: (context, actionsOn, _) {
                            return ValueListenableBuilder<bool>(
                              valueListenable: RenoirSignals.holeCardsVisible,
                              builder: (context, holesVisible, __) {
                                return ValueListenableBuilder<bool>(
                                  valueListenable: RenoirSignals.dealingActive,
                                  builder: (context, dealingActive, ___) {
                                    final bool heroCardsReady =
                                        widget.heroIndex >= 0 &&
                                            widget.heroIndex <
                                                widget.seats.length &&
                                            widget.seats[widget.heroIndex].hole
                                                    .length >=
                                                2;
                                    final bool canSkipNow = holesVisible &&
                                        heroCardsReady &&
                                        !dealingActive &&
                                        !widget.paused;

                                    return ActionBar(
                                      key: _actionBarKey,
                                      callButtonKey: _actionBarCallButtonKey,
                                      foldButtonKey: _actionBarFoldButtonKey,
                                      raiseButtonKey: _actionBarRaiseButtonKey,
                                      allInButtonKey: _actionBarAllInButtonKey,
                                      yellowButtonKey:
                                          _actionBarYellowButtonKey,
                                      pot: widget.pot.round(),
                                      callAmount: widget.toCall,
                                      minRaiseTo: widget.minRaise.round(),
                                      maxRaiseTo: widget.maxRaise.round(),
                                      sliderTo: widget.raiseAmount.round(),
                                      canAct: actionsOn &&
                                          widget.isHeroTurn &&
                                          heroCardsReady &&
                                          !widget.paused,
                                      onHandExamples: widget.onShowHandExamples,
                                      onBotLearning: widget.onShowBotLearning,
                                      showBotLearning: widget.showBotLearning,
                                      onScoreboard: () {
                                        final showScoreboard =
                                            widget.onShowScoreboard;
                                        if (showScoreboard != null) {
                                          showScoreboard();
                                          return;
                                        }
                                        Seat? heroSeat;
                                        if (widget.heroIndex >= 0 &&
                                            widget.heroIndex <
                                                widget.seats.length) {
                                          heroSeat =
                                              widget.seats[widget.heroIndex];
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
                                      canCallOrCheck: widget.canCallOrCheck,
                                      canRaise: widget.canRaise,
                                      canAllIn: widget.canAllIn,
                                      canFold: widget.canFold,
                                      onRaiseToChanged: (v) => widget
                                          .onRaiseAmountChanged(v.toDouble()),
                                      onBetOrRaise: widget.onBetOrRaise,
                                      onTips: () {
                                        final showPrevious =
                                            widget.onShowPreviousHand;
                                        if (showPrevious != null) {
                                          showPrevious();
                                          return;
                                        }
                                        go.showPreviousHandOverlay(context);
                                      },
                                      onSettings: widget.onShowSettings,
                                      onTogglePause: widget.onTogglePause,
                                      paused: widget.paused,
                                      canSkipToWinner:
                                          !widget.paused && kCanSkip,
                                      canSkipNow: canSkipNow,
                                      canShowdown: !widget.paused &&
                                          (_engineCanShow() ||
                                              (widget.canShowdown ?? false)),
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
                                      winnerOverlayVisible:
                                          _handWinnerOverlayVisible,
                                      winnerName: _handWinnerName,
                                      winnerAbout: _handWinnerAbout,
                                      winnerIsHero: _handWinnerIsHero,
                                      winnerGlow: _winnerBlink,
                                      idleMessage: idleActionMessage,
                                      guidanceRecommendation:
                                          actionBarGuidance?.recommendation,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Topmost while paused: every point on the game screen, including
          // the action bar, resumes play on the next tap.
          if (widget.paused &&
              widget.showPauseOverlay &&
              !_handWinnerOverlayVisible)
            Positioned.fill(
              child: PausedResumeOverlay(
                onPressed: widget.onTogglePause,
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
    bool Function(int index)? includeSeat,
  }) {
    final seatWidth = placement.seatWidth;
    final seatHeight = placement.seatHeight;
    final expandedSeatWidth = placement.expandedSeatWidth;
    final List<Offset> projected = placement.positions;
    final widgets = <Widget>[];
    for (final e in projected.asMap().entries) {
      final i = e.key;
      if (_hiddenSeatIdx.contains(i)) continue;
      if (includeSeat != null && !includeSeat(i)) continue;

      final Offset pos = e.value;

      widgets.add(
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: SizedBox(
            width: seatWidth,
            height: seatHeight,
            child: SeatWidget(
              seat: seats[i],
              isLeader: leaderIdx != null && i == leaderIdx,
              growWhenOthersGone: growOthers,
              onFadeDone: () {
                if (seats[i].busted &&
                    i != widget.heroIndex &&
                    !widget.activeBloodStains.contains(i)) {
                  setState(() => _hiddenSeatIdx.add(i));
                }
              },
              isTurn: canAct && (i == widget.currentTurn),
              isSB: i == widget.sbIndex,
              isBB: i == widget.bbIndex,
              fallbackAvatarAsset:
                  seatFallbackAsset(seats[i], widget.defaultProfileAsset),
              seatMaxWidth: expandedSeatWidth,
              seatHeight: seatHeight,
              persistBustedBubble: widget.activeBloodStains.contains(i),
              showTopBubble: false,
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
      fans.add(_WinnerFanInfo(seatIndex: seatIdx));
    }
    setState(() {
      _winnerFans = fans;
    });
  }

  List<Widget> _buildBloodStains({
    required _SeatPlacement placement,
    required List<Seat> seats,
  }) {
    final widgets = <Widget>[];
    final seatWidth = placement.seatWidth;
    final seatHeight = placement.seatHeight;
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
            width: seatWidth,
            height: seatHeight,
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
        (placement.seatHeight * 0.34).clamp(24.0, 40.0).toDouble();
    final bool chipsOnRail = _kBlindChipPlacement == BlindChipPlacement.rail;
    final Rect clampRect = chipsOnRail
        ? Rect.fromLTWH(0, 0, tableWidth, tableHeight)
        : _deflateForSeatPlacement(_feltRect, _kSeatVisualMarginPx);

    return buildBlindChips(
      seats: widget.seats,
      hiddenSeatIdx: _hiddenSeatIdx,
      seatPositions: placement.positions,
      seatSide: placement.seatHeight,
      tableCenter: _feltRect.center,
      clampRect: clampRect,
      chipSize: chipSize,
      dealerIndex: widget.dealerIndex,
      sbIndex: widget.sbIndex,
      bbIndex: widget.bbIndex,
      heroIndex: widget.heroIndex,
    );
  }

  List<Widget> _buildSeatMessageOverlaysOnTop({
    required _SeatPlacement placement,
    required List<Seat> seats,
  }) {
    final List<Widget> widgets = <Widget>[];
    final double seatWidth = placement.seatWidth;
    final double seatHeight = placement.seatHeight;
    for (final entry in placement.positions.asMap().entries) {
      final int i = entry.key;
      if (_hiddenSeatIdx.contains(i) || i >= seats.length) continue;
      widgets.add(
        Positioned(
          left: entry.value.dx,
          top: entry.value.dy,
          child: SizedBox(
            width: seatWidth,
            height: seatHeight,
            child: SeatTopBubbleOverlay(
              seat: seats[i],
              seatWidth: seatWidth,
              seatHeight: seatHeight,
              persistBustedBubble: widget.activeBloodStains.contains(i),
              isTurn: RenoirSignals.canAct.value && i == widget.currentTurn,
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  /* ----------------------------- UI helpers ------------------------------ */

  _SeatPlacement _computeSeatPlacement({
    required Rect feltRect,
    required double railW,
    required double seatW,
    required double seatH,
  }) {
    final double seatHeight = seatH;
    final double seatWidth = seatHeight;
    final double expandedSeatWidth = math.max(seatH, seatW);
    if (seatHeight <= 0 ||
        expandedSeatWidth <= 0 ||
        feltRect.width <= 0 ||
        feltRect.height <= 0) {
      return const _SeatPlacement(<Offset>[], 0, 0, 0);
    }

    final int seatCount = widget.seats.length;
    if (seatCount == 0) return const _SeatPlacement(<Offset>[], 0, 0, 0);

    final Size tableSize = Size(
      feltRect.width + railW * 2,
      feltRect.height + railW * 2,
    );
    final RRect safeBoundary = playerSafeFeltRRect(tableSize, railW);
    final List<Offset> positions = stadiumSeatTopLeftPositions(
      safeStadiumRect: safeBoundary.outerRect,
      seatCount: seatCount,
      heroIndex: widget.heroIndex,
      seatSize: seatHeight,
      visualFootprintSize: seatAvatarVisualRect(
        Rect.fromLTWH(0, 0, seatWidth, seatHeight),
        avatarScale: _kSeatAvatarScale,
      ).width,
      maximumVisualScale: 1.10,
      boundaryGap: _kSeatVisualMarginPx,
    );

    return _SeatPlacement(
      positions,
      seatWidth,
      seatHeight,
      expandedSeatWidth,
    );
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
    required double seatWidth,
    required double seatHeight,
    required double areaWidth,
    required double areaHeight,
    int iterations = 10,
  }) {
    if (positions.length <= 1) return positions;
    final double railCenter = _railW / 2;
    final double seatRadius = seatHeight / 2;
    final double overflow = math.max(0.0, seatRadius - railCenter);
    final double pad = _kSeatVisualMarginPx;
    final double minX = -overflow + pad;
    final double minY = -overflow + pad;
    final double maxX = math.max(minX, areaWidth - seatWidth + overflow - pad);
    final double maxY =
        math.max(minY, areaHeight - seatHeight + overflow - pad);
    final List<Offset> centers = [
      for (final o in positions)
        Offset(o.dx + seatWidth / 2, o.dy + seatHeight / 2),
    ];
    final double gap = math.max(6.0, seatHeight * 0.12);

    for (int iter = 0; iter < iterations; iter++) {
      bool moved = false;
      for (int i = 0; i < centers.length; i++) {
        for (int j = i + 1; j < centers.length; j++) {
          final Rect a = Rect.fromCenter(
            center: centers[i],
            width: seatWidth + gap,
            height: seatHeight + gap,
          );
          final Rect b = Rect.fromCenter(
            center: centers[j],
            width: seatWidth + gap,
            height: seatHeight + gap,
          );
          if (!a.overlaps(b)) continue;

          final double overlapX =
              math.min(a.right, b.right) - math.max(a.left, b.left);
          final double overlapY =
              math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
          if (overlapX <= 0 || overlapY <= 0) continue;

          final Offset delta = centers[j] - centers[i];
          if (delta.dy.abs() >= delta.dx.abs()) {
            final double push = overlapY / 2;
            final double sign = delta.dy >= 0 ? 1.0 : -1.0;
            centers[i] -= Offset(0, sign * push);
            centers[j] += Offset(0, sign * push);
          } else {
            final double push = overlapX / 2;
            final double sign = delta.dx >= 0 ? 1.0 : -1.0;
            centers[i] -= Offset(sign * push, 0);
            centers[j] += Offset(sign * push, 0);
          }
          moved = true;
        }
      }

      for (int k = 0; k < centers.length; k++) {
        final double cx = centers[k]
            .dx
            .clamp(minX + seatWidth / 2, maxX + seatWidth / 2)
            .toDouble();
        final double cy = centers[k]
            .dy
            .clamp(minY + seatHeight / 2, maxY + seatHeight / 2)
            .toDouble();
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
      for (final c in centers)
        Offset(c.dx - seatWidth / 2, c.dy - seatHeight / 2),
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
                '• Tap Hand Rankings to highlight your best hand.\n'
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
    _heroEquityGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _recoveryDebounce?.cancel();
    _recoveryDebounce = null;
    _disposeWinChipPops();
    _heroPillGlowCtl.dispose();
    _winnerBlinkCtl.dispose();
    try {
      _winnersSub?.cancel();
    } catch (_) {}
    _winnersSub = null;
    super.dispose();
  }
}

class _SeatPlacement {
  const _SeatPlacement(
    this.positions,
    this.seatWidth,
    this.seatHeight,
    this.expandedSeatWidth,
  );

  final List<Offset> positions;
  final double seatWidth;
  final double seatHeight;
  final double expandedSeatWidth;
}

class _SeatFaceUpCardsLayer extends StatelessWidget {
  final double railW;
  final List<Seat> seats;
  final List<Offset> seatTargets; // felt-space centers for card anchor
  final List<Offset> seatPanelPositions; // table-space seat rects
  final double seatPanelWidth;
  final double seatPanelHeight;
  final int heroIndex;
  final Set<int> hiddenSeats;
  final bool showToggleVisible;
  final bool heroShow;
  final double baseCardW, baseCardH;
  final bool hideAllHoleCards;
  final bool winnerOverlayVisible;
  final bool handHighlightActive;
  final int handHighlightSeat;
  final Set<String> handHighlightCodes;
  final Set<int> forcedFaceUpSeats;

  const _SeatFaceUpCardsLayer({
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
    required this.hideAllHoleCards,
    required this.winnerOverlayVisible,
    required this.handHighlightActive,
    required this.handHighlightSeat,
    required this.handHighlightCodes,
    this.forcedFaceUpSeats = const <int>{},
  });

  @override
  Widget build(BuildContext context) {
    if (hideAllHoleCards) return const SizedBox.shrink();
    if (seats.isEmpty || seatTargets.isEmpty) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: RenoirSignals.holeCardsVisible,
      builder: (context, holesVisible, _) {
        if (!holesVisible &&
            !winnerOverlayVisible &&
            forcedFaceUpSeats.isEmpty) {
          return const SizedBox.shrink();
        }
        final winnerData = winnerOverlayVisible
            ? _computeWinnerFaceUpData(seats)
            : _WinnerFaceUpData.empty;
        final bool winnerMode = winnerOverlayVisible;

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
            final RRect cardSafeBoundary =
                playerSafeFeltRRect(Size(w, h), railW);

            for (int i = 0; i < seats.length && i < seatTargets.length; i++) {
              if (hiddenSeats.contains(i)) continue;

              final seat = seats[i];
              final isHero = (i == heroIndex);
              final bool isWinner = winnerData.winningSeats.contains(i);
              final bool winnerShows = winnerData.winnerShowPref[i] ?? true;

              final int nToDraw = math.min(2, seat.hole.length);
              if (nToDraw == 0) continue;

              // Reveal rules
              final bool revealOpp =
                  showToggleVisible || forcedFaceUpSeats.contains(i);
              final bool revealHero =
                  isHero ? (showToggleVisible ? heroShow : true) : false;
              final bool facesUp = winnerMode
                  ? (isHero || (isWinner && winnerShows))
                  : (isHero ? revealHero : revealOpp);
              if (!facesUp) continue;

              // Sizes (face-up only)
              final double seatCardScale = isHero
                  ? _kSeatCardHeroScale
                  : (winnerMode && isWinner
                      ? _kSeatCardWinnerScale
                      : _kSeatCardOppShowScale);
              final double cardW = baseCardW * seatCardScale;
              final double cardH = baseCardH * seatCardScale;
              final bool heroSideBySide = isHero && nToDraw > 1;
              final double totalAngleDeg = heroSideBySide
                  ? 0.0
                  : (isHero
                      ? _kSeatCardHeroFanDeg
                      : (winnerMode && isWinner
                          ? _kSeatCardHeroFanDeg * 0.8
                          : _kSeatCardOppFanDeg));
              final double totalAngle = totalAngleDeg * (math.pi / 180.0);
              final double stepFactor = heroSideBySide
                  ? _kSeatCardHeroSideBySideGap
                  : 1 - _kSeatCardFanOverlap;

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
                    _cardCode(seat.hole[k].rank, seat.hole[k].suit);
                final bool winnerHighlight = winnerOverlayVisible &&
                    isWinner &&
                    (winnerData.winningHoleCodes[i]?.contains(code) ?? false);
                final bool handHighlight = handHighlightActive &&
                    i == handHighlightSeat &&
                    handHighlightCodes.contains(code);
                final bool highlight = winnerHighlight || handHighlight;
                final Color highlightColor = winnerHighlight
                    ? (isHero ? _kHeroWinOutline : _kBotWinOutline)
                    : _kHandHighlightOutline;

                Widget card = PlayingCard(
                  rank: seat.hole[k].rank,
                  suit: seat.hole[k].suit,
                  w: fittedCardW,
                  h: fittedCardH,
                );

                if (highlight) {
                  final double borderW =
                      (fittedCardW * 0.06).clamp(1.5, 4.0) * 1.2;
                  card = Stack(
                    fit: StackFit.expand,
                    children: [
                      card,
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(fittedCardW * 0.18),
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
                      angle: ang,
                      alignment: Alignment.center,
                      child: AnimatedOpacity(
                        key: ValueKey('seat-hole-$i-$k'),
                        opacity: seat.folded ? 0.0 : 1.0,
                        duration: seat.folded
                            ? _kFoldedSeatCardFadeDuration
                            : const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: card,
                      ),
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
      },
    );
  }
}

class _WinnerCycleEntry {
  final String name;
  final String about;
  final bool isHero;
  const _WinnerCycleEntry({
    required this.name,
    required this.about,
    required this.isHero,
  });
}

class _WinnerFanInfo {
  final int seatIndex;
  const _WinnerFanInfo({required this.seatIndex});
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

class _BoardInfoSpec {
  final String text;
  final Color fillColor;
  final double maxWidthFactor;
  final String fontFamily;
  final int maxLines;
  final double minFontSize;
  final double boxHeightFactor;

  const _BoardInfoSpec({
    required this.text,
    required this.fillColor,
    required this.maxWidthFactor,
    this.fontFamily = _kPopupFontFamily,
    this.maxLines = 1,
    this.minFontSize = 12,
    this.boxHeightFactor = 1.5,
  });
}

class _OutlinedText extends StatelessWidget {
  final String text;
  final Color fillColor;
  final Color outlineColor;
  final String fontFamily;
  final int maxLines;
  final double minFontSize;
  const _OutlinedText({
    super.key,
    required this.text,
    this.fillColor = const Color(0xFF3BB143),
    this.outlineColor = Colors.white,
    this.fontFamily = _kPopupFontFamily,
    this.maxLines = 1,
    this.minFontSize = 12,
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
          maxLines: maxLines,
          minFontSize: minFontSize,
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
  final int maxLines;
  final double minFontSize;
  const _OutlinedTextPainter({
    required this.text,
    required this.fillColor,
    required this.outlineColor,
    required this.fontFamily,
    required this.maxLines,
    required this.minFontSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = text.trim().toUpperCase();
    if (t.isEmpty || size.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final double maxTextWidth = w * 0.90;
    final double maxTextHeight = h * 0.90;
    final int effectiveMaxLines = math.max(1, maxLines);

    double fontSize = (h * (effectiveMaxLines > 1 ? 0.56 : 0.68))
        .clamp(minFontSize, 92.0)
        .toDouble();
    TextStyle base = TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      height: 1.0,
      letterSpacing: 0.1,
    );

    TextPainter buildPainter(Paint paint) {
      return TextPainter(
        text: TextSpan(
          text: t,
          style: base.copyWith(foreground: paint),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: effectiveMaxLines,
      )..layout(maxWidth: maxTextWidth);
    }

    TextPainter fill = buildPainter(
      Paint()
        ..style = PaintingStyle.fill
        ..color = fillColor,
    );

    while ((fill.didExceedMaxLines || fill.height > maxTextHeight) &&
        fontSize > minFontSize) {
      fontSize = (fontSize - 0.5).clamp(minFontSize, 92.0).toDouble();
      base = base.copyWith(fontSize: fontSize);
      fill = buildPainter(
        Paint()
          ..style = PaintingStyle.fill
          ..color = fillColor,
      );
    }

    final double strokeWidth = (fontSize * 0.095).clamp(1.5, 4.8).toDouble();
    final stroke = buildPainter(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..color = outlineColor,
    );

    final Offset off = Offset((w - stroke.width) / 2, (h - stroke.height) / 2);
    stroke.paint(canvas, off);
    fill.paint(canvas, off);
  }

  @override
  bool shouldRepaint(covariant _OutlinedTextPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.fontFamily != fontFamily ||
        oldDelegate.maxLines != maxLines ||
        oldDelegate.minFontSize != minFontSize;
  }
}

class _VenueClockChip extends StatelessWidget {
  final String flagPath;
  final String venueName;
  final String timeZoneId;
  final Animation<double>? glow;
  final bool glowActive;
  const _VenueClockChip({
    super.key,
    required this.flagPath,
    required this.venueName,
    required this.timeZoneId,
    this.glow,
    this.glowActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: _TopInfoPill(
        glow: glow,
        glowActive: glowActive,
        borderColor: Colors.white,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 17,
                child: _Flag(flagPath: flagPath),
              ),
              const SizedBox(width: 7),
              Text(
                venueName,
                style: _kSidePillTextStyle.copyWith(
                  color: Colors.white,
                  fontSize: 12.4,
                ),
                maxLines: 1,
                softWrap: false,
              ),
              Text(
                '  •  ',
                style: _kTopPillTextStyle.copyWith(
                  color: Colors.white,
                  fontSize: 11.4,
                ),
              ),
              DayDateClock(
                timeZoneId: timeZoneId,
                pillStyle: false,
                displayMode: DayDateClockDisplayMode.full,
                textStyle: _kTopPillTextStyle.copyWith(
                  color: Colors.white,
                  fontSize: 11.4,
                  letterSpacing: 0.10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HandHudPill extends StatelessWidget {
  final HandHudSnapshot snapshot;
  final bool showStateScreen;
  final Animation<double>? glow;
  final bool glowActive;

  const _HandHudPill({
    required this.snapshot,
    required this.showStateScreen,
    this.glow,
    this.glowActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: _TopInfoPill(
        glow: glow,
        glowActive: glowActive,
        borderColor: Colors.white,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.centerRight,
          child: RichText(
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.right,
            text: TextSpan(
              style: _kTopPillTextStyle.copyWith(
                fontSize: 11.6,
                letterSpacing: 0.10,
              ),
              children: <InlineSpan>[
                TextSpan(
                  text: snapshot.lineFor(heroFolded: showStateScreen),
                  style: TextStyle(
                    color: showStateScreen
                        ? Colors.white
                        : const Color(0xFFFFD54A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LastActionPill extends StatefulWidget {
  final List<SeatActionSnapshot> actions;
  final Animation<double>? glow;
  final bool glowActive;
  const _LastActionPill({
    required this.actions,
    this.glow,
    this.glowActive = false,
  });

  @override
  State<_LastActionPill> createState() => _LastActionPillState();
}

class _LastActionPillState extends State<_LastActionPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scroll;
  double _travel = 0;
  List<InlineSpan> _spans = const [];

  @override
  void initState() {
    super.initState();
    _scroll = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _LastActionPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebuildSpans();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Color _softActionColor(String label) {
    final Color base = _actionColorForLabel(label);
    final double alpha = ((base.opacity * 0.78).clamp(0.55, 0.82)).toDouble();
    return base.withValues(alpha: alpha);
  }

  String _compact(String label) {
    final up = label.toUpperCase().trim();
    return up
        .replaceAll('RAISE TO ', 'RAISE ')
        .replaceAll('ALL-IN ', 'ALL-IN ')
        .replaceAll('  ', ' ');
  }

  double _spanWidth(List<InlineSpan> spans) {
    final painter = TextPainter(
      text: TextSpan(style: _kTopPillTextStyle, children: spans),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return painter.width;
  }

  void _rebuildSpans() {
    final spans = <InlineSpan>[];
    final list = widget.actions;
    for (int i = 0; i < list.length; i++) {
      final text = _compact(list[i].label);
      final color = _softActionColor(text);
      if (i > 0) {
        spans.add(TextSpan(
          text: ' • ',
          style: _kTopPillTextStyle.copyWith(
            color: Colors.white.withValues(alpha: 0.48),
            fontWeight: FontWeight.w600,
          ),
        ));
      }
      spans.add(TextSpan(
        text: text,
        style: _kTopPillTextStyle.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ));
    }
    if (spans.isEmpty) {
      spans.add(const TextSpan(text: '---', style: _kTopPillTextStyle));
    }
    setState(() {
      _spans = spans;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Build spans once per frame if needed.
    if (_spans.isEmpty) _rebuildSpans();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        final double textW = _spanWidth(_spans);
        const double gap = 32.0;

        // If text fits, render static.
        if (textW <= maxW * 0.98) {
          _scroll.stop();
          _scroll.value = 0;
          return _TopInfoPill(
            glow: widget.glow,
            glowActive: widget.glowActive,
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(style: _kTopPillTextStyle, children: _spans),
            ),
          );
        }

        final double travel = textW + gap;
        if (_travel != travel || !_scroll.isAnimating) {
          _travel = travel;
          final int ms =
              ((travel + maxW) / 60 * 1000).clamp(1500, 12000).round();
          _scroll.duration = Duration(milliseconds: ms);
          _scroll.repeat();
        }

        Widget tickerText() => RichText(
              maxLines: 1,
              softWrap: false,
              text: TextSpan(style: _kTopPillTextStyle, children: _spans),
            );

        return _TopInfoPill(
          glow: widget.glow,
          glowActive: widget.glowActive,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _scroll,
              builder: (_, __) {
                final double dx = (_scroll.value % 1.0) * _travel;
                return Transform.translate(
                  offset: Offset(-dx, 0),
                  child: Row(
                    children: [
                      tickerText(),
                      const SizedBox(width: gap),
                      tickerText(),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TopInfoPill extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final double? height;
  final EdgeInsetsGeometry padding;
  final Animation<double>? glow;
  final bool glowActive;
  const _TopInfoPill({
    required this.child,
    this.borderColor,
    this.height,
    this.padding = _kTopPillPadding,
    this.glow,
    this.glowActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(999);
    final pill = Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.84),
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? Colors.white,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 18,
            spreadRadius: 1.2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            blurRadius: 0,
            spreadRadius: -0.3,
          ),
        ],
      ),
      child: child,
    );
    if (!glowActive || glow == null) return pill;
    return AnimatedBuilder(
      animation: glow!,
      child: pill,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: _PillGlowPainter(
            progress: glow!.value,
            color: Colors.white,
          ),
          child: child,
        );
      },
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

class _PillGlowPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _PillGlowPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    final rrect = RRect.fromRectAndRadius(rect.deflate(1.0), radius);
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final length = metric.length;
    if (length <= 0) return;

    final double sweep = length * 0.22;
    final double start = (progress % 1.0) * length;
    final double end = start + sweep;
    Path glowPath;
    if (end <= length) {
      glowPath = metric.extractPath(start, end);
    } else {
      final first = metric.extractPath(start, length);
      final second = metric.extractPath(0, end - length);
      glowPath = Path()
        ..addPath(first, Offset.zero)
        ..addPath(second, Offset.zero);
    }

    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final Paint corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.9);

    canvas.drawPath(glowPath, glowPaint);
    canvas.drawPath(glowPath, corePaint);
  }

  @override
  bool shouldRepaint(covariant _PillGlowPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
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

class _WinnerFaceUpData {
  final Set<int> winningSeats;
  final Map<int, Set<String>> winningHoleCodes;
  final Map<int, bool> winnerShowPref;

  const _WinnerFaceUpData({
    required this.winningSeats,
    required this.winningHoleCodes,
    required this.winnerShowPref,
  });

  static const empty = _WinnerFaceUpData(
    winningSeats: <int>{},
    winningHoleCodes: <int, Set<String>>{},
    winnerShowPref: <int, bool>{},
  );
}

_WinnerFaceUpData _computeWinnerFaceUpData(List<Seat> seats) {
  final snap = go.LastHandStore.last;
  if (snap == null || snap.winners.isEmpty) return _WinnerFaceUpData.empty;

  final Set<int> winners = {};
  final Map<int, Set<String>> holeCodes = {};
  final Map<int, bool> winnerShow = {};

  for (final w in snap.winners) {
    final idx = _seatIndexForName(seats, w.playerName);
    if (idx == null) continue;
    winners.add(idx);

    final Set<String> best = {
      for (final c in go.winningHandHighlightCards(w.bestFive))
        _cardCode(c.rank, c.suit),
    };

    final List<dynamic> holeList =
        w.holeCards.isNotEmpty ? w.holeCards : seats[idx].hole;
    final Set<String> winningHoles = {};
    for (final c in holeList) {
      final String code = _cardCode((c as dynamic).rank, (c as dynamic).suit);
      if (best.contains(code)) winningHoles.add(code);
    }
    holeCodes[idx] = winningHoles;

    final seed = snap.at.millisecondsSinceEpoch ^
        Seat.slugForName(w.playerName).hashCode;
    winnerShow[idx] = _winnerChoosesToShow(seats[idx], seed);
  }

  return _WinnerFaceUpData(
    winningSeats: winners,
    winningHoleCodes: holeCodes,
    winnerShowPref: winnerShow,
  );
}

int? _seatIndexForName(List<Seat> seats, String winnerName) {
  final slug = Seat.slugForName(winnerName);
  for (int i = 0; i < seats.length; i++) {
    if (Seat.slugForName(seats[i].name) == slug) return i;
  }
  return null;
}

bool _winnerChoosesToShow(Seat seat, int seed) {
  if (seat.isHero) return true;
  if (!seat.allIn) return true; // standard wins are always shown
  final rnd = math.Random(seed);
  final double tendency = (seat.aura.clamp(0, 100)) / 100.0; // 0..1
  final double bias = 0.35 + tendency * 0.5; // 0.35..0.85
  return rnd.nextDouble() < bias;
}

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
