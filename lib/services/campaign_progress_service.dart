import 'package:flutter/foundation.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';

class CampaignProgressService extends ChangeNotifier {
  final Set<String> _cleared = <String>{};
  final Set<String> _mainEventsCleared = <String>{};

  String subKingdomId({
    required VenueGroup group,
    required String kingdomName,
    required int subKingdomIndex,
  }) {
    final k = _slug(kingdomName);
    final i = subKingdomIndex < 1 ? 1 : subKingdomIndex;
    return 'sk:${group.name}:$k:$i';
  }

  bool isCleared({
    required VenueGroup group,
    required String kingdomName,
    required int subKingdomIndex,
  }) {
    return _cleared.contains(subKingdomId(
      group: group,
      kingdomName: kingdomName,
      subKingdomIndex: subKingdomIndex,
    ));
  }

  int clearedCount({
    required VenueGroup group,
    required String kingdomName,
  }) {
    final total = subKingdomCountFor(group: group, kingdomName: kingdomName);
    int count = 0;
    for (int i = 1; i <= total; i++) {
      if (isCleared(
          group: group, kingdomName: kingdomName, subKingdomIndex: i)) {
        count++;
      }
    }
    return count;
  }

  bool hasClearedAllSubKingdoms({
    required VenueGroup group,
    required String kingdomName,
  }) {
    final total = subKingdomCountFor(group: group, kingdomName: kingdomName);
    return clearedCount(group: group, kingdomName: kingdomName) >= total;
  }

  String mainEventId({
    required VenueGroup group,
    required String kingdomName,
  }) {
    final k = _slug(kingdomName);
    return 'me:${group.name}:$k';
  }

  bool isMainEventCleared({
    required VenueGroup group,
    required String kingdomName,
  }) {
    return _mainEventsCleared.contains(mainEventId(
      group: group,
      kingdomName: kingdomName,
    ));
  }

  void markMainEventCleared({
    required VenueGroup group,
    required String kingdomName,
  }) {
    final id = mainEventId(group: group, kingdomName: kingdomName);
    if (_mainEventsCleared.add(id)) {
      notifyListeners();
    }
  }

  bool hasTitle({
    required VenueGroup group,
    required String kingdomName,
  }) {
    return hasClearedAllSubKingdoms(group: group, kingdomName: kingdomName) &&
        isMainEventCleared(group: group, kingdomName: kingdomName);
  }

  bool isUnlocked({
    required VenueGroup group,
    required String kingdomName,
    required int subKingdomIndex,
  }) {
    final i = subKingdomIndex < 1 ? 1 : subKingdomIndex;
    if (i == 1) return true;
    return isCleared(
      group: group,
      kingdomName: kingdomName,
      subKingdomIndex: i - 1,
    );
  }

  void markCleared({
    required VenueGroup group,
    required String kingdomName,
    required int subKingdomIndex,
  }) {
    final id = subKingdomId(
      group: group,
      kingdomName: kingdomName,
      subKingdomIndex: subKingdomIndex,
    );
    if (_cleared.add(id)) {
      notifyListeners();
    }
  }

  int titlesEarned(VenueGroup group) {
    final venues =
        group == VenueGroup.india ? indianVenues : internationalVenues;
    int count = 0;
    for (final v in venues) {
      if (hasTitle(group: group, kingdomName: v.name)) count++;
    }
    return count;
  }

  static String _slug(String raw) {
    final lower = raw.trim().toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return replaced.replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
