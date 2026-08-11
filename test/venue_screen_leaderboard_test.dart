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
