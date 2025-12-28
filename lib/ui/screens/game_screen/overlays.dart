// lib/ui/screens/game_screen/overlays.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import 'package:intl/intl.dart';
import 'package:playing_cards/playing_cards.dart' as pc;

import 'package:ten_of_a_kind_poker/ui/screens/game_screen/bot_avatar.dart'
    show AvatarMood, BotAvatar;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/cards.dart'
    show PlayingCard, FaceCard;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/players.dart'
    show Seat;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/models.dart'
    show truncateNice;
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/slash_avatar.dart'
    show DealerAvatarStyle, SlashJacketTone, buildDealerSkinAvatar;

const Color _kBestHandOutline = Color(0xFF24B6FF);

/* ---------- Global Winners bus (dialog lifecycle) ---------- */
class WinnersBusEvent {
  /// true = dialog/banner just appeared, false = fully closed
  final bool shown;
  const WinnersBusEvent({required this.shown});
}

class WinnersBus {
  static final _ctrl = StreamController<WinnersBusEvent>.broadcast();
  static Stream<WinnersBusEvent> get stream => _ctrl.stream;
  static void fireShown() => _ctrl.add(const WinnersBusEvent(shown: true));
  static void fireClosed() => _ctrl.add(const WinnersBusEvent(shown: false));
}

void _showCelebrationBurst(BuildContext context) {
  final overlayState = Navigator.of(context, rootNavigator: true).overlay;
  if (overlayState == null) return;

  // Only applause; camera flash removed per request.
  unawaited(SoundFx.instance.playApplause());
}

/// Stores the most recent hand-winner snapshot so the Info button can recall it.
class LastHandSnapshot {
  final List<WinnerLine> winners;
  final WinnerLine? hero;
  final List<UiCard> board;
  final int totalPot;
  final DateTime at;
  const LastHandSnapshot({
    required this.winners,
    required this.totalPot,
    required this.at,
    this.hero,
    this.board = const [],
  });
}

class LastHandStore {
  static LastHandSnapshot? _last;
  static LastHandSnapshot? get last => _last;
  static void set({
    required List<WinnerLine> winners,
    required int totalPot,
    WinnerLine? hero,
    List<UiCard>? board,
  }) {
    _last = LastHandSnapshot(
      winners: winners,
      hero: hero,
      board: board ?? const [],
      totalPot: totalPot,
      at: DateTime.now(),
    );
  }

  static void clear() {
    _last = null;
  }
}

/* ---------- Brand palette & text styles ---------- */
const _kRed = Color(0xFFFF2800);
const _kBlue = Color(0xFF24B6FF);
const _kWhite = Color(0xFFFFFFFF);
const _kDialogBg = Color(0xFF141414);

/* ---------- Felt palette by venue / kingdom ---------- */
const Map<String, Color> _kKingdomFeltColors = {
  'Africa': Color(0xFF556B2F),
  'Amazon': Color(0xFF013220),
  'S. America': Color(0xFF013220),
  'America': Color(0xFF24247A),
  'N. America': Color(0xFF24247A),
  'Arabia': Color.fromARGB(227, 95, 65, 58),
  'Australia': Color.fromARGB(218, 203, 160, 20),
  'Baroda': Color.fromARGB(218, 203, 160, 20),
  'China': Color(0xFF8B0000),
  'Europe': Color.fromARGB(204, 220, 83, 220),
  'Gwalior': Color(0xFF1565C0),
  'Hyderabad': Color.fromARGB(173, 118, 30, 180),
  'Indore': Color(0xFF8B0000),
  'India': Color.fromARGB(208, 0, 166, 232),
  'International': Color(0xFF24B6FF),
  'Jaipur': Color.fromARGB(204, 220, 83, 220),
  'Japan': Color(0xFFB71C1C),
  'Maratha Empire': Color.fromARGB(212, 255, 107, 1),
  'Mewar': Color(0xFF2E8B57),
  'Mysore': Color.fromARGB(227, 95, 65, 58),
  'New Delhi': Color.fromARGB(208, 0, 166, 232),
  'Russia': Color.fromARGB(173, 118, 30, 180),
  'Sikh Empire': Color.fromARGB(255, 36, 36, 122),
  'Sikkim': Color(0xFF013220),
  'Asia': Color.fromARGB(212, 255, 107, 1),
  'Southeast': Color.fromARGB(212, 255, 107, 1),
  'Travancore': Color(0xFF556B2F),
};

Color _feltTextColor(Color color) {
  return Color.lerp(color, Colors.white, 0.35)!;
}

Color feltColorForKingdom(String? name,
    {Color fallback = const Color(0xB3FFFFFF)}) {
  if (name == null) return fallback;
  final trimmed = name.trim();
  if (trimmed.isEmpty || trimmed == '-' || trimmed == '—') return fallback;
  final direct = _kKingdomFeltColors[trimmed];
  if (direct != null) return _feltTextColor(direct);
  final lower = trimmed.toLowerCase();
  for (final entry in _kKingdomFeltColors.entries) {
    if (entry.key.toLowerCase() == lower) return _feltTextColor(entry.value);
  }
  return fallback;
}

const TextStyle _kKingdomBaseStyle = TextStyle(
  color: _kBlue,
  fontSize: 13.5,
  height: 1.1,
);

const _kTitleStyle = TextStyle(
  color: _kRed,
  fontWeight: FontWeight.w900,
  fontSize: 18,
  letterSpacing: 0.2,
  height: 1.0,
);

const _kSubtitleStyle = TextStyle(
  color: _kBlue,
  fontWeight: FontWeight.w700,
  fontSize: 15,
  height: 1.05,
);

const _kBodyStyle = TextStyle(
  color: _kWhite,
  fontSize: 14.5,
  height: 1.15,
);

BoxDecoration renoirGlassPanelDecoration(
    {double radius = 16, double opacity = 0.58}) {
  return BoxDecoration(
    color: Colors.black.withValues(alpha: opacity),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white24),
    boxShadow: const [
      BoxShadow(color: Color(0x80000000), blurRadius: 24, spreadRadius: 1),
    ],
  );
}

