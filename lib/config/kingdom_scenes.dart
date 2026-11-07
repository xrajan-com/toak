import 'dart:math' as math;

part 'kingdom_scenes.g.dart';

/// What a kingdom scene shows. Every kingdom has one of each, plus two wild
/// cards (night skies, nature, festivals).
enum SceneKind { history, animals, bar, rock, sport, wild }

/// The quiet sound of the place behind the table, played as a loop under
/// the game (lib/services/ambience_service.dart). Each scene has one,
/// chosen in tools/scenes/ambience_beds.js.
enum AmbienceBed {
  sea,
  jungle,
  meadow,
  desert,
  night,
  snow,
  lake,
  city,
  pub,
  casino,
  stadium,
  concert,
  camp,
  festival,
  storm,
  underwater,
}

/// One of a kingdom's scenes behind the table (lib/ui/art/kingdom_scene.dart,
/// drawn from assets/scenes/<id>.json; authored in tools/scenes).
class KingdomScene {
  const KingdomScene(this.id, this.kind, this.title, this.bed);

  final String id;
  final SceneKind kind;

  /// What the scene shows, e.g. "Mehrangarh at dusk".
  final String title;

  /// The sound of the place: waves, a pub, a stadium.
  final AmbienceBed bed;

  @override
  String toString() => 'KingdomScene($id)';
}

/// Every kingdom that has scenes, by its name in lib/config/venues.dart.
Iterable<String> get kingdomsWithScenes => _kKingdomScenes.keys;

/// The scenes of [kingdom] (case-insensitive), or an empty list.
List<KingdomScene> scenesForKingdom(String kingdom) {
  final String wanted = kingdom.trim().toLowerCase();
  for (final MapEntry<String, List<KingdomScene>> e
      in _kKingdomScenes.entries) {
    if (e.key.toLowerCase() == wanted) return e.value;
  }
  return const <KingdomScene>[];
}

final Map<String, String> _lastShown = <String, String>{};
final math.Random _random = math.Random();

/// Picks the scene for one game in [kingdom]. A title match is the battle
/// for the kingdom's crown, so it always gets the war & history scene;
/// otherwise any of the seven, never the one shown last time.
KingdomScene? pickKingdomScene(
  String kingdom, {
  bool titleMatch = false,
  math.Random? random,
}) {
  final List<KingdomScene> scenes = scenesForKingdom(kingdom);
  if (scenes.isEmpty) return null;
  final String key = kingdom.trim().toLowerCase();
  if (titleMatch) {
    for (final KingdomScene s in scenes) {
      if (s.kind == SceneKind.history) {
        _lastShown[key] = s.id;
        return s;
      }
    }
  }
  final String? last = _lastShown[key];
  final List<KingdomScene> pool =
      scenes.length > 1 ? scenes.where((s) => s.id != last).toList() : scenes;
  final KingdomScene pick = pool[(random ?? _random).nextInt(pool.length)];
  _lastShown[key] = pick.id;
  return pick;
}
