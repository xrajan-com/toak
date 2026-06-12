import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/info_pill.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/overlays.dart' as go;
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

/// Brand colors (fallbacks; prefer your theme if already exported)
const kBg = Color(0xFF101114);
const kText = Color(0xFFEAEAEA);
const kRed = AppColors.red;
const kYellow = Color(0xFFFFD100); // JCB yellow
const double _kActionBarScale = 0.64;
const double _kActionBarHeightScale = 0.81;
const double _kActionIconBoost = 1.10;
const double _kWinnerInfoPillHeight = 96.0;

class ActionBar extends StatefulWidget {
  /// Betting/stack context
  final int pot; // kept for future, not shown in UI
  final int callAmount; // used in button label
  final int minRaiseTo;
  final int maxRaiseTo;
  final int sliderTo; // current selected raise-to value (from parent)
  final bool canAct;

  /// Left-side actions
  final VoidCallback onHandExamples;
  final VoidCallback onBotLearning;
  final bool showBotLearning;
  final VoidCallback onScoreboard;

  /// Core hero actions
  final VoidCallback onCall;
  final VoidCallback onFold;
  final VoidCallback onAllIn;
  final ValueChanged<int> onRaiseToChanged;

  /// Called when the player CONFIRMS the raise (2nd click)
  final VoidCallback onBetOrRaise;

  /// Right-side utility actions
  final VoidCallback onTips; // “i” button
  final VoidCallback onTogglePause; // pause/resume
  final bool paused;

  /// Optional: keys for locating specific buttons (e.g. winner bursts).
  final Key? callButtonKey;
  final Key? foldButtonKey;
  final Key? raiseButtonKey;
  final Key? allInButtonKey;
  final Key? yellowButtonKey;

  /// NEW: Yellow SKIP/SHOW button controls
  final bool canSkipToWinner; // hero folded; fast-forward allowed
  /// Allow SKIP as soon as hole cards are dealt.
  final bool canSkipNow;
  final bool
      canShowdown; // hero all-in & action closed (or everyone else folded)
  final bool everyoneElseFolded; // enable SHOW when only hero remains
  final VoidCallback onSkipToWinner;
  final VoidCallback onShowdown;

  /// Optional: compact mode for smaller screens
  final bool compact;

  /// Optional: direct engine reference as a fallback (used if callbacks are no-ops)
  final Object?
      engine; // expects an object with requestSkipToWinner()/requestShowNow()

  /// Winner overlay display (sync with top info pills)
  final bool winnerOverlayVisible;
  final String winnerName;
  final String winnerAbout;
  final bool winnerIsHero;
  final Animation<double>? winnerGlow;
  final Animation<double>? turnGlow;
  final String idleMessage;

  const ActionBar({
    super.key,
    required this.pot,
    required this.callAmount,
    required this.minRaiseTo,
    required this.maxRaiseTo,
    required this.sliderTo,
    required this.canAct,
    required this.onHandExamples,
    required this.onBotLearning,
    required this.showBotLearning,
    required this.onScoreboard,
    required this.onCall,
    required this.onFold,
    required this.onAllIn,
    required this.onRaiseToChanged,
    required this.onBetOrRaise,
    required this.onTips,
    required this.onTogglePause,
    required this.paused,
    this.callButtonKey,
    this.foldButtonKey,
    this.raiseButtonKey,
    this.allInButtonKey,
    this.yellowButtonKey,
    this.compact = false,

    // NEW (you must pass these)
    this.canSkipToWinner = false,
    this.canSkipNow = false,
    this.canShowdown = false,
    this.everyoneElseFolded = false,
    required this.onSkipToWinner,
    required this.onShowdown,
    this.engine,
    this.winnerOverlayVisible = false,
    this.winnerName = '',
    this.winnerAbout = '',
    this.winnerIsHero = false,
    this.winnerGlow,
    this.turnGlow,
    this.idleMessage = '',
  });

