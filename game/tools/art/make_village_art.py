"""Iteration 009 village art: nature & boundaries, grit, the pond, the harbour, the herbalist, Barnaby's
Ironfront basement and the new mundane trades (stable, cooper, chandler). Straight top-down sprites in the
ink-and-parchment 80/20 style, same pipeline as make_props.py / make_interiors.py (template_ files).
Prop ids and sizes come from game/data/props.json (written by tools/data/make_data.py from extra_village_props.py).
Roofs of the new buildings are drawn by make_roofs.py from layout.json (python3 make_roofs.py --only=<ids>).
python3 make_village_art.py [--only=reeds,duck]   (also writes out/sheet_village9*.png)"""
import math
import os
import random
import artlib  # noqa: F401  (sets sys.path)
from artlib import (painter, sprite_svg, svg_doc, soft_filter, ground_shadow, glow, lin, fill, planks, end_grain, liquid,
                    bottle_top, candle_top, render, load, only_filter, ell, rect, poly, smooth, blob, wobbly_ell, ST, INK,
                    EMBER, EMBER_HOT, RUB, GILT, SPR, OUT, SOOT, blur_filter, hatch)
from make_props import tankard, book, barrel_top, crate_top, sack_top, rock
from make_interiors import bundle_hang, shelf_box, backboard, noise_clip, open_crate
import make_interiors  # noqa: F401  (registers the extra palette roles: amber, wine, moss, rust, ivory, pewter ...)

PAL = ST["pal"]
FELT = ("#9cb08a", "#5e7a52", "#2c3e28")
PAL.setdefault("felt", FELT)
PAL.setdefault("olive", ("#b4b48a", "#7c7c50", "#3c3c22"))
PAL.setdefault("mud", ("#9a8262", "#6a5236", "#3a2a18"))
PAL.setdefault("reed", ("#c8c48a", "#8e8a52", "#4a4626"))


def J(o):
    return "\n".join(x for x in o if x)


def sh_(P, d, dx=4, dy=5, **k):
    return ground_shadow(P, d, dx, dy, **k)


DECALS = set()


def decal(fn):
    DECALS.add(fn.__name__)
    return fn


# ================================================================ nature & boundaries
def reeds(P, W, H):
    """Clump of reeds and bulrushes rooted along the bottom edge (sway shader pivots there)."""
    rnd = random.Random(5)
    base = H - 3
    stems, heads, blades = [], [], []
    for i in range(13):
        x0 = 8 + i * 3.8 + rnd.uniform(-1.5, 1.5)
        tx, ty = x0 + rnd.uniform(-9, 9), rnd.uniform(4, 22)
        stems.append(f"M{x0:.1f},{base} Q{(x0+tx)/2+rnd.uniform(-3,3):.1f},{(base+ty)/2:.1f} {tx:.1f},{ty:.1f}")
        if i % 3 == 0:
            heads.append((tx, ty + 5))
        else:
            blades.append(smooth([(x0 - 1.4, base), (tx, ty), (x0 + 1.4, base)], t=0.5))
    sh = f'<ellipse cx="{W/2+3:.1f}" cy="{H-3:.1f}" rx="{W*0.4:.1f}" ry="4" fill="{INK}" opacity="0.25" {blur_filter(P, 2)}/>'
    b = [lin(" ".join(stems), INK, 2.0), lin(" ".join(stems), PAL["reed"][1], 1.0)]
    for d in blades:
        b.append(P.shape(d, "reed", s=0.5, lw=0.9))
    for x, y in heads:
        b.append(P.shape(rect(x - 2, y - 6, 4, 11, 2), "brown", s=0.8, lw=1.0))
    return sh, J(b), ""


@decal
def lily_pads(P, W, H):
    rnd = random.Random(8)
    b = []
    for i in range(6):
        x, y, r = rnd.uniform(10, W - 10), rnd.uniform(9, H - 9), rnd.uniform(5, 9)
        a = rnd.uniform(0, 360)
        pad = f"M{x:.1f},{y:.1f} L{x+r*math.cos(math.radians(a)):.1f},{y+r*math.sin(math.radians(a)):.1f} A{r:.1f},{r:.1f} 0 1,1 {x+r*math.cos(math.radians(a+40)):.1f},{y+r*math.sin(math.radians(a+40)):.1f} Z"
        b.append(fill(pad, PAL["green"][1], 0.95))
        b.append(lin(pad, INK, 0.8, 0.8))
        b.append(lin(f"M{x:.1f},{y:.1f} l{r*0.6:.1f},{r*0.2:.1f}", PAL["green"][2], 0.6, 0.7))
        if i == 2:
            b.append(fill(ell(x + 1, y - 1, 3), "#f2ead6"))
            b.append(lin(ell(x + 1, y - 1, 3), INK, 0.5))
            b.append(fill(ell(x + 1, y - 1, 1), PAL["gold"][1]))
    return "", J(b), ""


@decal
def duck(P, W, H):
    """A mallard on the water seen from above, heading east."""
    cx, cy = 15, 14
    body = smooth([(cx - 11, cy), (cx - 6, cy - 6), (cx + 5, cy - 6), (cx + 10, cy - 2), (cx + 10, cy + 2), (cx + 5, cy + 6), (cx - 6, cy + 6)])
    b = [fill(ell(cx, cy + 1, 13, 8), "#ffffff", 0.18), lin(f"M{cx-15},{cy+3} q-3,0 -5,3 M{cx-15},{cy-1} q-3,0 -5,-3", "#e8f0f4", 0.8, 0.6),
         P.shape(body, "brown", s=1.5, lw=1.2, fill_override="#8a7254"),
         P.shape(smooth([(cx - 8, cy - 3), (cx + 3, cy - 4), (cx + 3, cy + 4), (cx - 8, cy + 3)]), "slate", s=1, lw=0.9),
         P.shape(ell(cx + 10, cy, 4.4), "green", s=0.8, lw=1.0, fill_override="#3e6a46"),
         fill(f"M{cx+14},{cy-1.6} l5,1.6 l-5,1.6 Z", "#d8b040"), lin(f"M{cx+14},{cy-1.6} l5,1.6 l-5,1.6 Z", INK, 0.6),
         fill(ell(cx + 6.4, cy, 1.0, 4.2), "#f4f2ea", 0.9)]
    return "", J(b), ""


def fern(P, W, H):
    rnd = random.Random(4)
    cx, cy = W / 2, H - 6
    b = []
    for i in range(7):
        a = math.radians(-160 + i * 23 + rnd.uniform(-6, 6))
        L = rnd.uniform(18, 26)
        ex, ey = cx + math.cos(a) * L, cy + math.sin(a) * L * 0.9
        frond = smooth([(cx - 1.5, cy), ((cx + ex) / 2 - 3 * math.sin(a), (cy + ey) / 2 + 3 * math.cos(a)), (ex, ey),
                        ((cx + ex) / 2 + 3 * math.sin(a), (cy + ey) / 2 - 3 * math.cos(a)), (cx + 1.5, cy)], t=0.4)
        b.append(P.shape(frond, "foliage", s=0.8, lw=1.0, fill_override=["#7e8e5a", "#8c9a64", "#6e7e4c"][i % 3]))
        b.append(P.detail(f"M{cx:.1f},{cy:.1f} L{ex:.1f},{ey:.1f}", "foliage", 0.3, 0.6))
        ticks = " ".join(f"M{cx+(ex-cx)*t:.1f},{cy+(ey-cy)*t:.1f} l{-math.sin(a)*3:.1f},{math.cos(a)*3:.1f} M{cx+(ex-cx)*t:.1f},{cy+(ey-cy)*t:.1f} l{math.sin(a)*3:.1f},{-math.cos(a)*3:.1f}" for t in (0.35, 0.55, 0.75))
        b.append(lin(ticks, PAL["foliage"][2], 0.6, 0.7))
    sh = f'<ellipse cx="{cx+3:.1f}" cy="{cy:.1f}" rx="{W*0.4:.1f}" ry="5" fill="{INK}" opacity="0.2" {blur_filter(P, 2)}/>'
    return sh, J(b), ""


