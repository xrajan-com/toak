#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
release_mode="${RELEASE_ECONOMY_MODE:-}"
api_base_url="${API_BASE_URL:-}"

if [[ "$release_mode" != "backend" ]]; then
  echo "ERROR: Set RELEASE_ECONOMY_MODE=backend for any distributable build." >&2
  echo "Local/Spark economy builds are development-only and cannot be released." >&2
  exit 1
fi
if [[ ! "$api_base_url" =~ ^https://[^[:space:]]+$ ]]; then
  echo "ERROR: API_BASE_URL must be a non-empty HTTPS backend URL." >&2
  exit 1
fi

cd "$repo_root"
bash tools/verify_assets.sh
bash tools/verify_game_layout.sh
bash tools/verify_economy_catalog.sh
npm --prefix backend test
npm --prefix backend audit --omit=dev --audit-level=high

if [[ "${SKIP_RELEASE_RULES_GATE:-0}" == "1" ]]; then
  if [[ "${CI:-}" != "true" ]]; then
    echo "ERROR: SKIP_RELEASE_RULES_GATE is only accepted in CI jobs that ran it separately." >&2
    exit 1
  fi
else
  bash tools/verify_firestore_rules.sh
fi

if [[ "${SKIP_LIVE_BACKEND_HEALTH:-0}" == "1" ]]; then
  if [[ "${CI:-}" != "true" ]]; then
    echo "ERROR: SKIP_LIVE_BACKEND_HEALTH is only accepted for CI compile gates." >&2
    exit 1
  fi
else
  smoke_args=()
  if [[ -z "${FIREBASE_ID_TOKEN:-}" && \
        ( -z "${FIREBASE_TEST_EMAIL:-}" || \
          -z "${FIREBASE_TEST_PASSWORD:-}" ) ]]; then
    smoke_args+=(--ephemeral-user)
  fi
  API_BASE_URL="$api_base_url" \
    node tools/smoke_backend_live.mjs "${smoke_args[@]}"
fi

echo "Backend-authoritative release prerequisites passed."
