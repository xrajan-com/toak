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
      'Rabdentse (India)',
      'Damsang Fort (India)',
      'Budang Gadi Fort (India)',
      'Buxa Fort (India)',
      'Barabati Fort (India)',
      'Bihu Loukon Fort (India)',
      'Garh Doul (India)',
      'Ita Fort (India)',
      'Kangla Fort (India)',
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
    'Africa': [
      'Bastion de la Sqala (Morocco)',
      'Cairo Citadel (Egypt)',
      'Castle of Good Hope (South Africa)',
      'Fort d’Estrees (Senegal)',
      'Fort Dauphin (Madagascar)',
      'Fort Jesus (Kenya)',
      'Old Fort Durban (South Africa)',
      'Apollonia Fortress (Libya)',
      'Camp Lemonnier (Djibouti)',
      'Fort James / Kunta Kinteh Island (Gambia)',
    ],
    'S. America': [
      'Fort Bueras (Chile)',
      'Fort Copacabana (Brazil)',
      'Fort of Buenos Aires (Argentina)',
      'Itaipu Fortress (Brazil)',
      'Real Felipe Fortress (Peru)',
      'San Felipe de Barajas (Colombia)',
      'Fortaleza de Santa Cruz da Barra (Brazil)',
      'Fortaleza de São José de Macapá (Brazil)',
    ],
    'N. America': [
      'San Juan de Ulúa (Mexico)',
      'Fort Dallas (United States)',
      'Fort Dearborn (United States)',
      'Fort Independence (United States)',
      'Fort McNair (United States)',
      'Fort Point (United States)',
      'Fort Travis (United States)',
      'Fort Wadsworth (United States)',
      'Fort York (Canada)',
      'Old Las Vegas Fort (United States)',
      'Castillo de San Marcos (United States)',
      'Fort Ticonderoga (United States)',
      'Fort George (Belize)',
      'Fort Sumter (United States)',
      'Fort McHenry (United States)',
      'Fort Monroe (United States)',
      'Fort Pulaski (United States)',
      'Fort Moultrie (United States)',
      'Fort Matanzas (United States)',
      'Fort Pickens (United States)',
      'Fort Morgan (United States)',
      'Fort Washington (United States)',
      'Fort Niagara (United States)',
      'Fort Stanwix (United States)',
      'Fort Crown Point (United States)',
      'Fort Pitt (United States)',
      'Fort Necessity (United States)',
      'Fort Frederica (United States)',
      'The Alamo (United States)',
      'Fort Davis (United States)',
      'Fort Concho (United States)',
      'Fort Laramie (United States)',
      'Fort Bridger (United States)',
      'Fort Vancouver (United States)',
      'Fort Clatsop (United States)',
      'Fort Snelling (United States)',
      'Fort Leavenworth (United States)',
      'Fort Sill (United States)',
      'Fort Knox (United States)',
      'Bent’s Old Fort (United States)',
      'Fort Union (United States)',
      'Fort Bowie (United States)',
      'Fort Robinson (United States)',
    ],
    'Arabia': [
      'Al Jalali Fort (Oman)',
      'Al Koot Fort (Qatar)',
      'Asfan Castle (Saudi Arabia)',
      'Bahrain Fort (Bahrain)',
      'Citadel of Damascus (Syria)',
      'Kuwait Red Fort (Kuwait)',
      'Masmak Fort (Saudi Arabia)',
      'Qasr Al Hosn (United Arab Emirates)',
      'Sidon Sea Castle (Lebanon)',
    ],
    'China': [
      'Dapeng Fortress (China)',
      'Juyong Pass Fortress (China)',
      'Weiyuan Fort (China)',
      'Wusong Fortress (China)',
      'Xi’an City Wall (China)',
      'Jiayu Pass Fortress (China)',
      'Shanhai Pass Fortress (China)',
    ],
    'Far East': [
      'Edo Castle (Japan)',
      'Nijo Castle (Japan)',
      'Himeji Castle (Japan)',
      'Osaka Castle (Japan)',
      'Kumamoto Castle (Japan)',
      'Suwon Hwaseong Fortress (South Korea)',
      'Namhansanseong Fortress (South Korea)',
      'Hwaseong Haenggung (South Korea)',
    ],
    'Asia Rest': [
      'Gia Dinh Citadel (Vietnam)',
      'Imperial Citadel of Thang Long (Vietnam)',
      'Longvek Citadel (Cambodia)',
      'Phra Sumen Fort (Thailand)',
      'Rawat Fort (Pakistan)',
      'Mandalay Palace Fort (Myanmar)',
      'Red Fort of Lahore / Lahore Fort (Pakistan)',
      'Bala Hissar Peshawar (Pakistan)',
    ],
    'Central Asia': [
      'Ark of Bukhara (Uzbekistan)',
      'Itchan Kala (Uzbekistan)',
      'Ayaz Kala (Uzbekistan)',
      'Toprak Kala (Uzbekistan)',
      'Kunya-Ark Citadel (Uzbekistan)',
      'Gissar Fortress (Tajikistan)',
      'Hulbuk Fortress (Tajikistan)',
      'Nisa Fortress (Turkmenistan)',
      'Merv Fortifications (Turkmenistan)',
      'Sauran Fortress (Kazakhstan)',
      'Otrar Fortress (Kazakhstan)',
    ],
    'Persia': [
      'Arg-e Bam (Iran)',
      'Rayen Castle (Iran)',
      'Falak-ol-Aflak Castle (Iran)',
      'Narin Castle (Iran)',
      'Shush Castle (Iran)',
      'Erbil Citadel (Iraq)',
      'Al-Ukhaidir Fortress (Iraq)',
      'Kirkuk Citadel (Iraq)',
    ],
    'Europe': [
      'Acropolis of Athens (Greece)',
      'Tower of London (United Kingdom)',
      'Alhambra (Spain)',
      'Edinburgh Castle (United Kingdom)',
      'Windsor Castle (United Kingdom)',
      'Castel Sant’Angelo (Italy)',
      'Carcassonne Citadel (France)',
      'Hohensalzburg Fortress (Austria)',
      'Malbork Castle (Poland)',
      'Bran Castle (Romania)',
      'Suomenlinna Fortress (Finland)',
      'Bellinzona Castles (Switzerland)',
      'Château de Vincennes (France)',
      'Sforza Castle (Italy)',
      'Spandau Citadel (Germany)',
      'Montjuic Castle (Spain)',
      'Kyiv Fortress (Ukraine)',
    ],
  },
  VenueGroup.northAmerica: <String, List<String>>{
    'Dominion of Canada': [
      'CFB Halifax',
      'CFB Esquimalt',
      'CFB Kingston',
      'CFB Petawawa',
      'CFB Gagetown',
      'CFB Borden',
      'CFB Trenton',
      'CFB Cold Lake',
      'CFB Valcartier',
    ],
    'Massachusetts': [
      'Hanscom Air Force Base',
      'Springfield Armory',
      'Charlestown Navy Yard',
      'Fort Andrews',
      'Fort Revere',
      'Fort Banks',
      'Fort Sewall',
      'Fort Strong',
      'Fort Phoenix',
      'Otis Air National Guard Base',
    ],
    'New York': [
      'West Point Military Academy',
      'Fort Drum',
      'Fort Totten',
      'Fort Montgomery',
      'Fort Clinton',
      'Brooklyn Navy Yard',
      'Watervliet Arsenal',
      'Madison Barracks',
      'Fort Wood',
      'Camp Smith',
    ],
    'Virginia': [
      'Fort Belvoir',
      'Fort Gregg-Adams',
      'Fort Eustis',
      'Fort Story',
      'Fort Myer',
      'Fort Hunt',
      'Norfolk Naval Station',
      'Marine Corps Base Quantico',
      'Joint Base Langley-Eustis',
      'Naval Air Station Oceana',
    ],
    'Illinois': [
      'Rock Island Arsenal',
      'Great Lakes Naval Station',
      'Camp Grant',
      'Camp Lincoln',
      'Fort Sheridan',
      'Fort Massac',
      'Fort de Chartres',
      'Camp Ellis',
      'Fort Crevecoeur',
      'Joliet Army Ammunition Plant',
    ],
    'Florida': [
      'Fort Jefferson',
      'Fort Clinch',
      'Fort Barrancas',
      'Fort Zachary Taylor',
      'Fort Brooke',
      'Naval Air Station Pensacola',
      'Naval Station Mayport',
      'Cape Canaveral Space Force Station',
      'Patrick Space Force Base',
      'Homestead Air Reserve Base',
    ],
    'Texas': [
      'Fort Bliss',
      'Fort Cavazos',
      'Fort Sam Houston',
      'Laughlin Air Force Base',
      'Corpus Christi Naval Air Station',
      'Fort McKavett',
      'Presidio La Bahía',
      'Fort Chadbourne',
      'Fort McIntosh',
      'Fort Stockton',
    ],
    'Kansas': [
      'Fort Riley',
      'Fort Larned',
      'Fort Harker',
      'Fort Wallace',
      'Fort Zarah',
      'Fort Dodge',
      'Camp Funston',
      'Smoky Hill Depot',
      'Fort Mann',
      'Fort Aubrey',
    ],
    'Colorado': [
      'Fort Garland',
      'Fort Logan',
      'Camp Hale',
      'Fort Lyon',
      'Fort Vasquez',
      'Fort St. Vrain',
      'Rocky Mountain Arsenal',
      'Buckley Space Force Base',
      'Fort Sedgwick',
      'Fort Lupton',
    ],
    'California': [
      'Vandenberg Space Force Base',
      'Edwards Air Force Base',
      'China Lake Naval Weapons Station',
      'Camp Pendleton',
      'Fort Irwin',
      'Travis Air Force Base',
      'Naval Base San Diego',
      'Mare Island Naval Shipyard',
      'Moffett Federal Airfield',
      'Lawrence Livermore National Laboratory',
    ],
  },
  VenueGroup.euro: <String, List<String>>{
    'Britain': [
      'Bodiam Castle (United Kingdom)',
      'Caernarfon Castle (United Kingdom)',
      'Dover Castle (United Kingdom)',
      'Eilean Donan Castle (United Kingdom)',
      'Stirling Castle (United Kingdom)',
      'Caerphilly Castle (United Kingdom)',
      'Bamburgh Castle (United Kingdom)',
    ],
    'France': [
      'Château de Chambord (France)',
      'Fort Boyard (France)',
      'Château de Pierrefonds (France)',
      'Château de Chinon (France)',
      'Château de Fougères (France)',
      'Château de Saumur (France)',
    ],
    'Italy': [
      'Rocca Calascio (Italy)',
      'Castel del Monte (Italy)',
      'Castello di Miramare (Italy)',
      'Castello Estense (Italy)',
      'Castel Nuovo (Italy)',
      'Rocca Maggiore (Italy)',
    ],
    'Spain': [
      'Alcázar of Segovia (Spain)',
      'Manzanares Castle (Spain)',
      'Castillo de Coca (Spain)',
      'Castle of Loarre (Spain)',
      'Castillo de Peñafiel (Spain)',
      'Alcazaba of Málaga (Spain)',
    ],
    'Portugal': [
      'Elvas Fortifications (Portugal)',
      'Guimarães Castle (Portugal)',
      'Pena Palace (Portugal)',
      'Castle of the Moors (Portugal)',
      'Belém Tower (Portugal)',
      'São Jorge Castle (Portugal)',
    ],
    'North Sea': [
      'Fort Pampus (Netherlands)',
      'Muiderslot Castle (Netherlands)',
      'Bourtange Fortress (Netherlands)',
      'Naarden Fortress (Netherlands)',
      'Gravensteen (Belgium)',
      'Bouillon Castle (Belgium)',
      'Bock Casemates (Luxembourg)',
      'Gutenberg Castle (Liechtenstein)',
    ],
    'Scandinavia': [
      'Kronborg Castle (Denmark)',
      'Bohus Fortress (Sweden)',
      'Kalmar Castle (Sweden)',
      'Olavinlinna Castle (Finland)',
      'Vardøhus Fortress (Norway)',
      'Bergenhus Fortress (Norway)',
      'Skansinn Fort (Iceland)',
    ],
    'Baltic Marches': [
      'Kamianets-Podilskyi Castle (Ukraine)',
      'Khotyn Fortress (Ukraine)',
      'Akkerman Fortress (Ukraine)',
      'Brest Fortress (Belarus)',
      'Mir Castle (Belarus)',
      'Nesvizh Castle (Belarus)',
      'Trakai Island Castle (Lithuania)',
      'Narva Castle (Estonia)',
      'Turaida Castle (Latvia)',
      'Kaunas Castle (Lithuania)',
    ],
    'Russia & Siberia': [
      'Moscow Kremlin (Russia)',
      'Peter and Paul Fortress (Russia)',
      'Smolensk Fortress (Russia)',
      'Izborsk Fortress (Russia)',
      'Vladivostok Fortress (Russia)',
      'Tobolsk Kremlin (Russia)',
      'Omsk Fortress (Russia)',
      'Kuznetsk Fortress (Russia)',
      'Naryn-Kala Fortress (Russia)',
      'Derbent Fortress (Russia)',
    ],
    'Mediterranean': [
      'Acrocorinth (Greece)',
      'Palamidi Fortress (Greece)',
      'Castle of Mystras (Greece)',
      'Methoni Castle (Greece)',
      'Rumelihisarı (Turkey)',
      'Yedikule Fortress (Turkey)',
      'Predjama Castle (Slovenia)',
      'Lovrijenac Fortress (Croatia)',
      'Klis Fortress (Croatia)',
      'St. Nicholas Fortress (Croatia)',
      'Kamerlengo Castle (Croatia)',
      'Golubac Fortress (Serbia)',
      'Tsarevets Fortress (Bulgaria)',
      'Fort Antoine (Monaco)',
      'Fort St Elmo (Malta)',
      'Moorish Castle (Gibraltar)',
      'Kyrenia Castle (Cyprus)',
    ],
  },
  VenueGroup.oceania: <String, List<String>>{
    'Alaska': [
      'Fort William H. Seward (United States)',
      'Castle Hill / Baranof Castle Site (United States)',
      'Fort Abercrombie (United States)',
      'Fort Egbert (United States)',
      'Fort Davis Nome (United States)',
      'Fort Gibbon (United States)',
      'Camp Century (Greenland)',
    ],
    'Caribbean': [
      'Brimstone Hill Fortress (Saint Kitts and Nevis)',
      'Castillo San Felipe del Morro (United States)',
      'Castillo San Cristóbal (United States)',
      'Castillo de San Pedro de la Roca (Cuba)',
      'Fort Charles (Jamaica)',
      'Fort Charlotte (The Bahamas)',
      'Saint Ann’s Fort (Barbados)',
      'Fort George Grenada (Grenada)',
      'Fort King George Tobago (Trinidad and Tobago)',
      'Fort Shirley (Dominica)',
    ],
    'Dragonland': [
      'Guia Fortress (China)',
      'Monte Fort (China)',
      'Tung Chung Fort (China)',
      'Kowloon Walled City Site (China)',
      'Fort Santo Domingo (Taiwan)',
      'Eternal Golden Castle (Taiwan)',
      'Anping Fort (Taiwan)',
      'Hobe Fort (Taiwan)',
    ],
    'Straits': [
      'Fort Siloso (Singapore)',
      'Fort Canning (Singapore)',
      'Labrador Battery (Singapore)',
      'Johore Battery (Singapore)',
      'Fort Cornwallis (Malaysia)',
      'A Famosa (Malaysia)',
      'Fort Margherita (Malaysia)',
      'Kuala Kedah Fort (Malaysia)',
      'Fort Rotterdam (Indonesia)',
      'Fort Belgica (Indonesia)',
      'Fort Tolukko (Indonesia)',
      'Fort Marlborough (Indonesia)',
      'Kota Batu (Brunei)',
    ],
    'Indian Ocean': [
      'Galle Fort (Sri Lanka)',
      'Jaffna Fort (Sri Lanka)',
      'Batticaloa Fort (Sri Lanka)',
      'Fort Fredrick (Sri Lanka)',
      'Fort Adelaide (Mauritius)',
      'Fort George Mauritius (Mauritius)',
      'Utheemu Ganduvaru (Maldives)',
      'Mulee’aage Palace (Maldives)',
      'Addu Atoll British Loyalty Remains (Maldives)',
      'Fort Victoria Seychelles Site (Seychelles)',
    ],
    'Pacific': [
      'Fort Takapuna (New Zealand)',
      'Fort Ballance (New Zealand)',
      'Fort Jervois (New Zealand)',
      'North Head Historic Reserve (New Zealand)',
      'Tavuni Hill Fort (Fiji)',
      'Fort Apugan (Guam / United States)',
      'Fort Nuestra Señora de la Soledad (Guam / United States)',
      'Fort Santa Agueda (Guam / United States)',
      'Arai-Te-Tonga (Cook Islands)',
      'Peleliu Fortifications (Palau)',
      'Espiritu Santo WWII Base (Vanuatu)',
    ],
    'British Isles': [
      'Fort Barrington (Antigua and Barbuda)',
      'Fort James Antigua (Antigua and Barbuda)',
      'The Garrison (Bermuda)',
      'Fort St. Catherine (Bermuda)',
      'Fort Hamilton (Bermuda)',
      'Fort George Cayman (Cayman Islands)',
      'Fort Burt (British Virgin Islands)',
      'Fort Recovery (British Virgin Islands)',
      'Fort George Montserrat (Montserrat)',
      'High Knoll Fort (Saint Helena)',
      'Peel Castle (Isle of Man)',
    ],
    'French Isles': [
      'Fort Napoléon des Saintes (Guadeloupe / France)',
      'Fort Delgrès (Guadeloupe / France)',
      'Fort Fleur d’Épée (Guadeloupe / France)',
      'Fort Saint Louis (Martinique / France)',
      'Fort Desaix (Martinique / France)',
      'Fort Royal / Fort-de-France (Martinique / France)',
      'Fort Teremba (New Caledonia / France)',
      'Fort de la Reine (Réunion / France)',
      'Dzaoudzi Fortifications (Mayotte / France)',
      'Wallis & Futuna Royal Sites (Wallis and Futuna / France)',
      'Fort Gustaf (Saint Barthelemy)',
      'Fort Taravao (French Polynesia)',
    ],
    'Dutch Isles': [
      'Fort Amsterdam (Curaçao / Netherlands)',
      'Fort Nassau (Curaçao / Netherlands)',
      'Fort Beekenburg (Curaçao / Netherlands)',
      'Fort Oranje Sint Eustatius (Sint Eustatius / Netherlands)',
      'Fort Zoutman (Aruba / Netherlands)',
      'Fort Bay (Saba / Netherlands)',
      'Fort Zeelandia Suriname (Suriname)',
      'Fort Nieuw Amsterdam (Suriname)',
    ],
    'American Isles': [
      'Fort Christian (United States)',
      'Fort Frederik (United States)',
      'Blackbeard’s Castle (United States)',
      'Fort Segarra (United States)',
      'Fort San Jose Guam (Guam / United States)',
      'Fort Kamehameha (United States)',
      'Fort DeRussy (United States)',
      'Fort Armstrong (United States)',
      'Fort Ruger (United States)',
      'Fort Hase (United States)',
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
