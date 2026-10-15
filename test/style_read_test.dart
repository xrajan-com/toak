import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/bot/memory.dart'
    show BotOpponentMemory;
import 'package:ten_of_a_kind_poker/game/bot/style_read.dart';

void main() {
  test('no read until the player has been watched long enough', () {
    final m = BotOpponentMemory()
      ..handsSeen = PlayerStyleRead.minHands - 1
      ..vpipHands = 7
      ..preflopRaiseHands = 6;
    expect(PlayerStyleRead.readFor(m), isNull);
    m.handsSeen = PlayerStyleRead.minHands + 2;
    expect(PlayerStyleRead.readFor(m), isNotNull);
  });

  test('the four classic player types', () {
    expect(PlayerStyleRead.readFromStats(vpip: 0.55, pfr: 0.35),
        'Loose, aggressive');
    expect(PlayerStyleRead.readFromStats(vpip: 0.55, pfr: 0.05), 'Calls a lot');
    expect(PlayerStyleRead.readFromStats(vpip: 0.18, pfr: 0.14),
        'Tight, aggressive');
    expect(PlayerStyleRead.readFromStats(vpip: 0.15, pfr: 0.02),
        'Plays few hands');
  });

  test('a middling player is read by how they handle bets, or not at all', () {
    expect(
      PlayerStyleRead.readFromStats(vpip: 0.30, pfr: 0.12, foldToBet: 0.7),
      'Folds to pressure',
    );
    expect(
      PlayerStyleRead.readFromStats(vpip: 0.30, pfr: 0.12, foldToBet: 0.1),
      'Hard to bluff',
    );
    expect(PlayerStyleRead.readFromStats(vpip: 0.30, pfr: 0.12), isNull);
  });
}
