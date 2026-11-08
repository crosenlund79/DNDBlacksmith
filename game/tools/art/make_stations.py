"""Crafting-station sprites (straight top-down, transparent, exact spec size).
python3 make_stations.py [--only=anvil,forge]"""
import math
import os
import random
from artlib import *  # noqa: F401,F403
from artlib import (painter, sprite_svg, ground_shadow, glow, lin, fill, planks, end_grain, stones_ring, coals, liquid,
                    bottle_top, rune_glyphs, lit_marks, candle_top, sigil_ring, render, load, only_filter, hatch,
                    ell, rect, poly, smooth, blob, wobbly_ell, ST, INK, EMBER, EMBER_HOT, VIOLET, VIOLET_HOT, RUNE_GOLD,
                    SILVER, BREW_HOT, SPR, GILT, SOOT, blur_filter)

SH = (5, 6)  # default ground-shadow offset (px)


def J(o):
    return "\n".join(x for x in o if x)


# ======================================================================= CLASSIC
def anvil(P, W, H):
    sh, b, e = [], [], []
    stump = (52, 44, 30)
    an = [(8, 36), (20, 31), (34, 28), (40, 26), (88, 26), (88, 28), (102, 28), (102, 54), (88, 54), (88, 56), (40, 56),
          (34, 54), (20, 49)]
    sh.append(ground_shadow(P, ell(*stump) + " " + poly(an), *SH))
    b.append(end_grain(P, *stump, seed=3))
    # anvil body: horn (left, conic), face, heel with hardy & pritchel holes
    b.append(P.shape(smooth([(6, 41), (22, 31), (40, 27), (44, 27), (44, 55), (40, 55), (22, 50)], close=True), "darkiron", s=4))
    b.append(P.shape(rect(40, 25, 50, 32, 2), "darkiron", s=5))
    b.append(P.shape(rect(86, 27, 17, 28, 2), "darkiron", s=3))
    b.append(P.shape(rect(43, 28, 44, 26, 1.5), "metal", s=3, lw=2.2))  # polished steel face
    b.append(fill(rect(93, 33, 6, 6), INK, 0.95))
    b.append(fill(ell(95.5, 47, 2.2), INK, 0.95))
    b.append(P.detail("M46,31 L84,31", "metal", 0.4, 0.6))
    b.append(P.detail("M52,44 l7,3 M66,36 l5,-2 M74,48 l6,1", "metal", 0.4, 0.7))
    # hammer resting on the stump
    b.append(P.shape(rect(30, 64, 30, 4.5, 1.5), "wood", s=1.2, lw=1.6))
    b.append(P.shape(rect(56, 59, 9, 14, 1.5), "darkiron", s=2, lw=1.8))
    # hot bar on the face (classic ember accent)
    e.append(glow(P, 64, 41, 0, EMBER, 0.5, rx=22, ry=10))
    e.append(fill(rect(52, 38.5, 26, 5, 2), EMBER, 0.95))
    e.append(fill(rect(55, 39.5, 18, 2.6, 1.3), EMBER_HOT, 0.95))
    return J(sh), J(b), J(e)


def forge(P, W, H):
    sh, b, e = [], [], []
    base = rect(8, 8, 140, 106, 8)
    sh.append(ground_shadow(P, base, 6, 7))
    b.append(P.shape(base, "stone", s=6))
    # stone blocks of the hearth rim
    rnd = random.Random(4)
    blocks = []
    for (x0, y0, x1, y1, horiz) in [(8, 8, 148, 24, True), (8, 98, 148, 114, True)]:
        x = x0
        while x < x1 - 4:
            w = rnd.uniform(16, 26)
            w = min(w, x1 - x)
            blocks.append(rect(x + 0.8, y0 + 0.8, w - 1.6, y1 - y0 - 1.6, 2))
            x += w
    for (x0, y0, x1, y1) in [(8, 24, 26, 98), (130, 24, 148, 98)]:
        y = y0
        while y < y1 - 4:
            h = min(rnd.uniform(16, 24), y1 - y)
            blocks.append(rect(x0 + 0.8, y + 0.8, x1 - x0 - 1.6, h - 1.6, 2))
            y += h
    for i, d in enumerate(blocks):
        b.append(P.shape(d, "stone", s=2.2, lw=1.7))
    # working bed (dark, sooty)
    b.append(P.shape(rect(26, 24, 104, 74, 4), "coal", s=3, lw=2))
    # chimney hood on the back wall
    b.append(P.shape(rect(56, 0.5, 46, 22, 3), "slate", s=4))
    b.append(fill(rect(64, 5, 30, 12, 2), "#120c08", 0.95))
    cb, ce = coals(P, 78, 62, 36, 24, seed=5, hot=1.1)
    b.append(cb)
    e.append(ce)
    # tuyere (air pipe) from the left and a poker
    b.append(P.shape(rect(2, 56, 26, 8, 3), "darkiron", s=2, lw=1.8))
    b.append(P.shape(poly([(110, 104), (150, 84), (152, 87), (112, 107)]), "darkiron", s=1, lw=1.5))
    b.append(P.shape(ell(151, 85, 4), "darkiron", s=1, lw=1.5))
    # soot on the rim
    b.append(fill(ell(78, 26, 26, 6), SOOT, 0.25, blur_filter(P, 3)))
    e.append(glow(P, 78, 62, 0, EMBER, 0.35, rx=66, ry=52))
    rnd = random.Random(9)
    e.append(fill(" ".join(ell(78 + rnd.gauss(0, 20), 50 + rnd.gauss(0, 14), rnd.uniform(0.6, 1.3)) for _ in range(14)), EMBER_HOT, 0.9))
    return J(sh), J(b), J(e)


def crucible(P, W, H):
    sh, b, e = [], [], []
    cx, cy = 46, 46
    sh.append(ground_shadow(P, ell(cx, cy, 40), *SH))
    b.append(P.shape(ell(cx, cy, 40), "stone", s=4))  # brazier base
    cb, ce = coals(P, cx, cy, 33, 33, seed=8, hot=0.9)
    b.append(cb)
    e.append(ce)
    b.append(stones_ring(P, cx, cy, 38, 38, n=13, size=0.17, seed=4))
    # clay crucible pot
    b.append(P.shape(ell(cx, cy, 21), "clay", s=4))
    b.append(P.shape(ell(cx, cy, 16), "clay", s=-2, hl=False, lw=1.8))
    b.append(P.shape(poly([(cx + 16, cy - 6), (cx + 26, cy - 3), (cx + 16, cy + 1)]), "clay", s=1, lw=1.6))  # pouring lip
    e.append(fill(ell(cx, cy, 14.5), EMBER, 1.0))
    e.append(fill(ell(cx - 1.5, cy - 1.5, 9), EMBER_HOT, 0.95))
    e.append(fill(ell(cx - 4, cy - 4, 3.5, 2.2), "#fff2c8", 0.9))
    e.append(lin(f"M{cx-10},{cy+5} q6,-3 12,1 M{cx-4},{cy+9} q4,-2 8,0", "#a8380c", 0.8, 0.7))
    # tongs
    b.append(P.shape(poly([(70, 82), (92, 70), (93, 72), (72, 85)]), "darkiron", s=1, lw=1.4))
    b.append(P.shape(poly([(70, 86), (93, 78), (93, 80.5), (71, 88.5)]), "darkiron", s=1, lw=1.4))
    return J(sh), J(b), J(e)


def quench_trough(P, W, H):
    sh, b, e = [], [], []
    tr = rect(6, 8, 112, 46, 5)
    sh.append(ground_shadow(P, tr, *SH))
    b.append(planks(P, 6, 8, 112, 46, "wood", n=5, dirn="h", s=3, seed=2))
    b.append(P.shape(rect(12, 14, 100, 34, 3), "wood", s=-2.5, hl=False, lw=1.8))
    b.append(liquid(P, rect(13, 15, 98, 32, 2.5), "water", 62, 31, 49, 16, ripples=3))
    b.append(lin("M20,20 l14,0 M70,40 l18,0 M44,26 q6,-2 12,0", "#dbe8e2", 1, 0.8))
    # iron bands
    for x in (22, 62, 102):
        b.append(P.shape(rect(x - 2.5, 6, 5, 50, 1), "darkiron", s=1, lw=1.4))
    # ladle resting across
    b.append(P.shape(poly([(84, 4), (122, 18), (121, 21), (83, 7)]), "darkiron", s=1, lw=1.4))
    b.append(P.shape(ell(80, 5, 6, 4.5), "darkiron", s=1.5, lw=1.6))
    # steam wisps
    e.append(lin("M40,30 q4,-6 0,-11 q-4,-5 0,-10 M52,32 q3,-5 0,-9", "#f4f0e6", 1.1, 0.55))
    return J(sh), J(b), J(e)