  @override
  State<ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<ActionBar> {
  /// First Bet/Raise click shows slider strip; second click confirms.
  bool _showRaiseStrip = false;
  bool _raiseCommittedFromSlider = false;

  /// Arms SKIP after the hero taps Fold (and we also honor widget.canSkipToWinner).
  bool _skipAfterFold = false;
  bool get _isSkipArmed => _skipAfterFold;

  // Track previous canAct to detect transitions for state resets
  bool _prevCanAct = false;
  bool _notifiedActivation = false;

  @override
  void initState() {
    super.initState();
    _prevCanAct = widget.canAct;
    _skipAfterFold = widget.canSkipToWinner;
  }

  @override
  void didUpdateWidget(covariant ActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool overlayShown =
        !oldWidget.winnerOverlayVisible && widget.winnerOverlayVisible;
    final bool overlayHidden =
        oldWidget.winnerOverlayVisible && !widget.winnerOverlayVisible;
    final bool collapseRaise =
        !widget.canAct && _showRaiseStrip && !widget.winnerOverlayVisible;
    final bool regainedAction = !_prevCanAct && widget.canAct;
    final bool parentClearedSkip =
        oldWidget.canSkipToWinner && !widget.canSkipToWinner;
    final bool disarmSkip =
        _skipAfterFold && (regainedAction || parentClearedSkip);

    final bool shouldArmSkip = !_skipAfterFold && widget.canSkipToWinner;

    if (collapseRaise || disarmSkip || shouldArmSkip) {
      setState(() {
        if (collapseRaise) _showRaiseStrip = false;
        if (disarmSkip) {
          _skipAfterFold = false;
        } else if (shouldArmSkip) {
          _skipAfterFold = true;
        }
      });
    }

    if (overlayShown) {
      _notifiedActivation = false;
    }
    if (overlayHidden && (_showRaiseStrip || _skipAfterFold)) {
      setState(() {
        _showRaiseStrip = false;
        _skipAfterFold = false;
      });
    }

    if (regainedAction &&
        widget.canAct &&
        !_notifiedActivation &&
        !widget.winnerOverlayVisible) {
      _notifiedActivation = true;
      SoundFx.instance.playHeroTurn();
    } else if (!widget.canAct) {
      _notifiedActivation = false;
    }

    _prevCanAct = widget.canAct;
  }

  void _collapseStrip() {
    if (_showRaiseStrip) setState(() => _showRaiseStrip = false);
  }

  void _commitRaiseFromSlider(int value) {
    widget.onRaiseToChanged(value);
    if (_raiseCommittedFromSlider) return;
    _raiseCommittedFromSlider = true;
    widget.onBetOrRaise();
    setState(() => _showRaiseStrip = false);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double scale = _kActionBarScale;
    final baseHeight =
        (widget.compact ? 76.0 : 90.0) * scale * _kActionBarHeightScale;
    final messageHeight = baseHeight < _kWinnerInfoPillHeight * scale
        ? _kWinnerInfoPillHeight * scale
        : baseHeight;
    final extraForRaise = _showRaiseStrip
        ? (widget.compact ? 42.0 : 52.0) * scale * _kActionBarHeightScale
        : 0.0;
    final minHeight = baseHeight + extraForRaise;
    final double radius = 22.0 * scale;
    final bool skipReady = widget.canSkipNow;
    final bool yellowSkipPending = widget.canShowdown ||
        widget.everyoneElseFolded ||
        _isSkipArmed ||
        widget.canSkipToWinner;
    final bool showControls = widget.canAct || yellowSkipPending;
    final String idleMessage = widget.idleMessage.trim().isNotEmpty
        ? widget.idleMessage.trim()
        : 'WATCH THE TABLE. YOUR TURN WILL COME.';

    Widget buildLeftIcons() => _LeftIconButtons(
          onHandExamples: () {
            SoundFx.instance.playActionTap();
            _collapseStrip();
            widget.onHandExamples();
          },
          onBotLearning: () {
            SoundFx.instance.playActionTap();
            _collapseStrip();
            widget.onBotLearning();
          },
          showBotLearning: widget.showBotLearning,
          onScoreboard: () {
            SoundFx.instance.playActionTap();
            _collapseStrip();
            widget.onScoreboard();
          },
          compact: widget.compact,
          scale: scale,
          enabled: true,
        );

    Widget buildRightIcons() => _RightIcons(
          onTips: () {
            SoundFx.instance.playActionTap();
            _collapseStrip();
            widget.onTips();
          },
          onTogglePause: () {
            SoundFx.instance.playActionTap();
            _collapseStrip();
            widget.onTogglePause();
          },
          paused: widget.paused,
          compact: widget.compact,
          scale: scale,
          engine: widget.engine,
          enabled: true,
        );

    Widget buildShell({
      required Widget centerChild,
      bool centerExpanded = true,
    }) {
      final Widget wrappedCenter =
          centerExpanded ? Expanded(child: centerChild) : centerChild;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          buildLeftIcons(),
          SizedBox(width: 10 * scale),
          wrappedCenter,
          SizedBox(width: 10 * scale),
          buildRightIcons(),
        ],
      );
    }