def undergrowth(P, W, H):
    """Low bramble and shrub tangle that thickens the edge of a wood."""
    rnd = random.Random(13)
    sh = sh_(P, blob(W / 2, H / 2 + 2, W * 0.42, 9, 0.12, 2, squash=0.6), 3, 4)
    b = []
    for i in range(9):
        x, y = rnd.uniform(16, W - 16), rnd.uniform(16, H - 14)
        r = rnd.uniform(9, 15)
        b.append(P.shape(blob(x, y, r, 7, 0.14, i + 3), "foliage", s=1.6, lw=1.3,
                         fill_override=rnd.choice(["#7e8e5a", "#8c9a64", "#76844e", "#949c6a"])))
    b.append(lin(" ".join(f"M{rnd.uniform(8,W-8):.1f},{rnd.uniform(8,H-8):.1f} q6,-5 12,-1 t10,2" for _ in range(6)), PAL["brown"][2], 0.9, 0.8))
    b.append(fill(" ".join(ell(rnd.uniform(14, W - 14), rnd.uniform(12, H - 12), 1.6) for _ in range(9)), "#7a2a3a", 0.85))
    return sh, J(b), ""


def hedge_h(P, W, H):
    rnd = random.Random(2)
    sh = sh_(P, rect(2, 8, W - 4, H - 14, 10), 3, 5)
    b = [P.shape(rect(2, 6, W - 4, H - 12, 12), "foliage", s=3, fill_override="#7a8a56")]
    for i in range(int(W / 14)):
        x = 10 + i * 14 + rnd.uniform(-2, 2)
        b.append(P.shape(blob(x, H / 2 + rnd.uniform(-4, 4), 10, 7, 0.12, i), "foliage", s=1.5, lw=1.1, fill_override=rnd.choice(["#8c9a64", "#7e8e5a", "#949c6a"])))
    b.append(P.detail(" ".join(f"M{rnd.uniform(6,W-6):.1f},{rnd.uniform(9,H-9):.1f} q2,2 4,0" for _ in range(14)), "foliage", 0.5, 0.7))
    return sh, J(b), ""


def hedge_v(P, W, H):
    rnd = random.Random(3)
    sh = sh_(P, rect(8, 2, W - 14, H - 4, 10), 3, 5)
    b = [P.shape(rect(6, 2, W - 12, H - 4, 12), "foliage", s=3, fill_override="#7a8a56")]
    for i in range(int(H / 14)):
        y = 10 + i * 14 + rnd.uniform(-2, 2)
        b.append(P.shape(blob(W / 2 + rnd.uniform(-4, 4), y, 10, 7, 0.12, i + 9), "foliage", s=1.5, lw=1.1, fill_override=rnd.choice(["#8c9a64", "#7e8e5a", "#949c6a"])))
    return sh, J(b), ""


def _dry_wall(P, W, H, horiz, seed):
    rnd = random.Random(seed)
    o = []
    L = W if horiz else H
    t = H if horiz else W
    pos = 0.0
    while pos < L - 2:
        s = rnd.uniform(9, 16)
        for row in range(2):
            a = pos + rnd.uniform(-2, 2) + row * 5
            r = min(s, t * 0.38) * rnd.uniform(0.8, 1.05)
            c = (t * (0.32 + row * 0.36))
            x, y = (a + r, c) if horiz else (c, a + r)
            o.append(P.shape(blob(x, y, r, 6, 0.14, int(pos) + row, squash=0.75), "stone", s=r * 0.3, lw=1.3,
                             fill_override=rnd.choice(["#aea290", "#9c9282", "#b6ab98", "#8e8676"])))
        pos += s * 1.5
    # moss tufts
    o.append(fill(" ".join(ell(rnd.uniform(4, W - 4), rnd.uniform(4, H - 4), rnd.uniform(1.5, 3.5)) for _ in range(int(L / 10))), PAL["moss"][1], 0.75))
    return J(o)


def stone_wall_h(P, W, H):
    sh = sh_(P, rect(0, 6, W, H - 8, 4), 3, 4)
    return sh, _dry_wall(P, W, H, True, 4), ""


def stone_wall_v(P, W, H):
    sh = sh_(P, rect(6, 0, W - 8, H, 4), 3, 4)
    return sh, _dry_wall(P, W, H, False, 6), ""


@decal
def crop_rows(P, W, H):
    """Tilled field strip: furrows of dark soil with rows of young cabbages and leeks."""
    rnd = random.Random(9)
    b = [fill(rect(4, 4, W - 8, H - 8, 10), PAL["mud"][1], 0.85)]
    b.append(noise_clip(P, rect(4, 4, W - 8, H - 8, 10), "#2a1c10", 0.08, 1.5, -0.4, 3, 0, 0, W, H))
    for i, y in enumerate(range(16, H - 8, 16)):
        b.append(lin(f"M8,{y} L{W-8},{y + rnd.uniform(-1,1):.1f}", PAL["mud"][2], 3.0, 0.7))
        b.append(lin(f"M8,{y-5} L{W-8},{y-5}", PAL["mud"][0], 1.2, 0.5))
        for x in range(14, W - 10, 13):
            if rnd.random() < 0.15:
                continue
            r = rnd.uniform(3.2, 5.2)
            if i % 2:
                b.append(P.shape(blob(x + rnd.uniform(-1, 1), y - 3, r, 6, 0.2, x + y), "cabbage", s=0.8, lw=0.8))
            else:
                b.append(lin(f"M{x},{y-1} l-2,-6 M{x},{y-1} l1,-7 M{x},{y-1} l3,-5", PAL["green"][1], 1.3, 0.95))
    b.append(lin(rect(4, 4, W - 8, H - 8, 10), PAL["mud"][2], 1.6, 0.8))
    return "", J(b), ""


def stump(P, W, H):
    sh = sh_(P, ell(24, 24, 17))
    b = [end_grain(P, 24, 24, 16, seed=8), lin("M10,30 l-6,6 M36,32 l7,5 M30,10 l5,-6", PAL["wood"][2], 3.0, 0.9),
         fill(ell(14, 18, 3, 2), PAL["moss"][1], 0.8)]
    return sh, J(b), ""


# ================================================================ grit
@decal
def puddle(P, W, H):
    d = blob(W / 2, H / 2, W * 0.42, 9, 0.16, 5, squash=H / W * 1.05)
    b = [fill(blob(W / 2, H / 2, W * 0.47, 9, 0.18, 6, squash=H / W * 1.1), PAL["mud"][1], 0.6),
         liquid(P, d, "water", W / 2, H / 2, W * 0.4, H * 0.36, ripples=1, op=0.85),
         fill(d, "#3a2a18", 0.25), lin(d, INK, 0.9, 0.55),
         lin(f"M{W*0.3:.1f},{H*0.4:.1f} q{W*0.1:.1f},-3 {W*0.22:.1f},0", "#f0f0e8", 0.9, 0.6)]
    return "", J(b), ""


