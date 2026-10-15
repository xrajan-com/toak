// lib/game/bot/table_talk.dart
//
// Table talk: bots react in a few words at real moments, the way people at
// a card table do. Silence was the strongest remaining tell that the
// opponents are software.
//
// Rules that keep it human rather than chatty:
//   * only real moments: a big pot won or lost at showdown, a bad beat, a
//     bust; never a running commentary;
//   * rare: one line at most per hand for the whole table, each seat rests
//     for a few hands after speaking, and even a qualifying moment only
//     speaks some of the time;
//   * in character: a maniac gloats, a rock is dry, a calling station is
//     easy-going; a steaming or rattled bot sounds it.
//
// Pure and deterministic (seeded), so tests can pin it and replays agree.

import 'package:ten_of_a_kind_poker/game/bot/memory.dart' show BotMood;
import 'package:ten_of_a_kind_poker/game/models.dart' show BotTemperament;

enum TalkMoment {
  /// Won a big pot at showdown.
  wonBigPot,

  /// Lost a big pot at showdown.
  lostBigPot,

  /// Lost at showdown holding two pair or better.
  badBeat,

  /// Knocked out of the game.
  busted,
}

class BotTableTalk {
  BotTableTalk._();

  /// Hands a seat stays quiet after speaking.
  static const int seatRestHands = 4;

  /// Chance a qualifying moment produces a line at all.
  static const Map<TalkMoment, double> speakChance = <TalkMoment, double>{
    TalkMoment.wonBigPot: 0.30,
    TalkMoment.lostBigPot: 0.25,
    TalkMoment.badBeat: 0.55,
    TalkMoment.busted: 0.60,
  };

  static const Map<TalkMoment, Map<BotTemperament, List<String>>> _lines =
      <TalkMoment, Map<BotTemperament, List<String>>>{
    TalkMoment.wonBigPot: <BotTemperament, List<String>>{
      BotTemperament.aggressive: <String>[
        'Ship it!',
        'Too easy.',
        'Keep them coming.',
        'Pay the man.',
        'Who else wants some?',
      ],
      BotTemperament.stoic: <String>[
        "I'll take it.",
        'Nice pot.',
        'Thank you kindly.',
        'Finally, a good one.',
      ],
      BotTemperament.worldChamp: <String>[
        'Patience pays.',
        'As planned.',
        'Good hand.',
        'Thank you.',
      ],
    },
    TalkMoment.lostBigPot: <BotTemperament, List<String>>{
      BotTemperament.aggressive: <String>[
        'Lucky.',
        'Run it back.',
        'Next time.',
        "You won't do that twice.",
      ],
      BotTemperament.stoic: <String>[
        'Nice hand.',
        'You had it.',
        'Fair enough.',
        'Well played.',
      ],
      BotTemperament.worldChamp: <String>[
        'Well played.',
        'Nice hand.',
        'Noted.',
        'Good call.',
      ],
    },
    TalkMoment.badBeat: <BotTemperament, List<String>>{
      BotTemperament.aggressive: <String>[
        'Seriously?',
        'Unreal.',
        'The river hates me.',
        'How?!',
      ],
      BotTemperament.stoic: <String>[
        'Every time...',
        'Ouch.',
        'Unlucky.',
        'That hurts.',
      ],
      BotTemperament.worldChamp: <String>[
        "That's poker.",
        'Variance.',
        'Unlucky.',
        'It happens.',
      ],
    },
    TalkMoment.busted: <BotTemperament, List<String>>{
      BotTemperament.aggressive: <String>[
        "I'll be back.",
        'Unbelievable.',
        'GG. Next table.',
      ],
      BotTemperament.stoic: <String>[
        'GG, all.',
        'Good game.',
        "That's me out.",
      ],
      BotTemperament.worldChamp: <String>[
        'Good game.',
        'GG. Well played.',
        'Until next time.',
      ],
    },
  };

  /// Lines for a bot whose mood is far from neutral, after a loss.
  static const Map<BotMood, List<String>> _moodLosingLines =
      <BotMood, List<String>>{
    BotMood.steaming: <String>[
      "I'm done being nice.",
      "That's it.",
      'Watch this.',
    ],
    BotMood.rattled: <String>[
      'Not again...',
      "Can't win one.",
      'Brutal.',
    ],
  };

  /// What a bot says at [moment], or null when it stays quiet. [roll] in
  /// [0, 1) decides whether it speaks; [pick] in [0, 1) chooses the line.
  static String? lineFor({
    required TalkMoment moment,
    required BotTemperament temperament,
    required BotMood mood,
    required double roll,
    required double pick,
  }) {
    if (roll >= (speakChance[moment] ?? 0.0)) return null;
    final bool losing = moment == TalkMoment.lostBigPot ||
        moment == TalkMoment.badBeat;
    final List<String>? moodLines = losing ? _moodLosingLines[mood] : null;
    final List<String> lines = (moodLines != null && pick < 0.5)
        ? moodLines
        : (_lines[moment]?[temperament] ?? const <String>[]);
    if (lines.isEmpty) return null;
    final int i = (pick * lines.length).floor().clamp(0, lines.length - 1);
    return lines[i];
  }

  /// Every line a bot can say; used by tests to keep lines short.
  static Iterable<String> get allLines sync* {
    for (final byTemperament in _lines.values) {
      for (final lines in byTemperament.values) {
        yield* lines;
      }
    }
    for (final lines in _moodLosingLines.values) {
      yield* lines;
    }
  }
}
