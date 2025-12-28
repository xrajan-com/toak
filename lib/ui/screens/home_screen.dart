import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/ui/screens/profile_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/leaderboard_screen.dart';
// TODO: Import guest_game_screen.dart, career_screen.dart, chart_screen.dart, about_screen.dart, feedback_screen.dart

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text(
          'TEN OF A KIND',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ListView(
          children: [
            _buildSection('MY KINGDOM'),
            _buildActionButton(
              context,
              label: 'My Profile (Edit)',
              color: AppColors.white,
              icon: Icons.person,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              context,
              label: 'Leaderboard',
              color: AppColors.blue,
              icon: Icons.emoji_events,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                );
              },
            ),

            const SizedBox(height: 32),
            _buildSection('BATTLE MODES'),
            _buildActionButton(
              context,
              label: 'Play as Guest',
              color: AppColors.green,
              icon: Icons.videogame_asset,
              onPressed: () {
                // TODO: Navigator.push to GuestGameScreen
              },
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              context,
              label: 'Start / Continue Career',
              color: AppColors.red,
              icon: Icons.play_arrow,
              onPressed: () {
                // TODO: Navigator.push to CareerScreen
              },
            ),

            const SizedBox(height: 32),
            _buildSection('TOOLS'),
            _buildActionButton(
              context,
              label: 'Poker Hands Chart',
              color: AppColors.orange,
              icon: Icons.auto_graph,
              onPressed: () {
                // TODO: Show Poker Chart
              },
            ),

            const SizedBox(height: 32),
            _buildSection('ABOUT & FEEDBACK'),
            _buildOutlinedButton(
              context,
              label: 'About',
              icon: Icons.info_outline,
              onPressed: () {
                // TODO: Navigator.push to AboutScreen
              },
            ),
            const SizedBox(height: 8),
            _buildOutlinedButton(
              context,
              label: 'Feedback',
              icon: Icons.feedback_outlined,
              onPressed: () {
                // TODO: Navigator.push to FeedbackScreen
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.black,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }

  Widget _buildOutlinedButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.white),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(fontSize: 16),
      ),
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}
