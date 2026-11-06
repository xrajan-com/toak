import 'package:ten_of_a_kind_poker/ui/art/fort_style.dart' show stableArtSeed;

/// The story's lines, in Renoir's voice. The world and its rules are in
/// docs/STORY.md: kingdoms don't go to war, they play poker; every kingdom
/// crowns its ruler at a title match; Renoir deals every title match.
///
/// Voice: short, dry, second person. No exclamation marks, and no gambling
/// talk (no money, jackpots or "bet big"); poker words are fine.
class StoryLines {
  const StoryLines._();

  /// The premise, on the welcome screen.
  static const String premise =
      "Here, kingdoms don't go to war.\nThey play poker. Take your seat.";

  /// Renoir's opening line at a table, shown over the players as the game
  /// starts.
  ///
  /// [fortName] is set for a Career fort, [titleMatch] for a kingdom's title
  /// match, where [titleHolder] (if known) holds the crown called [title].
  /// [firstTable] is the player's first game ever.
  static String openingLine({
    required String kingdom,
    String? title,
    String? fortName,
    bool titleMatch = false,
    String? titleHolder,
    bool firstTable = false,
  }) {
    final String k = kingdom.trim().isEmpty ? 'the table' : kingdom.trim();
    final String? crown = _known(title);
    if (titleMatch) {
      final String? holder = _known(titleHolder);
      if (holder != null && crown != null) {
        return 'Title match, $k. $holder is $crown. '
            'Take the table and the crown is yours.';
      }
      if (crown != null) {
        return 'Title match, $k. Take the table and you are $crown of $k.';
      }
      return 'Title match, $k. Take the table and the crown is yours.';
    }
    final String? fort = _known(
      fortName?.replaceAll(RegExp(r'\s*\([^)]*\)'), ''),
    );
    if (fort != null) {
      return crown == null
          ? '$fort, $k. Every fort you take brings the crown closer.'
          : '$fort, $k. Every fort you take brings the crown of $crown '
              'closer.';
    }
    if (firstTable) {
      return 'Welcome to $k. Every crown in the world starts at a table '
          'like this one.';
    }
    return 'Welcome to $k. No crown at this table, only practice. '
        'Make it count.';
  }

  /// Over the title holder's seat at the first hand.
  static String titleHolderNote({required String title, required String kingdom}) =>
      '$title of ${kingdom.trim()} · holds the crown';

  /// Which of [candidates] holds [kingdom]'s crown: the same player every
  /// time for the same kingdom and field, so the title has a face.
  static String? pickTitleHolder(Iterable<String> candidates, String kingdom) {
    final List<String> names = candidates
        .map((String n) => n.trim())
        .where((String n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (names.isEmpty) return null;
    return names[stableArtSeed(kingdom.trim()) % names.length];
  }

  static String? _known(String? value) {
    final String t = (value ?? '').trim();
    if (t.isEmpty || t == 'N/A') return null;
    return t;
  }
}
