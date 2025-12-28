// lib/ui/screens/game_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/config/kingdom_titles.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart' show VenueGroup;
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/ui/utils/deck_cache.dart';
import 'package:ten_of_a_kind_poker/ui/utils/watermark_resolver.dart';
import 'package:ten_of_a_kind_poker/ui/utils/author_flash_gate.dart';
import 'package:ten_of_a_kind_poker/services/title_certificate_service.dart';
import 'package:ten_of_a_kind_poker/config/app_tier.dart';
import 'game_screen/renoir_ui.dart' show RenoirSignals;
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/overlays.dart' as go;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/models.dart'; // GCard
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/players.dart'; // Seat
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/hand_examples.dart';
import 'package:ten_of_a_kind_poker/game/events.dart' as ge;
import 'package:ten_of_a_kind_poker/ui/widgets/slash_avatar.dart'
    show DealerAvatarStyle;

import 'package:ten_of_a_kind_poker/ui/screens/game_screen/table.dart'
    show WoodType;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/ui.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/cards.dart'
    show CardBackTheme;

import 'game_screen/pacing.dart' as pace;

/* ---------------- Fixed bot roster (100 unique about lines) -------------- */

class _BotSpec {
  final String name;
  final String kingdom;
  final String about; // ≤ 30 chars
  final bool female;
  final bool hasAvatar;
  const _BotSpec(
    this.name,
    this.kingdom,
    this.about, {
    this.female = false,
    this.hasAvatar = true,
  });
}

// 30 Indian bots (3 per kingdom)
const List<_BotSpec> _indianBotSpecs = <_BotSpec>[
  // Maratha Empire
  _BotSpec('Arjun Deshmukh', 'Maratha Empire', 'Fort-born legend, no punts'),
  _BotSpec('Vidya Patil', 'Maratha Empire', 'Chai jokes, tight folds',
      female: true),
  _BotSpec('Sameer Pawar', 'Maratha Empire', 'Warhorse legend, pure value'),
  // Mysore
  _BotSpec('Kaveri Rao', 'Mysore', 'Palace queen, trophy hunter', female: true),
  _BotSpec('Rohan Iyengar', 'Mysore', 'Silk smile, savage shove'),
  _BotSpec('Meenakshi Gowda', 'Mysore', 'Sandalwood sweet, snap rage',
      female: true),
  // Sikh Empire
  _BotSpec('Gurdeep Singh', 'Sikh Empire', 'Turban jokes, iron patience'),
  _BotSpec('Amrita Kaur', 'Sikh Empire', 'Langar laughs, sneaky traps',
      female: true),
  _BotSpec('Harjit Sandhu', 'Sikh Empire', 'Bhangra heat, mean barrels'),
  // Jaipur
  _BotSpec('Rajvi Rathore', 'Jaipur', 'Pink city, sharp tongue bets',
      female: true),
  _BotSpec('Pratap Singh', 'Jaipur', 'Amber chill, fold like art'),
  _BotSpec('Smriti Vyas', 'Jaipur', 'Reads you, roasts you, repeats',
      female: true),
  // Baroda
  _BotSpec('Neel Patel', 'Baroda', 'Laxmi luck, legend hands'),
  _BotSpec('Bhavna Joshi', 'Baroda', 'Garbha grin, spicy 3-bet',
      female: true),
  _BotSpec('Kishor Mehta', 'Baroda', 'Statue-still, river surgeon'),
  // Hyderabad
  _BotSpec('Arjun Reddy', 'Hyderabad', 'Charminar fire, no mercy'),
  _BotSpec('Ayesha Qureshi', 'Hyderabad', 'Pearl smile, sharp elbows',
      female: true),
  _BotSpec('Jay Naidu', 'Hyderabad', 'Biryani hot, temper hotter'),
  // Indore
  _BotSpec('Tarun Malhotra', 'Indore', 'Sarafa swagger, shove first'),
  _BotSpec('Pooja Sharma', 'Indore', 'Poha polite, river vicious',
      female: true),
  _BotSpec('Devansh Agrawal', 'Indore', 'Rajwada chill, fold with flair'),
  // Sikkim
  _BotSpec('Geeta Chhetri', 'Sikkim', 'Peak zen, giggles at bluffs',
      female: true),
  _BotSpec('Sonu Biswas', 'Sikkim', 'Ridge-run rager, snap jams'),
  _BotSpec('Karan Bhutia', 'Sikkim', 'Yak stare, insta-overbet'),
  // New Delhi
  _BotSpec('Arvind Chundawat', 'New Delhi', 'Metro timing, meme machine'),
  _BotSpec('Farhan Siddiqui', 'New Delhi', 'Ring-road rage, rejam ready'),
  _BotSpec('Meera Luthra', 'New Delhi', 'Monsoon mood, mean raises',
      female: true),
  // Travancore
  _BotSpec('Anil Nair', 'Travancore', 'Backwater zen, laughs at tilts'),
  _BotSpec('Lekha Pillai', 'Travancore', 'Peppery reads, burn stacks',
      female: true),
  _BotSpec('Mohan Menon', 'Travancore', 'Coconut grin, snapcall savage'),

  // --- Super-bots ---
  // Maratha Empire
  _BotSpec('Bajirao Kale', 'Maratha Empire', 'ICM emperor, final boss'),
  _BotSpec('Savitri Shinde', 'Maratha Empire', 'Fortress queen, flawless KO',
      female: true),
  // Mysore
  _BotSpec('Veerendra Wodeyar', 'Mysore', 'Palace prince, zero punts'),
  _BotSpec('Anvika Nayak', 'Mysore', 'Trap legend, clean execution',
      female: true),
  // Sikh Empire
  _BotSpec('Jaspreet Dhillon', 'Sikh Empire', 'Grit GOAT, river royalty'),
  _BotSpec('Harleen Kaur', 'Sikh Empire', 'Steel nerves, mythic runouts',
      female: true),
  // Jaipur
  _BotSpec('Kunal Rathore', 'Jaipur', 'Desert king, unbluffable'),
  _BotSpec('Ishita Shekhawat', 'Jaipur', 'Pink-city legend, ice cold',
      female: true),
  // Baroda
  _BotSpec('Siddharth Gaekwad', 'Baroda', 'Edge finder, crown collector'),
  _BotSpec('Rupa Desai', 'Baroda', 'Temple calm, ruthless legend',
      female: true),
  // Hyderabad
  _BotSpec('Faizan Ali', 'Hyderabad', 'Bazaar boss, squeeze machine'),
  _BotSpec('Zoya Begum', 'Hyderabad', 'Razor thin, queen of jams',
      female: true),
  // Indore
  _BotSpec('Naveen Rajput', 'Indore', 'Sarafa shark, silent KO'),
  _BotSpec('Kriti Jain', 'Indore', 'Turn pressure, trophy hunter',
      female: true),
  // Sikkim
  _BotSpec('Tenzin Lama', 'Sikkim', 'Snowline sage, no mistakes'),
  _BotSpec('Pema Sherpa', 'Sikkim', 'Ridge queen, nuts only',
      female: true),
  // New Delhi
  _BotSpec('Kabir Verma', 'New Delhi', 'Ring-road ruler, no leaks'),
  _BotSpec('Ananya Khanna', 'New Delhi', 'Metro queen, stone-cold ICM',
      female: true),
  // Travancore
  _BotSpec('Hari Krishnan', 'Travancore', 'Backwater boss, value surgeon'),
  _BotSpec('Nila Varma', 'Travancore', 'Coconut crown, river tyrant',
      female: true),
];

// 30 International bots (3 per kingdom)
const List<_BotSpec> _intlBotSpecs = <_BotSpec>[
  // N. America
  _BotSpec('Jordan Walker', 'N. America', 'Route 66 legend, no brakes'),
  _BotSpec('Maria Rodriguez', 'N. America', 'Broadway bite, snap 3-bets',
      female: true),
  _BotSpec('Dexter Hughes', 'N. America', 'Vegas legend, chip magnet'),
  // Europe
  _BotSpec('Luca Bianchi', 'Europe', 'Espresso king, calm crusher'),
  _BotSpec('Sophie Dubois', 'Europe', 'Canal charm, cruel bluffs',
      female: true),
  _BotSpec('Nikos Papadakis', 'Europe', 'Acropolis chill, pun master'),
  // Russia
  _BotSpec('Nikolai Ivanov', 'Russia', 'Siberian glare, shove now'),
  _BotSpec('Anya Petrova', 'Russia', 'Metro menace, no small talk',
      female: true),
  _BotSpec('Sergei Volkov', 'Russia', 'Vodka jokes, iron folds'),
  // China
  _BotSpec('Wei Li', 'China', 'Dragon king, solver-backed'),
  _BotSpec('Xinyi Zhang', 'China', 'Silk smile, snap punish', female: true),
  _BotSpec('Bo Tao', 'China', 'Mahjong mood: all gas'),
  // Arabia
  _BotSpec('Samir Al-Farsi', 'Arabia', 'Dune wind, dagger raises'),
  _BotSpec('Layla Haddad', 'Arabia', 'Spice-souk sass, overbets',
      female: true),
  _BotSpec('Omar Rahman', 'Arabia', 'Falcon eyes, claws out'),
  // Africa
  _BotSpec('Kwame Mensah', 'Africa', 'Savanna snap, no patience'),
  _BotSpec('Zuri Okoro', 'Africa', 'Kora beat, mean re-raise',
      female: true),
  _BotSpec('Amare Bekele', 'Africa', 'Safari swagger, take it'),
  // S. America
  _BotSpec('Iara Santos', 'S. America', 'Canopy queen, chaos barrels',
      female: true),
  _BotSpec('Mateus Carvalho', 'S. America', 'Riverboat grin, safe folds'),
  _BotSpec('Belem Moraes', 'S. America', 'Rain-drum rage, shove',
      female: true),
  // Australia
  _BotSpec('Tahlia Lawson', 'Australia', 'Outback chill laughs at bluffs',
      female: true),
  _BotSpec('Cooper Mitchell', 'Australia', 'Harbour dad-jokes, tight'),
  _BotSpec('Nara Waru', 'Australia', 'Didgeridoo doom, snap jam',
      female: true),
  // India
  _BotSpec('Raghav Solanki', 'India', 'Tricolor calm, check-call king'),
  _BotSpec('Yuvraj Bhaduria', 'India', 'Freedom torch, burn stacks'),
  _BotSpec('Ruta Dogra', 'India', 'Bharat tour, ruthless reroutes',
      female: true),
  // Asia
  _BotSpec('Mahe Nguyen', 'Asia', 'Night market, nasty CR', female: true),
  _BotSpec('Somchai Prasert', 'Asia', 'Monsoon rage, barrels rain'),
  _BotSpec('Putri Dewi', 'Asia', 'Temple trapper, trophy shelf',
      female: true),

  // --- Super-bots ---
  // Africa
  _BotSpec('Kofi Adeyemi', 'Africa', 'Savanna GOAT, pounce mode'),
  _BotSpec('Amara Ndlovu', 'Africa', 'Lioness legend, fearless',
      female: true),
  // S. America
  _BotSpec('Rafael Mendes', 'S. America', 'Amazon legend, river knives'),
  _BotSpec('Camila Rojas', 'S. America', 'Samba queen, storm overbets',
      female: true),
  // N. America
  _BotSpec('Casey Morgan', 'N. America', 'Vegas final boss, clean KO'),
  _BotSpec('Brianna Lee', 'N. America', 'Broadway legend, snap queen',
      female: true),
  // Arabia
  _BotSpec('Hassan Al Noor', 'Arabia', 'Dune king, cold squeezes'),
  _BotSpec('Mariam Al Saif', 'Arabia', 'Spice-souk legend, sharp',
      female: true),
  // Australia
  _BotSpec("Blake O'Connor", 'Australia', 'Outback legend, unshakable'),
  _BotSpec('Sienna Harper', 'Australia', 'Harbour legend, laser value',
      female: true),
  // China
  _BotSpec('Ling Zhao', 'China', 'Dragon emperor, no leaks'),
  _BotSpec('Mei Chen', 'China', 'Mahjong legend, perfect lines',
      female: true),
  // Europe
  _BotSpec('Maximilian Keller', 'Europe', 'Solver GOAT, zero punts'),
  _BotSpec('Elena Rossi', 'Europe', 'Alpine legend, icy value',
      female: true),
  // Russia
  _BotSpec('Dmitri Kuznetsov', 'Russia', 'Ice-cold czar, final boss'),
  _BotSpec('Irina Sokolova', 'Russia', 'Metro legend, brutal value',
      female: true),
  // India
  _BotSpec('Arjun Malhotra', 'India', 'Tricolor titan, no leaks'),
  _BotSpec('Priya Nair', 'India', 'Spice queen, river lockdown',
      female: true),
  // Asia
  _BotSpec('Somporn Suriya', 'Asia', 'Monsoon master, crown reads'),
  _BotSpec('Lien Tran', 'Asia', 'Night-market legend, razor',
      female: true),
];

