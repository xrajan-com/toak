// lib/ui/screens/venue_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/config/kingdom_titles.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show subKingdomCountFor, totalKingdomCount, totalSubKingdomCount;
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/features/venue/game_mode.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/auth_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/sub_kingdom_screen.dart';
import 'package:ten_of_a_kind_poker/ui/utils/deck_cache.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/config/assets.dart';
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/services/economy_api_service.dart';
import 'package:ten_of_a_kind_poker/services/leaderboard_firestore_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';
import 'package:ten_of_a_kind_poker/services/x_music_service.dart';
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/ui/screens/profile_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/profile_setup_screen.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/app_settings_sheet.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/stadium_banner.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/trailblazers_panel.dart';

const _red = AppColors.red;
const _blue = AppColors.blue;

/* ----------------------- HEADER ----------------------- */

/// Circular, lightly frosted icon button used in the slim venue header.
class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIcon(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        child: _HeaderIconFace(icon: icon, onTap: onTap),
      ),
    );
  }
}

class _HeaderIconFace extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _HeaderIconFace({required this.icon, this.onTap});

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    final shape = CircleBorder(
      side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
    );
    final face = SizedBox(
      width: size,
      height: size,
      child: Icon(icon, color: Colors.white, size: 20),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? face
            : InkWell(
                onTap: onTap,
                customBorder: shape,
                mouseCursor: SystemMouseCursors.click,
                child: face,
              ),
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  final VoidCallback? onProfile;
  final VoidCallback? onTrailblazers;
  final VoidCallback? onSettings;
  const _HeaderActions({
    this.onProfile,
    this.onTrailblazers,
    this.onSettings,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderIcon(
          icon: Icons.person_outline,
          tooltip: 'My Profile',
          onTap: onProfile ?? () {},
        ),
        _HeaderIcon(
          icon: Icons.flag_outlined,
          tooltip: 'Trailblazers',
          onTap: onTrailblazers ?? () {},
        ),
        _HeaderIcon(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onTap: onSettings ?? () {},
        ),
      ],
    );
  }
}

