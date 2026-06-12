import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/leaderboard_firestore_service.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<LeaderboardEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _loadEntries();
  }

  Future<List<LeaderboardEntry>> _loadEntries() async {
    try {
      final aura = context.read<AuraPointsService>();
      await aura.init();
      await leaderboardFirestoreService.syncCurrentUserIfTop10(wallet: aura);
    } catch (e) {
      debugPrint('Leaderboard self-sync skipped: $e');
    }
    return leaderboardFirestoreService.fetchTop10();
  }

  void _refresh() {
    setState(() {
      _entriesFuture = _loadEntries();
    });
  }

  String _formatAura(LeaderboardEntry entry) {
    if (entry.auraMilli % 1000 == 0) {
      return entry.aura.toStringAsFixed(0);
    }
    return entry.aura.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text(
          'Leaderboard',
          style: TextStyle(color: AppColors.white),
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          IconButton(
            tooltip: 'Refresh leaderboard',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<LeaderboardEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.white),
            );
          }

          final entries = snapshot.data ?? const <LeaderboardEntry>[];
          if (entries.isEmpty) {
            return const Center(
              child: Text(
                'No ranked players yet.',
                style: TextStyle(color: AppColors.white54),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const Divider(color: AppColors.white24),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.red,
                  foregroundColor: AppColors.white,
                  child: Text('${index + 1}'),
                ),
                title: Text(
                  entry.displayName,
                  style: const TextStyle(color: AppColors.white),
                ),
                subtitle: Text(
                  'Aura: ${_formatAura(entry)}  |  AUP: ${entry.totalAup}  |  Activity: ${entry.activityScore}',
                  style: const TextStyle(color: AppColors.white70),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
