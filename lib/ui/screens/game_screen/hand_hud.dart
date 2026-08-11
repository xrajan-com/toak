import 'dart:math' as math;

class HandHudSeatState {
  final int chips;
  final int contribution;
  final bool active;
  final bool allIn;

  const HandHudSeatState({
    required this.chips,
    required this.contribution,
    required this.active,
    required this.allIn,
  });
}

class HandHudSnapshot {
  final String street;
  final int livePlayers;
  final int pot;
  final int toCall;
  final int heroStack;
  final int effectiveStack;
  final bool heroAllIn;
  final int heroAtRisk;
  final int mainPot;
  final int sidePot;
  final bool showdown;

  const HandHudSnapshot({
    required this.street,
    required this.livePlayers,
    required this.pot,
    required this.toCall,
    required this.heroStack,
    required this.effectiveStack,
    required this.heroAllIn,
    required this.heroAtRisk,
    required this.mainPot,
    required this.sidePot,
    required this.showdown,
  });

  String get primaryLine =>
      '$street • LIVE: $livePlayers • POT SIZE: ${compactHudChips(pot)}';

  String get secondaryLine {
    final String action =
        toCall > 0 ? 'TO CALL ${compactHudChips(toCall)}' : 'CHECK FREE';
    return '$action • YOU ${compactHudChips(heroStack)} • '
        'EFF ${compactHudChips(effectiveStack)}';
  }

  String lineFor({required bool heroFolded}) =>
      heroFolded ? primaryLine : secondaryLine;

  String get singleLine => primaryLine;
}

HandHudSnapshot buildHandHudSnapshot({
  required int boardCount,
  required double visiblePot,
  required int toCall,
  required int heroSeatIndex,
  required List<HandHudSeatState> seats,
  bool showdown = false,
}) {
  final int pot = math.max(0, visiblePot.round());
  final int livePlayers = seats.where((seat) => seat.active).length;
  final HandHudSeatState? hero =
      heroSeatIndex >= 0 && heroSeatIndex < seats.length
          ? seats[heroSeatIndex]
          : null;
  final int heroStack = math.max(0, hero?.chips ?? 0);
  final int largestOpponentStack = seats
      .asMap()
      .entries
      .where((entry) => entry.key != heroSeatIndex && entry.value.active)
      .map((entry) => math.max(0, entry.value.chips))
      .fold<int>(0, math.max);
  final int effectiveStack =
      largestOpponentStack > 0 ? math.min(heroStack, largestOpponentStack) : 0;

  final ({int main, int side}) pots = _mainAndSidePots(
    pot: pot,
    seats: seats,
  );
  final String street = showdown
      ? 'SHOWDOWN'
      : switch (boardCount) {
          <= 0 => 'PREFLOP',
          <= 3 => 'FLOP',
          4 => 'TURN',
          _ => 'RIVER',
        };

  return HandHudSnapshot(
    street: street,
    livePlayers: livePlayers,
    pot: pot,
    toCall: math.max(0, toCall),
    heroStack: heroStack,
    effectiveStack: effectiveStack,
    heroAllIn: hero?.allIn ?? false,
    heroAtRisk: math.max(0, hero?.contribution ?? 0),
    mainPot: pots.main,
    sidePot: pots.side,
    showdown: showdown,
  );
}

({int main, int side}) _mainAndSidePots({
  required int pot,
  required List<HandHudSeatState> seats,
}) {
  if (pot <= 0 || !seats.any((seat) => seat.active && seat.allIn)) {
    return (main: pot, side: 0);
  }
  final List<int> levels = seats
      .map((seat) => math.max(0, seat.contribution))
      .where((amount) => amount > 0)
      .toSet()
      .toList()
    ..sort();
  if (levels.length < 2) return (main: pot, side: 0);

  final List<int> layers = <int>[];
  int previous = 0;
  for (final int level in levels) {
    final int contributors =
        seats.where((seat) => seat.contribution >= level).length;
    final bool hasEligible = seats.any(
      (seat) => seat.active && seat.contribution >= level,
    );
    final int amount = (level - previous) * contributors;
    if (amount > 0 && hasEligible) layers.add(amount);
    previous = level;
  }
  if (layers.length < 2) return (main: pot, side: 0);
  final int main = layers.first.clamp(0, pot);
  return (main: main, side: math.max(0, pot - main));
}

String compactHudChips(int raw) {
  final int value = math.max(0, raw);
  if (value < 1000) return '$value';
  if (value < 1000000) return _compactUnit(value / 1000, 'K');
  return _compactUnit(value / 1000000, 'M');
}

String _compactUnit(double value, String suffix) {
  final String number = value >= 100
      ? value.round().toString()
      : value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  return '$number$suffix';
}
