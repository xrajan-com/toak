import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/features/venue/game_mode.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen.dart';

void main() {
  test('Quick games stay six-max for onboarding', () {
    expect(
      GameScreen.resolvedTableMaxSeats(
        venueMode: VenueEntryMode.quickGame,
        campaignMainEvent: false,
        isFreeSubKingdom: false,
        campaignMaxPlayers: 10,
      ),
      6,
    );
  });

  test('Free sub-kingdom tables stay six-max for onboarding', () {
    expect(
      GameScreen.resolvedTableMaxSeats(
        venueMode: VenueEntryMode.career,
        campaignMainEvent: false,
        isFreeSubKingdom: true,
        campaignMaxPlayers: 8,
      ),
      6,
    );
  });

  test('Paid career tables keep their configured size', () {
    expect(
      GameScreen.resolvedTableMaxSeats(
        venueMode: VenueEntryMode.career,
        campaignMainEvent: false,
        isFreeSubKingdom: false,
        campaignMaxPlayers: 8,
      ),
      8,
    );
  });

  test('only career forts and main events are campaign reward games', () {
    expect(
      GameScreen.isCampaignEventConfiguration(
        venueMode: VenueEntryMode.career,
        campaignMainEvent: false,
        campaignSubKingdomIndex: 3,
      ),
      isTrue,
    );
    expect(
      GameScreen.isCampaignEventConfiguration(
        venueMode: VenueEntryMode.career,
        campaignMainEvent: true,
        campaignSubKingdomIndex: null,
      ),
      isTrue,
    );
    expect(
      GameScreen.isCampaignEventConfiguration(
        venueMode: VenueEntryMode.quickGame,
        campaignMainEvent: false,
        campaignSubKingdomIndex: null,
      ),
      isFalse,
    );
  });

  test('career fort second and third place winnings are wallet payouts', () {
    for (final rank in const <int>[2, 3]) {
      expect(
        GameScreen.shouldCreditCampaignPodiumPayout(
          venueMode: VenueEntryMode.career,
          campaignMainEvent: false,
          campaignSubKingdomIndex: 3,
          rank: rank,
          winnings: 1000,
        ),
        isTrue,
      );
    }
    expect(
      GameScreen.shouldCreditCampaignPodiumPayout(
        venueMode: VenueEntryMode.quickGame,
        campaignMainEvent: false,
        campaignSubKingdomIndex: null,
        rank: 2,
        winnings: 1000,
      ),
      isFalse,
    );
    expect(
      GameScreen.shouldCreditCampaignPodiumPayout(
        venueMode: VenueEntryMode.career,
        campaignMainEvent: true,
        campaignSubKingdomIndex: null,
        rank: 2,
        winnings: 1000,
      ),
      isFalse,
      reason: 'Main events are winner-take-all',
    );
    expect(
      GameScreen.shouldCreditCampaignPodiumPayout(
        venueMode: VenueEntryMode.career,
        campaignMainEvent: false,
        campaignSubKingdomIndex: 3,
        rank: 4,
        winnings: 0,
      ),
      isFalse,
    );
  });

  test('locked all-in runouts reveal every live hand before showdown', () {
    expect(
      GameScreen.shouldRevealAllHoleCards(
        atShowdown: false,
        bettingLockedRunout: true,
      ),
      isTrue,
    );
    expect(
      GameScreen.shouldRevealAllHoleCards(
        atShowdown: false,
        bettingLockedRunout: false,
      ),
      isFalse,
    );
  });
}
