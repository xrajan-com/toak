import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/kingdom_titles.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/game/models.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';

void main() {
  test('fort venue IDs and fully qualified names are globally unique', () {
    final progress = CampaignProgressService();
    final ids = <String>{};
    final origins = <String, String>{};

    for (final group in kVenueGroups) {
      for (final venue in venuesForGroup(group)) {
        final names = subKingdomNamesFor(
          group: group,
          kingdomName: venue.name,
        );
        for (var i = 0; i < names.length; i++) {
          final name = names[i];
          final key = _fortNameKey(name);
          final origin = '${group.name}:${venue.name}';
          expect(
            origins[key],
            isNull,
            reason: '$name in $origin duplicates ${origins[key]}',
          );
          origins[key] = origin;

          final id = progress.subKingdomId(
            group: group,
            kingdomName: venue.name,
            subKingdomIndex: i + 1,
          );
          expect(ids.add(id), isTrue, reason: 'duplicate venue ID: $id');
        }
      }
    }

    expect(ids, hasLength(500));
  });

  test('complete career catalog is reachable and awards every title', () {
    const expectedFortCounts = <VenueGroup, int>{
      VenueGroup.euro: 93,
      VenueGroup.india: 89,
      VenueGroup.international: 88,
      VenueGroup.oceania: 100,
      VenueGroup.northAmerica: 130,
    };
    final progress = CampaignProgressService();
    int totalForts = 0;
    int totalTitles = 0;

    expect(kVenueGroups, hasLength(5));

    for (final group in kVenueGroups) {
      final venues = venuesForGroup(group);
      expect(venues, hasLength(10), reason: '${group.name} kingdom count');
      expect(kKingdomTitles[group], hasLength(10),
          reason: '${group.name} title count');

      int circuitBalance = aup.kRegisteredStarterAup ~/ kVenueGroups.length;
      int circuitForts = 0;

      for (final venue in venues) {
        final names = subKingdomNamesFor(
          group: group,
          kingdomName: venue.name,
        );
        final fortCount = subKingdomCountFor(
          group: group,
          kingdomName: venue.name,
        );
        final order = ce.subKingdomIndicesByPrizePool(
          group: group,
          kingdomName: venue.name,
        );

        expect(names, hasLength(fortCount),
            reason: '${group.name}:${venue.name} must not use fallback forts');
        expect(names.toSet(), hasLength(fortCount),
            reason: '${group.name}:${venue.name} duplicate fort names');
        expect(
            order.toSet(),
            {
              for (int index = 1; index <= fortCount; index++) index,
            },
            reason: '${group.name}:${venue.name} display order');
        expect(
          ce.freeSubKingdomIndexFor(
            group: group,
            kingdomName: venue.name,
          ),
          order.first,
          reason: '${group.name}:${venue.name} free fort',
        );

        final freePrizePool = aup.aupForSubKingdomEvent(
          group: group,
          kingdomName: venue.name,
          subKingdomIndex: order.first,
        );
        final freeFirstPrize = PayoutTable.fromPercentages(
          freePrizePool,
          const <double>[0.60, 0.25, 0.15],
        ).pays(1);
        expect(freeFirstPrize, greaterThan(0));

        for (final fortIndex in order) {
          expect(
            progress.isUnlocked(
              group: group,
              kingdomName: venue.name,
              subKingdomIndex: fortIndex,
            ),
            isTrue,
            reason:
                '${group.name}:${venue.name}:$fortIndex should be sequence-independent',
          );
        }

        for (int position = 0; position < order.length; position++) {
          final fortIndex = order[position];
          final fee = aup.entryFeeForSubKingdomEvent(
            group: group,
            kingdomName: venue.name,
            subKingdomIndex: fortIndex,
          );
          int freeFortReplays = 0;
          while (circuitBalance < fee) {
            circuitBalance =
                (circuitBalance + freeFirstPrize).clamp(0, aup.kAupPerCircuit);
            freeFortReplays += 1;
            expect(
              freeFortReplays,
              lessThan(1000),
              reason: '${group.name}:${venue.name} cannot grind entry $fee',
            );
          }
          expect(
            circuitBalance,
            greaterThanOrEqualTo(fee),
            reason:
                '${group.name}:${venue.name}:$fortIndex cannot afford $fee AUP',
          );
          circuitBalance -= fee;

          final prizePool = aup.aupForSubKingdomEvent(
            group: group,
            kingdomName: venue.name,
            subKingdomIndex: fortIndex,
          );
          final firstPrize = PayoutTable.fromPercentages(
            prizePool,
            const <double>[0.60, 0.25, 0.15],
          ).pays(1);
          expect(firstPrize, greaterThan(0),
              reason: '${group.name}:${venue.name}:$fortIndex first prize');
          circuitBalance =
              (circuitBalance + firstPrize).clamp(0, aup.kAupPerCircuit);

          progress.markCleared(
            group: group,
            kingdomName: venue.name,
            subKingdomIndex: fortIndex,
          );
        }

        expect(
          progress.hasClearedAllSubKingdoms(
            group: group,
            kingdomName: venue.name,
          ),
          isTrue,
          reason: '${group.name}:${venue.name} fort completion',
        );

        final mainFee = aup.entryFeeForKingdomMainEvent(
          group: group,
          kingdomName: venue.name,
        );
        expect(
          circuitBalance,
          greaterThanOrEqualTo(mainFee),
          reason: '${group.name}:${venue.name} cannot afford main event',
        );
        circuitBalance -= mainFee;
        circuitBalance = (circuitBalance +
                aup.aupForKingdomMainEvent(
                  group: group,
                  kingdomName: venue.name,
                ))
            .clamp(0, aup.kAupPerCircuit);

        progress.markMainEventCleared(
          group: group,
          kingdomName: venue.name,
        );
        expect(
          progress.hasTitle(group: group, kingdomName: venue.name),
          isTrue,
          reason: '${group.name}:${venue.name} title',
        );
        expect(
          kingdomTitleFor(group: group, kingdomName: venue.name),
          isNot('N/A'),
          reason: '${group.name}:${venue.name} title label',
        );

        circuitForts += fortCount;
        totalTitles += 1;
      }

      expect(progress.titlesEarned(group), 10,
          reason: '${group.name} completed titles');
      expect(circuitForts, lessThanOrEqualTo(500),
          reason: '${group.name} exceeds Firestore cleared-list limit');
      expect(circuitForts, expectedFortCounts[group],
          reason: '${group.name} configured fort inventory');
      expect(circuitBalance, inInclusiveRange(0, aup.kAupPerCircuit));
      totalForts += circuitForts;
    }

    expect(totalTitles, 50);
    expect(totalForts, 500);
  });
}

String _fortNameKey(String raw) {
  return raw
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('’', '')
      .replaceAll("'", '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}
