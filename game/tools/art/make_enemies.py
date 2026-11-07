"""Enemy tabletop miniatures for "Ember & Ash" expeditions (Ink & Parchment / Gothic Noir 80:20).

    python3 game/tools/art/make_enemies.py                  # every enemy in data/expeditions.json -> "enemies"
    python3 game/tools/art/make_enemies.py --only=wolf,golem
    python3 game/tools/art/make_enemies.py --contact        # only rebuild the review sheet from existing PNGs

Output: assets/sprites/enemies/template_<id>.png, RGBA, two frames side by side:
    frame 0 idle, frame 1 attack / lunge (restrained, same base, no rotation).
    regular enemies: 256x128 (cells 128x128), bosses: 384x192 (cells 192x192, figure + base 1.5x).
Same conventions as the character miniatures (make_minis.py / miniature.py): base centred horizontally,
top-face centre at 75 % of the cell height (y=96 / y=144), light from top-left, inked outlines + hatching.
Figures stand three-quarter facing screen-left (toward the party).  Enemy bases are darker and hostile
(scorched earth, crypt slate, bone-grey, bog) with a thin rubric rim line; spirit bases are faint.
The base is rendered once and composited under both frames, so it is pixel-identical.
Review sheet: tools/art/out/enemies_contact.png.
"""
import json
import math
import os
import random
import sys

import artlib
from artlib import render, ink_filter, svg_doc, SPR, OUT, DATA, INK, EMBER, EMBER_HOT, GILT, RUB, glow, blur_filter, lin, fill
from svgcore import ell, poly, smooth  # noqa: F401
import miniature as M
from miniature import CX, FY, SHADE, capsule
from person import tri, mix

OUT_EN = os.path.join(SPR, "enemies")
TMP = os.path.join(OUT, "enemies_tmp")
BOSSES = {"wolf_alpha", "brood_mother", "bandit_captain", "barrow_lord", "golem", "revenant"}
SPIRITS = {"bog_wraith", "shadow"}

GHOST = "#9ee0a0"        # sickly green
GHOST_HOT = "#e2ffd0"
COLD = "#9fd4ec"         # cold blue (wights)
COLD_HOT = "#eefaff"
RUST = "#9a4a22"

# extra material roles (light, base, shadow)
ROLES = dict(
    wolf=tri("#8e8c86", 0.02), wolf2=tri("#5e5c58", 0.02), wolfbelly=tri("#c4bcac", 0.02),
    alpha=tri("#6e6c6a", 0.0), alpha2=tri("#424040", 0.0),
    boar=tri("#6a4e3a", 0.0), boar2=tri("#3e2c20", 0.0), snout=tri("#b08074", 0.02),
    chitin=tri("#6e5444", 0.0), chitin2=tri("#3e3028", 0.0), brood=tri("#5a4448", 0.0),
    egg=("#f4eedc", "#d8d0b8", "#8e866c"),
    gob=tri("#8a9466", 0.02), rag=tri("#6a5638", 0.02), rag2=tri("#4e4434", 0.02),
    hood=tri("#4a4a3c", 0.0), jerkin=tri("#6e4e32", 0.0), mask=tri("#3a3430", 0.0),
    coat=tri("#5e2a24", 0.0), hat=tri("#2e2622", 0.0), sash=tri("#a8321e", 0.0),
    bone=("#f2ead2", "#d6caa8", "#8a7e5e"), rust=tri(RUST, 0.0), rustiron=tri("#6e5a4a", 0.0),
    shieldwood=tri("#6a4a2c", 0.0),
    robe=tri("#3c4048", 0.0), gaunt=tri("#a4a89a", 0.0),
    armor=tri("#5a5c60", 0.0), tatter=tri("#4a1e1a", 0.0),
    rock=tri("#8a847a", 0.0), rock2=tri("#625c54", 0.0),
    ink=("#3a3044", "#1e1824", "#0c0a10"),
    wisp=("#c8e0b8", "#7e9e72", "#3e5a3a"),
    ghostbeard=("#e6fff0", "#b4e4cc", "#6aa08c"),
)


def palette():
    pal = dict(artlib.ST["pal"])
    pal.update(ROLES)
    pal["eye"] = ("#3a2a1e", "#20140c", "#100a06")
    return pal


def J(o):
    return "\n".join(x for x in o if x)


def L(a, b, t):
    return a + (b - a) * t


# ------------------------------------------------------------------ builder
class E:
    """Collects one figure: o = inked layer, em = emissive (unfiltered) glows; alpha < 1 for spirits."""

    def __init__(self, P, a):
        self.P, self.a = P, a          # a: 0 idle, 1 attack
        self.o, self.em = [], []
        self.alpha = 1.0

    def sh(self, d, role, s=2, **kw):
        self.o.append(self.P.shape(d, role, s=s * SHADE, **kw))

    def det(self, d, w=1.0, op=1.0):
        self.o.append(self.P.detail(d, None, w, op))

    def ln(self, d, col=INK, w=1.0, op=1.0):
        self.o.append(lin(d, col, w, op))

    def fl(self, d, col, op=1.0):
        self.o.append(fill(d, col, op))

    def eye(self, x, y, col, hot, r=1.8, g=7, gop=0.75):
        self.o.append(fill(ell(x, y, r, r * 0.8), hot))
        self.em.append(glow(self.P, x, y, g, col, gop))
        self.em.append(fill(ell(x, y, r * 0.7, r * 0.55), hot))

    def limb(self, pts, r1, r2, role, s=1.2):
        """jointed limb: capsules through pts, radius r1 -> r2."""
        n = len(pts) - 1
        for i in range(n):
            ra = L(r1, r2, i / n)
            rb = L(r1, r2, (i + 1) / n)
            self.sh(capsule(pts[i], pts[i + 1], ra, rb), role, s=s)


def fur_strokes(rnd, x0, x1, y0, y1, n, dl=5):
    out = []
    for _ in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        out.append(f"M{x:.1f},{y:.1f} l{rnd.uniform(1, 3):.1f},{dl:.1f}")
    return " ".join(out)


# ================================================================== beasts
def wolf(e, alpha=False):
    a = e.a
    rnd = random.Random(3)
    fur, fur2, belly = ("alpha", "alpha2", "wolfbelly") if alpha else ("wolf", "wolf2", "wolfbelly")
    dx = -8 * a
    y0 = FY
    # body frame: shoulder / hip
    shx, shy = CX - 24 + dx, y0 - 58 + 7 * a
    hpx, hpy = CX + 30 + dx * 0.4, y0 - 60 + 1 * a
    # tail
    tb = (hpx + 8, hpy + 2)
    e.sh(smooth([(tb[0] - 4, tb[1] - 4), (tb[0] + 14, tb[1] + 2 - 6 * a), (tb[0] + 24, tb[1] + 22 - 10 * a), (tb[0] + 22, tb[1] + 34 - 12 * a),
                 (tb[0] + 14, tb[1] + 22 - 8 * a), (tb[0] + 2, tb[1] + 10)], t=0.45), fur, s=1.4)
    # far legs
    ffoot = (shx - 4 - 16 * a, y0 - 6)
    hfoot = (hpx + 4 + 10 * a, y0 - 6)
    e.limb([(shx + 4, shy + 10), (shx - 2 - 8 * a, shy + 32), ffoot], 6, 4, fur2)
    e.limb([(hpx + 2, hpy + 12), (hpx + 10 + 6 * a, hpy + 34), (hpx + 4 + 6 * a, hpy + 44), hfoot], 7, 4, fur2)
    # body
    body = [(shx - 14, shy - 4), (shx, shy - 14), (CX + dx * 0.7, shy - 10 + 2 * a), (hpx, hpy - 10), (hpx + 14, hpy - 2),
            (hpx + 12, hpy + 14), (hpx - 6, hpy + 22), (CX + dx * 0.7, hpy + 22 - 2 * a), (shx + 2, shy + 26), (shx - 14, shy + 14)]
    e.sh(smooth(body, t=0.42), fur, s=3)
    e.sh(smooth([(shx - 6, shy + 22), (CX + dx * 0.7, hpy + 20 - 2 * a), (hpx - 4, hpy + 20), (CX + dx * 0.7, hpy + 24), (shx, shy + 27)], t=0.4), belly, s=1, lw=1.0)
    e.det(fur_strokes(rnd, shx, hpx, shy - 6, shy + 12, 12), 0.7, 0.75)
    # near legs
    nf = (shx - 10 - 18 * a, y0 + 2)
    nh = (hpx - 2 + 12 * a, y0 + 3)
    e.limb([(shx + 2, shy + 14), (shx - 4 - 10 * a, shy + 36), (nf[0] + 2, nf[1] - 4)], 7.5, 4.5, fur)
    e.sh(ell(nf[0] - 1, nf[1] - 2, 6, 3), fur, s=0.6)
    e.limb([(hpx - 2, hpy + 6), (hpx + 8 + 6 * a, hpy + 32), (hpx + 2 + 8 * a, hpy + 44), (nh[0] + 1, nh[1] - 4)], 9, 4.5, fur)
    e.sh(ell(nh[0] - 1, nh[1] - 2, 6, 3), fur, s=0.6)
    # neck ruff + head
    hx, hy = shx - 22 - 6 * a, shy - 16 + 12 * a
    ruff = [(shx + 8, shy - 12), (shx - 2, shy - 20), (hx + 8, hy - 8), (hx - 2, hy + 8), (hx + 2, hy + 18), (shx - 6, shy + 22), (shx + 4, shy + 14)]
    e.sh(smooth(ruff, t=0.35), fur, s=2)
    e.det(" ".join(f"M{shx - 14 + i * 4:.1f},{shy - 8 + i * 4:.1f} l-4,4" for i in range(4)), 0.8, 0.8)
    # ears
    e.sh(poly([(hx + 4, hy - 9), (hx + 8, hy - 26), (hx + 13, hy - 7)]), fur2, s=1)
    e.sh(poly([(hx - 5, hy - 10), (hx - 4, hy - 27), (hx + 4, hy - 9)]), fur, s=1)
    # skull + muzzle
    open_ = a
    skull = [(hx + 12, hy - 8), (hx + 2, hy - 12), (hx - 8, hy - 9), (hx - 18, hy - 3), (hx - 30, hy + 1), (hx - 32, hy + 6),
             (hx - 26, hy + 8 - 1 * open_), (hx - 10, hy + 9), (hx + 4, hy + 12), (hx + 13, hy + 4)]
    if open_:
        jaw = [(hx - 10, hy + 9), (hx - 28, hy + 14), (hx - 26, hy + 18), (hx - 8, hy + 16)]
        e.fl(poly([(hx - 26, hy + 7), (hx - 10, hy + 9), (hx - 27, hy + 15)]), "#5a1610")
        e.sh(smooth(jaw, t=0.3), fur, s=0.8)
        e.ln(f"M{hx-25:.1f},{hy+8:.1f} l1,3 M{hx-20:.1f},{hy+9:.1f} l1,2.5 M{hx-24:.1f},{hy+14:.1f} l1,-3", "#f2ead2", 1.4)
    e.sh(smooth(skull, t=0.4), fur, s=2)
    e.sh(smooth([(hx - 12, hy + 4), (hx - 28, hy + 5), (hx - 24, hy + 8), (hx - 10, hy + 9)], t=0.4), belly, s=0.5, lw=0.9)
    e.fl(ell(hx - 31, hy + 2.5, 2.6, 2.2), INK)
    e.det(f"M{hx-14:.1f},{hy-6:.1f} q4,-3 8,-1", 0.8, 0.9)
    if alpha:
        e.eye(hx - 9, hy - 3, EMBER, EMBER_HOT, r=1.9, g=7)
        # scars: across the eye and down the flank
        e.ln(f"M{hx-15:.1f},{hy-10:.1f} l9,13", "#d8b0a0", 1.4, 0.95)
        e.ln(f"M{hx-15:.1f},{hy-10:.1f} l9,13", RUB, 0.6, 0.9)
        e.ln(f"M{CX+dx*0.7-4:.1f},{shy-8:.1f} l8,14 M{CX+dx*0.7+3:.1f},{shy-9:.1f} l8,14 M{CX+dx*0.7+10:.1f},{shy-8:.1f} l7,12", "#c8a090", 1.3, 0.9)
        # notched ear
        e.fl(poly([(hx - 3, hy - 22), (hx + 1, hy - 19), (hx - 3, hy - 17)]), "#20140c")
    else:
        e.eye(hx - 9, hy - 3, "#d8b040", "#fff0a0", r=1.6, g=4, gop=0.5)