/* -------------------------- Bot aura catalog ----------------------------- */
const Map<String, int> _botAuraByName = {
  // Indian roster
  'Arjun Deshmukh': 94,
  'Vidya Patil': 88,
  'Sameer Pawar': 80,
  'Kaveri Rao': 95,
  'Rohan Iyengar': 79,
  'Meenakshi Gowda': 85,
  'Gurdeep Singh': 82,
  'Amrita Kaur': 92,
  'Harjit Sandhu': 81,
  'Rajvi Rathore': 83,
  'Pratap Singh': 76,
  'Smriti Vyas': 85,
  'Neel Patel': 90,
  'Bhavna Joshi': 83,
  'Kishor Mehta': 80,
  'Arjun Reddy': 89,
  'Ayesha Qureshi': 85,
  'Jay Naidu': 77,
  'Tarun Malhotra': 85,
  'Pooja Sharma': 85,
  'Devansh Agrawal': 84,
  'Geeta Chhetri': 82,
  'Sonu Biswas': 79,
  'Karan Bhutia': 85,
  'Arvind Chundawat': 92,
  'Farhan Siddiqui': 85,
  'Meera Luthra': 85,
  'Anil Nair': 88,
  'Lekha Pillai': 85,
  'Mohan Menon': 75,

  // International roster
  'Jordan Walker': 93,
  'Maria Rodriguez': 87,
  'Dexter Hughes': 80,
  'Luca Bianchi': 95,
  'Sophie Dubois': 85,
  'Nikos Papadakis': 82,
  'Nikolai Ivanov': 81,
  'Anya Petrova': 85,
  'Sergei Volkov': 78,
  'Wei Li': 95,
  'Xinyi Zhang': 85,
  'Bo Tao': 85,
  'Samir Al-Farsi': 85,
  'Layla Haddad': 91,
  'Omar Rahman': 83,
  'Kwame Mensah': 79,
  'Zuri Okoro': 83,
  'Amare Bekele': 81,
  'Iara Santos': 85,
  'Mateus Carvalho': 84,
  'Belem Moraes': 79,
  'Tahlia Lawson': 82,
  'Cooper Mitchell': 76,
  'Nara Waru': 77,
  'Raghav Solanki': 92,
  'Yuvraj Bhaduria': 85,
  'Ruta Dogra': 85,
  'Mahe Nguyen': 85,
  'Somchai Prasert': 77,
  'Putri Dewi': 80,

  // Added super-bots (no custom avatars yet)
  // India
  'Bajirao Kale': 99,
  'Savitri Shinde': 96,
  'Veerendra Wodeyar': 99,
  'Anvika Nayak': 96,
  'Jaspreet Dhillon': 99,
  'Harleen Kaur': 97,
  'Kunal Rathore': 97,
  'Ishita Shekhawat': 96,
  'Siddharth Gaekwad': 98,
  'Rupa Desai': 95,
  'Faizan Ali': 97,
  'Zoya Begum': 95,
  'Naveen Rajput': 96,
  'Kriti Jain': 95,
  'Tenzin Lama': 98,
  'Pema Sherpa': 96,
  'Kabir Verma': 97,
  'Ananya Khanna': 95,
  'Hari Krishnan': 96,
  'Nila Varma': 95,

  // International
  'Kofi Adeyemi': 97,
  'Amara Ndlovu': 96,
  'Rafael Mendes': 95,
  'Camila Rojas': 96,
  'Casey Morgan': 97,
  'Brianna Lee': 95,
  'Hassan Al Noor': 96,
  'Mariam Al Saif': 95,
  "Blake O'Connor": 96,
  'Sienna Harper': 95,
  'Ling Zhao': 99,
  'Mei Chen': 97,
  'Maximilian Keller': 99,
  'Elena Rossi': 97,
  'Dmitri Kuznetsov': 99,
  'Irina Sokolova': 97,
  'Arjun Malhotra': 96,
  'Priya Nair': 95,
  'Somporn Suriya': 96,
  'Lien Tran': 97,
};

/* ------------------------------ Tunables --------------------------------- */
const int _kInitialChips = 10000;
const int _kMaxSeats = 10;
const double _kRenoirLiftPx = 96.0; // keep hands on rail in UI
const int _kHeroAura = 0;

// Renoir flip timing (deal pose -> back) — tied to relaxed pacing
Duration get _kRenoirDealOn => Duration(milliseconds: pace.kDealGapMs);
Duration get _kRenoirDealHold => Duration(milliseconds: pace.kDealGapMs - 40);

/* ------------------------------ Types ------------------------------------ */
enum _Phase { predeal, preflop, flop, turn, river, showdown }

/* =============================== Widget =================================== */
class GameScreen extends StatefulWidget {
  final String tableName;
  final dynamic venue; // { name, flagAsset, background, felt }
  final bool playIntroWelcome;
  final VenueGroup? campaignGroup;
  final int? campaignSubKingdomIndex;
  final bool campaignMainEvent;

  const GameScreen({
    super.key,
    required this.tableName,
    required this.venue,
    this.playIntroWelcome = true,
    this.campaignGroup,
    this.campaignSubKingdomIndex,
    this.campaignMainEvent = false,
  });

  factory GameScreen.guestTable({
    required String tableName,
    required dynamic venue,
    bool playIntroWelcome = true,
    VenueGroup? campaignGroup,
    int? campaignSubKingdomIndex,
    bool campaignMainEvent = false,
  }) =>
      GameScreen(
        tableName: tableName,
        venue: venue,
        playIntroWelcome: playIntroWelcome,
        campaignGroup: campaignGroup,
        campaignSubKingdomIndex: campaignSubKingdomIndex,
        campaignMainEvent: campaignMainEvent,
      );

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  String? _monumentPathOverride;

  void _markCampaignWinIfApplicable({required bool heroWon}) {
    if (!heroWon) return;
    final group = widget.campaignGroup;
    if (group == null) return;
    final kingdomName = (widget.venue?.name ?? '').toString();
    if (kingdomName.trim().isEmpty) return;
    try {
      final progress = context.read<CampaignProgressService>();
      if (widget.campaignMainEvent) {
        progress.markMainEventCleared(group: group, kingdomName: kingdomName);
        return;
      }

      final idx = widget.campaignSubKingdomIndex;
      if (idx == null) return;
      progress.markCleared(
        group: group,
        kingdomName: kingdomName,
        subKingdomIndex: idx,
      );
    } catch (_) {}
  }

  DealerAvatarStyle _dealerAvatarForVenue(String venueName) {
    if (AppTier.isPremiumBuild) return DealerAvatarStyle.slash;

    final String v = venueName.toLowerCase().trim();

    if (v.contains('baroda')) return DealerAvatarStyle.baroda;
    if (v.contains('hyderabad')) return DealerAvatarStyle.hyderabad;
    if (v.contains('indore')) return DealerAvatarStyle.indore;
    if (v.contains('jaipur')) return DealerAvatarStyle.jaipur;
    if (v.contains('maratha')) return DealerAvatarStyle.marathaEmpire;
    if (v.contains('mysore')) return DealerAvatarStyle.mysore;
    if (v.contains('new delhi') || v.contains('delhi')) {
      return DealerAvatarStyle.newDelhi;
    }
    if (v.contains('sikh')) return DealerAvatarStyle.sikhEmpire;
    if (v.contains('sikkim')) return DealerAvatarStyle.sikkim;
    if (v.contains('travancore')) return DealerAvatarStyle.travancore;

    // International
    if (v.contains('africa')) return DealerAvatarStyle.africa;
    if (v.contains('s. america') || v.contains('south america') || v.contains('amazon')) {
      return DealerAvatarStyle.southAmerica;
    }
    if (v.contains('n. america') || v.contains('north america')) {
      return DealerAvatarStyle.northAmerica;
    }
    if (v.contains('arabia')) return DealerAvatarStyle.arabia;
    if (v.contains('australia')) return DealerAvatarStyle.australia;
    if (v.contains('china')) return DealerAvatarStyle.china;
    if (v.contains('europe')) return DealerAvatarStyle.europe;
    if (v == 'india') return DealerAvatarStyle.india;
    if (v.contains('russia')) return DealerAvatarStyle.russia;
    if (v.contains('asia') || v.contains('southeast')) return DealerAvatarStyle.asia;

    // Sensible default if a new venue is introduced.
    return DealerAvatarStyle.india;
  }

  // ---- Assets
  static const String _renoirIdleAsset = 'assets/images/renoir_tux.png';
  static const String _renoirDealAsset = _renoirIdleAsset;
  static const String _defaultProfile = 'assets/images/default_profile.png';
  static const double _kCheckSpeedFactor = 0.75;
  static const double _kCheckQuickChance = 0.35;
  static const int _kCheckDelayFloorMs = pace.kBotActionMinDelayMs;
  static const double _kConfidenceFastFactor = 0.7;
  static const double _kConfidenceSlowFactor = 1.35;

  // ---- Engine
  eng.GameEngine? _engine;
  final math.Random _rng = math.Random();
  // Renoir is the single dealer; in free builds this is kingdom-specific,
  // and in premium builds it is the Slash skin (fixed per session).
  late DealerAvatarStyle _dealerAvatarStyle;
  Timer? _engineTicker;

  // Track engine events for bust scheduling
  int _lastEventSeen = 0;
  int? _lastSettledHand;
  List<SeatActionSnapshot> _recentActions = const [];

