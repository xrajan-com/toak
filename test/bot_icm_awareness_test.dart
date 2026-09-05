// test/bot_icm_awareness_test.dart
//
// Coverage for the ICM/tournament-standings layer added in
// lib/game/bot/icm.dart, lib/game/bot/tournament_context.dart and
// lib/game/bot/icm_guard.dart. See docs/BOT_HUMAN_INTELLIGENCE_AURA_SPEC.md
// for the design this implements.

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/bot/icm.dart';
import 'package:ten_of_a_kind_poker/game/bot/icm_guard.dart';
import 'package:ten_of_a_kind_poker/game/bot/tournament_context.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;
import 'package:ten_of_a_kind_poker/game/models.dart' show PayoutTable;

void main() {
  group('icmEquities (pure math)', () {
    test('equities always sum to the total prize pool', () {
      const stacks = [5000, 3000, 1500, 500];
      const payouts = [5000, 3000, 2000]; // 4 alive, top 3 paid
      final equities = icmEquities(stacks, payouts);
      final sum = equities.fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(10000, 0.01));
    });

    test('equal stacks get equal equity', () {
      const stacks = [1000, 1000, 1000];
      const payouts = [500, 300, 200];
      final equities = icmEquities(stacks, payouts);
      expect(equities[0], closeTo(equities[1], 0.001));
      expect(equities[1], closeTo(equities[2], 0.001));
      expect(equities[0], closeTo((500 + 300 + 200) / 3, 0.001));
    });

    test('a bigger stack never has less equity than a smaller one', () {
      const stacks = [8000, 5000, 3000, 1000, 500];
      const payouts = [4000, 2500, 1500, 1000];
      final equities = icmEquities(stacks, payouts);
      for (int i = 0; i < stacks.length - 1; i++) {
        expect(equities[i], greaterThanOrEqualTo(equities[i + 1]),
            reason: 'stack ${stacks[i]} should be worth at least as much '
                'as stack ${stacks[i + 1]}');
      }
    });

    test('a lone remaining player is a no-op passthrough', () {
      final equities = icmEquities([777], [1000]);
      expect(equities, [1000.0]);
    });
  });

  group('TableStanding', () {
    eng.GameEngine buildFourHandedBubble() {
      final e = eng.GameEngine(
        config: eng.GameConfig(
          tableSeed: 7,
          smallBlind: 50,
          bigBlind: 100,
          maxPlayers: 10,
          payoutTable: PayoutTable.fromPercentages(10000, const [0.5, 0.3, 0.2]),
        ),
      );
      final chips = [1000, 1000, 4000, 4000];
      for (int i = 0; i < chips.length; i++) {
        e.addPlayer(eng.Player(
          id: 'P$i',
          name: 'P$i',
          chips: chips[i],
          aura: 60,
          isBot: true,
        ));
      }
      return e;
    }

    test('ranks players by chips and flags the chip leader', () {
      final e = buildFourHandedBubble();
      final standingLeader = TableStanding.compute(e, 2); // 4000 stack
      final standingShort = TableStanding.compute(e, 0); // 1000 stack
      expect(standingLeader, isNotNull);
      expect(standingLeader!.rank, 1);
      expect(standingLeader.isChipLeader, isTrue);
      expect(standingShort, isNotNull);
      expect(standingShort!.rank, greaterThan(1));
      expect(standingShort.isChipLeader, isFalse);
    });

    test('flags bubbleFactor == 1.0 when one elimination from the money', () {
      final e = buildFourHandedBubble();
      // 4 alive, top 3 paid -> exactly one bust from the first cash.
      final standing = TableStanding.compute(e, 0);
      expect(standing, isNotNull);
      expect(standing!.paidAlive, 3);
      expect(standing.bubbleFactor, closeTo(1.0, 0.001));
    });

    test('is a no-op (null) when the table has no payout table configured', () {
      final e = eng.GameEngine(
        config: const eng.GameConfig(tableSeed: 1, maxPlayers: 10),
      );
      e.addPlayer(eng.Player(
          id: 'P0', name: 'P0', chips: 1000, aura: 60, isBot: true));
      expect(TableStanding.compute(e, 0), isNull);
    });

    test('threatFor classifies the chip leader, a short stack, a crippled '
        'stack and a mid stack correctly', () {
      final e = buildFourHandedBubble(); // chips: [1000, 1000, 4000, 4000]
      // average = 2500, bigBlind = 100.
      expect(TableStanding.threatFor(e, 2), StackThreat.chipLeader);
      expect(TableStanding.threatFor(e, 3), StackThreat.chipLeader);
      // 1000 chips = 10x bigBlind exactly -> crippled threshold (<=10x).
      expect(TableStanding.threatFor(e, 0), StackThreat.crippled);
    });

    test('threatFor reports a short (but not crippled) stack correctly',
        () {
      final e = eng.GameEngine(
        config: eng.GameConfig(
          tableSeed: 9,
          smallBlind: 25,
          bigBlind: 50,
          maxPlayers: 10,
          payoutTable: PayoutTable.fromPercentages(10000, const [0.6, 0.4]),
        ),
      );
      // average = 2500, bigBlind = 50 -> 10x bigBlind = 500 (below the
      // crippled cutoff), so 900 lands in "short" territory (<=50% of avg)
      // without being crippled.
      for (final chips in [900, 900, 3100, 5100]) {
        e.addPlayer(eng.Player(
            id: 'p${e.players.length}',
            name: 'p${e.players.length}',
            chips: chips,
            aura: 60,
            isBot: true));
      }
      expect(TableStanding.threatFor(e, 0), StackThreat.shortStack);
      expect(TableStanding.threatFor(e, 3), StackThreat.chipLeader);
    });
  });

  group('BotIcmGuard.adjust', () {
    eng.GameEngine buildBubbleShoveSpot({required int heroChips}) {
      final e = eng.GameEngine(
        config: eng.GameConfig(
          tableSeed: 3,
          smallBlind: 50,
          bigBlind: 100,
          maxPlayers: 10,
          payoutTable: PayoutTable.fromPercentages(10000, const [0.5, 0.3, 0.2]),
        ),
      );
      // 4 alive: hero + villain both short (near-even stacks), two other
      // seats sit on much bigger stacks and are not part of this hand.
      // Top 3 of 4 paid -> hero is exactly one bust from the money.
      e.addPlayer(eng.Player(
          id: 'hero', name: 'hero', chips: heroChips, aura: 99, isBot: true));
      e.addPlayer(eng.Player(
          id: 'villain', name: 'villain', chips: heroChips, aura: 60, isBot: true));
      e.addPlayer(eng.Player(
          id: 'other1', name: 'other1', chips: 4000, aura: 60, isBot: true));
      e.addPlayer(eng.Player(
          id: 'other2', name: 'other2', chips: 4000, aura: 60, isBot: true));
      // other1/other2 aren't part of the current hand.
      e.players[2].folded = true;
      e.players[3].folded = true;
      e.phase = eng.GamePhase.preflop;
      e.currentBet = heroChips;
      e.pot = heroChips; // villain's shove already in the pot
      e.players[1].chips = 0;
      e.players[1].allIn = true;
      e.players[1].betThisStreet = heroChips;
      return e;
    }

    test('folds a slightly +chip-EV call when ICM says it is not worth it, '
        'for a near-zero-noise (high aura) bot', () {
      final e = buildBubbleShoveSpot(heroChips: 1000);

      // Base chip-EV logic would call here: 52% equity in an exact
      // coinflip-priced shove (needs ~50%) is a clearly +chip-EV call on
      // its own (+40 chips of raw chip-EV in this exact setup).
      const baseDecision = (
        action: eng.ActionType.call,
        toAmount: 1000,
        confidence: 0.6,
        strength: 0.52,
      );

      final adjusted = BotIcmGuard.adjust(
        eng: e,
        idx: 0,
        decision: baseDecision,
        auraSkill: 1.0, // top aura -> ~0 noise, deterministic ICM-correct play
        temperament: eng.BotTemperament.worldChamp,
        hasToCall: true,
        toCall: 1000,
      );

      expect(adjusted.action, eng.ActionType.fold,
          reason: 'even at +40 chip-EV, busting on the direct bubble '
              'against a similarly-stacked opponent while two much bigger '
              'stacks are still alive is a clearly -ICM call (~-65 in this '
              'exact setup) — a textbook fold-up-the-bubble spot that '
              'chip-EV alone would miss');
    });

    test('is a complete no-op when no payout table is configured (cash play)',
        () {
      final e = eng.GameEngine(
        config: const eng.GameConfig(tableSeed: 5, maxPlayers: 10),
      );
      e.addPlayer(eng.Player(
          id: 'hero', name: 'hero', chips: 1000, aura: 20, isBot: true));
      e.addPlayer(eng.Player(
          id: 'villain', name: 'villain', chips: 1000, aura: 60, isBot: true));
      e.phase = eng.GamePhase.preflop;
      e.currentBet = 1000;
      e.pot = 1000;
      e.players[1].chips = 0;
      e.players[1].allIn = true;
      e.players[1].betThisStreet = 1000;

      const baseDecision = (
        action: eng.ActionType.fold,
        toAmount: 0,
        confidence: 0.5,
        strength: 0.2,
      );

      final adjusted = BotIcmGuard.adjust(
        eng: e,
        idx: 0,
        decision: baseDecision,
        auraSkill: 0.1,
        temperament: eng.BotTemperament.aggressive,
        hasToCall: true,
        toCall: 1000,
      );

      expect(adjusted, baseDecision);
    });
  });
}
