#!/usr/bin/env python3
"""Procedural audio generator for "Ember & Ash".

Everything is synthesised from scratch with numpy only (no samples, no scipy):
modal synthesis (metal, glass, wood), filtered noise, Karplus-Strong strings,
additive bells / brass / choir, formant-filtered voices, a synthetic
decaying-noise convolution reverb and a small rule-based composer for music.

Output: 22050 Hz mono 16-bit PCM WAV in game/assets/audio/<id>.wav plus
manifest.json. Loops (ids ending in _loop and all music) are rendered
*circularly* (events and filter/reverb tails wrap from the end into the head),
so the whole file is the loop and sample 0 follows the last sample seamlessly.

Usage:
    python3 make_audio.py                 # render everything, then verify
    python3 make_audio.py sfx/hammer_1    # render only matching ids (substring)
    python3 make_audio.py --verify        # only verify existing files + spectrograms
Deterministic: every sound uses a seed derived from its id.
"""
import json
import sys
import time
import wave
import zlib
from pathlib import Path

import numpy as np

SR = 22050
HERE = Path(__file__).resolve().parent
GAME = HERE.parent.parent
OUT = GAME / "assets" / "audio"
SPEC_OUT = HERE / "out"
TAU = 2 * np.pi

REGISTRY = {}
DEFAULT_PEAK = {"SFX": -1.0, "UI": -1.0, "Ambience": -8.0, "Music": -4.0}


def sound(sid, bus="SFX", peak=None):
    def deco(fn):
        REGISTRY[sid] = dict(fn=fn, bus=bus, loop=sid.endswith("_loop") or sid.startswith("music/"),
                             peak=DEFAULT_PEAK[bus] if peak is None else peak)
        return fn
    return deco


# ----------------------------------------------------------------------------
# basics
# ----------------------------------------------------------------------------
def N(sec):
    return max(1, int(round(sec * SR)))


def tt(n):
    return np.arange(n) / SR


def rng_of(sid, salt=0):
    return np.random.default_rng(zlib.crc32(f"{sid}|{salt}".encode()))


def mtof(m):
    return 440.0 * 2 ** ((np.asarray(m, float) - 69) / 12)


def dbg(d):
    return 10 ** (d / 20)


def env_pts(n, pts):
    """Piecewise-linear envelope from (time_s, value) points."""
    ts = np.array([p[0] for p in pts]) * SR
    vs = np.array([p[1] for p in pts], float)
    return np.interp(np.arange(n), ts, vs)


def env_exp(n, tau, attack=0.002):
    t = tt(n)
    e = np.exp(-t / tau)
    a = N(attack)
    if a > 1:
        e[:a] *= np.linspace(0, 1, a)
    return e


def add_at(buf, a, start):
    """Add `a` into `buf` at sample `start` (clipped to buffer)."""
    s = int(start)
    if s >= len(buf):
        return
    if s < 0:
        a = a[-s:]
        s = 0
    e = min(len(buf), s + len(a))
    buf[s:e] += a[:e - s]


def add_circ(buf, a, start):
    """Add `a` into a loop buffer, wrapping around the end (seamless loops)."""
    L = len(buf)
    s = int(start) % L
    i = 0
    while i < len(a):
        take = min(L - s, len(a) - i)
        buf[s:s + take] += a[i:i + take]
        i += take
        s = 0


def loopify(x, L, xf):
    """Fold the part of a linear render beyond L back over the head (equal-power crossfade)."""
    out = x[:L].copy()
    f = np.linspace(0, 1, xf)
    out[:xf] = out[:xf] * np.sin(f * np.pi / 2) + x[L:L + xf] * np.cos(f * np.pi / 2)
    return out


# ----------------------------------------------------------------------------
# filters (implemented in the frequency domain; zero-phase)
# ----------------------------------------------------------------------------
def r_lp(f, fc, order=2):
    return 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def r_hp(f, fc, order=2):
    return 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** (2 * order))


def r_bp(f, fc, q):
    """Analog 2nd-order band-pass magnitude (peak gain 1 at fc)."""
    num = f * fc / q
    return num / np.maximum(np.sqrt((fc ** 2 - f ** 2) ** 2 + num ** 2), 1e-12)


def r_peak(f, fc, q, gdb):
    """RBJ-style analog peaking EQ magnitude."""
    A = 10 ** (gdb / 40)
    s = 1j * f / fc
    return np.abs((s * s + s * A / q + 1) / (s * s + s / (A * q) + 1))


def ffilt(x, resp, circular=False, pad=None):
    x = np.asarray(x, float)
    n = len(x)
    if circular:
        xx = x
    else:
        p = pad if pad is not None else min(max(n // 2, 4096), SR)
        xx = np.concatenate([x, np.zeros(p)])
    X = np.fft.rfft(xx)
    f = np.fft.rfftfreq(len(xx), 1 / SR)
    return np.fft.irfft(X * resp(f), len(xx))[:n]


def lp(x, fc, order=2, **k):
    return ffilt(x, lambda f: r_lp(f, fc, order), **k)


def hp(x, fc, order=2, **k):
    return ffilt(x, lambda f: r_hp(f, fc, order), **k)


def bp(x, fc, q=2.0, **k):
    return ffilt(x, lambda f: r_bp(f, fc, q), **k)


def onepole_lp(x, fc):
    """True recursive one-pole low-pass (time domain) for short signals."""
    a = np.exp(-TAU * fc / SR)
    y = np.empty_like(x)
    s = 0.0
    for i, v in enumerate(x):
        s = (1 - a) * v + a * s
        y[i] = s
    return y


def tvfilt(x, gain_fn, nfft=1024, hop=256, circular=False):
    """Time-varying filter via STFT: gain_fn(t[frames,1], f[1,bins]) -> gains."""
    x = np.asarray(x, float)
    n = len(x)
    if circular:
        reps = int(np.ceil(nfft / n)) + 1
        big = np.tile(x, reps * 2 + 1)
        xx = big[reps * n - nfft: reps * n + n + nfft]
    else:
        xx = np.concatenate([np.zeros(nfft), x, np.zeros(nfft)])
    win = np.hanning(nfft + 1)[:-1]
    nfr = (len(xx) - nfft) // hop + 1
    idx = np.arange(nfft)[None, :] + hop * np.arange(nfr)[:, None]
    F = np.fft.rfft(xx[idx] * win, axis=1)
    tc = (hop * np.arange(nfr) + nfft / 2 - nfft) / SR
    if circular:
        tc = np.mod(tc, n / SR)
    f = np.fft.rfftfreq(nfft, 1 / SR)
    G = gain_fn(tc[:, None], f[None, :])
    yf = np.fft.irfft(F * G, nfft, axis=1) * win
    y = np.zeros(len(xx))
    for i in range(nfr):
        y[i * hop:i * hop + nfft] += yf[i]
    y /= 1.5  # periodic hann^2 overlap-add at 75 % overlap
    return y[nfft:nfft + n]


# ----------------------------------------------------------------------------
# noise & modulation
# ----------------------------------------------------------------------------
def white(rng, n):
    return rng.standard_normal(n)


def pink(rng, n, circular=False):
    return ffilt(rng.standard_normal(n), lambda f: 1 / np.sqrt(np.maximum(f, 20) / 20), circular=circular)


def smooth(rng, n, fc, circular=True):
    """Unit-variance smooth random curve (band-limited noise)."""
    x = lp(rng.standard_normal(n), fc, order=2, circular=circular)
    return x / (np.std(x) + 1e-12)


def norm(x, peak=1.0):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


# ----------------------------------------------------------------------------
# reverb: synthetic decaying-noise impulse response, FFT convolution
# ----------------------------------------------------------------------------
_IR_CACHE = {}


def make_ir(t60=1.2, damp=0.45, predelay=0.012, early=6, seed=7, length=None):
    key = (t60, damp, predelay, early, seed, length)
    if key in _IR_CACHE:
        return _IR_CACHE[key]
    rng = np.random.default_rng(seed)
    n = N(length or min(t60 * 1.1, 3.0))
    t = tt(n)
    w = rng.standard_normal(n)
    low = lp(w, 1400)
    high = w - low
    ir = low * 10 ** (-3 * t / t60) + 0.7 * high * 10 ** (-3 * t / (t60 * damp))
    ir *= np.minimum(1, t / 0.008)  # diffuse build-up
    for _ in range(early):
        d = N(rng.uniform(0.004, 0.045))
        ir[d] += rng.uniform(0.6, 1.6) * rng.choice([-1, 1]) * np.sqrt(n) * 0.04
    pd = N(predelay)
    ir = np.concatenate([np.zeros(pd), ir])
    ir /= np.sqrt(np.sum(ir ** 2))
    _IR_CACHE[key] = ir
    return ir


def reverb(x, wet=0.25, circular=False, **irk):
    ir = make_ir(**irk)
    n = len(x)
    if circular:
        h = np.zeros(n)
        m = min(len(ir), n)
        h[:m] = ir[:m]
        y = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(h), n)
    else:
        nf = 1 << int(np.ceil(np.log2(n + len(ir))))
        y = np.fft.irfft(np.fft.rfft(x, nf) * np.fft.rfft(ir, nf), nf)[:n]
    return x + wet * y


# ----------------------------------------------------------------------------
# synthesis primitives
# ----------------------------------------------------------------------------
def modal(n, modes):
    """Sum of exponentially decaying sinusoids: modes = [(freq, amp, tau)]."""
    t = tt(n)
    y = np.zeros(n)
    for f, a, tau in modes:
        if 20 < f < SR * 0.46:
            y += a * np.exp(-t / tau) * np.sin(TAU * f * t)
    return y


def phase_of(freq, n):
    if np.isscalar(freq):
        return TAU * freq * tt(n)
    return TAU * np.cumsum(freq) / SR


def saw_phase(ph, fmax, tilt=1.0, nh=None):
    """Band-limited sawtooth-like additive tone from a phase array."""
    nh = nh or max(1, int(SR * 0.45 / fmax))
    y = np.zeros(len(ph))
    for k in range(1, nh + 1):
        y += np.sin(k * ph) / k ** tilt
    return y


def ks_pluck(freq, dur, rng, t60=1.6, damp=0.2, bright=0.6, pos=0.18):
    """Karplus-Strong plucked string with fractional delay + loop smoothing.

    The feedback kernel is conv([s,1-2s,s],[1-w,w]) placed at delays M-1..M+2,
    giving total delay M+w = SR/freq; processed in vectorised blocks of M-1.
    """
    n = N(dur)
    D = SR / freq
    M = int(np.floor(D))
    w = D - M
    k = np.convolve([damp, 1 - 2 * damp, damp], [1 - w, w])
    g = 10 ** (-3 / (t60 * freq))
    L0 = M + 3
    e = rng.uniform(-1, 1, L0)
    sm = np.convolve(e, np.ones(4) / 4, "same")
    e = bright * e + (1 - bright) * sm
    p = max(1, int(pos * M))
    e = e - np.roll(e, p)
    e -= e.mean()
    y = np.zeros(n + L0)
    y[:L0] = e
    blk = max(1, M - 1)
    i = L0
    tot = len(y)
    while i < tot:
        j = min(i + blk, tot)
        y[i:j] = g * (k[0] * y[i - M + 1:j - M + 1] + k[1] * y[i - M:j - M]
                      + k[2] * y[i - M - 1:j - M - 1] + k[3] * y[i - M - 2:j - M - 2])
        i = j
    out = y[:n].copy()
    out[-N(0.01):] *= np.linspace(1, 0, N(0.01))
    return out


CHIME = [(0.5, 0.18, 1.6), (1.0, 1.0, 1.0), (2.0, 0.42, 0.55), (2.76, 0.3, 0.38),
         (4.07, 0.14, 0.24), (5.4, 0.1, 0.16), (6.8, 0.05, 0.1)]
HANDBELL = [(1.0, 1.0, 1.0), (2.0, 0.35, 0.6), (2.66, 0.5, 0.45), (3.01, 0.2, 0.4),
            (4.13, 0.25, 0.25), (5.42, 0.12, 0.18), (6.9, 0.06, 0.12)]


def bell(freq, dur, vel=1.0, decay=1.2, partials=CHIME, detune=0.0018, strike=0.15, rng=None):
    n = N(dur)
    t = tt(n)
    y = np.zeros(n)
    for r, a, dm in partials:
        f = freq * r
        if f > SR * 0.45:
            continue
        tau = decay * dm * (1.0 if f < 2000 else 2000 / f + 0.3)
        y += a * np.exp(-t / tau) * (np.sin(TAU * f * t) + 0.6 * np.sin(TAU * f * (1 + detune) * t + 1.0)) / 1.6
    if strike and rng is not None:
        s = hp(rng.standard_normal(n), min(freq * 2, 6000)) * np.exp(-t / 0.003)
        y += strike * s
    a = N(0.0015)
    y[:a] *= np.linspace(0, 1, a)
    return vel * y


def sparkle(freq, dur=0.25, vel=1.0):
    n = N(dur)
    t = tt(n)
    y = np.sin(TAU * freq * t) + 0.3 * np.sin(TAU * freq * 2.76 * t) * np.exp(-t / 0.03)
    y *= np.exp(-t / (dur * 0.3))
    a = N(0.002)
    y[:a] *= np.linspace(0, 1, a)
    return vel * y


def bubble(f0, tau, rise=0.12):
    n = N(tau * 7)
    t = tt(n)
    f = f0 * (1 + rise * t / tau)
    return np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / tau)


