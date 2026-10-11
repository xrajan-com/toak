# Brand colours

X Poker uses one blue and two reds. The values live in `project.yaml`
(`colors.*`); `tools/verify_palette.sh` fails a release if the app drifts
from them.

| Role | Name | Hex | Reference |
| --- | --- | --- | --- |
| Primary accent (energy) | **Ferrari Red** | `#FF2800` | The widely used digital value for Ferrari red |
| Action bar danger buttons, red kingdom pill | Action Red | `#C41230` | The only other red allowed |
| Secondary accent (peace) | **Porsche Miami Blue** | `#00B5C8` | Porsche *Miamiblau*, factory paint code **M5C / J5** |

## The story

The red is Ferrari red (energy); the blue is Porsche Miami Blue (peace,
beaches). Together they are "work hard, play hard": a contrast between
technology and nature. The app icon's red/blue split carries the same idea.

## Porsche Miami Blue: reference values

Chosen 11 October 2026, from a web search for the paint's hex code
(screenshot: `design_sources/brand/references/porsche-miami-blue-search-2026-10-11.png`).

- Paint code: **M5C / J5**, German name *Miamiblau*
- Digital hex used by X Poker: **`#00B5C8`** (RGB 0, 181, 200)
- Alternative design approximation: `#54C3EA` (RGB 84, 195, 234;
  CMYK 64, 17, 0, 8), closest Pantone 2985 C. Not used; recorded only so the
  choice is clear.

Paint is a physical metallic finish, so no single hex code is "the" Miami
Blue; `#00B5C8` is the value we standardise on.

## History

- Until October 2026 the blue was `#20D9FF`, a bright cyan named only
  "beach blue". It was replaced everywhere in the app and website by Miami
  Blue, and `tools/verify_palette.sh` now rejects `#20D9FF` so it cannot
  creep back. App icons already rendered keep their colours until the icon
  is next redrawn.
