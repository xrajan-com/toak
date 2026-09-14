import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/services/app_settings_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/venue_screen.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // Keep this CRC-valid: VenueScreen precaches every flag after its first
  // frame, so corrupt placeholder bytes fail asynchronously under full-suite
  // concurrency even when a focused widget test appears to finish first.
  final transparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  setUp(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      if (key == 'AssetManifest.json') {
        return ByteData.sublistView(Uint8List.fromList(utf8.encode('{}')));
      }
      if (key == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(<String, Object>{});
      }
      return ByteData.sublistView(Uint8List.fromList(transparentPng));
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  testWidgets('venue screen exposes truthful Aura leaderboard state on tap',
      (tester) async {
    await binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: VenueScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('GLOBAL AURA'), findsNothing);

    await tester.tap(find.text('Australasia'));
    await tester.pump();

    expect(find.text('GLOBAL AURA'), findsOneWidget);
    expect(find.text('Leaderboard service is unavailable.'), findsOneWidget);
    expect(find.text('NUR AISYAH'), findsNothing);
    expect(find.text('99 AURA'), findsNothing);
    expect(find.text('90 AURA'), findsNothing);

    await tester.tap(find.text('Choose a Kingdom'));
    await tester.pump();

    expect(find.text('GLOBAL AURA'), findsNothing);
  });

  testWidgets('Aura leaderboard closes automatically after four seconds',
      (tester) async {
    await binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: VenueScreen(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Australasia'));
    await tester.pump();
    expect(find.text('GLOBAL AURA'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3999));
    expect(find.text('GLOBAL AURA'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('GLOBAL AURA'), findsNothing);
  });

  testWidgets('Eurasia and Rest of the World Aura headings use black strips',
      (tester) async {
    await binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: VenueScreen(),
      ),
    );
    await tester.pump();

    for (final circuit in <String>['Eurasia', 'Rest of the World']) {
      await tester.tap(find.text(circuit));
      await tester.pump();

      final headingBox = tester.widget<Container>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.child is Text &&
              (widget.child! as Text).data == 'GLOBAL AURA',
        ),
      );
      expect(headingBox.color, Colors.black);

      await tester.tap(find.text('Choose a Kingdom'));
      await tester.pump();
    }
  });

  testWidgets('all circuit selectors share one row in phone landscape',
      (tester) async {
    await binding.setSurfaceSize(const Size(800, 360));
    addTearDown(() => binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: VenueScreen(),
      ),
    );
    await tester.pump();

    final chipFinders = List.generate(
      5,
      (index) => find.byKey(ValueKey('circuit-chip-$index')),
    );
    final firstCenterY = tester.getCenter(chipFinders.first).dy;

    for (final chipFinder in chipFinders.skip(1)) {
      expect(tester.getCenter(chipFinder).dy, closeTo(firstCenterY, 0.5));
    }

    final euroChip = tester.widget<Container>(chipFinders[1]);
    final euroDecoration = euroChip.decoration! as ShapeDecoration;
    final euroLabel = tester.widget<Text>(find.text('Eurasia'));

    expect(euroDecoration.color, Colors.transparent);
    expect(euroLabel.style?.color, Colors.white);

    await tester.tap(find.text('Eurasia'));
    await tester.pump();

    final selectedEuroChip = tester.widget<Container>(chipFinders[1]);
    final selectedEuroDecoration =
        selectedEuroChip.decoration! as ShapeDecoration;
    final selectedEuroLabel = tester.widget<Text>(find.text('Eurasia'));
    final leaderboardHeading = tester.widget<Text>(find.text('GLOBAL AURA'));
    final leaderboardHeadingBox = tester.widget<Container>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.child is Text &&
            (widget.child! as Text).data == 'GLOBAL AURA',
      ),
    );
    final leaderboardBody = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('Eurasia-leaderboard-body')),
    );
    final leaderboardBodyDecoration =
        leaderboardBody.decoration as BoxDecoration;
    final unavailableMessage = tester.widget<Text>(
      find.text('Leaderboard service is unavailable.'),
    );

    expect(selectedEuroDecoration.color, Colors.white);
    expect(selectedEuroLabel.style?.color, Colors.black);
    expect(leaderboardHeadingBox.color, Colors.black);
    expect(leaderboardHeading.style?.color, Colors.white);
    expect(leaderboardBodyDecoration.color, Colors.white);
    expect(unavailableMessage.style?.color, Colors.black);
    final fittedLeaderboard = find.byKey(
      const ValueKey<String>('circuit-leaderboard-fitted-box'),
    );
    expect(tester.getTopLeft(fittedLeaderboard).dy, greaterThanOrEqualTo(0));
    expect(tester.getBottomRight(fittedLeaderboard).dy, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Choose a Kingdom'));
    await tester.pump();
  });

  testWidgets('venue exposes an accessible Settings entry', (tester) async {
    await binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettingsService>(
        create: (_) => AppSettingsService(),
        child: const MaterialApp(home: VenueScreen()),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Settings'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);
    expect(find.text('Lounge sounds'), findsOneWidget);
    expect(find.text('Reduce motion'), findsOneWidget);
  });
}
