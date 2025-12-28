import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'models.dart'; // GCard, truncateNice
import 'cards.dart' show ActionGate;
import 'bot_avatar.dart';

/* ──────────────────────────────────────────────
 * Legibility floors
 * ─────────────────────────────────────────── */
/// Target diameter (in pixels) for seat widgets.
const double kSeatDiameterPx = 128.0;
const double _kSeatMinSide = kSeatDiameterPx;

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
  int enduranceMinutes;
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
    this.enduranceMinutes = 0,
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
  static final NumberFormat _chipFormat = NumberFormat.compact();
  double _opacity = 1.0;
  Timer? _fadeTimer;
  late final AnimationController _turnController;
  late final AnimationController _bustShatterController;
  bool _turnActive = false;
  bool _busting = false;

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
            _syncTurnAnimation(canShowTurn);
            final AvatarMood mood = _resolveMood(seat, canShowTurn);

            final double maxW = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : widget.seatMaxWidth;
            final double maxH = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : widget.seatHeight;
            double side = math.min(maxW, maxH);
            if (!side.isFinite || side <= 0) {
              side = math.min(widget.seatMaxWidth, widget.seatHeight);
            }
            final double minSide = math.min(_kSeatMinSide, widget.seatMaxWidth);
            final double maxSide = math.max(minSide, widget.seatMaxWidth);
            side = side.clamp(minSide, maxSide).toDouble();

            final _BorderAttributes border = _borderForSeat(seat, canShowTurn);
            final Color? statusTint = _statusTint(seat);

            return AnimatedScale(
              scale: (widget.growWhenOthersGone && !isBusted) ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: _opacity,
                duration:
                    seat.busted ? _kBustFadeDuration : _kDefaultFadeDuration,
                curve: seat.busted ? Curves.easeOutQuad : Curves.easeOut,
                child: Center(
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: border.color, width: border.width),
                        boxShadow: border.shadows,
                      ),
                      child: ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            BotAvatar(
                              avatarKey: seat.avatarKey,
                              mood: mood,
                              assetFolder: seat.avatarAssetFolder,
                              fallbackAsset: widget.fallbackAvatarAsset,
                            ),
                            if (statusTint != null && !isFolded && !isBusted)
                              Container(
                                  color: statusTint.withValues(alpha: 0.10)),
                            if (isFolded && !isBusted)
                              Container(
                                  color: Colors.white.withValues(alpha: 0.25)),
                            if (isAllIn && !isBusted)
                              Container(color: const Color(0x33FF8A65)),
                            if (_busting && isBusted && seat.chips <= 0)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _bustShatterController,
                                    builder: (context, _) {
                                      final t = Curves.easeOutCubic.transform(
                                          _bustShatterController.value);
                                      final double opacity =
                                          (1.0 - t).clamp(0.0, 1.0);
                                      final double scale = 0.95 + 0.10 * t;
                                      final double rotation = (t - 0.5) * 0.08;
                                      return Opacity(
                                        opacity: opacity,
                                        child: Transform.rotate(
                                          angle: rotation,
                                          child: Transform.scale(
                                            scale: scale,
                                            child: SvgPicture.asset(
                                              'assets/images/svgs/shattered-glass-svgrepo-com.svg',
                                              fit: BoxFit.cover,
                                              colorFilter: ColorFilter.mode(
                                                Colors.white
                                                    .withValues(alpha: 0.75),
                                                BlendMode.srcIn,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (showRedRing) const _CriticalStackRing(),
                            if (seat.isHero) const _HeroGlow(),
                            if (widget.isSB || widget.isBB)
                              _BlindRing(isSB: widget.isSB, isBB: widget.isBB),
                            if (canShowTurn)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _TurnArcPainter(
                                      animation: _turnController,
                                      color: const Color(0xFFFFC857),
                                    ),
                                  ),
                                ),
                              ),
                            if (!isBusted)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 10),
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: _SeatInfoChip(
                                        text: _actionLabelFor(seat, isFolded,
                                                isAllIn, canShowTurn)
                                            .toUpperCase(),
                                        highlight: canShowTurn ||
                                            seat.lastAction
                                                .toLowerCase()
                                                .contains('win'),
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _syncTurnAnimation(bool active) {
    if (active == _turnActive) return;
    _turnActive = active;
    if (active) {
      _turnController.repeat();
    } else {
      _turnController.stop();
      _turnController.reset();
    }
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
    final double opacity =
        highlightTurn
            ? 0.65
            : (widget.isLeader ? 0.52 : (seat.profitable ? 0.42 : 0.28));
    final List<BoxShadow> shadows = [
      BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: blur,
          spreadRadius: spread),
    ];

    return _BorderAttributes(color, width, shadows);
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
            side: BorderSide(color: Color(0x6624B6FF), width: 5),
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
    final Color color = const Color(0xFFC41230).withValues(alpha: 0.85);
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
      ..color = color.withValues(alpha: 0.28);
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
          color.withValues(alpha: 0.12),
          color,
          color.withValues(alpha: 0.12),
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
        ? Colors.orangeAccent.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.45);
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
  const _SeatStackBadge({required this.stackLabel, this.betLabel});

  final String stackLabel;
  final String? betLabel;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
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