def bellows(P, W, H):
    sh, b, e = [], [], []
    wedge = smooth([(14, 30), (34, 18), (60, 26), (80, 42), (84, 48), (80, 54), (60, 70), (34, 78), (14, 66), (10, 48)])
    sh.append(ground_shadow(P, wedge, *SH))
    # leather body peeking out with pleats
    b.append(P.shape(wedge, "leather", s=4))
    pl = []
    for k in (0.94, 0.86):
        pl.append(smooth([(14 + (1 - k) * 30, 30 + (1 - k) * 20), (34, 18 + (1 - k) * 40), (60, 26 + (1 - k) * 30),
                          (80 - (1 - k) * 40, 42 + (1 - k) * 10)], close=False))
    b.append(P.detail(" ".join(pl), "leather", 0.5, 0.8))
    b.append(P.detail(" ".join(f"M{x},{y0} L{x+2},{y1}" for x, y0, y1 in [(22, 26, 30), (32, 21, 25), (44, 20, 24), (56, 24, 28),
                                                                           (22, 70, 66), (32, 75, 71), (44, 76, 72), (56, 71, 67)]), "leather", 0.5, 0.8))
    # top wooden board (teardrop) with handle
    board = smooth([(16, 34), (36, 24), (60, 31), (76, 45), (78, 48), (76, 51), (60, 65), (36, 72), (16, 62), (13, 48)])
    b.append(P.shape(board, "wood", s=3.5))
    b.append(P.detail("M16,41 L70,41 M14,55 L70,55 M30,30 L30,41 M50,55 L50,68 M44,41 L44,55", "wood", 0.55, 0.85))
    # handle
    b.append(P.shape(rect(1, 42, 16, 12, 3), "wood", s=2, lw=2))
    b.append(P.shape(rect(3, 45, 7, 6, 2), "darkiron", s=1, lw=1.2))
    # brass nails and air-valve flap
    b.append(fill(" ".join(ell(x, y, 1.2) for x, y in [(22, 36), (22, 60), (40, 30), (40, 66), (60, 36), (60, 60)]), ST["pal"]["bronze"][1], 1))
    b.append(P.shape(rect(34, 42, 14, 12, 2), "leather", s=1.5, lw=1.4))
    # nozzle
    b.append(P.shape(poly([(78, 44), (94, 46), (94, 50), (78, 52)]), "bronze", s=1.5, lw=1.8))
    return J(sh), J(b), J(e)


def grinding_wheel(P, W, H):
    sh, b, e = [], [], []
    frame = rect(8, 16, 78, 64, 3)
    sh.append(ground_shadow(P, frame, *SH))
    # water trough below the wheel
    b.append(planks(P, 26, 58, 42, 20, "wood", n=2, dirn="h", s=2, seed=3))
    b.append(liquid(P, rect(29, 61, 36, 14, 2), "water", 47, 68, 18, 7, ripples=1))
    # frame rails
    b.append(planks(P, 8, 16, 78, 9, "wood", n=1, dirn="h", s=2, seed=4))
    b.append(planks(P, 8, 71, 78, 9, "wood", n=1, dirn="h", s=2, seed=5, nails=False))
    for x in (12, 76):
        b.append(P.shape(rect(x, 10, 10, 76, 2), "wood", s=2.5))
    # axle
    b.append(P.shape(rect(6, 44, 84, 6, 2), "darkiron", s=1.5, lw=1.7))
    # stone wheel (seen slightly from the front so the face reads)
    b.append(P.shape(ell(47, 47, 23, 30), "stone", s=5))
    b.append(P.detail(ell(47, 47, 17, 23) + " " + ell(47, 47, 5, 6.5), "stone", 0.5, 0.7))
    b.append(P.detail("M33,32 l6,4 M58,60 l-5,-3 M40,64 l4,-2 M58,30 l-3,4", "stone", 0.4, 0.7))
    b.append(P.shape(ell(47, 47, 4.5, 5.5), "darkiron", s=1, lw=1.4))
    # crank handle
    b.append(P.shape(poly([(88, 44), (92, 44), (92, 30), (88, 30)]), "darkiron", s=1, lw=1.4))
    b.append(P.shape(rect(86, 24, 9, 9, 2), "wood", s=1.5, lw=1.5))
    return J(sh), J(b), J(e)


# ======================================================================= RUNECRAFT
def rune_marks_emit(P, pts, s, seed=1, col=RUNE_GOLD, core="#fff0c0", w=0.9, op=0.75):
    rnd = random.Random(seed)
    d = " ".join(rune_glyphs(rnd, x, y, s) for x, y in pts)
    return lit_marks(P, d, col, core, w=w, glow_w=2.6, op=op, blur=1.1)


def rune_cutting_bench(P, W, H):
    sh, b, e = [], [], []
    top = rect(6, 8, 112, 60, 4)
    sh.append(ground_shadow(P, top, *SH))
    # wooden frame with blue-grey stone top
    b.append(P.shape(rect(4, 6, 116, 64, 4), "wood", s=3))
    b.append(P.shape(rect(9, 11, 106, 54, 3), "rune", s=4))
    b.append(P.detail("M40,12 L40,64 M78,12 L78,64", "rune", 0.5, 0.6))
    # raw runestone block with saw cuts
    blk = poly([(16, 20), (44, 16), (52, 32), (46, 52), (20, 54), (12, 38)])
    b.append(P.shape(blk, "slate", s=4))
    b.append(P.detail("M18,30 L48,26 M16,42 L49,40", "slate", 0.6, 0.85))
    b.append(P.detail("M24,22 l4,8 M36,46 l5,-6", "slate", 0.4, 0.7))
    # cut blanks
    for i, (x, y) in enumerate([(64, 26), (82, 22), (72, 48)]):
        b.append(P.shape(wobbly_ell(x, y, 9, 7, i + 3, 0.08), "rune", s=2, lw=1.8))
    e.append(rune_marks_emit(P, [(82, 22), (72, 48)], 3.2, seed=2))
    # chisel + mallet
    b.append(P.shape(poly([(94, 40), (114, 52), (112, 55), (92, 43)]), "darkiron", s=1, lw=1.4))
    b.append(P.shape(rect(98, 56, 18, 4, 1.5), "wood", s=1, lw=1.4))
    b.append(P.shape(rect(92, 52, 9, 12, 2), "wood", s=1.5, lw=1.6))
    # stone dust
    rnd = random.Random(3)
    b.append(fill(" ".join(ell(30 + rnd.gauss(0, 12), 58 + rnd.gauss(0, 3), rnd.uniform(0.5, 1.2)) for _ in range(30)), "#e6e8e6", 0.8))
    return J(sh), J(b), J(e)


def rune_engraving_stand(P, W, H):
    sh, b, e = [], [], []
    cx, cy = 46, 46
    oct_ = poly([(cx + 38 * math.cos(a), cy + 38 * math.sin(a)) for a in [math.pi / 8 + i * math.pi / 4 for i in range(8)]])
    sh.append(ground_shadow(P, oct_, *SH))
    b.append(P.shape(oct_, "rune", s=5))
    b.append(P.detail(poly([(cx + 30 * math.cos(a), cy + 30 * math.sin(a)) for a in [math.pi / 8 + i * math.pi / 4 for i in range(8)]]), "rune", 0.6, 0.7))
    # vise jaws holding a blank
    b.append(P.shape(rect(18, 38, 14, 16, 2), "darkiron", s=2, lw=1.8))
    b.append(P.shape(rect(60, 38, 14, 16, 2), "darkiron", s=2, lw=1.8))
    b.append(P.shape(rect(4, 44, 16, 4, 1.5), "darkiron", s=1, lw=1.3))
    b.append(P.shape(ell(5, 46, 3), "wood", s=1, lw=1.2))
    b.append(P.shape(wobbly_ell(46, 46, 15, 12, 4, 0.06), "slate", s=3))
    e.append(rune_marks_emit(P, [(42, 46)], 6, seed=7, w=1.3, op=0.95))
    # tool cup with burins
    b.append(P.shape(ell(72, 22, 8), "darkiron", s=2, lw=1.6))
    b.append(fill(ell(72, 22, 5.5), "#1a120c", 0.9))
    for (dx, dy) in [(-2, -2), (2, -1), (0, 2)]:
        b.append(P.shape(ell(72 + dx, 22 + dy, 1.8), "wood", s=0.5, lw=0.8))
    # loupe
    b.append(P.shape(ell(26, 72, 6), "bronze", s=1.5, lw=1.5))
    b.append(fill(ell(25, 71, 3.6), "#e4ecee", 0.8))
    return J(sh), J(b), J(e)


