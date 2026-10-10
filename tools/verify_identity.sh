#!/usr/bin/env bash
# Fails if any shipped surface disagrees with project.yaml: the app name on
# Android, iOS and the web, the permanent store IDs, the backend URL compiled
# into release builds, the Firebase targets, and the Hosting route that
# carries tenofakind.com/api to Cloud Run. Also fails if a tracked file points
# at api.<domain>, which is not connected to anything: a release once went out
# against an address that did not exist.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
# shellcheck source=tools/project_config.sh
source "$root/tools/project_config.sh"

app_name="$(project_value app.name)"
android_id="$(project_value app.android_application_id)"
ios_id="$(project_value app.ios_bundle_id)"
dart_package="$(project_value app.dart_package)"
public_url="$(project_value backend.public_url)"
backend_service="$(project_value backend.service)"
backend_region="$(project_value backend.region)"
firebase_project="$(project_value firebase.project)"
hosting_site="$(project_value firebase.hosting_site)"
domain="$(project_value brand.domain)"

failures=0
check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "MISMATCH $label: expected '$expected', found '${actual:-<none>}'" >&2
    failures=$((failures + 1))
  fi
}
first_match() { sed -n "$1" "$2" | head -n 1; }

check "Android app_name" "$app_name" \
  "$(first_match 's/.*<string name="app_name">\(.*\)<\/string>.*/\1/p' android/app/src/main/res/values/strings.xml)"
check "iOS CFBundleDisplayName" "$app_name" \
  "$(sed -n '/<key>CFBundleDisplayName<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' ios/Runner/Info.plist | head -n 1)"
check "iOS CFBundleName" "$app_name" \
  "$(sed -n '/<key>CFBundleName<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' ios/Runner/Info.plist | head -n 1)"
check "web manifest name" "$app_name" \
  "$(first_match 's/.*"name":[[:space:]]*"\([^"]*\)".*/\1/p' web/manifest.json)"
check "web manifest short_name" "$app_name" \
  "$(first_match 's/.*"short_name":[[:space:]]*"\([^"]*\)".*/\1/p' web/manifest.json)"
if ! grep -q "<title>[^<]*${app_name}" web/index.html; then
  echo "MISMATCH web/index.html <title> does not contain '$app_name'" >&2
  failures=$((failures + 1))
fi
if ! grep -q "<title>[^<]*${app_name}" hosting/index.html; then
  echo "MISMATCH hosting/index.html <title> does not contain '$app_name'" >&2
  failures=$((failures + 1))
fi

check "Android applicationId" "$android_id" \
  "$(first_match 's/.*applicationId[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' android/app/build.gradle.kts)"
check "Android namespace" "$android_id" \
  "$(first_match 's/.*namespace[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' android/app/build.gradle.kts)"
while IFS= read -r ios_bundle; do
  check "iOS bundle id" "$ios_id" "$ios_bundle"
done < <(sed -n 's/.*PRODUCT_BUNDLE_IDENTIFIER = \([^;]*\);.*/\1/p' ios/Runner.xcodeproj/project.pbxproj |
  grep -v 'Tests$' | sort -u)
check "pubspec name" "$dart_package" \
  "$(first_match 's/^name:[[:space:]]*\([^[:space:]]*\).*/\1/p' pubspec.yaml)"

check "release backend URL (lib/services/api_client.dart)" "$public_url" \
  "$(sed -n '/_productionBaseUrl =/,/;/p' lib/services/api_client.dart | grep -o "https://[^']*" | head -n 1)"
check "Firebase default project (.firebaserc)" "$firebase_project" \
  "$(first_match 's/.*"default":[[:space:]]*"\([^"]*\)".*/\1/p' .firebaserc)"
check "Firebase hosting site (firebase.json)" "$hosting_site" \
  "$(first_match 's/.*"site":[[:space:]]*"\([^"]*\)".*/\1/p' firebase.json)"

case "$public_url" in
  "https://$domain/"*) ;;
  *)
    echo "MISMATCH backend.public_url: expected an address on https://$domain/, found '$public_url'" >&2
    failures=$((failures + 1))
    ;;
esac
public_path="/${public_url#https://$domain/}"
hosting_route="$(node -e '
  const [path, service, region] = process.argv.slice(1);
  const hosting = require("./firebase.json").hosting;
  const rules = hosting.rewrites || [];
  const first = rules.find((rule) => rule.source === `${path}/**`);
  const ok = first?.run?.serviceId === service && first?.run?.region === region &&
    rules.indexOf(first) === 0;
  process.stdout.write(ok ? "ok" : JSON.stringify(first || null));
' "$public_path" "$backend_service" "$backend_region")"
if [[ "$hosting_route" != "ok" ]]; then
  echo "MISMATCH firebase.json: the first rewrite must send $public_path/** to Cloud Run service '$backend_service' in '$backend_region'; found $hosting_route" >&2
  failures=$((failures + 1))
fi

if stray="$(git grep -n -F "api.$domain" -- . ':!project.yaml' ':!tools/verify_identity.sh')"; then
  echo "UNMAPPED DOMAIN: api.$domain is not connected to anything; the backend is at $public_url. These files point at it:" >&2
  echo "$stray" >&2
  failures=$((failures + 1))
fi

if [[ "$failures" -ne 0 ]]; then
  echo "Identity check failed: $failures mismatch(es) with project.yaml." >&2
  exit 1
fi
echo "Identity matches project.yaml: $app_name ($android_id) -> $public_url"
