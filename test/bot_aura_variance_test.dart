import 'dart:math' show sqrt;

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/bot/aura_variance.dart';

void main() {
  test('read error shrinks steeply with Aura and vanishes at the top', () {
    expect(BotAuraVariance.sigmaFor(1.0), 0.0);
    expect(BotAuraVariance.sigmaFor(0.95), lessThan(0.003));
    expect(BotAuraVariance.sigmaFor(0.50), closeTo(0.038, 0.002));
    expect(BotAuraVariance.sigmaFor(0.20), closeTo(0.073, 0.002));
    expect(BotAuraVariance.sigmaFor(0.0), BotAuraVariance.sigmaMax);
    for (var a = 0.0; a < 1.0; a += 0.05) {
      expect(
        BotAuraVariance.sigmaFor(a),
        greaterThan(BotAuraVariance.sigmaFor(a + 0.05)),
      );
    }
  });

  test('read error is zero-mean with the advertised spread', () {
    const aura = 0.3;
    const n = 20000;
    double sum = 0, sumSq = 0;
    for (var i = 0; i < n; i++) {
      final e = BotAuraVariance.readError(
        auraSkill: aura,
        handKey: 'hand$i',
        decisionKey: 'decision$i',
      );
      sum += e;
      sumSq += e * e;
    }
    final mean = sum / n;
    final sd = sqrt(sumSq / n - mean * mean);
    final sigma = BotAuraVariance.sigmaFor(aura);
    expect(mean.abs(), lessThan(sigma * 0.05));
    expect(sd, closeTo(sigma, sigma * 0.05));
  });

  test('part of a misread lasts the whole hand', () {
    // Two decisions in one hand share zHand, so their errors correlate by
    // about handShare; decisions in different hands do not.
    const n = 20000;
    double same = 0, other = 0, sq = 0;
    for (var i = 0; i < n; i++) {
      double e(String hand, String decision) => BotAuraVariance.readError(
            auraSkill: 0.0,
            handKey: hand,
            decisionKey: decision,
          );
      final a = e('h$i', 'flop$i');
      final b = e('h$i', 'river$i');
      final c = e('x$i', 'river$i');
      same += a * b;
      other += a * c;
      sq += a * a;
    }
    expect(same / sq, closeTo(BotAuraVariance.handShare, 0.04));
    expect((other / sq).abs(), lessThan(0.04));
  });

  test('the same spot always gets the same read', () {
    double read() => BotAuraVariance.readError(
          auraSkill: 0.25,
          handKey: 'table|7|seat2',
          decisionKey: 'table|7|river|400|2600|seat2',
        );
    expect(read(), read());
  });

  test('the report switch turns it off', () {
    BotAuraVariance.debugDisabledForReport = true;
    addTearDown(() => BotAuraVariance.debugDisabledForReport = false);
    expect(
      BotAuraVariance.readError(
        auraSkill: 0.0,
        handKey: 'a',
        decisionKey: 'b',
      ),
      0.0,
    );
  });
}
