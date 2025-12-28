import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/services/stat_service.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> leaderboard = StatService().getLeaderboard();

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text(
          'Leaderboard',
          style: TextStyle(color: AppColors.white),
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: leaderboard.isEmpty
          ? const Center(
              child: Text(
                'No games played yet.',
                style: TextStyle(color: AppColors.white54),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: leaderboard.length,
              separatorBuilder: (_, __) => const Divider(color: AppColors.white24),
              itemBuilder: (context, index) {
                final entry = leaderboard[index];
                final playerId = entry['playerId'] ?? 'Unknown';
                final handsWon = entry['handsWon'] ?? 0;
                final handsPlayed = entry['handsPlayed'] ?? 0;
                final winRate = handsPlayed > 0
                    ? (handsWon / handsPlayed * 100).toStringAsFixed(1)
                    : '0.0';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.red,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    playerId,
                    style: const TextStyle(color: AppColors.white),
                  ),
                  subtitle: Text(
                    'Wins: $handsWon  |  Played: $handsPlayed  |  Win Rate: $winRate%',
                    style: const TextStyle(color: AppColors.white70),
                  ),
                );
              },
            ),
    );
  }
}
