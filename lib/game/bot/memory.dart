import 'package:ten_of_a_kind_poker/game/core.dart' show ActionType, GamePhase;
import 'package:ten_of_a_kind_poker/game/models.dart'
    show BotSkill, BotTemperament;

class BotOpponentMemory {
  int handsSeen = 0;
  int vpipHands = 0;
  int preflopRaiseHands = 0;
  int flopCBetOpportunities = 0;
  int flopCBetCount = 0;
  int turnBarrelOpportunities = 0;
  int turnBarrelCount = 0;
  int facedBetSpots = 0;
  int foldToBetCount = 0;
  int facedRaiseSpots = 0;
  int foldToRaiseCount = 0;
  int riverActionOpportunities = 0;
  int riverAggressionCount = 0;
  int showdowns = 0;
  double showdownStrengthTotal = 0.0;
  int aggressiveActions = 0;
  int largePressureActions = 0;
  int allInActions = 0;
  double aggressionHeat = 0.0;
  double pressureHeat = 0.0;

  void observeNewHand() {
    handsSeen += 1;
    // Recent pressure matters much more than ancient table history. A player
    // who stops shoving will gradually regain credit.
    aggressionHeat *= 0.84;
    pressureHeat *= 0.78;
  }

  void observeAggression({
    required bool largePressure,
    required bool allIn,
  }) {
    aggressiveActions += 1;
    if (largePressure) largePressureActions += 1;
    if (allIn) allInActions += 1;

    aggressionHeat += largePressure ? 0.18 : 0.10;
    pressureHeat += largePressure ? 0.25 : 0.03;
    if (allIn) {
      aggressionHeat += 0.10;
      pressureHeat += 0.17;
    }
    aggressionHeat = aggressionHeat.clamp(0.0, 1.0).toDouble();
    pressureHeat = pressureHeat.clamp(0.0, 1.0).toDouble();
  }

  double get vpip => _ratio(vpipHands, handsSeen);
  double get pfr => _ratio(preflopRaiseHands, handsSeen);
  double get flopCBet => _ratio(flopCBetCount, flopCBetOpportunities);
  double get turnBarrel => _ratio(turnBarrelCount, turnBarrelOpportunities);
  double get foldToBet => _ratio(foldToBetCount, facedBetSpots);
  double get foldToRaise => _ratio(foldToRaiseCount, facedRaiseSpots);
  double get riverAggression =>
      _ratio(riverAggressionCount, riverActionOpportunities);
  double get showdownStrength => showdowns <= 0
      ? 0.5
      : (showdownStrengthTotal / showdowns).clamp(0.0, 1.0).toDouble();

  double get foldPressure => ((foldToBet + foldToRaise) / 2).clamp(0.0, 1.0);

  double get aggressionIndex {
    final double value = vpip * 0.16 +
        pfr * 0.24 +
        flopCBet * 0.20 +
        turnBarrel * 0.16 +
        riverAggression * 0.24;
    final double observed = value.clamp(0.0, 1.0).toDouble();
    return observed >= aggressionHeat ? observed : aggressionHeat;
  }

  bool get appliesRepeatPressure {
    final bool repeatedLargePressure =
        largePressureActions >= 2 && pressureHeat >= 0.42;
    final bool repeatedOrdinaryPressure =
        aggressiveActions >= 3 && aggressionHeat >= 0.24;
    return repeatedLargePressure || repeatedOrdinaryPressure;
  }

  static double _ratio(int num, int den) {
    if (den <= 0) return 0.5;
    return (num / den).clamp(0.0, 1.0).toDouble();
  }
}

/// A player-readable summary of where a bot's head is at right now.
/// Ordered fear -> greed. Exposed so the table UI can show the mood as a
/// tell the human player can actually read and exploit.
enum BotMood { rattled, cagey, steady, runningHot, steaming }

extension BotMoodLabel on BotMood {
  /// Short label for the table. Deliberately poker-native language rather
  /// than a number — "Steaming" is a read, "0.83" is a debug value.
  String get label => switch (this) {
        BotMood.rattled => 'Rattled',
        BotMood.cagey => 'Cagey',
        BotMood.steady => 'Steady',
        BotMood.runningHot => 'Running hot',
        BotMood.steaming => 'Steaming',
      };

  /// True when the mood is far enough from neutral to be worth showing.
  /// A table where every bot wears a permanent badge is noise; a badge
  /// that appears when someone actually tilts is information.
  bool get isNotable => this != BotMood.steady;
}

class BotStyleState {
  double aggressionHeat;
  double bluffAppetite;
  double caution;
  double confidence;