  // Bust after delay (index → timer)
  final Map<int, Timer> _bustTimers = <int, Timer>{};
  static const Duration _kBloodStainLifetime = Duration(seconds: 60);
  final Set<int> _activeBloodStains = <int>{};
  final Map<int, Timer> _bloodStainTimers = <int, Timer>{};
  final Map<int, Timer> _actionHintTimers = <int, Timer>{};
  final Set<int> _pendingBust = <int>{};
  final Set<int> _bustSounded = <int>{};

  // ---- Table / seats
  late List<Seat> seats;
  int sbIndex = 0;
  int bbIndex = 1;

  // ---- Pot & pulse
  double pot = 0;
  double _prevPot = 0;
  late final AnimationController _potPulseCtl;
  late final Animation<double> _potPulse;

  // ---- Phase / turn
  _Phase phase = _Phase.predeal;
  int currentTurn = -1;

  // ---- Hand/match
  bool _matchOver = false;
  bool _handOverHandled = false;
  double _lastHandPot = 0;
  // Track if everyone is all-in & matched (for debug/UX)
  bool _allInMatched = false;
  bool _heroWasLeader = false;
  bool _heroInDanger = false;
  bool _matchEndSoundPlayed = false;
  bool _handWinSoundPlayed = false;
  bool _handStartQueued = true;
  bool _dealSfxEnabled = false;
  bool _welcomePlayed = false;

  // ---- Visual flags
  bool _uiShowShuffle = false;
  bool _showSeatCards = true;
  List<int> _visualDealt = const [];

  // ---- Board
  List<GCard> _boardTarget = const [];
  List<GCard> board = const [];
  int _boardRevealCount = 0;
  int _lastBoardTargetLen = 0;
  final List<Timer> _boardRevealTimers = <Timer>[];

  // ---- Hero controls
  double _raiseAmount = 400.0;

  // ---- Look
  late final WoodType _currentWood;

  // ---- Sync coalescing
  bool _syncScheduled = false;

  // ---- Venue watermark map
  static const Map<String, String> _monumentForVenue = {
    'baroda': 'assets/images/watermarks/baroda.svg',
    'new delhi': 'assets/images/watermarks/new_delhi.svg',
    'hyderabad': 'assets/images/watermarks/hyderabad.svg',
    'indore': 'assets/images/watermarks/indore.svg',
    'jaipur': 'assets/images/watermarks/jaipur.svg',
    'maratha empire': 'assets/images/watermarks/maratha_empire.svg',
    'mysore': 'assets/images/watermarks/mysore.svg',
    'sikh empire': 'assets/images/watermarks/sikh_empire.svg',
    'sikkim': 'assets/images/watermarks/sikkim.svg',
    'travancore': 'assets/images/watermarks/travancore.svg',
    'india': 'assets/images/watermarks/india.svg',
    'china': 'assets/images/watermarks/china.svg',
    'america': 'assets/images/watermarks/america.svg',
    'australia': 'assets/images/watermarks/australia.svg',
    'russia': 'assets/images/watermarks/russia.svg',
    'arabia': 'assets/images/watermarks/arabia.svg',
    'africa': 'assets/images/watermarks/africa.svg',
    'amazon': 'assets/images/watermarks/amazon.svg',
    'europe': 'assets/images/watermarks/europe.svg',
    'n. america': 'assets/images/watermarks/america.svg',
    's. america': 'assets/images/watermarks/amazon.svg',
    'asia': 'assets/images/watermarks/southeast.svg',
    'southeast': 'assets/images/watermarks/southeast.svg',
  };

  // ---- Kingdom pools for bots
  bool _isIndianVenueName(String v) {
    final x = v.toLowerCase();
    return x.contains('india') ||
        x.contains('delhi') ||
        x.contains('new delhi') ||
        x.contains('jaipur') ||
        x.contains('baroda') ||
        x.contains('hyderabad') ||
        x.contains('mysore') ||
        x.contains('sikkim') ||
        x.contains('indore') ||
        x.contains('travancore') ||
        x.contains('sikh empire') ||
        x.contains('maratha');
  }

  String get _monumentPath {
    final override = _monumentPathOverride;
    if (override != null && override.isNotEmpty) return override;
    final vn = (widget.venue?.name ?? '').toString().toLowerCase().trim();
    return _monumentForVenue[vn] ?? 'assets/images/watermarks/india.svg';
  }

  Future<void> _pickRandomSubKingdomWatermarkIfAny() async {
    final group = widget.campaignGroup;
    final idx = widget.campaignSubKingdomIndex;
    if (group == null || idx == null) return;

    final kingdomName = (widget.venue?.name ?? '').toString().trim();
    if (kingdomName.isEmpty) return;

    final candidates = await WatermarkResolver.listKingdomFolderWatermarks(
      kingdomName: kingdomName,
    );
    if (candidates.isEmpty) return;

    final path = candidates[_rng.nextInt(candidates.length)];
    if (!mounted) return;
    setState(() => _monumentPathOverride = path);
  }

  // ---- Hero helpers
  int get _heroIndex => seats.indexWhere((s) => s.isHero);

  bool get _isHeroTurn {
    final e = _engine;
    if (e == null) return false;
    return !_matchOver &&
        _heroIndex >= 0 &&
        e.players.isNotEmpty &&
        e.actingIndex == _heroIndex &&
        e.phase != eng.GamePhase.handOver &&
        e.phase != eng.GamePhase.showdown;
  }

  int get _heroToCall {
    final e = _engine;
    if (e == null) return 0;
    return e.toCallFor(_heroIndex);
  }

  /* ---------------- Renoir dealing flip tracking ---------------- */
  bool _renoirDealing = false;
  Timer? _renoirTimer;
  int _lastCommunityLen = 0;
  int _lastTotalHole = 0;
  Timer? _botActionTimer;
  int _lastBotSeat = -1;
  final Map<int, int> _botFixedThinkDelays = <int, int>{};
  bool _heroTurnChimed = false; // ensure hero-turn sound plays once per turn
  late final StreamController<ge.EngineEvent> _dealEventCtrl;

  void _triggerRenoirDealOnce() {
    _renoirTimer?.cancel();
    setState(() => _renoirDealing = true);
    _renoirTimer = Timer(_kRenoirDealOn + _kRenoirDealHold, () {
      if (!mounted) return;
      setState(() => _renoirDealing = false);
    });
  }

  void _handleRenoirShuffle() {
    _dealSfxEnabled = true;
    _handWinSoundPlayed = false;
    if (_handStartQueued) {
      _handStartQueued = false;
      _engine?.startNewHand();
      _kickIfStuck();
    }
  }

  void _onCanActChanged() {
    if (!mounted) return;
    if (!RenoirSignals.canAct.value) {
      _heroTurnChimed = false;
      _botActionTimer?.cancel();
      _botActionTimer = null;
      return;
    }
    // Action just opened: chime hero if it's their turn, otherwise kick bots.
    if (_isHeroTurn && !_heroTurnChimed) {
      _heroTurnChimed = true;
      unawaited(SoundFx.instance.playHeroTurn());
    } else {
      final e = _engine;
      if (e != null) {
        _scheduleBotActionIfNeeded(e);
      }
    }
  }

