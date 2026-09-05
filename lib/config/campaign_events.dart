import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show subKingdomCountFor, subKingdomNamesFor;
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/game/models.dart';

enum CampaignEventKind { subKingdom, kingdomMainEvent }

class CurrencySpec {
  final String code;
  final String prefix;
  final String locale;

  /// Baseline (1x) prize pool for a kingdom main event.
  final int baseKingdomPrizePool;

  const CurrencySpec({
    required this.code,
    required this.prefix,
    required this.locale,
    required this.baseKingdomPrizePool,
  });

  String format(int amount) {
    final formatted = NumberFormat.decimalPattern(locale).format(amount);
    return '$prefix$formatted';
  }
}

class CampaignEventSpec {
  final VenueGroup group;
  final String kingdomName;
  final CampaignEventKind kind;
  final int? subKingdomIndex;
  final CurrencySpec currency;

  /// Kingdom gold multiplier (1x..10x).
  final int kingdomGoldMultiplier;

  /// Total prize pool for the event (in [currency]).
  final int prizePool;

  /// Engine table size for the event.
  final int maxPlayers;

  /// Tournament starting stack (chips) for every seat.
  /// Main kingdom events stay fixed at 10,000; sub-kingdoms can vary.
  final int startingStack;

  /// Number of paid places (1 => winner takes all).
  final int placesPaid;

  /// Amounts by finishing rank.
  final PayoutTable payoutTable;

  /// Global bot difficulty scaling for the engine.
  final BotDifficulty botDifficulty;

  /// How many top bots to force-seed into the table (0..maxPlayers-1).
  final int forcedTopBots;

  const CampaignEventSpec({
    required this.group,
    required this.kingdomName,
    required this.kind,
    required this.currency,
    required this.kingdomGoldMultiplier,
    required this.prizePool,
    required this.maxPlayers,
    this.startingStack = 10000,
    required this.placesPaid,
    required this.payoutTable,
    required this.botDifficulty,
    required this.forcedTopBots,
    this.subKingdomIndex,
  });

  bool get isMainEvent => kind == CampaignEventKind.kingdomMainEvent;

  String get prizePoolLabel => currency.format(prizePool);

  String payoutSummaryLabel() {
    if (placesPaid <= 1) return 'Winner takes all';
    return 'Top $placesPaid paid';
  }

  String tableSizeLabel() => '${maxPlayers}p';
}

const CurrencySpec kCurrencyINR = CurrencySpec(
  code: 'AUP',
  prefix: 'AUP ',
  locale: 'en_IN',
  baseKingdomPrizePool: 100000,
);

const Map<String, CurrencySpec> _intlCurrencyByKingdom = <String, CurrencySpec>{
  'Africa': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 35000,
  ),
  'S. America': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 12000,
  ),
  'N. America': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 3000,
  ),
  'Arabia': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 9000,
  ),
  'Australia': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 3000,
  ),
  'China': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 18000,
  ),
  'India': kCurrencyINR,
  'Russia': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 200000,
  ),
  'Asia': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 3200,
  ),
  'Far East': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 450000,
  ),
  'Asia Rest': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 3200,
  ),
  'Central Asia': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 3000,
  ),
  'Persia': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 3000,
  ),
  'Europe': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 2800,
  ),
  'European Marches': CurrencySpec(
    code: 'AUP',
    prefix: 'AUP ',
    locale: 'en_IN',
    baseKingdomPrizePool: 2800,
  ),
};

CurrencySpec currencyForVenue({
  required VenueGroup group,
  required String kingdomName,
}) {
  if (group == VenueGroup.india) return kCurrencyINR;
  final canonical =
      canonicalKingdomName(group: group, kingdomName: kingdomName);
  return _intlCurrencyByKingdom[canonical] ??
      const CurrencySpec(
        code: 'AUP',
        prefix: 'AUP ',
        locale: 'en_IN',
        baseKingdomPrizePool: 3000,
      );
}

