import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/services/firebase_ready.dart';

/// The steps a brand-new player passes on the way into their first game, in
/// order. Each becomes an Analytics event sent at most once per install, so a
/// funnel built from them (Firebase console -> Analytics -> Explore -> Funnel
/// exploration) counts players, not visits, and shows where new players stop.
enum OnboardingStep {
  /// The first screen of a fresh install. Opens the funnel: the other steps
  /// are only sent on installs where this one was.
  welcomeShown('onboard_welcome_shown'),
  disclaimerAccepted('onboard_disclaimer_accepted'),
  signInShown('onboard_signin_shown'),
  guestChosen('onboard_guest_chosen'),
  signedIn('onboard_signed_in'),
  modeShown('onboard_mode_shown'),
  modeChosen('onboard_mode_chosen'),
  firstGameStarted('onboard_first_game_started'),
  firstHandDealt('onboard_first_hand_dealt'),
  firstHandFinished('onboard_first_hand_finished'),
  firstGameFinished('onboard_first_game_finished'),
  firstGameLeft('onboard_first_game_left');

  const OnboardingStep(this.eventName);

  /// The Analytics event name; Analytics allows 40 characters at most.
  final String eventName;
}

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

  static const String _onboardingPrefix = 'analytics.onboarding.';
  static const String _onboardingStartedKey = '${_onboardingPrefix}started_ms';
  static final Set<OnboardingStep> _onboardingSent = <OnboardingStep>{};
  static void Function(String name, Map<String, Object> parameters)?
      _debugSink;

  /// Tests only: send events to [sink] instead of Firebase, and forget which
  /// onboarding steps this run has already sent. Pass null to stop.
  @visibleForTesting
  static void debugCaptureEvents(
    void Function(String name, Map<String, Object> parameters)? sink,
  ) {
    _debugSink = sink;
    _onboardingSent.clear();
  }

  /// True once events are being sent.
  static bool get enabled => _enabled;

  /// Whether this build may send analytics at all.
  static bool get supported => !kDebugMode;

  /// Call once Firebase has initialized. Does nothing if it did not.
  static Future<void> start() async {
    if (!firebaseReady()) return;
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

  /// The store was asked to show its rating sheet after a win; [ask] counts
  /// the asks on this install (the store may still choose not to show it).
  static Future<void> ratingAsked({required String kind, required int ask}) =>
      _log('rating_asked', <String, Object>{'kind': kind, 'ask': ask});

  /// From the game-over screen, the player went straight into another table
  /// ([choice] is play_again or next_table).
  static Future<void> playedAgain({
    required String kind,
    required String choice,
  }) =>
      _log('game_again', <String, Object>{'kind': kind, 'choice': choice});

  /// The daily tribute was paid: [streak] is the run it reached.
  static Future<void> tributeClaimed({
    required int streak,
    required int amount,
  }) =>
      _log('tribute_claimed', <String, Object>{
        'streak': streak,
        'amount': amount,
      });

  /// The game was opened from one of its reminders ([id]: 101 tribute,
  /// 102 comeback).
  static Future<void> reminderOpened({required int id}) =>
      _log('reminder_opened', <String, Object>{'id': id});

  /// The player answered the system's notification permission prompt.
  static Future<void> reminderPermission({required bool granted}) =>
      _log('reminder_permission', <String, Object>{'granted': granted ? 1 : 0});

  /// The player sent a win card through the share sheet.
  static Future<void> winCardShared({required String kind}) =>
      _log('win_card_shared', <String, Object>{'kind': kind});

  /// A new player reached [step] on the way into their first game.
  ///
  /// Sent once per install, and only on installs that began with
  /// [OnboardingStep.welcomeShown], so players from before this build never
  /// enter the funnel. Every step carries `elapsed_s`: the seconds since the
  /// welcome screen, which makes "time to first hand" readable in Analytics.
  static Future<void> onboarding(
    OnboardingStep step, {
    Map<String, Object> parameters = const <String, Object>{},
  }) async {
    if (!_enabled && _debugSink == null) return;
    if (!_onboardingSent.add(step)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final int now = DateTime.now().millisecondsSinceEpoch;
      int? started = prefs.getInt(_onboardingStartedKey);
      if (started == null) {
        if (step != OnboardingStep.welcomeShown) return;
        started = now;
        await prefs.setInt(_onboardingStartedKey, started);
      }
      final String key = '$_onboardingPrefix${step.name}';
      if (prefs.getBool(key) ?? false) return;
      await prefs.setBool(key, true);
      await _log(step.eventName, <String, Object>{
        ...parameters,
        'elapsed_s': ((now - started) / 1000).round(),
      });
    } catch (_) {
      // Analytics must never become a failure of its own.
    }
  }

  static Future<void> _log(String name, Map<String, Object> parameters) async {
    final sink = _debugSink;
    if (sink != null) {
      sink(name, parameters);
      return;
    }
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
