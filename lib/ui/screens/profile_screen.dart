import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ten_of_a_kind_poker/config/.env.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _aboutController = TextEditingController();
  bool _saving = false;
  bool _aboutDirty = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);

    await context.read<ProfileService>().updateAbout(_aboutController.text);

    setState(() {
      _saving = false;
      _aboutDirty = false;
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("About updated")),
      );
    }
  }

  Future<void> _logout() async {
    await context.read<AuthService>().logout();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _openExternalUrl(Uri uri) async {
    try {
      final ok = await canLaunchUrl(uri);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open website'),
            duration: Duration(milliseconds: 900),
          ),
        );
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open website'),
          duration: Duration(milliseconds: 900),
        ),
      );
    }
  }

  Future<void> _openPrivacyPolicy() async {
    await _openExternalUrl(Uri.parse(Env.privacyPolicyUrl));
  }

  Future<void> _openDeleteAccount() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final Map<String, String> params = <String, String>{};
    if (user != null) {
      if (user.uid.isNotEmpty) params['uid'] = user.uid;
      final email = (user.email ?? '').trim();
      if (email.isNotEmpty) params['email'] = email;
      final name = (user.displayName ?? '').trim();
      if (name.isNotEmpty) params['name'] = name;
      if (user.isAnonymous) params['guest'] = '1';
    } else {
      params['guest'] = '1';
    }
    final uri = params.isEmpty
        ? Uri.parse(Env.deleteAccountUrl)
        : Uri.parse(Env.deleteAccountUrl).replace(queryParameters: params);
    await _openExternalUrl(uri);
  }

  Future<void> _copyPlayerId(String playerId) async {
    if (playerId.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: playerId.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Player ID copied'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _pickAvatar() async {
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
      await context.read<ProfileService>().setLocalAvatarBytes(bytes);
    } catch (e) {
      debugPrint('Profile image pick failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final profile = context.watch<ProfileService>();
    final Uint8List? avatarBytes = profile.avatarBytes;
    String displayName = (user?.displayName ?? '').toString().trim();
    final email = (user?.email ?? '').toString().trim();
    if (displayName.isEmpty && email.contains('@')) {
      displayName = email.split('@').first.trim();
    }
    if (displayName.isEmpty) displayName = 'Player';
    final playerId = (user?.uid ?? '').trim();
    final hasPlayerId =
        user != null && !user.isAnonymous && playerId.isNotEmpty;

    if (!_aboutDirty) {
      final about = ProfileService.normalizeAbout(profile.about);
      if (_aboutController.text != about) {
        _aboutController.text = about;
      }
    }

    final ImageProvider<Object> avatarImage = avatarBytes != null
        ? MemoryImage(avatarBytes) as ImageProvider<Object>
        : const AssetImage('assets/images/default_profile.png');

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title:
            const Text('My Profile', style: TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            /// Avatar
            CircleAvatar(
              radius: 50,
              backgroundImage: avatarImage,
              backgroundColor: Colors.white10,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _pickAvatar,
                  icon: const Icon(Icons.photo_camera_back_outlined, size: 18),
                  label: const Text('Change'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: avatarBytes == null
                      ? null
                      : () => context.read<ProfileService>().clearLocalAvatar(),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            /// Username
            Text(
              displayName,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            if (hasPlayerId) ...[
              _ProfileInfoTile(
                icon: Icons.badge_outlined,
                label: 'Player ID',
                value: playerId,
                trailing: IconButton(
                  tooltip: 'Copy Player ID',
                  icon: const Icon(Icons.copy, color: AppColors.blue, size: 18),
                  onPressed: () => _copyPlayerId(playerId),
                ),
              ),
              const SizedBox(height: 18),
            ],

            /// About input
            TextField(
              controller: _aboutController,
              maxLength: 30,
              style: const TextStyle(color: AppColors.white),
              onChanged: (_) => _aboutDirty = true,
              decoration: const InputDecoration(
                counterStyle: TextStyle(color: AppColors.white54),
                labelText: 'About (max 30 chars)',
                labelStyle: TextStyle(color: AppColors.white70),
                hintText: ProfileService.defaultAbout,
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.blue),
                ),
              ),
            ),

            const SizedBox(height: 30),

            /// Save Button
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _saving ? null : _saveChanges,
              label: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),

            const SizedBox(height: 20),

            /// Logout
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _logout,
              label: const Text('Log Out'),
            ),

            const SizedBox(height: 24),
            const Divider(color: AppColors.white24),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Privacy & Legal',
                style: TextStyle(
                  color: AppColors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.privacy_tip_outlined),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.white70,
                side: const BorderSide(color: AppColors.white30),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _openPrivacyPolicy,
              label: const Text('Privacy Policy'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_forever_outlined),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orange,
                side: const BorderSide(color: AppColors.orange),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _openDeleteAccount,
              label: const Text('Request Account Deletion'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
