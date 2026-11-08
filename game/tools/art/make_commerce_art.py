"""Commerce art for Ember & Ash (iteration 010): companion creatures (icons + village miniatures), the rival smith's
sea-bronze and ripple-steel work and the caravan's curiosities.

    python3 game/tools/art/make_commerce_art.py               # everything
    python3 game/tools/art/make_commerce_art.py icons minis   # a part
    python3 game/tools/art/make_commerce_art.py --contact     # review sheet only

Icons:  assets/sprites/icons/template_<item id>.png (64x64, designed in a 128-unit space like make_icons.py).
Minis:  assets/sprites/creatures/template_<creature>.png — 128x64: two 64x64 frames (idle/step or wing up/down)
        of a little tabletop miniature: the creature in side view facing right on a round dark base (same base as
        the village animals, 40 px wide). Flying creatures sit on a thin brass flight-stand above the base.
        The game flips the sprite for leftward movement.
Characters (rival_smith, pawnbroker, caravan_master, hale_elder, hale_younger) use the shared tools:
        python3 make_minis.py --only=rival_smith,pawnbroker,caravan_master,hale_elder,hale_younger
        python3 make_characters.py rival_smith pawnbroker caravan_master hale_elder hale_younger
Review: tools/art/out/commerce_contact.png
"""
import math
import os
import random
import sys

from artlib import (painter, render, svg_doc, ink_filter, lin, fill, glow, ell, rect, poly, smooth, blob, lit_marks,
                    INK, EMBER, EMBER_HOT, GILT, VIOLET, VIOLET_HOT, SPR, OUT, ST)
import miniature as M
import make_icons as MI

PAL = ST["pal"]
J = MI.J
cap = M.capsule

PAL.update(
    tabby=("#e0ae6c", "#b47838", "#5a3414"),
    mulecoat=("#a8927c", "#76604c", "#382c20"),
    ponycoat=("#94704e", "#5e4028", "#2a1a0c"),
    mane=("#4a3626", "#2a1c12", "#140c06"),
    hound=("#a88660", "#745232", "#3a2614"),
    falcon=("#a89880", "#6e5e4c", "#342a20"),
    pale=("#f4ecd8", "#dcd0b4", "#8e8264"),
    moth=("#f2f4f8", "#c8d0dc", "#6a7488"),
    toad=("#bcb8ac", "#86827a", "#423e38"),
    fox=("#eca868", "#c46e2c", "#5e2c0c"),
    drake=("#e07058", "#a42c1e", "#4a0c08"),
    drakebelly=("#f2cc94", "#d29c54", "#6e4618"),
    seabronze=("#c8c08a", "#8e9a5e", "#3e4a2a"),
    ripple=("#e8ecee", "#a8b2b8", "#4e585e"),
)
GROUND = 104.0


# ====================================================================== creatures (side view, facing right)
def legs4(P, xs, top, ground, w, role, f, far_role=None):
    """Four legs: far pair first (darker), near pair; frame 1 swings them a little."""
    o = []
    sw = 4 if f else -4
    fr = far_role or role
    for i, x in enumerate(xs):
        s = sw if i % 2 == 0 else -sw
        o.append(P.shape(cap((x + 3, top), (x + 3 + s * 0.6, ground - 1), w * 0.9, w * 0.75), fr, s=1))
    for i, x in enumerate(xs):
        s = -sw if i % 2 == 0 else sw
        o.append(P.shape(cap((x, top), (x + s * 0.6, ground), w, w * 0.8), role, s=1.4))
    return J(o)


def mouser_cat(P, f):
    o = []
    y = GROUND
    tail_tip = (24, 46) if f else (20, 52)
    o.append(P.shape(smooth([(42, y - 26), (30, y - 34), tail_tip, (tail_tip[0] + 6, tail_tip[1] + 2), (36, y - 30), (46, y - 20)], close=True, t=0.45), "tabby", s=1.4))
    o.append(legs4(P, [48, 58, 78, 86], y - 22, y, 4.0, "tabby", f))
    o.append(P.shape(ell(66, y - 30, 26, 12), "tabby", s=3))
    o.append(P.detail(" ".join(f"M{x},{y-41} q2,6 0,11" for x in range(52, 82, 7)), "tabby", 0.9, 0.9))
    hx, hy = 92, y - 42
    o.append(P.shape(poly([(hx - 9, hy - 6), (hx - 7, hy - 20), (hx - 1, hy - 9)]) + " " + poly([(hx + 3, hy - 9), (hx + 7, hy - 21), (hx + 11, hy - 5)]), "tabby", s=1))
    o.append(P.shape(ell(hx, hy, 12, 11), "tabby", s=2))
    o.append(P.shape(ell(hx + 7, hy + 5, 6, 4.5), "pale", s=0.6, lw=1.0))
    o.append(fill(ell(hx + 4, hy - 2, 2.2, 2.6), "#7a8a2a") + fill(ell(hx + 4.5, hy - 2, 0.8, 2.2), INK))
    o.append(P.detail(f"M{hx+9},{hy+5} l9,-2 M{hx+9},{hy+6} l9,2", None, 0.6, 0.8))
    o.append(P.detail(f"M{hx-8},{hy-3} l5,1 M{hx-9},{hy+1} l5,0", "tabby", 0.8))
    return J(o), ""