def click(rng, fc=2500, tau=0.003, q=1.5, dur=None):
    n = N(dur or tau * 8)
    return bp(rng.standard_normal(n) * np.exp(-tt(n) / tau), fc, q)


def creak(rng, dur, f_start, f_end, rough=0.35, res=((480, 6), (1100, 7), (2300, 6)), jit=0.08):
    """Stick-slip creak: irregular pulse train through wooden resonances."""
    n = N(dur)
    f = np.geomspace(f_start, f_end, n) * (1 + jit * smooth(rng, n, 6, circular=False))
    ph = np.cumsum(f) / SR
    hits = np.nonzero(np.diff(np.floor(ph)) > 0)[0] + 1
    imp = np.zeros(n)
    imp[hits] = 1 + rough * rng.standard_normal(len(hits))
    y = ffilt(imp, lambda fr: sum(r_bp(fr, c, q) for c, q in res))
    return y


VOWELS = {  # F1, F2, F3 (neutral-ish adult values)
    "a": (760, 1250, 2600), "o": (520, 900, 2500), "u": (360, 820, 2400),
    "e": (500, 1750, 2600), "i": (330, 2100, 2900), "@": (560, 1450, 2500),
    "m": (260, 1100, 2300),
}


def formant_resp(vowel, bw=(90, 110, 160), gains=(1.0, 0.55, 0.3)):
    F = VOWELS[vowel]
    return lambda f: sum(g * r_bp(f, Fi, Fi / b) for Fi, b, g in zip(F, bw, gains))


def glottal(f0, n, tilt=1.2):
    ph = phase_of(f0, n)
    fmax = np.max(f0) if not np.isscalar(f0) else f0
    return saw_phase(ph, fmax, tilt=tilt, nh=min(40, int(SR * 0.45 / fmax)))


def brass(freq, dur, vel, rng):
    n = N(dur)
    t = tt(n)
    p = np.interp(t, [0, 0.04, 0.12, 0.4, dur], [4.0, 1.6, 1.25, 1.7, 2.0])
    vib = 1 + 0.004 * np.sin(TAU * 5.2 * t) * np.clip((t - 0.25) / 0.3, 0, 1)
    ph = phase_of(freq * vib, n)
    nh = max(1, int(SR * 0.45 / freq))
    y = np.zeros(n)
    for k in range(1, nh + 1):
        y += np.exp(-p * np.log(k)) * np.sin(k * ph)
    env = env_pts(n, [(0, 0), (0.035, 1.0), (0.18, 0.78), (max(0.2, dur - 0.18), 0.7), (dur, 0)])
    return vel * y * env


def flute(freq, dur, vel, rng):
    n = N(dur)
    t = tt(n)
    vd = 0.0035 * np.clip((t - 0.25) / 0.35, 0, 1)
    vib = 1 + vd * np.sin(TAU * (4.8 + rng.uniform(-0.3, 0.3)) * t + rng.uniform(0, 6))
    ph = phase_of(freq * vib, n)
    y = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.07 * np.sin(3 * ph) + 0.025 * np.sin(4 * ph)
    w = rng.standard_normal(n)
    breath = 0.05 * bp(w, freq * 2, 3) + 0.012 * hp(w, 2500)
    chiff = 0.35 * bp(w, min(freq * 3, 7000), 2) * np.exp(-t / 0.018)
    rel = min(0.09, dur * 0.3)
    env = env_pts(n, [(0, 0), (0.06, 1.0), (0.2, 0.9), (max(0.21, dur - rel), 0.85), (dur, 0)])
    return vel * (y + breath + chiff) * env


def fiddle(freq, dur, vel, rng, vib_depth=0.005):
    n = N(dur)
    t = tt(n)
    vd = vib_depth * np.clip((t - 0.12) / 0.25, 0, 1)
    vib = 1 + vd * np.sin(TAU * 5.6 * t + rng.uniform(0, 6))
    ph = phase_of(freq * vib, n)
    y = saw_phase(ph, freq * 1.01, tilt=1.05)
    y += 0.04 * bp(rng.standard_normal(n), 3000, 1.0)
    rel = min(0.08, dur * 0.3)
    env = env_pts(n, [(0, 0), (0.05, 0.9), (0.12, 0.8), (max(0.13, dur - rel), 0.9), (dur, 0)])
    return vel * y * env


def frame_drum(rng, vel=1.0, kind="dum", dur=0.6):
    n = N(dur)
    t = tt(n)
    if kind == "dum":
        f = 62 + 40 * np.exp(-t / 0.03)
        y = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.22)
        y += 0.5 * lp(rng.standard_normal(n), 500) * np.exp(-t / 0.02)
        y += 0.25 * modal(n, [(170, 1, 0.12), (285, 0.6, 0.08)])
    else:  # tek (rim)
        y = 0.8 * bp(rng.standard_normal(n), 1800, 1.2) * np.exp(-t / 0.012)
        y += 0.4 * modal(n, [(410, 1, 0.05), (690, 0.6, 0.04)])
    return vel * y


def choir(freqs, n, rng, vowel="a", voices=3, spread=0.005):
    t = tt(n)
    y = np.zeros(n)
    for f in freqs:
        for _ in range(voices):
            det = 1 + rng.normal(0, spread)
            vib = 1 + 0.005 * np.sin(TAU * rng.uniform(4.5, 5.8) * t + rng.uniform(0, 6))
            y += saw_phase(phase_of(f * det * vib, n), f * 1.02, tilt=1.1, nh=min(30, int(SR * 0.45 / f)))
    y = ffilt(y, formant_resp(vowel, bw=(110, 130, 200), gains=(1, 0.7, 0.35)))
    y += 0.02 * ffilt(rng.standard_normal(n), formant_resp(vowel))
    return y / np.sqrt(len(freqs) * voices)


def anvil(rng, f0=780, dur=1.4, bright=1.0, ring=1.0, thud=0.6):
    n = N(dur)
    t = tt(n)
    base = [(1.0, 1.0, 0.95), (2.27, 0.75, 0.62), (2.94, 0.6, 0.5), (3.86, 0.5, 0.36),
            (4.63, 0.36, 0.3), (5.72, 0.26, 0.22), (6.95, 0.18, 0.17), (8.31, 0.12, 0.12)]
    modes = []
    for i, (r, a, tau) in enumerate(base):
        f = f0 * r * (1 + rng.normal(0, 0.004))
        amp = a * bright ** i * rng.uniform(0.75, 1.25)
        modes.append((f, amp, tau * ring))
        modes.append((f + rng.uniform(0.7, 2.2), amp * 0.5, tau * ring * 0.9))  # doublet beating
    y = 0.5 * modal(n, modes)
    y += 0.9 * hp(rng.standard_normal(n), 1800) * np.exp(-t / 0.0025)
    fth = 75 + 50 * np.exp(-t / 0.015)
    y += thud * (np.sin(TAU * np.cumsum(fth) / SR) * np.exp(-t / 0.05)
                 + 0.6 * lp(rng.standard_normal(n), 350) * np.exp(-t / 0.02))
    a = N(0.0008)
    y[:a] *= np.linspace(0, 1, a)
    return y


def crackles(rng, n, rate, amp=1.0, circular=False, fc=(1200, 5000)):
    buf = np.zeros(n)
    cnt = rng.poisson(rate * n / SR)
    for _ in range(cnt):
        s = rng.integers(0, n)
        tau = rng.uniform(0.0006, 0.004)
        c = click(rng, rng.uniform(*fc), tau, q=rng.uniform(0.8, 2.5))
        a = amp * rng.uniform(0.15, 1.0) ** 2
        (add_circ if circular else add_at)(buf, a * c, s)
    return buf


def fire_bed(rng, n, circular=True, dark=1.0):
    w = rng.standard_normal(n)
    roar = ffilt(w, lambda f: r_lp(f, 380 * dark, 2) * r_hp(f, 45, 2) * (1 + 1.5 * r_bp(f, 140, 1.5)), circular=circular)
    flutter = 1 + 0.35 * smooth(rng, n, 3.0, circular) + 0.2 * smooth(rng, n, 11.0, circular)
    roar = roar / np.std(roar) * np.clip(flutter, 0.2, None)
    mid = ffilt(rng.standard_normal(n), lambda f: r_bp(f, 900 * dark, 0.8), circular=circular)
    mid = mid / np.std(mid) * np.clip(1 + 0.5 * smooth(rng, n, 5.0, circular), 0, None)
    hiss = hp(rng.standard_normal(n), 3500, circular=circular)
    hiss /= np.std(hiss)
    return roar + 0.22 * mid + 0.05 * dark * hiss


# ----------------------------------------------------------------------------
# SFX
# ----------------------------------------------------------------------------
@sound("sfx/forge_loop")
def s_forge_loop(rng):
    n = N(5.0)
    y = fire_bed(rng, n)
    y += crackles(rng, n, 14, amp=5.0, circular=True)
    y += crackles(rng, n, 40, amp=1.4, circular=True, fc=(2500, 7000))
    # occasional coal shift: low tumble
    for s in rng.uniform(0, 5, 2):
        seg = N(0.35)
        tum = lp(rng.standard_normal(seg), 600) * env_pts(seg, [(0, 0), (0.03, 1), (0.35, 0)])
        tum += crackles(rng, seg, 60, amp=1.5, fc=(800, 2500))
        add_circ(y, 1.2 * tum, N(s))
    return reverb(y, 0.12, circular=True, t60=0.7)


@sound("sfx/bellows")
def s_bellows(rng):
    n = N(1.25)
    t = tt(n)
    w = rng.standard_normal(n)
    # air rush: band-pass whose centre rises as the pressure builds then falls
    cf = lambda tc: np.interp(tc, [0, 0.25, 0.7, 1.2], [350, 900, 700, 300])
    whoosh = tvfilt(w, lambda tc, f: r_bp(f, cf(tc), 0.9) + 0.3 * r_lp(f, 400))
    whoosh *= env_pts(n, [(0, 0), (0.18, 0.7), (0.35, 1.0), (0.75, 0.8), (1.1, 0.05), (1.25, 0)])
    # leather creak while the bellows is pressed
    cr = creak(rng, 0.42, 45, 110, rough=0.5, res=((650, 4), (1300, 5), (2600, 4)))
    cr *= env_pts(len(cr), [(0, 0), (0.05, 1), (0.35, 0.8), (0.42, 0)])
    y = whoosh + np.zeros(n)
    add_at(y, 0.9 * cr / np.max(np.abs(cr)) * np.max(np.abs(whoosh)), N(0.02))
    # small wooden knock of the handle at the end
    add_at(y, 0.35 * np.max(np.abs(whoosh)) * modal(N(0.15), [(210, 1, 0.03), (520, 0.5, 0.02)]), N(0.98))
    return reverb(y, 0.12, t60=0.6)


def _hammer(rng, f0, bright, ring, thud, delay_second=None):
    y = anvil(rng, f0, 1.5, bright, ring, thud)
    if delay_second:  # small rebound bounce
        b = 0.25 * anvil(rng, f0, 1.5 - delay_second, bright * 0.8, ring * 0.7, thud * 0.3)
        add_at(y, b, N(delay_second))
    return reverb(y, 0.2, t60=0.9, damp=0.4)


@sound("sfx/hammer_1")
def s_hammer_1(rng):
    return _hammer(rng, 780, 1.0, 1.0, 0.6)


@sound("sfx/hammer_2")
def s_hammer_2(rng):
    return _hammer(rng, 735, 0.92, 0.85, 0.75, delay_second=0.085)


@sound("sfx/hammer_3")
def s_hammer_3(rng):
    return _hammer(rng, 842, 1.05, 1.1, 0.5)


