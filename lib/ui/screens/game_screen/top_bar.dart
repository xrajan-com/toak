// lib/ui/screens/game_screen/top_bar.dart
import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/clock.dart';

/* ---------------- STADIUM BANNER (capsule) ---------------- */
class _StadiumBanner extends StatelessWidget {
  final String asset;
  const _StadiumBanner({required this.asset});

  static const StadiumBorder _shape = StadiumBorder();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: ShapeBorderClipper(shape: _shape),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset,
        height: 40, // keeps it slim for the top bar
        fit: BoxFit.fitHeight,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
      ),
    );
  }
}

/* ---------------- GAME TOP BAR ---------------- */
class GameTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Color bg;
  final String venueName;
  final String flagPath;

  final String venueTimeZoneId;
  final VoidCallback onExit;
  final VoidCallback onShowHandRankings;

  /// Extras
  final bool isGuest;
  final double height;

  const GameTopBar({
    super.key,
    required this.bg,
    required this.venueName,
    required this.flagPath,
    required this.venueTimeZoneId,
    required this.onExit,
    required this.onShowHandRankings,
    this.isGuest = false,
    this.height = 64,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: bg,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: false,
      toolbarHeight: height,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ---------------- Left cluster ----------------
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      label: 'Exit table',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Exit',
                        onPressed: onExit,
                      ),
                    ),
                    Image.asset(
                      flagPath,
                      width: 46,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 46,
                        height: 28,
                        color: Colors.white12,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.flag_outlined,
                          color: Colors.white54,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        '${venueName.isEmpty ? "Venue" : venueName}${isGuest ? " (Guest Mode)" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ---------------- Right cluster ----------------
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: DayDateClock(timeZoneId: venueTimeZoneId),
                    ),
                    Semantics(
                      label: 'Open hand rankings',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.menu_book, color: Colors.white),
                        tooltip: 'Hand Rankings',
                        onPressed: onShowHandRankings,
                      ),
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
