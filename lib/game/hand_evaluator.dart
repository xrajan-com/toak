// lib/game/hand_evaluator.dart
//
// Standalone hand evaluator (best 5 of 7) for Hold’em-style games.
// Depends only on core.dart for Card/Suit/Rank + rankValue.

import 'core.dart' show Card, Suit, rankValue;
import 'dart:math' show min;

/// Hand strength buckets (weakest → strongest)
enum HandCategory {
  highCard,
  pair,
  twoPair,
  threeKind,
  straight,
  flush,
  fullHouse,
  fourKind,
  straightFlush,
}

/// Comparable result of a 5-card hand selection.
/// - `category` decides the main rank
/// - `tiebreakers` are descending high-card values specific to the category
/// - `bestFive` are the exact 5 cards chosen (useful for UI)
class HandRank implements Comparable<HandRank> {
  final HandCategory category;
  final List<int> tiebreakers; // descending priority
  final String name; // e.g. "Two Pair", "Flush"
  final List<Card> bestFive; // exact 5 used

  const HandRank(this.category, this.tiebreakers, this.name, this.bestFive);

  @override
  int compareTo(HandRank other) {
    if (category.index != other.category.index) {
      return category.index.compareTo(other.category.index);
    }
    final n = min(tiebreakers.length, other.tiebreakers.length);
    for (var i = 0; i < n; i++) {
      final d = tiebreakers[i].compareTo(other.tiebreakers[i]);
      if (d != 0) return d;
    }
    return 0;
  }

  @override
  String toString() => '$name $tiebreakers (${bestFive.join(" ")})';
}

class HandEvaluator {
  /// Evaluate best 5 out of `seven` (2 hole + 5 board typical).
  static HandRank evaluate(List<Card> seven) {
    if (seven.length < 5) {
      throw ArgumentError('Need at least 5 cards to evaluate');
    }

    int rv(Card c) => rankValue(c.rank);

    List<Card> sortDesc(List<Card> cards) =>
        (cards.toList()..sort((a, b) => rv(b).compareTo(rv(a))));

    // Build indexes by rank and suit
    final byRank = <int, List<Card>>{};
    final bySuit = <Suit, List<Card>>{};
    for (final c in seven) {
      final v = rv(c);
      (byRank[v] ??= <Card>[]).add(c);
      (bySuit[c.suit] ??= <Card>[]).add(c);
    }

    List<int> uniqueRanksDesc(Iterable<int> values) {
      final s = {...values};
      final out = s.toList()..sort((a, b) => b.compareTo(a));
      return out;
    }

    // Return high card of a straight if present, else null.
    // Supports wheel: A (14) can count as 1.
    int? straightHighFromRanks(List<int> ranksDesc) {
      final set = ranksDesc.toSet();
      final r = set.toList()..sort((a, b) => b.compareTo(a));
      if (set.contains(14)) {
        r.add(1); // Ace as 1 for wheels
        r.sort((a, b) => b.compareTo(a));
      }
      int streak = 1;
      for (int i = 0; i < r.length - 1; i++) {
        if (r[i] - 1 == r[i + 1]) {
          streak++;
          if (streak >= 5) return r[i - 3]; // high card when 5 reached
        } else if (r[i] != r[i + 1]) {
          streak = 1;
        }
      }
      return null;
    }

    // ---------- Straight Flush ----------
    List<Card>? flushCards;
    for (final e in bySuit.entries) {
      if (e.value.length >= 5) {
        flushCards = sortDesc(e.value);
        break;
      }
    }
    if (flushCards != null) {
      final ranks = flushCards.map(rv).toList();
      final sfHigh = straightHighFromRanks(ranks);
      if (sfHigh != null) {
        final ranksSet = flushCards.map(rv).toSet();
        final seq = _straightSequence(sfHigh, ranksSet);
        final bestFive = _pickSequenceCards(flushCards, seq);
        return HandRank(
          HandCategory.straightFlush,
          [sfHigh],
          sfHigh == 14 ? 'Royal Flush' : 'Straight Flush',
          bestFive,
        );
      }
    }

    // ---------- Four of a Kind ----------
    final quads = byRank.entries
        .where((e) => e.value.length == 4)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (quads.isNotEmpty) {
      final q = quads.first;
      final kickers =
          uniqueRanksDesc(byRank.keys).where((v) => v != q).toList();
      final bestFive = [
        ...byRank[q]!.take(4),
        _highestCard(seven.where((c) => rv(c) != q)),
      ];
      return HandRank(
        HandCategory.fourKind,
        [q, kickers.first],
        'Four of a Kind',
        bestFive,
      );
    }

    // Groupings for trips/pairs
    final trips = byRank.entries
        .where((e) => e.value.length == 3)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final pairs = byRank.entries
        .where((e) => e.value.length == 2)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => b.compareTo(a));