def boar(e):
    a = e.a
    rnd = random.Random(5)
    dx = -8 * a
    y0 = FY
    shx, shy = CX - 20 + dx, y0 - 50 + 6 * a
    hpx, hpy = CX + 30 + dx * 0.4, y0 - 44
    # tail
    e.ln(f"M{hpx+14:.1f},{hpy-6:.1f} q8,2 6,10 q-3,3 2,6", INK, 2.2)
    # far legs
    e.limb([(shx + 4, shy + 18), (shx - 2 - 8 * a, y0 - 14), (shx - 2 - 10 * a, y0 - 6)], 6, 4, "boar2")
    e.limb([(hpx + 4, hpy + 10), (hpx + 8 + 6 * a, y0 - 16), (hpx + 6 + 8 * a, y0 - 6)], 6.5, 4, "boar2")
    body = [(shx - 18, shy + 2), (shx - 8, shy - 18), (CX + dx * 0.6, shy - 20), (hpx, hpy - 18), (hpx + 18, hpy - 6), (hpx + 16, hpy + 16),
            (CX + dx * 0.6, hpy + 24), (shx, shy + 34), (shx - 18, shy + 24)]
    e.sh(smooth(body, t=0.42), "boar", s=3)
    e.det(fur_strokes(rnd, shx - 6, hpx + 10, shy - 8, hpy + 14, 18, 4), 0.7, 0.7)
    # bristly mane along the spine
    mane = []
    for i in range(9):
        t = i / 8
        x = L(shx - 8, hpx, t)
        y = L(shy - 18, hpy - 16, t) - 2 * math.sin(t * math.pi)
        mane += [(x - 3, y + 3), (x, y - 7 + (i % 2) * 2)]
    mane += [(hpx + 4, hpy - 12), (shx - 10, shy - 10)]
    e.sh(poly(mane), "boar2", s=0.8)
    # near legs
    nf = (shx - 6 - 14 * a, y0 + 2)
    e.limb([(shx + 2, shy + 22), (shx - 4 - 8 * a, y0 - 10), (nf[0], nf[1] - 3)], 7.5, 4.5, "boar")
    e.sh(ell(nf[0], nf[1] - 1.5, 4.5, 2.6), "boar2", s=0.5)
    nh = (hpx + 2 + 10 * a, y0 + 3)
    e.limb([(hpx, hpy + 10), (hpx + 4 + 6 * a, y0 - 12), (nh[0], nh[1] - 3)], 8.5, 4.5, "boar")
    e.sh(ell(nh[0], nh[1] - 1.5, 4.5, 2.6), "boar2", s=0.5)
    # head: low wedge with snout disc
    hx, hy = shx - 22 - 4 * a, shy + 6 + 8 * a
    head = [(hx + 22, hy - 18), (hx + 6, hy - 16), (hx - 12, hy - 6), (hx - 20, hy + 2), (hx - 18, hy + 10), (hx - 2, hy + 14), (hx + 18, hy + 16)]
    e.sh(poly(head), "boar", s=2)
    e.sh(poly([(hx + 6, hy - 14), (hx + 4, hy - 28), (hx + 14, hy - 16)]), "boar2", s=0.8)   # ear
    e.sh(ell(hx - 20, hy + 5, 4, 6.5), "snout", s=0.6)
    e.fl(ell(hx - 21, hy + 3, 0.9, 1.4) + ell(hx - 20.5, hy + 7.5, 0.9, 1.4), INK)
    # tusks
    e.sh(smooth([(hx - 10, hy + 10), (hx - 20, hy + 5), (hx - 28, hy - 10), (hx - 22, hy + 1), (hx - 12, hy + 14)], t=0.4), "bone", s=0.5, lw=1.0)
    e.sh(smooth([(hx - 4, hy + 12), (hx - 9, hy + 6), (hx - 12, hy - 2), (hx - 8, hy + 6), (hx - 2, hy + 14)], t=0.4), "bone", s=0.5, lw=0.9)
    e.eye(hx - 5, hy - 6, EMBER, EMBER_HOT, r=1.4, g=4, gop=0.55)
    e.det(f"M{hx-10:.1f},{hy-9:.1f} l8,-1", 0.9, 0.9)


def spider(e, brood=False):
    a = e.a
    dx = -6 * a
    y0 = FY
    ccx, ccy = CX - 18 + dx, y0 - 30 - 6 * a           # cephalothorax
    abx, aby = CX + 20 + dx * 0.3, y0 - 40 + 2 * a       # abdomen
    ar = (36, 29) if brood else (31, 25)
    role, role2 = ("brood", "chitin2") if brood else ("chitin", "chitin2")
    # legs: attach offset from the cephalothorax, knee, foot (absolute offsets from CX / FY); far side first
    far = [((-8, -6), (-44, -62), (-66, -12)), ((-4, -8), (-24, -68), (-40, -14)), ((4, -8), (14, -68), (30, -14)), ((8, -6), (40, -60), (60, -12))]
    near = [((-10, 4), (-50, -46), (-72, 0)), ((-4, 6), (-30, -50), (-46, 4)), ((4, 6), (8, -50), (30, 4)), ((8, 4), (40, -44), (64, 0))]
    if a:
        near[0] = ((-10, 0), (-50, -78), (-72, -64))
        far[0] = ((-8, -6), (-38, -88), (-64, -82))

    def leg(att, kn, ft, rl, w):
        p0 = (ccx + att[0], ccy + att[1])
        k = (CX + kn[0] + dx, FY + kn[1] - 2 * a)
        f = (CX + ft[0] + dx * (0.3 if ft[1] > -20 else 1), FY + ft[1])
        mid = (L(k[0], f[0], 0.45) + (4 if f[0] > k[0] else -4), L(k[1], f[1], 0.3))
        e.limb([p0, k, mid, f], w, w * 0.4, rl, s=0.9)

    w = 4.0 if brood else 3.6
    for att, kn, ft in far:
        leg(att, kn, ft, role2, w * 0.9)
    e.sh(ell(abx, aby, ar[0], ar[1]), role, s=4)
    if brood:
        e.fl(poly([(abx - 9, aby - 16), (abx + 7, aby - 16), (abx, aby - 5)]) + poly([(abx - 8, aby + 5), (abx + 8, aby + 5), (abx, aby - 6)]), RUB, 0.95)
        e.ln(f"M{abx-22:.1f},{aby-14:.1f} q10,-8 26,-4 M{abx-26:.1f},{aby+8:.1f} q16,10 36,2", INK, 0.6, 0.6)
        for (ex, ey, r) in ((abx + 10, aby - 24, 9.5), (abx + 26, aby - 14, 8.5), (abx - 8, aby - 27, 7.5), (abx + 34, aby + 4, 9), (abx + 22, aby + 20, 7.5)):
            e.sh(ell(ex, ey, r, r * 0.85), "egg", s=1.2)
            e.ln(f"M{ex-r*0.8:.1f},{ey:.1f} q{r*0.8:.1f},{-r*0.5:.1f} {r*1.6:.1f},0", "#8e866c", 0.6, 0.8)
        e.ln(f"M{abx-4:.1f},{aby-30:.1f} l30,28 M{abx+16:.1f},{aby-26:.1f} l-12,44 M{abx+38:.1f},{aby-6:.1f} l-28,6", "#f4eedc", 0.6, 0.6)
    else:
        e.fl(ell(abx - 2, aby - 9, 8, 4.5) + ell(abx + 9, aby + 2, 5.5, 3.2), "#8a6a4a", 0.75)
        e.det(f"M{abx-18:.1f},{aby-8:.1f} q14,-8 30,0 M{abx-20:.1f},{aby+5:.1f} q16,-6 34,2", 0.7, 0.6)
    e.sh(ell(ccx, ccy, 18, 14), role, s=2.4)
    fy = ccy + 12 + 3 * a
    e.sh(smooth([(ccx - 14, ccy + 4), (ccx - 19, fy + 5), (ccx - 14, fy + 7), (ccx - 9, ccy + 7)], t=0.4), role2, s=0.5)
    e.sh(smooth([(ccx - 6, ccy + 7), (ccx - 9, fy + 7), (ccx - 4, fy + 8), (ccx - 1, ccy + 8)], t=0.4), role2, s=0.5)
    for (x, y, r) in ((ccx - 11, ccy - 5, 2.3), (ccx - 4, ccy - 7, 2.3), (ccx - 15, ccy - 0.5, 1.5), (ccx + 1, ccy - 3, 1.5)):
        e.eye(x, y, "#e04a2a", "#ffb080", r=r, g=5, gop=0.5)
    for att, kn, ft in near:
        leg(att, kn, ft, role, w)


