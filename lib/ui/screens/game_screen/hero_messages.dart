import 'dart:math' as math;

import 'package:ten_of_a_kind_poker/game/core.dart'
    show Card, Rank, Suit, rankValue;
import 'package:ten_of_a_kind_poker/game/hand_evaluator.dart'
    show HandEvaluator, HandRank;

double? estimateVisibleHeroWinProbability({
  required int livePlayers,
  required List<Card> heroHole,
  required List<Card> revealedBoard,
}) {
  if (livePlayers <= 0) return null;
  if (heroHole.length < 2) return null;

  final int opponents = math.max(0, livePlayers - 1);
  if (opponents == 0) return 1.0;

  final List<Card> board = revealedBoard.take(5).toList(growable: false);
  final List<Card> hole = heroHole.take(2).toList(growable: false);
  final List<Card> visible = <Card>[...hole, ...board];
  final Set<String> excluded = visible.map(_cardKey).toSet();
  final List<Card> remaining = _standardDeck()
      .where((card) => !excluded.contains(_cardKey(card)))
      .toList(growable: false);

  final int boardNeeded = 5 - board.length;
  final int totalDraw = boardNeeded + opponents * 2;
  if (boardNeeded < 0 || remaining.length < totalDraw) return null;

  final int baseIterations = switch (board.length) {
    0 => 220,
    3 => 180,
    4 => 140,
    5 => 110,
    _ => 160,
  };
  final int iterations =
      (baseIterations / (1 + (opponents - 1) * 0.25)).round().clamp(80, 240);
  final math.Random rng = math.Random(
    _visibleStateSeed(
      livePlayers: livePlayers,
      heroHole: hole,
      revealedBoard: board,
    ),
  );
  final List<Card> sample = List<Card>.from(remaining);
  double score = 0.0;

  for (int i = 0; i < iterations; i++) {
    _shuffleInPlace(sample, rng);
    final List<Card> runout = sample.take(totalDraw).toList(growable: false);
    int offset = 0;
    final List<Card> fullBoard = <Card>[
      ...board,
      if (boardNeeded > 0) ...runout.take(boardNeeded),
    ];
    offset += boardNeeded;

    final HandRank heroRank =
        HandEvaluator.evaluate(<Card>[...hole, ...fullBoard]);
    bool heroBest = true;
    int ties = 1;

    for (int opp = 0; opp < opponents; opp++) {
      final List<Card> oppHole = <Card>[runout[offset], runout[offset + 1]];
      offset += 2;
      final HandRank oppRank = HandEvaluator.evaluate(<Card>[
        ...oppHole,
        ...fullBoard,
      ]);
      final int cmp = oppRank.compareTo(heroRank);
      if (cmp > 0) {
        heroBest = false;
        break;
      }
      if (cmp == 0) {
        ties += 1;
      }
    }

    if (heroBest) {
      score += 1.0 / ties;
    }
  }

  return (score / iterations).clamp(0.0, 1.0).toDouble();
}

String buildVisibleHeroGuidanceMessage({
  required int livePlayers,
  required bool canCheck,
  required double? winProbability,
  required int revealedBoardCount,
  required int variantSeed,
  String? aggressorName,
  bool aggressorAllIn = false,
  String? handName,
  String? improvementHint,
  String? heroRecentActionLabel,
}) {
  final String chanceLabel = _chanceLabel(winProbability);
  final String resolvedHand = _resolvedHandLabel(
    handName: handName,
    improvementHint: improvementHint,
  );
  final String actionLabel = _recommendedActionLabel(
    livePlayers: livePlayers,
    canCheck: canCheck,
    winProbability: winProbability,
    revealedBoardCount: revealedBoardCount,
    variantSeed: variantSeed,
    aggressorAllIn: aggressorAllIn,
  );
  return '$chanceLabel, $resolvedHand, $actionLabel';
}