def pack_mule(P, f):
    o = []
    y = GROUND
    o.append(P.shape(smooth([(20, y - 46), (12, y - 30 + (3 if f else 0)), (16, y - 28), (22, y - 40)], t=0.4), "mulecoat", s=1))
    o.append(legs4(P, [28, 38, 74, 84], y - 34, y, 4.6, "mulecoat", f))
    o.append(P.shape(ell(56, y - 44, 36, 16), "mulecoat", s=3))
    o.append(P.shape(ell(56, y - 32, 26, 6), "pale", s=0.8, lw=0.8))
    # neck and long head with long ears
    o.append(P.shape(smooth([(80, y - 52), (92, y - 74), (104, y - 76), (100, y - 58), (88, y - 40)], t=0.45), "mulecoat", s=2))
    o.append(P.shape(poly([(96, y - 76), (90, y - 98), (100, y - 78)]) + " " + poly([(101, y - 76), (102, y - 98), (106, y - 76)]), "mulecoat", s=1))
    o.append(P.shape(smooth([(96, y - 78), (116, y - 64), (118, y - 56), (108, y - 54), (98, y - 64)], t=0.45), "mulecoat", s=2))
    o.append(P.shape(ell(115, y - 57, 5, 5), "pale", s=0.6, lw=0.9))
    o.append(fill(ell(104, y - 70, 1.6, 1.8), INK))
    # pack saddle: two bundles and a rolled blanket
    o.append(P.shape(rect(36, y - 74, 22, 22, 4), "burlap", s=2))
    o.append(P.shape(rect(58, y - 72, 20, 20, 4), "burlap", s=2))
    o.append(P.detail(f"M36,{y-63} L58,{y-63} M58,{y-62} L78,{y-62}", "leather", 1.2))
    o.append(P.shape(cap((38, y - 78), (76, y - 76), 5, 5), "cloth", s=1))
    o.append(P.detail(f"M47,{y-74} L47,{y-36} M68,{y-72} L68,{y-36}", "leather", 1.0, 0.9))
    return J(o), ""


def fell_pony(P, f):
    o = []
    y = GROUND
    o.append(P.shape(smooth([(24, y - 50), (10, y - 34 + (4 if f else 0)), (14, y - 22), (20, y - 30), (26, y - 42)], t=0.4), "mane", s=1))
    o.append(legs4(P, [30, 40, 72, 82], y - 32, y, 5.2, "ponycoat", f))
    # feathered fetlocks
    o.append(P.shape(" ".join(ell(x + (2 if f and i % 2 else -2 if f else 0) * 0, y - 3, 6, 3.5) for i, x in enumerate([30, 40, 72, 82])), "pale", s=0.4, lw=0.8))
    o.append(P.shape(ell(56, y - 44, 32, 16), "ponycoat", s=3))
    o.append(P.shape(smooth([(76, y - 52), (86, y - 72), (98, y - 74), (96, y - 56), (84, y - 40)], t=0.45), "ponycoat", s=2))
    o.append(P.shape(smooth([(92, y - 76), (112, y - 64), (112, y - 56), (102, y - 54), (92, y - 62)], t=0.45), "ponycoat", s=2))
    o.append(P.shape(poly([(92, y - 76), (91, y - 86), (97, y - 76)]), "ponycoat", s=0.6))
    o.append(P.shape(smooth([(78, y - 50), (84, y - 76), (94, y - 80), (90, y - 70), (84, y - 52)], t=0.4), "mane", s=1))
    o.append(P.shape(smooth([(92, y - 80), (102, y - 78), (98, y - 70)], t=0.4), "mane", s=0.6))
    o.append(fill(ell(100, y - 68, 1.6, 1.8), INK))
    o.append(P.shape(rect(46, y - 62, 22, 8, 3), "leather", s=1))
    return J(o), ""


