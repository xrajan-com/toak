import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/config/.env.dart';
import 'package:ten_of_a_kind_poker/config/kingdom_titles.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/ui/utils/author_flash.dart';
import 'package:ten_of_a_kind_poker/ui/utils/deck_cache.dart';

class SubKingdomScreen extends StatelessWidget {
  final VenueTheme kingdom;
  final VenueGroup group;

  const SubKingdomScreen({
    super.key,
    required this.kingdom,
    required this.group,
  });

  String get _circuitLabel =>
      group == VenueGroup.india ? 'Indian Season' : 'International Circuit';

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<CampaignProgressService>();
    final total = subKingdomCountFor(group: group, kingdomName: kingdom.name);
    final bool devUnlockAll = Env.debugMode;
    final cleared =
        progress.clearedCount(group: group, kingdomName: kingdom.name);
    final clearedAllSubKingdoms = progress.hasClearedAllSubKingdoms(
      group: group,
      kingdomName: kingdom.name,
    );
    final mainEventUnlocked = Env.unlockMainEvents || clearedAllSubKingdoms;
    final mainEventCleared = progress.isMainEventCleared(
      group: group,
      kingdomName: kingdom.name,
    );
    final titleValue = progress.hasTitle(group: group, kingdomName: kingdom.name)
        ? kingdomTitleFor(group: group, kingdomName: kingdom.name)
        : 'N/A';
    final titlesInCircuit = progress.titlesEarned(group);

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kingdom.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              _circuitLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: _ProgressHeader(
              kingdom: kingdom,
              cleared: cleared,
              total: total,
              titleValue: titleValue,
              circuitProgress: titlesInCircuit,
              circuitTotal: group == VenueGroup.india
                  ? indianVenues.length
                  : internationalVenues.length,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _MainEventTile(
              felt: kingdom.felt,
              unlocked: mainEventUnlocked,
              cleared: mainEventCleared,
              onTap: () async {
                if (!mainEventUnlocked) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Defeat all Sub‑Kingdoms to unlock Main Event.'),
                      duration: Duration(milliseconds: 900),
                    ),
                  );
                  return;
                }

                await showAuthorFlashOverlay(
                  context: context,
                  startWork: () async {
                    final unlock = SoundFx.instance.unlock();
                    final deck = DeckCache.ensureDeckReady();
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GameScreen.guestTable(
                          tableName: '${kingdom.name} — Main Event',
                          venue: kingdom,
                          playIntroWelcome: false,
                          campaignGroup: group,
                          campaignMainEvent: true,
                        ),
                      ),
                    );
                    await Future.wait([unlock, deck]);
                  },
                );
              },
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                const crossAxisCount = 2;
                const crossAxisSpacing = 12.0;
                const horizontalPadding = 16.0;
                const tileHeight = 70.0;

                final tileWidth =
                    (w - (horizontalPadding * 2) - crossAxisSpacing) /
                        crossAxisCount;
                final childAspectRatio = tileWidth / tileHeight;
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      horizontalPadding, 8, horizontalPadding, 18),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: crossAxisSpacing,
                    mainAxisSpacing: 12,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: total,
                  itemBuilder: (_, i) {
                    final idx = i + 1;
                    final isCleared = progress.isCleared(
                      group: group,
                      kingdomName: kingdom.name,
                      subKingdomIndex: idx,
                    );
                    final isUnlocked = devUnlockAll ||
                        progress.isUnlocked(
                          group: group,
                          kingdomName: kingdom.name,
                          subKingdomIndex: idx,
                        );
                    final name = subKingdomDisplayName(
                      group: group,
                      kingdomName: kingdom.name,
                      index: idx,
                    );
                    final about = subKingdomAbout(
                      group: group,
                      kingdomName: kingdom.name,
                      index: idx,
                    );
                    return _SubKingdomTile(
                      name: name,
                      about: about,
                      felt: kingdom.felt,
                      cleared: isCleared,
                      unlocked: isUnlocked,
                      onTap: () async {
                        if (!isUnlocked) {
                          final unlockFrom = math.max(1, idx - 1);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Defeat Sub‑Kingdom ${unlockFrom.toString().padLeft(2, '0')} to unlock.',
                              ),
                              duration: const Duration(milliseconds: 900),
                            ),
                          );
                          return;
                        }

                        await showAuthorFlashOverlay(
                          context: context,
                          startWork: () async {
                            final unlock = SoundFx.instance.unlock();
                            final deck = DeckCache.ensureDeckReady();
                            if (!context.mounted) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GameScreen.guestTable(
                                  tableName: '${kingdom.name} — $name',
                                  venue: kingdom,
                                  playIntroWelcome: false,
                                  campaignGroup: group,
                                  campaignSubKingdomIndex: idx,
                                ),
                              ),
                            );
                            await Future.wait([unlock, deck]);
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final VenueTheme kingdom;
  final int cleared;
  final int total;
  final String titleValue;
  final int circuitProgress;
  final int circuitTotal;

  const _ProgressHeader({
    required this.kingdom,
    required this.cleared,
    required this.total,
    required this.titleValue,
    required this.circuitProgress,
    required this.circuitTotal,
  });

  @override
  Widget build(BuildContext context) {
    final border = kingdom.felt.withValues(alpha: 0.95);
    final title = 'Title: $titleValue';
    final subtitle = 'Progress: $cleared / $total cleared';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 2),
        boxShadow: [
          BoxShadow(
            color: border.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                kingdom.flagAsset,
                width: 46,
                height: 30,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 46,
                  height: 30,
                  color: Colors.white12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.flag_outlined,
                      color: Colors.white54, size: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _CircuitBadge(progress: circuitProgress, total: circuitTotal),
          ],
        ),
      ),
    );
  }
}

