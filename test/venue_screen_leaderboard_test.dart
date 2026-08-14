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

    await tester.tap(find.text('Micro'));
    await tester.pump();

    expect(find.text('GLOBAL AURA'), findsOneWidget);
    expect(find.text('Leaderboard service is unavailable.'), findsOneWidget);
    expect(find.text('NUR AISYAH'), findsNothing);
    expect(find.text('99 AURA'), findsNothing);
    expect(find.text('90 AURA'), findsNothing);

    await tester.tap(find.text('GLOBAL AURA'));
    await tester.pump();

    expect(find.text('GLOBAL AURA'), findsNothing);
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

    final usChip = tester.widget<Container>(chipFinders.last);
    final usDecoration = usChip.decoration! as ShapeDecoration;
    final usLabel = tester.widget<Text>(find.text('US Circuit'));

    expect(usDecoration.color, Colors.transparent);
    expect(usLabel.style?.color, Colors.white);

    await tester.tap(find.text('US Circuit'));
    await tester.pumpAndSettle();

    final selectedUsChip = tester.widget<Container>(chipFinders.last);
    final selectedUsDecoration = selectedUsChip.decoration! as ShapeDecoration;
    final selectedUsLabel = tester.widget<Text>(find.text('US Circuit'));
    final leaderboardHeading = tester.widget<Text>(find.text('GLOBAL AURA'));
    final leaderboardHeadingBox = tester.widget<Container>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.child is Text &&
            (widget.child! as Text).data == 'GLOBAL AURA',
      ),
    );

    expect(selectedUsDecoration.color, Colors.white);
    expect(selectedUsLabel.style?.color, Colors.black);
    expect(leaderboardHeadingBox.color, Colors.white);
    expect(leaderboardHeading.style?.color, Colors.black);
    expect(tester.takeException(), isNull);
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
    expect(find.text('Reduce motion'), findsOneWidget);
  });
}
