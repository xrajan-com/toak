#!/usr/bin/env python3
"""
normalize_custom_card_backs.py
──────────────────────────────

Normalizes the custom card-back assets used by the Flutter app:

- Trims outer whitespace/blank margins (near-white)
- Resizes to a consistent output size
- Adds a uniform white border on all sides
- Overwrites files in-place (so existing asset paths remain valid)

Usage:
    python3 tools/normalize_custom_card_backs.py
    python3 tools/normalize_custom_card_backs.py --border 30 --size 600x840
    python3 tools/normalize_custom_card_backs.py --dry-run
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Tuple

from PIL import Image, ImageOps


@dataclass(frozen=True)
class Size:
  w: int
  h: int


def _parse_size(s: str) -> Size:
  try:
    a, b = s.lower().split("x", 1)
    w = int(a.strip())
    h = int(b.strip())
    if w <= 0 or h <= 0:
      raise ValueError()
    return Size(w=w, h=h)
  except Exception as e:  # pragma: no cover
    raise argparse.ArgumentTypeError(f'Invalid size "{s}" (expected WxH)') from e


def _scan_trim_bbox(img: Image.Image, *, tol: int, frac: float) -> Tuple[int, int, int, int]:
  """Returns a bbox trimming near-white margins.

  A row/col is considered margin if <= `frac` of its pixels are non-white.
  Pixel is considered white if all channels >= (255 - tol).
  """
  rgb = img.convert("RGB")
  w, h = rgb.size
  px = rgb.load()

  thr = 255 - tol

  def row_nonwhite_fraction(y: int) -> float:
    non = 0
    for x in range(w):
      r, g, b = px[x, y]
      if r < thr or g < thr or b < thr:
        non += 1
    return non / w

  def col_nonwhite_fraction(x: int) -> float:
    non = 0
    for y in range(h):
      r, g, b = px[x, y]
      if r < thr or g < thr or b < thr:
        non += 1
    return non / h

  top = 0
  while top < h and row_nonwhite_fraction(top) <= frac:
    top += 1

  bottom = h - 1
  while bottom >= 0 and row_nonwhite_fraction(bottom) <= frac:
    bottom -= 1

  left = 0
  while left < w and col_nonwhite_fraction(left) <= frac:
    left += 1

  right = w - 1
  while right >= 0 and col_nonwhite_fraction(right) <= frac:
    right -= 1

  if top >= bottom or left >= right:
    return (0, 0, w, h)

  # bbox uses exclusive end coords.
  return (left, top, right + 1, bottom + 1)


def _expand_bbox(
  bbox: Tuple[int, int, int, int],
  *,
  size: Tuple[int, int],
  pad: int,
) -> Tuple[int, int, int, int]:
  x0, y0, x1, y1 = bbox
  w, h = size
  return (
    max(0, x0 - pad),
    max(0, y0 - pad),
    min(w, x1 + pad),
    min(h, y1 + pad),
  )


def _iter_backs(pattern: str) -> Iterable[Path]:
  paths = sorted(Path().glob(pattern))
  if not paths:
    raise SystemExit(f'No files matched: "{pattern}"')
  return paths


def main() -> int:
  ap = argparse.ArgumentParser()
  ap.add_argument(
    "--pattern",
    default="assets/images/cards/back_custom_*.webp",
    help="Glob of card back assets to normalize (default: %(default)s)",
  )
  ap.add_argument(
    "--size",
    type=_parse_size,
    default=Size(w=600, h=840),
    help="Output size WxH (default: %(default)s)",
  )
  ap.add_argument(
    "--border",
    type=int,
    default=30,
    help="Uniform white border thickness in px (default: %(default)s)",
  )
  ap.add_argument(
    "--trim-tol",
    type=int,
    default=15,
    help="Near-white tolerance (lower trims less; default: %(default)s)",
  )
  ap.add_argument(
    "--trim-frac",
    type=float,
    default=0.02,
    help="Max non-white fraction for a row/col to be treated as margin (default: %(default)s)",
  )
  ap.add_argument(
    "--trim-pad",
    type=int,
    default=6,
    help="Padding added back after trimming, in px (default: %(default)s)",
  )
  ap.add_argument(
    "--quality",
    type=int,
    default=92,
    help="WebP quality (default: %(default)s)",
  )
  ap.add_argument("--dry-run", action="store_true", help="Print actions but do not write files")
  args = ap.parse_args()

  size: Size = args.size
  border: int = args.border
  if border < 0 or border * 2 >= min(size.w, size.h):
    raise SystemExit("--border must be >= 0 and smaller than half the output dimensions")

  inner_w = size.w - border * 2
  inner_h = size.h - border * 2

  paths = list(_iter_backs(args.pattern))

  for p in paths:
    with Image.open(p) as im:
      bbox = _scan_trim_bbox(im, tol=args.trim_tol, frac=args.trim_frac)
      bbox = _expand_bbox(bbox, size=im.size, pad=max(0, args.trim_pad))
      cropped = im.convert("RGB").crop(bbox)

      fitted = ImageOps.fit(
        cropped,
        (inner_w, inner_h),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
      )

      out = Image.new("RGB", (size.w, size.h), (255, 255, 255))
      out.paste(fitted, (border, border))

      if args.dry_run:
        print(f"{p} <- trim {bbox} -> {inner_w}x{inner_h} + border {border}px")
      else:
        out.save(p, format="WEBP", quality=args.quality, method=6)

  if args.dry_run:
    print(f"Dry run complete ({len(paths)} files).")
  else:
    print(f"Normalized {len(paths)} files.")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
