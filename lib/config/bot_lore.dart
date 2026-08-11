import 'dart:math' as math;

/// Internal backstory metadata for bots.
///
/// Not shown in-game yet; intended for future character/promotional content.
typedef BotLore = ({
  String hometown,
  String profession,
  int casesFiled,
  int convictions,
  int trialsOngoing,
});

String _canonicalKingdomName(String kingdomName) {
  final t = kingdomName.trim();
  if (t.isEmpty) return t;

  final lower = t.toLowerCase();

  // International synonyms.
  if (lower == 'amazon' ||
      lower == 'south america' ||
      lower == 's america' ||
      lower == 's. america') {
    return 'S. America';
  }
  if (lower == 'america' ||
      lower == 'usa' ||
      lower == 'u.s.a' ||
      lower == 'us' ||
      lower == 'united states' ||
      lower == 'united states of america' ||
      lower == 'north america' ||
      lower == 'n america' ||
      lower == 'n. america') {
    return 'N. America';
  }
  if (lower == 'southeast') return 'Asia';

  // India synonyms.
  if (lower == 'delhi') return 'New Delhi';
  if (lower == 'maratha') return 'Maratha Empire';
  if (lower == 'sikh') return 'Sikh Empire';

  return t;
}

const Map<String, List<String>> _hometownsByKingdom = <String, List<String>>{
  // India circuit
  'Maratha Empire': <String>[
    'Pune Cantonment',
    'Satara Fort Ward',
    'Kolhapur Old Town',
    'Nashik Riverside',
    'Aurangabad Bazaar',
    'Nagpur Ring Road',
    'Solapur Mill Line',
    'Thane Creek Side',
  ],
  'Mysore': <String>[
    'Mysuru Palace Road',
    'Mandya Sugar Belt',
    'Coorg Hill Colony',
    'Hassan Lakeview',
    'Shivamogga Circle',
    'Tumakuru North End',
    'Udupi Temple Lane',
    'Bengaluru South Gate',
  ],
  'Sikh Empire': <String>[
    'Amritsar Heritage Lane',
    'Ludhiana Mill Block',
    'Jalandhar Sports Row',
    'Patiala Court Square',
    'Bathinda Canal Side',
    'Hoshiarpur Hillside',
    'Mohali Tech Park',
    'Gurdaspur Market Road',
  ],
  'Jaipur': <String>[
    'Jaipur Pink Quarter',
    'Udaipur Lakefront',
    'Jodhpur Blue Street',
    'Ajmer Dargah Lane',
    'Kota Coaching Colony',
    'Bikaner Fort Road',
    'Alwar Ridge Block',
    'Sikar Old Bazaar',
  ],
  'Baroda': <String>[
    'Vadodara Palace Circle',
    'Surat Textile Ward',
    'Ahmedabad Riverfront',
    'Rajkot Ring Road',
    'Bhavnagar Dockside',
    'Jamnagar Oil Avenue',
    'Gandhinagar Sector 7',
    'Anand Dairy District',
  ],
  'Hyderabad': <String>[
    'Charminar Old City',
    'Hitech City Block',
    'Secunderabad Parade Rd',
    'Warangal Fort Ward',
    'Nizamabad South End',
    'Karimnagar Lake Road',
    'Gachibowli Heights',
    'Begumpet Airport Road',
  ],
  'Indore': <String>[
    'Indore Sarafa Lane',
    'Ujjain Temple Road',
    'Bhopal Lakeview',
    'Dewas Industrial Strip',
    'Ratlam Rail Colony',
    'Jabalpur Ridge Line',
    'Gwalior Fort Gate',
    'Sagar Old Town',
  ],
  'Sikkim': <String>[
    'Gangtok Ridge Walk',
    'Namchi Monastery Row',
    'Pelling Viewpoint',
    'Mangan River Bend',
    'Rangpo Bridge Town',
    'Rumtek Hill Quarter',
    'Gyalshing Market',
    'Singtam Valley Road',
  ],
  'New Delhi': <String>[
    'Lajpat Nagar Block',
    'Karol Bagh Lane',
    'Dwarka Sector 9',
    'Rohini Phase 2',
    'Connaught Place Ring',
    'Noida Sector 62',
    'Gurugram Cyber City',
    'South Ex Part 1',
  ],
  'Travancore': <String>[
    'Kochi Harbor Road',
    'Trivandrum Museum Row',
    'Kollam Backwater Line',
    'Alappuzha Canal Town',
    'Thrissur Round Block',
    'Kottayam Rubber Belt',
    'Kozhikode Beach Lane',
    'Kannur Fort Street',
  ],

  // International circuit
  'Africa': <String>[
    'Nairobi Ngong Road',
    'Accra Osu Quarter',
    'Lagos Mainland',
    'Johannesburg CBD',
    'Cape Town Sea Point',
    'Kigali Hill District',
    'Dakar Medina',
    'Addis Bole Side',
  ],
  'S. America': <String>[
    'São Paulo Centro',
    'Rio Copacabana',
    'Bogotá Chapinero',
    'Lima Miraflores',
    'Santiago Providencia',
    'Quito La Mariscal',
    'Medellín Laureles',
    'Buenos Aires Palermo',
  ],
  'N. America': <String>[
    'Austin East Side',
    'Chicago Lakeview',
    'Las Vegas Summerlin',
    'Toronto Harbourfront',
    'Vancouver Kitsilano',
    'Mexico City Roma Norte',
    'Seattle Ballard',
    'New York Queens',
  ],
  'Arabia': <String>[
    'Dubai Marina',
    'Riyadh Olaya',
    'Doha West Bay',
    'Muscat Mutrah',
    'Jeddah Corniche',
    'Abu Dhabi Khalidiya',
    'Manama Seef',
    'Kuwait City Sharq',
  ],
  'Australia': <String>[
    'Sydney Inner West',
    'Melbourne Docklands',
    'Brisbane South Bank',
    'Perth Fremantle',
    'Adelaide Glenelg',
    'Hobart Battery Point',
    'Darwin Waterfront',
    'Canberra Belconnen',
  ],
  'China': <String>[
    'Shanghai Pudong',
    'Shenzhen Nanshan',
    'Beijing Chaoyang',
    'Guangzhou Tianhe',
    'Chengdu High-Tech Zone',
    'Hangzhou Binjiang',
    'Wuhan Optics Valley',
    'Xi’an City Wall',
  ],
  'Europe': <String>[
    'Berlin Mitte',
    'Paris Bastille',
    'Madrid Centro',
    'Rome Trastevere',
    'Amsterdam Jordaan',
    'Stockholm Södermalm',
    'Dublin Docklands',
    'Lisbon Alfama',
  ],
  'India': <String>[
    'Mumbai Harbour Line',
    'Bengaluru Outer Ring',
    'Kolkata College Street',
    'Chennai Beach Road',
    'Goa Panjim',
    'Lucknow Hazratganj',
    'Jaipur Old City',
    'Kochi Marine Drive',
  ],
  'Russia': <String>[
    'Moscow Tagansky',
    'St. Petersburg Neva',
    'Kazan Riverside',
    'Novosibirsk Akadem',
    'Yekaterinburg VIZ',
    'Sochi Seaside',
    'Vladivostok Bayfront',
    'Perm Old Quarter',
  ],
  'Asia': <String>[
    'Singapore Bugis',
    'Bangkok Sukhumvit',
    'Kuala Lumpur KLCC',
    'Jakarta Kemang',
    'Manila Makati',
    'Hanoi Old Quarter',
    'Ho Chi Minh D1',
    'Phnom Penh Riverside',
  ],
};

