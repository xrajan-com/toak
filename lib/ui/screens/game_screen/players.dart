import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui show TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'models.dart'; // GCard, truncateNice
import 'cards.dart' show ActionGate;
import 'bot_avatar.dart';
import 'seat_card_layout.dart' show seatAvatarVisualRect;

/* ──────────────────────────────────────────────
 * Legibility floors
 * ─────────────────────────────────────────── */
/// Target diameter (in pixels) for seat widgets.
const double kSeatDiameterPx = 115.2;
const double _kSeatMinSide = kSeatDiameterPx;
const double _kSeatAvatarScale = 0.85;
const Color _kSeatBetTextColor = Color(0xFFFFD54A);
const Color _kSeatStackTextColor = Color(0xFF3BB143);
const Color _kSeatPillFill = Color(0xD9111216);
const double _kSeatShellOpacityScale = 0.5;
const double _kHeroAvatarOpacity = 0.40;

Color _seatShellColor(
  Color color, [
  double opacityScale = _kSeatShellOpacityScale,
]) {
  return color.withValues(
    alpha: (color.a * opacityScale).clamp(0.0, 1.0),
  );
}

/* ──────────────────────────────────────────────
 * Seat model (UI)
 * ─────────────────────────────────────────── */
class Seat {
  String name;
  int chips;
  int startChips;
  int bet;
  int aura;
  bool isHero;
  bool folded;
  bool busted;
  bool allIn;
  int contributedThisHand;
  List<GCard> hole;
  String about;
  String kingdom;
  String lastAction;
  String avatarKey;
  String? avatarAssetFolder;

  Seat({
    required this.name,
    required this.chips,
    required this.startChips,
    required this.bet,
    this.aura = 60,
    this.isHero = false,
    this.hole = const [],
    this.folded = false,
    this.busted = false,
    this.allIn = false,
    this.contributedThisHand = 0,
    this.about = '',
    this.kingdom = '-',
    this.lastAction = '',
    String? avatarKey,
    this.avatarAssetFolder,
  }) : avatarKey = avatarKey ?? Seat._slugFromName(name);

  static String slugForName(String raw) => _slugFromName(raw);

  bool get profitable => chips > startChips;
  int get shortStackThreshold =>
      math.max(3000, (startChips.toDouble() * 0.30).round());
  bool get shortStack => chips > 0 && chips < shortStackThreshold;

  static String _slugFromName(String raw) {
    final slug = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'bot' : slug;
  }
}

/// Returns a per-seat portrait asset (falls back to the shared default image).
String seatFallbackAsset(Seat seat, String defaultAsset) {
  final String? folderRaw = seat.avatarAssetFolder;
  if (folderRaw == null || folderRaw.isEmpty || seat.isHero) {
    return defaultAsset;
  }

  final String slug = seat.avatarKey.trim();
  if (slug.isEmpty) return defaultAsset;

  final String folder = folderRaw.endsWith('/') ? folderRaw : '$folderRaw/';
  return '$folder$slug.png';
}

/* ──────────────────────────────────────────────
 * Seat widget (pill)
 * ─────────────────────────────────────────── */
class SeatWidget extends StatefulWidget {
  final Seat seat;
  final bool isLeader;
  final bool growWhenOthersGone;
  final bool isTurn;
  final bool isSB;
  final bool isBB;
  final String fallbackAvatarAsset;
  final double seatMaxWidth;
  final double seatHeight;
  final bool persistBustedBubble;
  final bool showTopBubble;

  /// Called when the bust fade finishes (only when busted).
  final VoidCallback? onFadeDone;

  const SeatWidget({
    super.key,
    required this.seat,
    required this.isLeader,
    required this.growWhenOthersGone,
    required this.isTurn,
    required this.isSB,
    required this.isBB,
    required this.fallbackAvatarAsset,
    required this.seatMaxWidth,
    required this.seatHeight,
    this.persistBustedBubble = false,
    this.showTopBubble = true,
    this.onFadeDone,
  });

  @override
  State<SeatWidget> createState() => _SeatWidgetState();
}

class _SeatWidgetState extends State<SeatWidget> with TickerProviderStateMixin {
  static const Duration _kBustFadeDuration = Duration(milliseconds: 280);
  static const Duration _kBustRemovalDelay = Duration(milliseconds: 320);
  static const Duration _kBustShatterDuration = Duration(milliseconds: 240);
  static const Duration _kDefaultFadeDuration = Duration(milliseconds: 400);
  static const Duration _kFoldVisualFadeDuration = Duration(seconds: 2);
  static const Duration _kSeatExpandDuration = Duration(milliseconds: 240);
  static const Duration _kSeatExpandedVisibleFor = Duration(seconds: 3);
  static final NumberFormat _chipFormat = NumberFormat.compact();
  double _opacity = 1.0;
  Timer? _fadeTimer;
  Timer? _detailsTimer;
  late final AnimationController _turnController;
  late final AnimationController _bustShatterController;
  bool _turnActive = false;
  bool _busting = false;
  bool _showDetails = false;

