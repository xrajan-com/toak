import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/app/startup/auth_gate.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show totalKingdomCount;
import 'package:ten_of_a_kind_poker/config/story.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/features/venue/game_mode.dart';
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/game_analytics.dart';
import 'package:ten_of_a_kind_poker/services/x_music_service.dart';
import 'package:ten_of_a_kind_poker/ui/art/fort_backdrop.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

/// The first screen of a fresh install: one PLAY button that deals the first
/// hand. Tapping it confirms the play-money and 18+ notice under it, starts
/// guest play and opens a Quick Game in the first kingdom; the game menu
/// waits underneath for when that table ends. Players who already accepted
/// go straight to [AuthGate].
class DisclaimerSplash extends StatefulWidget {
  static const String acceptanceKey = 'disclaimer.accepted.v2';

  const DisclaimerSplash({
    super.key,
    this.home,
    this.firstTableBuilder,
  });

  /// What follows the welcome screen; [AuthGate] unless a test says otherwise.
  @visibleForTesting
  final Widget? home;

  /// The first table a new player sits at; the first kingdom's Quick Game
  /// unless a test says otherwise.
  @visibleForTesting
  final WidgetBuilder? firstTableBuilder;

  /// The full notice, shown under "Details".
  static const List<String> noticeParagraphs = <String>[
    'Ten of a Kind is a free, recreational poker simulation made for fun and '
        'learning. It is not a gambling or real-money gaming product.',
    'There are no cash deposits, cash-outs, prizes, or rewards with real-world '
        'value. Chips, AUP, Aura, ranks, and progress exist only inside the game.',
    'Poker involves chance. Focus on decision quality over any single result, '
        'and take a break if play stops feeling enjoyable.',
    'You must be at least 18 to use this app. Follow the laws that apply where '
        'you live and avoid illegal real-money offerings.',
  ];

  @override
  State<DisclaimerSplash> createState() => _DisclaimerSplashState();
}

