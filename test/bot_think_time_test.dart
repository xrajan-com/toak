// test/bot_think_time_test.dart
//
// The design claims behind bot think time, pinned as tests. See
// docs/BOT_HUMAN_INTELLIGENCE_AURA_SPEC.md and lib/game/bot/think_time.dart.
//
// The claims, in plain terms:
//   1. Aura does not make a bot uniformly faster. It widens the gap between
//      easy and hard, because a strong player snaps the obvious and tanks
//      the genuinely close ones — they can see that it is close.
//   2. How much think time leaks about hand strength scales inversely with
//      aura, so a weak bot's tank is a readable tell and a pro's is not.
//   3. Mood shows up in tempo: greed is impulsive, fear stalls.

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/bot/think_time.dart';

double _factor(double difficulty, double aura,
        {double strength = 0.5, double mood = 0.0}) =>
    BotThinkTime.delayFactor(
      difficulty: difficulty,
      auraSkill: aura,
      strength: strength,
      fearGreedSigned: mood,
    );

void main() {
  group('decision difficulty', () {
    test('a decision far from the required equity is trivial', () {
      final d = BotThinkTime.difficultyFor(
        hasToCall: true,
        winProb: 0.85,
        requiredEquity: 0.30,
        stackFrac: 0.2,
        facingAllIn: false,
      );
      expect(d, lessThan(0.05));
    });

    test('a decision sitting on the required equity is agonising', () {
      final d = BotThinkTime.difficultyFor(
        hasToCall: true,
        winProb: 0.50,
        requiredEquity: 0.50,
        stackFrac: 1.0,
        facingAllIn: true,
      );
      expect(d, greaterThan(0.9));
    });

    test('being a fold and being a call are equally hard when equally close',
        () {
      // Difficulty is about closeness, not direction — a marginal fold is
      // just as hard as a marginal call.
      final justCall = BotThinkTime.difficultyFor(
        hasToCall: true,
        winProb: 0.52,
        requiredEquity: 0.50,
        stackFrac: 0.5,
        facingAllIn: false,
      );
      final justFold = BotThinkTime.difficultyFor(
        hasToCall: true,
        winProb: 0.48,
        requiredEquity: 0.50,
        stackFrac: 0.5,
        facingAllIn: false,
      );
      expect(justCall, closeTo(justFold, 1e-9));
    });

    test('a free check is trivial even holding nothing', () {
      final d = BotThinkTime.difficultyFor(
        hasToCall: false,
        winProb: 0.50,
        requiredEquity: 0.50,
        stackFrac: 0.0,
        facingAllIn: false,
      );
      expect(d, lessThan(0.4),
          reason: 'checking back for free should never be a tank');
    });

    test('the same close spot is harder when the stack is on the line', () {
      double at(double stackFrac) => BotThinkTime.difficultyFor(
            hasToCall: true,
            winProb: 0.50,
            requiredEquity: 0.50,
            stackFrac: stackFrac,
            facingAllIn: false,
          );
      expect(at(1.0), greaterThan(at(0.1)));
    });
  });

  group('aura calibrates time to difficulty (it is not a speed dial)', () {
    test('a pro snaps the obvious and tanks the close one', () {
      final easy = _factor(0.0, 0.95);
      final hard = _factor(1.0, 0.95);
      expect(hard / easy, greaterThan(3.5),
          reason: 'a strong player should have a wide tempo range');
    });

    test("a weak bot's timing is comparatively flat", () {
      final easy = _factor(0.0, 0.15);
      final hard = _factor(1.0, 0.15);
      expect(hard / easy, lessThan(2.2),
          reason: 'a weak player barely distinguishes easy from hard');
      expect(hard / easy, greaterThan(1.0));
    });

    test('on a genuinely close decision the pro is the slower of the two',
        () {
      // The counter-intuitive half of the model, and the reason aura is not
      // simply a speed dial: expertise means seeing that a spot is close.
      expect(_factor(1.0, 0.95), greaterThan(_factor(1.0, 0.15)));
    });

    test('on a trivial decision the pro is the faster of the two', () {
      expect(_factor(0.0, 0.95), lessThan(_factor(0.0, 0.15)));
    });
  });

  group('timing leakage scales inversely with aura', () {
    test("a low-aura bot's tank genuinely means it is weak", () {
      final junk = _factor(0.5, 0.15, strength: 0.05);
      final nuts = _factor(0.5, 0.15, strength: 0.95);
      expect(junk / nuts, greaterThan(1.25),
          reason: 'a weak bot should be readable from its clock');
    });

    test("a pro's clock says nothing about their holding", () {
      final junk = _factor(0.5, 0.98, strength: 0.05);
      final nuts = _factor(0.5, 0.98, strength: 0.95);
      expect(junk / nuts, closeTo(1.0, 0.03),
          reason: 'balanced timing is what makes a strong player unreadable');
    });

    test('leakage falls monotonically as aura rises', () {
      double tell(double aura) =>
          _factor(0.5, aura, strength: 0.05) /
          _factor(0.5, aura, strength: 0.95);
      expect(tell(0.0), greaterThan(tell(0.5)));
      expect(tell(0.5), greaterThan(tell(1.0)));
    });
  });

  group('mood shows up in tempo', () {
    test('greed is impulsive, fear stalls', () {
      final steaming = _factor(0.5, 0.6, mood: 1.0);
      final steady = _factor(0.5, 0.6, mood: 0.0);
      final rattled = _factor(0.5, 0.6, mood: -1.0);
      expect(steaming, lessThan(steady));
      expect(rattled, greaterThan(steady));
      expect(rattled / steaming, greaterThan(1.3));
    });
  });

  group('floors', () {
    test('a trivial decision may snap, a hard one keeps the full floor', () {
      expect(
        BotThinkTime.floorMsFor(
            difficulty: 0.0, trivialFloorMs: 800, normalFloorMs: 1400),
        800,
      );
      expect(
        BotThinkTime.floorMsFor(
            difficulty: 1.0, trivialFloorMs: 800, normalFloorMs: 1400),
        1400,
      );
    });

    test('jitter is steadier for composed bots', () {
      expect(BotThinkTime.jitterScaleForAura(1.0),
          lessThan(BotThinkTime.jitterScaleForAura(0.0)));
    });

    test('the factor never collapses to zero or goes negative', () {
      for (final d in <double>[0.0, 0.5, 1.0]) {
        for (final a in <double>[0.0, 0.5, 1.0]) {
          for (final m in <double>[-1.0, 1.0]) {
            expect(_factor(d, a, strength: 1.0, mood: m), greaterThan(0.0));
          }
        }
      }
    });
  });
}
