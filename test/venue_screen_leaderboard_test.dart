import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ten_of_a_kind_poker/ui/screens/venue_screen.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  final transparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
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

  testWidgets('venue screen exposes circuit leaderboard on tap',
      (tester) async {
    await binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: VenueScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('LEADERBOARD'), findsNothing);

    await tester.tap(find.text('Micro'));
    await tester.pump();

    expect(find.text('LEADERBOARD'), findsOneWidget);
    expect(find.text('NUR AISYAH'), findsOneWidget);
    expect(find.text('99 AURA'), findsOneWidget);
    expect(find.text('90 AURA'), findsOneWidget);

    await tester.tap(find.text('LEADERBOARD'));
    await tester.pump();

    expect(find.text('LEADERBOARD'), findsNothing);
  });
}
