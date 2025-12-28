// lib/ui/screens/game_screen/models.dart

/// Minimal UI card used by game_screen.*
/// Mapping from engine Card -> GCard happens in game_screen.dart.
class GCard {
  final String rank; // "2".."9","T","J","Q","K","A"
  final String suit; // "♣","♦","♥","♠"

  const GCard(this.rank, this.suit);

  /// Useful when debugging.
  @override
  String toString() => '$rank$suit';

  /// Null/invalid safety check.
  bool get isValid =>
      rank.isNotEmpty && suit.isNotEmpty;

  /// Quick conversion to code format (like "As" for Ace of spades).
  String get code => '$rank$suit';
}

/// Nicely truncate text to a max length, keeping the end visible.
/// Example: truncateNice("abcdefghijkl", 8) → "abcde…"
String truncateNice(String s, int maxLen) {
  if (s.isEmpty) return s;
  if (s.length <= maxLen) return s;
  if (maxLen <= 3) return s.substring(0, maxLen);
  return s.substring(0, maxLen - 3) + '…';
}

/// Extension to wrap an int index safely into [0, n).
extension IntWrap on int {
  int wrap(int n) {
    if (n <= 0) return 0;
    var r = this % n;
    return (r < 0) ? r + n : r;
  }
}