import 'package:ten_of_a_kind_poker/config/venues.dart';

/// Default number of sub-kingdoms per kingdom.
///
/// If you provide more names than this in [kSubKingdomNames], the app will
/// automatically expand the grid to match.
const int kDefaultSubKingdomCount = 50;

/// Optional sub-kingdom names keyed by circuit -> kingdom name.
///
/// - Indices are 1-based in the UI, but lists are 0-based here.
/// - If a name is missing/blank, the UI falls back to "Sub‑Kingdom 01".
///
/// Fill this incrementally as you finalize names.
const Map<VenueGroup, Map<String, List<String>>> kSubKingdomNames = {
  VenueGroup.india: <String, List<String>>{
    'Baroda': [
      'Bhadra Fort',
      'Surat Fort',
      'Uparkot Fort',
      'Pavagadh Fort',
      'Dhoraji Fort',
      'Lakhota Fort',
      'Diu Fort',
      'Bhujia Fort',
    ],
    'Jaipur': [
      'Taragarh Fort',
      'Lohagarh Fort',
      'Mehrangarh Fort',
      'Sajjangarh Fort',
      'Jalore Fort',
      'Chittorgarh Fort',
      'Junagarh Fort',
      'Kumbhalgarh Fort',
      'Achalgarh Fort',
    ],
    'Hyderabad': [
      'Golconda Fort',
      'Warangal Fort',
      'Konda Reddy Fort',
      'Bhongir Fort',
      'Kondapalli Fort',
    ],
    'Mysore': [
      'Bangalore Fort',
      'Srirangapatna Fort',
      'Chitradurga Fort',
      'Manjarabad Fort',
      'Madikeri Fort',
    ],
    'Travancore': [
      'East Fort',
      'Pallippuram Fort',
      'Udayagiri Fort',
      'Vattakottai Fort',
      'Dindigul Fort',
      'Tiruchirappalli Rock Fort',
    ],
    'Indore': [
      'Asirgarh Fort',
      'Mandu Fort',
      'Dhar Fort',
      'Gwalior Fort',
      'Narwar Fort',
    ],
    'New Delhi': [
      'Red Fort',
      'Purana Qila',
      'Tughlaqabad Fort',
      'Salimgarh Fort',
      'Firoz Shah Kotla',
      'Adilabad Fort',
      'Panipat Fort',
      'Ballabhgarh Fort',
      'Agra Fort',
      'Chunar Fort',
      'Ramnagar Fort',
      'Allahabad Fort',
    ],
    'Maratha Empire': [
      'Raigad Fort',
      'Pratapgad Fort',
      'Sinhagad Fort',
      'Shivneri Fort',
      'Sindhudurg Fort',
      'Lohagad Fort',
      'Vijaydurg Fort',
      'Arnala Fort',
    ],
    'Sikh Empire': [
      'Lahore Fort',
      'Multan Fort',
      'Attock Fort',
      'Rohtas Fort',
      'Govindgarh Fort',
      'Kangra Fort',
      'Bathinda Fort',
      'Qila Mubarak Patiala',
      'Phillaur Fort',
      'Bahadurgarh Fort',
      'Nabha Fort',
      'Lodhi Fort',
      'Shahpurkandi Fort',
      'Payal Fort',
      'Manauli Fort',
      'Keshgarh Fort',
      'Sheikhupura Fort',
      'Sialkot Fort',
      'Jamrud Fort',
      'Nandana Fort',
      'Sangni Fort',
      'Pharwala Fort',
      'Hari Parbat Fort',
      'Bahu Fort',
    ],
    'Sikkim': [
      'Budang Gadi Fort',
      'Rabdentse',
      'Damsang Fort',
      'Buxa Fort',
      'Ita Fort',
      'Kangla Fort',
      'Bihu Loukon Fort',
      'Garh Doul',
      'Barabati Fort',
      'Sisupalgarh',
    ],
  },
  VenueGroup.international: <String, List<String>>{
    'Africa': [
      'Cairo Citadel',
      'Bastion de la Sqala',
      'Castle of Good Hope',
      "Fort d'Estrees",
      'Old Fort Durban',
      'Fort Dauphin',
      'Fort Jesus',
    ],
    'S. America': [
      'Fort of Buenos Aires',
      'Castillo del Morro',
      'Fort Charles',
      'San Juan de Ulua',
      'Fort San Lorenzo',
      'Fort Copacabana',
      'Itaipu Fortress',
      'Fort Bueras',
    ],
    'N. America': [
      'Fort William H. Seward',
      'Fort Charlotte',
      "Saint Ann's Fort",
      'Fort Independence',
      'Fort Dearborn',
      'Fort Travis',
      'Old Las Vegas Fort',
      'Fort Moore',
      'Fort Dallas',
      'Fort Wadsworth',
      'Fort Point',
      'Fort York',
      'Fort McNair',
    ],
    'Arabia': [
      'Qasr Al Hosn',
      'Sidon Sea Castle',
      'Citadel of Damascus',
      'Al Koot Fort',
      'Asfan Castle',
      'Kuwait Red Fort',
      'Bahrain Fort',
      'Al Jalali Fort',
      'Masmak Fort',
      'Apollonia Fortress',
    ],
    'Australia': [
      'Fort Takapuna',
      'Fort Queenscliff',
      'Tavuni Hill Fort',
      'Fort Nepean',
      'Princess Royal Fortress',
      'Bare Island Fort',
    ],
    'China': [
      'Juyong Pass Fortress',
      'Weiyuan Fort',
      'Tung Chung Fort',
      'Guia Fortress',
      'Wusong Fortress',
      'Dapeng Fortress',
      "Xi'an Fortifications",
    ],
    'Europe': [
      'Fort Pampus',
      'Acropolis Citadel',
      'Montjuic Castle',
      'Spandau Citadel',
      'Poenari Citadel',
      'Lovrijenac Fortress',
      'Suomenlinna Fortress',
      'Kyiv Fortress',
      'Tower of London',
      'Manzanares Castle',
      'Sforza Castle',
      'Burghausen Castle',
      'Akershus Fortress',
      'Chateau de Vincennes',
      'Vysehrad Fortress',
      "Castel Sant'Angelo",
      'Hohensalzburg Fortress',
      'Warsaw Citadel',
      'Munot Fortress',
      'Bellinzona Castles',
    ],
    'India': [
      'Agra Fort',
      'Gobindgarh Fort',
      'Bangalore Fort',
      'Raisen Fort',
      'Fort St. George',
      'Lalbagh Fort',
      'Pavagadh Fort',
      'Itakhuli Fort',
      'Bala Hissar',
      'Manora Fort',
      'Fort Emmanuel',
      'Fort William',
      'Chunar Fort',
      'Fort Adelaide',
      'Castella de Aguada',
      'Sindhuli Gadhi',
      'Rohtasgarh Fort',
      'Miri Fort',
      'Navratangarh Fort',
      'Simtokha Dzong',
      'Kumbhalgarh Fort',
      'Vizianagaram Fort',
    ],
    'Russia': [
      'Izborsk Fortress',
      'Moscow Kremlin',
      'Smolensk Fortress',
      'Godlik Fortress',
      'Peter and Paul Fortress',
      'Vladivostok Fortress',
    ],
    'Asia': [
      'Phra Sumen Fort',
      'Fort Fredrick',
      'Imperial Citadel of Thang Long',
      'Gia Dinh Citadel',
      'Rumelihisari',
      'Fort Rotterdam',
      'Fort Cornwallis',
      'Nijo Castle',
      'Fort Santiago',
      'Longvek Citadel',
      'Rawat Fort',
      'Fort Canning',
      'Fort Santo Domingo',
      'Edo Castle',
    ],
  },
};

