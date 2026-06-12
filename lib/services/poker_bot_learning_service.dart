import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/game/bot/policy_model.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart'
    show BotDecisionLogEntry, GamePhase;

class PokerBotLearningService {
  static const String _storageKey = 'poker.bot_learning.weights.v1';

  const PokerBotLearningService();

  Future<BotLearnedPolicyWeights?> loadPersistedWeights() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return BotLearnedPolicyWeights.fromJson(
        Map<String, Object?>.from(decoded as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWeights(BotLearnedPolicyWeights weights) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(weights.toJson()));
  }

  Future<void> clearWeights() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  List<BotDecisionLogEntry> parseDecisionLogs(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return const <BotDecisionLogEntry>[];

    final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is List) {
        for (final dynamic item in decoded) {
          if (item is! Map) continue;
          rows.add(item.map<String, Object?>(
            (dynamic key, dynamic value) =>
                MapEntry<String, Object?>(key.toString(), value),
          ));
        }
      } else if (decoded is Map) {
        final dynamic logRows = decoded['decisionLog'] ?? decoded['rows'];
        if (logRows is List) {
          for (final dynamic item in logRows) {
            if (item is! Map) continue;
            rows.add(item.map<String, Object?>(
              (dynamic key, dynamic value) =>
                  MapEntry<String, Object?>(key.toString(), value),
            ));
          }
        }
      }
    } else {
      for (final String line in trimmed.split('\n')) {
        final String candidate = line.trim();
        if (candidate.isEmpty) continue;
        final dynamic decoded = jsonDecode(candidate);
        if (decoded is! Map) continue;
        rows.add(decoded.map<String, Object?>(
          (dynamic key, dynamic value) =>
              MapEntry<String, Object?>(key.toString(), value),
        ));
      }
    }

    return rows.map(BotDecisionLogEntry.fromJson).toList(growable: false);
  }

  BotLearnedPolicyWeights trainFromLogs(
    List<BotDecisionLogEntry> rows, {
    int epochs = 600,
    double learningRate = 0.03,
    double l2 = 0.0008,
  }) {
    if (rows.length < 20) {
      throw ArgumentError('Need at least 20 bot decisions to train weights.');
    }

    final List<Map<String, double>> features =
        rows.map(_featureRow).toList(growable: false);
    final List<double> callTargets =
        rows.map(_targetCallBias).toList(growable: false);
    final List<double> raiseTargets =
        rows.map(_targetRaiseBias).toList(growable: false);
    final List<double> bluffTargets =
        rows.map(_targetBluffBias).toList(growable: false);
    final List<double> valueTargets =
        rows.map(_targetValueBias).toList(growable: false);
    final List<double> sizeTargets = rows
        .map((BotDecisionLogEntry row) => _targetSizeFactor(row) - 1.0)
        .toList(growable: false);

    final Map<String, double> callWeights = _trainLinear(
      features: features,
      targets: callTargets,
      epochs: epochs,
      learningRate: learningRate,
      l2: l2,
    );
    final Map<String, double> raiseWeights = _trainLinear(
      features: features,
      targets: raiseTargets,
      epochs: epochs,
      learningRate: learningRate,
      l2: l2,
    );
    final Map<String, double> bluffWeights = _trainLinear(
      features: features,
      targets: bluffTargets,
      epochs: epochs,
      learningRate: learningRate,
      l2: l2,
    );
    final Map<String, double> valueWeights = _trainLinear(
      features: features,
      targets: valueTargets,
      epochs: epochs,
      learningRate: learningRate,
      l2: l2,
    );
    final Map<String, double> sizeWeights = _trainLinear(
      features: features,
      targets: sizeTargets,
      epochs: epochs,
      learningRate: learningRate,
      l2: l2,
    );

    final Set<String> names = <String>{
      ...callWeights.keys,
      ...raiseWeights.keys,
      ...bluffWeights.keys,
      ...valueWeights.keys,
      ...sizeWeights.keys,
    };
    final Map<String, BotPolicyAdjustment> featureWeights =
        <String, BotPolicyAdjustment>{};
    for (final String name in names.toList()..sort()) {
      if (name == 'bias') continue;
      featureWeights[name] = BotPolicyAdjustment(
        callBias: _round6(callWeights[name] ?? 0.0),
        raiseBias: _round6(raiseWeights[name] ?? 0.0),
        bluffBias: _round6(bluffWeights[name] ?? 0.0),
        valueBias: _round6(valueWeights[name] ?? 0.0),
        sizeFactor: _round6(1.0 + (sizeWeights[name] ?? 0.0)),
      );
    }

    return BotLearnedPolicyWeights(
      version: 1,
      intercept: BotPolicyAdjustment(
        callBias: _round6(callWeights['bias'] ?? 0.0),
        raiseBias: _round6(raiseWeights['bias'] ?? 0.0),
        bluffBias: _round6(bluffWeights['bias'] ?? 0.0),
        valueBias: _round6(valueWeights['bias'] ?? 0.0),
        sizeFactor: _round6(1.0 + (sizeWeights['bias'] ?? 0.0)),
      ),
      featureWeights: featureWeights,
    );
  }

  static double _clamp(double value, double lo, double hi) {
    if (value < lo) return lo;
    if (value > hi) return hi;
    return value;
  }

  static double _round6(double value) {
    return double.parse(value.toStringAsFixed(6));
  }

  Map<String, double> _featureRow(BotDecisionLogEntry row) {
    final int pot = row.pot < 0 ? 0 : row.pot;
    final int toCall = row.toCall < 0 ? 0 : row.toCall;
    final int stack = row.stack < 0 ? 0 : row.stack;
    final int denom = (pot + toCall) <= 0 ? 1 : (pot + toCall);
    final double stackFrac =
        stack <= 0 ? 0.0 : _clamp(toCall / stack, 0.0, 1.0);

    return <String, double>{
      'bias': 1.0,
      'aura_skill': _clamp(row.aura / 100.0, 0.0, 1.0),
      'confidence': _clamp(row.confidence, 0.0, 1.0),
      'strength': _clamp(row.strength, 0.0, 1.0),
      'style_aggression': _clamp(row.aggressionHeat - 0.5, -0.5, 0.5),
      'style_bluff': _clamp(row.bluffAppetite - 0.5, -0.5, 0.5),
      'style_caution': _clamp(row.caution - 0.5, -0.5, 0.5),
      'style_confidence': _clamp(row.styleConfidence - 0.5, -0.5, 0.5),
      'field_fold_rate': _clamp(row.fieldFoldRate - 0.5, -0.5, 0.5),
      'field_aggression': _clamp(row.fieldAggression - 0.5, -0.5, 0.5),
      'aggressor_aggression': _clamp(row.aggressorAggression - 0.5, -0.5, 0.5),
      'aggressor_solidity': _clamp(row.aggressorSolidity - 0.5, -0.5, 0.5),
      'pot_odds': _clamp(toCall / denom, 0.0, 1.0),
      'stack_frac': stackFrac,
      'live_opponents': _clamp(row.liveOpponents / 8.0, 0.0, 1.0),
      'has_to_call': row.hasToCall ? 1.0 : 0.0,
      'multiway': row.multiway ? 1.0 : 0.0,
      'facing_all_in': row.facingAllIn ? 1.0 : 0.0,
      'revenge_spot': row.revengeSpot ? 1.0 : 0.0,
      'phase_preflop': row.phase == GamePhase.preflop ? 1.0 : 0.0,
      'phase_flop': row.phase == GamePhase.flop ? 1.0 : 0.0,
      'phase_turn': row.phase == GamePhase.turn ? 1.0 : 0.0,
      'phase_river': row.phase == GamePhase.river ? 1.0 : 0.0,
      'temper_aggressive': row.temperament?.name == 'aggressive' ? 1.0 : 0.0,
      'temper_stoic': row.temperament?.name == 'stoic' ? 1.0 : 0.0,
      'temper_worldchamp': row.temperament?.name == 'worldChamp' ? 1.0 : 0.0,
      'skill_killer': row.skill?.name == 'killer' ? 1.0 : 0.0,
      'skill_fluke': row.skill?.name == 'fluke' ? 1.0 : 0.0,
    };
  }

  double _targetCallBias(BotDecisionLogEntry row) {
    if (!row.hasToCall) return 0.0;
    final String action = row.action.name;
    if (action == 'fold') return -1.0;
    if (_continueActions.contains(action)) return 1.0;
    return 0.2;
  }

  double _targetRaiseBias(BotDecisionLogEntry row) {
    final String action = row.action.name;
    if (_aggressiveActions.contains(action)) return 1.0;
    if (action == 'call' || action == 'check') return -0.35;
    return -0.6;
  }

  double _targetBluffBias(BotDecisionLogEntry row) {
    final String action = row.action.name;
    final bool weak = row.strength < 0.46 && row.confidence < 0.76;
    if (!weak) return 0.0;
    if (_aggressiveActions.contains(action)) return 1.0;
    if (action == 'check' || action == 'fold') return -1.0;
    return -0.4;
  }

  double _targetValueBias(BotDecisionLogEntry row) {
    final String action = row.action.name;
    final bool strong = row.strength >= 0.60;
    if (!strong) return 0.0;
    if (_aggressiveActions.contains(action)) return 1.0;
    if (action == 'call' || action == 'check') return -0.6;
    return -1.0;
  }

  double _targetSizeFactor(BotDecisionLogEntry row) {
    final String action = row.action.name;
    if (!_aggressiveActions.contains(action)) return 1.0;
    final int pot = row.pot <= 0 ? 1 : row.pot;
    final int toAmount = row.toAmount <= 0 ? 0 : row.toAmount;
    if (toAmount <= 0) return 1.0;
    return _clamp(toAmount / pot, 0.75, 1.30);
  }

  Map<String, double> _trainLinear({
    required List<Map<String, double>> features,
    required List<double> targets,
    required int epochs,
    required double learningRate,
    required double l2,
  }) {
    final List<String> names = features.first.keys.toList()..sort();
    final Map<String, double> weights = <String, double>{
      for (final String name in names) name: 0.0,
    };

    for (int epoch = 0; epoch < epochs; epoch += 1) {
      final Map<String, double> grads = <String, double>{
        for (final String name in names) name: 0.0,
      };
      final int count = features.isEmpty ? 1 : features.length;
      for (int index = 0; index < features.length; index += 1) {
        final Map<String, double> row = features[index];
        final double target = targets[index];
        double prediction = 0.0;
        for (final String name in names) {
          prediction += (weights[name] ?? 0.0) * (row[name] ?? 0.0);
        }
        final double error = prediction - target;
        for (final String name in names) {
          grads[name] = (grads[name] ?? 0.0) + error * (row[name] ?? 0.0);
        }
      }
      for (final String name in names) {
        final double gradient =
            ((grads[name] ?? 0.0) / count) + ((weights[name] ?? 0.0) * l2);
        weights[name] = (weights[name] ?? 0.0) - (learningRate * gradient);
      }
    }
    return weights;
  }
}

const Set<String> _aggressiveActions = <String>{'bet', 'raise', 'allIn'};
const Set<String> _continueActions = <String>{'call', 'raise', 'allIn'};
