import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/x_music_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/auth_screen.dart';
import 'package:ten_of_a_kind_poker/features/venue/game_mode.dart';
import 'package:ten_of_a_kind_poker/ui/screens/venue_screen.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/stadium_banner.dart';

class GameModeScreen extends StatefulWidget {
  const GameModeScreen({super.key});

  @override
  State<GameModeScreen> createState() => _GameModeScreenState();
}

class _GameModeScreenState extends State<GameModeScreen> {
  static const String _bannerAsset = 'assets/images/x_poker_logo.png';

  @override
  void initState() {
    super.initState();
    XMusicService.instance.playHomepage();
  }

  Future<void> _openMode(BuildContext context, VenueEntryMode mode) async {
    XMusicService.instance.stop();
    unawaited(XMusicService.instance.unlock());
    if (mode == VenueEntryMode.career) {
      final user = context.read<AuthService>().currentUser;
      final isRegisteredUser = user != null && !user.isAnonymous;
      if (!isRegisteredUser) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AuthScreen(
              requireRegisteredUser: true,
              postAuthDestination: VenueScreen(mode: VenueEntryMode.career),
              title: 'Login or Register for Career',
              message:
                  'Career progress is saved to your account across kingdoms, forts, titles, and Aura.',
            ),
          ),
        );
        if (mounted) XMusicService.instance.playHomepage();
        return;
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VenueScreen(mode: mode),
      ),
    );
    if (mounted) XMusicService.instance.playHomepage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool compact =
                constraints.maxHeight < 430 || constraints.maxWidth < 820;
            final bool stacked = constraints.maxWidth < 720;
            final double contentMaxWidth =
                math.min(constraints.maxWidth - 32, stacked ? 520 : 1080);
            final double cardGap = compact ? 12 : 18;
            final double cardWidth =
                stacked ? contentMaxWidth : (contentMaxWidth - cardGap) / 2;
            final double cardHeight = stacked
                ? (constraints.maxHeight * 0.30).clamp(160.0, 220.0)
                : (constraints.maxHeight * 0.43).clamp(200.0, 290.0);

            Widget card(VenueEntryMode mode,
                {required IconData icon,
                required Color accent,
                required Color secondary}) {
              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: _GameModeCard(
                  mode: mode,
                  icon: icon,
                  accent: accent,
                  secondary: secondary,
                  compact: compact,
                  onTap: () => unawaited(_openMode(context, mode)),
                ),
              );
            }

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, compact ? 12 : 18, 16, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StadiumBanner(
                        asset: _bannerAsset,
                        maxHeight: compact ? 52 : 68,
                        maxWidth: compact ? 300 : 400,
                      ),
                      SizedBox(height: compact ? 10 : 16),
                      Text(
                        'Game Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 24 : 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: compact ? 6 : 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Text(
                          'Quick Game throws you straight into a single table. '
                          'Career keeps the kingdom ladder, fort clears, and title match progression.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: compact ? 11.8 : 13.8,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 12 : 20),
                      if (stacked) ...[
                        card(
                          VenueEntryMode.quickGame,
                          icon: Icons.bolt_rounded,
                          accent: AppColors.red,
                          secondary: AppColors.red,
                        ),
                        SizedBox(height: cardGap),
                        card(
                          VenueEntryMode.career,
                          icon: Icons.workspace_premium_rounded,
                          accent: AppColors.blue,
                          secondary: AppColors.green,
                        ),
                      ] else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            card(
                              VenueEntryMode.quickGame,
                              icon: Icons.bolt_rounded,
                              accent: AppColors.red,
                              secondary: AppColors.red,
                            ),
                            SizedBox(width: cardGap),
                            card(
                              VenueEntryMode.career,
                              icon: Icons.workspace_premium_rounded,
                              accent: AppColors.blue,
                              secondary: AppColors.green,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GameModeCard extends StatelessWidget {
  final VenueEntryMode mode;
  final IconData icon;
  final Color accent;
  final Color secondary;
  final bool compact;
  final VoidCallback onTap;

  const _GameModeCard({
    required this.mode,
    required this.icon,
    required this.accent,
    required this.secondary,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final LinearGradient gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        accent.withValues(alpha: 0.52),
        accent.withValues(alpha: 0.40),
        accent.withValues(alpha: 0.28),
      ],
      stops: const [0.0, 0.58, 1.0],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double widthScale =
            constraints.maxWidth / (compact ? 360.0 : 470.0);
        final double heightScale =
            constraints.maxHeight / (compact ? 185.0 : 270.0);
        final double scale =
            math.min(widthScale, heightScale).clamp(0.82, 1.16).toDouble();

        final double iconShell = (compact ? 44.0 : 52.0) * scale;
        final double iconSize = (compact ? 22.0 : 28.0) * scale;
        final double titleSize = (compact ? 21.0 : 28.0) * scale;
        final double bodySize = (compact ? 12.4 : 14.0) * scale;
        final double detailSize = (compact ? 11.2 : 12.5) * scale;
        final double ctaSize = (compact ? 12.4 : 13.5) * scale;
        final double ctaIconSize = 18.0 * scale;
        final double ctaMinHeight = (compact ? 46.0 : 52.0) * scale;
        final EdgeInsets cardPadding = EdgeInsets.fromLTRB(
          (compact ? 18.0 : 24.0) * scale,
          (compact ? 16.0 : 22.0) * scale,
          (compact ? 18.0 : 24.0) * scale,
          (compact ? 16.0 : 20.0) * scale,
        );
        final double maxCtaWidth = math.min(
          constraints.maxWidth - cardPadding.horizontal,
          (compact ? 250.0 : 290.0) * scale,
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Ink(
              decoration: ShapeDecoration(
                gradient: gradient,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: accent.withValues(alpha: 0.92),
                    width: 2.2,
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: iconShell,
                      height: iconShell,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(icon, color: accent, size: iconSize),
                    ),
                    const Spacer(),
                    Text(
                      mode.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: (compact ? 5.0 : 8.0) * scale),
                    Text(
                      mode.subtitle,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: bodySize,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: (compact ? 7.0 : 10.0) * scale),
                    Text(
                      mode.detail,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: detailSize,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: (compact ? 12.0 : 18.0) * scale),
                    Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: ctaMinHeight,
                          maxWidth: maxCtaWidth,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: (compact ? 24.0 : 28.0) * scale,
                            vertical: (compact ? 10.0 : 12.0) * scale,
                          ),
                          decoration: ShapeDecoration(
                            color: accent.withValues(alpha: 0.16),
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: accent.withValues(alpha: 0.60),
                                width: 1.4,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Flexible(
                                child: Text(
                                  mode.ctaLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: ctaSize,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10 * scale),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: ctaIconSize,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