/// Optional sub-kingdom tile taglines keyed by circuit -> kingdom name.
///
/// Keep these short (≤ 30 chars); they render inline with the sub-kingdom name.
/// If a kingdom is missing here, [subKingdomAbout] falls back to deterministic
/// war-themed phrases.
const Map<VenueGroup, Map<String, List<String>>> kSubKingdomAboutThemes = {
  VenueGroup.india: <String, List<String>>{
    'Baroda': [
      'Gujarati grit, sharp value',
      'Garba nights, snap 3-bets',
      'Diamond hands, no punts',
      'Coastal breeze, cold reads',
      'Bazaari swagger, big pots',
      'Dandiya beats, mean bluffs',
      'Temple calm, river bite',
      'Spice heat, steady pressure',
      'Sea-raid stacks, rejam',
      'Quiet smile, loud overbets',
      'Rail jokes, ruthless value',
      'Gujju reads, roast mode',
    ],
    'Jaipur': [
      'Pink-city bluffs, big pots',
      'Desert reads, dagger jams',
      'Amber vibes, royal value',
      'Rajput pride, no mercy',
      'Sandstorm bluffs incoming',
      'Fort walls, fearless raises',
      'Camel tilt? never heard',
      'Gold bazaar, cold 3-bets',
      'Palace calm, savage river',
      'Rajasthan rail, roast you',
      'Sunset stacks, sharp squeezes',
      'Thar heat, mean barrels',
      'Royal grin, ruthless value',
    ],
    'Hyderabad': [
      'Pearl city pressure cooker',
      'Biryani bluffs, spicy jams',
      'Charminar stare, snap 3-bet',
      'Nizam nerves, cold value',
      'Deccan heat, no brakes',
      'Golconda gold, grind mode',
      'Sultan swagger, shove first',
      'Techie math, brutal lines',
      'Pearls out, claws out',
      'Smile off, pressure on',
    ],
    'Mysore': [
      'Tiger stride, river bite',
      'Palace calm, savage value',
      'Rocket bluffs, boom pots',
      'Coffee reads, cold folds',
      'Silk court, savage shove',
      'Wodeyar swagger, no punts',
      'Royal court, ruthless river',
      'Quiet grin, sharp check-raise',
      'Crown on, pressure on',
      'Patience now, pain later',
    ],
    'Travancore': [
      'Backwater bluffs, easy',
      'Coconut calm, sharp claws',
      'Sea breeze, ruthless river',
      'Temple bells, turn barrels',
      'Spice routes, stack routes',
      'Harbour hustle, hero calls',
      'Southside swagger, no punts',
      'Quiet waves, loud overbets',
      'Palm shade, pressure made',
      'Monsoon mood, mean value',
    ],
    'Indore': [
      'Street-food swagger, shove',
      'Poha polite, river savage',
      'Rajwada grind, clean KO',
      'Malwa mood, mean bluffs',
      'Night markets, nasty squeezes',
      'Quiet laugh, sharp raise',
      'No mercy, only value',
      'Spicy stacks, steady hands',
      'Turn pressure, trophy vibes',
      'Cool face, cruel river',
    ],
    'New Delhi': [
      'Metro timing, savage value',
      'Ring-road rage, rejam',
      'Capital grind, no leaks',
      'Capital bluffs, big pots',
      'Old walls, new overbets',
      'Paperwork? I prefer pots',
      'Courtroom calm, river rage',
      'Deadline pressure, snap 3-bets',
      'Bureaucracy? shove anyway',
      'Street food, street fights',
      'Night lights, mean value',
      'Yamuna chill, river kill',
      'Stare down, stack up',
      'Hero calls, zero fear',
      'Mean reads, clean wins',
      'Only pressure, no pity',
    ],
    'Maratha Empire': [
      'Fort raids, fat stacks',
      'Shivaji swagger, snap KO',
      'Peshwa pressure, no punts',
      'Deccan drums, deep runs',
      'Konkan coast, cold value',
      'Cavalry calm, river cut',
      'Steel nerves, spicy overbets',
      'Quick blade, quick rejam',
      'War cry, value high',
      'Crown on, chaos on',
      'Sunset bluffs, sunset value',
      'Edge forged, chips seized',
    ],
    'Sikh Empire': [
      'Punjab lions, big pots',
      'Khalsa calm, brutal jams',
      'Ranjit roar, no mercy',
      'Nihang mode: all in',
      'Khyber gate, cold squeeze',
      'Dhol beats, tilt deletes',
      'Steel kirpan, river cut',
      'Frontier grit, no punts',
      'Lionheart laughs, sharp value',
      'Honor high, bluff higher',
      'No fear, only pressure',
      'Quick rejam, quicker grin',
      'Royal guard, river hard',
      'Mean stare, clean lines',
      'Hard folds, harder barrels',
      'Valor on, overbet on',
    ],
    'Sikkim': [
      'Mountain zen, mean jams',
      'Snowline calm, savage value',
      'Tea trails, tight folds',
      'Monastery mind, no punts',
      'Ridge reads, river knives',
      'Cloud cover, bluff cover',
      'Thin air, thick stacks',
      'Quiet peaks, loud overbets',
      'Himalayan chill, sharp kill',
      'Calm face, cruel river',
      'Summit swagger, snap call',
      'Trail tough, tilt-proof',
    ],
  },
  VenueGroup.international: <String, List<String>>{
    'Africa': [
      'Savanna swagger, big swings',
      'Sun heat, cold folds',
      'Lion calm, brutal value',
      'Desert grit, sharp squeezes',
      'Coast breeze, chaos barrels',
      'Ancient kings, modern bluffs',
      'Safari eyes, river knives',
      'Tribal beat, tilt defeat',
      'Dust storms, stack storms',
      'Fearless, fresh overbets',
      'Quiet grin, big pots',
      'Pounce fast, punish faster',
    ],
    'S. America': [
      'Jungle bluffs, river knives',
      'Samba tempo, savage value',
      'Volcano cool, brutal jams',
      'Carnival laughs, cruel lines',
      'Rainforest reads, mean bluffs',
      'Riverboat vibes, rejam',
      'Sunset heat, sharp squeezes',
      'Spice & steel, stack steals',
      'Chaos barrels, clean KOs',
      'Loud rail, lethal river',
      'Wild cards, wilder bets',
      'Tango tilt? never heard',
    ],
    'N. America': [
      'Vegas math, brutal value',
      'Big city, bigger bluffs',
      'Cold coffee, colder 3-bets',
      'Roadtrip grit, rejam',
      'Fast lanes, fearless raises',
      'Showtime bluffs, clean wins',
      'Surf calm, savage river',
      'Grind mode, no mercy',
      'Poker face, punchy bets',
      'Hero calls, meme laughs',
      'No punts, only pressure',
      'Chips up, ego down',
      'Loud crowd, cold folds',
      'All gas, no brakes',
      'Stack snatcher, no sorry',
      'Stacks rise, ego falls',
    ],
    'Arabia': [
      'Dune winds, sharp squeezes',
      'Spice souk, savage value',
      'Falcon eyes, claws out',
      'Caravan calm, river rage',
      'Golden sands, cold reads',
      'Desert heat, mean barrels',
      'Mint tea, murder bluffs',
      'Oasis chill, knife river',
      'Sand cold, stacks colder',
      'Silk routes, stack routes',
      'Crescent moon, cruel jams',
      'Sunrise bluffs, sunset value',
    ],
    'Australia': [
      'Outback laughs, overbets',
      'Ocean chill, savage river',
      'Sunburnt bluffs, big pots',
      'No worries, no punts',
      'Wildlife stare, snap shove',
      'Larrikin grin, mean value',
      'Coral coast, cold squeezes',
      'Desert heat, clean KOs',
      'Boomerang bluffs return',
      'No worries, brutal value',
    ],
    'China': [
      'Dragon discipline, river doom',
      'Silk smooth, sudden shove',
      'Great Wall, greater value',
      'Tea calm, brutal jams',
      'Red lanterns, cold reads',
      'Jade guard, sharp squeezes',
      'Fireworks on the turn',
      'Ancient pride, modern grind',
      'No smile, only value',
      'Quiet court, loud overbets',
      'Emperor mode, no punts',
      'Fortune favors the fearless',
    ],
    'Europe': [
      'Solver chic, no punts',
      'Castle calm, cruel value',
      'Espresso reads, snap 3-bets',
      'Musketeer bluffs, clean wins',
      'Knight code, savage river',
      'High fashion, higher bets',
      'Bank-grade value, no leaks',
      'Cold rain, colder folds',
      'Ancient streets, modern grind',
      'Opera calm, dagger jams',
      'Euro swagger, sharp squeezes',
      'Royal roads, ruthless value',
      'Legends only, no mercy',
      'Tight suits, tighter ranges',
      'No drama, only chips',
      'Math clean, ego gone',
    ],
    'India': [
      'Spice roads, stack roads',
      'Masala mood, sharp bluffs',
      'Bollywood bluffs, big pots',
      'Chai breaks, cold 3-bets',
      'Street eats, savage beats',
      'High peaks, higher pots',
      'Coastal breeze, cruel value',
      'Metro timing, no leaks',
      'Fort vibes, fearless jams',
      'Rail laughs, ruthless value',
      'Desi swagger, clean lines',
      'Underdog energy, big wins',
      'Spice up, stack up',
      'Zero punts, full pressure',
      'Hero calls, legend tales',
      'Desi edge, legend vibes',
    ],
    'Russia': [
      'Winter nerves, brutal jams',
      'Ice veins, cold overbets',
      'Red Army pressure, no punts',
      'Siberian stare, snap shove',
      'Vodka jokes, iron folds',
      'Frozen river, sharp knives',
      'Steel rails, savage value',
      'Tsar mode, no mercy',
      'Blizzard bluffs incoming',
      'Cold hands, hot stacks',
      'Iron curtain, clean lines',
      'Cold edge, colder stare',
    ],
    'Asia': [
      'Monsoon bluffs, ninja steals',
      'Island vibes, savage value',
      'Spice fleet, sharp squeezes',
      'Temple calm, dagger jams',
      'Samurai calm, brutal jams',
      'Tiger grin, mean barrels',
      'Jade guard, no leaks',
      'Night market, nasty CR',
      'Sea lanes, stack raids',
      'Quiet zen, loud overbets',
      'Fast trains, faster 3-bets',
      'Lanterns lit, bluffs hit',
      'Road to glory, no punts',
      'Throne vibes, river knives',
      'Legend tales, chip trails',
      'Zen calm, savage edge',
    ],
  },
};

