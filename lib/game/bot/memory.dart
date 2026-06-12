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

  void observeNewHand() {
    handsSeen += 1;
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
    return value.clamp(0.0, 1.0);
  }

  static double _ratio(int num, int den) {
    if (den <= 0) return 0.5;
    return (num / den).clamp(0.0, 1.0).toDouble();
  }
}

class BotStyleState {
  double aggressionHeat;
  double bluffAppetite;
  double caution;
  double confidence;
  String? revengeTargetId;

  BotStyleState({
    this.aggressionHeat = 0.5,
    this.bluffAppetite = 0.5,
    this.caution = 0.5,
    this.confidence = 0.5,
    this.revengeTargetId,
  });

  void normalize() {
    aggressionHeat = aggressionHeat.clamp(0.0, 1.0).toDouble();
    bluffAppetite = bluffAppetite.clamp(0.0, 1.0).toDouble();
    caution = caution.clamp(0.0, 1.0).toDouble();
    confidence = confidence.clamp(0.0, 1.0).toDouble();
  }

  void decayTowardNeutral([double rate = 0.06]) {
    aggressionHeat = _toward(aggressionHeat, 0.5, rate);
    bluffAppetite = _toward(bluffAppetite, 0.5, rate);
    caution = _toward(caution, 0.5, rate);
    confidence = _toward(confidence, 0.5, rate);
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
      aggressorSolidity:
          (json['aggressorSolidity'] as num?)?.toDouble() ?? 0.5,
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
