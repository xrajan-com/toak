import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hosting venue tabs prioritize international circuit by default', () {
    final indexHtml = File('hosting/index.html').readAsStringSync();
    final styles = File('hosting/styles.css').readAsStringSync();

    expect(
      indexHtml,
      contains(
        '<button class="venue-tab active" data-target="world" '
        'role="tab" aria-selected="true">International Circuit</button>',
      ),
    );
    expect(
      indexHtml,
      contains(
        '<button class="venue-tab" data-target="india" '
        'role="tab" aria-selected="false">Royal Indian Circuit</button>',
      ),
    );
    expect(
      indexHtml,
      contains(
        '<button class="venue-tab" data-target="euro" '
        'role="tab" aria-selected="false">Euro Circuit</button>',
      ),
    );
    expect(
      indexHtml,
      contains(
        '<button class="venue-tab" data-target="oceania" '
        'role="tab" aria-selected="false">Oceania Circuit</button>',
      ),
    );
    expect(
      indexHtml,
      contains('<div class="venue-grid active" data-group="world"'),
    );

    final worldActive = RegExp(
      r'\.venue-tab\[data-target="world"\]\.active\s*\{[^}]*background:\s*#ff2800;',
      multiLine: true,
    );
    final indiaActive = RegExp(
      r'\.venue-tab\[data-target="india"\]\.active\s*\{[^}]*background:\s*linear-gradient\(120deg, #24b6ff, #00a6e8\);',
      multiLine: true,
    );
    final euroActive = RegExp(
      r'\.venue-tab\[data-target="euro"\]\.active\s*\{[^}]*background:\s*#0aa83f;[^}]*color:\s*#ffffff;',
      multiLine: true,
    );
    final oceaniaActive = RegExp(
      r'\.venue-tab\[data-target="oceania"\]\.active\s*\{[^}]*background:\s*#ffd400;[^}]*color:\s*#000000;',
      multiLine: true,
    );

    expect(styles, matches(worldActive));
    expect(styles, matches(indiaActive));
    expect(styles, matches(euroActive));
    expect(styles, matches(oceaniaActive));
  });

  test('hosting venue intro is replaced by circuit aura leaderboard pills', () {
    final indexHtml = File('hosting/index.html').readAsStringSync();
    final styles = File('hosting/styles.css').readAsStringSync();

    expect(indexHtml, contains('class="aura-leaderboard-strip"'));
    expect(indexHtml, contains('class="aura-board-pill aura-board-title"'));
    expect(indexHtml, contains('>Leaderboard</div>'));
    expect(indexHtml, contains('class="aura-board-label"'));
    expect(
        indexHtml,
        contains(
            '<span class="aura-board-label">International Circuit</span>'));
    expect(indexHtml,
        contains('<div class="aura-board-pill">Jordan Walker</div>'));
    expect(indexHtml, contains('International Circuit top 10 Aura players'));
    expect(indexHtml, contains('Royal Indian Circuit top 10 Aura players'));
    expect(indexHtml, contains('Euro Circuit top 10 Aura players'));
    expect(indexHtml, contains('Oceania Circuit top 10 Aura players'));

    for (final topName in <String>[
      'Jordan Walker',
      'Bajirao Kale',
      'Mei Lin Tan',
      'Nur Aisyah',
    ]) {
      expect(indexHtml, contains(topName));
    }

    expect(
      indexHtml,
      isNot(contains('Same tabs, same tiles as the in-game Venue Screen.')),
    );
    expect(
      indexHtml,
      isNot(contains('Flip between the International, Royal Indian, Euro')),
    );
    expect(indexHtml, isNot(contains('class="demo-banner"')));
    expect(indexHtml, isNot(contains('Play Demo')));
    expect(indexHtml, contains('class="download-pill web-play-pill"'));
    expect(indexHtml, contains('<span>PLAY IN</span>'));
    expect(indexHtml, contains('<strong>Browser</strong>'));
    expect(indexHtml, isNot(contains('id="leaderboardLink"')));
    expect(indexHtml, contains('aria-label="Open player dashboard"'));
    expect(indexHtml, contains('id="dashboardFortWins"'));
    expect(indexHtml, contains('id="dashboardKingdomWins"'));
    expect(indexHtml, contains('id="dashboardCircuitWins"'));
    expect(indexHtml, contains('id="dashboardTitlesWon"'));
    expect(indexHtml, isNot(contains('viewIdCardBtn')));
    expect(indexHtml, isNot(contains('id-card')));
    expect(indexHtml, isNot(contains('ID Card')));

    expect(styles, contains('.aura-board-world'));
    expect(styles, contains('background: #ff2800;'));
    expect(styles, contains('.aura-board-india'));
    expect(styles, contains('linear-gradient(120deg, #24b6ff, #00a6e8)'));
    expect(styles, contains('.aura-board-euro'));
    expect(styles, contains('background: #0aa83f;'));
    expect(styles, contains('.aura-board-oceania'));
    expect(styles, contains('background: #ffd400;'));
    expect(styles, contains('.aura-board-circuit:hover .aura-board-menu'));
    expect(styles, contains('visibility: hidden;'));
    expect(styles, contains('.web-play-pill'));
    expect(styles, contains('.web-launch-mark'));
    expect(styles, contains('.dashboard-stat'));
    expect(styles, contains('.aura-board-label'));
    expect(styles, isNot(contains('.demo-banner')));
    expect(styles, isNot(contains('.id-card')));
  });

  test('hosting venue cards show fort counts and title names', () {
    final indexHtml = File('hosting/index.html').readAsStringSync();
    final scripts = File('hosting/scripts.js').readAsStringSync();

    const expectedSummaries = <String>[
      '8 Forts, Title: Patel',
      '5 Forts, Title: Nizam',
      '5 Forts, Title: Subedar',
      '9 Forts, Title: Rawal',
      '8 Forts, Title: Peshwa',
      '5 Forts, Title: Sultan',
      '12 Forts, Title: Raja',
      '21 Forts, Title: Zaildar',
      '10 Forts, Title: Sherpa',
      '6 Forts, Title: Thala',
      '8 Forts, Title: Mansa',
      '8 Forts, Title: Caudillo',
      '12 Forts, Title: Chief',
      '9 Forts, Title: Sheikh',
      '7 Forts, Title: Jiangjun',
      '8 Forts, Title: Shogun',
      '8 Forts, Title: Mandala',
      '11 Forts, Title: Emir',
      '8 Forts, Title: Shah',
      '17 Forts, Title: Duke',
      '7 Forts, Title: Baron',
      '6 Forts, Title: Marquis',
      '6 Forts, Title: Conte',
      '6 Forts, Title: Hidalgo',
      '6 Forts, Title: Infante',
      '6 Forts, Title: Stadtholder',
      '6 Forts, Title: Jarl',
      '10 Forts, Title: Hetman',
      '10 Forts, Title: Ataman',
      '13 Forts, Title: Strategos',
      '6 Forts, Title: Chieftain',
      '10 Forts, Title: Governor',
      '8 Forts, Title: Taipan',
      '12 Forts, Title: Laksamana',
      '10 Forts, Title: Admiral',
      '8 Forts, Title: Tui',
      '10 Forts, Title: Warden',
      '10 Forts, Title: Seigneur',
      '8 Forts, Title: Burgher',
      '10 Forts, Title: Marshal',
    ];

    for (final summary in expectedSummaries) {
      expect(indexHtml, contains(summary));
    }

    const expectedFlagPaths = <String>[
      'images/venues/euro/britain.png',
      'images/venues/euro/france.png',
      'images/venues/euro/italy.png',
      'images/venues/euro/spain.png',
      'images/venues/euro/portugal.png',
      'images/venues/euro/north_sea.png',
      'images/venues/euro/scandinavia.png',
      'images/venues/euro/baltic_marches.png',
      'images/venues/euro/russia_siberia.png',
      'images/venues/euro/mediterranean.png',
      'images/venues/oceania/alaska.png',
      'images/venues/oceania/caribbean.png',
      'images/venues/oceania/dragonland.png',
      'images/venues/oceania/straits.png',
      'images/venues/oceania/indian_ocean.png',
      'images/venues/oceania/pacific.png',
      'images/venues/oceania/british_isles.png',
      'images/venues/oceania/french_isles.png',
      'images/venues/oceania/dutch_isles.png',
      'images/venues/oceania/american_isles.png',
    ];
    for (final path in expectedFlagPaths) {
      expect(indexHtml, contains(path));
      expect(scripts, contains(path.replaceFirst('images/venues/', '')));
    }

    expect(indexHtml, isNot(contains('Gaekwad palaces bankroll legends')));
    expect(indexHtml, isNot(contains('Savanna drums pace deep stacks')));
    expect(scripts, contains('const venueTitles = {'));
    expect(
      scripts,
      contains(r'return `${count} ${fortLabel}, Title: ${title}`;'),
    );
  });
}
