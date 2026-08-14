import 'package:flutter/services.dart' show AssetManifest, rootBundle;

class WatermarkResolver {
  static const Map<String, String> _kingdomFolderAliases = <String, String>{
    'Far East': 'Asia',
    'Asia Rest': 'Asia',
    'Central Asia': 'Russia',
    'Persia': 'Arabia',
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

  static Set<String>? _keys;
  static Future<Set<String>>? _loading;

  static String _fixDupAssets(String p) =>
      p.replaceFirst(RegExp(r'^(assets/)+'), 'assets/');

  static Future<Set<String>> _ensureKeys() {
    final keys = _keys;
    if (keys != null) return Future<Set<String>>.value(keys);
    final loading = _loading;
    if (loading != null) return loading;

    final future = (() async {
      try {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        _keys = manifest.listAssets().map(_fixDupAssets).toSet();
      } catch (_) {
        _keys = null;
      } finally {
        _loading = null;
      }
      return _keys ?? <String>{};
    })();

    _loading = future;
    return future;
  }

  /// Lists watermark assets under a kingdom folder.
  ///
  /// Folder convention:
  /// `assets/images/watermarks/<Kingdom Name>/...`
  static Future<List<String>> listKingdomFolderWatermarks({
    required String kingdomName,
  }) async {
    final kingdom = _folderForKingdom(kingdomName);
    if (kingdom.isEmpty) return const <String>[];

    final keys = await _ensureKeys();
    if (keys.isEmpty) return const <String>[];

    final folder = 'assets/images/watermarks/$kingdom/';
    final list = keys.where((k) {
      if (!k.startsWith(folder)) return false;
      final lower = k.toLowerCase();
      return lower.endsWith('.svg') || lower.endsWith('.png');
    }).toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Future<String?> subKingdomWatermarkFor({
    required String kingdomName,
    required int subKingdomIndex,
    String? subKingdomName,
  }) async {
    final kingdom = _folderForKingdom(kingdomName);
    if (kingdom.isEmpty || subKingdomIndex < 1) return null;

    final keys = await _ensureKeys();
    if (keys.isEmpty) return null;

    final namedAsset = _subKingdomNamedAsset(
      kingdomName: kingdom,
      subKingdomName: subKingdomName,
    );
    if (namedAsset != null && keys.contains(namedAsset)) return namedAsset;

    final suffix = subKingdomIndex.toString().padLeft(2, '0');
    final asset = 'assets/images/watermarks/$kingdom/fort_$suffix.svg';
    return keys.contains(asset) ? asset : null;
  }

  static String _folderForKingdom(String kingdomName) {
    final kingdom = kingdomName.trim();
    return _kingdomFolderAliases[kingdom] ?? kingdom;
  }

  static String? _subKingdomNamedAsset({
    required String kingdomName,
    required String? subKingdomName,
  }) {
    final slug = _slugForAsset(subKingdomName);
    if (slug == null) return null;
    return 'assets/images/watermarks/$kingdomName/$slug.svg';
  }

  static String? _slugForAsset(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final withoutCountry = trimmed.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
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
    final slug = buffer.toString().replaceFirst(RegExp(r'_+$'), '');
    return slug.isEmpty ? null : slug;
  }

  static const Map<String, String> _assetSlugReplacements = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'ā': 'a',
    'ă': 'a',
    'ą': 'a',
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
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ı': 'i',
    'ñ': 'n',
    'ń': 'n',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ø': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'æ': 'ae',
    'œ': 'oe',
    'ß': 'ss',
  };
}
