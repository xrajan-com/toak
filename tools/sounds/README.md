# Scene sounds

The quiet sound of the place behind the table (a sound "bed": waves, a pub,
a stadium) and the place reacting to big moments (a war horn on an all-in,
the crowd when the player takes a big pot). Played by
`lib/services/ambience_service.dart`; each scene's bed is chosen in
`tools/scenes/ambience_beds.js`.

    python3 tools/sounds/build_ambience.py          # rebuild assets/sounds/ambience/

The script takes the steadiest 45 seconds of each recording (so no single
shout or thunderclap repeats every loop), mixes it to mono, levels it to
-20 dBFS RMS like the table effects, tames the loudest moments and saves
48 kbps AAC (about 270 KB a bed; about 4.5 MB for everything). Reactions
are the loudest few seconds, with a soft tail. The app cross-fades the loop
seam, so the files need no loop points.

The recordings it uses are in `tools/sounds/source/` as lossless FLAC of
the originals (one 10-channel file stays WAV). They are not in git (about
1.3 GB). They come from the Sonniss #GameAudioGDC 2026 bundle: royalty-free,
no attribution needed, never to be used for AI training
(`docs/licenses/sonniss-gdc-2026-bundle-license.pdf`).

To change a sound, edit `BEDS` or `REACTIONS` in the script (a fragment of
the recording's file name, its level, an ffmpeg filter) and run it again.
Needs ffmpeg and numpy.

## Win fireworks

    python3 tools/sounds/build_fireworks.py         # rebuild assets/sounds/firework_*.wav

Four booms cut from two recordings in the same bundle (two near shells,
two across a town), plus a launch thump and a crackle made in code, since
the recordings hold neither cleanly. Levelled like the table effects, with
the peak held under -1 dBFS so the booms keep their punch. Played by the
win fireworks (`lib/ui/screens/game_screen/action_burst.dart`, at most four
sounds a show, only when the player wins) through `SoundFx.playFirework`.
