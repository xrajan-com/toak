# Ten Of A Kind - Dart Bot Architecture Spec

Date: 2026-03-01

## Purpose

Define a stronger non-ML bot architecture for the current Flutter/Dart game.

This design is meant to:
- stay fully in-process with the existing engine
- produce readable archetypes for players
- improve decision quality beyond the current single heuristic layer
- remain debuggable, testable, and tunable without a Python/ML stack

This is a production runtime design, not a training/research design.

## Offline Blueprint vs Runtime Core

Offline advisor/generator:
- runs outside the app
- produces strategy tables, spot recommendations, or tuning data
- can be slow and compute-heavy
- does not make live decisions during a hand

Runtime bot core:
- runs inside the app during every action
- must be fast, deterministic enough to test, and easy to debug
- directly consumes the live `GameEngine` state
- decides `fold/check/call/bet/raise/all-in` in real time

Recommendation:
- keep runtime decisions in Dart
- treat any future CFR or solver output as optional input data, not as the live decision engine

## Goals

Primary goals:
- bots compare equity to price before calling
- archetypes are distinct: calling station, maniac, rock
- postflop logic understands board texture and made-hand class
- bots react to opponent tendencies, not only raw equity
- actions remain believable and legible to players

Non-goals:
- full GTO
- perfect opponent range reconstruction
- external service dependency
- model inference runtime

## Current Baseline

The current stack already has the right core primitives:
- hand evaluation in `lib/game/hand_evaluator.dart`
- showdown settlement in `lib/game/game_engine.dart`
- Monte Carlo win probability in `lib/game/bot_engine.dart`
- archetype/temperament flags in `lib/game/models.dart`

The main limitation is architecture, not missing primitives. Too much policy lives in one large heuristic function.

## Target Architecture

Split bot logic into five layers:

1. State extraction
2. Equity and hand analysis
3. Opponent model
4. Policy engine
5. Archetype overlay

Each layer should return explicit data structures, not hide logic inside a single monolithic decision function.

## Proposed Modules

Suggested files:
- `lib/game/bot/bot_state.dart`
- `lib/game/bot/bot_analysis.dart`
- `lib/game/bot/opponent_model.dart`
- `lib/game/bot/policy.dart`
- `lib/game/bot/archetypes.dart`
- `lib/game/bot/bet_sizing.dart`
- `lib/game/bot/bot_advisor.dart`

The existing `BotAdvisor.suggest()` should become a thin orchestrator over these modules.

## 1. State Extraction

Create a derived immutable bot state object per decision.

Suggested shape:

```dart
class BotDecisionState {
  final GamePhase phase;
  final int seat;
  final int pot;
  final int toCall;
  final int stack;
  final int invested;
  final int currentBet;
  final int liveOpponents;
  final int dealerDistance;
  final bool inPosition;
  final bool hasToCall;
  final bool facingAllIn;
  final bool headsUp;
  final bool multiway;
  final List<Card> hole;
  final List<Card> board;
}
```

Responsibilities:
- convert raw engine state into decision-ready fields
- normalize position and pressure
- expose only stable, poker-relevant inputs to later layers

## 2. Equity and Hand Analysis

This layer should not choose actions. It should only describe the hand.

Outputs should include:
- `winProb`
- `breakEvenEquity`
- `callEv`
- `madeHandClass`
- `drawClass`
- `boardTexture`
- `showdownValue`
- `nutPotential`

Suggested enums:

```dart
enum DrawClass { none, gutshot, openEnded, flushDraw, comboDraw, bustedDraw }
enum BoardTexture { dry, semiWet, wet, paired, monotone, fourFlush, fourStraight }
enum ShowdownValue { none, weak, medium, strong }
```

Rules:
- continue using the existing Monte Carlo equity path
- add board texture classification on top of current made-hand and draw detection
- compute explicit `breakEvenEquity = toCall / (pot + toCall)`
- compute explicit `callEv = winProb * pot - (1 - winProb) * toCall`

## 3. Opponent Model

Add a lightweight in-memory model per seat. No ML required.

Track:
- VPIP estimate
- preflop raise frequency
- c-bet frequency
- turn barrel frequency
- river aggression frequency
- fold-to-bet frequency
- fold-to-raise frequency
- showdown strength seen at reveal

Suggested shape:

```dart
class OpponentTendencies {
  double vpip;
  double pfr;
  double cbetFlop;
  double barrelTurn;
  double riverAggression;
  double foldToBet;
  double foldToRaise;
}
```

Use:
- widen bluffing against overfolders
- value bet thinner against calling stations
- fold more often versus rock aggression
- bluff less often into sticky fields

## 4. Policy Engine

This is the core poker logic before archetype flavor is applied.

It should answer:
- should fold?
- if continuing, should call or raise?
- if betting, is this value, bluff, or protection?
- what sizing bucket is appropriate?

Policy stages:

1. Hard constraints
- illegal action filtering
- all-in pressure rules
- minimum strength floors for extreme spots

2. Price check
- compare `winProb` to `breakEvenEquity`
- compare `callEv` to zero
- adjust for future realization only via small rules, not hand-wavy large bonuses

3. Spot classification
- preflop open
- preflop facing raise
- flop/turn checked to
- flop/turn facing bet
- river checked to
- river facing bet

4. Intent selection
- fold
- bluff-catch
- value-bet
- protection-bet
- semi-bluff
- pure bluff
- trap

5. Size selection
- choose a sizing bucket
- then snap to engine constraints

## 5. Archetype Overlay

