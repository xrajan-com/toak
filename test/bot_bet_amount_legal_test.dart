// Every bot action must be one the engine accepts. The engine takes bets
// and raises in steps of kRaiseIncrement; when it refuses a bot's action,
// the bot loop checks or folds instead, so a refused raise silently becomes
// a fold. This plays real hands at every Aura band and fails on any refusal.
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

void main() {
  test('the engine accepts every bot action at every Aura band', () {
    final refused = <String>[];
    for (final aura in const <int>[20, 50, 80, 95]) {
      final e = eng.GameEngine(
        config: eng.GameConfig(
          tableSeed: 7100 + aura,
          smallBlind: 100,
          bigBlind: 200,
          maxPlayers: 6,
        ),
      );
      e.animateStreets = false;
      for (int i = 0; i < 6; i++) {
        e.addPlayer(eng.Player(
          id: 'L$i',
          name: 'Legal $aura-$i',
          chips: 10000,
          aura: aura,
          isBot: true,
        ));
      }
      e.assignBotTraits(guaranteeWorldChampKiller: false);

      for (int hand = 0; hand < 120; hand++) {
        for (final p in e.players) {
          p.chips = 10000;
          p.isOut = false;
          p.sittingOut = false;
        }
        if (e.startNewHand(seed: 17 * aura + hand) != eng.ActionResult.ok) {
          break;
        }
        int steps = 0;
        while (e.phase != eng.GamePhase.handOver &&
            e.phase != eng.GamePhase.showdown &&
            steps++ < 400) {
          final seat = e.actingIndex;
          if (seat < 0 || seat >= e.players.length) break;
          final advice = e.prepareBotDecision(seat);
          e.recordBotDecision(
            seat: seat,
            action: advice.action,
            toAmount: advice.toAmount,
            confidence: advice.confidence,
            strength: advice.strength,
          );
          final result = e.act(advice.action, amount: advice.toAmount);
          if (result != eng.ActionResult.ok) {
            refused.add('Aura $aura, hand $hand, seat $seat, '
                '${e.phase.name}: ${advice.action.name} to '
                '${advice.toAmount} -> ${result.name}');
            if (e.canCheck(seat)) {
              e.act(eng.ActionType.check);
            } else {
              e.act(eng.ActionType.fold);
            }
          }
        }
      }
    }
    expect(
      refused,
      isEmpty,
      reason: '${refused.length} refused, first ones:\n'
          '${refused.take(12).join('\n')}',
    );
  });
}
