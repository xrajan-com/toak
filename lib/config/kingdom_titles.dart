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
    'Africa': 'Mansa',
    'S. America': 'Caudillo',
    'N. America': 'Chief',
    'Arabia': 'Sheikh',
    'China': 'Jiangjun',
    'Far East': 'Shogun',
    'Asia Rest': 'Mandala',
    'Central Asia': 'Emir',
    'Persia': 'Shah',
    'Europe': 'Duke',
  },
  VenueGroup.euro: <String, String>{
    'Britain': 'Baron',
    'France': 'Marquis',
    'Italy': 'Conte',
    'Spain': 'Hidalgo',
    'Portugal': 'Infante',
    'North Sea': 'Stadtholder',
    'Scandinavia': 'Jarl',
    'Baltic Marches': 'Hetman',
    'Russia & Siberia': 'Ataman',
    'Mediterranean': 'Strategos',
  },
  VenueGroup.oceania: <String, String>{
    'Alaska': 'Chieftain',
    'Caribbean': 'Governor',
    'Dragonland': 'Taipan',
    'Straits': 'Laksamana',
    'Indian Ocean': 'Admiral',
    'Pacific': 'Tui',
    'British Isles': 'Warden',
    'French Isles': 'Seigneur',
    'Dutch Isles': 'Burgher',
    'American Isles': 'Marshal',
  },
  VenueGroup.northAmerica: <String, String>{
    'Dominion of Canada': 'Mountie',
    'Massachusetts': 'Patriot',
    'New York': 'Maccabee',
    'Virginia': 'Cavalier',
    'Illinois': 'Loopmaster',
    'Florida': 'Buccaneer',
    'Texas': 'Longhorn',
    'Kansas': 'Marshal',
    'Colorado': 'Prospector',
    'California': 'Rainmaker',
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
