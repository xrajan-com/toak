// lib/ui/screens/venue_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/config/.env.dart';
import 'package:ten_of_a_kind_poker/config/kingdom_titles.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/sub_kingdom_screen.dart';
import 'package:ten_of_a_kind_poker/ui/utils/deck_cache.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/config/assets.dart';
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:url_launcher/url_launcher.dart';

const _red = AppColors.red;
const _blue = AppColors.blue;

/* ----------------------- HEADER ----------------------- */

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 22),
      tooltip: tooltip,
      onPressed: onTap,
      splashRadius: 22,
    );
  }
}

class _HeaderActions extends StatelessWidget {
  static const double _w = 144; // keeps banner perfectly centered
  final bool mirrored;
  const _HeaderActions({required this.mirrored});
  @override
  Widget build(BuildContext context) {
    if (mirrored) return const SizedBox(width: _w, height: 48);
    return SizedBox(
      width: _w,
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _HeaderIcon(icon: Icons.emoji_events_outlined, tooltip: 'Leaderboard', onTap: () {}),
          _HeaderIcon(icon: Icons.person_outline,         tooltip: 'My Profile',  onTap: () {}),
        ],
      ),
    );
  }
}

/* ----------------------- STADIUM/CAPSULE BANNER ----------------------- */
/* No glow, no background, tightly clipped to capsule. */
class _StadiumBanner extends StatelessWidget {
  final String asset;
  const _StadiumBanner({required this.asset});