@sound("sfx/hammer_arcane")
def s_hammer_arcane(rng):
    n = N(2.4)
    t = tt(n)
    y = np.zeros(n)
    add_at(y, anvil(rng, 790, 1.4, 1.0, 1.1, 0.6), 0)
    sh = np.zeros(n)
    for m in [76, 83, 88, 91, 95, 100]:  # E5 B5 E6 G6 B6 E7
        f = mtof(m)
        trem = 1 + 0.5 * np.sin(TAU * rng.uniform(5, 9) * t + rng.uniform(0, 6))
        sh += np.sin(TAU * f * t * (1 + 0.003 * t)) * trem + 0.6 * np.sin(TAU * f * 1.004 * t)
    sh *= env_pts(n, [(0, 0), (0.05, 0.4), (0.35, 1.0), (1.2, 0.5), (2.4, 0)]) * 0.12
    y += sh
    for _ in range(18):
        s = rng.uniform(0.05, 1.6)
        add_at(y, 0.12 * sparkle(rng.uniform(3000, 7500), 0.2, rng.uniform(0.3, 1)), N(s))
    return reverb(y, 0.35, t60=1.8, damp=0.6)


@sound("sfx/quench")
def s_quench(rng):
    n = N(2.3)
    t = tt(n)
    w = rng.standard_normal(n)
    hiss = ffilt(w, lambda f: r_hp(f, 1600, 2) * (0.5 + r_bp(f, 4800, 1.0)))
    rough = np.clip(1 + 0.6 * smooth(rng, n, 35, circular=False), 0.1, None)
    env = np.minimum(1, t / 0.008) * (0.65 * np.exp(-t / 0.18) + 0.35 * np.exp(-t / 0.7))
    env *= np.clip((2.3 - t) / 0.4, 0, 1)
    y = 0.8 * hiss * rough * env
    y += lp(w, 300) * np.minimum(1, t / 0.02) * np.exp(-t / 0.5) * 0.9
    sz = np.zeros(n)
    sz[:N(0.6)] = crackles(rng, N(0.6), 90, amp=2.0, fc=(2000, 6000)) * np.linspace(1, 0.2, N(0.6))
    y += 0.4 * sz
    tb = 0.0
    while tb < 2.0:
        rate = 45 * np.exp(-tb / 0.6) + 5
        tb += rng.exponential(1 / rate)
        f0 = rng.uniform(350, 1300) * (1 + tb * 0.3)
        b = bubble(f0, rng.uniform(0.006, 0.02))
        add_at(y, rng.uniform(0.15, 0.5) * np.exp(-tb / 1.2) * b, N(tb))
    return reverb(y, 0.15, t60=0.7)


@sound("sfx/grind")
def s_grind(rng):
    n = N(1.5)
    t = tt(n)
    w = rng.standard_normal(n)
    rasp = ffilt(w, lambda f: r_bp(f, 2400, 1.2) + 0.7 * r_bp(f, 5200, 2) + 0.4 * r_bp(f, 900, 2))
    rot = 1 + 0.35 * np.sin(TAU * 7.5 * t) + 0.25 * smooth(rng, n, 150, circular=False)
    sq = 1 + 0.3 * np.sign(np.sin(TAU * 120 * t + 0.5 * smooth(rng, n, 30, False)))
    y = rasp * np.clip(rot, 0, None) * sq
    for _ in range(26):  # metallic sparks ringing
        s = rng.uniform(0.05, 1.2)
        m = modal(N(0.12), [(rng.uniform(3500, 8000), 1, 0.02), (rng.uniform(5000, 9500), 0.5, 0.012)])
        add_at(y, 0.6 * m, N(s))
    hum = 0.25 * np.sin(TAU * 110 * t) * (1 + 0.3 * np.sin(TAU * 7.5 * t))
    y = (y + hum) * env_pts(n, [(0, 0), (0.08, 1), (1.15, 0.9), (1.5, 0)])
    return reverb(y, 0.15, t60=0.7)


@sound("sfx/grind_soft")
def s_grind_soft(rng):
    n = N(1.3)
    t = tt(n)
    y = np.zeros(n)
    add_at(y, 0.5 * modal(N(0.3), [(420, 1, 0.05), (910, 0.5, 0.03), (1570, 0.3, 0.02)]), 0)
    for s0, d in [(0.08, 0.5), (0.62, 0.55)]:
        m = N(d)
        g = ffilt(rng.standard_normal(m), lambda f: r_bp(f, 1300, 0.9) + 0.4 * r_bp(f, 3200, 2))
        g *= np.clip(1 + 0.7 * smooth(rng, m, 25, False), 0, None)
        g += crackles(rng, m, 120, amp=2.5, fc=(1500, 4500))
        g *= np.sin(np.pi * np.linspace(0, 1, m)) ** 1.5
        add_at(y, 0.6 * g, N(s0))
    return reverb(y, 0.12, t60=0.5)


@sound("sfx/chisel")
def s_chisel(rng):
    n = N(1.0)
    y = np.zeros(n)
    for i, s in enumerate([0.0, 0.28, 0.52]):
        m = N(0.35)
        tt_ = tt(m)
        tick = modal(m, [(rng.uniform(2300, 2700), 1, 0.03), (rng.uniform(4100, 4600), 0.6, 0.02),
                         (rng.uniform(6200, 6800), 0.3, 0.012)])
        crunch = bp(rng.standard_normal(m), 1800, 0.8) * np.exp(-tt_ / 0.03)
        thud = lp(rng.standard_normal(m), 400) * np.exp(-tt_ / 0.02)
        hit = 0.6 * tick + 0.8 * crunch + 0.5 * thud + crackles(rng, m, 50, 0.8, fc=(2500, 6000)) * np.exp(-tt_ / 0.12)
        add_at(y, (1.0 - 0.15 * i) * hit, N(s))
    return reverb(y, 0.15, t60=0.6)


@sound("sfx/bubble")
def s_bubble(rng):
    n = N(1.3)
    t = tt(n)
    y = 0.15 * lp(rng.standard_normal(n), 250) * env_pts(n, [(0, 0), (0.1, 1), (1.1, 1), (1.3, 0)])
    for s in sorted(rng.uniform(0, 1.0, 8)):
        f0 = rng.uniform(140, 380)
        add_at(y, rng.uniform(0.4, 1.0) * bubble(f0, rng.uniform(0.02, 0.05), 0.25), N(s))
        add_at(y, 0.3 * lp(rng.standard_normal(N(0.05)), 900) * np.exp(-tt(N(0.05)) / 0.01), N(s + 0.03))
    return reverb(y, 0.2, t60=0.6)


@sound("sfx/glass")
def s_glass(rng):
    n = N(1.1)
    y = np.zeros(n)
    for s, f0, v in [(0.0, 2050, 1.0), (0.17, 2380, 0.7)]:
        m = N(0.9)
        g = modal(m, [(f0, 1, 0.35), (f0 * 2.32, 0.55, 0.2), (f0 * 4.25, 0.25, 0.08), (f0 * 1.003, 0.6, 0.32)])
        g += 0.5 * hp(rng.standard_normal(m), 4000) * np.exp(-tt(m) / 0.0015)
        add_at(y, v * g, N(s))
    return reverb(y, 0.15, t60=0.6)


@sound("sfx/water")
def s_water(rng):
    n = N(1.1)
    w = rng.standard_normal(n)
    cf = lambda tc: np.interp(tc, [0, 0.2, 0.5, 1.1], [350, 1200, 600, 400])
    y = tvfilt(w, lambda tc, f: r_bp(f, cf(tc), 1.4) + 0.3 * r_bp(f, 2 * cf(tc), 3))
    y *= env_pts(n, [(0, 0), (0.12, 1), (0.4, 0.6), (0.9, 0.15), (1.1, 0)])
    y *= np.clip(1 + 0.6 * smooth(rng, n, 18, False), 0, None)
    for s in rng.uniform(0.1, 0.9, 9):
        add_at(y, rng.uniform(0.2, 0.6) * bubble(rng.uniform(500, 1600), rng.uniform(0.005, 0.015), 0.4), N(s))
    return reverb(y, 0.15, t60=0.6)


@sound("sfx/rune_hum")
def s_rune_hum(rng):
    n = N(1.6)
    t = tt(n)
    f = 110.0
    y = (np.sin(TAU * f * t) + 0.5 * np.sin(TAU * f * 1.006 * t) + 0.35 * np.sin(TAU * 2 * f * t)
         + 0.2 * np.sin(TAU * 3.01 * f * t))
    glass = sum(a * np.sin(TAU * f * r * t + p) for r, a, p in [(8.0, 0.09, 0), (8.03, 0.07, 1), (12.1, 0.05, 2),
                                                               (16.2, 0.03, 0.5)])
    y += glass * (1 + 0.5 * np.sin(TAU * 3.5 * t))
    y *= env_pts(n, [(0, 0), (0.55, 1), (1.0, 0.85), (1.6, 0)])
    return reverb(y, 0.3, t60=1.4)


@sound("sfx/arcane")
def s_arcane(rng):
    n = N(1.6)
    t = tt(n)
    glide = 2 ** (t / 1.6)  # rises an octave
    y = np.zeros(n)
    for m in [67, 70, 74, 77, 79, 82]:  # G minor-ish violet cluster
        f = mtof(m) * glide
        ph = TAU * np.cumsum(f * (1 + 0.004 * np.sin(TAU * rng.uniform(5, 8) * t))) / SR
        y += (np.sin(ph) + 0.25 * np.sin(2 * ph)) * (1 + 0.6 * np.sin(TAU * rng.uniform(6, 12) * t + rng.uniform(0, 6)))
    y *= 0.15 * env_pts(n, [(0, 0), (0.5, 0.5), (1.2, 1), (1.6, 0)])
    w = rng.standard_normal(n)
    air = tvfilt(w, lambda tc, f: r_bp(f, 1500 * 2 ** (tc / 0.6), 2))
    y += 0.2 * air * env_pts(n, [(0, 0), (1.1, 1), (1.6, 0)])
    for _ in range(40):
        s = 1.6 * rng.uniform(0, 1) ** 0.6
        add_at(y, 0.1 * (s / 1.6) * sparkle(rng.uniform(2500, 8000), 0.15), N(s))
    return reverb(y, 0.4, t60=1.6, damp=0.6)


@sound("sfx/stitch")
def s_stitch(rng):
    n = N(1.0)
    y = np.zeros(n)
    for s, d in [(0.0, 0.32), (0.45, 0.4)]:
        add_at(y, 0.5 * click(rng, 3500, 0.002), N(s))
        m = N(d)
        pull = ffilt(rng.standard_normal(m), lambda f: r_bp(f, 2800, 1.5) + 0.5 * r_bp(f, 5500, 2))
        slip = creak(rng, d, 120, 260, rough=0.6, res=((1800, 4), (3500, 4)))
        pull = pull / np.std(pull) * 0.3 + slip / (np.std(slip) + 1e-9) * 0.25
        pull *= env_pts(m, [(0, 0), (0.06, 1), (d * 0.7, 0.8), (d, 0)])
        add_at(y, pull, N(s + 0.05))
    return reverb(y, 0.1, t60=0.4)


@sound("sfx/spin")
def s_spin(rng):
    n = N(1.6)
    t = tt(n)
    whir = ffilt(rng.standard_normal(n), lambda f: r_bp(f, 520, 1.5) + 0.4 * r_bp(f, 1400, 3))
    whir *= 1 + 0.5 * np.sin(TAU * 5.0 * t)
    y = 0.4 * whir / np.std(whir)
    for k in range(int(1.6 * 5)):  # spokes ticking past the guide
        add_at(y, 0.5 * click(rng, 2200, 0.002), N(k / 5.0 + rng.uniform(0, 0.01)))
    for s in [0.1, 0.78, 1.45]:  # treadle knocks
        add_at(y, 0.9 * modal(N(0.2), [(180, 1, 0.04), (430, 0.6, 0.03), (980, 0.3, 0.015)]), N(s))
    cr = creak(rng, 0.5, 70, 50, rough=0.4)
    add_at(y, 0.4 * cr / np.max(np.abs(cr)), N(0.4))
    y *= env_pts(n, [(0, 0), (0.1, 1), (1.4, 1), (1.6, 0)])
    return reverb(y, 0.15, t60=0.6)


@sound("sfx/check_start")
def s_check_start(rng):
    n = N(0.65)
    t = tt(n)
    w = rng.standard_normal(n)
    sw = tvfilt(w, lambda tc, f: r_bp(f, 600 * 2 ** (tc * 4.5), 2.5))
    y = 0.5 * sw * env_pts(n, [(0, 0), (0.45, 1), (0.55, 0.3), (0.65, 0)])
    add_at(y, 0.8 * modal(N(0.12), [(1650, 1, 0.012), (3900, 0.4, 0.006)]), 0)
    y += 0.08 * np.sin(TAU * 220 * t) * env_pts(n, [(0, 0), (0.45, 1), (0.65, 0)])
    return reverb(y, 0.15, t60=0.6)


