#!/usr/bin/env python3
"""
generate_card_backs.py
──────────────────────

Generates 20 procedural playing-card back images for the Flutter app:
- 4 classic-inspired pattern families
- 5 colorways each (red, light blue, green, black, purple)

Output format: WebP (small + high quality for mobile/web).

Usage:
    python3 tools/generate_card_backs.py
    python3 tools/generate_card_backs.py --out assets/images/cards --size 600x840 --seed 1337
"""

from __future__ import annotations

import argparse
import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence, Tuple

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps

Color = Tuple[int, int, int]


@dataclass(frozen=True)
class Size:
  w: int
  h: int


@dataclass(frozen=True)
class Palette:
  name: str
  bg_top: Color
  bg_bottom: Color
  ink: Color
  ink_soft: Color


def _clamp(x: float, lo: float, hi: float) -> float:
  return max(lo, min(hi, x))


def _lerp(a: float, b: float, t: float) -> float:
  return a + (b - a) * t


def _lerp_color(a: Color, b: Color, t: float) -> Color:
  return (
    int(_lerp(a[0], b[0], t)),
    int(_lerp(a[1], b[1], t)),
    int(_lerp(a[2], b[2], t)),
  )


def _lighten(c: Color, amount: float) -> Color:
  amount = _clamp(amount, 0.0, 1.0)
  return (
    int(c[0] + (255 - c[0]) * amount),
    int(c[1] + (255 - c[1]) * amount),
    int(c[2] + (255 - c[2]) * amount),
  )


def _darken(c: Color, amount: float) -> Color:
  amount = _clamp(amount, 0.0, 1.0)
  return (
    int(c[0] * (1.0 - amount)),
    int(c[1] * (1.0 - amount)),
    int(c[2] * (1.0 - amount)),
  )


def _new_rgb(size: Size, color: Color) -> Image.Image:
  return Image.new("RGB", (size.w, size.h), color)


def _vertical_gradient(size: Size, top: Color, bottom: Color) -> Image.Image:
  # Faster than per-pixel loops; keeps gradients smooth even with supersampling.
  if size.h <= 1:
    return _new_rgb(size, top)
  g = Image.new("L", (1, size.h))
  g.putdata([int(255 * y / (size.h - 1)) for y in range(size.h)])
  g = g.resize((size.w, size.h), resample=Image.Resampling.BILINEAR)
  return ImageOps.colorize(g, black=top, white=bottom).convert("RGB")


def _radial_gradient(size: Size, inner: Color, outer: Color, center: Tuple[float, float]) -> Image.Image:
  img = Image.new("RGB", (size.w, size.h))
  px = img.load()
  cx, cy = center
  max_r = math.hypot(max(cx, size.w - cx), max(cy, size.h - cy))
  for y in range(size.h):
    dy = y - cy
    for x in range(size.w):
      t = math.hypot(x - cx, dy) / max_r
      t = _clamp(t, 0.0, 1.0)
      px[x, y] = _lerp_color(inner, outer, t)
  return img