Archetypes should not replace poker logic. They should bias thresholds around a common core.

### Calling Station

Profile:
- loose passive
- low raise frequency
- low bluff frequency
- low fold frequency to small and medium bets
- continues too wide with pair/draw/showdown value

Adjustments:
- reduce required equity to call
- strongly increase threshold to raise
- almost never turn medium hands into bluffs
- prefer check/call over bet/raise
- use smaller value bets

Player-facing lesson:
- bet for value
- do not bluff too much

### Maniac

Profile:
- loose aggressive
- high bluff frequency
- high probe and stab frequency
- overbets more often
- continues wide and raises wide

Adjustments:
- slightly reduce required equity to continue
- reduce threshold to raise
- increase checked-to bluff frequency
- allow overbet buckets on turn and river
- accept higher variance lines

Player-facing lesson:
- trap stronger hands
- bluff-catch wider

### Rock

Profile:
- tight passive
- folds marginal hands early
- rarely bluffs
- when betting big, range is strong

Adjustments:
- increase preflop playable threshold
- increase required equity to continue
- sharply increase threshold to raise
- use strong showdown/value lines only
- cap bluff frequency very low

Player-facing lesson:
- fold when the rock wakes up

## 6. Bet Sizing System

Do not hardcode sizing inside action selection branches.

Introduce sizing buckets:
- `block`: 20-30% pot
- `small`: 33% pot
- `medium`: 50% pot
- `large`: 75% pot
- `polar`: 100% pot
- `overbet`: 125-175% pot

Archetype defaults:
- calling station: mostly `block`, `small`, `medium`
- maniac: `medium`, `large`, `polar`, `overbet`
- rock: mostly `small`, `medium`, occasional `large`

Sizing then passes through:
- min raise rules
- stack cap
- all-in conversion
- engine increment snapping

## 7. Board Texture Rules

Add explicit texture adjustments:

Dry boards:
- fewer bluffs needed
- more small c-bets

Wet boards:
- stronger value threshold for thin betting
- more protection betting
- less pure bluffing into multiple players

Paired boards:
- more c-bet pressure possible
- more trap logic for nutted hands

Four-straight / four-flush rivers:
- reduce thin value
- increase caution for rocks
- allow maniacs to polarize

## 8. Range Approximation

Do not jump to full range solving. Use a lightweight range model.

For each opponent, infer a coarse range bucket:
- capped weak
- medium showdown
- strong value
- draw-heavy
- uncapped aggressive

Derive from:
- preflop line
- street aggression
- bet size
- multiway vs heads-up

This is enough to improve decision quality materially without solver infrastructure.

## 9. Runtime Decision Flow

Target flow:

```text
GameEngine state
-> BotDecisionState
-> HandAnalysis
-> OpponentSnapshot
-> BasePolicyDecision
-> ArchetypeAdjustment
-> BetSizing
-> LegalActionClamp
-> Final action
```

Suggested result object:

```dart
class BotDecision {
  final ActionType action;
  final int toAmount;
  final String intent; // value, bluff, bluffCatch, protection, trap
  final double confidence;
  final double winProb;
  final double breakEvenEquity;
}
```

This should make debugging and analytics much easier.

## 10. Logging and Debuggability

Every bot action should be explainable.

Add optional debug traces like:
- `winProb=0.31`
- `breakEven=0.22`
- `callEv=+420`
- `drawClass=flushDraw`
- `boardTexture=wet`
- `villainRange=strongValue`
- `intent=bluffCatch`
- `archetype=callingStation`

This should not be shown to players by default, but it should be available in debug/test mode.

## 11. Testing Strategy

Add focused tests for:
- preflop threshold differences by archetype
- pot-odds-based calls
- busted-draw bluff frequencies
- rock overfold behavior versus aggression
- calling-station under-bluff behavior
- maniac overbet and stab behavior
- board-texture adjustments

Add snapshot-style fixtures:
- exact board
- exact stacks
- exact current bet
- exact archetype
- expected action family

Prefer assertions like:
- rock folds
- calling station calls, does not raise
- maniac bets or raises, not checks

instead of brittle exact sizing assertions in every case.

## 12. Implementation Order

Phase 1:
- extract `BotDecisionState`
- extract `HandAnalysis`
- keep existing behavior intact

Phase 2:
- extract archetype overlay
- formalize calling station / maniac / rock thresholds

Phase 3:
- add opponent tendency tracking
- connect simple exploit adjustments

Phase 4:
- add board texture system and sizing buckets

Phase 5:
- add debug trace output and broader regression fixtures

## 13. Recommended Near-Term Refactor

Do next:

1. move state extraction out of `BotAdvisor.suggest()`
2. move draw/made-hand/price calculations into a reusable analysis object
3. centralize archetype threshold tables in one file
4. centralize bet sizing in one file
5. keep the runtime path deterministic enough for tests

Do not do yet:
- external Python dependency
- RLCard integration
- CFR solver integration
- model serving

## 14. Success Criteria

This architecture is successful if:
- bots are stronger without becoming unreadable
- archetypes remain obvious to players
- call/fold logic is price-aware
- bluffing is controlled and auditable
- new strategy tweaks land in small modules instead of one giant function
- tests can pin behavior by spot and archetype

## Summary

The right next step is not ML. It is a cleaner Dart bot stack with:
- explicit state extraction
- explicit hand and price analysis
- lightweight opponent modeling
- a shared base policy
- archetype-specific overlays
- centralized sizing rules

That gets most of the practical value now, keeps the app architecture clean, and leaves the door open for future offline solver input later.