def rune_cleansing_basin(P, W, H):
    sh, b, e = [], [], []
    cx, cy = 46, 46
    sh.append(ground_shadow(P, ell(cx, cy, 40), *SH))
    b.append(P.shape(wobbly_ell(cx, cy, 40, 40, 2, 0.03), "rune", s=5))
    b.append(P.shape(ell(cx, cy, 29), "rune", s=-3, hl=False, lw=1.8))
    b.append(liquid(P, ell(cx, cy, 28), "ice", cx, cy, 28, 28, ripples=2))
    b.append(P.shape(wobbly_ell(cx + 4, cy + 3, 9, 7, 9, 0.08), "slate", s=1.5, lw=1.6))
    # carved rune ring on the rim
    rnd = random.Random(5)
    pts = [(cx + 34.5 * math.cos(a), cy + 34.5 * math.sin(a)) for a in [i / 9 * math.tau for i in range(9)]]
    b.append(P.detail(" ".join(rune_glyphs(rnd, x, y, 2.3) for x, y in pts), "rune", 0.5, 0.8))
    e.append(rune_marks_emit(P, pts[::2], 2.3, seed=5, op=0.7))
    e.append(glow(P, cx, cy, 26, "#d8ecf4", 0.35))
    e.append(rune_marks_emit(P, [(cx + 4, cy + 3)], 3.4, seed=11, op=0.9))
    # floating residue (pale motes)
    e.append(fill(" ".join(ell(cx + rnd.gauss(0, 10), cy + rnd.gauss(0, 10), 0.8) for _ in range(10)), "#f6f2dc", 0.7))
    return J(sh), J(b), J(e)


def resonance_pedestal(P, W, H):
    sh, b, e = [], [], []
    cx, cy = 46, 46
    sq = rect(10, 10, 72, 72, 5)
    sh.append(ground_shadow(P, sq, *SH))
    b.append(P.shape(sq, "rune", s=5))
    b.append(P.shape(rect(18, 18, 56, 56, 4), "rune", s=3, lw=1.8))
    b.append(P.shape(ell(cx, cy, 20), "slate", s=3, lw=2))
    b.append(P.shape(ell(cx, cy, 11), "rune", s=2, lw=1.8))
    # resonance rings (pale gold, dashed)
    rings = ell(cx, cy, 25) + " " + ell(cx, cy, 31)
    e.append(f'<path d="{rings}" fill="none" stroke="{RUNE_GOLD}" stroke-width="0.9" stroke-dasharray="3 2.5" opacity="0.8"/>')
    e.append(glow(P, cx, cy, 22, RUNE_GOLD, 0.35))
    e.append(rune_marks_emit(P, [(cx, cy)], 5, seed=3, w=1.2, op=0.95))
    # corner studs
    b.append(fill(" ".join(ell(x, y, 1.8) for x, y in [(14, 14), (78, 14), (14, 78), (78, 78)]), ST["pal"]["bronze"][1]))
    # tuning fork
    b.append(P.shape(poly([(66, 84), (88, 70), (89.5, 72.5), (68, 86.5)]), "silver", s=1, lw=1.2))
    b.append(lin("M88,71 l5,-4 M89.5,73 l5.5,-3", INK, 1.6))
    return J(sh), J(b), J(e)


def rune_polishing_wheel(P, W, H):
    sh, b, e = [], [], []
    cx, cy = 44, 46
    base = rect(8, 12, 76, 70, 6)
    sh.append(ground_shadow(P, base, *SH))
    b.append(P.shape(base, "rune", s=4))
    b.append(P.detail("M8,40 L84,40 M30,12 L30,40 M62,40 L62,82", "rune", 0.5, 0.55))
    # horizontal felt lap (polishing disc)
    b.append(P.shape(ell(cx, cy, 28), "darkiron", s=3))
    b.append(P.shape(ell(cx, cy, 24), "linen", s=3, lw=1.6))
    b.append(P.detail(" ".join(ell(cx, cy, r) for r in (18, 12)), "linen", 0.4, 0.6))
    b.append(lin(f"M{cx-18},{cy-8} a20,20 0 0,1 14,-12 M{cx+16},{cy+10} a20,20 0 0,1 -12,10", "#8e8064", 0.8, 0.8))
    b.append(P.shape(ell(cx, cy, 3.5), "darkiron", s=1, lw=1.2))
    # runestone being polished
    b.append(P.shape(wobbly_ell(cx + 10, cy - 7, 7, 5.5, 3, 0.06), "slate", s=1.5, lw=1.5))
    e.append(rune_marks_emit(P, [(cx + 10, cy - 7)], 2.8, seed=4, op=0.95))
    e.append(fill(ell(cx + 7, cy - 9, 2.2, 1.2), "#ffffff", 0.6))
    # crank
    b.append(P.shape(rect(76, 60, 14, 5, 2), "darkiron", s=1, lw=1.3))
    b.append(P.shape(ell(88, 62.5, 4), "wood", s=1, lw=1.3))
    # polishing compound pot (red rouge)
    b.append(P.shape(ell(18, 72, 7), "clay", s=1.5, lw=1.5))
    b.append(fill(ell(18, 72, 4.5), ST["pal"]["redp"][1], 0.8))
    return J(sh), J(b), J(e)


# ======================================================================= ALCHEMY
def herb_sprig(P, x, y, ang, L=14, role="green", seed=1):
    rnd = random.Random(seed)
    ca, sa = math.cos(ang), math.sin(ang)
    o = [P.detail(f"M{x:.1f},{y:.1f} L{x+ca*L:.1f},{y+sa*L:.1f}", role, 0.6)]
    for i in range(4):
        t = 0.3 + i * 0.2
        px, py = x + ca * L * t, y + sa * L * t
        for sgn in (-1, 1):
            a2 = ang + sgn * 0.9
            lx, ly = px + math.cos(a2) * 3.4, py + math.sin(a2) * 3.4
            o.append(P.shape(ell(lx, ly, 2.2, 1.2).replace("M", "M", 1), role, s=0.4, lw=0.6))
    return "\n".join(o)


def mortar_station(P, W, H):
    sh, b, e = [], [], []
    top = rect(6, 6, 82, 64, 4)
    sh.append(ground_shadow(P, top, *SH))
    b.append(planks(P, 6, 6, 82, 64, "wood", n=4, dirn="h", s=3, seed=7))
    # big stone mortar with ground green powder
    b.append(P.shape(ell(38, 38, 22), "stone", s=4))
    b.append(P.shape(ell(38, 38, 16), "stone", s=-2.5, hl=False, lw=1.8))
    b.append(fill(ell(39, 39, 13), BREW, 0.9))
    b.append(fill(ell(36, 36, 7, 5), "#a8c07c", 0.8))
    rnd = random.Random(2)
    b.append(fill(" ".join(ell(39 + rnd.gauss(0, 6), 39 + rnd.gauss(0, 6), 0.7) for _ in range(16)), "#3c5226", 0.8))
    # pestle
    b.append(P.shape(poly([(36, 34), (64, 18), (67, 22), (40, 39)]), "stone", s=1.5, lw=1.7))
    b.append(P.shape(ell(66, 19.5, 4.2), "stone", s=1.2, lw=1.6))
    # herb bundle + jars
    b.append(herb_sprig(P, 62, 56, -0.3, 18, seed=3))
    b.append(herb_sprig(P, 64, 60, 0.1, 16, seed=4))
    b.append(P.shape(rect(58, 55, 4, 8, 1), "straw", s=0.5, lw=0.8))
    b.append(bottle_top(P, 76, 18, 6, "brew"))
    b.append(bottle_top(P, 14, 60, 5, "straw"))
    return J(sh), J(b), J(e)


def alembic(P, W, H):
    sh, b, e = [], [], []
    sh.append(ground_shadow(P, rect(6, 8, 100, 80, 6), *SH))
    b.append(planks(P, 6, 8, 100, 80, "wood", n=5, dirn="h", s=3, seed=11))
    # burner
    b.append(P.shape(ell(34, 50, 20), "darkiron", s=3))
    e.append(glow(P, 34, 50, 22, EMBER, 0.4))
    # copper pot still (cucurbit) with helm
    b.append(P.shape(ell(34, 50, 17), "copper", s=4))
    b.append(P.shape(ell(34, 50, 8.5), "copper", s=2, lw=1.8))
    b.append(fill(ell(29, 44, 4, 2.5), "#fde0c0", 0.6))
    # swan neck to receiver
    neck = smooth([(40, 46), (56, 36), (72, 40), (82, 56)], close=False)
    b.append(lin(neck, INK, 6.4))
    b.append(lin(neck, ST["pal"]["copper"][1], 4))
    b.append(lin(neck, ST["pal"]["copper"][0], 1.2, 0.7))
    # receiving flask (glass) with green distillate
    b.append(P.shape(ell(84, 64, 13), "glass", s=2.5, lw=1.9))
    b.append(fill(ell(85, 65, 9.5), BREW, 0.8))
    b.append(P.shape(ell(84, 64, 4), "glass", s=1, lw=1.1))
    b.append(fill(ell(79, 59, 3, 2), "#ffffff", 0.7))
    e.append(fill(ell(86, 67, 4, 3), BREW_HOT, 0.6))
    # drip + spare vials
    e.append(fill(ell(82, 57, 1.2), BREW_HOT, 0.9))
    for i, (x, y, l) in enumerate([(14, 20, "brew"), (24, 18, "straw"), (90, 22, "brew")]):
        b.append(bottle_top(P, x, y, 4.5, l))
    return J(sh), J(b), J(e)


