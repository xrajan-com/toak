#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_AAB="$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"
OUTPUT_DIR="$ROOT_DIR/build/releases"
OUTPUT_AAB="$OUTPUT_DIR/toak-public-release.aab"

cd "$ROOT_DIR"

API_BASE_URL="${API_BASE_URL:-}"
bash "$ROOT_DIR/tools/verify_android_signing.sh"
bash "$ROOT_DIR/tools/verify_release_prereqs.sh"
echo "Building backend-authoritative public bundle."
flutter build appbundle \
  --release \
  -t lib/main_public.dart \
  --dart-define="API_BASE_URL=$API_BASE_URL" \
  --dart-define="ALLOW_LOCAL_ECONOMY_DEV=false" \
  "$@"
mkdir -p "$OUTPUT_DIR"
cp "$SOURCE_AAB" "$OUTPUT_AAB"

echo "Built public release bundle:"
echo "  $OUTPUT_AAB"
