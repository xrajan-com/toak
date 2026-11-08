#!/usr/bin/env python3
"""Builds the win-fireworks sounds in assets/sounds/:

    python3 tools/sounds/build_fireworks.py [--out assets/sounds] [source folder...]

The booms are cut from two recordings in the Sonniss GDC 2026 bundle
(royalty-free, no attribution; not for AI training), kept in
tools/sounds/source/ like the scene sounds:

    firework_boom_1/2   near shells bursting overhead (Ivo Vicic, Fireworks FX)
    firework_far_1/2    single shells across a town (Sonic Bat, Distant
                        Fireworks), with their natural echo

The recordings hold no clean launch or crackle, so those two are made here:

    firework_launch     the mortar's low thump and a short rising hiss
    firework_crackle    a burst of tiny sharp pops thinning out, with a
                        little room on it

Every file is mono 44.1 kHz 16-bit WAV, levelled to about -20 dBFS RMS like
the other table effects (SoundMix), with its peak held under -1 dBFS.
Needs ffmpeg and numpy.
"""
import os
import subprocess
import sys

import numpy as np

RATE = 44100
TARGET_RMS_DB = -20.0
PEAK_CEILING = 0.89  # -1 dBFS

# name: (file name fragment, approximate burst time in s, length in s)
CLIPS = {
    'firework_boom_1': ('Fireworks_powerful explosions_multiples in a row_near', 6.61, 1.35),
    'firework_boom_2': ('Fireworks_powerful explosions_multiples in a row_near', 2.64, 1.45),
    'firework_far_1': ('Distant Fireworks 005', 108.79, 1.6),
    'firework_far_2': ('Distant Fireworks 005', 284.24, 1.5),
}


def find(roots, fragment):
    for root in roots:
        for folder, _, files in os.walk(root):
            for f in sorted(files):
                if f.lower().endswith(('.wav', '.flac')) and fragment.lower() in f.lower():
                    return os.path.join(folder, f)
    return None


def decode(path):
    cmd = ['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', str(RATE), '-f', 'f32le', '-']
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def rms(x):
    return float(np.sqrt(np.mean(x * x)) + 1e-12)


def level(x):
    """-20 dBFS RMS, unless that would push the peak past -1 dBFS; then the
    peak sets the level. A boom keeps its punch instead of being limited."""
    gain = 10 ** (TARGET_RMS_DB / 20) / rms(x)
    peak = float(np.max(np.abs(x))) * gain
    if peak > PEAK_CEILING:
        gain *= PEAK_CEILING / peak
    return x * gain


def fade(x, fade_in, fade_out_share):
    y = x.copy()
    a = int(fade_in * RATE)
    if a:
        y[:a] *= np.linspace(0, 1, a)
    b = int(len(y) * fade_out_share)
    if b:
        y[-b:] *= np.linspace(1, 0, b) ** 2
    return y


def band(x, lo, hi):
    """Band-pass by masking the spectrum, with soft edges."""
    n = len(x)
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / RATE)
    lo_gain = 1 / (1 + (lo / np.maximum(f, 1)) ** 4) if lo else 1
    hi_gain = 1 / (1 + (f / hi) ** 4) if hi else 1
    return np.fft.irfft(spec * lo_gain * hi_gain, n)


def cut(x, at, seconds):
    """The burst nearest [at], from just before its first sharp rise."""
    a, b = int((at - 0.12) * RATE), int((at + 0.12) * RATE)
    win = np.abs(x[a:b])
    onset = a + int(np.argmax(win > 0.3 * win.max()))
    start = max(0, onset - int(0.006 * RATE))
    return x[start:start + int(seconds * RATE)]