# ================================================================== humanoids
class Biped:
    """Three-quarter, facing screen-left.  Near arm = figure's right (screen-right shoulder, drawn last)."""

    def __init__(self, e, H=160, hr=13.5, sw=22, hw=16, lw=7.5, ar=6.0, hunch=0.0, lunge=10):
        self.e, a = e, e.a
        self.a = a
        self.H, self.hr, self.sw, self.hw, self.lw, self.ar = H, hr, sw, hw, lw, ar
        d = lunge * a
        self.nfoot = (CX - 8 - 14 * a, FY + 3)
        self.ffoot = (CX + 10 + 10 * a, FY - 3)
        self.hip = (CX + 1 - d * 0.35, FY - H * 0.46 + 4 * a)
        self.S = FY - H + 2 * hr + 3 + 5 * a + hunch * 6
        self.sx = CX - 1 - d * 0.9 - hunch * 6      # torso centre at the shoulders
        self.head = (self.sx - 3 - d * 0.25 - hunch * 6, FY - H + hr + 5 * a + hunch * 10)

    def legs(self, role="trouser", boot="boot", far=True):
        e, a = self.e, self.a
        hx, hy = self.hip
        if far:
            fx, fy = self.ffoot
            kx = L(hx + 7, fx, 0.5) + 3 + 4 * a
            e.limb([(hx + 7, hy), (kx, L(hy, fy, 0.5)), (fx, fy - 8)], self.lw, self.lw * 0.8, role, s=1.4)
            e.sh(smooth([(fx - 9, fy - 10), (fx + 5, fy - 11), (fx + 6, fy - 2), (fx - 11, fy), (fx - 12, fy - 4)], t=0.4), boot, s=1)
        else:
            fx, fy = self.nfoot
            kx = L(hx - 5, fx, 0.5) - 2 - 4 * a
            e.limb([(hx - 5, hy + 2), (kx, L(hy, fy, 0.5) - 3 * a), (fx, fy - 9)], self.lw * 1.05, self.lw * 0.85, role, s=1.4)
            e.sh(smooth([(fx - 9, fy - 12), (fx + 6, fy - 12), (fx + 7, fy - 2), (fx - 12, fy), (fx - 13, fy - 5)], t=0.4), boot, s=1)

    def torso(self, role, s=3, flare=0.0, bottom=None):
        hx, hy = self.hip
        S, sx, sw, hw = self.S, self.sx, self.sw, self.hw
        bot = hy + 6 if bottom is None else bottom
        pts = [(sx - sw * 0.75, S + 1), (sx - sw * 0.2, S - 4), (sx + sw * 0.9, S), (sx + sw, S + 8), (L(sx + sw * 0.85, hx + hw, 0.5), L(S, hy, 0.5)),
               (hx + hw + flare, bot), (hx - hw * 0.8 - flare, bot + 2), (L(sx - sw * 0.7, hx - hw * 0.8, 0.5), L(S, hy, 0.55))]
        self.e.sh(smooth(pts, t=0.4), role, s=s)

    def shoulder(self, near=True):
        if near:
            return (self.sx + self.sw * 0.82, self.S + 5)
        return (self.sx - self.sw * 0.62, self.S + 4)

    def arm(self, near, hand, role, handrole="skin", elbow=None, r=None):
        e = self.e
        sx, sy = self.shoulder(near)
        hx, hy = hand
        r = r or self.ar
        if elbow is None:
            elbow = (L(sx, hx, 0.5) + (5 if near else -3), L(sy, hy, 0.5) + 2)
        e.limb([(sx, sy), elbow, (hx, hy)], r, r * 0.85, role, s=1.4)
        e.sh(ell(hx, hy, r * 0.85, r * 0.8), handrole, s=0.6)

    def head_shape(self, role, rx=None, ry=None):
        hx, hy = self.head
        rx = rx or self.hr
        ry = ry or self.hr * 1.12
        d = smooth([(hx - rx * 0.95, hy - ry * 0.2), (hx - rx * 0.6, hy - ry * 0.9), (hx + rx * 0.3, hy - ry), (hx + rx, hy - ry * 0.3),
                    (hx + rx * 0.9, hy + ry * 0.5), (hx + rx * 0.2, hy + ry), (hx - rx * 0.6, hy + ry * 0.8), (hx - rx * 1.08, hy + ry * 0.25)], t=0.45)
        self.e.sh(d, role, s=2)
        return d


def blade(e, hx, hy, ang, ln, w=3.2, role="metal", guard="darkiron", curve=0.0, notched=False):
    """sword from a hand at (hx,hy) pointing at angle ang (deg, 0 = screen-right, 180 = left)."""
    c, s = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    nx, ny = -s, c
    tip = (hx + c * ln, hy + s * ln)
    b0 = (hx + c * 6, hy + s * 6)
    mid = (L(b0[0], tip[0], 0.55) + nx * curve, L(b0[1], tip[1], 0.55) + ny * curve)
    pts = [(b0[0] + nx * w, b0[1] + ny * w), (mid[0] + nx * w * 0.9, mid[1] + ny * w * 0.9), tip,
           (mid[0] - nx * w * 0.8, mid[1] - ny * w * 0.8), (b0[0] - nx * w, b0[1] - ny * w)]
    if notched:
        n1 = (L(b0[0], tip[0], 0.45), L(b0[1], tip[1], 0.45))
        pts.insert(4, (n1[0] - nx * w * 0.2, n1[1] - ny * w * 0.2))
    e.sh(poly(pts) if not curve else smooth(pts, t=0.3), role, s=0.8, lw=1.4)
    e.ln(f"M{b0[0]:.1f},{b0[1]:.1f} L{L(b0[0], tip[0], 0.85):.1f},{L(b0[1], tip[1], 0.85):.1f}", INK, 0.5, 0.45)
    # guard + grip + pommel
    g = 7.5
    e.sh(capsule((hx + c * 5 + nx * g, hy + s * 5 + ny * g), (hx + c * 5 - nx * g, hy + s * 5 - ny * g), 1.9), guard, s=0.4)
    e.sh(capsule((hx - c * 5, hy - s * 5), (hx + c * 4, hy + s * 4), 2.2), "leather", s=0.3)
    e.sh(ell(hx - c * 7, hy - s * 7, 2.6, 2.6), guard, s=0.3)
    return tip


def goblin(e):
    a = e.a
    b = Biped(e, H=104, hr=15, sw=15, hw=12, lw=5.5, ar=4.4, hunch=0.8, lunge=9)
    hx0, hy0 = b.head
    # far arm (claw out)
    fh = (b.sx - 22 - 6 * a, b.S + 26 - 6 * a)
    b.arm(False, fh, "gob", "gob")
    b.legs("gob", "gob", far=True)
    b.legs("gob", "gob", far=False)
    # ragged tunic with zig-zag hem
    hx, hy = b.hip
    S, sx, sw = b.S, b.sx, b.sw
    hem = []
    for i in range(7):
        t = i / 6
        hem.append((L(hx + 15, hx - 15, t), hy + 12 + (5 if i % 2 else 0)))
    pts = [(sx - sw * 0.8, S + 2), (sx + sw * 0.9, S), (sx + sw, S + 10), (hx + 15, hy + 10)] + hem + [(hx - 15, hy + 6), (sx - sw * 0.9, S + 16)]
    e.sh(poly(pts), "rag", s=2.6)
    e.sh(capsule((sx - 10, hy - 6), (sx + 14, hy - 4), 2.2), "strap", s=0.4)
    e.ln(f"M{sx-4:.1f},{S+8:.1f} l3,9 M{sx+8:.1f},{S+10:.1f} l-2,8", INK, 0.7, 0.7)
    # head: big, long nose, huge ears
    hx, hy = b.head
    hr = b.hr
    e.sh(poly([(hx + hr * 0.6, hy - 4), (hx + hr + 16, hy - 14 + 2 * a), (hx + hr * 0.7, hy + 5)]), "gob", s=0.8)    # far-right ear
    b.head_shape("gob", rx=hr, ry=hr * 0.92)
    e.sh(poly([(hx - hr * 0.6, hy - 6), (hx - hr - 14, hy - 16 + 2 * a), (hx - hr * 0.5, hy + 2)]), "gob", s=0.8)     # near-left ear
    e.sh(smooth([(hx - hr * 0.7, hy - 1), (hx - hr - 7, hy + 5), (hx - hr * 0.6, hy + 7)], t=0.3), "gob", s=0.4, lw=1.0)
    e.ln(f"M{hx-hr*0.75:.1f},{hy+9:.1f} q5,3 11,0", INK, 0.9)
    e.ln(f"M{hx-hr*0.6:.1f},{hy+9.5:.1f} l1,2.5 M{hx-hr*0.2:.1f},{hy+10:.1f} l0.5,-2.5", "#f2ead2", 1.0)
    e.eye(hx - hr * 0.55, hy - 3, "#e8c040", "#fff4a0", r=1.7, g=4, gop=0.55)
    e.eye(hx + hr * 0.05, hy - 3.5, "#e8c040", "#fff4a0", r=1.5, g=4, gop=0.45)
    e.det(f"M{hx-hr*0.8:.1f},{hy-7:.1f} l7,2 M{hx-hr*0.1:.1f},{hy-7.5:.1f} l6,-1", 0.9)
    # near arm + crude notched blade
    if a:
        nh = (b.sx - 18, b.S + 6)
        ang = 200
    else:
        nh = (b.sx + sw + 4, b.S + 26)
        ang = 235
    b.arm(True, nh, "gob", "gob")
    blade(e, nh[0], nh[1], ang, 26, w=4.0, role="rustiron", guard="wood", notched=True)


