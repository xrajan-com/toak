# Modularization Blueprint

## Goal

Modularize the app around stable business domains and feature boundaries so the codebase can keep growing without central files turning into permanent bottlenecks.

This is not a one-pass folder shuffle. The long-term target is:

- small composition roots
- explicit domain boundaries
- feature-owned presentation flows
- infrastructure isolated behind services
- game logic kept UI-free and testable

## Current Hotspots

The main scaling risks are structural, not just file length:

- `lib/main.dart` mixes bootstrap, providers, startup flow, and navigation.
- `lib/ui/screens/game_screen.dart` still acts as the gameplay orchestration root even though some pieces already live under `lib/ui/screens/game_screen/`.
- `lib/game/game_engine.dart` and `lib/game/bot/advisor.dart` contain core runtime logic that should stay modular and UI-independent.
- `lib/ui/screens/venue_screen.dart` mixes navigation, profile access, progression, and presentation.
- `lib/ui/widgets/slash_avatar.dart` is large enough to be its own feature-supporting package inside the repo.
- `lib/services/` is a mixed bag of app services, infrastructure adapters, and feature-specific state.

## Target Module Map

### `lib/app/`

Owns application composition only.

- bootstrap and global error handling
- provider registration
- top-level navigation entry points
- startup shells like disclaimer/auth gate

`app` may depend on any feature or infrastructure module, but other modules should not depend on `app`.

### `lib/core/`

Cross-cutting primitives that are not poker-specific and are reused in multiple places.

- small utilities
- extensions
- app-wide policies

Keep this dependency-light. `core` should not depend on `ui/screens`, feature modules, or backend code.

### `lib/game/`

Poker domain and engine runtime.

- cards, deck, RNG, hand evaluation
- engine state transitions
- bot logic and simulations
- game models/events

Rules:

- no widget imports
- no Firebase or HTTP dependencies
- no screen-specific assumptions

### `lib/features/`

Feature entrypoints and, over time, feature-owned code.

Initial target features:

- `auth`
- `venue`
- `gameplay`
- `profile`
- `campaign`
- `leaderboard`

Each feature should converge toward:

- `presentation/`
- `application/`
- `domain/` when needed
- `data/` when needed

### `lib/services/`

Temporary infrastructure layer while the repo migrates.

Long term, services should be split into:

- app infrastructure shared across features
- feature-specific data/services moved under the owning feature

Examples:

- auth and profile data belong closer to `features/auth` and `features/profile`
- campaign progress belongs closer to `features/campaign`
- ads and leaderboard integrations can remain infrastructure-style services

### `lib/ui/widgets/` and `lib/ui/theme/`

Shared presentation primitives only.

These should not own feature workflows or domain decisions.

### `backend/`

Separate deployable boundary. Keep contracts explicit and avoid leaking backend assumptions into the Flutter domain layer.

## Dependency Rules

Allowed flow:

1. `app -> features / game / services / core / config / shared ui`
2. `features -> game / services / core / config / shared ui`
3. `services -> core / config / external SDKs`
4. `game -> core`

Avoid:

- `game -> ui`
- `game -> services`
- `shared widgets -> feature services`
- `feature A -> feature B internals`

Feature-to-feature dependencies should go through:

- public feature entrypoints
- shared domain contracts
- shared services

## Import Strategy

Use feature entrypoint files as stable seams for app-level imports.

Examples:

- `lib/features/auth/auth_feature.dart`
- `lib/features/venue/venue_feature.dart`
- `lib/features/gameplay/gameplay_feature.dart`

Do not create giant wildcard barrel files that re-export half the repo. Entry points should be narrow and intentional.

## Migration Phases

### Phase 1

Foundation.

- extract `lib/app/*` from `main.dart`
- stabilize `lib/game/bot/*`
- add feature entrypoint files

### Phase 2

Move screen ownership into features.

- migrate `AuthScreen` under `features/auth`
- migrate `VenueScreen` and `SubKingdomScreen` under `features/venue`
- migrate `GameScreen` under `features/gameplay`

Keep old paths working temporarily through entrypoints if needed.

### Phase 3

Split orchestration from presentation.

- `game_screen.dart`: isolate state/controller/orchestration from widgets and static data
- `venue_screen.dart`: extract progress logic, navigation actions, and dialogs
- `slash_avatar.dart`: split painter/layout/assets/model concerns

### Phase 4

Service ownership cleanup.

- move feature-specific services under owning features
- keep only genuinely shared infra in `lib/services`
- define narrow interfaces where game or UI needs data

### Phase 5

Engine decomposition.

- separate engine state, hand flow, payout resolution, and bot policy internals
- keep `game` runtime deterministic and test-first

## Immediate Priority Files

These are the files that should be reduced first because they currently hold too many responsibilities:

- `lib/ui/screens/game_screen.dart`
- `lib/ui/screens/venue_screen.dart`
- `lib/ui/widgets/slash_avatar.dart`
- `lib/game/game_engine.dart`
- `lib/services/aura_points_service.dart`

## Success Criteria

The modularization is working when:

- `main.dart` becomes tiny
- app startup lives under `lib/app/`
- new code lands under a feature or domain module by default
- game logic remains testable without Flutter widgets
- large screen files stop being the only place where behavior can be changed
