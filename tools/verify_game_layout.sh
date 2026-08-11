#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Verifying canonical game layout across device sizes"
flutter test \
  test/game_viewport_test.dart \
  test/game_screen_visual_parity_test.dart \
  test/hero_card_spacing_test.dart \
  test/bot_card_layout_test.dart \
  test/seat_layout_test.dart \
  test/action_bar_height_stability_test.dart

echo "==> Re-running rendered parity checks in Chrome"
flutter test --platform chrome \
  test/game_viewport_test.dart \
  test/game_screen_visual_parity_test.dart