String canonicalKingdomName({
  required VenueGroup group,
  required String kingdomName,
}) {
  final t = kingdomName.trim();
  if (t.isEmpty) return t;
  if (group == VenueGroup.international) {
    final lower = t.toLowerCase();
    if (lower == 'amazon' ||
        lower == 'south america' ||
        lower == 's america' ||
        lower == 's. america') {
      return 'S. America';
    }
    if (lower == 'america' ||
        lower == 'usa' ||
        lower == 'u.s.a' ||
        lower == 'us' ||
        lower == 'united states' ||
        lower == 'united states of america' ||
        lower == 'north america' ||
        lower == 'n america' ||
        lower == 'n. america') {
      return 'Australia';
    }
    if (lower == 'far east' || lower == 'east asia') return 'Far East';
    if (lower == 'asia rest' ||
        lower == 'mainland asia' ||
        lower == 'southeast' ||
        lower == 'asia') {
      return 'Asia Rest';
    }
    if (lower == 'europe' ||
        lower == 'europe kingdom' ||
        lower == 'european marches') {
      return 'European Marches';
    }
    if (lower == 'persia' ||
        lower == 'persia and mesopotamia' ||
        lower == 'mesopotamia') {
      return 'Persia & Mesopotamia';
    }
  }
  return t;
}

