import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService extends ChangeNotifier {
  static const String defaultAbout = 'Plays the player, not cards';
  static const String _kAvatarKeyPrefix = 'profile.avatar.';
  static const String _kNameKeyPrefix = 'profile.name.';
  static const String _kEmailKeyPrefix = 'profile.email.';
  static const String _kAboutKeyPrefix = 'profile.about.';
  static const String _kKingdomKeyPrefix = 'profile.kingdom.';
  String? _displayName;
  String? _email;
  String? _avatarUrl;
  String? _userId;
  String? _rank;
  String? _about;
  String? _kingdom;
  Uint8List? _avatarBytes;
  FirebaseFirestore? _db;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  // Getters
  String? get displayName => _displayName;
  String? get email => _email;
  String? get avatarUrl => _avatarUrl;
  String? get userId => _userId;
  String? get rank => _rank;
  String? get about => _about ?? defaultAbout;
  String? get kingdom => _kingdom;
  Uint8List? get avatarBytes => _avatarBytes;

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

  void bindUserId(String? uid) {
    if (_userId == uid) return;
    _sub?.cancel();
    _sub = null;
    _userId = uid;
    _avatarBytes = null;
    _displayName = null;
    _email = null;
    _about = null;
    _kingdom = null;
    notifyListeners();
    if (uid == null || uid.trim().isEmpty) return;
    _loadLocalProfile(uid);
    _loadLocalAvatar(uid);
    _bindRemoteProfile(uid);
  }

  void _bindRemoteProfile(String uid) {
    final db = _dbOrNull();
    if (db == null) return;
    final doc = db.collection('users').doc(uid);
    _sub = doc.snapshots().listen(
      (snap) {
        final data = snap.data();
        if (data == null) return;
        _applyRemote(data, uid: uid);
      },
      onError: (e) => debugPrint('Profile stream error: $e'),
    );
  }

  void _applyRemote(Map<String, dynamic> data, {required String uid}) {
    _displayName = (data['displayName'] as String?)?.trim() ?? _displayName;
    _email = (data['email'] as String?)?.trim() ?? _email;
    final String? remoteAbout = (data['about'] as String?)?.trim();
    _about = remoteAbout == null
        ? (_about ?? defaultAbout)
        : normalizeAbout(remoteAbout);
    _kingdom = (data['kingdom'] as String?)?.trim() ?? _kingdom;
    notifyListeners();
    unawaited(_persistLocalProfile(uid));
  }

  FirebaseFirestore? _dbOrNull() {
    if (_db != null) return _db;
    try {
      _db = FirebaseFirestore.instance;
      return _db;
    } catch (e) {
      debugPrint('Firestore unavailable: $e');
      return null;
    }
  }

  Future<void> _loadLocalAvatar(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kAvatarKeyPrefix$uid');
      if (_userId != uid) return;
      if (raw == null || raw.isEmpty) {
        _avatarBytes = null;
      } else {
        _avatarBytes = base64Decode(raw);
      }
    } catch (_) {
      _avatarBytes = null;
    }
    if (_userId == uid) notifyListeners();
  }

  Future<void> _loadLocalProfile(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _displayName = prefs.getString('$_kNameKeyPrefix$uid');
      _email = prefs.getString('$_kEmailKeyPrefix$uid');
      _about = normalizeAbout(prefs.getString('$_kAboutKeyPrefix$uid'));
      _kingdom = prefs.getString('$_kKingdomKeyPrefix$uid');
      notifyListeners();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _persistLocalProfile(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_displayName != null && _displayName!.trim().isNotEmpty) {
        await prefs.setString('$_kNameKeyPrefix$uid', _displayName!.trim());
      }
      if (_email != null && _email!.trim().isNotEmpty) {
        await prefs.setString('$_kEmailKeyPrefix$uid', _email!.trim());
      }
      if (_about != null && _about!.trim().isNotEmpty) {
        final safe = normalizeAbout(_about);
        await prefs.setString('$_kAboutKeyPrefix$uid', safe);
      }
      if (_kingdom != null && _kingdom!.trim().isNotEmpty) {
        await prefs.setString('$_kKingdomKeyPrefix$uid', _kingdom!.trim());
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> setLocalProfile({
    String? displayName,
    String? email,
    String? about,
    String? kingdom,
  }) async {
    final uid = _userId;
    if (uid == null || uid.trim().isEmpty) return;
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
    notifyListeners();
    await _persistLocalProfile(uid);
  }

  Future<void> updateAbout(String about) async {
    final uid = _userId;
    if (uid == null || uid.trim().isEmpty) return;
    final safe = normalizeAbout(about);
    _about = safe;
    notifyListeners();
    await _persistLocalProfile(uid);

    final db = _dbOrNull();
    if (db == null) return;
    try {
      final updates = <String, Object?>{
        'updatedAt': FieldValue.serverTimestamp(),
        'about': safe,
      };
      await db.collection('users').doc(uid).set(
            updates,
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Failed to update about: $e');
    }
  }

  Future<void> setLocalAvatarBytes(
    Uint8List bytes, {
    String? uidOverride,
  }) async {
    final uid = uidOverride ?? _userId;
    if (uid == null || uid.trim().isEmpty) return;
    _avatarBytes = bytes;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_kAvatarKeyPrefix$uid',
        base64Encode(bytes),
      );
    } catch (_) {
      // ignore persistence failures
    }
  }

  Future<void> clearLocalAvatar({String? uidOverride}) async {
    final uid = uidOverride ?? _userId;
    if (uid == null || uid.trim().isEmpty) return;
    _avatarBytes = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kAvatarKeyPrefix$uid');
    } catch (_) {
      // ignore persistence failures
    }
  }

  // Load profile from a data source (e.g., Firebase, REST API)
  Future<void> loadProfile(Map<String, dynamic> data) async {
    _displayName = data['displayName'];
    _email = data['email'];
    _avatarUrl = data['avatarUrl'];
    _userId = data['userId'];
    _rank = data['rank'];
    notifyListeners();
  }

  // Update display name
  void updateDisplayName(String newName) {
    _displayName = newName;
    notifyListeners();
    // TODO: Persist to backend
  }

  // Update avatar URL
  void updateAvatar(String newUrl) {
    _avatarUrl = newUrl;
    notifyListeners();
    // TODO: Persist to backend
  }

  // Clear profile on logout
  void clearProfile() {
    _displayName = null;
    _email = null;
    _avatarUrl = null;
    _userId = null;
    _rank = null;
    _about = null;
    _kingdom = null;
    _avatarBytes = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
