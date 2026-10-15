import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show totalSubKingdomCount;
import 'package:ten_of_a_kind_poker/services/leaderboard_firestore_service.dart';

typedef TrailblazersLoader = Future<List<LeaderboardEntry>> Function();

/// Opens Trailblazers: the ten players who have cleared the most of the 500
/// forts, on a frosted-glass panel with white type over the venue screen.
Future<void> showTrailblazers(
  BuildContext context, {
  TrailblazersLoader? load,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Trailblazers',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => TrailblazersPanel(
      load: load ?? leaderboardFirestoreService.fetchTrailblazers,
    ),
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class TrailblazersPanel extends StatefulWidget {
  final TrailblazersLoader load;

  const TrailblazersPanel({super.key, required this.load});

  @override
  State<TrailblazersPanel> createState() => _TrailblazersPanelState();
}

class _TrailblazersPanelState extends State<TrailblazersPanel> {
  late Future<List<LeaderboardEntry>> _entries = widget.load();

  void _retry() {
    setState(() {
      _entries = widget.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fortTotal = totalSubKingdomCount();
    // showGeneralDialog adds no Material; the close and Retry buttons need one.
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FittedBox(
              key: const ValueKey<String>('trailblazers-fitted-box'),
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 330,
                child: Semantics(
                  label: 'Trailblazers: most forts cleared',
                  liveRegion: true,
                  child: _Glass(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Heading(
                          fortTotal: fortTotal,
                          onClose: () => Navigator.of(context).maybePop(),
                        ),
                        Container(height: 1, color: _line),
                        FutureBuilder<List<LeaderboardEntry>>(
                          future: _entries,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Padding(
                                padding: EdgeInsets.all(22),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              );
                            }
                            if (snapshot.hasError) {
                              return _Message(
                                text: snapshot.error is LeaderboardLoadException
                                    ? (snapshot.error!
                                            as LeaderboardLoadException)
                                        .message
                                    : 'Could not load the Trailblazers.',
                                onRetry: _retry,
                              );
                            }
                            final rows = trailblazerRows(snapshot.data!);
                            if (rows.isEmpty) {
                              return const _Message(
                                text: 'No forts cleared yet. Be the first.',
                              );
                            }
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < rows.length; i++)
                                  _Row(
                                    rank: i + 1,
                                    entry: rows[i],
                                    fortTotal: fortTotal,
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 6),
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

/// The rows to show: players with at least one fort, most forts first, ties
/// to more Aura, ten at most. The backend already sends them in this order;
/// sorting again keeps the panel right if it ever does not.
@visibleForTesting
List<LeaderboardEntry> trailblazerRows(List<LeaderboardEntry> entries) {
  final rows = entries.where((entry) => entry.fortsCleared > 0).toList()
    ..sort((a, b) {
      final byForts = b.fortsCleared.compareTo(a.fortsCleared);
      return byForts != 0 ? byForts : b.auraMilli.compareTo(a.auraMilli);
    });
  return rows.take(10).toList(growable: false);
}

final Color _line = Colors.white.withValues(alpha: 0.16);

class _Glass extends StatelessWidget {
  final Widget child;
  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            key: const ValueKey<String>('trailblazers-glass'),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.20),
                  Colors.white.withValues(alpha: 0.07),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final int fortTotal;
  final VoidCallback onClose;
  const _Heading({required this.fortTotal, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TRAILBLAZERS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Most forts cleared of $fortTotal',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            splashRadius: 18,
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final int fortTotal;
  const _Row({
    required this.rank,
    required this.entry,
    required this.fortTotal,
  });

  @override
  Widget build(BuildContext context) {
    final name = entry.displayName.trim().isEmpty
        ? 'Player'
        : entry.displayName.trim();
    return Container(
      height: 27,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: rank == 1 ? Colors.white.withValues(alpha: 0.08) : null,
        border: rank == 1
            ? null
            : Border(top: BorderSide(color: _line, width: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Text(
            '${entry.fortsCleared} / $fortTotal',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  const _Message({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
