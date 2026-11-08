#!/usr/bin/env python3
"""Iteration 010 livestock calls, synthesised with the make_audio.py toolkit (numpy only, deterministic):
    sfx/neigh   a horse's whinny: a high, trilling call that falls away, ending in a snort
    sfx/moo     a cow's low lowing: hummed onset opening to a long "ooo"
Output: 22050 Hz mono 16-bit WAV in game/assets/audio/sfx/ (played positionally by scripts/world/animal.gd).
python3 make_animal_sounds.py"""
import sys
import wave

import numpy as np

import make_audio as A
from make_audio import N, tt, SR, TAU, glottal, ffilt, r_bp, r_lp, r_hp, formant_resp, env_pts, reverb, norm, rng_of, dbg


def neigh(rng):
    d = 1.5
    n = N(d)
    t = tt(n)
    # pitch: a quick rise, a trilling plateau, then the long falling whinny
    f0 = np.interp(t, [0, 0.08, 0.35, 0.9, 1.25, d], [520, 980, 900, 620, 380, 300])
    trill = 1 + 0.06 * np.sin(TAU * 11.5 * t) * np.interp(t, [0, 0.1, 1.0, d], [0, 1, 0.8, 0.2])
    src = glottal(f0 * trill, n, tilt=1.0)
    src += 0.25 * ffilt(rng.standard_normal(n), lambda f: r_bp(f, 2400, 1.2))   # breathiness
    voiced = ffilt(src, lambda f: 1.0 * r_bp(f, 1150, 3) + 0.7 * r_bp(f, 2300, 4) + 0.35 * r_bp(f, 3400, 5))
    amp = env_pts(n, [(0, 0), (0.03, 0.8), (0.12, 1.0), (0.85, 0.75), (1.2, 0.35), (1.32, 0.0), (d, 0)])
    amp *= 1 + 0.35 * np.sin(TAU * 11.5 * t + 0.6) * np.interp(t, [0, 0.1, 1.1, d], [0, 1, 0.6, 0])
    y = voiced / (np.max(np.abs(voiced)) + 1e-9) * amp
    # the closing snort: a broadband, nasal burst
    sn = N(0.22)
    snort = ffilt(rng.standard_normal(sn), lambda f: r_lp(f, 1400, 2) * r_hp(f, 120, 1)) * env_pts(sn, [(0, 0), (0.02, 1), (0.22, 0)])
    A.add_at(y, 0.55 * snort / (np.max(np.abs(snort)) + 1e-9), N(1.26))
    return reverb(y, 0.18, t60=0.9)


def moo(rng):
    d = 1.8
    n = N(d)
    t = tt(n)
    f0 = np.interp(t, [0, 0.25, 0.9, 1.5, d], [105, 132, 140, 118, 96]) * (1 + 0.012 * np.sin(TAU * 5.0 * t))
    src = glottal(f0, n, tilt=1.4)
    hum = ffilt(src, formant_resp("m"))
    oo = ffilt(src, formant_resp("o", bw=(110, 140, 200)))
    uu = ffilt(src, formant_resp("u", bw=(100, 130, 200)))
    k1 = np.clip((t - 0.15) / 0.3, 0, 1)
    k2 = np.clip((t - 1.0) / 0.6, 0, 1)
    v = hum * (1 - k1) + (oo * (1 - k2) + uu * k2) * k1
    v += 0.06 * ffilt(rng.standard_normal(n), lambda f: r_bp(f, 900, 1.5)) * np.std(v)
    amp = env_pts(n, [(0, 0), (0.08, 0.5), (0.4, 1.0), (1.3, 0.85), (1.7, 0.0), (d, 0)])
    y = v / (np.max(np.abs(v)) + 1e-9) * amp
    return reverb(y, 0.15, t60=0.8)


def write(sid, y, peak_db=-3.0):
    y = norm(y, dbg(peak_db))
    path = A.OUT / (sid + ".wav")
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(y, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(path, f"{len(y) / SR:.2f}s")


if __name__ == "__main__":
    for sid, fn in (("sfx/neigh", neigh), ("sfx/moo", moo)):
        if len(sys.argv) > 1 and not any(a in sid for a in sys.argv[1:]):
            continue
        write(sid, fn(rng_of(sid)))
