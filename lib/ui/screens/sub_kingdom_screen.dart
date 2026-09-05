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
import 'package:ten_of_a_kind_poker/services/x_music_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/ui/utils/deck_cache.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/stadium_banner.dart';

class SubKingdomScreen extends StatefulWidget {
  final VenueTheme kingdom;
  final VenueGroup group;

  const SubKingdomScreen({
    super.key,
    required this.kingdom,
    required this.group,
  });

  @override
  State<SubKingdomScreen> createState() => _SubKingdomScreenState();
}

class _SubKingdomScreenState extends State<SubKingdomScreen> {
  static const String _bannerAsset = 'assets/images/x_poker_logo.png';

  bool _entryActionInProgress = false;

  VenueTheme get kingdom => widget.kingdom;
  VenueGroup get group => widget.group;

  String get _circuitLabel => venueGroupLabel(group);

  @override
  void initState() {
    super.initState();
    XMusicService.instance.playCareerCircuit(group);
  }

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

  Future<void> _showEntryFailure(
    BuildContext context, {
    required EntryPaymentResult result,
    required int requiredAup,
    required String entryLabel,
  }) async {
    if (result.status == EntryPaymentStatus.insufficientFunds) {
      await _showInsufficientAupDialog(
        context,
        requiredAup: requiredAup,
        entryLabel: entryLabel,
      );
      return;
    }
    final message = switch (result.status) {
      EntryPaymentStatus.walletLoading => 'AUP wallet is still loading.',
      EntryPaymentStatus.pending =>
        'Entry payment is being reconciled. Reconnect and tap again; '
            'the same payment attempt will be reused.',
      EntryPaymentStatus.serviceUnavailable =>
        'AUP service is unavailable. Your wallet was not treated as empty.',
      EntryPaymentStatus.updateRequired =>
        'This app version uses an older tournament catalog. Update the app '
            'before entering another event.',
      EntryPaymentStatus.campaignLocked =>
        'This event is still locked on the authoritative campaign record.',
      EntryPaymentStatus.conflict =>
        'Your wallet changed on another device. Refresh and try again.',
      _ => 'Entry could not be verified. Please try again.',
    };
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _recoverInterruptedEntry(
    BuildContext context, {
    required AuraPointsService auraService,
    required EntryReservation reservation,
  }) async {
    final EntryPaymentResult result = await auraService.recoverOrphanedEntry(
      attemptId: reservation.attemptId,
    );
    if (!context.mounted) return;
    final String message = switch (result.status) {
      EntryPaymentStatus.recovered =>
        'Interrupted entry recovered. The entry value was returned and the normal quit penalty applied.',
      EntryPaymentStatus.pending =>
        'Recovery is queued. The safety window has not elapsed yet; try again shortly.',
      EntryPaymentStatus.serviceUnavailable =>
        'Recovery service is unavailable. Your committed entry remains protected.',
      _ when result.reason == 'entry_already_settled' =>
        'That tournament was already settled.',
      _ => 'The interrupted entry could not be recovered yet.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _retryPendingSettlement(
    BuildContext context, {
    required AuraPointsService auraService,
    required CampaignProgressService progress,
  }) async {
    final bool reconciled = await auraService.reconcilePendingEconomy();
    final bool refreshed =
        reconciled ? await progress.refreshFromAuthority() : false;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reconciled && refreshed
              ? 'Tournament result confirmed and campaign progress refreshed.'
              : 'Tournament result is still queued. Your entry remains protected.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openReservedGame({
    required BuildContext context,
    required AuraPointsService auraService,
    required EntryReservation reservation,
    required Widget Function(
      BuildContext context,
      EntryReservation reservation,
    ) builder,
  }) async {
    unawaited(SoundFx.instance.unlock());
    unawaited(DeckCache.ensureDeckReadySafely());
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) =>
              builder(routeContext, reservation),
        ),
      );
    } catch (_) {
      await auraService.refundEntry(reservation);
      rethrow;
    } finally {
      if (mounted) XMusicService.instance.playCareerCircuit(group);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<CampaignProgressService>();
    final auraService = context.watch<AuraPointsService>();
    final recoveryNotice = auraService.takeEntryRecoveryNotice();
    if (recoveryNotice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(recoveryNotice),
            duration: const Duration(seconds: 5),
          ),
        );
      });
    }
    if (!auraService.isLoaded) {
      unawaited(auraService.init());
    }
    if (!progress.isHydrated) {
      return const Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.blue),
                SizedBox(height: 14),
                Text(
                  'Loading career progress…',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final int walletAup = auraService.aupForGroup(group);
    final bool walletReady = auraService.isReady;
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
    final bool canPayMain = mainEntryFee <= 0 ||
        (walletReady && walletAup >= mainEntryFee) ||
        devUnlockAll;
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
    final bool hasPendingSettlement = auraService.hasPendingCampaignSettlements;
    EntryReservation? interruptedEntry;
    if (!hasPendingSettlement) {
      for (final EntryReservation reservation
          in auraService.activeCommittedEntries.reversed) {
        interruptedEntry = reservation;
        break;
      }
    }

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
            child: _CampaignProgressAuthoritySync(
              auraService: auraService,
              progress: progress,
            ),
          ),
          if (hasPendingSettlement)
            SliverToBoxAdapter(
              child: Semantics(
                liveRegion: true,
                label: 'Tournament result awaiting server confirmation',
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17253A),
                    border: Border.all(color: AppColors.blue),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.cloud_sync_rounded,
                          color: AppColors.blue),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Your tournament result is queued. The entry is '
                          'protected and progress will unlock only after '
                          'server confirmation.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () async {
                          if (_entryActionInProgress) return;
                          _entryActionInProgress = true;
                          try {
                            await _retryPendingSettlement(
                              context,
                              auraService: auraService,
                              progress: progress,
                            );
                          } finally {
                            _entryActionInProgress = false;
                          }
                        },
                        child: const Text('RETRY'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (interruptedEntry != null)
            SliverToBoxAdapter(
              child: Semantics(
                liveRegion: true,
                label: 'Interrupted tournament entry needs recovery',
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1E08),
                    border: Border.all(color: const Color(0xFFFFD100)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.restore_rounded,
                        color: Color(0xFFFFD100),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'A previous tournament was interrupted. '
                          '${interruptedEntry.campaignId} '
                          '(${interruptedEntry.state.toUpperCase()}). '
                          'Recover ${aup.formatAup(interruptedEntry.amount)} '
                          'before entering another event.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () async {
                          if (_entryActionInProgress) return;
                          _entryActionInProgress = true;
                          try {
                            await _recoverInterruptedEntry(
                              context,
                              auraService: auraService,
                              reservation: interruptedEntry!,
                            );
                          } finally {
                            _entryActionInProgress = false;
                          }
                        },
                        child: const Text('RECOVER'),
                      ),
                    ],
                  ),
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
                  if (hasPendingSettlement || interruptedEntry != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          hasPendingSettlement
                              ? 'Wait for the queued tournament result first.'
                              : 'Recover the interrupted tournament first.',
                        ),
                      ),
                    );
                    return;
                  }
                  if (_entryActionInProgress) return;
                  _entryActionInProgress = true;
                  try {
                    if (!mainEventUnlocked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Defeat all Forts to unlock Main Event.'),
                          duration: Duration(milliseconds: 900),
                        ),
                      );
                      return;
                    }
                    if (mainEntryFee > 0 && !walletReady) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('AUP wallet is still loading.'),
                          duration: Duration(milliseconds: 900),
                        ),
                      );
                      return;
                    }
                    if (!canPayMain && !auraService.isAuthorityUnavailable) {
                      await _showInsufficientAupDialog(
                        context,
                        requiredAup: mainEntryFee,
                        entryLabel: 'Main Event',
                      );
                      return;
                    }

                    final entry = await auraService.reserveCampaignEntry(
                      group: group,
                      kingdomName: kingdom.name,
                      isMainEvent: true,
                      expectedEntryFee: mainEntryFee,
                    );
                    if (!entry.canEnter || entry.reservation == null) {
                      if (!context.mounted) return;
                      await _showEntryFailure(
                        context,
                        result: entry,
                        requiredAup: mainEntryFee,
                        entryLabel: 'Main Event',
                      );
                      return;
                    }
                    if (!context.mounted) {
                      await auraService.refundEntry(entry.reservation!);
                      return;
                    }
                    await _openReservedGame(
                      context: context,
                      auraService: auraService,
                      reservation: entry.reservation!,
                      builder: (_, EntryReservation reservation) =>
                          GameScreen.guestTable(
                        tableName: '${kingdom.name} — Main Event',
                        venue: kingdom,
                        playIntroWelcome: false,
                        venueMode: VenueEntryMode.career,
                        campaignGroup: group,
                        campaignMainEvent: true,
                        campaignEntryReservation: reservation,
                      ),
                    );
                  } finally {
                    _entryActionInProgress = false;
                  }
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
                          (walletReady && walletAup >= entryFee) ||
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
                          final prizeAup = aup.aupForSubKingdomEvent(
                            group: group,
                            kingdomName: kingdom.name,
                            subKingdomIndex: idx,
                          );
                          final prizeLabel = aup.formatAup(prizeAup);
                          final base = '${spec.tableSizeLabel()} • '
                              'Prize AUP $prizeLabel';
                          if (entryFee <= 0 || idx == freeSubKingdomIndex) {
                            return '$base • Entry FREE';
                          }
                          final feeLabel = aup.formatAup(entryFee);
                          return '$base • Entry AUP $feeLabel';
                        } catch (_) {
                          return subKingdomAbout(
                            group: group,
                            kingdomName: kingdom.name,
                            index: idx,
                          );
                        }
                      }();
                      return _SubKingdomTile(
                        key: ValueKey<String>('fort-$idx'),
                        name: name,
                        about: about,
                        felt: kingdom.felt,
                        cleared: isCleared,
                        unlocked: isUnlocked,
                        onTap: () async {
                          if (hasPendingSettlement ||
                              interruptedEntry != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  hasPendingSettlement
                                      ? 'Wait for the queued tournament result first.'
                                      : 'Recover the interrupted tournament first.',
                                ),
                              ),
                            );
                            return;
                          }
                          if (_entryActionInProgress) return;
                          _entryActionInProgress = true;
                          try {
                            if (entryFee > 0 && !walletReady) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('AUP wallet is still loading.'),
                                  duration: Duration(milliseconds: 900),
                                ),
                              );
                              return;
                            }
                            if (!canPayEntry &&
                                !auraService.isAuthorityUnavailable) {
                              await _showInsufficientAupDialog(
                                context,
                                requiredAup: entryFee,
                                entryLabel: 'this table',
                              );
                              return;
                            }

                            final entry =
                                await auraService.reserveCampaignEntry(
                              group: group,
                              kingdomName: kingdom.name,
                              isMainEvent: false,
                              subKingdomIndex: idx,
                              expectedEntryFee: entryFee,
                            );
                            if (!entry.canEnter || entry.reservation == null) {
                              if (!context.mounted) return;
                              await _showEntryFailure(
                                context,
                                result: entry,
                                requiredAup: entryFee,
                                entryLabel: 'this table',
                              );
                              return;
                            }
                            if (!context.mounted) {
                              await auraService.refundEntry(entry.reservation!);
                              return;
                            }
                            await _openReservedGame(
                              context: context,
                              auraService: auraService,
                              reservation: entry.reservation!,
                              builder: (_, EntryReservation reservation) =>
                                  GameScreen.guestTable(
                                tableName: '${kingdom.name} — $name',
                                venue: kingdom,
                                playIntroWelcome: false,
                                venueMode: VenueEntryMode.career,
                                campaignGroup: group,
                                campaignSubKingdomIndex: idx,
                                campaignEntryReservation: reservation,
                              ),
                            );
                          } finally {
                            _entryActionInProgress = false;
                          }
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