@decal
def mud_patch(P, W, H):
    """Trampled mud: a soft-edged wet patch with boot prints and two wheel marks (no hard outline)."""
    rnd = random.Random(7)
    b = []
    for k, (sc, op) in enumerate([(1.0, 0.22), (0.82, 0.22), (0.62, 0.25)]):
        d = wobbly_ell(W / 2, H / 2, W * 0.44 * sc, H * 0.4 * sc, 2 + k, 0.07, 16)
        b.append(fill(d, PAL["mud"][1 if k < 2 else 2], op, blur_filter(P, 4 - k)))
    for i in range(9):
        x, y = rnd.uniform(W * 0.22, W * 0.78), rnd.uniform(H * 0.28, H * 0.72)
        b.append(fill(ell(x, y, 2.4, 3.8), "#2a1c10", 0.35))
    b.append(lin(f"M8,{H*0.42:.1f} Q{W/2:.1f},{H*0.32:.1f} {W-8},{H*0.44:.1f} M8,{H*0.62:.1f} Q{W/2:.1f},{H*0.52:.1f} {W-8},{H*0.64:.1f}",
                 "#2a1c10", 2.2, 0.28))
    b.append(fill(ell(W * 0.62, H * 0.46, W * 0.08, H * 0.06), "#c8d4dc", 0.35))
    return "", J(b), ""


def refuse_heap(P, W, H):
    """Midden by a back door: peelings, a cracked pot, rags, bones and a broken basket."""
    rnd = random.Random(11)
    cx, cy = W / 2, H / 2 + 2
    sh = sh_(P, blob(cx, cy, 30, 8, 0.12, 3, squash=0.7), 3, 4)
    b = [P.shape(blob(cx, cy, 30, 8, 0.14, 3, squash=0.7), "mud", s=3)]
    for i in range(10):
        x, y = cx + rnd.gauss(0, 11), cy + rnd.gauss(0, 7)
        k = i % 5
        if k == 0:
            b.append(P.shape(blob(x, y, 5, 5, 0.3, i), "cabbage", s=0.5, lw=0.8))
        elif k == 1:
            b.append(P.shape(f"M{x:.1f},{y:.1f} a6,6 0 0,1 10,-2 l-3,5 Z", "clay", s=0.8, lw=1.0))
        elif k == 2:
            b.append(P.shape(rect(x - 6, y - 1.4, 12, 2.8, 1.4), "linen", s=0.4, lw=0.9))
        elif k == 3:
            b.append(P.shape(blob(x, y, 4, 5, 0.3, i + 4), "apple", s=0.5, lw=0.8))
        else:
            b.append(P.shape(smooth([(x - 7, y - 3), (x + 6, y - 5), (x + 7, y + 3), (x - 5, y + 4)]), "straw", s=0.6, lw=0.9))
    b.append(P.detail(f"M{cx+6:.1f},{cy-10:.1f} l8,8 M{cx-14:.1f},{cy+2:.1f} l6,-6", "linen", 0.6))
    return sh, J(b), ""


def broken_crate(P, W, H):
    sh = sh_(P, rect(6, 8, 46, 40, 3))
    b = [P.shape(rect(8, 10, 40, 36, 2), "brown", s=-2, hl=False, lw=1.4), fill(rect(10, 12, 36, 32), "#1a120c", 0.45)]
    b.append(f'<g transform="rotate(-8 28 28)">{planks(P, 6, 8, 44, 9, "wood", n=1, s=1, seed=3)}</g>')
    b.append(f'<g transform="rotate(14 30 40)">{planks(P, 10, 38, 40, 8, "wood", n=1, s=1, seed=4)}</g>')
    b.append(f'<g transform="rotate(62 50 30)">{planks(P, 34, 26, 26, 7, "wood", n=1, s=1, seed=5)}</g>')
    b.append(lin("M18,22 l6,10 l-3,6 M34,18 l4,8", PAL["straw"][1], 1.4, 0.9))
    return sh, J(b), ""


@decal
def moss_decal(P, W, H):
    rnd = random.Random(4)
    b = []
    for i in range(14):
        x, y = rnd.uniform(6, W - 6), rnd.uniform(H * 0.3, H - 4)
        b.append(fill(blob(x, y, rnd.uniform(4, 9), 6, 0.3, i, squash=0.7), rnd.choice(PAL["moss"][:2] + ("#6e7e4c",)), 0.75))
    b.append(fill(" ".join(ell(rnd.uniform(4, W - 4), rnd.uniform(2, H - 2), rnd.uniform(0.8, 1.8)) for _ in range(20)), PAL["moss"][2], 0.6))
    return "", J(b), ""


def chopping_block(P, W, H):
    sh = sh_(P, ell(24, 26, 18))
    b = [end_grain(P, 24, 26, 17, seed=12), lin("M14,20 l8,6 M26,34 l6,-4", INK, 0.9, 0.7)]
    b.append(P.shape(rect(22, 6, 4, 26, 1.5), "wood", s=0.6, lw=1.1))
    b.append(P.shape(smooth([(18, 22), (30, 22), (31, 30), (17, 30)]), "metal", s=1, lw=1.2))
    b.append(fill(" ".join(ell(4 + i * 5.5, 44 + (i % 2) * 2, 1.6, 1) for i in range(8)), PAL["wood"][0], 0.9))
    return sh, J(b), ""


# ================================================================ harbour
def mooring_post(P, W, H):
    sh = sh_(P, ell(16, 16, 11), 3, 4)
    b = [end_grain(P, 16, 16, 11, seed=3), lin(ell(16, 16, 13), PAL["burlap"][1], 2.6), lin(ell(16, 16, 13), INK, 0.6, 0.7),
         lin("M27,18 q5,6 4,13", PAL["burlap"][1], 2.4), fill(ell(10, 22, 2.4, 1.6), PAL["moss"][1], 0.8)]
    return sh, J(b), ""


def net_rack(P, W, H):
    """Two trestles with a fishing net hung to dry, floats along the top rope."""
    rnd = random.Random(6)
    sh = sh_(P, rect(6, 10, W - 12, H - 18, 4), 3, 4)
    b = []
    for x in (10, W - 10):
        b.append(P.shape(rect(x - 4, 4, 8, H - 8, 2), "wood", s=1.4, lw=1.4))
    b.append(P.shape(rect(6, 10, W - 12, 4, 1.5), "wood", s=1, lw=1.2))
    net = rect(14, 14, W - 28, H - 24, 3)
    b.append(fill(net, PAL["brown"][1], 0.25))
    mesh = " ".join(f"M{x},{14} L{x + 10},{H - 10}" for x in range(10, W - 18, 7)) + " " + \
        " ".join(f"M{x},{14} L{x - 10},{H - 10}" for x in range(24, W, 7))
    cid = artlib.uid("nr")
    P.defs.append(f'<clipPath id="{cid}"><path d="{net}"/></clipPath>')
    b.append(f'<g clip-path="url(#{cid})">{lin(mesh, PAL["brown"][2], 0.7, 0.85)}</g>')
    b.append(lin(f"M14,{H-10} Q{W/2},{H-4} {W-14},{H-10}", PAL["burlap"][1], 1.6))
    for x in range(20, W - 16, 16):
        b.append(P.shape(ell(x, 12, 3.2), "cloth", s=0.6, lw=0.9, fill_override=rnd.choice(["#b0503a", "#d8c49a"])))
    return sh, J(b), ""


def net_pile(P, W, H):
    rnd = random.Random(2)
    d = blob(W / 2, H / 2, W * 0.42, 8, 0.16, 4, squash=0.7)
    sh = sh_(P, d, 3, 4)
    b = [P.shape(d, "brown", s=2, fill_override="#7a6448")]
    cid = artlib.uid("np")
    P.defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
    mesh = " ".join(f"M{rnd.uniform(0,W):.1f},0 Q{rnd.uniform(0,W):.1f},{H/2} {rnd.uniform(0,W):.1f},{H}" for _ in range(14))
    b.append(f'<g clip-path="url(#{cid})">{lin(mesh, INK, 0.7, 0.6)}</g>')
    for i in range(4):
        b.append(P.shape(ell(rnd.uniform(14, W - 14), rnd.uniform(12, H - 12), 3.4), "cloth", s=0.5, lw=0.9, fill_override="#c06a48"))
    return sh, J(b), ""


