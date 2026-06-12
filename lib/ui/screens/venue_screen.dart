// lib/ui/screens/venue_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/kingdom_titles.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show subKingdomCountFor;
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/features/venue/game_mode.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/sub_kingdom_screen.dart';
import 'package:ten_of_a_kind_poker/ui/utils/deck_cache.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/config/assets.dart';
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/ui/screens/profile_screen.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/stadium_banner.dart';

const _red = AppColors.red;
const _blue = AppColors.blue;

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
      constraints: const BoxConstraints.tightFor(width: 40, height: 48),
      padding: EdgeInsets.zero,
      splashRadius: 22,
      mouseCursor: SystemMouseCursors.click,
    );
  }
}

class _HeaderActions extends StatelessWidget {
  static const double _w = 120; // keeps banner perfectly centered
  final bool mirrored;
  final VoidCallback? onProfile;
  final VoidCallback? onProgress;
  final VoidCallback? onAup;
  const _HeaderActions({
    required this.mirrored,
    this.onProfile,
    this.onProgress,
    this.onAup,
  });
  @override
  Widget build(BuildContext context) {
    if (mirrored) return const SizedBox(width: _w, height: 48);
    return SizedBox(
      width: _w,
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _HeaderIcon(
            icon: Icons.person_outline,
            tooltip: 'My Profile',
            onTap: onProfile ?? () {},
          ),
          _HeaderIcon(
            icon: Icons.auto_graph,
            tooltip: 'Progress & Aura',
            onTap: onProgress ?? () {},
          ),
          _HeaderIcon(
            icon: Icons.account_balance_wallet_outlined,
            tooltip: 'AUP Wallet',
            onTap: onAup ?? () {},
          ),
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
  static const String _guestDocsHint =
      'Sign-up to generate ID card — play Career to win Titles.';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await DeckCache.ensureDeckReady();
      if (!mounted) return;
      final ctx = context;
      for (final v in [...indianVenues, ...internationalVenues]) {
        precacheImage(AssetImage(v.flagAsset), ctx);
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

  Future<void> _pushQuickGame(VenueTheme venue) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen.guestTable(
          tableName: '${venue.name} — Quick Game',
          venue: venue,
          playIntroWelcome: false,
          venueMode: VenueEntryMode.quickGame,
        ),
      ),
    );
  }

  Future<void> _enterQuickGame(VenueTheme venue) async {
    await _pushQuickGame(venue);
  }

  Future<void> _openVenue(VenueTheme venue, VenueGroup group) async {
    unawaited(SoundFx.instance.unlock());
    unawaited(DeckCache.ensureDeckReady());
    if (!mounted) return;
    if (widget.mode == VenueEntryMode.quickGame) {
      await _enterQuickGame(venue);
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

  Future<void> _openLocalIdCard() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final bool isGuest = user == null || user.isAnonymous;
    if (isGuest) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_guestDocsHint),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }

    final profile = context.read<ProfileService>();
    final progress = context.read<CampaignProgressService>();
    final titles = <String>[];

    void collect(VenueGroup group, List<VenueTheme> venues) {
      for (final v in venues) {
        if (!progress.hasTitle(group: group, kingdomName: v.name)) continue;
        titles.add(kingdomTitleFor(group: group, kingdomName: v.name));
      }
    }

    collect(VenueGroup.india, indianVenues);
    collect(VenueGroup.international, internationalVenues);

    String displayName = (profile.displayName ?? '').toString().trim();
    if (displayName.isEmpty) {
      displayName = (user?.displayName ?? '').toString().trim();
    }
    final String email = (profile.email ?? user?.email ?? '').toString().trim();
    if (displayName.isEmpty && email.contains('@')) {
      displayName = email.split('@').first.trim();
    }
    if (displayName.isEmpty) displayName = 'Player';