def _draw_double_border(img: Image.Image, *, pad: int, outer: Color, inner: Color) -> None:
  draw = ImageDraw.Draw(img)
  w, h = img.size
  draw.rectangle((pad, pad, w - pad - 1, h - pad - 1), outline=outer, width=max(2, pad // 6))
  pad2 = pad + max(6, pad // 2)
  draw.rectangle((pad2, pad2, w - pad2 - 1, h - pad2 - 1), outline=inner, width=max(2, pad // 8))


def _add_subtle_noise(img: Image.Image, rng: random.Random, *, strength: float) -> Image.Image:
  strength = _clamp(strength, 0.0, 1.0)
  if strength <= 0:
    return img
  noise = Image.effect_noise(img.size, rng.uniform(24, 64)).convert("L")
  noise = ImageEnhance.Contrast(noise).enhance(1.6)
  noise = ImageOps.colorize(noise, black=(0, 0, 0), white=(255, 255, 255)).convert("RGB")
  return ImageChops.blend(img, noise, strength * 0.14)


def _draw_outer_border(img: Image.Image, *, width: int, color: Color) -> None:
  if width <= 0:
    return
  draw = ImageDraw.Draw(img)
  w, h = img.size
  for i in range(width):
    draw.rectangle((i, i, w - i - 1, h - i - 1), outline=color)


def _save_webp(img: Image.Image, path: Path) -> None:
  path.parent.mkdir(parents=True, exist_ok=True)
  _draw_outer_border(img, width=5 * max(8, img.size[0] // 80), color=(255, 255, 255))
  img.save(path, format="WEBP", quality=92, method=6)


# ──────────────────────────────────────────────────────────────────────────────
# Classic-inspired backs
# ──────────────────────────────────────────────────────────────────────────────

def _rgba(c: Color, a: int) -> Tuple[int, int, int, int]:
  return (c[0], c[1], c[2], a)


def _make_palette(name: str, base: Color) -> Palette:
  ink = (252, 252, 252) if name != "black" else (255, 252, 245)
  ink_soft = (240, 240, 240) if name != "black" else (245, 240, 230)
  return Palette(
    name=name,
    bg_top=_darken(base, 0.20),
    bg_bottom=_lighten(base, 0.10),
    ink=ink,
    ink_soft=ink_soft,
  )


_PAL_RED = _make_palette("red", (190, 30, 55))
_PAL_LIGHT_BLUE = _make_palette("light_blue", (55, 155, 255))
_PAL_GREEN = _make_palette("green", (20, 150, 90))
_PAL_BLACK = _make_palette("black", (18, 18, 22))
_PAL_PURPLE = _make_palette("purple", (120, 60, 215))
_COLORWAYS: Tuple[Palette, Palette, Palette, Palette, Palette] = (
  _PAL_RED,
  _PAL_LIGHT_BLUE,
  _PAL_GREEN,
  _PAL_BLACK,
  _PAL_PURPLE,
)


def _render_supersampled(
  size: Size,
  *,
  factor: int,
  builder,
) -> Image.Image:
  if factor <= 1:
    return builder(size)
  hi = Size(w=size.w * factor, h=size.h * factor)
  img = builder(hi)
  return img.resize((size.w, size.h), resample=Image.Resampling.LANCZOS)


def _draw_diamond(
  d: ImageDraw.ImageDraw,
  cx: float,
  cy: float,
  r: float,
  *,
  color: Tuple[int, int, int, int],
  width: int,
) -> None:
  pts = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy), (cx, cy - r)]
  d.line(pts, fill=color, width=width, joint="curve")


def _draw_beads(
  d: ImageDraw.ImageDraw,
  rect: Tuple[int, int, int, int],
  *,
  r: int,
  step: int,
  fill: Tuple[int, int, int, int],
) -> None:
  x0, y0, x1, y1 = rect
  for x in range(x0 + r * 2, x1 - r * 2, step):
    d.ellipse((x - r, y0 - r, x + r, y0 + r), fill=fill)
    d.ellipse((x - r, y1 - r, x + r, y1 + r), fill=fill)
  for y in range(y0 + r * 2, y1 - r * 2, step):
    d.ellipse((x0 - r, y - r, x0 + r, y + r), fill=fill)
    d.ellipse((x1 - r, y - r, x1 + r, y + r), fill=fill)


def _draw_hypotrochoid(
  d: ImageDraw.ImageDraw,
  center: Tuple[float, float],
  *,
  R: int,
  r: int,
  d0: int,
  steps: int,
  width: int,
  color: Tuple[int, int, int, int],
) -> None:
  cx, cy = center
  if R <= 0 or r <= 0:
    return
  g = math.gcd(R, r)
  turns = max(1, r // max(1, g))
  pts = []
  for i in range(steps + 1):
    t = (math.tau * turns) * (i / steps)
    x = (R - r) * math.cos(t) + d0 * math.cos(((R - r) / r) * t)
    y = (R - r) * math.sin(t) - d0 * math.sin(((R - r) / r) * t)
    pts.append((cx + x, cy + y))
  d.line(pts, fill=color, width=width, joint="curve")


def _pattern_ornate_filigree(size: Size, rng: random.Random, pal: Palette) -> Image.Image:
  def build(s: Size) -> Image.Image:
    img = _vertical_gradient(s, pal.bg_top, pal.bg_bottom)
    img = _add_subtle_noise(img, rng, strength=0.22)
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    pad0 = int(w * 0.11)
    pad1 = pad0 + int(w * 0.035)
    frame_w = max(6, w // 180)
    thin = max(3, w // 260)

    def rect(pad: int) -> Tuple[int, int, int, int]:
      return (pad, pad, w - pad - 1, h - pad - 1)

    d.rectangle(rect(pad0), outline=_rgba(pal.ink, 255), width=frame_w * 2)
    d.rectangle(rect(pad1), outline=_rgba(pal.ink, 255), width=frame_w)

    # Braided/rope-ish diagonals in the band.
    band = max(10, pad1 - pad0 - frame_w)
    step = max(22, w // 48)
    rope = _rgba(pal.ink, 140)
    # Top/bottom
    for x in range(pad0 - h, w - pad0 + h, step):
      d.line((x, pad0 + frame_w, x + band, pad1 - frame_w), fill=rope, width=thin)
      d.line((x + band, h - pad0 - frame_w, x, h - pad1 + frame_w), fill=rope, width=thin)
    # Left/right
    for y in range(pad0 - w, h - pad0 + w, step):
      d.line((pad0 + frame_w, y, pad1 - frame_w, y + band), fill=rope, width=thin)
      d.line((w - pad0 - frame_w, y, w - pad1 + frame_w, y + band), fill=rope, width=thin)

    # Subtle background rosettes (light).
    ro_step = max(120, w // 6)
    ro_r = max(10, w // 120)
    for yy in range(pad1 + ro_step // 2, h - pad1, ro_step):
      for xx in range(pad1 + ro_step // 2, w - pad1, ro_step):
        if rng.random() < 0.35:
          continue
        for k in range(8):
          ang = k * (math.tau / 8.0)
          px = xx + math.cos(ang) * ro_r * 2.5
          py = yy + math.sin(ang) * ro_r * 2.5
          d.ellipse((px - ro_r, py - ro_r, px + ro_r, py + ro_r), outline=_rgba(pal.ink, 45), width=thin)
        d.ellipse((xx - ro_r, yy - ro_r, xx + ro_r, yy + ro_r), outline=_rgba(pal.ink, 55), width=thin)

    # Corner pips.
    pip_r = max(12, w // 110)
    corners = [(pad1, pad1), (w - pad1 - 1, pad1), (pad1, h - pad1 - 1), (w - pad1 - 1, h - pad1 - 1)]
    for x, y in corners:
      d.ellipse((x - pip_r, y - pip_r, x + pip_r, y + pip_r), outline=_rgba(pal.ink, 220), width=thin)
      d.ellipse((x - pip_r // 3, y - pip_r // 3, x + pip_r // 3, y + pip_r // 3), fill=_rgba(pal.ink, 200))

    # Center medallion (diamond + guilloche).
    cx, cy = w * 0.5, h * 0.5
    dr = int(w * 0.18)
    _draw_diamond(d, cx, cy, dr, color=_rgba(pal.ink, 255), width=max(6, thin + 2))
    ring_r = int(dr * 0.78)
    d.ellipse((cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r), outline=_rgba(pal.ink, 220), width=thin)
    _draw_hypotrochoid(
      d,
      (cx, cy),
      R=max(40, int(dr * 0.75)),
      r=max(18, int(dr * 0.28)),
      d0=max(26, int(dr * 0.68)),
      steps=1700,
      width=thin,
      color=_rgba(pal.ink, 220),
    )

    # Simple corner scrolls (spirals).
    def spiral(cx0: float, cy0: float, sign_x: int, sign_y: int) -> None:
      pts = []
      turns = 1.65
      steps2 = 220
      rmax = w * 0.10
      phase = rng.uniform(0.0, math.tau)
      for i in range(steps2):
        t = (math.tau * turns) * (i / (steps2 - 1)) + phase
        rr = rmax * (i / (steps2 - 1))
        pts.append((cx0 + sign_x * rr * math.cos(t), cy0 + sign_y * rr * math.sin(t)))
      d.line(pts, fill=_rgba(pal.ink, 140), width=thin, joint="curve")

    inset = pad1 + int(w * 0.07)
    spiral(inset, inset, 1, 1)
    spiral(w - inset, inset, -1, 1)
    spiral(inset, h - inset, 1, -1)
    spiral(w - inset, h - inset, -1, -1)

    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    img = ImageEnhance.Contrast(img).enhance(1.08)
    return img

  return _render_supersampled(size, factor=2, builder=build)


def _pattern_lattice_seal(size: Size, rng: random.Random, pal: Palette) -> Image.Image:
  def build(s: Size) -> Image.Image:
    img = _vertical_gradient(s, _darken(pal.bg_top, 0.05), _lighten(pal.bg_bottom, 0.04))
    img = _add_subtle_noise(img, rng, strength=0.18)
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    pad0 = int(w * 0.11)
    pad1 = pad0 + int(w * 0.030)
    frame_w = max(6, w // 190)
    thin = max(3, w // 280)

    def rect(pad: int) -> Tuple[int, int, int, int]:
      return (pad, pad, w - pad - 1, h - pad - 1)

    d.rectangle(rect(pad0), outline=_rgba(pal.ink, 255), width=frame_w * 2)
    d.rectangle(rect(pad1), outline=_rgba(pal.ink, 255), width=frame_w)

    # Beaded inner frame for a classic "printed" feel.
    bead_r = max(6, w // 260)
    bead_step = max(22, w // 40)
    _draw_beads(d, rect(pad1 + int(w * 0.02)), r=bead_r, step=bead_step, fill=_rgba(pal.ink, 180))

    # Side stripe bands.
    band_w = int(w * 0.085)
    band_in = pad1 + int(w * 0.055)
    y0 = pad1 + int(w * 0.06)
    y1 = h - pad1 - int(w * 0.06)
    stripe_step = max(12, h // 100)
    for yy in range(y0, y1, stripe_step):
      d.line((band_in, yy, band_in + band_w, yy), fill=_rgba(pal.ink, 150), width=thin)
      d.line((w - band_in - band_w, yy, w - band_in, yy), fill=_rgba(pal.ink, 150), width=thin)

    # Central lattice panel.
    x0 = band_in + band_w + int(w * 0.04)
    x1 = w - x0
    panel = (x0, y0, x1, y1)
    step = max(70, int((x1 - x0) / 6))
    dot_r = max(7, step // 10)

    for yy in range(panel[1], panel[3] + 1, step):
      for xx in range(panel[0], panel[2] + 1, step):
        d.ellipse((xx - dot_r, yy - dot_r, xx + dot_r, yy + dot_r), outline=_rgba(pal.ink, 200), width=thin)
        # Horizontal/vertical connectors
        if xx + step <= panel[2]:
          d.line((xx + dot_r, yy, xx + step - dot_r, yy), fill=_rgba(pal.ink, 120), width=max(2, thin // 2))
        if yy + step <= panel[3]:
          d.line((xx, yy + dot_r, xx, yy + step - dot_r), fill=_rgba(pal.ink, 120), width=max(2, thin // 2))
        # Diagonals for a diamond lattice vibe.
        if xx + step <= panel[2] and yy + step <= panel[3]:
          d.line((xx + dot_r, yy + dot_r, xx + step - dot_r, yy + step - dot_r), fill=_rgba(pal.ink, 90), width=max(1, thin // 2))
        if xx - step >= panel[0] and yy + step <= panel[3]:
          d.line((xx - dot_r, yy + dot_r, xx - step + dot_r, yy + step - dot_r), fill=_rgba(pal.ink, 90), width=max(1, thin // 2))

    # Central seal medallion.
    cx, cy = w * 0.5, h * 0.5
    seal_r = int(w * 0.15)
    d.ellipse((cx - seal_r, cy - seal_r, cx + seal_r, cy + seal_r), outline=_rgba(pal.ink, 255), width=frame_w)
    d.ellipse((cx - int(seal_r * 0.82), cy - int(seal_r * 0.82), cx + int(seal_r * 0.82), cy + int(seal_r * 0.82)),
              outline=_rgba(pal.ink, 210), width=thin)

    petals = 8
    pr = int(seal_r * 0.20)
    for i in range(petals):
      ang = i * (math.tau / petals)
      px = cx + math.cos(ang) * seal_r * 0.50
      py = cy + math.sin(ang) * seal_r * 0.50
      d.ellipse((px - pr, py - pr, px + pr, py + pr), outline=_rgba(pal.ink, 220), width=thin)
    d.ellipse((cx - pr // 2, cy - pr // 2, cx + pr // 2, cy + pr // 2), fill=_rgba(pal.ink, 220))

    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    img = ImageEnhance.Contrast(img).enhance(1.06)
    return img

  return _render_supersampled(size, factor=2, builder=build)


def _pattern_twin_medallions(size: Size, rng: random.Random, pal: Palette) -> Image.Image:
  def build(s: Size) -> Image.Image:
    img = _vertical_gradient(s, pal.bg_top, pal.bg_bottom)
    img = _add_subtle_noise(img, rng, strength=0.20)
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    pad0 = int(w * 0.11)
    pad1 = pad0 + int(w * 0.030)
    frame_w = max(6, w // 190)
    thin = max(3, w // 280)

    def rect(pad: int) -> Tuple[int, int, int, int]:
      return (pad, pad, w - pad - 1, h - pad - 1)

    d.rectangle(rect(pad0), outline=_rgba(pal.ink, 255), width=frame_w * 2)
    d.rectangle(rect(pad1), outline=_rgba(pal.ink, 255), width=frame_w)

    # Background micro-diamonds (very subtle).
    step = max(60, w // 12)
    r = max(10, step // 6)
    for yy in range(pad1 + step // 2, h - pad1, step):
      for xx in range(pad1 + step // 2, w - pad1, step):
        _draw_diamond(d, xx, yy, r, color=_rgba(pal.ink, 40), width=thin)

    def medallion(cy: float) -> None:
      cx = w * 0.5
      R = int(w * 0.21)
      d.ellipse((cx - R, cy - R, cx + R, cy + R), outline=_rgba(pal.ink, 255), width=frame_w)
      d.ellipse((cx - int(R * 0.86), cy - int(R * 0.86), cx + int(R * 0.86), cy + int(R * 0.86)),
                outline=_rgba(pal.ink, 210), width=thin)
      # Beads around the ring.
      bead_r = max(5, w // 320)
      for i in range(28):
        ang = i * (math.tau / 28.0)
        px = cx + math.cos(ang) * R * 0.93
        py = cy + math.sin(ang) * R * 0.93
        d.ellipse((px - bead_r, py - bead_r, px + bead_r, py + bead_r), fill=_rgba(pal.ink, 190))

      # Diamond + rays.
      dr = R * 0.60
      _draw_diamond(d, cx, cy, dr, color=_rgba(pal.ink, 255), width=frame_w)
      _draw_diamond(d, cx, cy, dr * 0.65, color=_rgba(pal.ink, 210), width=thin)
      rays = 28
      for k in range(rays):
        ang = (k + 0.25) * (math.tau / rays)
        x2 = cx + math.cos(ang) * R * 0.78
        y2 = cy + math.sin(ang) * R * 0.78
        d.line((cx, cy, x2, y2), fill=_rgba(pal.ink, 120), width=max(2, thin // 2))

    medallion(h * 0.34)
    medallion(h * 0.66)

    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    img = ImageEnhance.Contrast(img).enhance(1.07)
    return img

  return _render_supersampled(size, factor=2, builder=build)


def _pattern_oval_filigree(size: Size, rng: random.Random, pal: Palette) -> Image.Image:
  def build(s: Size) -> Image.Image:
    img = _vertical_gradient(s, _darken(pal.bg_top, 0.04), _lighten(pal.bg_bottom, 0.04))
    img = _add_subtle_noise(img, rng, strength=0.18)
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    pad0 = int(w * 0.11)
    pad1 = pad0 + int(w * 0.030)
    frame_w = max(6, w // 190)
    thin = max(3, w // 280)

    def rect(pad: int) -> Tuple[int, int, int, int]:
      return (pad, pad, w - pad - 1, h - pad - 1)

    d.rectangle(rect(pad0), outline=_rgba(pal.ink, 255), width=frame_w * 2)
    d.rectangle(rect(pad1), outline=_rgba(pal.ink, 255), width=frame_w)

    # Dot-string inside the frame.
    bead_r = max(5, w // 320)
    _draw_beads(d, rect(pad1 + int(w * 0.03)), r=bead_r, step=max(20, w // 44), fill=_rgba(pal.ink, 180))

    # Central oval medallion with guilloche.
    cx, cy = w * 0.5, h * 0.5
    rx = int(w * 0.24)
    ry = int(h * 0.20)
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), outline=_rgba(pal.ink, 255), width=frame_w)
    d.ellipse((cx - int(rx * 0.86), cy - int(ry * 0.86), cx + int(rx * 0.86), cy + int(ry * 0.86)),
              outline=_rgba(pal.ink, 210), width=thin)

    # Guilloche-like rosette, stretched to oval.
    pts = []
    R = int(rx * 0.95)
    r = max(20, int(R * 0.35))
    d0 = max(22, int(R * 0.78))
    g = math.gcd(max(1, R), max(1, r))
    turns = max(1, r // max(1, g))
    steps = 1600
    for i in range(steps + 1):
      t = (math.tau * turns) * (i / steps)
      x = (R - r) * math.cos(t) + d0 * math.cos(((R - r) / r) * t)
      y = (R - r) * math.sin(t) - d0 * math.sin(((R - r) / r) * t)
      # stretch y to the oval.
      y *= (ry / max(1.0, rx))
      pts.append((cx + x, cy + y))
    d.line(pts, fill=_rgba(pal.ink, 210), width=thin, joint="curve")

    # Corner leaf/teardrop motifs.
    leaf_r = int(w * 0.06)
    for sx in (-1, 1):
      for sy in (-1, 1):
        lx = cx + sx * int(w * 0.25)
        ly = cy + sy * int(h * 0.30)
        d.ellipse((lx - leaf_r, ly - leaf_r, lx + leaf_r, ly + leaf_r), outline=_rgba(pal.ink, 140), width=thin)
        d.ellipse((lx - int(leaf_r * 0.55), ly - int(leaf_r * 0.90), lx + int(leaf_r * 0.55), ly + int(leaf_r * 0.90)),
                  outline=_rgba(pal.ink, 140), width=thin)

    # Small central cross motif.
    arm = int(w * 0.055)
    d.line((cx - arm, cy, cx + arm, cy), fill=_rgba(pal.ink, 200), width=thin)
    d.line((cx, cy - arm, cx, cy + arm), fill=_rgba(pal.ink, 200), width=thin)
    d.ellipse((cx - bead_r * 2, cy - bead_r * 2, cx + bead_r * 2, cy + bead_r * 2), fill=_rgba(pal.ink, 220))

    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    img = ImageEnhance.Contrast(img).enhance(1.06)
    return img

  return _render_supersampled(size, factor=2, builder=build)


# 20 outputs: 4 patterns × 5 colorways (filenames kept stable for the app).
def _geo_blue(size: Size, rng: random.Random) -> Image.Image:
  return _pattern_ornate_filigree(size, rng, _PAL_LIGHT_BLUE)


def _geo_black(size: Size, rng: random.Random) -> Image.Image:
  return _pattern_ornate_filigree(size, rng, _PAL_BLACK)


def _geo_green(size: Size, rng: random.Random) -> Image.Image:
  return _pattern_ornate_filigree(size, rng, _PAL_GREEN)


def _geo_red(size: Size, rng: random.Random) -> Image.Image:
  return _pattern_ornate_filigree(size, rng, _PAL_RED)


def _geo_yellow(size: Size, rng: random.Random) -> Image.Image:
  # Repurposed as purple to match requested 5th color.
  return _pattern_ornate_filigree(size, rng, _PAL_PURPLE)


def _animal_giraffe(size: Size, rng: random.Random) -> Image.Image:
  return _pattern_lattice_seal(size, rng, _PAL_RED)


def _animal_leopard(size: Size, rng: random.Random) -> Image.Image:
  return _pattern_lattice_seal(size, rng, _PAL_LIGHT_BLUE)


def _animal_white_tiger(size: Size, rng: random.Random) -> Image.Image:
  return _pattern_lattice_seal(size, rng, _PAL_GREEN)


def _animal_dalmatian(size: Size, rng: random.Random) -> Image.Image:
  return _pattern_lattice_seal(size, rng, _PAL_BLACK)


def _animal_peacock(size: Size, rng: random.Random) -> Image.Image:
  return _pattern_lattice_seal(size, rng, _PAL_PURPLE)


def _psychedelic(size: Size, rng: random.Random, variant: int) -> Image.Image:
  idx = (variant - 1) % 5
  pal = _COLORWAYS[idx]
  if variant <= 5:
    return _pattern_twin_medallions(size, rng, pal)
  return _pattern_oval_filigree(size, rng, pal)


# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────


def _parse_size(s: str) -> Size:
  parts = s.lower().replace("x", " ").split()
  if len(parts) != 2:
    raise ValueError("Size must look like 600x840")
  w, h = int(parts[0]), int(parts[1])
  if w < 100 or h < 100:
    raise ValueError("Size too small")
  return Size(w=w, h=h)


def _emit_all(size: Size, out_dir: Path, seed: int) -> Iterable[Tuple[str, Image.Image]]:
  # Use stable per-asset seeds so re-runs are deterministic.
  def rr(name: str) -> random.Random:
    return random.Random(f"{seed}:{name}")

  yield ("back_geo_blue.webp", _geo_blue(size, rr("geo_blue")))
  yield ("back_geo_black.webp", _geo_black(size, rr("geo_black")))
  yield ("back_geo_green.webp", _geo_green(size, rr("geo_green")))
  yield ("back_geo_red.webp", _geo_red(size, rr("geo_red")))
  yield ("back_geo_yellow.webp", _geo_yellow(size, rr("geo_yellow")))

  yield ("back_animal_giraffe.webp", _animal_giraffe(size, rr("animal_giraffe")))
  yield ("back_animal_leopard.webp", _animal_leopard(size, rr("animal_leopard")))
  yield ("back_animal_white_tiger.webp", _animal_white_tiger(size, rr("animal_white_tiger")))
  yield ("back_animal_dalmatian.webp", _animal_dalmatian(size, rr("animal_dalmatian")))
  yield ("back_animal_peacock.webp", _animal_peacock(size, rr("animal_peacock")))

  for i in range(1, 11):
    name = f"back_psy_{i:02d}.webp"
    yield (name, _psychedelic(size, rr(name), variant=i))


def main() -> int:
  ap = argparse.ArgumentParser()
  ap.add_argument("--out", default="assets/images/cards", help="Output directory")
  ap.add_argument("--size", default="600x840", help="Image size, e.g. 600x840 (aspect ~1.4)")
  ap.add_argument("--seed", type=int, default=1337, help="Deterministic seed")
  args = ap.parse_args()

  size = _parse_size(args.size)
  out_dir = Path(args.out)

  items = list(_emit_all(size, out_dir, seed=args.seed))
  for filename, img in items:
    _save_webp(img, out_dir / filename)
  print(f"Wrote {len(items)} card backs to {out_dir}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
