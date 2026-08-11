# T-O-A-K Backend

Express API for Ten Of A Kind.

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

Distributable builds are backend-authoritative. They require
`RELEASE_ECONOMY_MODE=backend` and a non-empty HTTPS `API_BASE_URL`; release
scripts fail closed otherwise. Local wallets are only a debug/test facility.

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

Default Cloud Run target:

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
RELEASE_ECONOMY_MODE=backend \
API_BASE_URL=https://api.tenofakind.com \
tools/build_public_release.sh
```

## Live smoke

Health-only check:

```bash
API_BASE_URL=https://api.tenofakind.com tools/smoke_backend_live.mjs --health-only
```

Authenticated smoke with a Firebase ID token:

```bash
API_BASE_URL=https://api.tenofakind.com \
FIREBASE_ID_TOKEN=... \
ALLOW_MUTATING_SMOKE=1 \
tools/smoke_backend_live.mjs
```

Authenticated smoke with a Firebase test account:

```bash
API_BASE_URL=https://api.tenofakind.com \
FIREBASE_TEST_EMAIL=... \
FIREBASE_TEST_PASSWORD=... \
ALLOW_MUTATING_SMOKE=1 \
tools/smoke_backend_live.mjs
```

Without `ALLOW_MUTATING_SMOKE=1`, authenticated smoke is read-only. The
mutating path reserves and commits a catalog-backed free fort, finalizes a
first-place result, replays the same receipt to verify idempotency, and verifies
that the authoritative wallet contains the career clear.

## Economy endpoints

- `GET /v1/economy/wallet`
- `POST /v1/economy/entries/reserve`
- `POST /v1/economy/entries/commit`
- `POST /v1/economy/entries/refund`
- `POST /v1/economy/entries/recover`
- `GET /v1/economy/entries/:attemptId`
- `POST /v1/economy/events` (`campaign_result` atomically settles every rank)
- `DELETE /v1/auth/account` with `{"confirmation":"DELETE"}` and a Firebase
  token authenticated within the last five minutes