final Map<VenueGroup, Map<String, List<int>>> _subKingdomPrizeOrderCache =
    <VenueGroup, Map<String, List<int>>>{};

int subKingdomCountFor({
  required VenueGroup group,
  required String kingdomName,
}) {
  final names = subKingdomNamesFor(group: group, kingdomName: kingdomName);
  return names.isNotEmpty ? names.length : kDefaultSubKingdomCount;
}

List<String> subKingdomNamesFor({
  required VenueGroup group,
  required String kingdomName,
}) {
  final raw = () {
    final byGroup = kSubKingdomNames[group];
    if (byGroup == null || byGroup.isEmpty) return const <String>[];

    final wanted = _canonicalKingdomName(group, kingdomName);
    final direct = byGroup[wanted];
    if (direct != null) return direct;

    final lower = wanted.toLowerCase();
    for (final entry in byGroup.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return const <String>[];
  }();
  final seen = <String>{};
  final names = <String>[];
  for (final n in raw) {
    final t = n.trim();
    if (t.isEmpty) continue;
    final key = t.toLowerCase();
    if (seen.add(key)) names.add(t);
  }
  names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return names;
}

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
  return t;
}

String subKingdomDisplayName({
  required VenueGroup group,
  required String kingdomName,
  required int index,
}) {
  final i = index - 1;
  if (i < 0) return 'Sub‑Kingdom 01';

  final names = subKingdomNamesFor(group: group, kingdomName: kingdomName);
  if (i < names.length) return names[i];

  return 'Sub‑Kingdom ${index.toString().padLeft(2, '0')}';
}

