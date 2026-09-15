#!/usr/bin/env bash
# Prints the build number from pubspec.yaml — the digits after '+' in
# `version: 1.2.8+83`.
#
# The client compares this against runtime_config/app_release.latestBuild to
# decide whether to show the update notice, so it is derived rather than
# hand-maintained: Env.appVersion sat at '1.0.0' for eighty-three builds, which
# is what happens to a version constant somebody has to remember to bump.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build="$(
  sed -n 's/^version:[[:space:]]*[0-9][0-9.]*+\([0-9][0-9]*\)[[:space:]]*$/\1/p' \
    "$root/pubspec.yaml" | head -n 1
)"

if [[ -z "$build" ]]; then
  echo "ERROR: no build number in the pubspec.yaml 'version:' line." >&2
  echo "       Expected the form: version: 1.2.8+83" >&2
  exit 1
fi

printf '%s\n' "$build"
