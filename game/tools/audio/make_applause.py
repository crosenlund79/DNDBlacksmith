#!/usr/bin/env python3
"""Applause for the ceremony in the village square (sfx/applause).

A crowd of a dozen villagers clapping: each clap is a short band-passed noise burst with a
hand-sized resonance; clappers start staggered, swell, and trail off one by one, with a
couple of cheers (formant-ish voiced bursts) on top. numpy only, deterministic.
Writes game/assets/audio/sfx/applause.wav (22050 Hz mono 16-bit).
"""
import wave
from pathlib import Path

import numpy as np

SR = 22050
OUT = Path(__file__).resolve().parent.parent.parent / "assets" / "audio" / "sfx" / "applause.wav"


def bandpass(x, lo, hi):
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    resp = np.exp(-0.5 * ((np.log(np.maximum(fr, 1) / np.sqrt(lo * hi))) / (np.log(hi / lo) / 2)) ** 2)
    return np.fft.irfft(f * resp, len(x))


def clap(rng):
    n = int(SR * 0.05)
    t = np.arange(n) / SR
    env = np.exp(-t / rng.uniform(0.006, 0.012))
    x = rng.standard_normal(n) * env
    c = rng.uniform(900, 2200)
    return bandpass(x, c * 0.6, c * 1.8)


def cheer(rng, dur):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f0 = rng.uniform(170, 260) * (1 + 0.15 * np.sin(2 * np.pi * 3 * t))
    ph = np.cumsum(2 * np.pi * f0 / SR)
    v = sum(np.sin(k * ph) / k for k in range(1, 12))
    v = bandpass(v, 500, 2600)
    env = np.minimum(1, t / 0.08) * np.exp(-t / (dur * 0.6))
    return v * env * 0.35


def main():
    rng = np.random.default_rng(7310)
    dur = 4.2
    n = int(SR * dur)
    out = np.zeros(n + SR)
    for c in range(14):
        start = rng.uniform(0.0, 0.5)
        stop = rng.uniform(2.6, 3.9)
        rate = rng.uniform(4.2, 6.5)
        amp = rng.uniform(0.5, 1.0)
        t = start
        while t < stop:
            k = clap(rng)
            i = int(t * SR)
            fade = min(1.0, (t - start) / 0.4) * (1.0 if t < stop - 0.8 else max(0.0, (stop - t) / 0.8))
            out[i:i + len(k)] += k * amp * fade
            t += 1.0 / rate * rng.uniform(0.85, 1.15)
    for s in (0.6, 1.5):
        k = cheer(rng, 0.9)
        i = int(s * SR)
        out[i:i + len(k)] += k
    out = out[:n]
    out *= np.minimum(1, (n - np.arange(n)) / (0.3 * SR))
    out /= np.max(np.abs(out)) / (10 ** (-3 / 20))
    pcm = (out * 32767).astype(np.int16)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", OUT)


if __name__ == "__main__":
    main()