class _CampaignProgressAuthoritySync extends StatefulWidget {
  const _CampaignProgressAuthoritySync({
    required this.auraService,
    required this.progress,
  });

  final AuraPointsService auraService;
  final CampaignProgressService progress;

  @override
  State<_CampaignProgressAuthoritySync> createState() =>
      _CampaignProgressAuthoritySyncState();
}

class _CampaignProgressAuthoritySyncState
    extends State<_CampaignProgressAuthoritySync> {
  bool _inFlight = false;
  bool _ran = false;
  late bool _lastPending;

  @override
  void initState() {
    super.initState();
    _lastPending = widget.auraService.hasPendingCampaignSettlements;
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _CampaignProgressAuthoritySync oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool pending = widget.auraService.hasPendingCampaignSettlements;
    if (oldWidget.auraService != widget.auraService ||
        oldWidget.progress != widget.progress ||
        pending != _lastPending) {
      _lastPending = pending;
      _ran = false;
      _schedule();
    }
  }

  void _schedule() {
    if (_ran || _inFlight) return;
    _ran = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_reconcile());
    });
  }

  Future<void> _reconcile() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final bool reconciled =
          await widget.auraService.reconcilePendingEconomy();
      if (reconciled) {
        await widget.progress.refreshFromAuthority();
      }
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
    final subtitle = 'Forts cleared: $cleared / $total';

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
    super.key,
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

    final Color nameColor =
        Colors.white.withValues(alpha: unlocked ? 1.0 : 0.78);
    final Color aboutColor =
        Colors.white.withValues(alpha: unlocked ? 0.72 : 0.50);
    final Widget content = Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: cleared || !unlocked ? 36 : 10,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      name,
                      maxLines: 1,
                      style: TextStyle(
                        color: nameColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      about,
                      maxLines: 1,
                      style: TextStyle(
                        color: aboutColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),
              ],
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
        if (!unlocked)
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Icon(
              Icons.lock_outline,
              color: Colors.white.withValues(alpha: 0.40),
              size: 18,
            ),
          ),
      ],
    );

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
          child: content,
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