@decal
def rope_coil(P, W, H):
    cx, cy = W / 2, H / 2
    b = [fill(ell(cx + 2, cy + 3, 15), INK, 0.2)]
    for r in (15, 12, 9, 6):
        b.append(lin(ell(cx, cy, r), INK, 3.4))
        b.append(lin(ell(cx, cy, r), PAL["burlap"][1], 2.2))
        b.append(lin(ell(cx, cy, r), PAL["burlap"][0], 0.6, 0.7))
    b.append(lin(f"M{cx+15},{cy} q6,6 4,14", INK, 3.4))
    b.append(lin(f"M{cx+15},{cy} q6,6 4,14", PAL["burlap"][1], 2.2))
    return "", J(b), ""


def crate_stack(P, W, H):
    sh = sh_(P, rect(4, 4, W - 10, H - 10, 3))
    b = [crate_top(P, 4, 40, 50, 5), crate_top(P, 44, 40, 46, 6), crate_top(P, 10, 6, 48, 7)]
    b.append(P.shape(rect(60, 10, 30, 26, 2), "burlap", s=1.2, lw=1.2))
    b.append(lin("M64,22 h22 M75,12 v22", PAL["brown"][2], 1.0, 0.8))
    b.append(P.detail("M18,26 l20,0 M18,30 l14,0", "wood", 0.5, 0.7))
    b.append(fill(" ".join([ell(30, 22, 4, 2.4)]), RUB, 0.7))
    return sh, J(b), ""


def lobster_pots(P, W, H):
    sh = sh_(P, rect(4, 8, W - 8, H - 14, 6))
    b = []
    for i, (x, y) in enumerate([(18, 24), (44, 26)]):
        b.append(P.shape(ell(x, y, 15, 13), "wood", s=1.5, lw=1.4, fill_override="#9a7a50"))
        b.append(lin(" ".join(f"M{x-14+k*5},{y-11} Q{x-14+k*5+2},{y} {x-14+k*5},{y+11}" for k in range(1, 6)), PAL["wood"][2], 0.9, 0.85))
        b.append(lin(ell(x, y, 5, 4), INK, 1.2))
        b.append(fill(ell(x, y, 4, 3), "#1a120c", 0.7))
    return sh, J(b), ""


@decal
def anchor(P, W, H):
    cx = W / 2
    b = [fill(ell(cx + 3, H / 2 + 4, 26, 22), INK, 0.12)]
    shaft = rect(cx - 3, 10, 6, H - 26, 2)
    arm = f"M{cx-24},{H-26} Q{cx},{H-4} {cx+24},{H-26}"
    b.append(lin(arm, INK, 8))
    b.append(lin(arm, PAL["darkiron"][1], 5.4))
    b.append(P.shape(shaft, "darkiron", s=1, lw=1.4))
    b.append(P.shape(rect(cx - 13, 16, 26, 5, 2), "darkiron", s=0.6, lw=1.2))
    b.append(lin(ell(cx, 8, 5), INK, 4))
    b.append(lin(ell(cx, 8, 5), PAL["darkiron"][1], 2.2))
    for sx in (-1, 1):
        b.append(P.shape(f"M{cx+sx*24},{H-26} l{sx*5},-9 l{-sx*9},4 Z", "darkiron", s=0.6, lw=1.1))
    b.append(fill(" ".join(ell(cx + random.Random(i).uniform(-16, 16), H - 16 + random.Random(i + 9).uniform(-6, 4), 2) for i in range(6)), PAL["rust"][1], 0.7))
    return "", J(b), ""


def harbour_booth(P, W, H):
    """Harbourmaster's booth seen from above: plank roof with a tarred ridge, a serving hatch to the south
    with a ledger, a brass bell and a slate of tide times; a lantern on the corner."""
    sh = sh_(P, rect(10, 8, W - 20, H - 30, 3), 6, 7)
    x0, y0, w, h = 10, 8, W - 20, H - 34
    b = [planks(P, x0, y0, w, h / 2, "wood", n=5, dirn="h", s=3, seed=21),
         planks(P, x0, y0 + h / 2, w, h / 2, "wood", n=5, dirn="h", s=3, seed=22),
         fill(rect(x0, y0 + h / 2, w, h / 2), hatch(P, -35, 4.0, 0.9), 0.35),
         P.shape(rect(x0 - 2, y0 + h / 2 - 3, w + 4, 6, 2), "coal", s=0.8, lw=1.4),
         lin(rect(x0, y0, w, h, 2), INK, 2.6)]
    # serving hatch / ledge (south)
    ly = y0 + h
    b.append(planks(P, x0 + 12, ly, w - 24, 16, "wood", n=1, dirn="h", s=1.2, seed=23))
    b.append(book(P, x0 + 20, ly + 2, 26, 12, "leather", open_=True))
    b.append(P.shape(ell(x0 + w - 30, ly + 8, 6), "bronze", s=1, lw=1.2))
    b.append(fill(ell(x0 + w - 30, ly + 8, 2), INK))
    b.append(P.shape(rect(x0 + 56, ly + 2, 18, 12, 1), "slate", s=0.6, lw=1.0))
    b.append(lin(f"M{x0+59},{ly+6} h12 M{x0+59},{ly+9} h9", "#f0f0e8", 0.6, 0.8))
    # anchor plaque
    b.append(P.shape(ell(W / 2, y0 + h / 4, 9), "wood", s=1, lw=1.2, fill_override="#2e3e58"))
    b.append(lin(f"M{W/2},{y0+h/4-6} v11 M{W/2-5},{y0+h/4+2} q5,6 10,0 M{W/2-4},{y0+h/4-3} h8", PAL["gold"][0], 1.2))
    b.append(P.shape(ell(x0 + 4, y0 + 4, 5), "darkiron", s=0.6, lw=1.1))
    emit = J([glow(P, x0 + 4, y0 + 4, 14, EMBER_HOT, 0.55), fill(ell(x0 + 4, y0 + 4, 2.4), EMBER_HOT)])
    return sh, J(b), emit


# ================================================================ herbalist
def herb_counter(P, W, H):
    """The herbalist's counter: mortar and pestle, brass scales, paper twists, jars and a bundle of sage."""
    sh = sh_(P, rect(4, 6, W - 8, H - 12, 3))
    b = [planks(P, 4, 6, W - 8, H - 12, "wood", n=4, dirn="h", s=3, seed=41),
         P.shape(rect(4, 6, W - 8, 6, 2), "brown", s=1, lw=1.5)]
    b.append(P.shape(ell(34, 32, 13), "stone", s=2, lw=1.5))
    b.append(fill(ell(34, 32, 8), PAL["green"][1], 0.9))
    b.append(P.shape(rect(36, 18, 5, 20, 2.4), "stone", s=0.6, lw=1.1))
    b.append(P.shape(rect(70, 30, 40, 3, 1), "bronze", s=0.5, lw=1.2))
    for x in (72, 108):
        b.append(P.shape(ell(x, 31.5, 8), "bronze", s=1.5, lw=1.3))
    b.append(fill(ell(108, 31.5, 4), PAL["moss"][1], 0.9))
    for i, x in enumerate((130, 146, 162)):
        b.append(P.shape(f"M{x},{40} l6,-14 l6,14 Z", "paper", s=0.6, lw=1.0))
        b.append(lin(f"M{x+6},26 l0,-3", PAL["burlap"][2], 0.8))
    for i, (x, liq) in enumerate([(186, "brew"), (200, "amber"), (214, "wine")]):
        b.append(P.shape(ell(x, 28, 7), "glass", s=1, lw=1.1))
        b.append(fill(ell(x, 28, 5), PAL[liq][1], 0.85))
        b.append(P.shape(ell(x, 28, 3), "wood", s=0.4, lw=0.7))
    b.append(bundle_hang(P, 232, 16, 26, "green", 3, dried=True))
    b.append(P.shape(rect(14, 42, 20, 10, 1), "paper", s=0.6, lw=1.0))
    return sh, J(b), ""


