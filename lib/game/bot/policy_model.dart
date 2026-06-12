import 'package:ten_of_a_kind_poker/game/core.dart' show GamePhase;
import 'package:ten_of_a_kind_poker/game/models.dart'
    show BotSkill, BotTemperament;

class BotPolicyFeatures {
  final GamePhase phase;
  final BotTemperament temperament;
  final BotSkill skill;
  final double auraSkill;
  final double winProb;
  final double baseEquity;
  final double confidence;
  final double strength;
  final double styleAggression;
  final double styleBluff;
  final double styleCaution;
  final double styleConfidence;
  final double fieldFoldRate;
  final double fieldAggression;
  final double aggressorAggression;
  final double aggressorSolidity;
  final bool hasToCall;
  final bool multiway;
  final bool facingAllIn;
  final bool revengeSpot;

  const BotPolicyFeatures({
    required this.phase,
    required this.temperament,
    required this.skill,
    required this.auraSkill,
    required this.winProb,
    required this.baseEquity,
    required this.confidence,
    required this.strength,
    required this.styleAggression,
    required this.styleBluff,
    required this.styleCaution,
    required this.styleConfidence,
    required this.fieldFoldRate,
    required this.fieldAggression,
    required this.aggressorAggression,
    required this.aggressorSolidity,
    required this.hasToCall,
    required this.multiway,
    required this.facingAllIn,
    required this.revengeSpot,
  });

  Map<String, double> toNumericFeatureMap() {
    return <String, double>{
      'aura_skill': auraSkill,
      'win_prob': winProb,
      'base_equity': baseEquity,
      'win_edge': winProb - baseEquity,
      'confidence': confidence,
      'strength': strength,
      'style_aggression': styleAggression,
      'style_bluff': styleBluff,
      'style_caution': styleCaution,
      'style_confidence': styleConfidence,
      'field_fold_rate': fieldFoldRate - 0.5,
      'field_aggression': fieldAggression - 0.5,
      'aggressor_aggression': aggressorAggression - 0.5,
      'aggressor_solidity': aggressorSolidity - 0.5,
      'has_to_call': hasToCall ? 1.0 : 0.0,
      'multiway': multiway ? 1.0 : 0.0,
      'facing_all_in': facingAllIn ? 1.0 : 0.0,
      'revenge_spot': revengeSpot ? 1.0 : 0.0,
      'phase_preflop': phase == GamePhase.preflop ? 1.0 : 0.0,
      'phase_flop': phase == GamePhase.flop ? 1.0 : 0.0,
      'phase_turn': phase == GamePhase.turn ? 1.0 : 0.0,
      'phase_river': phase == GamePhase.river ? 1.0 : 0.0,
      'temper_aggressive': temperament == BotTemperament.aggressive ? 1.0 : 0.0,
      'temper_stoic': temperament == BotTemperament.stoic ? 1.0 : 0.0,
      'temper_worldchamp':
          temperament == BotTemperament.worldChamp ? 1.0 : 0.0,
      'skill_killer': skill == BotSkill.killer ? 1.0 : 0.0,
      'skill_fluke': skill == BotSkill.fluke ? 1.0 : 0.0,
    };
  }
}

class BotPolicyAdjustment {
  final double callBias;
  final double raiseBias;
  final double bluffBias;
  final double valueBias;
  final double sizeFactor;

  const BotPolicyAdjustment({
    required this.callBias,
    required this.raiseBias,
    required this.bluffBias,
    required this.valueBias,
    required this.sizeFactor,
  });

  static const neutral = BotPolicyAdjustment(
    callBias: 0.0,
    raiseBias: 0.0,
    bluffBias: 0.0,
    valueBias: 0.0,
    sizeFactor: 1.0,
  );

  BotPolicyAdjustment plus(BotPolicyAdjustment other) {
    return BotPolicyAdjustment(
      callBias: callBias + other.callBias,
      raiseBias: raiseBias + other.raiseBias,
      bluffBias: bluffBias + other.bluffBias,
      valueBias: valueBias + other.valueBias,
      sizeFactor: sizeFactor * other.sizeFactor,
    );
  }