def cauldron(P, W, H):
    sh, b, e = [], [], []
    cx, cy = 54, 54
    sh.append(ground_shadow(P, ell(cx, cy, 46), *SH))
    # fire ring of stones + coals
    b.append(stones_ring(P, cx, cy, 44, 44, n=14, size=0.16, seed=6))
    cb, ce = coals(P, cx, cy, 39, 39, seed=3, hot=0.7)
    b.append(cb)
    e.append(ce.split("\n", 1)[0])
    e.append(fill(" ".join(ell(cx + 36 * math.cos(a), cy + 36 * math.sin(a), 2) for a in [0.3, 1.2, 2.3, 3.4, 4.4, 5.5]), EMBER, 0.9))
    # iron cauldron with lip and handles
    b.append(P.shape(ell(cx - 34, cy, 5, 7), "darkiron", s=1, lw=1.6))
    b.append(P.shape(ell(cx + 34, cy, 5, 7), "darkiron", s=1, lw=1.6))
    b.append(P.shape(ell(cx, cy, 32), "darkiron", s=5))
    b.append(P.shape(ell(cx, cy, 27), "darkiron", s=-3, hl=False, lw=1.8))
    b.append(liquid(P, ell(cx, cy, 25), "brew", cx, cy, 25, 25, ripples=0, sheen=False))
    rnd = random.Random(4)
    bub = []
    for i in range(9):
        x, y, r = cx + rnd.gauss(0, 9), cy + rnd.gauss(0, 9), rnd.uniform(1.4, 3.6)
        bub.append(ell(x, y, r))
    e.append(fill(" ".join(bub), BREW_HOT, 0.45))
    e.append(lin(" ".join(bub), "#3c5226", 0.7, 0.9))
    e.append(glow(P, cx, cy, 30, BREW_HOT, 0.35))
    # paddle
    b.append(P.shape(poly([(cx + 4, cy + 2), (cx + 44, cy - 34), (cx + 47, cy - 31), (cx + 8, cy + 6)]), "wood", s=1, lw=1.6))
    b.append(P.shape(ell(cx + 2, cy + 4, 5, 3), "wood", s=1, lw=1.4))
    return J(sh), J(b), J(e)


def reagent_table(P, W, H):
    sh, b, e = [], [], []
    sh.append(ground_shadow(P, rect(4, 6, 118, 64, 4), *SH))
    b.append(planks(P, 4, 6, 118, 64, "wood", n=4, dirn="h", s=3, seed=12))
    # rack of jars (back row)
    b.append(P.shape(rect(8, 9, 64, 18, 2), "wood", s=2, lw=1.8))
    for i, l in enumerate(["brew", "straw", "copper", "brew", "ice"]):
        b.append(bottle_top(P, 15 + i * 12.5, 18, 5.2, l))
    # separatory funnel on ring stand
    b.append(P.shape(ell(92, 26, 15), "darkiron", s=1, lw=1.4, flat=True, fill_override="none"))
    b.append(P.shape(ell(92, 26, 11), "glass", s=2, lw=1.8))
    b.append(fill(ell(92, 26, 10) , "#c4a050", 0.45))
    b.append(fill(f"M82,26 a10,10 0 0,0 20,0 Z", BREW, 0.75))
    b.append(fill(ell(88, 21, 3, 2), "#ffffff", 0.6))
    # dish with separated salts + mortar
    b.append(P.shape(ell(26, 50, 11, 9), "clay", s=2, lw=1.7))
    b.append(fill(ell(23, 49, 4.5, 3.5), "#f0ece0", 0.95))
    b.append(fill(ell(29, 52, 4, 3), BREW, 0.9))
    b.append(P.shape(ell(56, 48, 9), "stone", s=2, lw=1.7))
    b.append(fill(ell(56, 48, 5.5), "#e2d6bc", 0.9))
    # notebook + scales
    b.append(P.shape(rect(74, 44, 22, 18, 1.5), "paper", s=1.5, lw=1.5))
    b.append(P.detail("M78,49 h14 M78,53 h12 M78,57 h13", "paper", 0.35, 0.7))
    b.append(P.shape(rect(103, 44, 15, 20, 2), "bronze", s=1.5, lw=1.4))
    b.append(P.shape(ell(110.5, 49, 4.5), "bronze", s=1, lw=1.2))
    b.append(P.shape(ell(110.5, 59, 4.5), "bronze", s=1, lw=1.2))
    e.append(fill(ell(92, 30, 4, 2.5), BREW_HOT, 0.5))
    return J(sh), J(b), J(e)


def infusion_rack(P, W, H):
    sh, b, e = [], [], []
    sh.append(ground_shadow(P, rect(4, 6, 118, 50, 3), *SH))
    b.append(P.shape(rect(4, 6, 118, 50, 3), "wood", s=3))
    b.append(P.shape(rect(9, 11, 108, 40, 2), "brown", s=-2, hl=False, lw=1.5))
    b.append(P.detail("M9,31 L117,31", "wood", 1.0))
    libs = ["brew", "straw", "brew", "copper", "brew", "ice", "brew", "redp"]
    for row, y in enumerate((21, 41)):
        for i in range(8):
            l = libs[(i + row * 3) % 8]
            b.append(bottle_top(P, 16 + i * 13.5, y, 5.4, l))
    # herb sprigs steeping in two bottles
    e.append(glow(P, 43, 21, 7, BREW_HOT, 0.45))
    e.append(glow(P, 97, 41, 7, BREW_HOT, 0.45))
    b.append(lin("M43,21 l-4,-7 M43,21 l2,-8 M97,41 l5,-6", ST["pal"]["green"][2], 1.0))
    return J(sh), J(b), J(e)


# ======================================================================= ARCANE
def arcane_crucible(P, W, H):
    sh, b, e = [], [], []
    cx, cy = 62, 62
    sh.append(ground_shadow(P, ell(cx, cy, 54), 6, 7))
    b.append(P.shape(wobbly_ell(cx, cy, 54, 54, 3, 0.02), "slate", s=5))
    ring_d, glyph_d = sigil_ring(P, cx, cy, 50, n=12, seed=9)
    b.append(P.detail(ring_d, "slate", 0.45, 0.7))
    e.append(lit_marks(P, glyph_d, VIOLET, VIOLET_HOT, w=0.9, glow_w=2.8, op=0.85, blur=1.3))
    cb, ce = coals(P, cx, cy, 36, 36, seed=11, hot=0.45)
    b.append(cb)
    e.append(ce)
    # dark crucible (obsidian-iron) with three clawed feet
    for a in (math.pi / 2 + 0.4, math.pi * 7 / 6 + 0.4, math.pi * 11 / 6 + 0.4):
        b.append(P.shape(ell(cx + math.cos(a) * 30, cy + math.sin(a) * 30, 5), "obsidian", s=1, lw=1.6))
    b.append(P.shape(ell(cx, cy, 28), "obsidian", s=5))
    b.append(P.shape(ell(cx, cy, 22), "obsidian", s=-3, hl=False, lw=1.8))
    # molten mithril with violet charge
    e.append(fill(ell(cx, cy, 20.5), "#b8c4e8", 1))
    e.append(fill(ell(cx + 3, cy + 3, 15), VIOLET, 0.55))
    e.append(fill(ell(cx - 5, cy - 5, 7, 4.5), "#f4f0ff", 0.85))
    e.append(lin(f"M{cx-12},{cy+4} q8,-6 16,0 M{cx-6},{cy+11} q6,-3 12,0", "#5e3aa0", 0.8, 0.8))
    e.append(glow(P, cx, cy, 44, VIOLET, 0.35))
    # sigils on the crucible body
    rnd = random.Random(2)
    sg = " ".join(rune_glyphs(rnd, cx + 25 * math.cos(a), cy + 25 * math.sin(a), 1.8) for a in [i * math.tau / 7 for i in range(7)])
    e.append(lit_marks(P, sg, VIOLET, VIOLET_HOT, w=0.8, glow_w=2.2, op=0.9, blur=1))
    return J(sh), J(b), J(e)


