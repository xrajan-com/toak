import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show subKingdomCountFor, subKingdomNamesFor;
import 'package:ten_of_a_kind_poker/config/venues.dart'
    show VenueGroup, venuesForGroup;

const int kAupPerAura = 10000000;
const int kAuraMilliPerAura = 1000;
const int kAupMaxAuraPerCircuit = 25;
const int kAupMaxAuraTotal = 100;

const int kAupPerCircuit = 250000000;

/// All kingdom/event rewards are quantized to keep numbers easy to remember.
const int kAupRewardUnit = 1000;

/// Entry fees are also quantized to keep numbers easy to remember.
const int kAupEntryFeeUnit = kAupRewardUnit;

const int kAupMaxTotal = kAupPerCircuit * 4;
const int kRegisteredStarterAup = 10000;
const int kRewardedAdAupBonus = 2000;

// Entry fee tuning:
// - Sub‑kingdoms are cheaper to access (grindable).
// - Main events demand higher Aura (AUP) to enter.
const double _kSubEventEntryFeeFrac = 0.10;
const double _kMainEventEntryFeeFrac = 0.20;

const Map<VenueGroup, Map<String, int>> _kQuickGameEntryFees =
    <VenueGroup, Map<String, int>>{
  VenueGroup.india: <String, int>{
    'Baroda': 3000,
    'Hyderabad': 4000,
    'Indore': 3000,
    'Jaipur': 4000,
    'Maratha Empire': 4000,
    'Mysore': 3000,
    'New Delhi': 3000,
    'Sikh Empire': 4000,
    'Sikkim': 3000,
    'Travancore': 3000,
  },
  VenueGroup.international: <String, int>{
    'Africa': 3000,
    'Arabia': 3000,
    'Asia': 4000,
    'Australia': 3000,
    'China': 4000,
    'Europe': 4000,
    'India': 3000,
    'N. America': 4000,
    'Russia': 4000,
    'S. America': 3000,
  },
};

const Map<VenueGroup, Map<String, int>> _kKingdomPopularityWeights =
    <VenueGroup, Map<String, int>>{
  VenueGroup.india: <String, int>{
    'Sikh Empire': 150,
    'Jaipur': 138,
    'New Delhi': 134,
    'Maratha Empire': 130,
    'Mysore': 122,
    'Hyderabad': 118,
    'Baroda': 112,
    'Indore': 108,
    'Travancore': 102,
    'Sikkim': 96,
  },
  VenueGroup.international: <String, int>{
    'Europe': 150,
    'N. America': 144,
    'China': 136,
    'Far East': 130,
    'Arabia': 122,
    'Persia': 116,
    'Africa': 112,
    'S. America': 108,
    'Asia Rest': 104,
    'Central Asia': 98,
  },
  VenueGroup.euro: <String, int>{
    'Britain': 150,
    'France': 142,
    'Italy': 136,
    'Spain': 132,
    'Mediterranean': 128,
    'Russia & Siberia': 118,
    'Portugal': 114,
    'Scandinavia': 110,
    'Baltic Marches': 104,
    'North Sea': 100,
  },
  VenueGroup.oceania: <String, int>{
    'Caribbean': 142,
    'British Isles': 136,
    'Indian Ocean': 132,
    'Pacific': 124,
    'Alaska': 118,
    'Straits': 114,
    'French Isles': 110,
    'Dragonland': 108,
    'Dutch Isles': 104,
    'American Isles': 102,
  },
};

final Map<VenueGroup, Map<String, int>> _kingdomTotalsCache =
    <VenueGroup, Map<String, int>>{};

final Map<VenueGroup, Map<String, List<int>>> _subKingdomAupCache =
    <VenueGroup, Map<String, List<int>>>{};

final Map<VenueGroup, Map<String, List<int>>> _subKingdomPrizeOrderCache =
    <VenueGroup, Map<String, List<int>>>{};

String formatAup(int amount, {String locale = 'en_IN'}) {
  return NumberFormat.decimalPattern(locale).format(amount);
}

int auraFromAup(int aup) {
  if (aup <= 0) return 0;
  return (aup ~/ kAupPerAura);
}

int auraMilliFromAup(int aup) {
  if (aup <= 0) return 0;
  final int scaled = aup * kAuraMilliPerAura;
  final int rounded = scaled + (kAupPerAura ~/ 2);
  return rounded ~/ kAupPerAura;
}

double auraValueFromAup(int aup) {
  final milli = auraMilliFromAup(aup);
  return milli / kAuraMilliPerAura;
}

int aupForKingdomTotal({
  required VenueGroup group,
  required String kingdomName,
}) {
  final canonical =
      ce.canonicalKingdomName(group: group, kingdomName: kingdomName);
  final totals = _kingdomTotalsForGroup(group);
  return totals[canonical] ?? (kAupPerCircuit ~/ 10);
}

