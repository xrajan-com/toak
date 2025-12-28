import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

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
        final manifestJson = await rootBundle.loadString('AssetManifest.json');
        final manifest =
            json.decode(manifestJson) as Map<String, dynamic>? ?? const {};
        _keys = manifest.keys.map(_fixDupAssets).toSet();
      } catch (_) {
        _keys = <String>{};
      } finally {
        _loading = null;
      }
      return _keys!;
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
}
