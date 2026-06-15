// lib/ui/screens/game_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, rootBundle;
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/app/system_ui.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/config/app_build.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart' show VenueGroup;
import 'package:ten_of_a_kind_poker/features/venue/game_mode.dart';
import 'package:ten_of_a_kind_poker/game/bot/policy_model.dart'
    show BotLearnedPolicyRegistry, BotLearnedPolicyWeights, BotPolicyAdjustment;
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/ads_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/services/poker_bot_learning_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/ui/utils/deck_cache.dart';
import 'package:ten_of_a_kind_poker/ui/utils/rewarded_aup.dart';
import 'package:ten_of_a_kind_poker/ui/utils/watermark_resolver.dart';
import 'package:ten_of_a_kind_poker/ui/utils/author_flash_gate.dart';
import 'package:ten_of_a_kind_poker/config/app_tier.dart';
import 'game_screen/renoir_ui.dart' show RenoirSignals;
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/overlays.dart' as go;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/models.dart'; // GCard
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/players.dart'; // Seat
import 'package:ten_of_a_kind_poker/game/events.dart' as ge;
import 'package:ten_of_a_kind_poker/ui/widgets/slash_avatar.dart'
    show DealerAvatarStyle;

import 'package:ten_of_a_kind_poker/ui/screens/game_screen/table.dart'
    show WoodType;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/hand_examples.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/ui.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/cards.dart'
    show CardBackTheme;
import 'package:ten_of_a_kind_poker/ui/screens/venue_screen.dart';

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

// 25 Indian bots
const List<_BotSpec> _indianBotSpecs = <_BotSpec>[
  // Maratha Empire
  _BotSpec('Arjun Deshmukh', 'Maratha Empire', 'Fort-born legend, no punts'),
  _BotSpec('Bajirao Kale', 'Maratha Empire', 'ICM emperor, final boss'),
  _BotSpec('Savitri Shinde', 'Maratha Empire', 'Fortress queen, flawless KO',
      female: true),
  // Mysore
  _BotSpec('Kaveri Rao', 'Mysore', 'Palace queen, trophy hunter', female: true),
  _BotSpec('Anvika Nayak', 'Mysore', 'Trap legend, clean execution',
      female: true),
  // Sikh Empire
  _BotSpec('Amrita Kaur', 'Sikh Empire', 'Langar laughs, sneaky traps',
      female: true),
  _BotSpec('Jaspreet Dhillon', 'Sikh Empire', 'Grit GOAT, river royalty'),
  _BotSpec('Harleen Kaur', 'Sikh Empire', 'Steel nerves, mythic runouts',
      female: true),
  // Jaipur
  _BotSpec('Rajvi Rathore', 'Jaipur', 'Pink city, sharp tongue bets',
      female: true),
  _BotSpec('Kunal Rathore', 'Jaipur', 'Desert king, unbluffable'),
  // Baroda
  _BotSpec('Neel Patel', 'Baroda', 'Laxmi luck, legend hands'),
  _BotSpec('Siddharth Gaekwad', 'Baroda', 'Edge finder, crown collector'),
  // Hyderabad
  _BotSpec('Ayesha Qureshi', 'Hyderabad', 'Pearl smile, sharp elbows',
      female: true),
  _BotSpec('Faizan Ali', 'Hyderabad', 'Bazaar boss, squeeze machine'),
  _BotSpec('Zoya Begum', 'Hyderabad', 'Razor thin, queen of jams',
      female: true),
  // Indore
  _BotSpec('Pooja Sharma', 'Indore', 'Poha polite, river vicious',
      female: true),
  _BotSpec('Kriti Jain', 'Indore', 'Turn pressure, trophy hunter',
      female: true),
  // Sikkim
  _BotSpec('Geeta Chhetri', 'Sikkim', 'Peak zen, giggles at bluffs',
      female: true),
  _BotSpec('Tenzin Lama', 'Sikkim', 'Snowline sage, no mistakes'),
  // New Delhi
  _BotSpec('Meera Luthra', 'New Delhi', 'Monsoon mood, mean raises',
      female: true),
  _BotSpec('Kabir Verma', 'New Delhi', 'Ring-road ruler, no leaks'),
  _BotSpec('Ananya Khanna', 'New Delhi', 'Metro queen, stone-cold ICM',
      female: true),
  // Travancore
  _BotSpec('Lekha Pillai', 'Travancore', 'Peppery reads, burn stacks',
      female: true),
  _BotSpec('Hari Krishnan', 'Travancore', 'Backwater boss, value surgeon'),
  _BotSpec('Nila Varma', 'Travancore', 'Coconut crown, river tyrant',
      female: true),
];

// 75 shared International, Euro, and Oceania bots.
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
  _BotSpec('Layla Haddad', 'Arabia', 'Spice-souk sass, overbets', female: true),
  _BotSpec('Omar Rahman', 'Arabia', 'Falcon eyes, claws out'),
  // Africa
  _BotSpec('Kwame Mensah', 'Africa', 'Savanna snap, no patience'),
  _BotSpec('Zuri Okoro', 'Africa', 'Kora beat, mean re-raise', female: true),
  _BotSpec('Amare Bekele', 'Africa', 'Safari swagger, take it'),
  // S. America
  _BotSpec('Iara Santos', 'S. America', 'Canopy queen, chaos barrels',
      female: true),
  _BotSpec('Mateus Carvalho', 'S. America', 'Riverboat grin, safe folds'),
  _BotSpec('Belem Moraes', 'S. America', 'Rain-drum rage, shove', female: true),
  // Australia
  _BotSpec('Tahlia Lawson', 'Australia', 'Outback chill laughs at bluffs',
      female: true),
  _BotSpec('Cooper Mitchell', 'Australia', 'Harbour dad-jokes, tight'),
  _BotSpec('Nara Waru', 'Australia', 'Didgeridoo doom, snap jam', female: true),
  // India
  _BotSpec('Raghav Solanki', 'India', 'Tricolor calm, check-call king'),
  _BotSpec('Yuvraj Bhaduria', 'India', 'Freedom torch, burn stacks'),
  _BotSpec('Ruta Dogra', 'India', 'Bharat tour, ruthless reroutes',
      female: true),
  // Asia
  _BotSpec('Mahe Nguyen', 'Asia', 'Night market, nasty CR', female: true),
  _BotSpec('Somchai Prasert', 'Asia', 'Monsoon rage, barrels rain'),
  _BotSpec('Putri Dewi', 'Asia', 'Temple trapper, trophy shelf', female: true),

  // Southeast Asia
  _BotSpec('Anong Srisai', 'Asia', 'Bangkok calm, snap steals', female: true),
  _BotSpec('Chaiwat Rattan', 'Asia', 'Chiang Mai pressure lines'),
  _BotSpec('Linh Pham', 'Asia', 'Saigon river, clean calls', female: true),
  _BotSpec('Minh Tran', 'Asia', 'Hanoi grind, cold 4-bets'),
  _BotSpec('Sari Wijaya', 'Asia', 'Jakarta tempo, thin value', female: true),
  _BotSpec('Bima Santoso', 'Asia', 'Bali smile, brutal jams'),
  _BotSpec('Nur Aisyah', 'Asia', 'KL lights, tricky barrels', female: true),
  _BotSpec('Hakim Rahman', 'Asia', 'Penang read, quiet traps'),
  _BotSpec('Mei Lin Tan', 'Asia', 'Marina solver, no leaks', female: true),
  _BotSpec('Darren Lim', 'Asia', 'Lion City, clean pressure'),
  _BotSpec('Rosa Delgado', 'Asia', 'Manila rhythm, hero calls', female: true),
  _BotSpec('Miguel Santos', 'Asia', 'Cebu heat, fearless shoves'),
  _BotSpec('Thandar Hlaing', 'Asia', 'Yangon patience, sharp traps',
      female: true),
  _BotSpec('Ko Aung Min', 'Asia', 'Mandalay steel, slow burn'),
  _BotSpec('Sreymom Vann', 'Asia', 'Phnom Penh calm, river sting',
      female: true),
  _BotSpec('Dara Sok', 'Asia', 'Angkor focus, clean folds'),
  _BotSpec('Kanya Vong', 'Asia', 'Vientiane quiet, value cuts', female: true),
  _BotSpec('Somphone Keo', 'Asia', 'Mekong grind, crisp calls'),
  _BotSpec('Liyana Salleh', 'Asia', 'Bandar poise, soft smiles', female: true),
  _BotSpec('Azim Mahmud', 'Asia', 'Borneo patience, cold jams'),
  _BotSpec('Ana Soares', 'Asia', 'Dili breeze, sharp calls', female: true),
  _BotSpec('Mateus da Costa', 'Asia', 'Timor grit, fearless value'),
  _BotSpec('Fitri Halim', 'Asia', 'Surabaya snap, turn heat', female: true),
  _BotSpec('Van Nguyen', 'Asia', 'Da Nang pressure, neat traps'),
  _BotSpec('Nattida Kwan', 'Asia', 'Phuket charm, hard reads', female: true),

  // --- Super-bots ---
  // Africa
  _BotSpec('Kofi Adeyemi', 'Africa', 'Savanna GOAT, pounce mode'),
  _BotSpec('Amara Ndlovu', 'Africa', 'Lioness legend, fearless', female: true),
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
  _BotSpec('Mei Chen', 'China', 'Mahjong legend, perfect lines', female: true),
  // Europe
  _BotSpec('Maximilian Keller', 'Europe', 'Solver GOAT, zero punts'),
  _BotSpec('Elena Rossi', 'Europe', 'Alpine legend, icy value', female: true),
  // Russia
  _BotSpec('Dmitri Kuznetsov', 'Russia', 'Ice-cold czar, final boss'),
  _BotSpec('Irina Sokolova', 'Russia', 'Metro legend, brutal value',
      female: true),
  // India
  _BotSpec('Arjun Malhotra', 'India', 'Tricolor titan, no leaks'),
  _BotSpec('Priya Nair', 'India', 'Spice queen, river lockdown', female: true),
  // Asia
  _BotSpec('Somporn Suriya', 'Asia', 'Monsoon master, crown reads'),
  _BotSpec('Lien Tran', 'Asia', 'Night-market legend, razor', female: true),
];

