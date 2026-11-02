"""Interior decor pass: room props/decals, five interior floor/wall textures and the station marker.
Same pipeline + conventions as make_props / make_textures / make_ui (Painter "ink_parchment_gothic_80_20",
final-size rendering with lw_mul, hatched ground shadow toward bottom-right inside the canvas, transparent bg).
Prop ids/sizes come from game/data/props.json (written by tools/data/make_data.py).
python3 make_interiors.py [--only=tool_wall,floor_soot,station_marker]   (also writes sheet_interiors*.png)"""
import math
import os
import random
import artlib  # noqa: F401  (sets sys.path)
from artlib import (painter, sprite_svg, svg_doc, ink_filter, soft_filter, ground_shadow, glow, lin, fill, planks,
                    end_grain, bottle_top, candle_top, rune_glyphs, lit_marks, sigil_ring, render, load, only_filter,
                    ell, rect, poly, smooth, blob, wobbly_ell, uid, ST, INK, EMBER, EMBER_HOT, RUB, GILT, SPR, OUT, SOOT,
                    VIOLET, VIOLET_HOT, RUNE_GOLD, BREW_HOT, blur_filter, hatch)
from make_props import tankard, plate, book, sword_top, barrel_top, crate_top, sack_top
from make_stations import pelt, spool, thread_line, herb_sprig
import make_textures as mt
from PIL import Image

PAL = ST["pal"]
# extra muted materials for this pass (new keys only; existing roles untouched)
PAL.setdefault("amber", ("#e8c88a", "#b8873a", "#5e3e12"))
PAL.setdefault("wine", ("#c48a7c", "#8a3a2c", "#46160e"))
PAL.setdefault("moss", ("#b8c49a", "#7e8e5a", "#3e4a28"))
PAL.setdefault("rust", ("#c08a6a", "#8a5236", "#3e2214"))
PAL.setdefault("ivory", ("#f4ecd6", "#ddcfae", "#8e7e5c"))
PAL.setdefault("pewter", ("#d4d4cc", "#9c9c94", "#56564e"))
PAL.setdefault("sootstone", ("#aea290", "#857a68", "#433a30"))
PAL.setdefault("tile", ("#e2caa4", "#c8a87e", "#7a5e40"))
PAL.setdefault("darkstone", ("#7c7680", "#55505a", "#2a262e"))
GHOST = "#dce6ff"


GLYPHS = [
    lambda x, y, s: f"M{x},{y-s} L{x},{y+s} M{x},{y-s*0.4} L{x+s*0.6},{y-s} M{x},{y} L{x+s*0.6},{y-s*0.4}",
    lambda x, y, s: f"M{x},{y-s} L{x},{y+s} M{x-s*0.6},{y-s*0.5} L{x+s*0.6},{y+s*0.1}",
    lambda x, y, s: f"M{x},{y-s} L{x},{y+s} M{x-s*0.55},{y-s*0.55} L{x},{y} L{x+s*0.55},{y-s*0.55}",
    lambda x, y, s: f"M{x},{y-s} L{x},{y+s} M{x-s*0.5},{y+s*0.2} L{x},{y-s*0.3} L{x+s*0.5},{y+s*0.2}",
    lambda x, y, s: f"M{x-s*0.3},{y-s} L{x-s*0.3},{y+s} M{x-s*0.3},{y-s*0.6} L{x+s*0.4},{y-s*0.1} L{x-s*0.3},{y+s*0.3}",
    lambda x, y, s: f"M{x-s*0.5},{y-s} L{x+s*0.4},{y-s*0.2} L{x-s*0.4},{y+s*0.4} L{x+s*0.5},{y+s}",
]


def glyph(rnd, x, y, s):
    """Rune-like mark that cannot be read as a latin letter (no A / X / > shapes)."""
    return rnd.choice(GLYPHS)(x, y, s)


def J(o):
    return "\n".join(x for x in o if x)


def sh_(P, d, dx=4, dy=5, **k):
    return ground_shadow(P, d, dx, dy, **k)


def backboard(P, x, y, w, h=9, role="brown", pegs=()):
    """Wall batten / board: the hint of a top face for wall-mounted racks."""
    o = [P.shape(rect(x, y, w, h, 2), role, s=1.5, lw=1.6),
         P.detail(f"M{x+3},{y+h*0.5:.1f} L{x+w-3},{y+h*0.5:.1f}", role, 0.3, 0.5)]
    if pegs:
        o.append(fill(" ".join(ell(px, y + h * 0.5, 1.3) for px in pegs), INK, 0.85))
    return J(o)


def shelf_box(P, x, y, w, h, role="wood"):
    return J([P.shape(rect(x, y, w, h, 2), role, s=2), P.shape(rect(x + 3, y + 3, w - 6, h - 6, 1.5), "brown", s=-1.5, hl=False, lw=1.2)])


# ======================================================================= SMITHY
def hammer_hang(P, x, y, L=30, hw=16, seed=1):
    return J([P.shape(rect(x - 2, y + 4, 4, L, 1.5), "wood", s=0.6, lw=1.2),
              P.shape(rect(x - hw / 2, y, hw, 8, 1.5), "darkiron", s=1.2, lw=1.4),
              P.detail(f"M{x-hw/2+2},{y+4} L{x+hw/2-2},{y+4}", "darkiron", 0.3, 0.6),
              fill(rect(x - hw / 2 + 0.5, y + 1, 2, 6), PAL["metal"][0], 0.6)])


def tongs_hang(P, x, y, L=34, spread=5):
    o = []
    for s_ in (-1, 1):
        d = f"M{x+s_*1.2:.1f},{y+2} L{x+s_*spread:.1f},{y+L:.1f}"
        o += [lin(d, INK, 3.4), lin(d, PAL["darkiron"][1], 1.6)]
    jaw = f"M{x-3},{y+2} Q{x},{y-3} {x+3},{y+2}"
    o += [lin(jaw, INK, 3.6), lin(jaw, PAL["darkiron"][0], 1.4), fill(ell(x, y + 9, 1.8), INK), fill(ell(x, y + 9, 0.8), PAL["metal"][0])]
    return J(o)


def file_hang(P, x, y, L=30):
    o = [P.shape(rect(x - 2.2, y, 4.4, L * 0.68, 1), "metal", s=0.5, lw=1.1),
         P.detail(" ".join(f"M{x-2},{y+2+i*2.2:.1f} l4,1.4" for i in range(int(L * 0.6 / 2.2))), "metal", 0.25, 0.7),
         P.shape(rect(x - 2.6, y + L * 0.68, 5.2, L * 0.32, 2), "wood", s=0.6, lw=1.1)]
    return J(o)


def tool_wall(P, W, H):
    sh = sh_(P, rect(4, 3, 150, 38, 3))
    b = [backboard(P, 4, 3, 150, 9, pegs=[16, 34, 54, 74, 94, 112, 130, 146])]
    b.append(hammer_hang(P, 16, 8, 28, 16))
    b.append(hammer_hang(P, 34, 9, 24, 12))
    b.append(tongs_hang(P, 54, 8, 32))
    b.append(tongs_hang(P, 72, 8, 28, 4))
    b.append(file_hang(P, 88, 10, 28))
    b.append(file_hang(P, 98, 10, 24))
    b.append(hammer_hang(P, 114, 8, 30, 18))
    # set hammer / fuller (rounded head)
    b.append(J([P.shape(rect(132, 12, 4, 26, 1.5), "wood", s=0.6, lw=1.2), P.shape(ell(134, 11, 6, 4.5), "darkiron", s=1, lw=1.4)]))
    b.append(tongs_hang(P, 146, 8, 30, 3.5))
    # soot smudge on the board
    b.append(fill(ell(80, 8, 40, 4), SOOT, 0.2, blur_filter(P, 2.5)))
    return sh, J(b), ""


def iron_bar(P, x, y, w, h, rust=False, seed=1):
    rnd = random.Random(seed)
    o = [P.shape(rect(x, y, w, h, 1.2), "darkiron", s=min(w, h) * 0.3, lw=1.3)]
    o.append(fill(rect(x + 1, y + 0.8, w - 2, h * 0.3, 0.6), PAL["metal"][1], 0.45))
    if rust:
        o.append(fill(" ".join(ell(x + rnd.uniform(0.1, 0.9) * w, y + h * rnd.uniform(0.3, 0.7), rnd.uniform(1.5, 3.5), h * 0.3) for _ in range(3)),
                      PAL["rust"][1], 0.55))
    o.append(P.detail(f"M{x+w-0.8:.1f},{y+1} L{x+w-0.8:.1f},{y+h-1}", "darkiron", 0.4, 0.8))
    return J(o)


