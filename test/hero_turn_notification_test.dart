import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/assets.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/hero_turn_cue.dart';

void main() {
  test('hero turn notification asset exists in the release bundle source', () {
    expect(AppAssets.heroTurnNotificationSound, endsWith('notification.mp3'));
    expect(File(AppAssets.heroTurnNotificationSound).existsSync(), isTrue);
  });

  test('hero turn cue plays exactly once per action opportunity', () {
    final HeroTurnCueTracker tracker = HeroTurnCueTracker();

    expect(
      tracker.shouldPlay(
        heroCanAct: false,
        handNumber: 1,
        phase: 'preflop',
        eventRevision: 12,
      ),
      isFalse,
    );
    expect(
      tracker.shouldPlay(
        heroCanAct: true,
        handNumber: 1,
        phase: 'preflop',
        eventRevision: 12,
      ),
      isTrue,
    );
    expect(
      tracker.shouldPlay(
        heroCanAct: true,
        handNumber: 1,
        phase: 'preflop',
        eventRevision: 12,
      ),
      isFalse,
    );

    // Pausing and resuming the same turn must not replay the cue.
    expect(
      tracker.shouldPlay(
        heroCanAct: false,
        handNumber: 1,
        phase: 'preflop',
        eventRevision: 12,
      ),
      isFalse,
    );
    expect(
      tracker.shouldPlay(
        heroCanAct: true,
        handNumber: 1,
        phase: 'preflop',
        eventRevision: 12,
      ),
      isFalse,
    );

    // New public actions can return action to the hero on the same street.
    expect(
      tracker.shouldPlay(
        heroCanAct: true,
        handNumber: 1,
        phase: 'preflop',
        eventRevision: 16,
      ),
      isTrue,
    );
    expect(
      tracker.shouldPlay(
        heroCanAct: true,
        handNumber: 1,
        phase: 'flop',
        eventRevision: 20,
      ),
      isTrue,
    );
    expect(
      tracker.shouldPlay(
        heroCanAct: true,
        handNumber: 2,
        phase: 'preflop',
        eventRevision: 30,
      ),
      isTrue,
    );
  });
}