def bandit(e):
    a = e.a
    b = Biped(e, H=158, hr=13.5, sw=21, hw=15, lw=7.5, ar=5.8, lunge=11)
    S, sx, sw = b.S, b.sx, b.sw
    hx, hy = b.hip
    # cloak behind
    e.sh(smooth([(sx - sw * 0.6, S - 2), (sx + sw * 1.2, S + 2), (sx + sw * 1.5 + 6 * a, FY - 24), (sx + sw * 1.1 + 8 * a, FY - 12),
                 (sx - 2, FY - 18), (sx - sw * 0.9, S + 20)], t=0.42), "hood", s=3)
    fh = (b.sx - 20 - 4 * a, b.S + 34 - 8 * a)
    b.arm(False, fh, "jerkin", "leather")
    # dagger in the off hand
    if True:
        blade(e, fh[0], fh[1], 160 - 20 * a, 12, w=2.0, role="metal", guard="darkiron")
    b.legs("brown", "boot", far=True)
    b.legs("brown", "boot", far=False)
    b.torso("jerkin", s=3, bottom=hy + 10)
    e.sh(capsule((hx - 15, hy - 4), (hx + 15, hy - 2), 2.4), "strap", s=0.4)
    e.sh(ell(hx + 2, hy - 3, 3, 2.6), "gold", s=0.3)
    e.ln(f"M{sx-8:.1f},{S+3:.1f} L{hx+8:.1f},{hy-4:.1f}", INK, 1.6, 0.85)
    # hood + masked face
    px, py = b.head
    hr = b.hr
    e.sh(smooth([(px - hr * 1.15, py + 2), (px - hr * 0.8, py - hr * 1.2), (px + hr * 0.4, py - hr * 1.4), (px + hr * 1.35, py - hr * 0.4),
                 (px + hr * 1.5, py + hr * 1.1), (px + hr * 0.4, py + hr * 1.4), (px - hr * 0.9, py + hr * 1.1)], t=0.45), "hood", s=2.2)
    e.fl(smooth([(px - hr * 0.95, py - 2), (px - hr * 0.5, py - hr * 0.7), (px + hr * 0.4, py - hr * 0.6), (px + hr * 0.5, py + 4), (px - hr * 0.9, py + 6)], t=0.45), "#1a120c")
    e.sh(smooth([(px - hr * 0.95, py - 0.5), (px + hr * 0.5, py), (px + hr * 0.45, py + hr * 0.8), (px - hr * 0.8, py + hr * 0.7)], t=0.35), "mask", s=0.6)
    e.eye(px - hr * 0.55, py - 4, "#d8b878", "#f4e4b8", r=1.3, g=2.5, gop=0.4)
    e.eye(px - hr * 0.0, py - 4.5, "#d8b878", "#f4e4b8", r=1.2, g=2.5, gop=0.35)
    # near arm: short sword
    if a:
        nh = (b.sx - 16, b.S + 14)
        ang = 192
    else:
        nh = (b.sx + sw + 6, b.S + 38)
        ang = 245
    b.arm(True, nh, "jerkin", "leather")
    blade(e, nh[0], nh[1], ang, 30, w=3.0)


def captain(e):
    a = e.a
    b = Biped(e, H=166, hr=13.5, sw=23, hw=16, lw=7.8, ar=6.2, lunge=12)
    S, sx, sw = b.S, b.sx, b.sw
    hx, hy = b.hip
    fh = (b.sx - 14 - 2 * a, b.hip[1] - 8 - 4 * a)      # far hand on hip / forward
    b.arm(False, fh, "coat", "leather")
    b.legs("hat", "boot", far=True)
    b.legs("hat", "boot", far=False)
    # tall boot cuffs
    for (fx, fy) in (b.ffoot, b.nfoot):
        e.sh(ell(fx - 1, fy - 22, 8.5, 4), "boot", s=0.5)
    # long coat flaring to the knees
    bot = FY - 40
    coat = [(sx - sw * 0.8, S + 1), (sx + sw * 0.9, S - 1), (sx + sw * 1.05, S + 10), (hx + sw * 0.9, hy), (hx + sw * 1.25 + 4 * a, bot),
            (hx + 4, bot + 6), (hx - 8, bot + 3), (hx - sw * 0.9 - 6 * a, bot - 2), (hx - sw * 0.75, hy - 4), (sx - sw * 0.9, S + 18)]
    e.sh(smooth(coat, t=0.4), "coat", s=3.4)
    # shirt / waistcoat opening + sash + lapel
    e.sh(smooth([(sx - 10, S), (sx - 2, S), (hx - 2, hy - 6), (hx - 10, hy - 4)], t=0.3), "linen", s=0.8, lw=1.0)
    e.sh(smooth([(hx - sw * 0.85, hy - 14), (hx + sw * 0.95, hy - 12), (hx + sw * 0.95, hy - 4), (hx - sw * 0.85, hy - 5)], t=0.3), "sash", s=0.8)
    e.sh(poly([(hx + 6, hy - 6), (hx + 2, hy + 14), (hx + 8, hy + 12), (hx + 10, hy - 5)]), "sash", s=0.4)
    e.ln(f"M{sx-2:.1f},{S+2:.1f} l-4,18 M{hx-10:.1f},{hy+2:.1f} l-6,{bot-hy-6:.1f}", INK, 0.9, 0.8)
    for i in range(3):
        e.fl(ell(sx + 3, S + 8 + i * 8, 1.4, 1.4), GILT)
    # head: beard, wide hat with feather
    px, py = b.head
    hr = b.hr
    b.head_shape("skin")
    e.sh(smooth([(px - hr * 0.9, py + 4), (px - hr * 0.5, py + 3), (px - hr * 0.1, py + 4.5), (px - hr * 0.3, py + hr * 1.15), (px - hr * 0.7, py + hr * 1.0)], t=0.45), "hair", s=0.6,
         fill_override="#3a2a20")
    e.ln(f"M{px-hr*1.0:.1f},{py+4:.1f} q{hr*0.5:.1f},-2 {hr*0.95:.1f},0.5", "#3a2a20", 1.6)
    e.fl(ell(px - hr * 0.55, py - 2, 1.6, 1.4) + ell(px - hr * 0.05, py - 2.5, 1.4, 1.3), INK)
    e.ln(f"M{px-hr*0.9:.1f},{py-6:.1f} l5,1 M{px-hr*0.25:.1f},{py-6.5:.1f} l5,0", INK, 1.0)
    # hat
    e.sh(ell(px + 1, py - hr * 0.62, hr * 1.9, hr * 0.48), "hat", s=1.2)
    e.sh(smooth([(px - hr * 0.85, py - hr * 0.6), (px - hr * 0.7, py - hr * 1.6), (px + hr * 0.2, py - hr * 1.9), (px + hr * 0.95, py - hr * 1.5), (px + hr * 0.95, py - hr * 0.55)], t=0.4), "hat", s=1.2)
    e.sh(capsule((px - hr * 0.85, py - hr * 0.8), (px + hr * 0.95, py - hr * 0.78), 1.8), "sash", s=0.3)
    e.sh(smooth([(px + hr * 0.6, py - hr * 0.9), (px + hr * 1.7, py - hr * 1.9), (px + hr * 2.6, py - hr * 2.15), (px + hr * 2.1, py - hr * 1.6), (px + hr * 0.9, py - hr * 0.8)], t=0.45),
         "linen", s=0.6, lw=1.0)
    e.ln(f"M{px+hr*0.8:.1f},{py-hr*0.9:.1f} Q{px+hr*1.7:.1f},{py-hr*1.7:.1f} {px+hr*2.5:.1f},{py-hr*2.1:.1f}", INK, 0.6, 0.8)
    # near arm: sabre
    if a:
        nh = (b.sx - 18, b.S + 12)
        ang = 188
    else:
        nh = (b.sx + sw + 8, b.S + 40)
        ang = 252
    b.arm(True, nh, "coat", "leather")
    tip = blade(e, nh[0], nh[1], ang, 44, w=2.8, role="silver", guard="gold", curve=5)
    e.sh(smooth([(nh[0] - 4, nh[1] - 6), (nh[0] + 6, nh[1] - 6), (nh[0] + 7, nh[1] + 4), (nh[0] - 3, nh[1] + 4)], t=0.5), "gold", s=0.3, lw=0.9)


def skeleton(e):
    a = e.a
    b = Biped(e, H=156, hr=12.5, sw=18, hw=12, lw=3.4, ar=3.0, lunge=10)
    S, sx, sw = b.S, b.sx, b.sw
    hx, hy = b.hip
    # far arm holding a round shield forward
    fh = (b.sx - 18 - 8 * a, b.S + 26 - 4 * a)
    b.arm(False, fh, "bone", "bone", r=3.0)
    b.legs("bone", "bone", far=True)
    b.legs("bone", "bone", far=False)
    # tattered loincloth + pelvis
    e.sh(poly([(hx - 12, hy - 4), (hx + 13, hy - 4), (hx + 10, hy + 14), (hx + 4, hy + 8), (hx, hy + 18), (hx - 5, hy + 9), (hx - 11, hy + 13)]), "rag2", s=1)
    e.sh(smooth([(hx - 11, hy - 8), (hx + 12, hy - 8), (hx + 8, hy + 1), (hx - 8, hy + 1)], t=0.4), "bone", s=0.6)
    # spine + ribcage
    e.sh(capsule((sx + 2, S + 6), (hx + 1, hy - 8), 2.6), "bone", s=0.4)
    rib = smooth([(sx - sw * 0.6, S + 4), (sx + sw * 0.85, S + 2), (sx + sw * 0.75, S + 26), (sx + 2, S + 32), (sx - sw * 0.55, S + 24)], t=0.45)
    e.fl(rib, "#20140c", 0.85)
    for i in range(4):
        y = S + 6 + i * 6.5
        e.sh(smooth([(sx - sw * 0.55 + i, y), (sx + sw * 0.8 - i, y - 2), (sx + sw * 0.8 - i, y + 1.6), (sx - sw * 0.55 + i, y + 3)], t=0.4), "bone", s=0.3, lw=0.9)
    e.sh(capsule((sx - sw * 0.7, S + 1), (sx + sw * 0.95, S - 1), 2.6), "bone", s=0.3)       # collarbones
    # skull
    px, py = b.head
    hr = b.hr
    b.head_shape("bone", rx=hr, ry=hr * 1.05)
    e.sh(smooth([(px - hr * 0.9, py + 3), (px + hr * 0.3, py + 5), (px + hr * 0.2, py + hr * 1.2), (px - hr * 0.7, py + hr * 1.1)], t=0.3), "bone", s=0.4, lw=1.0)
    e.fl(ell(px - hr * 0.55, py - 1, 3.4, 3.8) + ell(px + hr * 0.1, py - 1.5, 3.0, 3.6), "#140c06")
    e.eye(px - hr * 0.55, py - 0.5, EMBER, EMBER_HOT, r=1.1, g=4, gop=0.6)
    e.eye(px + hr * 0.1, py - 1, EMBER, EMBER_HOT, r=1.0, g=3.5, gop=0.5)
    e.fl(poly([(px - hr * 0.35, py + 4), (px - hr * 0.15, py + 4), (px - hr * 0.25, py + 8)]), "#140c06")
    e.ln(" ".join(f"M{px-hr*0.75+i*3.2:.1f},{py+hr*0.75:.1f} l0,3" for i in range(5)), INK, 0.8)
    # shield (far arm) over the body's left
    cx_, cy_ = fh[0] - 2, fh[1] - 2
    e.sh(ell(cx_, cy_, 15, 17), "shieldwood", s=2)
    e.ln(f"M{cx_-15:.1f},{cy_:.1f} L{cx_+15:.1f},{cy_:.1f} M{cx_:.1f},{cy_-17:.1f} L{cx_:.1f},{cy_+17:.1f}", INK, 0.6, 0.5)
    e.o.append(lin(ell(cx_, cy_, 14, 16), "#6e5a4a", 2.2, 0.9))
    e.sh(ell(cx_ - 1, cy_ - 1, 4.5, 5), "rust", s=0.5)
    e.fl(poly([(cx_ + 6, cy_ + 9), (cx_ + 14, cy_ + 5), (cx_ + 12, cy_ + 12)]), "#20140c", 0.8)      # split
    # near arm: rusty sword
    if a:
        nh = (b.sx - 16, b.S + 6)
        ang = 196
    else:
        nh = (b.sx + sw + 6, b.S + 34)
        ang = 240
    b.arm(True, nh, "bone", "bone", r=3.0)
    blade(e, nh[0], nh[1], ang, 34, w=3.0, role="rust", guard="rustiron", notched=True)