String _chanceLabel(double? winProbability) {
  if (winProbability == null) return '--% CHANCE';
  final int pct = (winProbability * 100).round().clamp(0, 100).toInt();
  return '$pct% CHANCE';
}

String _resolvedHandLabel({
  required String? handName,
  required String? improvementHint,
}) {
  final String preferred = (handName ?? '').trim();
  if (preferred.isNotEmpty) {
    return preferred.toUpperCase();
  }
  final String fallback = (improvementHint ?? '').trim();
  if (fallback.isNotEmpty) {
    return fallback.toUpperCase();
  }
  return 'A CLEAN SPOT';
}

String _recommendedActionLabel({
  required int livePlayers,
  required bool canCheck,
  required double? winProbability,
  required int revealedBoardCount,
  required int variantSeed,
  required bool aggressorAllIn,
}) {
  if (canCheck) {
    if (winProbability != null && winProbability >= 0.68) {
      return 'RAISE';
    }
    return 'CHECK';
  }

  if (winProbability == null) {
    return 'CALL';
  }

  final bool river = revealedBoardCount >= 5;
  final double clearFoldThreshold;
  if (aggressorAllIn) {
    clearFoldThreshold = river ? 0.16 : 0.12;
  } else if (river) {
    clearFoldThreshold = livePlayers >= 4 ? 0.14 : 0.12;
  } else {
    clearFoldThreshold = livePlayers >= 4 ? 0.10 : 0.08;
  }
  if (winProbability <= clearFoldThreshold) {
    return _cautionaryActionLabel(variantSeed);
  }

  if (winProbability >= 0.68) {
    return aggressorAllIn ? 'CALL' : 'RAISE';
  }
  if (river && winProbability >= 0.58) return 'CALL';
  return 'CALL';
}

String _cautionaryActionLabel(int variantSeed) {
  const List<String> phrases = <String>[
    'CAUTION',
    'TOO THIN',
    'DANGER',
  ];
  return phrases[variantSeed.abs() % phrases.length];
}

