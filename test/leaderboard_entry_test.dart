import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/services/leaderboard_firestore_service.dart';

void main() {
  test('leaderboard Aura values are capped at 100 Aura', () {
    const entry = LeaderboardEntry(
      uid: 'player-1',
      displayName: 'Player One',
      auraMilli: 250000,
      totalAup: 2500000000,
      activityScore: 100,
    );

    expect(
      entry.cappedAuraMilli,
      aup.kAupMaxAuraTotal * aup.kAuraMilliPerAura,
    );
    expect(entry.aura, 100);
  });
}