  BotPolicyAdjustment scale(double factor) {
    return BotPolicyAdjustment(
      callBias: callBias * factor,
      raiseBias: raiseBias * factor,
      bluffBias: bluffBias * factor,
      valueBias: valueBias * factor,
      sizeFactor: 1.0 + ((sizeFactor - 1.0) * factor),
    );
  }

  Map<String, double> toJson() {
    return <String, double>{
      'callBias': callBias,
      'raiseBias': raiseBias,
      'bluffBias': bluffBias,
      'valueBias': valueBias,
      'sizeFactor': sizeFactor,
    };
  }

  factory BotPolicyAdjustment.fromJson(Map<String, Object?> json) {
    return BotPolicyAdjustment(
      callBias: (json['callBias'] as num?)?.toDouble() ?? 0.0,
      raiseBias: (json['raiseBias'] as num?)?.toDouble() ?? 0.0,
      bluffBias: (json['bluffBias'] as num?)?.toDouble() ?? 0.0,
      valueBias: (json['valueBias'] as num?)?.toDouble() ?? 0.0,
      sizeFactor: (json['sizeFactor'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class BotLearnedPolicyWeights {
  final int version;
  final BotPolicyAdjustment intercept;
  final Map<String, BotPolicyAdjustment> featureWeights;

  const BotLearnedPolicyWeights({
    required this.version,
    required this.intercept,
    required this.featureWeights,
  });

  factory BotLearnedPolicyWeights.empty() {
    return const BotLearnedPolicyWeights(
      version: 1,
      intercept: BotPolicyAdjustment.neutral,
      featureWeights: <String, BotPolicyAdjustment>{},
    );
  }

  BotPolicyAdjustment evaluate(Map<String, double> features) {
    double callBias = intercept.callBias;
    double raiseBias = intercept.raiseBias;
    double bluffBias = intercept.bluffBias;
    double valueBias = intercept.valueBias;
    double sizeFactor = intercept.sizeFactor;

    for (final entry in featureWeights.entries) {
      final value = features[entry.key];
      if (value == null || value == 0.0) continue;
      final weight = entry.value;
      callBias += weight.callBias * value;
      raiseBias += weight.raiseBias * value;
      bluffBias += weight.bluffBias * value;
      valueBias += weight.valueBias * value;
      sizeFactor += (weight.sizeFactor - 1.0) * value;
    }

    return BotPolicyAdjustment(
      callBias: callBias.clamp(-0.35, 0.35).toDouble(),
      raiseBias: raiseBias.clamp(-0.35, 0.35).toDouble(),
      bluffBias: bluffBias.clamp(-0.40, 0.40).toDouble(),
      valueBias: valueBias.clamp(-0.35, 0.35).toDouble(),
      sizeFactor: sizeFactor.clamp(0.70, 1.35).toDouble(),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': version,
      'intercept': intercept.toJson(),
      'featureWeights': featureWeights.map(
        (key, value) => MapEntry<String, Object?>(key, value.toJson()),
      ),
    };
  }

  factory BotLearnedPolicyWeights.fromJson(Map<String, Object?> json) {
    final featureWeightsJson =
        (json['featureWeights'] as Map<Object?, Object?>?) ?? const {};
    final mapped = <String, BotPolicyAdjustment>{};
    for (final entry in featureWeightsJson.entries) {
      final key = entry.key?.toString();
      final value = entry.value;
      if (key == null || value is! Map) continue;
      mapped[key] = BotPolicyAdjustment.fromJson(
        value.map<String, Object?>(
          (dynamic k, dynamic v) => MapEntry<String, Object?>(k.toString(), v),
        ),
      );
    }
    return BotLearnedPolicyWeights(
      version: (json['version'] as num?)?.toInt() ?? 1,
      intercept: json['intercept'] is Map
          ? BotPolicyAdjustment.fromJson(
              (json['intercept'] as Map).map<String, Object?>(
                (dynamic k, dynamic v) =>
                    MapEntry<String, Object?>(k.toString(), v),
              ),
            )
          : BotPolicyAdjustment.neutral,
      featureWeights: mapped,
    );
  }
}

class BotLearnedPolicyRegistry {
  static BotLearnedPolicyWeights _weights = BotLearnedPolicyWeights.empty();

  static BotLearnedPolicyWeights get weights => _weights;

  static void setWeights(BotLearnedPolicyWeights weights) {
    _weights = weights;
  }

  static void reset() {
    _weights = BotLearnedPolicyWeights.empty();
  }
}

abstract class BotPolicyModel {
  const BotPolicyModel();

  BotPolicyAdjustment evaluate(BotPolicyFeatures features);
}

class ExperimentalImitationPolicyModel extends BotPolicyModel {
  const ExperimentalImitationPolicyModel();

  @override
  BotPolicyAdjustment evaluate(BotPolicyFeatures f) {
    double callBias = 0.0;
    double raiseBias = 0.0;
    double bluffBias = 0.0;
    double valueBias = 0.0;
    double sizeFactor = 1.0;

    final double winEdge = f.winProb - f.baseEquity;

    callBias += f.styleConfidence * 0.22;
    callBias -= f.styleCaution * 0.28;
    callBias += (f.aggressorAggression - 0.5) * 0.18;
    callBias -= (f.aggressorSolidity - 0.5) * 0.22;
    if (f.revengeSpot) callBias += 0.06;
    if (f.facingAllIn) callBias -= 0.08;

    raiseBias += f.styleAggression * 0.26;
    raiseBias += f.styleConfidence * 0.10;
    raiseBias -= f.styleCaution * 0.16;
    raiseBias += (f.fieldFoldRate - 0.5) * 0.18;
    raiseBias += winEdge * 0.20;
    if (f.multiway) raiseBias -= 0.06;
    if (f.revengeSpot) raiseBias += 0.04;

    bluffBias += f.styleBluff * 0.34;
    bluffBias += f.styleAggression * 0.12;
    bluffBias -= f.styleCaution * 0.24;
    bluffBias += (f.fieldFoldRate - 0.5) * 0.32;
    bluffBias -= (f.fieldAggression - 0.5) * 0.16;
    bluffBias -= (f.aggressorSolidity - 0.5) * 0.14;
    if (f.revengeSpot) bluffBias += 0.06;
    if (f.multiway) bluffBias -= 0.10;
    if (f.facingAllIn) bluffBias -= 0.18;
    if (f.phase == GamePhase.river) bluffBias += 0.03;

    valueBias += winEdge * 0.24;
    valueBias += (f.strength - 0.5) * 0.22;
    valueBias += f.styleConfidence * 0.08;
    valueBias -= f.styleCaution * 0.10;
    valueBias -= (f.fieldAggression - 0.5) * 0.06;
    if (f.skill == BotSkill.killer) valueBias += 0.03;

    sizeFactor += f.styleAggression * 0.20;
    sizeFactor += f.styleBluff * 0.08;
    sizeFactor += (f.fieldFoldRate - 0.5) * 0.14;
    sizeFactor -= f.styleCaution * 0.08;
    if (f.multiway) sizeFactor -= 0.05;
    if (f.temperament == BotTemperament.aggressive) sizeFactor += 0.08;
    if (f.temperament == BotTemperament.stoic) sizeFactor -= 0.06;

    final base = BotPolicyAdjustment(
      callBias: callBias.clamp(-0.25, 0.25).toDouble(),
      raiseBias: raiseBias.clamp(-0.30, 0.30).toDouble(),
      bluffBias: bluffBias.clamp(-0.35, 0.35).toDouble(),
      valueBias: valueBias.clamp(-0.25, 0.25).toDouble(),
      sizeFactor: sizeFactor.clamp(0.75, 1.30).toDouble(),
    );
    final learned =
        BotLearnedPolicyRegistry.weights.evaluate(f.toNumericFeatureMap());
    return base.plus(learned).scale(1.0);
  }
}

const BotPolicyModel kExperimentalBotPolicyModel =
    ExperimentalImitationPolicyModel();