  /* ================================ Lifecycle ============================== */
  @override
  void initState() {
    super.initState();

    unawaited(() async {
      await SoundFx.instance.unlock();
      // If we're transitioning through the author "flash" overlay, delay the
      // welcome music until the actual game screen is visible.
      await AuthorFlashGate.waitUntilHidden();
      if (!mounted || _welcomePlayed) return;
      _welcomePlayed = true;
      unawaited(SoundFx.instance.playWelcome());
    }());
    _dealEventCtrl = StreamController<ge.EngineEvent>.broadcast();

    CardBackTheme.nextGame();
    _currentWood = WoodType.values[_rng.nextInt(WoodType.values.length)];
    _dealerAvatarStyle =
        _dealerAvatarForVenue((widget.venue?.name ?? '').toString());
    seats = _buildTableFromBotPool();
    _botFixedThinkDelays.clear();

    unawaited(_pickRandomSubKingdomWatermarkIfAny());

    // Start with hidden cards; mirror Renoir’s reveal signal
    _showSeatCards = false;
    RenoirSignals.holeCardsVisible.addListener(() {
      if (!mounted) return;
      final vis = RenoirSignals.holeCardsVisible.value;
      if (_showSeatCards != vis) setState(() => _showSeatCards = vis);
      if (vis) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncFromEngine();
        });
      }
    });
    RenoirSignals.canAct.addListener(_onCanActChanged);

    _potPulseCtl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _potPulse =
        CurvedAnimation(parent: _potPulseCtl, curve: Curves.easeOutCubic)
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) _potPulseCtl.reset();
          });

    _initEngineAndStart();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await precacheImage(AssetImage(CardBackTheme.current), context);
        await DeckCache.ensureDeckReady();
        await precacheImage(const AssetImage(_renoirIdleAsset), context);
        await precacheImage(const AssetImage(_renoirDealAsset), context);
      } catch (_) {}
      if (!mounted) return;

      _uiShowShuffle = true;
      setState(() {});

      await Future<void>.delayed(Duration(milliseconds: pace.kShuffleMs));
      if (!mounted) return;

      _uiShowShuffle = false;
      setState(() {});
      // Do not force show here; Renoir will broadcast reveal via RenoirSignals
    });
  }

  @override
  void dispose() {
    _engineTicker?.cancel();
    _renoirTimer?.cancel();
    RenoirSignals.canAct.removeListener(_onCanActChanged);
    for (final t in _bustTimers.values) {
      t.cancel();
    }
    _bustTimers.clear();
    _pendingBust.clear();
    for (final t in _actionHintTimers.values) {
      t.cancel();
    }
    _actionHintTimers.clear();
    for (final t in _bloodStainTimers.values) {
      t.cancel();
    }
    _bloodStainTimers.clear();
    _activeBloodStains.clear();
    _bustSounded.clear();
    _cancelBoardRevealTimers();
    _botActionTimer?.cancel();
    _botActionTimer = null;
    _potPulseCtl.dispose();
    unawaited(SoundFx.instance.dispose());
    unawaited(_dealEventCtrl.close());
    go.dismissWelcomeRenoir();
    super.dispose();
  }

  /* ============================= Table / bots ============================== */
  int _auraForBot(String name) => _botAuraByName[name] ?? 60;

  List<Seat> _seatsFromSpecs(List<_BotSpec> specs, {required int chips}) {
    final out = <Seat>[];
    for (final b in specs) {
      final slug = Seat.slugForName(b.name);
      final s = Seat(
        name: b.name,
        chips: chips,
        startChips: chips,
        bet: 0,
        aura: _auraForBot(b.name),
        about: b.about,
        kingdom: b.kingdom,
        enduranceMinutes: 0,
        avatarKey: slug,
        avatarAssetFolder: b.hasAvatar ? 'assets/images/avatars/bots/' : null,
      );
      out.add(s);
    }
    return out;
  }

  void _assignEnduranceProfiles(List<Seat> candidates) {
    if (candidates.isEmpty) return;
    final seatsCopy = List<Seat>.from(candidates)..shuffle(_rng);
    final enduranceBuckets = <int>[
      30,
      30,
      20,
      20,
      10,
      10,
    ]..shuffle(_rng);

    for (int i = 0; i < seatsCopy.length; i++) {
      if (i < enduranceBuckets.length) {
        seatsCopy[i].enduranceMinutes = enduranceBuckets[i];
      } else {
        // Default endurance for remaining bots
        seatsCopy[i].enduranceMinutes = 15;
      }
    }
  }

  List<Seat> _buildTableFromBotPool() {
    final String vname = (widget.venue?.name ?? '').toString();
    final bool indian = _isIndianVenueName(vname);
    final specs = indian ? _indianBotSpecs : _intlBotSpecs;

    // Build full pool with fixed about lines, then shuffle for variety.
    final pool = _seatsFromSpecs(specs, chips: _kInitialChips)..shuffle(_rng);
    final int botsNeeded = math.max(0, _kMaxSeats - 1);
    final bool isTitleGame =
        (widget.campaignGroup != null) && widget.campaignMainEvent;

    final picked = <Seat>[];
    if (botsNeeded > 0) {
      final int eliteNeeded = isTitleGame ? math.min(3, botsNeeded) : 0;

      // In title games, guarantee at least 3 "super-bots" (aura 99) at the table.
      if (eliteNeeded > 0) {
        final elites =
            pool.where((s) => s.aura >= 99 && !s.busted).toList(growable: false)
              ..shuffle(_rng);
        picked.addAll(elites.take(eliteNeeded));

        // Defensive: if the pool ever has fewer elites than needed, top up by aura.
        if (picked.length < eliteNeeded) {
          final byAura = <Seat>[...pool]
            ..sort((a, b) => b.aura.compareTo(a.aura));
          for (final s in byAura) {
            if (picked.length >= eliteNeeded) break;
            if (!picked.contains(s)) picked.add(s);
          }
        }
      }

      final remaining = pool.where((s) => !picked.contains(s)).toList()
        ..shuffle(_rng);
      picked.addAll(remaining.take(botsNeeded - picked.length));
      picked.shuffle(_rng); // randomize seating order
    }
    _assignEnduranceProfiles(picked);
    if (isTitleGame) {
      // Give super-bots a long-run temperament in title games.
      for (final s in picked) {
        if (s.aura >= 99) {
          s.enduranceMinutes = math.max(s.enduranceMinutes, 30);
        }
      }
    }

    final heroKingdomRaw = vname.trim();
    final heroKingdom = heroKingdomRaw.isNotEmpty
        ? heroKingdomRaw
        : (indian ? 'India' : 'International');

    final hero = Seat(
      name: 'You',
      chips: _kInitialChips,
      startChips: _kInitialChips,
      bet: 0,
      aura: _kHeroAura,
      isHero: true,
      hole: const [],
      about: indian ? 'Underdog story brewing' : 'Wildcard legend pending',
      kingdom: heroKingdom,
      enduranceMinutes: 0,
      avatarKey: 'avatar_male',
      avatarAssetFolder: null,
    );

    return <Seat>[picked[0], hero, ...picked.skip(1)];
  }

  /* ============================= Engine wiring ============================ */
  void _initEngineAndStart() {
    final e = eng.GameEngine(
      config: eng.GameConfig(
        smallBlind: 100,
        bigBlind: 200,
        maxPlayers: _kMaxSeats,
        blindSchedule: eng.BlindSchedule(
          orbitsPerLevel: 3,
          levels: <eng.BlindLevel>[
            eng.BlindLevel(smallBlind: 100, bigBlind: 200),
            eng.BlindLevel(smallBlind: 200, bigBlind: 400),
            eng.BlindLevel(smallBlind: 300, bigBlind: 600),
            eng.BlindLevel(smallBlind: 400, bigBlind: 800),
            eng.BlindLevel(smallBlind: 500, bigBlind: 1000),
          ],
        ),
        payoutForRank: (rank) => rank == 1 ? 100000 : 0,
      ),
    );
    _engine = e;

    for (int i = 0; i < seats.length && i < _kMaxSeats; i++) {
      final s = seats[i];
      s.chips = _kInitialChips;
      e.addPlayer(eng.Player(
        id: 'P$i',
        name: s.name,
        chips: s.chips,
        enduranceMinutes: s.enduranceMinutes,
        aura: s.aura,
        isBot: !s.isHero,
      ));
    }
    // Ensure engine knows who the hero is (needed for canSkipToWinner gate)
    try {
      (e as dynamic).heroIndex =
          _heroIndex; // seats array already built; hero seat is known
    } catch (_) {}

    _ensureVisualDealtSize();

    e.addListener((ev) {
      // Listen for tournament end (engine-level terminal signal)
      if (ev is ge.TournamentEnded) {
        _onTournamentEnded(ev);
        return; // no further sync needed, UI will close out
      }

      _captureNewEngineEvents();

      if (_syncScheduled) return;
      _syncScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncFromEngine();
        _syncScheduled = false;
      });
    });

    _syncFromEngine();

    // Lightweight engine ticker (drives hand-over flow and schedules bots).
    _engineTicker?.cancel();
    _engineTicker =
        Timer.periodic(Duration(milliseconds: pace.kBotThinkTimeMs), (_) {
      if (!mounted || _matchOver) return;
      final ee = _engine;
      if (ee == null) return;

      // Surface engine's extreme state: everyone all-in & matched
      final bool allInNow = ee.everyoneAllInMatched();
      if (allInNow != _allInMatched) {
        _allInMatched = allInNow;
        if (_allInMatched) {
          debugPrint(
              '[GameScreen] Everyone all-in & matched — fast runout enabled');
        } else {
          debugPrint('[GameScreen] Exited all-in matched state');
        }
      }

      final currentPhase = ee.phase;

      if (currentPhase == eng.GamePhase.handOver) {
        _onHandOverAndContinue();
        return;
      }

      // If action is live and the hero isn't acting, schedule the next bot.
      _scheduleBotActionIfNeeded(ee);
    });

    // When acting becomes allowed (~1.5s after reveal), set UTG (next to BB) as first actor
    // and give bots a nudge so action starts if hero isn't first.
    RenoirSignals.canAct.addListener(() {
      if (!mounted) return;
      final bool canActNow = RenoirSignals.canAct.value;
      if (!canActNow) {
        _botActionTimer?.cancel();
        _botActionTimer = null;
        _lastBotSeat = -1;
        return;
      }
      final ee = _engine;
      if (ee == null || ee.players.isEmpty) return;
      try {
        final int n = ee.players.length;

        // Prefer engine's own bb index if exposed, else fall back to dealer+2
        int bb;
        try {
          bb = (ee as dynamic).bbIndex as int;
        } catch (_) {
          bb = (ee.dealerIndex + 2) % n;
        }
        if (bb < 0 || bb >= n) bb = (ee.dealerIndex + 2) % n;

        // Compute UTG (next to BB), skipping ineligible seats
        int utg = (bb + 1) % n;
        bool isActiveSeat(eng.Player p) =>
            !p.isOut && !p.sittingOut && !p.folded;
        int hops = 0;
        while (hops < n && !isActiveSeat(ee.players[utg])) {
          utg = (utg + 1) % n;
          hops++;
        }

        // Tell engine who acts first if API is present
        try {
          (ee as dynamic).setActingIndex(utg);
        } catch (_) {}

        _scheduleBotActionIfNeeded(ee);
      } catch (_) {}
    });
  }

  Future<void> Function()? _titleCertificateDownloadAction({
    required bool heroWon,
  }) {
    if (!heroWon) return null;
    final group = widget.campaignGroup;
    if (group == null) return null;
    if (!widget.campaignMainEvent) return null;

    final String kingdomName = (widget.venue?.name ?? '').toString();
    if (kingdomName.trim().isEmpty) return null;

    final progress = context.read<CampaignProgressService>();
    if (!progress.hasTitle(group: group, kingdomName: kingdomName)) return null;

    final titleName = kingdomTitleFor(group: group, kingdomName: kingdomName);
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final playerId = (user?.uid ?? 'guest').toString().trim();
    final playerName = ((user?.displayName ?? user?.email) ?? 'Guest Player')
        .toString()
        .trim();

    return () async {
      await TitleCertificateService.downloadTitleCertificate(
        playerName: playerName.isEmpty ? 'Guest Player' : playerName,
        playerId: playerId.isEmpty ? 'guest' : playerId,
        kingdomName: kingdomName,
        titleName: titleName,
        issuedAt: DateTime.now(),
      );
    };
  }

  void _onTournamentEnded(ge.TournamentEnded ev) async {
    if (!mounted) return;
    _matchOver = true;
    _engineTicker?.cancel();
    final bool heroWon = ev.championIndex == _heroIndex;
    _playMatchEndCue(heroWon: heroWon);
    _markCampaignWinIfApplicable(heroWon: heroWon);
    final Seat? winnerSeat = (ev.championIndex >= 0 &&
            ev.championIndex < seats.length)
        ? seats[ev.championIndex]
        : null;
    final String venueName = (widget.venue?.name ?? '').toString();
    final String venueFlag = (widget.venue?.flagAsset ?? '').toString();
    final onDownloadCertificate =
        _titleCertificateDownloadAction(heroWon: heroWon);
    // Optional UI: show final congrats using your existing overlay
    await go.showRenoirCongratsForMatch(
      context,
      winnerName: (_engine != null &&
              ev.championIndex >= 0 &&
              ev.championIndex < _engine!.players.length)
          ? _engine!.players[ev.championIndex].name
          : _winnerNameOrTopStack(),
      winnerSeat: winnerSeat,
      venueName: venueName,
      venueFlagAsset: venueFlag,
      prize: ev.prize,
      onExitToVenue: (widget.campaignGroup != null)
          ? () => Navigator.of(context).maybePop()
          : null,
      onDownloadCertificate: onDownloadCertificate,
    );
    if (!mounted) return;
    setState(() {});
  }

  void _captureNewEngineEvents() {
    final e = _engine;
    if (e == null) return;

    final events = e.eventLog;
    bool needsSeatRefresh = false;
    for (int i = _lastEventSeen; i < events.length; i++) {
      final ev = events[i];
      if (ev is ge.CardDealt) {
        _pushDealEvent(ev);
        if (_dealSfxEnabled) {
          if (ev.isBoard) {
            // Use fold sfx for community reveals per UX request.
            unawaited(SoundFx.instance.playFold());
          } else {
            unawaited(SoundFx.instance.playDeal());
          }
        }
        continue;
      }
      if (ev is ge.ActionTaken) {
        _handleActionSound(ev);
        needsSeatRefresh = _applySeatAction(ev) || needsSeatRefresh;
        continue;
      }
      if (ev is ge.PlayerBusted) {
        _handlePlayerBusted(ev);
        continue;
      }
      if (ev is ge.HandStarted) {
        _handWinSoundPlayed = false;
        needsSeatRefresh = _clearSeatActions() || needsSeatRefresh;
        _handOverHandled = false; // new hand started, allow next winners flow
        continue;
      }
      if (ev is ge.StreetDealt) {
        needsSeatRefresh = _clearSeatActions() || needsSeatRefresh;
        continue;
      }
      if (ev is ge.HandSettled) {
        _clearSeatActions();
        _lastSettledHand = ev.handNumber;
        _scheduleBustsFromSettlement(ev);
        // Keep cards on the table until the winners overlay is shown.
        _cancelBoardRevealTimers();
        _botActionTimer?.cancel();
        _botActionTimer = null;
        _lastBotSeat = -1;
        // Direct call to winner flow so Skip → settlement shows overlay immediately
        if (!_handOverHandled) {
          _onHandOverAndContinue();
        }
        continue;
      }
    }
    _lastEventSeen = events.length;
    if (needsSeatRefresh && mounted) {
      setState(() {});
    }
  }

  void _scheduleBustsFromSettlement(ge.HandSettled hs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMs = math.max(0, (hs.endedAtMs + 5000) - now);

    _pendingBust.clear();
    _bustSounded.clear();
    for (final idx in hs.bustedThisHand) {
      if (idx < 0 || idx >= (_engine?.players.length ?? 0)) continue;
      final p = _engine!.players[idx];
      if (p.chips > 0) continue;

      _pendingBust.add(idx);
      _bustTimers[idx]?.cancel();
      _bustTimers[idx] = Timer(Duration(milliseconds: remainingMs), () {
        _bustTimers.remove(idx);
        if (!mounted) return;
        if (idx >= 0 && idx < seats.length) {
          _playBustSound(idx);
          setState(() {
            seats[idx].busted = true;
            _activateBloodStain(idx);
          });
        }
      });
    }
  }

  void _playBustSound(int idx) {
    if (_bustSounded.contains(idx)) return;
    _bustSounded.add(idx);
    if (idx == _heroIndex) {
      unawaited(SoundFx.instance.playHeroBust());
    } else {
      unawaited(SoundFx.instance.playPlayerBusted());
    }
  }

  void _activateBloodStain(int idx) {
    _activeBloodStains.add(idx);
    _bloodStainTimers[idx]?.cancel();
    _bloodStainTimers[idx] = Timer(_kBloodStainLifetime, () {
      _bloodStainTimers.remove(idx);
      if (!mounted) return;
      if (_activeBloodStains.remove(idx)) {
        setState(() {});
      }
    });
  }

  void _clearBloodStain(int idx) {
    _bloodStainTimers.remove(idx)?.cancel();
    _activeBloodStains.remove(idx);
  }

  bool _clearSeatActions() {
    bool changed = false;
    if (_recentActions.isNotEmpty) {
      _recentActions = const [];
      changed = true;
    }
    for (int i = 0; i < seats.length; i++) {
      if (seats[i].lastAction.isNotEmpty) {
        seats[i].lastAction = '';
        changed = true;
      }
      _actionHintTimers.remove(i)?.cancel();
    }
    return changed;
  }

  bool _applySeatAction(ge.ActionTaken ev) {
    final idx = ev.playerIndex;
    if (idx < 0 || idx >= seats.length) return false;
    final label = _describeAction(ev.type, ev.amountTo);
    bool changed = seats[idx].lastAction != label;
    seats[idx].lastAction = label;
    if (label.isNotEmpty) {
      _recordSeatAction(idx, label);
    }
    if (ev.type == eng.ActionType.fold && !seats[idx].isHero) {
      if (seats[idx].hole.isNotEmpty) {
        seats[idx].hole = const [];
        changed = true;
      }
    }
    _actionHintTimers[idx]?.cancel();
    if (label.isNotEmpty) {
      _actionHintTimers[idx] = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (idx >= seats.length) return;
        if (seats[idx].lastAction.isEmpty) return;
        seats[idx].lastAction = '';
        setState(() {});
      });
    } else {
      _actionHintTimers.remove(idx);
    }
    return changed;
  }

  void _recordSeatAction(int idx, String label) {
    if (idx < 0 || idx >= seats.length) return;
    final snap = SeatActionSnapshot(
      seatIndex: idx,
      label: label,
      chips: seats[idx].chips,
    );
    final List<SeatActionSnapshot> next =
        _recentActions.where((a) => a.seatIndex != idx).toList();
    next.insert(0, snap);
    while (next.length > 3) {
      next.removeLast();
    }
    setState(() {
      _recentActions = next;
    });
  }

  void _handleActionSound(ge.ActionTaken ev) {
    switch (ev.type) {
      case eng.ActionType.fold:
        unawaited(SoundFx.instance.playFold());
        break;
      case eng.ActionType.allIn:
        unawaited(SoundFx.instance.playPlayerAllIn());
        break;
      case eng.ActionType.bet:
      case eng.ActionType.raise:
        unawaited(SoundFx.instance.playRaiseAtm());
        break;
      case eng.ActionType.call:
        unawaited(SoundFx.instance.playCallCoin());
        break;
      case eng.ActionType.check:
        unawaited(SoundFx.instance.playCheck());
        break;
    }
  }

  void _pushDealEvent(ge.EngineEvent ev) {
    if (_dealEventCtrl.isClosed) return;
    try {
      _dealEventCtrl.add(ev);
    } catch (_) {}
  }

  void _handlePlayerBusted(ge.PlayerBusted ev) {
    _playBustSound(ev.playerIndex);
    if (ev.playerIndex == _heroIndex) {
      _heroWasLeader = false;
      _heroInDanger = false;
      _playMatchEndCue(heroWon: false);
    }
  }

  void _playMatchEndCue({required bool heroWon}) {
    if (_matchEndSoundPlayed) return;
    _matchEndSoundPlayed = true;
    unawaited(heroWon
        ? SoundFx.instance.playGameWin()
        : SoundFx.instance.playGameLost());
  }

  void _checkHeroStateCues() {
    final idx = _heroIndex;
    if (idx < 0 || idx >= seats.length) {
      _heroWasLeader = false;
      _heroInDanger = false;
      return;
    }
    final hero = seats[idx];
    final bool alive = !hero.busted && hero.chips > 0;
    if (!alive) {
      _heroWasLeader = false;
      _heroInDanger = false;
      return;
    }

    final int heroChips = hero.chips;
    final bool leading = seats.asMap().entries.every((entry) {
      if (entry.key == idx) return true;
      final seat = entry.value;
      if (seat.busted || seat.chips <= 0) return true;
      return heroChips > seat.chips;
    });

    if (leading) {
      if (!_heroWasLeader) {
        _heroWasLeader = true;
        unawaited(SoundFx.instance.playHeroLeader());
      }
    } else {
      _heroWasLeader = false;
    }

    final int baseline =
        hero.startChips <= 0 ? _kInitialChips : hero.startChips;
    final bool inDanger =
        hero.chips > 0 && hero.chips < math.max(200, (baseline / 3).round());
    if (inDanger) {
      if (!_heroInDanger) {
        _heroInDanger = true;
        unawaited(SoundFx.instance.playHeroDanger());
      }
    } else {
      _heroInDanger = false;
    }
  }

  String _describeAction(eng.ActionType type, int amountTo) {
    switch (type) {
      case eng.ActionType.check:
        return 'Check';
      case eng.ActionType.call:
        return amountTo > 0 ? 'Call ${_formatChips(amountTo)}' : 'Call';
      case eng.ActionType.bet:
        return 'Bet ${_formatChips(amountTo)}';
      case eng.ActionType.raise:
        return 'Raise to ${_formatChips(amountTo)}';
      case eng.ActionType.fold:
        return 'Fold';
      case eng.ActionType.allIn:
        return 'All-in ${_formatChips(amountTo)}';
      default:
        return '';
    }
  }

  String _formatChips(int amount) => amount.toString();

  int _randInRangeInt(int lo, int hi) {
    if (hi <= lo) return lo;
    return lo + _rng.nextInt(hi - lo + 1);
  }

  int _raiseSpreadForPhase(eng.GamePhase phase, int bigBlind) {
    switch (phase) {
      case eng.GamePhase.preflop:
        return bigBlind;
      case eng.GamePhase.flop:
        return bigBlind * 2;
      case eng.GamePhase.turn:
      case eng.GamePhase.river:
        return bigBlind * 3;
      case eng.GamePhase.showdown:
      case eng.GamePhase.handOver:
      case eng.GamePhase.predeal:
        return bigBlind;
    }
  }

  /* ===== Sync + AUTO board reveal ===== */
  void _ensureVisualDealtSize() {
    final e = _engine;
    final need =
        (e == null || e.players.isEmpty) ? seats.length : e.players.length;
    if (_visualDealt.length != need) {
      final copy = List<int>.filled(need, 2);
      if (_visualDealt.isNotEmpty) {
        for (int i = 0; i < math.min(_visualDealt.length, need); i++) {
          copy[i] = (_visualDealt[i].clamp(0, 2) as int);
        }
      }
      _visualDealt = copy;
    }
  }

  void _cancelBoardRevealTimers() {
    if (_boardRevealTimers.isEmpty) return;
    for (final timer in _boardRevealTimers) {
      timer.cancel();
    }
    _boardRevealTimers.clear();
  }

  void _stageBoardReveal(List<GCard> target, int nextLen) {
    // Renoir's flights already animate the dealing; keep engine/community state
    // synced immediately so card faces are available when the flight completes.
    final int clamped = nextLen.clamp(0, target.length);
    _cancelBoardRevealTimers();
    _boardRevealCount = clamped;
    board = target.take(clamped).toList(growable: false);
  }

  void _forceRiverIfAvailable() {
    final e = _engine;
    if (e == null) return;
    if (e.community.length == 5 && board.length != 5) {
      final tgt = e.community.map(_mapEngCard).toList(growable: false);
      _cancelBoardRevealTimers();
      setState(() {
        _boardTarget = tgt;
        _boardRevealCount = 5;
        board = tgt;
        _lastBoardTargetLen = 5;
      });
    }
  }

  void _scheduleBotActionIfNeeded(eng.GameEngine e) {
    if (!mounted || _matchOver) return;

    if (!RenoirSignals.canAct.value) {
      _botActionTimer?.cancel();
      _botActionTimer = null;
      _lastBotSeat = -1;
      return;
    }

    final int actor = e.actingIndex;
    if (actor < 0 || actor >= e.players.length) {
      _botActionTimer?.cancel();
      _botActionTimer = null;
      _lastBotSeat = -1;
      return;
    }

    if (actor == _heroIndex) {
      _botActionTimer?.cancel();
      _botActionTimer = null;
      _lastBotSeat = -1;
      return;
    }

    if (_botActionTimer != null && _lastBotSeat == actor) return;

    _botActionTimer?.cancel();
    _lastBotSeat = actor;

    Seat? actingSeat;
    if (actor >= 0 && actor < seats.length) {
      actingSeat = seats[actor];
    }
    final int aura = actingSeat?.aura ?? 60;
    final suggestion = _botSuggestionFor(e, actor);
    int delayMs = _fixedBotDelayFor(actor, aura);
    final double strength = (suggestion?.strength ?? 0.5).clamp(0.0, 1.0);
    delayMs = (delayMs * _strengthDelayFactor(strength)).round();
    final double confidence = (suggestion?.confidence ?? 0.5).clamp(0.0, 1.0);
    delayMs = (delayMs * _confidenceDelayFactor(confidence)).round();
    final bool highAura = aura >= pace.kBotHighAuraThreshold;
    final bool quickCheck = suggestion != null &&
        suggestion.action == eng.ActionType.check &&
        e.toCallFor(actor) == 0 &&
        _rng.nextDouble() < _kCheckQuickChance;
    if (quickCheck) {
      delayMs = math.max(
        _kCheckDelayFloorMs,
        (delayMs * _kCheckSpeedFactor).round(),
      );
    }
    if (highAura) {
      delayMs = math.max(delayMs, pace.kBotActionHighAuraMinDelayMs);
      if (strength >= 0.6) {
        // Stronger hands from composed players tank a bit longer.
        delayMs = math.max(delayMs, pace.kBotActionHighAuraMinDelayMs + 300);
        delayMs = (delayMs * 1.25).round();
      }
      delayMs = delayMs
          .clamp(
            pace.kBotActionHighAuraMinDelayMs,
            pace.kBotActionHighAuraMaxDelayMs,
          )
          .toInt();
    }
    delayMs = math.max(delayMs, pace.kBotActionMinDelayMs);
    // Add slight randomness to avoid robotic timing.
    const double jitter = 0.12; // +/-12%
    final double noise = (_rng.nextDouble() * 2 - 1) * jitter;
    delayMs = (delayMs * (1 + noise)).round();
    delayMs = delayMs
        .clamp(
          pace.kBotActionMinDelayMs,
          pace.kBotActionAbsoluteMaxDelayMs,
        )
        .toInt();
    _botActionTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      final eng.GameEngine? ee = _engine;
      if (ee == null) return;
      if (!RenoirSignals.canAct.value) return;
      if (ee.actingIndex != actor) return;
      if (actor == _heroIndex) return;
      ee.tickBots(maxSteps: 1);
      _botActionTimer?.cancel();
      _botActionTimer = null;
    });
  }

  int _fixedBotDelayFor(int seatIndex, int aura) {
    final cached = _botFixedThinkDelays[seatIndex];
    if (cached != null) return cached;
    const double auraFloor = 45;
    const double auraCeil = 95;
    final double clamped = aura.toDouble().clamp(auraFloor, auraCeil);
    final double t = (clamped - auraFloor) / (auraCeil - auraFloor);
    final int minMs = pace.kBotActionMinDelayMs;
    final int maxMs = pace.kBotActionHighAuraMaxDelayMs;
    final int ms = minMs + ((maxMs - minMs) * t).round();
    _botFixedThinkDelays[seatIndex] = ms;
    return ms;
  }

  ({eng.ActionType action, int toAmount, double confidence, double strength})?
      _botSuggestionFor(
    eng.GameEngine engine,
    int seat,
  ) {
    try {
      return eng.BotAdvisor.suggest(engine, seat);
    } catch (_) {
      return null;
    }
  }

  double _confidenceDelayFactor(double confidence) {
    final double c = confidence.clamp(0.0, 1.0);
    final double span = _kConfidenceSlowFactor - _kConfidenceFastFactor;
    return _kConfidenceSlowFactor - span * c;
  }

  double _strengthDelayFactor(double strength) {
    final double s = strength.clamp(0.0, 1.0);
    // Weak hands tank a bit longer; strong hands act a bit faster.
    return 1.15 - 0.45 * s; // 1.15 → 0.70 across the range
  }

  void _syncFromEngine() {
    final e = _engine;
    if (e == null) {
      if (mounted) setState(() {});
      return;
    }

    _ensureVisualDealtSize();

    // Mirror Renoir’s reveal: only show holes when signaled visible
    _showSeatCards = RenoirSignals.holeCardsVisible.value;

    final newPot = e.pot.toDouble();
    if (newPot > _prevPot) {
      _potPulseCtl.forward(from: 0);
      unawaited(SoundFx.instance.playPotIncrease());
    }
    _prevPot = newPot;
    pot = newPot;

    final prevPhase = phase;
    phase = _mapPhase(e.phase);
    if (phase == _Phase.showdown || e.phase == eng.GamePhase.handOver) {
      _lastHandPot = math.max(_lastHandPot, pot);
    }
    if (prevPhase != _Phase.showdown && e.phase == eng.GamePhase.handOver) {
      _lastHandPot = math.max(_lastHandPot, pot);
    }

    final curCommunityLen = e.community.length;
    final curTotalHole =
        e.players.fold<int>(0, (sum, p) => sum + (p.hole.length));

    if (curCommunityLen > _lastCommunityLen || curTotalHole > _lastTotalHole) {
      _triggerRenoirDealOnce();
    }
    _lastCommunityLen = curCommunityLen;
    _lastTotalHole = curTotalHole;

    final nextTarget = e.community.map(_mapEngCard).toList(growable: false);
    final int nextLen = math.min(nextTarget.length, 5);

    _boardTarget = nextTarget;

    if (nextLen != _lastBoardTargetLen) {
      _stageBoardReveal(_boardTarget, nextLen);
      _lastBoardTargetLen = nextLen;
    } else if (nextLen == 5 && board.length < 5) {
      _boardTarget = nextTarget;
      _boardRevealCount = 5;
      board = _boardTarget;
      _lastBoardTargetLen = 5;
    }

    if (e.players.isNotEmpty) {
      if (e.smallBlindIndex >= 0) sbIndex = e.smallBlindIndex;
      if (e.bigBlindIndex >= 0) bbIndex = e.bigBlindIndex;
    }

    currentTurn = e.actingIndex;
    // Play hero turn notification exactly once per turn when action is live.
    if (!RenoirSignals.canAct.value) {
      _heroTurnChimed = false;
    } else if (_isHeroTurn && !_heroTurnChimed) {
      _heroTurnChimed = true;
      unawaited(SoundFx.instance.playHeroTurn());
    } else if (!_isHeroTurn) {
      _heroTurnChimed = false;
    }

    final showAll = (phase == _Phase.showdown);
    for (int i = 0; i < seats.length && i < e.players.length; i++) {
      final ep = e.players[i];
      final s = seats[i];

      s.chips = ep.chips;
      s.bet = ep.betThisStreet;
      s.contributedThisHand = ep.contributedThisHand;
      s.folded = ep.folded;

      if (s.busted && ep.chips > 0 && !ep.isOut) {
        s.busted = false;
        _pendingBust.remove(i);
        _bustTimers.remove(i)?.cancel();
        _clearBloodStain(i);
      }

      if (ep.isOut &&
          !s.busted &&
          !_pendingBust.contains(i) &&
          !_bustTimers.containsKey(i)) {
        _playBustSound(i);
        s.busted = true;
        _activateBloodStain(i);
      }

      final full = ep.hole.map(_mapEngCard).toList();
      final bool keepVisible = !ep.folded || s.isHero;
      if (!keepVisible) {
        s.hole = const [];
      } else if (showAll) {
        s.hole = full;
      } else if (_showSeatCards) {
        s.hole = full.take(math.min(2, full.length)).toList();
      } else {
        s.hole = const [];
      }
    }

    _checkHeroStateCues();

    _forceRiverIfAvailable();

    _scheduleBotActionIfNeeded(e);

    if (mounted) setState(() {});
    _kickIfStuck();
  }

  void _kickIfStuck() {
    Future.delayed(Duration(milliseconds: pace.kPostActionPauseMs), () {
      if (!mounted) return;
      bool needSet = false;

      final bool shouldShow = RenoirSignals.holeCardsVisible.value;
      if (_showSeatCards != shouldShow) {
        _showSeatCards = shouldShow;
        needSet = true;
      }
      // No visualDealt forcing here; reveal timing is controlled by Renoir

      final e = _engine;
      if (e != null && e.community.isNotEmpty && board.isEmpty) {
        _boardTarget = e.community.map(_mapEngCard).toList(growable: false);
        final int nextLen = math.min(_boardTarget.length, 5);
        _stageBoardReveal(_boardTarget, nextLen);
        _lastBoardTargetLen = nextLen;
        needSet = true;
      }

      if (needSet) setState(() {});
    });

    // Web watchdog: if canAct is true but no bot acts for a bit, nudge the engine.
    if (kIsWeb) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        final e = _engine;
        if (e == null) return;
        if (!RenoirSignals.canAct.value) return;
        // If hero not acting and engine is idle, force a check/call/skip.
        final int actor = e.actingIndex;
        if (actor == _heroIndex) return; // never auto-act for the hero
        if (actor >= 0 && actor < e.players.length) {
          // Try a safe action; fall back to skip-to-winner if stuck.
          try {
            final legal = e.legalActionsFor(actor);
            if (legal.contains(eng.ActionType.check)) {
              e.act(eng.ActionType.check);
              return;
            }
            if (legal.contains(eng.ActionType.call)) {
              e.act(eng.ActionType.call);
              return;
            }
            if (legal.contains(eng.ActionType.fold)) {
              e.act(eng.ActionType.fold);
              return;
            }
          } catch (_) {}
        }
        try {
          (e as dynamic).requestSkipToWinner?.call();
        } catch (_) {}
      });
    }
  }

  /* ========================== Hand-over / winners ========================= */
  void _onHandOverAndContinue() async {
    final e = _engine;
    if (e == null) return;
    if (_handOverHandled) return;
    _handOverHandled = true;

    // Ensure community cards are visible on the table while the winners overlay
    // is shown, especially for Skip fast-forward paths where Renoir may not
    // receive per-card dealing events.
    final forcedBoard =
        e.community.map(_mapEngCard).toList(growable: false);
    if (forcedBoard.length > board.length) {
      _cancelBoardRevealTimers();
      setState(() {
        _boardTarget = forcedBoard;
        _boardRevealCount = forcedBoard.length;
        _lastBoardTargetLen = forcedBoard.length;
        board = forcedBoard;
      });
    }

    final players = e.players;
    var payouts = e.lastPayouts;

    if (payouts.isEmpty) {
      final aliveIdx = <int>[];
      for (var i = 0; i < players.length; i++) {
        final p = players[i];
        if (!p.folded && !p.sittingOut) aliveIdx.add(i);
      }
      final total =
          (_lastHandPot > 0 ? _lastHandPot : e.pot.toDouble()).round();
      if (aliveIdx.isEmpty) {
        payouts = [];
      } else if (aliveIdx.length == 1) {
        payouts = [
          eng.Payout(playerIndex: aliveIdx.first, amount: total, best: null)
        ];
      } else {
        final share = total ~/ aliveIdx.length;
        int rem = total % aliveIdx.length;
        payouts = aliveIdx
            .map((i) => eng.Payout(
                playerIndex: i, amount: share, best: players[i].best))
            .toList();
        int give = (e.dealerIndex + 1) % players.length;
        while (rem > 0) {
          final j = payouts.indexWhere((p) => p.playerIndex == give);
          if (j != -1) {
            payouts[j] = eng.Payout(
              playerIndex: payouts[j].playerIndex,
              amount: payouts[j].amount + 1,
              best: payouts[j].best,
            );
            rem--;
          }
          give = (give + 1) % players.length;
        }
      }
    }

    if (payouts.isEmpty) {
      final alive = players
          .where((p) => !p.folded && !p.sittingOut)
          .map((p) => p.name)
          .toList();
      final title = alive.length == 1 ? '${alive.first} wins' : 'Split Pot';
      final subtitle = (_lastHandPot > 0)
          ? 'Pot ${_lastHandPot.toStringAsFixed(0)}'
          : 'Hand complete';
      await go
          .showWinnerSplash(context, title: title, subtitle: subtitle)
          .whenComplete(_afterWinnersClosed);
      return;
    }

    final lines = <go.WinnerLine>[];
    for (final p in payouts) {
      final pl = players[p.playerIndex];
      final handName = _fallbackHandName(pl.best?.category);
      final bestFiveUi = (pl.best?.bestFive ?? const <eng.Card>[])
          .map<go.UiCard>((card) => _toUiCard(_mapEngCard(card)))
          .toList(growable: false);
      final holeUi = pl.hole
          .map<go.UiCard>((card) => _toUiCard(_mapEngCard(card)))
          .toList(growable: false);
      final Seat? seatInfo =
          (p.playerIndex >= 0 && p.playerIndex < seats.length)
              ? seats[p.playerIndex]
              : null;
      final int contributed =
          (p.playerIndex >= 0 && p.playerIndex < players.length)
              ? players[p.playerIndex].contributedThisHand
              : 0;
      lines.add(go.WinnerLine(
        playerName: pl.name,
        amount: p.amount,
        delta: p.amount - contributed,
        bet: contributed,
        handName: handName,
        bestFive: bestFiveUi,
        holeCards: holeUi,
        kingdom: seatInfo?.kingdom ?? '-',
        about: seatInfo?.about ?? '',
      ));
    }
    lines.sort((a, b) => b.amount.compareTo(a.amount));
    final totalPot = payouts.fold<int>(0, (a, e) => a + e.amount);

    final boardUi = e.community
        .map<go.UiCard>((card) => _toUiCard(_mapEngCard(card)))
        .toList(growable: false);

    go.WinnerLine? heroLine;
    if (_heroIndex >= 0 && _heroIndex < players.length) {
      final heroPlayer = players[_heroIndex];
      eng.HandRank? heroRank = heroPlayer.best;
      if (heroRank == null) {
        final combinedEng = <eng.Card>[
          ...heroPlayer.hole,
          ...e.community,
        ];
        if (combinedEng.length >= 5) {
          heroRank = eng.HandEvaluator.evaluate(combinedEng);
        }
      }
      final List<go.UiCard> heroBest = heroRank != null
          ? heroRank.bestFive
              .map<go.UiCard>((card) => _toUiCard(_mapEngCard(card)))
              .toList(growable: false)
          : <go.UiCard>[];

      final heroHole = heroPlayer.hole
          .map<go.UiCard>((card) => _toUiCard(_mapEngCard(card)))
          .toList(growable: false);

      final heroAmount = payouts
          .where((p) => p.playerIndex == _heroIndex)
          .fold<int>(0, (acc, p) => acc + p.amount);
      final int heroContributed = heroPlayer.contributedThisHand;
      final Seat? heroSeat = (_heroIndex >= 0 && _heroIndex < seats.length)
          ? seats[_heroIndex]
          : null;
      final heroHandName = _fallbackHandName(heroRank?.category);
      heroLine = go.WinnerLine(
        playerName: heroPlayer.name,
        amount: heroAmount,
        delta: heroAmount - heroContributed,
        bet: heroContributed,
        handName: heroHandName,
        bestFive: heroBest,
        holeCards: heroHole,
        kingdom: heroSeat?.kingdom ?? '-',
        about: heroSeat?.about ?? '',
      );
    }

    final bool heroWonHand = _heroIndex >= 0 &&
        payouts.any((p) => p.playerIndex == _heroIndex && p.amount > 0);

    if (!_handWinSoundPlayed) {
      _handWinSoundPlayed = true;
      if (heroWonHand) {
        unawaited(SoundFx.instance.playHeroHandWin());
      } else {
        unawaited(SoundFx.instance.playHandWin());
      }
    }
    final overlayDuration = Duration(milliseconds: pace.kOverlayMinShowMs);
    bool overlayShown = false;
    bool overlayClosed = false;

    try {
      debugPrint('[GameScreen] winners overlay start (web=$kIsWeb)');
      await go.showWinnersDialog(
        context,
        winners: lines,
        totalPot: totalPot,
        duration: overlayDuration,
        heroLine: heroLine,
        board: boardUi,
        showCommunity:
            false, // keep community row on table (no movement/resize)
        onShown: () {
          overlayShown = true;
          debugPrint('[GameScreen] winners overlay shown');
        },
        onClosed: () {
          overlayClosed = true;
          debugPrint('[GameScreen] winners overlay closed');
        },
        useLegacyLayout: false,
      ).timeout(
        Duration(milliseconds: pace.kOverlayMinShowMs + 1500),
        onTimeout: () {
          debugPrint(
              '[GameScreen] Winners dialog timed out; forcing close (${kIsWeb ? 'web' : 'native'}).');
        },
      );
    } catch (err, st) {
      debugPrint(
          '[GameScreen] Winners dialog failed (${kIsWeb ? 'web' : 'native'}) → $err');
      debugPrint('$st');
    } finally {
      // If the dialog never opened/closed (e.g., web overlay issues), still fire the bus so Renoir can advance.
      if (!overlayClosed) {
        if (!overlayShown) {
          go.WinnersBus.fireShown();
          overlayShown = true;
        }
        go.WinnersBus.fireClosed();
        overlayClosed = true;
      }
      await _afterWinnersClosed();
    }
  }

  Future<void> _afterWinnersClosed() async {
    final e = _engine;
    if (!mounted || e == null) return;
    _lastHandPot = 0;

    if (_isMatchOver()) {
      _matchOver = true;
      _engineTicker?.cancel();
      final bool heroWon = _heroIndex >= 0 &&
          _heroIndex < e.players.length &&
          e.players[_heroIndex].chips > 0 &&
          !(e.players[_heroIndex].isOut);
      _playMatchEndCue(heroWon: heroWon);
      _markCampaignWinIfApplicable(heroWon: heroWon);
      final int winnerIdx = e.players
          .indexWhere((p) => p.chips > 0 && !p.sittingOut);
      final Seat? winnerSeat =
          (winnerIdx >= 0 && winnerIdx < seats.length) ? seats[winnerIdx] : null;
      final String venueName = (widget.venue?.name ?? '').toString();
      final String venueFlag = (widget.venue?.flagAsset ?? '').toString();
      final onDownloadCertificate =
          _titleCertificateDownloadAction(heroWon: heroWon);
      int prize = 0;
      try {
        prize = e.config.payoutForRank?.call(1) ?? 0;
      } catch (_) {}

      await go.showRenoirCongratsForMatch(
        context,
        winnerName: _winnerNameOrTopStack(),
        winnerSeat: winnerSeat,
        venueName: venueName,
        venueFlagAsset: venueFlag,
        prize: prize,
        onExitToVenue: (widget.campaignGroup != null)
            ? () => Navigator.of(context).maybePop()
            : null,
        onDownloadCertificate: onDownloadCertificate,
      );
      return;
    }

    // Reset debug all-in matched state for next hand
    _allInMatched = false;

    _cancelBoardRevealTimers();
    _botActionTimer?.cancel();
    _botActionTimer = null;
    _lastBotSeat = -1;
    setState(() {
      board = const [];
      _boardTarget = const [];
      _boardRevealCount = 0;
      _lastBoardTargetLen = 0;
      _showSeatCards = false;
      // No longer force visual deal size or force holes revealed here.
      for (int i = 0; i < seats.length; i++) {
        if (seats[i].chips > 0) {
          seats[i].busted = false;
          _clearBloodStain(i);
        }
      }
    });

    _dealSfxEnabled = false;
    _handStartQueued = true;
  }

  bool _isMatchOver() {
    final e = _engine;
    if (e == null) return false;
    final alive = e.players.where((p) => p.chips > 0 && !p.sittingOut).toList();
    return alive.length <= 1;
  }

  String _winnerNameOrTopStack() {
    final e = _engine;
    if (e == null) return 'Winner';
    final alive = e.players.where((p) => p.chips > 0 && !p.sittingOut).toList();
    if (alive.isNotEmpty) return alive.first.name;
    if (e.players.isEmpty) return 'Winner';
    final sorted = [...e.players]..sort((a, b) => b.chips.compareTo(a.chips));
    return sorted.first.name;
  }

  /* ================================= Mappers =============================== */
  _Phase _mapPhase(eng.GamePhase gp) {
    switch (gp) {
      case eng.GamePhase.predeal:
        return _Phase.predeal;
      case eng.GamePhase.preflop:
        return _Phase.preflop;
      case eng.GamePhase.flop:
        return _Phase.flop;
      case eng.GamePhase.turn:
        return _Phase.turn;
      case eng.GamePhase.river:
        return _Phase.river;
      case eng.GamePhase.showdown:
        return _Phase.showdown;
      case eng.GamePhase.handOver:
        return _Phase.showdown;
    }
  }

  GCard _mapEngCard(eng.Card c) {
    String r() {
      switch (c.rank) {
        case eng.Rank.ace:
          return 'A';
        case eng.Rank.king:
          return 'K';
        case eng.Rank.queen:
          return 'Q';
        case eng.Rank.jack:
          return 'J';
        case eng.Rank.ten:
          return '10';
        case eng.Rank.nine:
          return '9';
        case eng.Rank.eight:
          return '8';
        case eng.Rank.seven:
          return '7';
        case eng.Rank.six:
          return '6';
        case eng.Rank.five:
          return '5';
        case eng.Rank.four:
          return '4';
        case eng.Rank.three:
          return '3';
        case eng.Rank.two:
          return '2';
      }
    }

    String s() {
      switch (c.suit) {
        case eng.Suit.spades:
          return '♠';
        case eng.Suit.hearts:
          return '♥';
        case eng.Suit.diamonds:
          return '♦';
        case eng.Suit.clubs:
          return '♣';
      }
    }

    return GCard(r(), s());
  }

  go.UiCard _toUiCard(GCard gc) => go.UiCard(gc.rank, gc.suit);

  String _fallbackHandName(eng.HandCategory? c) {
    switch (c) {
      case eng.HandCategory.straightFlush:
        return 'Straight Flush';
      case eng.HandCategory.fourKind:
        return 'Four of a Kind';
      case eng.HandCategory.fullHouse:
        return 'Full House';
      case eng.HandCategory.flush:
        return 'Flush';
      case eng.HandCategory.straight:
        return 'Straight';
      case eng.HandCategory.threeKind:
        return 'Three of a Kind';
      case eng.HandCategory.twoPair:
        return 'Two Pair';
      case eng.HandCategory.pair:
        return 'One Pair';
      case eng.HandCategory.highCard:
        return 'High Card';
      default:
        return '';
    }
  }

  double _snapRaiseAmount(double raw, double min, double max) {
    final int inc = eng.kRaiseIncrement;
    if (inc <= 0) return raw.clamp(min, max).toDouble();

    final double snapped = ((raw / inc).round() * inc).toDouble();
    return snapped.clamp(min, max).toDouble();
  }

  int _sanitizeRaiseForEngine(int raiseToTotal) {
    final e = _engine;
    if (e == null) return raiseToTotal;

    final bounds = e.raiseBoundsTo(_heroIndex);
    return _snapRaiseAmount(
      raiseToTotal.toDouble(),
      bounds.minTo.toDouble(),
      bounds.maxTo.toDouble(),
    ).round();
  }

  /* =============================== Hero actions =========================== */
  void _doHeroCheckOrCall() {
    final e = _engine;
    if (!_isHeroTurn || e == null) return;
    _botActionTimer?.cancel();
    _botActionTimer = null;
    _lastBotSeat = -1;
    final need = e.toCallFor(_heroIndex);
    if (need == 0) {
      e.act(eng.ActionType.check);
    } else {
      e.act(eng.ActionType.call);
    }
  }

  void _doHeroFold() {
    final e = _engine;
    if (!_isHeroTurn || e == null) return;
    _botActionTimer?.cancel();
    _botActionTimer = null;
    _lastBotSeat = -1;
    e.act(eng.ActionType.fold);
  }

  void _doHeroBetOrRaise(int raiseToTotal) {
    final e = _engine;
    if (!_isHeroTurn || e == null) return;
    _botActionTimer?.cancel();
    _botActionTimer = null;
    _lastBotSeat = -1;
    final int desired = _sanitizeRaiseForEngine(raiseToTotal);
    final int need = e.toCallFor(_heroIndex);
    if (need <= 0) {
      e.act(eng.ActionType.bet, amount: desired);
    } else {
      e.act(eng.ActionType.raise, amount: desired);
    }
  }

  void _doHeroAllIn() {
    final e = _engine;
    if (!_isHeroTurn || e == null) return;
    _botActionTimer?.cancel();
    _botActionTimer = null;
    _lastBotSeat = -1;
    e.act(eng.ActionType.allIn);
  }

  /* ============================ UI ======================================= */
  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    final Color bg = _venueColor(venue, 'background', AppColors.black);
    final Color felt = _venueColor(venue, 'felt', const Color(0xFF13321E));
    final String flagPath = (venue?.flagAsset ?? '').toString();
    final String venueName = (venue?.name ?? '').toString();

    final bool isHeroTurn = _isHeroTurn;
    final int toCall = _heroToCall;

    final e = _engine;
    final int bb = e?.config.bigBlind ?? 200;
    int minTo = bb;
    int maxTo = bb * 20;
    if (e != null && e.players.isNotEmpty && _heroIndex >= 0) {
      final bounds = e.raiseBoundsTo(_heroIndex);
      minTo = bounds.minTo;
      maxTo = math.max(bounds.maxTo, minTo);
    }
    final double sliderMin = minTo.toDouble();
    final double sliderMax = math.max(sliderMin, maxTo.toDouble());
    final double raiseAmount =
        _snapRaiseAmount(_raiseAmount, sliderMin, sliderMax);

    const double deckHeightPx = 0.0;
    const Offset deckOffset = Offset.zero;
    const double deckScale = 0.0;

    // 🔹 Venue time (fixed offsets as per your spec, DST where applicable)
    final int venueOffset = offsetMinutesForVenue(venueName);

    final String renoirNow =
        _renoirDealing ? _renoirDealAsset : _renoirIdleAsset;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: GameScreenUI(
        bg: bg,
        venueName: venueName,
        flagPath: flagPath,
        onShowHandRankings: _showHandRankings,
        felt: felt,
        wood: _currentWood,
        monumentPath: _monumentPath,
        renoirAsset: renoirNow,
        defaultProfileAsset: _defaultProfile,
        cardBackAsset: CardBackTheme.current,
        pot: pot,
        board: board,
        seats: seats,
        activeBloodStains: _activeBloodStains,
        currentTurn: currentTurn,
        sbIndex: sbIndex,
        bbIndex: bbIndex,
        heroIndex: _heroIndex,
        recentActions: _recentActions,
        isHeroTurn: isHeroTurn,
        toCall: toCall,
        showShuffle: _uiShowShuffle,
        showDeckPile: false,
        deckHeightPx: deckHeightPx,
        deckOffset: deckOffset,
        deckScale: deckScale,
        renoirLiftPx: _kRenoirLiftPx,
        showToggleVisible: (phase == _Phase.showdown),
        heroShow: false,
        playIntroWelcome: widget.playIntroWelcome,
        potPulse: _potPulse,
        raiseAmount: raiseAmount,
        minRaise: sliderMin,
        maxRaise: sliderMax,
        onRaiseAmountChanged: (v) => setState(() {
          _raiseAmount = _snapRaiseAmount(v, sliderMin, sliderMax);
        }),
        onCheckOrCall: _doHeroCheckOrCall,
        onFold: _doHeroFold,
        onBetOrRaise: () => _doHeroBetOrRaise(raiseAmount.round()),
        onAllIn: _doHeroAllIn,
        onToggleShow: () {},
        startingStack: _kInitialChips,
        venueOffsetMinutes: venueOffset,
        engineEvents: _dealEventCtrl.stream,
        engine: _engine,
        onRenoirShuffle: _handleRenoirShuffle,
        dealerAvatarStyle: _dealerAvatarStyle,
      ),
    );
  }

  /* ================= Venue → offset (minutes east of UTC) ================= */

  /// Primary helper used in build()
  int offsetMinutesForVenue(String venueName, {DateTime? nowUtc}) {
    nowUtc ??= DateTime.now().toUtc();
    final v = venueName.toLowerCase().trim();

    // ——— Your explicit spec ———
    if (v.contains('america')) {
      // Washington, DC (US Eastern) with DST
      return _usEasternOffsetMinutes(nowUtc);
    }
    if (v.contains('arabia')) {
      // UAE/Dubai (no DST)
      return 240; // UTC+4
    }
    if (v.contains('southeast')) {
      // Singapore (no DST)
      return 480; // UTC+8
    }
    if (v.contains('amazon')) {
      // São Paulo reference (no DST since 2019)
      return -180; // UTC-3
    }
    if (v.contains('africa')) {
      // Cairo baseline per your note (keep fixed)
      return 120; // UTC+2
    }

    // ——— “Just in case” fallbacks you noted earlier ———
    if (v.contains('europe') || v.contains('paris')) {
      return _europeParisOffsetMinutes(nowUtc);
    }
    if (v.contains('russia') || v.contains('moscow')) {
      return 180; // UTC+3
    }
    if (v.contains('australia') ||
        v.contains('sydney') ||
        v.contains('melbourne')) {
      return _australiaSydneyOffsetMinutes(nowUtc);
    }
    if (v.contains('china') || v.contains('hong kong') || v.contains('macau')) {
      return 480; // UTC+8
    }

    // Indian venues & defaults → IST
    if (v.contains('india') ||
        v.contains('delhi') ||
        v.contains('new delhi') ||
        v.contains('jaipur') ||
        v.contains('baroda') ||
        v.contains('hyderabad') ||
        v.contains('mysore') ||
        v.contains('sikkim') ||
        v.contains('indore') ||
        v.contains('travancore') ||
        v.contains('sikh empire') ||
        v.contains('maratha')) {
      return 330; // UTC+5:30
    }

    return 330; // safe default IST
  }

  /// US Eastern DST: -300 (EST) vs -240 (EDT)
  int _usEasternOffsetMinutes(DateTime nowUtc) {
    // Approximate by computing local-like dates.
    final asEasternStd = nowUtc.add(const Duration(minutes: -300));
    final year = asEasternStd.year;

    final secondSunMar = _nthWeekdayOfMonth(year, 3, DateTime.sunday, 2);
    final firstSunNov = _nthWeekdayOfMonth(year, 11, DateTime.sunday, 1);

    final dstStartLocal = DateTime(year, 3, secondSunMar.day, 2); // 02:00 local
    final dstEndLocal = DateTime(year, 11, firstSunNov.day, 2);

    final dstStartUtc =
        dstStartLocal.subtract(const Duration(hours: 5)); // EST=UTC-5
    final dstEndUtc =
        dstEndLocal.subtract(const Duration(hours: 4)); // EDT=UTC-4

    final inDst = nowUtc.isAfter(dstStartUtc) && nowUtc.isBefore(dstEndUtc);
    return inDst ? -240 : -300;
  }

  /// Paris CET/CEST: +60 / +120
  int _europeParisOffsetMinutes(DateTime nowUtc) {
    final year = nowUtc.year;
    final lastSunMar = _lastWeekdayOfMonth(year, 3, DateTime.sunday);
    final lastSunOct = _lastWeekdayOfMonth(year, 10, DateTime.sunday);

    final dstStartLocal = DateTime(year, 3, lastSunMar.day, 2); // 02:00 CET
    final dstEndLocal = DateTime(year, 10, lastSunOct.day, 3); // 03:00 CEST

    final dstStartUtc =
        dstStartLocal.subtract(const Duration(hours: 1)); // CET=UTC+1
    final dstEndUtc =
        dstEndLocal.subtract(const Duration(hours: 2)); // CEST=UTC+2

    final inDst = nowUtc.isAfter(dstStartUtc) && nowUtc.isBefore(dstEndUtc);
    return inDst ? 120 : 60;
  }

  /// Sydney AEST/AEDT: +600 / +660
  int _australiaSydneyOffsetMinutes(DateTime nowUtc) {
    final asSydneyStd = nowUtc.add(const Duration(hours: 10));
    final year = asSydneyStd.year;

    final firstSunOct = _nthWeekdayOfMonth(year, 10, DateTime.sunday, 1);
    final firstSunApr = _nthWeekdayOfMonth(year + 1, 4, DateTime.sunday, 1);

    final dstStartLocal = DateTime(year, 10, firstSunOct.day, 2);
    final dstEndLocal = DateTime(year + 1, 4, firstSunApr.day, 3);

    final dstStartUtc =
        dstStartLocal.subtract(const Duration(hours: 10)); // AEST
    final dstEndUtc = dstEndLocal.subtract(const Duration(hours: 11)); // AEDT

    final inDst = nowUtc.isAfter(dstStartUtc) && nowUtc.isBefore(dstEndUtc);
    return inDst ? 660 : 600;
  }

  // Calendar helpers
  DateTime _nthWeekdayOfMonth(int year, int month, int weekday, int nth) {
    final first = DateTime(year, month, 1);
    int shift = (weekday - first.weekday) % 7;
    final day = 1 + shift + (nth - 1) * 7;
    return DateTime(year, month, day);
  }

  DateTime _lastWeekdayOfMonth(int year, int month, int weekday) {
    final firstNext =
        (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final last = firstNext.subtract(const Duration(days: 1));
    int shift = (last.weekday - weekday) % 7;
    return DateTime(year, month, last.day - shift);
  }

  /* ============================ Misc UI helpers =========================== */

  Color _venueColor(dynamic v, String key, Color fallback) {
    if (v == null) return fallback;

    if (v is Map && v[key] is Color) {
      return v[key] as Color;
    }

    try {
      final dynamic c = (key == 'background')
          ? (v as dynamic).background
          : (v as dynamic).felt;
      if (c is Color) return c;
    } catch (_) {}

    return fallback;
  }

  void _showHandRankings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Builder(
            builder: (sheetContext) {
              final media = MediaQuery.of(sheetContext);
              final maxListHeight =
                  (media.size.height * 0.65).clamp(360.0, 780.0);
              final controller = ScrollController();

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  media.viewInsets.bottom + 24,
                ),
                child: DecoratedBox(
                  decoration:
                      go.renoirGlassPanelDecoration(radius: 18, opacity: 0.68),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Center(
                          child: go.GoldenText(
                            'Hand Rankings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxListHeight,
                            maxWidth: 760,
                          ),
                          child: Scrollbar(
                            controller: controller,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: controller,
                              physics: const BouncingScrollPhysics(),
                              child: const HandExamples(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
