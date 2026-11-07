import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/kingdom_scenes.dart';
import 'package:ten_of_a_kind_poker/config/third_party_notices.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/ui/art/kingdom_scene.dart';

void main() {
  test('scene paths: relative commands, implicit repeats, packed numbers', () {
    final Path square = parseScenePath('m10 20l5 0 0 5-5 0z');
    expect(square.getBounds(), const Rect.fromLTWH(10, 20, 5, 5));
    final Path packed = parseScenePath('m1.5.5l-.5.5');
    expect(packed.getBounds(), const Rect.fromLTRB(1.0, 0.5, 1.5, 1.0));
    final Path curves = parseScenePath('M0 0Q10 0 10 10c0 5-5 10-10 10z');
    expect(curves.getBounds().bottom, closeTo(20, 0.01));
  });

  test('every kingdom scene parses and paints', () {
    final Map<String, dynamic> iconsJson =
        jsonDecode(File('assets/scenes/icons.json').readAsStringSync())
            as Map<String, dynamic>;
    final Map<String, Path> icons = <String, Path>{
      for (final MapEntry<String, dynamic> e
          in (iconsJson['icons'] as Map<String, dynamic>).entries)
        e.key: parseScenePath(e.value as String),
    };
    expect(iconsJson['authors'], isNotEmpty);
    for (final dynamic author
        in (iconsJson['authors'] as Map<String, dynamic>).values.toSet()) {
      final String name = (author as String).replaceAll('-', ' ');
      expect(kGameIconsCredit.toLowerCase(), contains(name), reason: name);
      expect(kGameIconsLicense.toLowerCase(), contains(name), reason: name);
    }
    for (final String kingdom in kingdomsWithScenes) {
      for (final KingdomScene scene in scenesForKingdom(kingdom)) {
        final File file = File(KingdomSceneLibrary.assetFor(scene.id));
        expect(file.existsSync(), isTrue, reason: scene.id);
        final KingdomSceneData data = KingdomSceneData.parse(
          scene.id,
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
          icons,
        );
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        data.paint(canvas, const Size(1280, 576)); // 20:9 phone
        data.paint(canvas, const Size(1024, 768)); // 4:3 tablet
        recorder.endRecording().dispose();
      }
    }
  });

  test('every kingdom has one scene of each kind and two wild cards', () {
    expect(kingdomsWithScenes, isNotEmpty);
    for (final String kingdom in kingdomsWithScenes) {
      final List<KingdomScene> scenes = scenesForKingdom(kingdom);
      expect(scenes, hasLength(7), reason: kingdom);
      for (final SceneKind kind in SceneKind.values) {
        expect(
          scenes.where((KingdomScene s) => s.kind == kind),
          hasLength(kind == SceneKind.wild ? 2 : 1),
          reason: '$kingdom $kind',
        );
      }
      expect(scenes.map((KingdomScene s) => s.id).toSet(), hasLength(7));
    }
  });

  test('scene kingdoms are exactly the real kingdoms', () {
    final Set<String> names = <String>{
      for (final VenueGroup g in kVenueGroups)
        for (final VenueTheme v in venuesForGroup(g)) v.name,
    };
    for (final String k in kingdomsWithScenes) {
      expect(names, contains(k));
    }
    // Every kingdom players can visit has its own scenes.
    for (final String name in names) {
      expect(scenesForKingdom(name), hasLength(7), reason: name);
    }
  });

  test('a title match gets the history scene; games never repeat a scene',
      () {
    final String kingdom = kingdomsWithScenes.first;
    expect(
      pickKingdomScene(kingdom, titleMatch: true)!.kind,
      SceneKind.history,
    );
    expect(pickKingdomScene(kingdom.toUpperCase()), isNotNull);
    final math.Random random = math.Random(3);
    String? last;
    for (int i = 0; i < 40; i++) {
      final KingdomScene scene = pickKingdomScene(kingdom, random: random)!;
      expect(scene.id, isNot(last));
      last = scene.id;
    }
    expect(pickKingdomScene('Atlantis'), isNull);
  });
}
