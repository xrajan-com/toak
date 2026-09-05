// lib/game/bot/icm.dart
//
// Pure Independent Chip Model (ICM) equity calculation.
//
// Converts live tournament chip stacks into expected prize-money equity
// given a payout structure, using the standard Malmuth-Harville recursive
// model (the same approximation used by SNG/tournament ICM trainers). This
// file has no dependency on GameEngine so it is trivially unit-testable in
// isolation from the rest of the bot stack.
//
// See docs/BOT_HUMAN_INTELLIGENCE_AURA_SPEC.md for why this exists: bots
// currently reason purely in chip-EV, with zero awareness that a marginal
// +chip-EV shove can be -$EV near a payout jump. This is the primitive that
// fixes that; `tournament_context.dart` and `icm_guard.dart` are what wire
// it into live decisions.

/// Computes each player's ICM $ equity given their live chip stacks and the
/// payout amounts for finishing 1st, 2nd, 3rd, ... in order.
///
/// [stacks] must all be > 0 (already-eliminated players aren't part of this
/// calculation — the recursion below assigns a bust-to-zero seat exactly
/// its correct guaranteed last-place payout via the single-player base
/// case, so a hypothetical "loses this all-in" stack of 0 is handled
/// correctly if you do pass one in).
///
/// [payouts] should have at least as many entries as there are paid places;
/// any place beyond the list length implicitly pays 0. The list does not
/// need to be the same length as [stacks] — trailing unpaid places can be
/// omitted, or an explicit list of zeros can be passed, with the same
/// result either way.
///
/// Returns a list the same length as [stacks], in the same order, where
/// each value is that seat's expected prize money. The sum of the returned
/// list always equals the sum of the first `stacks.length` entries of
/// [payouts] (padded with 0) — this is the cheapest correctness check to
/// assert in tests.
List<double> icmEquities(List<int> stacks, List<int> payouts) {
  final int n = stacks.length;
  if (n == 0) return const <double>[];

  final Map<String, List<double>> memo = <String, List<double>>{};

  List<double> solve(List<int> remainingStacks, List<int> remainingPayouts) {
    final int m = remainingStacks.length;
    if (m == 0) return const <double>[];
    if (remainingPayouts.isEmpty) return List<double>.filled(m, 0.0);
    if (m == 1) return <double>[remainingPayouts.first.toDouble()];

    final String key = '${remainingStacks.join(',')}|${remainingPayouts.length}';
    final List<double>? cached = memo[key];
    if (cached != null) return cached;

    final int subTotal = remainingStacks.fold<int>(0, (a, b) => a + b);
    final List<double> equity = List<double>.filled(m, 0.0);
    if (subTotal <= 0) {
      memo[key] = equity;
      return equity;
    }

    for (int i = 0; i < m; i++) {
      final int stackI = remainingStacks[i];
      if (stackI <= 0) continue;
      final double pFirst = stackI / subTotal;
      if (pFirst <= 0) continue;
      equity[i] += pFirst * remainingPayouts.first;

      if (remainingPayouts.length > 1) {
        final List<int> nextStacks = <int>[
          ...remainingStacks.sublist(0, i),
          ...remainingStacks.sublist(i + 1),
        ];
        final List<int> nextPayouts = remainingPayouts.sublist(1);
        final List<double> subEquity = solve(nextStacks, nextPayouts);
        int k = 0;
        for (int j = 0; j < m; j++) {
          if (j == i) continue;
          equity[j] += pFirst * subEquity[k];
          k++;
        }
      }
    }
    memo[key] = equity;
    return equity;
  }

  return solve(stacks, payouts);
}

/// Convenience accessor for a single seat's ICM equity, given the full
/// (already-ordered) stacks list and payout list. [heroSlot] is an index
/// into [stacks], not a player id or seat number.
double icmEquityFor(int heroSlot, List<int> stacks, List<int> payouts) {
  final List<double> equities = icmEquities(stacks, payouts);
  if (heroSlot < 0 || heroSlot >= equities.length) return 0.0;
  return equities[heroSlot];
}
