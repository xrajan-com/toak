// lib/ui/screens/venue_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/config/kingdom_titles.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show subKingdomCountFor;
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
import 'package:ten_of_a_kind_poker/services/leaderboard_firestore_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/ui/screens/profile_screen.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/app_settings_sheet.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/stadium_banner.dart';

const _red = AppColors.red;
const _blue = AppColors.blue;
const _navyBlue = Color(0xFF001F3F);

/* ----------------------- HEADER ----------------------- */

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIcon(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 22),
      tooltip: tooltip,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      splashRadius: 22,
      mouseCursor: SystemMouseCursors.click,
    );
  }
}

enum _HeaderMenuAction { dashboard, settings }

class _HeaderActions extends StatelessWidget {
  final bool mirrored;
  final VoidCallback? onProfile;
  final VoidCallback? onDashboard;
  final VoidCallback? onSettings;
  const _HeaderActions({
    required this.mirrored,
    this.onProfile,
    this.onDashboard,
    this.onSettings,
  });
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final width = compact ? 96.0 : 144.0;
    if (mirrored) return SizedBox(width: width, height: 48);
    return SizedBox(
      width: width,
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _HeaderIcon(
            icon: Icons.person_outline,
            tooltip: 'My Profile',
            onTap: onProfile ?? () {},
          ),
          if (compact)
            PopupMenuButton<_HeaderMenuAction>(
              tooltip: 'More options',
              icon: const Icon(Icons.more_horiz, color: Colors.white),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              onSelected: (action) {
                switch (action) {
                  case _HeaderMenuAction.dashboard:
                    onDashboard?.call();
                  case _HeaderMenuAction.settings:
                    onSettings?.call();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _HeaderMenuAction.dashboard,
                  child: ListTile(
                    leading: Icon(Icons.dashboard_customize_outlined),
                    title: Text('Dashboard'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _HeaderMenuAction.settings,
                  child: ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Settings'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            )
          else ...[
            _HeaderIcon(
              icon: Icons.dashboard_customize_outlined,
              tooltip: 'Dashboard',
              onTap: onDashboard ?? () {},
            ),
            _HeaderIcon(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onTap: onSettings ?? () {},
            ),
          ],
        ],
      ),
    );
  }
}

/* ----------------------- SCREEN ----------------------- */

class VenueScreen extends StatefulWidget {
  static const routeName = '/venue';
  final VenueEntryMode mode;

  const VenueScreen({
    super.key,
    this.mode = VenueEntryMode.career,
  });
  @override
  State<VenueScreen> createState() => _VenueScreenState();
}

class _VenueScreenState extends State<VenueScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  static const _bannerAsset = 'assets/images/banner.png';
  int? _activeLeaderboardIndex;
  List<LeaderboardEntry> _leaderboardEntries = const <LeaderboardEntry>[];
  bool _leaderboardLoading = true;
  String? _leaderboardError;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: kVenueGroups.length, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(_loadCircuitLeaderboardEntries());
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
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _showCircuitLeaderboard(int index) {
    if (_activeLeaderboardIndex == index) return;
    setState(() => _activeLeaderboardIndex = index);
  }

  void _hideCircuitLeaderboard() {
    if (_activeLeaderboardIndex == null) return;
    setState(() => _activeLeaderboardIndex = null);
  }

  Future<void> _loadCircuitLeaderboardEntries() async {
    if (mounted) {
      setState(() {
        _leaderboardLoading = true;
        _leaderboardError = null;
      });
    }
    try {
      final aura = context.read<AuraPointsService>();
      await aura.init();
      await leaderboardFirestoreService.syncCurrentUserIfTop10(wallet: aura);
      final entries = await leaderboardFirestoreService.fetchTop10ByAura();
      if (!mounted) return;
      setState(() {
        _leaderboardEntries = entries;
        _leaderboardLoading = false;
      });
    } on ProviderNotFoundException {
      if (!mounted) return;
      setState(() {
        _leaderboardLoading = false;
        _leaderboardError = 'Leaderboard service is unavailable.';
      });
    } catch (error) {
      debugPrint('Venue leaderboard fetch failed: $error');
      if (!mounted) return;
      setState(() {
        _leaderboardLoading = false;
        _leaderboardError = 'Could not load the leaderboard.';
      });
    }
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
  }

  Future<void> _enterQuickGame(VenueTheme venue, VenueGroup group) async {
    await _pushQuickGame(venue, group);
  }

  Future<void> _openVenue(VenueTheme venue, VenueGroup group) async {
    unawaited(SoundFx.instance.unlock());
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
  }

  int _totalSubKingdomsForGroup(VenueGroup group) {
    final venues = venuesForGroup(group);
    int total = 0;
    for (final v in venues) {
      total += subKingdomCountFor(group: group, kingdomName: v.name);
    }
    return total;
  }

  int _clearedSubKingdomsForGroup(
    CampaignProgressService progress,
    VenueGroup group,
  ) {
    final venues = venuesForGroup(group);
    int total = 0;
    for (final v in venues) {
      total += progress.clearedCount(group: group, kingdomName: v.name);
    }
    return total;
  }

  void _openProfileEditor(BuildContext dialogContext) {
    Navigator.pop(dialogContext);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _openSignIn(BuildContext dialogContext) {
    Navigator.pop(dialogContext);
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

    final subProgress = <VenueGroup, ({int cleared, int total})>{
      for (final group in kVenueGroups)
        group: (
          cleared: _clearedSubKingdomsForGroup(progress, group),
          total: _totalSubKingdomsForGroup(group),
        ),
    };
    final titlesTotal = kVenueGroups.fold<int>(
      0,
      (sum, group) => sum + progress.titlesEarned(group),
    );
    final titlesPossible = kVenueGroups.fold<int>(
      0,
      (sum, group) => sum + venuesForGroup(group).length,
    );

    final double auraValue = aura.isLoaded ? aura.totalAura.clamp(0, 100) : 0;
    final int auraInt = auraValue.round().clamp(0, 100);
    final double auraProgress = auraInt / 100.0;
    final int totalAup = aura.totalAup;
    final int aupLeft =
        (aup.kAupMaxTotal - totalAup).clamp(0, aup.kAupMaxTotal);

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
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
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
                  for (final group in kVenueGroups)
                    _MetricRow(
                      label: 'Forts cleared (${venueGroupLabel(group)})',
                      value:
                          '${subProgress[group]!.cleared} / ${subProgress[group]!.total}',
                    ),
                  _MetricRow(
                    label: 'Titles earned',
                    value: '$titlesTotal / $titlesPossible',
                  ),
                  const SizedBox(height: 8),
                  _MetricRow(
                    label: 'AUP won (total)',
                    value: aup.formatAup(totalAup),
                  ),
                  _MetricRow(
                    label: 'AUP left to 100 Aura',
                    value: aup.formatAup(aupLeft),
                  ),
                  _MetricRow(
                    label: 'Euro AUP',
                    value: aup.formatAup(aura.euroAup),
                  ),
                  _MetricRow(
                    label: 'India AUP',
                    value: aup.formatAup(aura.indiaAup),
                  ),
                  _MetricRow(
                    label: 'International AUP',
                    value: aup.formatAup(aura.internationalAup),
                  ),
                  _MetricRow(
                    label: 'Micro AUP',
                    value: aup.formatAup(aura.oceaniaAup),
                  ),
                  _MetricRow(
                    label: 'US Circuit AUP',
                    value: aup.formatAup(aura.northAmericaAup),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.brightness_5,
                          color: AppColors.blue, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'Aura',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: aura.isLoaded ? auraProgress : null,
                            minHeight: 6,
                            backgroundColor: Colors.white12,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        aura.isLoaded ? '$auraInt / 100' : '…',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
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
    final screenH = MediaQuery.of(context).size.height;
    final compactHeader = screenH < 520;
    const bannerScale = 0.75;
    final bannerMaxH = (compactHeader ? 48.0 : 72.0) * bannerScale;
    final bannerMaxW = (compactHeader ? 280.0 : 420.0) * bannerScale;
    final appBarHeight = compactHeader ? 152.0 : 206.0;
    final vPad = compactHeader ? 6.0 : 10.0;
    final gapL = compactHeader ? 6.0 : 12.0;
    final gapM = compactHeader ? 4.0 : 8.0;
    final String modeSummary = widget.mode.venueSummary;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: SafeArea(
          bottom: false,
          child: Container(
            color: AppColors.black,
            padding: EdgeInsets.symmetric(vertical: vPad, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _HeaderActions(mirrored: true), // keeps center true
                    const SizedBox(width: 8),
                    Expanded(
                      child: StadiumBanner(
                        asset: _bannerAsset,
                        maxHeight: bannerMaxH,
                        maxWidth: bannerMaxW,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _HeaderActions(
                      mirrored: false,
                      onProfile: _showMyProfileDialog,
                      onDashboard: _showProgressDialog,
                      onSettings: () {
                        unawaited(showAppSettingsSheet(context));
                      },
                    ),
                  ],
                ),
                SizedBox(height: gapL),
                _TitleAndTabs(
                  controller: _tab,
                  title: widget.mode.venueHeading,
                  onLeaderboardShown: _showCircuitLeaderboard,
                  onLeaderboardHidden: _hideCircuitLeaderboard,
                ),
                SizedBox(height: gapM),
                _ModeSummary(
                  text: modeSummary,
                  accent: widget.mode == VenueEntryMode.quickGame
                      ? AppColors.red
                      : AppColors.blue,
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _hideCircuitLeaderboard(),
          child: Stack(
            children: [
              TabBarView(
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
              if (_activeLeaderboardIndex case final index?)
                Positioned(
                  top: 10,
                  left: 12,
                  right: 12,
                  child: _CircuitLeaderboardPopover(
                    spec: _circuitLeaderboards[index],
                    entries: _leaderboardEntries,
                    loading: _leaderboardLoading,
                    errorMessage: _leaderboardError,
                    onRetry: () {
                      unawaited(_loadCircuitLeaderboardEntries());
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
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
  static const String bannerAsset = 'assets/images/banner.png';
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

/* ----------------------- TITLE + TABS ----------------------- */

class _TitleAndTabs extends StatefulWidget {
  final TabController controller;
  final String title;
  final ValueChanged<int> onLeaderboardShown;
  final VoidCallback onLeaderboardHidden;
  const _TitleAndTabs({
    required this.controller,
    required this.title,
    required this.onLeaderboardShown,
    required this.onLeaderboardHidden,
  });
  @override
  State<_TitleAndTabs> createState() => _TitleAndTabsState();
}

class _TitleAndTabsState extends State<_TitleAndTabs> {
  int _hoveredIndex = -1;
  int _focusedIndex = -1;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final chipOuterPadding = compact ? 8.0 : 20.0;
        final children = <Widget>[
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              fontSize: 16,
            ),
          ),
          _chip(
            0,
            'Euro',
            color: Colors.green,
            textOn: Colors.white,
            outerHorizontalPadding: chipOuterPadding,
          ),
          _chip(
            1,
            'India',
            color: _blue,
            textOn: Colors.black,
            outerHorizontalPadding: chipOuterPadding,
          ),
          _chip(
            2,
            'International',
            color: _red,
            textOn: Colors.white,
            outerHorizontalPadding: chipOuterPadding,
          ),
          _chip(
            3,
            'Micro',
            color: Colors.yellow,
            textOn: Colors.black,
            outerHorizontalPadding: chipOuterPadding,
          ),
          _chip(
            4,
            'US Circuit',
            color: Colors.white,
            textOn: Colors.black,
            outerHorizontalPadding: chipOuterPadding,
          ),
        ];

        if (constraints.maxWidth >= 600 && compact) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  children[i],
                ],
              ],
            ),
          );
        }

        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: compact ? 6 : 10,
          runSpacing: 8,
          children: children,
        );
      },
    );
  }

  Widget _chip(
    int index,
    String label, {
    required Color color,
    required Color textOn,
    required double outerHorizontalPadding,
  }) {
    final hovered = _hoveredIndex == index;
    final focused = _focusedIndex == index;
    final selected = widget.controller.index == index;
    final highlighted = hovered || focused || selected;
    final bg = highlighted ? color : Colors.transparent;
    final fg = highlighted ? textOn : Colors.white;

    void activate() {
      widget.controller.animateTo(index);
      widget.onLeaderboardShown(index);
    }

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
          onEnter: (_) {
            setState(() => _hoveredIndex = index);
            widget.onLeaderboardShown(index);
          },
          onExit: (_) {
            setState(() => _hoveredIndex = -1);
            widget.onLeaderboardHidden();
          },
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: activate,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: EdgeInsets.symmetric(
                horizontal: outerHorizontalPadding,
                vertical: 10,
              ),
              decoration: ShapeDecoration(
                color: Colors.transparent,
                shape: StadiumBorder(
                  side: focused
                      ? const BorderSide(color: Colors.white, width: 2)
                      : BorderSide.none,
                ),
              ),
              child: Container(
                key: ValueKey('circuit-chip-$index'),
                decoration: ShapeDecoration(
                  color: bg,
                  shape: const StadiumBorder(),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: .2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircuitLeaderboardSpec {
  final String label;
  final Color background;
  final Color foreground;
  final Color headingBackground;
  final Color headingForeground;

  const _CircuitLeaderboardSpec({
    required this.label,
    required this.background,
    required this.foreground,
    required this.headingBackground,
    required this.headingForeground,
  });
}

const _circuitLeaderboards = <_CircuitLeaderboardSpec>[
  _CircuitLeaderboardSpec(
    label: 'Euro Circuit',
    background: Colors.green,
    foreground: Colors.white,
    headingBackground: Colors.white,
    headingForeground: Colors.green,
  ),
  _CircuitLeaderboardSpec(
    label: 'Indian Circuit',
    background: _blue,
    foreground: Colors.black,
    headingBackground: Colors.black,
    headingForeground: _blue,
  ),
  _CircuitLeaderboardSpec(
    label: 'International Circuit',
    background: _red,
    foreground: Colors.white,
    headingBackground: Colors.white,
    headingForeground: _red,
  ),
  _CircuitLeaderboardSpec(
    label: 'Micro Circuit',
    background: Colors.yellow,
    foreground: Colors.black,
    headingBackground: Colors.black,
    headingForeground: Colors.yellow,
  ),
  _CircuitLeaderboardSpec(
    label: 'US Circuit',
    background: Colors.white,
    foreground: Colors.black,
    headingBackground: Colors.white,
    headingForeground: Colors.black,
  ),
];

class _CircuitLeaderboardPopover extends StatelessWidget {
  final _CircuitLeaderboardSpec spec;
  final List<LeaderboardEntry> entries;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onRetry;

  const _CircuitLeaderboardPopover({
    required this.spec,
    required this.entries,
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _leaderboardRowsFor(entries);

    return Semantics(
      label: '${spec.label} global Aura leaderboard',
      liveRegion: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Material(
            color: Colors.transparent,
            elevation: 18,
            shadowColor: spec.background.withValues(alpha: 0.42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: spec.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: spec.headingBackground.withValues(alpha: 0.55),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.42),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: spec.background.withValues(alpha: 0.35),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LeaderboardHeadingRow(spec: spec),
                    if (loading)
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                          color: spec.foreground,
                          strokeWidth: 2.5,
                        ),
                      )
                    else if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: spec.foreground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                              style: TextButton.styleFrom(
                                foregroundColor: spec.foreground,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          'No ranked players yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: spec.foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      for (int i = 0; i < rows.length; i++)
                        _LeaderboardNameRow(
                          rank: i + 1,
                          name: rows[i].name,
                          auraText: rows[i].auraText,
                          spec: spec,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRowData {
  final String name;
  final int auraMilli;

  const _LeaderboardRowData({
    required this.name,
    required this.auraMilli,
  });

  String get auraText {
    if (auraMilli % 1000 == 0) return '${auraMilli ~/ 1000}';
    final tenths = (auraMilli / 100).round() / 10;
    return tenths.toStringAsFixed(tenths.truncateToDouble() == tenths ? 0 : 1);
  }
}

List<_LeaderboardRowData> _leaderboardRowsFor(
  List<LeaderboardEntry> entries,
) {
  final rows = entries
      .where((entry) => entry.auraMilli > 0)
      .map(
        (entry) => _LeaderboardRowData(
          name: entry.displayName.trim().isEmpty
              ? 'Player'
              : entry.displayName.trim(),
          auraMilli: entry.cappedAuraMilli,
        ),
      )
      .toList()
    ..sort((a, b) => b.auraMilli.compareTo(a.auraMilli));

  return rows.take(10).toList(growable: false);
}

class _LeaderboardHeadingRow extends StatelessWidget {
  final _CircuitLeaderboardSpec spec;

  const _LeaderboardHeadingRow({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      color: spec.headingBackground,
      alignment: Alignment.center,
      child: Text(
        'GLOBAL AURA',
        style: TextStyle(
          color: spec.headingForeground,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _LeaderboardNameRow extends StatelessWidget {
  final int rank;
  final String name;
  final String auraText;
  final _CircuitLeaderboardSpec spec;

  const _LeaderboardNameRow({
    required this.rank,
    required this.name,
    required this.auraText,
    required this.spec,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = spec.foreground.withValues(alpha: 0.18);

    return Container(
      height: 25,
      decoration: BoxDecoration(
        color: spec.background,
        border: Border(
          top: BorderSide(color: borderColor, width: 0.8),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: TextStyle(
                color: spec.foreground.withValues(alpha: 0.66),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: spec.foreground,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.25,
              ),
            ),
          ),
          Text(
            '$auraText AURA',
            style: TextStyle(
              color: spec.foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSummary extends StatelessWidget {
  final String text;
  final Color accent;

  const _ModeSummary({
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.82),
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          height: 1.15,
        ),
      ),
    );
  }
}

/* ----------------------- VENUE GRID (2 × 5) ----------------------- */

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
      const rows = 5, cols = 2;
      const hPad = 6.0, vPad = 6.0, hGap = 6.0, vGap = 6.0;
      const bottomCushion = 8.0;
      const bottomGuard = 16.0;
      final double bottomInset = MediaQuery.of(context).padding.bottom;
      final double bottomBuffer = bottomCushion + bottomGuard + bottomInset;

      final availW = c.maxWidth - hPad * 2 - hGap * (cols - 1);
      final tileW = availW / cols;

      final h = MediaQuery.of(context).size.height;
      final scale = h < 600 ? 0.94 : (h < 720 ? 0.975 : 1.0);

      final availH =
          (c.maxHeight - vPad * 2 - vGap * (rows - 1) - bottomBuffer) * scale;
      const minTileH = 84.0;
      final idealTileH = availH / rows;
      final tileH = math.max(idealTileH, minTileH);
      final scroll = tileH > idealTileH;

      final grid = GridView.builder(
        physics: scroll
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomGuard + bottomInset),
        itemCount: math.min(items.length, rows * cols),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: hGap,
          mainAxisSpacing: vGap,
          childAspectRatio: tileW / (tileH > 0 ? tileH : 1),
        ),
        itemBuilder: (_, i) => _VenueTile(
          group: group,
          mode: mode,
          venue: items[i],
          onTap: () => onOpen(items[i], group),
        ),
      );

      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        child: grid,
      );
      final Widget gridLayer =
          scroll ? content : SizedBox(height: c.maxHeight, child: content);

      return Stack(
        children: [
          Positioned.fill(child: gridLayer),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: bottomGuard + bottomInset,
                color: AppColors.black,
              ),
            ),
          ),
        ],
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
    Key? key,
  }) : super(key: key);

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
    final String infoLine = '$fortCount $fortLabel, Title: $titleName';

    // Stronger border color
    final borderColor =
        (_hover || _pressed) ? v.felt : v.felt.withValues(alpha: 0.95);

    final bg = _pressed
        ? Colors.black.withValues(alpha: 0.45)
        : (_hover
            ? Colors.black.withValues(alpha: 0.36)
            : Colors.black.withValues(alpha: 0.28));

    // Stronger border width
    final borderWidth = _pressed ? 4.0 : (_hover ? 3.6 : 3.2);

    // Stronger text scaling
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.25);

    final double flagW = 36 * 0.6;
    final double flagH = 24 * 0.6;
    final int flagCacheW = (flagW * 2).round();

    return Semantics(
      button: true,
      label: widget.mode == VenueEntryMode.quickGame
          ? 'Start quick game at ${v.name}'
          : 'Open ${v.name} kingdom career',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
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
            splashColor: Colors.white10,
            highlightColor: Colors.white.withValues(alpha: 0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: ShapeDecoration(
                color: bg,
                shape: StadiumBorder(
                  side: BorderSide(color: borderColor, width: borderWidth),
                ),
                shadows: [
                  // More prominent glow
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.55),
                    blurRadius: _hover ? 18 : 14,
                    spreadRadius: _hover ? 2.2 : 1.4,
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          v.flagAsset,
                          width: flagW,
                          height: flagH,
                          fit: BoxFit.cover,
                          cacheWidth: flagCacheW,
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
                        const SizedBox(width: 6),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.name,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14 * textScale,
                                  letterSpacing: .35,
                                  height: 1.0,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 8,
                                      offset: Offset(0, 1),
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                              if (infoLine.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  infoLine,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10.5 * textScale,
                                    letterSpacing: 0.25,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ],
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
