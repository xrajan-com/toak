import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One opponent's record against the player: games together, and how many
/// of those the player finished ahead.
@immutable
class RivalRecord {
  final int games;
  final int playerAhead;

  const RivalRecord({required this.games, required this.playerAhead});

  int get opponentAhead => games - playerAhead;

  Map<String, int> toJson() => <String, int>{'g': games, 'w': playerAhead};

  static RivalRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final g = raw['g'];
    final w = raw['w'];
    if (g is! int || w is! int || g <= 0 || w < 0 || w > g) return null;
    return RivalRecord(games: g, playerAhead: w);
  }
}

/// Rivals who remember you: real tables have regulars, so the opponents a
/// player keeps meeting come back, with their head-to-head record.
///
/// Kept on this device only (shared_preferences), keyed by bot name. A game
/// counts once it finishes for the player (they bust or win); leaving early
/// does not count.
class RivalService {
  RivalService({SharedPreferences? prefs}) : _prefs = prefs;

  static final RivalService instance = RivalService();

  static const String _key = 'rivals_v1';

  /// Games together before an opponent counts as a rival.
  static const int minGames = 2;

  /// At most this many rivals are brought back to one table.
  static const int maxRivalsPerTable = 2;

  /// Chance each rival is seated at a new table, so tables still vary.
  static const double seatChance = 0.6;

  SharedPreferences? _prefs;
  Map<String, RivalRecord> _records = <String, RivalRecord>{};
  bool _loaded = false;

  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_key);
      final decoded = raw == null ? null : jsonDecode(raw);
      final out = <String, RivalRecord>{};
      if (decoded is Map) {
        decoded.forEach((name, value) {
          final record = RivalRecord.fromJson(value);
          if (name is String && record != null) out[name] = record;
        });
      }
      _records = out;
    } catch (_) {
      _records = <String, RivalRecord>{};
    }
    _loaded = true;
  }

  RivalRecord? recordFor(String name) => _records[name];

  /// The opponents worth bringing back, most games together first.
  List<String> rivals() {
    final names = _records.entries
        .where((e) => e.value.games >= minGames)
        .toList()
      ..sort((a, b) => b.value.games.compareTo(a.value.games));
    return names.map((e) => e.key).toList(growable: false);
  }

  /// Picks which rivals sit at a new table: up to [maxRivalsPerTable] of
  /// those in [pool], each with [seatChance]. [roll] returns 0..1.
  List<String> rivalsToSeat(Iterable<String> pool, double Function() roll) {
    final available = pool.toSet();
    final out = <String>[];
    for (final name in rivals()) {
      if (out.length >= maxRivalsPerTable) break;
      if (!available.contains(name)) continue;
      if (roll() < seatChance) out.add(name);
    }
    return out;
  }

  /// "Rival · you lead 3-2", or null when [name] is not a rival yet.
  String? noteFor(String name) {
    final r = _records[name];
    if (r == null || r.games < minGames) return null;
    final int you = r.playerAhead;
    final int them = r.opponentAhead;
    if (you > them) return 'Rival · you lead $you-$them';
    if (them > you) return 'Rival · leads you $them-$you';
    return 'Rival · level $you-$them';
  }

  /// Records one finished game: for each opponent, whether the player
  /// finished ahead of them.
  Future<void> recordGame(Map<String, bool> playerAheadOf) async {
    if (playerAheadOf.isEmpty) return;
    playerAheadOf.forEach((name, ahead) {
      final old = _records[name];
      _records[name] = RivalRecord(
        games: (old?.games ?? 0) + 1,
        playerAhead: (old?.playerAhead ?? 0) + (ahead ? 1 : 0),
      );
    });
    // Keep the store small: the 60 opponents met most often.
    if (_records.length > 60) {
      final keep = _records.entries.toList()
        ..sort((a, b) => b.value.games.compareTo(a.value.games));
      _records = Map<String, RivalRecord>.fromEntries(keep.take(60));
    }
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(
        _key,
        jsonEncode(_records.map((k, v) => MapEntry(k, v.toJson()))),
      );
    } catch (_) {
      // A lost record is not worth an error for the player.
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _records = <String, RivalRecord>{};
    _loaded = false;
    _prefs = null;
  }
}
