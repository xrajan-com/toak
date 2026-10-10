#!/usr/bin/env bash
# Builds the web app and publishes tenofakind.com, including the /api route
# that carries the apps' and the website's backend calls to Cloud Run.
#
# Order, so a broken route never goes live:
#   1. release gates, with the live smoke against Cloud Run directly;
#   2. build the web app against https://tenofakind.com/api;
#   3. publish to a private preview channel and smoke the backend through
#      that channel's /api, which proves the Hosting route works;
#   4. publish live, then smoke https://tenofakind.com/api itself.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hosting_public_dir="$repo_root/hosting"
hosting_web_dir="$hosting_public_dir/web"

if [[ ! -d "$hosting_public_dir" ]]; then
  echo "ERROR: Expected hosting public dir at: $hosting_public_dir" >&2
  echo "       The tracked hosting/ directory is required for Firebase Hosting deploys." >&2
  exit 1
fi

cd "$repo_root"
# shellcheck source=tools/project_config.sh
source "$repo_root/tools/project_config.sh"
firebase_project="$(project_value firebase.project)"

# This script only ever ships production, so release mode is not optional and
# the backend URL comes from project.yaml (checked against Cloud Run).
export RELEASE_ECONOMY_MODE=backend
echo "==> Resolving the production backend URL"
api_base_url="$(bash "$repo_root/tools/backend_url.sh")"
direct_url="$(project_value backend.url)"
export API_BASE_URL="$api_base_url"
echo "    apps call:    $api_base_url"
echo "    Cloud Run at: $direct_url"
app_build="$(bash "$repo_root/tools/app_build_number.sh")"

smoke_args=()
if [[ -z "${FIREBASE_ID_TOKEN:-}" && \
      ( -z "${FIREBASE_TEST_EMAIL:-}" || \
        -z "${FIREBASE_TEST_PASSWORD:-}" ) ]]; then
  smoke_args+=(--ephemeral-user)
fi

echo "==> Getting Flutter packages"
flutter pub get

echo "==> Running backend-authoritative release gates"
SMOKE_API_BASE_URL="$direct_url" bash "$repo_root/tools/verify_release_prereqs.sh"

echo "==> Building Flutter web (served under /web/)"
build_args=(
  web
  --release
  --base-href /web/
  --no-wasm-dry-run
  --dart-define="API_BASE_URL=$api_base_url"
  --dart-define="ALLOW_LOCAL_ECONOMY_DEV=false"
  --dart-define="APP_BUILD=$app_build"
)
flutter build "${build_args[@]}"

echo "==> Syncing build output to Firebase Hosting public dir"
rm -rf "$hosting_web_dir"
mkdir -p "$hosting_web_dir"
cp -R "$repo_root/build/web/"* "$hosting_web_dir/"

if [[ -f "$hosting_web_dir/assets/.env" ]]; then
  echo "ERROR: Refusing to deploy: $hosting_web_dir/assets/.env exists (never ship secrets in client builds)." >&2
  exit 1
fi

echo "==> Publishing to a private preview channel"
preview_json="$(
  env -u DEBUG firebase hosting:channel:deploy release-check \
    --project "$firebase_project" \
    --expires 1h \
    --json \
    --non-interactive
)"
preview_url="$(
  node -e '
    const out = JSON.parse(process.argv[1]);
    const sites = Object.values(out.result || {});
    process.stdout.write((sites.find((site) => site?.url) || {}).url || "");
  ' "$preview_json"
)"
if [[ -z "$preview_url" ]]; then
  echo "ERROR: Firebase did not report a preview channel URL:" >&2
  echo "$preview_json" >&2
  exit 1
fi
echo "    $preview_url"

echo "==> Checking the backend through the preview channel's /api route"
if ! API_BASE_URL="$preview_url/api" \
  node "$repo_root/tools/smoke_backend_live.mjs" "${smoke_args[@]}"; then
  echo "ERROR: The /api route does not reach the backend on the preview channel." >&2
  echo "       Nothing went live. Check the /api/** rewrite in firebase.json." >&2
  exit 1
fi

echo "==> Deploying verified Firestore rules and Firebase Hosting"
deploy_log="$(mktemp)"
if ! env -u DEBUG firebase deploy \
  --project "$firebase_project" \
  --only firestore:rules,hosting \
  --non-interactive 2>&1 | tee "$deploy_log"; then
  if grep -q "Hosting storage quota" "$deploy_log"; then
    cat >&2 <<'QUOTA'

ERROR: Firebase Hosting storage quota is blocking this deploy.

The live channel should keep only a few releases. If quota still blocks deploys,
Firebase may still be deleting old release content in the background. Check:

  firebase hosting:channel:list --json -P ten-of-a-kind-poker

Expected: "retainedReleaseCount": 3 for the live channel.

If it is not 3, set it in Firebase Console:
Hosting & Serverless > Hosting > Release History > Release storage settings.
Keep 3 releases, save, then wait for old releases to be deleted.
QUOTA
  fi
  rm -f "$deploy_log"
  exit 1
fi
rm -f "$deploy_log"

echo "==> Checking the live backend route"
if ! API_BASE_URL="$api_base_url" \
  node "$repo_root/tools/smoke_backend_live.mjs" "${smoke_args[@]}"; then
  cat >&2 <<ROLLBACK

ERROR: $api_base_url is not answering after the deploy.
Roll back in Firebase Console: Hosting > Release history > the previous
release > Rollback. Builds before 1.2.11 are unaffected; they call Cloud Run
directly.
ROLLBACK
  exit 1
fi
echo "Live: https://$(project_value brand.domain)/web/ -> $api_base_url"