@sound("sfx/check_tick", peak=-5)
def s_check_tick(rng):
    y = modal(N(0.08), [(2400, 1, 0.006), (5200, 0.4, 0.003)])
    y += 0.3 * click(rng, 3000, 0.001, dur=0.08)
    return y


@sound("sfx/check_poor")
def s_check_poor(rng):
    n = N(0.5)
    t = tt(n)
    f = 70 + 70 * np.exp(-t / 0.04)
    y = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.09)
    y += 0.5 * modal(n, [(240, 1, 0.05), (390, 0.6, 0.035)])
    y += 0.4 * lp(rng.standard_normal(n), 500) * np.exp(-t / 0.02)
    return reverb(y, 0.12, t60=0.5)


@sound("sfx/check_good")
def s_check_good(rng):
    y = bell(mtof(81), 1.0, 1.0, decay=0.7, rng=rng, strike=0.08)
    return reverb(y, 0.2, t60=1.0)


@sound("sfx/check_great")
def s_check_great(rng):
    n = N(1.3)
    y = np.zeros(n)
    add_at(y, bell(mtof(81), 1.2, 0.8, decay=0.8, rng=rng), 0)
    add_at(y, bell(mtof(88), 1.15, 0.9, decay=0.8, rng=rng), N(0.07))
    for _ in range(10):
        add_at(y, 0.15 * sparkle(rng.uniform(4000, 8000), 0.18, rng.uniform(0.4, 1)), N(rng.uniform(0.08, 0.6)))
    return reverb(y, 0.25, t60=1.2, damp=0.6)


@sound("sfx/check_perfect")
def s_check_perfect(rng):
    n = N(1.9)
    y = np.zeros(n)
    add_at(y, 0.5 * bell(mtof(62), 1.9, 1.0, decay=1.4, rng=rng), 0)
    for i, m in enumerate([74, 78, 81, 86]):
        add_at(y, bell(mtof(m), 1.8, 0.85 - 0.08 * i, decay=1.1, rng=rng), N(0.03 * i))
    add_at(y, 0.45 * bell(mtof(90), 1.5, 1.0, decay=0.8, rng=rng), N(0.16))
    for _ in range(22):
        s = rng.uniform(0.08, 1.0)
        f = mtof(rng.choice([98, 102, 105, 110, 114]))
        add_at(y, 0.13 * sparkle(f, 0.25, rng.uniform(0.3, 1) * np.exp(-s)), N(s))
    return reverb(y, 0.3, t60=1.6, damp=0.6)


def bone_click(rng, f0=None, v=1.0):
    f0 = f0 or rng.uniform(1700, 3200)
    m = N(0.06)
    y = modal(m, [(f0, 1, 0.012), (f0 * 1.7, 0.6, 0.008), (f0 * 2.9, 0.3, 0.005)])
    y += 0.4 * hp(rng.standard_normal(m), 3000) * np.exp(-tt(m) / 0.001)
    return v * y


@sound("sfx/dice_roll")
def s_dice_roll(rng):
    n = N(1.25)
    y = np.zeros(n)
    cup = np.zeros(n)
    s = 0.0
    while s < 0.6:  # shaken in a cup: bursts at ~7 Hz
        for _ in range(rng.integers(1, 4)):
            add_at(cup, bone_click(rng, v=rng.uniform(0.3, 1)), N(s + rng.uniform(0, 0.03)))
        s += rng.uniform(0.11, 0.16)
    cup = ffilt(cup, lambda f: 0.4 + 1.6 * r_bp(f, 650, 4) + 0.8 * r_bp(f, 1500, 5))
    y += cup
    tumble = [0.66, 0.75, 0.83, 0.9, 0.95, 0.995, 1.03, 1.06]
    for i, s in enumerate(tumble):  # spilling onto a wooden table, bouncing
        v = 1.0 - i * 0.09
        add_at(y, bone_click(rng, v=v), N(s))
        add_at(y, 0.6 * v * modal(N(0.12), [(190, 1, 0.03), (420, 0.6, 0.02)]), N(s))
        if rng.uniform() < 0.5:
            add_at(y, bone_click(rng, v=v * 0.5), N(s + 0.02))
    return reverb(y, 0.12, t60=0.5)


@sound("sfx/dice_land")
def s_dice_land(rng):
    n = N(0.4)
    y = np.zeros(n)
    add_at(y, bone_click(rng, 2300, 1.0), 0)
    add_at(y, 0.8 * modal(N(0.2), [(170, 1, 0.04), (390, 0.7, 0.03), (850, 0.3, 0.015)]), 0)
    add_at(y, bone_click(rng, 2700, 0.45), N(0.045))
    return reverb(y, 0.15, t60=0.5)


@sound("sfx/search_tick", peak=-6)
def s_search_tick(rng):
    n = N(0.16)
    y = 0.6 * ffilt(rng.standard_normal(n), lambda f: r_bp(f, 1800, 0.8)) * env_pts(n, [(0, 0), (0.02, 1), (0.16, 0)])
    y = y / np.max(np.abs(y))
    add_at(y, 0.6 * click(rng, 2600, 0.0015), N(0.03))
    return y


@sound("sfx/reveal_common")
def s_reveal_common(rng):
    y = ks_pluck(mtof(67), 0.7, rng, t60=0.9, damp=0.15, bright=0.7)
    y = ffilt(y, lambda f: r_peak(f, 250, 1, 4) * r_hp(f, 90) * r_lp(f, 5000))
    return reverb(y, 0.2, t60=0.8)


@sound("sfx/reveal_magic")
def s_reveal_magic(rng):
    n = N(1.1)
    y = np.zeros(n)
    add_at(y, bell(mtof(76), 1.0, 0.9, decay=0.7, rng=rng), 0)
    add_at(y, bell(mtof(83), 0.95, 1.0, decay=0.8, rng=rng), N(0.13))
    t = tt(n)
    y *= 1 + 0.15 * np.sin(TAU * 6 * t)  # cool shimmer
    return reverb(y, 0.3, t60=1.3, damp=0.6)


@sound("sfx/reveal_rare")
def s_reveal_rare(rng):
    n = N(1.35)
    y = np.zeros(n)
    for i, m in enumerate([84, 88, 91]):
        add_at(y, bell(mtof(m), 1.2, 0.8 + 0.1 * i, decay=0.8, rng=rng), N(0.1 * i))
        add_at(y, 0.4 * ks_pluck(mtof(m - 12), 0.8, rng, t60=0.8, damp=0.1), N(0.1 * i))
    for _ in range(8):
        add_at(y, 0.12 * sparkle(rng.uniform(5000, 8000), 0.2), N(rng.uniform(0.2, 0.7)))
    return reverb(y, 0.3, t60=1.4, damp=0.6)


@sound("sfx/legendary_drop")
def s_legendary_drop(rng):
    n = N(2.7)
    t = tt(n)
    y = np.zeros(n)
    # 1) deep impact / boom
    fb = 36 + 26 * np.exp(-t / 0.12)
    boom = np.sin(TAU * np.cumsum(fb) / SR) * np.exp(-t / 0.55) * np.minimum(1, t / 0.004)
    boom += 0.8 * lp(rng.standard_normal(n), 160) * np.exp(-t / 0.12)
    boom += 0.5 * hp(rng.standard_normal(n), 1200) * np.exp(-t / 0.012)
    boom += 0.3 * anvil(rng, 260, 2.7, 0.9, 1.6, 0.0)
    y += 1.0 * boom
    # riser into the impact tail
    w = rng.standard_normal(n)
    rise = tvfilt(w, lambda tc, f: r_bp(f, 400 * 2 ** (np.clip(tc, 0, 0.9) * 4.5), 3))
    y += 0.25 * rise * env_pts(n, [(0, 0), (0.1, 0.3), (0.8, 1), (1.0, 0)])
    # 2) rising golden arpeggio: bells + plucked strings (D lydian-major)
    arp = [62, 66, 69, 74, 76, 78, 81, 86, 88, 90]
    tnote = 0.12
    for i, m in enumerate(arp):
        v = 0.45 + 0.05 * i
        add_at(y, 0.55 * bell(mtof(m), 2.6 - tnote, v, decay=1.3, rng=rng), N(tnote))
        if m <= 81:
            p = ks_pluck(mtof(m - 12 if m > 74 else m), 1.6, rng, t60=1.4, damp=0.12, bright=0.8)
            add_at(y, 0.55 * v * p, N(tnote))
        tnote += 0.075 - 0.002 * i
    # final golden chord
    tc0 = tnote + 0.02
    for m in [74, 78, 81, 86]:
        add_at(y, 0.35 * bell(mtof(m), 2.7 - tc0, 0.9, decay=1.6, rng=rng), N(tc0))
    # 3) choir-like pad swell (D major, "ah")
    cn = N(2.55)
    pad = choir(mtof([50, 57, 62, 66, 69, 74]), cn, rng, "a")
    pad *= env_pts(cn, [(0, 0), (0.25, 0.1), (0.95, 1.0), (1.6, 0.85), (2.55, 0)])
    add_at(y, 0.55 * pad / np.max(np.abs(pad)), N(0.1))
    # 4) glittering shimmer tail
    sh = np.zeros(n)
    for m in [98, 105, 110]:
        f = mtof(m)
        sh += np.sin(TAU * f * t) * (1 + np.sin(TAU * rng.uniform(7, 11) * t)) * 0.5
    sh *= env_pts(n, [(0, 0), (0.6, 0), (1.1, 1), (2.7, 0)])
    y += 0.06 * sh
    for _ in range(70):
        s = rng.normal(1.0, 0.45)
        if 0.45 < s < 2.5:
            f = mtof(rng.choice([93, 95, 98, 100, 102, 105, 107, 110])) * rng.choice([1, 1, 1.5])
            add_at(y, 0.11 * rng.uniform(0.3, 1) * sparkle(min(f, 9500), 0.3), N(s))
    y = reverb(y, 0.35, t60=2.2, damp=0.6)
    y *= np.clip((2.7 - t) / 0.35, 0, 1) ** 1.5
    return y


@sound("sfx/bag_open")
def s_bag_open(rng):
    n = N(0.85)
    y = np.zeros(n)
    m = N(0.22)
    flap = ffilt(rng.standard_normal(m), lambda f: r_lp(f, 1200) * r_hp(f, 120)) * env_pts(m, [(0, 0), (0.05, 1), (0.22, 0)])
    add_at(y, flap / np.max(np.abs(flap)), N(0.18))
    cr = creak(rng, 0.25, 60, 140, rough=0.5, res=((700, 4), (1500, 5)))
    add_at(y, 0.4 * cr / np.max(np.abs(cr)) * env_pts(len(cr), [(0, 0), (0.05, 1), (0.25, 0)]), N(0.0))
    for s, f0 in [(0.03, 3100), (0.1, 3500), (0.42, 2900)]:  # buckle jingles
        b = modal(N(0.2), [(f0, 1, 0.04), (f0 * 1.53, 0.7, 0.03), (f0 * 2.4, 0.4, 0.02)])
        add_at(y, 0.45 * b, N(s))
    return reverb(y, 0.12, t60=0.5)


@sound("sfx/coins")
def s_coins(rng):
    n = N(0.95)
    y = np.zeros(n)
    s = 0.0
    for i in range(10):
        f0 = rng.uniform(2600, 4200)
        m = N(0.35)
        c = modal(m, [(f0, 1, rng.uniform(0.08, 0.2)), (f0 * 1.47, 0.7, 0.07), (f0 * 2.09, 0.5, 0.05),
                      (f0 * 2.56, 0.3, 0.04)])
        c += 0.4 * hp(rng.standard_normal(m), 4000) * np.exp(-tt(m) / 0.0012)
        add_at(y, rng.uniform(0.4, 1.0) * (1 - i * 0.05) * c, N(s))
        s += rng.exponential(0.06) + 0.012
    return reverb(y, 0.15, t60=0.5)


@sound("sfx/ui_click", bus="UI", peak=-3)
def s_ui_click(rng):
    m = N(0.07)
    y = modal(m, [(1450, 1, 0.008), (3100, 0.35, 0.004), (420, 0.5, 0.01)])
    y += 0.3 * click(rng, 2500, 0.0015, dur=0.07)
    return y


@sound("sfx/ui_hover", bus="UI", peak=-14)
def s_ui_hover(rng):
    m = N(0.06)
    y = modal(m, [(2600, 1, 0.006), (5100, 0.2, 0.003)])
    y += 0.4 * ffilt(rng.standard_normal(m), lambda f: r_bp(f, 3000, 1)) * np.exp(-tt(m) / 0.006)
    return y