def war_hound(P, f):
    o = []
    y = GROUND
    tail = [(30, y - 44), (16, y - 56 - (4 if f else 0)), (14, y - 52 - (4 if f else 0)), (28, y - 40)]
    o.append(P.shape(smooth(tail, t=0.45), "hound", s=1))
    o.append(legs4(P, [36, 46, 74, 84], y - 30, y, 4.8, "hound", f))
    o.append(P.shape(smooth([(28, y - 40), (40, y - 52), (70, y - 54), (90, y - 50), (94, y - 34), (80, y - 28), (52, y - 30), (32, y - 30)], t=0.45), "hound", s=3))
    o.append(P.shape(smooth([(80, y - 34), (92, y - 30), (90, y - 22)], close=True, t=0.4), "pale", s=0.6, lw=0.8))
    # head with drop ear, muzzle, collar
    hx, hy = 96, y - 60
    o.append(P.shape(smooth([(86, y - 50), (90, hy - 6), (104, hy - 10), (118, hy - 2), (118, hy + 6), (104, hy + 8), (92, y - 42)], t=0.45), "hound", s=2))
    o.append(P.shape(smooth([(94, hy - 8), (88, hy + 2), (90, hy + 12), (96, hy + 4)], t=0.4), "brown", s=1))
    o.append(fill(ell(116, hy - 1, 3, 2.6), INK))
    o.append(fill(ell(103, hy - 4, 1.8, 1.8), INK))
    o.append(P.shape(cap((86, y - 54), (92, y - 42), 4.2, 4.2), "leather", s=1))
    o.append(" ".join(fill(ell(87 + i * 2, y - 52 + i * 4, 1.3, 1.3), GILT) for i in range(3)))
    return J(o), ""


def _wings_bird(P, f, role, span=46):
    up = f == 0
    if up:
        return P.shape(smooth([(56, 52), (40, 18), (60, 8), (78, 24), (74, 48)], t=0.45), role, s=2)
    return P.shape(smooth([(56, 54), (30, 78), (40, 88), (70, 70), (76, 56)], t=0.45), role, s=2)


def flight_stand(P):
    """Thin brass rod from the base up to a flying miniature."""
    return P.shape(rect(62, 64, 4, GROUND - 64), "bronze", s=0.6, lw=0.9)


def hunting_falcon(P, f):
    o = []
    # far wing
    o.append(P.shape(smooth([(60, 52), (52, 22 if f == 0 else 76), (72, 30 if f == 0 else 70), (74, 50)], t=0.45), "mane", s=1))
    # tail fan
    o.append(P.shape(poly([(44, 58), (22, 52), (22, 68), (44, 64)]), "falcon", s=1))
    o.append(P.detail("M24,56 L42,59 M24,63 L42,62", "falcon", 0.7))
    o.append(P.shape(ell(62, 58, 22, 11), "falcon", s=2.5))
    o.append(P.shape(smooth([(56, 62), (78, 60), (82, 66), (60, 68)], t=0.4), "pale", s=0.6, lw=0.8))
    o.append(P.detail(" ".join(f"M{x},{63} l2,2" for x in range(60, 80, 5)), "falcon", 0.6))
    o.append(P.shape(ell(86, 52, 10, 9), "falcon", s=1.5))
    o.append(P.shape(smooth([(84, 54), (90, 56), (88, 60)], t=0.3), "pale", s=0.4, lw=0.7))
    o.append(P.shape(poly([(94, 48), (102, 52), (95, 56)]), "gold", s=0.5, lw=0.9))
    o.append(fill(ell(89, 50, 2.2, 2.2), INK) + fill(ell(88.5, 49.4, 0.7, 0.7), "#ffffff"))
    # jesses
    o.append(P.detail("M62,68 l-2,8 M66,68 l1,8", "leather", 0.9))
    o.append(_wings_bird(P, f, "falcon"))
    o.append(P.detail("M46,26 L66,40 M50,20 L70,34" if f == 0 else "M38,82 L64,66 M46,86 L70,70", "falcon", 0.7, 0.8))
    return J(o), ""


def moon_moth(P, f):
    o = []
    emit = glow(P, 64, 52, 46, "#cfe0ff", 0.35)
    up = f == 0
    # wings: forewing + hindwing, two silver pairs
    if up:
        fw = smooth([(64, 54), (34, 14), (52, 8), (80, 18), (70, 48)], t=0.45)
        hw = smooth([(62, 58), (36, 62), (28, 80), (48, 82), (66, 64)], t=0.45)
    else:
        fw = smooth([(64, 54), (24, 40), (26, 24), (60, 30), (72, 50)], t=0.45)
        hw = smooth([(62, 58), (30, 74), (36, 92), (58, 84), (68, 64)], t=0.45)
    o.append(P.shape(fw, "moth", s=2))
    o.append(P.shape(hw, "moth", s=2))
    ex, ey = (52, 26) if up else (40, 34)
    o.append(P.shape(ell(ex, ey, 6, 5), "pale", s=0.6, lw=1.0))
    o.append(fill(ell(ex, ey, 2.4, 2.2), "#4a6aa8"))
    o.append(P.detail(f"M64,54 Q{ex-4},{ey+12} {ex-12},{ey-6}", "moth", 0.7, 0.8))
    # body, furry thorax, feathered antennae
    o.append(P.shape(cap((52, 60), (80, 54), 6, 7), "pale", s=1.4))
    o.append(P.detail(" ".join(f"M{x},{56} l0,8" for x in range(56, 74, 4)), "pale", 0.6))
    o.append(P.detail("M80,52 Q88,40 96,36 M80,52 Q92,46 100,46", None, 0.9))
    o.append(P.detail("M86,42 l3,-4 M90,39 l3,-3 M90,46 l2,-4 M94,46 l3,-3", None, 0.5))
    o.append(fill(ell(82, 52, 1.6, 1.6), INK))
    emit += J(fill(MI.sparkle(x, yy, r), "#f4f8ff", 0.95) for x, yy, r in ([(30, 30, 4), (92, 70, 3), (40, 92, 3)] if up else [(26, 52, 4), (96, 30, 3), (50, 96, 3)]))
    return J(o), emit