def wight(e):
    a = e.a
    b = Biped(e, H=172, hr=12.5, sw=19, hw=14, lw=6, ar=4.6, hunch=0.5, lunge=10)
    S, sx, sw = b.S, b.sx, b.sw
    hx, hy = b.hip
    # far arm reaching, clawed
    fh = (b.sx - 26 - 10 * a, b.S + 30 - 14 * a)
    b.arm(False, fh, "robe", "gaunt", r=4.2)
    for i in range(3):
        e.ln(f"M{fh[0]-2:.1f},{fh[1]+i*2-2:.1f} l-7,{i*3-1:.1f}", "#cfd0c4", 1.1)
    # tattered robe to the ground (no legs)
    hem = []
    for i in range(9):
        t = i / 8
        hem.append((L(CX + 26 + 6 * a, CX - 24 - 10 * a, t), FY - 2 + (6 if i % 2 else 0) - 3 * a * (1 - t)))
    robe = [(sx - sw * 0.8, S + 2), (sx + sw * 0.9, S - 1), (sx + sw * 1.1, S + 14), (hx + sw * 1.1, hy + 10), (CX + 26 + 6 * a, FY - 6)] + hem + \
           [(CX - 22 - 10 * a, FY - 12), (hx - sw * 0.9, hy + 6), (sx - sw * 0.9, S + 20)]
    e.sh(smooth(robe, t=0.3), "robe", s=3.4)
    e.ln(f"M{sx+4:.1f},{S+10:.1f} L{CX-6-6*a:.1f},{FY-6:.1f} M{sx+14:.1f},{S+14:.1f} L{CX+12:.1f},{FY-8:.1f}", INK, 0.9, 0.7)
    e.sh(capsule((hx - 14, hy - 6), (hx + 16, hy - 4), 2), "rustiron", s=0.3)
    # head: gaunt face inside a tattered hood
    px, py = b.head
    hr = b.hr
    e.sh(smooth([(px - hr * 1.2, py + 4), (px - hr * 0.8, py - hr * 1.3), (px + hr * 0.5, py - hr * 1.5), (px + hr * 1.5, py - hr * 0.3),
                 (px + hr * 1.6, py + hr * 1.6), (px + hr * 0.2, py + hr * 1.3), (px - hr * 1.0, py + hr * 1.4)], t=0.42), "robe", s=2.4)
    e.fl(smooth([(px - hr * 1.0, py), (px - hr * 0.5, py - hr * 0.9), (px + hr * 0.5, py - hr * 0.8), (px + hr * 0.6, py + hr * 0.9), (px - hr * 0.8, py + hr * 1.0)], t=0.45), "#0e0a0c")
    e.sh(smooth([(px - hr * 0.9, py - 2), (px - hr * 0.3, py - hr * 0.6), (px + hr * 0.2, py - hr * 0.3), (px + hr * 0.1, py + hr * 0.8), (px - hr * 0.6, py + hr * 0.9)], t=0.45), "gaunt", s=0.8)
    e.fl(ell(px - hr * 0.55, py - 1, 2.6, 2.2) + ell(px - hr * 0.0, py - 1.5, 2.3, 2.0), "#0e0a0c")
    e.eye(px - hr * 0.55, py - 1, COLD, COLD_HOT, r=1.3, g=7, gop=0.85)
    e.eye(px - hr * 0.0, py - 1.5, COLD, COLD_HOT, r=1.2, g=6, gop=0.75)
    e.ln(f"M{px-hr*0.7:.1f},{py+hr*0.55:.1f} l9,0", INK, 0.8)
    # near arm: long claws
    if a:
        nh = (b.sx - 20, b.S + 18)
    else:
        nh = (b.sx + sw + 6, b.S + 40)
    b.arm(True, nh, "robe", "gaunt", r=4.6)
    for i in range(3):
        dxl = -9 if a else -2
        e.ln(f"M{nh[0]-1:.1f},{nh[1]+i*2.4-2:.1f} l{dxl:.1f},{4+i*1.5:.1f}", "#dcdcd0", 1.2)
    e.em.append(glow(e.P, px - hr * 0.3, py, 18, COLD, 0.22))


def barrow_lord(e):
    a = e.a
    b = Biped(e, H=178, hr=13.5, sw=26, hw=18, lw=8.5, ar=7.0, lunge=12)
    S, sx, sw = b.S, b.sx, b.sw
    hx, hy = b.hip
    # tattered cloak
    hem = []
    for i in range(7):
        t = i / 6
        hem.append((L(sx + sw * 1.6 + 8 * a, sx - 6, t), FY - 22 + (7 if i % 2 else 0)))
    e.sh(poly([(sx - sw * 0.6, S - 2), (sx + sw * 1.1, S)] + hem + [(sx - sw * 0.6, S + 30)]), "tatter", s=3)
    fh = (b.sx - 6 - 10 * a, hy - 8 - 10 * a)
    b.arm(False, fh, "armor", "darkiron", r=6.5)
    b.legs("darkiron", "armor", far=True)
    b.legs("darkiron", "armor", far=False)
    # greaves / knees
    for (fx, fy), sgn in ((b.ffoot, 1), (b.nfoot, -1)):
        e.sh(ell(L(hx, fx, 0.5) + sgn * 2, L(hy, fy, 0.5), 6.5, 5.5), "armor", s=0.6)
    # armoured torso + skirt of plates
    e.sh(poly([(hx - 18, hy - 6), (hx + 20, hy - 6), (hx + 24, hy + 20), (hx + 8, hy + 22), (hx - 4, hy + 24), (hx - 20, hy + 18)]), "darkiron", s=1.6)
    e.ln(f"M{hx-2:.1f},{hy-4:.1f} l-1,26 M{hx+10:.1f},{hy-4:.1f} l1,24", INK, 0.8, 0.8)
    b.torso("armor", s=3.4, bottom=hy)
    e.ln(f"M{sx-sw*0.5:.1f},{S+18:.1f} Q{sx+6:.1f},{S+26:.1f} {sx+sw*0.95:.1f},{S+16:.1f} M{sx-sw*0.4:.1f},{S+30:.1f} Q{sx+6:.1f},{S+38:.1f} {sx+sw:.1f},{S+28:.1f}", INK, 0.9, 0.85)
    e.ln(f"M{sx:.1f},{S+2:.1f} L{hx-2:.1f},{hy-4:.1f}", GILT, 1.0, 0.6)
    # pauldrons
    for near in (False, True):
        x, y = b.shoulder(near)
        e.sh(smooth([(x - 10, y + 6), (x - 8, y - 6), (x + 4, y - 9), (x + 12, y - 2), (x + 11, y + 8), (x, y + 10)], t=0.45), "armor", s=1.6)
    # helm with crown, cold eyes through the visor
    px, py = b.head
    hr = b.hr
    b.head_shape("armor", rx=hr * 1.05, ry=hr * 1.15)
    e.fl(smooth([(px - hr * 1.05, py - 3), (px + hr * 0.4, py - 4), (px + hr * 0.4, py + 0.5), (px - hr * 1.05, py + 0.5)], t=0.2), "#0c0a0c")
    e.ln(f"M{px-hr*0.4:.1f},{py+1:.1f} l0,{hr*0.8:.1f}", INK, 1.0)
    e.eye(px - hr * 0.65, py - 1.5, COLD, COLD_HOT, r=1.3, g=7, gop=0.9)
    e.eye(px - hr * 0.1, py - 1.8, COLD, COLD_HOT, r=1.2, g=6, gop=0.8)
    crown = [(px - hr * 1.0, py - hr * 0.75)]
    for i in range(5):
        t = i / 4
        x = L(px - hr * 1.0, px + hr * 0.95, t)
        crown += [(x - 1.5, py - hr * 0.95), (x, py - hr * 1.65), (x + 1.5, py - hr * 0.95)]
    crown += [(px + hr * 0.95, py - hr * 0.7)]
    e.sh(poly(crown), "gold", s=0.6, lw=1.1)
    e.fl(ell(px - hr * 0.1, py - hr * 0.85, 1.6, 1.4), "#4aa0b0")
    # great sword: idle point-down planted in front, attack swung forward
    if a:
        nh = (b.sx - 14, b.S + 22)
        b.arm(True, nh, "armor", "darkiron", r=7)
        blade(e, nh[0], nh[1], 196, 70, w=4.2, role="mithril", guard="gold")
    else:
        nh = (b.sx - 4, hy - 10)
        b.arm(True, nh, "armor", "darkiron", r=7, elbow=(b.sx + sw + 4, b.S + 30))
        blade(e, nh[0], nh[1], 96, 64, w=4.4, role="mithril", guard="gold")
        e.sh(ell(nh[0] - 3, nh[1] - 1, 6, 5.5), "darkiron", s=0.4)
    e.em.append(glow(e.P, px - hr * 0.4, py - 1, 20, COLD, 0.25))


