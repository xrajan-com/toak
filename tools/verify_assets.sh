#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

missing=0
while IFS= read -r asset_path; do
  if [[ ! -e "$asset_path" ]]; then
    echo "Missing referenced asset: $asset_path" >&2
    missing=1
  fi
done < <(
  rg -o --no-filename \
    "assets/[A-Za-z0-9_ .&()'/-]+\\.(png|jpg|jpeg|webp|svg|wav|mp3|ttf|json)" \
    lib test pubspec.yaml |
    sort -u
)

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

if rg -q '^[[:space:]]*-[[:space:]]+assets/images/[[:space:]]*$' pubspec.yaml; then
  echo "Do not bundle the entire root assets/images directory; list used root files explicitly." >&2
  exit 1
fi

echo "Asset references and bundle declarations are valid."
