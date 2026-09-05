// test/bot_fear_greed_test.dart
//
// Coverage for the fear/greed axis added to BotStyleState — the single
// directional risk dial that replaced the four correlated ones. See
// docs/BOT_HUMAN_INTELLIGENCE_AURA_SPEC.md.
//
// The design claim under test: aura governs how violently and how durably
// a bot's mood moves, so two bots given identical results end a session in
// very different emotional places.

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/bot/memory.dart';

void main() {
  group('fearGreed axis', () {
    test('starts neutral and maps onto a signed -1..1 axis', () {
      final s = BotStyleState();
      expect(s.fearGreed, 0.5);
      expect(s.fearGreedSigned, closeTo(0.0, 1e-9));

      s.fearGreed = 1.0;
      expect(s.fearGreedSigned, closeTo(1.0, 1e-9));
      s.fearGreed = 0.0;
      expect(s.fearGreedSigned, closeTo(-1.0, 1e-9));
    });

    test('a low-aura bot swings harder than a pro on the identical event',
        () {
      final loose = BotStyleState();
      final pro = BotStyleState();
      loose.applyFearGreed(0.10, 0.0);
      pro.applyFearGreed(0.10, 1.0);

      expect(loose.fearGreed, closeTo(0.66, 1e-9)); // 0.5 + 0.10 * 1.60
      expect(pro.fearGreed, closeTo(0.54, 1e-9)); // 0.5 + 0.10 * 0.40
      expect(loose.fearGreed - 0.5,
          greaterThan((pro.fearGreed - 0.5) * 2.5),
          reason: 'emotional volatility must be a real function of aura');
    });

    test('a pro returns to neutral faster than a low-aura bot', () {
      final loose = BotStyleState(fearGreed: 0.9);
      final pro = BotStyleState(fearGreed: 0.9);
      loose.decayTowardNeutral(0.06, 0.0);
      pro.decayTowardNeutral(0.06, 1.0);

      expect(loose.fearGreed, closeTo(0.892, 1e-9)); // rate 0.020
      expect(pro.fearGreed, closeTo(0.872, 1e-9)); // rate 0.070
      expect(pro.fearGreed, lessThan(loose.fearGreed),
          reason: 'emotional control means shaking it off sooner');
    });

    test('tilt persists across a realistic run of hands for a low-aura bot',
        () {
      // One big loss, then twenty quiet hands. The pro is basically over
      // it; the low-aura bot is still visibly rattled, which is the whole
      // point of the slower decay.
      final loose = BotStyleState();
      final pro = BotStyleState();
      loose.applyFearGreed(-0.22, 0.10);
      pro.applyFearGreed(-0.22, 0.95);
      for (int hand = 0; hand < 20; hand++) {
        loose.decayTowardNeutral(0.06, 0.10);
        pro.decayTowardNeutral(0.06, 0.95);
      }

      expect(0.5 - loose.fearGreed, greaterThan(0.10),
          reason: 'a low-aura bot should still be carrying the beat');
      expect(0.5 - pro.fearGreed, lessThan(0.04),
          reason: 'a disciplined bot should be near neutral again');
    });

    test('legacy dials keep their aura-independent decay (no regression)',
        () {
      final a = BotStyleState(confidence: 0.9, caution: 0.9);
      final b = BotStyleState(confidence: 0.9, caution: 0.9);
      a.decayTowardNeutral(0.06, 0.0);
      b.decayTowardNeutral(0.06, 1.0);

      expect(a.confidence, closeTo(0.876, 1e-9));
      expect(b.confidence, closeTo(0.876, 1e-9));
      expect(a.caution, closeTo(b.caution, 1e-9));
    });

    test('stays clamped under a run of extreme events', () {
      final s = BotStyleState();
      for (int i = 0; i < 25; i++) {
        s.applyFearGreed(0.5, 0.0);
      }
      expect(s.fearGreed, 1.0);
      expect(s.fearGreedSigned, closeTo(1.0, 1e-9));

      for (int i = 0; i < 50; i++) {
        s.applyFearGreed(-0.5, 0.0);
      }
      expect(s.fearGreed, 0.0);
      expect(s.fearGreedSigned, closeTo(-1.0, 1e-9));
    });

    test('mood reads fear -> greed in order', () {
      expect(BotStyleState(fearGreed: 0.05).mood, BotMood.rattled);
      expect(BotStyleState(fearGreed: 0.30).mood, BotMood.cagey);
      expect(BotStyleState(fearGreed: 0.50).mood, BotMood.steady);
      expect(BotStyleState(fearGreed: 0.70).mood, BotMood.runningHot);
      expect(BotStyleState(fearGreed: 0.85).mood, BotMood.steaming);
    });

    test('only a notable mood surfaces a label to the table', () {
      expect(BotStyleState(fearGreed: 0.5).notableMoodLabel, isNull);
      expect(BotStyleState(fearGreed: 0.45).notableMoodLabel, isNull);
      expect(BotStyleState(fearGreed: 0.85).notableMoodLabel, 'Steaming');
      expect(BotStyleState(fearGreed: 0.05).notableMoodLabel, 'Rattled');
      expect(BotMood.steady.isNotable, isFalse);
      expect(BotMood.steaming.isNotable, isTrue);
    });
  });
}
