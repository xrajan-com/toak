// The blind structure every X Poker table plays: forts, title matches and
// Quick Game.
//
// It follows the shape of an online turbo sit-and-go, the standard format
// for a single-table tournament played on a phone: blinds rise every orbit
// of the dealer button, by roughly a quarter to a third each level, and from
// level 4 every player also pays an ante of about 12.5% of the big blind.
// Stacks start at 50 big blinds, so the early levels still reward patient,
// skilful play; the rising blinds make a six-seat fort a game of minutes,
// not an hour. (Until build 92 blinds rose every two orbits.) Twenty levels take the big blind from 200 to 30,000, well
// past the point where the chips in play run out (a ten-seat title match
// has 100,000), so the pressure keeps rising until someone wins.
//
// An orbit ends when the button passes every player still in, so levels
// come round faster in hands as the table shrinks.
import 'package:ten_of_a_kind_poker/game/models.dart'
    show BlindLevel, BlindSchedule;

/// Completed dealer orbits per level.
const int kOrbitsPerBlindLevel = 1;

/// The first level with an ante, counting from 1.
const int kFirstAnteLevel = 4;

const List<BlindLevel> kTournamentBlindLevels = <BlindLevel>[
  BlindLevel(smallBlind: 100, bigBlind: 200),
  BlindLevel(smallBlind: 150, bigBlind: 300),
  BlindLevel(smallBlind: 200, bigBlind: 400),
  BlindLevel(smallBlind: 300, bigBlind: 600, ante: 75),
  BlindLevel(smallBlind: 400, bigBlind: 800, ante: 100),
  BlindLevel(smallBlind: 500, bigBlind: 1000, ante: 125),
  BlindLevel(smallBlind: 600, bigBlind: 1200, ante: 150),
  BlindLevel(smallBlind: 800, bigBlind: 1600, ante: 200),
  BlindLevel(smallBlind: 1000, bigBlind: 2000, ante: 250),
  BlindLevel(smallBlind: 1250, bigBlind: 2500, ante: 300),
  BlindLevel(smallBlind: 1500, bigBlind: 3000, ante: 400),
  BlindLevel(smallBlind: 2000, bigBlind: 4000, ante: 500),
  BlindLevel(smallBlind: 2500, bigBlind: 5000, ante: 600),
  BlindLevel(smallBlind: 3000, bigBlind: 6000, ante: 750),
  BlindLevel(smallBlind: 4000, bigBlind: 8000, ante: 1000),
  BlindLevel(smallBlind: 5000, bigBlind: 10000, ante: 1250),
  BlindLevel(smallBlind: 6000, bigBlind: 12000, ante: 1500),
  BlindLevel(smallBlind: 8000, bigBlind: 16000, ante: 2000),
  BlindLevel(smallBlind: 10000, bigBlind: 20000, ante: 2500),
  BlindLevel(smallBlind: 15000, bigBlind: 30000, ante: 4000),
];

const BlindSchedule kTournamentBlindSchedule = BlindSchedule(
  levels: kTournamentBlindLevels,
  orbitsPerLevel: kOrbitsPerBlindLevel,
);

/// "300/600", or "300/600 · ante 75" when the level has one.
String blindLevelLabel({
  required int smallBlind,
  required int bigBlind,
  int ante = 0,
  String Function(int amount)? format,
}) {
  final String Function(int) f = format ?? ((int amount) => '$amount');
  final String blinds = '${f(smallBlind)}/${f(bigBlind)}';
  return ante > 0 ? '$blinds · ante ${f(ante)}' : blinds;
}

/// One line for the entry sheet: how the blinds behave over a game.
String blindStructureSummary({String Function(int amount)? format}) {
  final BlindLevel first = kTournamentBlindLevels.first;
  final String start = blindLevelLabel(
    smallBlind: first.smallBlind,
    bigBlind: first.bigBlind,
    format: format,
  );
  final String every = kOrbitsPerBlindLevel == 1
      ? 'every orbit'
      : 'every $kOrbitsPerBlindLevel orbits';
  return 'Blinds start at $start and rise $every. '
      'Antes from level $kFirstAnteLevel.';
}
