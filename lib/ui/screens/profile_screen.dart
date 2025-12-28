import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _statusController = TextEditingController();
  final AuthService _authService = AuthService();

  String username = 'Player001'; // Replace with real data from user model
  String profileImagePath = 'assets/images/default_avatar.png'; // Placeholder
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // Load user's data (mocked here)
    _statusController.text = "Focused and calm."; // load from player model
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);

    // Simulate saving status to backend / database
    await Future.delayed(const Duration(milliseconds: 800));

    // TODO: Update player model/status here
    debugPrint('Status saved: ${_statusController.text}');

    setState(() => _saving = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated")),
      );
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('My Profile', style: TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            /// Avatar
            CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage(profileImagePath),
              backgroundColor: Colors.white10,
            ),
            const SizedBox(height: 16),

            /// Username
            Text(
              username,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            /// Status input
            TextField(
              controller: _statusController,
              maxLength: 30,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(
                counterStyle: TextStyle(color: AppColors.white54),
                labelText: 'Status (max 30 chars)',
                labelStyle: TextStyle(color: AppColors.white70),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
          ],
        ),
      ),
    );
  }
}
