import 'package:ten_of_a_kind_poker/config/venues.dart';

const Map<VenueGroup, Map<String, String>> kKingdomTitles = {
  VenueGroup.india: <String, String>{
    'Baroda': 'Patel',
    'Hyderabad': 'Nizam',
    'Indore': 'Holkar',
    'Jaipur': 'Maharawal',
    'Maratha Empire': 'Chhatrapati',
    'Mysore': 'Sultan',
    'New Delhi': 'Sultan',
    'Sikh Empire': 'Sardar',
    'Sikkim': 'Sherpa',
    'Travancore': 'Maharaja',
  },
  VenueGroup.international: <String, String>{
    'Africa': 'Mansa',
    'S. America': 'Caudillo',
    'N. America': 'Chief',
    'Arabia': 'Sheikh',
    'Australia': 'Elder',
    'China': 'Jiangjun',
    'Europe': 'Duke',
    'India': 'Maharaja',
    'Russia': 'Ataman',
    'Asia': 'Kokuo',
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
