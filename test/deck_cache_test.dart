import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/utils/deck_cache.dart';

void main() {
  tearDown(() {
    DeckCache.manifestLoaderOverride = null;
    DeckCache.clearCache();
  });

  test('concurrent deck warmups share one initialization future', () async {
    final Completer<Iterable<String>> manifest = Completer<Iterable<String>>();
    int loads = 0;
    DeckCache.manifestLoaderOverride = () {
      loads++;
      return manifest.future;
    };

    final Future<void> first = DeckCache.ensureDeckReady();
    final Future<void> second = DeckCache.ensureDeckReady();

    expect(identical(first, second), isTrue);
    expect(loads, 1);

    manifest.complete(const <String>[]);
    await Future.wait(<Future<void>>[first, second]);
    await DeckCache.ensureDeckReady();

    expect(loads, 1);
  });

  test('a manifest failure can be retried', () async {
    int loads = 0;
    DeckCache.manifestLoaderOverride = () async {
      loads++;
      if (loads == 1) throw StateError('temporary manifest failure');
      return const <String>[];
    };

    await expectLater(DeckCache.ensureDeckReady(), throwsStateError);
    await DeckCache.ensureDeckReady();

    expect(loads, 2);
  });

  testWidgets(
    'default loader reads Flutter generated asset manifest',
    (_) async {
      expect(DeckCache.manifestLoaderOverride, isNull);

      await DeckCache.ensureDeckReady();
      await DeckCache.ensureDeckReady();
    },
  );
}