  /// The single directional risk axis: 0.0 = maximum fear (scared money,
  /// folding everything, no bluffs), 0.5 = neutral, 1.0 = maximum greed
  /// (gambling, bluffing, calling light).
  ///
  /// This is the "which way is this bot currently leaning" term. Aura is
  /// the orthogonal axis: it governs the *spread* of per-decision noise,
  /// and here it governs how violently and how durably this mood moves.
  /// Together: `action = correct + fearGreed offset + aura-scaled noise`.
  ///
  /// The legacy four dials above are kept because bet sizing and several
  /// heuristics still read them; this axis is what carries the directional
  /// weight in decisions. See docs/BOT_HUMAN_INTELLIGENCE_AURA_SPEC.md.
  double fearGreed;

  String? revengeTargetId;

  BotStyleState({
    this.aggressionHeat = 0.5,
    this.bluffAppetite = 0.5,
    this.caution = 0.5,
    this.confidence = 0.5,
    this.fearGreed = 0.5,
    this.revengeTargetId,
  });

  /// -1.0 (maximum fear) .. +1.0 (maximum greed). The form decision code
  /// wants, so call sites don't each re-center around 0.5.
  double get fearGreedSigned =>
      ((fearGreed - 0.5) * 2.0).clamp(-1.0, 1.0).toDouble();

  BotMood get mood {
    if (fearGreed >= 0.78) return BotMood.steaming;
    if (fearGreed >= 0.62) return BotMood.runningHot;
    if (fearGreed > 0.38) return BotMood.steady;
    if (fearGreed > 0.22) return BotMood.cagey;
    return BotMood.rattled;
  }

  /// The mood label to show the player, or null when the bot is close
  /// enough to neutral that showing anything would just be wallpaper.
  /// Returned as a plain String so UI code needs no extension import.
  String? get notableMoodLabel {
    final BotMood m = mood;
    return m.isNotable ? m.label : null;
  }

  /// How hard this bot's mood swings per event. A low-aura bot is
  /// emotionally loud — one big pot genuinely changes how they play. A
  /// high-aura bot barely registers it. This is what makes aura mean
  /// "emotional control across a session" and not just "noisy per hand".
  static double volatilityForAura(double auraSkill) =>
      (1.60 - 1.20 * auraSkill.clamp(0.0, 1.0)).clamp(0.40, 1.60).toDouble();

  /// How fast the mood returns to neutral, per hand. A pro shakes off a
  /// bad beat in roughly ten hands; a low-aura player is still rattled
  /// thirty-plus hands later, which for a typical session means they
  /// never fully reset. Deliberately much slower than the legacy 0.06
  /// dials, whose swings washed out before the next orbit.
  static double decayForAura(double auraSkill) =>
      (0.020 + 0.050 * auraSkill.clamp(0.0, 1.0))
          .clamp(0.020, 0.070)
          .toDouble();

  /// Applies a mood swing, scaled by this bot's emotional volatility.
  /// [delta] is expressed on the neutral-0.5 scale (so +0.20 is a large
  /// lurch toward greed before volatility is applied).
  void applyFearGreed(double delta, double auraSkill) {
    fearGreed =
        (fearGreed + delta * volatilityForAura(auraSkill))
            .clamp(0.0, 1.0)
            .toDouble();
  }

  void normalize() {
    aggressionHeat = aggressionHeat.clamp(0.0, 1.0).toDouble();
    bluffAppetite = bluffAppetite.clamp(0.0, 1.0).toDouble();
    caution = caution.clamp(0.0, 1.0).toDouble();
    confidence = confidence.clamp(0.0, 1.0).toDouble();
    fearGreed = fearGreed.clamp(0.0, 1.0).toDouble();
  }

  /// [auraSkill] governs only the fearGreed decay; the legacy dials keep
  /// their original flat rate so existing behaviour is unchanged.
  void decayTowardNeutral([double rate = 0.06, double auraSkill = 0.5]) {
    aggressionHeat = _toward(aggressionHeat, 0.5, rate);
    bluffAppetite = _toward(bluffAppetite, 0.5, rate);
    caution = _toward(caution, 0.5, rate);
    confidence = _toward(confidence, 0.5, rate);
    fearGreed = _toward(fearGreed, 0.5, decayForAura(auraSkill));
    normalize();
  }

  static double _toward(double current, double target, double rate) {
    return current + ((target - current) * rate);
  }
}

class BotHandTracker {
  bool sawVpip = false;
  bool sawPreflopRaise = false;
  bool sawFlopCBetOpportunity = false;
  bool sawFlopCBet = false;
  bool sawTurnBarrelOpportunity = false;
  bool sawTurnBarrel = false;
  bool sawFacedBet = false;
  bool sawFacedRaise = false;
  bool sawFoldToBet = false;
  bool sawFoldToRaise = false;
  bool sawRiverActionOpportunity = false;
  bool sawRiverAggression = false;
}

class BotDecisionLogEntry {
  final int handNumber;
  final int seat;
  final String playerId;
  final String playerName;
  final GamePhase phase;
  final BotTemperament? temperament;
  final BotSkill? skill;
  final int aura;
  final int pot;
  final int currentBet;
  final int toCall;
  final int stack;
  final int liveOpponents;
  final bool hasToCall;
  final bool multiway;
  final bool facingAllIn;
  final bool revengeSpot;
  final double fieldFoldRate;
  final double fieldAggression;
  final double aggressorAggression;
  final double aggressorSolidity;
  final ActionType action;
  final int toAmount;
  final double confidence;
  final double strength;
  final double aggressionHeat;
  final double bluffAppetite;
  final double caution;
  final double styleConfidence;

