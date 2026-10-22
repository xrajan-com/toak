import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/services/game_analytics.dart';

/// Asks happy players to rate the game on the store: after a fort or title
/// win, at most [maxAsks] times per install and at least [minGap] apart.
///
/// Google Play and the App Store decide whether their review sheet actually
/// appears (both limit how often), so an ask they skip costs nothing. The
/// sheet is the store's own, in place: the player never leaves the game.
class RatingPrompt {
  RatingPrompt({
    InAppReview? review,
    DateTime Function()? now,
    bool? supported,
  })  : _review = review,
        _now = now ?? DateTime.now,
        _supported = supported ?? !kIsWeb;

  static final RatingPrompt instance = RatingPrompt();

  static const int maxAsks = 3;
  static const Duration minGap = Duration(days: 30);
  static const String askedCountKey = 'rating_prompt.asked_count';
  static const String lastAskedKey = 'rating_prompt.last_asked_ms';

  final InAppReview? _review;
  final DateTime Function() _now;
  final bool _supported;
  bool _asking = false;

  /// The player just won a fort or a title. Returns whether the store was
  /// asked to show its review sheet.
  Future<bool> afterWin({required String kind}) async {
    if (!_supported || _asking) return false;
    _asking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final int asked = prefs.getInt(askedCountKey) ?? 0;
      if (asked >= maxAsks) return false;
      final int? lastMs = prefs.getInt(lastAskedKey);
      final DateTime now = _now();
      if (lastMs != null &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(lastMs)) <
              minGap) {
        return false;
      }
      final InAppReview review = _review ?? InAppReview.instance;
      if (!await review.isAvailable()) return false;
      await prefs.setInt(askedCountKey, asked + 1);
      await prefs.setInt(lastAskedKey, now.millisecondsSinceEpoch);
      unawaited(GameAnalytics.ratingAsked(kind: kind, ask: asked + 1));
      await review.requestReview();
      return true;
    } catch (_) {
      // A rating ask must never get in the way of the game.
      return false;
    } finally {
      _asking = false;
    }
  }
}
