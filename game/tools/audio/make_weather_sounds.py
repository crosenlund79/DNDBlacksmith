#!/usr/bin/env python3
"""Canonical v1.6 §11 (seasons and weather, atmospheric only): two weather ambience loops, synthesised with the
make_audio.py toolkit (numpy only, deterministic, rendered circularly so the whole file is the loop):
    amb/rain_loop   steady rain: a soft broadband hiss, patter on leaves and roofs, the odd drip from the eaves
    amb/wind_loop   winter wind: a hollow, gusting moan with a dry hiss of blown snow
Output: 22050 Hz mono 16-bit WAV in game/assets/audio/amb/ plus their manifest.json entries.
Played on the "weather" ambience layer by scripts/world/season_dressing.gd; a creator may replace either file through
the usual audio override/inbox (scripts/autoload/audio.gd).
python3 make_weather_sounds.py [id substring]"""
import json
import sys
import wave

import numpy as np

import make_audio as A
from make_audio import N, tt, SR, TAU, ffilt, r_bp, r_lp, r_hp, smooth, add_circ, reverb, norm, rng_of, dbg, bubble


def rain(rng):
    L = N(30.0)
    hiss = ffilt(rng.standard_normal(L), lambda f: r_lp(f, 5200, 2) * r_hp(f, 300, 1), circular=True)
    hiss = hiss / np.std(hiss) * np.clip(1 + 0.18 * smooth(rng, L, 0.08), 0.6, None)
    body = ffilt(rng.standard_normal(L), lambda f: r_bp(f, 900, 0.6), circular=True)
    body = body / np.std(body)
    y = 0.10 * hiss + 0.05 * body
    ev = np.zeros(L)
    for _ in range(2200):                      # patter: tiny filtered ticks on leaves and roofs
        m = N(0.012)
        tick = rng.standard_normal(m) * np.exp(-tt(m) / 0.0025)
        tick = ffilt(tick, lambda f, fc=rng.uniform(1800, 5200): r_bp(f, fc, 1.6))
        add_circ(ev, 0.06 * rng.uniform(0.2, 1.0) * tick / (np.max(np.abs(tick)) + 1e-9), int(rng.integers(0, L)))
    for s0 in np.arange(0.7, 30.0, 1.9):      # a slow drip from the eaves
        add_circ(ev, 0.05 * bubble(rng.uniform(700, 1100), 0.03, rise=0.15), N(s0 + rng.uniform(0, 0.4)))
    ev = reverb(ev, 0.25, circular=True, t60=0.7)
    return y + ev


def wind(rng):
    L = N(30.0)
    t = tt(L)
    gust = np.clip(0.55 + 0.6 * smooth(rng, L, 0.06), 0.12, None)
    moan = ffilt(rng.standard_normal(L), lambda f: r_bp(f, 260, 2.2) + 0.5 * r_bp(f, 410, 3.0), circular=True)
    moan = moan / np.std(moan) * gust * (1 + 0.15 * np.sin(TAU * 0.2 * t))
    rush = ffilt(rng.standard_normal(L), lambda f: r_bp(f, 700, 0.6), circular=True)
    rush = rush / np.std(rush) * gust ** 1.5
    snowhiss = ffilt(rng.standard_normal(L), lambda f: r_hp(f, 3500, 2), circular=True)
    snowhiss = snowhiss / np.std(snowhiss) * np.clip(gust - 0.5, 0, None)
    y = 0.10 * moan + 0.06 * rush + 0.025 * snowhiss
    return reverb(y, 0.2, circular=True, t60=1.4)


def write(sid, y, peak_db=-8.0):
    y = norm(y, dbg(peak_db))
    path = A.OUT / (sid + ".wav")
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(y, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    man_path = A.OUT / "manifest.json"
    man = json.loads(man_path.read_text())
    man[sid] = {"bus": "Ambience", "duration": round(len(y) / SR, 2), "loop": True}
    man_path.write_text(json.dumps(dict(sorted(man.items())), indent=2))
    print(path, f"{len(y) / SR:.2f}s")


if __name__ == "__main__":
    for sid, fn in (("amb/rain_loop", rain), ("amb/wind_loop", wind)):
        if len(sys.argv) > 1 and not any(a in sid for a in sys.argv[1:]):
            continue
        write(sid, fn(rng_of(sid)))
