import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

eng.GameEngine _botTable() {
  final eng.GameEngine engine = eng.GameEngine(
    config: const eng.GameConfig(
      tableSeed: 912,
      smallBlind: 50,
      bigBlind: 100,
      maxPlayers: 3,
    ),
  )..animateStreets = false;
  for (int i = 0; i < 3; i++) {
    engine.addPlayer(eng.Player(
      id: 'bot-$i',
      name: 'Bot $i',
      chips: 5000,
      aura: 70 + i,
      isBot: true,
    ));
  }
  expect(engine.startNewHand(seed: 8841), eng.ActionResult.ok);
  return engine;
}

List<Object?> _stateDigest(eng.GameEngine engine) => <Object?>[
      engine.phase,
      engine.handNumber,
      engine.dealerIndex,
      engine.actingIndex,
      engine.currentBet,
      engine.pot,
      for (final eng.Player player in engine.players) ...<Object?>[
        player.chips,
        player.betThisStreet,
        player.contributedThisHand,
        player.folded,
        player.allIn,
      ],
      for (final eng.Card card in engine.community) ...<Object?>[
        card.rank,
        card.suit,
      ],
    ];

void main() {
  test('presentation lookups reuse one bot decision and consume RNG once', () {
    final eng.GameEngine withRepeatedUiReads = _botTable();
    final eng.GameEngine withOneUiRead = _botTable();
    final int actor = withRepeatedUiReads.actingIndex;
    expect(withOneUiRead.actingIndex, actor);

    final first = withRepeatedUiReads.prepareBotDecision(actor);
    for (int i = 0; i < 8; i++) {
      expect(withRepeatedUiReads.prepareBotDecision(actor), first);
    }
    final control = withOneUiRead.prepareBotDecision(actor);
    expect(control, first);

    withRepeatedUiReads.tickBots(maxSteps: 1);
    withOneUiRead.tickBots(maxSteps: 1);

    expect(
      _stateDigest(withRepeatedUiReads),
      _stateDigest(withOneUiRead),
    );
    expect(
      withRepeatedUiReads.handRng.copy().nextUint32(),
      withOneUiRead.handRng.copy().nextUint32(),
      reason: 'UI rebuilds must not advance gameplay RNG',
    );

    if (withRepeatedUiReads.phase != eng.GamePhase.handOver &&
        withRepeatedUiReads.phase != eng.GamePhase.showdown) {
      final int nextActor = withRepeatedUiReads.actingIndex;
      expect(
        withRepeatedUiReads.prepareBotDecision(nextActor),
        withOneUiRead.prepareBotDecision(nextActor),
      );
    }
  });
}