class _CircuitBadge extends StatelessWidget {
  final int progress;
  final int total;
  const _CircuitBadge({required this.progress, required this.total});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Titles',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$progress / $total',
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubKingdomTile extends StatelessWidget {
  final String name;
  final String about;
  final Color felt;
  final bool cleared;
  final bool unlocked;
  final VoidCallback onTap;

  const _SubKingdomTile({
    required this.name,
    required this.about,
    required this.felt,
    required this.cleared,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color border = felt.withValues(alpha: unlocked ? 0.95 : 0.30);
    final Color bg = cleared
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: unlocked ? 0.25 : 0.12);

    final Widget content = unlocked
        ? Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            height: 1.05,
                          ),
                        ),
                        const TextSpan(text: ' - '),
                        TextSpan(
                          text: about,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (cleared)
                const Positioned(
                  right: 10,
                  top: 10,
                  child: Icon(
                    Icons.check_rounded,
                    color: AppColors.green,
                    size: 20,
                  ),
                ),
            ],
          )
        : Icon(Icons.lock_outline,
            color: Colors.white.withValues(alpha: 0.35), size: 18);

    final shape = StadiumBorder(side: BorderSide(color: border, width: 2));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Ink(
          decoration: ShapeDecoration(
            color: bg,
            shape: shape,
            shadows: unlocked
                ? [
                    BoxShadow(
                      color: border.withValues(alpha: 0.18),
                      blurRadius: 14,
                      spreadRadius: 0.6,
                    ),
                  ]
                : const [],
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

class _MainEventTile extends StatelessWidget {
  final Color felt;
  final bool unlocked;
  final bool cleared;
  final VoidCallback onTap;

  const _MainEventTile({
    required this.felt,
    required this.unlocked,
    required this.cleared,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color border = felt.withValues(alpha: unlocked ? 0.95 : 0.30);
    final Color bg =
        Colors.black.withValues(alpha: unlocked ? (cleared ? 0.32 : 0.25) : 0.12);

    final shape = StadiumBorder(side: BorderSide(color: border, width: 2));
    final subtitle = !unlocked
        ? 'Locked until all are cleared'
        : (cleared ? 'Complete' : 'Kingdom final table');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Ink(
          height: 66,
          decoration: ShapeDecoration(
            color: bg,
            shape: shape,
            shadows: unlocked
                ? [
                    BoxShadow(
                      color: border.withValues(alpha: 0.18),
                      blurRadius: 14,
                      spreadRadius: 0.6,
                    ),
                  ]
                : const [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  color: unlocked
                      ? AppColors.blue
                      : Colors.white.withValues(alpha: 0.35),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Main Event',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  !unlocked
                      ? Icons.lock_outline
                      : (cleared
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded),
                  color: cleared
                      ? AppColors.green
                      : Colors.white.withValues(alpha: unlocked ? 0.65 : 0.35),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
