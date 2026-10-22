import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ten_of_a_kind_poker/ui/utils/card_image.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/win_card.dart';

WinCardData _card(WinKind kind, {String name = 'Peter Power'}) => WinCardData(
      kind: kind,
      playerName: name,
      kingdom: 'New Delhi',
      circuit: 'Indian Ocean',
      fortName: 'Red Fort',
      fortNumber: 3,
      kingdomForts: 12,
      title: 'Raja',
      fortsCleared: 17,
      fortTotal: 500,
      titlesWon: 1,
      titlesTotal: 50,
      wonAt: DateTime(2026, 10, 17, 22, 40, 5),
    );

void main() {
  test('each win reads as what it is', () {
    final fort = _card(WinKind.fort);
    expect(fort.kicker, 'FORT TAKEN');
    expect(fort.headline, 'RED FORT');
    expect(fort.detail, 'NEW DELHI · 3 OF 12 FORTS');
    expect(fort.buttonLabel, 'SHARE YOUR FORT');

    final kingdom = _card(WinKind.kingdom);
    expect(kingdom.kicker, 'KINGDOM CONQUERED');
    expect(kingdom.headline, 'NEW DELHI');
    expect(kingdom.detail, 'ALL 12 FORTS TAKEN · TITLE MATCH NEXT');

    final title = _card(WinKind.title);
    expect(title.kicker, 'TITLE WON');
    expect(title.headline, 'RAJA');
    expect(title.detail, 'OF NEW DELHI');
    expect(title.shareText, contains('I am the Raja of New Delhi'));
  });

  test('saved files get a readable, unique-per-second name', () {
    expect(
      cardFileName(
        _card(WinKind.title).fileStem,
        at: DateTime(2026, 10, 17, 9, 5, 7),
      ),
      'x-poker-title-raja-new-delhi-20261017-090507.png',
    );
    expect(cardFileName('***'), startsWith('x-poker-card-'));
  });

  for (final kind in WinKind.values) {
    testWidgets('the ${kind.name} card lays out at 360 x 450', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: WinCard(data: _card(kind))),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(WinCard)), const Size(360, 450));
      expect(find.text('PETER POWER'), findsOneWidget);
      expect(find.text('17 / 500'), findsOneWidget);
      expect(find.text('tenofakind.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a nameless card leaves the name off', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: WinCard(data: _card(WinKind.fort, name: ''))),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('CLAIMED BY'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the card sheet offers Save and Share', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showWinCardSheet(context, data: _card(WinKind.title)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('card-save')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('card-share')), findsOneWidget);
    expect(find.text('RAJA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
