import 'package:ten_of_a_kind_poker/config/venues.dart';

/// Default number of sub-kingdoms per kingdom.
///
/// If you provide more names than this in [kSubKingdomNames], the app will
/// automatically expand the grid to match.
const int kDefaultSubKingdomCount = 50;

/// Optional sub-kingdom names keyed by circuit -> kingdom name.
///
/// - Indices are 1-based in the UI, but lists are 0-based here.
/// - If a name is missing/blank, the UI falls back to "Fort 01".
///
/// Fill this incrementally as you finalize names.
const Map<VenueGroup, Map<String, List<String>>> kSubKingdomNames = {
  VenueGroup.india: <String, List<String>>{
    'Baroda': [
      'Bhadra Fort (India)',
      'Bhujia Fort (India)',
      'Dhoraji Fort (India)',
      'Diu Fort (India)',
      'Lakhota Fort (India)',
      'Pavagadh Fort (India)',
      'Surat Fort (India)',
      'Uparkot Fort (India)',
    ],
    'Hyderabad': [
      'Bhongir Fort (India)',
      'Golconda Fort (India)',
      'Konda Reddy Fort (India)',
      'Kondapalli Fort (India)',
      'Warangal Fort (India)',
    ],
    'Indore': [
      'Asirgarh Fort (India)',
      'Dhar Fort (India)',
      'Gwalior Fort (India)',
      'Mandu Fort (India)',
      'Narwar Fort (India)',
    ],
    'Jaipur': [
      'Achalgarh Fort (India)',
      'Chittorgarh Fort (India)',
      'Jalore Fort (India)',
      'Junagarh Fort (India)',
      'Kumbhalgarh Fort (India)',
      'Lohagarh Fort (India)',
      'Mehrangarh Fort (India)',
      'Sajjangarh Fort (India)',
      'Taragarh Fort (India)',
    ],
    'Maratha Empire': [
      'Arnala Fort (India)',
      'Lohagad Fort (India)',
      'Pratapgad Fort (India)',
      'Raigad Fort (India)',
      'Shivneri Fort (India)',
      'Sindhudurg Fort (India)',
      'Sinhagad Fort (India)',
      'Vijaydurg Fort (India)',
    ],
    'Mysore': [
      'Bangalore Fort (India)',
      'Chitradurga Fort (India)',
      'Madikeri Fort (India)',
      'Manjarabad Fort (India)',
      'Srirangapatna Fort (India)',
    ],
    'New Delhi': [
      'Adilabad Fort (India)',
      'Agra Fort (India)',
      'Allahabad Fort (India)',
      'Ballabhgarh Fort (India)',
      'Chunar Fort (India)',
      'Firoz Shah Kotla (India)',
      'Panipat Fort (India)',
      'Purana Qila (India)',
      'Ramnagar Fort (India)',
      'Red Fort (India)',
      'Salimgarh Fort (India)',
      'Tughlaqabad Fort (India)',
    ],
    'Sikh Empire': [
      'Attock Fort (Pakistan)',
      'Bahadurgarh Fort (India)',
      'Bahu Fort (India)',
      'Bathinda Fort (India)',
      'Govindgarh Fort (India)',
      'Hari Parbat Fort (India)',
      'Jamrud Fort (Pakistan)',
      'Kangra Fort (India)',
      'Keshgarh Fort (India)',
      'Multan Fort (Pakistan)',
      'Nabha Fort (India)',
      'Nandana Fort (Pakistan)',
      'Payal Fort (India)',
      'Pharwala Fort (Pakistan)',
      'Phillaur Fort (India)',
      'Qila Mubarak Patiala (India)',
      'Rohtas Fort (Pakistan)',
      'Sangni Fort (Pakistan)',
      'Shahpurkandi Fort (India)',
      'Sheikhupura Fort (Pakistan)',
      'Sialkot Fort (Pakistan)',
    ],
    'Sikkim': [
      'Barabati Fort (India)',
      'Bihu Loukon Fort (India)',
      'Budang Gadi Fort (India)',
      'Buxa Fort (India)',
      'Damsang Fort (India)',
      'Garh Doul (India)',
      'Ita Fort (India)',
      'Kangla Fort (India)',
      'Rabdentse (India)',
      'Sisupalgarh (India)',
    ],
    'Travancore': [
      'Dindigul Fort (India)',
      'East Fort (India)',
      'Pallippuram Fort (India)',
      'Tiruchirappalli Rock Fort (India)',
      'Udayagiri Fort (India)',
      'Vattakottai Fort (India)',
    ],
  },
  VenueGroup.international: <String, List<String>>{
    'North Africa': [
      'Cairo Citadel (Egypt)',
      'Apollonia Fortress (Libya)',
      'Bastion de la Sqala (Morocco)',
      'Citadel of Qaitbay (Egypt)',
      'Saladin Citadel (Egypt)',
      'Kasbah of the Udayas (Morocco)',
      'Borj Nord (Morocco)',
      'Kasbah of Algiers (Algeria)',
      'Fort Santa Cruz (Algeria)',
    ],
    'Pacific': [
      'Fort Apugan (Guam)',
      'Fort Santa Agueda (Guam)',
      'Fort Nuestra Señora de la Soledad (Guam)',
      'Peleliu Fortifications (Palau)',
      'Espiritu Santo WWII Base (Vanuatu)',
      'Tavuni Hill Fort (Fiji)',
      'Arai-Te-Tonga (Cook Islands)',
      'Fort Ballance (New Zealand)',
      'Fort Jervois (New Zealand)',
      'Fort Takapuna (New Zealand)',
      'North Head Historic Reserve (New Zealand)',
      'Fort Teremba (New Caledonia)',
    ],
    'Sub-Saharan Africa': [
      'Castle of Good Hope (South Africa)',
      'Fort Jesus (Kenya)',
      'Fort d’Estrees (Senegal)',
      'Fort James / Kunta Kinteh Island (Gambia)',
      'Old Fort Durban (South Africa)',
      'Fort Dauphin (Madagascar)',
      'Camp Lemonnier (Djibouti)',
      'Elmina Castle (Ghana)',
      'Cape Coast Castle (Ghana)',
    ],
    'Arabia': [
      'Al Jalali Fort (Oman)',
      'Al Koot Fort (Qatar)',
      'Asfan Castle (Saudi Arabia)',
      'Bahrain Fort (Bahrain)',
      'Kuwait Red Fort (Kuwait)',
      'Masmak Fort (Saudi Arabia)',
      'Qasr Al Hosn (UAE)',
      'Sidon Sea Castle (Lebanon)',
      'Nizwa Fort (Oman)',
    ],
    'Persia & Mesopotamia': [
      'Al-Ukhaidir Fortress (Iraq)',
      'Arg-e Bam (Iran)',
      'Erbil Citadel (Iraq)',
      'Falak-ol-Aflak Castle (Iran)',
      'Kirkuk Citadel (Iraq)',
      'Narin Castle (Iran)',
      'Rayen Castle (Iran)',
      'Shush Castle (Iran)',
      'Citadel of Damascus (Syria)',
    ],
    'Indian Ocean Isles': [
      'Addu Atoll British Loyalty Remains (Maldives)',
      'Batticaloa Fort (Sri Lanka)',
      'Fort Adelaide (Mauritius)',
      'Fort Fredrick (Sri Lanka)',
      'Fort George (Mauritius)',
      'Fort Victoria Site (Seychelles)',
      'Galle Fort (Sri Lanka)',
      'Jaffna Fort (Sri Lanka)',
      'Mulee’aage Palace (Maldives)',
      'Utheemu Ganduvaru (Maldives)',
    ],
    'Atlantic Isles': [
      'Fort Hamilton (Bermuda)',
      'Fort St. Catherine (Bermuda)',
      'The Garrison (Bermuda)',
      'High Knoll Fort (Saint Helena)',
      'Fort Barrington (Antigua)',
      'Fort James (Antigua)',
      'Fort Burt (British Virgin Islands)',
    ],
    'French & Dutch Isles': [
      'Fort Delgrès (Guadeloupe)',
      'Fort Desaix (Martinique)',
      'Fort Napoléon des Saintes (Guadeloupe)',
      'Fort Amsterdam (Curaçao)',
      'Fort Beekenburg (Curaçao)',
      'Fort Oranje, Sint Eustatius',
      'Fort Zoutman (Aruba)',
    ],
    'Arctic': [
      'Camp Century (Greenland)',
      'Fort Abercrombie (Alaska)',
      'Fort Egbert (Alaska)',
      'Fort Gibbon (Alaska)',
      'Fort William H. Seward (Alaska)',
    ],
  },
  VenueGroup.euro: <String, List<String>>{
    'Britain & Ireland': [
      'Bamburgh Castle (England)',
      'Bodiam Castle (England)',
      'Caernarfon Castle (Wales)',
      'Caerphilly Castle (Wales)',
      'Dover Castle (England)',
      'Edinburgh Castle (Scotland)',
      'Eilean Donan Castle (Scotland)',
      'Stirling Castle (Scotland)',
      'Tower of London (England)',
      'Windsor Castle (England)',
    ],
    'Central Asia': [
      'Ark of Bukhara (Uzbekistan)',
      'Ayaz Kala (Uzbekistan)',
      'Gissar Fortress (Tajikistan)',
      'Hulbuk Fortress (Tajikistan)',
      'Itchan Kala (Uzbekistan)',
      'Kunya-Ark Citadel (Uzbekistan)',
      'Merv Fortifications (Turkmenistan)',
      'Nisa Fortress (Turkmenistan)',
      'Otrar Fortress (Kazakhstan)',
      'Sauran Fortress (Kazakhstan)',
      'Toprak Kala (Uzbekistan)',
    ],
    'France': [
      'Carcassonne Citadel',
      'Château de Chambord',
      'Château de Chinon',
      'Château de Fougères',
      'Château de Pierrefonds',
      'Château de Saumur',
      'Château de Vincennes',
      'Fort Boyard',
    ],
    'Italy': [
      'Castel del Monte',
      'Castel Nuovo',
      'Castel Sant’Angelo',
      'Castello di Miramare',
      'Castello Estense',
      'Rocca Calascio',
      'Rocca Maggiore',
      'Sforza Castle',
    ],
    'Iberia': [
      'Alcazaba of Málaga (Spain)',
      'Alcázar of Segovia (Spain)',
      'Alhambra (Spain)',
      'Castillo de Coca (Spain)',
      'Castillo de Peñafiel (Spain)',
      'Castle of Loarre (Spain)',
      'Belém Tower (Portugal)',
      'Castle of the Moors (Portugal)',
      'Guimarães Castle (Portugal)',
      'São Jorge Castle (Portugal)',
    ],
    'Low Countries': [
      'Bock Casemates (Luxembourg)',
      'Bouillon Castle (Belgium)',
      'Bourtange Fortress (Netherlands)',
      'Fort Pampus (Netherlands)',
      'Gravensteen (Belgium)',
      'Muiderslot Castle (Netherlands)',
      'Naarden Fortress (Netherlands)',
      'Antwerp Citadel (Belgium)',
    ],
    'Scandinavia': [
      'Bergenhus Fortress (Norway)',
      'Bohus Fortress (Sweden)',
      'Kalmar Castle (Sweden)',
      'Kronborg Castle (Denmark)',
      'Olavinlinna Castle (Finland)',
      'Skansinn Fort (Iceland)',
      'Vardøhus Fortress (Norway)',
      'Suomenlinna Fortress (Finland)',
    ],
    'Central Europe': [
      'Bellinzona Castles (Switzerland)',
      'Hohensalzburg Fortress (Austria)',
      'Spandau Citadel (Germany)',
      'Malbork Castle (Poland)',
      'Bran Castle (Romania)',
      'Prague Castle (Czechia)',
      'Königstein Fortress (Germany)',
      'Bratislava Castle (Slovakia)',
      'Buda Castle (Hungary)',
    ],
    'Balkans & Mediterranean': [
      'Acrocorinth (Greece)',
      'Acropolis of Athens (Greece)',
      'Fort St Elmo (Malta)',
      'Golubac Fortress (Serbia)',
      'Kamerlengo Castle (Croatia)',
      'Klis Fortress (Croatia)',
      'Lovrijenac Fortress (Croatia)',
      'Predjama Castle (Slovenia)',
      'Tsarevets Fortress (Bulgaria)',
      'Rumelihisarı (Turkey)',
    ],
    'Baltic Marches': [
      'Akkerman Fortress (Ukraine)',
      'Brest Fortress (Belarus)',
      'Kamianets-Podilskyi Castle (Ukraine)',
      'Kaunas Castle (Lithuania)',
      'Khotyn Fortress (Ukraine)',
      'Mir Castle (Belarus)',
      'Narva Castle (Estonia)',
      'Nesvizh Castle (Belarus)',
      'Trakai Island Castle (Lithuania)',
      'Turaida Castle (Latvia)',
    ],
    'Russia & Siberia': [
      'Moscow Kremlin',
      'Peter and Paul Fortress',
      'Smolensk Fortress',
      'Izborsk Fortress',
      'Pskov Kremlin',
      'Kazan Kremlin',
      'Naryn-Kala Citadel',
      'Tobolsk Kremlin',
      'Omsk Fortress',
      'Kuznetsk Fortress',
      'Shlisselburg Fortress',
      'Vladivostok Fortress',
    ],
  },
  VenueGroup.oceania: <String, List<String>>{
    'Australia': [
      'Bare Island Fort',
      'Fort Denison',
      'Fort Glanville',
      'Fort Largs',
      'Fort Lytton',
      'Fort Nepean',
      'Fort Pearce',
      'Fort Queenscliff',
      'Fort Scratchley',
      'Fort Wellington',
      'North Head Fort',
      'Rottnest Island Battery',
    ],
    'China': [
      'Dapeng Fortress',
      'Jiayu Pass Fortress',
      'Juyong Pass Fortress',
      'Shanhai Pass Fortress',
      'Weiyuan Fort',
      'Wusong Fortress',
      'Xi’an City Wall',
      'Nanjing City Wall',
      'Humen Fort',
      'Monte Fort (Macau)',
      'Guia Fortress (Macau)',
    ],
    'Japan': [
      'Edo Castle',
      'Himeji Castle',
      'Kumamoto Castle',
      'Nijo Castle',
      'Osaka Castle',
      'Matsumoto Castle',
      'Hikone Castle',
      'Matsue Castle',
      'Inuyama Castle',
      'Bitchū Matsuyama Castle',
    ],
    'Korea': [
      'Suwon Hwaseong Fortress',
      'Hwaseong Haenggung',
      'Namhansanseong Fortress',
      'Bukhansanseong Fortress',
      'Gongsanseong Fortress',
      'Geumjeongsanseong Fortress',
      'Jinju Fortress',
      'Haemieupseong Fortress',
    ],
    'Taiwan': [
      'Anping Fort',
      'Eternal Golden Castle',
      'Fort Santo Domingo',
      'Hobe Fort',
      'Qihou Fort',
      'Ershawan Fort',
      'Dawulun Fort',
      'Huwei Fort',
    ],
    'Vietnam': [
      'Imperial Citadel of Thăng Long',
      'Gia Định Citadel',
      'Huế Imperial Citadel',
      'Cổ Loa Citadel',
      'Hồ Dynasty Citadel',
      'Sơn Tây Citadel',
      'Quảng Trị Citadel',
      'Điện Hải Citadel',
      'Mạc Dynasty Citadel',
      'Hải Vân Gate',
    ],
    'Mekong': [
      'Phra Sumen Fort (Thailand)',
      'Mahakan Fort (Thailand)',
      'Wichaiprasit Fort (Thailand)',
      'Phra Chulachomklao Fort (Thailand)',
      'Pom Phet (Thailand)',
      'Longvek Citadel (Cambodia)',
      'Angkor Thom (Cambodia)',
      'Vientiane City Walls (Laos)',
      'Mandalay Palace Fort (Myanmar)',
    ],
    'Philippines': [
      'Fort Santiago',
      'Fort San Pedro',
      'Fort Pilar',
      'Fort San Felipe',
      'Fort San Antonio Abad',
      'Fort Drum, Manila Bay',
      'Fort Mills',
      'Fort Wint',
      'Baluarte de San Diego',
      'Fuerza de San Andrés',
    ],
    'Straits': [
      'A Famosa (Malaysia)',
      'Fort Cornwallis (Malaysia)',
      'Fort Margherita (Malaysia)',
      'Kuala Kedah Fort (Malaysia)',
      'Fort Canning (Singapore)',
      'Fort Siloso (Singapore)',
      'Johore Battery (Singapore)',
      'Labrador Battery (Singapore)',
      'Kota Batu (Brunei)',
      'Fort Alice (Malaysia)',
      'Fort Brooke (Malaysia)',
      'Fort Sylvia (Malaysia)',
    ],
    'Indonesia': [
      'Fort Belgica',
      'Fort Rotterdam',
      'Fort Marlborough',
      'Fort Tolukko',
      'Fort Oranje, Ternate',
      'Fort Kalamata',
      'Fort Amsterdam, Ambon',
      'Fort Duurstede',
      'Fort Vredeburg',
      'Fort Speelwijk',
    ],
  },
  VenueGroup.northAmerica: <String, List<String>>{
    'Canada': [
      'CFB Halifax',
      'CFB Esquimalt',
      'CFB Kingston',
      'CFB Petawawa',
      'CFB Gagetown',
      'CFB Borden',
      'CFB Trenton',
      'CFB Cold Lake',
      'CFB Valcartier',
      'Fort York',
    ],
    'Northeast USA': [
      'Charlestown Navy Yard',
      'Springfield Armory',
      'Fort Independence',
      'Fort Revere',
      'Fort Sewall',
      'Fort Ticonderoga',
      'Fort Niagara',
      'Fort Stanwix',
      'Fort Montgomery',
      'Fort Totten',
      'Fort Wood',
      'West Point Military Academy',
      'Watervliet Arsenal',
      'Fort Drum, New York',
      'Brooklyn Navy Yard',
    ],
    'Atlantic USA': [
      'Fort McHenry',
      'Fort McNair',
      'Fort Monroe',
      'Fort Belvoir',
      'Fort Eustis',
      'Fort Gregg-Adams',
      'Fort Myer',
      'Fort Story',
      'Marine Corps Base Quantico',
      'Norfolk Naval Station',
      'Naval Air Station Oceana',
      'Fort Moultrie',
      'Fort Pulaski',
      'Fort Sumter',
      'Fort Necessity',
    ],
    'Southern USA': [
      'Castillo de San Marcos',
      'Fort Barrancas',
      'Fort Brooke',
      'Fort Clinch',
      'Fort Jefferson',
      'Fort Zachary Taylor',
      'Naval Air Station Pensacola',
      'Cape Canaveral Space Force Station',
      'Patrick Space Force Base',
      'Fort Sam Houston',
      'The Alamo',
      'Fort Bliss',
      'Fort Cavazos',
      'Fort Davis',
      'Presidio La Bahía',
    ],
    'Western USA': [
      'Fort Leavenworth',
      'Fort Riley',
      'Fort Sill',
      'Bent’s Old Fort',
      'Fort Laramie',
      'Fort Bridger',
      'Fort Garland',
      'Rocky Mountain Arsenal',
      'Camp Pendleton',
      'Edwards Air Force Base',
      'Fort Irwin',
      'Fort Point, San Francisco',
      'Naval Base San Diego',
      'Vandenberg Space Force Base',
      'Travis Air Force Base',
    ],
    'Mexico & Central America': [
      'San Juan de Ulúa (Mexico)',
      'Chapultepec Castle (Mexico)',
      'Fort San Diego (Mexico)',
      'San Carlos Fortress (Mexico)',
      'San Felipe Bacalar (Mexico)',
      'Fortress of San Carlos de Perote (Mexico)',
      'Castillo de la Inmaculada Concepción (Nicaragua)',
      'Fortaleza de la Inmaculada Concepción (Nicaragua)',
      'Castillo de San Felipe (Guatemala)',
      'Fortaleza San Fernando (Honduras)',
      'Fuerte San Lorenzo (Panama)',
      'Fort George (Belize)',
    ],
    'Caribbean': [
      'Castillo de San Pedro de la Roca (Cuba)',
      'Castillo San Cristóbal (Puerto Rico)',
      'Castillo San Felipe del Morro (Puerto Rico)',
      'Fort Charles (Jamaica)',
      'Fort Charlotte (Bahamas)',
      'Brimstone Hill Fortress (Saint Kitts and Nevis)',
      'Fort George (Grenada)',
      'Fort King George (Tobago)',
      'Fort Shirley (Dominica)',
      'Saint Ann’s Fort (Barbados)',
      'Fort Christian (US Virgin Islands)',
      'Fort Frederik (US Virgin Islands)',
    ],
    'Brazil': [
      'Fort Copacabana',
      'Fortaleza de Santa Cruz da Barra',
      'Fortaleza de São José de Macapá',
      'Itaipu Fortress',
      'Forte de São Marcelo',
      'Forte de Santo Antônio da Barra',
      'Forte dos Reis Magos',
      'Forte Orange',
      'Forte das Cinco Pontas',
      'Forte de Nossa Senhora dos Remédios',
      'Forte de Coimbra',
      'Forte de Santa Catarina',
      'Forte São João da Bertioga',
    ],
    'Andes': [
      'Real Felipe Fortress (Peru)',
      'San Felipe de Barajas (Colombia)',
      'Fortaleza del Real Felipe (Peru)',
      'Fortaleza de Kuélap (Peru)',
      'Castillo de San Carlos de la Barra (Venezuela)',
      'Fortín Solano (Venezuela)',
      'Castillo de San Antonio de la Eminencia (Venezuela)',
      'Castillo San Felipe (Venezuela)',
      'Ingapirca (Ecuador)',
      'Rumicucho (Ecuador)',
      'Fuerte de Samaipata (Bolivia)',
    ],
    'Southern Cone': [
      'Fort Bueras (Chile)',
      'Fort of Buenos Aires (Argentina)',
      'Fuerte Bulnes (Chile)',
      'Fort Niebla (Chile)',
      'Fort Corral (Chile)',
      'Fort Mancera (Chile)',
      'Fortaleza del Cerro (Uruguay)',
      'Santa Teresa Fortress (Uruguay)',
      'San Miguel Fortress (Uruguay)',
      'Fuerte de Buenos Aires (Argentina)',
      'Fortaleza Protectora Argentina (Argentina)',
      'Fuerte San José (Argentina)',
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
    'European Marches': [
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
  VenueGroup.oceania: <String, List<String>>{
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

/// Every fort inside one circuit, summed across its kingdoms.
int subKingdomCountForGroup(VenueGroup group) {
  int total = 0;
  for (final venue in venuesForGroup(group)) {
    total += subKingdomCountFor(group: group, kingdomName: venue.name);
  }
  return total;
}

/// Every fort in the game — the full conquest target the home screen sets.
///
/// Derived from the fort tables rather than written down as a number, so
/// adding a fort moves the target everywhere it is advertised.
int totalSubKingdomCount() {
  int total = 0;
  for (final group in kVenueGroups) {
    total += subKingdomCountForGroup(group);
  }
  return total;
}

/// Every kingdom in the game, across all circuits. One title per kingdom.
int totalKingdomCount() {
  int total = 0;
  for (final group in kVenueGroups) {
    total += venuesForGroup(group).length;
  }
  return total;
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
  return t;
}

String subKingdomDisplayName({
  required VenueGroup group,
  required String kingdomName,
  required int index,
}) {
  final i = index - 1;
  if (i < 0) return 'Fort 01';

  final names = subKingdomNamesFor(group: group, kingdomName: kingdomName);
  if (i < names.length) return names[i];

  return 'Fort ${index.toString().padLeft(2, '0')}';
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
  final byGroup = _subKingdomPrizeOrderCache.putIfAbsent(
      group, () => <String, List<int>>{});
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