/// Slim, transparent header: the X logo in the centre of the screen,
/// account actions on the right, circuit tabs on the row below. It paints no
/// background of its own so the ambient backdrop shows through and every row
/// of kingdoms keeps the vertical space.
class _VenueHeader extends StatelessWidget {
  final String logoAsset;
  final String semanticTitle;
  final bool compact;
  final Widget tabs;
  final Widget actions;
  const _VenueHeader({
    required this.logoAsset,
    required this.semanticTitle,
    required this.compact,
    required this.tabs,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 40.0 : 48.0;
    final logo = Semantics(
      header: true,
      label: semanticTitle,
      child: ClipOval(
        key: const ValueKey<String>('venue-logo'),
        child: Image.asset(
          logoAsset,
          width: logoSize,
          height: logoSize,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A Stack, not a Row, so the logo sits on the screen's true centre
        // whatever the width of the actions beside it.
        SizedBox(
          height: math.max(logoSize, _HeaderIconFace.size + 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              logo,
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        tabs,
      ],
    );
  }
}

/// Soft stage lighting behind the venue list, so the transparent header and
/// the pills sit on depth instead of a flat black void.
class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFF050505)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -1.4),
                  radius: 1.3,
                  colors: [Color(0x1FFFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-1.1, 1.2),
                  radius: 0.95,
                  colors: [Color(0x1700B5C8), Color(0x0000B5C8)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(1.1, 1.2),
                  radius: 0.95,
                  colors: [Color(0x17FF2800), Color(0x00FF2800)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------- SCREEN ----------------------- */

class VenueScreen extends StatefulWidget {
  static const routeName = '/venue';
  final VenueEntryMode mode;

  /// Opens Trailblazers by itself for a few seconds when the screen first
  /// shows. Off in tests that are not about it.
  final bool autoShowTrailblazers;

  /// Where Trailblazers loads from; tests pass a fake.
  final TrailblazersLoader? trailblazersLoader;

  /// Who is looking at Trailblazers; by default the signed-in player. Tests
  /// pass their own.
  final TrailblazersViewer? trailblazersViewer;

  const VenueScreen({
    super.key,
    this.mode = VenueEntryMode.career,
    this.autoShowTrailblazers = true,
    this.trailblazersLoader,
    this.trailblazersViewer,
  });

  /// How long the automatic Trailblazers stays up.
  static const Duration trailblazersPreview = Duration(seconds: 4);
  @override
  State<VenueScreen> createState() => _VenueScreenState();
}

class _VenueScreenState extends State<VenueScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  // One client for the dashboard's rank lookups, made on first use.
  late final EconomyApiService _economyApi = EconomyApiService();
  static const _bannerAsset = 'assets/images/x_poker_logo.png';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: kVenueGroups.length, vsync: this);
    _tab.addListener(_syncMusicForSelectedCircuit);
    _syncMusicForSelectedCircuit();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await DeckCache.ensureDeckReadySafely();
      if (!mounted) return;
      final ctx = context;
      for (final group in kVenueGroups) {
        for (final v in venuesForGroup(group)) {
          precacheImage(AssetImage(v.flagAsset), ctx);
        }
      }
      precacheImage(const AssetImage(_bannerAsset), ctx);
      if (!mounted) return;
      setState(() {});
    });

    if (widget.autoShowTrailblazers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Only while this screen is on top: not over a game pushed in the
        // same frame, and never twice for one visit.
        if (ModalRoute.of(context)?.isCurrent == false) return;
        unawaited(
          _openTrailblazers(autoCloseAfter: VenueScreen.trailblazersPreview),
        );
      });
    }
  }

  Future<void> _openTrailblazers({Duration? autoCloseAfter}) {
    return showTrailblazers(
      context,
      load: widget.trailblazersLoader,
      autoCloseAfter: autoCloseAfter,
      viewer: widget.trailblazersViewer ?? _trailblazersViewer(),
    );
  }

  /// The signed-in player as Trailblazers sees them: their own row, and a
  /// nudge to log in or set a name when that is what keeps them off it.
  TrailblazersViewer _trailblazersViewer() {
    final user = _maybeRead<AuthService>()?.currentUser;
    final registered = user != null && !user.isAnonymous;
    final name = (_maybeRead<ProfileService>()?.displayName ?? '').trim();
    return TrailblazersViewer(
      registered: registered,
      name: name,
      loadStanding: registered
          ? leaderboardFirestoreService.fetchMyTrailStanding
          : null,
      onSetName: () => unawaited(_setNameForTrailblazers()),
      onSignIn: _pushSignIn,
    );
  }

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _setNameForTrailblazers() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(popWhenSaved: true),
      ),
    );
    // Straight back to the board, now with their name on it.
    if (saved == true && mounted) unawaited(_openTrailblazers());
  }

  @override
  void dispose() {
    _tab.removeListener(_syncMusicForSelectedCircuit);
    _tab.dispose();
    super.dispose();
  }

  void _syncMusicForSelectedCircuit() {
    if (widget.mode == VenueEntryMode.quickGame) {
      XMusicService.instance.stop();
      return;
    }
    XMusicService.instance.playCareerCircuit(kVenueGroups[_tab.index]);
  }

  Future<void> _pushQuickGame(VenueTheme venue, VenueGroup group) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen.guestTable(
          tableName: '${venue.name} — Quick Game',
          venue: venue,
          playIntroWelcome: false,
          venueMode: VenueEntryMode.quickGame,
          campaignGroup: group,
        ),
      ),
    );
    if (mounted) XMusicService.instance.stop();
  }

  Future<void> _enterQuickGame(VenueTheme venue, VenueGroup group) async {
    await _pushQuickGame(venue, group);
  }

  Future<void> _openVenue(VenueTheme venue, VenueGroup group) async {
    unawaited(SoundFx.instance.unlock());
    unawaited(XMusicService.instance.unlock());
    unawaited(DeckCache.ensureDeckReadySafely());
    if (!mounted) return;
    if (widget.mode == VenueEntryMode.quickGame) {
      await _enterQuickGame(venue, group);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubKingdomScreen(
          kingdom: venue,
          group: group,
        ),
      ),
    );
    if (!mounted) return;
    _syncMusicForSelectedCircuit();
  }

  void _openProfileEditor(BuildContext dialogContext) {
    Navigator.pop(dialogContext);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _openSignIn(BuildContext dialogContext) {
    Navigator.pop(dialogContext);
    _pushSignIn();
  }

  void _pushSignIn() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AuthScreen(
          requireRegisteredUser: true,
          postAuthDestination: VenueScreen(mode: VenueEntryMode.career),
          title: 'Login or Register',
          message: 'Login or register to save Career progress.',
        ),
      ),
    );
  }

  Future<void> _logoutFromProfileDialog(BuildContext dialogContext) async {
    Navigator.pop(dialogContext);
    final auth = context.read<AuthService>();
    await auth.logout();
    if (!mounted) return;
    if (auth.currentUser == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not log out. Check your connection and retry.'),
      ),
    );
  }

  void _showMyProfileDialog() {
    final profile = context.read<ProfileService>();
    final auth = context.read<AuthService>();
    final user = auth.currentUser;

    String name = profile.displayName ?? '';
    if (name.isEmpty) {
      name = (user?.displayName ?? '').toString().trim();
    }
    final email = (profile.email ?? user?.email ?? '').toString().trim();
    if (name.isEmpty && email.contains('@')) {
      name = email.split('@').first.trim();
    }
    if (name.isEmpty) name = 'Player';

    final about = ProfileService.normalizeAbout(profile.about);
    final kingdom = (profile.kingdom ?? '').trim();
    final isGuest = user == null || user.isAnonymous;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final avatarBytes = profile.avatarBytes;
        final ImageProvider<Object> avatarImage = avatarBytes != null
            ? MemoryImage(avatarBytes) as ImageProvider<Object>
            : const AssetImage('assets/images/default_profile.png');

        return Dialog(
          backgroundColor: const Color(0xFF101010),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: AppColors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'My Profile',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Dashboard',
                        splashRadius: 18,
                        icon: const Icon(
                          Icons.dashboard_customize_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showProgressDialog();
                        },
                      ),
                      IconButton(
                        tooltip: 'Close',
                        splashRadius: 18,
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: CircleAvatar(
                      radius: 38,
                      backgroundImage: avatarImage,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      isGuest
                          ? 'Guest player'
                          : (email.isNotEmpty ? email : 'Signed in player'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MetricRow(
                    label: 'Kingdom',
                    value: kingdom.isNotEmpty ? kingdom : 'Not set',
                  ),
                  _MetricRow(
                    label: 'About',
                    value:
                        about.isNotEmpty ? about : ProfileService.defaultAbout,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isGuest
                          ? () => _openSignIn(ctx)
                          : () => _openProfileEditor(ctx),
                      icon: Icon(
                        isGuest ? Icons.login_rounded : Icons.edit_outlined,
                      ),
                      label: Text(isGuest ? 'Sign In' : 'Edit Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blue,
                        side: const BorderSide(color: AppColors.blue),
                        minimumSize: const Size(double.infinity, 46),
                      ),
                    ),
                  ),
                  if (isGuest) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openProfileEditor(ctx),
                        icon: const Icon(Icons.manage_accounts_outlined),
                        label: const Text('Guest Account & Privacy'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white30),
                          minimumSize: const Size(double.infinity, 46),
                        ),
                      ),
                    ),
                  ],
                  if (!isGuest) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          unawaited(_logoutFromProfileDialog(ctx));
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Log Out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: const BorderSide(color: AppColors.red),
                          minimumSize: const Size(double.infinity, 46),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProgressDialog() {
    final profile = context.read<ProfileService>();
    final auth = context.read<AuthService>();
    final progress = context.read<CampaignProgressService>();
    final aura = context.read<AuraPointsService>();

    final user = auth.currentUser;
    String name = profile.displayName ?? '';
    if (name.isEmpty) {
      name = (user?.displayName ?? '').toString().trim();
    }
    final email = (profile.email ?? user?.email ?? '').toString().trim();
    if (name.isEmpty && email.contains('@')) {
      name = email.split('@').first.trim();
    }
    if (name.isEmpty) name = 'Player';

    final about = profile.about.trim();
    final kingdom = (profile.kingdom ?? '').trim();

    // The whole journey, in four numbers: forts, titles, regions, rank.
    final int fortsWon = progress.totalClearedCount();
    final int fortsTotal = totalSubKingdomCount();
    final int titlesWon = progress.totalTitlesEarned();
    final int titlesTotal = kVenueGroups.fold<int>(
      0,
      (sum, group) => sum + venuesForGroup(group).length,
    );
    // A region counts as unlocked once every kingdom in it has given up its
    // title.
    final int regionsUnlocked = kVenueGroups.where((group) {
      final kingdoms = venuesForGroup(group).length;
      return kingdoms > 0 && progress.titlesEarned(group) >= kingdoms;
    }).length;
    final int regionsTotal = kVenueGroups.length;

    // Ranks live on the server, which only ranks registered accounts.
    final bool canRank =
        user != null && !user.isAnonymous && _economyApi.isConfigured;
    final Future<EconomyRank>? rankFuture =
        canRank ? _economyApi.rank() : null;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final avatarBytes = profile.avatarBytes;
        final ImageProvider<Object> avatarImage = avatarBytes != null
            ? MemoryImage(avatarBytes) as ImageProvider<Object>
            : const AssetImage('assets/images/default_profile.png');
        return Dialog(
          backgroundColor: const Color(0xFF101010),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 460,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_graph, color: AppColors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        splashRadius: 18,
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: avatarImage,
                        backgroundColor: Colors.white10,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              kingdom.isNotEmpty
                                  ? kingdom
                                  : 'Profile details not set',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            if (about.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                about,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _AupHeadline(
                    totalAup: aura.isLoaded ? aura.totalAup : null,
                  ),
                  const SizedBox(height: 10),
                  _MetricRow(
                    label: 'Forts won',
                    value: '$fortsWon / $fortsTotal',
                  ),
                  _MetricRow(
                    label: 'Titles won',
                    value: '$titlesWon / $titlesTotal',
                  ),
                  _MetricRow(
                    label: 'Regions unlocked',
                    value: '$regionsUnlocked / $regionsTotal',
                  ),
                  _GlobalRankRow(rankFuture: rankFuture),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 480;
    final hPad = compact ? 12.0 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientBackdrop()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                hPad,
                compact ? 6 : 10,
                hPad,
                compact ? 8 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VenueHeader(
                    logoAsset: _bannerAsset,
                    semanticTitle: widget.mode == VenueEntryMode.quickGame
                        ? 'Choose a venue'
                        : 'Choose a kingdom',
                    compact: compact,
                    tabs: _TitleAndTabs(controller: _tab),
                    actions: _HeaderActions(
                      onProfile: _showMyProfileDialog,
                      onTrailblazers: () {
                        unawaited(_openTrailblazers());
                      },
                      onSettings: () {
                        unawaited(showAppSettingsSheet(context));
                      },
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 6),
                  _VenueIntro(
                    lines: venueIntroLines(
                      kingdoms: totalKingdomCount(),
                      forts: totalSubKingdomCount(),
                      maxAura: aup.kAupMaxAuraTotal,
                    ),
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 6 : 10),
                  Expanded(
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        for (final group in kVenueGroups)
                          _VenueGrid(
                            group: group,
                            venues: venuesForGroup(group),
                            mode: widget.mode,
                            onOpen: _openVenue,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final NumberFormat _dashboardCount = NumberFormat.decimalPattern('en_IN');

/// The player's total AUP, shown first and largest on the dashboard.
class _AupHeadline extends StatelessWidget {
  /// Null while the wallet is still loading.
  final int? totalAup;
  const _AupHeadline({required this.totalAup});

  @override
  Widget build(BuildContext context) {
    final amount = totalAup;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AUP',
            style: TextStyle(
              color: AppColors.blue,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount == null ? '…' : aup.formatAup(amount),
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w900,
                fontSize: 30,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "#12" among every player who has won AUP. Equal AUP shares a rank.
class _GlobalRankRow extends StatelessWidget {
  /// Null when there is no registered account to rank (guests).
  final Future<EconomyRank>? rankFuture;
  const _GlobalRankRow({required this.rankFuture});

  static const String _label = 'Global rank';

  @override
  Widget build(BuildContext context) {
    final future = rankFuture;
    if (future == null) {
      return const _MetricRow(label: _label, value: 'Sign in to get ranked');
    }
    return FutureBuilder<EconomyRank>(
      future: future,
      builder: (context, snapshot) {
        final String value;
        if (snapshot.hasError) {
          value = 'Not available now';
        } else if (!snapshot.hasData) {
          value = '…';
        } else {
          final rank = snapshot.requireData.rank;
          value = rank == null
              ? 'Win AUP to get ranked'
              : '#${_dashboardCount.format(rank)}';
        }
        return _MetricRow(label: _label, value: value);
      },
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------- Kenny interlude (per-venue) ----------------------- */

class _KennyInterlude extends StatefulWidget {
  final VenueTheme venue;
  final VenueGroup group;
  static const String bannerAsset = 'assets/images/x_poker_logo.png';
  const _KennyInterlude({required this.venue, required this.group});

  @override
  State<_KennyInterlude> createState() => _KennyInterludeState();
}

class _KennyInterludeState extends State<_KennyInterlude>
    with SingleTickerProviderStateMixin {
  static const _lines = [
    "You got to know when to hold 'em",
    "Know when to fold 'em",
    'Know when to walk away',
    'And know when to run',
    "You never count your money",
    "When you're sittin' at the table",
    "There'll be time enough for countin'",
    "When the dealing's done",
  ];

  Timer? _navTimer;
  bool _navigated = false;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Allow assets to warm while showing the interlude.
    unawaited(DeckCache.ensureDeckReadySafely());
    _navTimer = Timer(const Duration(seconds: 4), _goNext);
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen.guestTable(
          tableName: 'Guest Table',
          venue: widget.venue,
          playIntroWelcome: false,
          venueMode: VenueEntryMode.quickGame,
          campaignGroup: widget.group,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              StadiumBanner(asset: _KennyInterlude.bannerAsset),
              const SizedBox(height: 30),
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _glow,
                    builder: (_, __) {
                      final double t = _glow.value;
                      return ShaderMask(
                        shaderCallback: (Rect bounds) {
                          final double width = bounds.width;
                          final double glowWidth = width * 0.35;
                          final double shift =
                              (t * (width + glowWidth * 2)) - glowWidth;
                          return LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: const [
                              Colors.white24,
                              Colors.white,
                              Colors.white24,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                            transform: _TranslateGradient(Offset(shift, 0)),
                          ).createShader(
                            Rect.fromLTWH(
                              -glowWidth,
                              0,
                              width + glowWidth * 2,
                              bounds.height,
                            ),
                          );
                        },
                        blendMode: BlendMode.srcATop,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (final line in _lines)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  line,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'OpenSans',
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            const Text(
                              '- Kenny Rogers',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'OpenSans',
                              ),
                            ),
                          ],
                        ),
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

class _TranslateGradient extends GradientTransform {
  const _TranslateGradient(this.offset);
  final Offset offset;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(offset.dx, offset.dy, 0.0);
  }
}

/* ----------------------- CIRCUIT TABS ----------------------- */

class _TitleAndTabs extends StatefulWidget {
  final TabController controller;
  const _TitleAndTabs({required this.controller});
  @override
  State<_TitleAndTabs> createState() => _TitleAndTabsState();
}

class _TitleAndTabsState extends State<_TitleAndTabs> {
  int _hoveredIndex = -1;
  int _focusedIndex = -1;

  static const List<(Color, Color)> _circuitColors = <(Color, Color)>[
    (Colors.green, Colors.white),
    (Colors.white, Colors.black),
    (Colors.yellow, Colors.black),
    (_red, Colors.white),
    (_blue, Colors.black),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  void _sync() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 480;
    final chips = <Widget>[
      for (var i = 0; i < kVenueGroups.length; i++)
        _chip(
          i,
          venueGroupLabel(kVenueGroups[i]),
          color: _circuitColors[i % _circuitColors.length].$1,
          textOn: _circuitColors[i % _circuitColors.length].$2,
          compact: compact,
        ),
    ];

    // Decide by the screen, not by the slot the header hands us: in the
    // one-row header the tabs share the row with the logo and actions, and
    // that slot can be narrower than 600 even on a landscape phone, where
    // the tabs must still stay on one line.
    if (MediaQuery.sizeOf(context).width >= 600) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: _segment(
          radius: 999,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < chips.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                chips[i],
              ],
            ],
          ),
        ),
      );
    }

    return _segment(
      radius: 22,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        runSpacing: 4,
        children: chips,
      ),
    );
  }

  Widget _segment({required double radius, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: child,
    );
  }

  Widget _chip(
    int index,
    String label, {
    required Color color,
    required Color textOn,
    required bool compact,
  }) {
    final hovered = _hoveredIndex == index;
    final focused = _focusedIndex == index;
    final selected = widget.controller.index == index;
    final highlighted = hovered || focused || selected;
    final bg = highlighted ? color : Colors.transparent;
    final fg = highlighted ? textOn : Colors.white;

    void activate() => widget.controller.animateTo(index);

    return Semantics(
      button: true,
      selected: selected,
      label: 'Switch to $label',
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) {
          setState(() => _focusedIndex = value ? index : -1);
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              activate();
              return null;
            },
          ),
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = -1),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: activate,
            child: Container(
              key: ValueKey('circuit-chip-$index'),
              decoration: ShapeDecoration(
                color: bg,
                shape: StadiumBorder(
                  side: focused
                      ? const BorderSide(color: Colors.white, width: 2)
                      : BorderSide.none,
                ),
                shadows: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 15,
                vertical: compact ? 6 : 7,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 12.5 : 13.5,
                  letterSpacing: .2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The introduction under the circuit tabs: one short line at a time,
/// changing every few seconds, so a newcomer learns the whole game without a
/// wall of text. Tap to move to the next line.
class _VenueIntro extends StatefulWidget {
  final List<String> lines;
  final bool compact;

  const _VenueIntro({
    required this.lines,
    required this.compact,
  });

  static const Duration interval = Duration(milliseconds: 4500);

  @override
  State<_VenueIntro> createState() => _VenueIntroState();
}

class _VenueIntroState extends State<_VenueIntro> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant _VenueIntro oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.lines.length) _index = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    if (widget.lines.length < 2) return;
    _timer = Timer.periodic(_VenueIntro.interval, (_) => _next());
  }

  void _next() {
    if (!mounted || widget.lines.isEmpty) return;
    setState(() => _index = (_index + 1) % widget.lines.length);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) return const SizedBox.shrink();
    final compact = widget.compact;
    final fontSize = compact ? 11.5 : 12.5;
    final still = MediaQuery.disableAnimationsOf(context);
    // Wide screens fit every line on one row; narrow ones get two, so the
    // kingdoms below keep as much height as they can.
    final lineCount = MediaQuery.sizeOf(context).width >= 700 ? 1 : 2;
    final line = widget.lines[_index];
    final text = Text(
      line,
      key: ValueKey<int>(_index),
      textAlign: TextAlign.center,
      maxLines: lineCount,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.72),
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
        letterSpacing: 0.2,
        height: 1.2,
      ),
    );

    return Semantics(
      key: const ValueKey<String>('venue-intro'),
      liveRegion: false,
      button: widget.lines.length > 1,
      label: line,
      hint: widget.lines.length > 1 ? 'Next tip' : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _next();
          _restart();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A fixed height, so the grid below never jumps when a short
            // line follows a long one.
            SizedBox(
              height: fontSize * 1.2 * lineCount + 2,
              child: Center(
                child: still
                    ? text
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: text,
                      ),
              ),
            ),
            if (widget.lines.length > 1) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.lines.length; i++)
                    AnimatedContainer(
                      duration: still
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: i == _index ? 12 : 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: i == _index ? 0.75 : 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ----------------------- VENUE GRID (2 columns, every kingdom) ----------------------- */

class _VenueGrid extends StatelessWidget {
  final VenueGroup group;
  final List<VenueTheme> venues;
  final VenueEntryMode mode;
  final Future<void> Function(VenueTheme, VenueGroup) onOpen;
  const _VenueGrid({
    required this.group,
    required this.venues,
    required this.mode,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final items = List<VenueTheme>.of(venues)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return LayoutBuilder(builder: (context, c) {
      const cols = 2;
      final rows = (items.length / cols).ceil();
      final compact = MediaQuery.sizeOf(context).height < 480;
      final hGap = compact ? 8.0 : 12.0;
      final vGap = compact ? 6.0 : 8.0;
      // Room for the pills' outer glow so the first and last rows are not
      // shaved off at the edges of the grid.
      const glowRoom = 4.0;
      final minTileH = compact ? 40.0 : 48.0;
      const maxTileH = 84.0;

      final availH = c.maxHeight - glowRoom * 2 - vGap * math.max(0, rows - 1);
      final fitTileH = rows > 0 ? availH / rows : maxTileH;
      // Every kingdom fits on one screen; scrolling is only a last resort for
      // very short windows.
      final scroll = fitTileH < minTileH;
      final tileH = scroll ? minTileH : math.min(fitTileH, maxTileH);

      return GridView.builder(
        physics: scroll
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        clipBehavior: scroll ? Clip.hardEdge : Clip.none,
        padding: const EdgeInsets.all(glowRoom),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: hGap,
          mainAxisSpacing: vGap,
          mainAxisExtent: tileH,
        ),
        itemBuilder: (_, i) => _VenueTile(
          group: group,
          mode: mode,
          venue: items[i],
          onTap: () => onOpen(items[i], group),
        ),
      );
    });
  }
}

/* ----------------------- VENUE TILE ----------------------- */

class _VenueTile extends StatefulWidget {
  final VenueGroup group;
  final VenueEntryMode mode;
  final VenueTheme venue;
  final Future<void> Function() onTap;
  const _VenueTile({
    required this.group,
    required this.mode,
    required this.venue,
    required this.onTap,
  });

  @override
  State<_VenueTile> createState() => _VenueTileState();
}

class _VenueTileState extends State<_VenueTile> {
  static const StadiumBorder _shape = StadiumBorder();
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.venue;
    final int fortCount = subKingdomCountFor(
      group: widget.group,
      kingdomName: v.name,
    );
    final String fortLabel = fortCount == 1 ? 'Fort' : 'Forts';
    final String titleName = kingdomTitleFor(
      group: widget.group,
      kingdomName: v.name,
    );
    final String infoLine = '$fortCount $fortLabel · $titleName';

    final vivid = feltHighlight(v.felt);
    final active = _hover || _pressed;
    final borderColor = vivid.withValues(alpha: active ? 1.0 : 0.85);
    final fill =
        vivid.withValues(alpha: _pressed ? 0.28 : (_hover ? 0.22 : 0.15));
    final borderWidth = active ? 2.4 : 2.0;

    return Semantics(
      button: true,
      label: widget.mode == VenueEntryMode.quickGame
          ? 'Start quick game at ${v.name}'
          : 'Open ${v.name} kingdom career',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: ShapeDecoration(
            color: Color.alphaBlend(fill, const Color(0xFF070707)),
            shape: StadiumBorder(
              side: BorderSide(color: borderColor, width: borderWidth),
            ),
            shadows: [
              BoxShadow(
                color: vivid.withValues(alpha: active ? 0.45 : 0.28),
                blurRadius: active ? 16 : 12,
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: _shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: () {
                setState(() => _pressed = false);
                widget.onTap();
              },
              customBorder: _shape,
              splashColor: vivid.withValues(alpha: 0.18),
              highlightColor: Colors.white.withValues(alpha: 0.04),
              child: LayoutBuilder(
                builder: (context, box) {
                  final h = box.maxHeight.isFinite ? box.maxHeight : 64.0;
                  final nameSize = (h * 0.22).clamp(12.5, 15.0);
                  final metaSize = (h * 0.16).clamp(10.0, 11.5);
                  final flagH = (h * 0.30).clamp(14.0, 20.0);
                  final flagW = flagH * 1.5;
                  final hPad = math.max(14.0, h * 0.4);
                  final maxContentW = math.max(0.0, box.maxWidth - hPad * 2);

                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxContentW),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: Image.asset(
                                  v.flagAsset,
                                  width: flagW,
                                  height: flagH,
                                  fit: BoxFit.cover,
                                  cacheWidth: (flagW * 3).round(),
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: flagW,
                                    height: flagH,
                                    color: Colors.white12,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.flag_outlined,
                                        color: Colors.white70, size: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.name,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: nameSize,
                                        letterSpacing: .2,
                                        height: 1.1,
                                        shadows: const [
                                          Shadow(
                                            blurRadius: 8,
                                            offset: Offset(0, 1),
                                            color: Colors.black54,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      infoLine,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.66),
                                        fontWeight: FontWeight.w700,
                                        fontSize: metaSize,
                                        letterSpacing: 0.2,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 110,
                child: Image.asset(
                  AppAssets.logo,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  strokeWidth: 3.2,
                  color: _blue,
                  valueColor: AlwaysStoppedAnimation<Color>(_blue),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Loading table...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
