import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/config/venues.dart'
    show VenueGroup, venueGroupLabel;
import 'package:ten_of_a_kind_poker/core/aup.dart' show formatAup;
import 'package:ten_of_a_kind_poker/core/daily_tribute.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/economy_api_service.dart'
    show DailyTributeClaim;
import 'package:ten_of_a_kind_poker/services/game_analytics.dart';
import 'package:ten_of_a_kind_poker/services/return_reminders.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

/// The daily tribute on the home screen: red and asking to be tapped while
/// today's is waiting, quiet blue once it is claimed.
///
/// Renders nothing without a server wallet (a local guest with no account,
/// or before the wallet has loaded), and nothing where the AUP service is
/// not provided (widget tests of the home screen alone).
class DailyTributeChip extends StatefulWidget {
  const DailyTributeChip({
    super.key,
    required this.compact,
    this.maxWidth = 300,
    this.onPlayFort,
  });

  final bool compact;
  final double maxWidth;

  /// Opens Career; offered after a claim, where the new AUP is spent.
  final VoidCallback? onPlayFort;

  @override
  State<DailyTributeChip> createState() => _DailyTributeChipState();
}

class _DailyTributeChipState extends State<DailyTributeChip> {
  Timer? _midnight;
  bool _remindersRefreshed = false;

  @override
  void dispose() {
    _midnight?.cancel();
    super.dispose();
  }