def spellbinding_array(P, W, H):
    sh, b, e = [], [], []
    cx, cy = 80, 80
    # floor circle: inlaid dark stone slab
    sh.append(ground_shadow(P, ell(cx, cy, 70), 3, 4, op=0.3, soft=0.12))
    b.append(P.shape(wobbly_ell(cx, cy, 72, 72, 4, 0.015), "slate", s=4, lw=2.4))
    b.append(P.shape(ell(cx, cy, 64), "obsidian", s=3, lw=1.6))
    ring_d, glyph_d = sigil_ring(P, cx, cy, 60, n=16, seed=21)
    # heptagram
    pts = [(cx + 46 * math.cos(-math.pi / 2 + i * math.tau / 7), cy + 46 * math.sin(-math.pi / 2 + i * math.tau / 7)) for i in range(7)]
    star = poly([pts[(i * 3) % 7] for i in range(7)])
    inner = ell(cx, cy, 46) + " " + ell(cx, cy, 16)
    e.append(lit_marks(P, ring_d + " " + inner, VIOLET, "#b496ec", w=1.0, glow_w=2.6, op=0.55, blur=1.6))
    e.append(lit_marks(P, star, VIOLET, VIOLET_HOT, w=1.1, glow_w=3.0, op=0.7, blur=1.8))
    e.append(lit_marks(P, glyph_d, VIOLET, VIOLET_HOT, w=0.9, glow_w=2.6, op=0.9, blur=1.2))
    # central iron plate (where the cooling metal lies)
    b.append(P.shape(ell(cx, cy, 13), "darkiron", s=2.5, lw=1.8))
    e.append(fill(rect(cx - 9, cy - 3, 18, 6, 2), EMBER, 0.95))
    e.append(fill(rect(cx - 6, cy - 1.5, 12, 3, 1.5), EMBER_HOT, 0.95))
    e.append(glow(P, cx, cy, 30, VIOLET, 0.35))
    # candles at the cardinal points
    for i in range(4):
        a = -math.pi / 2 + i * math.pi / 2 + math.pi / 4
        x, y = cx + 67 * math.cos(a), cy + 67 * math.sin(a)
        cb_, ce_ = candle_top(P, x, y, 3.6)
        b.append(cb_)
        e.append(ce_)
    return J(sh), J(b), J(e)


def crystal(P, x, y, L, w, ang, role="arcane", s=2):
    ca, sa = math.cos(ang), math.sin(ang)
    px, py = -sa, ca
    pts = [(x + px * w, y + py * w), (x + ca * L * 0.8 + px * w, y + sa * L * 0.8 + py * w), (x + ca * L, y + sa * L),
           (x + ca * L * 0.8 - px * w, y + sa * L * 0.8 - py * w), (x - px * w, y - py * w)]
    o = [P.shape(poly(pts), role, s=s, lw=1.8)]
    o.append(P.detail(f"M{x:.1f},{y:.1f} L{x+ca*L*0.8:.1f},{y+sa*L*0.8:.1f} L{x+ca*L:.1f},{y+sa*L:.1f}", role, 0.4, 0.7))
    return "\n".join(o)


def leyline_conductor(P, W, H):
    sh, b, e = [], [], []
    cx, by = 48, 92
    base = poly([(cx + 34 * math.cos(a), by + 28 * math.sin(a)) for a in [i * math.pi / 3 for i in range(6)]])
    sh.append(ground_shadow(P, base + " " + poly([(cx - 12, by), (cx - 4, 10), (cx + 12, by)]), 5, 6))
    b.append(P.shape(base, "slate", s=4))
    b.append(P.shape(poly([(cx + 24 * math.cos(a), by + 19 * math.sin(a)) for a in [i * math.pi / 3 for i in range(6)]]), "rune", s=2.5, lw=1.8))
    # leyline crack on the floor
    e.append(lit_marks(P, f"M2,{by+30} L18,{by+22} L30,{by+26} L{cx},{by} M{cx},{by} L70,{by+20} L94,{by+24}", VIOLET, VIOLET_HOT, w=1.0, glow_w=3, op=0.8))
    # iron prongs
    for dx in (-18, 18):
        b.append(P.shape(poly([(cx + dx, by), (cx + dx * 0.55, by - 46), (cx + dx * 0.45, by - 46), (cx + dx * 0.8, by)]), "darkiron", s=1, lw=1.5))
    # crystal cluster (tall pylon leaning to the north)
    b.append(crystal(P, cx - 10, by - 4, 34, 6, -math.pi / 2 - 0.45))
    b.append(crystal(P, cx + 11, by - 4, 30, 5.5, -math.pi / 2 + 0.42))
    b.append(crystal(P, cx, by - 2, 84, 11, -math.pi / 2, s=4))
    b.append(fill(poly([(cx - 6, by - 20), (cx - 5, by - 70), (cx - 1, by - 74), (cx - 2, by - 22)]), "#efe4ff", 0.6))
    # copper coil bands
    for yy in (by - 22, by - 40):
        b.append(P.shape(rect(cx - 13, yy, 26, 4, 1.5), "copper", s=1, lw=1.3))
    e.append(glow(P, cx, by - 46, 0, VIOLET, 0.55, rx=26, ry=50))
    e.append(fill(ell(cx, by - 80, 2.4), "#ffffff", 0.9))
    e.append(lit_marks(P, f"M{cx},{by-82} l-6,-6 l4,-1 l-5,-6 M{cx+2},{by-80} l7,-5 l-2,-2 l6,-3", VIOLET, VIOLET_HOT, w=0.8, glow_w=2.4, op=0.85))
    return J(sh), J(b), J(e)


def aetheric_stabilizer(P, W, H):
    sh, b, e = [], [], []
    cx, cy = 54, 54
    sh.append(ground_shadow(P, rect(10, 10, 88, 88, 6), *SH))
    b.append(P.shape(rect(10, 10, 88, 88, 6), "slate", s=4))
    b.append(P.shape(rect(18, 18, 72, 72, 4), "obsidian", s=3, lw=1.8))
    # iron ring frame with four struts
    b.append(P.shape(ell(cx, cy, 34), "darkiron", s=2, lw=2.2, flat=True, fill_override="none"))
    b.append(lin(ell(cx, cy, 34), ST["pal"]["darkiron"][1], 3.5))
    b.append(lin(ell(cx, cy, 34), INK, 0.8, 0.8))
    for (x0, y0, x1, y1) in [(14, 14, 30, 30), (94, 14, 78, 30), (14, 94, 30, 78), (94, 94, 78, 78)]:
        b.append(lin(f"M{x0},{y0} L{x1},{y1}", INK, 4.2))
        b.append(lin(f"M{x0},{y0} L{x1},{y1}", ST["pal"]["darkiron"][1], 2.4))
    # charged ingot cradle
    b.append(P.shape(rect(cx - 13, cy - 6, 26, 12, 2), "mithril", s=2, lw=1.8))
    e.append(lit_marks(P, f"M{cx-8},{cy} l4,-3 l4,3 l4,-3 l4,3", VIOLET, VIOLET_HOT, w=0.9, glow_w=2.4, op=0.9))
    # three floating orbs + arcs
    orbs = [(cx + 34 * math.cos(a), cy + 34 * math.sin(a)) for a in (-math.pi / 2, math.pi / 6, math.pi * 5 / 6)]
    arc = " ".join(f"M{x:.1f},{y:.1f} Q{cx + (x-cx)*0.2 + 6:.1f},{cy + (y-cy)*0.2 - 4:.1f} {cx:.1f},{cy:.1f}" for x, y in orbs)
    e.append(lit_marks(P, arc, VIOLET, "#cdb4ff", w=0.7, glow_w=2.2, op=0.7))
    for x, y in orbs:
        e.append(glow(P, x, y, 14, VIOLET, 0.6))
        b.append(P.shape(ell(x, y, 7), "arcane", s=2, lw=1.8))
        e.append(fill(ell(x - 2, y - 2, 2.6, 2), "#f4ecff", 0.9))
    return J(sh), J(b), J(e)


def arcane_anvil(P, W, H):
    sh, b, e = [], [], []
    blk = rect(30, 14, 64, 68, 4)
    an = [(8, 47), (22, 38), (40, 33), (100, 33), (100, 35), (118, 35), (118, 61), (100, 61), (100, 63), (40, 63), (22, 58)]
    sh.append(ground_shadow(P, blk + " " + poly(an), *SH))
    b.append(P.shape(blk, "slate", s=4))
    b.append(P.detail("M30,30 L94,30 M30,66 L94,66 M52,14 L52,30 M74,66 L74,82", "slate", 0.5, 0.6))
    rnd = random.Random(7)
    side = " ".join(rune_glyphs(rnd, x, y, 2.4) for x, y in [(40, 22), (62, 22), (84, 22), (42, 74), (64, 74), (86, 74)])
    e.append(lit_marks(P, side, VIOLET, VIOLET_HOT, w=0.8, glow_w=2.4, op=0.8))
    b.append(P.shape(smooth([(6, 48), (22, 38), (42, 34), (46, 34), (46, 62), (42, 62), (22, 57)]), "obsidian", s=4))
    b.append(P.shape(rect(42, 32, 60, 32, 2), "obsidian", s=5))
    b.append(P.shape(rect(98, 34, 21, 28, 2), "obsidian", s=3))
    b.append(P.shape(rect(45, 35, 54, 26, 1.5), "darkiron", s=3, lw=2))
    b.append(fill(rect(106, 40, 6, 6), INK, 0.95))
    # imprinted sigil on the face: violet + ember
    sig = f"M60,48 l12,-9 l12,9 l-12,9 Z M72,39 L72,57 M60,48 L84,48"
    e.append(lit_marks(P, sig, VIOLET, VIOLET_HOT, w=1.1, glow_w=3.2, op=0.95, blur=1.4))
    e.append(lit_marks(P, ell(72, 48, 3), EMBER, EMBER_HOT, w=1.1, glow_w=3, op=0.95))
    e.append(lit_marks(P, "M50,40 l3,4 M92,56 l-3,-4 M50,56 l3,-4 M92,40 l-3,4", EMBER, EMBER_HOT, w=0.9, glow_w=2.2, op=0.85))
    e.append(glow(P, 72, 48, 28, VIOLET, 0.3))
    return J(sh), J(b), J(e)