    final String about = ProfileService.normalizeAbout(profile.about);
    final String kingdom = (profile.kingdom ?? '').trim();

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PlayerIdCardScreen(
          bannerAsset: _bannerAsset,
          name: displayName,
          email: email,
          playerId: user?.uid ?? '',
          about: about,
          kingdom: kingdom,
          titles: titles,
          avatarBytes: profile.avatarBytes,
          issuedAt: DateTime.now(),
        ),
      ),
    );
  }

  int _totalSubKingdomsForGroup(VenueGroup group) {
    final venues =
        group == VenueGroup.india ? indianVenues : internationalVenues;
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
    final venues =
        group == VenueGroup.india ? indianVenues : internationalVenues;
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

  Future<void> _logoutFromProfileDialog(BuildContext dialogContext) async {
    Navigator.pop(dialogContext);
    await context.read<AuthService>().logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
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
          child: Padding(
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
                  value: about.isNotEmpty ? about : ProfileService.defaultAbout,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isGuest
                        ? () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(_guestDocsHint),
                                duration: Duration(milliseconds: 1200),
                              ),
                            );
                          }
                        : () {
                            Navigator.pop(ctx);
                            unawaited(_openLocalIdCard());
                          },
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Player ID'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.blue,
                      side: const BorderSide(color: AppColors.blue),
                      minimumSize: const Size(double.infinity, 46),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openProfileEditor(ctx),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                    ),
                  ),
                ),
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

    final about = (profile.about ?? '').trim();
    final kingdom = (profile.kingdom ?? '').trim();

    final indiaTotal = _totalSubKingdomsForGroup(VenueGroup.india);
    final intlTotal = _totalSubKingdomsForGroup(VenueGroup.international);
    final indiaCleared =
        _clearedSubKingdomsForGroup(progress, VenueGroup.india);
    final intlCleared =
        _clearedSubKingdomsForGroup(progress, VenueGroup.international);

    final titlesIndia = progress.titlesEarned(VenueGroup.india);
    final titlesIntl = progress.titlesEarned(VenueGroup.international);
    final titlesTotal = titlesIndia + titlesIntl;
    final titlesPossible = indianVenues.length + internationalVenues.length;

    final double auraValue = aura.isLoaded ? aura.totalAura.clamp(0, 100) : 0;
    final int auraInt = auraValue.round().clamp(0, 100);
    final double auraProgress = auraInt / 100.0;

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
          child: Padding(
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
                      'Progress & Aura',
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
                _MetricRow(
                  label: 'Sub‑Kingdoms cleared (India)',
                  value: '$indiaCleared / $indiaTotal',
                ),
                _MetricRow(
                  label: 'Sub‑Kingdoms cleared (International)',
                  value: '$intlCleared / $intlTotal',
                ),
                _MetricRow(
                  label: 'Titles earned',
                  value: '$titlesTotal / $titlesPossible',
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
        );
      },
    );
  }

  void _showAupDialog() {
    final aura = context.read<AuraPointsService>();
    final int total = aura.totalAup;
    final int left = (aup.kAupMaxTotal - total).clamp(0, aup.kAupMaxTotal);
    final india = aura.indiaAup;
    final intl = aura.internationalAup;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF101010),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        color: AppColors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'AUP Wallet',
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
                _MetricRow(
                  label: 'AUP won (total)',
                  value: aup.formatAup(total),
                ),
                _MetricRow(
                  label: 'AUP left to 100 Aura',
                  value: aup.formatAup(left),
                ),
                const SizedBox(height: 6),
                _MetricRow(
                  label: 'India AUP',
                  value: aup.formatAup(india),
                ),
                _MetricRow(
                  label: 'International AUP',
                  value: aup.formatAup(intl),
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
    final screenH = MediaQuery.of(context).size.height;
    final compactHeader = screenH < 520;
    const bannerScale = 0.75;
    final bannerMaxH = (compactHeader ? 48.0 : 72.0) * bannerScale;
    final bannerMaxW = (compactHeader ? 280.0 : 420.0) * bannerScale;
    final appBarHeight = compactHeader ? 148.0 : 206.0;
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
                      onProgress: _showProgressDialog,
                      onAup: _showAupDialog,
                    ),
                  ],
                ),
                SizedBox(height: gapL),
                _TitleAndTabs(
                  controller: _tab,
                  title: widget.mode.venueHeading,
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
        child: TabBarView(
          controller: _tab,
          children: [
            _VenueGrid(
              group: VenueGroup.international,
              venues: internationalVenues,
              mode: widget.mode,
              onOpen: _openVenue,
            ),
            _VenueGrid(
              group: VenueGroup.india,
              venues: indianVenues,
              mode: widget.mode,
              onOpen: _openVenue,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerIdCardScreen extends StatelessWidget {
  final String bannerAsset;
  final String name;
  final String email;
  final String playerId;
  final String about;
  final String kingdom;
  final List<String> titles;
  final Uint8List? avatarBytes;
  final DateTime issuedAt;

  const _PlayerIdCardScreen({
    required this.bannerAsset,
    required this.name,
    required this.email,
    required this.playerId,
    required this.about,
    required this.kingdom,
    required this.titles,
    required this.avatarBytes,
    required this.issuedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Player ID'),
        actions: [
          IconButton(
            tooltip: 'Edit Profile',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _PlayerLicenseCard(
                bannerAsset: bannerAsset,
                name: name,
                email: email,
                playerId: playerId,
                about: about,
                kingdom: kingdom,
                titles: titles,
                avatarBytes: avatarBytes,
                issuedAt: issuedAt,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerLicenseCard extends StatelessWidget {
  final String bannerAsset;
  final String name;
  final String email;
  final String playerId;
  final String about;
  final String kingdom;
  final List<String> titles;
  final Uint8List? avatarBytes;
  final DateTime issuedAt;

  const _PlayerLicenseCard({
    required this.bannerAsset,
    required this.name,
    required this.email,
    required this.playerId,
    required this.about,
    required this.kingdom,
    required this.titles,
    required this.avatarBytes,
    required this.issuedAt,
  });

  @override
  Widget build(BuildContext context) {
    final titleLine =
        titles.isEmpty ? 'Career titles pending' : titles.take(2).join(' / ');
    return RepaintBoundary(
      child: Container(
        width: 760,
        height: 480,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F1E8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black, width: 2.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _LicenseBackgroundPainter()),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 270,
                          height: 64,
                          child: Image.asset(bannerAsset, fit: BoxFit.contain),
                        ),
                        const Spacer(),
                        const Text(
                          'PLAYER LICENSE',
                          style: TextStyle(
                            color: Color(0xFF141414),
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _LicenseField(
                                  label: 'Name',
                                  value: name,
                                  large: true,
                                ),
                                const SizedBox(height: 14),
                                _LicenseField(label: 'Email', value: email),
                                const SizedBox(height: 14),
                                _LicenseField(
                                  label: 'Player ID',
                                  value: playerId,
                                ),
                                const SizedBox(height: 14),
                                _LicenseField(
                                  label: 'Kingdom',
                                  value: kingdom.isEmpty ? 'Not set' : kingdom,
                                ),
                                const SizedBox(height: 14),
                                _LicenseField(
                                  label: 'About',
                                  value: about.isEmpty
                                      ? ProfileService.defaultAbout
                                      : about,
                                ),
                                const SizedBox(height: 14),
                                _LicenseField(
                                    label: 'Titles', value: titleLine),
                              ],
                            ),
                          ),
                          const SizedBox(width: 28),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: 166,
                                height: 204,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.72),
                                    width: 1.5,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: avatarBytes == null
                                    ? Image.asset(
                                        'assets/images/default_profile.png',
                                        fit: BoxFit.cover,
                                      )
                                    : Image.memory(
                                        avatarBytes!,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: 166,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.36),
                                  ),
                                  color: Colors.white.withValues(alpha: 0.58),
                                ),
                                child: Text(
                                  _issuedLabel(issuedAt),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF2B2B2B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'LOCAL DEVICE COPY',
                                style: TextStyle(
                                  color: Color(0xFFB21818),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _issuedLabel(DateTime date) {
    final d = date.toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'ISSUED $y-$m-$day';
  }
}

class _LicenseField extends StatelessWidget {
  final String label;
  final String value;
  final bool large;

  const _LicenseField({
    required this.label,
    required this.value,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF6C6A66),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value.isEmpty ? '-' : value,
          maxLines: large ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.black,
            fontSize: large ? 30 : 17,
            height: 1.05,
            fontWeight: large ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LicenseBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.black.withValues(alpha: 0.055);
    for (double x = -size.height; x < size.width; x += 34) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), paint);
    }

    final sealPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = const Color(0xFFB21818).withValues(alpha: 0.055);
    canvas.drawCircle(
        Offset(size.width * 0.47, size.height * 0.55), 104, sealPaint);
    canvas.drawCircle(
        Offset(size.width * 0.47, size.height * 0.55), 72, sealPaint);
  }

  @override
  bool shouldRepaint(covariant _LicenseBackgroundPainter oldDelegate) => false;
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
    DeckCache.ensureDeckReady();
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
  const _TitleAndTabs({
    required this.controller,
    required this.title,
  });
  @override
  State<_TitleAndTabs> createState() => _TitleAndTabsState();
}

class _TitleAndTabsState extends State<_TitleAndTabs> {
  int _hoveredIndex = -1;

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
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            fontSize: 16,
          ),
        ),
        _chip(0, 'International', color: _red, textOn: Colors.white),
        _chip(1, 'India', color: _blue, textOn: Colors.black),
      ],
    );
  }

  Widget _chip(int index, String label,
      {required Color color, required Color textOn}) {
    final hovered = _hoveredIndex == index;
    final selected = widget.controller.index == index;
    final bg = (hovered || selected) ? color : Colors.transparent;
    final fg = (hovered || selected) ? textOn : Colors.white70;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = -1),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.controller.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const ShapeDecoration(
            color: Colors.transparent,
            shape: StadiumBorder(),
          ),
          child: Container(
            decoration:
                ShapeDecoration(color: bg, shape: const StadiumBorder()),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
    final String infoLine = () {
      if (widget.mode == VenueEntryMode.quickGame) {
        return 'FREE • Quick Game';
      }
      try {
        final int freeIdx = ce.freeSubKingdomIndexFor(
          group: widget.group,
          kingdomName: v.name,
        );
        final spec = ce.subKingdomEventSpec(
          group: widget.group,
          kingdomName: v.name,
          subKingdomIndex: freeIdx,
        );
        return 'FREE • ${spec.prizePoolLabel}';
      } catch (_) {
        try {
          final main = ce.kingdomMainEventSpec(
            group: widget.group,
            kingdomName: v.name,
          );
          return main.prizePoolLabel;
        } catch (_) {
          return '';
        }
      }
    }();

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
