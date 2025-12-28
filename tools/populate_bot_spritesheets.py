#!/usr/bin/env python3
"""
populate_bot_spritesheets.py
────────────────────────────

Populates placeholder spritesheets for every bot defined in
`lib/ui/screens/game_screen.dart` by copying the existing `raj_malik`
spritesheets into each bot's asset folder.

Usage:
    python3 tools/populate_bot_spritesheets.py

This will overwrite existing folders under `assets/bots/<bot-key>/`.
"""

from __future__ import annotations

import re
import shutil
from pathlib import Path
from typing import List

SOURCE_FILE = Path("lib/ui/screens/game_screen.dart")
OUTPUT_ROOT = Path("assets/bots")
SOURCE_BOT = OUTPUT_ROOT / "raj_malik"


def slugify(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", name.lower())
    slug = slug.strip("_")
    return slug or "bot"


def discover_bot_names() -> List[str]:
    text = SOURCE_FILE.read_text(encoding="utf-8")
    matches = re.findall(r"_BotSpec\('([^']+)'", text)
    seen = set()
    ordered: List[str] = []
    for name in matches:
        if name not in seen:
            seen.add(name)
            ordered.append(name)
    return ordered


def main() -> None:
    if not SOURCE_BOT.exists():
        raise SystemExit("Source spritesheet folder assets/bots/raj_malik not found.")

    bot_names = discover_bot_names()
    if not bot_names:
        raise SystemExit("No bot names found in game_screen.dart.")

    for name in bot_names:
        slug = slugify(name)
        if slug == "raj_malik":
            continue
        dest = OUTPUT_ROOT / slug
        if dest.exists():
            shutil.rmtree(dest)
        shutil.copytree(SOURCE_BOT, dest)
        print(f"Copied spritesheets -> {dest}")

    print(f"Done. Spritesheets populated for {len(bot_names)} bots.")


if __name__ == "__main__":
    main()