# ======================================================================= STITCHING
def thread_line(P, d, w=0.8, op=0.9):
    return lit_marks(P, d, "#c8d4ea", "#f6f8ff", w=w, glow_w=2.4, op=op, blur=1.0)


def spool(P, x, y, r=4.5, thread=SILVER):
    return "\n".join([P.shape(ell(x, y, r), "wood", s=1, lw=1.2), fill(ell(x, y, r * 0.75), thread, 1),
                      lin(" ".join(ell(x, y, r * k) for k in (0.6, 0.45)), "#9aa0a8", 0.5, 0.8),
                      P.shape(ell(x, y, r * 0.28), "wood", s=0.3, lw=0.6)])


def pelt(cx, cy, sx, sy, rot=0):
    """Hide/pelt outline with leg lobes and neck (unit shape scaled)."""
    pts = [(0, -1.0), (0.3, -0.85), (0.42, -0.95), (0.62, -0.9), (0.55, -0.6), (0.62, -0.2), (0.6, 0.3), (0.66, 0.62),
           (0.8, 0.86), (0.5, 0.82), (0.3, 0.95), (0, 0.9), (-0.3, 0.95), (-0.5, 0.82), (-0.8, 0.86), (-0.66, 0.62),
           (-0.6, 0.3), (-0.62, -0.2), (-0.55, -0.6), (-0.62, -0.9), (-0.42, -0.95), (-0.3, -0.85)]
    c, s_ = math.cos(rot), math.sin(rot)
    return smooth([(cx + (x * sx) * c - (y * sy) * s_, cy + (x * sx) * s_ + (y * sy) * c) for x, y in pts])


def stitching_table(P, W, H):
    sh, b, e = [], [], []
    sh.append(ground_shadow(P, rect(4, 6, 118, 64, 4), *SH))
    b.append(planks(P, 4, 6, 118, 64, "wood", n=4, dirn="h", s=3, seed=21))
    # leather piece with stitch lines
    hidep = pelt(42, 37, 44, 26, math.pi / 2)
    b.append(P.shape(hidep, "hide", s=3))
    b.append(f'<path d="{rect(30, 26, 26, 22, 3)}" fill="none" stroke="#f4ead0" stroke-width="0.9" stroke-dasharray="2.2 1.6" opacity="0.9"/>')
    b.append(P.detail("M22,37 q20,-3 40,0", "hide", 0.4, 0.5))
    # needles, awl, shears
    b.append(lin("M84,18 L104,12 M86,24 L106,20", INK, 1.4))
    b.append(lin("M84,18 L104,12 M86,24 L106,20", "#e8ece8", 0.6))
    e.append(thread_line(P, "M104,12 q8,2 6,10 q-3,8 -16,10 q-14,2 -26,10"))
    b.append(P.shape(poly([(82, 50), (104, 42), (106, 45), (84, 53)]), "silver", s=1, lw=1.3))
    b.append(P.shape(ell(108, 44, 4, 3), "wood", s=1, lw=1.3))
    # shears
    b.append(lin("M88,62 L110,56 M88,56 L110,62", INK, 1.8))
    b.append(lin("M88,62 L110,56 M88,56 L110,62", "#c8ccd0", 0.8))
    b.append(P.shape(ell(85, 63, 3), "darkiron", s=0.5, lw=1.1, flat=True, fill_override="none"))
    b.append(P.shape(ell(85, 55, 3), "darkiron", s=0.5, lw=1.1, flat=True, fill_override="none"))
    # spools of pale thread
    b.append(spool(P, 98, 30, 5))
    b.append(spool(P, 110, 32, 4.5, "#d8c8a8"))
    e.append(glow(P, 98, 30, 9, "#dce6ff", 0.4))
    return J(sh), J(b), J(e)


def thread_spinner(P, W, H):
    sh, b, e = [], [], []
    sh.append(ground_shadow(P, rect(10, 30, 90, 40, 4) + " " + ell(66, 44, 30, 38), *SH))
    # bench with three legs (bench top)
    b.append(planks(P, 10, 40, 92, 22, "wood", n=2, dirn="h", s=2.5, seed=8))
    # big wheel, slightly tilted so the face reads
    wx, wy = 66, 46
    b.append(P.shape(ell(wx, wy, 30, 38), "wood", s=3, flat=True, fill_override="none", lw=2.4))
    b.append(lin(ell(wx, wy, 30, 38), ST["pal"]["wood"][1], 3.4))
    b.append(lin(ell(wx, wy, 30, 38) + " " + ell(wx, wy, 26.5, 34), INK, 0.9))
    sp = " ".join(f"M{wx:.1f},{wy:.1f} L{wx + 27*math.cos(a):.1f},{wy + 35*math.sin(a):.1f}" for a in [i * math.tau / 10 for i in range(10)])
    b.append(lin(sp, INK, 2.2))
    b.append(lin(sp, ST["pal"]["wood"][0], 1.0))
    b.append(P.shape(ell(wx, wy, 5.5), "wood", s=1, lw=1.5))
    # uprights + treadle
    b.append(P.shape(rect(62, 4, 8, 14, 2), "wood", s=1, lw=1.4))
    b.append(P.shape(rect(62, 76, 8, 14, 2), "wood", s=1, lw=1.4))
    b.append(P.shape(rect(80, 68, 24, 9, 2), "wood", s=1.5, lw=1.6))
    # flyer & bobbin + distaff with fibre
    b.append(P.shape(rect(14, 44, 22, 8, 2), "wood", s=1.5, lw=1.5))
    b.append(fill(rect(20, 44.5, 10, 7, 2), SILVER, 1))
    b.append(P.shape(ell(26, 28, 9, 7), "linen", s=1.5, lw=1.4))
    b.append(lin("M26,28 L26,44", INK, 1.2))
    # glowing thread: drive band around wheel + yarn to bobbin
    e.append(thread_line(P, f"M{wx-30},{wy} Q{wx-34},{wy+40} 30,48 M{wx-30},{wy} Q40,40 30,48", w=0.8, op=0.9))
    e.append(thread_line(P, "M26,34 Q24,40 25,46", w=0.8))
    e.append(glow(P, 25, 48, 12, "#dce6ff", 0.45))
    e.append(glow(P, 26, 28, 10, "#dce6ff", 0.3))
    return J(sh), J(b), J(e)


def leather_vat(P, W, H):
    sh, b, e = [], [], []
    cx, cy = 54, 54
    sh.append(ground_shadow(P, ell(cx, cy, 46), *SH))
    b.append(P.shape(ell(cx, cy, 46), "wood", s=5))
    rnd = random.Random(2)
    b.append(P.detail(" ".join(f"M{cx+40*math.cos(a):.1f},{cy+40*math.sin(a):.1f} L{cx+46*math.cos(a):.1f},{cy+46*math.sin(a):.1f}"
                               for a in [i * math.tau / 24 for i in range(24)]), "wood", 0.5, 0.8))
    b.append(lin(ell(cx, cy, 44), INK, 0.8, 0.8))
    b.append(lin(ell(cx, cy, 44), ST["pal"]["darkiron"][1], 1.6, 0.8))
    b.append(P.shape(ell(cx, cy, 39), "wood", s=-3, hl=False, lw=1.8))
    b.append(liquid(P, ell(cx, cy, 37), "brown", cx, cy, 37, 37, ripples=2))
    # hide draped over the rim, soaking
    hd = pelt(cx - 18, cy - 8, 30, 24, -0.5)
    b.append(P.shape(hd, "hide", s=3))
    b.append(P.detail(f"M{cx-38},{cy-12} q12,-8 24,-4 M{cx-36},{cy-2} q14,-4 26,2", "hide", 0.45, 0.7))
    b.append(fill(ell(cx + 2, cy - 4, 6, 4), "#3e2a18", 0.35))
    # paddle
    b.append(P.shape(poly([(cx + 12, cy + 8), (cx + 50, cy + 40), (cx + 47.5, cy + 43), (cx + 9, cy + 11)]), "wood", s=1, lw=1.5))
    b.append(P.shape(ell(cx + 10, cy + 9, 7, 4), "wood", s=1, lw=1.4))
    # bubbles
    b.append(lin(" ".join(ell(cx + rnd.gauss(14, 6), cy + rnd.gauss(-14, 6), rnd.uniform(1, 2.2)) for _ in range(6)), "#c8a47c", 0.7, 0.8))
    return J(sh), J(b), J(e)


