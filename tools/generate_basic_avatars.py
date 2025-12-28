#!/usr/bin/env python3
"""
generate_basic_avatars.py
─────────────────────────

Creates two simple spritesheet-based avatars (male & female) with five distinct
frames illustrating idle breathing plus nervous/angry/happy expressions. The
output structure matches the manifest expected by `BotAvatar`.

Usage:
    python3 tools/generate_basic_avatars.py
"""

from __future__ import annotations

import math
import struct
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Tuple

FRAME_W = 320
FRAME_H = 320

OUTPUT_ROOT = Path("assets/bots")


@dataclass
class AvatarStyle:
  key: str
  skin: Tuple[int, int, int]
  hair: Tuple[int, int, int]
  shirt: Tuple[int, int, int]
  accent: Tuple[int, int, int]
  background: Tuple[int, int, int]


def lerp_color(a: Tuple[int, int, int], b: Tuple[int, int, int], t: float) -> Tuple[int, int, int]:
  return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def lighten(color: Tuple[int, int, int], amount: float) -> Tuple[int, int, int]:
  return tuple(min(255, int(c + (255 - c) * amount)) for c in color)


def darken(color: Tuple[int, int, int], amount: float) -> Tuple[int, int, int]:
  return tuple(max(0, int(c * (1.0 - amount))) for c in color)


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
    raw_bytes.append(0)  # filter type 0 (none)
    raw_bytes.extend(row)

  idat_chunk = chunk(b"IDAT", zlib.compress(bytes(raw_bytes), 9))
  iend_chunk = chunk(b"IEND", b"")

  path.parent.mkdir(parents=True, exist_ok=True)
  with path.open("wb") as fh:
    fh.write(signature + ihdr_chunk + idat_chunk + iend_chunk)


def compose_sheet(frames: List[List[bytes]]) -> List[bytes]:
  sheet_rows: List[bytes] = []
  for y in range(FRAME_H):
    row = bytearray()
    for frame in frames:
      row.extend(frame[y])
    sheet_rows.append(bytes(row))
  return sheet_rows


def draw_avatar(style: AvatarStyle, expression: str, breath_phase: float = 0.0) -> List[bytes]:
  """Render a single frame."""
  rows: List[bytes] = []

  head_cx = FRAME_W * 0.5
  head_cy = FRAME_H * 0.33
  head_r = FRAME_W * 0.18 * (1 + 0.02 * math.sin(breath_phase))

  body_top = head_cy + head_r * 0.4
  shoulders_y = head_cy + head_r * 0.1
  body_width = FRAME_W * 0.42

  bg_top = style.background
  bg_bottom = darken(style.background, 0.25)

  # expression cues
  mouth_curve = 0.0
  mouth_thickness = 6
  mouth_color = (40, 40, 40)
  eye_height = head_cy - head_r * 0.2
  pupil_color = (12, 12, 12)
  brow_offset = 0.0
  blush_strength = 0.0

  if expression == "idle":
    mouth_curve = 0.0
  elif expression == "nervous":
    mouth_curve = -0.4
    mouth_color = (80, 80, 80)
    brow_offset = 0.06
    blush_strength = 0.12
  elif expression == "angry":
    mouth_curve = -0.8
    mouth_color = (170, 40, 40)
    brow_offset = 0.12
    pupil_color = (20, 5, 5)
  elif expression == "happy":
    mouth_curve = 0.9
    mouth_color = (40, 120, 60)
    eye_height -= head_r * 0.02
  else:
    mouth_curve = 0.0

  for y in range(FRAME_H):
    row = bytearray()
    v = y / (FRAME_H - 1)
    bg = lerp_color(bg_top, bg_bottom, v)

    for x in range(FRAME_W):
      color = list(bg)
      dx = x - head_cx
      dy = y - head_cy
      dist = math.hypot(dx, dy)
      in_head = dist <= head_r

      in_hair = in_head and (dy < -head_r * 0.2)
      if in_head:
        shade = 1.0
        if expression == "idle":
          shade += 0.04 * math.sin(breath_phase) - 0.02
        elif expression == "nervous":
          shade -= 0.05
        elif expression == "angry":
          shade -= 0.08
        elif expression == "happy":
          shade += 0.06
        skin_color = tuple(
            max(0, min(255, int(channel * shade))) for channel in style.skin
        )
        color = list(skin_color)

        if in_hair:
          color = list(style.hair)

        # cheeks blush
        if blush_strength > 0 and dy > -head_r * 0.1:
          cheek_radius = head_r * 0.35
          if abs(dx) < cheek_radius and dy > 0:
            t = (abs(dx) / cheek_radius)
            blush = (255, 120, 140)
            mix = blush_strength * (1 - t) * math.exp(-(dy / head_r) ** 2)
            color = [
                int(color[i] * (1 - mix) + blush[i] * mix)
                for i in range(3)
            ]

      # shoulders / torso
      if y >= shoulders_y:
        body_factor = max(0.0, 1 - abs(dx) / (body_width))
        if body_factor > 0:
          blend = 0.4 + 0.6 * body_factor
          shirt_color = [
              int(style.shirt[i] * blend + style.accent[i] * (1 - blend) * 0.5)
              for i in range(3)
          ]
          color = shirt_color

      # eyes
      eye_r = head_r * 0.11
      left_eye_cx = head_cx - head_r * 0.55
      right_eye_cx = head_cx + head_r * 0.55
      eye_cy = eye_height

      def in_eye(ex, px, py) -> bool:
        return ((px - ex) ** 2) / (eye_r ** 2) + ((py - eye_cy) ** 2) / (eye_r * 0.8) ** 2 <= 1

      if in_eye(left_eye_cx, x, y) or in_eye(right_eye_cx, x, y):
        color = list(pupil_color)

      # eyebrows (simple rectangles)
      brow_width = head_r * 0.6
      brow_thickness = head_r * 0.12
      brow_y = eye_cy - head_r * (0.25 + brow_offset)
      if abs(dx + brow_width * 0.5) < brow_width and abs(y - brow_y) < brow_thickness:
        color = [30, 30, 30]
      if abs(dx - brow_width * 0.5) < brow_width and abs(y - brow_y) < brow_thickness:
        color = [30, 30, 30]

      # mouth (simple quadratic curve)
      mouth_width = head_r * 1.1
      mouth_cy = head_cy + head_r * 0.45
      if abs(dx) <= mouth_width and abs(y - mouth_cy) <= mouth_thickness:
        t = (dx / mouth_width)
        curve = mouth_curve * (1 - t * t)
        mid = mouth_cy + curve * head_r * 0.3
        if abs(y - mid) <= mouth_thickness:
          color = list(mouth_color)

      row.extend(int(c) for c in color)
    rows.append(bytes(row))

  return rows