/* ---------- Shining Golden Text utility ---------- */
class GoldenText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  const GoldenText(
    this.text, {
    super.key,
    this.style = const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    this.textAlign = TextAlign.center,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF4C2), // light gold
            Color(0xFFFFD76E), // warm gold
            Color(0xFFE6B400), // mid gold
            Color(0xFF8C6A00), // deep gold
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        style: style.copyWith(
          // The color is replaced by the shader; keep white for legibility fallback
          color: Colors.white,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
            Shadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}

class OverlayStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const OverlayStatChip(
      {super.key, required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white60),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: _kBodyStyle.copyWith(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GoldenText(
            value,
            style: _kTitleStyle.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/* ---------- Renoir voice helpers (English, Monsieur/Madame) ---------- */
String _renoirAddress(String name) {
  final t = name.trim();
  if (t.isEmpty) return 'Monsieur';
  final first = t.split(' ').first;
  final isMadame = first.endsWith('a') || first.endsWith('e');
  return isMadame ? 'Madame $first' : 'Monsieur $first';
}

String renoirWelcomeLine() => 'Ladies and gentlemen, welcome to the table.';
String renoirBeginLine() => 'The game begins. Shuffle up and deal.';

String renoirCongratsLine({
  required String winnerName,
  String? winningHandName,
  int? winnings,
}) {
  final who = _renoirAddress(winnerName);
  final hand = (winningHandName != null && winningHandName.isNotEmpty)
      ? ' with $winningHandName'
      : '';
  final chips =
      (winnings != null && winnings > 0) ? '  •  +$winnings chips' : '';
  return 'Congratulations, $who$hand.$chips';
}

/* ---------- Winner Splash (toast) ---------- */
Future<void> showWinnerSplash(
  BuildContext context, {
  required String title,
  required String subtitle,
  Duration duration = const Duration(seconds: 2),
}) {
  return _showAutoBanner(
    context,
    duration: duration,
    child: WinnerBanner(
      icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
      title: title,
      subtitle: subtitle,
    ),
    alignment: Alignment.topCenter,
    dedupeKey: 'winner:$title|$subtitle',
  );
}

class _OverlayBannerHandle {
  final OverlayEntry entry;
  final AnimationController controller;
  final Completer<void> _completed = Completer<void>();
  Timer? _autoCloseTimer;
  bool _closing = false;

  _OverlayBannerHandle({
    required this.entry,
    required this.controller,
  });

  void startAutoClose(Duration duration) {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(duration, () {
      // Fire and forget; the completer ensures callers can await close().
      close();
    });
  }

  Future<void> close() async {
    if (_closing) return _completed.future;
    _closing = true;
    _autoCloseTimer?.cancel();
    _autoCloseTimer = null;
    try {
      final startValue = controller.value.clamp(0.0, 1.0);
      if (startValue > 0.0) {
        await controller.reverse(from: startValue);
      }
    } catch (_) {
      // Ignore ticker cancellations; we still remove the entry.
    }
    try {
      entry.remove();
    } catch (_) {}
    try {
      controller.dispose();
    } catch (_) {}
    if (!_completed.isCompleted) {
      _completed.complete();
    }
    return _completed.future;
  }

  Future<void> get completed => _completed.future;
}

_OverlayBannerHandle? _activeWelcomeBanner;

/* ---------- Renoir Welcome (compact) ---------- */
Future<void> showWelcomeRenoir(
  BuildContext context, {
  String? avatarAsset,
  String heading = 'Welcome to the Table',
  List<PlayerBrief> players = const [],
  Duration duration = const Duration(seconds: 5),
}) async {
  await dismissWelcomeRenoir();

  final overlayState = Navigator.of(context, rootNavigator: true).overlay;
  if (overlayState == null) return;

  final controller = AnimationController(
    vsync: overlayState,
    duration: const Duration(milliseconds: 180),
  );

  final curved =
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
  final offsetTween =
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
          .animate(curved);
  final opacityTween = Tween<double>(begin: 0, end: 1).animate(curved);

  final entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      ignoring: true,
      child: SafeArea(
        child: Align(
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, offsetTween.value.dy * 24.0),
              child: Opacity(
                opacity: opacityTween.value,
                child: RenoirWelcomePanel(
                  heading: heading,
                  players: players,
                  avatarAsset: avatarAsset,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  final handle = _OverlayBannerHandle(entry: entry, controller: controller);
  _activeWelcomeBanner = handle;

  var timerStarted = false;
  controller.addStatusListener((status) {
    if (status == AnimationStatus.completed &&
        !timerStarted &&
        identical(_activeWelcomeBanner, handle)) {
      timerStarted = true;
      handle.startAutoClose(duration);
    }
  });

  overlayState.insert(entry);
  controller.forward();

  await handle.completed;
  if (identical(_activeWelcomeBanner, handle)) {
    _activeWelcomeBanner = null;
  }
}

Future<void> dismissWelcomeRenoir() async {
  final handle = _activeWelcomeBanner;
  if (handle == null) return;
  await handle.close();
  if (identical(_activeWelcomeBanner, handle)) {
    _activeWelcomeBanner = null;
  }
}

/* ---------- Renoir congrats (Match Over) ---------- */
Future<void> showRenoirCongratsForMatch(
  BuildContext context, {
  required String winnerName,
  Seat? winnerSeat,
  String venueName = '',
  String venueFlagAsset = '',
  int prize = 100000,
  String? renoirAsset,
  String? winningHandName,
  int? winnings,
  Duration? duration, // ignored: persistent modal now
  VoidCallback? onExitToVenue,
  Future<void> Function()? onDownloadCertificate,
  String certificateButtonLabel = 'Download Certificate',
}) async {
  final Seat? seat = winnerSeat;
  final String displayName =
      (seat?.name ?? winnerName).toString().trim().isNotEmpty
          ? (seat?.name ?? winnerName).toString().trim()
          : 'Winner';
  final String kingdom = (seat?.kingdom ?? '').toString().trim();
  final String kingdomFlagPath = _flagForKingdom(kingdom);
  final String vName = venueName.trim();
  final String vFlag = venueFlagAsset.trim();

  final int prizeValue = prize > 0 ? prize : 100000;
  final String prizeLabel =
      NumberFormat.decimalPattern('en_IN').format(prizeValue);

  bool closedFired = false;
  bool firedOnShown = false;
  bool downloading = false;
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false, // persistent until explicit exit
    barrierColor: Colors.transparent,
    builder: (dialogCtx) {
      if (!firedOnShown) {
        firedOnShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(SoundFx.instance.playGameWinnerApplause());
          WinnersBus.fireShown();
        });
      }

      return StatefulBuilder(
        builder: (ctx, setLocalState) {
          return AlertDialog(
            backgroundColor: _kDialogBg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GoldenText(
                  'Match Winner',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (vName.isNotEmpty || vFlag.isNotEmpty)
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      if (vFlag.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            vFlag,
                            width: 40,
                            height: 24,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 40,
                              height: 24,
                              color: Colors.white12,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.flag_outlined,
                                color: Colors.white54,
                                size: 16,
                              ),
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.flag_outlined,
                          color: Colors.white54,
                          size: 16,
                        ),
                      Text(
                        vName.isNotEmpty ? vName : 'Venue',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 152,
                  height: 152,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18), width: 2),
                  ),
                  child: ClipOval(
                    child: seat != null
                        ? BotAvatar(
                            avatarKey: seat.avatarKey,
                            mood: AvatarMood.win,
                            assetFolder: seat.avatarAssetFolder,
                            fallbackAsset: 'assets/images/default_profile.png',
                          )
                        : Image.asset(
                            'assets/images/default_profile.png',
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 0.2,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                if (kingdom.isNotEmpty && kingdom != '-')
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      if (kingdomFlagPath.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            kingdomFlagPath,
                            width: 36,
                            height: 24,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 36,
                              height: 24,
                              color: Colors.white12,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.flag_outlined,
                                color: Colors.white54,
                                size: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.flag_outlined,
                          color: Colors.white54,
                          size: 14,
                        ),
                      Text(
                        kingdom,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
                GoldenText(
                  'Prize $prizeLabel',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              if (onDownloadCertificate != null)
                TextButton(
                  onPressed: downloading
                      ? null
                      : () async {
                          setLocalState(() => downloading = true);
                          try {
                            await onDownloadCertificate();
                          } catch (_) {
                            // ignore
                          } finally {
                            if (ctx.mounted) {
                              setLocalState(() => downloading = false);
                            }
                          }
                        },
                  child: Text(
                    downloading ? 'Preparing…' : certificateButtonLabel,
                    style: _kBodyStyle,
                  ),
                ),
              TextButton(
                onPressed: () {
                  try {
                    onExitToVenue?.call();
                  } catch (_) {}
                  Navigator.of(ctx, rootNavigator: true).maybePop();
                  if (!closedFired) {
                    closedFired = true;
                    WinnersBus.fireClosed();
                  }
                },
                child: const Text('Exit to Venue', style: _kBodyStyle),
              ),
            ],
          );
        },
      );
    },
  );
  if (!closedFired) {
    closedFired = true;
    WinnersBus.fireClosed();
  }
}

/* ---------- Internal auto banner (OverlayEntry) ---------- */
class _BannerRegistry {
  static final Map<String, DateTime> _lastShown = <String, DateTime>{};

  static bool shouldShow(String key, Duration cooldown) {
    final now = DateTime.now();
    final last = _lastShown[key];
    if (last == null || now.difference(last) >= cooldown) {
      _lastShown[key] = now;
      return true;
    }
    return false;
  }
}

Future<void> _showAutoBanner(
  BuildContext context, {
  required Widget child,
  required Duration duration,
  Alignment alignment = Alignment.topCenter,
  String? dedupeKey,
  Duration dedupeCooldown = const Duration(seconds: 2),
}) async {
  if (dedupeKey != null &&
      !_BannerRegistry.shouldShow(dedupeKey, dedupeCooldown)) {
    return;
  }

  final overlayState = Navigator.of(context, rootNavigator: true).overlay;
  if (overlayState == null) return;

  final controller = AnimationController(
    vsync: overlayState,
    duration: const Duration(milliseconds: 180),
  );

  final curved =
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
  final beginOffset = alignment == Alignment.center
      ? const Offset(0, 0.06)
      : const Offset(0, -0.06);
  final offsetTween =
      Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(curved);
  final opacityTween = Tween<double>(begin: 0, end: 1).animate(curved);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      ignoring: true,
      child: SafeArea(
        child: Align(
          alignment: alignment,
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, offsetTween.value.dy * 24.0),
              child: Opacity(opacity: opacityTween.value, child: child),
            ),
          ),
        ),
      ),
    ),
  );

  overlayState.insert(entry);
  await controller.forward();
  await Future.delayed(duration);
  await controller.reverse();
  entry.remove();
  controller.dispose();
}

