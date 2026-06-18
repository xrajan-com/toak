import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/ui/utils/dealer_avatar_assignment.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/slash_avatar.dart';

void main() {
  test('dealer avatar styles are unique within each circuit', () {
    for (final VenueGroup group in kVenueGroups) {
      final styles = <DealerAvatarStyle>[
        for (final venue in venuesForGroup(group))
          dealerAvatarStyleForVenue(group: group, venueName: venue.name),
      ];

      expect(styles, hasLength(10),
          reason: 'Unexpected venue count for $group');
      expect(
        styles.toSet(),
        hasLength(styles.length),
        reason: 'Dealer avatar repeated within $group',
      );
    }
  });

  test('each free dealer avatar is assigned to two kingdoms in two circuits',
      () {
    final assignments =
        <DealerAvatarStyle, List<({VenueGroup group, String name})>>{};

    for (final VenueGroup group in kVenueGroups) {
      for (final venue in venuesForGroup(group)) {
        final style =
            dealerAvatarStyleForVenue(group: group, venueName: venue.name);
        assignments.putIfAbsent(
            style, () => <({VenueGroup group, String name})>[]);
        assignments[style]!.add((group: group, name: venue.name));
      }
    }

    expect(assignments.keys.toSet(), kFreeDealerAvatarStyles.toSet());

    for (final style in kFreeDealerAvatarStyles) {
      final styleAssignments = assignments[style] ?? const [];
      expect(
        styleAssignments,
        hasLength(2),
        reason: '$style should be reused by exactly two kingdoms',
      );
      expect(
        styleAssignments.map((assignment) => assignment.group).toSet(),
        hasLength(2),
        reason: '$style should not be reused inside one circuit',
      );
    }
  });
}
