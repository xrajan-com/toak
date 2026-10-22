enum VenueEntryMode {
  quickGame,
  career,
}

extension VenueEntryModeX on VenueEntryMode {
  String get title => switch (this) {
        VenueEntryMode.quickGame => 'Quick Game',
        VenueEntryMode.career => 'Play Career',
      };

  String get subtitle => switch (this) {
        VenueEntryMode.quickGame =>
          'All venues open. Pick one kingdom, play one table, move on.',
        VenueEntryMode.career =>
          'Choose a kingdom, clear every fort, then fight for the title.',
      };

  String get detail => switch (this) {
        VenueEntryMode.quickGame =>
          'Single-match drop-in. No fort ladder. No title gate.',
        VenueEntryMode.career =>
          'Bots sharpen as the prize pool rises, and the killers wait in the title match.',
      };

  String get ctaLabel => switch (this) {
        VenueEntryMode.quickGame => 'Enter Quick Game',
        VenueEntryMode.career => 'Begin Career Run',
      };
}

/// The introduction the venue screen cycles through, in place of a heading:
/// one list for Quick Game and Career alike, so every player learns what the
/// whole game offers before picking a kingdom. Counts come from the catalog
/// so the copy never drifts from the map.
List<String> venueIntroLines({
  required int kingdoms,
  required int forts,
  required int maxAura,
}) =>
    <String>[
      "Welcome to X Poker: Texas Hold'em across $kingdoms kingdoms and $forts forts.",
      'Career is the journey: take all $forts forts and win $kingdoms titles across the world.',
      "Clear a kingdom's forts to reach its title match. Win it and the title is yours.",
      'Every title lifts your Aura, up to $maxAura. AUP pays your entry fees and grows as you win.',
      'Quick Game: every kingdom open and free, one table. The last player with chips wins.',
      'Opponents play like real people: they talk, read your style and come back as rivals.',
      'Win a fort, a kingdom or a title and save its card to your phone, or share it.',
      'Clear the most forts to join the Trailblazers. Tap the flag up top to see them.',
      'Play money only. No deposits, no cash-outs, just poker.',
    ];
