import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart';

void main() {
  test('configured fort watermarks use fort-name SVG filenames only', () {
    final expected = _expectedFortWatermarkAssets();
    final actual = _svgFilesUnder('assets/images/watermarks')
        .where((path) => path.split('/').length > 4)
        .where((path) => !_nonVenueReferenceAssets.contains(path))
        .toSet();

    final missing = expected.difference(actual).toList()..sort();
    final extra = actual
        .difference(expected)
        .where((path) => !_retainedLegacyFortAsset(path))
        .toList()
      ..sort();
    final numbered = actual
        .where((path) => RegExp(r'/fort_[0-9][0-9]\.svg$').hasMatch(path))
        .toList()
      ..sort();

    expect(missing, isEmpty);
    expect(extra, isEmpty);
    expect(numbered, isEmpty);
  });

  test('non-venue watermark references remain available', () {
    final actual = _svgFilesUnder('assets/images/watermarks');

    expect(actual, containsAll(_nonVenueReferenceAssets));
  });

  test('root kingdom watermark SVGs are referenced by the table maps', () {
    final actual = _svgFilesUnder('assets/images/watermarks')
        .where((path) => path.split('/').length == 4)
        .toSet();
    final referenced = <String>{
      ..._rootWatermarkReferencesIn('lib/ui/screens/game_screen/table.dart'),
      ..._rootWatermarkReferencesIn('lib/ui/screens/game_screen.dart'),
    };

    final missing = referenced.difference(actual).toList()..sort();
    final extra = actual.difference(referenced).toList()..sort();

    expect(missing, isEmpty);
    expect(extra, isEmpty);
  });
}

Set<String> _expectedFortWatermarkAssets() {
  final expected = <String>{};
  for (final kingdomEntry in kSubKingdomNames.entries) {
    for (final fortEntry in kingdomEntry.value.entries) {
      final folder = _kingdomFolderAliases[fortEntry.key] ?? fortEntry.key;
      for (final fortName in fortEntry.value) {
        final slug = _slugForAsset(fortName);
        final primary = 'assets/images/watermarks/$folder/$slug.svg';
        if (File(primary).existsSync()) {
          expected.add(primary);
          continue;
        }
        String? legacy;
        for (final candidate in _legacyFortFolders(folder)) {
          final path = 'assets/images/watermarks/$candidate/$slug.svg';
          if (File(path).existsSync()) {
            legacy = path;
            break;
          }
        }
        expected.add(legacy ?? primary);
      }
    }
  }
  return expected;
}

Iterable<String> _legacyFortFolders(String folder) sync* {
  if (folder == 'US Circuit') yield 'N. America';
  if (<String>{
    'Europe',
    'Britain',
    'France',
    'Italy',
    'Spain',
    'Mediterranean',
  }.contains(folder)) {
    yield 'Europe';
  }
}

Set<String> _svgFilesUnder(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return const <String>{};
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => file.path.replaceAll('\\', '/'))
      .where((path) => path.toLowerCase().endsWith('.svg'))
      .toSet();
}

Set<String> _rootWatermarkReferencesIn(String path) {
  final source = File(path).readAsStringSync();
  return RegExp(r"assets/images/watermarks/[^/'" r'"]+\.svg')
      .allMatches(source)
      .map((match) => match.group(0)!)
      .where((path) => !path.contains(r'$'))
      .toSet();
}

String _slugForAsset(String raw) {
  final withoutCountry = raw.trim().replaceAll(RegExp(r'\s*\([^)]*\)'), '');
  final normalized = withoutCountry
      .replaceAll('’', '')
      .replaceAll("'", '')
      .replaceAll('`', '')
      .replaceAll('‘', '')
      .replaceAll('´', '');
  final buffer = StringBuffer();
  var previousWasSeparator = true;
  for (final rune in normalized.runes) {
    final ch = String.fromCharCode(rune).toLowerCase();
    final replacement = _assetSlugReplacements[ch] ?? ch;
    for (final unit in replacement.runes) {
      final c = String.fromCharCode(unit);
      final isAlnum = RegExp(r'[a-z0-9]').hasMatch(c);
      if (isAlnum) {
        buffer.write(c);
        previousWasSeparator = false;
      } else if (!previousWasSeparator) {
        buffer.write('_');
        previousWasSeparator = true;
      }
    }
  }
  return buffer.toString().replaceFirst(RegExp(r'_+$'), '');
}

const Map<String, String> _kingdomFolderAliases = <String, String>{
  'Far East': 'Asia',
  'Asia Rest': 'Asia',
  'Persia': 'Arabia',
  'European Marches': 'Europe',
  'Dominion of Canada': 'US Circuit',
  'Massachusetts': 'US Circuit',
  'New York': 'US Circuit',
  'Virginia': 'US Circuit',
  'Illinois': 'US Circuit',
  'Florida': 'US Circuit',
  'Texas': 'US Circuit',
  'Kansas': 'US Circuit',
  'Colorado': 'US Circuit',
  'California': 'US Circuit',
};

const Set<String> _nonVenueReferenceAssets = <String>{
  'assets/images/watermarks/US Circuit/guitar_pedal_2.svg',
};

bool _retainedLegacyFortAsset(String path) {
  return path.startsWith('assets/images/watermarks/N. America/') ||
      path.startsWith('assets/images/watermarks/Europe/');
}

const Map<String, String> _assetSlugReplacements = <String, String>{
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'ạ': 'a',
  'ả': 'a',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ė': 'e',
  'ę': 'e',
  'ế': 'e',
  'ệ': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ı': 'i',
  'ị': 'i',
  'ñ': 'n',
  'ń': 'n',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ø': 'o',
  'ơ': 'o',
  'ồ': 'o',
  'ổ': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'æ': 'ae',
  'œ': 'oe',
  'ß': 'ss',
  'đ': 'd',
};