/// Minimal AUP fee for Quick Game venues that are otherwise open by default.
///
/// Fees intentionally vary by venue, but stay small enough that two rewarded
/// ads at [kRewardedAdAupBonus] can cover any Quick Game entry.
int entryFeeForQuickGameVenue({
  required VenueGroup group,
  required String venueName,
}) {
  final canonical =
      ce.canonicalKingdomName(group: group, kingdomName: venueName);
  return _kQuickGameEntryFees[group]?[canonical] ?? (kRewardedAdAupBonus * 2);
}

int aupForKingdomMainEvent({
  required VenueGroup group,
  required String kingdomName,
}) {
  // Main event is ~half of the total kingdom AUP budget, rounded to thousands.
  final total = aupForKingdomTotal(group: group, kingdomName: kingdomName);
  if (total <= 0) return 0;
  final half = total ~/ 2;
  final main = _roundToUnit(half, kAupRewardUnit).clamp(0, total);
  return main == 0 ? total : main;
}

int aupForSubKingdomEvent({
  required VenueGroup group,
  required String kingdomName,
  required int subKingdomIndex,
}) {
  final canonical =
      ce.canonicalKingdomName(group: group, kingdomName: kingdomName);
  final int idx = subKingdomIndex < 1 ? 1 : subKingdomIndex;
  final prizes =
      _subKingdomAupPrizesFor(group: group, canonicalKingdomName: canonical);
  if (prizes.isEmpty) return 0;
  return prizes[idx.clamp(1, prizes.length) - 1];
}

int _entryFeeFromPrize({
  required int prizeAup,
  required double fraction,
}) {
  if (prizeAup <= 0) return 0;
  if (fraction <= 0) return 0;
  // Floor keeps fee <= prize even after unit quantization.
  final int raw = (prizeAup * fraction).floor();
  final int fee = _roundToUnit(raw, kAupEntryFeeUnit).clamp(0, prizeAup);
  return fee;
}

/// Entry fee (AUP) required to enter the kingdom Main Event.
int entryFeeForKingdomMainEvent({
  required VenueGroup group,
  required String kingdomName,
}) {
  final prize = aupForKingdomMainEvent(group: group, kingdomName: kingdomName);
  return _entryFeeFromPrize(prizeAup: prize, fraction: _kMainEventEntryFeeFrac);
}

/// Entry fee (AUP) required to enter a Sub‑Kingdom match.
///
/// The lowest-prize sub‑kingdom is always free to enter so new/low‑Aura players
/// can grind.
int entryFeeForSubKingdomEvent({
  required VenueGroup group,
  required String kingdomName,
  required int subKingdomIndex,
}) {
  final canonical =
      ce.canonicalKingdomName(group: group, kingdomName: kingdomName);
  final prizes =
      _subKingdomAupPrizesFor(group: group, canonicalKingdomName: canonical);
  if (prizes.isEmpty) return 0;

  final int idx = subKingdomIndex < 1 ? 1 : subKingdomIndex;
  final int clamped = idx.clamp(1, prizes.length);
  if (clamped ==
      ce.freeSubKingdomIndexFor(group: group, kingdomName: canonical)) {
    return 0;
  }

  final prize = prizes[clamped - 1];
  return _entryFeeFromPrize(prizeAup: prize, fraction: _kSubEventEntryFeeFrac);
}

/// Returns sub‑kingdom indices (1-based) ordered by AUP prize, ascending.
///
/// The first index in this list is the free sub‑kingdom for that kingdom.
List<int> subKingdomIndicesByPrizeAup({
  required VenueGroup group,
  required String kingdomName,
}) {
  final canonical =
      ce.canonicalKingdomName(group: group, kingdomName: kingdomName);

  final byGroup = _subKingdomPrizeOrderCache.putIfAbsent(
    group,
    () => <String, List<int>>{},
  );
  final cached = byGroup[canonical];
  if (cached != null) return cached;

  final prizes =
      _subKingdomAupPrizesFor(group: group, canonicalKingdomName: canonical);
  if (prizes.isEmpty) return const <int>[];

  final order = List<int>.generate(prizes.length, (i) => i + 1);
  order.sort((a, b) {
    final pa = prizes[a - 1];
    final pb = prizes[b - 1];
    if (pa != pb) return pa.compareTo(pb);
    return a.compareTo(b);
  });
  final frozen = List<int>.unmodifiable(order);
  byGroup[canonical] = frozen;
  return frozen;
}

