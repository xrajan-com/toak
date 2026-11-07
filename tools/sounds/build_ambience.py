#!/usr/bin/env python3
"""Builds the scene sounds in assets/sounds/ambience/ from recordings in the
Sonniss GDC 2026 bundle (royalty-free, no attribution; not for AI training).

    python3 tools/sounds/build_ambience.py [--out assets/sounds/ambience] [source folder...]

The recordings it uses are kept in tools/sounds/source/ (lossless FLAC of the
originals; not in git, about 1.3 GB), which is the default source folder.

Every bed is a steady 45-second stretch of one or more recordings, mixed to
mono, levelled to -20 dBFS RMS like the table effects (SoundMix) and saved as
48 kbps AAC. The app cross-fades the loop seam itself (AmbienceService), so
the files need no loop points. Reactions are the loudest few seconds of a
crowd, a horn or fireworks, levelled the same way with a soft tail.

Needs ffmpeg and numpy. Sources are found by a fragment of their file name.
"""
import json
import os
import subprocess
import sys

import numpy as np

RATE = 44100
TARGET_RMS_DB = -20.0
PEAK_LIMIT = 0.79  # -2 dBFS: room for the AAC encoder to overshoot
BED_SECONDS = 45.0

# bed: [(file name fragment, level relative to the bed, ffmpeg filter or None,
#        how many times to scatter a short sound through the loop, or 0 for a
#        recording that runs the whole length)]
BEDS = {
    'sea': [('Medium Waves at Pebble Beach', 1.0, None, 0)],
    'jungle': [('Jungle Night Humid Birds Bug Chirps', 1.0, None, 0)],
    'meadow': [('Meadow Pipits calling many Insects', 1.0, None, 0)],
    'desert': [('Eye Of The Storm | Wind Whipping Constricted Flow', 1.0, 'lowpass=f=2200', 0)],
    'night': [('Forest Crickets, Birds, Connecticut', 1.0, None, 0)],
    'snow': [('ChimneyWind05 | Eye Of The Storm', 1.0, 'lowpass=f=3500', 0),
             ('ice field cracking up', 0.5, None, 3)],
    'lake': [('Small Waves sloshing onto Rock Slabs | Tennessee Lake Dock Water Ripples', 1.0, None, 0)],
    'city': [('City Nightlife Ext Street', 1.0, None, 0)],
    'pub': [('Pub Walla, Crowd, Bar', 1.0, None, 0)],
    'casino': [('SBbra_Bar E 001', 1.0, None, 0),
               ('Shimmer Loop Small Bell Metal Taps', 0.12, None, 0)],
    'stadium': [('Masculine Regional Match', 1.0, None, 0)],
    'concert': [('Dense Immersive Group of Adults', 1.0, None, 0)],
    'camp': [('Campfire, Dropping Fresh Pine Branches | Fire Crackling Crunchy Flame Burn', 1.0, None, 0),
             ('ChimneyWind05', 0.35, 'lowpass=f=1800', 0)],
    'festival': [('NIG015', 1.0, None, 0),
                 ('Distant Fireworks 005 | Fireworks_ explosions_dense_whistles', 0.45, 'lowpass=f=5000', 0)],
    'storm': [('StormAmbience11 | Texas Rain Thunder', 1.0, None, 0)],
    'underwater': [('Soft Waves Cliffs', 1.0, 'lowpass=f=320,highpass=f=40', 0),
                   ('Liquid Impact, Bubble', 0.35, 'lowpass=f=3000', 4)],
}

# reaction: (file name fragment, seconds, where: 'start' | 'loudest')
REACTIONS = {
    'horn': ('Cinematic Horn Braam, Epic, Cinematic, Dark, Instrument, Huge-32', 5.0, 'start'),
    'cheer': ('Small Club, 50 People, Crowd, Spanish, Cheering and Applause', 5.0, 'loudest'),
    'toast': ('Dinner Party Crowd in Terrace', 4.0, 'loudest'),
    'fireworks': ('Fireworks_powerful explosions_multiples in a row_near', 4.0, 'loudest'),
    'ooh': ('Feminine League Match 017', 3.0, 'loudest'),
}


def find(roots, fragment):
    """The first recording whose name holds the fragment; 'a | b' tries a,
    then b."""
    if ' | ' in fragment:
        for alt in fragment.split(' | '):
            hit = find(roots, alt)
            if hit:
                return hit
        return None
    hits = []
    for root in roots:
        for folder, _, files in os.walk(root):
            for f in files:
                if f.lower().endswith(('.wav', '.flac')) and fragment.lower() in f.lower():
                    hits.append(os.path.join(folder, f))
    if not hits:
        return None
    # Prefer stereo/mono masters over ambisonic or surround versions.
    hits.sort(key=lambda p: (('ambix' in p.lower()) or ('b-format' in p.lower()), len(p)))
    return hits[0]


def decode(path, flt=None):
    cmd = ['ffmpeg', '-v', 'error', '-i', path]
    if flt:
        cmd += ['-af', flt]
    cmd += ['-ac', '1', '-ar', str(RATE), '-f', 'f32le', '-']
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def rms(x):
    return float(np.sqrt(np.mean(x * x)) + 1e-12)


def level(x, db=TARGET_RMS_DB):
    return x * (10 ** (db / 20) / rms(x))


def window_db(x, win):
    n = len(x) // win
    if n == 0:
        return np.array([20 * np.log10(rms(x))])
    blocks = x[: n * win].reshape(n, win)
    return 20 * np.log10(np.sqrt(np.mean(blocks * blocks, axis=1)) + 1e-12)


