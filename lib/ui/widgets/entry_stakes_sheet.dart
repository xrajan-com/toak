import 'package:flutter/material.dart';

import 'package:ten_of_a_kind_poker/config/blind_structure.dart';
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

/// What is at stake at a table, shown before the entry fee is taken.
class EntryStakes {
  const EntryStakes({
    required this.tableName,
    required this.isMainEvent,
    required this.seats,
    required this.startingChips,
    required this.entryFee,
    required this.payouts,
    this.circuitLabel,
    this.walletAup,
  });

  final String tableName;
  final bool isMainEvent;
  final int seats;
  final int startingChips;
  final int entryFee;

  /// AUP paid by finishing place, 1st first.
  final List<int> payouts;

  /// The circuit wallet the fee comes from, if known.
  final String? circuitLabel;
  final int? walletAup;

  bool get isFree => entryFee <= 0;
  bool get winnerTakesAll => payouts.length == 1;

  /// The one rule a player needs before paying.
  String get riskLine {
    if (isFree) {
      return 'Free entry: nothing to lose.';
    }
    return 'The entry fee is the most you can lose. Finishing outside the '
        'prizes, leaving the table, or a game that does not finish all cost '
        'the fee and nothing more.';
  }
}

/// Asks the player to confirm an entry. True means enter.
Future<bool> showEntryStakesSheet(
  BuildContext context, {
  required EntryStakes stakes,
}) async {
  final bool? enter = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: const Color(0xFF15161A),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => EntryStakesSheet(stakes: stakes),
  );
  return enter == true;
}

class EntryStakesSheet extends StatelessWidget {
  const EntryStakesSheet({super.key, required this.stakes});

  final EntryStakes stakes;

  static String _aup(int amount) => 'AUP ${aup.formatAup(amount)}';

  static String _place(int place) => switch (place) {
        1 => '1st',
        2 => '2nd',
        3 => '3rd',
        _ => '${place}th',
      };

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    final String kind = stakes.isMainEvent ? 'MAIN EVENT' : 'FORT';
    final String enterLabel = stakes.isFree
        ? 'ENTER · FREE'
        : 'ENTER · ${_aup(stakes.entryFee)}';

    final List<_StakeRow> rows = <_StakeRow>[
      _StakeRow(
        label: 'Entry',
        value: stakes.isFree ? 'Free' : _aup(stakes.entryFee),
      ),
      if (stakes.winnerTakesAll)
        _StakeRow(
          label: 'Winner takes all',
          value: _aup(stakes.payouts.single),
          highlight: true,
        )
      else
        for (int i = 0; i < stakes.payouts.length; i++)
          _StakeRow(
            label: _place(i + 1),
            value: _aup(stakes.payouts[i]),
            highlight: i == 0,
          ),
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    '$kind · ${stakes.seats} PLAYERS',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stakes.tableName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < rows.length; i++) ...<Widget>[
                            if (i > 0)
                              const Divider(height: 1, color: Colors.white10),
                            rows[i],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        stakes.isFree
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.blue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          stakes.riskLine,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${aup.formatAup(stakes.startingChips)} chips each. '
                    '${blindStructureSummary(format: aup.formatAup)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  if (!stakes.isFree &&
                      stakes.walletAup != null &&
                      stakes.circuitLabel != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      'Paid from your ${stakes.circuitLabel} wallet: '
                      '${_aup(stakes.walletAup!)}.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('Not now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.actionRed,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              enterLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _StakeRow extends StatelessWidget {
  const _StakeRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFFFFD54A) : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
