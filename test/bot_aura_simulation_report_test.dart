// Bot simulation report: how bots of each Aura level actually play, with and
// without "Aura in every decision" (lib/game/bot/aura_variance.dart).
//
// Run on its own to read the report:
//   flutter test test/bot_aura_simulation_report_test.dart
// It prints a table and writes build/bot_simulation_report.md.
//
// What to look for:
//   * VPIP (share of hands played) near the preflop_range.dart targets:
//     Aura 95 ~20%, 80 ~25%, 50 ~35%, 20 ~50%, PFR below it;
//   * fold to a bet, preflop and postflop, in a human range (postflop about
//     40-50% for strong players, less for weak ones);
//   * flop c-bet: how often the preflop raiser bets the flop when checked
//     to (people: roughly 50-70%); postflop AF about 1.5-3;
//   * "Unstable": real deals whose first decision is replayed with the same
//     cards. High Aura should nearly always give the same answer; low Aura
//     should change its mind more, and more with variance on than off.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/bot/aura_variance.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

const List<int> _bands = <int>[20, 50, 80, 95];
const int _handsPerBand = 120;
const int _spotReplays = 15;

class _Stats {
  int hands = 0;
  int vpip = 0;
  int pfr = 0;
  int postflopAggressive = 0;
  int postflopCalls = 0;
  int cbetChances = 0;
  int cbets = 0;
  int facedBetPre = 0;
  int foldedToBetPre = 0;
  int facedBetPost = 0;
  int foldedToBetPost = 0;

  double get vpipRate => hands == 0 ? 0 : vpip / hands;
  double get pfrRate => hands == 0 ? 0 : pfr / hands;
  double get af => postflopCalls == 0
      ? postflopAggressive.toDouble()
      : postflopAggressive / postflopCalls;
  double get cbetRate => cbetChances == 0 ? 0 : cbets / cbetChances;
  double get foldToBetPre =>
      facedBetPre == 0 ? 0 : foldedToBetPre / facedBetPre;
  double get foldToBetPost =>
      facedBetPost == 0 ? 0 : foldedToBetPost / facedBetPost;
}

bool _aggressive(eng.ActionType a) =>
    a == eng.ActionType.bet ||
    a == eng.ActionType.raise ||
    a == eng.ActionType.allIn;

/// Six bots of one Aura play [_handsPerBand] seeded hands; stacks are reset
/// every hand so every hand is a comparable 50-big-blind spot.
_Stats _playBand(int aura) {
  final e = eng.GameEngine(
    config: eng.GameConfig(
      tableSeed: 9000 + aura,
      smallBlind: 100,
      bigBlind: 200,
      maxPlayers: 6,
    ),
  );
  e.animateStreets = false;
  for (int i = 0; i < 6; i++) {
    e.addPlayer(eng.Player(
      id: 'B$i',
      name: 'Bot $aura-$i',
      chips: 10000,
      aura: aura,
      isBot: true,
    ));
  }
  e.assignBotTraits(guaranteeWorldChampKiller: false);

  final stats = _Stats();
  for (int hand = 0; hand < _handsPerBand; hand++) {
    for (final p in e.players) {
      p.chips = 10000;
      p.isOut = false;
      p.sittingOut = false;
    }
    if (e.startNewHand(seed: 31 * aura + hand) != eng.ActionResult.ok) break;
    final voluntary = <int>{};
    final raisedPre = <int>{};
    int lastPreflopRaiser = -1;
    bool cbetCounted = false;
    int steps = 0;
    while (e.phase != eng.GamePhase.handOver &&
        e.phase != eng.GamePhase.showdown &&
        steps++ < 400) {
      final seat = e.actingIndex;
      if (seat < 0 || seat >= e.players.length) break;
      final toCall = e.toCallFor(seat);
      final preflop = e.phase == eng.GamePhase.preflop;
      final advice = e.prepareBotDecision(seat);
      final a = advice.action;
      if (preflop) {
        if (a == eng.ActionType.call || _aggressive(a)) voluntary.add(seat);
        if (_aggressive(a)) {
          raisedPre.add(seat);
          lastPreflopRaiser = seat;
        }
      } else {
        // Continuation bet: the preflop raiser's first flop action when it
        // is checked to them.
        if (!cbetCounted &&
            e.phase == eng.GamePhase.flop &&
            seat == lastPreflopRaiser &&
            toCall == 0) {
          cbetCounted = true;
          stats.cbetChances++;
          if (_aggressive(a)) stats.cbets++;
        }
        if (_aggressive(a)) stats.postflopAggressive++;
        if (a == eng.ActionType.call) stats.postflopCalls++;
      }
      if (toCall > 0 && preflop) {
        stats.facedBetPre++;
        if (a == eng.ActionType.fold) stats.foldedToBetPre++;
      } else if (toCall > 0) {
        stats.facedBetPost++;
        if (a == eng.ActionType.fold) stats.foldedToBetPost++;
      }
      e.recordBotDecision(
        seat: seat,
        action: a,
        toAmount: advice.toAmount,
        confidence: advice.confidence,
        strength: advice.strength,
      );
      if (e.act(a, amount: advice.toAmount) != eng.ActionResult.ok) {
        if (e.canCheck(seat)) {
          e.act(eng.ActionType.check);
        } else {
          e.act(eng.ActionType.fold);
        }
      }
    }
    stats.hands += 6;
    stats.vpip += voluntary.length;
    stats.pfr += raisedPre.length;
  }
  return stats;
}

