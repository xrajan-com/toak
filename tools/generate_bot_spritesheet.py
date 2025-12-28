#!/usr/bin/env python3
"""
generate_bot_spritesheet.py
───────────────────────────

Generates lightweight spritesheet animations for poker bot avatars using only
the Python standard library. Each bot gets a manifest plus one PNG per mood
(`idle.png`, `raise.png`, etc.) containing all frames laid out horizontally.

Usage example:
    python tools/generate_bot_spritesheet.py \
        --bot raj_malik \
        --skin 219,170,118 \
        --clothes 32,58,96 \
        --accent 255,179,71

Run the script repeatedly with different parameters to populate additional bots.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import struct
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

# Output resolution for each frame (square to match seat tiles).
FRAME_WIDTH = 320
FRAME_HEIGHT = 320

# Animation settings per bot mood/state.
STATE_FRAME_COUNTS: Dict[str, int] = {
    "idle": 3,
    "focused": 3,
    "raise": 3,
    "win": 3,
    "lose": 3,
    "folded": 2,
    "busted": 2,
}

STATE_ACCENTS: Dict[str, Tuple[int, int, int]] = {
    "idle": (60, 120, 255),
    "focused": (90, 200, 255),
    "raise": (255, 120, 60),
    "win": (60, 220, 130),
    "lose": (255, 80, 90),
    "folded": (160, 160, 160),
    "busted": (90, 90, 90),
}

STATE_BRIGHTNESS: Dict[str, float] = {
    "idle": 0.0,
    "focused": 0.08,
    "raise": 0.12,
    "win": 0.18,
    "lose": -0.10,
    "folded": -0.15,
    "busted": -0.25,
}

STATE_MOTION: Dict[str, float] = {
    "idle": 0.02,
    "focused": 0.03,
    "raise": 0.05,
    "win": 0.04,
    "lose": 0.04,
    "folded": 0.0,
    "busted": 0.0,
}

# Background gradient (top → bottom).
BG_TOP = (22, 29, 36)
BG_BOTTOM = (40, 48, 58)


def parse_rgb(value: str) -> Tuple[int, int, int]:
    parts = [int(p.strip()) for p in value.split(",")]
    if len(parts) != 3:
        raise argparse.ArgumentTypeError("RGB triplets must have 3 comma-separated numbers.")
    if not all(0 <= channel <= 255 for channel in parts):
        raise argparse.ArgumentTypeError("RGB values must be in the range [0, 255].")
    return tuple(parts)  # type: ignore[return-value]


def chunk(chunk_type: bytes, data: bytes) -> bytes:
    chunk_len = struct.pack(">I", len(data))
    crc = struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
    return chunk_len + chunk_type + data + crc


def write_png(path: Path, rows: Iterable[bytes], width: int, height: int) -> None:
    signature = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    ihdr_chunk = chunk(b"IHDR", ihdr)

    raw_bytes = bytearray()
    for row in rows:
        raw_bytes.append(0)  # filter type 0 (None)
        raw_bytes.extend(row)

    idat_chunk = chunk(b"IDAT", zlib.compress(bytes(raw_bytes), 9))
    iend_chunk = chunk(b"IEND", b"")

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as fh:
        fh.write(signature + ihdr_chunk + idat_chunk + iend_chunk)


def lerp(rgb_a: Tuple[int, int, int], rgb_b: Tuple[int, int, int], t: float) -> Tuple[int, int, int]:
    return tuple(int(rgb_a[i] + (rgb_b[i] - rgb_a[i]) * t) for i in range(3))


def clamp_unit(value: float) -> float:
    return max(0.0, min(1.0, value))


@dataclass
class BotPalette:
    key: str
    skin: Tuple[int, int, int]
    clothes: Tuple[int, int, int]
    accent: Tuple[int, int, int]


def generate_frame_pixels(
    bot: BotPalette, state: str, frame_idx: int, total_frames: int
) -> List[bytes]:
    accent = STATE_ACCENTS[state]
    brightness = STATE_BRIGHTNESS[state]
    motion = STATE_MOTION[state]

    pulse = math.sin((frame_idx / max(1, total_frames)) * math.pi)
    pulse_scale = 1.0 + (0.045 + motion) * pulse

    head_center_y = FRAME_HEIGHT * 0.30
    head_radius = FRAME_WIDTH * 0.18 * pulse_scale
    body_top = FRAME_HEIGHT * 0.36
    body_bottom = FRAME_HEIGHT * 0.78
    body_width = FRAME_WIDTH * 0.42 * pulse_scale
    center_x = FRAME_WIDTH / 2

    frame_rows: List[bytes] = []
    for y in range(FRAME_HEIGHT):
        row = bytearray()
        bg = lerp(BG_TOP, BG_BOTTOM, y / (FRAME_HEIGHT - 1))

        for x in range(FRAME_WIDTH):
            color = list(bg)
            dx = x - center_x
            dy = y - head_center_y
            head_dist = math.hypot(dx, dy)
            in_head = head_dist <= head_radius

            body_fraction = (
                (y - body_top) / (body_bottom - body_top) if body_bottom != body_top else 0
            )
            in_body = False
            if 0 <= body_fraction <= 1:
                body_half_width = (1 - (body_fraction ** 1.6)) * body_width
                in_body = abs(dx) <= body_half_width

            if in_head:
                shimmer = 0.9 + 0.1 * math.cos((x + y) * 0.02)
                color = [int(bot.skin[i] * shimmer) for i in range(3)]
            elif in_body:
                fold = math.cos((y - body_top) * 0.04)
                tint = 0.75 + 0.25 * fold
                base = [int(bot.clothes[i] * tint) for i in range(3)]
                blend = 0.25 + 0.75 * (1 - abs(dx) / max(1, body_width))
                color = [int(base[i] * (1 - blend) + accent[i] * blend * 0.6) for i in range(3)]
            else:
                aura = math.exp(-((dx ** 2) + (dy ** 2)) / (2 * (FRAME_WIDTH * 0.45) ** 2))
                aura_strength = 0.1 + 0.25 * aura
                color = [int(color[i] + (accent[i] - color[i]) * aura_strength) for i in range(3)]

            if brightness:
                factor = clamp_unit((color[0] + color[1] + color[2]) / (3 * 255) + brightness)
                color = [int(clamp_unit(channel / 255 * (0.85 + factor)) * 255) for channel in color]

            row.extend(color)

        frame_rows.append(bytes(row))

    return frame_rows


def compile_spritesheet(frames: List[List[bytes]]) -> List[bytes]:
    """Concatenate frames horizontally into a single spritesheet."""
    sheet_rows: List[bytes] = []
    for y in range(FRAME_HEIGHT):
        row = bytearray()
        for frame in frames:
            row.extend(frame[y])
        sheet_rows.append(bytes(row))
    return sheet_rows


def write_manifest(bot: BotPalette, output_dir: Path) -> None:
    manifest_path = output_dir / bot.key / "manifest.json"
    states = {
        state: {
            "sheet": f"{state}.png",
            "frame_count": STATE_FRAME_COUNTS[state],
        }
        for state in STATE_FRAME_COUNTS
    }
    manifest = {
        "frame_width": FRAME_WIDTH,
        "frame_height": FRAME_HEIGHT,
        "states": states,
    }

    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")


def clean_previous(bot_dir: Path) -> None:
    if bot_dir.exists():
        shutil.rmtree(bot_dir)


def generate_bot(bot: BotPalette, output_root: Path) -> None:
    bot_dir = output_root / bot.key
    clean_previous(bot_dir)

    for state, frame_count in STATE_FRAME_COUNTS.items():
        frames: List[List[bytes]] = []
        for frame_idx in range(frame_count):
            frames.append(generate_frame_pixels(bot, state, frame_idx, max(1, frame_count - 1)))
        sheet_rows = compile_spritesheet(frames)
        sheet_width = FRAME_WIDTH * frame_count
        sheet_height = FRAME_HEIGHT
        sheet_path = bot_dir / f"{state}.png"
        write_png(sheet_path, sheet_rows, sheet_width, sheet_height)

    write_manifest(bot, output_root)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate spritesheet assets for a bot avatar.")
    parser.add_argument("--bot", required=True, help="Bot key (matches seat.avatarKey).")
    parser.add_argument("--skin", type=parse_rgb, required=True, help="Skin tone RGB, e.g. 219,170,118.")
    parser.add_argument("--clothes", type=parse_rgb, required=True, help="Clothing RGB, e.g. 32,58,96.")
    parser.add_argument("--accent", type=parse_rgb, required=True, help="Accent RGB, e.g. 255,179,71.")
    parser.add_argument("--output-root", default="assets/bots", help="Directory to place generated sprites.")
    args = parser.parse_args()

    bot = BotPalette(
        key=args.bot,
        skin=args.skin,
        clothes=args.clothes,
        accent=args.accent,
    )

    output_root = Path(args.output_root)
    generate_bot(bot, output_root)
    print(f"Generated spritesheets for '{bot.key}' in {output_root / bot.key}")


if __name__ == "__main__":
    main()