def tile(x, seconds, fade=2.0):
    """Repeats a short recording with cross-fades until it is long enough."""
    need, f = int(seconds * RATE), int(min(fade * RATE, len(x) // 3))
    out = x.copy()
    while len(out) < need:
        ramp = np.linspace(0, 1, f)
        head = out[:-f]
        seam = out[-f:] * (1 - ramp) + x[:f] * ramp
        out = np.concatenate([head, seam, x[f:]])
    return out


def steady_stretch(x, seconds):
    """The calmest stretch: the one whose loudness swings least, so no single
    shout or bang repeats every time the loop comes round."""
    need = int(seconds * RATE)
    if len(x) <= need + 2 * RATE:
        return tile(x, seconds)[:need]
    half = RATE // 2
    db = window_db(x, half)
    per = need // half
    best, best_score = 0, None
    for i in range(1, len(db) - per - 1):
        seg = db[i:i + per]
        score = float(np.max(seg) - np.median(seg)) + 0.5 * float(np.std(seg))
        if best_score is None or score < best_score:
            best, best_score = i, score
    return x[best * half: best * half + need]


def scatter(x, seconds, count, seed):
    """Places a short sound [count] times through the loop, away from the
    seam, at slightly different levels."""
    need = int(seconds * RATE)
    out = np.zeros(need)
    rng = np.random.default_rng(seed)
    x = x[:need // max(count, 1)]
    slots = np.linspace(2 * RATE, need - len(x) - 2 * RATE, count)
    for i, at in enumerate(slots):
        at = int(at + rng.uniform(-1, 1) * RATE)
        at = min(max(at, 0), need - len(x))
        out[at:at + len(x)] += x * rng.uniform(0.6, 1.0)
    return out


def loudest_stretch(x, seconds):
    need = int(seconds * RATE)
    if len(x) <= need:
        return x
    tenth = RATE // 10
    db = window_db(x, tenth)
    per = need // tenth
    energy = np.convolve(10 ** (db / 10), np.ones(per), mode='valid')
    start = int(np.argmax(energy)) * tenth
    # Begin a little before the swell.
    start = max(0, start - RATE // 4)
    return x[start:start + need]


def limit(x):
    """Pulls the rare loud moment (a thunderclap, a shout) down towards the
    rest instead of turning the whole loop down for it: a gentle compressor
    above -14 dBFS, then a soft ceiling at -1 dBFS."""
    t = 10 ** (-14 / 20)
    a = np.abs(x)
    over = a > t
    y = x.copy()
    y[over] = np.sign(x[over]) * (t + (a[over] - t) / 3)
    a = np.abs(y)
    over = a > PEAK_LIMIT * 0.7
    k = PEAK_LIMIT * 0.7
    y[over] = np.sign(y[over]) * (k + (PEAK_LIMIT - k) * np.tanh((a[over] - k) / (PEAK_LIMIT - k)))
    return y


def fades(x, fade_in, fade_out):
    a, b = int(fade_in * RATE), int(fade_out * RATE)
    y = x.copy()
    if a:
        y[:a] *= np.linspace(0, 1, a)
    if b:
        y[-b:] *= np.linspace(1, 0, b) ** 2
    return y


def encode(x, out, kbps):
    pcm = np.clip(x, -1, 1).astype(np.float32).tobytes()
    subprocess.run(
        ['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', '-',
         '-af', 'highpass=f=40', '-c:a', 'aac', '-b:a', f'{kbps}k', '-movflags', '+faststart', out],
        input=pcm, check=True)


def main():
    args = sys.argv[1:]
    out_dir = 'assets/sounds/ambience'
    if '--out' in args:
        i = args.index('--out')
        out_dir = args[i + 1]
        del args[i:i + 2]
    root = args or [os.path.join(os.path.dirname(os.path.abspath(__file__)), 'source')]
    os.makedirs(out_dir, exist_ok=True)
    report, missing = {}, []
    for bed, layers in BEDS.items():
        mix = None
        used = []
        for i, (fragment, gain, flt, count) in enumerate(layers):
            src = find(root, fragment)
            if not src:
                missing.append(f'bed {bed}: {fragment}')
                continue
            x = decode(src, flt)
            if count:
                part = scatter(level(loudest_stretch(x, 3.0)), BED_SECONDS, count, i + 7) * gain
            else:
                part = level(steady_stretch(x, BED_SECONDS)) * gain
            mix = part if mix is None else mix[:len(part)] + part[:len(mix)]
            used.append(os.path.basename(src))
        if mix is None:
            continue
        mix = limit(level(mix))
        out = os.path.join(out_dir, f'bed_{bed}.m4a')
        encode(fades(mix, 0.3, 0.3), out, 48)
        report[f'bed_{bed}'] = {'sources': used, 'kb': os.path.getsize(out) // 1024}
    for name, (fragment, seconds, where) in REACTIONS.items():
        src = find(root, fragment)
        if not src:
            missing.append(f'react {name}: {fragment}')
            continue
        x = decode(src)
        x = x[:int(seconds * RATE)] if where == 'start' else loudest_stretch(x, seconds)
        x = limit(level(fades(x, 0.04, min(1.2, seconds / 3))))
        out = os.path.join(out_dir, f'react_{name}.m4a')
        encode(x, out, 64)
        report[f'react_{name}'] = {'sources': [os.path.basename(src)], 'kb': os.path.getsize(out) // 1024}
    print(json.dumps(report, indent=1))
    total = sum(v['kb'] for v in report.values())
    print(f'{len(report)} files, {total} KB')
    if missing:
        print('MISSING:\n  ' + '\n  '.join(missing))
        sys.exit(1)


if __name__ == '__main__':
    main()