@sound("sfx/page_turn", bus="UI")
def s_page_turn(rng):
    n = N(0.6)
    w = rng.standard_normal(n)
    cf = lambda tc: np.interp(tc, [0, 0.25, 0.6], [1500, 3500, 2000])
    y = tvfilt(w, lambda tc, f: r_bp(f, cf(tc), 0.8) + 0.3 * r_hp(f, 5000))
    y *= env_pts(n, [(0, 0), (0.1, 0.4), (0.28, 1), (0.42, 0.3), (0.6, 0)])
    y = y / np.std(y)
    y += crackles(rng, n, 70, amp=4, fc=(2000, 6000)) * env_pts(n, [(0, 0.3), (0.3, 1), (0.6, 0.2)])
    y += 2.0 * lp(rng.standard_normal(n), 300) * env_pts(n, [(0.3, 0), (0.36, 1), (0.5, 0)])
    return reverb(y, 0.1, t60=0.4)


@sound("sfx/door")
def s_door(rng):
    n = N(1.7)
    y = np.zeros(n)
    cr = creak(rng, 1.05, 260, 140, rough=0.3, res=((420, 6), (950, 8), (1900, 6), (3100, 5)))
    cr *= env_pts(len(cr), [(0, 0), (0.08, 0.7), (0.4, 1), (0.8, 0.6), (1.05, 0)])
    add_at(y, 0.5 * cr / np.max(np.abs(cr)), 0)
    m = N(0.6)
    th = modal(m, [(88, 1, 0.12), (176, 0.6, 0.08), (265, 0.5, 0.06), (520, 0.3, 0.04)])
    th += 0.8 * lp(rng.standard_normal(m), 600) * np.exp(-tt(m) / 0.025)
    add_at(y, th / np.max(np.abs(th)), N(1.12))
    add_at(y, 0.25 * modal(N(0.15), [(2600, 1, 0.02), (3900, 0.5, 0.015)]), N(1.15))  # latch
    return reverb(y, 0.2, t60=0.8)


def _footstep(rng):
    n = N(0.32)
    y = np.zeros(n)
    for s, v in [(0.0, 1.0), (0.045, 0.6)]:
        m = N(0.2)
        tm = tt(m)
        th = lp(rng.standard_normal(m), 260) * np.exp(-tm / 0.03)
        grit = ffilt(rng.standard_normal(m), lambda f: r_bp(f, 1500, 0.7)) * np.exp(-tm / 0.04)
        grit += crackles(rng, m, 150, amp=1.2, fc=(1500, 5000)) * np.exp(-tm / 0.06)
        add_at(y, v * (th / np.max(np.abs(th)) + 0.5 * grit / np.max(np.abs(grit))), N(s))
    return reverb(y, 0.1, t60=0.4)


@sound("sfx/footstep_1", peak=-6)
def s_footstep_1(rng):
    return _footstep(rng)


@sound("sfx/footstep_2", peak=-6)
def s_footstep_2(rng):
    return _footstep(rng)


@sound("sfx/npc_greet")
def s_npc_greet(rng):
    n = N(0.5)
    t = tt(n)
    f0 = np.interp(t, [0, 0.25, 0.42, 0.5], [175, 168, 225, 235]) * (1 + 0.004 * np.sin(TAU * 5.5 * t))
    src = glottal(f0, n, tilt=1.4)
    breath = rng.standard_normal(n)
    # "h" into a hummed "m" that lifts in pitch (questioning "hm?")
    h = ffilt(breath, formant_resp("@")) * env_pts(n, [(0, 0), (0.02, 1), (0.08, 0.3), (0.12, 0)])
    voiced_m = ffilt(src, lambda f: formant_resp("m", bw=(60, 200, 300), gains=(1, 0.15, 0.06))(f) * r_lp(f, 1600, 2))
    voiced_o = ffilt(src, formant_resp("@"))
    mix = np.interp(t, [0, 0.07, 0.14, 0.5], [1, 0.6, 0, 0])
    y = (voiced_o * mix * 0.6 + voiced_m * (1 - mix)) * env_pts(n, [(0, 0), (0.06, 0.6), (0.15, 1), (0.38, 0.9), (0.5, 0)])
    y = y / np.max(np.abs(y)) + 0.25 * h / np.max(np.abs(h))
    return reverb(y, 0.12, t60=0.4)


@sound("sfx/eggs_splat")
def s_eggs_splat(rng):
    n = N(0.6)
    t = tt(n)
    y = np.zeros(n)
    for s in [0.0, 0.006, 0.015]:  # shell cracks
        add_at(y, 0.6 * click(rng, rng.uniform(3000, 5000), 0.0012, 1.0), N(s))
    w = rng.standard_normal(n)
    cf = lambda tc: np.interp(tc, [0, 0.05, 0.3], [2200, 900, 400])
    sp = tvfilt(w, lambda tc, f: r_bp(f, cf(tc), 1.2), nfft=512, hop=128)
    y += 1.2 * sp / np.std(sp) * 0.3 * np.minimum(1, t / 0.004) * np.exp(-t / 0.08)
    for s in rng.uniform(0.05, 0.45, 5):
        add_at(y, 0.25 * bubble(rng.uniform(600, 1500), 0.008, 0.6), N(s))
    return reverb(y, 0.1, t60=0.4)


@sound("sfx/level_up")
def s_level_up(rng):
    n = N(1.6)
    y = np.zeros(n)
    # triplet pickup then a held C major chord
    for s, m, d in [(0.0, 67, 0.15), (0.13, 72, 0.15), (0.26, 76, 0.15)]:
        add_at(y, 0.55 * brass(mtof(m), d + 0.05, 0.8, rng), N(s))
    for m, v in [(48, 0.5), (60, 0.55), (67, 0.6), (72, 0.75), (76, 0.65), (79, 0.6)]:
        add_at(y, 0.4 * brass(mtof(m), 1.2, v, rng), N(0.39 + rng.uniform(0, 0.012)))
    y = ffilt(y, lambda f: r_lp(f, 3800, 2) * r_peak(f, 900, 0.8, 3))
    add_at(y, 0.4 * np.max(np.abs(y)) * frame_drum(rng, 1.0, "dum", 0.7), N(0.39))
    return reverb(y, 0.3, t60=1.4)


@sound("sfx/door_bell")
def s_door_bell(rng):
    n = N(1.6)
    y = np.zeros(n)
    for s, v in [(0.0, 1.0), (0.12, 0.6), (0.27, 0.4), (0.45, 0.2)]:
        add_at(y, bell(1320 * rng.uniform(0.998, 1.002), 1.6 - s, v, decay=0.7, partials=HANDBELL,
                       rng=rng, strike=0.2), N(s))
    return reverb(y, 0.2, t60=0.8)


@sound("sfx/error", bus="UI")
def s_error(rng):
    n = N(0.42)
    t = tt(n)
    sq = saw_phase(TAU * 110 * t, 110, tilt=1.0) + 0.6 * saw_phase(TAU * 116.5 * t, 116.5, tilt=1.0)
    sq = lp(sq, 700)
    env = env_pts(n, [(0, 0), (0.01, 1), (0.14, 0.8), (0.16, 0), (0.2, 0), (0.21, 1), (0.36, 0.7), (0.42, 0)])
    return reverb(sq * env, 0.1, t60=0.4)


@sound("sfx/hire")
def s_hire(rng):
    n = N(1.25)
    y = np.zeros(n)
    s = 0.0
    while s < 0.65:  # quill strokes
        d = rng.uniform(0.06, 0.14)
        m = N(d)
        st = ffilt(rng.standard_normal(m), lambda f: r_bp(f, rng.uniform(3500, 5500), 1.2))
        st *= np.clip(1 + 0.8 * np.sin(TAU * rng.uniform(40, 80) * tt(m)), 0, None)
        st *= np.sin(np.pi * np.linspace(0, 1, m))
        add_at(y, 0.35 * st / np.std(st) * 0.4, N(s))
        s += d + rng.uniform(0.01, 0.05)
    m = N(0.4)
    tm = tt(m)
    stamp = 1.0 * lp(rng.standard_normal(m), 400) * np.exp(-tm / 0.03)
    stamp += 0.8 * modal(m, [(140, 1, 0.06), (330, 0.6, 0.04), (760, 0.3, 0.02)])
    stamp += 0.4 * bp(rng.standard_normal(m), 2500, 1) * np.exp(-tm / 0.01)
    add_at(y, stamp / np.max(np.abs(stamp)), N(0.82))
    return reverb(y, 0.15, t60=0.6)


# ----------------------------------------------------------------------------
# AMBIENCE (circular render => seamless)
# ----------------------------------------------------------------------------
@sound("amb/workshop_loop", bus="Ambience")
def a_workshop(rng):
    L = N(24.0)
    y = 0.5 * lp(fire_bed(rng, L, dark=0.8), 1500, circular=True)
    y += crackles(rng, L, 5, amp=1.5, circular=True, fc=(1000, 3500))
    ev = np.zeros(L)
    for s0 in [3.0, 15.5]:  # distant hammering bouts
        for k in range(rng.integers(3, 6)):
            a = anvil(rng, rng.uniform(740, 820), 1.2, 0.7, 0.8, 0.3)
            add_circ(ev, 0.35 * rng.uniform(0.6, 1.0) * lp(a, 2500), N(s0 + k * rng.uniform(0.5, 0.65)))
    for s0 in [9.0, 20.5]:
        a = 0.15 * lp(modal(N(0.5), [(2200, 1, 0.1), (5000, 0.5, 0.05)]), 3000)  # tool set down
        add_circ(ev, a, N(s0))
    for s0 in [6.5, 12.0, 21.8]:  # wooden beam creaks
        cr = creak(rng, rng.uniform(0.5, 0.9), rng.uniform(70, 110), rng.uniform(50, 90), rough=0.4,
                   res=((300, 5), (720, 6), (1500, 5)))
        cr *= np.sin(np.pi * np.linspace(0, 1, len(cr)))
        add_circ(ev, 0.12 * cr / np.max(np.abs(cr)), N(s0))
    ev = reverb(ev, 0.6, circular=True, t60=1.3)
    y = y / np.std(y) * 0.12 + ev
    return y


def bird(rng, kind):
    if kind == "chirp":
        out = []
        for _ in range(rng.integers(3, 7)):
            m = N(0.06)
            tm = tt(m)
            f = np.interp(tm, [0, 0.06], [rng.uniform(4000, 4800), rng.uniform(2600, 3200)])
            out += [np.sin(TAU * np.cumsum(f) / SR) * np.sin(np.pi * tm / 0.06) ** 2, np.zeros(N(rng.uniform(0.06, 0.1)))]
        return np.concatenate(out)
    if kind == "warble":
        m = N(rng.uniform(0.4, 0.8))
        tm = tt(m)
        f = rng.uniform(2800, 3500) + rng.uniform(300, 700) * np.sin(TAU * rng.uniform(18, 30) * tm) \
            + 400 * smooth(rng, m, 8, False)
        return np.sin(TAU * np.cumsum(f) / SR) * np.sin(np.pi * tm / tm[-1]) ** 0.7 * (0.6 + 0.4 * np.sin(TAU * 12 * tm))
    # two-note whistle "tee-tyoo"
    out = []
    a, b = rng.uniform(3900, 4500), rng.uniform(3000, 3400)
    for _ in range(rng.integers(2, 4)):
        for f0, d in [(a, 0.11), (b, 0.14)]:
            m = N(d)
            tm = tt(m)
            f = f0 * (1 - 0.05 * tm / d)
            out += [np.sin(TAU * np.cumsum(f) / SR) * np.sin(np.pi * tm / d) ** 1.5, np.zeros(N(0.04))]
        out.append(np.zeros(N(0.12)))
    return np.concatenate(out)


