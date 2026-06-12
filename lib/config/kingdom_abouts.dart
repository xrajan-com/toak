import 'package:ten_of_a_kind_poker/config/venues.dart';

/// Short, coat-of-arms-style mottos for each kingdom (≤ 30 chars).
const Map<VenueGroup, Map<String, String>> kKingdomAbouts = {
  VenueGroup.india: <String, String>{
    'Baroda': 'Gilded Value, Steady Hands',
    'Hyderabad': 'Pearl City, Royal Pressure',
    'Indore': 'Mercantile Edge, Clean Value',
    'Jaipur': 'Royal Range, Fortified Nerves',
    'Maratha Empire': 'Fortified Steel, Turn Dominion',
    'Mysore': 'Palace Poise, Tiger Value',
    'New Delhi': 'Capital Discipline, No Leaks',
    'Sikh Empire': 'Honor and Aggression, Balanced',
    'Sikkim': 'Summit Calm, Razor Rivers',
    'Travancore': 'Coastal Poise, Ruthless Pots',
  },
  VenueGroup.international: <String, String>{
    'Africa': 'Savanna Kings, Pot Dominion',
    'S. America': 'Jungle Fury, River Authority',
    'N. America': 'Continental Edge, Bold Value',
    'Arabia': 'Desert Honor, Dagger Bluffs',
    'Australia': 'Stoic Tablecraft, True Value',
    'China': 'Dragon Order, Impeccable Lines',
    'Europe': 'Measured Ranges, Noble Pots',
    'India': 'Ancient Skill, Modern Value',
    'Russia': 'Winter Discipline, Iron Lines',
    'Asia': 'Eastern Poise, Surgical Rivers',
  },
};

String _canonicalKingdomName(VenueGroup group, String kingdomName) {
  final t = kingdomName.trim();
  if (t.isEmpty) return t;

  final lower = t.toLowerCase();
  if (group == VenueGroup.international) {
    if (lower == 'amazon' ||
        lower == 'south america' ||
        lower == 's america' ||
        lower == 's. america') {
      return 'S. America';
    }
    if (lower == 'america' ||
        lower == 'north america' ||
        lower == 'n america' ||
        lower == 'n. america') {
      return 'N. America';
    }
    if (lower == 'southeast') return 'Asia';
  }

  if (group == VenueGroup.india) {
    if (lower == 'delhi') return 'New Delhi';
    if (lower == 'maratha') return 'Maratha Empire';
    if (lower == 'sikh') return 'Sikh Empire';
  }
  return t;
}

String _truncate30(String s) {
  final t = s.trim();
  if (t.length <= 30) return t;
  return '${t.substring(0, 29)}…';
}

String kingdomAboutFor({
  required VenueGroup group,
  required String kingdomName,
}) {
  final raw = _canonicalKingdomName(group, kingdomName);
  if (raw.isEmpty) return '—';

  final byGroup = kKingdomAbouts[group];
  if (byGroup == null || byGroup.isEmpty) return '—';

  final direct = byGroup[raw];
  if (direct != null) return _truncate30(direct);

  final lower = raw.toLowerCase();
  for (final entry in byGroup.entries) {
    if (entry.key.toLowerCase() == lower) return _truncate30(entry.value);
  }
  return '—';
}