  void triggerBustFade() {
    if (_opacity == 0.0) return;
    setState(() {
      _opacity = 0.0;
      _busting = true;
    });
    _bustShatterController.forward(from: 0);
    _fadeTimer?.cancel();
    _fadeTimer = Timer(_kBustRemovalDelay, () {
      widget.onFadeDone?.call();
    });
  }

  @override
  void didUpdateWidget(covariant SeatWidget old) {
    super.didUpdateWidget(old);
    if (!widget.seat.busted && _opacity != 1.0) {
      _fadeTimer?.cancel();
      _bustShatterController.stop();
      setState(() {
        _opacity = 1.0;
        _busting = false;
      });
    }
    if (widget.seat.busted && widget.seat.chips <= 0 && _showDetails) {
      _detailsTimer?.cancel();
      setState(() {
        _showDetails = false;
      });
    }
    // Fade ANY busted seat after settlement.
    if (widget.seat.busted && widget.seat.chips <= 0 && _opacity != 0.0) {
      triggerBustFade();
    }
  }

  @override
  void initState() {
    super.initState();
    _turnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _bustShatterController = AnimationController(
      vsync: this,
      duration: _kBustShatterDuration,
    );
    if (widget.seat.busted && widget.seat.chips <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        triggerBustFade();
      });
    }
  }

  @override
  void dispose() {
    _turnController.dispose();
    _bustShatterController.dispose();
    _fadeTimer?.cancel();
    _detailsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ActionGate.enabled,
      builder: (context, actionsOn, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final seat = widget.seat;
            final bool isBusted = seat.busted;
            final bool isAllIn = !isBusted && (seat.allIn || seat.chips <= 0);
            final bool isFolded = !isBusted && seat.folded;
            final bool showRedRing = !isBusted && (isAllIn || seat.shortStack);
            final bool canShowTurn = actionsOn && widget.isTurn && !isBusted;
            final bool showExpandedSeat = _showDetails && !isBusted;
            final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
            _syncTurnAnimation(canShowTurn, reduceMotion: reduceMotion);
            final AvatarMood mood = _resolveMood(seat, canShowTurn);

            final double maxH = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : widget.seatHeight;
            double pillH = maxH;
            if (!pillH.isFinite || pillH <= 0) {
              pillH = widget.seatHeight;
            }
            final double minHeight = math.min(_kSeatMinSide, widget.seatHeight);
            final double maxHeight = math.max(minHeight, widget.seatHeight);
            pillH = pillH.clamp(minHeight, maxHeight).toDouble();
            final double collapsedSide = pillH;
            double pillW = widget.seatMaxWidth;
            if (!pillW.isFinite || pillW <= 0) {
              pillW = pillH * 2.02;
            }
            final double minWidth = math.max(pillH * 1.70, pillH);
            final double maxWidth = math.max(minWidth, widget.seatMaxWidth);
            pillW = pillW.clamp(minWidth, maxWidth).toDouble();
            final double shellWidth = showExpandedSeat ? pillW : collapsedSide;
            final Rect avatarGeometry = seatAvatarVisualRect(
              Rect.fromLTWH(0, 0, collapsedSide, pillH),
              avatarScale: _kSeatAvatarScale,
            );
            final double avatarSize = avatarGeometry.width;
            final double avatarInset = avatarGeometry.top;
            final double avatarLeft = showExpandedSeat
                ? avatarInset
                : ((collapsedSide - avatarSize) / 2).clamp(0.0, collapsedSide);
            final double avatarBoxSize = avatarSize;
            final double textLeft = avatarInset + avatarSize + (pillH * 0.16);
            final double textRight = pillH * 0.18;

            final _BorderAttributes border = _borderForSeat(seat, canShowTurn);
            final Color? statusTint = _statusTint(seat);
            final Color pillFillColor = _seatShellColor(_kSeatPillFill);
            final Color? shellStatusTint = statusTint == null
                ? null
                : _seatShellColor(statusTint.withValues(alpha: 0.08));
            final Color? avatarStatusTint = statusTint == null
                ? null
                : _seatShellColor(statusTint.withValues(alpha: 0.10));
            final Color allInShellTint =
                _seatShellColor(const Color(0x1FFF8A65));
            final Color allInAvatarTint =
                _seatShellColor(const Color(0x33FF8A65));
            final Widget avatar = AnimatedOpacity(
              opacity:
                  isFolded ? 0.30 : (seat.isHero ? _kHeroAvatarOpacity : 1.0),
              duration:
                  isFolded ? _kFoldVisualFadeDuration : _kDefaultFadeDuration,
              curve: Curves.easeOutCubic,
              child: BotAvatar(
                avatarKey: seat.avatarKey,
                mood: mood,
                assetFolder: seat.avatarAssetFolder,
                fallbackAsset: widget.fallbackAvatarAsset,
              ),
            );
            final List<BoxShadow> avatarShadows = <BoxShadow>[
              ...border.shadows,
              BoxShadow(
                color: _seatShellColor(const Color(0x33000000)),
                blurRadius: 10,
                spreadRadius: 0.5,
              ),
            ];
            final String seatStatus =
                _actionLabelFor(seat, isFolded, isAllIn, canShowTurn);
            final String blindLabel = widget.isSB
                ? ', small blind'
                : widget.isBB
                    ? ', big blind'
                    : '';
            final String semanticsLabel =
                '${seat.name}, ${_formatAmount(seat.chips)} chips'
                '${seat.contributedThisHand > 0 ? ', ${_formatAmount(seat.contributedThisHand)} committed' : ''}'
                ', $seatStatus$blindLabel';

            return AnimatedScale(
              scale: (widget.growWhenOthersGone && !isBusted) ? 1.1 : 1.0,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              child: Center(
                child: SizedBox(
                  width: collapsedSide,
                  height: pillH,
                  child: Semantics(
                    container: true,
                    button: !isBusted,
                    enabled: !isBusted,
                    excludeSemantics: true,
                    label: semanticsLabel,
                    onTap: isBusted ? null : _showSeatDetails,
                    child: GestureDetector(
                      excludeFromSemantics: true,
                      behavior: HitTestBehavior.opaque,
                      onTap: isBusted ? null : _showSeatDetails,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: AnimatedOpacity(
                              opacity: _opacity,
                              duration: reduceMotion
                                  ? Duration.zero
                                  : seat.busted
                                      ? _kBustFadeDuration
                                      : _kDefaultFadeDuration,
                              curve: seat.busted
                                  ? Curves.easeOutQuad
                                  : Curves.easeOut,
                              child: Center(
                                child: OverflowBox(
                                  minWidth: collapsedSide,
                                  maxWidth: pillW,
                                  minHeight: pillH,
                                  maxHeight: pillH,
                                  alignment: Alignment.center,
                                  child: AnimatedContainer(
                                    duration: reduceMotion
                                        ? Duration.zero
                                        : _kSeatExpandDuration,
                                    curve: Curves.easeOutCubic,
                                    width: shellWidth,
                                    height: pillH,
                                    decoration: BoxDecoration(
                                      color: showExpandedSeat
                                          ? pillFillColor
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(pillH / 2),
                                      border: showExpandedSeat
                                          ? Border.all(
                                              color: Colors.white.withValues(
                                                alpha: isBusted ? 0.06 : 0.14,
                                              ),
                                              width: 1.0,
                                            )
                                          : null,
                                      boxShadow: showExpandedSeat
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.28,
                                                ),
                                                blurRadius: 16,
                                                spreadRadius: 0.5,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(pillH / 2),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (showExpandedSeat &&
                                              shellStatusTint != null &&
                                              !isFolded &&
                                              !isBusted)
                                            Container(color: shellStatusTint),
                                          if (showExpandedSeat &&
                                              isAllIn &&
                                              !isBusted)
                                            Container(color: allInShellTint),
                                          AnimatedPositioned(
                                            duration: reduceMotion
                                                ? Duration.zero
                                                : _kSeatExpandDuration,
                                            curve: Curves.easeOutCubic,
                                            left: avatarLeft,
                                            top: avatarInset,
                                            width: avatarBoxSize,
                                            height: avatarBoxSize,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: border.color,
                                                  width: border.width,
                                                ),
                                                boxShadow: avatarShadows,
                                              ),
                                              child: ClipOval(
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    avatar,
                                                    if (avatarStatusTint !=
                                                            null &&
                                                        !isFolded &&
                                                        !isBusted)
                                                      Container(
                                                        color: avatarStatusTint,
                                                      ),
                                                    if (isAllIn && !isBusted)
                                                      Container(
                                                        color: allInAvatarTint,
                                                      ),
                                                    if (_busting &&
                                                        isBusted &&
                                                        seat.chips <= 0)
                                                      Positioned.fill(
                                                        child: IgnorePointer(
                                                          child:
                                                              AnimatedBuilder(
                                                            animation:
                                                                _bustShatterController,
                                                            builder:
                                                                (context, _) {
                                                              final t = Curves
                                                                  .easeOutCubic
                                                                  .transform(
                                                                _bustShatterController
                                                                    .value,
                                                              );
                                                              final double
                                                                  opacity =
                                                                  (1.0 - t)
                                                                      .clamp(
                                                                0.0,
                                                                1.0,
                                                              );
                                                              final double
                                                                  scale = 0.95 +
                                                                      0.10 * t;
                                                              final double
                                                                  rotation =
                                                                  (t - 0.5) *
                                                                      0.08;
                                                              return Opacity(
                                                                opacity:
                                                                    opacity,
                                                                child: Transform
                                                                    .rotate(
                                                                  angle:
                                                                      rotation,
                                                                  child:
                                                                      Transform
                                                                          .scale(
                                                                    scale:
                                                                        scale,
                                                                    child: SvgPicture
                                                                        .asset(
                                                                      'assets/images/svgs/shattered-glass-svgrepo-com.svg',
                                                                      fit: BoxFit
                                                                          .cover,
                                                                      colorFilter:
                                                                          ColorFilter
                                                                              .mode(
                                                                        Colors
                                                                            .white
                                                                            .withValues(
                                                                          alpha:
                                                                              0.75,
                                                                        ),
                                                                        BlendMode
                                                                            .srcIn,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    if (showRedRing)
                                                      const _CriticalStackRing(),
                                                    if (seat.isHero)
                                                      const _HeroGlow(),
                                                    if (widget.isSB ||
                                                        widget.isBB)
                                                      _BlindRing(
                                                        isSB: widget.isSB,
                                                        isBB: widget.isBB,
                                                      ),
                                                    if (canShowTurn)
                                                      Positioned.fill(
                                                        child: IgnorePointer(
                                                          child: CustomPaint(
                                                            painter:
                                                                _TurnArcPainter(
                                                              animation:
                                                                  _turnController,
                                                              color:
                                                                  const Color(
                                                                0xFFFFC857,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (showExpandedSeat)
                                            Positioned.fill(
                                              left: textLeft,
                                              right: textRight,
                                              child: IgnorePointer(
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: _SeatInfoText(
                                                    name: truncateNice(
                                                      _seatFirstName(seat.name),
                                                      18,
                                                    ),
                                                    betLabel: _formatAmount(
                                                      seat.contributedThisHand,
                                                    ),
                                                    stackLabel: _formatAmount(
                                                      seat.chips,
                                                    ),
                                                    height: pillH,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (widget.showTopBubble)
                            Positioned.fill(
                              child: SeatTopBubbleOverlay(
                                seat: seat,
                                seatWidth: collapsedSide,
                                seatHeight: pillH,
                                persistBustedBubble: widget.persistBustedBubble,
                                seatVisibleOpacity: _opacity,
                              ),
                            ),
                          if (!isBusted && !showExpandedSeat)
                            Positioned(
                              left: -(pillH * 0.14),
                              right: -(pillH * 0.14),
                              bottom: -2,
                              child: IgnorePointer(
                                child: _SeatStackBadge(
                                  name: _seatFirstName(seat.name),
                                  stackLabel: _formatAmount(seat.chips),
                                  betLabel: seat.contributedThisHand > 0
                                      ? _formatAmount(
                                          seat.contributedThisHand,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _syncTurnAnimation(bool active, {required bool reduceMotion}) {
    if (!active) {
      if (!_turnActive && _turnController.value == 0) return;
      _turnActive = false;
      _turnController.stop();
      _turnController.reset();
      return;
    }

    _turnActive = true;
    if (reduceMotion) {
      _turnController.stop();
      _turnController.value = 1;
    } else if (!_turnController.isAnimating) {
      _turnController.repeat();
    }
  }

  void _showSeatDetails() {
    _detailsTimer?.cancel();
    if (!_showDetails) {
      setState(() {
        _showDetails = true;
      });
    }
    _detailsTimer = Timer(_kSeatExpandedVisibleFor, () {
      if (!mounted) return;
      setState(() {
        _showDetails = false;
      });
    });
  }

  String _actionLabelFor(
      Seat seat, bool isFolded, bool isAllIn, bool canShowTurn) {
    final String trimmed = seat.lastAction.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (seat.busted) return 'Busted';
    if (isAllIn) return 'All-In';
    if (isFolded) return 'Folded';
    if (seat.bet > 0) return 'Committed';
    if (canShowTurn) return 'Acting';
    return 'Waiting';
  }

  String _formatAmount(int value) {
    if (value <= 0) return '0';
    return _chipFormat.format(value);
  }

  String _seatFirstName(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Player';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  AvatarMood _resolveMood(Seat seat, bool canShowTurn) {
    if (seat.busted) return AvatarMood.busted;
    if (seat.folded) return AvatarMood.folded;

    final String action = seat.lastAction.toLowerCase();
    if (action.contains('win') || action.contains('winner')) {
      return AvatarMood.win;
    }
    if (action.contains('lose') || action.contains('lost')) {
      return AvatarMood.lose;
    }
    if (action.contains('raise') || action.contains('bet')) {
      return AvatarMood.raise;
    }
    if (seat.allIn || canShowTurn) {
      return AvatarMood.focused;
    }
    return AvatarMood.idle;
  }

  _BorderAttributes _borderForSeat(Seat seat, bool highlightTurn) {
    if (seat.busted) {
      return const _BorderAttributes(Colors.transparent, 0, []);
    }

    Color color = Colors.white24;
    double width = 1.2;

    if (highlightTurn) {
      color = const Color(0xFFFFC857);
      width = 3.4;
    }
    // Blue ring for the current chip leader.
    else if (widget.isLeader) {
      color = const Color(0xFF24B6FF);
      width = 2.8;
    }
    // Green ring for players who are up vs their starting stack.
    else if (seat.profitable) {
      color = const Color(0xFF3BB143);
      width = 2.6;
    }

    final double blur = highlightTurn ? 20 : 14;
    final double spread = highlightTurn ? 1.6 : 0.4;
    final double opacity = highlightTurn
        ? 0.65
        : (widget.isLeader ? 0.52 : (seat.profitable ? 0.42 : 0.28));
    final List<BoxShadow> shadows = [
      BoxShadow(
          color: _seatShellColor(color.withValues(alpha: opacity)),
          blurRadius: blur,
          spreadRadius: spread),
    ];

    return _BorderAttributes(_seatShellColor(color), width, shadows);
  }

  Color? _statusTint(Seat seat) {
    if (seat.busted) return null;
    if (widget.isLeader) return const Color(0xFF24B6FF); // chip leader: blue
    if (seat.profitable) return const Color(0xFF3BB143); // up vs start: green
    if (seat.shortStack) return const Color(0xFFC41230); // low stack: red
    return null;
  }
}

class _BorderAttributes {
  const _BorderAttributes(this.color, this.width, this.shadows);

  final Color color;
  final double width;
  final List<BoxShadow> shadows;
}

String _seatOverlayActionLabel(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return trimmed
      .toUpperCase()
      .replaceAll('RAISE TO ', 'RAISE ')
      .replaceAll('  ', ' ');
}

Color _seatOverlayFillColor(String label) {
  final lower = label.toLowerCase();
  if (lower.startsWith('call') || lower.startsWith('check')) {
    return const Color(0xFF3BB143);
  }
  if (lower.startsWith('raise') || lower.startsWith('bet')) {
    return const Color(0xFF007FFF);
  }
  if (lower.startsWith('all-in') || lower.startsWith('all in')) {
    return const Color(0xFFFF8A65);
  }
  if (lower.startsWith('fold')) {
    return const Color(0xFFC41230);
  }
  return Colors.white;
}

class SeatTopBubbleOverlay extends StatelessWidget {
  const SeatTopBubbleOverlay({
    super.key,
    required this.seat,
    required this.seatWidth,
    required this.seatHeight,
    required this.persistBustedBubble,
    this.seatVisibleOpacity = 1.0,
  });

  final Seat seat;
  final double seatWidth;
  final double seatHeight;
  final bool persistBustedBubble;
  final double seatVisibleOpacity;

  @override
  Widget build(BuildContext context) {
    final String actionLabel = _seatOverlayActionLabel(seat.lastAction);
    final bool showBustedBubble = seat.busted &&
        seat.chips <= 0 &&
        (persistBustedBubble || seatVisibleOpacity > 0.0);
    final String displayLabel = showBustedBubble ? 'BUSTED' : actionLabel;
    if (displayLabel.isEmpty) return const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -seatHeight * 0.42,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: showBustedBubble
                  ? _SeatBustedBubble(
                      key: ValueKey('seat-busted-${seat.avatarKey}'),
                      label: displayLabel,
                      seatWidth: seatWidth,
                      seatHeight: seatHeight,
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      child: _SeatActionBubble(
                        key: ValueKey(
                          'seat-action-${seat.avatarKey}-$displayLabel',
                        ),
                        label: displayLabel,
                        fillColor: _seatOverlayFillColor(displayLabel),
                        seatWidth: seatWidth,
                        seatHeight: seatHeight,
                      ),
                      transitionBuilder: (child, animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          child: child,
                          builder: (context, child) {
                            final double t =
                                animation.value.clamp(0.0, 1.0).toDouble();
                            final double fadeT = Curves.easeOutCubic
                                .transform(t)
                                .clamp(0.0, 1.0);
                            final double popT = Curves.easeOutBack
                                .transform(t)
                                .clamp(0.0, 1.06);
                            return Opacity(
                              opacity: fadeT,
                              child: Transform.translate(
                                offset: Offset(0, (1.0 - fadeT) * 10),
                                child: Transform.scale(
                                  scale: 0.82 + (0.18 * popT),
                                  child: child,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeatActionBubble extends StatelessWidget {
  final String label;
  final Color fillColor;
  final double seatWidth;
  final double seatHeight;

  const _SeatActionBubble({
    super.key,
    required this.label,
    required this.fillColor,
    required this.seatWidth,
    required this.seatHeight,
  });

  @override
  Widget build(BuildContext context) {
    final double bubbleWidth =
        math.max(seatWidth * 0.96, seatHeight * 1.34).toDouble();
    return SizedBox(
      width: bubbleWidth,
      height: seatHeight * 0.52,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SeatActionTextPainter(
            text: label,
            fillColor: fillColor,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SeatBustedBubble extends StatelessWidget {
  final String label;
  final double seatWidth;
  final double seatHeight;

  const _SeatBustedBubble({
    super.key,
    required this.label,
    required this.seatWidth,
    required this.seatHeight,
  });

  @override
  Widget build(BuildContext context) {
    final double bubbleWidth =
        math.max(seatWidth * 1.02, seatHeight * 1.46).toDouble();
    return SizedBox(
      width: bubbleWidth,
      height: seatHeight * 0.68,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SeatBustedTextPainter(text: label),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SeatActionTextPainter extends CustomPainter {
  final String text;
  final Color fillColor;

  const _SeatActionTextPainter({
    required this.text,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final String t = text.trim().toUpperCase();
    if (t.isEmpty || size.isEmpty) return;

    final double maxTextWidth = size.width * 0.96;
    final double maxTextHeight = size.height * 0.94;
    double fontSize = (size.height * 0.62).clamp(10.0, 22.0).toDouble();
    TextStyle base = TextStyle(
      fontFamily: 'OpenSans',
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
        maxLines: 1,
      )..layout(maxWidth: maxTextWidth);
    }

    TextPainter fill = buildPainter(
      Paint()
        ..style = PaintingStyle.fill
        ..color = fillColor,
    );

    while ((fill.didExceedMaxLines || fill.height > maxTextHeight) &&
        fontSize > 10.0) {
      fontSize = (fontSize - 0.5).clamp(10.0, 22.0).toDouble();
      base = base.copyWith(fontSize: fontSize);
      fill = buildPainter(
        Paint()
          ..style = PaintingStyle.fill
          ..color = fillColor,
      );
    }

    final double strokeWidth = (fontSize * 0.095).clamp(1.2, 3.2).toDouble();
    final TextPainter stroke = buildPainter(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );

    final Offset offset = Offset(
      (size.width - stroke.width) / 2,
      (size.height - stroke.height) / 2,
    );
    stroke.paint(canvas, offset);
    fill.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SeatActionTextPainter oldDelegate) {
    return oldDelegate.text != text || oldDelegate.fillColor != fillColor;
  }
}

class _SeatBustedTextPainter extends CustomPainter {
  final String text;

  const _SeatBustedTextPainter({
    required this.text,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final String t = text.trim().toUpperCase();
    if (t.isEmpty || size.isEmpty) return;

    final double maxTextWidth = size.width * 0.96;
    final double maxTextHeight = size.height * 0.66;
    double fontSize = (size.height * 0.50).clamp(12.0, 24.0).toDouble();
    TextStyle base = TextStyle(
      fontFamily: 'OpenSans',
      fontWeight: FontWeight.w900,
      fontSize: fontSize,
      height: 1.0,
      letterSpacing: 0.2,
    );

    TextPainter buildPainter(Paint paint) {
      return TextPainter(
        text: TextSpan(
          text: t,
          style: base.copyWith(foreground: paint),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
      )..layout(maxWidth: maxTextWidth);
    }

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFD10D24);
    TextPainter fill = buildPainter(fillPaint);

    while ((fill.didExceedMaxLines || fill.height > maxTextHeight) &&
        fontSize > 12.0) {
      fontSize = (fontSize - 0.5).clamp(12.0, 24.0).toDouble();
      base = base.copyWith(fontSize: fontSize);
      fill = buildPainter(fillPaint);
    }

    final double strokeWidth = (fontSize * 0.11).clamp(1.4, 3.4).toDouble();
    final TextPainter glow = buildPainter(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0x88FF243B)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final TextPainter stroke = buildPainter(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );

    final Offset offset = Offset(
      (size.width - stroke.width) / 2,
      size.height * 0.02,
    );

    final double textBottom = offset.dy + stroke.height * 0.86;
    final double left = offset.dx;
    final double right = offset.dx + stroke.width;
    final double width = stroke.width;
    final Color dripColor = const Color(0xFF8D0014);
    final Paint dripShadow = Paint()
      ..color = const Color(0xAA320008)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final Paint dripPaint = Paint()..color = dripColor;
    final Paint dripHighlight = Paint()..color = const Color(0x66FF6472);

    void drawDrip({
      required double x,
      required double stemWidth,
      required double stemHeight,
      required double dropRadius,
    }) {
      final Rect stemRect = Rect.fromCenter(
        center: Offset(x, textBottom + stemHeight * 0.45),
        width: stemWidth,
        height: stemHeight,
      );
      final RRect stem = RRect.fromRectAndRadius(
        stemRect,
        Radius.circular(stemWidth / 2),
      );
      final Offset dropCenter = Offset(
        x,
        textBottom + stemHeight + dropRadius * 0.55,
      );
      canvas.drawRRect(stem.shift(const Offset(0, 1.4)), dripShadow);
      canvas.drawCircle(dropCenter.translate(0, 1.8), dropRadius, dripShadow);
      canvas.drawRRect(stem, dripPaint);
      canvas.drawCircle(dropCenter, dropRadius, dripPaint);
      canvas.drawCircle(
        Offset(x - stemWidth * 0.14, textBottom + stemHeight * 0.20),
        stemWidth * 0.18,
        dripHighlight,
      );
    }

    drawDrip(
      x: left + width * 0.18,
      stemWidth: fontSize * 0.16,
      stemHeight: fontSize * 0.30,
      dropRadius: fontSize * 0.12,
    );
    drawDrip(
      x: left + width * 0.54,
      stemWidth: fontSize * 0.20,
      stemHeight: fontSize * 0.42,
      dropRadius: fontSize * 0.15,
    );
    drawDrip(
      x: right - width * 0.14,
      stemWidth: fontSize * 0.15,
      stemHeight: fontSize * 0.25,
      dropRadius: fontSize * 0.11,
    );

    glow.paint(canvas, offset);
    stroke.paint(canvas, offset);
    fill.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SeatBustedTextPainter oldDelegate) {
    return oldDelegate.text != text;
  }
}

String _firstName(String fullName) {
  if (fullName.isEmpty) return fullName;
  final trimmed = fullName.trim();
  final int space = trimmed.indexOf(' ');
  final String name = space <= 0 ? trimmed : trimmed.substring(0, space);
  return truncateNice(name, 12);
}

class _HeroGlow extends StatelessWidget {
  const _HeroGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: const ShapeDecoration(
          shape: CircleBorder(
            side: BorderSide(color: Color(0x3324B6FF), width: 5),
          ),
        ),
      ),
    );
  }
}

class _CriticalStackRing extends StatelessWidget {
  const _CriticalStackRing();

  @override
  Widget build(BuildContext context) {
    final Color color =
        _seatShellColor(const Color(0xFFC41230).withValues(alpha: 0.85));
    return IgnorePointer(
      child: Container(
        decoration: ShapeDecoration(
          shape: CircleBorder(side: BorderSide(color: color, width: 4)),
        ),
      ),
    );
  }
}

class _TurnArcPainter extends CustomPainter {
  _TurnArcPainter({required this.animation, required this.color})
      : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = size.shortestSide * 0.08;
    final Rect rect = Offset.zero & size;
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = _seatShellColor(color.withValues(alpha: 0.28));
    canvas.drawArc(rect.deflate(stroke / 2), 0, math.pi * 2, false, base);

    final double sweep = math.pi * 0.7;
    final double start = (animation.value * math.pi * 2) % (math.pi * 2);
    final Paint sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.05
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + sweep,
        colors: [
          _seatShellColor(color.withValues(alpha: 0.12)),
          _seatShellColor(color),
          _seatShellColor(color.withValues(alpha: 0.12)),
        ],
      ).createShader(rect.deflate(stroke / 2));

    canvas.drawArc(rect.deflate(stroke / 2), start, sweep, false, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _TurnArcPainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.color != color;
  }
}

class _BlindRing extends StatelessWidget {
  const _BlindRing({required this.isSB, required this.isBB});

  final bool isSB;
  final bool isBB;

  @override
  Widget build(BuildContext context) {
    final Color color = isBB
        ? _seatShellColor(Colors.orangeAccent.withValues(alpha: 0.55))
        : _seatShellColor(Colors.white.withValues(alpha: 0.45));
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: ShapeDecoration(
          shape: CircleBorder(side: BorderSide(color: color, width: 4)),
        ),
      ),
    );
  }
}

class _SeatInfoChip extends StatelessWidget {
  const _SeatInfoChip({required this.text, this.highlight = false});

  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Color border = highlight
        ? const Color(0xFF24B6FF)
        : Colors.white.withValues(alpha: 0.18);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: highlight ? 1.2 : 0.8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SeatStackBadge extends StatelessWidget {
  const _SeatStackBadge({
    required this.name,
    required this.stackLabel,
    this.betLabel,
  });

  final String name;
  final String stackLabel;
  final String? betLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 0.8,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'OpenSans',
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    stackLabel,
                    maxLines: 1,
                    style: const TextStyle(
                      color: _kSeatStackTextColor,
                      fontFamily: 'OpenSans',
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                      height: 1,
                    ),
                  ),
                  if (betLabel != null) ...<Widget>[
                    const Text(
                      ' • ',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        height: 1,
                      ),
                    ),
                    Text(
                      betLabel!,
                      maxLines: 1,
                      style: const TextStyle(
                        color: _kSeatBetTextColor,
                        fontFamily: 'OpenSans',
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatInfoText extends StatelessWidget {
  const _SeatInfoText({
    required this.name,
    required this.betLabel,
    required this.stackLabel,
    required this.height,
  });

  final String name;
  final String betLabel;
  final String stackLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double nameSize =
        ((height * 0.23) * 0.90).clamp(9.5, 15.3).toDouble();
    final double metaSize =
        ((height * 0.18) * 0.90).clamp(8.2, 11.9).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.w800,
            fontSize: nameSize,
            height: 1.0,
          ),
        ),
        SizedBox(height: (height * 0.04).clamp(1.0, 3.0).toDouble()),
        Text(
          betLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _kSeatBetTextColor,
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.w800,
            fontSize: metaSize,
            height: 1.0,
          ),
        ),
        SizedBox(height: (height * 0.025).clamp(0.5, 2.0).toDouble()),
        Text(
          stackLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _kSeatStackTextColor,
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.w800,
            fontSize: metaSize,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

/* ──────────────────────────────────────────────
 * Seat positions helper
 * ─────────────────────────────────────────── */
List<Offset> seatPositionsWithGapAndPush({
  required double w,
  required double h,
  required int n,
  required double seatW,
  required double seatH,
  required double topGapRadians,
  required double softBandRadians,
  required double pushDownPx,
  required int heroIndex,
}) {
  final double cx = w / 2;
  final double cy = h / 2;
  final double rx = (w * 0.46);
  final double ry = (h * 0.42);

  final double gap = topGapRadians.clamp(0.0, math.pi).toDouble();
  final double softBand = softBandRadians.clamp(0.0, math.pi / 2).toDouble();
  final double available = (2 * math.pi) - gap;
  final double spacing = available / n;

  final double start = (-math.pi / 2) + (gap / 2) + (spacing / 2);
  final List<double> baseAngles =
      List<double>.generate(n, (i) => start + i * spacing);

  const double target = math.pi / 2;
  int anchorIdx = 0;
  double best = double.infinity;
  for (int i = 0; i < baseAngles.length; i++) {
    final double d = (baseAngles[i] - target).abs();
    if (d < best) {
      best = d;
      anchorIdx = i;
    }
  }

  final int heroIdx = (heroIndex < 0 || heroIndex >= n) ? 0 : heroIndex;
  const double inset = 12.0;
  const double topCenter = -math.pi / 2;

  final List<Offset> out = [];
  for (int i = 0; i < n; i++) {
    final int idx = ((i - heroIdx + anchorIdx) % n + n) % n;
    final double a = baseAngles[idx];

    final double px = cx + rx * math.cos(a);
    double py = cy + ry * math.sin(a);

    final double delta = (a - topCenter).abs();
    final double bandStart = gap / 2;
    final double bandEnd = bandStart + softBand;
    if (delta > bandStart && delta < bandEnd) {
      final double t = 1.0 - ((delta - bandStart) / (bandEnd - bandStart));
      py += (pushDownPx * t);
    }

    double x = px - seatW / 2;
    double y = py - seatH / 2;

    final double minX = math.min(inset, w - seatW - inset);
    final double maxX = math.max(inset, w - seatW - inset);
    final double minY = math.min(inset, h - seatH - inset);
    final double maxY = math.max(inset, h - seatH - inset);
    x = x.clamp(minX, maxX);
    y = y.clamp(minY, maxY);

    out.add(Offset(x, y));
  }
  return out;
}
