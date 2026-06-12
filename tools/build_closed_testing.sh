#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_AAB="$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"
OUTPUT_DIR="$ROOT_DIR/build/releases"
OUTPUT_AAB="$OUTPUT_DIR/toak-closed-testing.aab"

cd "$ROOT_DIR"

flutter build appbundle --release -t lib/main_testing.dart "$@"
mkdir -p "$OUTPUT_DIR"
cp "$SOURCE_AAB" "$OUTPUT_AAB"

echo "Built closed testing bundle:"
echo "  $OUTPUT_AAB"