    // ---------- Full House ----------
    if (trips.isNotEmpty && (pairs.isNotEmpty || trips.length >= 2)) {
      final topTrip = trips.first;
      final altTripAsPair = trips.where((t) => t != topTrip).toList();
      final pairPart = pairs.isNotEmpty
          ? pairs.first
          : (altTripAsPair.isNotEmpty ? altTripAsPair.first : null);
      if (pairPart != null) {
        final bestFive = [
          ...byRank[topTrip]!.take(3),
          ...byRank[pairPart]!.take(2),
        ];
        return HandRank(
          HandCategory.fullHouse,
          [topTrip, pairPart],
          'Full House',
          bestFive,
        );
      }
    }

    // ---------- Flush ----------
    if (flushCards != null) {
      final bestFive = flushCards.take(5).toList();
      final tiebreakers = bestFive.map(rv).toList();
      return HandRank(HandCategory.flush, tiebreakers, 'Flush', bestFive);
    }

    // ---------- Straight (any suits) ----------
    final allRanksDesc = uniqueRanksDesc(byRank.keys);
    final straightHigh = straightHighFromRanks(allRanksDesc);
    if (straightHigh != null) {
      final seq = _straightSequence(straightHigh, allRanksDesc.toSet());
      final bestFive = _pickSequenceCards(sortDesc(seven), seq);
      return HandRank(
          HandCategory.straight, [straightHigh], 'Straight', bestFive);
    }

    // ---------- Three of a Kind ----------
    if (trips.isNotEmpty) {
      final t = trips.first;

      // pick top 2 kickers from non-trip cards
      final nonTrip = seven.where((c) => rv(c) != t).toList()
        ..sort((a, b) => rv(b).compareTo(rv(a)));
      final k1 = nonTrip.isNotEmpty ? nonTrip[0] : seven.first;
      final k2 = nonTrip.length > 1 ? nonTrip[1] : seven.last;

      final bestFive = [
        ...byRank[t]!.take(3),
        k1,
        k2,
      ];

      final kickersRanks = [rv(k1), rv(k2)];
      return HandRank(
        HandCategory.threeKind,
        [t, ...kickersRanks],
        'Three of a Kind',
        bestFive,
      );
    }

    // ---------- Two Pair ----------
    if (pairs.length >= 2) {
      final a = pairs[0], b = pairs[1];
      final kicker = allRanksDesc.firstWhere((v) => v != a && v != b);
      final bestFive = [
        ...byRank[a]!.take(2),
        ...byRank[b]!.take(2),
        _highestCard(seven.where((c) => rv(c) != a && rv(c) != b)),
      ];
      return HandRank(
          HandCategory.twoPair, [a, b, kicker], 'Two Pair', bestFive);
    }

    // ---------- One Pair ----------
    if (pairs.length == 1) {
      final p = pairs.first;
      final kickers = allRanksDesc.where((v) => v != p).take(3).toList();
      final bestFive = [
        ...byRank[p]!.take(2),
        ..._highestNCards(seven.where((c) => rv(c) != p), 3),
      ];
      return HandRank(HandCategory.pair, [p, ...kickers], 'One Pair', bestFive);
    }

    // ---------- High Card ----------
    final top5 = _highestNCards(seven, 5);
    final tiebreakers = top5.map(rv).toList();
    return HandRank(HandCategory.highCard, tiebreakers, 'High Card', top5);
  }

  // ---------- Helpers ----------

  static Card _highestCard(Iterable<Card> cards) {
    Card? best;
    for (final c in cards) {
      if (best == null || rankValue(c.rank) > rankValue(best.rank)) best = c;
    }
    if (best == null) {
      throw StateError('No cards');
    }
    return best;
  }

  static List<Card> _highestNCards(Iterable<Card> cards, int n) {
    final list = cards.toList()
      ..sort((a, b) => rankValue(b.rank).compareTo(rankValue(a.rank)));
    return list.take(n).toList();
  }

  /// Build the straight sequence ranks expected for a given high card.
  /// Handles wheel: if `high == 5` and Ace (14) exists, sequence is [5,4,3,2,1].
  static List<int> _straightSequence(int high, Set<int> ranksSet) {
    if (high == 5 && ranksSet.contains(14)) {
      return [5, 4, 3, 2, 1];
    }
    return [high, high - 1, high - 2, high - 3, high - 4];
  }

  /// Given cards sorted descending and a target straight sequence, pick the 5 exact cards.
  /// Treat Ace(14) as rank 1 when the sequence contains 1 (wheel).
  static List<Card> _pickSequenceCards(List<Card> sortedDesc, List<int> seq) {
    final need = seq.toList();
    final out = <Card>[];
    for (final c in sortedDesc) {
      final v = rankValue(c.rank);
      // Ace as 1 for wheel
      if (v == 14 && need.contains(1) && !out.contains(c)) {
        out.add(c);
        need.remove(1);
      } else if (need.contains(v)) {
        out.add(c);
        need.remove(v);
      }
      if (need.isEmpty) break;
    }
    return out.take(5).toList();
  }
}
