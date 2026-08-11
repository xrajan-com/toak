#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_id="${PROJECT_ID:-${FIREBASE_PROJECT_ID:-ten-of-a-kind-poker}}"

java_major_for() {
  "$1/bin/java" -version 2>&1 |
    awk -F '"' '/version/ {
      split($2, parts, ".");
      if (parts[1] == "1") {
        print parts[2];
      } else {
        print parts[1];
      }
      exit;
    }'
}

use_java_21_or_newer() {
  local candidates=()
  if [[ -n "${JAVA_HOME:-}" ]]; then
    candidates+=("$JAVA_HOME")
  fi
  candidates+=(
    "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
    "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
    "/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
    "/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  )

  local candidate major
  for candidate in "${candidates[@]}"; do
    if [[ ! -x "$candidate/bin/java" ]]; then
      continue
    fi
    major="$(java_major_for "$candidate")"
    if [[ "$major" =~ ^[0-9]+$ && "$major" -ge 21 ]]; then
      export JAVA_HOME="$candidate"
      export PATH="$JAVA_HOME/bin:$PATH"
      return
    fi
  done

  echo "ERROR: Firestore emulator tests require Java 21 or newer." >&2
  echo "Install it with: brew install openjdk@21" >&2
  exit 1
}

cd "$repo_root"
use_java_21_or_newer
firebase emulators:exec \
  --project "$project_id" \
  --only firestore \
  "npm --prefix backend run test:emulator"