@sound("amb/village_day_loop", bus="Ambience")
def a_village_day(rng):
    L = N(30.0)
    w = rng.standard_normal(L)
    wind = ffilt(w, lambda f: r_bp(f, 420, 0.7) + 0.4 * r_lp(f, 200), circular=True)
    wind = wind / np.std(wind) * np.clip(1 + 0.45 * smooth(rng, L, 0.15), 0.15, None)
    leaves = hp(rng.standard_normal(L), 3000, circular=True)
    leaves = leaves / np.std(leaves) * np.clip(smooth(rng, L, 0.4), 0, None) * 0.25
    y = 0.08 * (wind + leaves)
    ev = np.zeros(L)
    s = 0.5
    while s < 29.5:
        kind = rng.choice(["chirp", "warble", "whistle"], p=[0.45, 0.25, 0.3])
        dist = rng.uniform(0.3, 1.0)
        b = bird(rng, kind) * dist
        b = lp(b, 6000 * dist + 1500)
        add_circ(ev, 0.12 * b, N(s))
        s += rng.uniform(1.0, 3.2)
    # distant rooster hint
    m = N(1.3)
    tm = tt(m)
    f0 = np.interp(tm, [0, 0.15, 0.5, 0.9, 1.3], [480, 620, 640, 560, 420])
    crow = ffilt(glottal(f0, m, 1.0), formant_resp("a")) * env_pts(m, [(0, 0), (0.08, 1), (0.15, 0.6), (0.25, 1), (1.0, 0.8), (1.3, 0)])
    add_circ(ev, 0.03 * lp(crow / np.max(np.abs(crow)), 1800), N(18.0))
    # distant cart rumble with wheel clacks
    m = N(4.0)
    cart = lp(rng.standard_normal(m), 250) * np.sin(np.pi * np.linspace(0, 1, m))
    for k in range(14):
        add_at(cart, 0.6 * np.sin(np.pi * k / 14) * modal(N(0.1), [(300, 1, 0.02), (700, 0.5, 0.01)]), N(k * 0.28))
    add_circ(ev, 0.04 * cart / np.max(np.abs(cart)), N(7.0))
    ev = reverb(ev, 0.25, circular=True, t60=0.9)
    return y + ev


@sound("amb/village_night_loop", bus="Ambience")
def a_village_night(rng):
    L = N(30.0)
    w = rng.standard_normal(L)
    wind = ffilt(w, lambda f: r_bp(f, 300, 0.6), circular=True)
    wind = wind / np.std(wind) * np.clip(1 + 0.5 * smooth(rng, L, 0.1), 0.1, None)
    y = 0.07 * wind
    chorus = ffilt(rng.standard_normal(L), lambda f: r_bp(f, 4300, 6), circular=True)
    chorus *= 1 + 0.6 * np.sin(TAU * 20 * tt(L))
    y += 0.02 * chorus / np.std(chorus)
    ev = np.zeros(L)
    for fc, per, amp in [(4400, 0.62, 1.0), (4750, 0.81, 0.6), (3950, 0.7, 0.35)]:
        s = rng.uniform(0, per)
        while s < 30.0:
            for p in range(3):
                m = N(0.016)
                tm = tt(m)
                pulse = np.sin(TAU * fc * tm) * np.sin(np.pi * tm / 0.016)
                add_circ(ev, 0.05 * amp * pulse, N(s + p * 0.033))
            s += per * rng.uniform(0.92, 1.08)
            if rng.uniform() < 0.06:
                s += rng.uniform(1, 3)  # occasional pause
    for s0 in [6.0, 20.5]:  # tawny owl: hoo ... hoo-hoo-hooo
        for ds, d, f0 in [(0, 0.45, 390), (1.3, 0.12, 400), (1.5, 0.12, 405), (1.7, 0.7, 395)]:
            m = N(d)
            tm = tt(m)
            f = f0 * (1 - 0.06 * tm / d) * (1 + 0.01 * np.sin(TAU * 7 * tm))
            ph = TAU * np.cumsum(f) / SR
            o = (np.sin(ph) + 0.08 * np.sin(2 * ph)) * np.sin(np.pi * tm / d) ** 1.2
            add_circ(ev, 0.06 * o, N(s0 + ds))
    ev = reverb(ev, 0.35, circular=True, t60=1.5)
    return y + ev


def talker(rng, dur, f0c, circular_len=None):
    """One murmuring voice: glottal source + per-syllable vowel formants."""
    n = N(dur)
    t = tt(n)
    f0 = f0c * (1 + 0.12 * smooth(rng, n, 1.5, False)) * (1 + 0.04 * smooth(rng, n, 6, False))
    src = glottal(f0, n, 1.3) + 0.15 * rng.standard_normal(n)
    # syllable schedule
    env = np.zeros(n)
    syl_t, syl_v = [], []
    s = rng.uniform(0, 0.3)
    while s < dur:
        if rng.uniform() < 0.15:
            s += rng.uniform(0.4, 1.2)  # pause
            continue
        d = rng.uniform(0.12, 0.28)
        a, b = N(s), min(n, N(s + d))
        if b > a:
            env[a:b] = np.sin(np.pi * np.linspace(0, 1, b - a)) * rng.uniform(0.5, 1)
        syl_t.append(s + d / 2)
        syl_v.append(rng.choice(list("aoue@i")))
        s += d + rng.uniform(0.0, 0.06)
    if not syl_t:
        return np.zeros(n)
    st = np.array(syl_t)
    F = np.array([VOWELS[v] for v in syl_v], float)
    def g(tc, f):
        tcf = tc[:, 0]
        f1 = np.interp(tcf, st, F[:, 0])[:, None]
        f2 = np.interp(tcf, st, F[:, 1])[:, None]
        f3 = np.interp(tcf, st, F[:, 2])[:, None]
        return r_bp(f, f1, f1 / 90) + 0.5 * r_bp(f, f2, f2 / 120) + 0.25 * r_bp(f, f3, f3 / 170)
    return tvfilt(src * env, g)


@sound("amb/tavern_loop", bus="Ambience")
def a_tavern(rng):
    L = N(30.0)
    T = L / SR
    crowd = np.zeros(L)
    for i in range(9):
        v = loopify(talker(rng, T + 1.0, rng.uniform(95, 230)), L, N(1.0))
        crowd += rng.uniform(0.4, 1.0) * v / (np.std(v) + 1e-9)
    walla = ffilt(rng.standard_normal(L), lambda f: r_bp(f, 600, 0.6) + 0.5 * r_bp(f, 1500, 1), circular=True)
    walla *= np.clip(1 + 0.8 * smooth(rng, L, 4.5), 0, None)
    crowd = lp(crowd / np.std(crowd), 1900, circular=True) + 0.5 * walla / np.std(walla)
    y = 0.12 * crowd
    ev = np.zeros(L)
    # laugh-like bursts
    for s0 in rng.uniform(1, 29, 4):
        k = rng.integers(3, 6)
        m = N(k * 0.16 + 0.1)
        tm = tt(m)
        f0 = np.interp(tm, [0, tm[-1]], [rng.uniform(220, 300), rng.uniform(150, 200)])
        src = glottal(f0, m, 1.2) + 0.4 * rng.standard_normal(m)
        env = np.clip(np.sin(TAU * 6.2 * tm), 0, None) ** 1.5 * np.exp(-tm / 0.6)
        lg = ffilt(src * env, formant_resp("a"))
        add_circ(ev, 0.05 * lp(lg / np.max(np.abs(lg)), 2000), N(s0))
    # cup and tankard clinks, mugs set down
    for s0 in rng.uniform(0, 30, 14):
        f0 = rng.uniform(1200, 2600)
        c = modal(N(0.4), [(f0, 1, 0.12), (f0 * 2.4, 0.5, 0.06), (f0 * 3.9, 0.25, 0.03)])
        add_circ(ev, 0.05 * rng.uniform(0.3, 1) * c, N(s0))
        if rng.uniform() < 0.4:
            add_circ(ev, 0.04 * modal(N(0.15), [(160, 1, 0.03), (380, 0.5, 0.02)]), N(s0 + rng.uniform(0.2, 1)))
    # faint lute noodling (G major pentatonic random walk)
    pent = [55, 57, 59, 62, 64, 67, 69, 71, 74]
    idx = 4
    s = 0.3
    lute = np.zeros(L)
    while s < 29.8:
        idx = int(np.clip(idx + rng.choice([-2, -1, -1, 1, 1, 2]), 0, len(pent) - 1))
        p = ks_pluck(mtof(pent[idx]), 0.9, rng, t60=1.0, damp=0.2)
        add_circ(lute, p * rng.uniform(0.5, 1), N(s))
        s += rng.choice([0.25, 0.25, 0.5, 0.375]) + (rng.uniform(0.6, 1.5) if rng.uniform() < 0.12 else 0)
    lute = lp(lute, 2400, circular=True)
    ev += 0.025 * lute / np.max(np.abs(lute))
    y = reverb(y + ev, 0.4, circular=True, t60=1.0)
    return y


# ----------------------------------------------------------------------------
# MUSIC: rule-based composer
# ----------------------------------------------------------------------------
DORIAN = [0, 2, 3, 5, 7, 9, 10]
AEOLIAN = [0, 2, 3, 5, 7, 8, 10]
IONIAN = [0, 2, 4, 5, 7, 9, 11]


