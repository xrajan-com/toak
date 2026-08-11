#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

cd "$repo_root"
ECONOMY_CATALOG_OUTPUT="$temp_dir/economy_catalog.json" \
ECONOMY_CATALOG_DART_OUTPUT="$temp_dir/economy_catalog_version.dart" \
  flutter test tools/export_economy_catalog.dart --reporter compact

if ! cmp -s \
  "$temp_dir/economy_catalog.json" \
  "$repo_root/backend/src/economy_catalog.json"; then
  echo "ERROR: backend economy catalog is stale. Regenerate it with:" >&2
  echo "  flutter test tools/export_economy_catalog.dart --reporter compact" >&2
  exit 1
fi

if ! cmp -s \
  "$temp_dir/economy_catalog_version.dart" \
  "$repo_root/lib/config/economy_catalog_version.dart"; then
  echo "ERROR: client economy catalog version is stale. Regenerate it with:" >&2
  echo "  flutter test tools/export_economy_catalog.dart --reporter compact" >&2
  exit 1
fi

node - <<'NODE'
const catalog = require('./backend/src/economy_catalog.json');
const { ECONOMY_CATALOG_VERSION } = require('./backend/src/economy_catalog');
if (catalog.schemaVersion !== 1 || catalog.eventCount !== 550) {
  throw new Error(
    `Expected economy catalog v1 with 550 events; got ` +
    `v${catalog.schemaVersion}:${catalog.eventCount}`,
  );
}
if (Object.keys(catalog.events || {}).length !== catalog.eventCount) {
  throw new Error('Economy catalog eventCount does not match its event map.');
}
console.log(`Economy catalog drift gate passed: ${ECONOMY_CATALOG_VERSION}`);
NODE
