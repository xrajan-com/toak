/// De-duplicates the audible cue for an actionable hero turn.
///
/// A hero may act again without [phase] changing (for example, after a raise
/// is called around the table), so the engine event revision is part of the
/// identity. Conversely, pause/resume and repeated widget synchronization do
/// not change the identity and therefore cannot replay the sound.
class HeroTurnCueTracker {
  String? _lastPlayedTurn;

  bool shouldPlay({
    required bool heroCanAct,
    required int handNumber,
    required String phase,
    required int eventRevision,
  }) {
    if (!heroCanAct) return false;

    final String turn = '$handNumber:$phase:$eventRevision';
    if (_lastPlayedTurn == turn) return false;
    _lastPlayedTurn = turn;
    return true;
  }
}