const Map<String, List<String>> _professionsByKingdom = <String, List<String>>{
  // India circuit
  'Maratha Empire': <String>[
    'Logistics Supervisor',
    'Civil Engineer',
    'Bank Teller',
    'Gym Coach',
    'Small Business Owner',
    'Auto Workshop Manager',
    'Railway Clerk',
    'Restaurant Manager',
  ],
  'Mysore': <String>[
    'Coffee Roaster',
    'Software Tester',
    'School Teacher',
    'Hospital Pharmacist',
    'Textile Trader',
    'Tour Guide',
    'Mechanic',
    'Photographer',
  ],
  'Sikh Empire': <String>[
    'Agriculture Analyst',
    'Transport Contractor',
    'Fitness Trainer',
    'Retail Shopkeeper',
    'Nurse',
    'Sports Equipment Seller',
    'Warehouse Manager',
    'Accountant',
  ],
  'Jaipur': <String>[
    'Jewelry Designer',
    'Event Planner',
    'Hotel Front Desk',
    'Architect Assistant',
    'Sales Executive',
    'Bus Dispatcher',
    'Artisan Weaver',
    'Travel Agent',
  ],
  'Baroda': <String>[
    'Chemical Plant Tech',
    'Insurance Agent',
    'Export Coordinator',
    'Lab Assistant',
    'Call Center Lead',
    'Finance Analyst',
    'Pharma QA Associate',
    'Site Supervisor',
  ],
  'Hyderabad': <String>[
    'App Developer',
    'Cybersecurity Analyst',
    'Chef',
    'Medical Sales Rep',
    'Network Engineer',
    'QA Engineer',
    'Startup Operator',
    'Civil Services Aspirant',
  ],
  'Indore': <String>[
    'Retail Trader',
    'Account Manager',
    'Food Vendor',
    'Operations Executive',
    'Data Entry Supervisor',
    'Factory Supervisor',
    'Delivery Coordinator',
    'Customer Support Lead',
  ],
  'Sikkim': <String>[
    'Eco-Tourism Guide',
    'Cafe Owner',
    'Forest Ranger',
    'Hotel Steward',
    'Local Reporter',
    'Nursing Assistant',
    'Shopkeeper',
    'Taxi Operator',
  ],
  'New Delhi': <String>[
    'Policy Researcher',
    'Marketing Manager',
    'Paralegal',
    'UX Designer',
    'Real Estate Agent',
    'Media Producer',
    'Sales Consultant',
    'Fitness Coach',
  ],
  'Travancore': <String>[
    'Marine Logistics Exec',
    'Nurse',
    'Spice Trader',
    'Tour Operator',
    'Boat Mechanic',
    'Accountant',
    'Hotel Manager',
    'Kitchen Supervisor',
  ],

  // International circuit
  'Africa': <String>[
    'Solar Installer',
    'Mobile Money Agent',
    'Wildlife Vet Tech',
    'Shop Owner',
    'Public Transit Clerk',
    'Hotel Concierge',
    'Construction Foreman',
    'Radio Host',
  ],
  'S. America': <String>[
    'Coffee Export Agent',
    'Bartender',
    'Tour Guide',
    'Graphic Designer',
    'Bike Courier',
    'Call Center Lead',
    'Factory Technician',
    'Street Food Vendor',
  ],
  'N. America': <String>[
    'Paramedic',
    'Software Engineer',
    'Barista',
    'Truck Dispatcher',
    'Retail Manager',
    'High School Coach',
    'Mortgage Broker',
    'Night Shift Security',
  ],
  'Arabia': <String>[
    'Airport Ground Staff',
    'Oilfield Technician',
    'Hospitality Manager',
    'Procurement Officer',
    'Site Safety Officer',
    'Fleet Supervisor',
    'Facilities Engineer',
    'Account Executive',
  ],
  'Australia': <String>[
    'Mining Technician',
    'Surf Instructor',
    'Paramedic',
    'Cafe Owner',
    'Electrician',
    'Warehouse Lead',
    'Construction Planner',
    'Wildlife Rescuer',
  ],
  'China': <String>[
    'Supply Chain Planner',
    'App Designer',
    'Factory Supervisor',
    'E-commerce Seller',
    'Hardware Engineer',
    'Accountant',
    'Restaurant Owner',
    'Civil Engineer',
  ],
  'Europe': <String>[
    'Data Analyst',
    'Chef',
    'Architect',
    'Sales Manager',
    'Nurse',
    'Bartender',
    'Product Manager',
    'Train Conductor',
  ],
  'India': <String>[
    'Startup Founder',
    'Chartered Accountant',
    'Teacher',
    'Software Engineer',
    'Hospital Admin',
    'Video Editor',
    'Fitness Trainer',
    'Retail Owner',
  ],
  'Russia': <String>[
    'Mechanical Engineer',
    'IT Support Lead',
    'Mining Surveyor',
    'Security Consultant',
    'Rail Operator',
    'Welding Foreman',
    'Warehouse Manager',
    'Delivery Dispatcher',
  ],
  'Asia': <String>[
    'Port Operations Exec',
    'Tour Coordinator',
    'Restaurant Manager',
    'Customer Support Lead',
    'Graphic Designer',
    'Flight Attendant',
    'Market Trader',
    'Logistics Coordinator',
  ],
};

