import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:ten_of_a_kind_poker/services/api_client.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? _auth;
  StreamSubscription<User?>? _authSub;
  final ApiClient _apiClient;
  bool _isLocalGuest = false;

  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient() {
    final auth = _authOrNull();
    _authSub = auth?.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  FirebaseAuth? _authOrNull() {
    try {
      _auth ??= FirebaseAuth.instance;
      return _auth;
    } catch (e) {
      debugPrint('FirebaseAuth not available: $e');
      return null;
    }
  }

  User? get currentUser {
    try {
      return _authOrNull()?.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isLoggedIn => currentUser != null;

  /// True when the player chose guest play while Firebase Auth was unavailable.
  ///
  /// Quick Game is fully local, so a cloud outage must not block this path.
  bool get isLocalGuest => _isLocalGuest;

  void continueAsLocalGuest() {
    if (_isLocalGuest) return;
    _isLocalGuest = true;
    notifyListeners();
  }

  Stream<User?> get authStateChanges =>
      _authOrNull()?.authStateChanges() ?? Stream<User?>.empty();

  // 🔐 Sign in with Email & Password
  Future<User?> signInWithEmail(String email, String password) async {
    final auth = _authOrNull();
    if (auth == null) return null;
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return credential.user;
    } catch (e) {
      debugPrint('Email sign-in failed: $e');
      return null;
    }
  }

  // 🆕 Register with Email & Password
  Future<User?> registerWithEmail(String email, String password) async {
    final auth = _authOrNull();
    if (auth == null) return null;
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return credential.user;
    } catch (e) {
      debugPrint('Email registration failed: $e');
      return null;
    }
  }

  // 🔄 Password Reset
  Future<void> resetPassword(String email) async {
    final auth = _authOrNull();
    if (auth == null) return;
    try {
      await auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password reset failed: $e');
    }
  }

  // 🔓 Sign out
  Future<bool> logout() async {
    if (_isLocalGuest) {
      _isLocalGuest = false;
      notifyListeners();
      return true;
    }
    final auth = _authOrNull();
    if (auth == null) return false;
    try {
      await auth.signOut();
      notifyListeners();
      return auth.currentUser == null;
    } catch (e) {
      debugPrint('Logout failed: $e');
      return false;
    }
  }

  /// Deletes the current account through the authenticated backend endpoint.
  ///
  /// [ApiException] is intentionally allowed through so the UI can distinguish
  /// a recent-login requirement from network and server failures.
  Future<AccountDeletionResult> deleteCurrentAccount() async {
    final result = await _apiClient.deleteCurrentAccount();
    if (result.deleted) {
      final auth = _authOrNull();
      try {
        await auth?.signOut();
      } catch (error) {
        debugPrint('Local sign-out after account deletion failed: $error');
      }
      notifyListeners();
    }
    return result;
  }

  // 🔐 Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final auth = _authOrNull();
      if (auth == null) return null;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        final userCredential = await auth.signInWithPopup(provider);
        notifyListeners();
        return userCredential.user;
      }

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await auth.signInWithCredential(credential);
      notifyListeners();
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google sign-in failed (${e.code}): ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      return null;
    }
  }

  // 👤 Anonymous Guest Login
  Future<User?> signInAnonymously() async {
    final auth = _authOrNull();
    if (auth == null) return null;
    try {
      final credential = await auth.signInAnonymously();
      notifyListeners();
      return credential.user;
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
