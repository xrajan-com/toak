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

  String get venueHeading => switch (this) {
        VenueEntryMode.quickGame => 'Choose a Venue',
        VenueEntryMode.career => 'Choose a Kingdom',
      };

  String get venueSummary => switch (this) {
        VenueEntryMode.quickGame =>
          'Every kingdom is open and free here. Pick any venue for one quick game.',
        VenueEntryMode.career =>
          'Pick a kingdom, conquer its forts, then reach the title match against the toughest table.',
      };
}
