import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/services/x_music_service.dart';

/// User-controlled accessibility and audio preferences.
///
/// Values are local device preferences by design: they apply before login and
/// must remain available to guests.
class AppSettingsService extends ChangeNotifier {
  static const String _soundEffectsKey = 'settings.sound_effects.v1';
  static const String _loungeSoundsKey = 'settings.lounge_sounds.v1';
  static const String _dealerVoiceKey = 'settings.dealer_voice.v1';
  static const String _reducedMotionKey = 'settings.reduced_motion.v1';

  // Table audio defaults to off: the game screen is busy enough without it,
  // and a first run that is quiet by default is easier to recover from than
  // one that is loud. Users can turn it on in settings. The dealer voice is
  // deliberately left on, since it carries information about the hand.
  bool _soundEffectsEnabled = false;
  bool _loungeSoundsEnabled = false;
  bool _dealerVoiceEnabled = true;
  bool _reducedMotion = false;
  bool _loaded = false;
  Future<void>? _loadFuture;

  bool get soundEffectsEnabled => _soundEffectsEnabled;
  bool get loungeSoundsEnabled => _loungeSoundsEnabled;
  bool get dealerVoiceEnabled => _dealerVoiceEnabled;
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

  Future<void> setDealerVoiceEnabled(bool value) async {
    if (_dealerVoiceEnabled == value) return;
    _dealerVoiceEnabled = value;
    SoundFx.instance.setVoiceMuted(!value);
    notifyListeners();
    await _persist(_dealerVoiceKey, value);
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
      _soundEffectsEnabled = prefs.getBool(_soundEffectsKey) ?? false;
      _loungeSoundsEnabled = prefs.getBool(_loungeSoundsKey) ?? false;
      _dealerVoiceEnabled = prefs.getBool(_dealerVoiceKey) ?? true;
      _reducedMotion = prefs.getBool(_reducedMotionKey) ?? false;
    } catch (error, stack) {
      debugPrint('Settings load failed: $error\n$stack');
    } finally {
      SoundFx.instance.setSoundEffectsMuted(!_soundEffectsEnabled);
      XMusicService.instance.setMuted(!_loungeSoundsEnabled);
      SoundFx.instance.setVoiceMuted(!_dealerVoiceEnabled);
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
