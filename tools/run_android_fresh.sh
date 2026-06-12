#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_ID="com.tenofakind.poker"
MODE="debug"
DEVICE_ID=""
ADB_BIN=""
TARGET_FILE="lib/main_testing.dart"
BUILD_VARIANT="testing"

usage() {
  cat <<'EOF'
Usage: tools/run_android_fresh.sh [--release] [--testing|--public] [device_id]

Defaults:
  mode: debug
  build_variant: testing
  device_id: first connected/booted adb device

Examples:
  tools/run_android_fresh.sh
  tools/run_android_fresh.sh emulator-5554
  tools/run_android_fresh.sh --release emulator-5554
  tools/run_android_fresh.sh --public emulator-5554
EOF
}

for arg in "$@"; do
  case "$arg" in
    --release)
      MODE="release"
      ;;
    --debug)
      MODE="debug"
      ;;
    --testing)
      BUILD_VARIANT="testing"
      TARGET_FILE="lib/main_testing.dart"
      ;;
    --public)
      BUILD_VARIANT="public"
      TARGET_FILE="lib/main_public.dart"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$DEVICE_ID" ]]; then
        echo "Only one device_id can be provided." >&2
        usage
        exit 1
      fi
      DEVICE_ID="$arg"
      ;;
  esac
done

if command -v adb >/dev/null 2>&1; then
  ADB_BIN="$(command -v adb)"
elif [[ -x "${ANDROID_HOME:-}/platform-tools/adb" ]]; then
  ADB_BIN="${ANDROID_HOME}/platform-tools/adb"
elif [[ -x "${ANDROID_SDK_ROOT:-}/platform-tools/adb" ]]; then
  ADB_BIN="${ANDROID_SDK_ROOT}/platform-tools/adb"
elif [[ -x "$HOME/Library/Android/sdk/platform-tools/adb" ]]; then
  ADB_BIN="$HOME/Library/Android/sdk/platform-tools/adb"
else
  echo "adb not found. Install Android platform-tools or set ANDROID_HOME/ANDROID_SDK_ROOT." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not available in PATH." >&2
  exit 1
fi

if [[ -z "$DEVICE_ID" ]]; then
  DEVICES=()
  while IFS= read -r device; do
    [[ -n "$device" ]] && DEVICES+=("$device")
  done < <("$ADB_BIN" devices | awk 'NR>1 && $2=="device" {print $1}')
  if [[ ${#DEVICES[@]} -eq 0 ]]; then
    echo "No Android devices/emulators are connected. Start an emulator first." >&2
    exit 1
  fi
  DEVICE_ID="${DEVICES[0]}"
fi

cd "$ROOT_DIR"

echo "Using device: $DEVICE_ID"
echo "Mode: $MODE"
echo "Variant: $BUILD_VARIANT"
echo "Project: $ROOT_DIR"
echo "adb: $ADB_BIN"

echo "==> flutter clean"
flutter clean

echo "==> flutter pub get"
flutter pub get

echo "==> uninstall old app (if present)"
"$ADB_BIN" -s "$DEVICE_ID" uninstall "$PACKAGE_ID" >/dev/null 2>&1 || true

if [[ "$MODE" == "release" ]]; then
  echo "==> flutter build apk --release"
  flutter build apk --release -t "$TARGET_FILE"
  echo "==> adb install release apk"
  "$ADB_BIN" -s "$DEVICE_ID" install -r build/app/outputs/flutter-apk/app-release.apk
  echo "==> launch app"
  "$ADB_BIN" -s "$DEVICE_ID" shell monkey -p "$PACKAGE_ID" -c android.intent.category.LAUNCHER 1 >/dev/null
  echo "Done."
else
  echo "==> flutter run"
  flutter run -d "$DEVICE_ID" -t "$TARGET_FILE"
fi
