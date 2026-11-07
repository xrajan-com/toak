import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/services/ambience_service.dart';
import 'package:ten_of_a_kind_poker/services/x_music_service.dart';

/// User-controlled accessibility and audio preferences.
///
/// Values are local device preferences by design: they apply before login and
/// must remain available to guests.
class AppSettingsService extends ChangeNotifier {
  static const String _soundEffectsKey = 'settings.sound_effects.v1';
  static const String _loungeSoundsKey = 'settings.lounge_sounds.v1';
  static const String _sceneSoundsKey = 'settings.scene_sounds.v1';
  static const String _dealerVoiceKey = 'settings.dealer_voice.v1';
  static const String _dealerVoiceEveryActionKey =
      'settings.dealer_voice_every_action.v1';
  static const String _reducedMotionKey = 'settings.reduced_motion.v1';

  // Lounge/table music defaults to off: it's ambient, not informational,
  // and a first run that is quiet by default is easier to recover from than
  // one that is loud. Users can turn it on in settings. Sound effects and the
  // dealer voice are deliberately left on in every game, since they carry
  // information about the hand as it happens. The voice calls all-ins only
  // unless the player asks for every action: a dealer naming every check and
  // fold at a full table never stops talking.
  bool _soundEffectsEnabled = true;
  bool _loungeSoundsEnabled = false;
  // The sound of the scene behind the table (waves, a pub, a stadium) is on
  // by default: it is quiet, sits well under the cards and chips, and is
  // what makes the place feel like a place.
  bool _sceneSoundsEnabled = true;
  bool _dealerVoiceEnabled = true;
  bool _dealerVoiceEveryAction = false;
  bool _reducedMotion = false;
  bool _loaded = false;
  Future<void>? _loadFuture;

  bool get soundEffectsEnabled => _soundEffectsEnabled;
  bool get loungeSoundsEnabled => _loungeSoundsEnabled;
  bool get sceneSoundsEnabled => _sceneSoundsEnabled;
  bool get dealerVoiceEnabled => _dealerVoiceEnabled;
  bool get dealerVoiceEveryAction => _dealerVoiceEveryAction;
  bool get reducedMotion => _reducedMotion;
  bool get loaded => _loaded;

  Future<void> load() => _loadFuture ??= _load();

  bool reduceMotionFor(BuildContext context) {
    return _reducedMotion || MediaQuery.disableAnimationsOf(context);
  }

  Future<void> setSoundEffectsEnabled(bool value) async {
    if (_soundEffectsEnabled == value) return;
    _soundEffectsEnabled = value;
    SoundFx.instance.setSoundEffectsMuted(!value);
    notifyListeners();
    await _persist(_soundEffectsKey, value);
  }

  Future<void> setLoungeSoundsEnabled(bool value) async {
    if (_loungeSoundsEnabled == value) return;
    _loungeSoundsEnabled = value;
    XMusicService.instance.setMuted(!value);
    notifyListeners();
    await _persist(_loungeSoundsKey, value);
  }

  Future<void> setSceneSoundsEnabled(bool value) async {
    if (_sceneSoundsEnabled == value) return;
    _sceneSoundsEnabled = value;
    AmbienceService.instance.setMuted(!value);
    notifyListeners();
    await _persist(_sceneSoundsKey, value);
  }

  Future<void> setDealerVoiceEnabled(bool value) async {
    if (_dealerVoiceEnabled == value) return;
    _dealerVoiceEnabled = value;
    SoundFx.instance.setVoiceMuted(!value);
    notifyListeners();
    await _persist(_dealerVoiceKey, value);
  }

  Future<void> setDealerVoiceEveryAction(bool value) async {
    if (_dealerVoiceEveryAction == value) return;
    _dealerVoiceEveryAction = value;
    SoundFx.instance.setVoiceEveryAction(value);
    notifyListeners();
    await _persist(_dealerVoiceEveryActionKey, value);
  }

  Future<void> setReducedMotion(bool value) async {
    if (_reducedMotion == value) return;
    _reducedMotion = value;
    notifyListeners();
    await _persist(_reducedMotionKey, value);
  }

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _soundEffectsEnabled = prefs.getBool(_soundEffectsKey) ?? true;
      _loungeSoundsEnabled = prefs.getBool(_loungeSoundsKey) ?? false;
      _sceneSoundsEnabled = prefs.getBool(_sceneSoundsKey) ?? true;
      _dealerVoiceEnabled = prefs.getBool(_dealerVoiceKey) ?? true;
      _dealerVoiceEveryAction =
          prefs.getBool(_dealerVoiceEveryActionKey) ?? false;
      _reducedMotion = prefs.getBool(_reducedMotionKey) ?? false;
    } catch (error, stack) {
      debugPrint('Settings load failed: $error\n$stack');
    } finally {
      SoundFx.instance.setSoundEffectsMuted(!_soundEffectsEnabled);
      XMusicService.instance.setMuted(!_loungeSoundsEnabled);
      AmbienceService.instance.setMuted(!_sceneSoundsEnabled);
      SoundFx.instance.setVoiceMuted(!_dealerVoiceEnabled);
      SoundFx.instance.setVoiceEveryAction(_dealerVoiceEveryAction);
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _persist(String key, bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool saved = await prefs.setBool(key, value);
      if (!saved) {
        debugPrint('Settings write was rejected for $key.');
      }
    } catch (error, stack) {
      debugPrint('Settings write failed for $key: $error\n$stack');
    }
  }
}
