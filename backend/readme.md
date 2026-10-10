# X Poker backend (`toak-backend`)

Express API for X Poker, the game from Ten of a Kind. Its Cloud Run service,
project, region and production URL are recorded in [`project.yaml`](../project.yaml);
that file is the only place they are defined.

## Local

```bash
npm install
cp .env.example .env
npm test
npm start
```

For local-only browser testing, `CORS_ORIGIN=*` is acceptable in `.env`.
Production must use an explicit comma-separated allowlist.

## Test

Unit tests:

```bash
npm --prefix backend test
npm --prefix backend audit --omit=dev --audit-level=high
```

Firestore emulator integration tests:

```bash
firebase emulators:exec \
  --project ten-of-a-kind-poker \
  --only firestore \
  "npm --prefix backend run test:emulator"
```

## Economy authority

Distributable builds are backend-authoritative. The release scripts set
`RELEASE_ECONOMY_MODE=backend` themselves and resolve `API_BASE_URL` with
`tools/backend_url.sh` (project.yaml, checked against Cloud Run); they fail
closed if either is wrong. Local wallets are only a debug/test facility.

Firestore rules deny client writes to authoritative wallet, career, receipt,
server-progress, and leaderboard data by default. A temporary admin-created
`runtime_config/economy_authority` document may enable validated legacy client
writes during a controlled migration, but it must be absent/false for release.

Gameplay outcomes use the repository's accepted
[`authenticated-client-outcome-claims-v1`](../docs/GAMEPLAY_TRUST_MODEL.md)
model. The backend is authoritative for catalog pricing, reservations,
settlement accounting, balances, and progression, while an authenticated
client reports the result of its local single-player match. Consequently AUP,
titles, and leaderboard positions are cosmetic entertainment state and must
never confer money, prizes, purchases, or external eligibility.

## Deploy

The backend is deployed separately from Firebase Hosting:

```bash
tools/deploy_backend.sh
```

Default Cloud Run target (read from `project.yaml`):

- project: `ten-of-a-kind-poker`
- service: `toak-backend`
- region: `asia-south1`
- production CORS: custom domains plus the Firebase Hosting web.app and
  firebaseapp.com origins

Override with environment variables:

```bash
PROJECT_ID=ten-of-a-kind-poker \
CLOUD_RUN_REGION=asia-south1 \
BACKEND_SERVICE_NAME=toak-backend \
CORS_ORIGIN=https://tenofakind.com,https://www.tenofakind.com \
tools/deploy_backend.sh
```

Build or deploy only after the backend health response reports the exact
generated catalog content hash, the production dependency audit passes, the
generated catalog is current, and Firestore emulator tests pass:

```bash
bash tools/deploy_web.sh             # web, served at tenofakind.com/web/
bash tools/build_public_release.sh   # Play Store bundle
```

## Live smoke

Health-only check:

```bash
API_BASE_URL="$(bash tools/backend_url.sh)" node tools/smoke_backend_live.mjs --health-only
```

Authenticated smoke with a Firebase ID token:

```bash
API_BASE_URL="$(bash tools/backend_url.sh)" \
FIREBASE_ID_TOKEN=... \
ALLOW_MUTATING_SMOKE=1 \
node tools/smoke_backend_live.mjs
```

Authenticated smoke with a Firebase test account:

```bash
API_BASE_URL="$(bash tools/backend_url.sh)" \
FIREBASE_TEST_EMAIL=... \
FIREBASE_TEST_PASSWORD=... \
ALLOW_MUTATING_SMOKE=1 \
node tools/smoke_backend_live.mjs
```

Without `ALLOW_MUTATING_SMOKE=1`, authenticated smoke is read-only. The
mutating path reserves and commits a catalog-backed free fort, finalizes a
first-place result, replays the same receipt to verify idempotency, and verifies
that the authoritative wallet contains the career clear.

## Code layout

```
src/index.js               app setup: /api prefix, CORS, rate limit, routes, shutdown
src/routes/                HTTP only: economy, leaderboard, auth, app-release
src/economy/constants.js   every number that sets the economy's rules
src/economy/catalog.js     forts and title matches: fees, table sizes, payouts
src/economy/progress.js    the wallet document and the arithmetic on it (pure)
src/economy/store.js       Firestore collections and the wallet transaction
src/economy/wallet.js      opening a wallet
src/economy/entries.js     paying for a table: reserve, commit, refund, recover
src/economy/events.js      results after a game
src/economy/rank.js        global rank
src/security/              Firebase auth and per-player rate limits
scripts/                   one-off data jobs, run by hand (never loaded by the server)
```

The server reads only `server_progress`. The pre-server collections
(`campaign_progress`, `aura_wallets`) are handled by
`scripts/migrate_legacy_wallets.js`, once, before deploying a server without
the old in-request migration.

## Economy endpoints

- `GET /v1/economy/wallet`
- `GET /v1/economy/rank`
- `POST /v1/economy/entries/reserve`
- `POST /v1/economy/entries/commit`
- `POST /v1/economy/entries/refund`
- `POST /v1/economy/entries/recover`
- `GET /v1/economy/entries/:attemptId`
- `POST /v1/economy/events` (`campaign_result` atomically settles every rank)
- `DELETE /v1/auth/account` with `{"confirmation":"DELETE"}` and a Firebase
  token authenticated within the last five minutes
