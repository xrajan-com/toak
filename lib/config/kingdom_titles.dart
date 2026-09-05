import 'package:ten_of_a_kind_poker/config/venues.dart';

const Map<VenueGroup, Map<String, String>> kKingdomTitles = {
  VenueGroup.india: <String, String>{
    'Baroda': 'Patel',
    'Hyderabad': 'Nizam',
    'Indore': 'Subedar',
    'Jaipur': 'Rawal',
    'Maratha Empire': 'Peshwa',
    'Mysore': 'Sultan',
    'New Delhi': 'Raja',
    'Sikh Empire': 'Zaildar',
    'Sikkim': 'Sherpa',
    'Travancore': 'Thala',
  },
  VenueGroup.international: <String, String>{
    'Australia': 'Premier',
    'North Africa': 'Pasha',
    'Sub-Saharan Africa': 'Mansa',
    'Arabia': 'Sheikh',
    'Persia & Mesopotamia': 'Shah',
    'Central Asia': 'Emir',
    'Indian Ocean Isles': 'Admiral',
    'Atlantic Isles': 'Warden',
    'French & Dutch Isles': 'Burgher',
    'Arctic': 'Chieftain',
  },
  VenueGroup.euro: <String, String>{
    'Britain & Ireland': 'Baron',
    'France': 'Marquis',
    'Italy': 'Conte',
    'Iberia': 'Hidalgo',
    'Low Countries': 'Stadtholder',
    'Scandinavia': 'Jarl',
    'Central Europe': 'Margrave',
    'Balkans & Mediterranean': 'Strategos',
    'Baltic Marches': 'Hetman',
    'Russia & Siberia': 'Ataman',
  },
  VenueGroup.oceania: <String, String>{
    'China': 'Jiangjun',
    'Japan': 'Shogun',
    'Korea': 'Daegam',
    'Taiwan': 'Taipan',
    'Vietnam': 'Vương',
    'Mekong': 'Mandala',
    'Philippines': 'Datu',
    'Straits': 'Laksamana',
    'Indonesia': 'Sultan',
    'Pacific': 'Tui',
  },
  VenueGroup.northAmerica: <String, String>{
    'Canada': 'Mountie',
    'Northeast USA': 'Patriot',
    'Atlantic USA': 'Commodore',
    'Southern USA': 'Colonel',
    'Western USA': 'Prospector',
    'Mexico & Central America': 'Caudillo',
    'Caribbean': 'Governor',
    'Brazil': 'Bandeirante',
    'Andes': 'Inca',
    'Southern Cone': 'Gaucho',
  },
};

String kingdomTitleFor({
  required VenueGroup group,
  required String kingdomName,
}) {
  final raw = kingdomName.trim();
  if (raw.isEmpty) return 'N/A';

  final byGroup = kKingdomTitles[group];
  if (byGroup == null || byGroup.isEmpty) return 'N/A';

  final direct = byGroup[raw];
  if (direct != null) return direct;

  final lower = raw.toLowerCase();
  for (final entry in byGroup.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return 'N/A';
}
