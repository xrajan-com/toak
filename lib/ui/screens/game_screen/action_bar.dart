import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/overlays.dart' as go;
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

/// Brand colors (fallbacks; prefer your theme if already exported)
const kBg = Color(0xFF101114);
const kText = Color(0xFFEAEAEA);
const kRed = AppColors.red;
const kBlue = AppColors.blue;
const kGreen = Color(0xFF1B5E20); // dark leaf green
const kYellow = Color(0xFFFFD100); // JCB yellow

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
  final VoidCallback onSaveExit; // Save & Exit

  /// Optional: keys for locating specific buttons (e.g. winner bursts).
  final Key? callButtonKey;
  final Key? foldButtonKey;
  final Key? raiseButtonKey;
  final Key? allInButtonKey;
  final Key? yellowButtonKey;

  /// NEW: Yellow SKIP/SHOW button controls
  final bool canSkipToWinner; // hero folded; fast-forward allowed
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

  const ActionBar({
    super.key,
    required this.pot,
    required this.callAmount,
    required this.minRaiseTo,
    required this.maxRaiseTo,
    required this.sliderTo,
    required this.canAct,
    required this.onHandExamples,
    required this.onScoreboard,
    required this.onCall,
    required this.onFold,
    required this.onAllIn,
    required this.onRaiseToChanged,
    required this.onBetOrRaise,
    required this.onTips,
    required this.onSaveExit,
    this.callButtonKey,
    this.foldButtonKey,
    this.raiseButtonKey,
    this.allInButtonKey,
    this.yellowButtonKey,
    this.compact = false,

    // NEW (you must pass these)
    this.canSkipToWinner = false,
    this.canShowdown = false,
    this.everyoneElseFolded = false,
    required this.onSkipToWinner,
    required this.onShowdown,
    this.engine,
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
  StreamSubscription<go.WinnersBusEvent>? _winnersReset;
  bool _notifiedActivation = false;
  bool _winnerOverlayVisible = false;

  @override
  void initState() {
    super.initState();
    _prevCanAct = widget.canAct;
    _skipAfterFold = widget.canSkipToWinner;
    try {
      _winnersReset = go.WinnersBus.stream.listen((evt) {
        if (!mounted) return;
        _winnerOverlayVisible = evt.shown;
        if (!evt.shown && (_showRaiseStrip || _skipAfterFold)) {
          setState(() {
            _showRaiseStrip = false;
            _skipAfterFold = false;
          });
        }
        if (evt.shown) {
          _notifiedActivation = false;
        } else if (widget.canAct && !_notifiedActivation) {
          _notifiedActivation = true;
          SoundFx.instance.playHeroTurn();
        }
      });
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant ActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool collapseRaise = !widget.canAct && _showRaiseStrip;
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

    if (regainedAction &&
        widget.canAct &&
        !_notifiedActivation &&
        !_winnerOverlayVisible) {
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

  void _scheduleShowdownAfterSkip() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      try {
        widget.onShowdown();
      } catch (_) {}
      try {
        final e = widget.engine;
        if (e != null) {
          (e as dynamic).requestShowNow();
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _winnersReset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseHeight = widget.compact ? 76.0 : 90.0;
    final extraForRaise =
        _showRaiseStrip ? (widget.compact ? 42.0 : 52.0) : 0.0;
    final minHeight = baseHeight + extraForRaise;
    const double radius = 22.0;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 8),
            color: Color(0x99000000),
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
              enabled: widget.canAct,
              compact: widget.compact,
              onChanged: widget.onRaiseToChanged,
              onChangeEnd: _commitRaiseFromSlider,
            ),
            const SizedBox(height: 10),
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
                  callButtonKey: widget.callButtonKey,
                  foldButtonKey: widget.foldButtonKey,
                  raiseButtonKey: widget.raiseButtonKey,
                  allInButtonKey: widget.allInButtonKey,
                  yellowButtonKey: widget.yellowButtonKey,

                  // Yellow SKIP / SHOW button logic
                  canSkipToWinner: _isSkipArmed,
                  canShowdown: widget.canShowdown,
                  everyoneElseFolded: widget.everyoneElseFolded,
                  onYellowTap: () {
                    _collapseStrip();
                    if (widget.canShowdown || widget.everyoneElseFolded) {
                      widget.onShowdown();
                      try {
                        final e = widget.engine;
                        if (e != null) (e as dynamic).requestShowNow();
                      } catch (_) {}
                    } else if (_skipAfterFold) {
                      widget.onSkipToWinner();
                      try {
                        final e = widget.engine;
                        if (e != null) (e as dynamic).requestSkipToWinner();
                      } catch (_) {}
                      _scheduleShowdownAfterSkip();
                    }
                    // Hand is ending; disarm Skip so next hand re-enables all buttons
                    setState(() => _skipAfterFold = false);
                  },

                  // Hero action buttons
                  onCall: () {
                    _collapseStrip();
                    widget.onCall();
                  },
                  onFold: () {
                    _collapseStrip();
                    setState(() => _skipAfterFold = true);
                    widget.onFold();
                  },
                  onBetOrRaise: () {
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
                  leftIcons: _LeftIconButtons(
                    onHandExamples: () {
                      _collapseStrip();
                      widget.onHandExamples();
                    },
                    onScoreboard: () {
                      _collapseStrip();
                      widget.onScoreboard();
                    },
                    compact: widget.compact,
                    enabled: true,
                  ),
                  rightIcons: _RightIcons(
                    onTips: () {
                      _collapseStrip();
                      widget.onTips();
                    },
                    onSaveExit: () {
                      _collapseStrip();
                      widget.onSaveExit();
                    },
                    compact: widget.compact,
                    engine: widget.engine,
                    enabled: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ============================ Pieces ==================================== */

class _LeftIconButtons extends StatelessWidget {
  final VoidCallback onHandExamples;
  final VoidCallback onScoreboard;
  final bool compact;
  final bool enabled;

  const _LeftIconButtons({
    required this.onHandExamples,
    required this.onScoreboard,
    required this.compact,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final double s = compact ? 40 : 46;
    return SizedBox(
      height: 74,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roundIcon(
            tooltip: 'Hand Examples',
            icon: Icons.menu_book_rounded,
            size: s,
            onTap: onHandExamples,
            enabled: enabled,
          ),
          const SizedBox(width: 8),
          _roundIcon(
            tooltip: 'Scoreboard',
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
  final Key? callButtonKey;
  final Key? foldButtonKey;
  final Key? raiseButtonKey;
  final Key? allInButtonKey;
  final Key? yellowButtonKey;

  // yellow-button state
  final bool canSkipToWinner, canShowdown;
  final bool everyoneElseFolded;
  final VoidCallback onYellowTap;

  final VoidCallback onCall, onFold, onBetOrRaise, onAllIn;
  final Widget leftIcons;
  final Widget rightIcons;

  const _HeroButtonsRow({
    required this.callAmount,
    required this.minRaiseTo,
    required this.sliderTo,
    required this.enabled,
    required this.showRaiseStrip,
    required this.actionsOn,
    this.callButtonKey,
    this.foldButtonKey,
    this.raiseButtonKey,
    this.allInButtonKey,
    this.yellowButtonKey,
    required this.canSkipToWinner,
    required this.canShowdown,
    required this.everyoneElseFolded,
    required this.onYellowTap,
    required this.onCall,
    required this.onFold,
    required this.onBetOrRaise,
    required this.onAllIn,
    required this.leftIcons,
    required this.rightIcons,
  });

  @override
  Widget build(BuildContext context) {
    final bool yellowShowReady = canShowdown || everyoneElseFolded;
    final bool skipArmed = canSkipToWinner;
    final bool yellowEnabled = yellowShowReady ? actionsOn : skipArmed;
    final String yellowLabel = yellowShowReady ? 'SHOW' : 'SKIP';
    final Color skipColor = yellowShowReady
        ? Colors.white
        : (skipArmed ? kYellow : Colors.white.withValues(alpha: 0.2));
    final Color skipTextColor =
        yellowShowReady ? kRed : (skipArmed ? Colors.black : kText);

    final bool hasCallAmount = callAmount > 0;
    final String callTitle = hasCallAmount ? 'Call' : 'Check';
    final String? callValue = hasCallAmount ? _kFmt(callAmount) : null;

    final bool raiseShowsValue =
        showRaiseStrip || (!showRaiseStrip && sliderTo >= minRaiseTo);
    const String raiseTitle = 'Raise';
    final String? raiseValue = raiseShowsValue ? _kFmt(sliderTo) : null;

    final containerColor = Colors.black.withValues(alpha: 0.25);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(60),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.4),
        color: containerColor,
      ),
      child: Row(
        children: [
          leftIcons,
          const SizedBox(width: 14),
          Expanded(
            child: _pillActionButton(
              widgetKey: callButtonKey,
              title: callTitle,
              value: callValue,
              color: const Color(0xFF3BB143),
              onTap: onCall,
              enabled: enabled,
              active: enabled,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _pillActionButton(
              title: 'Fold',
              widgetKey: foldButtonKey,
              color: const Color(0xFFF5F5F5),
              textColor: const Color(0xFFC41230),
              titleStyle: _foldLabelStyle(),
              onTap: onFold,
              enabled: enabled,
              active: enabled,
            ),
          ),
          const SizedBox(width: 10),
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
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _pillActionButton(
              title: 'All-In',
              widgetKey: allInButtonKey,
              color: const Color(0xFFC41230),
              onTap: onAllIn,
              enabled: enabled,
              active: enabled,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _pillActionButton(
              widgetKey: yellowButtonKey,
              title: yellowLabel,
              color: skipColor,
              textColor: skipTextColor,
              onTap: onYellowTap,
              enabled: yellowEnabled,
              active: yellowShowReady ? actionsOn : skipArmed,
            ),
          ),
          const SizedBox(width: 14),
          rightIcons,
        ],
      ),
    );
  }
}

class _RaiseStrip extends StatelessWidget {
  final int value, min, max;
  final bool enabled, compact;
  final ValueChanged<int> onChanged;
  final ValueChanged<int>? onChangeEnd;

  const _RaiseStrip({
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.compact,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final double trackH = compact ? 3 : 4;
    final double thumbR = compact ? 8 : 10;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: kRed),
              const SizedBox(width: 6),
              Text(
                'Raise to: ${_kFmt(value)}',
                style:
                    const TextStyle(color: kText, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SliderTheme(
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
  required VoidCallback onTap,
  required Color color,
  Color textColor = Colors.white,
  Color? valueColor,
  bool enabled = true,
  bool active = true,
  TextStyle? titleStyle,
  TextStyle? valueStyle,
}) {
  const double size = 74;
  final bool neutral = !active;
  final Color primaryText = neutral ? kText : textColor;
  final bool isValueText = value != null;
  final Color secondaryText = neutral
      ? (isValueText ? Colors.white : kText.withValues(alpha: 0.85))
      : (valueColor ?? Colors.white);

  final BoxDecoration decoration = neutral
      ? BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.15),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.25), width: 1.4),
        )
      : BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.3,
          ),
        );

  return SizedBox(
    key: widgetKey,
    height: size,
    child: Center(
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: SizedBox.square(
          dimension: size,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onTap : null,
              child: Ink(
                decoration: decoration,
                child: Padding(
                  padding: EdgeInsets.all(size * 0.18),
                  child: value != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FittedBox(
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: titleStyle ??
                                    _buttonTitleStyle(primaryText),
                              ),
                            ),
                            FittedBox(
                              child: Text(
                                value,
                                textAlign: TextAlign.center,
                                style: valueStyle ??
                                    _buttonValueStyle(secondaryText),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: FittedBox(
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: _buttonTitleStyle(primaryText),
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
}

TextStyle _buttonTitleStyle(Color color) => TextStyle(
      color: color,
      fontWeight: FontWeight.w500,
      fontSize: 16.5,
      letterSpacing: 0.15,
    );

TextStyle _buttonValueStyle(Color color) => TextStyle(
      color: color,
      fontWeight: FontWeight.w500,
      fontSize: 12.3,
      letterSpacing: 0.15,
    );

// Bold lower-case "fold" with a faux stroke and soft glow.
TextStyle _foldLabelStyle() => const TextStyle(
      color: Color(0xFFC41230),
      fontWeight: FontWeight.w900,
      fontSize: 22,
      letterSpacing: 0.6,
      shadows: [
        Shadow(offset: Offset(1.1, 0), blurRadius: 0, color: Color(0xFFC41230)),
        Shadow(
            offset: Offset(-1.1, 0), blurRadius: 0, color: Color(0xFFC41230)),
        Shadow(offset: Offset(0, 1.1), blurRadius: 0, color: Color(0xFFC41230)),
        Shadow(
            offset: Offset(0, -1.1), blurRadius: 0, color: Color(0xFFC41230)),
        Shadow(offset: Offset(0, 1.5), blurRadius: 6, color: Color(0x66FF5A70)),
        Shadow(offset: Offset(0, 0), blurRadius: 14, color: Color(0x55FF1744)),
      ],
    );

Widget _roundIcon({
  required String tooltip,
  required IconData icon,
  required double size,
  VoidCallback? onTap,
  bool enabled = true,
}) {
  return Tooltip(
    message: tooltip,
    child: Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: Colors.white12,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: kText),
          ),
        ),
      ),
    ),
  );
}

class _RightIcons extends StatelessWidget {
  final VoidCallback onTips;
  final VoidCallback onSaveExit;
  final bool compact;
  final Object? engine;
  final bool enabled;

  const _RightIcons({
    required this.onTips,
    required this.onSaveExit,
    required this.compact,
    this.engine,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final s = compact ? 40.0 : 46.0;

    // Prefer cached last-hand snapshot stored by overlays.dart
    final cached = go.LastHandStore.last;
    final bool hasLast = cached != null && cached.winners.isNotEmpty;

    return SizedBox(
      height: 74,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roundIcon(
            tooltip: hasLast ? 'Previous Hand' : 'No previous hand yet',
            icon: Icons.info_outline_rounded,
            size: s,
            enabled: enabled,
            onTap: onTips,
          ),
          const SizedBox(width: 8),
          _roundIcon(
            tooltip: 'Save & Exit',
            icon: Icons.logout_rounded,
            size: s,
            onTap: onSaveExit,
            enabled: enabled,
          ),
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
