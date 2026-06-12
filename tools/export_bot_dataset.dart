import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final int hands = int.parse(options['hands'] ?? '1500');
  final int players = int.parse(options['players'] ?? '6');
  final int stack = int.parse(options['stack'] ?? '12000');
  final int seed = int.parse(options['seed'] ?? '42');
  final String output = options['output'] ?? 'tmp/bot_logs.json';

  if (hands <= 0) {
    stderr.writeln('--hands must be > 0');
    exitCode = 1;
    return;
  }
  if (players < 2) {
    stderr.writeln('--players must be >= 2');
    exitCode = 1;
    return;
  }

  final rng = math.Random(seed);
  final rows = <Map<String, Object?>>[];
  int exportedHands = 0;
  int tournamentIndex = 0;

  while (exportedHands < hands) {
    final remainingHands = hands - exportedHands;
    final batch = await _runTournamentBatch(
      players: players,
      stack: stack,
      remainingHands: remainingHands,
      rng: rng,
      tableSeed: seed + tournamentIndex,
    );
    exportedHands += batch.handsPlayed;
    rows.addAll(batch.rows);
    tournamentIndex += 1;
    if (batch.handsPlayed <= 0) {
      throw StateError(
        'Bot dataset exporter made no progress at tournament $tournamentIndex',
      );
    }
  }

  final outFile = File(output);
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(const JsonEncoder.withIndent('  ').convert(rows));

  stdout.writeln('Exported ${rows.length} bot decisions from $exportedHands hands.');
  stdout.writeln('Wrote dataset -> ${outFile.path}');
}

Future<({int handsPlayed, List<Map<String, Object?>> rows})> _runTournamentBatch({
  required int players,
  required int stack,
  required int remainingHands,
  required math.Random rng,
  required int tableSeed,
}) async {
  final engine = eng.GameEngine(
    config: eng.GameConfig(
      tableSeed: tableSeed,
      smallBlind: 100,
      bigBlind: 200,
      maxPlayers: players,
      minPlayersToStart: 2,
    ),
  );

  for (int i = 0; i < players; i++) {
    final aura = 55 + rng.nextInt(41);
    engine.addPlayer(
      eng.Player(
        id: 'bot_${tableSeed}_$i',
        name: 'Bot ${tableSeed}_$i',
        chips: stack,
        aura: aura,
        isBot: true,
      ),
    );
  }
  engine.assignBotTraits(guaranteeWorldChampKiller: true);

  int handsPlayed = 0;
  int localSeed = tableSeed * 1000;
  while (handsPlayed < remainingHands && !engine.isTournamentOver) {
    final result = engine.startNewHand(seed: localSeed++);
    if (result != eng.ActionResult.ok) {
      break;
    }
    handsPlayed += 1;

    int safety = players * 200;
    while (safety-- > 0 &&
        engine.phase != eng.GamePhase.handOver &&
        engine.phase != eng.GamePhase.showdown) {
      engine.tickBots(maxSteps: players * 8);
    }
    if (safety <= 0) {
      throw StateError('Bot simulation stalled during hand ${engine.handNumber}');
    }
  }

  final rows = engine.botDecisionLog.map((entry) => entry.toJson()).toList();
  return (handsPlayed: handsPlayed, rows: rows);
}

Map<String, String> _parseArgs(List<String> args) {
  final out = <String, String>{};
  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final key = arg.substring(2);
    final next = i + 1 < args.length ? args[i + 1] : null;
    if (next != null && !next.startsWith('--')) {
      out[key] = next;
      i += 1;
    } else {
      out[key] = 'true';
    }
  }
  return out;
}