    final normalCenter = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 8 * scale * _kActionBarHeightScale,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // RAISE STRIP ABOVE BUTTONS so the buttons stay in place
          if (_showRaiseStrip) ...[
            _RaiseStrip(
              value: widget.sliderTo,
              min: widget.minRaiseTo,
              max: widget.maxRaiseTo,
              enabled: widget.canAct,
              compact: widget.compact,
              scale: scale,
              onChanged: widget.onRaiseToChanged,
              onChangeEnd: _commitRaiseFromSlider,
            ),
            SizedBox(height: 10 * scale),
          ],

          Row(
            children: [
              Expanded(
                child: _HeroButtonsRow(
                  callAmount: widget.callAmount,
                  minRaiseTo: widget.minRaiseTo,
                  sliderTo: widget.sliderTo,
                  // Disable core hero buttons once Skip is armed (after Fold).
                  enabled: widget.canAct && !_isSkipArmed,
                  showRaiseStrip: _showRaiseStrip,
                  actionsOn: widget.canAct,
                  scale: scale,
                  callButtonKey: widget.callButtonKey,
                  foldButtonKey: widget.foldButtonKey,
                  raiseButtonKey: widget.raiseButtonKey,
                  allInButtonKey: widget.allInButtonKey,
                  yellowButtonKey: widget.yellowButtonKey,

                  // Yellow FOLD / SKIP button logic
                  canSkipToWinner: yellowSkipPending,
                  canShowdown: widget.canShowdown,
                  everyoneElseFolded: widget.everyoneElseFolded,
                  yellowEnabled:
                      widget.canAct || skipReady || yellowSkipPending,
                  turnGlow: widget.turnGlow,
                  turnGlowActive: widget.canAct,
                  onYellowTap: () {
                    SoundFx.instance.playActionTap();
                    _collapseStrip();
                    if (widget.canAct && !yellowSkipPending) {
                      setState(() => _skipAfterFold = true);
                      widget.onFold();
                      return;
                    }
                    if (widget.canShowdown || widget.everyoneElseFolded) {
                      widget.onShowdown();
                      try {
                        final e = widget.engine;
                        if (e != null) (e as dynamic).requestShowNow();
                      } catch (_) {}
                    } else if (skipReady ||
                        widget.canSkipToWinner ||
                        _isSkipArmed) {
                      widget.onSkipToWinner();
                      try {
                        final e = widget.engine;
                        if (e != null) (e as dynamic).requestSkipToWinner();
                      } catch (_) {}
                    }
                    // Hand is ending; disarm Skip so next hand re-enables all buttons
                    setState(() => _skipAfterFold = false);
                  },

                  // Hero action buttons
                  onCall: () {
                    SoundFx.instance.playActionTap();
                    _collapseStrip();
                    widget.onCall();
                  },
                  onBetOrRaise: () {
                    SoundFx.instance.playActionTap();
                    if (_showRaiseStrip) {
                      _commitRaiseFromSlider(widget.sliderTo);
                    } else {
                      _raiseCommittedFromSlider = false;
                      setState(() => _showRaiseStrip = true);
                    }
                  },
                  onAllIn: () {
                    _collapseStrip();
                    widget.onAllIn();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final idleBar = _MessagePill(
      message: idleMessage,
      compact: widget.compact,
      scale: scale,
      minHeight: messageHeight,
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      borderColor: Colors.white.withValues(alpha: 0.24),
      textColor: Colors.white,
      borderWidth: 3.2 * scale,
    );

    final bool showWinnerOverlay = widget.winnerOverlayVisible &&
        (widget.winnerName.trim().isNotEmpty ||
            widget.winnerAbout.trim().isNotEmpty);
    if (!showWinnerOverlay) {
      return buildShell(
        centerChild: showControls ? normalCenter : idleBar,
      );
    }

    final String winnerAbout =
        widget.winnerAbout.trim().isNotEmpty ? widget.winnerAbout.trim() : '-';
    final Animation<double> glowAnim =
        widget.winnerGlow ?? const AlwaysStoppedAnimation<double>(0);
    final winnerBar = IgnorePointer(
      child: AnimatedBuilder(
        animation: glowAnim,
        builder: (context, _) {
          final palette = winnerPillPalette(
            isHero: widget.winnerIsHero,
            blinkStrength: glowAnim.value,
          );
          final double t = glowAnim.value.clamp(0.0, 1.0);
          final double borderWidth = (3.2 + (0.8 * t)) * scale;
          final double outerBlur = (14 + (4 * t)) * scale;
          final double outerSpread = 1.4 + (0.8 * t);

          final Color bgColor = palette.background.withValues(
            alpha: (0.28 + (0.12 * t)).clamp(0.0, 1.0),
          );
          final Color borderColor = palette.border.withValues(
            alpha: (0.95 + (0.05 * t)).clamp(0.0, 1.0),
          );
          final Color glowColor = palette.glow.withValues(
            alpha: (0.55 + (0.15 * t)).clamp(0.0, 1.0),
          );

          return _MessagePill(
            message: winnerAbout,
            compact: widget.compact,
            scale: scale,
            minHeight: _kWinnerInfoPillHeight * scale,
            backgroundColor: bgColor,
            borderColor: borderColor,
            textColor: palette.foreground,
            borderWidth: borderWidth,
            extraShadows: [
              BoxShadow(
                color: glowColor,
                blurRadius: outerBlur,
                spreadRadius: outerSpread,
              ),
              BoxShadow(
                color: Colors.white.withValues(
                  alpha: 0.12 + (0.14 * t),
                ),
                blurRadius: (8 + (6 * t)) * scale,
                spreadRadius: 0.4 + (0.9 * t),
              ),
            ],
          );
        },
      ),
    );

    return buildShell(centerChild: winnerBar);
  }
}

/* ============================ Pieces ==================================== */

class _LeftIconButtons extends StatelessWidget {
  final VoidCallback onHandExamples;
  final VoidCallback onBotLearning;
  final bool showBotLearning;
  final VoidCallback onScoreboard;
  final bool compact;
  final double scale;
  final bool enabled;

  const _LeftIconButtons({
    required this.onHandExamples,
    required this.onBotLearning,
    required this.showBotLearning,
    required this.onScoreboard,
    required this.compact,
    required this.scale,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final double s = (compact ? 40 : 46) * scale * _kActionIconBoost;
    return SizedBox(
      height: 74 * scale * _kActionBarHeightScale,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roundIcon(
            tooltip: 'Open hand examples, rules, and quick tips.',
            icon: Icons.menu_book_rounded,
            size: s,
            onTap: onHandExamples,
            enabled: enabled,
          ),
          if (showBotLearning) ...[
            SizedBox(width: 8 * scale),
            _roundIcon(
              tooltip: 'Open the bot learning and behavior panel.',
              icon: Icons.psychology_alt_rounded,
              size: s,
              onTap: onBotLearning,
              enabled: enabled,
            ),
          ],
          SizedBox(width: 8 * scale),
          _roundIcon(
            tooltip: 'Open the scoreboard and chip order.',
            icon: Icons.leaderboard_rounded,
            size: s,
            onTap: onScoreboard,
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}

class _HeroButtonsRow extends StatelessWidget {
  final int callAmount, minRaiseTo, sliderTo;
  final bool enabled, showRaiseStrip;
  final bool actionsOn; // reflects ActionGate / canAct from parent
  final double scale;
  final Key? callButtonKey;
  final Key? foldButtonKey;
  final Key? raiseButtonKey;
  final Key? allInButtonKey;
  final Key? yellowButtonKey;

  // yellow-button state
  final bool canSkipToWinner, canShowdown;
  final bool everyoneElseFolded;
  final bool yellowEnabled;
  final Animation<double>? turnGlow;
  final bool turnGlowActive;
  final VoidCallback onYellowTap;

  final VoidCallback onCall, onBetOrRaise, onAllIn;

  const _HeroButtonsRow({
    required this.callAmount,
    required this.minRaiseTo,
    required this.sliderTo,
    required this.enabled,
    required this.showRaiseStrip,
    required this.actionsOn,
    required this.scale,
    this.callButtonKey,
    this.foldButtonKey,
    this.raiseButtonKey,
    this.allInButtonKey,
    this.yellowButtonKey,
    required this.canSkipToWinner,
    required this.canShowdown,
    required this.everyoneElseFolded,
    required this.yellowEnabled,
    this.turnGlow,
    this.turnGlowActive = false,
    required this.onYellowTap,
    required this.onCall,
    required this.onBetOrRaise,
    required this.onAllIn,
  });

  @override
  Widget build(BuildContext context) {
    final bool yellowSkipPending =
        canShowdown || everyoneElseFolded || canSkipToWinner;
    final bool yellowIsFold = actionsOn && !yellowSkipPending;
    final String yellowLabel = yellowIsFold ? 'FOLD' : 'SKIP';

    final bool hasCallAmount = callAmount > 0;
    final String callTitle = hasCallAmount ? 'CALL' : 'CHECK';
    final String? callValue = hasCallAmount ? _kFmt(callAmount) : null;

    final bool raiseShowsValue = !showRaiseStrip && sliderTo >= minRaiseTo;
    final String raiseTitle = showRaiseStrip ? 'CONFIRM' : 'RAISE';
    final String? raiseValue = raiseShowsValue ? _kFmt(sliderTo) : null;
    final String callTooltip = hasCallAmount
        ? 'Call and match the current bet.'
        : 'Check and pass without betting.';
    final String raiseTooltip = showRaiseStrip
        ? 'Confirm a raise to ${_kFmt(sliderTo)}.'
        : 'Open the raise slider and choose a bigger bet.';
    const String allInTooltip = 'Put your full stack in now.';
    final String yellowTooltip = yellowIsFold
        ? 'Fold and give up this hand.'
        : canShowdown || everyoneElseFolded
            ? 'Show the remaining cards and resolve the hand.'
            : 'Skip ahead and fast-forward to the winner.';

    const containerColor = Colors.transparent;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 8 * scale * _kActionBarHeightScale,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(60 * scale),
        color: containerColor,
      ),
      child: Row(
        children: [
          Expanded(
            child: _pillActionButton(
              widgetKey: callButtonKey,
              title: callTitle,
              value: callValue,
              color: const Color(0xFF3BB143),
              onTap: onCall,
              enabled: enabled,
              active: enabled,
              scale: scale,
              turnGlow: turnGlow,
              turnGlowActive: turnGlowActive,
              tooltip: callTooltip,
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: _pillActionButton(
              title: raiseTitle,
              value: raiseValue,
              widgetKey: raiseButtonKey,
              color: const Color(0xFF007FFF),
              textColor: Colors.white,
              valueColor: Colors.white,
              onTap: onBetOrRaise,
              enabled: enabled && (!showRaiseStrip || sliderTo >= minRaiseTo),
              active: enabled && (!showRaiseStrip || sliderTo >= minRaiseTo),
              scale: scale,
              turnGlow: turnGlow,
              turnGlowActive: turnGlowActive,
              tooltip: raiseTooltip,
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: _pillActionButton(
              title: 'ALL-IN',
              widgetKey: allInButtonKey,
              color: const Color(0xFFC41230),
              onTap: onAllIn,
              enabled: enabled,
              active: enabled,
              scale: scale,
              turnGlow: turnGlow,
              turnGlowActive: turnGlowActive,
              tooltip: allInTooltip,
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: _pillActionButton(
              widgetKey: yellowButtonKey ?? foldButtonKey,
              title: yellowLabel,
              color: kYellow,
              textColor: Colors.black,
              titleStyle: _yellowActionLabelStyle(),
              onTap: onYellowTap,
              enabled: yellowEnabled,
              active: yellowEnabled,
              scale: scale,
              turnGlow: turnGlow,
              turnGlowActive: turnGlowActive,
              tooltip: yellowTooltip,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagePill extends StatelessWidget {
  final String message;
  final bool compact;
  final double scale;
  final double minHeight;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final double borderWidth;
  final List<BoxShadow> extraShadows;

  const _MessagePill({
    required this.message,
    required this.compact,
    required this.scale,
    required this.minHeight,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.borderWidth = 1.4,
    this.extraShadows = const <BoxShadow>[],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.symmetric(
        horizontal: 18 * scale,
        vertical: 10 * scale * _kActionBarHeightScale,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: 1.5,
          ),
          ...extraShadows,
        ],
      ),
      child: SizedBox(
        height: minHeight - (20 * scale * _kActionBarHeightScale),
        child: Center(
          child: _AdaptivePillText(
            message: message,
            compact: compact,
            textColor: textColor,
          ),
        ),
      ),
    );
  }
}

class _AdaptivePillText extends StatelessWidget {
  final String message;
  final bool compact;
  final Color textColor;

  const _AdaptivePillText({
    required this.message,
    required this.compact,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        const double step = 0.5;
        final double maxFont = compact ? 15.5 : 18.0;
        final double minFont = compact ? 10.5 : 12.0;
        double fontSize = maxFont;

        TextStyle styleFor(double size) => TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: size,
              height: 1.12,
              letterSpacing: 0.08,
            );

        while (fontSize > minFont) {
          final TextPainter painter = TextPainter(
            text: TextSpan(
              text: message,
              style: styleFor(fontSize),
            ),
            textAlign: TextAlign.center,
            textDirection: Directionality.of(context),
            maxLines: 2,
          )..layout(maxWidth: maxWidth);
          if (!painter.didExceedMaxLines) break;
          fontSize -= step;
        }

        return Text(
          message,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: styleFor(fontSize),
        );
      },
    );
  }
}

class _RaiseStrip extends StatelessWidget {
  final int value, min, max;
  final bool enabled, compact;
  final double scale;
  final ValueChanged<int> onChanged;
  final ValueChanged<int>? onChangeEnd;

  const _RaiseStrip({
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.compact,
    required this.scale,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final double trackH = (compact ? 3 : 4) * scale;
    final double thumbR = (compact ? 8 : 10) * scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12 * scale,
              vertical: 5 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 10 * scale,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Text(
              'RAISE TO ${_kFmt(value)}',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 12 * scale,
                letterSpacing: 0.16,
              ),
            ),
          ),
        ),
        SizedBox(height: 8 * scale),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: trackH,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbR),
            overlayShape: RoundSliderOverlayShape(overlayRadius: thumbR + 2),
          ),
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            onChanged: enabled ? (v) => onChanged(v.round()) : null,
            onChangeEnd: enabled && onChangeEnd != null
                ? (v) => onChangeEnd!(v.round())
                : null,
          ),
        ),
      ],
    );
  }
}

/* ============================ UI helpers ================================ */

Widget _pillActionButton({
  Key? widgetKey,
  required String title,
  String? value,
  String? tooltip,
  required VoidCallback onTap,
  required Color color,
  Color textColor = Colors.white,
  Color? valueColor,
  bool enabled = true,
  bool active = true,
  TextStyle? titleStyle,
  TextStyle? valueStyle,
  double scale = 1.0,
  Animation<double>? turnGlow,
  bool turnGlowActive = false,
}) {
  return _PillActionButton(
    key: widgetKey,
    title: title,
    value: value,
    tooltip: tooltip,
    onTap: onTap,
    color: color,
    textColor: textColor,
    valueColor: valueColor,
    enabled: enabled,
    active: active,
    titleStyle: titleStyle,
    valueStyle: valueStyle,
    scale: scale,
    turnGlow: turnGlow,
    turnGlowActive: turnGlowActive,
  );
}

class _PillActionButton extends StatefulWidget {
  final String title;
  final String? value;
  final String? tooltip;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;
  final Color? valueColor;
  final bool enabled;
  final bool active;
  final TextStyle? titleStyle;
  final TextStyle? valueStyle;
  final double scale;
  final Animation<double>? turnGlow;
  final bool turnGlowActive;

  const _PillActionButton({
    super.key,
    required this.title,
    this.value,
    this.tooltip,
    required this.onTap,
    required this.color,
    required this.textColor,
    this.valueColor,
    required this.enabled,
    required this.active,
    this.titleStyle,
    this.valueStyle,
    required this.scale,
    this.turnGlow,
    this.turnGlowActive = false,
  });

  @override
  State<_PillActionButton> createState() => _PillActionButtonState();
}

class _PillActionButtonState extends State<_PillActionButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant _PillActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && (_hover || _pressed)) {
      _hover = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double height = 74 * widget.scale * _kActionBarHeightScale;
    final bool neutral = !widget.active;
    final bool emphasized = _hover || _pressed;
    final String titleText = widget.title.toUpperCase();
    final String? valueText = widget.value?.trim().toUpperCase();
    final String displayLabel = (valueText == null || valueText.isEmpty)
        ? titleText
        : '$titleText-$valueText';
    final Color fillTop = neutral
        ? Colors.white.withValues(alpha: 0.08)
        : Color.lerp(
            widget.color,
            Colors.white,
            _pressed ? 0.08 : (_hover ? 0.05 : 0.0),
          )!
            .withValues(alpha: _pressed ? 0.34 : (_hover ? 0.30 : 0.26));
    final Color fillBottom = neutral
        ? Colors.white.withValues(alpha: 0.05)
        : widget.color.withValues(
            alpha: _pressed ? 0.22 : (_hover ? 0.18 : 0.15),
          );
    final Color primaryText = neutral ? kText : widget.textColor;

    final Color edgeColor =
        neutral ? Colors.white.withValues(alpha: 0.35) : widget.color;
    final Color borderColor =
        emphasized ? edgeColor : edgeColor.withValues(alpha: 0.95);
    final double borderWidth = _pressed ? 2.1 : (_hover ? 1.8 : 1.5);
    final Color glowColor = borderColor.withValues(alpha: 0.24);
    final double glowBlur = _hover ? 12 : 8;
    final double glowSpread = _hover ? 0.8 : 0.0;
    final Color effectiveBorderColor =
        widget.enabled ? borderColor : borderColor.withValues(alpha: 0.35);
    final List<BoxShadow> glow = widget.enabled
        ? [
            BoxShadow(
              color: glowColor,
              blurRadius: glowBlur,
              spreadRadius: glowSpread,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 8,
              spreadRadius: 0.0,
              offset: const Offset(0, 4),
            ),
          ]
        : const [];
    final Color turnGlowColor = neutral
        ? Colors.white.withValues(alpha: 0.88)
        : widget.color.withValues(alpha: 0.96);

    Widget button = SizedBox(
      height: height,
      child: Center(
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.5,
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: MouseRegion(
              onEnter:
                  widget.enabled ? (_) => setState(() => _hover = true) : null,
              onExit: (_) => setState(() {
                _hover = false;
                _pressed = false;
              }),
              cursor: widget.enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: Material(
                color: Colors.transparent,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTapDown: widget.enabled
                      ? (_) => setState(() => _pressed = true)
                      : null,
                  onTapCancel: widget.enabled
                      ? () => setState(() => _pressed = false)
                      : null,
                  onTap: widget.enabled
                      ? () {
                          setState(() => _pressed = false);
                          widget.onTap();
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [fillTop, fillBottom],
                      ),
                      border: Border.all(
                          color: effectiveBorderColor, width: borderWidth),
                      boxShadow: glow,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: height * 0.12,
                        vertical: height * 0.16,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            displayLabel,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: (widget.titleStyle ??
                                    _buttonTitleStyle(primaryText))
                                .copyWith(color: primaryText),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.turnGlowActive && widget.turnGlow != null) {
      button = AnimatedBuilder(
        animation: widget.turnGlow!,
        child: button,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: _ActionButtonTurnGlowPainter(
              progress: widget.turnGlow!.value,
              color: turnGlowColor,
              inset: borderWidth * 0.45,
              strokeWidth: 1.9 + (0.5 * widget.scale),
            ),
            child: child,
          );
        },
      );
    }

    final String tooltip =
        widget.tooltip?.trim().isNotEmpty == true ? widget.tooltip!.trim() : '';
    if (tooltip.isEmpty) return button;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 180),
      child: button,
    );
  }
}

class _ActionButtonTurnGlowPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double inset;
  final double strokeWidth;

