import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/kingdom_titles.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';

void main() {
  test('hosting venue tabs use the five clear circuit names', () {
    final indexHtml = File('hosting/index.html').readAsStringSync();
    final styles = File('hosting/styles.css').readAsStringSync();

    expect(
      indexHtml,
      contains(
        '<button class="venue-tab active" data-target="euro" '
        'role="tab" aria-selected="true">Europe</button>',
      ),
    );
    expect(
      indexHtml,
      contains(
        '<button class="venue-tab" data-target="us" '
        'role="tab" aria-selected="false">Americas</button>',
      ),
    );
    expect(
      indexHtml,
      contains(
        '<button class="venue-tab" data-target="oceania" '
        'role="tab" aria-selected="false">Asia-Pacific</button>',
      ),
    );
    expect(
      indexHtml,
      contains(
        '<button class="venue-tab" data-target="india" '
        'role="tab" aria-selected="false">Indian Ocean</button>',
      ),
    );
    expect(
      indexHtml,
      contains(
        '<button class="venue-tab" data-target="world" '
        'role="tab" aria-selected="false">World Frontiers</button>',
      ),
    );
    expect(
      indexHtml,
      contains('<div class="venue-grid active" data-group="euro"'),
    );

    final worldActive = RegExp(
      r'\.venue-tab\[data-target="world"\]\.active\s*\{[^}]*background:\s*#ff2800;',
      multiLine: true,
    );
    final indiaActive = RegExp(
      r'\.venue-tab\[data-target="india"\]\.active\s*\{[^}]*background:\s*linear-gradient\(120deg, #20d9ff, #00a6e8\);',
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
    final usActive = RegExp(
      r'\.venue-tab\[data-target="us"\]\.active\s*\{[^}]*background:\s*#ffffff;[^}]*color:\s*#000000;',
      multiLine: true,
    );
    final usInactive = RegExp(
      r'\.venue-tab\[data-target="us"\]\s*\{[^}]*background:\s*rgba\(0,\s*0,\s*0,\s*0\.6\);[^}]*color:\s*#ffffff;',
      multiLine: true,
    );
    final desktopSingleRow = RegExp(
      r'@media \(min-width:\s*769px\)\s*\{[\s\S]*?\.venue-tabs\s*\{[^}]*flex-wrap:\s*nowrap;[\s\S]*?\.venue-tab-item\s*\{[^}]*flex:\s*1 1 0;',
      multiLine: true,
    );

    expect(styles, matches(worldActive));
    expect(styles, matches(indiaActive));
    expect(styles, matches(euroActive));
    expect(styles, matches(oceaniaActive));
    expect(styles, matches(usInactive));
    expect(styles, matches(usActive));
    expect(styles, matches(desktopSingleRow));
  });

  test('hosting venue tabs expose circuit leaderboards on hover or touch', () {
    final indexHtml = File('hosting/index.html').readAsStringSync();
    final styles = File('hosting/styles.css').readAsStringSync();
    final scripts = File('hosting/scripts.js').readAsStringSync();

    expect(indexHtml, isNot(contains('class="aura-leaderboard-strip"')));
    expect(
        indexHtml, isNot(contains('class="aura-board-pill aura-board-title"')));
    expect(indexHtml, isNot(contains('aura-board-label-spacer')));
    expect(indexHtml, isNot(contains('class="aura-board-label"')));
    expect(
        indexHtml,
        contains(
            '<ol class="venue-leaderboard-menu" aria-label="Europe leaderboard">'));
    expect(
        indexHtml,
        contains(
            '<ol class="venue-leaderboard-menu" aria-label="Americas leaderboard">'));
    expect(
        indexHtml,
        contains(
            '<ol class="venue-leaderboard-menu" aria-label="Asia-Pacific leaderboard">'));
    expect(
        indexHtml,
        contains(
            '<ol class="venue-leaderboard-menu" aria-label="Indian Ocean leaderboard">'));
    expect(
        indexHtml,
        contains(
            '<ol class="venue-leaderboard-menu" aria-label="World Frontiers leaderboard">'));

    final leaderboardHeadingRows = RegExp(
      r'<li class="venue-leaderboard-heading">Live Overall Leaderboard</li>',
    ).allMatches(indexHtml).length;
    expect(leaderboardHeadingRows, 5);

    final firstMenu = RegExp(
      r'<ol class="venue-leaderboard-menu" aria-label="Europe leaderboard">([\s\S]*?)</ol>',
    ).firstMatch(indexHtml);
    expect(firstMenu, isNotNull);
    expect(RegExp(r'<li').allMatches(firstMenu!.group(1)!).length, 2);
    expect(
      RegExp(r'class="venue-leaderboard-status"').allMatches(indexHtml).length,
      5,
    );

    for (final topName in <String>[
      'Jordan Walker',
      'Bajirao Kale',
      'Mei Lin Tan',
      'Nur Aisyah',
    ]) {
      expect(indexHtml, isNot(contains(topName)));
    }

    expect(
      indexHtml,
      isNot(contains('Same tabs, same tiles as the in-game Venue Screen.')),
    );
    expect(
      indexHtml,
      isNot(contains('Flip between the International, Indian, Euro')),
    );
    expect(indexHtml, isNot(contains('class="demo-banner"')));
    expect(indexHtml, isNot(contains('Play Demo')));
    expect(indexHtml, contains('class="download-pill web-play-pill"'));
    expect(indexHtml, contains('class="download-pill play-store-badge"'));
    expect(indexHtml, contains('class="download-pill app-store-badge"'));
    expect(indexHtml, contains('<span>PLAY IN</span>'));
    expect(indexHtml, contains('<strong>Browser</strong>'));
    expect(indexHtml, contains('<span>DOWNLOAD ON</span>'));
    expect(indexHtml, contains('<strong>App Store</strong>'));
    expect(
        indexHtml,
        contains(
            'https://apps.apple.com/us/search?term=Ten%20of%20a%20Kind%20Poker'));
    expect(indexHtml, isNot(contains('id="leaderboardLink"')));
    final navBlock = RegExp(r'<nav role="navigation">([\s\S]*?)</nav>')
        .firstMatch(indexHtml)
        ?.group(1);
    expect(navBlock, isNotNull);
    expect(navBlock, isNot(contains('Kingdom Atlas')));
    expect(navBlock, isNot(contains('Game Modes')));
    expect(navBlock, isNot(contains('Support')));
    expect(indexHtml, contains('id="supportLink">Support</a>'));
    expect(indexHtml, contains('aria-label="Sign in to manage profile"'));
    expect(indexHtml, contains('aria-label="Open player dashboard"'));
    expect(indexHtml,
        contains('<span class="profile-icon-text">My Profile</span>'));
    expect(indexHtml,
        contains('<span class="profile-icon-text">Dashboard</span>'));
    expect(
      indexHtml,
      contains(
        'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore-compat.js',
      ),
    );
    expect(indexHtml, contains('id="dashboardFortWins"'));
    expect(indexHtml, contains('id="dashboardKingdomWins"'));
    expect(indexHtml, contains('id="dashboardCircuitWins"'));
    expect(indexHtml, contains('id="dashboardTitlesWon"'));
    expect(indexHtml, contains('id="dashboardAura"'));
    expect(indexHtml, contains('id="dashboardAupTotal"'));
    expect(indexHtml, contains('id="dashboardAupLeft"'));
    expect(indexHtml, contains('id="dashboardAupOceania"'));
    expect(indexHtml, contains('id="dashboardAupEuro"'));
    expect(indexHtml, contains('id="dashboardAupIndia"'));
    expect(indexHtml, contains('id="dashboardAupInternational"'));
    expect(indexHtml, contains('id="dashboardAupNorthAmerica"'));
    expect(indexHtml, isNot(contains('viewIdCardBtn')));
    expect(indexHtml, isNot(contains('id-card')));
    expect(indexHtml, isNot(contains('ID Card')));

    expect(styles, isNot(contains('.aura-board-world')));
    expect(styles, contains('.venue-tab-item-world'));
    expect(styles, contains('background: #ff2800;'));
    expect(styles, contains('.venue-tab-item-india'));
    expect(styles, contains('linear-gradient(120deg, #20d9ff, #00a6e8)'));
    expect(styles, contains('.venue-tab-item-euro'));
    expect(styles, contains('background: #0aa83f;'));
    expect(styles, contains('.venue-tab-item-oceania'));
    expect(styles, contains('background: #ffd400;'));
    expect(styles, contains('.venue-tab-item-us'));
    expect(styles, contains('--venue-tab-menu-bg: #001f3f;'));
    expect(
      styles,
      matches(RegExp(
        r'\.venue-tabs\s*\{[^}]*z-index:\s*40;',
        multiLine: true,
      )),
    );
    expect(
      styles,
      matches(RegExp(
        r'\.venue-leaderboard-menu\s*\{[^}]*z-index:\s*100;',
        multiLine: true,
      )),
    );
    expect(
      styles,
      contains('.venue-tab-item.leaderboard-open .venue-leaderboard-menu'),
    );
    expect(styles,
        isNot(contains('.venue-tab-item:hover .venue-leaderboard-menu')));
    expect(
      styles,
      isNot(contains('.venue-tab-item:focus-within .venue-leaderboard-menu')),
    );
    expect(styles, contains('visibility: hidden;'));
    expect(styles, contains('.web-play-pill'));
    expect(styles, contains('.app-store-badge'));
    expect(styles, contains('.web-launch-mark'));
    expect(styles, contains('.app-store-arrow'));
    expect(styles, contains('.profile-action-link'));
    expect(styles, contains('.profile-icon-text'));
    expect(styles, contains('.dashboard-icon'));
    expect(styles, contains('.profile-modal-dashboard'));
    expect(styles, contains('.profile-modal-profile'));
    expect(styles, contains('.dashboard-stat'));
    expect(styles, contains('.venue-leaderboard-heading'));
    expect(styles, contains('background: var(--venue-tab-heading-bg);'));
    expect(styles, contains('color: var(--venue-tab-heading-fg);'));
    expect(styles, isNot(contains('.demo-banner')));
    expect(styles, isNot(contains('.id-card')));
    expect(scripts, contains('firebase.firestore'));
    expect(scripts, contains('openProfileSurface("profile")'));
    expect(scripts, contains('openProfileSurface("dashboard")'));
    expect(scripts, contains('profile-modal-dashboard'));
    expect(scripts, contains('dashboardAupTotal'));
    expect(scripts, contains('leaderboard-open'));
    expect(scripts,
        contains('setTimeout(() => closeLeaderboardMenu(item), 4000)'));
    expect(scripts, contains('event.target.closest?.(".venue-tab-item")'));
    expect(scripts, contains('aria-expanded'));
    expect(scripts, contains('orderBy("auraMilli", "desc")'));
    expect(scripts, contains('renderLiveLeaderboards(entries)'));
    expect(scripts, isNot(contains('leaderboardFallbacks')));
    expect(scripts, contains('"Dashboard"'));
    expect(scripts, contains('"Open my profile"'));
    expect(scripts, contains('"Sign in to manage profile"'));
  });

  test('hosting shell has no orphan feature panel and stable favicon refresh',
      () {
    final indexHtml = File('hosting/index.html').readAsStringSync();
    final webIndexHtml = File('web/index.html').readAsStringSync();
    final styles = File('hosting/styles.css').readAsStringSync();
    final scripts = File('hosting/scripts.js').readAsStringSync();
    final firebaseJson = File('firebase.json').readAsStringSync();

    for (final removed in <String>[
      'feature-panel',
      'featurePopup',
      'featureModal',
      'closeFeatureModal',
      'closeFeaturePopup',
      'Everything synced with the app',
      'Jump into the circuit however you like',
    ]) {
      expect(indexHtml, isNot(contains(removed)));
      expect(styles, isNot(contains(removed)));
      expect(scripts, isNot(contains(removed)));
    }

    for (final href in <String>[
      'favicon.ico?v=20260705',
      'favicon-32x32.png?v=20260705',
      'favicon-16x16.png?v=20260705',
    ]) {
      expect(indexHtml, contains(href));
      expect(webIndexHtml, contains(href));
    }
    expect(indexHtml, contains('favicon.png?v=20260705'));
    expect(firebaseJson, contains('"source": "/favicon.ico"'));
    expect(firebaseJson, contains('"source": "/web/favicon.ico"'));
  });

  test('hosting venue cards show fort counts and title names', () {
    final indexHtml = File('hosting/index.html').readAsStringSync();
    final scripts = File('hosting/scripts.js').readAsStringSync();

    final expectedSummaries = <String>[
      for (final group in kVenueGroups)
        for (final venue in venuesForGroup(group))
          '${subKingdomCountFor(group: group, kingdomName: venue.name)} '
              'Forts, Title: '
              '${kingdomTitleFor(group: group, kingdomName: venue.name)}',
    ];

    for (final summary in expectedSummaries) {
      expect(indexHtml, contains(summary));
    }

    final actualFeltByVenue = <String, String>{};
    final cardPattern = RegExp(
      r'<article class="venue-card" style="--felt:(#[0-9A-Fa-f]{6})">'
      r'[\s\S]*?<h4>([^<]+)</h4>',
    );
    for (final match in cardPattern.allMatches(indexHtml)) {
      actualFeltByVenue[match.group(2)!.replaceAll('&amp;', '&')] =
          match.group(1)!.toUpperCase();
    }

    final expectedFeltByVenue = <String, String>{
      for (final group in kVenueGroups)
        for (final venue in venuesForGroup(group))
          venue.name:
              '#${(venue.felt.value & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
    };

    expect(
        actualFeltByVenue.keys.toSet(), containsAll(expectedFeltByVenue.keys));
    for (final entry in expectedFeltByVenue.entries) {
      expect(
        actualFeltByVenue[entry.key],
        entry.value,
        reason: '${entry.key} website tile color should match app felt color',
      );
    }

    final expectedFlagPaths = RegExp(r'src="(images/venues/[^"]+\.png)"')
        .allMatches(indexHtml)
        .map((match) => match.group(1)!)
        .toSet();
    expect(expectedFlagPaths, isNotEmpty);
    for (final path in expectedFlagPaths) {
      expect(File('hosting/$path').existsSync(), isTrue, reason: path);
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
