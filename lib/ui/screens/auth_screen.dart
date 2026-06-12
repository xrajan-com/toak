// lib/ui/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart'; // Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';
import 'package:ten_of_a_kind_poker/features/venue/game_mode.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_mode_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/profile_setup_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/venue_screen.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/stadium_banner.dart';

class AuthScreen extends StatefulWidget {
  final bool requireRegisteredUser;
  final Widget? postAuthDestination;
  final String? title;
  final String? message;

  const AuthScreen({
    super.key,
    this.requireRegisteredUser = false,
    this.postAuthDestination,
    this.title,
    this.message,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _bannerAsset = 'assets/images/banner.png';
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

  FirebaseAuth? _authOrNotify() {
    final auth = _authOrNull();
    if (auth == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Auth unavailable. Check Firebase setup.')),
      );
    }
    return auth;
  }

  bool _isLogin = true;
  String _email = '';
  String _password = '';
  bool _isLoading = false;

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
    final isValid = _email.isNotEmpty && _password.length >= 6;
    if (!isValid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter a valid email and 6+ char password')),
      );
      return;
    }

    try {
      if (mounted) setState(() => _isLoading = true);
      User? signedInUser;

      if (_isLogin) {
        final auth = _authOrNotify();
        if (auth == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Auth unavailable. Check Firebase setup.'),
              ),
            );
          }
          if (!widget.requireRegisteredUser) {
            await _enterGame(reason: 'email-auth-unavailable');
          }
          return;
        }
        final cred = await auth.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        final user = cred.user;
        signedInUser = user;
        if (user != null) {
          await _upsertUserDoc(user);
          if (mounted) {
            await context.read<ProfileService>().setLocalProfile(
                  displayName: user.displayName,
                  email: user.email,
                );
          }
        }
      } else {
        final auth = _authOrNotify();
        if (auth == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Auth unavailable. Check Firebase setup.'),
              ),
            );
          }
          if (!widget.requireRegisteredUser) {
            await _enterGame(reason: 'register-auth-unavailable');
          }
          return;
        }
        final userCred = await auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        final user = userCred.user;
        signedInUser = user;
        if (user != null) {
          await _upsertUserDoc(
            user,
            profileComplete: false,
          );
          if (mounted) {
            await context.read<ProfileService>().setLocalProfile(
                  email: user.email,
                );
          }
        }
      }

      if (mounted) {
        await _enterGame(
          reason: signedInUser != null ? 'email' : 'email-null-user',
          needsProfileSetup: !_isLogin && signedInUser != null,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Authentication error')),
      );
      if (!widget.requireRegisteredUser) {
        await _enterGame(reason: 'email-auth-error');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication error')),
      );
      if (!widget.requireRegisteredUser) {
        await _enterGame(reason: 'email-auth-exception');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    if (mounted) setState(() => _isLoading = true);
    try {
      final auth = _authOrNotify();
      if (auth == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Auth unavailable. Check Firebase setup.'),
            ),
          );
          if (!widget.requireRegisteredUser) {
            await _enterGame(reason: 'google-auth-unavailable');
          }
        }
        return;
      }

      UserCredential userCred;
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        userCred = await auth.signInWithPopup(provider);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Google sign-in cancelled.')),
            );
          }
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
        final bool isNewUser = userCred.additionalUserInfo?.isNewUser == true;
        await _upsertUserDoc(
          user,
          profileComplete: isNewUser ? false : null,
        );
        if (mounted) {
          await context.read<ProfileService>().setLocalProfile(
                displayName: user.displayName,
                email: user.email,
              );
        }
        if (mounted) {
          await _enterGame(
            reason: 'google',
            needsProfileSetup: isNewUser,
          );
        }
      } else if (mounted) {
        await _enterGame(reason: 'google-null-user');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Google Sign-In failed (${e.code}): ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Google sign-in failed')),
      );
      if (!widget.requireRegisteredUser) {
        await _enterGame(reason: 'google-auth-error');
      }
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google sign-in failed')),
      );
      if (!widget.requireRegisteredUser) {
        await _enterGame(reason: 'google-auth-exception');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    if (_isLoading) return;
    if (mounted) setState(() => _isLoading = true);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Continuing as guest...')),
        );
      }
      final auth = _authOrNull();
      if (auth != null) {
        try {
          final cred = await auth.signInAnonymously();
          final user = cred.user ?? auth.currentUser;
          if (user == null) {
            debugPrint('Guest sign-in returned null user');
          }
        } catch (e) {
          debugPrint('Guest sign-in failed (non-fatal): $e');
        }
      } else {
        debugPrint('FirebaseAuth unavailable; using offline guest.');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Guest login failed (${e.code}): ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Guest sign-in failed')),
        );
      }
    } catch (e) {
      debugPrint('Guest login failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guest sign-in failed')),
        );
      }
    }
    if (!mounted) return;
    await _enterGame(reason: 'guest');
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _enterGame({
    String? reason,
    bool needsProfileSetup = false,
  }) async {
    if (!mounted) return;
    if (reason != null) {
      debugPrint('AuthScreen: entering game ($reason)');
    }
    final user = _authOrNull()?.currentUser;
    if (widget.requireRegisteredUser) {
      if (user == null || user.isAnonymous) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login or register to save Career progress.'),
          ),
        );
        return;
      }
    }
    if (user != null && !user.isAnonymous) {
      _bindRegisteredUserServices(user);
    }
    final Widget destination =
        widget.postAuthDestination ?? _defaultDestination();
    final Widget next = needsProfileSetup && user != null && !user.isAnonymous
        ? ProfileSetupScreen(destination: destination)
        : destination;
    await Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(
        builder: (_) => next,
      ),
    );
  }

  void _bindRegisteredUserServices(User user) {
    context.read<AuraPointsService>().bindUserId(
          user.uid,
          registeredUser: true,
        );
    context.read<CampaignProgressService>().bindUserId(user.uid);
    context.read<ProfileService>().bindUserId(user.uid);
  }

  Widget _defaultDestination() {
    final user = _authOrNull()?.currentUser;
    if (user == null || user.isAnonymous) return const GameModeScreen();
    return const VenueScreen(mode: VenueEntryMode.career);
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
          child: Padding(
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
        );
      },
    );
  }

  void _showSupportDialog() {
    const email = 'xrajan.com@gmail.com';
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF101010),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
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
                    Text('xrajan.com@gmail.com',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(const ClipboardData(text: email));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email copied')),
                        );
                      }
                    },
                    icon:
                        const Icon(Icons.copy, color: AppColors.blue, size: 18),
                    label: const Text('Copy Email',
                        style: TextStyle(color: AppColors.blue)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _field(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.white),
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
      );

  Widget _clickable(Widget child) {
    return MouseRegion(cursor: SystemMouseCursors.click, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
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
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
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

            // -------- Common fields --------
            TextField(
              onChanged: (v) => _email = v.trim(),
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.white),
              decoration: _field('Email'),
            ),
            const SizedBox(height: 12),

            TextField(
              onChanged: (v) => _password = v,
              obscureText: true,
              style: const TextStyle(color: AppColors.white),
              decoration: _field('Password'),
            ),

            const SizedBox(height: 20),

            // -------- Submit --------
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.blue),
              )
            else
              _AuthPillButton(
                label: _isLogin ? 'Login' : 'Register',
                backgroundColor: AppColors.red,
                textColor: AppColors.white,
                onPressed: _submitAuthForm,
              ),

            // Switch login/register
            _AuthPillButton(
              label: _isLogin
                  ? 'Create new account'
                  : 'Already have an account? Login',
              backgroundColor: const Color(0xFF2E3238),
              textColor: AppColors.white,
              onPressed: () => setState(() => _isLogin = !_isLogin),
            ),

            if (!widget.requireRegisteredUser) ...[
              // Continue as Guest (blue)
              _AuthPillButton(
                label: 'Continue as Guest',
                backgroundColor: const Color(0xFF24B6FF),
                textColor: Colors.white,
                onPressed: _isLoading ? null : _continueAsGuest,
              ),
              const SizedBox(height: 10),
            ],

            // Google Sign-in
            _AuthPillButton(
              label: 'Sign in with Google',
              icon: Icons.g_mobiledata,
              iconSize: 28,
              backgroundColor: AppColors.white,
              textColor: AppColors.white,
              onPressed: _isLoading ? null : _signInWithGoogle,
            ),

            const SizedBox(height: 16),

            // -------- Footer links --------
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _clickable(
                  _AuthFooterPillLink(
                    onPressed: _showAboutDialog,
                    label: 'About Us',
                  ),
                ),
                const SizedBox(width: 10),
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
