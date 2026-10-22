import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:ten_of_a_kind_poker/ui/utils/card_image.dart'
    show CardSaveResult;
import 'package:ten_of_a_kind_poker/ui/widgets/card_sheet.dart';

/// What a win card celebrates.
enum WinKind {
  /// Won a fort's table.
  fort,

  /// That fort was the kingdom's last: every fort taken.
  kingdom,

  /// Won the kingdom's title match.
  title,
}

/// Everything a win card shows, captured when the win was confirmed.
@immutable
class WinCardData {
  final WinKind kind;

  /// The player's name; left off the card when empty.
  final String playerName;
  final String kingdom;
  final String flagAsset;

  /// The circuit, e.g. "Indian Ocean".
  final String circuit;

  /// The fort won (fort cards).
  final String fortName;

  /// How many of the kingdom's forts are taken (this one included), and
  /// how many it has.
  final int fortNumber;
  final int kingdomForts;

  /// The kingdom's title, e.g. "Raja" (title cards).
  final String title;

  /// The journey so far, including this win.
  final int fortsCleared;
  final int fortTotal;
  final int titlesWon;
  final int titlesTotal;

  final DateTime wonAt;

  const WinCardData({
    required this.kind,
    required this.kingdom,
    required this.wonAt,
    this.playerName = '',
    this.flagAsset = '',
    this.circuit = '',
    this.fortName = '',
    this.fortNumber = 0,
    this.kingdomForts = 0,
    this.title = '',
    this.fortsCleared = 0,
    this.fortTotal = 0,
    this.titlesWon = 0,
    this.titlesTotal = 0,
  });

  /// The small label above the headline.
  String get kicker => switch (kind) {
        WinKind.fort => 'FORT TAKEN',
        WinKind.kingdom => 'KINGDOM CONQUERED',
        WinKind.title => 'TITLE WON',
      };

  /// The big line: the fort, the kingdom, or the title itself.
  String get headline => switch (kind) {
        WinKind.fort =>
          (fortName.trim().isEmpty ? kingdom : fortName).toUpperCase(),
        WinKind.kingdom => kingdom.toUpperCase(),
        WinKind.title =>
          (title.trim().isEmpty ? 'CHAMPION' : title).toUpperCase(),
      };

  /// The line under it.
  String get detail {
    final k = kingdom.toUpperCase();
    return switch (kind) {
      WinKind.fort => kingdomForts > 0 && fortNumber > 0
          ? '$k · $fortNumber OF $kingdomForts FORTS'
          : k,
      WinKind.kingdom => kingdomForts > 0
          ? 'ALL $kingdomForts FORTS TAKEN · TITLE MATCH NEXT'
          : 'EVERY FORT TAKEN · TITLE MATCH NEXT',
      WinKind.title => 'OF $k',
    };
  }

  /// The button that opens the card, on the finish screen.
  String get buttonLabel => switch (kind) {
        WinKind.fort => 'SHARE YOUR FORT',
        WinKind.kingdom => 'SHARE YOUR KINGDOM',
        WinKind.title => 'SHARE YOUR TITLE',
      };

  /// Sent with the image when shared.
  String get shareText => switch (kind) {
        WinKind.fort => 'I took ${fortName.trim().isEmpty ? kingdom : fortName}'
            ' in $kingdom at X Poker · tenofakind.com',
        WinKind.kingdom =>
          'I conquered every fort of $kingdom at X Poker · tenofakind.com',
        WinKind.title => title.trim().isEmpty
            ? 'I won the title of $kingdom at X Poker · tenofakind.com'
            : 'I am the $title of $kingdom at X Poker · tenofakind.com',
      };

  /// Names the saved file.
  String get fileStem => switch (kind) {
        WinKind.fort => 'fort-$fortName-$kingdom',
        WinKind.kingdom => 'kingdom-$kingdom',
        WinKind.title => 'title-$title-$kingdom',
      };
}

/// Opens the card for [data], with Save and Share.
Future<void> showWinCardSheet(
  BuildContext context, {
  required WinCardData data,
  ValueChanged<CardSaveResult>? onSaved,
  VoidCallback? onShared,
}) {
  return showCardSheet(
    context,
    card: WinCard(data: data),
    fileStem: data.fileStem,
    shareText: data.shareText,
    onSaved: onSaved,
    onShared: onShared,
  );
}

/// The card itself, laid out at 360 x 450 (4:5).
class WinCard extends StatelessWidget {
  const WinCard({super.key, required this.data});

  final WinCardData data;

  static const Color _red = Color(0xFFFF2800);
  static const Color _blue = Color(0xFF00B5C8);
  static const Color _gold = Color(0xFFFFD76E);

  Color get _accent => switch (data.kind) {
        WinKind.fort => _blue,
        WinKind.kingdom => _red,
        WinKind.title => _gold,
      };

  IconData get _emblem => switch (data.kind) {
        WinKind.fort => Icons.fort_rounded,
        WinKind.kingdom => Icons.castle_rounded,
        WinKind.title => Icons.emoji_events_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final name = data.playerName.trim();
    final radius = BorderRadius.circular(22);
    return SizedBox(
      width: 360,
      height: 450,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0B0F), Color(0xFF151B24)],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.75), width: 2),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              // Soft light behind the emblem.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.22),
                      radius: 0.75,
                      colors: [
                        accent.withValues(alpha: 0.20),
                        accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              // Red and blue: work hard, play hard.
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SizedBox(
                  height: 4,
                  child: Row(
                    children: [
                      Expanded(child: ColoredBox(color: _red)),
                      Expanded(child: ColoredBox(color: _blue)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(champion: data.kind == WinKind.title, accent: accent),
                    const Spacer(),
                    Center(child: _Emblem(icon: _emblem, accent: accent)),
                    const SizedBox(height: 14),
                    Text(
                      data.kicker,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 40,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          data.headline,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (data.flagAsset.trim().isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Image.asset(
                              data.flagAsset,
                              width: 26,
                              height: 17,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            data.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (name.isNotEmpty) ...[
                      Text(
                        data.kind == WinKind.title ? 'CROWNED' : 'CLAIMED BY',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _Stat(
                            value: '${data.fortsCleared} / ${data.fortTotal}',
                            label: 'FORTS',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Stat(
                            value: '${data.titlesWon} / ${data.titlesTotal}',
                            label: 'TITLES',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              DateFormat('d MMM yyyy')
                                  .format(data.wonAt)
                                  .toUpperCase(),
                              if (data.circuit.trim().isNotEmpty)
                                data.circuit.trim().toUpperCase(),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Text(
                          'tenofakind.com',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.champion, required this.accent});

  final bool champion;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/x_poker_logo.png',
            width: 34,
            height: 34,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(width: 34),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'X POKER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent),
          ),
          child: Text(
            champion ? 'CHAMPION' : 'VICTORY',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accent.withValues(alpha: 0.38),
            accent.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: accent, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.45),
            blurRadius: 28,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 54),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
