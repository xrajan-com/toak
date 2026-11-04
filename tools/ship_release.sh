#!/usr/bin/env bash
# One command from the working tree to a Play-ready bundle, stopping at the
# first failure:
#   1. Flutter packages, the analyzer (errors fail it) and the whole test
#      suite;
#   2. the backend: deploy_backend.sh runs its tests, deploys Cloud Run and
#      smokes the live service. It goes first because the app relies on it
#      (build 93: the daily tribute route);
#   3. the signed Android bundle for Play (build_public_release.sh);
#   4. the website, unless SKIP_WEB=1 (deploy_web.sh).
# SKIP_FLUTTER_CHECKS=1 skips step 1's analyzer and tests on a rerun.
#
# Afterwards: upload build/releases/toak-public-release.aab in Play Console
# (Production, or the track you use) with the changelog in
# fastlane/metadata/android/en-US/changelogs/<build>.txt.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
build="$(bash tools/app_build_number.sh)"
changelog="fastlane/metadata/android/en-US/changelogs/$build.txt"
if [[ ! -s "$changelog" ]]; then
  echo "ERROR: no changelog for build $build ($changelog)." >&2
  exit 1
fi

echo "==> Build $build"
echo "==> Flutter packages"
flutter pub get

# SKIP_FLUTTER_CHECKS=1 skips the analyzer and tests on a rerun after they
# already passed on this tree.
if [[ "${SKIP_FLUTTER_CHECKS:-0}" != "1" ]]; then
  echo "==> Analyzer"
  flutter analyze --no-fatal-infos --no-fatal-warnings

  echo "==> Flutter tests"
  flutter test
fi

echo "==> Backend (tests, deploy, live smoke)"
bash tools/deploy_backend.sh

echo "==> Android bundle"
bash tools/build_public_release.sh

if [[ "${SKIP_WEB:-0}" != "1" ]]; then
  echo "==> Website"
  bash tools/deploy_web.sh
fi

echo
echo "Build $build is ready:"
echo "  build/releases/toak-public-release.aab"
echo "Release notes:"
sed 's/^/  /' "$changelog"
