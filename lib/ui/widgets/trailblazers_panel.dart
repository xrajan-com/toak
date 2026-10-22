import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show totalSubKingdomCount;
import 'package:ten_of_a_kind_poker/services/leaderboard_firestore_service.dart';

typedef TrailblazersLoader = Future<List<LeaderboardEntry>> Function();
typedef TrailStandingLoader = Future<TrailStanding?> Function();

/// The player looking at the board: their own row under the top ten, and
/// the nudge they need to get onto it (log in, or set a player name).
@immutable
class TrailblazersViewer {
  /// Signed in with a real account. Guests are asked to log in.
  final bool registered;

  /// Their player name, for their own row. Empty when they have none.
  final String name;

  /// Their forts and place; null when unavailable.
  final TrailStandingLoader? loadStanding;

  /// Opens player-name setup. Called after the panel has closed.
  final VoidCallback? onSetName;

  /// Opens log in / register. Called after the panel has closed.
  final VoidCallback? onSignIn;

  const TrailblazersViewer({
    required this.registered,
    this.name = '',
    this.loadStanding,
    this.onSetName,
    this.onSignIn,
  });
}

/// Opens Trailblazers: the ten players who have cleared the most of the 500
/// forts, on a frosted-glass panel with white type over the venue screen.
///
/// With [autoCloseAfter] it closes by itself that long after the board has
/// loaded, with a thin bar draining along the bottom; touching the panel
/// keeps it open. A tap anywhere outside closes it either way.
Future<void> showTrailblazers(
  BuildContext context, {
  TrailblazersLoader? load,
  Duration? autoCloseAfter,
  TrailblazersViewer? viewer,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Trailblazers',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => TrailblazersPanel(
      load: load ?? leaderboardFirestoreService.fetchTrailblazers,
      autoCloseAfter: autoCloseAfter,
      viewer: viewer,
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
  final Duration? autoCloseAfter;
  final TrailblazersViewer? viewer;

  const TrailblazersPanel({
    super.key,
    required this.load,
    this.autoCloseAfter,
    this.viewer,
  });

  @override
  State<TrailblazersPanel> createState() => _TrailblazersPanelState();
}

class _TrailblazersPanelState extends State<TrailblazersPanel> {
  late Future<List<LeaderboardEntry>> _entries = _load();
  late final Future<TrailStanding?> _standing = _loadStanding();

  Future<TrailStanding?> _loadStanding() async {
    final viewer = widget.viewer;
    final load = viewer?.loadStanding;
    if (viewer == null || !viewer.registered || load == null) return null;
    try {
      return await load();
    } catch (_) {
      // The player's own row is a bonus; the board shows without it.
      return null;
    }
  }

  /// Closes the panel, then runs [action] (which opens another screen).
  void _closeThen(VoidCallback? action) {
    _closed = true;
    Navigator.of(context).pop();
    action?.call();
  }

  // Counting down to the automatic close: from the moment the first load
  // settles, until the player touches the panel.
  bool _autoClosing = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoCloseAfter != null) {
      _entries.then<void>((_) {}, onError: (_) {}).whenComplete(() {
        if (mounted && !_closed) setState(() => _autoClosing = true);
      });
    }
  }

  void _keepOpen() {
    if (!_autoClosing) return;
    setState(() => _autoClosing = false);
  }

  void _autoClose() {
    if (!mounted || !_autoClosing || _closed) return;
    _closed = true;
    // This context belongs to the dialog's own route, so pop closes the
    // panel and nothing beneath it.
    Navigator.of(context).pop();
  }

  // A retry's future is created now but only listened to by the
  // FutureBuilder on the next frame; a failure in between would be reported
  // as unhandled. ignore() marks it handled here, and the FutureBuilder
  // still receives the error and shows Retry.
  Future<List<LeaderboardEntry>> _load() => widget.load()..ignore();

  void _retry() {
    final next = _load();
    setState(() {
      _entries = next;
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
                child: Listener(
                  onPointerDown: (_) => _keepOpen(),
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
                          if (widget.viewer != null)
                            _ViewerSection(
                              viewer: widget.viewer!,
                              standing: _standing,
                              fortTotal: fortTotal,
                              onSetName: () =>
                                  _closeThen(widget.viewer!.onSetName),
                              onSignIn: () =>
                                  _closeThen(widget.viewer!.onSignIn),
                            ),
                          SizedBox(
                            height: 6,
                            child: _autoClosing
                                ? _CountdownBar(
                                    duration: widget.autoCloseAfter!,
                                    onEnd: _autoClose,
                                  )
                                : null,
                          ),
                        ],
                      ),
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

/// Whether a row belongs to a registered player with a name of their own.
/// The backend writes 'Player' for an account that never set up a profile;
/// those rows stay off the board.
bool _hasPlayerName(LeaderboardEntry entry) {
  final name = entry.displayName.trim();
  return name.isNotEmpty && name.toLowerCase() != 'player';
}

/// The rows to show: named players with at least one fort, most forts first,
/// ties to more Aura, ten at most. The backend already sends them in this order;
/// sorting again keeps the panel right if it ever does not.
@visibleForTesting
List<LeaderboardEntry> trailblazerRows(List<LeaderboardEntry> entries) {
  final rows = entries
      .where((entry) => entry.fortsCleared > 0 && _hasPlayerName(entry))
      .toList()
    ..sort((a, b) {
      final byForts = b.fortsCleared.compareTo(a.fortsCleared);
      return byForts != 0 ? byForts : b.auraMilli.compareTo(a.auraMilli);
    });
  return rows.take(10).toList(growable: false);
}

final Color _line = Colors.white.withValues(alpha: 0.16);

/// A thin white line along the bottom that drains while the panel waits to
/// close by itself.
class _CountdownBar extends StatelessWidget {
  final Duration duration;
  final VoidCallback onEnd;
  const _CountdownBar({required this.duration, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: const ValueKey<String>('trailblazers-countdown'),
      tween: Tween<double>(begin: 1, end: 0),
      duration: duration,
      onEnd: onEnd,
      builder: (context, value, _) => Align(
        alignment: Alignment.bottomLeft,
        child: FractionallySizedBox(
          widthFactor: value,
          child: Container(
            height: 2,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

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

const Color _blue = Color(0xFF00B5C8);

/// Under the top ten: the viewer's own row, and what they need to do to get
/// onto the board. Shows nothing while their standing loads or if it cannot.
class _ViewerSection extends StatelessWidget {
  final TrailblazersViewer viewer;
  final Future<TrailStanding?> standing;
  final int fortTotal;
  final VoidCallback onSetName;
  final VoidCallback onSignIn;

  const _ViewerSection({
    required this.viewer,
    required this.standing,
    required this.fortTotal,
    required this.onSetName,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    if (!viewer.registered) {
      return _Prompt(
        key: const ValueKey<String>('trailblazers-sign-in'),
        text: 'Log in to save your forts and join the Trailblazers.',
        action: 'Log in',
        onTap: viewer.onSignIn == null ? null : onSignIn,
      );
    }
    return FutureBuilder<TrailStanding?>(
      future: standing,
      builder: (context, snapshot) {
        final mine = snapshot.data;
        if (mine == null) return const SizedBox.shrink();
        final total = mine.fortTotal > 0 ? mine.fortTotal : fortTotal;
        final rank = mine.rank;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OwnRow(
              rank: rank,
              name: mine.named ? viewer.name : '',
              forts: mine.fortsCleared,
              fortTotal: total,
            ),
            if (!mine.named)
              _Prompt(
                key: const ValueKey<String>('trailblazers-set-name'),
                text: rank != null && rank <= 10
                    ? "You'd be #$rank on the board. Set your player name "
                        'to take your place.'
                    : 'Set your player name to join the Trailblazers.',
                action: 'Set name',
                onTap: viewer.onSetName == null ? null : onSetName,
              )
            else if (mine.fortsCleared <= 0)
              const _Prompt(
                text: 'Clear your first fort to take a place on the board.',
              ),
          ],
        );
      },
    );
  }
}

/// The viewer's own line, tinted blue, set apart from the top ten.
class _OwnRow extends StatelessWidget {
  final int? rank;
  final String name;
  final int forts;
  final int fortTotal;

  const _OwnRow({
    required this.rank,
    required this.name,
    required this.forts,
    required this.fortTotal,
  });

  @override
  Widget build(BuildContext context) {
    final label = name.trim().isEmpty ? 'YOU' : 'YOU · ${name.trim()}';
    return Container(
      key: const ValueKey<String>('trailblazers-own-row'),
      height: 29,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.22),
        border: Border(
          top: BorderSide(color: _blue.withValues(alpha: 0.7), width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              rank == null ? '—' : '#$rank',
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              label.toUpperCase(),
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
            '$forts / $fortTotal',
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

/// One line of guidance, with an optional button that acts on it.
class _Prompt extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onTap;

  const _Prompt({super.key, required this.text, this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 10, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
          if (action != null && onTap != null) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.black,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
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
