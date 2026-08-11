// lib/ui/utils/deck_cache.dart
import 'dart:async';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// DeckCache (Option A):
/// - Auto-detects if there are ZERO front assets in Flutter's asset manifest
///   and then disables itself (no probing, no logs).
/// - You can also force-disable with [enabled = false].
/// - Still supports multiple naming conventions when enabled.
class DeckCache {
  // ========================= Config =========================

  /// Rooted folders to search, in order. Change with [configure].
  static List<String> _bases = <String>[
    'assets/images/fronts_svg', // e.g., "6H.webp", "6H.svg"
    'assets/images/fronts', // e.g., "hearts_6.webp", "hearts_6.jpeg"
  ];

  /// Allowed extensions in order of preference. Change with [configure].
  static List<String> _exts = <String>[
    '.webp',
    '.svg',
    '.png',
    '.jpg',
    '.jpeg'
  ];

  /// Master switch (set false to completely bypass DeckCache).
  static bool enabled = true;

  /// If true, when no front assets are found in the manifest,
  /// DeckCache will auto-silence verbose logs.
  static bool suppressLogsIfNoAssets = true;

  /// Turn on verbose logging in dev.
  static bool verbose = true;

  // =================== Internal state =======================

  static final Map<String, String> _resolved = {}; // "6H" → path
  static final Set<String> _misses = {};
  static bool _initialized = false;
  static Future<void>? _initializationFuture;
  static Future<void>? _manifestFuture;

  @visibleForTesting
  static Future<Iterable<String>> Function()? manifestLoaderOverride;

  // Cached manifest keys (all asset paths the app knows about)
  static Set<String>? _manifestKeys;

  // Derived from manifest: do we have ANY fronts at all?
  static bool _hasAnyFrontAssets = false;

  // ===================== Public API =========================

  /// Optionally override bases/exts at runtime (e.g., A/B variants)
  static void configure(
      {List<String>? bases, List<String>? exts, bool? enableVerbose}) {
    if (bases != null && bases.isNotEmpty) _bases = bases;
    if (exts != null && exts.isNotEmpty) _exts = exts;
    if (enableVerbose != null) verbose = enableVerbose;
    // Note: call clearCache() yourself if you changed actual files/folders.
  }

  /// Preload all 52 cards and warm the cache (only if enabled & assets exist).
  static Future<void> ensureDeckReady() {
    if (_initialized) return Future<void>.value();
    return _initializationFuture ??= _initializeDeck();
  }

  /// Warms the optional deck cache without allowing a precache failure to
  /// escape from fire-and-forget UI startup work.
  static Future<void> ensureDeckReadySafely() async {
    try {
      await ensureDeckReady();
    } catch (error) {
      debugPrint('DeckCache: warm-up failed: $error');
    }
  }

  static Future<void> _initializeDeck() async {
    try {
      await _ensureManifest();

      // Short-circuit: do nothing if disabled or no front assets present.
      if (!enabled || !_hasAnyFrontAssets) {
        if (verbose) {
          debugPrint('DeckCache: ensureDeckReady skipped '
              '(enabled=$enabled, hasFrontAssets=$_hasAnyFrontAssets)');
        }
        _initialized = true;
        return;
      }

      const suits = ['S', 'H', 'D', 'C'];
      const ranks = [
        'A',
        'K',
        'Q',
        'J',
        '10',
        '9',
        '8',
        '7',
        '6',
        '5',
        '4',
        '3',
        '2'
      ];
      for (final r in ranks) {
        for (final s in suits) {
          await _resolveAndCache(r, s);
        }
      }
      _initialized = true;
    } finally {
      _initializationFuture = null;
    }
  }

  /// Returns the asset path for a rank+suit if already resolved (or null).
  static String? assetFor(String rank, String suit) {
    if (!enabled || !_hasAnyFrontAssets) return null;
    return _resolved[_code(rank, suit)];
  }

  /// Resolves (and caches) the asset path for a rank+suit.
  static Future<String?> resolve(String rank, String suit) async {
    if (!enabled) return null;
    await _ensureManifest();
    if (!_hasAnyFrontAssets) return null;

    final code = _code(rank, suit);
    if (_resolved.containsKey(code)) return _resolved[code];
    if (_misses.contains(code)) return null;
    await _resolveAndCache(rank, suit);
    return _resolved[code];
  }

