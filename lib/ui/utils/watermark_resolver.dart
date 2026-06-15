import 'package:flutter/services.dart' show AssetManifest, rootBundle;

class WatermarkResolver {
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
    final kingdom = kingdomName.trim();
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
  }) async {
    final kingdom = kingdomName.trim();
    if (kingdom.isEmpty || subKingdomIndex < 1) return null;

    final keys = await _ensureKeys();
    if (keys.isEmpty) return null;

    final suffix = subKingdomIndex.toString().padLeft(2, '0');
    final asset = 'assets/images/watermarks/$kingdom/fort_$suffix.svg';
    return keys.contains(asset) ? asset : null;
  }
}
