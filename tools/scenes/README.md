# Kingdom scenes

The drawn world behind the poker table: seven scenes for every kingdom
(war & history, animals, bar, rock, sport and two wild cards), listed in
`kingdoms.js`. Art direction: `docs/ART_DIRECTION.md`.

Scenes are written as ordinary canvas code (`t_*.js`, shared parts in
`kit.js`). `engine/rec.js` records what a scene draws as a small display
list; the app draws that list (`lib/ui/art/kingdom_scene.dart`), and so does
the preview (`engine/interp.js`). Keep the two drawers in step.

    node tools/scenes/build.js            # all kingdoms
    node tools/scenes/build.js Jaipur     # one kingdom's files

The build writes `assets/scenes/<id>.json`, `assets/scenes/icons.json` and
`lib/config/kingdom_scenes.g.dart`. Preview in a browser:
`tools/scenes/preview.html?k=Jaipur`.

Scene space: height 576, reference width 1344, rail top at y 91, rail
bottom at y 457. Only the strip above the rail, the four corners and the
strip under the rail show; keep tall shapes between the HUD pills
(`HERO_L`, `HERO_R` in `kit.js`) and anchor corner pieces with
`anchored(ctx, 'L' | 'R', ...)`.

Silhouettes come from game-icons.net (CC BY 3.0; authors per icon in
`engine/icons.js`, credited in the app's licences). To add icons, clone
https://github.com/game-icons/icons and run
`node tools/scenes/engine/build_icons.js <clone> tools/scenes/engine <names...>`
with the full list of names.
