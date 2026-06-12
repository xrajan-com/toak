import 'dart:io';

import 'package:ten_of_a_kind_poker/config/bot_lore.dart' as lore;

typedef _BotEntry = ({String name, String kingdom, String profession});

class _Cursor {
  int i;
  _Cursor(this.i);
}

void main(List<String> args) {
  final String sourcePath =
      args.isNotEmpty ? args.first : 'lib/ui/screens/game_screen.dart';
  final String outPath =
      args.length >= 2 ? args[1] : 'docs/bot_roster.csv';

  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Source file not found: $sourcePath');
    exitCode = 2;
    return;
  }

  final src = sourceFile.readAsStringSync();
  final entries = _parseBotSpecsFromGameScreen(src);
  if (entries.isEmpty) {
    stderr.writeln('No bots found in $sourcePath');
    exitCode = 3;
    return;
  }

  entries.sort((a, b) {
    final kc = a.kingdom.toLowerCase().compareTo(b.kingdom.toLowerCase());
    if (kc != 0) return kc;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  final buffer = StringBuffer();
  buffer.writeln('name,kingdom,profession');
  for (final e in entries) {
    buffer.writeln(
        '${_csv(e.name)},${_csv(e.kingdom)},${_csv(e.profession)}');
  }

  final outFile = File(outPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(buffer.toString());

  stdout.writeln('Wrote ${entries.length} bots to $outPath');
}

List<_BotEntry> _parseBotSpecsFromGameScreen(String src) {
  final out = <_BotEntry>[];

  int i = 0;
  while (true) {
    final int at = src.indexOf('_BotSpec(', i);
    if (at < 0) break;
    final cursor = _Cursor(at + '_BotSpec('.length);

    _skipWhitespace(src, cursor);

    if (cursor.i >= src.length) break;
    final String? name = _readStringLiteral(src, cursor);
    if (name == null) {
      // Likely the constructor definition: `const _BotSpec(`.
      i = at + 1;
      continue;
    }

    _skipWhitespace(src, cursor);
    if (!_consumeChar(src, cursor, ',')) {
      i = at + 1;
      continue;
    }
    _skipWhitespace(src, cursor);

    final String? kingdom = _readStringLiteral(src, cursor);
    if (kingdom == null) {
      i = at + 1;
      continue;
    }

    final botLore = lore.botLoreFor(botName: name, kingdomName: kingdom);
    out.add((name: name, kingdom: kingdom, profession: botLore.profession));
    i = cursor.i;
  }

  // Dedup by name (should be unique), keep first.
  final seen = <String>{};
  return <_BotEntry>[
    for (final e in out)
      if (seen.add(e.name)) e,
  ];
}

String _csv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String? _readStringLiteral(String src, _Cursor cursor) {
  int i = cursor.i;
  if (i >= src.length) return null;
  final quote = src[i];
  if (quote != "'" && quote != '"') return null;
  i++;

  final sb = StringBuffer();
  while (i < src.length) {
    final ch = src[i];
    if (ch == quote) {
      i++;
      cursor.i = i;
      return sb.toString();
    }
    if (ch == r'\' && i + 1 < src.length) {
      // Simple escape handling for \" and \'
      final next = src[i + 1];
      sb.write(next);
      i += 2;
      continue;
    }
    sb.write(ch);
    i++;
  }
  return null;
}

void _skipWhitespace(String src, _Cursor cursor) {
  while (cursor.i < src.length) {
    final c = src.codeUnitAt(cursor.i);
    if (c != 0x20 && c != 0x0A && c != 0x0D && c != 0x09) break;
    cursor.i++;
  }
}

bool _consumeChar(String src, _Cursor cursor, String expected) {
  if (cursor.i >= src.length) return false;
  if (src[cursor.i] != expected) return false;
  cursor.i++;
  return true;
}
