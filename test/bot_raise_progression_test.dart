import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

void main() {
  test(
      'bot can only make one aggressive raise per street and regains it after a board reveal',
      () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 91,
        smallBlind: 50,
        bigBlind: 100,
        maxPlayers: 3,
      ),
    );
    e.animateStreets = false;

    for (int i = 0; i < 3; i++) {
      e.addPlayer(eng.Player(
        id: 'P$i',
        name: 'P$i',
        chips: 5000,
        aura: 70,
        isBot: true,
      ));
    }

    expect(e.startNewHand(seed: 1234), eng.ActionResult.ok);
    expect(e.phase, eng.GamePhase.preflop);

    final int opener = e.actingIndex;
    final int caller = (opener + 1) % e.players.length;

    expect(e.act(eng.ActionType.raise, amount: 300), eng.ActionResult.ok);
    expect(e.act(eng.ActionType.call), eng.ActionResult.ok);
    expect(e.act(eng.ActionType.raise, amount: 500), eng.ActionResult.ok);

    final legalFacingReraise = e.legalActionsFor(opener);
    expect(legalFacingReraise, contains(eng.ActionType.call));
    expect(legalFacingReraise, contains(eng.ActionType.fold));
    expect(legalFacingReraise, isNot(contains(eng.ActionType.bet)));
    expect(legalFacingReraise, isNot(contains(eng.ActionType.raise)));
    expect(legalFacingReraise, isNot(contains(eng.ActionType.allIn)));

    expect(e.act(eng.ActionType.call), eng.ActionResult.ok);
    expect(e.actingIndex, caller);
    expect(e.act(eng.ActionType.call), eng.ActionResult.ok);

    expect(e.phase, eng.GamePhase.flop);
    expect(e.community.length, 3);

    final legalOnFlop = e.legalActionsFor(opener);
    expect(legalOnFlop, contains(eng.ActionType.bet));
    expect(legalOnFlop, isNot(contains(eng.ActionType.raise)));
  });
}
