#!/usr/bin/env python3
"""The voice of an awakened piece of equipment (sfx/spirit_whisper).

A short, quiet shimmer: a few inharmonic bell partials ringing up out of nothing (like a struck blade heard
from far away), with a breath of band-passed noise underneath that rises and falls like a whisper.
numpy only, deterministic. Writes game/assets/audio/sfx/spirit_whisper.wav (22050 Hz mono 16-bit) and
registers it in assets/audio/manifest.json.
"""
import json
import wave
from pathlib import Path

import numpy as np

SR = 22050
ROOT = Path(__file__).resolve().parent.parent.parent / "assets" / "audio"
OUT = ROOT / "sfx" / "spirit_whisper.wav"


def bandpass(x, lo, hi):
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    resp = np.exp(-0.5 * ((np.log(np.maximum(fr, 1) / np.sqrt(lo * hi))) / (np.log(hi / lo) / 2)) ** 2)
    return np.fft.irfft(f * resp, len(x))


def main():
    rng = np.random.default_rng(1103)
    dur = 1.15
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # inharmonic partials of a thin blade, each swelling in slightly later and shimmering
    base = 880.0
    for k, (ratio, amp, delay) in enumerate([(1.0, 1.0, 0.0), (2.76, 0.55, 0.05), (5.4, 0.3, 0.1), (8.93, 0.16, 0.14), (1.5, 0.35, 0.22)]):
        f = base * ratio * (1 + 0.004 * np.sin(2 * np.pi * (5.5 + k) * t))
        ph = np.cumsum(2 * np.pi * f / SR)
        tt = np.maximum(0, t - delay)
        env = (1 - np.exp(-tt / 0.09)) * np.exp(-tt / (0.45 - k * 0.04)) * (t >= delay)
        out += np.sin(ph) * env * amp
    # the whisper: breathy noise, band-passed and slowly opened and closed
    noise = rng.standard_normal(n)
    breath = bandpass(noise, 1400, 5200)
    benv = np.sin(np.pi * np.clip(t / 0.9, 0, 1)) ** 2 * (0.6 + 0.4 * np.sin(2 * np.pi * 3.1 * t))
    out += breath * benv * 0.22
    out *= np.minimum(1, (n - np.arange(n)) / (0.25 * SR))
    out /= np.max(np.abs(out)) / (10 ** (-9 / 20))
    pcm = (out * 32767).astype(np.int16)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    man = ROOT / "manifest.json"
    m = json.loads(man.read_text())
    m["sfx/spirit_whisper"] = {"bus": "SFX", "duration": dur, "loop": False}
    man.write_text(json.dumps(m, indent=2, sort_keys=True))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