/// Returns the (1-based) sub‑kingdom index with the lowest AUP prize.
int freeSubKingdomIndexFor({
  required VenueGroup group,
  required String kingdomName,
}) {
  final order =
      subKingdomIndicesByPrizeAup(group: group, kingdomName: kingdomName);
  return order.isEmpty ? 1 : order.first;
}

List<int> _subKingdomAupPrizesFor({
  required VenueGroup group,
  required String canonicalKingdomName,
}) {
  final byGroup = _subKingdomAupCache.putIfAbsent(
    group,
    () => <String, List<int>>{},
  );
  final cached = byGroup[canonicalKingdomName];
  if (cached != null) return cached;

  final int count =
      subKingdomCountFor(group: group, kingdomName: canonicalKingdomName);
  if (count <= 0) return const <int>[];

  final int total =
      aupForKingdomTotal(group: group, kingdomName: canonicalKingdomName);
  final int main =
      aupForKingdomMainEvent(group: group, kingdomName: canonicalKingdomName);
  final int subTotal = (total - main).clamp(0, total);
  if (subTotal == 0) {
    final zeros = List<int>.filled(count, 0, growable: false);
    byGroup[canonicalKingdomName] = List<int>.unmodifiable(zeros);
    return byGroup[canonicalKingdomName]!;
  }

  final names =
      subKingdomNamesFor(group: group, kingdomName: canonicalKingdomName);
  final weights = <int>[
    for (int i = 1; i <= count; i++)
      _fortPopularityWeight(
        group: group,
        kingdomName: canonicalKingdomName,
        fortName: i <= names.length ? names[i - 1] : '',
        index: i,
      ),
  ];
  final amounts = _distributeByWeights(
    total: subTotal,
    weights: weights,
    seed: _fnv1a32('aup_rem|${group.name}|$canonicalKingdomName|v1'),
    unit: kAupRewardUnit,
  );
  byGroup[canonicalKingdomName] = amounts;
  return byGroup[canonicalKingdomName]!;
}

Map<String, int> _kingdomTotalsForGroup(VenueGroup group) {
  final cached = _kingdomTotalsCache[group];
  if (cached != null) return cached;

  final venues = venuesForGroup(group);
  final names = <String>{
    for (final v in venues)
      ce.canonicalKingdomName(group: group, kingdomName: v.name),
  }.where((n) => n.trim().isNotEmpty).toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final out = <String, int>{};
  if (names.isNotEmpty) {
    final weights = <int>[
      for (final k in names) _kingdomPopularityWeight(group: group, name: k),
    ];
    final amounts = _distributeByWeights(
      total: kAupPerCircuit,
      weights: weights,
      seed: _fnv1a32('aup_krem|${group.name}|v1'),
      unit: kAupRewardUnit,
    );
    for (int i = 0; i < names.length; i++) {
      out[names[i]] = amounts[i];
    }
  }

  final normalized = _makeKingdomTotalsUnique(
    group: group,
    totals: out,
    locked: const <String>{},
  );

  _kingdomTotalsCache[group] = Map<String, int>.unmodifiable(normalized);
  return _kingdomTotalsCache[group]!;
}

int _kingdomPopularityWeight({
  required VenueGroup group,
  required String name,
}) {
  final configured = _kKingdomPopularityWeights[group]?[name];
  if (configured != null) return configured;
  final multiplier = ce.kingdomGoldMultiplier(group: group, kingdomName: name);
  final texture = (_fnv1a32('aup_kw|${group.name}|$name|v2') % 17);
  return 90 + (multiplier * 4) + texture;
}

int _fortPopularityWeight({
  required VenueGroup group,
  required String kingdomName,
  required String fortName,
  required int index,
}) {
  final lower = fortName.toLowerCase();
  int weight =
      100 + (_fnv1a32('aup|${group.name}|$kingdomName|$index|v2') % 31);
  for (final entry in _kFortPopularityBoosts.entries) {
    if (lower.contains(entry.key)) weight += entry.value;
  }
  if (lower.contains('fort')) weight += 6;
  if (lower.contains('castle')) weight += 10;
  if (lower.contains('citadel') || lower.contains('fortress')) weight += 12;
  if (lower.contains('palace')) weight += 8;
  return weight.clamp(80, 360);
}

