import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/hand_hud.dart';

void main() {
  test('hand HUD prioritizes street live players pot and chip pressure', () {
    final snapshot = buildHandHudSnapshot(
      boardCount: 3,
      visiblePot: 2400,
      toCall: 400,
      heroSeatIndex: 0,
      seats: const <HandHudSeatState>[
        HandHudSeatState(
          chips: 8600,
          contribution: 600,
          active: true,
          allIn: false,
        ),
        HandHudSeatState(
          chips: 6200,
          contribution: 600,
          active: true,
          allIn: false,
        ),
        HandHudSeatState(
          chips: 10000,
          contribution: 0,
          active: false,
          allIn: false,
        ),
      ],
    );

    expect(snapshot.primaryLine, 'FLOP • LIVE: 2 • POT SIZE: 2.4K');
    expect(snapshot.secondaryLine, 'TO CALL 400 • YOU 8.6K • EFF 6.2K');
    expect(
      snapshot.lineFor(heroFolded: true),
      'FLOP • LIVE: 2 • POT SIZE: 2.4K',
    );
    expect(
      snapshot.lineFor(heroFolded: false),
      'TO CALL 400 • YOU 8.6K • EFF 6.2K',
    );
  });

  test('hand HUD shows a free check when hero owes no chips', () {
    final snapshot = buildHandHudSnapshot(
      boardCount: 4,
      visiblePot: 3600,
      toCall: 0,
      heroSeatIndex: 0,
      seats: const <HandHudSeatState>[
        HandHudSeatState(
          chips: 8400,
          contribution: 1600,
          active: true,
          allIn: false,
        ),
        HandHudSeatState(
          chips: 5100,
          contribution: 1600,
          active: true,
          allIn: false,
        ),
      ],
    );

    expect(snapshot.primaryLine, 'TURN • LIVE: 2 • POT SIZE: 3.6K');
    expect(snapshot.secondaryLine, 'CHECK FREE • YOU 8.4K • EFF 5.1K');
  });

  test('hand HUD separates main and side pots for an all-in hero', () {
    final snapshot = buildHandHudSnapshot(
      boardCount: 5,
      visiblePot: 700,
      toCall: 0,
      heroSeatIndex: 0,
      seats: const <HandHudSeatState>[
        HandHudSeatState(
          chips: 0,
          contribution: 100,
          active: true,
          allIn: true,
        ),
        HandHudSeatState(
          chips: 700,
          contribution: 300,
          active: true,
          allIn: false,
        ),
        HandHudSeatState(
          chips: 900,
          contribution: 300,
          active: true,
          allIn: false,
        ),
      ],
    );

    expect(snapshot.mainPot, 300);
    expect(snapshot.sidePot, 400);
    expect(snapshot.primaryLine, 'RIVER • LIVE: 3 • POT SIZE: 700');
    expect(snapshot.lineFor(heroFolded: true), snapshot.primaryLine);
    expect(snapshot.lineFor(heroFolded: false), snapshot.secondaryLine);
  });

  test('hand HUD switches to showdown total', () {
    final snapshot = buildHandHudSnapshot(
      boardCount: 5,
      visiblePot: 8400,
      toCall: 0,
      heroSeatIndex: 0,
      showdown: true,
      seats: const <HandHudSeatState>[
        HandHudSeatState(
          chips: 11600,
          contribution: 4200,
          active: true,
          allIn: false,
        ),
        HandHudSeatState(
          chips: 4800,
          contribution: 4200,
          active: true,
          allIn: false,
        ),
      ],
    );

    expect(snapshot.primaryLine, 'SHOWDOWN • LIVE: 2 • POT SIZE: 8.4K');
    expect(
      snapshot.lineFor(heroFolded: false),
      'CHECK FREE • YOU 11.6K • EFF 4.8K',
    );
  });
}