def golem(e):
    a = e.a
    dx = -10 * a
    rnd = random.Random(9)
    y0 = FY

    def rock(cx, cy, w, h, role="rock", s=2.4, seed=1):
        r = random.Random(seed)
        pts = [(cx - w * 0.5 + r.uniform(-2, 2), cy - h * 0.35), (cx - w * 0.3, cy - h * 0.5 + r.uniform(-2, 2)), (cx + w * 0.35, cy - h * 0.5 + r.uniform(-2, 1)),
               (cx + w * 0.5, cy - h * 0.25 + r.uniform(-2, 2)), (cx + w * 0.48 + r.uniform(-2, 1), cy + h * 0.4), (cx + w * 0.2, cy + h * 0.5),
               (cx - w * 0.35, cy + h * 0.5 + r.uniform(-1, 2)), (cx - w * 0.52, cy + h * 0.2)]
        e.sh(poly(pts), role, s=s)
        return pts

    hipx, hipy = CX + 2 + dx * 0.3, y0 - 66
    S = y0 - 128 + 6 * a
    sx = CX - 2 + dx
    # far arm (rear, raised back in the attack)
    fsx, fsy = sx + 40, S + 14
    if a:
        rock(fsx + 8, fsy + 14, 18, 26, "rock2", seed=21)
        rock(fsx + 10, fsy + 40, 22, 22, "rock2", seed=22)
    else:
        rock(sx - 36, S + 34, 18, 28, "rock2", seed=21)
        rock(sx - 40, S + 64, 24, 24, "rock2", seed=22)
    # legs: blocky columns
    rock(hipx + 16 + 6 * a, y0 - 30, 24, 40, "rock2", seed=3)
    rock(hipx + 18 + 8 * a, y0 - 6, 28, 14, "rock2", seed=4)
    rock(hipx - 14 - 10 * a, y0 - 26, 26, 40, "rock", seed=5)
    rock(hipx - 16 - 14 * a, y0 - 2, 30, 14, "rock", seed=6)
    # pelvis + torso boulder
    rock(hipx, hipy + 4, 46, 24, "rock2", seed=7)
    t = rock(sx + 6, S + 30, 74, 66, "rock", s=4, seed=8)
    # cracks + runes on the chest
    e.det(f"M{sx-18:.1f},{S+12:.1f} l10,8 l-4,10 M{sx+22:.1f},{S+44:.1f} l-8,6 l2,8 M{sx+30:.1f},{S+10:.1f} l-6,10", 0.9, 0.85)
    rx_, ry_ = sx + 2, S + 30
    runes = (f"M{rx_-8:.1f},{ry_-10:.1f} l0,16 M{rx_-8:.1f},{ry_-10:.1f} l7,5 l-7,5 M{rx_+4:.1f},{ry_-9:.1f} l6,8 l-6,8 "
             f"M{rx_+14:.1f},{ry_-6:.1f} l0,12 M{rx_+10:.1f},{ry_:.1f} l8,0")
    e.ln(runes, "#3a1a0c", 3.2, 0.9)
    e.ln(runes, EMBER_HOT, 1.4, 1.0)
    e.em.append(lin(runes, EMBER, 3.0, 0.35))
    e.em.append(glow(e.P, rx_ + 3, ry_, 22, EMBER, 0.3))
    # mossy shoulder
    e.fl(smooth([(sx - 30, S + 2), (sx - 12, S - 3), (sx - 2, S + 3), (sx - 18, S + 8)], t=0.4), "#6e7a46", 0.85)
    # head: small block sunk between the shoulders
    hx, hy = sx - 10 + dx * 0.3, S - 6 + 4 * a
    rock(hx, hy, 26, 22, "rock", s=1.6, seed=11)
    e.fl(poly([(hx - 12, hy - 1), (hx + 4, hy - 2), (hx + 4, hy + 3), (hx - 12, hy + 4)]), "#140c06")
    e.eye(hx - 7, hy + 1, EMBER, EMBER_HOT, r=1.6, g=7, gop=0.8)
    e.eye(hx + 0, hy + 0.5, EMBER, EMBER_HOT, r=1.4, g=6, gop=0.7)
    # near arm: huge stone fist (punch forward-left in the attack)
    nsx, nsy = sx + 34, S + 14
    rock(nsx, nsy, 30, 26, "rock", seed=12)
    if a:
        rock(nsx - 30, nsy + 6, 34, 22, "rock", seed=13)
        rock(nsx - 72, nsy + 6, 34, 30, "rock", s=2.4, seed=14)
        e.det(f"M{nsx-86:.1f},{nsy+0:.1f} l8,2 M{nsx-87:.1f},{nsy+9:.1f} l8,1", 0.9)
    else:
        rock(nsx + 4, nsy + 30, 22, 30, "rock", seed=13)
        rock(nsx + 4, nsy + 60, 32, 30, "rock", s=2.4, seed=14)
        e.det(f"M{nsx-8:.1f},{nsy+56:.1f} l0,10 M{nsx:.1f},{nsy+54:.1f} l0,12", 0.9)
    rnd.random()


def bog_wraith(e):
    a = e.a
    e.alpha = 0.78
    dx = -10 * a
    y0 = FY
    hx, hy = CX - 6 + dx, y0 - 124 + 6 * a
    # wispy body tapering to a curling tail above the base
    body = [(hx - 14, hy + 4), (hx - 16, hy - 12), (hx - 2, hy - 22), (hx + 14, hy - 16), (hx + 22, hy + 6), (hx + 26 - dx * 0.3, hy + 40),
            (CX + 22, y0 - 40), (CX + 30, y0 - 16), (CX + 18, y0 - 8), (CX + 6, y0 - 14), (CX + 14, y0 - 20), (CX + 8, y0 - 36),
            (hx - 6 - dx * 0.2, hy + 58), (hx - 18, hy + 30)]
    e.sh(smooth(body, t=0.4), "wisp", s=3)
    # tatters
    e.det(f"M{hx+2:.1f},{hy+20:.1f} q10,26 20,46 M{hx-6:.1f},{hy+26:.1f} q6,22 18,40 M{hx+14:.1f},{hy+10:.1f} q8,22 14,40", 0.8, 0.6)
    # far arm
    if a:
        e.sh(smooth([(hx + 2, hy + 14), (hx - 22, hy + 6), (hx - 38, hy + 2), (hx - 30, hy + 10), (hx - 6, hy + 22)], t=0.4), "wisp", s=1)
    else:
        e.sh(smooth([(hx - 4, hy + 16), (hx - 20, hy + 28), (hx - 26, hy + 44), (hx - 16, hy + 34), (hx, hy + 26)], t=0.4), "wisp", s=1)
    # hood + void face
    e.fl(smooth([(hx - 12, hy - 2), (hx - 6, hy - 14), (hx + 6, hy - 10), (hx + 6, hy + 8), (hx - 8, hy + 10)], t=0.45), "#0c140c")
    e.eye(hx - 7, hy - 2, GHOST, GHOST_HOT, r=1.6, g=8, gop=0.9)
    e.eye(hx + 0, hy - 3, GHOST, GHOST_HOT, r=1.4, g=7, gop=0.8)
    # near arm reaching
    if a:
        e.sh(smooth([(hx + 14, hy + 16), (hx - 10, hy + 18), (hx - 40, hy + 14), (hx - 32, hy + 22), (hx + 4, hy + 30)], t=0.4), "wisp", s=1.2)
        for i in range(3):
            e.ln(f"M{hx-38:.1f},{hy+15+i*3:.1f} l-8,{i*2-2:.1f}", "#c8e0b8", 1.0)
    else:
        e.sh(smooth([(hx + 16, hy + 14), (hx + 26, hy + 34), (hx + 24, hy + 56), (hx + 18, hy + 40), (hx + 8, hy + 26)], t=0.4), "wisp", s=1.2)
    e.em.append(glow(e.P, hx + 4, hy + 30, 46, GHOST, 0.32, rx=40, ry=60))
    e.em.append(glow(e.P, CX + 16, y0 - 12, 26, GHOST, 0.3, rx=30, ry=10))