  static AuraPointsService? _auraOrNull(BuildContext context) {
    try {
      return context.watch<AuraPointsService>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// At midnight the chip turns red again, even if the app stayed open.
  void _armMidnight(DailyTributeState tribute) {
    if (_midnight?.isActive ?? false) return;
    final Duration wait =
        tribute.nextOpensAt.difference(DateTime.now()) +
            const Duration(seconds: 2);
    _midnight = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _claim(AuraPointsService aura) async {
    final DailyTributeClaim? result = await aura.claimDailyTribute();
    if (!mounted || result == null) return;
    final ScaffoldMessengerState? messenger =
        ScaffoldMessenger.maybeOf(context);
    if (!result.accepted) {
      final String message = result.alreadyClaimed
          ? "Today's tribute is already in your wallet. Come back tomorrow."
          : result.unavailable
              ? "Couldn't reach the server. Try again in a moment."
              : 'The tribute could not be claimed right now.';
      messenger?.showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    unawaited(GameAnalytics.tributeClaimed(
      streak: result.streak,
      amount: result.delta,
    ));
    unawaited(SoundFx.instance.playChipsToWinner(heroWon: true));
    final ReturnReminders reminders = ReturnReminders.instance;
    final bool offer = await reminders.shouldOffer();
    if (!mounted) return;
    final _TributeDialogChoice choice = await _showTributeDialog(
      context,
      streak: result.streak,
      amount: result.delta,
      circuit: _circuitLabel(result.group),
      offerReminders: offer,
      canPlayFort: widget.onPlayFort != null,
    );
    if (offer) await reminders.setEnabled(choice.remind);
    unawaited(reminders.refresh(aura.dailyTribute()));
    if (choice.playFort && mounted) widget.onPlayFort?.call();
  }

  static String? _circuitLabel(String group) {
    for (final VenueGroup candidate in VenueGroup.values) {
      if (candidate.name == group) return venueGroupLabel(candidate);
    }
    return null;
  }

  void _showLadder(DailyTributeState tribute) {
    unawaited(_showTributeDialog(
      context,
      streak: tribute.displayStreak,
      amount: 0,
      offerReminders: false,
      canPlayFort: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final AuraPointsService? aura = _auraOrNull(context);
    if (aura == null || !aura.dailyTributeAvailable) {
      return const SizedBox.shrink();
    }
    final DailyTributeState tribute = aura.dailyTribute();
    _armMidnight(tribute);
    if (!_remindersRefreshed) {
      // Opening the home screen moves every pending reminder forward, so a
      // player who keeps coming back never gets one.
      _remindersRefreshed = true;
      unawaited(ReturnReminders.instance.refresh(tribute));
    }

    final bool claimable = tribute.canClaim;
    final bool busy = aura.isClaimingDailyTribute;
    final bool compact = widget.compact;
    final int streak = tribute.displayStreak;
    final String headline = claimable
        ? 'DAY $streak TRIBUTE'
        : 'DAY ${math.max(streak, 1)} CLAIMED';
    final String subline = claimable
        ? '+${formatAup(tribute.amountToday)} AUP · tap to claim'
        : 'Tomorrow +${formatAup(tribute.amountTomorrow)} AUP';
    final Color accent = claimable ? AppColors.red : AppColors.blue;
    final double shell = compact ? 30 : 36;
    final VoidCallback? onTap = busy
        ? null
        : claimable
            ? () => unawaited(_claim(aura))
            : () => _showLadder(tribute);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Semantics(
        button: true,
        label: claimable
            ? 'Claim day $streak tribute, '
                '${formatAup(tribute.amountToday)} AUP'
            : 'Daily tribute claimed. Tomorrow '
                '${formatAup(tribute.amountTomorrow)} AUP',
        // The label above says it all; the tap is carried here because the
        // InkWell's own semantics are excluded with its texts.
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey<String>('daily_tribute_chip'),
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Ink(
              decoration: ShapeDecoration(
                gradient: LinearGradient(
                  colors: claimable
                      ? <Color>[
                          AppColors.red.withValues(alpha: 0.92),
                          AppColors.red.withValues(alpha: 0.62),
                        ]
                      : <Color>[
                          AppColors.blue.withValues(alpha: 0.14),
                          AppColors.blue.withValues(alpha: 0.06),
                        ],
                ),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: accent.withValues(alpha: claimable ? 1 : 0.5),
                    width: 1.4,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 6 : 8,
                  compact ? 5 : 6,
                  compact ? 16 : 20,
                  compact ? 5 : 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: shell,
                      height: shell,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.28),
                      ),
                      child: busy
                          ? Padding(
                              padding: EdgeInsets.all(compact ? 7 : 9),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              claimable
                                  ? Icons.redeem_rounded
                                  : Icons.check_rounded,
                              color: claimable ? Colors.white : AppColors.blue,
                              size: compact ? 17 : 20,
                            ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            headline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 12.5 : 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: claimable ? 0.92 : 0.7,
                              ),
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}

class _TributeDialogChoice {
  const _TributeDialogChoice({this.playFort = false, this.remind = true});

  final bool playFort;
  final bool remind;
}

/// The tribute ladder. With [amount] above zero it is the receipt for a
/// claim just made (day [streak]); otherwise it explains the ladder.
Future<_TributeDialogChoice> _showTributeDialog(
  BuildContext context, {
  required int streak,
  required int amount,
  String? circuit,
  bool offerReminders = false,
  bool canPlayFort = false,
}) async {
  final _TributeDialogChoice? choice = await showDialog<_TributeDialogChoice>(
    context: context,
    builder: (BuildContext context) => _TributeDialog(
      streak: streak,
      amount: amount,
      circuit: circuit,
      offerReminders: offerReminders,
      canPlayFort: canPlayFort,
    ),
  );
  // Dismissed by tapping outside: no fort, and reminders as the switch
  // defaulted (on), since the player saw the offer and did not turn it off.
  return choice ?? const _TributeDialogChoice();
}

class _TributeDialog extends StatefulWidget {
  const _TributeDialog({
    required this.streak,
    required this.amount,
    required this.circuit,
    required this.offerReminders,
    required this.canPlayFort,
  });

  final int streak;
  final int amount;
  final String? circuit;
  final bool offerReminders;
  final bool canPlayFort;

  @override
  State<_TributeDialog> createState() => _TributeDialogState();
}

class _TributeDialogState extends State<_TributeDialog> {
  bool _remind = true;

  @override
  Widget build(BuildContext context) {
    final bool receipt = widget.amount > 0;
    final int streak = math.max(widget.streak, 1);
    final int tomorrow = dailyTributeAmount(streak + 1);
    return AlertDialog(
      backgroundColor: AppColors.darkSurface,
      scrollable: true,
      title: Text(
        receipt ? 'Day $streak tribute' : 'Daily tribute',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (receipt) ...<Widget>[
            Text(
              '+${formatAup(widget.amount)} AUP',
              style: const TextStyle(
                color: AppColors.red,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (widget.circuit != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Paid into your ${widget.circuit} circuit.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            const SizedBox(height: 14),
          ],
          _TributeLadder(streak: streak),
          const SizedBox(height: 14),
          Text(
            receipt
                ? 'Come back tomorrow for +${formatAup(tomorrow)} AUP. '
                    'Miss a day and the run starts again at day 1.'
                : 'A tribute every day you play, rising for seven days in a '
                    'row. Miss a day and the run starts again at day 1. '
                    'Next: +${formatAup(tomorrow)} AUP tomorrow.',
            style: const TextStyle(color: Colors.white, height: 1.35),
          ),
          if (widget.offerReminders)
            SwitchListTile.adaptive(
              key: const ValueKey<String>('tribute_remind_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Remind me when it's ready",
                style: TextStyle(color: Colors.white),
              ),
              value: _remind,
              onChanged: (bool value) => setState(() => _remind = value),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            _TributeDialogChoice(remind: _remind),
          ),
          child: Text(widget.canPlayFort ? 'Later' : 'Close'),
        ),
        if (widget.canPlayFort)
          FilledButton(
            key: const ValueKey<String>('tribute_play_fort'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(
              _TributeDialogChoice(playFort: true, remind: _remind),
            ),
            child: const Text('PLAY A FORT'),
          ),
      ],
    );
  }
}

/// Seven steps, the ones already climbed in red.
class _TributeLadder extends StatelessWidget {
  const _TributeLadder({required this.streak});

  final int streak;

  static String _short(int amount) => '${amount ~/ 1000}K';

  @override
  Widget build(BuildContext context) {
    final int climbed = math.min(streak, kDailyTributeLadder.length);
    return Row(
      children: <Widget>[
        for (int i = 0; i < kDailyTributeLadder.length; i++)
          Expanded(
            child: Column(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < climbed
                        ? AppColors.red
                        : Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: i == climbed - 1
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.2),
                      width: i == climbed - 1 ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _short(kDailyTributeLadder[i]),
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: i < climbed ? 0.9 : 0.5,
                    ),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