int _fnv1a32(String s) {
  var hash = 0x811c9dc5;
  for (final cu in s.codeUnits) {
    hash ^= cu;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// A deterministic "prize score" for ordering sub-kingdoms within a kingdom.
///
/// This is intentionally stable (no RNG) so the ordering doesn't reshuffle
/// between app launches. Higher means "bigger prize".
int subKingdomPrizeScore({
  required VenueGroup group,
  required String kingdomName,
  required int index,
}) {
  final canonical = _canonicalKingdomName(group, kingdomName);
  final int i = index < 1 ? 1 : index;
  final int h = _fnv1a32('sub_prize|${group.name}|$canonical|$i|v1');
  return h & 0x7FFFFFFF;
}

/// Returns sub-kingdom indices (1-based) ordered by prize score, ascending.
///
/// The first index in this list is the free sub-kingdom for that kingdom.
List<int> subKingdomIndicesByPrizeScore({
  required VenueGroup group,
  required String kingdomName,
}) {
  final canonical = _canonicalKingdomName(group, kingdomName);
  final byGroup =
      _subKingdomPrizeOrderCache.putIfAbsent(group, () => <String, List<int>>{});
  final cached = byGroup[canonical];
  if (cached != null) return cached;

  final int count = subKingdomCountFor(group: group, kingdomName: canonical);
  if (count <= 0) return const <int>[];

  final order = List<int>.generate(count, (i) => i + 1);
  order.sort((a, b) {
    final pa =
        subKingdomPrizeScore(group: group, kingdomName: canonical, index: a);
    final pb =
        subKingdomPrizeScore(group: group, kingdomName: canonical, index: b);
    if (pa != pb) return pa.compareTo(pb);
    return a.compareTo(b);
  });

  final frozen = List<int>.unmodifiable(order);
  byGroup[canonical] = frozen;
  return frozen;
}

/// Returns the (1-based) sub-kingdom index with the lowest prize score.
int freeSubKingdomIndexFor({
  required VenueGroup group,
  required String kingdomName,
}) {
  final order =
      subKingdomIndicesByPrizeScore(group: group, kingdomName: kingdomName);
  return order.isEmpty ? 1 : order.first;
}

String _truncate30(String s) {
  final t = s.trim();
  if (t.length <= 30) return t;
  return '${t.substring(0, 29)}…';
}

/// A short sub-kingdom tagline (≤ 30 chars) for tile UI.
///
/// This is intentionally deterministic (stable per sub-kingdom name) so the
/// UI doesn't "shuffle" on rebuilds.
String subKingdomAbout({
  required VenueGroup group,
  required String kingdomName,
  required int index,
}) {
  final name = subKingdomDisplayName(
    group: group,
    kingdomName: kingdomName,
    index: index,
  );

  const fallback = <String>[
    'All-in energy',
    'Value town vibes',
    'Bluff city',
    'No punts allowed',
    'River knives',
    'Snap call circus',
    'Cold 3-bets',
    'Tilt-proof legend',
    'Stack raids',
    'Quietly deadly',
    'Pressure cooker',
    'Hero calls only',
    'Read you, roast you',
    'Clean lines, mean wins',
    'Chips on fire',
    'Luck? I make it',
  ];

  final wantedKingdom = _canonicalKingdomName(group, kingdomName);
  final themes =
      kSubKingdomAboutThemes[group]?[wantedKingdom] ?? const <String>[];

  final phrases = themes.isNotEmpty ? themes : fallback;
  final seed = _fnv1a32('${group.name}|$wantedKingdom|$name');
  final phrase = phrases[seed % phrases.length];
  return _truncate30(phrase);
}
