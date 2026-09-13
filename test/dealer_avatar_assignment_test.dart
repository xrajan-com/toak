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

      expect(styles, hasLength(venuesForGroup(group).length),
          reason: 'Unexpected venue count for $group');
      expect(
        styles.toSet(),
        hasLength(styles.length),
        reason: 'Dealer avatar repeated within $group',
      );
    }
  });

  test('free dealer avatars are balanced across two or three circuits', () {
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
        hasLength(anyOf(2, 3)),
        reason: '$style should be reused by two or three kingdoms',
      );
      expect(
        styleAssignments.map((assignment) => assignment.group).toSet(),
        hasLength(styleAssignments.length),
        reason: '$style should not be reused inside one circuit',
      );
    }
  });
}
