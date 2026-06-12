import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/venues.dart' show VenueGroup;
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;

const int kHeroTurnTimeoutDefaultSeconds = 15;

/// Returns the per-turn hero action timeout in seconds.
///
/// The timeout is always one of {10, 15, 20}. When the timer expires, the hero
/// should auto-fold if they still haven't acted.
///
/// Rules:
/// - Main events are always 20s.
/// - Sub-kingdoms use a prize-tier (low/mid/high) derived from that kingdom’s
///   AUP sub-kingdom prize distribution, with a small bias based on the
///   kingdom’s gold multiplier so different kingdoms can feel faster/slower.
int heroTurnTimeoutSeconds({
  required VenueGroup? group,
  required String kingdomName,
  required bool isMainEvent,
  int? subKingdomIndex,
}) {
  final t = kingdomName.trim();
  if (t.isEmpty) return kHeroTurnTimeoutDefaultSeconds;
  if (isMainEvent) return 20;
  if (group == null || subKingdomIndex == null) {
    return kHeroTurnTimeoutDefaultSeconds;
  }

  final order = aup.subKingdomIndicesByPrizeAup(group: group, kingdomName: t);
  if (order.isEmpty) return kHeroTurnTimeoutDefaultSeconds;

  final int count = order.length;
  final int pos = order.indexOf(subKingdomIndex);
  final int safePos =
      pos >= 0 ? pos : (subKingdomIndex - 1).clamp(0, count - 1);

  // Base tier by relative prize rank: 0=low, 1=mid, 2=high.
  final int baseTier = (safePos * 3) ~/ count;

  // Bias by kingdom multiplier so different kingdoms land on different timers.
  final int mult =
      ce.kingdomGoldMultiplier(group: group, kingdomName: t).clamp(1, 10);
  final int bias = mult <= 3
      ? -1
      : mult >= 8
          ? 1
          : 0;

  final int tier = (baseTier + bias).clamp(0, 2);
  return switch (tier) { 0 => 10, 1 => 15, _ => 20 };
}