def jar_shelf(P, W, H):
    sh = sh_(P, rect(4, 4, W - 8, H - 8, 2), 3, 4)
    b = [shelf_box(P, 4, 4, W - 8, H - 8, "wood")]
    rnd = random.Random(31)
    x = 13
    i = 0
    while x < W - 12:
        r = rnd.uniform(5.5, 7.5)
        if i % 4 == 2:
            b.append(bottle_top(P, x, H / 2, r * 0.8, rnd.choice(["brew", "amber", "wine", "moss"])))
        else:
            b.append(P.shape(ell(x, H / 2, r), "clay", s=1.2, lw=1.2, fill_override=rnd.choice(["#b47a56", "#c8b490", "#8a9a7a"])))
            b.append(P.shape(ell(x, H / 2, r * 0.55), "linen", s=0.4, lw=0.8))
            b.append(lin(ell(x, H / 2, r * 0.7), PAL["burlap"][2], 0.7))
        x += r * 2 + 2.4
        i += 1
    return sh, J(b), ""


@decal
def herb_garlands(P, W, H):
    """Herb bundles hung from a ceiling string, seen from below the roof line (floor decal shadowing)."""
    b = [lin(f"M2,10 Q{W/2},16 {W-2},10", PAL["burlap"][2], 1.2)]
    roles = [("green", False), ("moss", True), ("straw", True), ("green", False), ("foliage2", True)]
    for i, x in enumerate(range(12, W - 6, 18)):
        role, dried = roles[i % len(roles)]
        yy = 10 + 6 * math.sin(math.pi * x / W)
        b.append(bundle_hang(P, x, yy, 22 + (i % 3) * 3, role, 60 + i, dried))
    return "", J(b), ""


def herb_baskets(P, W, H):
    rnd = random.Random(17)
    sh = sh_(P, rect(4, 6, W - 8, H - 10, 8), 3, 4)
    b = []
    for i, (x, y, r, fillc) in enumerate([(22, 24, 17, "#8c9a64"), (56, 22, 15, "#c8b4e0"), (76, 44, 14, "#d8b040"), (34, 48, 13, PAL["apple"][1])]):
        b.append(P.shape(ell(x, y, r), "straw", s=1.5, lw=1.3, fill_override="#b8945a"))
        b.append(lin(" ".join(f"M{x-r*0.9:.1f},{y+k:.1f} h{r*1.8:.1f}" for k in range(-int(r * 0.8), int(r * 0.8), 4)), PAL["straw"][2], 0.6, 0.5))
        b.append(fill(blob(x, y, r * 0.72, 7, 0.2, i), fillc, 0.95))
        b.append(fill(" ".join(ell(x + rnd.uniform(-r * 0.5, r * 0.5), y + rnd.uniform(-r * 0.5, r * 0.5), 1.4) for _ in range(9)), INK, 0.35))
    return sh, J(b), ""


@decal
def herb_garden(P, W, H):
    """Raised kitchen-garden bed of herbs edged with stones."""
    rnd = random.Random(23)
    b = [fill(rect(4, 4, W - 8, H - 8, 8), PAL["mud"][1], 0.85)]
    for i in range(16):
        x, y = rnd.uniform(16, W - 16), rnd.uniform(16, H - 16)
        col = rnd.choice(["#8c9a64", "#7e8e5a", "#a8b47a", "#9a86b0", "#c8c48a"])
        b.append(P.shape(blob(x, y, rnd.uniform(6, 10), 7, 0.25, i), "foliage", s=0.8, lw=0.9, fill_override=col))
    for k in range(0, int(2 * (W + H) / 12)):
        t = k * 12
        if t < W:
            x, y = t + 6, 5
        elif t < W + H:
            x, y = W - 5, t - W + 6
        elif t < 2 * W + H:
            x, y = 2 * W + H - t - 6, H - 5
        else:
            x, y = 5, 2 * (W + H) - t - 6
        b.append(P.shape(blob(x, y, 5, 5, 0.2, k), "stone", s=1, lw=0.9))
    return "", J(b), ""


def potting_bench(P, W, H):
    sh = sh_(P, rect(4, 6, W - 8, H - 12, 3))
    b = [planks(P, 4, 6, W - 8, H - 12, "wood", n=3, dirn="h", s=2.5, seed=51)]
    for i, x in enumerate((22, 46, 70)):
        b.append(P.shape(ell(x, 28, 10), "clay", s=1.5, lw=1.3))
        b.append(fill(ell(x, 28, 7), PAL["mud"][2], 0.9))
        b.append(P.shape(blob(x, 27, 6, 6, 0.25, i), "foliage", s=0.6, lw=0.9))
    b.append(P.shape(rect(90, 14, 26, 30, 2), "metal", s=1, lw=1.2, fill_override="#8a8a7a"))
    b.append(lin("M94,18 l18,22", PAL["wood"][1], 2.0))
    return sh, J(b), ""


# ================================================================ Barnaby's Ironfront den
def _tank(P, x, y, s, ang, col="olive", seed=1):
    """Model tank seen from above: hull, tracks, turret and barrel (s = hull length)."""
    tf = f'transform="rotate({ang} {x:.1f} {y:.1f})"'
    w = s * 0.62
    o = [P.shape(rect(x - s / 2, y - w / 2 - 2, s, 3.4, 1), "coal", s=0.4, lw=0.8),
         P.shape(rect(x - s / 2, y + w / 2 - 1.4, s, 3.4, 1), "coal", s=0.4, lw=0.8),
         P.shape(rect(x - s / 2 + 1, y - w / 2 + 1, s - 2, w - 2, 1.6), col, s=1, lw=1.0),
         P.shape(ell(x - s * 0.05, y, w * 0.32), col, s=0.8, lw=0.9),
         P.shape(rect(x + w * 0.2, y - 1, s * 0.55, 2, 0.8), "darkiron", s=0.3, lw=0.7)]
    return f'<g {tf}>' + J(o) + "</g>"


def _card(P, x, y, w=9, h=13, ang=0, back=False, seed=0):
    rnd = random.Random(seed)
    tf = f'transform="rotate({ang} {x+w/2:.1f} {y+h/2:.1f})"'
    if back:
        o = [P.shape(rect(x, y, w, h, 1.2), "cloth", s=0.4, lw=0.8, fill_override="#4e3a2a"),
             lin(rect(x + 1.5, y + 1.5, w - 3, h - 3, 0.8), GILT, 0.5, 0.9), fill(ell(x + w / 2, y + h / 2, 1.6), GILT)]
    else:
        o = [P.shape(rect(x, y, w, h, 1.2), "paper", s=0.4, lw=0.8),
             fill(rect(x + 1.2, y + 1.6, w - 2.4, h * 0.45), rnd.choice([PAL["olive"][1], "#6e86a0", "#a85a3e", "#8a7a5a"]), 0.9),
             lin(f"M{x+1.5},{y+h*0.7:.1f} h{w-3:.1f} M{x+1.5},{y+h*0.82:.1f} h{w-4:.1f}", INK, 0.4, 0.6)]
    return f'<g {tf}>' + J(o) + "</g>"


