import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A lightweight guided first game: three one-time tips at the moments a
/// newcomer needs them (their first turn, the first flop, the end of the
/// first hand), then never again. Many of X Poker's players are new to
/// poker; this keeps them from quitting in the first five minutes without a
/// tutorial standing between them and the game.
enum CoachTip { yourTurn, theFlop, handOver }

extension CoachTipText on CoachTip {
  String get text => switch (this) {
        CoachTip.yourTurn => 'Your turn. Fold to sit this hand out, Call to '
            'match the bet, or Raise to bet more. The best hand at the end '
            'wins the pot.',
        CoachTip.theFlop => 'These cards are shared by everyone. Your hand is '
            'the best five cards from your two plus the table.',
        CoachTip.handOver => 'Win chips hand by hand. The last player with '
            'chips wins the table, and every fort you win moves you along '
            'the journey.',
      };
}

class FirstGameTips {
  FirstGameTips({SharedPreferences? prefs}) : _prefs = prefs;

  static final FirstGameTips instance = FirstGameTips();

  static const String _key = 'first_game_tips_done_v1';

  SharedPreferences? _prefs;
  bool _done = true; // stays quiet until load() says otherwise

  /// Whether this player still needs the tips (their first game).
  bool get pending => !_done;

  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _done = _prefs!.getBool(_key) ?? false;
    } catch (_) {
      _done = true;
    }
  }

  /// No more tips, now or in later games.
  Future<void> markDone() async {
    if (_done) return;
    _done = true;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_key, true);
    } catch (_) {}
  }
}

/// The tip itself: a compact dark card with a "Got it" button.
class CoachTipBanner extends StatelessWidget {
  const CoachTipBanner({
    super.key,
    required this.text,
    required this.onDismiss,
  });

  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: text,
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            key: const ValueKey<String>('coach-tip'),
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(
              color: const Color(0xEE111216),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00B5C8), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFF00B5C8),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onDismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00B5C8),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
