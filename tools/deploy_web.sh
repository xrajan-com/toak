#!/usr/bin/env bash
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

api_base_url="${API_BASE_URL:-}"
app_build="$(bash "$repo_root/tools/app_build_number.sh")"

echo "==> Getting Flutter packages"
flutter pub get

echo "==> Running backend-authoritative release gates"
bash "$repo_root/tools/verify_release_prereqs.sh"

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

echo "==> Deploying verified Firestore rules and Firebase Hosting"
deploy_log="$(mktemp)"
if ! env -u DEBUG firebase deploy \
  --only firestore:rules,hosting \
  --non-interactive 2>&1 | tee "$deploy_log"; then
  if grep -q "Hosting storage quota" "$deploy_log"; then
    cat >&2 <<'EOF'

ERROR: Firebase Hosting storage quota is blocking this deploy.

The live channel should keep only a few releases. If quota still blocks deploys,
Firebase may still be deleting old release content in the background. Check:

  firebase hosting:channel:list --json -P ten-of-a-kind-poker

Expected: "retainedReleaseCount": 3 for the live channel.

If it is not 3, set it in Firebase Console:
Hosting & Serverless > Hosting > Release History > Release storage settings.
Keep 3 releases, save, then wait for old releases to be deleted.
EOF
  fi
  rm -f "$deploy_log"
  exit 1
fi
rm -f "$deploy_log"