String _legacyBuildVisibleHeroGuidanceMessage({
  required int livePlayers,
  required bool canCheck,
  required double? winProbability,
  required int revealedBoardCount,
  required int variantSeed,
  String? aggressorName,
  bool aggressorAllIn = false,
  String? improvementHint,
  String? heroRecentActionLabel,
}) {
  final String coachLead = _coachLead(
    canCheck: canCheck,
    winProbability: winProbability,
    variantSeed: variantSeed,
    heroRecentActionLabel: heroRecentActionLabel,
  );
  final String lead = _leadText(
    livePlayers: livePlayers,
    winProbability: winProbability,
  );
  final _Guidance guidance = _guidanceForSpot(
    livePlayers: livePlayers,
    canCheck: canCheck,
    winProbability: winProbability,
    revealedBoardCount: revealedBoardCount,
    variantSeed: variantSeed,
    aggressorName: aggressorName,
    aggressorAllIn: aggressorAllIn,
    improvementHint: improvementHint,
  );
  return '$coachLead $lead ${guidance.suggestion} ${guidance.warning}'
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _Guidance {
  final String suggestion;
  final String warning;

  const _Guidance({
    required this.suggestion,
    required this.warning,
  });
}

_Guidance _guidanceForSpot({
  required int livePlayers,
  required bool canCheck,
  required double? winProbability,
  required int revealedBoardCount,
  required int variantSeed,
  required String? aggressorName,
  required bool aggressorAllIn,
  required String? improvementHint,
}) {
  final int variant = variantSeed.abs() % 3;
  final String pressureName = (aggressorName ?? '').trim();
  final bool underPressure = !canCheck;
  final bool multiway = livePlayers >= 4;
  final String hint = _improvementHint(improvementHint);

  if (winProbability == null) {
    if (canCheck) {
      return const _Guidance(
        suggestion: 'Check is free here.',
        warning: 'Bet/Raise only with a plan.',
      );
    }
    return _Guidance(
      suggestion: hint.isNotEmpty
          ? 'Call only if it is cheap for $hint.'
          : 'Call only if it is cheap.',
      warning: aggressorAllIn
          ? 'All-In is your whole stack.'
          : pressureName.isNotEmpty
              ? 'Fold to big heat from $pressureName.'
              : 'Fold to big heat.',
    );
  }

  if (winProbability >= 0.68) {
    if (!underPressure) {
      final List<String> suggestions = <String>[
        'Bet/Raise for value.',
        'Bet now and charge the table.',
        'Raise while worse hands can still pay.',
      ];
      final List<String> warnings = <String>[
        'Check gives free cards.',
        'Slow-play can cost value.',
        'Do not let everyone peel.',
      ];
      return _Guidance(
        suggestion: suggestions[variant],
        warning: warnings[variant],
      );
    }
    final List<String> suggestions = <String>[
      aggressorAllIn
          ? 'Call is live here.'
          : 'Call is fine; raise for value if sizing stays sane.',
      aggressorAllIn
          ? 'This can call the shove.'
          : 'Keep playing forward; raise if it stays clean.',
      aggressorAllIn
          ? 'You can continue against the jam.'
          : 'Defend with Call or a value raise.',
    ];
    final List<String> warnings = <String>[
      aggressorAllIn
          ? 'All-In means your whole stack.'
          : 'Do not stack off blind.',
      aggressorAllIn
          ? 'Even strong hands can be second-best.'
          : 'Watch for a re-raise behind.',
      pressureName.isNotEmpty
          ? '$pressureName can still have the top range.'
          : 'Pressure still matters.',
    ];
    return _Guidance(
      suggestion: suggestions[variant],
      warning: warnings[variant],
    );
  }

  if (winProbability >= 0.45) {
    if (!underPressure) {
      final List<String> suggestions = <String>[
        'Check keeps it small.',
        'Take the free card or bet small.',
        'Stay small unless you improve again.',
      ];
      final List<String> warnings = <String>[
        'Bet/Raise can bloat this spot.',
        multiway
            ? 'Multiway makes this edge thinner.'
            : 'One more bet can trap you.',
        'Playable does not mean huge.',
      ];
      return _Guidance(
        suggestion: suggestions[variant],
        warning: warnings[variant],
      );
    }
    final String improveLine =
        hint.isNotEmpty && revealedBoardCount < 5 ? ' for $hint' : '';
    final List<String> suggestions = <String>[
      'Call only if the price is fair$improveLine.',
      'Call small pressure, but fold big heat.',
      'Call disciplined, not wide.',
    ];
    final List<String> warnings = <String>[
      aggressorAllIn
          ? 'All-In asks too much from this edge.'
          : 'Fold to a big raise.',
      pressureName.isNotEmpty
          ? '$pressureName has shown strength.'
          : 'Respect the aggression.',
      'Do not punt a medium edge.',
    ];
    return _Guidance(
      suggestion: suggestions[variant],
      warning: warnings[variant],
    );
  }

  if (!underPressure) {
    final String improveLine =
        hint.isNotEmpty && revealedBoardCount < 5 ? ' and chase $hint' : '';
    final List<String> suggestions = <String>[
      'Check for free$improveLine.',
      'Keep the pot small.',
      'Check unless you improve.',
    ];
    final List<String> warnings = <String>[
      multiway
          ? 'Bluffing into $livePlayers live is rough.'
          : 'Bet/Raise is mostly a bluff.',
      'This gets expensive fast.',
      'Do not build a pot light.',
    ];
    return _Guidance(
      suggestion: suggestions[variant],
      warning: warnings[variant],
    );
  }

  final String improveLine = hint.isNotEmpty && revealedBoardCount < 5
      ? ' unless the call is cheap for $hint'
      : ' unless the call is tiny';
  final List<String> suggestions = <String>[
    pressureName.isNotEmpty
        ? 'Fold to $pressureName$improveLine.'
        : 'Fold to pressure$improveLine.',
    'Let it go unless the call is tiny.',
    'Save the chips for a cleaner spot.',
  ];
  final List<String> warnings = <String>[
    aggressorAllIn ? 'All-In loses too often.' : 'Chasing burns chips.',
    pressureName.isNotEmpty
        ? '$pressureName looks strong.'
        : 'The pressure is a bad sign.',
    multiway
        ? 'Too many live players can beat you.'
        : 'Weak equity and pressure do not mix.',
  ];
  return _Guidance(
    suggestion: suggestions[variant],
    warning: warnings[variant],
  );
}

String _coachLead({
  required bool canCheck,
  required double? winProbability,
  required int variantSeed,
  required String? heroRecentActionLabel,
}) {
  final int variant = variantSeed.abs() % 3;
  final String action = (heroRecentActionLabel ?? '').trim().toUpperCase();
  final bool recentRaise = action.startsWith('RAISE') ||
      action.startsWith('BET') ||
      action.startsWith('ALL-IN') ||
      action.startsWith('ALL IN');
  final bool recentCall = action.startsWith('CALL');
  final bool recentCheck = action.startsWith('CHECK');

  if (winProbability != null && winProbability <= 0.28) {
    const List<String> lines = <String>[
      'Reset.',
      'Stay calm.',
      'Next hand.',
    ];
    return lines[variant];
  }

  if (winProbability != null && !canCheck && winProbability < 0.45) {
    const List<String> lines = <String>[
      'Stay disciplined.',
      'Reset and stay sharp.',
      'Keep your head.',
    ];
    return lines[variant];
  }

  if (recentRaise && (winProbability == null || winProbability >= 0.55)) {
    const List<String> lines = <String>[
      'Nice pressure.',
      'Good raise.',
      'Well played.',
    ];
    return lines[variant];
  }

  if (recentCall && winProbability != null && winProbability >= 0.62) {
    const List<String> lines = <String>[
      'Nice call.',
      'Good read.',
      'Solid call.',
    ];
    return lines[variant];
  }

  if (recentCheck &&
      canCheck &&
      winProbability != null &&
      winProbability >= 0.45 &&
      winProbability < 0.68) {
    const List<String> lines = <String>[
      'Good check.',
      'Nice patience.',
      'Smart check.',
    ];
    return lines[variant];
  }

  return '';
}

String _leadText({
  required int livePlayers,
  required double? winProbability,
}) {
  final String playersLabel = livePlayers == 1 ? '1 live' : '$livePlayers live';
  if (winProbability == null) {
    return 'No clear read vs $playersLabel.';
  }
  final int pct = (winProbability * 100).round().clamp(0, 100).toInt();
  return '$pct% to win vs $playersLabel.';
}

String _improvementHint(String? raw) {
  final String value = (raw ?? '').trim().toLowerCase();
  if (value.isEmpty) return '';
  return value;
}

int _visibleStateSeed({
  required int livePlayers,
  required List<Card> heroHole,
  required List<Card> revealedBoard,
}) {
  final List<String> parts = <String>[
    '$livePlayers',
    ...heroHole.map(_cardKey).toList(growable: false)..sort(),
    ...revealedBoard.map(_cardKey).toList(growable: false)..sort(),
  ];
  int hash = 216613626;
  for (final part in parts) {
    for (final int unit in part.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
  }
  return hash;
}

void _shuffleInPlace(List<Card> cards, math.Random rng) {
  for (int i = cards.length - 1; i > 0; i--) {
    final int j = rng.nextInt(i + 1);
    final Card tmp = cards[i];
    cards[i] = cards[j];
    cards[j] = tmp;
  }
}

List<Card> _standardDeck() {
  return <Card>[
    for (final Suit suit in Suit.values)
      for (final Rank rank in Rank.values) Card(rank, suit),
  ];
}

String _cardKey(Card card) {
  return '${rankValue(card.rank)}:${card.suit.index}';
}
