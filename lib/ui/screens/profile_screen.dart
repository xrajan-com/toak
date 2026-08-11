import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ten_of_a_kind_poker/config/.env.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/services/api_client.dart';
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _aboutController = TextEditingController();
  bool _saving = false;
  bool _loggingOut = false;
  bool _aboutDirty = false;

  @override
  void dispose() {
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_saving) return;
    setState(() => _saving = true);
    final synced =
        await context.read<ProfileService>().updateAbout(_aboutController.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (synced) _aboutDirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'About updated'
              : 'Saved on this device, but could not sync. Please retry.',
        ),
      ),
    );
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    final auth = context.read<AuthService>();
    await auth.logout();
    if (!mounted) return;
    setState(() => _loggingOut = false);
    if (auth.currentUser == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not log out. Check your connection and retry.'),
      ),
    );
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
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No signed-in account to delete.')),
      );
      return;
    }
    final deletedUid = user.uid;
    final profileService = context.read<ProfileService>();
    final auraService = context.read<AuraPointsService>();
    final campaignService = context.read<CampaignProgressService>();

    final confirmationController = TextEditingController();
    var deleting = false;
    String? errorText;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> deleteAccount() async {
                if (deleting ||
                    confirmationController.text.trim() != 'DELETE') {
                  return;
                }
                setDialogState(() {
                  deleting = true;
                  errorText = null;
                });
                try {
                  final result = await auth.deleteCurrentAccount();
                  if (!result.deleted) {
                    throw const ApiException(
                      kind: ApiFailureKind.malformedResponse,
                      message: 'Deletion was not confirmed.',
                    );
                  }
                  var localDataPurged = true;
                  try {
                    await Future.wait<void>(<Future<void>>[
                      profileService.purgeLocalDataForUser(deletedUid),
                      auraService.purgeLocalDataForUser(
                        deletedUid,
                        includeGuestWallet: user.isAnonymous,
                      ),
                      campaignService.purgeLocalDataForUser(deletedUid),
                    ]);
                  } catch (error) {
                    localDataPurged = false;
                    debugPrint(
                      'Account deleted, but local data purge failed: $error',
                    );
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  if (!mounted) return;
                  final messenger = ScaffoldMessenger.of(this.context);
                  Navigator.of(this.context).popUntil((route) => route.isFirst);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        localDataPurged
                            ? 'Account and device-local account data deleted.'
                            : 'Account deleted. Clear this app\'s storage to '
                                'remove any remaining device-only data.',
                      ),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                } on ApiException catch (error) {
                  if (!dialogContext.mounted) return;
                  if (error.code == 'recent_login_required') {
                    Navigator.of(dialogContext).pop();
                    await _showRecentLoginRequired();
                    return;
                  }
                  setDialogState(() {
                    deleting = false;
                    errorText = switch (error.kind) {
                      ApiFailureKind.network ||
                      ApiFailureKind.timeout =>
                        'Could not reach the deletion service. Check your '
                            'connection and retry.',
                      ApiFailureKind.notConfigured =>
                        'Account deletion is temporarily unavailable.',
                      ApiFailureKind.rateLimited =>
                        'Too many attempts. Please wait and try again.',
                      _ => 'We could not delete the account. Please try again.',
                    };
                  });
                } catch (error) {
                  debugPrint('Account deletion failed: $error');
                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    deleting = false;
                    errorText =
                        'We could not delete the account. Please try again.';
                  });
                }
              }

              return Dialog(
                backgroundColor: const Color(0xFF151515),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.orange,
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Permanently delete account?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'This permanently deletes your sign-in, profile, '
                          'saved progress, Aura, and leaderboard entry. This '
                          'cannot be undone.',
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Type DELETE to confirm',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: confirmationController,
                          enabled: !deleting,
                          autocorrect: false,
                          enableSuggestions: false,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(color: Colors.white),
                          onChanged: (_) => setDialogState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'DELETE',
                            hintStyle: TextStyle(color: Colors.white38),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.orange),
                            ),
                          ),
                        ),
                        if (errorText case final message?)
                          Semantics(
                            liveRegion: true,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                message,
                                style: const TextStyle(
                                  color: Color(0xFFFF8A80),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: deleting
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              child: const Text('Cancel'),
                            ),
                            FilledButton.icon(
                              onPressed: deleting ||
                                      confirmationController.text.trim() !=
                                          'DELETE'
                                  ? null
                                  : deleteAccount,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.red,
                              ),
                              icon: deleting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.delete_forever_outlined),
                              label: Text(
                                deleting ? 'Deleting…' : 'Delete Account',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      confirmationController.dispose();
    }
  }

  Future<void> _showRecentLoginRequired() async {
    if (!mounted) return;
    final logOut = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151515),
          title: const Text(
            'Sign in again',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'For security, account deletion requires a sign-in from the last '
            'five minutes. Log out, sign in again, then return here to retry.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
    if (logOut == true && mounted) await _logout();
  }

  Future<void> _copyPlayerId(String playerId) async {
    if (playerId.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: playerId.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account ID copied'),
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
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width > 600 ? (width - 552) / 2 : 24.0;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title:
            const Text('My Profile', style: TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          24,
          horizontalPadding,
          32,
        ),
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
                label: 'Account ID',
                value: playerId,
                trailing: IconButton(
                  tooltip: 'Copy Account ID',
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
              onPressed: _loggingOut ? null : _logout,
              label: Text(_loggingOut ? 'Logging Out…' : 'Log Out'),
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
              label: const Text('Delete Account'),
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