  const BotDecisionLogEntry({
    required this.handNumber,
    required this.seat,
    required this.playerId,
    required this.playerName,
    required this.phase,
    required this.temperament,
    required this.skill,
    required this.aura,
    required this.pot,
    required this.currentBet,
    required this.toCall,
    required this.stack,
    required this.liveOpponents,
    required this.hasToCall,
    required this.multiway,
    required this.facingAllIn,
    required this.revengeSpot,
    required this.fieldFoldRate,
    required this.fieldAggression,
    required this.aggressorAggression,
    required this.aggressorSolidity,
    required this.action,
    required this.toAmount,
    required this.confidence,
    required this.strength,
    required this.aggressionHeat,
    required this.bluffAppetite,
    required this.caution,
    required this.styleConfidence,
  });

  Map<String, Object?> toJson() {
    return {
      'handNumber': handNumber,
      'seat': seat,
      'playerId': playerId,
      'playerName': playerName,
      'phase': phase.name,
      'temperament': temperament?.name,
      'skill': skill?.name,
      'aura': aura,
      'pot': pot,
      'currentBet': currentBet,
      'toCall': toCall,
      'stack': stack,
      'liveOpponents': liveOpponents,
      'hasToCall': hasToCall,
      'multiway': multiway,
      'facingAllIn': facingAllIn,
      'revengeSpot': revengeSpot,
      'fieldFoldRate': fieldFoldRate,
      'fieldAggression': fieldAggression,
      'aggressorAggression': aggressorAggression,
      'aggressorSolidity': aggressorSolidity,
      'action': action.name,
      'toAmount': toAmount,
      'confidence': confidence,
      'strength': strength,
      'aggressionHeat': aggressionHeat,
      'bluffAppetite': bluffAppetite,
      'caution': caution,
      'styleConfidence': styleConfidence,
    };
  }

  factory BotDecisionLogEntry.fromJson(Map<String, Object?> json) {
    return BotDecisionLogEntry(
      handNumber: (json['handNumber'] as num?)?.toInt() ?? 0,
      seat: (json['seat'] as num?)?.toInt() ?? 0,
      playerId: (json['playerId'] ?? '').toString(),
      playerName: (json['playerName'] ?? '').toString(),
      phase: GamePhase.values.firstWhere(
        (value) => value.name == json['phase'],
        orElse: () => GamePhase.predeal,
      ),
      temperament: _temperamentFromJson(json['temperament']),
      skill: _skillFromJson(json['skill']),
      aura: (json['aura'] as num?)?.toInt() ?? 60,
      pot: (json['pot'] as num?)?.toInt() ?? 0,
      currentBet: (json['currentBet'] as num?)?.toInt() ?? 0,
      toCall: (json['toCall'] as num?)?.toInt() ?? 0,
      stack: (json['stack'] as num?)?.toInt() ?? 0,
      liveOpponents: (json['liveOpponents'] as num?)?.toInt() ?? 0,
      hasToCall: json['hasToCall'] == true,
      multiway: json['multiway'] == true,
      facingAllIn: json['facingAllIn'] == true,
      revengeSpot: json['revengeSpot'] == true,
      fieldFoldRate: (json['fieldFoldRate'] as num?)?.toDouble() ?? 0.5,
      fieldAggression: (json['fieldAggression'] as num?)?.toDouble() ?? 0.5,
      aggressorAggression:
          (json['aggressorAggression'] as num?)?.toDouble() ?? 0.5,
      aggressorSolidity: (json['aggressorSolidity'] as num?)?.toDouble() ?? 0.5,
      action: ActionType.values.firstWhere(
        (value) => value.name == json['action'],
        orElse: () => ActionType.check,
      ),
      toAmount: (json['toAmount'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      strength: (json['strength'] as num?)?.toDouble() ?? 0.5,
      aggressionHeat: (json['aggressionHeat'] as num?)?.toDouble() ?? 0.5,
      bluffAppetite: (json['bluffAppetite'] as num?)?.toDouble() ?? 0.5,
      caution: (json['caution'] as num?)?.toDouble() ?? 0.5,
      styleConfidence: (json['styleConfidence'] as num?)?.toDouble() ?? 0.5,
    );
  }

  static BotTemperament? _temperamentFromJson(Object? value) {
    if (value == null) return null;
    for (final candidate in BotTemperament.values) {
      if (candidate.name == value) return candidate;
    }
    return null;
  }

  static BotSkill? _skillFromJson(Object? value) {
    if (value == null) return null;
    for (final candidate in BotSkill.values) {
      if (candidate.name == value) return candidate;
    }
    return null;
  }
}