def shadow(e):
    a = e.a
    e.alpha = 0.86
    dx = -12 * a
    y0 = FY
    rnd = random.Random(13)
    # smoky trailing skirt pooling on the base
    skirt = []
    for i in range(11):
        t = i / 10
        skirt.append((L(CX + 30, CX - 26 + dx * 0.4, t) + rnd.uniform(-2, 2), y0 - 2 + (6 if i % 2 else -2)))
    bx, by = CX + 2 + dx * 0.6, y0 - 70 + 6 * a
    # far arms (two), long and jointed, clawing forward
    arms_far = [((bx - 10, by - 10), (bx - 40, by - 46 + 10 * a), (bx - 62 + dx, by - 20 + 8 * a)),
                ((bx + 6, by - 16), (bx + 30, by - 56), (bx + 46, by - 30))]
    for p0, k, f in arms_far:
        e.limb([p0, k, f], 4.0, 1.4, "ink", s=0.8)
    body = [(bx - 22, by - 14), (bx - 8, by - 34), (bx + 12, by - 30), (bx + 24, by - 8), (bx + 22, by + 20), (CX + 30, y0 - 14)] + skirt + \
           [(CX - 26 + dx * 0.4, y0 - 12), (bx - 18, by + 24), (bx - 26, by + 4)]
    e.sh(smooth(body, t=0.38), "ink", s=3.4)
    # tendrils licking up from the back
    for (x0, y0_, x1, y1) in ((bx + 6, by - 30, bx + 20, by - 58), (bx + 14, by - 26, bx + 36, by - 46), (bx - 2, by - 32, bx + 2, by - 62)):
        e.sh(smooth([(x0 - 4, y0_), (L(x0, x1, 0.5) - 2, L(y0_, y1, 0.5)), (x1, y1), (L(x0, x1, 0.5) + 3, L(y0_, y1, 0.5)), (x0 + 4, y0_)], t=0.4), "ink", s=0.8)
    # head thrust forward, many pale eyes
    hx, hy = bx - 22 + dx * 0.4, by - 26 + 6 * a
    e.sh(smooth([(hx - 20, hy + 2), (hx - 13, hy - 15), (hx + 9, hy - 18), (hx + 22, hy), (hx + 12, hy + 17), (hx - 12, hy + 16)], t=0.45), "ink", s=1.8)
    e.sh(poly([(hx - 6, hy - 14), (hx - 2, hy - 30), (hx + 4, hy - 15)]) , "ink", s=0.6)
    e.sh(poly([(hx + 6, hy - 14), (hx + 14, hy - 28), (hx + 14, hy - 10)]), "ink", s=0.6)
    for (x, y, r) in ((hx - 11, hy - 4, 2.2), (hx - 1, hy - 6, 2.2), (hx - 14, hy + 3, 1.4), (hx + 5, hy + 1, 1.4), (hx - 5, hy + 4, 1.2)):
        e.eye(x, y, "#c8a8ff", "#f4ecff", r=r, g=6, gop=0.8)
    e.ln(f"M{hx-12:.1f},{hy+9:.1f} q8,3 16,0", "#c8a8ff", 0.9, 0.8)
    # near arms (two), the front one reaching out
    arms_near = [((bx - 14, by + 2), (bx - 48, by - 18 + 14 * a), (bx - 66 + dx * 1.2, by + 18 - 22 * a)),
                 ((bx + 14, by + 4), (bx + 44, by - 14), (bx + 54, by + 26))]
    for p0, k, f in arms_near:
        e.limb([p0, k, f], 4.6, 1.5, "ink", s=0.8)
        e.ln(f"M{f[0]:.1f},{f[1]:.1f} l-5,3 M{f[0]:.1f},{f[1]:.1f} l-4,-3 M{f[0]:.1f},{f[1]:.1f} l-1,5", "#3a3044", 1.2)
    e.det(f"M{bx-10:.1f},{by+22:.1f} l0,10 M{bx+6:.1f},{by+28:.1f} l0,14 M{bx+16:.1f},{by+24:.1f} l0,8", 1.0, 0.8)
    e.em.append(glow(e.P, hx - 4, hy, 20, "#8a5cd0", 0.4))
    e.em.append(glow(e.P, CX, y0 - 4, 30, "#8a5cd0", 0.18, rx=44, ry=10))


def revenant(e):
    a = e.a
    b = Biped(e, H=142, hr=15, sw=30, hw=22, lw=10.5, ar=8.6, lunge=11)
    S, sx, sw = b.S, b.sx, b.sw
    hx, hy = b.hip
    fh = (b.sx - 26 - 6 * a, b.S + 34 - 10 * a)
    b.arm(False, fh, "darkiron", "darkiron", r=8)
    b.legs("darkiron", "armor", far=True)
    b.legs("darkiron", "armor", far=False)
    # mail skirt
    e.sh(poly([(hx - 24, hy - 6), (hx + 24, hy - 6), (hx + 26, hy + 18), (hx - 26, hy + 18)]), "armor", s=1.4)
    e.o.append(f'<path d="{poly([(hx - 24, hy - 6), (hx + 24, hy - 6), (hx + 26, hy + 18), (hx - 26, hy + 18)])}" fill="{artlib.hatch(e.P, 45, sp=3, w=0.7)}" opacity="0.6"/>')
    b.torso("darkiron", s=3.4, bottom=hy)
    # bronze trim + belt with rune buckle
    e.sh(smooth([(hx - sw * 0.85, hy - 14), (hx + sw * 0.95, hy - 12), (hx + sw * 0.95, hy - 4), (hx - sw * 0.85, hy - 5)], t=0.3), "bronze", s=0.8)
    e.sh(ell(hx - 2, hy - 9, 5, 5), "gold", s=0.4)
    e.ln(f"M{sx-sw*0.6:.1f},{S+16:.1f} Q{sx+4:.1f},{S+24:.1f} {sx+sw*0.95:.1f},{S+14:.1f}", "#b8923e", 1.4, 0.8)
    for near in (False, True):
        x, y = b.shoulder(near)
        e.sh(smooth([(x - 12, y + 7), (x - 9, y - 7), (x + 5, y - 10), (x + 14, y - 2), (x + 13, y + 9), (x, y + 11)], t=0.45), "bronze", s=1.6)
    # ghostly beard flowing down over the chest
    px, py = b.head
    hr = b.hr
    beard = [(px - hr * 1.0, py + 2), (px + hr * 0.6, py + 3), (px + hr * 0.9, py + hr * 1.6), (px + hr * 0.6 + 6 * a, py + hr * 3.2),
             (px + hr * 0.2 + 8 * a, py + hr * 3.9), (px - hr * 0.2, py + hr * 3.0), (px - hr * 0.7, py + hr * 3.6), (px - hr * 1.0, py + hr * 2.0)]
    # helm + face
    b.head_shape("darkiron", rx=hr * 1.05, ry=hr * 1.05)
    e.fl(smooth([(px - hr * 1.0, py - 4), (px + hr * 0.5, py - 5), (px + hr * 0.5, py + 3), (px - hr * 1.0, py + 3)], t=0.2), "#0c100e")
    e.eye(px - hr * 0.6, py - 1, GHOST, GHOST_HOT, r=1.5, g=7, gop=0.9)
    e.eye(px - hr * 0.0, py - 1.5, GHOST, GHOST_HOT, r=1.3, g=6, gop=0.8)
    e.o.append(f'<g opacity="0.82">{e.P.shape(smooth(beard, t=0.4), "ghostbeard", s=1.6 * SHADE)}</g>')
    e.ln(f"M{px-hr*0.5:.1f},{py+6:.1f} q2,14 -2,26 M{px+hr*0.1:.1f},{py+6:.1f} q3,16 2,30 M{px+hr*0.5:.1f},{py+8:.1f} q2,12 4,22", "#6aa08c", 0.9, 0.8)
    e.em.append(fill(smooth(beard, t=0.4), GHOST, 0.18))
    e.em.append(glow(e.P, px, py + hr * 2, 30, GHOST, 0.28, rx=26, ry=40))
    # crown on helm
    crown = [(px - hr * 1.0, py - hr * 0.65)]
    for i in range(4):
        x = L(px - hr * 1.0, px + hr * 0.95, i / 3)
        crown += [(x - 2, py - hr * 0.95), (x, py - hr * 1.6), (x + 2, py - hr * 0.95)]
    crown += [(px + hr * 0.95, py - hr * 0.6)]
    e.sh(poly(crown), "gold", s=0.6, lw=1.1)
    e.fl(ell(px - hr * 0.35, py - hr * 0.8, 1.8, 1.5) + ell(px + hr * 0.4, py - hr * 0.8, 1.6, 1.4), "#7e2418")
    # near arm: bearded axe
    if a:
        nh = (b.sx - 20, b.S + 10)
        ang = 200
    else:
        nh = (b.sx + sw + 4, b.S + 30)
        ang = 262
    b.arm(True, nh, "darkiron", "darkiron", r=8.6)
    c, s = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    nx, ny = -s, c
    top = (nh[0] + c * 40, nh[1] + s * 40)
    bot = (nh[0] - c * 12, nh[1] - s * 12)
    e.sh(capsule(bot, top, 2.6), "wood", s=0.5)
    # head: blade on the side facing away from the wielder (toward screen-left / forward)
    sgn = -1 if a else 1
    hc = (nh[0] + c * 32, nh[1] + s * 32)
    pts = [(hc[0] + c * 6, hc[1] + s * 6), (hc[0] + c * 10 + nx * 22 * sgn, hc[1] + s * 10 + ny * 22 * sgn), (hc[0] - c * 14 + nx * 24 * sgn, hc[1] - s * 14 + ny * 24 * sgn),
           (hc[0] - c * 8 + nx * 8 * sgn, hc[1] - s * 8 + ny * 8 * sgn), (hc[0] - c * 6, hc[1] - s * 6)]
    e.sh(smooth(pts, t=0.25), "mithril", s=1.0, lw=1.3)
    e.sh(ell(hc[0], hc[1], 4, 4), "bronze", s=0.3)


PAINTERS = dict(
    wolf=lambda e: wolf(e), wolf_alpha=lambda e: wolf(e, alpha=True), boar=boar,
    spider=lambda e: spider(e), brood_mother=lambda e: spider(e, brood=True),
    goblin=goblin, bandit=bandit, bandit_captain=captain, bog_wraith=bog_wraith, skeleton=skeleton,
    wight=wight, barrow_lord=barrow_lord, golem=golem, shadow=shadow, revenant=revenant,
)
# per enemy: (base kind, extra scale of the figure about the feet point)
STYLE = dict(
    wolf=("beast", 1.0), wolf_alpha=("beast", 1.12), boar=("beast", 1.18), spider=("cave", 0.95), brood_mother=("cave", 1.05),
    goblin=("scorched", 1.12), bandit=("scorched", 1.0), bandit_captain=("scorched", 1.0),
    bog_wraith=("bog", 1.0), skeleton=("crypt", 1.0), wight=("crypt", 1.0), barrow_lord=("crypt", 1.0),
    golem=("stone", 1.0), shadow=("void", 1.0), revenant=("crypt", 1.12),
)

# ------------------------------------------------------------------ hostile bases
ENEMY_TINT = {
    "beast": "#4e4030",      # scorched earth
    "scorched": "#4a3a2c",
    "cave": "#46403c",       # cave grit
    "crypt": "#4a4c50",      # crypt slate
    "stone": "#55524c",
    "bog": "#3c4636",
    "void": "#2e2a34",
}


