import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Product analytics through Google Analytics for Firebase: how many new
/// players come back on day 1, 7 and 30 (Firebase console -> Analytics ->
/// Retention, which needs no events of our own), and where they drop off,
/// from a handful of game moments.
///
/// Off in debug builds and tests, so only real players are counted. Events
/// carry game facts only (which kind of game, which circuit, the finishing
/// place); never a name, email or account id. The advertising id is not
/// collected (AndroidManifest.xml removes it and turns ad-id collection
/// off).
class GameAnalytics {
  GameAnalytics._();

  static bool _enabled = false;

  /// True once events are being sent.
  static bool get enabled => _enabled;

  /// Whether this build may send analytics at all.
  static bool get supported => !kDebugMode;

  /// Call once Firebase has initialized. Does nothing if it did not.
  static Future<void> start() async {
    if (Firebase.apps.isEmpty) return;
    try {
      // Written on every launch, so a debug build installed over a release
      // one stops counting too.
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(supported);
      _enabled = supported;
    } catch (_) {
      _enabled = false;
    }
  }

  /// A game began. [kind] is quick, fort or title.
  static Future<void> gameStarted({
    required String kind,
    String? circuit,
  }) =>
      _log('game_started', <String, Object>{
        'kind': kind,
        if (circuit != null) 'circuit': circuit,
      });

  /// A game ran to its end; [place] 1 is a win.
  static Future<void> gameFinished({
    required String kind,
    String? circuit,
    required int place,
    required int players,
  }) =>
      _log('game_finished', <String, Object>{
        'kind': kind,
        if (circuit != null) 'circuit': circuit,
        'place': place,
        'players': players,
        'won': place == 1 ? 1 : 0,
      });

  /// The player left a game before it ended.
  static Future<void> gameLeft({required String kind, String? circuit}) =>
      _log('game_left', <String, Object>{
        'kind': kind,
        if (circuit != null) 'circuit': circuit,
      });

  /// A fort (or, with [title], a kingdom's title match) was won and the
  /// server confirmed the clear.
  static Future<void> campaignWon({
    required bool title,
    required String circuit,
    required String kingdom,
  }) =>
      _log(title ? 'title_won' : 'fort_won', <String, Object>{
        'circuit': circuit,
        'kingdom': kingdom.length <= 100 ? kingdom : kingdom.substring(0, 100),
      });

  /// The player opened the share card for a hand.
  static Future<void> handShared({required bool heroWon}) =>
      _log('hand_shared', <String, Object>{'won': heroWon ? 1 : 0});

  /// The player opened the card for a fort, kingdom or title win
  /// ([kind] is fort, kingdom or title).
  static Future<void> winCardOpened({required String kind}) =>
      _log('win_card_opened', <String, Object>{'kind': kind});

  /// The player saved a win card to their device ([saved] 0 if it failed).
  static Future<void> winCardSaved({
    required String kind,
    required bool saved,
  }) =>
      _log('win_card_saved', <String, Object>{
        'kind': kind,
        'saved': saved ? 1 : 0,
      });

  /// The player sent a win card through the share sheet.
  static Future<void> winCardShared({required String kind}) =>
      _log('win_card_shared', <String, Object>{'kind': kind});

  static Future<void> _log(String name, Map<String, Object> parameters) async {
    if (!_enabled) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (_) {
      // Analytics must never become a failure of its own.
    }
  }
}
