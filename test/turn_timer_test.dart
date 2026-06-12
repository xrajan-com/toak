import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/turn_timer.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart'
    show VenueGroup, indianVenues;
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;

void main() {
  test('Main events use a 20s turn clock', () {
    expect(
      heroTurnTimeoutSeconds(
        group: VenueGroup.india,
        kingdomName: 'Baroda',
        isMainEvent: true,
      ),
      20,
    );
  });

  test('Sub-kingdom time is one of 10/15/20 and nondecreasing by prize tier',
      () {
    final group = VenueGroup.india;
    final kingdom = indianVenues.first.name;
    final order = aup.subKingdomIndicesByPrizeAup(
      group: group,
      kingdomName: kingdom,
    );
    expect(order.isNotEmpty, true);

    final low = order.first;
    final mid = order[order.length ~/ 2];
    final high = order.last;

    final tLow = heroTurnTimeoutSeconds(
      group: group,
      kingdomName: kingdom,
      isMainEvent: false,
      subKingdomIndex: low,
    );
    final tMid = heroTurnTimeoutSeconds(
      group: group,
      kingdomName: kingdom,
      isMainEvent: false,
      subKingdomIndex: mid,
    );
    final tHigh = heroTurnTimeoutSeconds(
      group: group,
      kingdomName: kingdom,
      isMainEvent: false,
      subKingdomIndex: high,
    );

    const allowed = <int>{10, 15, 20};
    expect(allowed.contains(tLow), true);
    expect(allowed.contains(tMid), true);
    expect(allowed.contains(tHigh), true);
    expect(tLow <= tMid && tMid <= tHigh, true);
  });

  test('Higher multiplier kingdoms are not faster than low multiplier kingdoms',
      () {
    final group = VenueGroup.india;

    String? lowMult;
    String? highMult;
    for (final v in indianVenues) {
      final m = ce.kingdomGoldMultiplier(group: group, kingdomName: v.name);
      if (m <= 3) lowMult ??= v.name;
      if (m >= 8) highMult ??= v.name;
    }

    expect(lowMult, isNotNull);
    expect(highMult, isNotNull);

    final lowOrder = aup.subKingdomIndicesByPrizeAup(
      group: group,
      kingdomName: lowMult!,
    );
    final highOrder = aup.subKingdomIndicesByPrizeAup(
      group: group,
      kingdomName: highMult!,
    );
    expect(lowOrder.isNotEmpty, true);
    expect(highOrder.isNotEmpty, true);

    final lowIdx = lowOrder[lowOrder.length ~/ 2];
    final highIdx = highOrder[highOrder.length ~/ 2];

    final tLow = heroTurnTimeoutSeconds(
      group: group,
      kingdomName: lowMult,
      isMainEvent: false,
      subKingdomIndex: lowIdx,
    );
    final tHigh = heroTurnTimeoutSeconds(
      group: group,
      kingdomName: highMult,
      isMainEvent: false,
      subKingdomIndex: highIdx,
    );

    expect(tHigh >= tLow, true);
  });
}
