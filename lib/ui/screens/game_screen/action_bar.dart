import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/game/equity/hero_action_guidance.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/info_pill.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/overlays.dart' as go;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/viewport.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

/// Brand colors (fallbacks; prefer your theme if already exported)
const kBg = Color(0xFF101114);
const kText = Color(0xFFEAEAEA);
const kRed = AppColors.red;
const kYellow = Color(0xFFFFD100); // JCB yellow
const double _kActionBarScale = 0.64;
const double _kActionBarHeightScale = 0.81;
const double _kWinnerInfoPillHeight = 96.0;
// A stable design-space target keeps the entire action cluster proportional
// across desktop and phone viewports. The scale-aware term below only grows it
// further on unusually small safe areas where 70 design pixels would render
// below the 44 logical-pixel accessibility minimum.
const double _kCanonicalMinHitTarget = 70.0;
const _kActionAreaFrameKey = ValueKey<String>('action-area-frame');
const _kHandExamplesButtonKey = ValueKey<String>('action-hand-examples-button');
const _kScoreboardButtonKey = ValueKey<String>('action-scoreboard-button');
const _kTipsButtonKey = ValueKey<String>('action-tips-button');
const _kPauseButtonKey = ValueKey<String>('action-pause-button');
const _kSettingsButtonKey = ValueKey<String>('action-settings-button');
const _kActionGuidanceKey = ValueKey<String>('action-guidance');
const _kActionGuidanceLabelKey = ValueKey<String>('action-guidance-label');

class ActionBar extends StatefulWidget {
  /// Betting/stack context
  final int pot; // kept for future, not shown in UI
  final int callAmount; // used in button label
  final int minRaiseTo;
  final int maxRaiseTo;
  final int sliderTo; // current selected raise-to value (from parent)
  final bool canAct;
  final bool canCallOrCheck;
  final bool canRaise;
  final bool canAllIn;
  final bool canFold;

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
  final VoidCallback? onSettings;
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
  final String idleMessage;
  final HeroActionRecommendation? guidanceRecommendation;

  const ActionBar({
    super.key,
    required this.pot,
    required this.callAmount,
    required this.minRaiseTo,
    required this.maxRaiseTo,
    required this.sliderTo,
    required this.canAct,
    this.canCallOrCheck = true,
    this.canRaise = true,
    this.canAllIn = true,
    this.canFold = true,
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
    this.onSettings,
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
    this.idleMessage = '',
    this.guidanceRecommendation,
  });

