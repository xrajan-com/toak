#!/usr/bin/env bash
# Preview the EXACT bundle tools/deploy_web.sh would ship, served locally.
#
# 'flutter run -d chrome' is a debug build at the root path with none of the
# release --dart-defines. This builds the real thing: --release, /web/ base
# href, same defines, then serves it at the same /web/ path production uses.
# What you see here is what goes live.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

port="${PORT:-8080}"
api_base_url="${API_BASE_URL:-}"

if [[ -z "$api_base_url" ]]; then
  echo "==> Resolving the live backend URL (pass API_BASE_URL=... to override)"
  api_base_url="$(gcloud run services describe toak-backend \
    --project ten-of-a-kind-poker --region asia-south1 \
    --format='value(status.url)' 2>/dev/null || true)"
  if [[ -z "$api_base_url" ]]; then
    echo "ERROR: Could not resolve the backend URL. Pass it explicitly:" >&2
    echo "       API_BASE_URL=https://... bash tools/preview_web_release.sh" >&2
    exit 1
  fi
  echo "    $api_base_url"
fi

app_build="$(bash "$repo_root/tools/app_build_number.sh")"

echo "==> flutter pub get"
flutter pub get

echo "==> Building release web bundle (build $app_build)"
flutter build web \
  --release \
  --base-href /web/ \
  --no-wasm-dry-run \
  --dart-define="API_BASE_URL=$api_base_url" \
  --dart-define="ALLOW_LOCAL_ECONOMY_DEV=false" \
  --dart-define="APP_BUILD=$app_build"

preview_root="$(mktemp -d)"
ln -s "$repo_root/build/web" "$preview_root/web"
url="http://localhost:$port/web/"

cat <<BANNER

==> Serving the release build at: $url

    This is what deploy_web.sh uploads - same flags, same base href.
    Resize the window from tiny to full screen: the layout should now
    scale as one piece instead of stranding a small card in a void.

    Ctrl+C to stop.

BANNER

if command -v open >/dev/null 2>&1; then
  ( sleep 1; open "$url" ) &
fi

cd "$preview_root"
exec python3 -m http.server "$port"
