/// How a kingdom's forts look in the art the app draws itself: the fort
/// behind the table (fort_backdrop.dart) and the emblem on the felt
/// (fort_emblem.dart). See docs/ART_DIRECTION.md.
enum FortStyle {
  /// Square merlons and round arches: Europe, the Americas, Africa south of
  /// the Sahara, Oceania and the isles.
  classic,

  /// Rounded merlons, domed pavilions and pointed arches: the Indian Ocean
  /// circuit's kingdoms, Arabia, Persia, Central Asia and North Africa.
  domed,

  /// Tiered, upturned roofs instead of merlons: China, Japan, Korea, Taiwan,
  /// Vietnam, the Mekong and Sikkim.
  eastern,
}

const Set<String> _kDomedKingdoms = <String>{
  'Baroda',
  'Hyderabad',
  'Indore',
  'Jaipur',
  'Maratha Empire',
  'Mysore',
  'New Delhi',
  'Sikh Empire',
  'Travancore',
  'Arabia',
  'Persia & Mesopotamia',
  'Central Asia',
  'North Africa',
  'Indian Ocean Isles',
};

const Set<String> _kEasternKingdoms = <String>{
  'China',
  'Japan',
  'Korea',
  'Taiwan',
  'Vietnam',
  'Mekong',
  'Sikkim',
};

/// The fort style for a kingdom, by its name as the venue list spells it.
/// Unknown names, and no name at all, get [FortStyle.classic].
FortStyle fortStyleForKingdom(String? kingdomName) {
  final String name = (kingdomName ?? '').trim();
  if (_kDomedKingdoms.contains(name)) return FortStyle.domed;
  if (_kEasternKingdoms.contains(name)) return FortStyle.eastern;
  return FortStyle.classic;
}

/// A small, stable number from [text], for picking variations of the art
/// (tower heights, star fields) that stay the same every time a fort is
/// drawn. String.hashCode is not promised to be stable across runs.
int stableArtSeed(String text) {
  int hash = 17;
  for (final int unit in text.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}