def stone_toad(P, f):
    o = []
    y = GROUND
    sw = 1 if f else 0
    o.append(P.shape(smooth([(32, y - 2), (26, y - 14), (40, y - 18), (48, y - 4)], t=0.4), "toad", s=1))
    o.append(P.shape(smooth([(30, y - 8), (36, y - 34 - sw), (60, y - 46 - sw * 2), (88, y - 40 - sw), (100, y - 22), (96, y - 4), (40, y - 2)], t=0.45), "toad", s=4))
    rnd = random.Random(4)
    o.append(P.shape(" ".join(blob(rnd.uniform(44, 84), rnd.uniform(y - 38, y - 16), rnd.uniform(3, 6), 7, 0.25, seed=i) for i in range(7)), "slate", s=0.8, lw=0.9))
    o.append(P.detail("M50,%d l6,8 l-2,8 M72,%d l-4,10 l6,6" % (y - 40, y - 42), "toad", 0.9))
    o.append(P.shape(smooth([(70, y - 12), (96, y - 10), (100, y - 2), (72, y - 2)], t=0.4), "pale", s=0.6, lw=0.8))
    o.append(P.shape(ell(84, y - 40 - sw, 8, 7), "toad", s=1.4))
    o.append(fill(ell(85, y - 41 - sw, 4.5, 4.2), "#d8a830") + fill(ell(86, y - 41 - sw, 1.2, 3.4), INK))
    o.append(P.detail(f"M92,{y-24} Q100,{y-22} 100,{y-16}", None, 1.0))
    o.append(P.shape(smooth([(80, y - 4), (92, y - 2), (94, y + 1), (78, y + 1)], t=0.4), "toad", s=0.6))
    emit = lit_marks(P, "M54,%d l4,-6 l4,6 M64,%d l0,-8 M60,%d l8,0" % (y - 26, y - 22, y - 26), "#9fd4ec", "#e4f4fa", w=1.0, glow_w=3.4, op=0.85 + 0.1 * f, blur=1.6)
    return J(o), emit


def glimmer_fox(P, f):
    o = []
    y = GROUND
    tail = [(36, y - 38), (18, y - 44 - (5 if f else 0)), (8, y - 34 - (5 if f else 0)), (14, y - 26), (34, y - 30)]
    o.append(P.shape(smooth(tail, t=0.45), "fox", s=1.6))
    o.append(P.shape(smooth([(14, y - 40 - (5 if f else 0)), (6, y - 34 - (5 if f else 0)), (12, y - 28), (18, y - 34)], t=0.4), "pale", s=0.6, lw=0.9))
    o.append(legs4(P, [42, 50, 74, 82], y - 26, y, 3.4, "mane", f))
    o.append(P.shape(smooth([(34, y - 34), (46, y - 44), (74, y - 46), (88, y - 40), (86, y - 28), (50, y - 24)], t=0.45), "fox", s=3))
    o.append(P.shape(smooth([(70, y - 30), (88, y - 32), (86, y - 26), (70, y - 26)], t=0.4), "pale", s=0.6, lw=0.8))
    hx, hy = 94, y - 50
    o.append(P.shape(poly([(hx - 8, hy - 4), (hx - 6, hy - 20), (hx, hy - 8)]) + " " + poly([(hx - 1, hy - 7), (hx + 3, hy - 21), (hx + 7, hy - 6)]), "fox", s=0.8))
    o.append(P.shape(smooth([(hx - 12, hy + 6), (hx - 8, hy - 8), (hx + 6, hy - 8), (hx + 20, hy + 2), (hx + 6, hy + 8)], t=0.4), "fox", s=2))
    o.append(P.shape(smooth([(hx + 2, hy + 3), (hx + 19, hy + 2), (hx + 6, hy + 8)], t=0.4), "pale", s=0.4, lw=0.7))
    o.append(fill(ell(hx + 19, hy + 1, 2, 1.8), INK))
    o.append(fill(ell(hx + 4, hy - 2, 2, 1.6), "#2a1a10") + fill(ell(hx + 3.5, hy - 2.5, 0.7, 0.6), "#ffffff"))
    sp = [(10, y - 50, 4), (4, y - 24, 3), (22, y - 54, 2.5), (30, y - 18, 2.5)] if f == 0 else [(6, y - 46, 3), (14, y - 58, 4), (2, y - 30, 2.5), (26, y - 14, 3)]
    emit = glow(P, 14, y - 38, 24, VIOLET_HOT, 0.4) + J(fill(MI.sparkle(x, yy, r), "#fff2c0", 0.95) for x, yy, r in sp)
    return J(o), emit