class _DisclaimerSplashState extends State<DisclaimerSplash> {
  bool _checking = true;
  bool _accepted = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _loadAcceptance();
  }

  Future<void> _loadAcceptance() async {
    var accepted = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      accepted = prefs.getBool(DisclaimerSplash.acceptanceKey) ?? false;
    } catch (error) {
      debugPrint('Disclaimer preference load failed: $error');
    }
    if (!mounted) return;
    setState(() {
      _accepted = accepted;
      _checking = false;
    });
    // A fresh install: the new-player funnel starts here.
    if (!accepted) {
      unawaited(GameAnalytics.onboarding(OnboardingStep.welcomeShown));
    }
  }

  Future<void> _play() async {
    if (_starting) return;
    setState(() => _starting = true);
    unawaited(GameAnalytics.onboarding(OnboardingStep.disclaimerAccepted));
    // The tap is the user gesture browsers need before playing sound.
    unawaited(SoundFx.instance.unlock());
    unawaited(XMusicService.instance.unlock());
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setBool(DisclaimerSplash.acceptanceKey, true);
      if (!saved) {
        debugPrint('Disclaimer preference write was rejected.');
      }
    } catch (error) {
      // Do not trap the user if local preferences are temporarily unavailable.
      debugPrint('Disclaimer preference write failed: $error');
    }

    if (!mounted) return;
    var dealFirstTable = true;
    AuthService? auth;
    try {
      auth = context.read<AuthService>();
    } on ProviderNotFoundException {
      auth = null;
    }
    if (auth != null) {
      final user = auth.currentUser;
      if (user == null && !auth.isLocalGuest) {
        unawaited(GameAnalytics.onboarding(OnboardingStep.guestChosen));
        await auth.startGuestPlay();
      } else if (user != null && !user.isAnonymous) {
        // Already signed in (the web keeps sessions): the usual way in.
        dealFirstTable = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _accepted = true;
      _starting = false;
    });
    if (dealFirstTable) _openFirstTableAfterFrame();
  }

  void _openFirstTableAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      XMusicService.instance.stop();
      // PLAY AGAIN on the game-over screen deals another starter table.
      Object? choice;
      do {
        choice = await Navigator.of(context).push<Object?>(
          MaterialPageRoute<Object?>(
            builder: widget.firstTableBuilder ?? _starterTable,
          ),
        );
      } while (mounted && choice == GameExitChoice.playAgain);
      if (!mounted) return;
      XMusicService.instance.playHomepage();
      unawaited(GameAnalytics.onboarding(OnboardingStep.modeShown));
    });
  }

  static Widget _starterTable(BuildContext context) {
    final VenueGroup group = kVenueGroups.first;
    final VenueTheme venue = venuesForGroup(group).first;
    return GameScreen.guestTable(
      tableName: '${venue.name} — Quick Game',
      venue: venue,
      venueMode: VenueEntryMode.quickGame,
      campaignGroup: group,
    );
  }

  void _showDetails() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Before you play',
                  style: TextStyle(
                    color: AppColors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                for (final String paragraph in DisclaimerSplash.noticeParagraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      paragraph,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );
    }
    if (_accepted) return widget.home ?? const AuthGate();

    final bool compact = MediaQuery.sizeOf(context).height < 420;
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = constraints.biggest;
          final bool tall = size.width / math.max(1.0, size.height) < 1.1;
          final FortGeometry fort = FortGeometry.welcome(size);
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // The fort at dusk, gate open, Renoir waiting in it
              // (docs/ART_DIRECTION.md, docs/STORY.md).
              FortBackdrop(
                geometry: fort,
                bannerColors: const <Color>[AppColors.red, AppColors.blue],
              ),
              Positioned.fromRect(
                rect: fort.arch,
                child: _RenoirInTheGate(fort: fort),
              ),
              // Shade behind the words so they read over the stone.
              if (tall)
                Positioned(
                  left: 0,
                  right: 0,
                  top: size.height * 0.58,
                  bottom: 0,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Color(0x00000000),
                            Color(0xB8000000),
                            Color(0xE6000000),
                          ],
                          stops: <double>[0, 0.45, 1],
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: size.width * 0.58,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Color(0x9E000000),
                            Color(0x61000000),
                            Color(0x00000000),
                          ],
                          stops: <double>[0, 0.75, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              if (tall)
                Positioned(
                  left: 0,
                  right: 0,
                  top: size.height * 0.60,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: compact ? 8 : 16,
                        ),
                        child: _welcomeColumn(compact),
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  left: size.width * 0.03,
                  width: size.width * 0.48,
                  top: 0,
                  bottom: 0,
                  child: SafeArea(
                    right: false,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: compact ? 8 : 20,
                        ),
                        child: _welcomeColumn(compact),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The story's first line, then PLAY and the notice under it.
  Widget _welcomeColumn(bool compact) {
    final int kingdoms = totalKingdomCount();
    final String count = kingdoms == 50 ? 'Fifty' : '$kingdoms';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image.asset(
            'assets/images/x_poker_logo.png',
            height: compact ? 44 : 64,
            fit: BoxFit.contain,
            semanticLabel: 'X Poker',
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            '$count kingdoms. $count crowns.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 22 : 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
              height: 1.15,
            ),
          ),
          SizedBox(height: compact ? 4 : 8),
          Text(
            StoryLines.premise,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: compact ? 13.5 : 15.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          SizedBox(height: compact ? 14 : 22),
          SizedBox(
            width: 280,
            height: 56,
            child: FilledButton.icon(
              key: const ValueKey('welcome_play'),
              onPressed: _starting ? null : _play,
              icon: _starting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 30),
              label: Text(_starting ? 'Dealing…' : 'PLAY'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.red.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          const Text(
            'Play money only. No real-money gambling.\n'
            "By tapping Play you confirm you're 18 or older.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          TextButton(
            key: const ValueKey('welcome_details'),
            onPressed: _showDetails,
            child: const Text('Details'),
          ),
        ],
      ),
    );
  }
}

/// Renoir, the dealer, standing in the open gate: clipped to the arch and
/// faded at the edges into its dark, so the photo's black ground disappears.
class _RenoirInTheGate extends StatelessWidget {
  const _RenoirInTheGate({required this.fort});

  final FortGeometry fort;

  // assets/images/renoir_tux.png is 1024 x 1536.
  static const double _imageAspect = 1024 / 1536;

  @override
  Widget build(BuildContext context) {
    final Rect arch = fort.arch;
    double h = arch.height;
    double w = h * _imageAspect;
    if (w > arch.width * 1.25) {
      w = arch.width * 1.25;
      h = w / _imageAspect;
    }
    return IgnorePointer(
      child: ClipPath(
        clipper: _ArchClipper(fort.archPath().shift(-arch.topLeft)),
        child: OverflowBox(
          alignment: Alignment.bottomCenter,
          minWidth: w,
          maxWidth: w,
          minHeight: h,
          maxHeight: h,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) => const RadialGradient(
              center: Alignment(0, -0.16),
              radius: 0.75,
              colors: <Color>[
                Color(0xFFFFFFFF),
                Color(0xFFFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: <double>[0, 0.40, 1],
            ).createShader(bounds),
            child: Image.asset(
              'assets/images/renoir_tux.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchClipper extends CustomClipper<Path> {
  const _ArchClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(covariant _ArchClipper oldClipper) =>
      oldClipper.path != path;
}
