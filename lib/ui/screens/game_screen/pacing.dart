// lib/ui/screens/game_screen/pacing.dart
library pacing;

/// ─────────────────────────────────────────────
/// Global pacing constants for a relaxed, cinematic game flow.
/// All durations are in milliseconds unless stated otherwise.
/// ─────────────────────────────────────────────

// ── Dealer & Shuffle ─────────────────────────
/// Total Renoir shuffle duration per loop *and* loop count.
/// Each frame lasts ~80 ms × loops.
const kShuffleFrameMs =
    60; // Duration per shuffle sprite frame (~25% faster overall)
const kShuffleLoops = 6; // Number of shuffle cycles (2× longer than before)
const kShuffleMs =
    kShuffleFrameMs * 12 * kShuffleLoops; // Approx total shuffle time

/// Cards appear ~180 ms after shuffle begins (see RenoirLayer.startNewHand)
const kRevealAfterShuffleMs = 180; // Delay before cards unhide during shuffle

// ── Dealing & Animation ──────────────────────
// Requested: 4× faster dealing animations (2× again).
const kDealCardFlightMs = 130; // 520 / 4 = 130ms
const kDealGapMs = 80; // 320 / 4 = 80ms
const kDealControllerPadMs = 0; // keep reveal/landing in sync
const kStreetRevealMs = 800; // Flip/reveal for flop, turn, river
const kCardFlipTailMs = 220; // Hero’s gentle flip at end of flight

// ── Player Actions & Turn Flow ───────────────
const kPostActionPauseMs = 850; // Pause after bet/call/fold before next actor
// Requested: bots act 2× faster (0.5× time).
const kBotThinkTimeMs = 800; // 1600 / 2
const kBotActionMinDelayMs = 1400; // 2800 / 2
const kBotActionMaxDelayMs = 3250; // 6500 / 2
const kBotHighAuraThreshold = 90; // Aura gate for slower, composed tanks
const kBotActionHighAuraMinDelayMs = 1750; // 3500 / 2
const kBotActionHighAuraMaxDelayMs = 4500; // 9000 / 2
const kBotActionAbsoluteMaxDelayMs = 5500; // 11000 / 2
const kAutoSkipDelayMs = 400; // Faster skip cadence for snappier winner reveal
const kTurnClockSeconds = 18; // Per-turn countdown displayed to player

// ── Hand Resolution & Overlays ───────────────
const kShowdownSettlePauseMs = 900; // Transition to winner overlay after skip
const kOverlayMinShowMs =
    3800; // Minimum overlay duration for pacing balance (+1.5s)
