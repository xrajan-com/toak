import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? _auth;

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
  Future<void> logout() async {
    final auth = _authOrNull();
    if (auth == null) return;
    try {
      await auth.signOut();
      notifyListeners();
    } catch (e) {
      debugPrint('Logout failed: $e');
    }
  }

  // 🔐 Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final auth = _authOrNull();
      if (auth == null) return null;

      final userCredential = await auth.signInWithCredential(credential);
      notifyListeners();
      return userCredential.user;
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
}