def save_avatar(style: AvatarStyle) -> None:
  bot_dir = OUTPUT_ROOT / style.key
  if bot_dir.exists():
    for item in bot_dir.iterdir():
      if item.is_file():
        item.unlink()
  bot_dir.mkdir(parents=True, exist_ok=True)

  # Prepare frames
  idle_frames = [
      draw_avatar(style, "idle", breath_phase=0.0),
      draw_avatar(style, "idle", breath_phase=math.pi),
  ]
  nervous_frame = draw_avatar(style, "nervous")
  angry_frame = draw_avatar(style, "angry")
  happy_frame = draw_avatar(style, "happy")

  def write_sheet(filename: str, frames: List[List[bytes]]) -> None:
    sheet_rows = compose_sheet(frames)
    width = FRAME_W * len(frames)
    write_png(bot_dir / filename, sheet_rows, width, FRAME_H)

  write_sheet("idle.png", idle_frames)
  write_sheet("focused.png", [nervous_frame])
  write_sheet("raise.png", [angry_frame])
  write_sheet("win.png", [happy_frame])
  write_sheet("lose.png", [nervous_frame])
  write_sheet("folded.png", [idle_frames[0]])
  write_sheet("busted.png", [angry_frame])

  manifest = {
      "frame_width": FRAME_W,
      "frame_height": FRAME_H,
      "states": {
          "idle": {"sheet": "idle.png", "frame_count": len(idle_frames)},
          "focused": {"sheet": "focused.png", "frame_count": 1},
          "raise": {"sheet": "raise.png", "frame_count": 1},
          "win": {"sheet": "win.png", "frame_count": 1},
          "lose": {"sheet": "lose.png", "frame_count": 1},
          "folded": {"sheet": "folded.png", "frame_count": 1},
          "busted": {"sheet": "busted.png", "frame_count": 1},
      },
  }
  (bot_dir / "manifest.json").write_text(
      f"{manifest}".replace("'", '"'), encoding="utf-8"
  )


def main() -> None:
  male = AvatarStyle(
      key="avatar_male",
      skin=(220, 184, 152),
      hair=(45, 34, 25),
      shirt=(35, 62, 110),
      accent=(210, 180, 120),
      background=(30, 38, 50),
  )
  female = AvatarStyle(
      key="avatar_female",
      skin=(235, 198, 162),
      hair=(90, 46, 20),
      shirt=(120, 58, 110),
      accent=(255, 182, 193),
      background=(34, 30, 44),
  )

  save_avatar(male)
  save_avatar(female)
  print("Generated avatar_male and avatar_female spritesheets.")


if __name__ == "__main__":
  main()