def felt_table(P, W, H):
    """Ironfront game table: oak frame, green felt with a hex-ruled battlefield, model tanks on both sides,
    hands of cards, dice, a rulebook and two tankards."""
    rnd = random.Random(61)
    sh = sh_(P, rect(6, 6, W - 12, H - 12, 6), 5, 6)
    b = [P.shape(rect(6, 6, W - 12, H - 12, 8), "wood", s=4, fill_override="#7a5636"),
         P.shape(rect(18, 18, W - 36, H - 36, 4), "felt", s=-2, hl=False, lw=1.6)]
    # hex/square grid of the field, front line and objective markers
    grid = " ".join(f"M{x},{20} L{x},{H-20}" for x in range(34, W - 20, 16)) + " " + " ".join(f"M20,{y} L{W-20},{y}" for y in range(34, H - 20, 16))
    b.append(lin(grid, FELT[0], 0.6, 0.5))
    b.append(lin(f"M20,{H/2} L{W-20},{H/2}", "#e8e0c0", 1.0, 0.6))
    b.append(fill(" ".join(ell(x, H / 2, 4) for x in (W * 0.3, W * 0.7)), RUB, 0.85))
    for i in range(4):
        b.append(_tank(P, W * 0.22 + i * W * 0.18 + rnd.uniform(-4, 4), H / 2 - 26 + rnd.uniform(-5, 5), 24, 90 + rnd.uniform(-20, 20), "olive", i))
        b.append(_tank(P, W * 0.3 + i * W * 0.18 + rnd.uniform(-4, 4), H / 2 + 26 + rnd.uniform(-5, 5), 24, -90 + rnd.uniform(-20, 20), "slate", i + 5))
    # a ruined farmhouse and a forest copse as terrain pieces
    b.append(P.shape(rect(W * 0.46, H / 2 - 9, 18, 18, 1), "stone", s=1, lw=1.0))
    b.append(lin(f"M{W*0.46+2:.1f},{H/2-7:.1f} l14,14", INK, 0.8))
    for k in range(4):
        b.append(P.shape(blob(W * 0.8 + (k % 2) * 9, H / 2 - 6 + (k // 2) * 10, 6, 6, 0.2, k), "foliage", s=0.6, lw=0.8))
    # card hands on the north and south rails, decks, dice, rulebook
    for k in range(5):
        b.append(_card(P, W / 2 - 24 + k * 9, 6, ang=(k - 2) * 8, seed=k))
        b.append(_card(P, W / 2 - 24 + k * 9, H - 19, ang=(k - 2) * -8, back=True))
    b.append(_card(P, 26, 26, back=True))
    b.append(_card(P, W - 38, H - 40, back=True))
    for x, y in [(W - 40, 28), (W - 30, 34)]:
        b.append(P.shape(rect(x, y, 7, 7, 1.4), "ivory", s=0.5, lw=0.8))
        b.append(fill(" ".join(ell(x + 2 + (j % 2) * 3, y + 2 + (j // 2) * 3, 0.8) for j in range(4)), INK))
    b.append(book(P, 24, H - 46, 22, 16, "cloth"))
    b.append(tankard(P, 14, 14, 5.5))
    b.append(tankard(P, W - 14, H - 14, 5.5))
    return sh, J(b), ""


def war_map_wall(P, W, H):
    """Wall-mounted campaign map: pinned paper with coastlines, front lines, arrows and unit flags."""
    rnd = random.Random(71)
    sh = sh_(P, rect(4, 4, W - 8, H - 8, 2), 3, 4)
    b = [backboard(P, 4, 2, W - 8, 6, role="wood"),
         P.shape(rect(8, 7, W - 16, H - 11, 1.5), "paper", s=1.2, lw=1.3)]
    coast = smooth([(10, 18), (40, 14), (70, 22), (100, 16), (130, 24), (160, 18), (W - 10, 22)], close=False)
    b.append(lin(coast, "#6e86a0", 1.6, 0.9))
    b.append(lin("M30,30 q20,-6 40,0 t40,2 t40,-4 t40,2", RUB, 1.4, 0.95))
    for x in range(26, W - 20, 28):
        b.append(lin(f"M{x},{H-10} l8,-8 m-4,-1 l4,1 l-1,4", "#2e3e58", 1.0, 0.9))
    for i in range(7):
        x, y = rnd.uniform(16, W - 16), rnd.uniform(12, H - 8)
        b.append(fill(ell(x, y, 1.6), rnd.choice([RUB, "#2e3e58", GILT])))
    b.append(lin(rect(10, 9, W - 20, H - 15, 1), PAL["paper"][2], 0.6, 0.7))
    return sh, J(b), ""


def diagram_board(P, W, H):
    """Board of military diagrams: tank cross-sections, armour angles and a chalked formation."""
    sh = sh_(P, rect(4, 4, W - 8, H - 8, 2), 3, 4)
    b = [backboard(P, 4, 2, W - 8, 6, role="wood"), P.shape(rect(8, 7, W - 16, H - 11, 1.5), "slate", s=1, lw=1.3, fill_override="#3e4440")]
    ch = "#e8e4d8"
    b.append(lin("M16,26 h30 l6,-6 h-22 l-4,-6 h-10 Z M22,26 v4 M42,26 v4", ch, 0.9, 0.85))
    b.append(lin("M60,14 l20,0 l0,16 M60,14 l20,16 M66,30 a8,8 0 0,1 10,-6", ch, 0.8, 0.8))
    b.append(lin(" ".join(f"M{x},{14 + (x % 3) * 4} l4,4 m-4,0 l4,-4" for x in range(92, W - 14, 10)), ch, 0.8, 0.85))
    b.append(lin(f"M90,30 Q{W-40},16 {W-14},28", RUB, 1.0, 0.9))
    for i in range(3):
        b.append(P.shape(rect(20 + i * 30, 7, 6, 4, 1), "paper", s=0.3, lw=0.6))
    return sh, J(b), ""


def tank_shelf(P, W, H):
    """Shelf of painted model tanks and armoured cars."""
    sh = sh_(P, rect(4, 4, W - 8, H - 8, 2), 3, 4)
    b = [shelf_box(P, 4, 4, W - 8, H - 8, "wood")]
    cols = ["olive", "slate", "olive", "brown", "slate", "olive"]
    for i, x in enumerate(range(18, W - 10, 20)):
        b.append(_tank(P, x, H / 2, 16, 0 if i % 2 else 180, cols[i % len(cols)], i))
    return sh, J(b), ""


def diorama_table(P, W, H):
    """A terrain diorama: a hill, a river crossing with a broken bridge, trench lines and little vehicles."""
    rnd = random.Random(81)
    sh = sh_(P, rect(4, 4, W - 8, H - 8, 4), 4, 5)
    b = [P.shape(rect(4, 4, W - 8, H - 8, 4), "wood", s=3, fill_override="#6a4a2c"),
         P.shape(rect(12, 12, W - 24, H - 24, 3), "green", s=-1, hl=False, lw=1.4, fill_override="#9a9a6a")]
    b.append(P.shape(blob(W * 0.3, H * 0.4, 22, 8, 0.15, 2), "green", s=2, lw=1.0, fill_override="#8a8a5a"))
    b.append(lin(" ".join(wobbly_ell(W * 0.3, H * 0.4, r, r * 0.8, r, 0.05) for r in (8, 14, 19)), PAL["mud"][2], 0.6, 0.6))
    river = f"M{W*0.62},12 Q{W*0.5},{H*0.5} {W*0.66},{H-12}"
    b.append(lin(river, INK, 9))
    b.append(lin(river, "#6e86a0", 7))
    b.append(P.shape(rect(W * 0.5, H * 0.46, 26, 6, 1), "wood", s=0.6, lw=1.0))
    b.append(lin(f"M18,{H-22} l12,-4 l10,4 l12,-4 l10,4", PAL["mud"][2], 2.4, 0.9))
    for i in range(5):
        b.append(_tank(P, rnd.uniform(24, W - 24), rnd.uniform(22, H - 22), 12, rnd.uniform(0, 360), rnd.choice(["olive", "slate"]), i))
    for i in range(6):
        b.append(P.shape(blob(rnd.uniform(18, W - 18), rnd.uniform(16, H - 16), 4, 6, 0.2, i), "foliage", s=0.5, lw=0.8))
    return sh, J(b), ""


def card_cabinet(P, W, H):
    """Cabinet of card drawers with brass pulls, binders and boxed decks on top."""
    sh = sh_(P, rect(4, 4, W - 8, H - 8, 2), 3, 4)
    b = [P.shape(rect(4, 4, W - 8, H - 8, 3), "brown", s=3)]
    for i in range(6):
        x = 10 + i * ((W - 20) / 6)
        b.append(P.shape(rect(x, 9, (W - 20) / 6 - 3, H - 18, 1.5), "wood", s=1, lw=1.1))
        b.append(P.shape(ell(x + (W - 20) / 12 - 1.5, H / 2, 2.4, 1.6), "bronze", s=0.4, lw=0.8))
        b.append(P.shape(rect(x + 3, 12, (W - 20) / 6 - 9, 5, 0.6), "paper", s=0.2, lw=0.5))
    return sh, J(b), ""


def card_binders(P, W, H):
    """Shelf of fat card binders and boxed decks, spines labelled by faction."""
    rnd = random.Random(91)
    sh = sh_(P, rect(4, 4, W - 8, H - 8, 2), 3, 4)
    b = [shelf_box(P, 4, 4, W - 8, H - 8, "wood")]
    x = 9
    while x < W - 16:
        w = rnd.uniform(8, 13)
        role = rnd.choice(["olive", "cloth", "blue", "leather", "slate"])
        b.append(P.shape(rect(x, 8, w, H - 16, 1.2), role, s=0.8, lw=1.0))
        b.append(fill(rect(x + 2, H / 2 - 3, w - 4, 6, 0.6), PAL["paper"][0], 0.9))
        x += w + 1.0
        if rnd.random() < 0.25 and x < W - 26:
            b.append(_card(P, x + 1, 10, 10, 14, back=True))
            x += 13
    return sh, J(b), ""


def paint_desk(P, W, H):
    """Hobby desk: paint pots, brushes in a jar, a half-painted tank, a lamp and a magnifier."""
    rnd = random.Random(101)
    sh = sh_(P, rect(4, 6, W - 8, H - 12, 3))
    b = [planks(P, 4, 6, W - 8, H - 12, "wood", n=3, dirn="h", s=2.5, seed=7)]
    for i in range(8):
        x, y = 14 + (i % 4) * 11, 18 + (i // 4) * 12
        b.append(P.shape(ell(x, y, 4.2), "ivory", s=0.4, lw=0.8))
        b.append(fill(ell(x, y, 3), rnd.choice([RUB, "#5e7a52", "#2e3e58", GILT, "#7c7c50", INK, "#a8825a", "#f0ece0"])))
    b.append(P.shape(ell(70, 22, 7), "glass", s=0.8, lw=1.0))
    b.append(lin("M70,22 l-5,-10 M70,22 l1,-12 M70,22 l6,-9", PAL["wood"][1], 1.4))
    b.append(_tank(P, 72, 42, 20, 20, "slate", 3))
    b.append(fill(ell(76, 40, 4), "#5e7a52", 0.6))
    b.append(P.shape(ell(W - 22, 22, 9), "darkiron", s=1, lw=1.2))
    b.append(P.shape(ell(W - 22, 22, 5), "bronze", s=0.5, lw=0.8))
    b.append(P.shape(ell(W - 30, 46, 7), "glass", s=0.6, lw=1.2))
    b.append(lin(f"M{W-25},51 l7,7", PAL["wood"][1], 2.2))
    emit = J([glow(P, W - 22, 22, 26, EMBER_HOT, 0.5)])
    return sh, J(b), emit


def standing_lamp(P, W, H):
    cx, cy = W / 2, H / 2
    sh = sh_(P, ell(cx, cy, 12), 3, 4)
    b = [P.shape(ell(cx, cy, 13), "darkiron", s=1.2, lw=1.3), P.shape(ell(cx, cy, 9), "bronze", s=1, lw=1.0),
         fill(ell(cx, cy, 5), EMBER_HOT, 0.9)]
    emit = J([glow(P, cx, cy, 18, EMBER_HOT, 0.6)])
    return sh, J(b), emit


# ================================================================ stable, cooper, chandler
def horse(P, W, H):
    """A bay horse standing in its stall, seen from above, head to the north: broad barrel, withers and croup,
    a long neck and narrow head with ears, dark mane and tail, a saddle blanket."""
    cx = W / 2
    sh = sh_(P, ell(cx, H * 0.58, 22, 50), 4, 5)
    body = smooth([(cx - 13, 50), (cx - 22, 64), (cx - 23, 86), (cx - 21, 108), (cx - 16, 124), (cx - 7, 130), (cx + 7, 130),
                   (cx + 16, 124), (cx + 21, 108), (cx + 23, 86), (cx + 22, 64), (cx + 13, 50), (cx + 7, 46), (cx - 7, 46)])
    neck = smooth([(cx - 8, 52), (cx - 9, 34), (cx - 7, 22), (cx + 7, 22), (cx + 9, 34), (cx + 8, 52)])
    head = smooth([(cx - 7, 26), (cx - 6, 12), (cx - 4.5, 3), (cx, 1), (cx + 4.5, 3), (cx + 6, 12), (cx + 7, 26)])
    b = [P.shape(body, "hide", s=4, fill_override="#8a5a36"), P.shape(neck, "hide", s=2, fill_override="#7e5030"),
         P.shape(head, "hide", s=1.5, fill_override="#7a4c2c"),
         P.shape(f"M{cx-6},20 l-3,-7 l5,3 Z M{cx+6},20 l3,-7 l-5,3 Z", "hide", s=0.4, lw=1.0, fill_override="#5a3820"),
         lin(f"M{cx},14 C{cx-1},30 {cx+1},40 {cx},52", "#2a1a10", 4.2, 0.95), fill(ell(cx, 4, 3, 2), "#3a2416", 0.8),
         P.detail(f"M{cx-14},74 q14,6 28,0 M{cx-15},104 q15,6 30,0 M{cx},110 l0,16", "hide", 0.4, 0.6),
         P.shape(rect(cx - 15, 62, 30, 26, 4), "cloth", s=1, lw=1.1, fill_override="#6a2a1e"),
         lin(rect(cx - 12, 65, 24, 20, 2), GILT, 0.8, 0.8),
         lin(f"M{cx},130 q-3,7 1,13 M{cx-2},130 q-5,6 -3,12 M{cx+2},130 q4,6 3,12", "#2a1a10", 2.6)]
    return sh, J(b), ""


def rowboat(P, W, H):
    """Clinker-built rowing boat seen from above, bow to the east, two thwarts, oars shipped."""
    cy = H / 2
    hull = smooth([(6, cy), (14, cy - 15), (40, cy - 19), (70, cy - 15), (W - 6, cy), (70, cy + 15), (40, cy + 19), (14, cy + 15)])
    inner = smooth([(12, cy), (18, cy - 11), (40, cy - 14), (68, cy - 10), (W - 14, cy), (68, cy + 10), (40, cy + 14), (18, cy + 11)])
    b = [fill(ell(W / 2 + 2, cy + 3, W * 0.48, H * 0.46), "#ffffff", 0.12),
         P.shape(hull, "wood", s=3, fill_override="#7a5636"), P.shape(inner, "wood", s=-2, hl=False, lw=1.2, fill_override="#a07a52"),
         P.detail(" ".join(f"M{x},{cy-12} L{x},{cy+12}" for x in (22, 30, 50, 58, 66)), "wood", 0.3, 0.5)]
    for x in (36, 60):
        b.append(P.shape(rect(x - 3, cy - 14, 6, 28, 1), "wood", s=1, lw=1.0))
    b.append(lin(f"M30,{cy-6} L76,{cy-22} M30,{cy+6} L76,{cy+22}", PAL["wood"][1], 2.4))
    b.append(lin(f"M30,{cy-6} L76,{cy-22} M30,{cy+6} L76,{cy+22}", INK, 0.6, 0.8))
    b.append(fill(ell(14, cy, 4, 6), "#6e86a0", 0.6))
    b.append(lin(f"M{W-8},{cy} q8,4 14,0", PAL["burlap"][1], 1.6))
    return "", J(b), ""


def water_trough(P, W, H):
    sh = sh_(P, rect(4, 6, W - 8, H - 12, 3))
    d = rect(10, 11, W - 20, H - 22, 2)
    b = [P.shape(rect(4, 6, W - 8, H - 12, 3), "wood", s=2), liquid(P, d, "water", W / 2, H / 2, W / 2 - 10, H / 2 - 11, ripples=1)]
    b.append(fill(ell(W * 0.7, H / 2, 4, 2), PAL["green"][1], 0.7))
    return sh, J(b), ""


def saddle_rack(P, W, H):
    sh = sh_(P, rect(4, 4, W - 8, H - 8, 2), 3, 4)
    b = [backboard(P, 4, 2, W - 8, 6, role="wood")]
    for i, x in enumerate((24, 64)):
        b.append(P.shape(smooth([(x - 14, 10), (x + 14, 10), (x + 16, 28), (x, 34), (x - 16, 28)]), "leather", s=1.5, lw=1.2,
                         fill_override=["#6a3e22", "#7a5636"][i]))
        b.append(lin(f"M{x-10},16 q10,6 20,0", GILT, 0.6, 0.7))
    b.append(lin(f"M{W-22},8 q-6,14 4,26 q8,-10 0,-24", PAL["leather"][1], 1.6))
    return sh, J(b), ""


def barrel_stack(P, W, H):
    """Cooper's yard: finished casks, one on its side, staves leaning."""
    sh = sh_(P, rect(4, 6, W - 8, H - 10, 10))
    b = [barrel_top(P, 26, 28, 20), barrel_top(P, 66, 26, 19), barrel_top(P, 46, 64, 21)]
    b.append(P.shape(rect(76, 48, 30, 40, 9), "wood", s=2))
    b.append(lin("M82,48 v40 M100,48 v40", PAL["darkiron"][1], 2.0))
    b.append(lin("M76,58 h30 M76,78 h30", PAL["wood"][2], 0.7, 0.7))
    return sh, J(b), ""


def stave_bundle(P, W, H):
    sh = sh_(P, rect(4, 8, W - 8, H - 14, 6))
    b = []
    for i in range(7):
        y = 10 + i * 4.4
        b.append(P.shape(f"M8,{y+2} Q{W/2},{y-2} {W-8},{y+2} L{W-8},{y+5.6} Q{W/2},{y+1.6} 8,{y+5.6} Z", "wood", s=0.6, lw=0.9))
    for x in (28, W - 28):
        b.append(lin(f"M{x},8 L{x},{H-6}", INK, 3.0))
        b.append(lin(f"M{x},8 L{x},{H-6}", PAL["darkiron"][1], 1.6))
    return sh, J(b), ""


@decal
def hoop_pile(P, W, H):
    b = [fill(ell(W / 2 + 3, H / 2 + 3, 24), INK, 0.15)]
    for i, (x, y, r) in enumerate([(30, 30, 20), (34, 34, 17), (28, 32, 14)]):
        b.append(lin(ell(x, y, r, r * 0.9), INK, 3.6))
        b.append(lin(ell(x, y, r, r * 0.9), PAL["darkiron"][1], 2.2))
        b.append(lin(ell(x, y, r, r * 0.9), PAL["rust"][1], 0.8, 0.6))
    return "", J(b), ""


def candle_rack(P, W, H):
    """Chandler's drying rack: rows of dipped tapers hanging in pairs by their wicks."""
    sh = sh_(P, rect(4, 4, W - 8, H - 8, 2), 3, 4)
    b = [backboard(P, 4, 2, W - 8, 6, role="wood")]
    for row in range(2):
        for x in range(12, W - 8, 8):
            y = 12 + row * 16
            b.append(lin(f"M{x},{y-4} l0,3", INK, 0.6))
            b.append(P.shape(rect(x - 2.2, y, 4.4, 11, 2), "wax", s=0.6, lw=0.8,
                             fill_override=["#f2e8cc", "#e8d8a8", "#f6ecd4"][(x // 8 + row) % 3]))
    return sh, J(b), ""


def wax_vat(P, W, H):
    cx, cy = W / 2, H / 2
    sh = sh_(P, ell(cx, cy, 32))
    b = [P.shape(ell(cx, cy, 32), "stone", s=3), P.shape(ell(cx, cy, 25), "darkiron", s=2, lw=1.6),
         liquid(P, ell(cx, cy, 21), "wax", cx, cy, 21, 21, ripples=1),
         lin(f"M{cx-6},{cy-30} L{cx+10},{cy+4}", PAL["wood"][1], 3.0)]
    emit = J([glow(P, cx, cy + 26, 14, EMBER, 0.5)])
    return sh, J(b), emit


# ================================================================ jobs & review
PROPS_V = {k: v for k, v in dict(globals()).items() if callable(v) and not k.startswith("_") and k not in (
    "J", "sh_", "decal", "painter", "sprite_svg", "svg_doc", "soft_filter", "ground_shadow", "glow", "lin", "fill", "planks",
    "end_grain", "liquid", "bottle_top", "candle_top", "render", "load", "only_filter", "ell", "rect", "poly", "smooth", "blob",
    "wobbly_ell", "blur_filter", "hatch", "tankard", "book", "barrel_top", "crate_top", "sack_top", "rock", "bundle_hang",
    "shelf_box", "backboard", "noise_clip", "open_crate", "jobs", "contact_sheets")}


def jobs():
    only = only_filter()
    js = []
    props = load("props.json")
    for pid, fn in PROPS_V.items():
        if pid not in props or (only and pid not in only):
            continue
        W, H = props[pid]["size"]
        P = painter(scale=1.0, lw_mul=0.7)
        sh, body, emit = fn(P, W, H)
        if pid in DECALS:
            svg = svg_doc(W, H, P, f'<g {soft_filter(P, 0.8)}>{sh}{body}</g><g>{emit}</g>', ss=3)
        else:
            svg = sprite_svg(P, W, H, sh, body, emit, ss=3, wob=0.9, dil=0.7, grain=0.45, soot=0.6)
        js.append(dict(name=f"pv_{pid}", svg=svg, w=W, h=H, ss=3, out=os.path.join(SPR, "props", pid + ".png")))
    return js


def contact_sheets():
    import contact
    props = load("props.json")
    pf = [os.path.join(SPR, "props", "template_" + p + ".png") for p in PROPS_V if p in props]
    contact.sheet("village9_props", pf, zoom=1.0, max_w=1600)
    contact.sheet("village9_props_ground", pf, zoom=1.0, max_w=1600, bg=(196, 176, 130))


if __name__ == "__main__":
    render(jobs())
    contact_sheets()
