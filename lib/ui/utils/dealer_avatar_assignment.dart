import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/slash_avatar.dart'
    show DealerAvatarStyle;

const List<DealerAvatarStyle> kFreeDealerAvatarStyles = <DealerAvatarStyle>[
  DealerAvatarStyle.baroda,
  DealerAvatarStyle.hyderabad,
  DealerAvatarStyle.indore,
  DealerAvatarStyle.jaipur,
  DealerAvatarStyle.marathaEmpire,
  DealerAvatarStyle.mysore,
  DealerAvatarStyle.newDelhi,
  DealerAvatarStyle.sikhEmpire,
  DealerAvatarStyle.sikkim,
  DealerAvatarStyle.travancore,
  DealerAvatarStyle.africa,
  DealerAvatarStyle.southAmerica,
  DealerAvatarStyle.northAmerica,
  DealerAvatarStyle.arabia,
  DealerAvatarStyle.australia,
  DealerAvatarStyle.china,
  DealerAvatarStyle.europe,
  DealerAvatarStyle.india,
  DealerAvatarStyle.russia,
  DealerAvatarStyle.asia,
];

const Map<VenueGroup, Map<String, DealerAvatarStyle>>
    kDealerAvatarStylesByVenue = <VenueGroup, Map<String, DealerAvatarStyle>>{
  VenueGroup.india: <String, DealerAvatarStyle>{
    'Baroda': DealerAvatarStyle.baroda,
    'Hyderabad': DealerAvatarStyle.hyderabad,
    'Indore': DealerAvatarStyle.indore,
    'Jaipur': DealerAvatarStyle.jaipur,
    'Maratha Empire': DealerAvatarStyle.marathaEmpire,
    'Mysore': DealerAvatarStyle.mysore,
    'New Delhi': DealerAvatarStyle.newDelhi,
    'Sikh Empire': DealerAvatarStyle.sikhEmpire,
    'Sikkim': DealerAvatarStyle.sikkim,
    'Travancore': DealerAvatarStyle.travancore,
  },
  VenueGroup.international: <String, DealerAvatarStyle>{
    'Africa': DealerAvatarStyle.africa,
    'S. America': DealerAvatarStyle.southAmerica,
    'N. America': DealerAvatarStyle.northAmerica,
    'Arabia': DealerAvatarStyle.arabia,
    'China': DealerAvatarStyle.china,
    'Far East': DealerAvatarStyle.australia,
    'Asia Rest': DealerAvatarStyle.asia,
    'Central Asia': DealerAvatarStyle.russia,
    'Persia': DealerAvatarStyle.india,
    'Europe': DealerAvatarStyle.europe,
  },
  VenueGroup.euro: <String, DealerAvatarStyle>{
    'Britain': DealerAvatarStyle.baroda,
    'France': DealerAvatarStyle.hyderabad,
    'Italy': DealerAvatarStyle.indore,
    'Spain': DealerAvatarStyle.jaipur,
    'Portugal': DealerAvatarStyle.marathaEmpire,
    'North Sea': DealerAvatarStyle.mysore,
    'Scandinavia': DealerAvatarStyle.newDelhi,
    'Baltic Marches': DealerAvatarStyle.sikhEmpire,
    'Russia & Siberia': DealerAvatarStyle.sikkim,
    'Mediterranean': DealerAvatarStyle.travancore,
  },
  VenueGroup.oceania: <String, DealerAvatarStyle>{
    'Alaska': DealerAvatarStyle.africa,
    'Caribbean': DealerAvatarStyle.southAmerica,
    'Dragonland': DealerAvatarStyle.northAmerica,
    'Straits': DealerAvatarStyle.arabia,
    'Indian Ocean': DealerAvatarStyle.china,
    'Pacific': DealerAvatarStyle.australia,
    'British Isles': DealerAvatarStyle.asia,
    'French Isles': DealerAvatarStyle.russia,
    'Dutch Isles': DealerAvatarStyle.india,
    'American Isles': DealerAvatarStyle.europe,
  },
  VenueGroup.northAmerica: <String, DealerAvatarStyle>{
    'Dominion of Canada': DealerAvatarStyle.northAmerica,
    'Massachusetts': DealerAvatarStyle.baroda,
    'New York': DealerAvatarStyle.europe,
    'Virginia': DealerAvatarStyle.india,
    'Illinois': DealerAvatarStyle.hyderabad,
    'Florida': DealerAvatarStyle.southAmerica,
    'Texas': DealerAvatarStyle.arabia,
    'Kansas': DealerAvatarStyle.russia,
    'Colorado': DealerAvatarStyle.africa,
    'California': DealerAvatarStyle.australia,
  },
};

DealerAvatarStyle dealerAvatarStyleForVenue({
  VenueGroup? group,
  required String venueName,
}) {
  final String key = _canonicalVenueKey(venueName);
  if (group != null) {
    final DealerAvatarStyle? style = _styleForGroup(group, key);
    if (style != null) return style;
  }

  for (final VenueGroup fallbackGroup in kVenueGroups) {
    final DealerAvatarStyle? style = _styleForGroup(fallbackGroup, key);
    if (style != null) return style;
  }

  return _legacyDealerAvatarStyleForVenue(key);
}

DealerAvatarStyle? _styleForGroup(VenueGroup group, String canonicalName) {
  final Map<String, DealerAvatarStyle>? styles =
      kDealerAvatarStylesByVenue[group];
  if (styles == null) return null;
  for (final MapEntry<String, DealerAvatarStyle> entry in styles.entries) {
    if (_canonicalVenueKey(entry.key) == canonicalName) return entry.value;
  }
  return null;
}

DealerAvatarStyle _legacyDealerAvatarStyleForVenue(String key) {
  if (key.contains('baroda')) return DealerAvatarStyle.baroda;
  if (key.contains('hyderabad')) return DealerAvatarStyle.hyderabad;
  if (key.contains('indore')) return DealerAvatarStyle.indore;
  if (key.contains('jaipur')) return DealerAvatarStyle.jaipur;
  if (key.contains('maratha')) return DealerAvatarStyle.marathaEmpire;
  if (key.contains('mysore')) return DealerAvatarStyle.mysore;
  if (key.contains('new delhi') || key.contains('delhi')) {
    return DealerAvatarStyle.newDelhi;
  }
  if (key.contains('sikh')) return DealerAvatarStyle.sikhEmpire;
  if (key.contains('sikkim')) return DealerAvatarStyle.sikkim;
  if (key.contains('travancore')) return DealerAvatarStyle.travancore;

  if (key.contains('africa')) return DealerAvatarStyle.africa;
  if (key.contains('s. america') ||
      key.contains('south america') ||
      key.contains('amazon')) {
    return DealerAvatarStyle.southAmerica;
  }
  if (key.contains('n. america') || key.contains('north america')) {
    return DealerAvatarStyle.northAmerica;
  }
  if (key.contains('arabia') || key.contains('persia')) {
    return DealerAvatarStyle.arabia;
  }
  if (key.contains('australia')) return DealerAvatarStyle.australia;
  if (key.contains('china') || key.contains('far east')) {
    return DealerAvatarStyle.china;
  }
  if (key.contains('europe')) return DealerAvatarStyle.europe;
  if (key == 'india') return DealerAvatarStyle.india;
  if (key.contains('russia')) return DealerAvatarStyle.russia;
  if (key.contains('asia') || key.contains('southeast')) {
    return DealerAvatarStyle.asia;
  }

  return DealerAvatarStyle.india;
}

String _canonicalVenueKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