/* ---------- Confirm dialog (modal) ---------- */
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelText = 'Cancel',
  String confirmText = 'OK',
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: _kDialogBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      title: Text(title, textAlign: TextAlign.center, style: _kTitleStyle),
      content: Text(message, textAlign: TextAlign.center, style: _kBodyStyle),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
          child: const Text('Cancel', style: _kBodyStyle),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: Colors.redAccent)
              : null,
          child: const Text('OK', style: _kBodyStyle),
        ),
      ],
    ),
  );
}

/* ---------- Winner banner (toast-style) ---------- */
class WinnerBanner extends StatelessWidget {
  final String? avatarAsset;
  final Widget? icon;
  final String title;
  final String subtitle;
  final double maxWidth;
  final double bannerHeight;
  final bool goldenTitle;
  final bool goldenSubtitle;

  const WinnerBanner({
    super.key,
    this.avatarAsset,
    this.icon,
    required this.title,
    required this.subtitle,
    this.maxWidth = 460,
    this.bannerHeight = 112.0,
    this.goldenTitle = false,
    this.goldenSubtitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasLeading = icon != null;

    Widget? leading;
    if (icon != null) {
      leading = icon!;
    }

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          minWidth: 220,
          minHeight: bannerHeight,
          maxHeight: bannerHeight,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: hasLeading ? 16 : 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x80000000), blurRadius: 24, spreadRadius: 1),
            ],
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...(goldenTitle
                        ? [
                            GoldenText(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _kTitleStyle,
                            ),
                          ]
                        : [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _kTitleStyle,
                            ),
                          ]),
                    const SizedBox(height: 4),
                    ...(goldenSubtitle
                        ? [
                            GoldenText(
                              subtitle,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _kSubtitleStyle,
                            ),
                          ]
                        : [
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _kSubtitleStyle,
                            ),
                          ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------- Reusable player line (Name + Kingdom + About) ---------- */
class PlayerLineTile extends StatelessWidget {
  final int?
      index; // 1-based index for lists (optional, ignored when showAvatar)
  final String name;
  final String kingdom;
  final String about;
  final int? aura;
  final TextStyle nameStyle;
  final TextStyle? kingdomStyle;
  final TextStyle aboutStyle;
  final double spacing;
  final bool showAvatar;
  final String? flagPath;
  final bool showAboutInline;
  final bool showAboutTrailing;
  final bool showAuraBadge;

  const PlayerLineTile({
    super.key,
    this.index,
    required this.name,
    required this.kingdom,
    required this.about,
    this.aura,
    this.nameStyle = _kSubtitleStyle,
    this.kingdomStyle,
    this.aboutStyle =
        const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.1),
    this.spacing = 2.0,
    this.showAvatar = false,
    this.flagPath,
    this.showAboutInline = true,
    this.showAboutTrailing = false,
    this.showAuraBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final prefix = (index != null && !showAvatar) ? '${index!}. ' : '';
    final TextStyle baseKingdomStyle = kingdomStyle ?? _kKingdomBaseStyle;
    final Color resolvedColor =
        kingdomStyle?.color ?? feltColorForKingdom(kingdom);
    final TextStyle resolvedKingdomStyle =
        baseKingdomStyle.copyWith(color: resolvedColor);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAvatar)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _FlagAvatar(
              flagPath: flagPath,
              name: name,
            ),
          )
        else if (index != null)
          Text(prefix, style: _kBodyStyle.copyWith(color: Colors.white70)),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: name, style: nameStyle),
                const TextSpan(text: ' ('),
                TextSpan(text: kingdom, style: resolvedKingdomStyle),
                const TextSpan(text: ')'),
                if (showAboutInline) ...[
                  const TextSpan(text: ' – '),
                  TextSpan(text: about, style: aboutStyle),
                ],
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
          ),
        ),
        if (showAboutTrailing || (showAuraBadge && aura != null)) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showAboutTrailing)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    about,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: aboutStyle,
                  ),
                ),
              if (showAboutTrailing && showAuraBadge && aura != null)
                const SizedBox(height: 6),
              if (showAuraBadge && aura != null) _AuraBadgeChip(aura: aura!),
            ],
          ),
        ],
      ],
    );
  }
}

class _AuraBadgeChip extends StatelessWidget {
  const _AuraBadgeChip({required this.aura});