const Map<String, int> _kFortPopularityBoosts = <String, int>{
  'red fort': 130,
  'agra fort': 125,
  'tower of london': 125,
  'alhambra': 120,
  'edinburgh castle': 112,
  'windsor castle': 110,
  'himeji castle': 115,
  'osaka castle': 100,
  'lahore fort': 108,
  'galle fort': 105,
  'golconda fort': 100,
  'gwalior fort': 100,
  'chittorgarh fort': 105,
  'mehrangarh fort': 105,
  'kumbhalgarh fort': 100,
  'raigad fort': 98,
  'srirangapatna fort': 92,
  'san juan de ulua': 95,
  'castillo de san marcos': 105,
  'fort sumter': 98,
  'fort mchenry': 95,
  'the alamo': 110,
  'brimstone hill': 92,
  'fort jesus': 100,
  'castle of good hope': 96,
  'bahrain fort': 88,
  'masmak fort': 90,
  'erbil citadel': 86,
  'jiayu pass': 86,
  'xian city wall': 90,
  'suwon hwaseong': 90,
  'namhansanseong': 86,
  'itachan kala': 85,
  'itchan kala': 90,
  'merv': 84,
  'acropolis': 105,
  'castel santangelo': 95,
  'carcassonne': 100,
  'hohensalzburg': 92,
  'malbork': 105,
  'bran castle': 100,
  'suomenlinna': 88,
  'chateau de chambord': 100,
  'fort boyard': 92,
  'castel del monte': 94,
  'alcazar of segovia': 96,
  'belem tower': 92,
  'kronborg': 92,
  'moscow kremlin': 115,
  'peter and paul fortress': 95,
  'derbent fortress': 90,
  'acrocorinth': 88,
  'yedikule': 88,
  'predjama': 96,
  'fort siloso': 86,
  'fort cornwallis': 84,
  'jaffna fort': 86,
  'peel castle': 82,
};

Map<String, int> _makeKingdomTotalsUnique({
  required VenueGroup group,
  required Map<String, int> totals,
  required Set<String> locked,
}) {
  if (totals.length <= 1) return totals;
  if (totals.values.toSet().length == totals.length) return totals;

  final allKeys = totals.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final adjustable = allKeys.where((k) => !locked.contains(k)).toList();
  if (adjustable.length <= 1) return totals;

  final baseOffsets = _zeroSumOffsets(adjustable.length);
  for (int step = 1; step <= 5000; step++) {
    final candidate = Map<String, int>.from(totals);
    for (int i = 0; i < adjustable.length; i++) {
      candidate[adjustable[i]] =
          candidate[adjustable[i]]! + baseOffsets[i] * step * kAupRewardUnit;
    }

    if (candidate.values.any((v) => v <= 0)) continue;
    if (candidate.values.fold<int>(0, (a, b) => a + b) != kAupPerCircuit) {
      continue;
    }
    if (candidate.values.toSet().length != candidate.length) continue;
    return candidate;
  }

  // If uniqueness can't be achieved safely, keep the original totals.
  return totals;
}

List<int> _zeroSumOffsets(int n) {
  if (n <= 0) return const <int>[];
  if (n == 1) return const <int>[0];

  if (n.isOdd) {
    final k = n ~/ 2;
    return <int>[for (int i = -k; i <= k; i++) i];
  }

  final k = n ~/ 2;
  return <int>[
    for (int i = 1; i <= k; i++) -i,
    for (int i = 1; i <= k; i++) i,
  ];
}

List<int> _distributeByWeights({
  required int total,
  required List<int> weights,
  required int seed,
  int unit = 1,
}) {
  final safeUnit = unit <= 1 ? 1 : unit;
  if (weights.isEmpty) return const <int>[];
  if (total <= 0) return List<int>.filled(weights.length, 0, growable: false);

  if (safeUnit != 1 && total % safeUnit == 0) {
    final units = _distributeByWeights(
      total: total ~/ safeUnit,
      weights: weights,
      seed: seed,
    );
    return List<int>.unmodifiable([for (final u in units) u * safeUnit]);
  }

  int sum = 0;
  for (final w in weights) {
    if (w > 0) sum += w;
  }
  if (sum <= 0) return List<int>.filled(weights.length, 0, growable: false);

  final out = <int>[];
  int acc = 0;
  for (final w in weights) {
    final int safeW = w <= 0 ? 0 : w;
    final int v = ((total * safeW) / sum).floor();
    out.add(v);
    acc += v;
  }

  int rem = total - acc;
  if (rem <= 0) return List<int>.unmodifiable(out);

  final order = List<int>.generate(out.length, (i) => i);
  order.shuffle(math.Random(seed));
  int oi = 0;
  while (rem-- > 0) {
    out[order[oi++ % order.length]] += 1;
  }
  return List<int>.unmodifiable(out);
}

int _fnv1a32(String s) {
  var hash = 0x811c9dc5;
  for (final cu in s.codeUnits) {
    hash ^= cu;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

int _roundToUnit(int amount, int unit) {
  if (unit <= 0) return amount;
  if (amount == 0) return 0;
  final int u = unit.abs();
  final int half = u ~/ 2;
  if (amount > 0) return ((amount + half) ~/ u) * u;
  return -(((-amount + half) ~/ u) * u);
}