  static const StadiumBorder _shape = StadiumBorder();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final maxW = math.min(c.maxWidth, 420.0);
      const maxH = 88.0;

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: maxH),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: _shape),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              // Important: no padding/decoration so there’s zero border/glow
              width: maxW,
              child: FittedBox(
                fit: BoxFit.fitHeight, // fit height so sides are never cropped
                alignment: Alignment.center,
                child: Image.asset(
                  asset,
                  isAntiAlias: true,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/* ----------------------- SCREEN ----------------------- */

class VenueScreen extends StatefulWidget {
  static const routeName = '/venue';

  const VenueScreen({super.key});
  @override
  State<VenueScreen> createState() => _VenueScreenState();
}

class _VenueScreenState extends State<VenueScreen> with SingleTickerProviderStateMixin {
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

  Future<void> _openVenue(VenueTheme venue, VenueGroup group) async {
    await SoundFx.instance.unlock();
    await DeckCache.ensureDeckReady();
    if (!mounted) return;
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

  Future<void> _openDocumentsPortal() async {
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

    final progress = context.read<CampaignProgressService>();
    final titles = <Map<String, String>>[];

    void collect(VenueGroup group, List<VenueTheme> venues) {
      for (final v in venues) {
        if (!progress.hasTitle(group: group, kingdomName: v.name)) continue;
        titles.add({
          'group': group.name,
          'kingdom': v.name,
          'title': kingdomTitleFor(group: group, kingdomName: v.name),
        });
      }
    }

    collect(VenueGroup.india, indianVenues);
    collect(VenueGroup.international, internationalVenues);

    String displayName = (user?.displayName ?? '').toString().trim();
    final String email = (user?.email ?? '').toString().trim();
    if (displayName.isEmpty && email.contains('@')) {
      displayName = email.split('@').first.trim();
    }
    if (displayName.isEmpty) displayName = 'Player';

    final Uri uri = Uri.parse(Env.documentsPortalUrl).replace(
      queryParameters: <String, String>{
        'uid': (user?.uid ?? '').toString(),
        'name': displayName,
        'email': email,
        'titles': jsonEncode(titles),
      },
    );

    try {
      final ok = await canLaunchUrl(uri);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open website'),
            duration: Duration(milliseconds: 900),
          ),
        );
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open website'),
          duration: Duration(milliseconds: 900),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final isGuest = user == null || user.isAnonymous;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(190),
        child: SafeArea(
          bottom: false,
          child: Container(
            color: AppColors.black,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _HeaderActions(mirrored: true), // keeps center true
                    const SizedBox(width: 8),
                    const Expanded(child: _StadiumBanner(asset: _bannerAsset)),
                    const SizedBox(width: 8),
                    const _HeaderActions(mirrored: false),
                  ],
                ),
                const SizedBox(height: 12),
                _TitleAndTabs(controller: _tab),
                const SizedBox(height: 8),
                _DocsHint(
                  isGuest: isGuest,
                  onOpenWebsite: _openDocumentsPortal,
                  guestHintText: _guestDocsHint,
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
              group: VenueGroup.india,
              venues: indianVenues,
              onOpen: _openVenue,
            ),
            _VenueGrid(
              group: VenueGroup.international,
              venues: internationalVenues,
              onOpen: _openVenue,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocsHint extends StatelessWidget {
  final bool isGuest;
  final Future<void> Function() onOpenWebsite;
  final String guestHintText;

  const _DocsHint({
    required this.isGuest,
    required this.onOpenWebsite,
    required this.guestHintText,
  });

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          guestHintText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            height: 1.15,
          ),
        ),
      );
    }

    return Center(
      child: TextButton.icon(
        onPressed: () {
          unawaited(onOpenWebsite());
        },
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: const Text(
          'Go to website',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
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
              _StadiumBanner(asset: _KennyInterlude.bannerAsset),
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
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  line,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Courier',
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
                                fontFamily: 'Courier',
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
  const _TitleAndTabs({required this.controller});
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
        const Text(
          'Choose a Venue',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            fontSize: 16,
          ),
        ),
        _chip(0, 'India', color: _red,  textOn: Colors.white),
        _chip(1, 'International', color: _blue, textOn: Colors.black),
      ],
    );
  }

  Widget _chip(int index, String label, {required Color color, required Color textOn}) {
    final hovered  = _hoveredIndex == index;
    final selected = widget.controller.index == index;
    final bg = (hovered || selected) ? color : Colors.transparent;
    final fg = (hovered || selected) ? textOn : Colors.white70;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit:  (_) => setState(() => _hoveredIndex = -1),
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
            decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
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

/* ----------------------- VENUE GRID (2 × 5) ----------------------- */

class _VenueGrid extends StatelessWidget {
  final VenueGroup group;
  final List<VenueTheme> venues;
  final Future<void> Function(VenueTheme, VenueGroup) onOpen;
  const _VenueGrid({
    required this.group,
    required this.venues,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final items = List<VenueTheme>.of(venues)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return LayoutBuilder(builder: (context, c) {
      const rows = 5, cols = 2;
      const hPad = 6.0, vPad = 6.0, hGap = 6.0, vGap = 6.0, bottomCushion = 8.0;

      final availW = c.maxWidth - hPad * 2 - hGap * (cols - 1);
      final tileW  = availW / cols;

      final h = MediaQuery.of(context).size.height;
      final scale = h < 600 ? 0.94 : (h < 720 ? 0.975 : 1.0);

      final availH = (c.maxHeight - vPad * 2 - vGap * (rows - 1) - bottomCushion) * scale;
      final tileH  = availH / rows;
      final scroll = tileH <= 64;

      final grid = GridView.builder(
        physics: scroll ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: math.min(items.length, rows * cols),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: hGap,
          mainAxisSpacing: vGap,
          childAspectRatio: tileW / (tileH > 0 ? tileH : 1),
        ),
        itemBuilder: (_, i) => _VenueTile(
          venue: items[i],
          onTap: () => onOpen(items[i], group),
        ),
      );

      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        child: ClipRect(child: grid),
      );

      return scroll ? content : SizedBox(height: c.maxHeight, child: content);
    });
  }
}

/* ----------------------- VENUE TILE ----------------------- */

class _VenueTile extends StatefulWidget {
  final VenueTheme venue;
  final Future<void> Function() onTap;
  const _VenueTile({required this.venue, required this.onTap, Key? key}) : super(key: key);

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

    // Stronger border color
    final borderColor = (_hover || _pressed)
        ? v.felt
        : v.felt.withValues(alpha: 0.95);

    final bg = _pressed
        ? Colors.black.withValues(alpha: 0.45)
        : (_hover ? Colors.black.withValues(alpha: 0.36)
                  : Colors.black.withValues(alpha: 0.28));

    // Stronger border width
    final borderWidth = _pressed ? 4.0 : (_hover ? 3.6 : 3.2);

    // Stronger text scaling
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.25);

    return Semantics(
      button: true,
      label: 'Open ${v.name} venue',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit:  (_) => setState(() => _hover = false),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          v.flagAsset,
                          width: 36,
                          height: 24,
                          fit: BoxFit.cover,
                          cacheWidth: 72,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => Container(
                            width: 36,
                            height: 24,
                            color: Colors.white12,
                            alignment: Alignment.center,
                            child: const Icon(Icons.flag_outlined,
                                color: Colors.white70, size: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            v.name,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
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