def launch(rng):
    """A mortar firing: a low thump, then the shell's hiss rising away."""
    n = int(0.62 * RATE)
    t = np.arange(n) / RATE
    thump = np.sin(2 * np.pi * (55 + 40 * np.exp(-t / 0.03)) * t) * np.exp(-t / 0.07)
    thump += band(rng.standard_normal(n), 60, 400) * np.exp(-t / 0.035) * 0.6
    # Rising hiss: noise through a band-pass whose centre climbs 500 Hz to
    # 2.4 kHz (a two-pole resonator, retuned every sample).
    noise = rng.standard_normal(n)
    hiss = np.zeros(n)
    y1 = y2 = 0.0
    for i in range(n):
        fc = 500 * (2400 / 500) ** min(1.0, t[i] / 0.5)
        r = 0.985
        c = 2 * r * np.cos(2 * np.pi * fc / RATE)
        y = noise[i] * (1 - r) + c * y1 - r * r * y2
        y2, y1 = y1, y
        hiss[i] = y
    swell = np.clip((t - 0.02) / 0.12, 0, 1) * np.clip((0.6 - t) / 0.35, 0, 1)
    hiss *= swell / (np.max(np.abs(hiss)) + 1e-9)
    thump /= np.max(np.abs(thump)) + 1e-9
    return fade(thump * 0.9 + hiss * 0.45, 0.002, 0.15)


def crackle(rng):
    """Dozens of tiny sharp pops, quick at first and thinning out, each with
    a hint of room after it."""
    n = int(1.15 * RATE)
    out = np.zeros(n)
    t = 0.01
    while True:
        # Gaps grow from ~18 ms to ~90 ms as the stars burn out.
        t += 0.004 + rng.exponential(0.014 + 0.075 * (t / 0.95) ** 1.4)
        if t > 0.98:
            break
        i = int(t * RATE)
        k = int(rng.uniform(0.0008, 0.0025) * RATE)
        pop = rng.standard_normal(k) * np.exp(-np.arange(k) / (k / 5))
        out[i:i + k] += pop * rng.uniform(0.3, 1.0) * (1.0 - 0.55 * t)
    out = band(out, 1800, 10000)
    m = int(0.12 * RATE)
    ir = rng.standard_normal(m) * np.exp(-np.arange(m) / (0.02 * RATE))
    wet = np.convolve(out, ir)[:n]
    wet /= np.max(np.abs(wet)) + 1e-9
    dry = out / (np.max(np.abs(out)) + 1e-9)
    return fade(dry + wet * 0.12, 0.0005, 0.15)


def write(x, path):
    pcm = np.clip(x, -1, 1).astype(np.float32).tobytes()
    subprocess.run(
        ['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', '-',
         '-af', 'highpass=f=35', '-c:a', 'pcm_s16le', path],
        input=pcm, check=True)


def main():
    args = sys.argv[1:]
    out_dir = 'assets/sounds'
    if '--out' in args:
        i = args.index('--out')
        out_dir = args[i + 1]
        del args[i:i + 2]
    roots = args or [os.path.join(os.path.dirname(os.path.abspath(__file__)), 'source')]
    os.makedirs(out_dir, exist_ok=True)
    rng = np.random.default_rng(2026_11_08)
    made, missing, cache = {}, [], {}
    for name, (fragment, at, seconds) in CLIPS.items():
        src = find(roots, fragment)
        if not src:
            missing.append(f'{name}: {fragment}')
            continue
        if src not in cache:
            cache[src] = decode(src)
        made[name] = fade(cut(cache[src], at, seconds), 0.002, 0.35)
    made['firework_launch'] = launch(rng)
    made['firework_crackle'] = crackle(rng)
    for name, x in made.items():
        x = level(x)
        path = os.path.join(out_dir, f'{name}.wav')
        write(x, path)
        print(f'{name:18s} {len(x) / RATE:4.2f} s  rms {20 * np.log10(rms(x)):6.1f} dBFS  '
              f'peak {20 * np.log10(np.max(np.abs(x))):5.1f} dBFS  {os.path.getsize(path) // 1024} KB')
    if missing:
        print('MISSING:\n  ' + '\n  '.join(missing))
        sys.exit(1)


if __name__ == '__main__':
    main()