def iron_bars(P, W, H):
    sh = sh_(P, rect(6, 6, 80, 50, 4))
    b = []
    # bottom layer: two bearers running vertically
    for x in (14, 70):
        b.append(P.shape(rect(x, 6, 8, 50, 1.5), "wood", s=1, lw=1.4))
    # stacked bars
    for i, y in enumerate((10, 18, 26, 34)):
        b.append(iron_bar(P, 8 + (i % 2) * 3, y, 72 - (i % 3) * 4, 7, rust=i % 2 == 0, seed=i))
    # top layer billets (square stock)
    for i, (x, y) in enumerate([(14, 42), (36, 43), (56, 41)]):
        b.append(P.shape(rect(x, y, 18, 12, 1.5), "darkiron", s=2.5, lw=1.5))
        b.append(fill(rect(x + 2, y + 2, 7, 3), PAL["metal"][1], 0.5))
        b.append(P.detail(f"M{x+4},{y+9} l9,0", "darkiron", 0.3, 0.6))
    b.append(P.shape(rect(76, 40, 8, 16, 1.5), "rust", s=1.5, lw=1.3))
    b.append(lin("M8,24 l78,0", "#120c08", 0.6, 0.35))
    return sh, J(b), ""


def decal_svg(P, W, H, body, wob=1.0):
    """Floor decal: organic marks without the ink silhouette outline (no dilation), soft wobble only."""
    f = soft_filter(P, wob)
    return svg_doc(W, H, P, f'<g {f}>{body}</g>', ss=3)


