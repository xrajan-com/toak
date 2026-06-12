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
}