  @override
  State<ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<ActionBar> {
  /// First Bet/Raise click shows slider strip; second click confirms.
  bool _showRaiseStrip = false;

  /// Arms SKIP after the hero taps Fold (and we also honor widget.canSkipToWinner).
  bool _skipAfterFold = false;
  bool get _isSkipArmed => _skipAfterFold;

  @override
  void initState() {
    super.initState();
    _skipAfterFold = widget.canSkipToWinner;
  }

  @override
  void didUpdateWidget(covariant ActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool overlayHidden =
        oldWidget.winnerOverlayVisible && !widget.winnerOverlayVisible;
    final bool collapseRaise =
        !widget.canAct && _showRaiseStrip && !widget.winnerOverlayVisible;
    final bool regainedAction = !oldWidget.canAct && widget.canAct;
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

    if (overlayHidden && (_showRaiseStrip || _skipAfterFold)) {
      setState(() {
        _showRaiseStrip = false;
        _skipAfterFold = false;
      });
    }
  }

  void _collapseStrip() {
    if (_showRaiseStrip) setState(() => _showRaiseStrip = false);
  }

  void _confirmSelectedRaise() {
    if (!widget.canAct || !widget.canRaise) return;
    setState(() => _showRaiseStrip = false);
    widget.onBetOrRaise();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double scale = _kActionBarScale;
    final double viewportScale = GameViewportScale.maybeOf(context) ?? 1.0;
    final double minHitTarget = max(
      _kCanonicalMinHitTarget,
      viewportScale > 0 ? 44.0 / viewportScale : 44.0,
    );
    final baseHeight =
        (widget.compact ? 76.0 : 90.0) * scale * _kActionBarHeightScale;
    final messageHeight = baseHeight < _kWinnerInfoPillHeight * scale
        ? _kWinnerInfoPillHeight * scale
        : baseHeight;
    final extraForRaise = _showRaiseStrip
        ? (widget.compact ? 42.0 : 52.0) * scale * _kActionBarHeightScale
        : 0.0;
    final minHeight = baseHeight + extraForRaise;
    const double actionFrameBorderWidth = 0;
    final double actionFrameReservedInset = 3.2 * scale;
    final actionAreaContentHeight =
        minHeight < messageHeight ? messageHeight : minHeight;
    final double baseActionAreaMinHeight =
        actionAreaContentHeight + (actionFrameReservedInset * 2);
    final double actionButtonVisualHeight = 74 * scale * _kActionBarHeightScale;
    final double actionButtonHeight =
        max(actionButtonVisualHeight, minHitTarget);
    final double actionAreaMinHeight =
        max(baseActionAreaMinHeight, actionButtonHeight);
    final double sideButtonSize = actionAreaMinHeight * 0.612;
    final double sideButtonHitSize = max(sideButtonSize, minHitTarget);
    final bool skipReady = widget.canSkipNow;
    final bool yellowSkipPending = widget.canShowdown ||
        widget.everyoneElseFolded ||
        _isSkipArmed ||
        widget.canSkipToWinner;
    final HeroActionRecommendation? actionGuidance =
        widget.guidanceRecommendation;
    final ({String label, int slot, Color color})? actionGuidanceStyle =
        actionGuidance == null
            ? null
            : _actionGuidanceStyle(actionGuidance.action);
    final int handStrengthPercent =
        ((actionGuidance?.handStrength ?? 0).clamp(0.0, 1.0) * 100)
            .round()
            .clamp(0, 100);

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
          scale: scale,
          buttonSize: sideButtonSize,
          hitSize: sideButtonHitSize,
          enabled: true,
        );

    Widget buildRightIcons() => _RightIcons(
          onTips: () {
            SoundFx.instance.playActionTap();
            _collapseStrip();
            widget.onTips();
          },
          onSettings: widget.onSettings == null
              ? null
              : () {
                  SoundFx.instance.playActionTap();
                  _collapseStrip();
                  widget.onSettings!.call();
                },
          onTogglePause: () {
            SoundFx.instance.playActionTap();
            _collapseStrip();
            widget.onTogglePause();
          },
          paused: widget.paused,
          scale: scale,
          buttonSize: sideButtonSize,
          hitSize: sideButtonHitSize,
          engine: widget.engine,
          enabled: true,
        );

    Widget buildShell({
      required Widget centerChild,
      bool centerExpanded = true,
      bool alignSidesToActionButtons = false,
    }) {
      final Widget wrappedCenter =
          centerExpanded ? Expanded(child: centerChild) : centerChild;
      return Row(
        crossAxisAlignment: alignSidesToActionButtons
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.center,
        children: [
          buildLeftIcons(),
          SizedBox(width: 10 * scale),
          wrappedCenter,
          SizedBox(width: 10 * scale),
          buildRightIcons(),
        ],
      );
    }

    final normalCenterFrame = Container(
      key: _kActionAreaFrameKey,
      height: _showRaiseStrip ? null : actionAreaMinHeight,
      alignment: _showRaiseStrip ? null : Alignment.center,
      constraints: _showRaiseStrip
          ? BoxConstraints(minHeight: actionAreaMinHeight)
          : null,
      padding: EdgeInsets.fromLTRB(
        12 * scale,
        0,
        12 * scale,
        0,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: 1.5,
          ),
        ],
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
              enabled: widget.canAct && widget.canRaise,
              compact: widget.compact,
              scale: scale,
              onChanged: widget.onRaiseToChanged,
              onChangeEnd: widget.onRaiseToChanged,
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
                  callEnabled: widget.canCallOrCheck,
                  raiseEnabled: widget.canRaise,
                  allInEnabled: widget.canAllIn,
                  foldEnabled: widget.canFold,
                  showRaiseStrip: _showRaiseStrip,
                  actionsOn: widget.canAct,
                  scale: scale,
                  hitHeight: actionButtonHeight,
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
                      _confirmSelectedRaise();
                    } else {
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

    final Widget normalCenter = actionGuidanceStyle == null || _showRaiseStrip
        ? normalCenterFrame
        : LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final double actionGap = 10 * scale;
              final double innerInset =
                  actionFrameBorderWidth + (12 * scale) + (6.03 * scale);
              final double rowWidth = width - (innerInset * 2);
              final double buttonWidth =
                  ((rowWidth - (actionGap * 3)) / 4).clamp(1.0, width);
              final double buttonCenter = innerInset +
                  (buttonWidth / 2) +
                  (actionGuidanceStyle.slot * (buttonWidth + actionGap));
              final double labelWidth = buttonWidth;
              final double labelHeight = 19 * scale;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  normalCenterFrame,
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 460),
                    curve: Curves.easeOutCubic,
                    left: buttonCenter - (labelWidth / 2),
                    top: scale,
                    width: labelWidth,
                    height: labelHeight,
                    child: IgnorePointer(
                      child: _ActionGuidanceLabel(
                        action: actionGuidanceStyle.label,
                        percent: handStrengthPercent,
                        actionColor: actionGuidanceStyle.color,
                        scale: scale,
                      ),
                    ),
                  ),
                ],
              );
            },
          );

    final bool showWinnerOverlay = widget.winnerOverlayVisible &&
        (widget.winnerName.trim().isNotEmpty ||
            widget.winnerAbout.trim().isNotEmpty);
    if (!showWinnerOverlay) {
      return buildShell(
        centerChild: normalCenter,
        alignSidesToActionButtons: true,
      );
    }

    final String winnerAbout =
        widget.winnerAbout.trim().isNotEmpty ? widget.winnerAbout.trim() : '-';
    final Animation<double> glowAnim =
        widget.winnerGlow ?? const AlwaysStoppedAnimation<double>(0);
    final winnerBar = SizedBox(
      height: actionAreaMinHeight,
      child: IgnorePointer(
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
              key: _kActionAreaFrameKey,
              message: winnerAbout,
              compact: widget.compact,
              scale: scale,
              minHeight: 20 * scale * _kActionBarHeightScale,
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
  final double scale;
  final double buttonSize;
  final double hitSize;
  final bool enabled;

  const _LeftIconButtons({
    required this.onHandExamples,
    required this.onBotLearning,
    required this.showBotLearning,
    required this.onScoreboard,
    required this.scale,
    required this.buttonSize,
    required this.hitSize,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hitSize,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roundIcon(
            buttonKey: _kHandExamplesButtonKey,
            tooltip: 'Open hand examples, rules, and quick tips.',
            icon: Icons.menu_book_rounded,
            size: buttonSize,
            hitSize: hitSize,
            onTap: onHandExamples,
            enabled: enabled,
          ),
          if (showBotLearning) ...[
            SizedBox(width: 8 * scale),
            _roundIcon(
              tooltip: 'Open the bot learning and behavior panel.',
              icon: Icons.psychology_alt_rounded,
              size: buttonSize,
              hitSize: hitSize,
              onTap: onBotLearning,
              enabled: enabled,
            ),
          ],
          SizedBox(width: 8 * scale),
          _roundIcon(
            buttonKey: _kScoreboardButtonKey,
            tooltip: 'Open the scoreboard and chip order.',
            icon: Icons.leaderboard_rounded,
            size: buttonSize,
            hitSize: hitSize,
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
  final bool callEnabled, raiseEnabled, allInEnabled, foldEnabled;
  final bool actionsOn; // reflects ActionGate / canAct from parent
  final double scale;
  final double hitHeight;
  final Key? callButtonKey;
  final Key? foldButtonKey;
  final Key? raiseButtonKey;
  final Key? allInButtonKey;
  final Key? yellowButtonKey;

  // yellow-button state
  final bool canSkipToWinner, canShowdown;
  final bool everyoneElseFolded;
  final bool yellowEnabled;
  final VoidCallback onYellowTap;

  final VoidCallback onCall, onBetOrRaise, onAllIn;

  const _HeroButtonsRow({
    required this.callAmount,
    required this.minRaiseTo,
    required this.sliderTo,
    required this.enabled,
    required this.callEnabled,
    required this.raiseEnabled,
    required this.allInEnabled,
    required this.foldEnabled,
    required this.showRaiseStrip,
    required this.actionsOn,
    required this.scale,
    required this.hitHeight,
    this.callButtonKey,
    this.foldButtonKey,
    this.raiseButtonKey,
    this.allInButtonKey,
    this.yellowButtonKey,
    required this.canSkipToWinner,
    required this.canShowdown,
    required this.everyoneElseFolded,
    required this.yellowEnabled,
    required this.onYellowTap,
    required this.onCall,
    required this.onBetOrRaise,
    required this.onAllIn,
  });

  @override
  Widget build(BuildContext context) {
    final bool yellowSkipPending =
        canShowdown || everyoneElseFolded || canSkipToWinner;
    final bool yellowIsFold = !yellowSkipPending;
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
        horizontal: 6.03 * scale,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(60 * scale),
        color: containerColor,
      ),
      child: SizedBox(
        height: hitHeight,
        child: Row(
          children: [
            Expanded(
              child: _pillActionButton(
                title: 'ALL-IN',
                widgetKey: allInButtonKey,
                color: const Color(0xFFC41230),
                onTap: onAllIn,
                enabled: enabled && allInEnabled,
                active: !actionsOn || (enabled && allInEnabled),
                scale: scale,
                hitHeight: hitHeight,
                tooltip: allInTooltip,
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
                enabled: enabled &&
                    raiseEnabled &&
                    (!showRaiseStrip || sliderTo >= minRaiseTo),
                active: !actionsOn ||
                    (enabled &&
                        raiseEnabled &&
                        (!showRaiseStrip || sliderTo >= minRaiseTo)),
                scale: scale,
                hitHeight: hitHeight,
                tooltip: raiseTooltip,
              ),
            ),
            SizedBox(width: 10 * scale),
            Expanded(
              child: _pillActionButton(
                widgetKey: callButtonKey,
                title: callTitle,
                value: callValue,
                color: const Color(0xFF3BB143),
                onTap: onCall,
                enabled: enabled && callEnabled,
                active: !actionsOn || (enabled && callEnabled),
                scale: scale,
                hitHeight: hitHeight,
                tooltip: callTooltip,
              ),
            ),
            SizedBox(width: 10 * scale),
            Expanded(
              child: _pillActionButton(
                widgetKey: yellowButtonKey ?? foldButtonKey,
                title: yellowLabel,
                color: kYellow,
                textColor: Colors.white,
                titleStyle: _yellowActionLabelStyle(),
                onTap: onYellowTap,
                enabled: yellowEnabled && (!yellowIsFold || foldEnabled),
                active: !actionsOn ||
                    (yellowEnabled && (!yellowIsFold || foldEnabled)),
                scale: scale,
                hitHeight: hitHeight,
                tooltip: yellowTooltip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGuidanceLabel extends StatelessWidget {
  final String action;
  final int percent;
  final Color actionColor;
  final double scale;

  const _ActionGuidanceLabel({
    required this.action,
    required this.percent,
    required this.actionColor,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: _kActionGuidanceKey,
      label: 'Recommended $action, hand strength $percent percent',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: RichText(
            key: _kActionGuidanceLabelKey,
            maxLines: 1,
            text: TextSpan(
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 19 * scale,
                letterSpacing: 0.28,
                shadows: const <Shadow>[
                  Shadow(
                    color: Colors.black,
                    blurRadius: 5,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              children: <InlineSpan>[
                TextSpan(
                  text: action,
                  style: TextStyle(color: actionColor),
                ),
                TextSpan(text: '  •  HAND STRENGTH: $percent%'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

({String label, int slot, Color color}) _actionGuidanceStyle(
  HeroRecommendedAction action,
) =>
    switch (action) {
      HeroRecommendedAction.allIn => (
          label: 'ALL-IN',
          slot: 0,
          color: const Color(0xFFC41230),
        ),
      HeroRecommendedAction.raise => (
          label: 'RAISE',
          slot: 1,
          color: const Color(0xFF007FFF),
        ),
      HeroRecommendedAction.check => (
          label: 'CHECK',
          slot: 2,
          color: const Color(0xFF3BB143),
        ),
      HeroRecommendedAction.call => (
          label: 'CALL',
          slot: 2,
          color: const Color(0xFF3BB143),
        ),
      HeroRecommendedAction.fold => (
          label: 'FOLD',
          slot: 3,
          color: kYellow,
        ),
    };

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
  final bool highlightTrailingAction;

  const _MessagePill({
    super.key,
    required this.message,
    required this.compact,
    required this.scale,
    required this.minHeight,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.borderWidth = 1.4,
    this.extraShadows = const <BoxShadow>[],
    this.highlightTrailingAction = false,
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
            highlightTrailingAction: highlightTrailingAction,
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
  final bool highlightTrailingAction;

  const _AdaptivePillText({
    required this.message,
    required this.compact,
    required this.textColor,
    required this.highlightTrailingAction,
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

        List<InlineSpan> spansFor(TextStyle style) {
          if (!highlightTrailingAction) {
            return <InlineSpan>[TextSpan(text: message, style: style)];
          }
          final _TrailingActionHighlight? highlight =
              _trailingActionHighlight(message);
          if (highlight == null) {
            return <InlineSpan>[TextSpan(text: message, style: style)];
          }
          return <InlineSpan>[
            TextSpan(text: highlight.prefix, style: style),
            TextSpan(
              text: highlight.action,
              style: style.copyWith(color: highlight.color),
            ),
          ];
        }

        while (fontSize > minFont) {
          final TextStyle style = styleFor(fontSize);
          final TextPainter painter = TextPainter(
            text: TextSpan(
              children: spansFor(style),
            ),
            textAlign: TextAlign.center,
            textDirection: Directionality.of(context),
            maxLines: 2,
          )..layout(maxWidth: maxWidth);
          if (!painter.didExceedMaxLines) break;
          fontSize -= step;
        }

        final TextStyle resolvedStyle = styleFor(fontSize);
        return RichText(
          key: const ValueKey<String>('action-guidance-text'),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(children: spansFor(resolvedStyle)),
        );
      },
    );
  }
}

class _TrailingActionHighlight {
  final String prefix;
  final String action;
  final Color color;

  const _TrailingActionHighlight({
    required this.prefix,
    required this.action,
    required this.color,
  });
}

_TrailingActionHighlight? _trailingActionHighlight(String message) {
  const List<(String, Color)> actions = <(String, Color)>[
    ('MATCH BID', kYellow),
    ('TOO THIN', Color(0xFFC41230)),
    ('ALL-IN', Color(0xFF007FFF)),
    ('ALL IN', Color(0xFF007FFF)),
    ('CAUTION', Color(0xFFC41230)),
    ('DANGER', Color(0xFFC41230)),
    ('RAISE', Color(0xFF007FFF)),
    ('BET', Color(0xFF007FFF)),
    ('CALL', Color(0xFF3BB143)),
    ('CHECK', Color(0xFF3BB143)),
    ('FOLD', Color(0xFFC41230)),
    ('SHOW', kYellow),
    ('SKIP', kYellow),
  ];
  final String upper = message.trimRight().toUpperCase();
  for (final (String action, Color color) in actions) {
    if (!upper.endsWith(action)) continue;
    final int start = message.trimRight().length - action.length;
    return _TrailingActionHighlight(
      prefix: message.trimRight().substring(0, start),
      action: message.trimRight().substring(start),
      color: color,
    );
  }
  return null;
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
    return SizedBox(
      height: 25 * scale,
      child: Row(
        children: [
          Container(
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
          SizedBox(width: 8 * scale),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: trackH,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbR),
                overlayShape:
                    RoundSliderOverlayShape(overlayRadius: thumbR + 2),
              ),
              child: Slider(
                padding: EdgeInsets.zero,
                value: value.clamp(min, max).toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                onChanged: enabled ? (v) => onChanged(v.round()) : null,
                onChangeEnd: enabled && onChangeEnd != null
                    ? (v) => onChangeEnd!(v.round())
                    : null,
              ),
            ),
          ),
        ],
      ),
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
  double? hitHeight,
}) {
  return _PillActionButton(
    visualKey: widgetKey,
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
    hitHeight: hitHeight,
  );
}

class _PillActionButton extends StatefulWidget {
  final Key? visualKey;
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
  final double? hitHeight;

  const _PillActionButton({
    this.visualKey,
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
    this.hitHeight,
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
    final double visualHeight = 74 * widget.scale * _kActionBarHeightScale;
    final double height = max(visualHeight, widget.hitHeight ?? 0);
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
    final Color effectiveBorderColor = borderColor;
    final List<BoxShadow> glow = [
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
    ];
    Widget button = SizedBox(
      height: height,
      child: Center(
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
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, 2 * widget.scale),
                    child: Container(
                      key: widget.visualKey,
                      width: double.infinity,
                      height: visualHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(visualHeight),
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
                          horizontal: visualHeight * 0.12,
                          vertical: visualHeight * 0.16,
                        ),
                        child: ClipRect(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                displayLabel,
                                key: ValueKey<String>(displayLabel),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
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
        ),
      ),
    );

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

TextStyle _buttonTitleStyle(Color color) => TextStyle(
      color: color,
      fontWeight: FontWeight.w800,
      fontSize: 17.5 * 1.6 * _kActionBarScale,
      height: 1.0,
      letterSpacing: 0.34 * _kActionBarScale,
    );

TextStyle _yellowActionLabelStyle() => TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      fontSize: 20 * 1.6 * _kActionBarScale,
      letterSpacing: 0.20 * _kActionBarScale,
    );

Widget _roundIcon({
  Key? buttonKey,
  required String tooltip,
  required IconData icon,
  required double size,
  double? hitSize,
  VoidCallback? onTap,
  bool enabled = true,
}) {
  return _RoundIconButton(
    buttonKey: buttonKey,
    tooltip: tooltip,
    icon: icon,
    size: size,
    hitSize: hitSize ?? size,
    onTap: onTap,
    enabled: enabled,
  );
}

class _RoundIconButton extends StatefulWidget {
  final Key? buttonKey;
  final String tooltip;
  final IconData icon;
  final double size;
  final double hitSize;
  final VoidCallback? onTap;
  final bool enabled;

  const _RoundIconButton({
    this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.size,
    required this.hitSize,
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
    final double iconSize = widget.size * 0.46;
    final double visualSize = widget.size;
    final double hitSize = max(widget.hitSize, visualSize);
    final double borderAlpha = _pressed ? 0.32 : (_hover ? 0.24 : 0.16);
    final double borderWidth = _pressed ? 1.5 : (_hover ? 1.3 : 1.0);
    final Color glowColor = Colors.white.withValues(
      alpha: _pressed ? 0.30 : (_hover ? 0.22 : 0.14),
    );
    const ShapeBorder circleShape = CircleBorder();

    final button = SizedBox(
      width: hitSize,
      height: hitSize,
      child: MouseRegion(
        onEnter: widget.enabled ? (_) => setState(() => _hover = true) : null,
        onExit: (_) => setState(() {
          _hover = false;
          _pressed = false;
        }),
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Material(
          color: Colors.transparent,
          shape: circleShape,
          child: InkWell(
            customBorder: circleShape,
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
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, 2 * _kActionBarScale),
                child: AnimatedContainer(
                  key: widget.buttonKey,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: visualSize,
                  height: visualSize,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: Colors.black.withValues(alpha: borderAlpha),
                        width: borderWidth,
                      ),
                    ),
                    shadows: [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: _pressed ? 10 : (_hover ? 8 : 5),
                        spreadRadius: 0.0,
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.black, size: iconSize),
                ),
              ),
            ),
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
  final VoidCallback? onSettings;
  final VoidCallback onTogglePause;
  final bool paused;
  final double scale;
  final double buttonSize;
  final double hitSize;
  final Object? engine;
  final bool enabled;

  const _RightIcons({
    required this.onTips,
    this.onSettings,
    required this.onTogglePause,
    required this.paused,
    required this.scale,
    required this.buttonSize,
    required this.hitSize,
    this.engine,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    // Prefer cached last-hand snapshot stored by overlays.dart
    final cached = go.LastHandStore.last;
    final bool hasLast = cached != null && cached.winners.isNotEmpty;

    return SizedBox(
      height: hitSize,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roundIcon(
            buttonKey: _kTipsButtonKey,
            tooltip: hasLast
                ? 'Open the previous hand recap.'
                : 'No previous hand recap yet.',
            icon: Icons.info_outline_rounded,
            size: buttonSize,
            hitSize: hitSize,
            enabled: enabled,
            onTap: onTips,
          ),
          SizedBox(width: 8 * scale),
          if (onSettings != null) ...[
            _roundIcon(
              buttonKey: _kSettingsButtonKey,
              tooltip: 'Open sound and accessibility settings.',
              icon: Icons.settings_rounded,
              size: buttonSize,
              hitSize: hitSize,
              enabled: enabled,
              onTap: onSettings,
            ),
            SizedBox(width: 8 * scale),
          ],
          _roundIcon(
            buttonKey: _kPauseButtonKey,
            tooltip:
                paused ? 'Resume the current hand.' : 'Pause the current hand.',
            icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            size: buttonSize,
            hitSize: hitSize,
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