  const _ActionButtonTurnGlowPainter({
    required this.progress,
    required this.color,
    required this.inset,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    final double safeInset = inset.clamp(0.0, size.shortestSide / 4);
    final RRect rrect = RRect.fromRectAndRadius(
      rect.deflate(safeInset),
      Radius.circular((size.height / 2) - safeInset),
    );
    final Path path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    if (metric.length <= 0) return;

    final double sweep = metric.length * 0.22;
    final double start = (progress % 1.0) * metric.length;
    final double end = start + sweep;
    Path glowPath;
    if (end <= metric.length) {
      glowPath = metric.extractPath(start, end);
    } else {
      glowPath = Path()
        ..addPath(metric.extractPath(start, metric.length), Offset.zero)
        ..addPath(metric.extractPath(0, end - metric.length), Offset.zero);
    }

    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 0.8
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.64)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final Paint corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawPath(glowPath, glowPaint);
    canvas.drawPath(glowPath, corePaint);
  }

  @override
  bool shouldRepaint(covariant _ActionButtonTurnGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.inset != inset ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

TextStyle _buttonTitleStyle(Color color) => TextStyle(
      color: color,
      fontWeight: FontWeight.w800,
      fontSize: 17.5 * 1.6 * _kActionBarScale,
      height: 1.0,
      letterSpacing: 0.34 * _kActionBarScale,
    );

TextStyle _yellowActionLabelStyle() => TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.w900,
      fontSize: 20 * 1.6 * _kActionBarScale,
      letterSpacing: 0.20 * _kActionBarScale,
    );

Widget _roundIcon({
  required String tooltip,
  required IconData icon,
  required double size,
  VoidCallback? onTap,
  bool enabled = true,
}) {
  return _RoundIconButton(
    tooltip: tooltip,
    icon: icon,
    size: size,
    onTap: onTap,
    enabled: enabled,
  );
}

class _RoundIconButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final bool enabled;

  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.size,
    this.onTap,
    required this.enabled,
  });

  @override
  State<_RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<_RoundIconButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant _RoundIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && (_hover || _pressed)) {
      _hover = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = widget.size * 0.55;
    final double buttonHeight = widget.size;
    final double buttonWidth = buttonHeight * 1.38;
    final double borderAlpha = _pressed ? 0.24 : (_hover ? 0.20 : 0.14);
    final double borderWidth = _pressed ? 1.5 : (_hover ? 1.3 : 1.0);
    final Color glowColor = Colors.white.withValues(
      alpha: _pressed ? 0.22 : (_hover ? 0.16 : 0.10),
    );

    final button = MouseRegion(
      onEnter: widget.enabled ? (_) => setState(() => _hover = true) : null,
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTapDown:
              widget.enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel:
              widget.enabled ? () => setState(() => _pressed = false) : null,
          onTap: widget.enabled
              ? () {
                  setState(() => _pressed = false);
                  widget.onTap?.call();
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: buttonWidth,
            height: buttonHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(buttonHeight),
              color: Colors.white.withValues(alpha: 0.09),
              border: Border.all(
                color: Colors.white.withValues(alpha: borderAlpha),
                width: borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: _pressed ? 10 : (_hover ? 8 : 5),
                  spreadRadius: 0.0,
                ),
              ],
            ),
            child: Icon(widget.icon, color: kText, size: iconSize),
          ),
        ),
      ),
    );

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 180),
      child: Opacity(
        opacity: widget.enabled ? 1.0 : 0.5,
        child: button,
      ),
    );
  }
}