def pocket_drake(P, f):
    o = []
    emit = ""
    # tail
    o.append(P.shape(smooth([(44, 62), (26, 70), (14, 62), (8, 66), (14, 72), (28, 76), (48, 68)], t=0.45), "drake", s=1.4))
    o.append(P.shape(poly([(8, 66), (2, 60), (6, 70)]), "drake", s=0.4))
    # far wing
    o.append(P.shape(poly([(58, 54), (44, 18 if f == 0 else 84), (62, 28 if f == 0 else 76), (70, 52)]), "drake", s=1, lw=1.0))
    o.append(P.shape(ell(60, 60, 20, 11), "drake", s=2.4))
    o.append(P.shape(smooth([(48, 66), (74, 64), (76, 70), (52, 71)], t=0.4), "drakebelly", s=0.6, lw=0.8))
    o.append(P.detail(" ".join(f"M{x},{51} l2,-3 l2,3" for x in range(50, 72, 5)), "drake", 0.8))
    # legs tucked
    o.append(P.shape(cap((52, 68), (50, 76), 3, 2.4) + " " + cap((68, 68), (70, 76), 3, 2.4), "drake", s=0.8))
    # neck and head with horns
    o.append(P.shape(smooth([(70, 58), (80, 44), (88, 42), (84, 56), (76, 64)], t=0.45), "drake", s=1.4))
    o.append(P.shape(smooth([(82, 38), (98, 40), (104, 46), (94, 50), (84, 48)], t=0.4), "drake", s=1.4))
    o.append(P.shape(poly([(84, 38), (78, 28), (88, 36)]) + " " + poly([(88, 38), (86, 28), (92, 37)]), "drakebelly", s=0.4, lw=0.9))
    o.append(fill(ell(92, 42, 2, 1.8), "#ffc070") + fill(ell(92.3, 42, 0.6, 1.4), INK))
    # near wing (membrane with finger bones)
    if f == 0:
        wing = poly([(60, 54), (52, 10), (66, 18), (78, 14), (80, 32), (74, 50)])
        bones = "M60,54 L52,10 M62,52 L66,18 M66,52 L78,14"
    else:
        wing = poly([(60, 58), (38, 92), (58, 86), (70, 96), (78, 76), (74, 60)])
        bones = "M60,58 L38,92 M64,60 L58,86 M68,60 L70,96"
    o.append(P.shape(wing, "drake", s=2, lw=1.3))
    o.append(P.detail(bones, None, 0.9))
    if f == 1:
        emit = glow(P, 112, 48, 18, EMBER, 0.6) + fill(smooth([(104, 46), (116, 40), (124, 46), (116, 52)], t=0.4), EMBER_HOT, 0.9)
    else:
        emit = fill(ell(106, 45, 2, 1.4), "#bfb4a8", 0.6) + fill(ell(110, 40, 2.6, 2), "#bfb4a8", 0.45)
    return J(o), emit


CREATURES = {
    "mouser_cat": (mouser_cat, False), "pack_mule": (pack_mule, False), "fell_pony": (fell_pony, False),
    "war_hound": (war_hound, False), "hunting_falcon": (hunting_falcon, True), "moon_moth": (moon_moth, True),
    "stone_toad": (stone_toad, False), "glimmer_fox": (glimmer_fox, False), "pocket_drake": (pocket_drake, True),
}
# creature -> (mini scale, icon scale, icon dx, icon dy)
FIT = {
    "mouser_cat": (0.76, 1.05, -2, 4), "pack_mule": (0.62, 0.95, -4, 12), "fell_pony": (0.64, 1.0, -4, 12),
    "war_hound": (0.7, 1.0, -6, 8), "hunting_falcon": (0.74, 1.05, 0, -6), "moon_moth": (0.74, 1.05, 0, -4),
    "stone_toad": (0.8, 1.15, -2, -8), "glimmer_fox": (0.72, 1.05, 2, 0), "pocket_drake": (0.72, 1.0, 0, -4),
}


