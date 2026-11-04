// lib/ui/screens/game_screen/pacing.dart
library pacing;

/// ─────────────────────────────────────────────
/// Global pacing constants: the tempo of a good online table. Bots think
/// like people (snap the obvious, take their time on the close ones), but
/// the ceremony around each hand is brief, as on any online site.
/// All durations are in milliseconds unless stated otherwise.
/// Build 92 trimmed the per-hand ceremony from about 8 s to about 4 s
/// (shuffle 4.3 s -> 1.4 s, winner banner 3.8 s -> 2.6 s) and tightened bot
/// tempo by about a quarter; see test/tournament_length_report_test.dart.
/// ─────────────────────────────────────────────

// ── Dealer & Shuffle ─────────────────────────
/// Total Renoir shuffle duration per loop *and* loop count.
/// Each frame lasts ~80 ms × loops.
const kShuffleFrameMs =
    60; // Duration per shuffle sprite frame (~25% faster overall)
const kShuffleLoops = 2; // A quick riffle: 1.4 s (was 6 loops, 4.3 s)
const kShuffleMs =
    kShuffleFrameMs * 12 * kShuffleLoops; // Approx total shuffle time

/// Cards appear ~180 ms after shuffle begins (see RenoirLayer.startNewHand)
const kRevealAfterShuffleMs = 180; // Delay before cards unhide during shuffle

// ── Dealing & Animation ──────────────────────
// Keep the fast 80 ms deal cadence, but let each flight overlap for long
// enough to receive roughly 11 display frames at 60 Hz (and 22 at 120 Hz).
// This preserves the quick deal while making each card path easier to track.
const kDealCardFlightMs = 180;
const kDealGapMs = 80; // 320 / 4 = 80ms
const kDealControllerPadMs = 0; // keep reveal/landing in sync
const kStreetRevealMs = 800; // Flip/reveal for flop, turn, river
const kCardFlipTailMs = 220; // Hero’s gentle flip at end of flight

// ── Player Actions & Turn Flow ───────────────
const kPostActionPauseMs = 500; // Pause after bet/call/fold before next actor
// Requested: bots act 2× faster (0.5× time).
const kBotThinkTimeMs = 800; // 1600 / 2
const kBotActionMinDelayMs = 1000; // floor for a real decision (was 1400)
const kBotActionMaxDelayMs = 3250; // 6500 / 2
// Superseded by the think-time model in lib/game/bot/think_time.dart, which
// replaced the "high aura = uniformly slower" band with calibration against
// decision difficulty. Kept because kBotActionHighAuraMaxDelayMs is still a
// sane upper reference and removing public constants is a breaking change
// for anything outside lib/; no live code path reads them now.
const kBotHighAuraThreshold = 90; // Aura gate for slower, composed tanks
const kBotActionHighAuraMinDelayMs = 1750; // 3500 / 2
const kBotActionHighAuraMaxDelayMs = 4500; // 9000 / 2
const kBotActionAbsoluteMaxDelayMs = 4500; // the longest tank (was 5500)
// Bot think-time model (see lib/game/bot/think_time.dart). Aura no longer
// sets raw speed — it sets how well think time tracks how hard the decision
// actually is. These are the per-seat baseline tempos that model modulates.
const kBotTempoMinMs = 1100; // baseline tempo, low aura (was 1500)
const kBotTempoMaxMs = 1900; // baseline tempo, high aura (was 2600)
const kBotTrivialFloorMs = 500; // a genuinely trivial decision may snap
const kAutoSkipDelayMs = 400; // Faster skip cadence for snappier winner reveal
const kTurnClockSeconds = 18; // Per-turn countdown displayed to player

// ── Hand Resolution & Overlays ───────────────
const kShowdownSettlePauseMs = 700; // Transition to winner overlay after skip
const kOverlayMinShowMs =
    2600; // Winner banner per hand (was 3800); long enough to read the hand
