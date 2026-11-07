# Third-party artwork

| What | Where in the app | Source | Licence |
|---|---|---|---|
| Country flags | `assets/images/flags/world/*.png` (rendered at 160 x 120 from the 4x3 SVGs) | [flag-icons](https://github.com/lipis/flag-icons) 7.6.0, commit `ac7e0eb` | MIT, `flag-icons-LICENSE.txt` |
| Scene sounds (sound beds and reactions) | `assets/sounds/ambience/*.m4a`, cut and levelled by `tools/sounds/build_ambience.py`; the recordings used are listed in that script | [Sonniss #GameAudioGDC 2026 bundle](https://gdc.sonniss.com) (344 Audio, Epic Stock Media, InMotionAudio, Ivo Vicic, Jake Fielding, Just Sound Effects, Sonic Bat, Sonik Sound Library, TheWorkRoom) | Royalty-free, no attribution required; may not be used to train AI. `sonniss-gdc-2026-bundle-license.pdf` |
| Silhouettes in the kingdom scenes | `assets/scenes/icons.json` (paths re-encoded from the SVGs; author per icon in the file) | [game-icons.net](https://game-icons.net) via [game-icons/icons](https://github.com/game-icons/icons), by Delapouite, Lorc, Caro Asercion, Skoll and Cathelineau | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/), `game-icons-LICENSE.txt` |

The licences are also registered in the app (`lib/config/third_party_notices.dart`)
and credited in the About box. A test fails if a scene uses an icon by an
author the credit does not name.
