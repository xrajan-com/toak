import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/features/auth/auth_feature.dart';
import 'package:ten_of_a_kind_poker/features/venue/venue_feature.dart';
import 'package:ten_of_a_kind_poker/services/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AuthLoading();
        }
        final user = snapshot.data;
        if (user == null) return const AuthScreen();
        if (user.isAnonymous) return const GameModeScreen();
        return const VenueScreen(mode: VenueEntryMode.career);
      },
    );
  }
}

class AuthLoading extends StatelessWidget {
  const AuthLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white70),
      ),
    );
  }
}
