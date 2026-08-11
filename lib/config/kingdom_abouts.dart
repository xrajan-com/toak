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
    'China': 'Dragon Order, Impeccable Lines',
    'Far East': 'Castle Calm, Samurai Value',
    'Asia Rest': 'River Citadels, Sharp Lines',
    'Central Asia': 'Steppe Steel, Cold Pressure',
    'Persia': 'Shah Walls, Desert Reads',
    'Europe': 'Imperial Keeps, Noble Pots',
  },
  VenueGroup.euro: <String, String>{
    'Britain': 'Crown Walls, Iron Calls',
    'France': 'Chateau Grace, River Bite',
    'Italy': 'Rocca Nerves, Clean Value',
    'Spain': 'Alcazar Pride, Bold Lines',
    'Portugal': 'Atlantic Forts, Steady Pots',
    'North Sea': 'Lowland Walls, Deep Reads',
    'Scandinavia': 'Nordic Calm, Sharp Steel',
    'Baltic Marches': 'Border Keeps, Hard Pressure',
    'Russia & Siberia': 'Winter Forts, Iron Lines',
    'Mediterranean': 'Sea Citadels, Old Power',
  },
  VenueGroup.oceania: <String, String>{
    'Alaska': 'Northern Posts, Cold Nerves',
    'Caribbean': 'Island Forts, Hot Rivers',
    'Dragonland': 'Harbor Walls, Dragon Value',
    'Straits': 'Trade Lanes, Tight Reads',
    'Indian Ocean': 'Monsoon Forts, Calm Value',
    'Pacific': 'Ocean Posts, Brave Calls',
    'British Isles': 'Colonial Keeps, Hard Lines',
    'French Isles': 'Island Bastions, Clean Pots',
    'Dutch Isles': 'Harbor Forts, Merchant Edge',
    'American Isles': 'Pacific Batteries, Bold Play',
  },
  VenueGroup.northAmerica: <String, String>{
    'Dominion of Canada': 'Northern Forts, Steady Nerves',
    'Massachusetts': 'Patriot Walls, Cold Reads',
    'New York': 'Atlantic Power, Sharp Value',
    'Virginia': 'Old Dominion, Iron Calls',
    'Illinois': 'Great Lakes, Deep Stacks',
    'Florida': 'Southern Forts, Hot Rivers',
    'Texas': 'Lone Star, Fearless Raises',
    'Kansas': 'Prairie Steel, Hard Pressure',
    'Colorado': 'Mountain Forts, High Stakes',
    'California': 'Pacific Edge, Golden Pots',
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
    if (lower == 'far east' || lower == 'east asia') return 'Far East';
    if (lower == 'asia rest' ||
        lower == 'mainland asia' ||
        lower == 'southeast' ||
        lower == 'asia') {
      return 'Asia Rest';
    }
    if (lower == 'europe' || lower == 'europe kingdom') return 'Europe';
    if (lower == 'persia' ||
        lower == 'persia & mesopotamia' ||
        lower == 'persia and mesopotamia' ||
        lower == 'mesopotamia') {
      return 'Persia';
    }
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