# ====================================================================== rival smith & curio icons
def cutlass_seabronze(P):
    o = []
    blade = smooth([(56, 96), (54, 50), (60, 22), (74, 12), (70, 30), (66, 60), (66, 96)], t=0.4)
    o.append(P.shape(blade, "seabronze", s=3))
    o.append(P.detail("M60,92 Q58,50 68,22", "seabronze", 0.8, 0.8))
    o.append(fill(smooth([(57, 90), (56, 52), (62, 28), (60, 54), (60, 90)], t=0.4), "#ffffff", 0.25))
    o.append(P.shape(smooth([(46, 98), (60, 94), (74, 96), (78, 104), (70, 100), (56, 100)], t=0.4), "bronze", s=1.5))
    o.append(P.shape(smooth([(48, 100), (44, 112), (52, 120), (58, 116), (52, 110), (54, 102)], t=0.4), "bronze", s=1))
    o.append(P.shape(rect(56, 100, 10, 18, 3), "leather", s=1.5))
    o.append(P.shape(ell(61, 121, 6), "bronze", s=1))
    o.append(fill(ell(70, 40, 3, 2), "#6e9a7a", 0.6) + fill(ell(64, 70, 2.4, 1.6), "#6e9a7a", 0.5))
    return MI.rot(J(o), 35), ""


def harpoon_barbed(P):
    o = []
    o.append(P.shape(rect(61, 34, 6, 92, 2), "wood", s=2))
    o.append(P.detail("M62,60 l4,3 M62,80 l4,3 M62,100 l4,3", "wood", 0.6))
    o.append(P.shape(poly([(64, 4), (72, 26), (68, 26), (78, 38), (68, 34), (68, 40), (60, 40), (60, 34), (50, 38), (60, 26), (56, 26)]), "seabronze", s=2))
    o.append(P.shape(rect(58, 40, 12, 8, 2), "bronze", s=1))
    o.append(P.detail("M60,44 Q48,56 56,70 Q64,80 54,92", "linen", 1.4))
    return MI.rot(J(o), 40), ""


def buckler_seabronze(P):
    o = [P.shape(ell(64, 64, 46, 46), "seabronze", s=5)]
    o.append(P.shape(ell(64, 64, 38, 38), "bronze", s=2, lw=1.0))
    o.append(P.detail(" ".join(f"M{64+math.cos(a)*30:.1f},{64+math.sin(a)*30:.1f} L{64+math.cos(a)*40:.1f},{64+math.sin(a)*40:.1f}" for a in [i * math.pi / 4 for i in range(8)]), "bronze", 0.8))
    o.append(P.shape(ell(64, 64, 13, 13), "seabronze", s=2))
    o.append(fill(ell(60, 60, 4, 3), "#ffffff", 0.5))
    o.append(fill(ell(30, 80, 8, 4), "#6e9a7a", 0.55) + fill(ell(94, 42, 6, 3), "#6e9a7a", 0.5))
    o.append(" ".join(fill(ell(64 + math.cos(a) * 42, 64 + math.sin(a) * 42, 2.2, 2.2), "#3e4a2a") for a in [i * math.pi / 6 for i in range(12)]))
    return J(o), ""


def helm_brinecap(P):
    o = []
    o.append(P.shape(smooth([(24, 88), (30, 108), (98, 108), (104, 88), (88, 98), (40, 98)], t=0.4), "leather", s=2))
    o.append(P.shape(smooth([(24, 86), (28, 46), (64, 24), (100, 46), (104, 86), (64, 92)], t=0.45), "seabronze", s=4))
    o.append(P.shape(cap((24, 84), (104, 84), 5, 5), "bronze", s=1))
    o.append(P.detail("M64,26 L64,82", "seabronze", 1.0))
    o.append(" ".join(fill(ell(x, 84, 1.8, 1.8), "#3e4a2a") for x in range(32, 100, 10)))
    o.append(fill(smooth([(36, 74), (40, 50), (56, 34), (46, 54), (42, 74)], t=0.4), "#ffffff", 0.3))
    emit = lit_marks(P, "M58,52 l6,-8 l6,8 M60,60 l8,0", "#9fd4ec", "#e4f4fa", w=1.0, glow_w=3, op=0.7, blur=1.4)
    return J(o), emit


def sabre_ripple(P):
    o = []
    blade = smooth([(58, 100), (56, 60), (60, 26), (70, 8), (68, 30), (66, 64), (66, 100)], t=0.4)
    o.append(P.shape(blade, "ripple", s=3))
    o.append(P.detail(" ".join(f"M{58+i%2},{94-i*8} q4,-3 7,0" for i in range(10)), "ripple", 0.7, 0.85))
    o.append(P.shape(smooth([(48, 102), (64, 98), (80, 102), (64, 106)], t=0.4), "gold", s=1.5))
    o.append(P.shape(rect(58, 104, 10, 16, 3), "cloth", s=1.5))
    o.append(P.shape(ell(63, 122, 5.5), "gold", s=1))
    return MI.rot(J(o), 38), ""


