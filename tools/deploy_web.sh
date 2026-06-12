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

echo "==> Getting Flutter packages"
flutter pub get

echo "==> Building Flutter web (served under /web/)"
build_args=(web --release --base-href /web/)
if [[ -n "${API_BASE_URL:-}" ]]; then
  build_args+=(--dart-define="API_BASE_URL=$API_BASE_URL")
fi
flutter build "${build_args[@]}"

echo "==> Syncing build output to Firebase Hosting public dir"
rm -rf "$hosting_web_dir"
mkdir -p "$hosting_web_dir"
cp -R "$repo_root/build/web/"* "$hosting_web_dir/"

if [[ -f "$hosting_web_dir/assets/.env" ]]; then
  echo "ERROR: Refusing to deploy: $hosting_web_dir/assets/.env exists (never ship secrets in client builds)." >&2
  exit 1
fi

echo "==> Deploying to Firebase Hosting"
firebase deploy --only hosting
