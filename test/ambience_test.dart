import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/kingdom_scenes.dart';
import 'package:ten_of_a_kind_poker/services/ambience_service.dart';

KingdomScene _scene(SceneKind kind, AmbienceBed bed) =>
    KingdomScene('test-${kind.name}-${bed.name}', kind, 'Test', bed);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final AmbienceService service = AmbienceService.instance;
  final List<String> played = <String>[];

  setUp(() {
    played.clear();
    service.debugOnPlay = (String asset, double volume) => played.add(asset);
    service.debugAssets = <String>{
      for (final AmbienceBed bed in AmbienceBed.values)
        AmbienceService.bedAsset(bed),
      for (final String r in AmbienceService.reactionNames)
        AmbienceService.reactionAsset(r),
    };
    service.setMuted(false);
  });

  tearDown(() async {
    await service.stop();
    service.debugOnPlay = null;
    service.debugAssets = null;
  });

  test('every scene has a bed, and every bed is used', () {
    final Set<AmbienceBed> used = <AmbienceBed>{
      for (final String k in kingdomsWithScenes)
        for (final KingdomScene s in scenesForKingdom(k)) s.bed,
    };
    expect(used, AmbienceBed.values.toSet());
  });

  test('every bed and reaction has its sound file', () {
    for (final AmbienceBed bed in AmbienceBed.values) {
      expect(File(AmbienceService.bedAsset(bed)).existsSync(), isTrue,
          reason: bed.name);
    }
    for (final String name in AmbienceService.reactionNames) {
      expect(File(AmbienceService.reactionAsset(name)).existsSync(), isTrue,
          reason: name);
    }
  });

  test('reactions fit the place', () {
    expect(
      AmbienceService.reactionFor(
          _scene(SceneKind.history, AmbienceBed.camp), AmbienceMoment.allIn),
      'horn',
    );
    expect(
      AmbienceService.reactionFor(_scene(SceneKind.sport, AmbienceBed.stadium),
          AmbienceMoment.heroBigWin),
      'cheer',
    );
    expect(
      AmbienceService.reactionFor(
          _scene(SceneKind.bar, AmbienceBed.pub), AmbienceMoment.heroBigWin),
      'toast',
    );
    expect(
      AmbienceService.reactionFor(_scene(SceneKind.wild, AmbienceBed.festival),
          AmbienceMoment.heroBigWin),
      'fireworks',
    );
    expect(
      AmbienceService.reactionFor(_scene(SceneKind.animals, AmbienceBed.meadow),
          AmbienceMoment.allIn),
      isNull,
    );
  });

  test('a table plays its scene bed; muted plays nothing', () async {
    await service.play(_scene(SceneKind.bar, AmbienceBed.pub));
    expect(played, <String>[AmbienceService.bedAsset(AmbienceBed.pub)]);

    played.clear();
    service.setMuted(true);
    await service.play(_scene(SceneKind.sport, AmbienceBed.stadium));
    await service.react(AmbienceMoment.heroBigWin);
    expect(played, isEmpty);
  });

  test('a reaction plays once per window', () async {
    await service.play(_scene(SceneKind.history, AmbienceBed.camp));
    played.clear();
    await service.react(AmbienceMoment.allIn);
    await service.react(AmbienceMoment.allIn);
    expect(played, <String>[AmbienceService.reactionAsset('horn')]);
  });

  test('a missing file is skipped quietly', () async {
    service.debugAssets = <String>{};
    await service.play(_scene(SceneKind.wild, AmbienceBed.storm));
    await service.react(AmbienceMoment.heroBigWin);
    expect(played, isEmpty);
  });
}
