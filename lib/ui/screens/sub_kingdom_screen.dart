import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/config/.env.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/kingdom_titles.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/features/venue/game_mode.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/ui/utils/author_flash.dart';
import 'package:ten_of_a_kind_poker/ui/utils/deck_cache.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/stadium_banner.dart';

class SubKingdomScreen extends StatelessWidget {
  final VenueTheme kingdom;
  final VenueGroup group;

  const SubKingdomScreen({
    super.key,
    required this.kingdom,
    required this.group,
  });

  static const String _bannerAsset = 'assets/images/banner.png';

  String get _circuitLabel => venueGroupLabel(group);

  Future<void> _showInsufficientAupDialog(
    BuildContext context, {
    required int requiredAup,
    required String entryLabel,
  }) async {
    final String feeLabel = aup.formatAup(requiredAup);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              backgroundColor: AppColors.black,
              title: const Text(
                'Need more AUP?',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need AUP $feeLabel to enter $entryLabel.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogCtx, rootNavigator: true).pop(),
                  child: const Text('Not now'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<CampaignProgressService>();
    final auraService = context.watch<AuraPointsService>();
    if (!auraService.isLoaded) {
      unawaited(auraService.init());
    }
    final int walletAup = auraService.aupForGroup(group);
    final total = subKingdomCountFor(group: group, kingdomName: kingdom.name);
    final orderedSubKingdomIndices = ce.subKingdomIndicesByPrizePool(
      group: group,
      kingdomName: kingdom.name,
    );
    final List<int> displaySubKingdomIndices =
        orderedSubKingdomIndices.isNotEmpty &&
                orderedSubKingdomIndices.length == total
            ? orderedSubKingdomIndices
            : List<int>.generate(total, (i) => i + 1);
    final Map<int, int> posBySubIndex = <int, int>{
      for (int p = 0; p < displaySubKingdomIndices.length; p++)
        displaySubKingdomIndices[p]: p,
    };
    final int freeSubKingdomIndex = ce.freeSubKingdomIndexFor(
      group: group,
      kingdomName: kingdom.name,
    );
    final bool devUnlockAll = Env.debugMode;
    final cleared =
        progress.clearedCount(group: group, kingdomName: kingdom.name);
    final clearedAllSubKingdoms = progress.hasClearedAllSubKingdoms(
      group: group,
      kingdomName: kingdom.name,
    );
    final int mainEntryFee = aup.entryFeeForKingdomMainEvent(
      group: group,
      kingdomName: kingdom.name,
    );
    final bool canPayMain =
        mainEntryFee <= 0 || walletAup >= mainEntryFee || devUnlockAll;
    final mainEventUnlocked = Env.unlockMainEvents || clearedAllSubKingdoms;
    final mainEventCleared = progress.isMainEventCleared(
      group: group,
      kingdomName: kingdom.name,
    );
    final titleValue =
        progress.hasTitle(group: group, kingdomName: kingdom.name)
            ? kingdomTitleFor(group: group, kingdomName: kingdom.name)
            : 'N/A';
    final titlesInCircuit = progress.titlesEarned(group);

    final screenH = MediaQuery.of(context).size.height;
    final compactHeader = screenH < 520;
    const bannerScale = 0.75;
    final bannerMaxH = (compactHeader ? 48.0 : 72.0) * bannerScale;
    final bannerMaxW = (compactHeader ? 280.0 : 420.0) * bannerScale;
    final vPad = compactHeader ? 6.0 : 10.0;
    final gap = compactHeader ? 4.0 : 6.0;
    const sideW = 48.0;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Container(
                color: Colors.black,
                padding: EdgeInsets.fromLTRB(12, vPad, 12, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: sideW,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new),
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                        Expanded(
                          child: StadiumBanner(
                            asset: _bannerAsset,
                            maxHeight: bannerMaxH,
                            maxWidth: bannerMaxW,
                          ),
                        ),
                        const SizedBox(width: sideW),
                      ],
                    ),
                    SizedBox(height: gap),
                    Column(
                      children: [
                        Text(
                          kingdom.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          _circuitLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: _ProgressHeader(
                kingdom: kingdom,
                cleared: cleared,
                total: total,
                titleValue: titleValue,
                circuitProgress: titlesInCircuit,
                circuitTotal: venuesForGroup(group).length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _MainEventTile(
                felt: kingdom.felt,
                progressUnlocked: mainEventUnlocked,
                cleared: mainEventCleared,
                entryFee: mainEntryFee,
                canPay: canPayMain,
                onTap: () async {
                  if (!mainEventUnlocked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Defeat all Sub‑Kingdoms to unlock Main Event.'),
                        duration: Duration(milliseconds: 900),
                      ),
                    );
                    return;
                  }
                  if (!canPayMain) {
                    await _showInsufficientAupDialog(
                      context,
                      requiredAup: mainEntryFee,
                      entryLabel: 'Main Event',
                    );
                    return;
                  }

                  if (mainEntryFee > 0) {
                    final paid = await auraService.payEntryFee(
                      group: group,
                      amount: mainEntryFee,
                    );
                    if (!paid) {
                      if (!context.mounted) return;
                      await _showInsufficientAupDialog(
                        context,
                        requiredAup: mainEntryFee,
                        entryLabel: 'Main Event',
                      );
                      return;
                    }
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
                            venueMode: VenueEntryMode.career,
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
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                const crossAxisCount = 2;
                const crossAxisSpacing = 12.0;
                const tileHeight = 70.0;
                final tileWidth =
                    (constraints.crossAxisExtent - crossAxisSpacing) /
                        crossAxisCount;
                final childAspectRatio = tileWidth / tileHeight;

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: crossAxisSpacing,
                    mainAxisSpacing: 12,
                    childAspectRatio: childAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final idx = displaySubKingdomIndices[i];
                      final isCleared = progress.isCleared(
                        group: group,
                        kingdomName: kingdom.name,
                        subKingdomIndex: idx,
                      );
                      final progressUnlocked = devUnlockAll ||
                          progress.isUnlocked(
                            group: group,
                            kingdomName: kingdom.name,
                            subKingdomIndex: idx,
                          );
                      final int entryFee = aup.entryFeeForSubKingdomEvent(
                        group: group,
                        kingdomName: kingdom.name,
                        subKingdomIndex: idx,
                      );
                      final bool canPayEntry = entryFee <= 0 ||
                          walletAup >= entryFee ||
                          devUnlockAll;
                      final bool isUnlocked = progressUnlocked && canPayEntry;
                      final name = subKingdomDisplayName(
                        group: group,
                        kingdomName: kingdom.name,
                        index: idx,
                      );
                      final String about = () {
                        try {
                          final spec = ce.subKingdomEventSpec(
                            group: group,
                            kingdomName: kingdom.name,
                            subKingdomIndex: idx,
                          );
                          final base =
                              '${spec.tableSizeLabel()} • ${spec.prizePoolLabel}';
                          if (entryFee <= 0 || idx == freeSubKingdomIndex) {
                            return 'FREE • $base';
                          }
                          final feeLabel = aup.formatAup(entryFee);
                          return 'Entry AUP $feeLabel • $base';
                        } catch (_) {
                          return subKingdomAbout(
                            group: group,
                            kingdomName: kingdom.name,
                            index: idx,
                          );
                        }
                      }();
                      return _SubKingdomTile(
                        name: name,
                        about: about,
                        felt: kingdom.felt,
                        cleared: isCleared,
                        unlocked: isUnlocked,
                        onTap: () async {
                          if (!progressUnlocked) {
                            final int pos = posBySubIndex[idx] ?? i;
                            final int unlockFrom = pos > 0
                                ? displaySubKingdomIndices[pos - 1]
                                : idx;
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
                          if (!canPayEntry) {
                            await _showInsufficientAupDialog(
                              context,
                              requiredAup: entryFee,
                              entryLabel: 'this table',
                            );
                            return;
                          }

                          if (entryFee > 0) {
                            final paid = await auraService.payEntryFee(
                              group: group,
                              amount: entryFee,
                            );
                            if (!paid) {
                              if (!context.mounted) return;
                              await _showInsufficientAupDialog(
                                context,
                                requiredAup: entryFee,
                                entryLabel: 'this table',
                              );
                              return;
                            }
                          }

                          await showAuthorFlashOverlay(
                            context: context,
                            startWork: () async {
                              unawaited(SoundFx.instance.unlock());
                              unawaited(DeckCache.ensureDeckReady());
                              if (!context.mounted) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GameScreen.guestTable(
                                    tableName: '${kingdom.name} — $name',
                                    venue: kingdom,
                                    playIntroWelcome: false,
                                    venueMode: VenueEntryMode.career,
                                    campaignGroup: group,
                                    campaignSubKingdomIndex: idx,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    childCount: total,
                  ),
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
  final bool progressUnlocked;
  final bool cleared;
  final int entryFee;
  final bool canPay;
  final VoidCallback onTap;

  const _MainEventTile({
    required this.felt,
    required this.progressUnlocked,
    required this.cleared,
    required this.entryFee,
    required this.canPay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool actionable = progressUnlocked && (canPay || entryFee <= 0);
    final Color border = felt.withValues(alpha: actionable ? 0.95 : 0.30);
    final Color bg = Colors.black.withValues(
      alpha: actionable ? (cleared ? 0.32 : 0.25) : 0.12,
    );

    final shape = StadiumBorder(side: BorderSide(color: border, width: 2));
    final subtitle = () {
      if (!progressUnlocked) return 'Locked until all are cleared';
      if (cleared) return 'Complete';
      if (entryFee <= 0) return 'Free entry • Kingdom final table';
      final feeLabel = aup.formatAup(entryFee);
      return canPay
          ? 'Entry AUP $feeLabel • Kingdom final table'
          : 'Need AUP $feeLabel to enter';
    }();

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
            shadows: actionable
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
                  color: actionable
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
                  !actionable
                      ? Icons.lock_outline
                      : (cleared
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded),
                  color: cleared
                      ? AppColors.green
                      : Colors.white
                          .withValues(alpha: actionable ? 0.65 : 0.35),
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