def enemy_base(P, kind, seed=5):
    M.BASE_TINT.update(ENEMY_TINT)
    rx, ry, rim = 60.0, 15.0, 8.0
    cy = FY + 1
    shadow, b = M.base(P, kind, rx=rx, ry=ry, rim=rim, seed=seed)
    P.pal["baserim"] = ("#3a2c22", "#1e1610", "#0e0806")
    rnd = random.Random(seed + 11)
    o = [b]
    # hostile mark: thin rubric line round the rim
    o.append(lin(f"M{CX-rx:.1f},{cy+rim*0.5:.1f} A{rx:.1f},{ry:.1f} 0 0 0 {CX+rx:.1f},{cy+rim*0.5:.1f}", RUB, 1.6, 0.85))
    top = M.BASE_TINT[kind]

    def pt(r0=0.3, r1=0.9):
        t = rnd.uniform(0, math.tau)
        r = rnd.uniform(r0, r1)
        return CX + math.cos(t) * rx * r, cy + math.sin(t) * ry * r

    if kind in ("crypt", "stone", "cave", "scorched", "beast"):
        cr = []
        for _ in range(6):
            x, y = pt()
            cr.append(f"M{x:.1f},{y:.1f} l{rnd.uniform(-10,10):.1f},{rnd.uniform(-2.5,2.5):.1f} l{rnd.uniform(-6,6):.1f},{rnd.uniform(-2,2):.1f}")
        o.append(lin(" ".join(cr), INK, 0.8, 0.6))
    if kind in ("scorched", "beast"):
        for _ in range(4):
            x, y = pt(0.5, 0.9)
            o.append(fill(ell(x, y, 1.1, 0.8), EMBER, 0.85))
        tufts = []
        for _ in range(6):
            x, y = pt(0.55, 0.92)
            tufts.append(f"M{x-2:.1f},{y:.1f} l-1.5,-4 M{x:.1f},{y:.1f} l0.5,-4.5 M{x+2:.1f},{y:.1f} l1.8,-3")
        o.append(lin(" ".join(tufts), "#2a1e14", 1.3, 0.9))
        o.append(lin(" ".join(tufts), "#8a7450", 0.5, 0.9))
    if kind == "crypt":
        # bone fragments + a tiny skull
        for _ in range(3):
            x, y = pt(0.55, 0.9)
            o.append(fill(capsule((x - 3, y), (x + 3, y - 0.8), 0.9), "#d6caa8", 0.9))
        x, y = CX - rx * 0.62, cy + ry * 0.35
        o.append(fill(ell(x, y - 1.2, 2.6, 2.2), "#d6caa8"))
        o.append(fill(ell(x - 0.9, y - 1.2, 0.6, 0.6) + ell(x + 0.9, y - 1.2, 0.6, 0.6), INK))
    if kind == "stone":
        for _ in range(5):
            x, y = pt(0.55, 0.9)
            o.append(fill(ell(x, y, rnd.uniform(1.6, 3), rnd.uniform(1, 1.8)), mix(top, "#ffffff", 0.25), 0.9))
            o.append(lin(ell(x, y, 2.4, 1.4), INK, 0.5, 0.5))
    if kind == "cave":
        webs = []
        for _ in range(3):
            x, y = pt(0.5, 0.85)
            webs.append(f"M{x:.1f},{y:.1f} l6,-1 M{x:.1f},{y:.1f} l-4,2 M{x:.1f},{y:.1f} l1,-3")
        o.append(lin(" ".join(webs), "#d8d0b8", 0.5, 0.7))
    if kind == "bog":
        o.append(fill(ell(CX + 8, cy + 2, rx * 0.5, ry * 0.45), "#24301e", 0.8))
        o.append(lin(f"M{CX-16:.1f},{cy+1:.1f} q10,-2 22,0", "#9ec08a", 0.6, 0.7))
        for _ in range(5):
            x, y = pt(0.6, 0.92)
            o.append(lin(f"M{x:.1f},{y:.1f} l-1,-5 M{x+1.5:.1f},{y:.1f} l1,-4", "#6a7a3e", 0.9, 0.9))
    if kind == "void":
        o.append(fill(ell(CX + 4, cy + 1, rx * 0.6, ry * 0.5), "#0c0a10", 0.6))
    return shadow, J(o)


# ------------------------------------------------------------------ sheets
def cell_of(eid):
    return 192 if eid in BOSSES else 128


def sheet_svgs(eid):
    cell = cell_of(eid)
    sc = cell / 256.0
    pal = palette()
    P = M.painter(pal, lw_mul=0.72 if cell == 128 else 0.62)
    kind, k = STYLE[eid]
    ff = ink_filter(P, wob=1.3, dil=1.1, grain=0.55, soot=0.55, seed=7)
    body = []
    for f in (0, 1):
        e = E(P, f)
        PAINTERS[eid](e)
        fig = J(e.o)
        em = J(e.em)
        if k != 1.0:
            xf = f'translate({CX},{FY}) scale({k}) translate({-CX},{-FY})'
            fig, em = f'<g transform="{xf}">{fig}</g>', f'<g transform="{xf}">{em}</g>'
        inner = f'<g {ff}>{fig}</g>'
        if e.alpha < 1:
            inner = f'<g opacity="{e.alpha}">{inner}</g>'
        body.append(f'<g transform="translate({f * cell},0) scale({sc})">{inner}<g>{em}</g></g>')
    figs = svg_doc(2 * cell, cell, P, "".join(body), ss=2)
    PB = M.painter(palette())
    shadow, base = enemy_base(PB, kind, seed=5 + len(eid))
    fb = ink_filter(PB, wob=1.0, dil=0.9, grain=0.5, soot=0.4, seed=4)
    bop = 0.55 if eid in SPIRITS else 1.0
    bsvg = svg_doc(cell, cell, PB, f'<g transform="scale({sc})" opacity="{bop}"><g>{shadow}</g><g {fb}>{base}</g></g>', ss=2)
    return figs, bsvg


def jobs_for(ids):
    js = []
    for eid in ids:
        figs, bsvg = sheet_svgs(eid)
        c = cell_of(eid)
        js.append(dict(name=f"enemy_{eid}", svg=figs, w=2 * c, h=c, ss=2, out=os.path.join(TMP, eid + "_fig.png")))
        js.append(dict(name=f"enemy_{eid}_base", svg=bsvg, w=c, h=c, ss=2, out=os.path.join(TMP, eid + "_base.png")))
    return js


def out_path(eid):
    return artlib.tpath(os.path.join(OUT_EN, eid + ".png"))


def compose(eid):
    from PIL import Image
    c = cell_of(eid)
    figs = Image.open(os.path.join(TMP, eid + "_fig.png")).convert("RGBA")
    b = Image.open(os.path.join(TMP, eid + "_base.png")).convert("RGBA")
    out = Image.new("RGBA", (2 * c, c))
    out.paste(b, (0, 0))
    out.paste(b, (c, 0))
    out.alpha_composite(figs)
    os.makedirs(OUT_EN, exist_ok=True)
    out.save(out_path(eid), optimize=True)


def check(eid):
    """size, base band identical in both frames, figure inside the cell, base geometry."""
    from PIL import Image
    import numpy as np
    c = cell_of(eid)
    im = Image.open(out_path(eid))
    errs = []
    if im.size != (2 * c, c) or im.mode != "RGBA":
        errs.append(f"size/mode {im.size} {im.mode}")
    a = np.asarray(im.convert("RGBA")).astype(int)
    y0 = int(c * 0.82)
    d = np.abs(a[y0:, :c] - a[y0:, c:]).max()
    if d > 0:
        errs.append(f"base band differs ({d})")
    for f in (0, 1):
        al = a[:, f * c:(f + 1) * c, 3]
        ys, xs = np.nonzero(al > 24)
        if xs.min() < 1 or xs.max() > c - 2 or ys.min() < 1:
            errs.append(f"touches edge f{f} x[{xs.min()},{xs.max()}] y{ys.min()}")
    b = np.asarray(Image.open(os.path.join(TMP, eid + "_base.png")).convert("RGBA"))[..., 3]
    ys, xs = np.nonzero(b > 128)
    geom = (int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max()))
    return errs, geom


# ------------------------------------------------------------------ review sheet
def contact(ids):
    from PIL import Image, ImageDraw
    from contact import font
    fnt = font(12)
    chars = ["player", "sigrun", "varn"]
    W = 10 + 3 * 140 + 10
    rows = []
    x = 10
    pad = 12
    cols, cur, rw = [], [], 0
    maxw = 1500
    for eid in ids:
        p = out_path(eid)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        if rw + im.width + pad > maxw and cur:
            cols.append(cur)
            cur, rw = [], 0
        cur.append((eid, im))
        rw += im.width + pad
    if cur:
        cols.append(cur)
    H = 10 + 150
    for r in cols:
        H += max(im.height for _, im in r) + 22
    sheet = Image.new("RGBA", (maxw + 20, H), (220, 199, 154, 255))
    d = ImageDraw.Draw(sheet)
    # scale references: character sheets' first frames
    x = 10
    for cid in chars:
        p = os.path.join(SPR, "chars", cid + ".png")
        if os.path.exists(artlib.tpath(p)):
            ch = Image.open(artlib.tpath(p)).convert("RGBA").crop((0, 0, 128, 128))
            sheet.alpha_composite(ch, (x, 24))
            d.text((x + 2, 8), "ref: " + cid, fill=(32, 20, 12), font=fnt)
            x += 140
    y = 10 + 150
    for r in cols:
        x = 10
        h = max(im.height for _, im in r)
        for eid, im in r:
            d.text((x + 2, y), eid, fill=(32, 20, 12), font=fnt)
            sheet.alpha_composite(im, (x, y + 16 + h - im.height))
            d.line([(x + im.width // 2, y + 16), (x + im.width // 2, y + 16 + 6)], fill=(150, 120, 80))
            x += im.width + pad
        y += h + 22
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, "enemies_contact.png")
    sheet.convert("RGB").save(out)
    print(out, sheet.size)
    # 2x zoom of the same sheet for detail review
    z = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    z.convert("RGB").save(os.path.join(OUT, "enemies_contact_2x.png"))


def all_ids():
    d = json.load(open(os.path.join(DATA, "expeditions.json")))
    return [x["id"] for x in d["enemies"]]


def main():
    only = artlib.only_filter()
    ids = all_ids()
    unknown = [i for i in ids if i not in PAINTERS]
    if unknown:
        print("!! no painter for:", unknown)
    todo = [i for i in ids if i in PAINTERS and (not only or i in only)]
    if "--contact" not in sys.argv:
        render(jobs_for(todo), workers=4)
        bad = 0
        for eid in todo:
            compose(eid)
            errs, g = check(eid)
            print(f"  {eid:14s} base bbox x{g[0]}-{g[1]} y{g[2]}-{g[3]}" + ("" if not errs else "  !! " + "; ".join(errs)))
            bad += bool(errs)
        print("check:", "OK" if not bad else f"{bad} sheet(s) with issues")
    contact([i for i in ids if i in PAINTERS])


if __name__ == "__main__":
    main()
