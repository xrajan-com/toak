// lib/ui/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

// Pull real venue data (to use "India" as the default for guests)
import 'package:ten_of_a_kind_poker/config/venues.dart'
    show VenueTheme, internationalVenues;

import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;

  bool _isLogin = true;
  String _email = '';
  String _password = '';
  String _username = '';
  String _about = '';
  String? _selectedKingdom;
  Uint8List? _pickedImageBytes; // web-safe
  bool _isLoading = false;

  final List<String> _kingdoms = const [
    // 10 Indian Kingdoms
    'Maurya', 'Gupta', 'Mughal', 'Chola', 'Vijayanagara',
    'Maratha', 'Rajput', 'Ahom', 'Pallava', 'Pandya',
    // 10 International Kingdoms
    'Roman', 'Ottoman', 'British', 'French', 'Japanese',
    'Mongol', 'Greek', 'Chinese', 'Zulu', 'Persian',
  ];

  Future<void> _pickImage() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() => _pickedImageBytes = bytes);
    } catch (e) {
      debugPrint('Image pick failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick image')),
      );
    }
  }

  Future<void> _submitAuthForm() async {
    final isValid = _email.isNotEmpty && _password.length >= 6;
    if (!isValid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email and 6+ char password')),
      );
      return;
    }

    try {
      if (mounted) setState(() => _isLoading = true);

      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(email: _email, password: _password);
      } else {
        final userCred = await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        await userCred.user!.updateDisplayName(_username);
        if (_about.isNotEmpty) {
          debugPrint('Captured about (${_about.length} chars)');
        }
        // TODO: Upload _pickedImageBytes/_about/_selectedKingdom to Firestore/Storage
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Authentication error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google sign-in failed')),
      );
    }
  }

  Future<void> _continueAsGuest() async {
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      debugPrint('Guest login failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guest sign-in failed')),
      );
      return;
    }
    if (!mounted) return;

    // Use the real "India" venue from the International list
    final VenueTheme indiaVenue = internationalVenues.firstWhere(
      (v) => v.name == 'India',
      orElse: () => internationalVenues.first,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          tableName: '${indiaVenue.name} — Guest Table',
          venue: indiaVenue,
        ),
      ),
    );
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                const Text('Just a passion project', style: TextStyle(color: Colors.white70)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                  style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text('Hey there!', style: TextStyle(color: Colors.white70)),
                const Text('Meet Renoir', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.mail_outline, size: 18, color: AppColors.blue),
                    SizedBox(width: 8),
                    Text('xrajan.com@gmail.com', style: TextStyle(color: Colors.white70)),
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
                    icon: const Icon(Icons.copy, color: AppColors.blue, size: 18),
                    label: const Text('Copy Email', style: TextStyle(color: AppColors.blue)),
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
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.blue),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'TEN OF A KIND',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // -------- Registration-only fields --------
                      if (!_isLogin)
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white10,
                            foregroundImage: _pickedImageBytes != null
                                ? MemoryImage(_pickedImageBytes!)
                                : null,
                            child: _pickedImageBytes == null
                                ? const Icon(Icons.add_a_photo, color: AppColors.white)
                                : null,
                          ),
                        ),
                      if (!_isLogin) const SizedBox(height: 12),

                      if (!_isLogin)
                        TextField(
                          onChanged: (v) => _username = v,
                          style: const TextStyle(color: AppColors.white),
                          decoration: _field('Username'),
                        ),
                      if (!_isLogin) const SizedBox(height: 12),

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

                      // -------- Registration-only fields (cont.) --------
                      if (!_isLogin) const SizedBox(height: 12),
                      if (!_isLogin)
                        TextField(
                          onChanged: (v) => _about = v,
                          maxLines: 2,
                          style: const TextStyle(color: AppColors.white),
                          decoration: _field('About You'),
                        ),
                      if (!_isLogin) const SizedBox(height: 12),
                      if (!_isLogin)
                        DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF141414),
                          value: _selectedKingdom,
                          onChanged: (val) => setState(() => _selectedKingdom = val),
                          items: _kingdoms
                              .map(
                                (k) => DropdownMenuItem(
                                  value: k,
                                  child: Text(k, style: const TextStyle(color: AppColors.white)),
                                ),
                              )
                              .toList(),
                          decoration: _field('Select Kingdom'),
                          style: const TextStyle(color: AppColors.white),
                          iconEnabledColor: AppColors.white,
                        ),

                      const SizedBox(height: 20),

                      // -------- Submit --------
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(color: AppColors.blue),
                        )
                      else
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.red,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _submitAuthForm,
                            child: Text(_isLogin ? 'Login' : 'Register'),
                          ),
                        ),

                      // Switch login/register
                      TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin ? 'Create new account' : 'Already have an account? Login',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),

                      // Continue as Guest (blue)
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF24B6FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _continueAsGuest,
                          child: const Text(
                            'Continue as Guest',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Google Sign-in
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Sign in with Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _signInWithGoogle,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // -------- Footer links --------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _showAboutDialog,
                            child: const Text('About Us', style: TextStyle(color: AppColors.blue)),
                          ),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Colors.white24)),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _showSupportDialog,
                            child: const Text('Support', style: TextStyle(color: AppColors.blue)),
                          ),
                        ],
                      ),

                      const Spacer(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
