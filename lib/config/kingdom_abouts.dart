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
    'North Africa': 'Desert Citadels, Old Power',
    'Pacific': 'Ocean Posts, Brave Calls',
    'Sub-Saharan Africa': 'Coastal Forts, Iron Nerves',
    'Arabia': 'Desert Honor, Dagger Bluffs',
    'Persia & Mesopotamia': 'Shah Walls, Desert Reads',
    'Indian Ocean Isles': 'Monsoon Forts, Calm Value',
    'Atlantic Isles': 'Ocean Keeps, Hard Lines',
    'French & Dutch Isles': 'Merchant Forts, Island Edge',
    'Arctic': 'Northern Posts, Cold Nerves',
  },
  VenueGroup.euro: <String, String>{
    'Britain & Ireland': 'Crown Walls, Iron Calls',
    'Central Asia': 'Steppe Steel, Cold Pressure',
    'France': 'Chateau Grace, River Bite',
    'Italy': 'Rocca Nerves, Clean Value',
    'Iberia': 'Alcazar Pride, Atlantic Steel',
    'Low Countries': 'Lowland Walls, Deep Reads',
    'Scandinavia': 'Nordic Calm, Sharp Steel',
    'Central Europe': 'Alpine Keeps, Measured Power',
    'Balkans & Mediterranean': 'Sea Citadels, Old Power',
    'Baltic Marches': 'Border Keeps, Hard Pressure',
    'Russia & Siberia': 'Winter Forts, Iron Lines',
  },
  VenueGroup.oceania: <String, String>{
    'Australia': 'Outback Forts, Harbour Nerves',
    'China': 'Dragon Order, Impeccable Lines',
    'Japan': 'Castle Calm, Samurai Value',
    'Korea': 'Mountain Walls, Disciplined Play',
    'Taiwan': 'Harbor Walls, Island Value',
    'Vietnam': 'River Citadels, Sharp Lines',
    'Mekong': 'River Kingdoms, Patient Steel',
    'Philippines': 'Island Forts, Bold Play',
    'Straits': 'Trade Lanes, Tight Reads',
    'Indonesia': 'Spice Forts, Merchant Edge',
  },
  VenueGroup.northAmerica: <String, String>{
    'Canada': 'Northern Forts, Steady Nerves',
    'Northeast USA': 'Patriot Walls, Cold Reads',
    'Atlantic USA': 'Atlantic Power, Sharp Value',
    'Southern USA': 'Southern Forts, Hot Rivers',
    'Western USA': 'Pacific Edge, Golden Pots',
    'Mexico & Central America': 'Volcano Walls, Bold Lines',
    'Caribbean': 'Island Forts, Hot Rivers',
    'Brazil': 'Coastal Steel, River Authority',
    'Andes': 'Highland Keeps, Hard Pressure',
    'Southern Cone': 'Frontier Forts, Cold Nerves',
  },
};

String _canonicalKingdomName(VenueGroup group, String kingdomName) {
  final t = kingdomName.trim();
  if (t.isEmpty) return t;

  final lower = t.toLowerCase();
  if (group == VenueGroup.oceania) {
    // Australia sits in Australasia now; legacy spellings from the old
    // World Frontiers circuit still have to resolve to it.
    if (lower == 'america' ||
        lower == 'north america' ||
        lower == 'n america' ||
        lower == 'n. america') {
      return 'Australia';
    }
  }
  if (group == VenueGroup.international) {
    if (lower == 'amazon' ||
        lower == 'south america' ||
        lower == 's america' ||
        lower == 's. america') {
      return 'S. America';
    }
    if (lower == 'far east' || lower == 'east asia') return 'Far East';
    if (lower == 'asia rest' ||
        lower == 'mainland asia' ||
        lower == 'southeast' ||
        lower == 'asia') {
      return 'Asia Rest';
    }
    if (lower == 'europe' ||
        lower == 'europe kingdom' ||
        lower == 'european marches') {
      return 'European Marches';
    }
    if (lower == 'persia' ||
        lower == 'persia and mesopotamia' ||
        lower == 'mesopotamia') {
      return 'Persia & Mesopotamia';
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
