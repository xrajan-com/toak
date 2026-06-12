import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/bot/policy_model.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

void main() {
  test('exports bot decision log rows with ML fields', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 7,
        smallBlind: 100,
        bigBlind: 200,
        maxPlayers: 2,
      ),
    );

    for (int i = 0; i < 2; i++) {
      e.addPlayer(eng.Player(
        id: 'P$i',
        name: 'P$i',
        chips: 6000,
        aura: 70 + i * 10,
        isBot: true,
      ));
    }

    e.startNewHand(seed: 19);
    final advice = eng.BotAdvisor.suggest(e, e.actingIndex);
    e.recordBotDecision(
      seat: e.actingIndex,
      action: advice.action,
      toAmount: advice.toAmount,
      confidence: advice.confidence,
      strength: advice.strength,
    );

    final rows = jsonDecode(e.exportBotDecisionLogJson()) as List<dynamic>;
    expect(rows, isNotEmpty);
    final row = rows.first as Map<String, dynamic>;
    expect(row['aura'], isA<int>());
    expect(row['fieldFoldRate'], isA<num>());
    expect(row['fieldAggression'], isA<num>());
    expect(row['liveOpponents'], isA<int>());
    expect(row['action'], isA<String>());
  });

  test('learned policy weights round-trip', () {
    const original = BotLearnedPolicyWeights(
      version: 1,
      intercept: BotPolicyAdjustment(
        callBias: 0.1,
        raiseBias: -0.05,
        bluffBias: 0.02,
        valueBias: 0.03,
        sizeFactor: 1.04,
      ),
      featureWeights: {
        'style_aggression': BotPolicyAdjustment(
          callBias: 0.02,
          raiseBias: 0.08,
          bluffBias: 0.03,
          valueBias: 0.01,
          sizeFactor: 1.02,
        ),
      },
    );

    final decoded = BotLearnedPolicyWeights.fromJson(
      Map<String, Object?>.from(original.toJson()),
    );

    final adjustment = decoded.evaluate(const {
      'style_aggression': 1.0,
    });

    expect(decoded.version, 1);
    expect(adjustment.raiseBias, greaterThan(0.0));
    expect(adjustment.sizeFactor, greaterThan(1.0));
  });
}