int _fnv1a32(String s) {
  var hash = 0x811c9dc5;
  for (final cu in s.codeUnits) {
    hash ^= cu;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

final Map<VenueGroup, Map<String, List<int>>> _subKingdomTableSizesCache =
    <VenueGroup, Map<String, List<int>>>{};

final Map<VenueGroup, Map<String, List<int>>> _subKingdomPrizeOrderCache =
    <VenueGroup, Map<String, List<int>>>{};

/// Returns sub-kingdom indices (1-based) ordered by prize pool, ascending.
///
/// The first index in this list is the "free" sub-kingdom for that kingdom.
List<int> subKingdomIndicesByPrizePool({
  required VenueGroup group,
  required String kingdomName,
}) {
  final canonical =
      canonicalKingdomName(group: group, kingdomName: kingdomName);
  final byGroup = _subKingdomPrizeOrderCache.putIfAbsent(
    group,
    () => <String, List<int>>{},
  );
  final cached = byGroup[canonical];
  if (cached != null) return cached;

  final int count = subKingdomCountFor(group: group, kingdomName: canonical);
  if (count <= 0) {
    byGroup[canonical] = const <int>[];
    return byGroup[canonical]!;
  }

  final prizes = <int, int>{};
  for (int i = 1; i <= count; i++) {
    try {
      prizes[i] = subKingdomEventSpec(
        group: group,
        kingdomName: canonical,
        subKingdomIndex: i,
      ).prizePool;
    } catch (_) {
      prizes[i] = 0;
    }
  }

  final order = List<int>.generate(count, (i) => i + 1);
  order.sort((a, b) {
    final int pa = prizes[a] ?? 0;
    final int pb = prizes[b] ?? 0;
    if (pa != pb) return pa.compareTo(pb);
    return a.compareTo(b);
  });

  final frozen = List<int>.unmodifiable(order);
  byGroup[canonical] = frozen;
  return frozen;
}

/// Returns the (1-based) sub-kingdom index with the lowest prize pool.
int freeSubKingdomIndexFor({
  required VenueGroup group,
  required String kingdomName,
}) {
  final canonical =
      canonicalKingdomName(group: group, kingdomName: kingdomName);
  final override = _preferredFreeSubKingdomIndex(
    group: group,
    canonicalKingdomName: canonical,
  );
  if (override != null) return override;

  final order = subKingdomIndicesByPrizePool(
    group: group,
    kingdomName: canonical,
  );
  return order.isEmpty ? 1 : order.first;
}

int? _preferredFreeSubKingdomIndex({
  required VenueGroup group,
  required String canonicalKingdomName,
}) {
  if (group == VenueGroup.india && canonicalKingdomName == 'Mysore') {
    return _subKingdomIndexForName(
      group: group,
      kingdomName: canonicalKingdomName,
      targetName: 'Kodagu',
    );
  }
  return null;
}

int? _subKingdomIndexForName({
  required VenueGroup group,
  required String kingdomName,
  required String targetName,
}) {
  final names = subKingdomNamesFor(group: group, kingdomName: kingdomName);
  final target = targetName.trim().toLowerCase();
  if (target.isEmpty) return null;
  for (int i = 0; i < names.length; i++) {
    if (names[i].trim().toLowerCase() == target) return i + 1;
  }
  return null;
}

List<int> _subKingdomTableSizesForKingdom({
  required VenueGroup group,
  required String canonicalKingdomName,
}) {
  final byGroup = _subKingdomTableSizesCache.putIfAbsent(
    group,
    () => <String, List<int>>{},
  );
  final cached = byGroup[canonicalKingdomName];
  if (cached != null) return cached;

  final int count =
      subKingdomCountFor(group: group, kingdomName: canonicalKingdomName);
  if (count <= 0) {
    byGroup[canonicalKingdomName] = const <int>[];
    return byGroup[canonicalKingdomName]!;
  }

  final scored = <({int idx, double frac})>[];
  for (int i = 1; i <= count; i++) {
    final rng = math.Random(
      _fnv1a32('sub_event|${group.name}|$canonicalKingdomName|$i|v2'),
    );
    final frac = 0.08 + rng.nextDouble() * 0.27; // 0.08..0.35
    scored.add((idx: i, frac: frac));
  }

  scored.sort((a, b) {
    final byFrac = b.frac.compareTo(a.frac);
    if (byFrac != 0) return byFrac;
    return a.idx.compareTo(b.idx);
  });

  final sizes = List<int>.filled(scored.length, 6);
  final int eightCount = switch (scored.length) {
    <= 2 => 0,
    3 => 1,
    _ => math.max(1, scored.length ~/ 3),
  };
  for (int j = 0; j < math.min(scored.length, eightCount); j++) {
    sizes[scored[j].idx - 1] = 8;
  }

  void forceSubKingdomTableSize(String name, int desired) {
    final names = subKingdomNamesFor(
      group: group,
      kingdomName: canonicalKingdomName,
    );
    final int idx = names.indexWhere(
      (n) => n.toLowerCase() == name.toLowerCase(),
    );
    if (idx < 0 || idx >= sizes.length) return;
    final int normalized = desired >= 8 ? 8 : 6;
    if (sizes[idx] == normalized) return;

    final int swapIndex = sizes.indexWhere((s) => s == normalized);
    if (swapIndex != -1 && swapIndex != idx) {
      final int prev = sizes[idx];
      sizes[idx] = normalized;
      sizes[swapIndex] = prev;
      return;
    }
    sizes[idx] = normalized;
  }

  if (group == VenueGroup.india && canonicalKingdomName == 'Indore') {
    forceSubKingdomTableSize('Chambal', 8);
  }
  if (group == VenueGroup.india && canonicalKingdomName == 'Mysore') {
    forceSubKingdomTableSize('Bengaluru', 8);
  }
  byGroup[canonicalKingdomName] = List<int>.unmodifiable(sizes);
  return byGroup[canonicalKingdomName]!;
}

int _roundNice(int amount) {
  final a = amount.abs();
  final int step;
  if (a >= 1000000) {
    step = 10000;
  } else if (a >= 100000) {
    step = 1000;
  } else if (a >= 10000) {
    step = 100;
  } else if (a >= 1000) {
    step = 50;
  } else {
    step = 10;
  }
  final rounded = ((amount + (step ~/ 2)) ~/ step) * step;
  return rounded == 0 ? amount : rounded;
}

final Map<VenueGroup, Map<String, int>> _kingdomMultiplierCache =
    <VenueGroup, Map<String, int>>{};

Map<String, int> _kingdomGoldMultipliersForGroup(VenueGroup group) {
  final cached = _kingdomMultiplierCache[group];
  if (cached != null) return cached;

  final List<String> kingdoms = venuesForGroup(group)
      .map((v) => v.name)
      .map((n) => n.trim())
      .where((n) => n.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final multipliers = List<int>.generate(10, (i) => i + 1);
  multipliers.shuffle(math.Random(_fnv1a32('kingdom_mults|${group.name}|v1')));

  final out = <String, int>{};
  for (int i = 0; i < kingdoms.length; i++) {
    out[kingdoms[i]] = multipliers[i % multipliers.length];
  }
  _kingdomMultiplierCache[group] = out;
  return out;
}

int kingdomGoldMultiplier({
  required VenueGroup group,
  required String kingdomName,
}) {
  final canonical =
      canonicalKingdomName(group: group, kingdomName: kingdomName);
  final map = _kingdomGoldMultipliersForGroup(group);
  return map[canonical] ?? 1;
}

BotDifficulty _botDifficultyForMainEvent(int multiplier) {
  final s = multiplier.clamp(1, 10) / 10.0;
  if (s < 0.30) return BotDifficulty.normal;
  if (s < 0.70) return BotDifficulty.hard;
  return BotDifficulty.brutal;
}

BotDifficulty _botDifficultyForSubEvent(double stakeScore) {
  final s = stakeScore.clamp(0.0, 1.0);
  if (s < 0.25) return BotDifficulty.easy;
  if (s < 0.55) return BotDifficulty.normal;
  if (s < 0.82) return BotDifficulty.hard;
  return BotDifficulty.brutal;
}

bool _subEventsUseLethalBots({
  required VenueGroup group,
  required String kingdomName,
}) {
  // Special high-reward kingdoms: sub-kingdoms should feel the toughest.
  if (group == VenueGroup.india && kingdomName == 'Sikh Empire') return true;
  if (group == VenueGroup.international && kingdomName == 'Australia') {
    return true;
  }
  return false;
}

PayoutTable _payoutTableFor({
  required int prizePool,
  required int placesPaid,
  required math.Random rng,
}) {
  if (prizePool <= 0 || placesPaid <= 0) return const PayoutTable([]);
  if (placesPaid == 1) return PayoutTable.fixed(<int>[prizePool]);

  if (placesPaid == 2) {
    const options = <List<double>>[
      <double>[0.70, 0.30],
      <double>[0.65, 0.35],
      <double>[0.60, 0.40],
    ];
    return PayoutTable.fromPercentages(
      prizePool,
      options[rng.nextInt(options.length)],
    );
  }

  if (placesPaid == 3) {
    const options = <List<double>>[
      <double>[0.50, 0.30, 0.20],
      <double>[0.55, 0.30, 0.15],
      <double>[0.45, 0.30, 0.25],
    ];
    return PayoutTable.fromPercentages(
      prizePool,
      options[rng.nextInt(options.length)],
    );
  }

  if (placesPaid == 5) {
    final power = 1.05 + rng.nextDouble() * 0.55; // 1.05..1.60
    return PayoutTable.inverseRankWeighted(
      total: prizePool,
      places: placesPaid,
      power: power,
    );
  }

  return PayoutTable.topHeavy(prizePool, placesPaid);
}

PayoutTable _subKingdomPayoutTable({
  required int prizePool,
}) {
  if (prizePool <= 0) return const PayoutTable([]);
  return PayoutTable.fromPercentages(
    prizePool,
    const <double>[0.60, 0.25, 0.15],
  );
}

CampaignEventSpec kingdomMainEventSpec({
  required VenueGroup group,
  required String kingdomName,
}) {
  final canonical =
      canonicalKingdomName(group: group, kingdomName: kingdomName);
  final currency = currencyForVenue(group: group, kingdomName: canonical);
  final mult = kingdomGoldMultiplier(group: group, kingdomName: canonical);

  final prizePool = _roundNice(currency.baseKingdomPrizePool * mult);

  // "More prize" => heavier seeding of lethal bots.
  final int forcedTopBots = switch (mult) {
    >= 9 => 9, // hero + 9 lethal bots
    8 => 6,
    7 => 5,
    6 => 4,
    5 => 4,
    4 => 3,
    3 => 2,
    _ => 1,
  };

  return CampaignEventSpec(
    group: group,
    kingdomName: canonical,
    kind: CampaignEventKind.kingdomMainEvent,
    currency: currency,
    kingdomGoldMultiplier: mult,
    prizePool: prizePool,
    maxPlayers: 10,
    startingStack: 10000,
    placesPaid: 1,
    payoutTable: PayoutTable.fixed(<int>[prizePool]),
    botDifficulty: _botDifficultyForMainEvent(mult),
    forcedTopBots: forcedTopBots.clamp(0, 9),
  );
}

CampaignEventSpec subKingdomEventSpec({
  required VenueGroup group,
  required String kingdomName,
  required int subKingdomIndex,
}) {
  final canonical =
      canonicalKingdomName(group: group, kingdomName: kingdomName);
  final main = kingdomMainEventSpec(group: group, kingdomName: canonical);
  final rng = math.Random(
    _fnv1a32('sub_event|${group.name}|$canonical|$subKingdomIndex|v2'),
  );

  // Prize is a fraction of the kingdom main event; keeps main event highest.
  final frac = 0.08 + rng.nextDouble() * 0.27; // 0.08..0.35
  int prizePool = _roundNice((main.prizePool * frac).round());
  prizePool = prizePool.clamp(0, main.prizePool - 1);

  // Starting stacks vary by sub-kingdom for variety (kingdom main event stays 10k).
  // Deterministic per (group, kingdom, subIndex) via the seeded RNG.
  final List<int> stackOptions = frac >= 0.25
      ? const <int>[7000, 8000, 9000, 10000]
      : (frac < 0.16
          ? const <int>[9000, 10000, 11000, 12000, 13000]
          : const <int>[8000, 9000, 10000, 11000, 12000]);
  final int startingStack =
      stackOptions[rng.nextInt(stackOptions.length)].clamp(2000, 50000);

  // Seats: mostly 6-player tables with a smaller set of tougher 8-player tables.
  final sizes = _subKingdomTableSizesForKingdom(
    group: group,
    canonicalKingdomName: canonical,
  );
  int maxPlayers = 8;
  if (sizes.isNotEmpty) {
    final clamped = subKingdomIndex.clamp(1, sizes.length);
    maxPlayers = sizes[clamped - 1];
  }

  // Sub-kingdoms are intentionally forgiving: always pay the top 3 spots.
  final int placesPaid = math.min(3, maxPlayers);

  final stakeScore =
      (main.kingdomGoldMultiplier / 10.0) * (frac / 0.35); // 0..1
  final botsNeeded = math.max(0, maxPlayers - 1);
  int forcedTopBots = (botsNeeded * stakeScore * 0.80).round();
  if (stakeScore < 0.22) forcedTopBots = 0;
  forcedTopBots = forcedTopBots.clamp(0, botsNeeded);

  BotDifficulty botDifficulty = _botDifficultyForSubEvent(stakeScore);
  if (_subEventsUseLethalBots(group: group, kingdomName: canonical)) {
    botDifficulty = BotDifficulty.brutal;
    forcedTopBots = botsNeeded; // seed the table with top-lethality bots
  }

  return CampaignEventSpec(
    group: group,
    kingdomName: canonical,
    kind: CampaignEventKind.subKingdom,
    subKingdomIndex: subKingdomIndex,
    currency: main.currency,
    kingdomGoldMultiplier: main.kingdomGoldMultiplier,
    prizePool: prizePool,
    maxPlayers: maxPlayers,
    startingStack: startingStack,
    placesPaid: placesPaid,
    payoutTable: _subKingdomPayoutTable(prizePool: prizePool),
    botDifficulty: botDifficulty,
    forcedTopBots: forcedTopBots,
  );
}