def embroidery_frame(P, W, H):
    sh, b, e = [], [], []
    cx, cy = 54, 52
    sh.append(ground_shadow(P, ell(cx, cy, 44) + " " + rect(46, 90, 18, 14), *SH))
    # stand foot
    b.append(P.shape(rect(30, 92, 48, 10, 3), "wood", s=1.5, lw=1.7))
    b.append(P.shape(rect(50, 82, 8, 16, 2), "wood", s=1, lw=1.5))
    # cloth (pale linen) stretched in double hoop
    b.append(P.shape(ell(cx, cy, 40), "linen", s=4))
    sig = []
    for i in range(6):
        a = i * math.tau / 6
        sig.append(f"M{cx:.1f},{cy:.1f} L{cx+22*math.cos(a):.1f},{cy+22*math.sin(a):.1f}")
    sig.append(ell(cx, cy, 22) + " " + ell(cx, cy, 10))
    sig.append(poly([(cx + 22 * math.cos(-math.pi / 2 + i * math.tau / 3), cy + 22 * math.sin(-math.pi / 2 + i * math.tau / 3)) for i in range(3)]))
    sd = " ".join(sig)
    b.append(f'<path d="{sd}" fill="none" stroke="#8a94a8" stroke-width="1.4" stroke-dasharray="1.6 0.9" opacity="0.85"/>')
    e.append(thread_line(P, sd, w=0.6, op=0.6))
    e.append(lit_marks(P, ell(cx, cy, 4), VIOLET, VIOLET_HOT, w=0.9, glow_w=2.4, op=0.75))
    for r, k in ((40, 3.8), (44, 3.6)):
        b.append(lin(ell(cx, cy, r), INK, k + 1.6))
        b.append(lin(ell(cx, cy, r), ST["pal"]["wood"][1], k))
        b.append(lin(ell(cx - 0.6, cy - 0.6, r), ST["pal"]["wood"][0], 0.8, 0.8))
    b.append(P.shape(rect(cx + 40, cy - 6, 10, 12, 2), "bronze", s=1, lw=1.4))  # screw clamp
    # needle with thread
    b.append(lin(f"M{cx+8},{cy-30} L{cx+26},{cy-42}", INK, 1.4))
    b.append(lin(f"M{cx+8},{cy-30} L{cx+26},{cy-42}", "#e8ece8", 0.6))
    e.append(thread_line(P, f"M{cx+26},{cy-42} q8,-4 4,-6 q-6,-2 -16,6 L{cx+6},{cy-24}", w=0.7))
    return J(sh), J(b), J(e)


def fitting_mannequin(P, W, H):
    """Dress form seen from the front/above (tilted so the torso reads), on a pole and tripod."""
    sh, b, e = [], [], []
    cx = 38
    sh.append(ground_shadow(P, ell(cx, 82, 26, 9) + " " + smooth([(cx - 22, 14), (cx + 22, 14), (cx + 18, 52), (cx - 18, 52)]), 4, 4))
    # tripod feet
    for (x1, y1) in [(cx - 26, 88), (cx + 26, 88), (cx, 76)]:
        b.append(lin(f"M{cx},{82} L{x1},{y1}", INK, 4.4))
        b.append(lin(f"M{cx},{82} L{x1},{y1}", ST["pal"]["wood"][1], 2.6))
    b.append(P.shape(rect(cx - 2.5, 50, 5, 34, 1.5), "wood", s=1, lw=1.5))
    b.append(P.shape(ell(cx, 82, 4), "bronze", s=0.8, lw=1.2))
    # torso (linen form)
    torso = smooth([(cx - 24, 16), (cx - 10, 10), (cx + 10, 10), (cx + 24, 16), (cx + 20, 30), (cx + 15, 40), (cx + 19, 52),
                    (cx, 56), (cx - 19, 52), (cx - 15, 40), (cx - 20, 30)])
    b.append(P.shape(torso, "linen", s=4))
    # leather jerkin over it (two front panels, laced)
    for sg in (-1, 1):
        pts = [(cx + sg * 2, 12), (cx + sg * 12, 11), (cx + sg * 22, 17), (cx + sg * 19, 30), (cx + sg * 15, 40), (cx + sg * 18, 51), (cx + sg * 2, 54)]
        b.append(P.shape(smooth(pts), "hide", s=2.5, lw=1.8))
    b.append(P.detail(" ".join(f"M{cx-3},{y} L{cx+3},{y+4} M{cx+3},{y} L{cx-3},{y+4}" for y in (18, 27, 36, 45)), "hide", 0.5))
    b.append(f'<path d="M{cx-14},{20} Q{cx-12},{36} {cx-14},{50} M{cx+14},{20} Q{cx+12},{36} {cx+14},{50}" fill="none" stroke="#f4ead0" stroke-width="0.8" stroke-dasharray="1.8 1.4" opacity="0.85"/>')
    # neck knob
    b.append(P.shape(ell(cx, 8, 6, 4.5), "wood", s=1.5, lw=1.6))
    b.append(P.shape(ell(cx, 7.5, 2.6, 2), "bronze", s=0.5, lw=0.9))
    # pins + tape
    b.append(fill(" ".join(ell(x, y, 1.3) for x, y in [(cx - 18, 22), (cx + 17, 25), (cx - 15, 44), (cx + 16, 46)]), RUB))
    tape = f"M{cx-22},{17} Q{cx-34},{36} {cx-28},{62}"
    b.append(lin(tape, INK, 3.6))
    b.append(lin(tape, "#e8d8a8", 2.2))
    b.append(f'<path d="{tape}" fill="none" stroke="{INK}" stroke-width="2.2" stroke-dasharray="0.5 2.5" opacity="0.7"/>')
    e.append(thread_line(P, f"M{cx+21},{18} q8,12 2,26 M{cx+4},{12} q8,-6 16,4", w=0.6, op=0.75))
    return J(sh), J(b), J(e)


# ======================================================================= TAILORING (iteration 010)
def _bolt(P, x, y, w, h, role, seed=1):
    """A rolled bolt of cloth lying horizontally: body, spiral end and a loose tail."""
    o = [P.shape(rect(x, y, w, h, h * 0.45), role, s=2.5, lw=1.6)]
    o.append(P.detail(" ".join(f"M{x + w * k:.1f},{y + 1.5} L{x + w * k:.1f},{y + h - 1.5}" for k in (0.25, 0.5, 0.75)), role, 0.4, 0.5))
    o.append(P.shape(ell(x + w, y + h / 2, h * 0.32, h / 2), role, s=1, lw=1.4))
    o.append(lin(f"M{x + w},{y + h / 2} m-{h * 0.18:.1f},0 a{h * 0.18:.1f},{h * 0.25:.1f} 0 1,1 {h * 0.3:.1f},0", INK, 0.7, 0.8))
    return J(o)


def loom(P, W, H):
    """Floor loom from above: two side frames, the warp beam at the back, the breast beam with woven cloth at the
    front, a fan of warp threads, the beater (reed) across the middle and a boat shuttle lying on the shed."""
    sh, b, e = [], [], []
    sh.append(ground_shadow(P, rect(6, 6, 116, 98, 4), *SH))
    # side frames (posts at the corners)
    for x in (6, 112):
        b.append(P.shape(rect(x, 6, 10, 98, 2), "wood", s=2.5, lw=1.8))
        b.append(P.detail(f"M{x + 5},{10} L{x + 5},{100}", "wood", 0.4, 0.6))
    for (x, y) in [(4, 4), (110, 4), (4, 94), (110, 94)]:
        b.append(P.shape(rect(x, y, 14, 12, 2), "wood", s=1.5, lw=1.6))
    # warp beam (back) with the rolled warp
    b.append(P.shape(rect(14, 10, 100, 14, 6), "wood", s=2, lw=1.8))
    b.append(P.shape(rect(20, 12, 88, 10, 4), "linen", s=1.5, lw=1.2))
    b.append(P.detail(" ".join(f"M{x},{12.5} L{x},{21.5}" for x in range(24, 106, 6)), "linen", 0.35, 0.5))
    # the warp: many fine threads from the back beam to the fell of the cloth
    warp = " ".join(f"M{24 + i * 2.6:.1f},{22} L{26 + i * 2.5:.1f},{70}" for i in range(31))
    b.append(lin(warp, ST["pal"]["linen"][2], 0.9, 0.9))
    b.append(lin(warp, ST["pal"]["linen"][0], 0.45, 0.9))
    # heddle frames (two shafts) as dark bars with eyes
    for y in (34, 40):
        b.append(P.shape(rect(18, y, 92, 3.4, 1), "darkiron", s=0.6, lw=1.0))
    # beater / reed across the warp
    b.append(P.shape(rect(14, 54, 100, 7, 2), "wood", s=1.5, lw=1.7))
    b.append(lin(" ".join(f"M{x},{55.5} L{x},{59.5}" for x in range(20, 110, 3)), INK, 0.5, 0.6))
    # woven cloth on the breast beam: a plum band through the linen
    cloth = rect(22, 68, 84, 22, 2)
    b.append(P.shape(cloth, "linen", s=3, lw=1.6))
    b.append(fill(rect(22, 76, 84, 6), "#6e3a5e", 0.85))
    b.append(lin(" ".join(f"M{x},{76.5} l2,2.5 l2,-2.5" for x in range(24, 104, 4)), "#e9dcc0", 0.6, 0.8))
    b.append(P.detail(" ".join(f"M22,{y} L106,{y}" for y in (71, 73.5, 85, 87.5)), "linen", 0.35, 0.6))
    b.append(P.shape(rect(14, 88, 100, 10, 4), "wood", s=2, lw=1.8))
    # boat shuttle with its bobbin of thread resting on the warp
    sht = smooth([(40, 47), (52, 44.5), (76, 44.5), (88, 47), (76, 49.5), (52, 49.5)])
    b.append(P.shape(sht, "wood", s=1.5, lw=1.5))
    b.append(fill(rect(56, 45.6, 16, 2.8, 1.2), "#6e3a5e", 0.95))
    b.append(lin("M70,47 Q92,52 104,66", "#6e3a5e", 0.9, 0.85))
    # bench in front (edge only)
    b.append(P.shape(rect(36, 100, 56, 9, 2), "wood", s=1.2, lw=1.5))
    return J(sh), J(b), J(e)