def noise_clip(P, d, col, freq, slope, off, seed, x, y, w, h, octaves=3):
    """Organic noise texture clipped to path d."""
    cid, fid = uid("nc"), uid("nf")
    r, g, b_ = [int(col[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    P.defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
    P.defs.append(f'<filter id="{fid}" filterUnits="userSpaceOnUse" x="{x}" y="{y}" width="{w}" height="{h}">'
                  f'<feTurbulence type="fractalNoise" baseFrequency="{freq}" numOctaves="{octaves}" seed="{seed}"/>'
                  f'<feColorMatrix values="0 0 0 0 {r:.3f}  0 0 0 0 {g:.3f}  0 0 0 0 {b_:.3f}  {slope} 0 0 0 {off}"/></filter>')
    return f'<g clip-path="url(#{cid})"><rect x="{x}" y="{y}" width="{w}" height="{h}" filter="url(#{fid})"/></g>'


def soot_decal(P, W, H):
    rnd = random.Random(12)
    cx, cy = W / 2, H / 2
    b = []
    outer = blob(cx, cy, 70, 13, 0.16, 5, squash=0.8)
    bl = blur_filter(P, 5)
    b.append(fill(outer, SOOT, 0.22, bl))
    b.append(noise_clip(P, outer, "#1a120c", 0.045, 1.6, -0.55, 3, 0, 0, W, H))
    inner = blob(cx, cy, 50, 9, 0.2, 9, squash=0.78)
    b.append(fill(inner, "#16100b", 0.2, blur_filter(P, 4)))
    # outlying patches
    for i in range(9):
        a = rnd.uniform(0, math.tau)
        r0 = rnd.uniform(52, 74)
        x, y = cx + math.cos(a) * r0, cy + math.sin(a) * r0 * 0.78
        x, y = min(max(x, 14), W - 14), min(max(y, 14), H - 14)
        d = blob(x, y, rnd.uniform(5, 11), 7, 0.25, 20 + i, squash=rnd.uniform(0.6, 1))
        b.append(fill(d, SOOT, rnd.uniform(0.18, 0.32), blur_filter(P, 1.4)))
    # hatched char scorch (ink language) inside the heavy area
    hp = hatch(P, -35, sp=3.4, w=0.8)
    b.append(fill(blob(cx - 6, cy - 4, 38, 8, 0.25, 31, squash=0.7), hp, 0.22))
    # scorch cracks + ash flecks
    cr = []
    for i in range(10):
        a = rnd.uniform(0, math.tau)
        r0 = rnd.uniform(18, 52)
        x, y = cx + math.cos(a) * r0, cy + math.sin(a) * r0 * 0.75
        cr.append(f"M{x:.1f},{y:.1f} l{rnd.uniform(-6,6):.1f},{rnd.uniform(-4,4):.1f} l{rnd.uniform(-5,5):.1f},{rnd.uniform(-4,4):.1f}")
    b.append(lin(" ".join(cr), INK, 0.8, 0.35))
    fl = []
    for i in range(46):
        a = rnd.uniform(0, math.tau)
        r0 = math.sqrt(rnd.uniform(0, 1)) * 80
        x, y = cx + math.cos(a) * r0, cy + math.sin(a) * r0 * 0.78
        if 6 < x < W - 6 and 6 < y < H - 6:
            fl.append(ell(x, y, rnd.uniform(0.6, 1.6)))
    b.append(fill(" ".join(fl[:30]), "#16100b", 0.45))
    b.append(fill(" ".join(fl[30:]), "#b8aa94", 0.5))  # pale ash
    # a few dead embers
    b.append(fill(" ".join(ell(cx + rnd.gauss(0, 20), cy + rnd.gauss(0, 14), rnd.uniform(0.7, 1.2)) for _ in range(6)), EMBER, 0.45))
    return "DECAL", J(b), ""


# ======================================================================= RUNECRAFT
def runestone(P, x, y, r, seed, role="rune"):
    return P.shape(blob(x, y, r, 5, 0.1, seed, squash=0.85), role, s=r * 0.3, lw=1.2)


def rune_shelf(P, W, H):
    sh = sh_(P, rect(4, 4, 118, 34, 2), 3, 4)
    b = [shelf_box(P, 4, 4, 118, 34, "wood")]
    rnd = random.Random(4)
    e = []
    x = 14
    i = 0
    while x < 114:
        r = rnd.uniform(5.2, 7.2)
        y = 21 + rnd.uniform(-3, 3)
        if i % 4 == 2:
            b.append(P.shape(rect(x - r, y - r * 0.7, r * 2, r * 1.4, 2), "slate", s=r * 0.3, lw=1.2))
        else:
            b.append(runestone(P, x, y, r, 30 + i))
        g = glyph(rnd, x, y, r * 0.42)
        b.append(lin(g, INK, 0.8, 0.75))
        if i % 2 == 0:
            e.append(lit_marks(P, g, RUNE_GOLD, "#fff0c0", w=0.6, glow_w=2.2, op=0.8, blur=0.9))
        x += r * 2 + 3.2
        i += 1
    return sh, J(b), J(e)


def rune_glyph_decal(P, W, H):
    cx, cy = W / 2, H / 2
    ring_d, glyph_d = sigil_ring(P, cx, cy, 66, seed=17, n=12)
    rnd = random.Random(3)
    inner = " ".join([ell(cx, cy, 34),
                      poly([(cx + math.cos(a) * 34, cy + math.sin(a) * 34) for a in [-math.pi / 2 + k * math.tau / 3 for k in range(3)]]),
                      poly([(cx + math.cos(a) * 34, cy + math.sin(a) * 34) for a in [math.pi / 2 + k * math.tau / 3 for k in range(3)]])])
    centre = GLYPHS[2](cx, cy, 8)
    b = [lin(ring_d, INK, 1.4, 0.4), lin(inner, INK, 1.0, 0.32),
         lin(ring_d, "#f4ead0", 0.5, 0.25, extra='transform="translate(-0.6,-0.6)"'),
         lin(glyph_d, INK, 1.2, 0.5), lin(centre, INK, 1.4, 0.5),
         fill(" ".join(ell(cx + math.cos(a) * 50, cy + math.sin(a) * 50, 1.1) for a in [k * math.tau / 24 for k in range(24)]), INK, 0.35)]
    b.append(lit_marks(P, glyph_d + " " + centre, RUNE_GOLD, "#fff0c0", w=0.6, glow_w=2.0, op=0.38, blur=1.2))
    b.append(glow(P, cx, cy, 30, RUNE_GOLD, 0.12))
    return "DECAL", J(b), ""


def stone_blocks(P, W, H):
    rnd = random.Random(8)
    slab = poly([(6, 40), (40, 36), (44, 60), (8, 64)])
    blk1 = poly([(8, 8), (30, 5), (34, 30), (10, 34)])
    blk2 = poly([(38, 7), (66, 10), (68, 28), (40, 30)])
    blk3 = poly([(48, 36), (68, 34), (70, 58), (50, 60)])
    sh = sh_(P, " ".join([slab, blk1, blk2, blk3]), 3, 4)
    b = []
    b.append(P.shape(slab, "slate", s=2.5, lw=1.5))
    b.append(P.detail("M10,52 L42,48", "slate", 0.35, 0.6))
    b.append(P.shape(blk1, "rune", s=3, lw=1.6))
    b.append(P.detail("M30,6 L22,18 L10,22 M22,18 L33,26", "rune", 0.45, 0.7))   # facet edges of the rough block
    b.append(P.shape(blk2, "rune", s=3, lw=1.6))
    b.append(P.detail(" ".join(f"M{43+i*4.5},{12+i*0.2:.1f} l2,4" for i in range(5)), "rune", 0.4, 0.7))  # chisel marks
    b.append(P.shape(blk3, "slate", s=2.5, lw=1.5))
    b.append(lin(glyph(rnd, 24, 51, 5) + " " + GLYPHS[1](58, 47, 5), INK, 0.9, 0.75))  # roughed-in runes
    b.append(fill(" ".join(wobbly_ell(rnd.uniform(10, 66), rnd.uniform(30, 36), 1.3, 0.9, i, 0.3, 6) for i in range(6)), PAL["rune"][0], 0.9))
    b.append(lin("M36,32 l3,2 M44,33 l2,1", INK, 0.6, 0.6))
    return sh, J(b), ""


# ======================================================================= ALCHEMY
def bundle_hang(P, x, y, L, role, seed, dried=False):
    """Herb bundle hung head-down from a batten: twine tie at top, stems fanning into a drooping leafy cone."""
    rnd = random.Random(seed)
    o = [lin(f"M{x},{y-4} L{x},{y+1}", PAL["burlap"][2], 1.0)]
    stems = " ".join(f"M{x+rnd.uniform(-0.8,0.8):.1f},{y+1} L{x+k*1.6+rnd.uniform(-0.6,0.6):.1f},{y+L*0.45:.1f}" for k in (-2, -1, 0, 1, 2))
    o.append(lin(stems, INK, 1.7))
    o.append(lin(stems, PAL[role][2], 0.7))
    right, left = [], []
    for k in range(8):
        t = 0.14 + 0.86 * k / 7
        wdt = 2.4 + 4.6 * math.sin(min(1.0, t * 1.15) * math.pi * 0.62) * (1 - max(0, t - 0.8) * 3.2)
        j = 1.6 if k % 2 else 0
        right.append((x + wdt + j, y + L * t + rnd.uniform(-0.6, 0.6)))
        left.append((x - wdt - j * 0.8, y + L * t + 1.2 + rnd.uniform(-0.6, 0.6)))
    cone = smooth(right + [(x, y + L + 1.5)] + left[::-1])
    o.append(P.shape(cone, role, s=1.6, lw=1.2))
    leaves = []
    for k in range(9):
        t = 0.3 + 0.075 * k
        side = -1 if k % 2 else 1
        lx = x + side * rnd.uniform(1.2, 4.2) * min(1, t * 1.6)
        ly = y + L * t
        leaves.append(f'<path d="{ell(lx, ly, 1.3, 2.8)}" fill="{PAL[role][0] if k % 3 else PAL[role][2]}" opacity="0.85" '
                      f'transform="rotate({side*25} {lx:.1f} {ly:.1f})"/>')
    o.append("".join(leaves))
    o.append(P.detail(f"M{x},{y+7} L{x},{y+L*0.9:.1f}", role, 0.35, 0.55))
    o.append(P.shape(rect(x - 2.6, y + 1, 5.2, 3.2, 1), "burlap", s=0.3, lw=0.8))
    if dried:
        o.append(fill(cone, PAL["straw"][1], 0.22))
    return J(o)


def herb_rack(P, W, H):
    sh = sh_(P, rect(4, 3, 150, 38, 3))
    b = [backboard(P, 4, 3, 150, 7, role="wood", pegs=[])]
    roles = [("green", False), ("moss", False), ("straw", True), ("green", False), ("foliage2", True), ("moss", False), ("green", True)]
    for i, x in enumerate(range(16, 150, 20)):
        role, dried = roles[i % len(roles)]
        b.append(bundle_hang(P, x, 10, 28 - (i % 3) * 3, role, 40 + i, dried))
    # lavender-ish sprig dots (muted)
    rnd = random.Random(3)
    b.append(fill(" ".join(ell(76 + rnd.uniform(-3, 3), 26 + rnd.uniform(0, 10), 1.0) for _ in range(9)), "#9a86b0", 0.85))
    return sh, J(b), ""


def bottle_shelf(P, W, H):
    sh = sh_(P, rect(4, 4, 118, 34, 2), 3, 4)
    b = [shelf_box(P, 4, 4, 118, 34, "wood")]
    rnd = random.Random(14)
    libs = ["brew", "amber", "wine", "moss", "amber", "brew", "wine", "amber", "brew"]
    x, i = 13, 0
    while x < 114:
        r = rnd.uniform(4.2, 6.2)
        if i % 5 == 3:  # squat flask / jar
            r = 7
            b.append(P.shape(ell(x + 1, 21, r), "clay", s=1.5, lw=1.3))
            b.append(P.shape(ell(x + 1, 21, r * 0.45), "linen", s=0.5, lw=1))
        else:
            b.append(bottle_top(P, x, 21 + rnd.uniform(-4, 4), r, libs[i % len(libs)]))
        x += r * 2 + 2.6
        i += 1
    b.append(lin("M10,9 l100,0", PAL["linen"][2], 0.6, 0.5))
    return sh, J(b), ""


def open_crate(P, x, y, w, h, seed):
    return J([P.shape(rect(x, y, w, h, 2), "wood", s=2, lw=1.6),
              P.detail(f"M{x+1},{y+h*0.5:.1f} L{x+3},{y+h*0.5:.1f} M{x+w-3},{y+h*0.5:.1f} L{x+w-1},{y+h*0.5:.1f}", "wood", 0.5),
              P.shape(rect(x + 4, y + 4, w - 8, h - 8, 1.5), "brown", s=-2, hl=False, lw=1.2),
              fill(rect(x + 4, y + 4, w - 8, h - 8, 1.5), "#1a120c", 0.35)])


def ingredient_crates(P, W, H):
    sh = sh_(P, rect(4, 4, 84, 68, 3))
    rnd = random.Random(21)
    b = []
    # crate 1: roots
    b.append(open_crate(P, 4, 4, 44, 34, 1))
    roots = []
    for i in range(6):
        x, y = rnd.uniform(10, 38), rnd.uniform(10, 30)
        roots.append(f"M{x:.1f},{y:.1f} q{rnd.uniform(3,6):.1f},{rnd.uniform(-4,4):.1f} {rnd.uniform(6,10):.1f},{rnd.uniform(-2,4):.1f} "
                     f"q{rnd.uniform(1,3):.1f},{rnd.uniform(1,3):.1f} {rnd.uniform(2,4):.1f},{rnd.uniform(2,5):.1f}")
    b.append(lin(" ".join(roots), INK, 3.6))
    b.append(lin(" ".join(roots), PAL["clay"][1], 2.0))
    b.append(lin(" ".join(roots), PAL["clay"][0], 0.6, 0.7))
    # crate 2: mushrooms
    b.append(open_crate(P, 50, 4, 40, 34, 2))
    for i, (x, y, r) in enumerate([(60, 14, 5.5), (72, 13, 4.5), (81, 20, 5), (62, 27, 5), (74, 28, 6)]):
        b.append(P.shape(ell(x, y, r), "hide", s=r * 0.35, lw=1.2))
        b.append(fill(" ".join(ell(x + rnd.uniform(-r, r) * 0.5, y + rnd.uniform(-r, r) * 0.5, 0.7) for _ in range(3)), PAL["ivory"][0], 0.9))
    # crate 3 (long, front): salts in a sack + a jar
    b.append(open_crate(P, 10, 40, 72, 30, 3))
    b.append(sack_top(P, 30, 55, 11, 6))
    salt = blob(30, 55, 6, 7, 0.25, 4)
    b.append(fill(salt, "#f4f0e6", 1))
    b.append(fill(" ".join(ell(30 + rnd.uniform(-4, 4), 55 + rnd.uniform(-4, 4), 0.8) for _ in range(6)), "#c8c4b8", 0.9))
    for i, x in enumerate((52, 66)):
        b.append(P.shape(ell(x, 55, 7), "glass", s=1.2, lw=1.2))
        b.append(fill(ell(x, 55, 5), ["#e6e0d0", "#c88a6a"][i], 0.9))
        b.append(fill(" ".join(ell(x + rnd.uniform(-3, 3), 55 + rnd.uniform(-3, 3), 1.2) for _ in range(5)), ["#ffffff", "#8a3a2c"][i], 0.7))
    return sh, J(b), ""


def spill_decal(P, W, H):
    rnd = random.Random(7)
    b = []
    for (x, y, r, col, dk, sd) in [(34, 30, 20, PAL["brew"][1], PAL["brew"][2], 3), (66, 44, 14, PAL["amber"][1], PAL["amber"][2], 8),
                                   (24, 54, 8, PAL["wine"][1], PAL["wine"][2], 12), (74, 18, 7, "#8a74a8", "#4a3a64", 17)]:
        d = blob(x, y, r, 5, 0.1, sd, squash=0.78, rot=sd * 0.3)
        b.append(fill(d, col, 0.34, blur_filter(P, 0.8)))
        b.append(noise_clip(P, d, dk, 0.12, 1.4, -0.5, sd, 0, 0, W, H))
        b.append(lin(d, dk, 1.0, 0.45))
        # tide line (dried ring)
        b.append(lin(blob(x - r * 0.08, y - r * 0.05, r * 0.7, 5, 0.1, sd + 1, squash=0.78, rot=sd * 0.3), dk, 0.5, 0.3))
        b.append(fill(" ".join(ell(x + math.cos(a) * r * 1.25, y + math.sin(a) * r * 0.95, r * 0.12) for a in (sd * 0.7, sd * 0.7 + 0.5)), col, 0.4))
        b.append(fill(" ".join(ell(x + rnd.uniform(-1.6, 1.6) * r, y + rnd.uniform(-1.3, 1.3) * r, rnd.uniform(0.7, 1.8)) for _ in range(6)), col, 0.5))
    # drip trail between the green and amber stains
    b.append(lin("M50,36 q6,2 10,6", PAL["brew"][2], 1.6, 0.3))
    return "DECAL", J(b), ""


# ======================================================================= ARCANE
def arcane_rack(P, W, H):
    sh = sh_(P, rect(4, 4, 100, 42, 3))
    b, e = [], []
    for x in (4, 98):
        b.append(P.shape(rect(x, 4, 8, 42, 2), "darkiron", s=1.5, lw=1.6))
    b.append(P.shape(rect(4, 4, 102, 7, 2), "brown", s=1, lw=1.5))
    rnd = random.Random(5)
    for i, y in enumerate((15, 24, 33, 41)):
        role = ["mithril", "darkiron", "metal", "mithril"][i]
        b.append(P.shape(rect(12, y - 3, 86, 6, 1.5), role, s=1.2, lw=1.3))
        b.append(fill(" ".join(ell(x, y, 2.6, 3.6) for x in (14, 96)), PAL["bronze"][1], 1))
        if i != 1:
            g = " ".join(f"M{x:.1f},{y-1.6} l2,1.6 l-2,1.6" for x in [24 + k * 14 + rnd.uniform(-2, 2) for k in range(5)])
            e.append(lit_marks(P, g, VIOLET, "#c4acf0", w=0.55, glow_w=2.0, op=0.6, blur=0.9))
    e.append(glow(P, 54, 28, 0, VIOLET, 0.16, rx=40, ry=16))
    return sh, J(b), J(e)


def arcane_glyph_decal(P, W, H):
    cx, cy = W / 2, H / 2
    ring_d, glyph_d = sigil_ring(P, cx, cy, 82, seed=29, n=14)
    rnd = random.Random(6)
    star = poly([(cx + math.cos(a) * 52, cy + math.sin(a) * 52) for a in [-math.pi / 2 + k * 2 * math.tau / 5 for k in range(5)]])
    inner = ell(cx, cy, 52) + " " + ell(cx, cy, 20)
    small = []
    for k in range(4):
        a = math.pi / 4 + k * math.tau / 4
        x, y = cx + math.cos(a) * 66, cy + math.sin(a) * 66
        small.append(ell(x, y, 6))
    b = [lin(ring_d + " " + inner + " " + " ".join(small), INK, 1.4, 0.32), lin(star, INK, 1.1, 0.28), lin(glyph_d, INK, 1.2, 0.38)]
    b.append(lit_marks(P, ring_d + " " + " ".join(small), VIOLET, "#b496ec", w=0.6, glow_w=2.0, op=0.32, blur=1.4))
    b.append(lit_marks(P, star + " " + inner, VIOLET, "#b496ec", w=0.55, glow_w=1.8, op=0.24, blur=1.4))
    b.append(lit_marks(P, glyph_d + " " + GLYPHS[0](cx, cy, 7), VIOLET, VIOLET_HOT, w=0.6, glow_w=2.0, op=0.48, blur=1.0))
    b.append(glow(P, cx, cy, 60, VIOLET, 0.08))
    return "DECAL", J(b), ""


# ======================================================================= LEATHER / STITCHING
def hide_rack(P, W, H):
    sh = sh_(P, rect(4, 4, 114, 82, 3))
    b = []
    fr = PAL["wood"]
    for d in (rect(4, 4, 114, 7, 2), rect(4, 79, 114, 7, 2), rect(4, 4, 7, 82, 2), rect(111, 4, 7, 82, 2)):
        b.append(P.shape(d, "wood", s=1.5, lw=1.6))
    hp = pelt(61, 45, 44, 30, math.pi / 2)
    b.append(P.shape(hp, "hide", s=4))
    b.append(P.detail("M40,45 q20,-4 42,0 M48,32 q12,-2 26,0 M48,58 q12,2 26,0", "hide", 0.3, 0.5))
    b.append(fill(blob(64, 46, 12, 6, 0.3, 4, squash=0.6), PAL["hide"][0], 0.35))
    # lacing from hide edge to frame
    lace = []
    for k in range(9):
        t = k / 8
        lace.append(f"M{20+t*82:.1f},11 L{22+t*78:.1f},{20+abs(t-0.5)*6:.1f}")
        lace.append(f"M{20+t*82:.1f},79 L{22+t*78:.1f},{70-abs(t-0.5)*6:.1f}")
    for k in range(5):
        y = 20 + k * 12.5
        lace.append(f"M11,{y:.1f} L{20+abs(k-2)*2:.1f},{y:.1f} M111,{y:.1f} L{102-abs(k-2)*2:.1f},{y:.1f}")
    b.append(lin(" ".join(lace), INK, 1.5))
    b.append(lin(" ".join(lace), PAL["strap"][0], 0.6))
    # scraper resting on the frame
    b.append(P.shape(poly([(86, 82), (104, 76), (106, 79), (88, 85)]), "metal", s=0.5, lw=1.1))
    return sh, J(b), ""


def pattern_board(P, W, H):
    sh = sh_(P, rect(4, 3, 118, 30, 2), 3, 4)
    b = [P.shape(rect(4, 3, 118, 30, 2), "brown", s=2.5), P.shape(rect(4, 3, 118, 6, 2), "wood", s=1, lw=1.4)]
    pieces = [(rect(10, 10, 20, 20, 3), "paper"), (smooth([(36, 10), (52, 10), (56, 22), (46, 30), (34, 24)]), "hide"),
              (rect(60, 10, 14, 21, 6), "paper"), (smooth([(80, 11), (98, 10), (96, 28), (86, 31), (80, 22)]), "leather"),
              (poly([(102, 10), (118, 12), (114, 30), (104, 28)]), "paper")]
    for d, role in pieces:
        b.append(P.shape(d, role, s=1.2, lw=1.1))
    # stitch guides + pins
    b.append(f'<path d="{rect(13, 13, 14, 14, 2)} {rect(63, 13, 8, 15, 4)}" fill="none" stroke="{INK}" stroke-width="0.6" stroke-dasharray="1.8 1.4" opacity="0.65"/>')
    b.append(lin("M38,16 l14,2 M84,16 l10,-1 M105,16 l8,1", INK, 0.5, 0.6))
    b.append(fill(" ".join(ell(x, 12, 1.3) for x in (20, 44, 67, 89, 110)), RUB, 0.95))
    b.append(lin("M30,22 L34,22", PAL["linen"][2], 0.6))
    return sh, J(b), ""


def thread_spools(P, W, H):
    sh = sh_(P, rect(4, 4, 62, 44, 6), 3, 4)
    b, e = [], []
    b.append(P.shape(rect(4, 4, 62, 44, 6), "straw", s=2.5, lw=1.6))   # wicker tray
    b.append(P.detail(" ".join(f"M{x},6 L{x},46" for x in range(10, 64, 5)), "straw", 0.35, 0.6))
    b.append(P.shape(rect(8, 8, 54, 36, 4), "straw", s=-1.5, hl=False, lw=1.0))
    for (x, y, r, th) in [(17, 17, 6, "#8a3a2c"), (32, 16, 5.5, PAL["blue"][1]), (16, 34, 5.5, "#c8b48a"), (31, 34, 6, PAL["moss"][1]),
                          (47, 37, 5, PAL["linen"][1])]:
        b.append(spool(P, x, y, r, th))
    # the pale ethereal spool
    b.append(spool(P, 49, 18, 6.5, "#eef2ff"))
    e.append(glow(P, 49, 18, 13, GHOST, 0.45))
    e.append(thread_line(P, "M53,22 q6,6 2,12 q-4,6 4,9", w=0.6, op=0.75))
    return sh, J(b), J(e)


def leather_roll(P, x, y, L, r, ang, role, seed):
    ca, sa = math.cos(ang), math.sin(ang)
    px, py = -sa * r, ca * r
    body = poly([(x + px, y + py), (x + ca * L + px, y + sa * L + py), (x + ca * L - px, y + sa * L - py), (x - px, y - py)])
    ex, ey = x + ca * L, y + sa * L
    o = [P.shape(body, role, s=r * 0.4, lw=1.3)]
    o.append(P.shape(ell(ex, ey, r * 0.55, r) if abs(ca) > 0.7 else ell(ex, ey, r, r * 0.55), role, s=0.6, lw=1.1))
    o.append(lin(ell(ex, ey, r * 0.3, r * 0.6) + " " + ell(ex, ey, r * 0.12, r * 0.25), INK, 0.55, 0.75))
    o.append(P.shape(rect(x + ca * L * 0.3 - 1.5, y - r - 0.5, 3, r * 2 + 1, 0.8) if abs(ca) > 0.7 else rect(x - r, y + sa * L * 0.4, r * 2, 3, 0.8), "strap", s=0.3, lw=0.9))
    return J(o)


def leather_bundle(P, W, H):
    sh = sh_(P, rect(6, 6, 66, 42, 8), 3, 4)
    b = []
    # flat offcuts spread underneath / beside the rolls
    b.append(P.shape(smooth([(40, 34), (70, 30), (74, 44), (62, 50), (44, 48)]), "hide", s=1.2, lw=1.1))
    b.append(P.shape(smooth([(6, 40), (24, 38), (30, 48), (12, 50)]), "leather", s=1.0, lw=1.1))
    b.append(P.shape(poly([(56, 8), (72, 10), (70, 15), (58, 14)]), "brown", s=0.6, lw=1.0))   # thin strap offcut
    b.append(f'<path d="M44,40 l20,-4" fill="none" stroke="#f4ead0" stroke-width="0.6" stroke-dasharray="1.6 1.4" opacity="0.7"/>')
    b.append(leather_roll(P, 6, 16, 44, 7, 0, "leather", 1))
    b.append(leather_roll(P, 12, 30, 40, 6, 0, "hide", 2))
    b.append(lin("M10,42 q14,5 26,-1", PAL["strap"][1], 1.6, 0.9))
    return sh, J(b), ""


# ======================================================================= LIVING QUARTERS
def quill(P, x0, y0, x1, y1):
    vane = smooth([(x0, y0), ((x0 + x1) / 2 - 2, (y0 + y1) / 2 - 2.5), (x1, y1), ((x0 + x1) / 2 + 2, (y0 + y1) / 2 + 1.5)])
    return J([P.shape(vane, "ivory", s=0.5, lw=1.0), lin(f"M{x0},{y0} L{x1+(x1-x0)*0.15:.1f},{y1+(y1-y0)*0.15:.1f}", INK, 0.7)])


def desk_ledger(P, W, H):
    sh = sh_(P, rect(4, 6, 132, 64, 3))
    b, e = [planks(P, 4, 6, 132, 64, "wood", n=3, dirn="h", s=3, seed=27)], []
    b.append(P.shape(rect(4, 6, 132, 6, 2), "brown", s=1, lw=1.4))
    # loose papers
    for (x, y, a) in [(10, 18, -8), (96, 40, 10), (102, 44, -4)]:
        b.append(f'<g transform="rotate({a} {x+12} {y+9})">' + P.shape(rect(x, y, 24, 18, 1), "paper", s=0.8, lw=1.0) +
                 P.detail(" ".join(f"M{x+3},{y+4+i*3} h{16 - (i % 2) * 5}" for i in range(4)), "paper", 0.2, 0.6) + "</g>")
    # open ledger
    b.append(book(P, 38, 22, 46, 32, "cloth", open_=True))
    b.append(lin("M61,22 L61,54", INK, 0.8))
    b.append(lin("M52,58 l0,6", RUB, 1.4))  # ribbon marker
    # ink pot + quill
    b.append(P.shape(ell(92, 22, 5), "darkiron", s=1, lw=1.2))
    b.append(fill(ell(92, 22, 2.8), "#100a06"))
    b.append(quill(P, 92, 21, 114, 12))
    # candle on a dish
    b.append(P.shape(ell(122, 24, 7.5), "bronze", s=1, lw=1.2))
    cb, ce = candle_top(P, 122, 24, 3.6)
    b.append(cb)
    e.append(ce)
    # keepsake: a small locket on a chain
    b.append(lin("M18,52 q6,8 14,4 q4,-2 2,-6", PAL["gold"][1], 0.8, 0.9))
    b.append(P.shape(ell(30, 52, 4, 4.6), "gold", s=0.8, lw=1.0))
    b.append(fill(ell(30, 52, 1.6), RUB, 0.85))
    # wax seal stick
    b.append(P.shape(rect(18, 36, 3, 12, 1), "wine", s=0.4, lw=0.9))
    return sh, J(b), J(e)


def bread(P, x, y, r):
    d = wobbly_ell(x, y, r * 1.4, r, 3, 0.06)
    return J([P.shape(d, "clay", s=r * 0.35, lw=1.2), P.detail(f"M{x-r*0.7:.1f},{y-r*0.3:.1f} l{r*0.4:.1f},{r*0.6:.1f} M{x:.1f},{y-r*0.5:.1f} l{r*0.4:.1f},{r*0.6:.1f} M{x+r*0.6:.1f},{y-r*0.4:.1f} l{r*0.3:.1f},{r*0.5:.1f}", "clay", 0.4, 0.8)])


def dining_table(P, W, H):
    sh = sh_(P, rect(6, 6, 176, 80, 3))
    b, e = [planks(P, 6, 6, 176, 80, "wood", n=5, dirn="h", s=3, seed=41)], []
    b.append(P.shape(rect(30, 34, 128, 24, 2), "linen", s=1.5, lw=1.3))  # runner
    b.append(lin(rect(33, 37, 122, 18, 1), RUB, 0.7, 0.6))
    for i, x in enumerate((30, 72, 116, 158)):
        b.append(plate(P, x, 20, 9, food=i % 2 == 0, seed=i))
        b.append(plate(P, x, 72, 9, food=i % 2 == 1, seed=i + 5))
        b.append(tankard(P, x + 15, 24 if i % 2 else 68, 5))
    b.append(P.shape(rect(66, 38, 36, 16, 3), "wood", s=1, lw=1.3))  # bread board
    b.append(bread(P, 82, 46, 6))
    b.append(P.shape(poly([(94, 44), (108, 41), (108, 43), (94, 46)]), "metal", s=0.3, lw=0.9))
    b.append(P.shape(ell(130, 46, 8), "clay", s=1.2, lw=1.2))
    b.append(fill(ell(130, 46, 5.5), "#e8d4a0", 0.95))  # cheese
    cb, ce = candle_top(P, 112, 46, 3.2)
    b.append(P.shape(ell(112, 46, 5.5), "pewter", s=0.8, lw=1.1))
    b.append(cb)
    e.append(ce)
    return sh, J(b), J(e)


def cupboard(P, W, H):
    sh = sh_(P, rect(4, 4, 102, 38, 2), 3, 4)
    b = [P.shape(rect(4, 4, 102, 38, 3), "brown", s=3), P.shape(rect(8, 7, 94, 28, 2), "wood", s=2, lw=1.5)]
    b.append(P.detail(" ".join(f"M10,{y} L100,{y}" for y in (14, 21, 28)), "wood", 0.3, 0.5))
    # front edge with door lip + knobs
    b.append(P.shape(rect(6, 35, 98, 6, 1.5), "brown", s=1, lw=1.3))
    b.append(fill(" ".join(ell(x, 38, 1.4) for x in (30, 52, 58, 80)), PAL["bronze"][0]))
    # crocks and a bowl on top
    b.append(P.shape(ell(24, 20, 8), "clay", s=1.5, lw=1.3))
    b.append(P.shape(ell(24, 20, 4.5), "linen", s=0.5, lw=0.9))
    b.append(P.shape(ell(44, 21, 6), "blue", s=1.2, lw=1.2))
    b.append(fill(ell(44, 21, 3.5), PAL["blue"][2], 0.8))
    b.append(P.shape(ell(66, 20, 9), "pewter", s=1.4, lw=1.2))
    b.append(lin(ell(66, 20, 6.5), INK, 0.5, 0.5))
    b.append(fill(" ".join(ell(x, y, 2.4) for x, y in [(64, 18), (68, 22), (67, 17)]), PAL["apple"][1]))
    b.append(P.shape(rect(80, 13, 16, 14, 2), "burlap", s=1, lw=1.1))
    return sh, J(b), ""


def kitchen_stove(P, W, H):
    sh = sh_(P, rect(4, 4, 102, 70, 4))
    b, e = [], []
    # stone hearth base
    b.append(P.shape(rect(4, 4, 102, 70, 4), "stone", s=3.5))
    b.append(P.detail("M4,30 L14,30 M96,30 L106,30 M4,52 L14,52 M96,52 L106,52 M30,64 L30,74 M80,64 L80,74", "stone", 0.45, 0.7))
    # iron stove body
    b.append(P.shape(rect(14, 10, 82, 54, 4), "darkiron", s=4, lw=1.8))
    b.append(P.shape(rect(18, 14, 74, 40, 2), "darkiron", s=-1.5, hl=False, lw=1.2, fill_override="#4a4640"))
    # flue on the back wall
    b.append(P.shape(ell(84, 9, 7), "darkiron", s=1.5, lw=1.5))
    b.append(fill(ell(84, 9, 4), "#120c08"))
    # hot plate (ring lid) with glow
    b.append(P.shape(ell(34, 34, 12), "darkiron", s=1.5, lw=1.4))
    b.append(lin(ell(34, 34, 8) + " " + ell(34, 34, 4.2), INK, 0.9, 0.85))
    e.append(lin(ell(34, 34, 10), EMBER, 0.9, 0.5))
    e.append(glow(P, 34, 34, 13, EMBER, 0.3))
    # pot of stew
    b.append(P.shape(rect(57, 23, 4, 6, 1), "darkiron", s=0.3, lw=1.0))
    b.append(P.shape(ell(70, 36, 15), "darkiron", s=2.5, lw=1.6))
    stew = ell(70, 36, 11.5)
    b.append(fill(stew, "#8a5a32", 1))
    b.append(fill(" ".join(ell(70 + dx, 36 + dy, r) for dx, dy, r in [(-4, -3, 2.4), (3, 2, 2.1), (-1, 5, 1.8), (5, -4, 1.6)]), PAL["clay"][0], 0.9))
    b.append(fill(" ".join(ell(70 + dx, 36 + dy, 1.2) for dx, dy in [(0, -6), (-6, 2), (6, 5)]), PAL["cabbage"][1]))
    b.append(lin("M66,32 L88,20", INK, 2.6))
    b.append(lin("M66,32 L88,20", PAL["wood"][1], 1.3))  # ladle handle
    e.append(lin("M64,30 q-2,-6 2,-10 M74,28 q2,-6 -1,-11", "#f4ead0", 0.8, 0.35))  # steam
    # firebox door at the front with ember slit
    b.append(P.shape(rect(30, 55, 40, 10, 2), "darkiron", s=1, lw=1.4))
    e.append(fill(" ".join(rect(34 + i * 8, 59, 5, 2, 0.8) for i in range(4)), EMBER, 0.9))
    e.append(glow(P, 50, 64, 0, EMBER, 0.35, rx=26, ry=8))
    b.append(fill(ell(84, 12, 14, 5), SOOT, 0.3, blur_filter(P, 2.5)))
    return sh, J(b), J(e)


def bed_double(P, W, H):
    x0, w = 6, W - 16
    y0, h = 6, H - 18
    sh = sh_(P, rect(x0, y0, w, h, 4))
    b = [P.shape(rect(x0, y0, w, h, 4), "wood", s=3), P.shape(rect(x0, y0, w, 13, 3), "brown", s=2, lw=2)]
    for x in (x0 + 4, x0 + w - 4):
        b.append(P.shape(ell(x, y0 + 6, 5), "wood", s=1, lw=1.4))
    b.append(P.shape(rect(x0 + 5, y0 + 13, w - 10, h - 18, 3), "linen", s=2, lw=1.6))
    pw = (w - 24) / 2
    for px in (x0 + 9, x0 + 15 + pw):
        b.append(P.shape(rect(px, y0 + 17, pw, 22, 7), "linen", s=2.5, lw=1.6))
        b.append(P.detail(f"M{px+pw/2:.1f},{y0+19} L{px+pw/2:.1f},{y0+37}", "linen", 0.3, 0.5))
    # patchwork quilt
    qy = y0 + 46
    qh = h - 50
    b.append(P.shape(rect(x0 + 3, qy, w - 6, qh, 4), "linen", s=5, lw=1.8))
    cols = ["blue", "wine", "linen", "moss", "burlap", "blue", "linen", "wine"]
    nx, ny = 5, 4
    cw, ch = (w - 14) / nx, (qh - 20) / ny
    rnd = random.Random(5)
    for j in range(ny):
        for i in range(nx):
            role = cols[(i + j * 3) % len(cols)]
            b.append(P.shape(rect(x0 + 7 + i * cw, qy + 14 + j * ch, cw, ch, 0.8), role, s=0.6, lw=0.8))
    b.append(f'<path d="{rect(x0 + 9, qy + 16, w - 18, qh - 24, 1)}" fill="none" stroke="#f4ead0" stroke-width="0.6" stroke-dasharray="1.8 1.6" opacity="0.6"/>')
    b.append(P.shape(rect(x0 + 3, qy, w - 6, 12, 3), "linen", s=2, lw=1.6))  # folded sheet
    b.append(P.detail(f"M{x0+12},{qy+qh-30} q{w*0.3:.1f},-10 {w*0.65:.1f},-2", "linen", 0.5, 0.6))
    return sh, J(b), ""


def dresser(P, W, H):
    sh = sh_(P, rect(4, 4, 86, 38, 2), 3, 4)
    b = [P.shape(rect(4, 4, 86, 38, 3), "brown", s=3), P.shape(rect(7, 7, 80, 28, 2), "wood", s=2, lw=1.5)]
    b.append(P.shape(rect(6, 35, 82, 6, 1.5), "brown", s=1, lw=1.3))
    b.append(fill(" ".join(ell(x, 38, 1.3) for x in (24, 47, 70)), PAL["bronze"][0]))
    # wash basin + jug
    b.append(P.shape(ell(28, 21, 11), "linen", s=2, lw=1.4))
    b.append(fill(ell(28, 21, 7.5), PAL["water"][1], 0.8))
    b.append(fill(ell(25, 18, 2.5, 1.2), "#ffffff", 0.45))
    b.append(P.shape(ell(48, 18, 6), "linen", s=1.2, lw=1.3))
    b.append(fill(ell(48, 18, 3.5), PAL["water"][2], 0.7))
    b.append(P.shape(rect(52, 16, 5, 3, 1), "linen", s=0.3, lw=0.9))
    # small hand mirror + comb
    b.append(P.shape(ell(70, 18, 6), "bronze", s=1, lw=1.2))
    b.append(fill(ell(70, 18, 4.2), "#c8d4d8", 0.95))
    b.append(P.shape(rect(68.5, 23, 3, 9, 1), "bronze", s=0.3, lw=1.0))
    b.append(P.shape(rect(76, 26, 10, 4, 1), "ivory", s=0.3, lw=0.9))
    return sh, J(b), ""


def bath_tub(P, W, H):
    sh = sh_(P, wobbly_ell(60, 36, 52, 30, 2, 0.02))
    b = []
    tub = wobbly_ell(60, 36, 52, 30, 2, 0.02)
    b.append(P.shape(tub, "wood", s=4))
    # staves
    b.append(P.detail(" ".join(f"M{60+math.cos(a)*44:.1f},{36+math.sin(a)*24:.1f} L{60+math.cos(a)*52:.1f},{36+math.sin(a)*30:.1f}" for a in [k * math.tau / 26 for k in range(26)]), "wood", 0.4, 0.7))
    for k in (0.92, 0.84):
        b.append(lin(ell(60, 36, 52 * k + 1, 30 * k + 1), INK, 1.0))
        b.append(lin(ell(60, 36, 52 * k + 1, 30 * k + 1), PAL["darkiron"][1], 1.4, 0.9))
    wat = ell(60, 37, 42, 22)
    b.append(liquid_inner(P, wat))
    # towel draped over the rim + soap
    b.append(P.shape(poly([(96, 8), (110, 14), (104, 30), (92, 22)]), "linen", s=1.5, lw=1.2))
    b.append(P.detail("M98,12 l6,4 M95,18 l6,4", "linen", 0.3, 0.6))
    b.append(P.shape(rect(18, 54, 10, 7, 2), "wax", s=0.5, lw=1.0))
    b.append(fill(" ".join(ell(48 + dx, 30 + dy, r) for dx, dy, r in [(0, 0, 2.2), (4, 2, 1.4), (-3, 4, 1.2), (20, 10, 1.8)]), "#ffffff", 0.55))
    return sh, J(b), ""


def liquid_inner(P, d):
    return J([fill(d, PAL["water"][1], 0.95), P._crescent(d, -5, -4, PAL["water"][2], 0.55),
              lin("M30,34 q8,-3 16,0 M64,44 q8,-3 16,0 M50,26 q6,-2 12,0", PAL["water"][0], 0.8, 0.7), lin(d, INK, 1.0)])


def horn_top(P, x, y, L=30):
    """Curved drinking/war horn: tapering crescent from the bell (left) to the tip (right)."""
    up, lo = [], []
    for k in range(9):
        t = k / 8
        cx, cy = x + t * L, y + 4 - math.sin(t * math.pi * 0.9) * 7
        w = 4.6 * (1 - t) + 0.6
        up.append((cx, cy - w))
        lo.append((cx, cy + w))
    d = smooth(up + lo[::-1])
    o = [P.shape(d, "ivory", s=1.5, lw=1.3)]
    bands = []
    for t in (0.12, 0.45, 0.7):
        cx, cy = x + t * L, y + 4 - math.sin(t * math.pi * 0.9) * 7
        w = 4.6 * (1 - t) + 0.6
        bands.append(f"M{cx:.1f},{cy-w:.1f} L{cx+0.6:.1f},{cy+w:.1f}")
    o.append(lin(" ".join(bands), INK, 2.4))
    o.append(lin(" ".join(bands), PAL["bronze"][1], 1.1))
    o.append(P.shape(ell(x, y + 4, 1.8, 4.8), "bronze", s=0.4, lw=1.0))
    o.append(lin(f"M{x+3},{y+9} Q{x+L*0.45:.1f},{y+16} {x+L*0.75:.1f},{y+4}", PAL["strap"][1], 0.9, 0.9))
    return J(o)


def trophy_wall(P, W, H):
    sh = sh_(P, rect(4, 3, 118, 30, 2), 3, 4)
    b = [backboard(P, 4, 3, 118, 8, role="brown", pegs=[12, 114])]
    # crossed swords behind the shield
    b.append(sword_top(P, 28, 34, 46, math.atan2(-27, 40)))
    b.append(sword_top(P, 70, 34, 46, math.atan2(-27, -40)))
    # battered round shield
    cx, cy = 49, 20
    b.append(P.shape(ell(cx, cy, 13), "wood", s=2.5, lw=1.6))
    b.append(lin(ell(cx, cy, 11.5), PAL["darkiron"][1], 2.0))
    b.append(fill(poly([(cx - 9, cy - 5), (cx, cy - 12), (cx, cy + 12), (cx - 9, cy + 6)]), RUB, 0.55))
    b.append(P.shape(ell(cx, cy, 4), "metal", s=1, lw=1.2))
    b.append(lin(f"M{cx+4},{cy-10} l3,5 l-1,4 M{cx-10},{cy+4} l5,2", INK, 0.8, 0.85))  # gouges
    b.append(f'<path d="M{cx+8},{cy-10} l5,0 l-1,4 Z" fill="{INK}" opacity="0.7"/>')  # chipped rim
    # horn + a small plaque (no text)
    b.append(horn_top(P, 82, 16))
    b.append(P.shape(rect(92, 28, 14, 5, 1), "bronze", s=0.5, lw=0.9))
    return sh, J(b), ""


def nightstand(P, W, H):
    sh = sh_(P, rect(4, 4, 36, 34, 2), 3, 4)
    b, e = [P.shape(rect(4, 4, 36, 34, 3), "brown", s=2.5), P.shape(rect(7, 7, 30, 25, 2), "wood", s=1.5, lw=1.3)], []
    b.append(P.shape(rect(6, 32, 32, 5, 1.5), "brown", s=0.6, lw=1.1))
    b.append(fill(ell(22, 34.5, 1.2), PAL["bronze"][0]))
    b.append(f'<g transform="rotate(-12 16 22)">' + book(P, 10, 16, 12, 15, "blue") + "</g>")
    b.append(P.shape(ell(29, 15, 5.5), "bronze", s=0.8, lw=1.1))
    cb, ce = candle_top(P, 29, 15, 2.8)
    b.append(cb)
    e.append(ce)
    return sh, J(b), J(e)


def bar_shelf(P, W, H):
    sh = sh_(P, rect(4, 4, 180, 28, 2), 3, 4)
    b = [shelf_box(P, 4, 4, 180, 28, "brown")]
    rnd = random.Random(19)
    libs = ["amber", "wine", "moss", "amber", "glass", "wine", "brew", "amber"]
    x, i = 12, 0
    while x < 178:
        if i % 4 == 1:  # mug pair
            b.append(tankard(P, x, 18, 5))
            x += 13
        elif i % 7 == 5:  # small cask
            b.append(barrel_top(P, x + 3, 18, 9))
            x += 22
        else:
            r = rnd.uniform(4.2, 5.4)
            b.append(bottle_top(P, x, 18 + rnd.uniform(-2.5, 2.5), r, libs[i % len(libs)] if libs[i % len(libs)] != "glass" else "straw"))
            x += r * 2 + 2.4
        i += 1
    return sh, J(b), ""


PROPS_I = dict(tool_wall=tool_wall, iron_bars=iron_bars, soot_decal=soot_decal, rune_shelf=rune_shelf,
               rune_glyph_decal=rune_glyph_decal, stone_blocks=stone_blocks, herb_rack=herb_rack, bottle_shelf=bottle_shelf,
               ingredient_crates=ingredient_crates, spill_decal=spill_decal, arcane_rack=arcane_rack,
               arcane_glyph_decal=arcane_glyph_decal, hide_rack=hide_rack, pattern_board=pattern_board,
               thread_spools=thread_spools, leather_bundle=leather_bundle, desk_ledger=desk_ledger, dining_table=dining_table,
               cupboard=cupboard, kitchen_stove=kitchen_stove, bed_double=bed_double, dresser=dresser, bath_tub=bath_tub,
               trophy_wall=trophy_wall, nightstand=nightstand, bar_shelf=bar_shelf)


# ======================================================================= TEXTURES (256, seamless)
T = mt.T


def floor_soot(P):
    o = [mt.stone_course(P, "sootstone", 4, 50, 90, 61, gap=3, rad=3, mortar="#3a3028", jitter=1.6)]
    o.append(mt.noise(P, 3, "#16100b", 1.9, -0.75, 31, 4))       # broad soot clouds
    o.append(mt.noise(P, 7, "#0e0a06", 1.6, -0.95, 33, 3))
    rnd = random.Random(14)
    marks = [(rnd.uniform(0, T), rnd.uniform(0, T), rnd.uniform(0, math.tau), rnd.uniform(5, 12)) for _ in range(22)]
    o.append(mt.wrap(lambda dx, dy: lin(" ".join(f"M{x+dx:.1f},{y+dy:.1f} l{math.cos(a)*L:.1f},{math.sin(a)*L:.1f} l{math.cos(a+0.7)*L*0.5:.1f},{math.sin(a+0.7)*L*0.5:.1f}" for x, y, a, L in marks), INK, 0.7, 0.4)))
    ash = [(rnd.uniform(0, T), rnd.uniform(0, T), rnd.uniform(0.6, 1.4)) for _ in range(60)]
    o.append(mt.wrap(lambda dx, dy: fill(" ".join(ell(x + dx, y + dy, r) for x, y, r in ash[:40]), "#16100b", 0.5) +
                     fill(" ".join(ell(x + dx, y + dy, r) for x, y, r in ash[40:]), "#c8bca6", 0.45)))
    o.append(mt.grain_layer(P, 35, 0.8))
    return "\n".join(o)


def floor_slate(P):
    o = [mt.stone_course(P, "slate", 5, 44, 84, 71, gap=2.6, rad=2, mortar="#3e4244", jitter=1.0)]
    o.append(mt.noise(P, 3, "#5a6266", 1.2, -0.6, 41, 4))
    o.append(mt.noise(P, 6, "#d6dada", 1.3, -0.95, 43, 3))
    rnd = random.Random(21)
    # cleft lines (slate lamination)
    lam = [(rnd.uniform(0, T), rnd.uniform(0, T), rnd.uniform(10, 26)) for _ in range(30)]
    o.append(mt.wrap(lambda dx, dy: lin(" ".join(f"M{x+dx:.1f},{y+dy:.1f} q{L*0.5:.1f},0 {L:.1f},{L*0.08:.1f}" for x, y, L in lam), "#2a2e30", 0.6, 0.35)))
    o.append(mt.grain_layer(P, 45, 0.6))
    return "\n".join(o)


def floor_arcane(P):
    o = [mt.stone_course(P, "darkstone", 4, 56, 96, 81, gap=3, rad=3, mortar="#1e1a22", jitter=1.4)]
    o.append(mt.noise(P, 3, "#120e16", 1.4, -0.7, 51, 4))
    rnd = random.Random(9)
    veins = []
    for i in range(7):
        x, y = rnd.uniform(0, T), rnd.uniform(0, T)
        a = rnd.uniform(0, math.tau)
        pts = [(x, y)]
        for k in range(rnd.randint(5, 9)):
            a += rnd.uniform(-0.7, 0.7)
            L = rnd.uniform(8, 18)
            x, y = x + math.cos(a) * L, y + math.sin(a) * L
            pts.append((x, y))
            if rnd.random() < 0.25:  # fork
                b2 = a + rnd.choice([-1, 1]) * rnd.uniform(0.6, 1.1)
                veins.append([(x, y), (x + math.cos(b2) * L * 0.8, y + math.sin(b2) * L * 0.8)])
        veins.append(pts)
    bf = blur_filter(P, 1.6)

    def vd(dx, dy):
        return " ".join("M" + " L".join(f"{px+dx:.1f},{py+dy:.1f}" for px, py in v) for v in veins)
    o.append(mt.wrap(lambda dx, dy: f'<path d="{vd(dx, dy)}" fill="none" stroke="{VIOLET}" stroke-width="3.2" opacity="0.28" {bf}/>'))
    o.append(mt.wrap(lambda dx, dy: lin(vd(dx, dy), "#a88ad8", 0.8, 0.55)))
    o.append(mt.grain_layer(P, 55, 0.7))
    return "\n".join(o)


def floor_herb(P):
    o = [fill(rect(0, 0, T, T), "#6a5a44")]
    rnd0 = random.Random(91)
    tiles = []
    for j in range(4):
        for i in range(4):
            sd = rnd0.randint(0, 999)
            rr = random.Random(sd)
            pts = [(i * 64 + 1.6 + rr.uniform(0, 0.8), j * 64 + 1.6 + rr.uniform(0, 0.8)), (i * 64 + 62.4 - rr.uniform(0, 0.8), j * 64 + 1.6 + rr.uniform(0, 0.8)),
                   (i * 64 + 62.4 - rr.uniform(0, 0.8), j * 64 + 62.4 - rr.uniform(0, 0.8)), (i * 64 + 1.6 + rr.uniform(0, 0.8), j * 64 + 62.4 - rr.uniform(0, 0.8))]
            col = [PAL["tile"][0], PAL["tile"][1], PAL["tile"][1], mt.mix(PAL["tile"][1], PAL["tile"][2], 0.25)][rr.randint(0, 3)]
            tiles.append(P.shape(mt.rounded(pts, 3), "tile", s=2.4, fill_override=col, lw=1.4))
            if rr.random() < 0.3:
                cx, cy = i * 64 + rr.uniform(14, 44), j * 64 + rr.uniform(14, 44)
                tiles.append(lin(f"M{cx:.1f},{cy:.1f} l{rr.uniform(3,6):.1f},{rr.uniform(-3,3):.1f} l{rr.uniform(2,4):.1f},{rr.uniform(-2,3):.1f}", INK, 0.6, 0.45))
    o.append("".join(tiles))
    o.append(mt.noise(P, 4, "#6e8048", 1.8, -0.86, 61, 4))   # green stains
    o.append(mt.noise(P, 3, "#5a4630", 1.2, -0.7, 63, 4))    # wear
    o.append(mt.noise(P, 6, "#f2e6c8", 1.2, -0.9, 65, 3))    # worn highlights
    rnd = random.Random(31)
    chips = [(rnd.uniform(0, T), rnd.uniform(0, T)) for _ in range(14)]
    o.append(mt.wrap(lambda dx, dy: lin(" ".join(f"M{x+dx:.1f},{y+dy:.1f} l3,2 l1,4" for x, y in chips), INK, 0.7, 0.4)))
    o.append(mt.grain_layer(P, 67, 0.7))
    return "\n".join(o)


def wall_plaster(P):
    o = [fill(rect(0, 0, T, T), "#e6dcc4")]
    o.append(mt.noise(P, 3, "#c4b494", 1.5, -0.78, 71, 4))
    o.append(mt.noise(P, 6, "#f6f0e0", 1.3, -0.82, 73, 3))
    o.append(mt.noise(P, 2, "#8a7656", 1.0, -0.8, 75, 3))
    rnd = random.Random(5)
    trowel = [(rnd.uniform(0, T), rnd.uniform(0, T), rnd.uniform(18, 40), rnd.uniform(-0.4, 0.4)) for _ in range(26)]
    o.append(mt.wrap(lambda dx, dy: lin(" ".join(f"M{x+dx:.1f},{y+dy:.1f} q{L*0.5:.1f},{-2+a*2:.1f} {L:.1f},{a*3:.1f}" for x, y, L, a in trowel), "#b8a888", 1.1, 0.22)))
    cracks = [(rnd.uniform(0, T), rnd.uniform(0, T)) for _ in range(5)]
    o.append(mt.wrap(lambda dx, dy: lin(" ".join(f"M{x+dx:.1f},{y+dy:.1f} l5,4 l1,7 l4,3 M{x+dx+6:.1f},{y+dy+11:.1f} l-4,4" for x, y in cracks), INK, 0.6, 0.35)))
    pits = [(rnd.uniform(0, T), rnd.uniform(0, T), rnd.uniform(0.5, 1.2)) for _ in range(40)]
    o.append(mt.wrap(lambda dx, dy: fill(" ".join(ell(x + dx, y + dy, r) for x, y, r in pits), "#8a7a5e", 0.45)))
    o.append(mt.grain_layer(P, 77, 0.6))
    return "\n".join(o)


TEX_I = dict(floor_soot=floor_soot, floor_slate=floor_slate, floor_arcane=floor_arcane, floor_herb=floor_herb,
             wall_plaster=wall_plaster)


# ======================================================================= UI
def station_marker(P):
    cx = 24
    e = [glow(P, cx, 22, 18, EMBER, 0.4)]
    outer = poly([(cx, 5), (cx + 12, 17), (cx + 5, 17), (cx, 44), (cx - 5, 17), (cx - 12, 17)])
    gem = poly([(cx, 5), (cx + 12, 17), (cx, 44), (cx - 12, 17)])
    body = [P.shape(gem, "fire", s=2.5, lw=2.0, fill_override=EMBER),
            fill(poly([(cx, 8), (cx + 7, 17), (cx, 37), (cx - 2, 17)]), EMBER_HOT, 0.75),
            lin(f"M{cx-12},17 L{cx+12},17 M{cx},5 L{cx},44", INK, 0.9, 0.7),
            fill(poly([(cx - 12, 17), (cx, 44), (cx, 17)]), "#8e2808", 0.45),
            lin(gem, INK, 2.0)]
    return J(e), J(body)


UI_I = dict(station_marker=(station_marker, 48, 48))


# ======================================================================= jobs
def jobs():
    only = only_filter()
    js = []
    props = load("props.json")
    for pid, fn in PROPS_I.items():
        if only and pid not in only:
            continue
        W, H = props[pid]["size"]
        P = painter(scale=1.0, lw_mul=0.7)
        sh, body, emit = fn(P, W, H)
        if sh == "DECAL":
            svg = decal_svg(P, W, H, body)
        else:
            svg = sprite_svg(P, W, H, sh, body, emit, ss=3, wob=0.9, dil=0.7, grain=0.45, soot=0.6)
        js.append(dict(name=f"pr_{pid}", svg=svg, w=W, h=H, ss=3, out=os.path.join(SPR, "props", pid + ".png")))
    for name, fn in TEX_I.items():
        if only and name not in only:
            continue
        P = painter(scale=1.0, lw_mul=0.55)
        svg = svg_doc(T, T, P, f'<g clip-path="none">{fn(P)}</g>', ss=2)
        js.append(dict(name=f"tx_{name}", svg=svg, w=T, h=T, ss=2, wrap=True, transparent=False,
                       out=os.path.join(SPR, "textures", name + ".png")))
    for name, (fn, W, H) in UI_I.items():
        if only and name not in only:
            continue
        P = painter(scale=1.0, lw_mul=0.75)
        emit, body = fn(P)
        svg = svg_doc(W, H, P, f'<g>{emit}</g><g {ink_filter(P, wob=1.0, dil=0.6, grain=0.5, soot=0.4)}>{body}</g>', ss=3)
        js.append(dict(name=f"ui_{name}", svg=svg, w=W, h=H, ss=3, out=os.path.join(SPR, "ui", name + ".png")))
    return js


def tile_test(names):
    os.makedirs(OUT, exist_ok=True)
    for n in names:
        im = Image.open(os.path.join(SPR, "textures", n + ".png")).convert("RGB")
        t = Image.new("RGB", (2 * T, 2 * T))
        for a in range(2):
            for b in range(2):
                t.paste(im, (a * T, b * T))
        t.save(os.path.join(OUT, f"tile2x2_{n}.png"))


def contact_sheets():
    import contact
    pf = [os.path.join(SPR, "props", p + ".png") for p in PROPS_I]
    contact.sheet("interiors_props", pf, zoom=1.0, max_w=1500)
    contact.sheet("interiors_props_floor", pf, zoom=1.0, max_w=1500, bg=(120, 104, 86))
    contact.sheet("interiors_textures", [os.path.join(SPR, "textures", t + ".png") for t in TEX_I], zoom=0.5, max_w=1400, tile=2)
    contact.sheet("interiors_ui", [os.path.join(SPR, "ui", u + ".png") for u in UI_I], zoom=2.0, max_w=400, bg=(120, 100, 80))


if __name__ == "__main__":
    render(jobs())
    tile_test([n for n in TEX_I if not only_filter() or n in only_filter()])
    contact_sheets()