class Piece:
    def __init__(self, sid, tonic, scale, bpm, beats_per_bar, bars, beat_unit_sec=None):
        self.rng = rng_of(sid, 1)
        self.tonic, self.scale = tonic, scale
        self.beat = beat_unit_sec or 60.0 / bpm
        self.bpb = beats_per_bar
        self.bars = bars
        self.L = N(self.beat * beats_per_bar * bars)
        self.tracks = {}

    def midi(self, deg):
        return self.tonic + 12 * (deg // 7) + self.scale[deg % 7]

    def at(self, bar, beat):
        return (bar * self.bpb + beat) * self.beat

    def add(self, track, sec, arr, jitter=0.007):
        buf = self.tracks.setdefault(track, np.zeros(self.L))
        add_circ(buf, arr, N(sec + self.rng.normal(0, jitter)) if jitter else N(sec))


STEP_CHOICES = [-2, -1, -1, -1, 0, 1, 1, 1, 2, 3, -3]


def make_motif(rng, rhythm):
    return (list(rhythm), [0] + [int(rng.choice(STEP_CHOICES)) for _ in rhythm[1:]])


def vary_motif(rng, motif):
    r, s = motif
    s = list(s)
    if len(s) > 1:
        i = int(rng.integers(1, len(s)))
        s[i] += int(rng.choice([-1, 1]))
    return (r, s)


def snap(rng, d, root, lo, hi):
    tones = {root % 7, (root + 2) % 7, (root + 4) % 7}
    cands = [c for c in range(d - 3, d + 4) if c % 7 in tones and lo <= c <= hi]
    if not cands:
        return d
    best = min(abs(c - d) for c in cands)
    return int(rng.choice([c for c in cands if abs(c - d) == best]))


def phrase(rng, motif, cad, chords2, start, target, bpb, strong, lo, hi):
    notes = []
    cur = start
    b = 0.0
    rhythm, steps = motif
    for i, (d, st) in enumerate(zip(rhythm, steps)):
        if i > 0:
            if not lo <= cur + st <= hi:
                st = -st
            cur += st
        if (b % bpb) in strong:
            cur = snap(rng, cur, chords2[0], lo, hi)
        notes.append([b, d, cur])
        b += d
    tgt = target + 7 * int(round((cur - target) / 7))
    while tgt > hi:
        tgt -= 7
    while tgt < lo:
        tgt += 7
    k = len(cad)
    b = float(bpb)
    for j, d in enumerate(cad):
        if j == k - 1:
            cur = tgt
        else:
            rem = k - 1 - j
            diff = tgt - cur
            if diff == 0:
                st = int(rng.choice([-1, 1]))
            else:
                st = int(np.sign(diff)) * max(1, int(np.ceil(abs(diff) / (rem + 1))))
            cur += st
            if j == 0:
                cur = snap(rng, cur, chords2[1], lo, hi)
        notes.append([b, d, cur])
        b += d
    return notes


def section_melody(rng, chords, bpb, strong, rhythms, cads, lo, hi, start, motif=None,
                   targets=(4, 0, 1, 0)):
    """8 bars = 4 two-bar phrases: call / response / sequenced call / cadence."""
    if motif is None:
        motif = make_motif(rng, rhythms[int(rng.integers(len(rhythms)))])
    out = []
    cur = start
    cad_a = cads[int(rng.integers(len(cads)))]
    cad_b = cads[int(rng.integers(len(cads)))]
    for p in range(len(chords) // 2):
        mot = motif if p % 2 == 0 else vary_motif(rng, motif)
        st = cur + (2 if p == 2 else 0)
        st = int(np.clip(st, lo, hi))
        ns = phrase(rng, mot, cad_a if p % 2 == 0 else cad_b, chords[2 * p:2 * p + 2], st,
                    targets[p % len(targets)], bpb, strong, lo, hi)
        for nn in ns:
            nn[0] += 2 * p * bpb
        out += ns
        cur = ns[-1][2]
        # next phrase starts on a chord tone near the cadence note (not always the same)
        cur = cur + int(rng.choice([-2, 0, 2]))
    return out, motif


def render_melody(pc, track, notes, bar0, inst, vel=0.8, legato=0.95, octave=0, strong=(0,)):
    for b, d, deg in notes:
        start = pc.at(bar0, b)
        v = vel * (1.08 if (b % pc.bpb) in strong else 0.92) * pc.rng.uniform(0.92, 1.05)
        f = mtof(pc.midi(deg) + 12 * octave)
        dur = d * pc.beat * legato
        pc.add(track, start, inst(f, dur + 0.05, v, pc.rng))


def lute_note(f, dur, v, rng):
    return v * ks_pluck(f, max(dur, 0.6), rng, t60=1.3, damp=0.22, bright=0.55, pos=rng.uniform(0.12, 0.25))


def chord_degs(root):
    return [root, root + 2, root + 4]


def mix_down(pc, gains, sends, t60=1.8, wet=0.3, posts=None):
    L = pc.L
    dry = np.zeros(L)
    send = np.zeros(L)
    for name, buf in pc.tracks.items():
        x = buf
        if posts and name in posts:
            x = ffilt(x, posts[name], circular=True)
        x = x * gains.get(name, 1.0)
        dry += x
        send += x * sends.get(name, 0.3)
    wetsig = reverb(send, 1.0, circular=True, t60=t60, damp=0.5, seed=11) - send
    return hp(dry + wet * wetsig, 55, order=2, circular=True)


def soft_limit(x, thr=0.7):
    x = x / np.max(np.abs(x))
    a = np.abs(x)
    over = a > thr
    y = x.copy()
    y[over] = np.sign(x[over]) * (thr + (1 - thr) * np.tanh((a[over] - thr) / (1 - thr)))
    return y


LUTE_POST = lambda f: r_peak(f, 210, 1.0, 4) * r_peak(f, 1200, 1.5, 2) * r_lp(f, 4200, 2) * r_hp(f, 70, 2)
FIDDLE_POST = lambda f: (r_peak(f, 290, 2, 5) * r_peak(f, 1000, 1.5, 3) * r_peak(f, 2600, 2, 4)
                         * r_lp(f, 5500, 2) * r_hp(f, 180, 2))


def drone(pc, track, midis, vel, bright=900, buzz=0.0):
    L = pc.L
    t = tt(L)
    T = L / SR
    y = np.zeros(L)
    for m in midis:
        f = round(float(mtof(m)) * T) / T  # whole number of cycles per loop => seamless
        # vibrato/swell with integer number of cycles over the loop => seamless
        vib = 1 + 0.0015 * np.sin(TAU * round(4.7 * T) / T * t + pc.rng.uniform(0, 6))
        y += saw_phase(TAU * np.cumsum(f * vib) / SR, f, tilt=1.0, nh=min(60, int(SR * 0.45 / f)))
    y = ffilt(y, lambda f: r_lp(f, bright, 2) * r_peak(f, 650, 1.2, 4), circular=True)
    swell = 1 + 0.15 * np.sin(TAU * round(T / 9) / T * t)
    if buzz:
        swell *= 1 + buzz * np.clip(np.sin(TAU * pc.bpb * pc.bars / T * t), 0, None) ** 4
    buf = pc.tracks.setdefault(track, np.zeros(L))
    buf += vel * y * swell


@sound("music/hearth_day", bus="Music")
def m_hearth_day(rng):
    pc = Piece("music/hearth_day", 62, DORIAN, 84, 4, 32)
    r = pc.rng
    rhythms = [[1, 0.5, 0.5, 1, 1], [1.5, 0.5, 1, 1], [0.5, 0.5, 1, 1, 1], [1, 1, 0.5, 0.5, 1]]
    cads = [[1, 1, 2], [1.5, 0.5, 2], [0.5, 0.5, 1, 2], [2, 2]]
    A = [0, 6, 3, 0, 2, 6, 3, 0]
    B = [2, 6, 0, 4, 2, 3, 6, 6]
    plan = [0, 0, 3, 0] + A + B + A + [0, 3, 6, 0]
    strong = (0, 2)
    melA, motif = section_melody(r, A, 4, strong, rhythms, cads, 0, 10, 4)
    melB, _ = section_melody(r, B, 4, strong, [[1, 1, 1, 1], [2, 1, 1], [1.5, 0.5, 2]], cads, 2, 12, 7,
                             targets=(4, 2, 1, 0))
    melA2, _ = section_melody(r, A, 4, strong, rhythms, cads, 0, 11, 4, motif=vary_motif(r, motif))
    render_melody(pc, "flute", melA, 4, flute, 0.8, 0.92, 0, strong)
    render_melody(pc, "flute", melB, 12, flute, 0.75, 0.95, 0, strong)
    render_melody(pc, "flute", melA2, 20, flute, 0.85, 0.92, 0, strong)
    # outro: echo first phrase of the motif, then rest so the loop breathes
    render_melody(pc, "flute", [n for n in melA if n[0] < 4], 28, flute, 0.6, 0.9, 0, strong)
    # lute arpeggios
    for bar, root in enumerate(plan):
        tones = [root - 7, root - 5, root - 3, root, root + 2]
        light = bar < 4 or bar >= 28
        pat = [0, 2, 3, 4, 3, 2, 1, 2] if not light else [0, 2, 3, 2, 4, 2, 3, 2]
        for i, k in enumerate(pat):
            v = (0.9 if i == 0 else 0.55 if i % 2 == 0 else 0.45) * r.uniform(0.85, 1.1)
            if 12 <= bar < 20 and i % 2 == 1 and r.uniform() < 0.3:
                continue
            pc.add("lute", pc.at(bar, i * 0.5) + (0.012 if i % 2 else 0), lute_note(mtof(pc.midi(tones[k])), 1.2, v, r))
    drone(pc, "drone", [38, 45], 0.35, bright=500)
    y = mix_down(pc, {"flute": 0.5, "lute": 0.75, "drone": 0.25},
                 {"flute": 0.45, "lute": 0.3, "drone": 0.2}, t60=1.8, wet=0.35,
                 posts={"lute": LUTE_POST, "flute": lambda f: r_lp(f, 6000)})
    return soft_limit(y, 0.75)


@sound("music/village_evening", bus="Music")
def m_village_evening(rng):
    pc = Piece("music/village_evening", 57, AEOLIAN, 66, 3, 32)
    r = pc.rng
    rhythms = [[2, 1], [1, 1, 1], [1.5, 0.5, 1], [2, 0.5, 0.5]]
    cads = [[1, 2], [3], [2, 1], [1, 1, 1]]
    cads = [[1, 2], [2, 1], [1.5, 1.5]]
    A = [0, 5, 2, 6, 0, 3, 4, 0]
    B = [5, 2, 6, 0, 3, 0, 4, 4]
    plan = [0, 5, 0, 4] + A + B + A + [0, 3, 5, 4]
    strong = (0,)
    melA, motif = section_melody(r, A, 3, strong, rhythms, cads, 0, 9, 4)
    melB, _ = section_melody(r, B, 3, strong, rhythms, cads, -2, 8, 2, targets=(4, 2, 6, 4))
    melA2, _ = section_melody(r, A, 3, strong, rhythms, cads, 0, 10, 4, motif=vary_motif(r, motif))
    render_melody(pc, "flute", melA, 4, flute, 0.75, 0.97, 0, strong)
    gurdy = lambda f, d, v, rr: fiddle(f, d, v, rr, vib_depth=0.002)
    render_melody(pc, "fiddle", melB, 12, gurdy, 0.6, 1.0, -1, strong)
    render_melody(pc, "flute", melA2, 20, flute, 0.75, 0.97, 0, strong)
    render_melody(pc, "fiddle", melA2, 20, gurdy, 0.25, 1.0, -1, strong)  # low doubling
    for bar, root in enumerate(plan):
        tones = [root - 7, root - 3, root, root + 2]
        pc.add("lute", pc.at(bar, 0), lute_note(mtof(pc.midi(tones[0])), 2.0, 0.9, r))
        if bar >= 4:
            for i, k in enumerate([1, 2, 3, 2]):
                pc.add("lute", pc.at(bar, 1 + i * 0.5), lute_note(mtof(pc.midi(tones[k])), 1.2, 0.45, r))
    drone(pc, "drone", [45, 52], 0.45, bright=1300, buzz=0.12)
    y = mix_down(pc, {"flute": 0.5, "fiddle": 0.55, "lute": 0.7, "drone": 0.3},
                 {"flute": 0.5, "fiddle": 0.45, "lute": 0.35, "drone": 0.25}, t60=2.4, wet=0.4,
                 posts={"lute": LUTE_POST, "fiddle": FIDDLE_POST, "flute": lambda f: r_lp(f, 5000)})
    return soft_limit(y, 0.75)


@sound("music/tavern", bus="Music")
def m_tavern(rng):
    eighth = 60 / 112 / 3
    pc = Piece("music/tavern", 67, IONIAN, 0, 6, 56, beat_unit_sec=eighth)
    r = pc.rng
    rhythms = [[1, 1, 1, 1, 1, 1], [2, 1, 2, 1], [1, 1, 1, 2, 1], [2, 1, 1, 1, 1], [3, 1, 1, 1]]
    cads = [[2, 1, 3], [1, 1, 1, 3], [3, 3], [2, 1, 2, 1]]
    A = [0, 3, 0, 4, 0, 3, 4, 0]
    B = [5, 5, 3, 4, 5, 3, 4, 0]
    strong = (0, 3)
    melA, motif = section_melody(r, A, 6, strong, rhythms, cads, -1, 10, 4)
    melA2, _ = section_melody(r, A, 6, strong, rhythms, cads, -1, 10, 4, motif=vary_motif(r, motif))
    melB, _ = section_melody(r, B, 6, strong, rhythms, cads, 1, 11, 5, targets=(4, 2, 4, 0))
    melB2, _ = section_melody(r, B, 6, strong, rhythms, cads, 1, 11, 5, targets=(4, 2, 4, 0))
    plan = [0, 4, 0, 4] + A + A + B + B + A + A + [0, 4, 0, 4]
    for bar0, mel in [(4, melA), (12, melA2), (20, melB), (28, melB2), (36, melA), (44, melA2)]:
        render_melody(pc, "fiddle", mel, bar0, fiddle, 0.75, 0.9, 0, strong)
    for bar, root in enumerate(plan):
        tones = [root - 7, root - 5, root - 3]
        pc.add("lute", pc.at(bar, 0), lute_note(mtof(pc.midi(root - 14)), 0.8, 0.9, r), 0.004)
        pc.add("lute", pc.at(bar, 3), lute_note(mtof(pc.midi(root - 10)), 0.8, 0.8, r), 0.004)
        for pos in [1, 2, 4, 5]:  # chord strums on the off-beats
            for j, k in enumerate(tones):
                pc.add("lute", pc.at(bar, pos) + j * 0.008, lute_note(mtof(pc.midi(k)), 0.4, 0.35, r), 0.004)
        # frame drum
        pat = [("dum", 1.0, 0), ("tek", 0.5, 2), ("dum", 0.75, 3), ("tek", 0.45, 4), ("tek", 0.6, 5)]
        if bar % 4 == 3:
            pat = [("dum", 1.0, 0), ("tek", 0.5, 1), ("tek", 0.6, 2), ("dum", 0.8, 3), ("dum", 0.7, 4), ("tek", 0.7, 5)]
        if bar >= 2:
            for kind, v, pos in pat:
                pc.add("drum", pc.at(bar, pos), frame_drum(r, v * r.uniform(0.85, 1.1), kind), 0.004)
    y = mix_down(pc, {"fiddle": 0.45, "lute": 0.6, "drum": 0.55},
                 {"fiddle": 0.3, "lute": 0.25, "drum": 0.2}, t60=1.2, wet=0.35,
                 posts={"lute": LUTE_POST, "fiddle": FIDDLE_POST})
    return soft_limit(y, 0.7)


@sound("music/title", bus="Music")
def m_title(rng):
    pc = Piece("music/title", 62, AEOLIAN, 70, 4, 20)
    r = pc.rng
    plan = [0, 0, 5, 5, 0, 5, 2, 6, 0, 5, 3, 4, 5, 2, 6, 0, 0, 5, 3, 4]
    # choir pad on every chord
    for bar, root in enumerate(plan):
        n = N(pc.at(1, 0) + 1.0)
        ch = choir(mtof([pc.midi(d - 14) for d in [root, root + 4]] + [pc.midi(d - 7) for d in chord_degs(root)]),
                   n, r, "a" if bar % 2 == 0 else "o")
        ch *= env_pts(n, [(0, 0), (0.9, 1), (n / SR - 1.2, 0.9), (n / SR, 0)])
        v = 0.6 if 12 <= bar < 16 else 0.4
        pc.add("choir", pc.at(bar, 0), v * ch / np.max(np.abs(ch)), 0)
    # bell motif (intro + outro)
    bell_motif = [(0, 7, 1.0), (1.5, 9, 0.7), (2, 11, 0.8), (3, 9, 0.6)]
    for bar in [0, 2, 16, 18]:
        for b, deg, v in bell_motif:
            pc.add("bells", pc.at(bar, b), bell(mtof(pc.midi(deg)), 3.0, v, decay=1.6, rng=r))
    # flute theme (bars 4-11)
    rhythms = [[2, 1, 1], [1.5, 0.5, 2], [1, 1, 2]]
    cads = [[1, 3], [2, 2], [1, 1, 2]]
    mel, motif = section_melody(r, plan[4:12], 4, (0, 2), rhythms, cads, 0, 9, 4)
    render_melody(pc, "flute", mel, 4, flute, 0.8, 0.98, 0, (0, 2))
    # climax: strings (low fiddle ensemble) carry the theme, bells double
    mel2, _ = section_melody(r, plan[12:16] * 2, 4, (0, 2), rhythms, cads, 2, 11, 7, motif=motif)
    mel2 = [nn for nn in mel2 if nn[0] < 16]
    strings = lambda f, d, v, rr: fiddle(f, d, v, rr, 0.004) + 0.6 * fiddle(f * 0.5, d, v, rr, 0.004)
    render_melody(pc, "strings", mel2, 12, strings, 0.7, 1.0, 0, (0, 2))
    for b, d, deg in mel2:
        if b % 4 == 0:
            pc.add("bells", pc.at(12, b), bell(mtof(pc.midi(deg) + 12), 2.5, 0.35, decay=1.2, rng=r))
    # lute arpeggios through the theme
    for bar in range(4, 16):
        root = plan[bar]
        tones = [root - 7, root - 3, root, root + 2]
        for i, k in enumerate([0, 1, 2, 3, 2, 1, 2, 3]):
            pc.add("lute", pc.at(bar, i * 0.5), lute_note(mtof(pc.midi(tones[k])), 1.2, 0.5 if i else 0.8, r))
    # distant drums
    for bar in [0, 4, 8, 12, 13, 14, 15, 16]:
        pc.add("drum", pc.at(bar, 0), frame_drum(r, 1.0, "dum", 1.0), 0)
        if 12 <= bar < 16:
            pc.add("drum", pc.at(bar, 2.5), frame_drum(r, 0.6, "dum", 1.0), 0)
    drone(pc, "drone", [38, 45, 50], 0.3, bright=600)
    y = mix_down(pc, {"choir": 0.35, "bells": 0.3, "flute": 0.5, "strings": 0.4, "lute": 0.5, "drum": 0.8, "drone": 0.25},
                 {"choir": 0.5, "bells": 0.6, "flute": 0.5, "strings": 0.5, "lute": 0.35, "drum": 0.6, "drone": 0.2},
                 t60=2.8, wet=0.45, posts={"lute": LUTE_POST, "strings": FIDDLE_POST, "flute": lambda f: r_lp(f, 5500),
                                           "drum": lambda f: r_lp(f, 1500)})
    return soft_limit(y, 0.75)


@sound("music/ironfront", bus="Music")
def m_ironfront(rng):
    """Barnaby's war-room: a jaunty brass march over snare and bass drum (loops seamlessly)."""
    pc = Piece("music/ironfront", 58, IONIAN, 116, 4, 24)
    r = pc.rng
    rhythms = [[1, 0.5, 0.5, 1, 1], [0.75, 0.25, 1, 0.75, 0.25, 1], [1, 1, 0.5, 0.5, 1], [0.5, 0.5, 1, 1, 1]]
    cads = [[1, 1, 2], [0.75, 0.25, 1, 2], [2, 2]]
    A = [0, 4, 0, 4, 0, 3, 4, 0]
    B = [3, 0, 4, 0, 3, 0, 4, 4]
    strong = (0, 2)
    melA, motif = section_melody(r, A, 4, strong, rhythms, cads, 0, 9, 4)
    melB, _ = section_melody(r, B, 4, strong, rhythms, cads, 2, 11, 5, targets=(4, 2, 4, 0))
    plan = A + B + A
    render_melody(pc, "brass", melA, 0, brass, 0.75, 0.82, 0, strong)
    render_melody(pc, "brass", melB, 8, brass, 0.75, 0.82, 0, strong)
    render_melody(pc, "brass", melA, 16, brass, 0.8, 0.82, 0, strong)
    render_melody(pc, "fife", melB, 8, flute, 0.35, 0.8, 1, strong)
    for bar, root in enumerate(plan):
        # oom-pah: bass on 1 and 3, chord stabs on 2 and 4
        for beat, deg in ((0, root - 14), (2, root - 10)):
            pc.add("bass", pc.at(bar, beat), brass(mtof(pc.midi(deg)), 0.42, 0.8, r), 0.004)
        for beat in (1, 3):
            for k in chord_degs(root):
                pc.add("stab", pc.at(bar, beat), brass(mtof(pc.midi(k - 7)), 0.22, 0.32, r), 0.004)
        # bass drum on 1 and 3, snare rudiments
        for beat in (0, 2):
            pc.add("drum", pc.at(bar, beat), frame_drum(r, 0.9, "dum", 0.5), 0.003)
        roll = [1, 3, 3.5] if bar % 4 != 3 else [1, 2.5, 2.75, 3, 3.25, 3.5, 3.75]
        for beat in roll:
            n = N(0.18)
            t = tt(n)
            sn = (0.8 * bp(r.standard_normal(n), 2600, 0.9) + 0.4 * np.sin(TAU * 190 * t)) * np.exp(-t / 0.045)
            pc.add("snare", pc.at(bar, beat), sn * (0.9 if beat == int(beat) else 0.6), 0.003)
    y = mix_down(pc, {"brass": 0.5, "fife": 0.35, "bass": 0.5, "stab": 0.45, "drum": 0.7, "snare": 0.35},
                 {"brass": 0.35, "fife": 0.4, "bass": 0.15, "stab": 0.2, "drum": 0.25, "snare": 0.25}, t60=1.1, wet=0.28,
                 posts={"brass": lambda f: r_lp(f, 4200) * r_peak(f, 900, 1.2, 3), "stab": lambda f: r_lp(f, 3000),
                        "fife": lambda f: r_lp(f, 6000), "drum": lambda f: r_lp(f, 1500)})
    return soft_limit(y, 0.72)


# ----------------------------------------------------------------------------
# output / verification
# ----------------------------------------------------------------------------
def finalize(x, loop, peak_db):
    x = np.asarray(x, float)
    x = hp(x, 25, order=2, circular=loop)
    x -= np.mean(x) if loop else 0
    if not loop:
        fi = N(0.0008)
        x[:fi] *= np.linspace(0, 1, fi)
        fo = min(N(0.03), len(x) // 4)
        x[-fo:] *= np.linspace(1, 0, fo) ** 2
    pk = np.max(np.abs(x))
    if pk > 0:
        x *= dbg(peak_db) / pk
    return x


def write_wav(path, x):
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(np.round(x * 32767), -32767, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def read_wav(path):
    with wave.open(str(path), "rb") as w:
        assert w.getframerate() == SR and w.getnchannels() == 1 and w.getsampwidth() == 2
        return np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32768.0


def spectrogram_png(x, path, max_sec=None, nfft=1024, hop=128, height=320, max_w=1000):
    from PIL import Image
    if max_sec:
        x = x[:N(max_sec)]
    xx = np.concatenate([np.zeros(nfft // 2), x, np.zeros(nfft)])
    nfr = (len(xx) - nfft) // hop
    idx = np.arange(nfft)[None, :] + hop * np.arange(nfr)[:, None]
    S = np.abs(np.fft.rfft(xx[idx] * np.hanning(nfft), axis=1))
    D = 20 * np.log10(S + 1e-9)
    D = np.clip((D - (D.max() - 65)) / 65, 0, 1)
    if D.shape[0] > max_w:
        k = int(np.ceil(D.shape[0] / max_w))
        D = D[:D.shape[0] // k * k].reshape(-1, k, D.shape[1]).max(axis=1)
    # log-ish frequency axis (50 Hz .. 11 kHz)
    f = np.fft.rfftfreq(nfft, 1 / SR)
    rows = np.geomspace(50, SR / 2, height)[::-1]
    img = np.array([np.interp(rows, f, col) for col in D]).T
    # waveform envelope strip
    wav_h = 60
    cols = img.shape[1]
    seg = np.array_split(np.abs(x), cols)
    env = np.array([s.max() if len(s) else 0 for s in seg])
    strip = np.zeros((wav_h, cols))
    for c, e in enumerate(env):
        h = int(e * (wav_h - 2))
        strip[wav_h // 2 - h // 2: wav_h // 2 + h // 2 + 1, c] = 1
    v = np.vstack([img, np.full((2, cols), 0.15), strip])
    rgb = np.stack([np.clip(v * 1.6, 0, 1), np.clip(v * 1.4 - 0.35, 0, 1), np.clip(v * 1.6 - 0.9, 0, 1)], -1)
    Image.fromarray((rgb * 255).astype(np.uint8)).save(path)


def verify(ids=None):
    print(f"\n{'id':28s} {'dur':>6s} {'peak dBFS':>9s} {'rms dBFS':>9s} {'clip':>5s} {'seam':>17s}  notes")
    tot = 0
    problems = []
    manifest = {}
    for sid, meta in sorted(REGISTRY.items()):
        p = OUT / f"{sid}.wav"
        if not p.exists():
            problems.append(f"missing {sid}")
            continue
        tot += p.stat().st_size
        x = read_wav(p)
        dur = len(x) / SR
        pk = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
        rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
        clip = int(np.sum(np.abs(x) >= 32766 / 32768))
        d = np.abs(np.diff(x))
        ref = np.percentile(d, 99.5) + 1e-9
        notes = []
        seam = ""
        if meta["loop"]:
            jump = abs(x[0] - x[-1])
            ratio = jump / ref
            seam = f"{ratio:5.2f}"
            w = N(0.05)
            lvl_a = np.sqrt(np.mean(x[:w] ** 2))
            lvl_b = np.sqrt(np.mean(x[-w:] ** 2))
            if ratio > 1.0:
                notes.append("SEAM JUMP")
            # level step across the seam vs. the same metric at every other 50 ms boundary
            fr = np.sqrt(np.mean(x[:len(x) // w * w].reshape(-1, w) ** 2, axis=1)) + 1e-6
            steps = np.abs(20 * np.log10(fr[1:] / fr[:-1]))
            seam_step = abs(20 * np.log10((lvl_a + 1e-6) / (lvl_b + 1e-6)))
            seam += f" {seam_step:4.1f}dB/p{(steps < seam_step).mean() * 100:3.0f}"
            # music loops restart on a bar-1 downbeat, where an onset (level step) is intended
            if not sid.startswith("music/") and seam_step > max(3.0, np.percentile(steps, 99)):
                notes.append("seam level step")
        else:
            if abs(x[0]) > 0.01 or abs(x[-1]) > 0.01:
                notes.append("edge click")
        if clip:
            notes.append("CLIP")
        if abs(np.mean(x)) > 0.01:
            notes.append("DC")
        if notes:
            problems.append(f"{sid}: {', '.join(notes)}")
        manifest[sid] = {"duration": round(dur, 3), "loop": meta["loop"], "bus": meta["bus"]}
        print(f"{sid:28s} {dur:6.2f} {pk:9.2f} {rms:9.2f} {clip:5d} {seam:>17s}  {' '.join(notes)}")
    with open(OUT / "manifest.json", "w") as fh:
        json.dump(manifest, fh, indent=2, sort_keys=True)
    tot += (OUT / "manifest.json").stat().st_size
    print(f"\nfiles: {len(manifest)}  total: {tot / 1e6:.2f} MB")
    print("problems:", problems or "none")
    SPEC_OUT.mkdir(parents=True, exist_ok=True)
    for sid, mx in [("sfx/legendary_drop", None), ("sfx/hammer_1", None), ("sfx/check_perfect", None),
                    ("music/hearth_day", 20.0)]:
        p = OUT / f"{sid}.wav"
        if p.exists():
            spectrogram_png(read_wav(p), SPEC_OUT / (sid.replace("/", "_") + ".png"), mx)
    return problems


def main(argv):
    if "--verify" in argv:
        verify()
        return
    filt = [a for a in argv if not a.startswith("-")]
    for sid, meta in REGISTRY.items():
        if filt and not any(f in sid for f in filt):
            continue
        t0 = time.time()
        x = meta["fn"](rng_of(sid))
        x = finalize(x, meta["loop"], meta["peak"])
        write_wav(OUT / f"{sid}.wav", x)
        print(f"rendered {sid:28s} {len(x) / SR:6.2f}s  ({time.time() - t0:.1f}s)", flush=True)
    verify()


if __name__ == "__main__":
    main(sys.argv[1:])