def curio_tide_compass(P):
    o = [P.shape(ell(64, 66, 44, 44), "bronze", s=4)]
    o.append(P.shape(ell(64, 66, 35, 35), "paper", s=2, lw=1.0))
    o.append(P.detail(" ".join(f"M{64+math.cos(a)*29:.1f},{66+math.sin(a)*29:.1f} L{64+math.cos(a)*34:.1f},{66+math.sin(a)*34:.1f}" for a in [i * math.pi / 8 for i in range(16)]), None, 0.6))
    o.append(P.detail("M40,66 Q52,58 64,66 T88,66 M44,78 Q54,72 64,78 T84,78", "blue", 1.0))
    o.append(P.shape(poly([(64, 38), (70, 66), (64, 70), (58, 66)]), "redp", s=1))
    o.append(P.shape(poly([(64, 94), (58, 66), (64, 62), (70, 66)]), "darkiron", s=1))
    o.append(P.shape(ell(64, 66, 4), "gold", s=0.6))
    o.append(P.shape(rect(58, 14, 12, 10, 3), "bronze", s=1))
    o.append(fill(ell(52, 52, 10, 6), "#ffffff", 0.3))
    return J(o), ""


def curio_songbird(P):
    o = []
    o.append(P.shape(rect(28, 98, 72, 10, 3), "wood", s=2))
    o.append(P.shape(rect(62, 70, 5, 30), "gold", s=0.8))
    o.append(P.shape(cap((40, 72), (94, 72), 3, 3), "gold", s=0.8))
    o.append(P.shape(poly([(44, 56), (24, 50), (28, 62)]), "gold", s=1))
    o.append(P.shape(ell(60, 56, 20, 13), "gold", s=3))
    o.append(P.shape(ell(80, 42, 11, 10), "gold", s=1.5))
    o.append(P.shape(poly([(89, 40), (100, 43), (89, 46)]), "bronze", s=0.5))
    o.append(fill(ell(83, 40, 2.2, 2.2), "#2a6a8a"))
    o.append(P.shape(smooth([(48, 50), (70, 44), (76, 56), (56, 62)], t=0.4), "bronze", s=1))
    o.append(P.detail("M52,54 l18,-4 M54,58 l16,-3", "bronze", 0.7))
    o.append(P.shape(rect(36, 60, 6, 10, 2) + " " + cap((33, 64), (45, 64), 2, 2), "silver", s=0.6))
    emit = J(fill(MI.sparkle(x, y, r), "#fff2c0", 0.9) for x, y, r in [(102, 26, 5), (110, 40, 3)])
    emit += lin("M100,18 q6,-4 4,-10 M108,30 q8,-2 8,-8", "#20140c", 1.0, 0.6)
    return J(o), emit


def curio_seer_glass(P):
    o = [P.shape(ell(60, 60, 38, 38), "pale", s=3)]
    o.append(P.shape(ell(60, 60, 29, 29), "obsidian", s=2, lw=1.0, opacity=0.95))
    o.append(P.shape(cap((86, 86), (112, 116), 7, 6), "pale", s=1.5))
    o.append(P.detail("M90,94 l6,-4 M96,102 l6,-4 M102,110 l6,-4", "pale", 0.7))
    o.append(fill(smooth([(44, 50), (52, 38), (62, 36), (50, 46)], t=0.4), "#ffffff", 0.5))
    emit = glow(P, 60, 64, 22, EMBER, 0.45) + fill(smooth([(56, 74), (60, 60), (64, 74), (60, 78)], t=0.4), EMBER_HOT, 0.8)
    return J(o), emit


def curio_star_chart(P):
    o = [P.shape(rect(18, 26, 92, 76, 4), "paper", s=4)]
    o.append(P.shape(cap((14, 26), (14, 102), 7, 7) + " " + cap((114, 26), (114, 102), 7, 7), "paper", s=2))
    rnd = random.Random(9)
    pts = [(rnd.uniform(28, 100), rnd.uniform(36, 92)) for _ in range(12)]
    o.append(P.detail(" ".join(f"M{a[0]:.1f},{a[1]:.1f} L{b[0]:.1f},{b[1]:.1f}" for a, b in zip(pts[:5], pts[1:6])), None, 0.7, 0.8))
    o.append(" ".join(fill(MI.sparkle(x, y, 3.2), INK, 0.9) for x, y in pts))
    o.append(P.detail("M30,94 l20,0 M80,40 l18,0 M78,46 l12,0", None, 0.6, 0.7))
    o.append(P.shape(ell(98, 86, 6), "redp", s=0.8))
    return J(o), ""


ITEM_ICONS = {f.__name__: f for f in [cutlass_seabronze, harpoon_barbed, buckler_seabronze, helm_brinecap, sabre_ripple,
                                      curio_tide_compass, curio_songbird, curio_seer_glass, curio_star_chart]}
COMP_ITEMS = {
    "comp_mouser_cat": "mouser_cat", "comp_pack_mule": "pack_mule", "comp_fell_pony": "fell_pony", "comp_war_hound": "war_hound",
    "comp_hunting_falcon": "hunting_falcon", "comp_moon_moth": "moon_moth", "comp_stone_toad": "stone_toad",
    "comp_glimmer_fox": "glimmer_fox", "comp_pocket_drake": "pocket_drake",
}


