import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/blind_structure.dart';
import 'package:ten_of_a_kind_poker/game/events.dart' as events;
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

eng.GameEngine _engine({
  required List<int> stacks,
  required List<eng.BlindLevel> levels,
  int orbitsPerLevel = 2,
}) {
  final eng.GameEngine engine = eng.GameEngine(
    config: eng.GameConfig(
      tableSeed: 71,
      smallBlind: levels.first.smallBlind,
      bigBlind: levels.first.bigBlind,
      maxPlayers: stacks.length,
      blindSchedule: eng.BlindSchedule(
        levels: levels,
        orbitsPerLevel: orbitsPerLevel,
      ),
    ),
  );
  engine.animateStreets = false;
  for (int index = 0; index < stacks.length; index++) {
    engine.addPlayer(
      eng.Player(id: 'P$index', name: 'P$index', chips: stacks[index]),
    );
  }
  return engine;
}

void main() {
  group('the tournament structure', () {
    test('keeps rising, smoothly, until no table can still be deep', () {
      expect(kTournamentBlindLevels, hasLength(20));
      expect(kTournamentBlindSchedule.orbitsPerLevel, kOrbitsPerBlindLevel);
      for (int i = 0; i < kTournamentBlindLevels.length; i++) {
        final eng.BlindLevel level = kTournamentBlindLevels[i];
        expect(level.smallBlind * 2, level.bigBlind, reason: 'level ${i + 1}');
        if (i == 0) continue;
        final double step =
            level.bigBlind / kTournamentBlindLevels[i - 1].bigBlind;
        expect(step, inInclusiveRange(1.15, 1.55), reason: 'level ${i + 1}');
      }
      // A ten-seat title match puts 100,000 chips in play: by the last level
      // that is a few big blinds, so no game can stall.
      expect(100000 / kTournamentBlindLevels.last.bigBlind, lessThan(4));
    });

    test('has antes of about an eighth of the big blind from level 4', () {
      for (int i = 0; i < kTournamentBlindLevels.length; i++) {
        final eng.BlindLevel level = kTournamentBlindLevels[i];
        if (i + 1 < kFirstAnteLevel) {
          expect(level.ante, 0, reason: 'level ${i + 1}');
          continue;
        }
        expect(level.ante / level.bigBlind, inInclusiveRange(0.10, 0.14),
            reason: 'level ${i + 1}');
      }
    });

    test('reads as players expect', () {
      expect(blindLevelLabel(smallBlind: 300, bigBlind: 600, ante: 75),
          '300/600 · ante 75');
      expect(blindLevelLabel(smallBlind: 100, bigBlind: 200), '100/200');
      expect(blindStructureSummary(),
          'Blinds start at 100/200 and rise every 2 orbits. Antes from level 4.');
    });
  });

  group('antes in the engine', () {
    test('are dead money: in the pot, never towards calling the big blind',
        () {
      final eng.GameEngine engine = _engine(
        stacks: <int>[1000, 1000, 1000, 1000],
        levels: const <eng.BlindLevel>[
          eng.BlindLevel(smallBlind: 50, bigBlind: 100, ante: 10),
        ],
      );

      expect(engine.startNewHand(seed: 1), eng.ActionResult.ok);

      expect(engine.ante, 10);
      expect(engine.dealerIndex, 0);
      expect(engine.pot, 50 + 100 + 4 * 10);
      expect(engine.players[1].betThisStreet, 50);
      expect(engine.players[2].betThisStreet, 100);
      expect(engine.players[3].betThisStreet, 0);
      expect(engine.toCallFor(3), 100);
      expect(engine.players[3].contributedThisHand, 10);
      expect(engine.players[2].contributedThisHand, 110);
      expect(engine.players[3].chips, 990);

      final List<events.AntesPosted> antes =
          engine.eventLog.whereType<events.AntesPosted>().toList();
      expect(antes, hasLength(1));
      expect(antes.single.ante, 10);
      expect(antes.single.total, 40);
    });

    test('a stack shorter than the ante goes all in and is still dealt in', () {
      final eng.GameEngine engine = _engine(
        stacks: <int>[1000, 1000, 1000, 6],
        levels: const <eng.BlindLevel>[
          eng.BlindLevel(smallBlind: 50, bigBlind: 100, ante: 10),
        ],
      );

      expect(engine.startNewHand(seed: 2), eng.ActionResult.ok);

      expect(engine.players[3].chips, 0);
      expect(engine.players[3].allIn, isTrue);
      expect(engine.players[3].contributedThisHand, 6);
      expect(engine.players[3].hole, hasLength(2));
      expect(engine.pot, 50 + 100 + 3 * 10 + 6);
    });

    test('blind positions never shift for a stack that only covers its blind',
        () {
      final eng.GameEngine engine = _engine(
        stacks: <int>[1000, 50, 1000, 1000],
        levels: const <eng.BlindLevel>[
          eng.BlindLevel(smallBlind: 50, bigBlind: 100, ante: 10),
        ],
      );

      expect(engine.startNewHand(seed: 3), eng.ActionResult.ok);

      expect(engine.dealerIndex, 0);
      expect(engine.smallBlindIndex, 1);
      expect(engine.bigBlindIndex, 2);
      expect(engine.players[1].betThisStreet, 50);
      expect(engine.players[1].allIn, isTrue);
      expect(engine.pot, 50 + 100 + 3 * 10);
    });

    test('arrive with the level, and the level is announced', () {
      final eng.GameEngine engine = _engine(
        stacks: <int>[100000, 100000, 100000],
        orbitsPerLevel: 1,
        levels: const <eng.BlindLevel>[
          eng.BlindLevel(smallBlind: 100, bigBlind: 200),
          eng.BlindLevel(smallBlind: 200, bigBlind: 400, ante: 50),
        ],
      );

      // One orbit: the button visits seats 0, 1 and 2.
      for (int hand = 1; hand <= 3; hand++) {
        expect(engine.startNewHand(seed: hand), eng.ActionResult.ok);
        expect(engine.bigBlind, 200);
        expect(engine.ante, 0);
      }
      expect(engine.eventLog.whereType<events.AntesPosted>(), isEmpty);

      // The button wraps: level 2, with its ante, from this hand.
      expect(engine.startNewHand(seed: 4), eng.ActionResult.ok);
      expect(engine.bigBlind, 400);
      expect(engine.ante, 50);
      expect(engine.pot, 200 + 400 + 3 * 50);

      final events.BlindLevelChanged change =
          engine.eventLog.whereType<events.BlindLevelChanged>().single;
      expect(change.levelIndex, 1);
      expect(change.previousAnte, 0);
      expect(change.ante, 50);
      expect(change.bigBlind, 400);

      // The last level holds.
      for (int hand = 5; hand <= 12; hand++) {
        engine.startNewHand(seed: hand);
      }
      expect(engine.bigBlind, 400);
      expect(engine.ante, 50);
    });
  });
}
