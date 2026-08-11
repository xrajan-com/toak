import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/leaderboard_firestore_service.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

class LeaderboardScreen extends StatefulWidget {
  final Future<List<LeaderboardEntry>> Function()? entriesLoader;

  const LeaderboardScreen({
    super.key,
    this.entriesLoader,
  });

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
    final loader = widget.entriesLoader;
    if (loader != null) return loader();
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
    if (entry.cappedAuraMilli % 1000 == 0) {
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
            return Center(
              child: Semantics(
                liveRegion: true,
                label: 'Loading leaderboard',
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.white),
                    SizedBox(height: 14),
                    Text(
                      'Loading leaderboard…',
                      style: TextStyle(color: AppColors.white70),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          color: AppColors.white70,
                          size: 38,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Could not load the leaderboard.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Check your connection and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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

          final width = MediaQuery.sizeOf(context).width;
          final horizontal = width > 760 ? (width - 720) / 2 : 16.0;
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
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