int _fnv1a32(String s) {
  var hash = 0x811c9dc5;
  for (final cu in s.codeUnits) {
    hash ^= cu;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

String _pickFromList(List<String> values, int seed) {
  if (values.isEmpty) return '—';
  return values[seed.abs() % values.length];
}

({int casesFiled, int convictions, int trialsOngoing}) _criminalStatusFor({
  required String botName,
  required String kingdomName,
}) {
  final int seed = _fnv1a32('crime|$kingdomName|$botName|v1');
  final int r = seed % 100;
  final int casesFiled = (r < 74)
      ? 0
      : (r < 92)
          ? 1
          : (r < 98)
              ? 2
              : 3;

  if (casesFiled == 0) {
    return (casesFiled: 0, convictions: 0, trialsOngoing: 0);
  }

  final int r2 = (seed >> 8) & 0xFF;
  final int r3 = (seed >> 16) & 0xFF;

  int convictions = 0;
  if (r2 < 55) {
    convictions = 0;
  } else if (r2 < 88) {
    convictions = 1;
  } else {
    convictions = math.min(2, casesFiled);
  }
  if (convictions < 0) convictions = 0;
  if (convictions > casesFiled) convictions = casesFiled;

  final int remaining = math.max(0, casesFiled - convictions);
  int trialsOngoing = remaining == 0 ? 0 : (r3 % (remaining + 1));
  if (trialsOngoing < 0) trialsOngoing = 0;
  if (trialsOngoing > remaining) trialsOngoing = remaining;

  return (
    casesFiled: casesFiled,
    convictions: convictions,
    trialsOngoing: trialsOngoing,
  );
}

BotLore botLoreFor({
  required String botName,
  required String kingdomName,
}) {
  final String k = _canonicalKingdomName(kingdomName);
  final List<String> hometowns = _hometownsByKingdom[k] ??
      const <String>[
        'Old Town',
        'Riverside',
        'Market Road',
        'Harbor District',
      ];
  final List<String> professions = _professionsByKingdom[k] ??
      const <String>[
        'Office Associate',
        'Driver',
        'Shop Owner',
        'Technician',
      ];

  final hometown = _pickFromList(
    hometowns,
    _fnv1a32('town|$k|$botName|v1'),
  );
  final profession = _pickFromList(
    professions,
    _fnv1a32('job|$k|$botName|v1'),
  );
  final criminal = _criminalStatusFor(botName: botName, kingdomName: k);

  return (
    hometown: hometown,
    profession: profession,
    casesFiled: criminal.casesFiled,
    convictions: criminal.convictions,
    trialsOngoing: criminal.trialsOngoing,
  );
}