/* -------------------------- Bot aura catalog ----------------------------- */
const Map<String, int> _botAuraByName = {
  // Indian roster
  'Arjun Deshmukh': 94,
  'Kaveri Rao': 95,
  'Amrita Kaur': 92,
  'Rajvi Rathore': 83,
  'Neel Patel': 90,
  'Ayesha Qureshi': 85,
  'Pooja Sharma': 85,
  'Geeta Chhetri': 82,
  'Meera Luthra': 85,
  'Lekha Pillai': 85,
  'Bajirao Kale': 99,
  'Savitri Shinde': 96,
  'Anvika Nayak': 96,
  'Jaspreet Dhillon': 99,
  'Harleen Kaur': 97,
  'Kunal Rathore': 97,
  'Siddharth Gaekwad': 98,
  'Faizan Ali': 97,
  'Zoya Begum': 95,
  'Kriti Jain': 95,
  'Tenzin Lama': 98,
  'Kabir Verma': 97,
  'Ananya Khanna': 95,
  'Hari Krishnan': 96,
  'Nila Varma': 95,

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
  'Anong Srisai': 86,
  'Chaiwat Rattan': 82,
  'Linh Pham': 88,
  'Minh Tran': 84,
  'Sari Wijaya': 87,
  'Bima Santoso': 83,
  'Nur Aisyah': 89,
  'Hakim Rahman': 81,
  'Mei Lin Tan': 95,
  'Darren Lim': 86,
  'Rosa Delgado': 87,
  'Miguel Santos': 82,
  'Thandar Hlaing': 85,
  'Ko Aung Min': 80,
  'Sreymom Vann': 84,
  'Dara Sok': 79,
  'Kanya Vong': 83,
  'Somphone Keo': 78,
  'Liyana Salleh': 86,
  'Azim Mahmud': 81,
  'Ana Soares': 82,
  'Mateus da Costa': 80,
  'Fitri Halim': 85,
  'Van Nguyen': 84,
  'Nattida Kwan': 88,

  // International super-bots
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
const int _kDefaultMaxSeats = 10;
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
  final VenueEntryMode venueMode;
  final VenueGroup? campaignGroup;
  final int? campaignSubKingdomIndex;
  final bool campaignMainEvent;

  const GameScreen({
    super.key,
    required this.tableName,
    required this.venue,
    this.playIntroWelcome = true,
    this.venueMode = VenueEntryMode.quickGame,
    this.campaignGroup,
    this.campaignSubKingdomIndex,
    this.campaignMainEvent = false,
  });

  factory GameScreen.guestTable({
    required String tableName,
    required dynamic venue,
    bool playIntroWelcome = true,
    VenueEntryMode venueMode = VenueEntryMode.quickGame,
    VenueGroup? campaignGroup,
    int? campaignSubKingdomIndex,
    bool campaignMainEvent = false,
  }) =>
      GameScreen(
        tableName: tableName,
        venue: venue,
        playIntroWelcome: playIntroWelcome,
        venueMode: venueMode,
        campaignGroup: campaignGroup,
        campaignSubKingdomIndex: campaignSubKingdomIndex,
        campaignMainEvent: campaignMainEvent,
      );

  @visibleForTesting
  static int resolvedTableMaxSeats({
    required VenueEntryMode venueMode,
    required bool campaignMainEvent,
    required bool isFreeSubKingdom,
    int? campaignMaxPlayers,
    int defaultMaxSeats = _kDefaultMaxSeats,
  }) {
    if (campaignMainEvent) return 10;
    if (venueMode == VenueEntryMode.quickGame || isFreeSubKingdom) {
      return 6;
    }
    return math.max(2, campaignMaxPlayers ?? defaultMaxSeats);
  }

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  String? _monumentPathOverride;
  ce.CampaignEventSpec? _campaignSpec;
  late final int _tableMaxSeats;
  late final int _startingStackChips;
  bool _disposing = false;
  AuraPointsService? _auraService;
  VoidCallback? _auraListener;
  int _heroAura = _kHeroAura;
  ProfileService? _profileService;
  VoidCallback? _profileListener;
  String _heroAbout = ProfileService.defaultAbout;

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
        unawaited(
          context.read<AuraPointsService>().awardForCampaignWin(
                group: group,
                kingdomName: kingdomName,
                isMainEvent: true,
              ),
        );
        return;
      }

      final idx = widget.campaignSubKingdomIndex;
      if (idx == null) return;
      progress.markCleared(
        group: group,
        kingdomName: kingdomName,
        subKingdomIndex: idx,
      );
      unawaited(
        context.read<AuraPointsService>().awardForCampaignWin(
              group: group,
              kingdomName: kingdomName,
              isMainEvent: false,
              subKingdomIndex: idx,
            ),
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
    if (v.contains('s. america') ||
        v.contains('south america') ||
        v.contains('amazon')) {
      return DealerAvatarStyle.southAmerica;
    }
    if (v.contains('n. america') || v.contains('north america')) {
      return DealerAvatarStyle.northAmerica;
    }
    if (v.contains('arabia') || v.contains('persia')) {
      return DealerAvatarStyle.arabia;
    }
    if (v.contains('australia')) return DealerAvatarStyle.australia;
    if (v.contains('china') || v.contains('far east')) {
      return DealerAvatarStyle.china;
    }
    if (v.contains('europe')) return DealerAvatarStyle.europe;
    if (v == 'india') return DealerAvatarStyle.india;
    if (v.contains('russia')) return DealerAvatarStyle.russia;
    if (v.contains('asia') || v.contains('southeast'))
      return DealerAvatarStyle.asia;

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
  static const Duration _kSeatActionPopupLifetime = Duration(seconds: 5);
  static const Duration _kFoldedHoleCardFadeDuration = Duration(seconds: 2);
  final Set<int> _activeBloodStains = <int>{};
  final Map<int, Timer> _bloodStainTimers = <int, Timer>{};
  final Map<int, Timer> _actionHintTimers = <int, Timer>{};
  final Map<int, Timer> _foldedHoleCardTimers = <int, Timer>{};
  final Set<int> _foldedHoleCardsCleared = <int>{};
  final Set<int> _pendingBust = <int>{};
  final Set<int> _bustSounded = <int>{};

  // ---- Table / seats
  late List<Seat> seats;
  int dealerIndex = -1;
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
  bool _paused = false;
  bool _handOverHandled = false;
  double _lastHandPot = 0;
  // Track if everyone is all-in & matched (for debug/UX)
  bool _allInMatched = false;
  bool _heroWasLeader = false;
  bool _heroInDanger = false;
  int? _heroFinalRank;
  int _heroFinalWinnings = 0;
  bool _heroFinishOverlayShown = false;
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
    'persia': 'assets/images/watermarks/arabia.svg',
    'africa': 'assets/images/watermarks/africa.svg',
    'amazon': 'assets/images/watermarks/amazon.svg',
    'europe': 'assets/images/watermarks/europe.svg',
    'far east': 'assets/images/watermarks/china.svg',
    'n. america': 'assets/images/watermarks/america.svg',
    's. america': 'assets/images/watermarks/amazon.svg',
    'asia rest': 'assets/images/watermarks/southeast.svg',
    'asia': 'assets/images/watermarks/southeast.svg',
    'southeast': 'assets/images/watermarks/southeast.svg',
    'britain': 'assets/images/watermarks/Britain/britain.svg',
    'france': 'assets/images/watermarks/France/france.svg',
    'italy': 'assets/images/watermarks/Italy/italy.svg',
    'spain': 'assets/images/watermarks/Spain/spain.svg',
    'portugal': 'assets/images/watermarks/Portugal/portugal.svg',
    'north sea': 'assets/images/watermarks/North Sea/north_sea.svg',
    'scandinavia': 'assets/images/watermarks/Scandinavia/scandinavia.svg',
    'baltic marches':
        'assets/images/watermarks/Baltic Marches/baltic_marches.svg',
    'russia & siberia':
        'assets/images/watermarks/Russia & Siberia/russia_siberia.svg',
    'mediterranean': 'assets/images/watermarks/Mediterranean/mediterranean.svg',
    'alaska': 'assets/images/watermarks/Alaska/alaska.svg',
    'caribbean': 'assets/images/watermarks/Caribbean/caribbean.svg',
    'dragonland': 'assets/images/watermarks/Dragonland/dragonland.svg',
    'straits': 'assets/images/watermarks/Straits/straits.svg',
    'indian ocean': 'assets/images/watermarks/Indian Ocean/indian_ocean.svg',
    'pacific': 'assets/images/watermarks/Pacific/pacific.svg',
    'british isles': 'assets/images/watermarks/British Isles/british_isles.svg',
    'french isles': 'assets/images/watermarks/French Isles/french_isles.svg',
    'dutch isles': 'assets/images/watermarks/Dutch Isles/dutch_isles.svg',
    'american isles':
        'assets/images/watermarks/American Isles/american_isles.svg',
  };

  bool get _useSubKingdomWatermark {
    final idx = widget.campaignSubKingdomIndex;
    return widget.campaignGroup != null &&
        !widget.campaignMainEvent &&
        idx != null &&
        idx > 0;
  }

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
    if (_useSubKingdomWatermark) {
      final override = _monumentPathOverride;
      if (override != null && override.isNotEmpty) return override;
    }
    final vn = (widget.venue?.name ?? '').toString().toLowerCase().trim();
    return _monumentForVenue[vn] ?? 'assets/images/watermarks/india.svg';
  }

  Future<void> _pickSubKingdomWatermarkIfAny() async {
    if (!_useSubKingdomWatermark) return;

    final kingdomName = (widget.venue?.name ?? '').toString().trim();
    if (kingdomName.isEmpty) return;

    final idx = widget.campaignSubKingdomIndex;
    if (idx == null) return;

    final path = await WatermarkResolver.subKingdomWatermarkFor(
      kingdomName: kingdomName,
      subKingdomIndex: idx,
    );
    if (path == null) return;

    try {
      await rootBundle.load(path);
    } catch (_) {
      return;
    }

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
  Timer? _botWatchdogTimer;
  int _lastBotSeat = -1;
  final Map<int, int> _botFixedThinkDelays = <int, int>{};
  bool _heroTurnChimed = false; // ensure hero-turn sound plays once per turn
  late final int _heroTurnTimeoutSeconds;
  Timer? _heroTurnTimer;
  int _heroTurnTimerToken = 0;
  bool _heroTurnClockArmed = false;
  DateTime? _heroTurnDeadline;
  int? _heroTurnSecondsRemaining;
  int? _heroTurnResumeSeconds;
  late final StreamController<ge.EngineEvent> _dealEventCtrl;
  Timer? _handRankHighlightTimer;
  bool _showHandRankHighlight = false;
  List<GCard> _handRankHighlightCards = const <GCard>[];
  Timer? _actionFlashTimer;
  bool _showActionFlash = false;
  String _actionFlashName = '';
  String _actionFlashLabel = '';
  DateTime? _lastBackPressedAt;
  bool _exitDialogOpen = false;
  final PokerBotLearningService _botLearningService =
      const PokerBotLearningService();
  String? _lastBotTrainingSummary;

  void _stopHeroTurnTicker() {
    _heroTurnTimer?.cancel();
    _heroTurnTimer = null;
    _heroTurnTimerToken++;
    _heroTurnClockArmed = false;
    _heroTurnDeadline = null;
  }

  void _clearHandRankHighlight({bool notify = true}) {
    _handRankHighlightTimer?.cancel();
    _handRankHighlightTimer = null;
    if (!_showHandRankHighlight && _handRankHighlightCards.isEmpty) return;
    _showHandRankHighlight = false;
    _handRankHighlightCards = const <GCard>[];
    if (notify && mounted && !_disposing) setState(() {});
  }

  void _clearActionFlash({bool notify = true}) {
    _actionFlashTimer?.cancel();
    _actionFlashTimer = null;
    if (!_showActionFlash &&
        _actionFlashName.isEmpty &&
        _actionFlashLabel.isEmpty) {
      return;
    }
    _showActionFlash = false;
    _actionFlashName = '';
    _actionFlashLabel = '';
    if (notify && mounted && !_disposing) setState(() {});
  }

  Future<void> _exitToVenue() async {
    if (!mounted || _disposing) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    final rootNav = Navigator.of(context, rootNavigator: true);
    await rootNav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => VenueScreen(mode: widget.venueMode),
      ),
      (route) => false,
    );
  }

  Future<bool> _showExitDialog() async {
    if (_exitDialogOpen) return false;
    _exitDialogOpen = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async {
            final now = DateTime.now();
            final last = _lastBackPressedAt;
            if (last != null &&
                now.difference(last) <= const Duration(milliseconds: 900)) {
              Navigator.of(ctx, rootNavigator: true).pop(true);
              return false;
            }
            _lastBackPressedAt = now;
            return false;
          },
          child: AlertDialog(
            backgroundColor: AppColors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Exit to venue?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: 'Cancel',
                  onPressed: () =>
                      Navigator.of(ctx, rootNavigator: true).pop(false),
                ),
              ],
            ),
            content: const Text(
              'Your current match will be closed.',
              style: TextStyle(color: Colors.white70),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(ctx, rootNavigator: true).pop(true),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    _exitDialogOpen = false;
    if (result == true) {
      await _exitToVenue();
      return true;
    }
    _lastBackPressedAt = null;
    return false;
  }

  Future<bool> _handleBackPressed() async {
    final now = DateTime.now();
    final last = _lastBackPressedAt;
    if (last != null &&
        now.difference(last) <= const Duration(milliseconds: 900)) {
      await _exitToVenue();
      return false;
    }
    _lastBackPressedAt = now;
    await _showExitDialog();
    return false;
  }

  String _formatBotLearningTimestamp(DateTime time) {
    return time.toLocal().toString().replaceFirst('.000', '');
  }

  List<eng.BotDecisionLogEntry> _currentBotDecisionLog() {
    final e = _engine;
    if (e == null) return const <eng.BotDecisionLogEntry>[];
    return List<eng.BotDecisionLogEntry>.from(e.botDecisionLog);
  }

  List<Map<String, Object?>> _botSeatLearningState() {
    final e = _engine;
    if (e == null) return const <Map<String, Object?>>[];
    return List<Map<String, Object?>>.generate(e.players.length, (int index) {
      final player = e.players[index];
      final memory = e.opponentMemoryForSeat(index);
      final style = e.styleStateForSeat(index);
      return <String, Object?>{
        'seat': index,
        'playerId': player.id,
        'playerName': player.name,
        'isBot': player.isBot,
        'chips': player.chips,
        'aura': player.aura,
        'memory': <String, Object?>{
          'handsSeen': memory.handsSeen,
          'vpip': memory.vpip,
          'pfr': memory.pfr,
          'flopCBet': memory.flopCBet,
          'turnBarrel': memory.turnBarrel,
          'foldToBet': memory.foldToBet,
          'foldToRaise': memory.foldToRaise,
          'riverAggression': memory.riverAggression,
          'foldPressure': memory.foldPressure,
          'aggressionIndex': memory.aggressionIndex,
          'showdownStrength': memory.showdownStrength,
        },
        'style': <String, Object?>{
          'aggressionHeat': style.aggressionHeat,
          'bluffAppetite': style.bluffAppetite,
          'caution': style.caution,
          'confidence': style.confidence,
          'revengeTargetId': style.revengeTargetId,
        },
      };
    });
  }

  String _botLearningSnapshotJson({
    List<eng.BotDecisionLogEntry>? decisionLog,
  }) {
    final List<eng.BotDecisionLogEntry> rows =
        decisionLog ?? _currentBotDecisionLog();
    final Map<String, Object?> export = <String, Object?>{
      'game': 'Ten of a Kind Poker',
      'generatedAtLocal': _formatBotLearningTimestamp(DateTime.now().toLocal()),
      'lastTrainingSummary': _lastBotTrainingSummary,
      'decisionLogCount': rows.length,
      'weights': BotLearnedPolicyRegistry.weights.toJson(),
      'seatStates': _botSeatLearningState(),
      'decisionLog': rows
          .map((eng.BotDecisionLogEntry entry) => entry.toJson())
          .toList(growable: false),
    };
    return const JsonEncoder.withIndent('  ').convert(export);
  }

  Future<void> _copyBotLearningSnapshotJson() async {
    if (!AppBuild.current.enableBotTraining) return;
    await Clipboard.setData(
      ClipboardData(text: _botLearningSnapshotJson()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Poker bot learning JSON copied')),
    );
  }

  double _botPolicyAdjustmentMetric(
    BotPolicyAdjustment adjustment,
    String metric,
  ) {
    switch (metric) {
      case 'call':
        return adjustment.callBias;
      case 'raise':
        return adjustment.raiseBias;
      case 'bluff':
        return adjustment.bluffBias;
      case 'value':
        return adjustment.valueBias;
      case 'size':
        return adjustment.sizeFactor - 1.0;
    }
    return 0.0;
  }

  List<MapEntry<String, BotPolicyAdjustment>> _topBotPolicyAdjustments({
    required String metric,
    required bool positive,
    int limit = 4,
    double minMagnitude = 0.003,
  }) {
    final List<MapEntry<String, BotPolicyAdjustment>> entries =
        BotLearnedPolicyRegistry.weights.featureWeights.entries
            .where((MapEntry<String, BotPolicyAdjustment> entry) {
      final double value = _botPolicyAdjustmentMetric(entry.value, metric);
      return positive ? value > minMagnitude : value < -minMagnitude;
    }).toList(growable: false);
    entries.sort((a, b) {
      final double aValue = _botPolicyAdjustmentMetric(a.value, metric);
      final double bValue = _botPolicyAdjustmentMetric(b.value, metric);
      return positive ? bValue.compareTo(aValue) : aValue.compareTo(bValue);
    });
    if (entries.length <= limit) return entries;
    return entries.take(limit).toList(growable: false);
  }

  Widget _botPolicyWeightList({
    required String label,
    required String metric,
    required bool positive,
    required Color accent,
  }) {
    final List<MapEntry<String, BotPolicyAdjustment>> entries =
        _topBotPolicyAdjustments(metric: metric, positive: positive);
    if (entries.isEmpty) {
      return Text(
        '$label: no strong signals yet',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        for (final MapEntry<String, BotPolicyAdjustment> entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '${entry.key}  '
              '(${_botPolicyAdjustmentMetric(entry.value, metric) >= 0 ? '+' : ''}'
              '${_botPolicyAdjustmentMetric(entry.value, metric).toStringAsFixed(2)})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
      ],
    );
  }

  Widget _botPolicySummaryCard({
    required String title,
    required String metric,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0x331C1C1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${BotLearnedPolicyRegistry.weights.featureWeights.length} tracked features',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _botPolicyWeightList(
            label: 'Leaning toward',
            metric: metric,
            positive: true,
            accent: accent,
          ),
          const SizedBox(height: 8),
          _botPolicyWeightList(
            label: 'Leaning away from',
            metric: metric,
            positive: false,
            accent: const Color(0xFFFF8A65),
          ),
        ],
      ),
    );
  }

  Widget _botLearningExportTextCard(String jsonText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0x331C1C1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Selectable Export Text',
            style: TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Select this text directly if you want to paste the learning snapshot outside the app.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 260),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                jsonText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _trainBotLogs(
    List<eng.BotDecisionLogEntry> rows, {
    required String successPrefix,
  }) async {
    final BotLearnedPolicyWeights weights =
        _botLearningService.trainFromLogs(rows);
    BotLearnedPolicyRegistry.setWeights(weights);
    await _botLearningService.saveWeights(weights);
    final String summary =
        '$successPrefix ${rows.length} decisions on ${_formatBotLearningTimestamp(DateTime.now())}.';
    if (!mounted) return;
    setState(() {
      _lastBotTrainingSummary = summary;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(summary)),
    );
  }

  Future<void> _trainCurrentBotLogs() async {
    if (!AppBuild.current.enableBotTraining) return;
    final List<eng.BotDecisionLogEntry> rows = _currentBotDecisionLog();
    if (rows.length < 20) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 20 bot decisions to train poker bots'),
        ),
      );
      return;
    }
    try {
      await _trainBotLogs(
        rows,
        successPrefix: 'Current poker bots trained from',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Poker bot training failed: $error')),
      );
    }
  }

  Future<void> _trainClipboardBotLogs() async {
    if (!AppBuild.current.enableBotTraining) return;
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Clipboard does not contain bot log JSON')),
      );
      return;
    }
    try {
      final List<eng.BotDecisionLogEntry> rows =
          _botLearningService.parseDecisionLogs(text);
      await _trainBotLogs(
        rows,
        successPrefix: 'Clipboard poker bots trained from',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clipboard poker training failed: $error')),
      );
    }
  }

  Future<void> _showBotLearningDialog() async {
    if (!AppBuild.current.enableBotTraining) return;
    if (!mounted) return;
    final List<eng.BotDecisionLogEntry> rows = _currentBotDecisionLog();
    final BotLearnedPolicyWeights weights = BotLearnedPolicyRegistry.weights;
    final String learningJson = _botLearningSnapshotJson(decisionLog: rows);
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final Size screen = MediaQuery.of(context).size;
        final double dialogMaxWidth = math.min(820, screen.width - 24);
        final double dialogMaxHeight = screen.height * 0.88;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: dialogMaxHeight,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xE6101010),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFD54F), width: 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.48),
                    blurRadius: 16,
                    spreadRadius: 1.0,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Center(
                      child: Text(
                        'Bot Learning',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: const Color(0x331C1C1C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Decision log rows: ${rows.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Tracked features: ${weights.featureWeights.length}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Intercept raise bias: ${weights.intercept.raiseBias.toStringAsFixed(3)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if ((_lastBotTrainingSummary ?? '').trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _lastBotTrainingSummary!,
                                style: const TextStyle(
                                  color: Color(0xFFFFF59D),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _botPolicySummaryCard(
                      title: 'Call Bias',
                      metric: 'call',
                      accent: const Color(0xFFFFD54F),
                    ),
                    const SizedBox(height: 10),
                    _botPolicySummaryCard(
                      title: 'Raise Bias',
                      metric: 'raise',
                      accent: const Color(0xFF81D4FA),
                    ),
                    const SizedBox(height: 10),
                    _botPolicySummaryCard(
                      title: 'Bluff Bias',
                      metric: 'bluff',
                      accent: const Color(0xFFFFAB91),
                    ),
                    const SizedBox(height: 10),
                    _botPolicySummaryCard(
                      title: 'Value Bias',
                      metric: 'value',
                      accent: const Color(0xFFA5D6A7),
                    ),
                    const SizedBox(height: 10),
                    _botPolicySummaryCard(
                      title: 'Sizing',
                      metric: 'size',
                      accent: const Color(0xFFE1BEE7),
                    ),
                    const SizedBox(height: 10),
                    _botLearningExportTextCard(learningJson),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        SizedBox(
                          width: 176,
                          child: OutlinedButton(
                            onPressed: _copyBotLearningSnapshotJson,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              backgroundColor: const Color(0xFFFFD54F)
                                  .withValues(alpha: 0.86),
                              side: const BorderSide(
                                color: Color(0xFFFFD54F),
                              ),
                            ),
                            child: const Text('Copy Learning JSON'),
                          ),
                        ),
                        SizedBox(
                          width: 176,
                          child: OutlinedButton(
                            onPressed: _trainCurrentBotLogs,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                            ),
                            child: const Text('Train Current Bots'),
                          ),
                        ),
                        SizedBox(
                          width: 176,
                          child: OutlinedButton(
                            onPressed: _trainClipboardBotLogs,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                            ),
                            child: const Text('Train Clipboard Bots'),
                          ),
                        ),
                        SizedBox(
                          width: 176,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _flashLastAction(String name, String label) {
    if (label.trim().isEmpty) return;
    _actionFlashTimer?.cancel();
    _actionFlashName = name.trim();
    _actionFlashLabel = label.trim();
    _showActionFlash = true;
    if (mounted && !_disposing) setState(() {});
    _actionFlashTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || _disposing) return;
      setState(() => _showActionFlash = false);
    });
  }

  void _triggerRenoirDealOnce() {
    _renoirTimer?.cancel();
    setState(() => _renoirDealing = true);
    _renoirTimer = Timer(_kRenoirDealOn + _kRenoirDealHold, () {
      if (!mounted) return;
      setState(() => _renoirDealing = false);
    });
  }

  void _handleRenoirShuffle() {
    _clearHandRankHighlight();
    _clearActionFlash();
    _dealSfxEnabled = true;
    _handWinSoundPlayed = false;
    if (_handStartQueued) {
      _handStartQueued = false;
      _engine?.startNewHand();
      _kickIfStuck();
    }
  }

  void _cancelBotScheduling({bool clearSeat = true}) {
    _botActionTimer?.cancel();
    _botActionTimer = null;
    _botWatchdogTimer?.cancel();
    _botWatchdogTimer = null;
    if (clearSeat) {
      _lastBotSeat = -1;
    }
  }

  void _queueBotSchedulingPass() {
    Timer.run(() {
      if (!mounted || _matchOver || _paused) return;
      final e = _engine;
      if (e == null) return;
      _scheduleBotActionIfNeeded(e);
    });
  }

  void _armBotWatchdog(int actor) {
    _botWatchdogTimer?.cancel();
    _botWatchdogTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _matchOver || _paused) return;
      final e = _engine;
      if (e == null) return;
      if (!RenoirSignals.canAct.value) return;
      if (e.phase == eng.GamePhase.handOver ||
          e.phase == eng.GamePhase.showdown) {
        _cancelBotScheduling();
        return;
      }
      if (actor < 0 || actor >= e.players.length) {
        _cancelBotScheduling();
        return;
      }
      if (e.actingIndex != actor ||
          actor == _heroIndex ||
          !e.players[actor].isBot) {
        _cancelBotScheduling();
        return;
      }
      _botActionTimer?.cancel();
      _botActionTimer = null;
      _botWatchdogTimer = null;
      e.tickBots(maxSteps: 1);
      _queueBotSchedulingPass();
    });
  }

  void _onCanActChanged() {
    if (!mounted) return;
    if (_paused) return;
    if (!RenoirSignals.canAct.value) {
      _heroTurnChimed = false;
      _cancelBotScheduling();
      _disarmHeroTurnClock();
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
    _armHeroTurnClockIfNeeded();
  }

  void _disarmHeroTurnClock() {
    _stopHeroTurnTicker();
    if (_heroTurnSecondsRemaining != null) {
      _heroTurnSecondsRemaining = null;
      if (mounted && !_disposing) setState(() {});
    }
  }

  bool _heroCanActNow() {
    final e = _engine;
    if (e == null) return false;
    if (_matchOver) return false;
    if (_paused) return false;
    if (!_isHeroTurn) return false;
    if (!RenoirSignals.holeCardsVisible.value) return false;
    if (!RenoirSignals.canAct.value) return false;
    return true;
  }

  bool _shouldDoubleHeroTurnClock() {
    final e = _engine;
    if (e == null || e.players.isEmpty) return false;
    int eliminated = 0;
    for (final p in e.players) {
      if (p.isOut || p.chips <= 0) eliminated++;
    }
    final int total = e.players.length;
    return eliminated >= (total / 2).ceil();
  }

  void _togglePaused() => _setPaused(!_paused);

  void _setPaused(bool value) {
    if (_paused == value) return;
    setState(() => _paused = value);
    if (_paused) {
      _pauseGameplay();
    } else {
      _resumeGameplay();
    }
  }

  void _pauseGameplay() {
    final int? remaining = _heroTurnSecondsRemaining;
    if (remaining != null && remaining > 0) {
      _heroTurnResumeSeconds = remaining;
    }
    _stopHeroTurnTicker(); // keep displayed seconds (frozen)
    _cancelBotScheduling();
    _engineTicker?.cancel();
    _engineTicker = null;
    unawaited(SoundFx.instance.stopAll());
  }

  void _resumeGameplay() {
    if (!mounted || _matchOver) return;
    final e = _engine;
    if (e == null) return;
    _startEngineTicker();
    _scheduleBotActionIfNeeded(e);
    _armHeroTurnClockIfNeeded();
  }

  void _startEngineTicker() {
    // Lightweight engine ticker (drives hand-over flow and schedules bots).
    _engineTicker?.cancel();
    _engineTicker =
        Timer.periodic(Duration(milliseconds: pace.kBotThinkTimeMs), (_) {
      if (!mounted || _matchOver || _paused) return;
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
  }

  void _armHeroTurnClockIfNeeded() {
    if (_paused) {
      _stopHeroTurnTicker();
      return;
    }
    if (!_heroCanActNow()) {
      _heroTurnResumeSeconds = null;
      _disarmHeroTurnClock();
      return;
    }
    if (_heroTurnClockArmed && _heroTurnTimer != null) return;

    _stopHeroTurnTicker();
    final bool resuming = _heroTurnResumeSeconds != null;
    int seconds = _heroTurnResumeSeconds ?? _heroTurnTimeoutSeconds;
    _heroTurnResumeSeconds = null;
    if (!resuming && _shouldDoubleHeroTurnClock()) {
      seconds *= 2;
    }
    if (seconds <= 0) return;

    final int token = ++_heroTurnTimerToken;
    _heroTurnClockArmed = true;
    _heroTurnDeadline = DateTime.now().add(Duration(seconds: seconds));
    _heroTurnSecondsRemaining = seconds;
    setState(() {});

    _heroTurnTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) return;
      if (token != _heroTurnTimerToken) return;
      if (!_heroCanActNow()) {
        _disarmHeroTurnClock();
        return;
      }

      final deadline = _heroTurnDeadline;
      if (deadline == null) {
        _disarmHeroTurnClock();
        return;
      }

      final now = DateTime.now();
      final int remaining = (deadline.difference(now).inMilliseconds / 1000)
          .ceil()
          .clamp(0, seconds);
      if (_heroTurnSecondsRemaining != remaining) {
        setState(() => _heroTurnSecondsRemaining = remaining);
      }
      if (remaining <= 0) {
        _disarmHeroTurnClock();
        if (_heroCanActNow()) _doHeroFold();
      }
    });
  }

  int _computeHeroTurnTimeoutSeconds() {
    const int fallback = 15;
    final String kingdom = (widget.venue?.name ?? '').toString().trim();
    if (kingdom.isEmpty) return fallback;
    if (widget.campaignMainEvent) return 20;

    final group = widget.campaignGroup;
    final int? subIndex = widget.campaignSubKingdomIndex;
    if (group == null || subIndex == null) return fallback;

    final order =
        ce.subKingdomIndicesByPrizePool(group: group, kingdomName: kingdom);
    if (order.isEmpty) return fallback;

    final int count = order.length;
    final int pos = order.indexOf(subIndex);
    final int safePos = pos >= 0 ? pos : (subIndex - 1).clamp(0, count - 1);

    // Base tier by relative prize rank: 0=low, 1=mid, 2=high.
    final int baseTier = (safePos * 3) ~/ count;

    // Small per-kingdom bias so different kingdoms feel faster/slower.
    final int biasSeed =
        ('${group.name}|${kingdom.toLowerCase()}').hashCode.abs();
    final int bias = (biasSeed % 3) - 1; // -1, 0, +1

    final int tier = (baseTier + bias).clamp(0, 2);
    return switch (tier) { 0 => 10, 1 => 15, _ => 20 };
  }

  bool _isFreeSubKingdomTable() {
    if (widget.campaignMainEvent) return false;
    final group = widget.campaignGroup;
    final int? subIndex = widget.campaignSubKingdomIndex;
    final String kingdom = (widget.venue?.name ?? '').toString().trim();
    if (group == null || subIndex == null || kingdom.isEmpty) return false;
    try {
      return ce.freeSubKingdomIndexFor(
            group: group,
            kingdomName: kingdom,
          ) ==
          subIndex;
    } catch (_) {
      return false;
    }
  }

  /* ================================ Lifecycle ============================== */
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(applyGameSystemUi());

    _campaignSpec = () {
      final group = widget.campaignGroup;
      final String kingdom = (widget.venue?.name ?? '').toString().trim();
      if (group == null || kingdom.isEmpty) return null;
      try {
        if (widget.campaignMainEvent) {
          return ce.kingdomMainEventSpec(group: group, kingdomName: kingdom);
        }
        final idx = widget.campaignSubKingdomIndex;
        if (idx != null) {
          return ce.subKingdomEventSpec(
            group: group,
            kingdomName: kingdom,
            subKingdomIndex: idx,
          );
        }
      } catch (_) {}
      return null;
    }();
    _tableMaxSeats = GameScreen.resolvedTableMaxSeats(
      venueMode: widget.venueMode,
      campaignMainEvent: widget.campaignMainEvent,
      isFreeSubKingdom: _isFreeSubKingdomTable(),
      campaignMaxPlayers: _campaignSpec?.maxPlayers,
    );
    _startingStackChips =
        math.max(1, _campaignSpec?.startingStack ?? _kInitialChips);

    final auraService = context.read<AuraPointsService>();
    final profileService = context.read<ProfileService>();
    unawaited(adsService.init());
    _heroAura = _auraFromService(auraService);
    _heroAbout = _aboutFromProfile(profileService);

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
    _heroTurnTimeoutSeconds = _computeHeroTurnTimeoutSeconds();
    seats = _buildTableFromBotPool();
    _bindAuraListener(auraService);
    _bindProfileListener(profileService);
    _botFixedThinkDelays.clear();

    unawaited(_pickSubKingdomWatermarkIfAny());

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(applyGameSystemUi());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_disposing && !_matchOver) {
          _setPaused(true);
        }
        break;
    }
  }

  @override
  void dispose() {
    _disposing = true;
    WidgetsBinding.instance.removeObserver(this);
    _engineTicker?.cancel();
    _renoirTimer?.cancel();
    _clearHandRankHighlight(notify: false);
    _clearActionFlash(notify: false);
    RenoirSignals.canAct.removeListener(_onCanActChanged);
    _disarmHeroTurnClock();
    for (final t in _bustTimers.values) {
      t.cancel();
    }
    _bustTimers.clear();
    _pendingBust.clear();
    for (final t in _actionHintTimers.values) {
      t.cancel();
    }
    _actionHintTimers.clear();
    for (final t in _foldedHoleCardTimers.values) {
      t.cancel();
    }
    _foldedHoleCardTimers.clear();
    _foldedHoleCardsCleared.clear();
    for (final t in _bloodStainTimers.values) {
      t.cancel();
    }
    _bloodStainTimers.clear();
    _activeBloodStains.clear();
    _bustSounded.clear();
    _cancelBoardRevealTimers();
    _cancelBotScheduling();
    _potPulseCtl.dispose();
    unawaited(SoundFx.instance.dispose());
    unawaited(_dealEventCtrl.close());
    go.dismissWelcomeRenoir();
    if (_auraService != null && _auraListener != null) {
      _auraService!.removeListener(_auraListener!);
    }
    if (_profileService != null && _profileListener != null) {
      _profileService!.removeListener(_profileListener!);
    }
    unawaited(applyGameSystemUi());
    super.dispose();
  }

  int _auraFromService(AuraPointsService service) {
    if (!service.isLoaded) return _heroAura;
    return service.totalAura.round().clamp(0, 100);
  }

  String _aboutFromProfile(ProfileService service) {
    final about = (service.about ?? '').trim();
    return about.isNotEmpty ? about : ProfileService.defaultAbout;
  }

  void _bindAuraListener(AuraPointsService service) {
    _auraService = service;
    _auraListener = () {
      final next = _auraFromService(service);
      if (next == _heroAura) return;
      if (!mounted) return;
      setState(() {
        _heroAura = next;
        for (final s in seats) {
          if (s.isHero) {
            s.aura = _heroAura;
            break;
          }
        }
      });
    };
    service.addListener(_auraListener!);
  }

  void _bindProfileListener(ProfileService service) {
    _profileService = service;
    _profileListener = () {
      final next = _aboutFromProfile(service);
      if (next == _heroAbout) return;
      if (!mounted) return;
      setState(() {
        _heroAbout = next;
        for (final s in seats) {
          if (s.isHero) {
            s.about = _heroAbout;
            break;
          }
        }
      });
    };
    service.addListener(_profileListener!);
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
        avatarKey: slug,
        avatarAssetFolder: b.hasAvatar ? 'assets/images/avatars/bots/' : null,
      );
      out.add(s);
    }
    return out;
  }

  List<Seat> _buildTableFromBotPool() {
    final String vname = (widget.venue?.name ?? '').toString();
    final bool indian = _isIndianVenueName(vname);
    final specs = indian ? _indianBotSpecs : _intlBotSpecs;

    // Build full pool with fixed about lines, then shuffle for variety.
    final pool = _seatsFromSpecs(specs, chips: _startingStackChips)
      ..shuffle(_rng);
    final int botsNeeded = math.max(0, _tableMaxSeats - 1);
    final bool isTitleGame =
        (widget.campaignGroup != null) && widget.campaignMainEvent;

    final picked = <Seat>[];
    if (botsNeeded > 0) {
      final int eliteNeeded = isTitleGame ? math.min(3, botsNeeded) : 0;

      // In title games, guarantee at least 3 "super-bots" (aura 99) at the table.
      if (eliteNeeded > 0) {
        final elites = pool
            .where((s) => s.aura >= 99 && !s.busted)
            .toList(growable: false)
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
    // Temperament/skill assignments handled in the engine after seats are added.

    final heroKingdomRaw = vname.trim();
    final heroKingdom = heroKingdomRaw.isNotEmpty
        ? heroKingdomRaw
        : (indian ? 'India' : 'International');

    final hero = Seat(
      name: 'You',
      chips: _startingStackChips,
      startChips: _startingStackChips,
      bet: 0,
      aura: _heroAura,
      isHero: true,
      hole: const [],
      about: _heroAbout,
      kingdom: heroKingdom,
      avatarKey: 'avatar_male',
      avatarAssetFolder: null,
    );

    return <Seat>[picked[0], hero, ...picked.skip(1)];
  }

  /* ============================= Engine wiring ============================ */
  void _initEngineAndStart() {
    final payoutTable = _campaignSpec?.payoutTable;
    final e = eng.GameEngine(
      config: eng.GameConfig(
        smallBlind: 100,
        bigBlind: 200,
        maxPlayers: _tableMaxSeats,
        blindSchedule: eng.BlindSchedule(
          orbitsPerLevel: 2,
          levels: <eng.BlindLevel>[
            eng.BlindLevel(smallBlind: 100, bigBlind: 200),
            eng.BlindLevel(smallBlind: 200, bigBlind: 400),
            eng.BlindLevel(smallBlind: 300, bigBlind: 600),
            eng.BlindLevel(smallBlind: 400, bigBlind: 800),
            eng.BlindLevel(smallBlind: 500, bigBlind: 1000),
          ],
        ),
        payoutTable: payoutTable,
        payoutForRank: (rank) =>
            rank == 1 ? (_campaignSpec?.prizePool ?? 100000) : 0,
      ),
    );
    _engine = e;

    for (int i = 0; i < seats.length && i < _tableMaxSeats; i++) {
      final s = seats[i];
      s.chips = _startingStackChips;
      e.addPlayer(eng.Player(
        id: 'P$i',
        name: s.name,
        chips: s.chips,
        aura: s.aura,
        isBot: !s.isHero,
      ));
    }
    final bool isTitleGame =
        (widget.campaignGroup != null) && widget.campaignMainEvent;
    final int multiplier = _campaignSpec?.kingdomGoldMultiplier ?? 0;
    final bool isHighStake = multiplier >= 6;
    final bool forceChampKiller = widget.campaignMainEvent;
    e.assignBotTraits(
      guaranteeWorldChampKiller: forceChampKiller || isHighStake,
      minAuraForGuarantee: forceChampKiller ? 0 : 85,
      minWorldChampKiller: 2,
    );
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

    _startEngineTicker();
  }

  void _onTournamentEnded(ge.TournamentEnded ev) async {
    if (!mounted) return;
    _matchOver = true;
    _engineTicker?.cancel();
    final bool heroWon = ev.championIndex == _heroIndex;
    _playMatchEndCue(heroWon: heroWon);
    _markCampaignWinIfApplicable(heroWon: heroWon);
    if (heroWon) {
      _heroFinalRank = 1;
      _heroFinalWinnings = ev.prize;
    }
    final int fallbackRank = heroWon
        ? 1
        : (_heroFinalRank ??
            math.max(
              2,
              (_engine?.players
                          .where(
                              (p) => p.chips > 0 && !p.isOut && !p.sittingOut)
                          .length ??
                      1) +
                  1,
            ));
    await _showHeroFinishOverlay(
      rank: fallbackRank,
      winnings: heroWon ? ev.prize : _heroFinalWinnings,
    );
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
        continue;
      }
      if (ev is ge.HandSettled) {
        _clearSeatActions();
        _lastSettledHand = ev.handNumber;
        _scheduleBustsFromSettlement(ev);
        // Keep cards on the table until the winners overlay is shown.
        _cancelBoardRevealTimers();
        _cancelBotScheduling();
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
    for (final idx in hs.bustedThisHand) {
      if (idx < 0 || idx >= (_engine?.players.length ?? 0)) continue;
      final p = _engine!.players[idx];
      if (p.chips > 0) continue;
      if (idx >= 0 && idx < seats.length && seats[idx].busted) {
        continue;
      }

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
    _clearActionFlash();
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
      _flashLastAction(seats[idx].name, label);
    }
    if (ev.type == eng.ActionType.fold) {
      _scheduleFoldedHoleCardClear(idx);
    }
    _actionHintTimers[idx]?.cancel();
    _actionHintTimers.remove(idx);
    if (label.isNotEmpty) {
      _actionHintTimers[idx] = Timer(_kSeatActionPopupLifetime, () {
        _actionHintTimers.remove(idx);
        if (!mounted || idx < 0 || idx >= seats.length) return;
        if (seats[idx].lastAction != label) return;
        setState(() {
          if (seats[idx].lastAction == label) {
            seats[idx].lastAction = '';
          }
        });
      });
    }
    return changed;
  }

  void _scheduleFoldedHoleCardClear(int idx) {
    if (idx < 0 || idx >= seats.length) return;
    if (seats[idx].hole.isEmpty) return;
    if (_foldedHoleCardTimers.containsKey(idx) ||
        _foldedHoleCardsCleared.contains(idx)) {
      return;
    }
    _foldedHoleCardTimers[idx]?.cancel();
    _foldedHoleCardTimers[idx] = Timer(_kFoldedHoleCardFadeDuration, () {
      _foldedHoleCardTimers.remove(idx);
      if (!mounted || idx < 0 || idx >= seats.length) return;
      if (!seats[idx].folded || seats[idx].hole.isEmpty) return;
      setState(() {
        if (seats[idx].folded) {
          seats[idx].hole = const [];
          _foldedHoleCardsCleared.add(idx);
        }
      });
    });
  }

  void _cancelFoldedHoleCardClear(int idx) {
    _foldedHoleCardTimers.remove(idx)?.cancel();
    _foldedHoleCardsCleared.remove(idx);
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
    // Keep a longer rolling tape for the ticker; cap to avoid unbounded growth.
    const int kMaxActions = 20;
    while (next.length > kMaxActions) {
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
    final int idx = ev.playerIndex;
    if (idx >= 0 && idx < seats.length) {
      _pendingBust.remove(idx);
      _bustTimers.remove(idx)?.cancel();
      final int latestChips = (() {
        final e = _engine;
        if (e == null || idx >= e.players.length) return seats[idx].chips;
        return e.players[idx].chips;
      })();
      if (mounted) {
        setState(() {
          seats[idx].chips = latestChips;
          seats[idx].busted = true;
          _activateBloodStain(idx);
        });
      }
    }
    if (ev.playerIndex == _heroIndex) {
      _heroFinalRank = ev.rank;
      _heroFinalWinnings = ev.winnings;
      _heroWasLeader = false;
      _heroInDanger = false;
      _playMatchEndCue(heroWon: ev.rank > 0 && ev.rank <= 3);
    }
  }

  void _playMatchEndCue({required bool heroWon}) {
    if (_matchEndSoundPlayed) return;
    _matchEndSoundPlayed = true;
    unawaited(heroWon
        ? SoundFx.instance.playGameWin()
        : SoundFx.instance.playGameLost());
  }

  Future<void> _showHeroFinishOverlay({
    required int rank,
    required int winnings,
  }) async {
    if (!mounted || _disposing || _heroFinishOverlayShown) return;
    final int idx = _heroIndex;
    if (idx < 0 || idx >= seats.length) return;

    _heroFinishOverlayShown = true;
    _matchOver = true;
    _engineTicker?.cancel();
    _cancelBotScheduling();
    _stopHeroTurnTicker();

    final Seat heroSeat = seats[idx];
    final eng.GameEngine? e = _engine;
    final int finalChips = (e != null && idx < e.players.length)
        ? e.players[idx].chips
        : heroSeat.chips;
    final int totalPlayers =
        (e != null && e.players.isNotEmpty) ? e.players.length : seats.length;
    final int handsPlayed = (e != null && e.handNumber > 0)
        ? e.handNumber
        : math.max(1, _lastSettledHand ?? 1);
    final VenueGroup? campaignGroup = widget.campaignGroup;
    final bool canOfferRewardedAup = campaignGroup != null &&
        !(rank > 0 && rank <= 3) &&
        adsService.rewardedAdsSupported;

    await go.showHeroFinishOverlay(
      context,
      heroSeat: heroSeat,
      rank: rank,
      totalPlayers: totalPlayers,
      handsPlayed: handsPlayed,
      finalChips: finalChips,
      winnings: winnings,
      venueName: (widget.venue?.name ?? '').toString(),
      venueFlagAsset: (widget.venue?.flagAsset ?? '').toString(),
      onBeforeExit: () async {
        await adsService.showMatchEndInterstitial();
        await applyGameSystemUi();
      },
      rewardedAdLabel:
          canOfferRewardedAup ? rewardedAupOfferLabel().toUpperCase() : null,
      rewardedAdUnavailableMessage: rewardedAupUnavailableMessage(),
      onWatchRewardedAd: canOfferRewardedAup
          ? () => tryAwardRewardedAdAup(
                context,
                group: campaignGroup,
              )
          : null,
      onExitToVenue: (widget.campaignGroup != null)
          ? () => Navigator.of(context).maybePop()
          : _exitToVenue,
    );
    if (!mounted) return;
    setState(() {});
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
    if (e.phase == eng.GamePhase.handOver ||
        e.phase == eng.GamePhase.showdown) {
      _cancelBotScheduling();
      return;
    }
    if (_paused) {
      _cancelBotScheduling();
      return;
    }

    if (!RenoirSignals.canAct.value) {
      _cancelBotScheduling();
      return;
    }

    final int actor = e.actingIndex;
    if (actor < 0 || actor >= e.players.length) {
      _cancelBotScheduling();
      return;
    }

    if (actor == _heroIndex || !e.players[actor].isBot) {
      _cancelBotScheduling();
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
    final eng.BotTemperament? temperament = _botTemperamentFor(e, actor);
    delayMs = (delayMs * _temperamentDelayFactor(temperament)).round();
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
    final double jitter = _temperamentJitter(temperament);
    final double noise = (_rng.nextDouble() * 2 - 1) * jitter;
    delayMs = (delayMs * (1 + noise)).round();
    delayMs = delayMs
        .clamp(
          pace.kBotActionMinDelayMs,
          pace.kBotActionAbsoluteMaxDelayMs,
        )
        .toInt();
    _armBotWatchdog(actor);
    _botActionTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) {
        _cancelBotScheduling();
        return;
      }
      final eng.GameEngine? ee = _engine;
      if (ee == null) {
        _cancelBotScheduling();
        return;
      }
      if (!RenoirSignals.canAct.value) {
        _cancelBotScheduling();
        return;
      }
      if (ee.phase == eng.GamePhase.handOver ||
          ee.phase == eng.GamePhase.showdown) {
        _cancelBotScheduling();
        return;
      }
      if (ee.actingIndex != actor ||
          actor == _heroIndex ||
          !ee.players[actor].isBot) {
        _cancelBotScheduling();
        return;
      }
      _botWatchdogTimer?.cancel();
      _botWatchdogTimer = null;
      _botActionTimer = null;
      ee.tickBots(maxSteps: 1);
      _queueBotSchedulingPass();
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

  eng.BotTemperament? _botTemperamentFor(eng.GameEngine e, int seat) {
    if (seat < 0 || seat >= e.players.length) return null;
    return e.players[seat].temperament;
  }

  double _temperamentDelayFactor(eng.BotTemperament? temperament) {
    switch (temperament) {
      case eng.BotTemperament.aggressive:
        return 0.72;
      case eng.BotTemperament.stoic:
        return 1.08;
      case eng.BotTemperament.worldChamp:
        return 1.35;
      default:
        return 1.0;
    }
  }

  double _temperamentJitter(eng.BotTemperament? temperament) {
    switch (temperament) {
      case eng.BotTemperament.aggressive:
        return 0.18; // higher variance
      case eng.BotTemperament.stoic:
        return 0.10; // passive but a bit sticky
      case eng.BotTemperament.worldChamp:
        return 0.05; // very steady
      default:
        return 0.12;
    }
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
      if (e.dealerIndex >= 0) dealerIndex = e.dealerIndex;
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
      final List<GCard> partial = full.take(math.min(2, full.length)).toList();
      if (ep.folded) {
        if (!_foldedHoleCardsCleared.contains(i) &&
            s.hole.isEmpty &&
            partial.isNotEmpty) {
          s.hole = partial;
        }
        _scheduleFoldedHoleCardClear(i);
      } else {
        _cancelFoldedHoleCardClear(i);
      }

      if (showAll && !ep.folded) {
        s.hole = full;
      } else if (_showSeatCards && !ep.folded) {
        s.hole = partial;
      } else if (!ep.folded) {
        s.hole = const [];
      }
    }

    _checkHeroStateCues();

    _forceRiverIfAvailable();

    _scheduleBotActionIfNeeded(e);
    _armHeroTurnClockIfNeeded();

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
  }

  /* ========================== Hand-over / winners ========================= */
  void _onHandOverAndContinue() async {
    final e = _engine;
    if (e == null) return;
    if (_handOverHandled || _heroFinishOverlayShown) return;
    _handOverHandled = true;

    // Clear any in-flight announcer clip before the winner presentation begins.
    await SoundFx.instance.stopAnnouncer();

    // Ensure community cards are visible on the table while the winners overlay
    // is shown, especially for Skip fast-forward paths where Renoir may not
    // receive per-card dealing events.
    final forcedBoard = e.community.map(_mapEngCard).toList(growable: false);
    if (forcedBoard.length > board.length) {
      _cancelBoardRevealTimers();
      setState(() {
        _boardTarget = forcedBoard;
        _boardRevealCount = forcedBoard.length;
        _lastBoardTargetLen = forcedBoard.length;
        board = forcedBoard;
      });
    }
    if (forcedBoard.isNotEmpty) {
      await Future<void>.delayed(
        Duration(milliseconds: pace.kShowdownSettlePauseMs),
      );
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
        showCommunity: boardUi.isNotEmpty,
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

    final int heroIdx = _heroIndex;
    final bool heroOut = heroIdx >= 0 &&
        heroIdx < e.players.length &&
        (e.players[heroIdx].isOut || e.players[heroIdx].chips <= 0);
    if (heroOut) {
      final int aliveAhead = e.players
          .where((p) => p.chips > 0 && !p.isOut && !p.sittingOut)
          .length;
      await _showHeroFinishOverlay(
        rank: _heroFinalRank ?? math.max(2, aliveAhead + 1),
        winnings: _heroFinalWinnings,
      );
      return;
    }

    if (_isMatchOver()) {
      int prize = 0;
      try {
        prize = e.config.payoutForRank?.call(1) ?? 0;
      } catch (_) {}
      _heroFinalRank ??= 1;
      _heroFinalWinnings = math.max(_heroFinalWinnings, prize);
      await _showHeroFinishOverlay(
        rank: _heroFinalRank ?? 1,
        winnings: _heroFinalWinnings,
      );
      return;
    }

    // Reset debug all-in matched state for next hand
    _allInMatched = false;

    _cancelBoardRevealTimers();
    _cancelBotScheduling();
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
    _disarmHeroTurnClock();
    _cancelBotScheduling();
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
    _disarmHeroTurnClock();
    _cancelBotScheduling();
    e.act(eng.ActionType.fold);
  }

  void _doHeroBetOrRaise(int raiseToTotal) {
    final e = _engine;
    if (!_isHeroTurn || e == null) return;
    _disarmHeroTurnClock();
    _cancelBotScheduling();
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
    _disarmHeroTurnClock();
    _cancelBotScheduling();
    e.act(eng.ActionType.allIn);
  }

  /* ============================ UI ======================================= */
  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    final Color bg = _venueColor(venue, 'background', AppColors.black);
    final Color felt = _venueColor(venue, 'felt', const Color(0xFF13321E));
    final String flagPath = (venue?.flagAsset ?? '').toString();
    final String kingdomName = (venue?.name ?? '').toString();
    String venueName = kingdomName;
    final group = widget.campaignGroup;
    final subIdx = widget.campaignSubKingdomIndex;
    if (group != null && subIdx != null && kingdomName.trim().isNotEmpty) {
      venueName = subKingdomDisplayName(
        group: group,
        kingdomName: kingdomName,
        index: subIdx,
      );
    }

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
    final int venueOffset = offsetMinutesForVenue(kingdomName);

    // 🔸 Last-action ticker: show live hero timer while awaiting hero action.
    List<SeatActionSnapshot> tickerActions = _recentActions;
    final bool showHeroTimer =
        _heroTurnSecondsRemaining != null && _heroCanActNow();
    if (showHeroTimer &&
        _heroIndex >= 0 &&
        _heroIndex < seats.length &&
        _heroTurnSecondsRemaining != null) {
      tickerActions = [
        SeatActionSnapshot(
          seatIndex: _heroIndex,
          label: '${_heroTurnSecondsRemaining!}s',
          chips: seats[_heroIndex].chips,
        ),
        ..._recentActions.where((a) => a.seatIndex != _heroIndex),
      ];
    }

    final String renoirNow =
        _renoirDealing ? _renoirDealAsset : _renoirIdleAsset;

    return WillPopScope(
      onWillPop: _handleBackPressed,
      child: GameScreenUI(
        bg: bg,
        venueName: venueName,
        flagPath: flagPath,
        onShowHandExamples: _showHandExamples,
        onShowHandRankings: _showHandRankings,
        onShowBotLearning: _showBotLearningDialog,
        showBotLearning: AppBuild.current.enableBotTraining,
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
        dealerIndex: dealerIndex,
        sbIndex: sbIndex,
        bbIndex: bbIndex,
        heroIndex: _heroIndex,
        recentActions: tickerActions,
        isHeroTurn: isHeroTurn,
        heroTurnSecondsRemaining: _heroTurnSecondsRemaining,
        showHandHighlight: _showHandRankHighlight,
        handHighlightCards: _handRankHighlightCards,
        showActionFlash: _showActionFlash,
        actionFlashName: _actionFlashName,
        actionFlashLabel: _actionFlashLabel,
        paused: _paused,
        onTogglePause: _togglePaused,
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
        startingStack: _startingStackChips,
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

  void _showHandExamples() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final Size size = MediaQuery.of(sheetContext).size;
        final double maxHeight = math.min(size.height * 0.82, 720.0);

        return SafeArea(
          top: false,
          child: SizedBox(
            height: maxHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: const HandExamplesSheet(),
            ),
          ),
        );
      },
    );
  }

  void _showHandRankings() {
    final e = _engine;
    if (e == null) return;
    final heroIdx = _heroIndex;
    if (heroIdx < 0 || heroIdx >= e.players.length) return;

    final heroPlayer = e.players[heroIdx];
    final combined = <eng.Card>[
      ...heroPlayer.hole,
      ...e.community,
    ];
    if (combined.length < 5) {
      _clearHandRankHighlight();
      return;
    }

    eng.HandRank rank;
    try {
      rank = eng.HandEvaluator.evaluate(combined);
    } catch (_) {
      return;
    }
    final best = rank.bestFive
        .map<GCard>((card) => _mapEngCard(card))
        .toList(growable: false);
    if (best.isEmpty) {
      _clearHandRankHighlight();
      return;
    }

    setState(() {
      _handRankHighlightCards = best;
      _showHandRankHighlight = true;
    });
    _handRankHighlightTimer?.cancel();
    _handRankHighlightTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _showHandRankHighlight = false);
    });
  }
}
