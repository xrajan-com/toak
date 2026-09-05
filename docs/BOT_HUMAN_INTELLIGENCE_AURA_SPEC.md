# Human-Like Bot Intelligence, Driven by Aura

Date: 2026-09-05
Status: proposal — extends BOT_ARCHITECTURE_SPEC.md, does not replace it

## Core thesis

The one-word gap is **human**. Concretely: no two real players act
identically in an identical spot, and the same player doesn't act
identically to themselves from one instance of that spot to the next.
Aura is the mechanism for that, but only if it is modeled as **the size
of the random deviation from the correct action, not the direction of a
fixed bias**.

The current codebase mostly does the latter: `lowAura` consistently
shifts thresholds one way (looser calls, wider continues — see
`playableThreshold -= 0.06` under `lowAura` in advisor.dart). That
produces a bot that is predictably bad in one direction, which is a
difficulty slider, not a personality. A human fish is not "always 6%
looser than correct" — they are sometimes far too loose (pay off a river
bet they should snap-fold) and sometimes far too tight (fold a hand a
child would call), in the same session, sometimes in situations that look
similar. The unpredictability *is* the tell that they're human.

So the model to build toward: compute the correct action/threshold the
same way the engine does today (equity, breakeven, board read, opponent
model — this part doesn't change), then apply a **zero-mean noise term**
on top of it before the safety guard clamps it to something legal. Aura
sets the *spread* of that noise (`sigma`), not its sign:

```
effective_threshold = correct_threshold + noise
noise ~ distribution centered on 0, spread = sigma_max * (1 - auraSkill)^p
```

A 95-Aura bot's noise is nearly zero — it plays close to correct, which
is what "hard to read" actually means at the top: not "always right," but
"deviates so little you can't find the seam." A 30-Aura bot's noise is
wide enough that it will sometimes over-risk a spot a pro would fold and
sometimes under-risk (get scared off) a spot a pro would jam — in the same
sitting, unpredictably, exactly like point-blank human variance. This
reframes every "low aura = X" rule already in advisor.dart: the rule
shouldn't say low aura folds/calls more, it should say low aura's *result*
is noisier around the correct answer, with the specific outcome re-rolled
per decision.

One refinement worth building in from the start: pure per-decision noise
reads as random, not human — real erratic play is streaky (a human who
just got cracked makes several bad-risk decisions in a row, not one
isolated blip). So the noise should ride on top of a slower, autocorrelated
"mood" process (a short random walk, decaying each hand) whose amplitude
is also scaled by `1 - auraSkill`, rather than being redrawn independently
every time. That mood process is also the natural home for the tilt
behavior described below (item D) — they're the same mechanism.

This same noise-on-the-correct-answer model is the fix for the timing
problem from the previous round too: don't compute "hesitation" from hand
strength: compute the decision-risk score off the correct/optimal read,
then apply aura-scaled noise to *how accurately the bot's outward
hesitation matches the actual risk* — a low-aura bot should sometimes
tank on an easy decision and sometimes snap a hard one, because part of
being readable as human is occasionally misjudging how hard your own
decision is.

## Purpose

Answer one question concretely: how do we make bots feel like they are
*thinking*, not computing, and how does a bot's Aura score control that,
end to end. This doc audits what already does this today, names the real
gaps, and proposes the next slice of work — sized so it lands inside the
existing Dart runtime, no solver/ML-in-the-loop.

## What already makes bots feel human (confirmed in the current codebase)

This is further along than a typical "bot difficulty slider." Four systems
already tie behavior to Aura:

1. **Trait assignment.** `GameEngineBotLogic.assignBotTraits` (advisor.dart)
   draws `BotTemperament` (`aggressive`/`stoic`/`worldChamp`) and `BotSkill`
   (`killer`/`fluke`) from Aura-weighted distributions, seeded per table so
   it's deterministic but not obviously formulaic. A 96-Aura bot is drawn
   from a pool that's 58% worldChamp / 90% killer-skill; a 50-Aura bot is
   drawn from a pool that's 8% worldChamp / 20% killer-skill. Same Aura
   value, different table, can still land on a different draw — that's
   good, it avoids bots feeling like reskinned difficulty tiers.

2. **Continuous skill scaling.** Beyond the categorical draw, `auraSkill`
   (Aura/100, floored at 0.80 for guaranteed "world champ killer" seats) is
   threaded through essentially every decision point in advisor.dart —
   playable-hand thresholds, fold bias, raise thresholds, river bluff
   frequency, value-bet chance, push/shove frequency. This is why two
   `killer`-skill bots at Aura 72 and Aura 97 don't play identically.

3. **Opponent modeling with a grudge mechanic.** `BotOpponentMemory` tracks
   VPIP, PFR, c-bet%, barrel%, fold-to-bet/raise, and river aggression per
   opponent, with recent action weighted far more than old history
   (`aggressionHeat *= 0.84`, `pressureHeat *= 0.78` per hand). `revengeSpot`
   detection means a bot that just got aggressed by a specific opponent
   plays back at them differently next hand — a small but genuinely human
   "I remember what you did" signal, and it already feeds `advisor.dart`
   (aggro/threshold shifts) rather than sitting unused.

4. **Timing that reads as thought, not a poll interval.** This is the
   strongest existing piece and worth calling out because it's easy to
   under-rate: `_scheduleBotActionIfNeeded` / `_fixedBotDelayFor` in
   `game_screen.dart` derives a base think-time from Aura (interpolated
   45–95 across the min/high-Aura delay bands in `pacing.dart`), then
   multiplies it by temperament, decision *strength*, and decision
   *confidence* factors, adds a fast-path for trivial free checks, and
   layers random jitter so no two bots ever tank for an identical duration.
   High-Aura bots (>= `kBotHighAuraThreshold`, 90) get a longer floor and
   tank noticeably longer on strong hands — i.e. the "composed player who
   takes their time with the big decision" read is already built.

5. **Offline learning loop.** `PokerBotLearningService` trains a small
   linear model from real decision logs (`BotDecisionLogEntry`, which
   already records Aura, temperament, skill, and the field-read features)
   and `BotPolicyAdjustment` (policy_model.dart) applies the learned
   call/raise/bluff/value/size biases at runtime, with `aura_skill` as one
   of the model's own input features. So Aura already shapes both the
   hand-written heuristics *and* the learned correction layer on top of them.

None of this needs to be re-built. The gap is narrower than "bots don't
feel human" — it's specific, and each piece below is additive.

## The real gaps

**The core problem: timing and "boldness" are wired to hand strength, not
to decision risk.** Confirmed in `advisor.dart` and `game_screen.dart`,
not a guess:

- `_estimateConfidence` (advisor.dart) is a function of hole-card rank
  (`hiScore`, `loScore`, pocket pair, suitedness). It is a *hand-quality*
  score. It is not "how sure am I that the action I picked is correct,"
  which is what "confidence" should mean for a timing tell.
- Because of that, `strength` and `confidence` are near-duplicate signals.
  Both feed `_scheduleBotActionIfNeeded`'s delay math in the same
  direction: weak hand -> both factors say "slow," strong hand -> both say
  "fast" (`_strengthDelayFactor`: 1.15x at strength 0, 0.70x at strength 1;
  `_confidenceDelayFactor`: 1.35x at confidence 0, 0.70x at confidence 1).
- The result: a genuinely trivial fold (72o facing a raise — an instant,
  zero-doubt decision for any real player) and a live bluff (also a weak
  hand, and confidence gets multiplied down further in the bluff branches,
  e.g. `confidence * 0.6`) land in the *same* "slow" timing bucket. There
  is no separate signal for "this decision is close/risky" versus "this
  hand is bad." Meanwhile a monster hand always gets the fast multiplier,
  so bots never show the hesitation a real player has when deciding how to
  size a big hand for max value, whether to slowplow, or whether a scary
  runout just changed the read.
- Net effect: nothing in the bot's outward timing correlates with *risk*.
  A bluff doesn't read as a bluff. A hero call doesn't read as a hero call.
  A snap-fold of garbage tanks as long as anything else. That's the
  concrete reason none of "they don't bluff," "they don't fear," "they
  don't take time when nervous" show up on the felt table even though the
  underlying poker logic (bluff chances, fold/call math, aura scaling)
  is already there — the tell channel is measuring the wrong thing.

**Fix direction:** add an explicit decision-risk score, independent of
hand strength — e.g. `risk = 1 - clamp(|winProb - breakEvenEquity| * k, 0, 1)`
for continues, plus a flat bump whenever the chosen line is a bluff,
semi-bluff, thin value bet, or hero call/fold. Drive tank-time and jitter
off `risk`, not off `strength`/`confidence` alone. A trivial fold or a
snap-value shove should be near-instant regardless of hand strength; a
close bluff-catch or a bluff attempt should be the slowest thing at the
table, because that is the one moment a real opponent is actually
deciding, not just executing.

**Aura's second job: not just skill, variance.** Right now Aura mostly
sets a *mean* — better thresholds, better bluff/value balance, a longer
think-time floor. That alone still produces a fairly smooth, predictable
curve: give the aura value, and you can guess the bot's behavior closely.
Real unpredictability needs Aura to also set a *variance/entropy* dial —
how much a given bot's behavior wobbles hand-to-hand around its own
mean, and how often it deviates from "textbook" on purpose. Concretely:
low-Aura bots should have wide behavioral variance (capable of a wild bluff
or a scared fold that's off-book for them, sometimes profitable, sometimes
a spew) while high-Aura bots should have narrow variance around a sharp
mean *and* deliberately inject just enough deception (mixed strategies —
sometimes checking the nuts, sometimes betting air) that they aren't
purely readable either. This is a different axis from the existing
temperament/skill draw, and it's the piece that makes two bots at the
same Aura genuinely feel different from each other and from themselves
hand to hand, not just different tiers of "good."

**A. Mistakes are smooth, not shaped.** Low Aura today mostly means "the
same decision logic, nudged toward looser/worse thresholds." A human fish
doesn't play a slightly-worse version of a good player's strategy — they
have *characteristic* leaks: they overvalue top pair no matter the runout,
they forget a flush completed on the river, they limp hands they should
raise, they slowplay big hands into a scare card. Right now there's no
per-Aura-band catalog of *which* mistake a bot is prone to, so every low-
Aura bot leaks equity the same generic way instead of leaking it in a
distinct, learnable-by-the-human-opponent way.

**B. No bet-sizing tells.** Sizing doesn't yet route through the bucketed
system BOT_ARCHITECTURE_SPEC section 6 proposes
(`block`/`small`/`medium`/`large`/`polar`/`overbet`) — grep confirms there's
no `SizingBucket` or equivalent today. That's also the natural place to
put a human tell: a low-Aura bot sizing bigger for value and smaller/
hesitant for bluffs is a classic, exploitable, *readable* pattern; a high-
Aura bot should size its value and bluff ranges the same way (balanced),
which is exactly the kind of thing an attentive human opponent notices and
feels rewarded for noticing.

**C. No board-texture or range-approximation layer.** Sections 2, 7, and 8
of BOT_ARCHITECTURE_SPEC (board texture classes, draw classes, coarse
opponent range buckets) aren't implemented yet — advisor.dart reasons about
made-hand strength and price, but not "this river completes a lot of
straights, tighten the value range" or "this villain's line caps them at
medium showdown value." This is the single biggest lever for making
*high*-Aura bots read as smart rather than just "folds and raises at
better frequencies." It's also the precondition for B, since sizing should
key off texture.

**D. No bot-side tilt/mood.** The memory system tracks the *opponent's*
heat, but a bot has no internal state that responds to its own bad beats,
coolers, or heaters. A human who just got cracked by a two-outer plays
differently for the next few hands — loosens up, chases, sometimes goes
uncharacteristically aggressive. This is a cheap, high-signal addition and
maps naturally onto Aura: low-Aura bots should be tilt-prone (visible,
exploitable emotional swings), high-Aura bots should be closer to immune
(the "ice in their veins" read), which is a distinctly human axis that's
orthogonal to raw hand-reading skill.

**E. advisor.dart is still the single 2,475-line function BOT_ARCHITECTURE_SPEC
Phase 1 already flagged for extraction.** None of A–D are blocked by this,
but all four will be easier, safer, and more testable once state
extraction / hand analysis / policy / archetype overlay are split out as
that spec proposes. Worth doing Phase 1 concurrently with C, since board
texture is naturally a new module (`bot_analysis.dart`) rather than more
branches inside the existing function.

## Proposed Aura → human-trait mapping (new axes, additive to the existing temperament/skill table)

| Aura band | Mistake style | Sizing tell | Tilt susceptibility | Read depth |
|---|---|---|---|---|
| 90–100 | Rare, high-leverage-only errors (e.g. occasional over-fold to a very large river bet from a bot it has no read on) | Balanced value/bluff sizing, occasional deliberate size-based deception | Near-immune; one bad beat barely moves thresholds | Full texture + coarse range read on villain |
| 75–89 | Slight overvaluation of one-pair hands on scary turns; light thin-value leaks | Mostly balanced, small tell under time pressure (multiway pots) | Low; short memory of bad beats (1–2 hands) | Texture-aware, shallow range read |
| 55–74 | Chases draws slightly past price; occasional missed value bet on the river | Noticeably bigger value bets than bluffs | Moderate; 3–5 hand loosening after a cooler | Made-hand strength only, no texture |
| 35–54 | Overvalues top pair / overpairs on any runout; limps hands it should raise | Sizing correlates directly with hand strength (easy tell) | High; visible tilt spiral (widens calling range, bluffs more) after a bad beat | Own cards only, ignores board/opponent signal |
| < 35 | Calls too wide preflop; slowplays big hands too long; occasional pure misclick-style spew | Sizing is essentially random relative to strength | Very high; can tilt for the rest of an orbit | None |

This table is deliberately about *behavioral flavor*, not EV — it should sit
as an overlay on top of the existing temperament/skill draw and auraSkill
scaling, the same way BOT_ARCHITECTURE_SPEC's archetype overlay sits on top
of the base policy engine.

## Implementation order

1. **Bot tilt/mood state (D).** Add a per-bot `moodHeat` (mirrors the shape
   of `BotOpponentMemory.aggressionHeat`, but keyed to the bot's *own*
   recent bad-beat/cooler history) that decays each hand like the existing
   heat trackers. Gate its magnitude by `1 - auraSkill`. Cheapest change,
   immediately visible, no architecture change required.

2. **Mistake catalog (A).** Instead of only shifting thresholds, give each
   Aura band a small table of discrete "leak" behaviors (limp-raise-worthy
   hands, missed river value, chase-past-price) that fire probabilistically
   at a rate that falls as Aura rises. This is additive to advisor.dart and
   testable the same way BOT_ARCHITECTURE_SPEC section 11 already tests
   archetypes: assert the *family* of action, not exact sizing.

3. **BOT_ARCHITECTURE_SPEC Phase 1 + board texture (E, then C).** Extract
   `BotDecisionState` / `HandAnalysis` first (behavior-preserving), then add
   `BoardTexture`/`DrawClass` classification as new pure functions in the
   new analysis module. This is the highest-effort item but also the one
   that most changes how *smart* high-Aura bots feel, since it's what lets
   them reason about the board instead of just their own hand strength.

4. **Sizing buckets + tells (B).** Once texture exists, route sizing
   through the bucket system and make bucket selection Aura-dependent
   (balanced at high Aura, strength-correlated at low Aura). This is also
   where `poker_bot_training_reference.txt`'s blocker-bluff and polarized-
   bet concepts get a real home instead of living only as reference notes.

## Validation

The existing pipeline already supports this without new infrastructure:

- Extend `export_bot_dataset.dart` / `BotDecisionLogEntry` to log the new
  mood/mistake/sizing-bucket fields, the same way `aura`, `temperament`,
  and `skill` are logged today.
- Add archetype-family assertions per Aura band in the existing
  `bot_advisor_*_test.dart` style (rock folds, calling station calls-not-
  raises, maniac bets-not-checks) — extend with "low-Aura bot's bet size
  correlates with hand strength across N sampled spots" and "bot's raise
  frequency next hand rises after a logged bad-beat hand, scaled by
  1 - auraSkill."
- A simple statistical-fingerprint check is enough to validate "feels
  human": compare the distribution of bet-sizing-by-street and VPIP/PFR by
  Aura band against typical human-population ranges (the reference doc
  already has the numbers to eyeball this against). No need for a live
  human-vs-bot blind study to get most of the value here.

## Non-goals (unchanged from EXPERIMENTAL_POKER_AI.md)

- No RLCard/eval7/solver in the live decision loop. Aura-driven "thinking"
  stays a Dart heuristic + learned-linear-weights system, as today.
- No change to the gameplay trust model — Aura-driven bot behavior is
  entertainment tuning, not a fairness or payout mechanism.

## Status update: the two flat-zero axes now have a real v1

Following the "these have to be made 10/10" conversation, the table/game-
awareness and ICM/goal-awareness axes are no longer unimplemented. What
shipped:

- `lib/game/bot/icm.dart` — a pure, dependency-free Independent Chip Model
  (Malmuth-Harville) equity function, memoized over the O(2^n) reachable
  subsets so it's cheap even recomputed per decision. Unit-tested against
  its two hard invariants (equities sum to the prize pool; a bigger stack
  never has less equity than a smaller one) rather than hand-typed
  reference numbers.
- `lib/game/bot/tournament_context.dart` — `TableStanding.compute(eng, seat)`
  (rank, chip lead, average stack, `StackThreat` classification, and a
  `bubbleFactor` that hits 1.0 exactly one elimination from a payout-count
  change) and `IcmDecision.evaluate(...)` (the $ equity of continuing vs.
  folding a stack-off, correctly chip-conserving across the fold/win/lose
  branches — this took two real bugs out in review: an alive-player filter
  that wrongly excluded a mid-all-in opponent sitting at 0 chips before
  their hand resolves, and a stack-delta formula that didn't correctly
  account for chips already pushed into the pot before hero acts).
- `lib/game/bot/icm_guard.dart` — `BotIcmGuard.adjust(...)`, wired into
  `BotAdvisor.suggest`'s return path after `BotSafetyGuard`. Implements the
  noise-around-the-correct-answer model from this doc's core thesis:
  computes the ICM-correct read, blends in a standings-derived goal bias
  (lock up a position near a pay jump; gamble when crippled with little
  left to protect), then perturbs it with the same `sigma = sigmaMax *
  (1 - auraSkill)^p` aura-scaled noise used elsewhere, before deciding
  whether to override the base chip-EV action.
- `GameEngine.payoutForRank(rank)` — a one-line public accessor added so
  the bot layer can read the live payout table without reaching into
  engine internals.
- `test/bot_icm_awareness_test.dart` — pure-math invariants, standings
  computation, a no-op-in-cash-play regression guard, and a numerically
  verified fold-up-the-bubble case (a spot that's +40 chip-EV but a
  confirmed ~-65 -$EV once ICM is applied, at a near-zero-noise/high-aura
  setting, so the assertion is deterministic).

This entire layer is gated behind `eng.config.payoutTable != null`, and
further gated within that to genuine tournament-life spots (a shove, or a
call that would leave hero at ~0 chips) in a clean two-way pot — every
existing cash-style config and every existing test is unaffected; the only
test file in the whole suite that even references `payoutTable` before
this change tests an unrelated config object, never a live engine.

**Honest v1 scope, not yet 10/10:**

- Multiway all-ins (three or more live stacks contesting one pot) fall
  back to chip-EV only — `IcmDecision.evaluate` documents this and returns
  a coarser read rather than guessing. A real multiway ICM push/fold model
  is a solvable follow-up, not a redesign.
- The win-probability fed into the ICM comparison reuses the existing
  hand-strength proxy. It captures the showdown-equity side of a shove
  correctly; it doesn't yet fold a bluff's fold-equity into the ICM math
  itself.
- `TableStanding.threatFor(eng, seat)` is now wired into ordinary
  (non-all-in) decision thresholds too, not just literal stack-off spots:
  `BotAdvisor.suggest` reads the current aggressor's `StackThreat` (gated
  identically — tournament mode only) and nudges `potOddsBias` by it
  (crippled +0.035, shortStack +0.018, mediumStack 0.0, bigStack -0.01,
  chipLeader -0.02) — a short/crippled stack's aggression is often
  necessity, not strength, so continuing wider is correct; a chip
  leader's aggression carries more real threat, so it earns more respect.
  Doing this wiring surfaced a genuine bug: `StackThreat.chipLeader` was
  declared but `classify()` never actually produced it (only
  crippled/short/big/medium — a chip leader with an average-ish ratio
  would silently fall through to `mediumStack`). `threatFor` now checks
  the seat's chips against the field's max before falling back to
  `classify()`, and two new unit tests lock the fix in (chip-leader-vs-
  crippled on the existing 4-way bubble fixture, and a short-but-not-
  crippled stack under a different bigBlind/stack shape). This file's own
  Phase 1 modularization is still the right precondition for extending
  this further without the threshold stack becoming unreviewable.
  `_humanizeDecision`'s independently-recomputed aggressor context is
  deliberately still untouched here — a real scope limit, not an
  oversight.
- Hero's own bluffing/initiative logic still doesn't read opponent threat
  when hero is the one applying pressure, only when reacting to someone
  else's — the natural next slice of this same axis, not yet started.
- Verification here was static: careful manual review, balanced-syntax
  checks (parens/braces/brackets, comment- and string-stripped, run
  directly against the real files in this repo — not a scratch copy), and
  hand-derived/Python-cross-checked numeric expectations for the test
  file. A real Dart/Flutter SDK was confirmed present on this machine, but
  this session's shell runs inside a sandboxed Linux VM on the same
  machine and can't execute the SDK's native macOS binaries (`Exec format
  error`), so `flutter analyze`/`flutter test` still couldn't be run
  directly from here. Run `flutter test test/bot_icm_awareness_test.dart`
  (and the full suite, to confirm the gating is truly inert for existing
  tests) from a real terminal before merging.