const int _deals = 40;

/// One real seeded deal at a six-handed table of [aura] bots, with the
/// first player to act facing the big blind. [handNumber] is what a replay
/// changes: the same cards and table, a different moment.
eng.GameEngine _deal({
  required int aura,
  required int deal,
  required int handNumber,
}) {
  final e = eng.GameEngine(
    config: eng.GameConfig(
      tableSeed: 4242 + aura,
      smallBlind: 100,
      bigBlind: 200,
      maxPlayers: 6,
    ),
  );
  for (int i = 0; i < 6; i++) {
    e.addPlayer(eng.Player(
      id: 'S$i',
      name: 'Spot $aura-$i',
      chips: 10000,
      aura: aura,
      isBot: true,
    ));
  }
  e.assignBotTraits(guaranteeWorldChampKiller: false);
  e.startNewHand(seed: 1000 + deal);
  e.handNumber = handNumber;
  return e;
}

/// Share of deals whose first decision is not the same in every replay.
double _unstableShare(int aura) {
  int unstable = 0;
  for (int d = 0; d < _deals; d++) {
    final seen = <eng.ActionType>{};
    for (int r = 0; r < _spotReplays; r++) {
      final e = _deal(aura: aura, deal: d, handNumber: 100000 + r);
      final seat = e.actingIndex;
      if (seat < 0 || seat >= e.players.length) continue;
      seen.add(eng.BotAdvisor.suggest(e, seat).action);
    }
    if (seen.length > 1) unstable++;
  }
  return unstable / _deals;
}

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

void main() {
  test('bot simulation report by Aura band', () {
    final rows = <String>[];
    final unstable = <String, Map<int, double>>{'on': {}, 'off': {}};

    for (final mode in <String>['off', 'on']) {
      BotAuraVariance.debugDisabledForReport = mode == 'off';
      for (final aura in _bands) {
        final s = _playBand(aura);
        final u = _unstableShare(aura);
        unstable[mode]![aura] = u;
        rows.add('| $aura | $mode | ${_pct(s.vpipRate)} | ${_pct(s.pfrRate)} | '
            '${s.af.toStringAsFixed(2)} | ${_pct(s.cbetRate)} | '
            '${_pct(s.foldToBetPre)} | '
            '${_pct(s.foldToBetPost)} | ${_pct(u)} |');

        expect(s.hands, greaterThan(0));
        expect(s.vpipRate, inInclusiveRange(0.0, 1.0));
        expect(s.pfrRate, lessThanOrEqualTo(s.vpipRate));
      }
    }
    BotAuraVariance.debugDisabledForReport = false;

    final report = StringBuffer()
      ..writeln('# Bot simulation report')
      ..writeln()
      ..writeln('$_handsPerBand hands x 6 bots per Aura band. "Unstable" = '
          'share of $_deals real deals whose first decision changes across '
          '$_spotReplays replays of the same cards. "on" = Aura in every '
          'decision, "off" = without.')
      ..writeln()
      ..writeln('| Aura | Variance | VPIP | PFR | Postflop AF | Flop c-bet | '
          'Fold to bet (preflop) | Fold to bet (postflop) | Unstable |')
      ..writeln('|---|---|---|---|---|---|---|---|---|');
    rows.forEach(report.writeln);

    // ignore: avoid_print
    print(report);
    final out = File('build/bot_simulation_report.md');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(report.toString());

    // The point of the feature: variance barely touches a top bot, and makes
    // the weakest bot less predictable, never more.
    expect(
      unstable['on']![95]!,
      lessThanOrEqualTo(unstable['off']![95]! + 0.05),
    );
    expect(
      unstable['on']![20]!,
      greaterThanOrEqualTo(unstable['off']![20]! - 0.05),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
