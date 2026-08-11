import 'package:ten_of_a_kind_poker/game/equity/hero_equity.dart'
    show HeroEquityEstimate;

String buildVisibleHeroGuidanceMessage({
  required int livePlayers,
  required bool canCheck,
  double? winProbability,
  HeroEquityEstimate? equityEstimate,
  bool useEquityBreakdown = false,
  required int revealedBoardCount,
  required int variantSeed,
  String? aggressorName,
  bool aggressorAllIn = false,
  String? handName,
  String? improvementHint,
  String? heroRecentActionLabel,
}) {
  final double? recommendationEquity = equityEstimate?.equity ?? winProbability;
  final String chanceLabel = _chanceLabel(
    winProbability,
    equityEstimate: equityEstimate,
    useEquityBreakdown: useEquityBreakdown,
  );
  final String resolvedHand = _resolvedHandLabel(
    handName: handName,
    improvementHint: improvementHint,
  );
  final String actionLabel = _recommendedActionLabel(
    livePlayers: livePlayers,
    canCheck: canCheck,
    winProbability: recommendationEquity,
    revealedBoardCount: revealedBoardCount,
    variantSeed: variantSeed,
    aggressorAllIn: aggressorAllIn,
  );
  return '$chanceLabel, $resolvedHand, $actionLabel';
}

String _chanceLabel(
  double? winProbability, {
  HeroEquityEstimate? equityEstimate,
  required bool useEquityBreakdown,
}) {
  if (equityEstimate != null) {
    final int win =
        (equityEstimate.winProbability * 100).round().clamp(0, 100).toInt();
    final int tie =
        (equityEstimate.tieProbability * 100).round().clamp(0, 100).toInt();
    final int equity =
        (equityEstimate.equity * 100).round().clamp(0, 100).toInt();
    final String confidence = equityEstimate.exact ? '' : '~';
    final String base =
        'WIN $confidence$win% • TIE $confidence$tie% • EQUITY $confidence$equity%';
    if (!equityEstimate.sidePotAware) return base;
    final int potShare =
        (equityEstimate.expectedPotShare * 100).round().clamp(0, 100).toInt();
    return '$base • POT SHARE $confidence$potShare%';
  }
  if (useEquityBreakdown) return 'CALCULATING ODDS';
  if (winProbability == null) return 'CALCULATING ODDS';
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
