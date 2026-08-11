import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService extends ChangeNotifier {
  static const String defaultAbout = 'Plays the player, not cards';
  static const String _kAvatarKeyPrefix = 'profile.avatar.';
  static const String _kNameKeyPrefix = 'profile.name.';
  static const String _kEmailKeyPrefix = 'profile.email.';
  static const String _kAboutKeyPrefix = 'profile.about.';
  static const String _kKingdomKeyPrefix = 'profile.kingdom.';
  static const String _kProfileCompleteKeyPrefix = 'profile.complete.';

  String? _displayName;
  String? _email;
  String? _avatarUrl;
  String? _userId;
  String? _rank;
  String? _about;
  String? _kingdom;
  Uint8List? _avatarBytes;
  bool _profileComplete = false;
  bool _profileHydrated = true;
  bool _localProfileResolved = true;
  bool _remoteProfileResolved = true;
  bool _remoteCompletionAuthoritative = false;
  Object? _loadError;
  int _bindingGeneration = 0;
  final Set<String> _purgedUserIds = <String>{};
  Timer? _remoteHydrationTimer;
  FirebaseFirestore? _db;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  String? get displayName => _displayName;
  String? get email => _email;
  String? get avatarUrl => _avatarUrl;
  String? get userId => _userId;
  String? get rank => _rank;
  String get about => _about ?? defaultAbout;
  String? get kingdom => _kingdom;
  Uint8List? get avatarBytes => _avatarBytes;
  bool get profileComplete => _profileComplete;
  bool get isHydrated => _profileHydrated;
  Object? get loadError => _loadError;

  static String normalizeAbout(
    String? about, {
    bool useDefaultIfBlank = true,
  }) {
    final trimmed = (about ?? '').trim();
    if (trimmed.isEmpty) {
      return useDefaultIfBlank ? defaultAbout : '';
    }
    return trimmed.length > 30 ? trimmed.substring(0, 30) : trimmed;
  }

  static bool inferProfileComplete({
    String? displayName,
    String? kingdom,
  }) {
    return (displayName ?? '').trim().length >= 3 &&
        (kingdom ?? '').trim().isNotEmpty;
  }

  void bindUserId(String? uid) {
    final normalized = uid?.trim();
    final nextUid =
        normalized == null || normalized.isEmpty ? null : normalized;
    if (_userId == nextUid) return;
    _startBinding(nextUid);
  }

  void retryCurrentUser() {
    final uid = _userId;
    if (uid == null) return;
    _startBinding(uid);
  }

  void _startBinding(String? uid) {
    final generation = ++_bindingGeneration;
    _remoteHydrationTimer?.cancel();
    unawaited(_sub?.cancel());
    _sub = null;
    _userId = uid;
    _displayName = null;
    _email = null;
    _avatarUrl = null;
    _rank = null;
    _about = null;
    _kingdom = null;
    _avatarBytes = null;
    _profileComplete = false;
    _profileHydrated = uid == null;
    _localProfileResolved = uid == null;
    _remoteProfileResolved = uid == null;
    _remoteCompletionAuthoritative = false;
    _loadError = null;
    notifyListeners();

    if (uid == null) return;
    _remoteHydrationTimer = Timer(const Duration(seconds: 4), () {
      if (!_isCurrent(uid, generation) || _remoteProfileResolved) return;
      _remoteProfileResolved = true;
      _loadError = TimeoutException('Profile sync timed out.');
      _updateHydration();
      notifyListeners();
    });
    _bindRemoteProfile(uid, generation);
    unawaited(_loadLocalProfile(uid, generation));
    unawaited(_loadLocalAvatar(uid, generation));
  }

  bool _isCurrent(String uid, int generation) {
    return _userId == uid && _bindingGeneration == generation;
  }

  void _updateHydration() {
    _profileHydrated = _localProfileResolved && _remoteProfileResolved;
  }

  void _resolveRemoteHydration() {
    _remoteHydrationTimer?.cancel();
    _remoteProfileResolved = true;
    _updateHydration();
  }

  void _bindRemoteProfile(String uid, int generation) {
    final db = _dbOrNull();
    if (db == null) {
      if (_isCurrent(uid, generation)) {
        _loadError = StateError('Profile service is unavailable.');
        _resolveRemoteHydration();
        notifyListeners();
      }
      return;
    }

    final doc = db.collection('users').doc(uid);
    _sub = doc.snapshots().listen(
      (snap) {
        if (!_isCurrent(uid, generation)) return;
        final data = snap.data();
        if (data == null) {
          _remoteCompletionAuthoritative = false;
          _profileComplete = inferProfileComplete(
            displayName: _displayName,
            kingdom: _kingdom,
          );
          _resolveRemoteHydration();
          notifyListeners();
          return;
        }
        _applyRemote(data, uid: uid, generation: generation);
      },
      onError: (Object error) {
        if (!_isCurrent(uid, generation)) return;
        debugPrint('Profile stream error: $error');
        _loadError = error;
        _resolveRemoteHydration();
        notifyListeners();
      },
    );
  }

  void _applyRemote(
    Map<String, dynamic> data, {
    required String uid,
    required int generation,
  }) {
    if (!_isCurrent(uid, generation)) return;
    _displayName =
        (data['displayName'] as String?)?.trim().nullIfEmpty ?? _displayName;
    _email = (data['email'] as String?)?.trim().nullIfEmpty ?? _email;
    final remoteAbout = (data['about'] as String?)?.trim();
    _about = remoteAbout == null
        ? (_about ?? defaultAbout)
        : normalizeAbout(remoteAbout);
    _kingdom = (data['kingdom'] as String?)?.trim().nullIfEmpty ?? _kingdom;
    final explicitComplete = data['profileComplete'];
    _remoteCompletionAuthoritative = true;
    _profileComplete = explicitComplete is bool
        ? explicitComplete
        : inferProfileComplete(
            displayName: _displayName,
            kingdom: _kingdom,
          );
    _resolveRemoteHydration();
    _loadError = null;
    notifyListeners();
    unawaited(_persistLocalProfile(uid, generation));
  }

  FirebaseFirestore? _dbOrNull() {
    if (_db != null) return _db;
    try {
      _db = FirebaseFirestore.instance;
      return _db;
    } catch (error) {
      debugPrint('Firestore unavailable: $error');
      return null;
    }
  }

  Future<void> _loadLocalAvatar(String uid, int generation) async {
    Uint8List? decoded;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kAvatarKeyPrefix$uid');
      if (raw != null && raw.isNotEmpty) {
        decoded = base64Decode(raw);
      }
    } catch (error) {
      debugPrint('Local profile avatar load failed: $error');
    }
    if (!_isCurrent(uid, generation)) return;
    _avatarBytes ??= decoded;
    notifyListeners();
  }

  Future<void> _loadLocalProfile(String uid, int generation) async {
    String? displayName;
    String? email;
    String? about;
    String? kingdom;
    bool? complete;
    try {
      final prefs = await SharedPreferences.getInstance();
      displayName = prefs.getString('$_kNameKeyPrefix$uid');
      email = prefs.getString('$_kEmailKeyPrefix$uid');
      about = prefs.getString('$_kAboutKeyPrefix$uid');
      kingdom = prefs.getString('$_kKingdomKeyPrefix$uid');
      complete = prefs.getBool('$_kProfileCompleteKeyPrefix$uid');
    } catch (error) {
      debugPrint('Local profile load failed: $error');
    }

    if (!_isCurrent(uid, generation)) return;
    _displayName ??= displayName?.trim().nullIfEmpty;
    _email ??= email?.trim().nullIfEmpty;
    _about ??= about == null ? null : normalizeAbout(about);
    _kingdom ??= kingdom?.trim().nullIfEmpty;
    if (!_remoteCompletionAuthoritative) {
      _profileComplete = complete ??
          (_profileComplete ||
              inferProfileComplete(
                displayName: _displayName,
                kingdom: _kingdom,
              ));
    }
    _localProfileResolved = true;
    _updateHydration();
    notifyListeners();
  }

  Future<void> _persistLocalProfile(String uid, int generation) async {
    if (!_isCurrent(uid, generation) || _purgedUserIds.contains(uid)) return;
    final displayName = _displayName?.trim();
    final email = _email?.trim();
    final about = _about;
    final kingdom = _kingdom?.trim();
    final complete = _profileComplete;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_isCurrent(uid, generation) || _purgedUserIds.contains(uid)) {
        return;
      }
      if (displayName != null && displayName.isNotEmpty) {
        await prefs.setString('$_kNameKeyPrefix$uid', displayName);
      }
      if (email != null && email.isNotEmpty) {
        await prefs.setString('$_kEmailKeyPrefix$uid', email);
      }
      if (about != null && about.trim().isNotEmpty) {
        await prefs.setString(
          '$_kAboutKeyPrefix$uid',
          normalizeAbout(about),
        );
      }
      if (kingdom != null && kingdom.isNotEmpty) {
        await prefs.setString('$_kKingdomKeyPrefix$uid', kingdom);
      }
      await prefs.setBool('$_kProfileCompleteKeyPrefix$uid', complete);
    } catch (error) {
      debugPrint('Local profile persistence failed: $error');
    }
  }

  Future<void> setLocalProfile({
    String? displayName,
    String? email,
    String? about,
    String? kingdom,
    bool? profileComplete,
  }) async {
    final uid = _userId;
    final generation = _bindingGeneration;
    if (uid == null || !_isCurrent(uid, generation)) return;

    if (displayName != null && displayName.trim().isNotEmpty) {
      _displayName = displayName.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      _email = email.trim();
    }
    if (about != null) {
      _about = normalizeAbout(about);
    }
    if (kingdom != null && kingdom.trim().isNotEmpty) {
      _kingdom = kingdom.trim();
    }
    if (profileComplete != null) {
      _profileComplete = profileComplete;
    } else if (!_remoteCompletionAuthoritative) {
      _profileComplete = _profileComplete ||
          inferProfileComplete(
            displayName: _displayName,
            kingdom: _kingdom,
          );
    }
    _localProfileResolved = true;
    _updateHydration();
    notifyListeners();
    await _persistLocalProfile(uid, generation);
  }

  /// Returns false when the local change was saved but remote sync failed.
  Future<bool> updateAbout(String about) async {
    final uid = _userId;
    final generation = _bindingGeneration;
    if (uid == null || !_isCurrent(uid, generation)) return false;

    final safe = normalizeAbout(about);
    _about = safe;
    notifyListeners();
    await _persistLocalProfile(uid, generation);
    if (!_isCurrent(uid, generation)) return false;

    final db = _dbOrNull();
    if (db == null) return false;
    try {
      await db.collection('users').doc(uid).set(
        <String, Object?>{
          'updatedAt': FieldValue.serverTimestamp(),
          'about': safe,
        },
        SetOptions(merge: true),
      );
      return _isCurrent(uid, generation);
    } catch (error) {
      debugPrint('Failed to update about: $error');
      return false;
    }
  }

  Future<void> setLocalAvatarBytes(
    Uint8List bytes, {
    String? uidOverride,
  }) async {
    final uid = uidOverride?.trim().nullIfEmpty ?? _userId;
    if (uid == null || _purgedUserIds.contains(uid)) return;
    final generation = _bindingGeneration;
    if (_isCurrent(uid, generation)) {
      _avatarBytes = bytes;
      notifyListeners();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_kAvatarKeyPrefix$uid',
        base64Encode(bytes),
      );
    } catch (error) {
      debugPrint('Local avatar persistence failed: $error');
    }
  }

  Future<void> clearLocalAvatar({String? uidOverride}) async {
    final uid = uidOverride?.trim().nullIfEmpty ?? _userId;
    if (uid == null) return;
    final generation = _bindingGeneration;
    if (_isCurrent(uid, generation)) {
      _avatarBytes = null;
      notifyListeners();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kAvatarKeyPrefix$uid');
    } catch (error) {
      debugPrint('Local avatar removal failed: $error');
    }
  }

  /// Removes every device-local profile value associated with [uid].
  ///
  /// This is intentionally separate from [clearProfile], which only clears
  /// in-memory state during a normal sign-out. Account deletion must also
  /// erase the cached email, name, profile fields, and avatar bytes.
  Future<void> purgeLocalDataForUser(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;
    _purgedUserIds.add(normalizedUid);
    if (_userId == normalizedUid) _startBinding(null);

    final prefs = await SharedPreferences.getInstance();
    await Future.wait<bool>(<Future<bool>>[
      prefs.remove('$_kAvatarKeyPrefix$normalizedUid'),
      prefs.remove('$_kNameKeyPrefix$normalizedUid'),
      prefs.remove('$_kEmailKeyPrefix$normalizedUid'),
      prefs.remove('$_kAboutKeyPrefix$normalizedUid'),
      prefs.remove('$_kKingdomKeyPrefix$normalizedUid'),
      prefs.remove('$_kProfileCompleteKeyPrefix$normalizedUid'),
    ]);
  }

  Future<void> loadProfile(Map<String, dynamic> data) async {
    _displayName = data['displayName'] as String?;
    _email = data['email'] as String?;
    _avatarUrl = data['avatarUrl'] as String?;
    _userId = data['userId'] as String?;
    _rank = data['rank'] as String?;
    _kingdom = data['kingdom'] as String?;
    _profileComplete = data['profileComplete'] as bool? ??
        inferProfileComplete(
          displayName: _displayName,
          kingdom: _kingdom,
        );
    _profileHydrated = true;
    _localProfileResolved = true;
    _remoteProfileResolved = true;
    _remoteCompletionAuthoritative = data.containsKey('profileComplete');
    notifyListeners();
  }

  void updateDisplayName(String newName) {
    _displayName = newName;
    notifyListeners();
  }

  void updateAvatar(String newUrl) {
    _avatarUrl = newUrl;
    notifyListeners();
  }

  void clearProfile() {
    _startBinding(null);
  }

  @override
  void dispose() {
    _bindingGeneration++;
    _remoteHydrationTimer?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
