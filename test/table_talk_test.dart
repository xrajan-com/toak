import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/bot/memory.dart' show BotMood;
import 'package:ten_of_a_kind_poker/game/bot/table_talk.dart';
import 'package:ten_of_a_kind_poker/game/models.dart' show BotTemperament;

void main() {
  test('lines are short enough for the seat bubble', () {
    for (final line in BotTableTalk.allLines) {
      expect(line.length, lessThanOrEqualTo(24), reason: line);
      expect(line.trim(), line);
    }
  });

  test('bots stay quiet unless the roll says otherwise', () {
    for (final moment in TalkMoment.values) {
      final chance = BotTableTalk.speakChance[moment]!;
      expect(chance, inExclusiveRange(0.0, 1.0));
      expect(
        BotTableTalk.lineFor(
          moment: moment,
          temperament: BotTemperament.stoic,
          mood: BotMood.steady,
          roll: chance,
          pick: 0.1,
        ),
        isNull,
      );
      expect(
        BotTableTalk.lineFor(
          moment: moment,
          temperament: BotTemperament.stoic,
          mood: BotMood.steady,
          roll: 0.0,
          pick: 0.1,
        ),
        isNotNull,
      );
    }
  });

  test('every temperament has something to say at every moment', () {
    for (final moment in TalkMoment.values) {
      for (final t in BotTemperament.values) {
        for (final pick in [0.0, 0.5, 0.999]) {
          expect(
            BotTableTalk.lineFor(
              moment: moment,
              temperament: t,
              mood: BotMood.steady,
              roll: 0.0,
              pick: pick,
            ),
            isNotNull,
          );
        }
      }
    }
  });

  test('a steaming bot sounds it after a loss, not after a win', () {
    final losing = BotTableTalk.lineFor(
      moment: TalkMoment.badBeat,
      temperament: BotTemperament.worldChamp,
      mood: BotMood.steaming,
      roll: 0.0,
      pick: 0.0,
    );
    expect(losing, isIn(["I'm done being nice.", "That's it.", 'Watch this.']));
    final winning = BotTableTalk.lineFor(
      moment: TalkMoment.wonBigPot,
      temperament: BotTemperament.worldChamp,
      mood: BotMood.steaming,
      roll: 0.0,
      pick: 0.0,
    );
    expect(winning, 'Patience pays.');
  });
}
