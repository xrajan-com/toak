// How long is a game? Bot-only tournaments under the live blind structure,
// from the first hand until one player holds every chip, beside the
// structure and pace before build 92 (blinds every two orbits, slower
// ceremony) for comparison. Prints hands per game and an estimate of
// minutes at the table's pace, and guards the target: a six-seat fort plays
// like an online turbo sit-and-go, about a quarter of an hour, not an hour.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/blind_structure.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/pacing.dart'
    as pace;

const int _gamesPerSize = 6;

class _Game {
  _Game(this.hands, this.actions);

  final int hands;
  final int actions;
}

_Game _playTournament({
  required int seats,
  required int orbitsPerLevel,
  required int seed,
}) {
  final e = eng.GameEngine(
    config: eng.GameConfig(
      tableSeed: seed,
      smallBlind: kTournamentBlindLevels.first.smallBlind,
      bigBlind: kTournamentBlindLevels.first.bigBlind,
      maxPlayers: seats,
      blindSchedule: eng.BlindSchedule(
        levels: kTournamentBlindLevels,
        orbitsPerLevel: orbitsPerLevel,
      ),
    ),
  );
  e.animateStreets = false;
  for (int i = 0; i < seats; i++) {
    e.addPlayer(eng.Player(
      id: 'B$i',
      name: 'Bot $i',
      chips: 10000,
      aura: 35 + (i * 11) % 60,
      isBot: true,
    ));
  }
  e.assignBotTraits(guaranteeWorldChampKiller: false);

  int hands = 0;
  int actions = 0;
  while (hands < 2000 &&
      e.startNewHand(seed: seed * 7919 + hands) == eng.ActionResult.ok) {
    hands++;
    int steps = 0;
    while (e.phase != eng.GamePhase.handOver &&
        e.phase != eng.GamePhase.showdown &&
        steps++ < 400) {
      final int seat = e.actingIndex;
      if (seat < 0 || seat >= e.players.length) break;
      final advice = e.prepareBotDecision(seat);
      e.recordBotDecision(
        seat: seat,
        action: advice.action,
        toAmount: advice.toAmount,
        confidence: advice.confidence,
        strength: advice.strength,
      );
      if (e.act(advice.action, amount: advice.toAmount) !=
          eng.ActionResult.ok) {
        if (e.canCheck(seat)) {
          e.act(eng.ActionType.check);
        } else {
          e.act(eng.ActionType.fold);
        }
      }
      actions++;
    }
  }
  return _Game(hands, actions);
}

/// The table's tempo, in milliseconds: the ceremony around every hand
/// (shuffle, deal, winner banner) and the average turn (a bot's think time
/// plus the pause after it acts). An estimate: bots snap easy folds and
/// tank close spots around these averages.
class _Pace {
  const _Pace({required this.perHandMs, required this.perActionMs});

  final int perHandMs;
  final int perActionMs;

  double minutes(_Game game) =>
      (game.hands * perHandMs + game.actions * perActionMs) / 60000;
}

int _dealMs(int seats) =>
    seats * 2 * pace.kDealGapMs + pace.kDealCardFlightMs;

_Pace _livePace(int seats) => _Pace(
      perHandMs: pace.kShuffleMs +
          _dealMs(seats) +
          pace.kShowdownSettlePauseMs +
          pace.kOverlayMinShowMs,
      perActionMs: (pace.kBotTempoMinMs + pace.kBotTempoMaxMs) ~/ 2 +
          pace.kPostActionPauseMs,
    );

// The values before build 92, for the comparison column.
_Pace _oldPace(int seats) => _Pace(
      perHandMs: 60 * 12 * 6 + _dealMs(seats) + 900 + 3800,
      perActionMs: (1500 + 2600) ~/ 2 + 850,
    );

T _median<T extends num>(List<T> values) {
  final List<T> sorted = List<T>.of(values)..sort();
  return sorted[sorted.length ~/ 2];
}

void main() {
  test('a fort is a turbo sit-and-go, not an hour', () {
    final StringBuffer report = StringBuffer()
      ..writeln('# Tournament length')
      ..writeln()
      ..writeln('$_gamesPerSize bot-only games per table size, 10,000 chips '
          '(50 big blinds) each. Minutes are an estimate at the table pace.')
      ..writeln()
      ..writeln('| Seats | Hands before | Hands now | Minutes before '
          '| Minutes now |')
      ..writeln('|---|---|---|---|---|');

    final Map<int, double> minutesNow = <int, double>{};
    for (final int seats in <int>[6, 8, 10]) {
      final List<int> handsBefore = <int>[];
      final List<int> handsNow = <int>[];
      final List<double> minsBefore = <double>[];
      final List<double> minsNow = <double>[];
      for (int g = 0; g < _gamesPerSize; g++) {
        final int seed = 400 + seats * 31 + g;
        final _Game before =
            _playTournament(seats: seats, orbitsPerLevel: 2, seed: seed);
        final _Game now = _playTournament(
          seats: seats,
          orbitsPerLevel: kOrbitsPerBlindLevel,
          seed: seed,
        );
        handsBefore.add(before.hands);
        handsNow.add(now.hands);
        minsBefore.add(_oldPace(seats).minutes(before));
        minsNow.add(_livePace(seats).minutes(now));
      }
      minutesNow[seats] = _median(minsNow);
      report.writeln('| $seats | ${_median(handsBefore)} '
          '| ${_median(handsNow)} '
          '| ${_median(minsBefore).toStringAsFixed(0)} '
          '| ${_median(minsNow).toStringAsFixed(0)} |');
      expect(_median(handsNow), lessThan(_median(handsBefore)),
          reason: '$seats seats: the live structure must be the quicker one');
    }
    stdout.writeln(report);

    expect(minutesNow[6], lessThanOrEqualTo(25),
        reason: 'a six-seat fort should take about a quarter of an hour');
  });
}
