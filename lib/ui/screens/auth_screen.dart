// lib/ui/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart'; // Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_mode_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/profile_setup_screen.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/stadium_banner.dart';

String friendlyAuthErrorMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-email' => 'Enter a valid email address.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' =>
      'The email or password is incorrect.',
    'email-already-in-use' =>
      'An account already exists for this email. Try logging in.',
    'weak-password' => 'Choose a stronger password with at least 6 characters.',
    'network-request-failed' =>
      'Could not connect. Check your internet connection and try again.',
    'too-many-requests' =>
      'Too many attempts. Please wait a little before trying again.',
    'operation-not-allowed' => 'This sign-in option is currently unavailable.',
    'popup-closed-by-user' ||
    'cancelled-popup-request' =>
      'Google sign-in was cancelled.',
    _ => 'Authentication could not be completed. Please try again.',
  };
}

class AuthScreen extends StatefulWidget {
  final bool requireRegisteredUser;
  final Widget? postAuthDestination;
  final String? title;
  final String? message;
  final bool managedByAuthGate;
  final FirebaseAuth? authOverride;

  const AuthScreen({
    super.key,
    this.requireRegisteredUser = false,
    this.postAuthDestination,
    this.title,
    this.message,
    this.managedByAuthGate = false,
    this.authOverride,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _bannerAsset = 'assets/images/banner.png';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  FirebaseAuth? _auth;

  FirebaseAuth? _authOrNull() {
    if (widget.authOverride != null) return widget.authOverride;
    try {
      _auth ??= FirebaseAuth.instance;
      return _auth;
    } catch (e) {
      debugPrint('FirebaseAuth not available: $e');
      return null;
    }
  }

  bool _isLogin = true;
  bool _isLoading = false;
  bool _showPassword = false;
  String? _errorText;
  String? _statusText;

  bool get _googleSignInAvailable =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorText = message;
      _statusText = null;
    });
  }

  void _showStatus(String message) {
    if (!mounted) return;
    setState(() {
      _statusText = message;
      _errorText = null;
    });
  }

  void _setLoading(bool value) {
    if (!mounted) return;
    setState(() => _isLoading = value);
  }

  Future<void> _upsertUserDoc(
    User user, {
    String? username,
    String? about,
    String? kingdom,
    bool? profileComplete,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      final doc = db.collection('users').doc(user.uid);
      final snap = await doc.get();
      final now = FieldValue.serverTimestamp();

      final data = <String, Object?>{
        'email': user.email,
        'username': username?.trim(),
        'displayName': (user.displayName ?? username)?.trim(),
        'kingdom': kingdom?.trim(),
        'about': ProfileService.normalizeAbout(about),
        'profileComplete': profileComplete,
        'schemaVersion': 1,
        'updatedAt': now,
      };
      final u = (data['username'] as String?)?.trim();
      if (u != null && u.length < 3) {
        data.remove('username');
      }
      if (!snap.exists) {
        data['createdAt'] = now;
      }
      data.removeWhere(
        (key, value) =>
            value == null || (value is String && value.trim().isEmpty),
      );

      await doc.set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to upsert user profile: $e');
    }
  }

  Future<void> _submitAuthForm() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final isValid = email.contains('@') && password.length >= 6;
    if (!isValid) {
      _showError('Enter a valid email and a password of 6+ characters.');
      return;
    }

    final submittingLogin = _isLogin;
    _setLoading(true);
    if (mounted) {
      setState(() {
        _errorText = null;
        _statusText = null;
      });
    }
    try {
      final auth = _authOrNull();
      if (auth == null) {
        _showError(
          'Sign-in is unavailable right now. Please restart and try again.',
        );
        return;
      }

      final UserCredential credential;
      if (submittingLogin) {
        credential = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      final user = credential.user ?? auth.currentUser;
      if (user == null) {
        _showError('Sign-in did not finish. Please try again.');
        return;
      }

      _bindRegisteredUserServices(user);
      await _upsertUserDoc(
        user,
        profileComplete: submittingLogin ? null : false,
      );
      if (!mounted) return;
      await context.read<ProfileService>().setLocalProfile(
            displayName: user.displayName,
            email: user.email,
            profileComplete: submittingLogin ? null : false,
          );
      if (!mounted) return;
      await _completeAuth(user);
    } on FirebaseAuthException catch (error) {
      _showError(friendlyAuthErrorMessage(error));
    } catch (error) {
      debugPrint('Email authentication failed: $error');
      _showError(
        'Authentication could not be completed. Please try again.',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showError('Enter your email address first.');
      return;
    }

    _setLoading(true);
    try {
      final auth = _authOrNull();
      if (auth == null) {
        _showError(
          'Password reset is unavailable right now. Please try again later.',
        );
        return;
      }
      await auth.sendPasswordResetEmail(email: email);
      _showStatus(
        'If an account exists for that email, a reset link has been sent.',
      );
    } on FirebaseAuthException catch (error) {
      _showError(friendlyAuthErrorMessage(error));
    } catch (error) {
      debugPrint('Password reset failed: $error');
      _showError(
        'Password reset could not be completed. Please try again.',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    if (!_googleSignInAvailable) {
      _showError(
        'Google sign-in is not configured for this iOS build. '
        'Use email sign-in instead.',
      );
      return;
    }
    _setLoading(true);
    if (mounted) {
      setState(() {
        _errorText = null;
        _statusText = null;
      });
    }
    try {
      final auth = _authOrNull();
      if (auth == null) {
        _showError(
          'Google sign-in is unavailable right now. Please try again later.',
        );
        return;
      }

      UserCredential userCred;
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        userCred = await auth.signInWithPopup(provider);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          _showStatus('Google sign-in was cancelled.');
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCred = await auth.signInWithCredential(credential);
      }

      final user = userCred.user ?? auth.currentUser;
      if (user != null) {
        final isNewUser = userCred.additionalUserInfo?.isNewUser == true;
        _bindRegisteredUserServices(user);
        await _upsertUserDoc(
          user,
          profileComplete: isNewUser ? false : null,
        );
        if (mounted) {
          await context.read<ProfileService>().setLocalProfile(
                displayName: user.displayName,
                email: user.email,
                profileComplete: isNewUser ? false : null,
              );
        }
        if (!mounted) return;
        await _completeAuth(user);
      } else {
        _showError('Google sign-in did not finish. Please try again.');
      }
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'Google Sign-In failed (${error.code}): ${error.message}',
      );
      _showError(friendlyAuthErrorMessage(error));
    } catch (error) {
      debugPrint('Google Sign-In failed: $error');
      _showError('Google sign-in could not be completed. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _continueAsGuest() async {
    if (_isLoading) return;
    _setLoading(true);
    try {
      final auth = _authOrNull();
      if (auth == null) {
        await _continueAsLocalGuest();
        return;
      }
      final credential = await auth.signInAnonymously();
      final user = credential.user ?? auth.currentUser;
      if (user == null || !user.isAnonymous) {
        await _continueAsLocalGuest();
        return;
      }
      if (!mounted) return;
      if (widget.managedByAuthGate) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameModeScreen()),
      );
    } on FirebaseAuthException catch (error) {
      debugPrint('Guest login failed (${error.code}): ${error.message}');
      await _continueAsLocalGuest();
    } catch (error) {
      debugPrint('Guest login failed: $error');
      await _continueAsLocalGuest();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _continueAsLocalGuest() async {
    if (!mounted) return;
    try {
      context.read<AuthService>().continueAsLocalGuest();
      if (widget.managedByAuthGate) return;
    } on ProviderNotFoundException {
      // Isolated screens can still enter the local-only Quick Game flow.
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameModeScreen()),
    );
  }

  Future<void> _completeAuth(User user) async {
    if (!mounted) return;
    if (widget.requireRegisteredUser && user.isAnonymous) {
      _showError('Login or register to save Career progress.');
      return;
    }
    if (widget.managedByAuthGate) return;

    if (user.isAnonymous) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameModeScreen()),
      );
      return;
    }

    final destination = widget.postAuthDestination ?? const GameModeScreen();
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _RegisteredProfileDestination(
          userId: user.uid,
          destination: destination,
        ),
      ),
    );
  }

  void _bindRegisteredUserServices(User user) {
    if (user.isAnonymous || !mounted) return;
    try {
      context.read<AuraPointsService>().bindUserId(
            user.uid,
            registeredUser: true,
          );
    } on ProviderNotFoundException {
      // Some isolated widget tests intentionally omit app-level services.
    }
    try {
      context.read<CampaignProgressService>().bindUserId(user.uid);
    } on ProviderNotFoundException {
      // Some isolated widget tests intentionally omit app-level services.
    }
    try {
      context.read<ProfileService>().bindUserId(user.uid);
    } on ProviderNotFoundException {
      // The app always provides this service; tests may not.
    }
  }

  // ---------- Footer popups ----------
  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF101010),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'About Us',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        splashRadius: 18,
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Just a passion project',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  const Text(
                    'The Author would like to stay anonymous.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSupportDialog() {
    const email = 'pooniaone@gmail.com';
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF101010),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.support_agent, color: AppColors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Support',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        splashRadius: 18,
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '"THE WILD DOESN\'T FOLD"',
                    style: TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text('Hey there!',
                      style: TextStyle(color: Colors.white70)),
                  const Text('Meet Renoir',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(Icons.mail_outline, size: 18, color: AppColors.blue),
                      SizedBox(width: 8),
                      Text('pooniaone@gmail.com',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            const ClipboardData(text: email));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email copied')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy,
                          color: AppColors.blue, size: 18),
                      label: const Text('Copy Email',
                          style: TextStyle(color: AppColors.blue)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _field(String label, {Widget? suffixIcon}) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.white),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white10,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.blue),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      );

  Widget _clickable(Widget child) {
    return MouseRegion(cursor: SystemMouseCursors.click, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    final compactHeader = screenH < 520;
    const bannerScale = 0.75;
    final bannerMaxH = (compactHeader ? 48.0 : 72.0) * bannerScale;
    final bannerMaxW = (compactHeader ? 280.0 : 420.0) * bannerScale;

    return Scaffold(
      backgroundColor: AppColors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(
            bottom: media.viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      StadiumBanner(
                        asset: _bannerAsset,
                        maxHeight: bannerMaxH,
                        maxWidth: bannerMaxW,
                      ),
                      const SizedBox(height: 18),
                      if (widget.title != null || widget.message != null) ...[
                        if (widget.title != null)
                          Text(
                            widget.title!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        if (widget.message != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.message!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                      ],
                      TextField(
                        key: const ValueKey('auth_email'),
                        controller: _emailController,
                        enabled: !_isLoading,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        style: const TextStyle(color: AppColors.white),
                        decoration: _field('Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('auth_password'),
                        controller: _passwordController,
                        enabled: !_isLoading,
                        autofillHints: [
                          _isLogin
                              ? AutofillHints.password
                              : AutofillHints.newPassword,
                        ],
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        onSubmitted:
                            _isLoading ? null : (_) => _submitAuthForm(),
                        style: const TextStyle(color: AppColors.white),
                        decoration: _field(
                          'Password',
                          suffixIcon: IconButton(
                            tooltip: _showPassword
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: _isLoading
                                ? null
                                : () => setState(
                                      () => _showPassword = !_showPassword,
                                    ),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      if (_isLogin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: const ValueKey('forgot_password'),
                            onPressed: _isLoading ? null : _sendPasswordReset,
                            child: const Text('Forgot password?'),
                          ),
                        )
                      else
                        const SizedBox(height: 12),
                      if (_errorText case final error?)
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              error,
                              key: const ValueKey('auth_error'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFF8A80),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      if (_statusText case final status?)
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              status,
                              key: const ValueKey('auth_status'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF9BE7A5),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      _AuthPillButton(
                        label: _isLoading
                            ? (_isLogin ? 'Logging in…' : 'Registering…')
                            : (_isLogin ? 'Login' : 'Register'),
                        backgroundColor: AppColors.red,
                        textColor: AppColors.white,
                        onPressed: _isLoading ? null : _submitAuthForm,
                      ),
                      _AuthPillButton(
                        label: _isLogin
                            ? 'Create new account'
                            : 'Already have an account? Login',
                        backgroundColor: const Color(0xFF2E3238),
                        textColor: AppColors.white,
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                                  _isLogin = !_isLogin;
                                  _errorText = null;
                                  _statusText = null;
                                }),
                      ),
                      if (!widget.requireRegisteredUser) ...[
                        _AuthPillButton(
                          label: 'Continue as Guest',
                          backgroundColor: const Color(0xFF24B6FF),
                          textColor: Colors.white,
                          onPressed: _isLoading ? null : _continueAsGuest,
                        ),
                        const SizedBox(height: 10),
                      ],
                      _AuthPillButton(
                        label: _googleSignInAvailable
                            ? 'Sign in with Google'
                            : 'Google sign-in unavailable on iOS',
                        icon: Icons.g_mobiledata,
                        iconSize: 28,
                        backgroundColor: AppColors.white,
                        textColor: AppColors.white,
                        onPressed: _isLoading || !_googleSignInAvailable
                            ? null
                            : _signInWithGoogle,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _clickable(
                            _AuthFooterPillLink(
                              onPressed: _showAboutDialog,
                              label: 'About Us',
                            ),
                          ),
                          _clickable(
                            _AuthFooterPillLink(
                              onPressed: _showSupportDialog,
                              label: 'Support',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisteredProfileDestination extends StatelessWidget {
  final String userId;
  final Widget destination;

  const _RegisteredProfileDestination({
    required this.userId,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileService>();
    if (profile.userId != userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        profile.bindUserId(userId);
      });
      return const _ProfileLoading();
    }
    if (!profile.isHydrated) return const _ProfileLoading();
    if (profile.profileComplete) return destination;
    return ProfileSetupScreen(destination: destination);
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Center(
        child: Semantics(
          liveRegion: true,
          label: 'Loading your profile',
          child: const CircularProgressIndicator(color: AppColors.blue),
        ),
      ),
    );
  }
}

class _AuthPillButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final double iconSize;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onPressed;

  const _AuthPillButton({
    required this.label,
    this.icon,
    this.iconSize = 20,
    required this.backgroundColor,
    required this.textColor,
    this.onPressed,
  });

  @override
  State<_AuthPillButton> createState() => _AuthPillButtonState();
}

class _AuthPillButtonState extends State<_AuthPillButton> {
  static const StadiumBorder _shape = StadiumBorder();
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final bool emphasized = _hover || _pressed;
    final Color borderColor = !enabled
        ? widget.backgroundColor.withValues(alpha: 0.35)
        : (emphasized
            ? widget.backgroundColor
            : widget.backgroundColor.withValues(alpha: 0.95));
    final Color bg = !enabled
        ? widget.backgroundColor.withValues(alpha: 0.12)
        : (_pressed
            ? widget.backgroundColor.withValues(alpha: 0.45)
            : (_hover
                ? widget.backgroundColor.withValues(alpha: 0.36)
                : widget.backgroundColor.withValues(alpha: 0.28)));
    final double borderWidth =
        !enabled ? 2.6 : (_pressed ? 4.0 : (_hover ? 3.6 : 3.2));
    final List<BoxShadow> glow = !enabled
        ? const []
        : [
            BoxShadow(
              color: borderColor.withValues(alpha: emphasized ? 0.62 : 0.55),
              blurRadius: emphasized ? 18 : 14,
              spreadRadius: emphasized ? 2.2 : 1.4,
            ),
          ];

    return SizedBox(
      height: 48,
      width: double.infinity,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: MouseRegion(
          onEnter: enabled ? (_) => setState(() => _hover = true) : null,
          onExit: (_) => setState(() {
            _hover = false;
            _pressed = false;
          }),
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Material(
            type: MaterialType.transparency,
            shape: _shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTapDown:
                  enabled ? (_) => setState(() => _pressed = true) : null,
              onTapCancel:
                  enabled ? () => setState(() => _pressed = false) : null,
              onTap: enabled
                  ? () {
                      setState(() => _pressed = false);
                      widget.onPressed!();
                    }
                  : null,
              customBorder: _shape,
              splashColor: Colors.white10,
              highlightColor: Colors.white.withValues(alpha: 0.05),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: ShapeDecoration(
                  color: bg,
                  shape: StadiumBorder(
                    side: BorderSide(color: borderColor, width: borderWidth),
                  ),
                  shadows: glow,
                ),
                child: Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            size: widget.iconSize,
                            color: widget.textColor,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.textColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              height: 1.0,
                              letterSpacing: 0.2,
                              shadows: const [
                                Shadow(
                                  blurRadius: 8,
                                  offset: Offset(0, 1),
                                  color: Colors.black38,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthFooterPillLink extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _AuthFooterPillLink({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue,
        backgroundColor: Colors.transparent,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        side: BorderSide(
          color: AppColors.blue.withValues(alpha: 0.85),
          width: 1.2,
        ),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.15,
        ),
      ),
      child: Text(label),
    );
  }
}