  final int aura;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (aura >= 90) {
      color = const Color(0xFFFFF4C2);
    } else if (aura >= 75) {
      color = const Color(0xFF64FFDA);
    } else if (aura > 60) {
      color = const Color(0xFF81D4FA);
    } else {
      color = const Color(0xFFFF8A80);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.9), width: 1),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        'Aura $aura',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _FlagAvatar extends StatelessWidget {
  const _FlagAvatar({required this.flagPath, required this.name});
  final String? flagPath;
  final String name;

  @override
  Widget build(BuildContext context) {
    final String initial =
        (name.isNotEmpty ? name.characters.first : '?').toUpperCase();
    const double w = 36;
    const double h = 24;
    Widget fallback = Container(
      width: w,
      height: h,
      color: Colors.white.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final String? fp = flagPath;
    if (fp == null || fp.isEmpty) {
      return ClipRRect(borderRadius: BorderRadius.circular(4), child: fallback);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.asset(
        fp,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

/* ---------- Renoir Welcome Panel (golden heading + players list) ---------- */
class RenoirWelcomePanel extends StatelessWidget {
  final String heading;
  final List<PlayerBrief> players;
  final String? avatarAsset;
  const RenoirWelcomePanel({
    super.key,
    required this.heading,
    required this.players,
    this.avatarAsset,
  });

  @override
  Widget build(BuildContext context) {
    final shown = players.take(10).toList();
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 640,
          minWidth: 320,
        ),
        child: Container(
          // padding independent of avatar (since none is shown)
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x80000000), blurRadius: 24, spreadRadius: 1),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GoldenText(
                  heading,
                  style: _kTitleStyle.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: shown.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white24, height: 6),
                    itemBuilder: (_, i) {
                      final p = shown[i];
                      final about = truncateNice(p.about.trim(), 40);
                      final String flagPath = _flagForKingdom(p.kingdom);
                      return PlayerLineTile(
                        showAvatar: true,
                        flagPath: flagPath,
                        name: p.name,
                        kingdom: p.kingdom,
                        about: about,
                        nameStyle: _kSubtitleStyle.copyWith(fontSize: 14.5),
                        aboutStyle: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.05,
                        ),
                        showAboutInline: false,
                        showAboutTrailing: true,
                        aura: p.aura,
                        showAuraBadge: false,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------- Scoreboard reusable widget (for future use) ---------- */
class ScoreboardList extends StatelessWidget {
  final List<PlayerBrief> players;
  final List<int>? scores;
  final bool showIndex;
  final EdgeInsetsGeometry? padding;
  final double spacing;
  const ScoreboardList({
    super.key,
    required this.players,
    this.scores,
    this.showIndex = true,
    this.padding,
    this.spacing = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      shrinkWrap: true,
      itemCount: players.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white24, height: 10),
      itemBuilder: (_, i) {
        final p = players[i];
        final aboutText = p.about.trim();
        final String aboutDisplay =
            aboutText.isNotEmpty ? truncateNice(aboutText, 40) : '—';
        final String flagPath = _flagForKingdom(p.kingdom);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PlayerLineTile(
                showAvatar: showIndex,
                flagPath: flagPath,
                name: p.name,
                kingdom: p.kingdom,
                about: aboutDisplay,
                spacing: spacing,
                showAboutInline: false,
                aura: p.aura,
                showAuraBadge: true,
              ),
            ),
            const SizedBox(width: 12),
            if (scores != null && i < scores!.length)
              SizedBox(
                width: 70,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    '${scores![i]}',
                    style: _kTitleStyle.copyWith(
                      fontSize: 15,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Flexible(
              flex: 3,
              child: Align(
                alignment: Alignment.topRight,
                child: Text(
                  aboutDisplay,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/* ---------- Dealer badge (glow when handWon) ---------- */
class DealerBadge extends StatefulWidget {
  final double radius;
  final String? asset;
  final bool handWon;
  final double corner;
  final DealerAvatarStyle avatarStyle;
  final SlashJacketTone jacketTone;

  const DealerBadge({
    super.key,
    required this.radius,
    required this.handWon,
    this.corner = 12,
    this.asset,
    this.avatarStyle = DealerAvatarStyle.classic,
    this.jacketTone = SlashJacketTone.black,
  });

  @override
  State<DealerBadge> createState() => _DealerBadgeState();
}

class _DealerBadgeState extends State<DealerBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _glow =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _curve = CurvedAnimation(parent: _glow, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant DealerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.handWon && !oldWidget.handWon) {
      _glow.forward(from: 0); // one pulse
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.radius;

    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (_, __) {
          final t = _curve.value;
          final glow = (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.corner),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.65 * glow),
                  blurRadius: 12 + 12 * glow,
                  spreadRadius: 2 + 2 * glow,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.corner),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: r * 2.4,
                height: r * 2.4,
                color: Colors.black,
                child: _badgeSprite(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _badgeSprite() {
    if (widget.avatarStyle != DealerAvatarStyle.classic) {
      return Center(
        child: buildDealerSkinAvatar(
          style: widget.avatarStyle,
          height: widget.radius * 2.0,
          pose: 0,
          jacketTone: widget.jacketTone,
        ),
      );
    }
    final asset = widget.asset;
    if (asset == null || asset.isEmpty) {
      return const SizedBox.shrink();
    }
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
  }
}

/* ---------- Renoir dealer (idle / shuffle frames) ---------- */
enum DealerAct { idle, shuffle, bow }

class RenoirDealer extends StatefulWidget {
  final String idleAsset;
  final List<String> shuffleAssets; // ordered
  final double size;
  final double railWidth; // (kept for API parity; parent handles transform)
  final double liftPx; // (kept for API parity; parent handles transform)
  final Duration frameDuration;
  final bool loopShuffle;
  final int loops;
  final DealerAvatarStyle avatarStyle;
  final SlashJacketTone jacketTone;
  final Color? feltColor;
  final Color? railLightColor;
  final Color? railMidColor;
  final Color? railDarkColor;

  const RenoirDealer({
    super.key,
    required this.idleAsset,
    required this.shuffleAssets,
    required this.railWidth,
    this.size = 220,
    this.liftPx = 0,
    this.frameDuration = const Duration(milliseconds: 55),
    this.loopShuffle = false,
    this.loops = 2,
    this.avatarStyle = DealerAvatarStyle.classic,
    this.jacketTone = SlashJacketTone.black,
    this.feltColor,
    this.railLightColor,
    this.railMidColor,
    this.railDarkColor,
  });

  @override
  RenoirDealerState createState() => RenoirDealerState();
}

class RenoirDealerState extends State<RenoirDealer> {
  DealerAct _act = DealerAct.idle;

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
  List<Image>? _frames;

  int _frameIndex = 0;
  Timer? _timer;
  int _completedLoops = 0;

  void idle() {
    _stopTimer();
    if (!mounted) return;
    setState(() {
      _act = DealerAct.idle;
      _frameIndex = 0;
      _completedLoops = 0;
    });
  }

  Future<void> shuffle() async {
    if (!mounted) return;
    if (_frameCount == 0) {
      idle();
      return;
    }
    setState(() {
      _act = DealerAct.shuffle;
      _frameIndex = 0;
      _completedLoops = 0;
    });
    _startTimer();

    if (!widget.loopShuffle) {
      final totalFrames = _frameCount * widget.loops;
      if (totalFrames <= 0) return;
      final total = widget.frameDuration * totalFrames;
      await Future.delayed(total);
      if (!mounted) return;
      idle();
    }
  }

  Future<void> bow(
      {Duration duration = const Duration(milliseconds: 600)}) async {
    await Future.delayed(duration);
  }

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  @override
  void didChangeDependencies() {
    if (!_usesCustomAvatar) {
      final idle = _idle;
      final frames = _frames;
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
    final bool assetsChanged = widget.avatarStyle != oldWidget.avatarStyle ||
        widget.idleAsset != oldWidget.idleAsset ||
        !listEquals(widget.shuffleAssets, oldWidget.shuffleAssets);
    if (assetsChanged) {
      final bool wasShuffling = _act == DealerAct.shuffle;
      _stopTimer();
      setState(() {
        _frameIndex = 0;
        _completedLoops = 0;
        _loadAssets();
      });
      if (wasShuffling) {
        if (_frameCount == 0) {
          idle();
        } else {
          _act = DealerAct.shuffle;
          _startTimer();
        }
      }
    } else if (widget.frameDuration != oldWidget.frameDuration ||
        widget.loopShuffle != oldWidget.loopShuffle ||
        widget.loops != oldWidget.loops) {
      if (_act == DealerAct.shuffle) {
        _startTimer();
      }
    }
  }

  void _loadAssets() {
    if (_usesCustomAvatar) {
      _idle = null;
      _frames = null;
      return;
    }
    _idle = Image.asset(widget.idleAsset, filterQuality: FilterQuality.high);
    _frames = widget.shuffleAssets
        .map((p) => Image.asset(p, filterQuality: FilterQuality.high))
        .toList();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  bool get _usesCustomAvatar => widget.avatarStyle != DealerAvatarStyle.classic;

  int get _frameCount {
    if (_usesCustomAvatar) return _slashTimeline.length;
    final frames = _frames;
    return frames == null || frames.isEmpty ? 0 : frames.length;
  }

  double get _customPose {
    if (_frameCount == 0) return 0;
    return _slashTimeline[_frameIndex % _slashTimeline.length];
  }

  void _startTimer() {
    _stopTimer();
    if (_frameCount == 0) return;
    Duration tick = widget.frameDuration;
    if (_usesCustomAvatar) {
      int micro = widget.frameDuration.inMicroseconds ~/ 3;
      if (micro <= 0) micro = 1;
      tick = Duration(microseconds: micro);
    }
    _timer = Timer.periodic(tick, (_) {
      if (!mounted) return;
      setState(() {
        final int frames = _frameCount;
        if (frames == 0) return;
        _frameIndex = (_frameIndex + 1) % frames;
        if (_frameIndex == 0) {
          _completedLoops++;
          if (!widget.loopShuffle && _completedLoops >= widget.loops) {
            idle();
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
  Widget build(BuildContext context) {
    Widget child;
    if (_usesCustomAvatar) {
      final double pose = _act == DealerAct.shuffle ? _customPose : 0.0;
      child = buildDealerSkinAvatar(
        style: widget.avatarStyle,
        height: widget.size,
        pose: pose,
        jacketTone: widget.jacketTone,
        feltColor: widget.feltColor,
        railLightColor: widget.railLightColor,
        railMidColor: widget.railMidColor,
        railDarkColor: widget.railDarkColor,
      );
    } else {
      final frames = _frames;
      final idle = _idle;
      if (_act == DealerAct.shuffle) {
        child = (frames != null && frames.isNotEmpty)
            ? frames[_frameIndex % frames.length]
            : (idle ?? const SizedBox.shrink());
      } else {
        child = idle ?? const SizedBox.shrink();
      }
    }

    // Vertical placement is handled by the parent via Transform/Align.
    return IgnorePointer(
      ignoring: true,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: widget.size,
          child: FittedBox(fit: BoxFit.contain, child: child),
        ),
      ),
    );
  }
}

/* ---------- Animated board helper ---------- */
class BoardRowAnimated extends StatelessWidget {
  final List<PlayingCard> cards;
  final double cardWidth;
  final double cardHeight;
  final double gap;
  final BorderRadius borderRadius;

  const BoardRowAnimated({
    super.key,
    this.cards = const [],
    this.cardWidth = 60,
    this.cardHeight = 84,
    this.gap = 8,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          FaceCard(cards[i],
              w: cardWidth, h: cardHeight, borderRadius: borderRadius),
        ],
      ],
    );
  }
}

/* ---------- Dimmer while shuffling/dealing ---------- */
class ShuffleOverlay extends StatelessWidget {
  final bool visible;
  final String label;
  final Duration duration;

  const ShuffleOverlay({
    super.key,
    required this.visible,
    this.label = 'Shuffling cards…',
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: true,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: duration,
        curve: Curves.easeOut,
        child: Container(
          alignment: Alignment.center,
          color: Colors.black.withValues(alpha: 0.35),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------- Convenience wrappers for winner overlay ---------- */
/// Quick single-winner helper. Call this from your UI listener right after
/// settlement if you don’t want to build WinnerLine manually elsewhere.
Future<void> showHandWinnerOverlaySimple(
  BuildContext context, {
  required String winnerName,
  required int amount,
  required String handName,
  required List<UiCard> bestFive,
  required int totalPot,
  String? kingdom,
  String? about,
  Duration? duration,
  bool barrierDismissible = true,
  VoidCallback? onShown,
  VoidCallback? onClosed,
}) {
  return showWinnersDialog(
    context,
    winners: [
      WinnerLine(
        playerName: winnerName,
        amount: amount,
        delta: amount,
        handName: handName,
        bestFive: bestFive,
        kingdom: kingdom ?? '-',
        about: about ?? '',
      ),
    ],
    totalPot: totalPot,
    duration: duration,
    barrierDismissible: barrierDismissible,
    onShown: onShown,
    onClosed: onClosed,
  );
}

/// Multi-winner convenience. Pass a prepared list of WinnerLine entries.
Future<void> showHandWinnersOverlay(
  BuildContext context, {
  required List<WinnerLine> winners,
  required int totalPot,
  Duration? duration,
  bool barrierDismissible = true,
  VoidCallback? onShown,
  VoidCallback? onClosed,
}) {
  return showWinnersDialog(
    context,
    winners: winners,
    totalPot: totalPot,
    duration: duration,
    barrierDismissible: barrierDismissible,
    onShown: onShown,
    onClosed: onClosed,
  );
}

/* ---------- Winners detail dialog (English) ---------- */
class UiCard {
  final String rank;
  final String suit;
  const UiCard(this.rank, this.suit);
}

class WinnerLine {
  final String playerName;
  final int amount;

  /// Net change for the hand (payout - contributed). Negative means chips lost.
  final int delta;

  /// Total chips contributed ("bet") during the hand.
  final int bet;
  final String handName;
  final List<UiCard> bestFive;
  final List<UiCard> holeCards;
  final String kingdom;
  final String about;
  const WinnerLine({
    required this.playerName,
    required this.amount,
    required this.delta,
    this.bet = 0,
    required this.handName,
    required this.bestFive,
    this.holeCards = const [],
    this.kingdom = '-',
    this.about = '',
  });
}

/// Returns only the cards that form the *named hand* (pair/trips/quads/etc),
/// excluding kickers. For straights/flushes/full houses this is all 5.
List<UiCard> winningHandHighlightCards(List<UiCard> bestFive) {
  if (bestFive.isEmpty) return const <UiCard>[];
  final five = bestFive.take(5).toList(growable: false);
  if (five.length <= 1) return five;

  int rankValue(String raw) {
    final r = raw.trim().toUpperCase();
    switch (r) {
      case 'A':
      case 'ACE':
        return 14;
      case 'K':
      case 'KING':
        return 13;
      case 'Q':
      case 'QUEEN':
        return 12;
      case 'J':
      case 'JACK':
        return 11;
      case '10':
      case 'T':
        return 10;
      case '9':
        return 9;
      case '8':
        return 8;
      case '7':
        return 7;
      case '6':
        return 6;
      case '5':
        return 5;
      case '4':
        return 4;
      case '3':
        return 3;
      case '2':
        return 2;
      default:
        return 0;
    }
  }

  String normSuit(String raw) {
    final s = raw.trim();
    final u = s.toUpperCase();
    if (s == '♠' || u == 'S' || u.startsWith('SPADE')) return 'S';
    if (s == '♥' || u == 'H' || u.startsWith('HEART')) return 'H';
    if (s == '♦' || u == 'D' || u.startsWith('DIAMOND')) return 'D';
    if (s == '♣' || u == 'C' || u.startsWith('CLUB')) return 'C';
    return u.isNotEmpty ? u[0] : '';
  }

  bool isFlush(List<UiCard> cards) {
    if (cards.isEmpty) return false;
    final s0 = normSuit(cards.first.suit);
    if (s0.isEmpty) return false;
    for (final c in cards.skip(1)) {
      if (normSuit(c.suit) != s0) return false;
    }
    return true;
  }

  bool isStraight(List<UiCard> cards) {
    if (cards.length < 5) return false;
    final ranks = cards.map((c) => rankValue(c.rank)).toSet().toList()..sort();
    if (ranks.length != 5) return false;
    // Wheel: A-2-3-4-5
    if (ranks[0] == 2 &&
        ranks[1] == 3 &&
        ranks[2] == 4 &&
        ranks[3] == 5 &&
        ranks[4] == 14) {
      return true;
    }
    for (int i = 0; i < ranks.length - 1; i++) {
      if (ranks[i] + 1 != ranks[i + 1]) return false;
    }
    return true;
  }

  // Straights/flushes always use all 5 cards.
  if (isFlush(five) || isStraight(five)) return five;

  final byRank = <int, List<UiCard>>{};
  for (final c in five) {
    final v = rankValue(c.rank);
    (byRank[v] ??= <UiCard>[]).add(c);
  }

  final groups = byRank.entries.toList()
    ..sort((a, b) {
      final len = b.value.length.compareTo(a.value.length);
      if (len != 0) return len;
      return b.key.compareTo(a.key);
    });

  final quads = groups.where((e) => e.value.length == 4).toList();
  if (quads.isNotEmpty) return quads.first.value.toList(growable: false);

  final trips = groups.where((e) => e.value.length == 3).toList();
  final pairs = groups.where((e) => e.value.length == 2).toList();

  // Full house uses all 5 cards (3 + 2).
  if (trips.isNotEmpty && pairs.isNotEmpty) return five;

  if (trips.isNotEmpty) return trips.first.value.toList(growable: false);

  if (pairs.length >= 2) {
    return <UiCard>[
      ...pairs[0].value,
      ...pairs[1].value,
    ];
  }

  if (pairs.length == 1) return pairs.first.value.toList(growable: false);

  // High card: highlight only the top card.
  UiCard best = five.first;
  int bestV = rankValue(best.rank);
  for (final c in five.skip(1)) {
    final v = rankValue(c.rank);
    if (v > bestV) {
      best = c;
      bestV = v;
    }
  }
  return <UiCard>[best];
}

class PlayerBrief {
  final String name;
  final String kingdom;
  final String about;
  final int aura;
  const PlayerBrief({
    required this.name,
    required this.kingdom,
    required this.about,
    required this.aura,
  });
}

// --- Typed helpers to build PlayerBriefs from Seat(s) ---
PlayerBrief briefFromSeat(Seat s) => PlayerBrief(
      name: s.name,
      kingdom: (s.kingdom).trim().isEmpty ? '-' : s.kingdom.trim(),
      about: (s.about).trim(),
      aura: s.aura,
    );

List<PlayerBrief> briefsFromSeats(List<Seat> seats,
    {bool includeHero = true, bool heroFirst = true}) {
  final list = <PlayerBrief>[];
  final heroes = <PlayerBrief>[];
  final others = <PlayerBrief>[];
  for (final s in seats) {
    final b = briefFromSeat(s);
    if (s.isHero) {
      if (includeHero) heroes.add(b);
    } else {
      others.add(b);
    }
  }
  if (heroFirst) {
    list
      ..addAll(heroes)
      ..addAll(others);
  } else {
    list
      ..addAll(others)
      ..addAll(heroes);
  }
  return list;
}

String _flagForKingdom(String kingdomRaw) {
  final k = kingdomRaw.toLowerCase().trim();
  if (k.isEmpty) return '';
  const flags = {
    'baroda': 'assets/images/flags/baroda.png',
    'hyderabad': 'assets/images/flags/hyderabad.png',
    'indore': 'assets/images/flags/indore.png',
    'jaipur': 'assets/images/flags/jaipur.png',
    'maratha empire': 'assets/images/flags/maratha_empire.png',
    'mysore': 'assets/images/flags/mysore.png',
    'new delhi': 'assets/images/flags/new_delhi.png',
    'sikh empire': 'assets/images/flags/sikh_empire.png',
    'sikkim': 'assets/images/flags/sikkim.png',
    'travancore': 'assets/images/flags/travancore.png',
    'africa': 'assets/images/flags/africa.png',
    'amazon': 'assets/images/flags/amazon.png',
    's. america': 'assets/images/flags/amazon.png',
    'america': 'assets/images/flags/america.png',
    'n. america': 'assets/images/flags/america.png',
    'arabia': 'assets/images/flags/arabia.png',
    'australia': 'assets/images/flags/australia.png',
    'china': 'assets/images/flags/china.png',
    'europe': 'assets/images/flags/europe.png',
    'india': 'assets/images/flags/india.png',
    'russia': 'assets/images/flags/russia.png',
    'asia': 'assets/images/flags/asean.png',
    'southeast': 'assets/images/flags/asean.png',
  };
  return flags[k] ?? '';
}

Future<void> showWinnersDialog(
  BuildContext context, {
  required List<WinnerLine> winners,
  required int totalPot,
  Duration? duration,
  bool barrierDismissible = true,
  bool showLegacyTitle = true,
  VoidCallback? onShown, // fires as soon as dialog first renders
  VoidCallback? onClosed, // fires after dialog closes
  WinnerLine? heroLine,
  List<UiCard> board = const [],
  bool notifyBus = true,
  bool celebrate = true,
  bool useLegacyLayout = false,
  Color barrierColor = Colors.transparent,
  bool pillBackground = false,
  bool showCommunity = true,
  bool showArcCongrats = false,
}) async {
  // Remember this hand so the Info (i) button can recall it later
  LastHandStore.set(
    winners: winners,
    totalPot: totalPot,
    hero: heroLine,
    board: board,
  );

  bool _sameWinner(WinnerLine a, WinnerLine b) =>
      a.playerName == b.playerName &&
      a.handName == b.handName &&
      a.amount == b.amount;

  final bool heroHasShowableHand = heroLine?.bestFive.isNotEmpty == true;
  final bool heroWonPot =
      heroLine != null && winners.any((w) => _sameWinner(w, heroLine!));
  final bool showHeroBest =
      heroHasShowableHand && heroLine != null && !heroWonPot;

  final List<WinnerLine> winnersForUi = showHeroBest && heroLine != null
      ? [
          for (final w in winners)
            if (!_sameWinner(w, heroLine!)) w,
        ]
      : winners;

  var firedOnShown = false;

  final bool lockInput = duration != null && notifyBus;
  final bool effectiveBarrierDismissible =
      lockInput ? false : barrierDismissible;

  final bool isInfoOverlay = !notifyBus && !celebrate;
  final bool isPreviousHandTable = isInfoOverlay && duration == null;
  final int celebrationSeed = DateTime.now().microsecondsSinceEpoch;

  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: effectiveBarrierDismissible,
    barrierColor: barrierColor,
    builder: (dialogCtx) {
      // Fire onShown after the dialog is laid out
      if (!firedOnShown) {
        firedOnShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (celebrate) {
            _showCelebrationBurst(dialogCtx);
          }
          onShown?.call();
          if (notifyBus) {
            WinnersBus.fireShown(); // notify listeners: dialog shown
          }
        });
      }

      // Auto-close after duration, if specified
      if (duration != null) {
        Future<void>.delayed(duration, () {
          try {
            final route = ModalRoute.of(dialogCtx);
            if (route == null || !route.isActive) return;
            // Use pop() (not maybePop) so the input-lock doesn't veto the
            // scheduled auto-close (important for web builds too).
            Navigator.of(dialogCtx, rootNavigator: true).pop();
          } catch (_) {}
        });
      }

      final dialog = WillPopScope(
        onWillPop: () async => !lockInput,
        child: IgnorePointer(
          ignoring: lockInput,
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: EdgeInsets.zero,
            contentPadding: EdgeInsets.zero,
            title: (useLegacyLayout && showLegacyTitle)
                ? Text(
                    winners.length == 1 ? 'Congratulations' : 'Split Pot',
                    textAlign: TextAlign.center,
                    style: _kTitleStyle,
                  )
                : null,
            content: Builder(
              builder: (context) {
                Widget body = isPreviousHandTable
                    ? _PreviousHandInfoTable(
                        heroLine: heroLine,
                        winners: winnersForUi,
                      )
                    : (useLegacyLayout
                        ? Column(
                            children: [
                              ...winnersForUi
                                  .map((w) => _WinnerHandBlock(line: w)),
                              if (showHeroBest && heroLine != null) ...[
                                const SizedBox(height: 12),
                                _HeroBestHandBlock(line: heroLine!),
                              ],
                            ],
                          )
                        : _WinnerRevealContent(
                            winners: winnersForUi,
                            board: board,
                            pillBackground: pillBackground,
                            showCommunity: showCommunity,
                            showArcCongrats: showArcCongrats,
                          ));

                // Previous-hand “info” overlay: flexible panel that shrink-wraps.
                if (isInfoOverlay) {
                  final size = MediaQuery.sizeOf(context);
                  final double panelMaxW =
                      math.min(math.max(0.0, size.width - 32), 980.0);
                  final double panelMaxH = math.max(0.0, size.height * 0.82);
                  // Avoid forcing a tall panel when the table is short; only scroll
                  // vertically when we expect it to overflow.
                  final int approxRows = isPreviousHandTable
                      ? (2 /*header+hero*/ + winnersForUi.length)
                      : 999;
                  final double approxRowH = 78.0;
                  final double approxTopH = isPreviousHandTable ? 64.0 : 0.0;
                  final bool needsVScroll = !isPreviousHandTable ||
                      (approxTopH + approxRowH * approxRows) > panelMaxH;
                  final Widget panelBody =
                      needsVScroll ? SingleChildScrollView(child: body) : body;
                  body = Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: panelMaxW,
                          maxHeight: panelMaxH,
                        ),
                        child: IntrinsicWidth(
                          child: DecoratedBox(
                            decoration: renoirGlassPanelDecoration(
                                radius: 16, opacity: 0.30),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 16, 16),
                              child: panelBody,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  return body;
                }

                return SingleChildScrollView(child: body);
              },
            ),
          ),
        ),
      );
      return dialog;
    },
  );

  // After the dialog fully closes (manual or auto)
  onClosed?.call();
  if (notifyBus) {
    WinnersBus.fireClosed(); // notify listeners: dialog closed
  }
}

/// Replays the previous hand in a PERSISTENT modal (no auto-close).
/// Use this for the ⓘ / "previous hand" button so the user can read
/// everything and dismiss manually.
Future<void> showPreviousHandOverlay(
  BuildContext context, {
  bool barrierDismissible = true,
  VoidCallback? onShown,
  VoidCallback? onClosed,
}) async {
  final snap = LastHandStore.last;
  if (snap == null || snap.winners.isEmpty) {
    await showWinnerSplash(
      context,
      title: 'No previous hand yet',
      subtitle: 'Finish a hand to view results',
    );
    return;
  }

  await showWinnersDialog(
    context,
    winners: snap.winners,
    totalPot: snap.totalPot,
    duration: null, // ⬅️ persistent; user must dismiss
    barrierDismissible: barrierDismissible,
    onShown: onShown,
    onClosed: onClosed,
    heroLine: snap.hero,
    board: snap.board,
    notifyBus: false,
    celebrate: false,
    useLegacyLayout: false,
    pillBackground: true, // pill backdrop for previous-hand cards
    showCommunity: true,
    showArcCongrats: false,
    // Darken the backdrop for readability
    barrierColor: Colors.black.withValues(alpha: 0.30),
  );
}

/// Replays the previously shown winners dialog if available, otherwise shows a toast.
Future<void> showLastHandOrToast(
  BuildContext context, {
  Duration duration = const Duration(seconds: 3),
  bool barrierDismissible = true,
  VoidCallback? onShown,
  VoidCallback? onClosed,
}) async {
  final snap = LastHandStore.last;
  if (snap == null || snap.winners.isEmpty) {
    await showWinnerSplash(
      context,
      title: 'No previous hand yet',
      subtitle: 'Finish a hand to view results',
      duration: duration,
    );
    return;
  }

  await showWinnersDialog(
    context,
    winners: snap.winners,
    totalPot: snap.totalPot,
    duration: duration,
    barrierDismissible: barrierDismissible,
    onShown: onShown,
    onClosed: onClosed,
    heroLine: snap.hero,
    board: snap.board,
    notifyBus: false,
    celebrate: false,
    useLegacyLayout: true, // preserve legacy look for previous-hand recall
    showLegacyTitle: false, // no "Congratulations" header
  );
}

class _MiniCard extends StatelessWidget {
  final UiCard card;
  final bool highlight;
  const _MiniCard(this.card, {super.key, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final s = card.suit;
    final isRed = s.contains('♥') || s.contains('♦');
    final Color suitColor =
        isRed ? (Colors.red[700] ?? Colors.red) : Colors.black;
    final borderColor = highlight ? _kBestHandOutline : Colors.black12;
    final shadowColor =
        highlight ? _kBestHandOutline.withValues(alpha: 0.4) : Colors.black26;
    return Container(
      width: 46,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: highlight ? 2.4 : 1.0),
        boxShadow: [
          BoxShadow(
              color: shadowColor, blurRadius: 8, offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(card.rank,
              style: TextStyle(
                  color: suitColor, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 2),
          Text(card.suit, style: TextStyle(color: suitColor, fontSize: 16)),
        ],
      ),
    );
  }
}

class _WinnerFaceUpContent extends StatelessWidget {
  final List<WinnerLine> winners;
  final List<UiCard> board;
  final bool pillBackground;
  final bool showCommunity;
  final bool showArcCongrats;
  const _WinnerFaceUpContent({
    required this.winners,
    required this.board,
    this.pillBackground = false,
    this.showCommunity = true,
    this.showArcCongrats = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showArcCongrats) const _ArcCongratsText(),
        for (final w in winners)
          _WinnerRevealBlock(
            line: w,
            board: board,
            pillBackground: pillBackground,
            showCommunity: showCommunity,
          ),
      ],
    );
  }
}

// New minimal reveal layout: about text + cards only (no labels/names)
class _WinnerRevealContent extends StatelessWidget {
  final List<WinnerLine> winners;
  final List<UiCard> board;
  final bool pillBackground;
  final bool showCommunity;
  final bool showArcCongrats;
  const _WinnerRevealContent({
    required this.winners,
    required this.board,
    required this.pillBackground,
    required this.showCommunity,
    required this.showArcCongrats,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showArcCongrats) const _ArcCongratsText(),
        for (final w in winners)
          _WinnerRevealBlock(
            line: w,
            board: board,
            pillBackground: pillBackground,
            showCommunity: showCommunity,
          ),
      ],
    );
  }
}

class _WinnerRevealBlock extends StatelessWidget {
  final WinnerLine line;
  final List<UiCard> board;
  final bool pillBackground;
  final bool showCommunity;
  const _WinnerRevealBlock(
      {required this.line,
      required this.board,
      required this.pillBackground,
      required this.showCommunity});

  @override
  Widget build(BuildContext context) {
    final highlightKeys = _cardKeySet(winningHandHighlightCards(line.bestFive));

    final List<UiCard> community = board;
    final Size cardSize = _heroCardSize(context);
    const double gap = 8.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCommunity && community.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < community.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                            right: i == community.length - 1 ? 0 : gap),
                        child: _FaceUpCard(
                          card: community[i],
                          size: cardSize,
                          highlight: highlightKeys.contains(
                              _WinnerRevealBlock._cardKey(community[i])),
                          pill: pillBackground,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }

  static Set<String> _cardKeySet(List<UiCard> cards) =>
      {for (final c in cards) _cardKey(c)};

  static String _cardKey(UiCard c) =>
      '${c.rank.trim().toUpperCase()}|${_normalizeSuit(c.suit)}';

  static String _normalizeSuit(String raw) {
    final s = raw.trim();
    switch (s) {
      case '♠':
      case 'S':
      case 'SPADES':
      case 'Spades':
      case 'spades':
        return 'S';
      case '♥':
      case 'H':
      case 'HEARTS':
      case 'Hearts':
      case 'hearts':
        return 'H';
      case '♦':
      case 'D':
      case 'DIAMONDS':
      case 'Diamonds':
      case 'diamonds':
        return 'D';
      case '♣':
      case 'C':
      case 'CLUBS':
      case 'Clubs':
      case 'clubs':
        return 'C';
      default:
        return s.toUpperCase();
    }
  }
}

class _AboutBanner extends StatelessWidget {
  final String text;
  final String kingdom;
  const _AboutBanner({required this.text, required this.kingdom});

  @override
  Widget build(BuildContext context) {
    final Color fill = feltColorForKingdom(kingdom);
    final TextStyle base = Theme.of(context).textTheme.titleMedium ??
        const TextStyle(fontSize: 16);
    final double baseSize = (base.fontSize ?? 16);
    final double giant = baseSize * 5; // 50% smaller than previous 10x
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(
            fontSize: giant,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..color = Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(
            fontSize: giant,
            color: Colors.white.withValues(alpha: 0.5),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FaceUpCard extends StatelessWidget {
  final UiCard card;
  final Size size;
  final bool highlight;
  final bool pill;

  const _FaceUpCard({
    required this.card,
    required this.size,
    required this.highlight,
    this.pill = false,
  });

  @override
  Widget build(BuildContext context) {
    final pc.PlayingCard? mapped = _toPlayingCard(card);
    final double radius = size.shortestSide * 0.16;
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final Widget inner = mapped == null
        ? _FallbackCard(size: size)
        : ClipRRect(
            borderRadius: borderRadius,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: pc.PlayingCardView(
                card: mapped,
                showBack: false,
              ),
            ),
          );

    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: pill ? Colors.grey.shade200.withOpacity(0.35) : null,
        borderRadius: borderRadius,
        border: Border.all(
          color: highlight ? _kBestHandOutline : Colors.white24,
          width: highlight ? 3.6 : 1.4,
        ),
        boxShadow: [
          if (highlight)
            BoxShadow(
              color: _kBestHandOutline.withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 1.5,
            ),
        ],
      ),
      child: inner,
    );
  }

  pc.PlayingCard? _toPlayingCard(UiCard c) {
    final suit = _toSuit(c.suit);
    final value = _toValue(c.rank);
    if (suit == null || value == null) return null;
    return pc.PlayingCard(suit, value);
  }

  pc.Suit? _toSuit(String raw) {
    final s = raw.trim().toUpperCase();
    switch (s) {
      case 'S':
      case '♠':
      case 'SPADES':
        return pc.Suit.spades;
      case 'H':
      case '♥':
      case 'HEARTS':
        return pc.Suit.hearts;
      case 'D':
      case '♦':
      case 'DIAMONDS':
        return pc.Suit.diamonds;
      case 'C':
      case '♣':
      case 'CLUBS':
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

class _ArcCongratsText extends StatelessWidget {
  const _ArcCongratsText();

  @override
  Widget build(BuildContext context) {
    const String text = 'Congratulations';
    const double radius = 140.0;
    final chars = text.split('');
    final int n = chars.length;
    final double span = math.pi * 0.9; // near-semicircle
    final double start = -span / 2;
    final Color color = Colors.red.shade700;
    final double fontSize = 24;

    return SizedBox(
      width: radius * 2 + fontSize,
      height: radius + fontSize * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < n; i++)
            _ArcLetter(
              char: chars[i],
              angle: start + (span * i / math.max(1, n - 1)),
              radius: radius,
              color: color,
              fontSize: fontSize,
            ),
        ],
      ),
    );
  }
}

class _ArcLetter extends StatelessWidget {
  final String char;
  final double angle;
  final double radius;
  final Color color;
  final double fontSize;
  const _ArcLetter({
    required this.char,
    required this.angle,
    required this.radius,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final double x = radius * math.cos(angle);
    final double y = radius * math.sin(angle);
    return Transform.translate(
      offset: Offset(x, -y),
      child: Transform.rotate(
        angle: angle + math.pi / 2,
        child: Text(
          char,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _FallbackCard extends StatelessWidget {
  final Size size;
  const _FallbackCard({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(size.shortestSide * 0.14),
      ),
      child: const Icon(Icons.style, color: Colors.white54),
    );
  }
}

Size _heroCardSize(BuildContext context) {
  final double w = MediaQuery.of(context).size.width;
  final double cw = (w / 1280 * 66).clamp(52.0, 88.0).toDouble();
  final double ch = (w / 1280 * 92).clamp(76.0, 128.0).toDouble();
  return Size(cw, ch);
}

class _WinnerHandBlock extends StatelessWidget {
  final WinnerLine line;
  const _WinnerHandBlock({required this.line});

  static const Map<String, int> _rankStrength = {
    'A': 14,
    'K': 13,
    'Q': 12,
    'J': 11,
    '10': 10,
    '9': 9,
    '8': 8,
    '7': 7,
    '6': 6,
    '5': 5,
    '4': 4,
    '3': 3,
    '2': 2,
  };

  static const Map<String, int> _suitPriority = {
    '♠': 4,
    '♥': 3,
    '♦': 2,
    '♣': 1,
  };

  static String chipText(int amount) {
    if (amount == 0) return '0';
    return amount > 0 ? '+$amount' : '$amount';
  }

  static int _rankValue(String rank) => _rankStrength[rank] ?? 0;
  static int _suitValue(String suit) => _suitPriority[suit] ?? 0;

  @override
  Widget build(BuildContext context) {
    final highlightKeys = {
      for (final c in winningHandHighlightCards(line.bestFive))
        '${c.rank}|${c.suit}',
    };

    final namePart = _renoirAddress(line.playerName);
    final handLabel = line.handName.trim().isNotEmpty ? line.handName : '—';
    final chipsPart = '${_WinnerHandBlock.chipText(line.amount)} chips';
    final winnerLine = [namePart, handLabel, chipsPart]
        .where((segment) => segment.isNotEmpty)
        .join('   •   ');
    final displayCards =
        _WinnerHandBlock.orderedDisplayCards(line, highlightKeys);

    final hasCards = displayCards.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kWhite.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            winnerLine,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _kBodyStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          if (hasCards) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < displayCards.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                            right: i == displayCards.length - 1 ? 0 : 6),
                        child: _MiniCard(
                          displayCards[i].card,
                          highlight: displayCards[i].highlight,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static List<({UiCard card, bool highlight})> orderedDisplayCards(
      WinnerLine line, Set<String> highlightKeys) {
    final cards = <({UiCard card, bool highlight, int index})>[];
    for (int i = 0; i < line.bestFive.length; i++) {
      final card = line.bestFive[i];
      cards.add((
        card: card,
        highlight: highlightKeys.contains('${card.rank}|${card.suit}'),
        index: i,
      ));
    }

    final rankCounts = <String, int>{};
    for (final entry in cards) {
      rankCounts.update(entry.card.rank, (value) => value + 1,
          ifAbsent: () => 1);
    }

    final bool treatAsSequence =
        line.handName.toLowerCase().contains('straight');
    final ordered = [...cards];

    if (!treatAsSequence) {
      ordered.sort((a, b) {
        final countA = rankCounts[a.card.rank] ?? 0;
        final countB = rankCounts[b.card.rank] ?? 0;
        if (countA != countB) return countB.compareTo(countA);

        final rankA = _rankValue(a.card.rank);
        final rankB = _rankValue(b.card.rank);
        if (rankA != rankB) return rankB.compareTo(rankA);

        if (a.highlight != b.highlight) return a.highlight ? -1 : 1;

        final suitA = _suitValue(a.card.suit);
        final suitB = _suitValue(b.card.suit);
        if (suitA != suitB) return suitB.compareTo(suitA);

        return a.index.compareTo(b.index);
      });
    }

    return [
      for (final entry in ordered)
        (card: entry.card, highlight: entry.highlight),
    ];
  }
}

class _HeroBestHandBlock extends StatelessWidget {
  final WinnerLine line;
  const _HeroBestHandBlock({required this.line});

  @override
  Widget build(BuildContext context) {
    final highlightKeys = {
      for (final c in winningHandHighlightCards(line.bestFive))
        '${c.rank}|${c.suit}',
    };
    final displayCards =
        _WinnerHandBlock.orderedDisplayCards(line, highlightKeys);
    final handLabel = line.handName.trim().isNotEmpty ? line.handName : '—';
    final chipsLabel = '${_WinnerHandBlock.chipText(line.amount)} chips';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kWhite.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              GoldenText(
                'Your Best Hand',
                style: _kSubtitleStyle.copyWith(fontSize: 16),
              ),
              Text(
                '•',
                style: _kBodyStyle.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                handLabel,
                style: _kBodyStyle.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                '•',
                style: _kBodyStyle.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                chipsLabel,
                style: _kBodyStyle.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (displayCards.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < displayCards.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                            right: i == displayCards.length - 1 ? 0 : 6),
                        child: _MiniCard(
                          displayCards[i].card,
                          highlight: displayCards[i].highlight,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviousHandInfoTable extends StatelessWidget {
  final WinnerLine? heroLine;
  final List<WinnerLine> winners;

  const _PreviousHandInfoTable({
    required this.heroLine,
    required this.winners,
  });

  @override
  Widget build(BuildContext context) {
    const Color winGreen = Color(0xFF4CFFBE);
    const Color neutralYellow = Color(0xFFFFD76E);

    String betText(int bet) => '$bet';

    String deltaText(int delta) => delta > 0 ? '+$delta' : '$delta';

    Color deltaColor(int delta) {
      if (delta > 0) return winGreen;
      if (delta < 0) return _kRed;
      return neutralYellow;
    }

    Widget cell(
      Widget child, {
      EdgeInsets padding =
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    }) {
      return Padding(
        padding: padding,
        child: Align(alignment: Alignment.center, child: child),
      );
    }

    String firstName(String raw) {
      final t = raw.trim();
      if (t.isEmpty) return '—';
      return t.split(RegExp(r'\s+')).first;
    }

    Widget bestFiveCell(List<UiCard> bestFive, List<UiCard> holeCards) {
      final best = bestFive.take(5).toList(growable: false);
      if (best.isEmpty) {
        return Text('—',
            style: _kBodyStyle.copyWith(color: Colors.white54, fontSize: 13));
      }
      final holeKeys = <String>{
        for (final c in holeCards.take(2)) '${c.rank}|${c.suit}',
      };
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < best.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == best.length - 1 ? 0 : 6),
              child: _MiniCard(
                best[i],
                highlight: holeKeys.contains('${best[i].rank}|${best[i].suit}'),
              ),
            ),
        ],
      );
    }

    TableRow dataRow({
      required int bet,
      required int delta,
      required String name,
      required String hand,
      required List<UiCard> bestFive,
      required List<UiCard> holeCards,
      bool isHero = false,
    }) {
      final TextStyle base = _kBodyStyle.copyWith(
        fontSize: 13.5,
        height: 1.1,
        fontWeight: isHero ? FontWeight.w800 : FontWeight.w600,
      );
      return TableRow(
        decoration: isHero
            ? BoxDecoration(color: Colors.white.withValues(alpha: 0.06))
            : null,
        children: [
          cell(
            Text(
              betText(bet),
              style: base.copyWith(color: Colors.white.withValues(alpha: 0.88)),
              textAlign: TextAlign.center,
            ),
          ),
          cell(
            Text(
              deltaText(delta),
              style: base.copyWith(color: deltaColor(delta)),
              textAlign: TextAlign.center,
            ),
          ),
          cell(
            Text(
              name.isNotEmpty ? firstName(name) : '—',
              style: base.copyWith(
                color: isHero
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.92),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          cell(
            Text(
              hand.isNotEmpty ? hand : '—',
              style: base.copyWith(color: Colors.white.withValues(alpha: 0.9)),
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          cell(
            bestFiveCell(bestFive, holeCards),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          ),
        ],
      );
    }

    final String? heroSlug =
        heroLine != null ? Seat.slugForName(heroLine!.playerName) : null;
    final winnerRows = <WinnerLine>[
      for (final w in winners)
        if (heroSlug == null || Seat.slugForName(w.playerName) != heroSlug) w,
    ];

    final hero = heroLine;
    final heroDelta = hero?.delta ?? 0;
    final heroBet = hero?.bet ?? 0;
    final heroName = 'You';
    final heroHand = hero?.handName ?? '—';
    final heroBest = hero?.bestFive ?? const <UiCard>[];

    final headerStyle = _kBodyStyle.copyWith(
      color: Colors.white70,
      fontWeight: FontWeight.w800,
      fontSize: 12.5,
      letterSpacing: 0.2,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Previous Hand',
          textAlign: TextAlign.center,
          style: _kTitleStyle.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const <int, TableColumnWidth>{
              0: IntrinsicColumnWidth(), // bet
              1: IntrinsicColumnWidth(), // win/lose
              2: IntrinsicColumnWidth(), // name
              3: IntrinsicColumnWidth(), // hand
              4: IntrinsicColumnWidth(), // cards
            },
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.white12),
              verticalInside: BorderSide(color: Colors.white10),
              top: BorderSide(color: Colors.white24),
              bottom: BorderSide(color: Colors.white24),
            ),
            children: [
              TableRow(
                decoration:
                    BoxDecoration(color: Colors.black.withValues(alpha: 0.18)),
                children: [
                  cell(Text('Bet',
                      style: headerStyle, textAlign: TextAlign.center)),
                  cell(Text('Win/Lose',
                      style: headerStyle, textAlign: TextAlign.center)),
                  cell(Text('Name',
                      style: headerStyle, textAlign: TextAlign.center)),
                  cell(Text('Hand',
                      style: headerStyle, textAlign: TextAlign.center)),
                  cell(Text('Best 5',
                      style: headerStyle, textAlign: TextAlign.center)),
                ],
              ),
              dataRow(
                bet: heroBet,
                delta: heroDelta,
                name: heroName,
                hand: heroHand,
                bestFive: heroBest,
                holeCards: hero?.holeCards ?? const <UiCard>[],
                isHero: true,
              ),
              for (final w in winnerRows)
                dataRow(
                  bet: w.bet,
                  delta: w.delta,
                  name: w.playerName,
                  hand: w.handName,
                  bestFive: w.bestFive,
                  holeCards: w.holeCards,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
