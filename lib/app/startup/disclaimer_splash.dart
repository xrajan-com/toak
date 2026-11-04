import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/app/startup/auth_gate.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show totalKingdomCount;
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/features/venue/game_mode.dart';
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/game_analytics.dart';
import 'package:ten_of_a_kind_poker/services/x_music_service.dart';
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: compact ? 12 : 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Image.asset(
                    'assets/images/x_poker_logo.png',
                    height: compact ? 56 : 84,
                    fit: BoxFit.contain,
                    semanticLabel: 'X Poker',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Texas Hold'em across ${totalKingdomCount()} kingdoms",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: compact ? 16 : 26),
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
                        disabledBackgroundColor:
                            AppColors.red.withValues(alpha: 0.6),
                        disabledForegroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 18),
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
            ),
          ),
        ),
      ),
    );
  }
}
