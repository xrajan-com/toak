import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/config/venues.dart'
    show kVenueGroups, venueGroupLabel, venuesForGroup;
import 'package:ten_of_a_kind_poker/services/profile_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_mode_screen.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/stadium_banner.dart';

class ProfileSetupScreen extends StatefulWidget {
  final Widget? destination;
  final bool managedByAuthGate;

  const ProfileSetupScreen({
    super.key,
    this.destination,
    this.managedByAuthGate = false,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const _bannerAsset = 'assets/images/banner.png';

  final _nameController = TextEditingController();
  final _aboutController = TextEditingController(
    text: ProfileService.defaultAbout,
  );
  Uint8List? _pickedImageBytes;
  String? _selectedKingdom;
  bool _saving = false;
  bool _seededFromProfile = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final user = _authOrNull()?.currentUser;
    final initialName = (user?.displayName ?? '').trim();
    if (initialName.isNotEmpty) {
      _nameController.text = initialName;
    } else {
      final email = (user?.email ?? '').trim();
      if (email.contains('@')) {
        _nameController.text = email.split('@').first.trim();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededFromProfile) return;
    _seededFromProfile = true;
    final profile = context.read<ProfileService>();
    final profileName = (profile.displayName ?? '').trim();
    if (_nameController.text.trim().isEmpty && profileName.isNotEmpty) {
      _nameController.text = profileName;
    }
    final profileKingdom = (profile.kingdom ?? '').trim();
    if (profileKingdom.isNotEmpty) {
      _selectedKingdom = profileKingdom;
    }
    _aboutController.text = ProfileService.normalizeAbout(profile.about);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  FirebaseAuth? _authOrNull() {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  List<DropdownMenuItem<String>> _kingdomMenuItems() {
    const headerStyle = TextStyle(
      color: Colors.white54,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
    );
    const itemStyle = TextStyle(color: AppColors.white);

    final items = <DropdownMenuItem<String>>[];

    void addGroup(String label, Iterable<String> names) {
      items.add(
        DropdownMenuItem<String>(
          value: null,
          enabled: false,
          child: Text(label, style: headerStyle),
        ),
      );
      for (final name in names) {
        items.add(
          DropdownMenuItem<String>(
            value: name,
            child: Text(name, style: itemStyle),
          ),
        );
      }
    }

    for (final group in kVenueGroups) {
      addGroup(
        venueGroupLabel(group).replaceAll(' Circuit', ''),
        venuesForGroup(group).map((venue) => venue.name),
      );
    }
    return items;
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      );

  Future<void> _pickImage() async {
    if (_saving) return;
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() => _pickedImageBytes = bytes);
    } catch (e) {
      debugPrint('Profile setup image pick failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick image')),
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final user = _authOrNull()?.currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login or register first.')),
      );
      return;
    }

    final displayName = _nameController.text.trim();
    final kingdom = _selectedKingdom?.trim() ?? '';
    if (displayName.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a 3+ character player name.')),
      );
      return;
    }
    if (kingdom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose your kingdom.')),
      );
      return;
    }

    final userId = user.uid;
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final about = ProfileService.normalizeAbout(_aboutController.text);
      if ((user.displayName ?? '').trim() != displayName) {
        await user.updateDisplayName(displayName);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        <String, Object?>{
          'email': user.email,
          'username': displayName,
          'displayName': displayName,
          'kingdom': kingdom,
          'about': about,
          'profileComplete': true,
          'schemaVersion': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final currentUser = _authOrNull()?.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        throw StateError('The signed-in account changed while saving.');
      }

      final profile = context.read<ProfileService>();
      profile.bindUserId(userId);
      await profile.setLocalProfile(
        displayName: displayName,
        email: user.email,
        about: about,
        kingdom: kingdom,
        profileComplete: true,
      );
      final bytes = _pickedImageBytes;
      if (bytes != null) {
        await profile.setLocalAvatarBytes(bytes);
      }

      if (!mounted) return;
      if (widget.managedByAuthGate) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => widget.destination ?? const GameModeScreen(),
        ),
      );
    } catch (error) {
      debugPrint('Profile setup save failed: $error');
      if (!mounted) return;
      setState(() {
        _errorText = error is StateError
            ? 'Your account changed. Please try again.'
            : 'We could not save your profile. Check your connection and retry.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    final compact = screenH < 540;
    final horizontalPadding =
        media.size.width > 552 ? (media.size.width - 520) / 2 : 16.0;
    return Scaffold(
      backgroundColor: AppColors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: horizontalPadding,
            top: compact ? 12 : 18,
            bottom: media.viewInsets.bottom + 18,
          ),
          children: [
            StadiumBanner(
              asset: _bannerAsset,
              maxHeight: compact ? 48 : 64,
              maxWidth: compact ? 280 : 380,
            ),
            SizedBox(height: compact ? 14 : 22),
            const Text(
              'Player Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete these once to start Career.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: compact ? 14 : 22),
            Center(
              child: Semantics(
                button: true,
                enabled: !_saving,
                label: _pickedImageBytes == null
                    ? 'Choose a profile image'
                    : 'Change profile image',
                child: MouseRegion(
                  cursor: _saving
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _saving ? null : _pickImage,
                    child: CircleAvatar(
                      radius: compact ? 34 : 42,
                      backgroundColor: Colors.white10,
                      foregroundImage: _pickedImageBytes != null
                          ? MemoryImage(_pickedImageBytes!)
                          : null,
                      child: _pickedImageBytes == null
                          ? const Icon(
                              Icons.add_a_photo,
                              color: AppColors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: compact ? 14 : 18),
            TextField(
              controller: _nameController,
              enabled: !_saving,
              maxLength: 40,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.nickname],
              style: const TextStyle(color: AppColors.white),
              decoration: _field('Player Name'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              isExpanded: true,
              dropdownColor: const Color(0xFF141414),
              value: _selectedKingdom,
              onChanged: _saving
                  ? null
                  : (val) => setState(() => _selectedKingdom = val),
              items: _kingdomMenuItems(),
              decoration: _field('Select Kingdom'),
              style: const TextStyle(color: AppColors.white),
              iconEnabledColor: AppColors.white,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aboutController,
              enabled: !_saving,
              maxLength: 30,
              maxLines: kIsWeb ? 1 : 2,
              style: const TextStyle(color: AppColors.white),
              decoration: _field('About You').copyWith(
                hintText: ProfileService.defaultAbout,
              ),
            ),
            const SizedBox(height: 18),
            if (_errorText case final error?)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFF8A80),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_saving ? 'Saving…' : 'Continue'),
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: Colors.white12,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
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