# ====================================================================== jobs
def icon_svg(body, emit):
    P = painter(scale=1.25, lw_mul=0.95)
    b, e = body(P)
    f = ink_filter(P, wob=1.4, dil=1.6, grain=0.5, soot=0.7)
    return svg_doc(64, 64, P, f'<g {f}>{b}</g><g>{e}</g>', ss=4, vw=128, vh=128)


def creature_icon(cid):
    fn, flying = CREATURES[cid]
    _, k, dx, dy = FIT[cid]

    def body(P):
        b, e = fn(P, 0)
        t = f'transform="translate({64 + dx},{64 + dy}) scale({k}) translate(-64,-64)"'
        return f"<g {t}>{b}</g>", f"<g {t}>{e}</g>"
    return icon_svg(body, None)


def mini_svg(cid):
    """128x64 sheet: two 64x64 cells (design 128 units each, drawn at 0.5)."""
    fn, flying = CREATURES[cid]
    k = FIT[cid][0]
    P = M.painter(dict(PAL), lw_mul=0.95)
    shadow, base = M.base(P, "animal", rx=40, ry=11, rim=6, seed=3)
    fb = ink_filter(P, wob=1.0, dil=0.9, grain=0.5, soot=0.4, seed=4)
    ff = ink_filter(P, wob=1.2, dil=1.2, grain=0.5, soot=0.5, seed=7)
    cells = []
    for fr in (0, 1):
        b, e = fn(P, fr)
        # base designed about (CX, FY) = (128, 192) in 256 units -> centre (64, 104) in our 128 units
        bt = 'transform="translate(64,104) translate(-128,-192)"'
        ct = f'transform="translate(64,{GROUND}) scale({k}) translate(-64,{-GROUND})"'
        stand_svg = ""
        if flying:
            stand_svg = f'<g {ct}>{flight_stand(P)}</g>'
        cells.append(f'<g transform="translate({fr * 128},0)"><g {bt}><g>{shadow}</g><g {fb}>{base}</g></g>'
                     f'<g {ff}>{stand_svg}<g {ct}>{b}</g></g><g {ct}>{e}</g></g>')
    return svg_doc(128, 64, P, f'<g transform="scale(0.5)">{"".join(cells)}</g>', ss=4, vw=128, vh=64)


def jobs(parts):
    js = []
    if "icons" in parts:
        for item, cid in COMP_ITEMS.items():
            js.append(dict(name=f"ic_{item}", svg=creature_icon(cid), w=64, h=64, ss=4, out=os.path.join(SPR, "icons", item + ".png")))
        for item, fn in ITEM_ICONS.items():
            js.append(dict(name=f"ic_{item}", svg=icon_svg(fn, None), w=64, h=64, ss=4, out=os.path.join(SPR, "icons", item + ".png")))
    if "minis" in parts:
        for cid in CREATURES:
            js.append(dict(name=f"cr_{cid}", svg=mini_svg(cid), w=128, h=64, ss=4, out=os.path.join(SPR, "creatures", cid + ".png")))
    return js


def contact():
    from PIL import Image, ImageDraw
    import artlib
    from contact import font
    fnt = font(13)
    names = list(COMP_ITEMS.items())
    cw, ch = 330, 150
    sheet = Image.new("RGBA", (3 * cw + 10, (len(names) + 2) // 3 * ch + 170), (220, 199, 154, 255))
    d = ImageDraw.Draw(sheet)
    for i, (item, cid) in enumerate(names):
        x0, y0 = 10 + (i % 3) * cw, 10 + (i // 3) * ch
        ic = Image.open(os.path.join(SPR, "icons", item + ".png")).convert("RGBA")
        sheet.alpha_composite(ic.resize((96, 96), Image.LANCZOS), (x0, y0 + 16))
        mi = Image.open(os.path.join(SPR, "creatures", cid + ".png")).convert("RGBA")
        sheet.alpha_composite(mi.resize((224, 112), Image.LANCZOS), (x0 + 100, y0 + 16))
        d.text((x0, y0), item, fill=(32, 20, 12, 255), font=fnt)
    y0 = 10 + (len(names) + 2) // 3 * ch
    for i, item in enumerate(ITEM_ICONS):
        ic = Image.open(os.path.join(SPR, "icons", item + ".png")).convert("RGBA")
        sheet.alpha_composite(ic.resize((96, 96), Image.LANCZOS), (10 + i * 108, y0 + 20))
        d.text((10 + i * 108, y0), item[:16], fill=(32, 20, 12, 255), font=fnt)
    p = os.path.join(OUT, "commerce_contact.png")
    sheet.save(p)
    print(p)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--contact" not in sys.argv:
        render(jobs(set(args) if args else {"icons", "minis"}))
    contact()
