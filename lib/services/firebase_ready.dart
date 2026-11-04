import 'package:firebase_core/firebase_core.dart';

/// Whether Firebase initialized. In a browser whose ad or privacy blocker
/// stopped the Firebase scripts, even asking throws; that counts as no, and
/// the game starts without accounts, analytics and App Check.
bool firebaseReady() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}