def cutting_table(P, W, H):
    """Long cutting table: a bolt of blue wool unrolled, paper pattern pieces chalked onto it, great shears,
    a yardstick with tick marks and a pin cushion."""
    sh, b, e = [], [], []
    sh.append(ground_shadow(P, rect(4, 6, 120, 66, 4), *SH))
    b.append(planks(P, 4, 6, 120, 66, "wood", n=4, dirn="h", s=3, seed=31))
    # unrolled cloth from the bolt on the left
    b.append(P.shape(rect(18, 14, 74, 48, 2), "tunic", s=3, lw=1.6))
    b.append(P.detail(" ".join(f"M18,{y} L92,{y}" for y in range(18, 62, 5)), "tunic", 0.3, 0.45))
    b.append(_bolt(P, 6, 12, 14, 52, "tunic"))
    # chalked pattern pieces: a robe panel (trapezoid with sleeve) and a hood
    chalk = (poly([(28, 18), (52, 18), (60, 56), (22, 56)]) + " " + smooth([(64, 20), (82, 22), (88, 36), (80, 48), (66, 46), (62, 32)]))
    b.append(f'<path d="{chalk}" fill="none" stroke="#f4ead0" stroke-width="1.1" stroke-dasharray="2.4 1.6" opacity="0.95"/>')
    # a paper pattern piece pinned on top
    b.append(P.shape(poly([(66, 24), (80, 26), (84, 36), (72, 40), (64, 34)]), "paper", s=1.5, lw=1.2))
    b.append(fill(" ".join(ell(x, y, 1.1) for x, y in [(68, 27), (80, 30), (72, 37)]), RUB))
    # great shears, open
    b.append(lin("M94,58 L118,40 M96,44 L118,58", INK, 2.6))
    b.append(lin("M94,58 L118,40 M96,44 L118,58", "#c8ccd0", 1.3))
    b.append(P.shape(ell(92, 61, 4, 3), "darkiron", s=0.5, lw=1.2, flat=True, fill_override="none"))
    b.append(P.shape(ell(93, 41, 4, 3), "darkiron", s=0.5, lw=1.2, flat=True, fill_override="none"))
    # yardstick
    b.append(P.shape(rect(20, 64, 82, 5, 1), "bronze", s=1, lw=1.2))
    b.append(lin(" ".join(f"M{x},{64.5} l0,{2 if (x - 22) % 10 else 3.5}" for x in range(22, 100, 5)), INK, 0.6, 0.85))
    # pin cushion and chalk
    b.append(P.shape(ell(108, 22, 7, 6), "redp", s=1.5, lw=1.3))
    b.append(lin(" ".join(f"M{108 + dx},{22 + dy} l{dx * 0.4:.1f},{dy * 0.4 - 2:.1f}" for dx, dy in [(-3, -2), (2, -3), (3, 1), (-1, 2)]), "#d8dce0", 0.8))
    b.append(P.shape(rect(100, 30, 10, 4, 1), "paper", s=0.6, lw=1.0))
    return J(sh), J(b), J(e)


def tailors_bench(P, W, H):
    """Tailor's bench: a half-sewn plum robe laid out, running stitches, needle and thread, thimble, spools,
    a pin cushion and a pressing iron."""
    sh, b, e = [], [], []
    sh.append(ground_shadow(P, rect(4, 6, 104, 66, 4), *SH))
    b.append(planks(P, 4, 6, 104, 66, "wood", n=3, dirn="h", s=3, seed=17))
    # the garment: robe body with one sleeve, folded hem
    robe = smooth([(22, 14), (38, 12), (46, 18), (56, 12), (72, 14), (84, 22), (78, 30), (70, 26), (72, 62), (24, 64), (26, 26), (16, 30), (12, 22)])
    b.append(P.shape(robe, "cloth", s=3, fill_override="#6e3a5e", lw=1.6))
    b.append(fill(smooth([(30, 16), (46, 22), (62, 16), (64, 40), (34, 42)]), "#8a4e76", 0.5))
    b.append(P.detail("M46,18 L46,60 M24,56 Q48,60 72,56", "cloth", 0.5, 0.6))
    # gilt trim at the hem and collar (sigil-ish), running stitch along the seam
    b.append(lin("M25,58 Q48,62 71,58", GILT, 1.6, 0.95))
    b.append(lin("M38,13 Q46,20 56,13", GILT, 1.2, 0.95))
    b.append(f'<path d="M58,16 L66,60" fill="none" stroke="#f4ead0" stroke-width="0.9" stroke-dasharray="2 1.5" opacity="0.9"/>')
    # needle and its thread trailing from the seam
    b.append(lin("M66,34 L84,44", INK, 1.4))
    b.append(lin("M66,34 L84,44", "#e8ece8", 0.6))
    b.append(lin("M84,44 q8,4 4,10 q-4,6 -14,4", "#e9dcc0", 0.8, 0.9))
    # spools, thimble, pin cushion
    b.append(spool(P, 92, 18, 5, "#e9dcc0"))
    b.append(spool(P, 100, 26, 4.5, "#6e3a5e"))
    b.append(spool(P, 90, 30, 4.5, GILT))
    b.append(P.shape(ell(96, 44, 4), "silver", s=1, lw=1.2))
    b.append(fill(" ".join(ell(96 + dx, 44 + dy, 0.5) for dx in (-2, 0, 2) for dy in (-2, 0, 2)), INK, 0.6))
    b.append(P.shape(ell(14, 56, 7, 6), "redp", s=1.5, lw=1.3))
    b.append(lin(" ".join(f"M{14 + dx},{56 + dy} l{dx * 0.4:.1f},{dy * 0.4 - 2:.1f}" for dx, dy in [(-3, -2), (2, -3), (3, 1)]), "#d8dce0", 0.8))
    # pressing iron
    b.append(P.shape(poly([(84, 58), (104, 56), (106, 66), (86, 68)]), "darkiron", s=2, lw=1.5))
    b.append(P.shape(rect(90, 58, 10, 3.5, 1.5), "wood", s=0.8, lw=1.0))
    return J(sh), J(b), J(e)


STATIONS = dict(anvil=anvil, forge=forge, crucible=crucible, quench_trough=quench_trough, bellows=bellows,
                grinding_wheel=grinding_wheel, rune_cutting_bench=rune_cutting_bench, rune_engraving_stand=rune_engraving_stand,
                rune_cleansing_basin=rune_cleansing_basin, resonance_pedestal=resonance_pedestal,
                rune_polishing_wheel=rune_polishing_wheel, mortar_station=mortar_station, alembic=alembic, cauldron=cauldron,
                reagent_table=reagent_table, infusion_rack=infusion_rack, arcane_crucible=arcane_crucible,
                spellbinding_array=spellbinding_array, leyline_conductor=leyline_conductor,
                aetheric_stabilizer=aetheric_stabilizer, arcane_anvil=arcane_anvil, stitching_table=stitching_table,
                thread_spinner=thread_spinner, leather_vat=leather_vat, embroidery_frame=embroidery_frame,
                fitting_mannequin=fitting_mannequin, loom=loom, cutting_table=cutting_table, tailors_bench=tailors_bench)

RUB = ST["rubric"]


def jobs():
    only = only_filter()
    js = []
    for s in load("stations.json"):
        sid = s["id"]
        if only and sid not in only:
            continue
        W, H = s["size"]
        P = painter(scale=1.0, lw_mul=0.7)
        fn = STATIONS[sid]
        # center the drawing in the canvas: functions draw within their own nominal box
        sh, body, emit = fn(P, W, H)
        svg = sprite_svg(P, W, H, sh, body, emit, ss=3, wob=0.9, dil=0.75, grain=0.45, soot=0.8)
        js.append(dict(name=f"st_{sid}", svg=svg, w=W, h=H, ss=3, out=os.path.join(SPR, "stations", sid + ".png")))
    return js


if __name__ == "__main__":
    render(jobs())