  /// Quick widget builder for a card front.
  /// If disabled or no assets found: returns [fallback] or empty box (no logs).
  static Widget cardFrontWidget({
    required String rank,
    required String suit,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? fallback,
  }) {
    if (!enabled || !_hasAnyFrontAssets) {
      return fallback ?? const SizedBox.shrink();
    }

    final path = assetFor(rank, suit);
    if (path == null) return fallback ?? const SizedBox.shrink();

    final fixed = _fixDupAssetsPrefix(path);
    assert(
        !fixed.startsWith('assets/assets/'), 'Double assets/ prefix: $fixed');

    Widget child = fixed.toLowerCase().endsWith('.svg')
        ? SvgPicture.asset(fixed, width: width, height: height, fit: fit)
        : Image.asset(fixed, width: width, height: height, fit: fit);

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius, child: child);
    }
    return child;
  }

  /// Debug helpers
  static void clearCache() {
    _resolved.clear();
    _misses.clear();
    _initialized = false;
    _initializationFuture = null;
    _manifestFuture = null;
    _manifestKeys = null;
    _hasAnyFrontAssets = false;
  }

  static void debugReport() {
    if (!verbose) return;
    debugPrint('DeckCache report: '
        'enabled=$enabled, hasFrontAssets=$_hasAnyFrontAssets, '
        'resolved=${_resolved.length}, misses=${_misses.length}, '
        'bases=${_bases.join(', ')}, exts=${_exts.join(', ')}');
  }

  // ===================== Internals ==========================

  static String _fixDupAssetsPrefix(String p) =>
      p.replaceFirst(RegExp(r'^(assets/)+'), 'assets/');

  static Future<void> _ensureManifest() {
    if (_manifestKeys != null) return Future<void>.value();
    return _manifestFuture ??= _loadManifest();
  }

  static Future<void> _loadManifest() async {
    try {
      final keys =
          await (manifestLoaderOverride?.call() ?? _loadBundledManifestKeys());
      _manifestKeys = keys.map(_fixDupAssetsPrefix).toSet();

      // Detect if we have *any* front assets in the configured bases
      _hasAnyFrontAssets = _manifestKeys!.any(
        (k) => _bases.any((b) => k.startsWith('$b/')),
      );

      if (suppressLogsIfNoAssets && !_hasAnyFrontAssets) {
        verbose = false; // auto-silence when nothing to load
      }

      if (verbose) {
        debugPrint(
          'DeckCache: manifest loaded with ${_manifestKeys!.length} entries '
          '(hasFrontAssets=$_hasAnyFrontAssets)',
        );
      }
    } finally {
      _manifestFuture = null;
    }
  }

  static Future<Iterable<String>> _loadBundledManifestKeys() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest.listAssets();
  }

  static Future<void> _resolveAndCache(String rank, String suit) async {
    final code = _code(rank, suit);
    if (_resolved.containsKey(code) || _misses.contains(code)) return;

    // Safety: if somehow called before checks
    if (!enabled || !_hasAnyFrontAssets) {
      _misses.add(code);
      return;
    }

    final s = _suitLetter(suit);
    final r = _rankKey(rank);

    // suit/rank words for word-based conventions
    final suitName =
        {'S': 'spades', 'H': 'hearts', 'D': 'diamonds', 'C': 'clubs'}[s]!;
    final rankName = {
      'A': 'ace',
      'K': 'king',
      'Q': 'queen',
      'J': 'jack',
      '10': '10',
      '9': '9',
      '8': '8',
      '7': '7',
      '6': '6',
      '5': '5',
      '4': '4',
      '3': '3',
      '2': '2'
    }[r]!;

    // Candidate base filenames (no extension), in preference order
    final candidates = <String>[
      '$r$s', // AS, 10H
      '${r}_$s', // A_S, 10_H
      '${rankName}_${suitName}', // ace_spades, 10_hearts
      '${rankName}-of-${suitName}', // ace-of-spades, 10-of-hearts
      '${suitName}_$r', // spades_A, hearts_10
    ];

    final found = _findInManifest(candidates);
    if (found != null) {
      _resolved[code] = found;
      if (verbose) debugPrint('DeckCache: $code → $found');
      return;
    }

    _misses.add(code);
    if (verbose) {
      final sample = _sampleProbes(candidates, 8);
      debugPrint('DeckCache: MISS $code (probed e.g.: $sample …)');
    }
  }

  /// Tries all bases/exts for each base-filename, checks against the manifest set.
  static String? _findInManifest(List<String> baseNames) {
    final keys = _manifestKeys!;
    for (final base in _bases) {
      for (final name in baseNames) {
        for (final ext in _exts) {
          final p1 = _fixDupAssetsPrefix('$base/$name$ext');
          if (keys.contains(p1)) return p1;

          // also try a lowercase variant (useful when files were lowercased)
          final p2 = p1.toLowerCase();
          if (p2 != p1 && keys.contains(p2)) return p2;
        }
      }
    }
    return null;
  }

  static String _code(String rank, String suit) =>
      '${_rankKey(rank)}${_suitLetter(suit)}';

  static String _rankKey(String rank) {
    final r = rank.toUpperCase().trim();
    const valid = {
      'A',
      'K',
      'Q',
      'J',
      '10',
      '9',
      '8',
      '7',
      '6',
      '5',
      '4',
      '3',
      '2'
    };
    if (valid.contains(r)) return r;
    final n = int.tryParse(r);
    if (n != null && n >= 2 && n <= 10) return n.toString();
    return r;
  }

  static String _suitLetter(String suit) {
    switch (suit) {
      case 'S':
      case '♠':
        return 'S';
      case 'H':
      case '♥':
        return 'H';
      case 'D':
      case '♦':
        return 'D';
      case 'C':
      case '♣':
        return 'C';
      default:
        return 'S';
    }
  }

  static String _sampleProbes(List<String> names, int max) {
    final probes = <String>[];
    outer:
    for (final b in _bases) {
      for (final n in names) {
        for (final e in _exts) {
          probes.add('$b/$n$e');
          if (probes.length >= max) break outer;
        }
      }
    }
    return probes.join(', ');
  }
}