class _RightIcons extends StatelessWidget {
  final VoidCallback onTips;
  final VoidCallback onTogglePause;
  final bool paused;
  final bool compact;
  final double scale;
  final Object? engine;
  final bool enabled;

  const _RightIcons({
    required this.onTips,
    required this.onTogglePause,
    required this.paused,
    required this.compact,
    required this.scale,
    this.engine,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final s = (compact ? 40.0 : 46.0) * scale * _kActionIconBoost;

    // Prefer cached last-hand snapshot stored by overlays.dart
    final cached = go.LastHandStore.last;
    final bool hasLast = cached != null && cached.winners.isNotEmpty;

    return SizedBox(
      height: 74 * scale * _kActionBarHeightScale,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roundIcon(
            tooltip: hasLast
                ? 'Open the previous hand recap.'
                : 'No previous hand recap yet.',
            icon: Icons.info_outline_rounded,
            size: s,
            enabled: enabled,
            onTap: onTips,
          ),
          SizedBox(width: 8 * scale),
          _roundIcon(
            tooltip:
                paused ? 'Resume the current hand.' : 'Pause the current hand.',
            icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            size: s,
            enabled: enabled,
            onTap: onTogglePause,
          ),
          SizedBox(width: 8 * scale),
        ],
      ),
    );
  }
}

/* ============================ Format helper ============================= */

String _kFmt(int v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return '$v';
}
