import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/features/auth/auth_feature.dart';
import 'package:ten_of_a_kind_poker/features/venue/venue_feature.dart';
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/profile_setup_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      initialData: auth.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AuthLoading();
        }
        if (snapshot.hasError) {
          return const _AuthStateError();
        }
        final user = snapshot.data;
        if (user == null) {
          return const AuthScreen(managedByAuthGate: true);
        }
        if (user.isAnonymous) return const GameModeScreen();

        final profile = context.watch<ProfileService>();
        if (profile.userId != user.uid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            profile.bindUserId(user.uid);
          });
          return const AuthLoading(message: 'Loading your profile…');
        }
        if (!profile.isHydrated) {
          return const AuthLoading(message: 'Loading your profile…');
        }
        if (!profile.profileComplete) {
          return ProfileSetupScreen(
            key: ValueKey(user.uid),
            managedByAuthGate: true,
          );
        }
        return const GameModeScreen();
      },
    );
  }
}

class AuthLoading extends StatelessWidget {
  final String message;

  const AuthLoading({
    super.key,
    this.message = 'Checking your account…',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Semantics(
          liveRegion: true,
          label: message,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white70),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthStateError extends StatelessWidget {
  const _AuthStateError();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'We could not check your account. Please check your connection '
              'and restart the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
