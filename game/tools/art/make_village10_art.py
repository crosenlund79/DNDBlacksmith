"""Iteration 010 village art: hanging street signs with trade emblems, street lamps, the new venues (pawnshop, the
rival smith's forge, the Hales' cottage and menagerie, the caravan camp, the ceremony stage on the square), paddock
gates and grave plots. Straight top-down sprites in the ink-and-parchment 80/20 style (template_ files), same pipeline
as make_village_art.py. Prop ids and sizes come from game/data/props.json (tools/data/extra_village10.py).
python3 make_village10_art.py [--only=sign_inn,street_lamp]   (also writes out/sheet_village10*.png)"""
import math
import os
import random
import artlib  # noqa: F401  (sets sys.path)
from artlib import (painter, sprite_svg, svg_doc, soft_filter, ground_shadow, glow, lin, fill, planks, end_grain, liquid,
                    bottle_top, candle_top, coals, stones_ring, sigil_ring, render, load, only_filter, ell, rect, poly, smooth,
                    blob, wobbly_ell, ST, INK, EMBER, EMBER_HOT, RUB, GILT, SPR, VIOLET, VIOLET_HOT, blur_filter, hatch)
from make_props import tankard, book, barrel_top, crate_top, sack_top, sword_top, axe_top
from make_interiors import backboard, shelf_box, open_crate
import make_village_art  # noqa: F401  (palette roles: felt, olive, mud, reed ...)

PAL = ST["pal"]
PAL.setdefault("navy", ("#5a6e8e", "#2e3e58", "#18202e"))
PAL.setdefault("bottle", ("#7e9a6a", "#4e6a3e", "#28361e"))
PAL.setdefault("canvas", ("#f2e6c8", "#d8c49a", "#8a7650"))
PAL.setdefault("burgundy", ("#a8584a", "#6e2a22", "#3a1410"))
PAL.setdefault("hen", ("#e8d2a8", "#b88a56", "#6a4826"))


def J(o):
    return "\n".join(x for x in o if x)


def sh_(P, d, dx=4, dy=5, **k):
    return ground_shadow(P, d, dx, dy, **k)


DECALS = set()


def decal(fn):
    DECALS.add(fn.__name__)
    return fn


# ================================================================ hanging signs
# 80 x 48: a wrought bracket bar across the top (it juts from the wall), two short chains, the board below.
BOARDS = {"wood": None, "navy": "#2e3e58", "burgundy": "#6a2a22", "green": "#3a5236", "black": "#2a2420", "ochre": "#8a6a32"}


def _board(P, shape, role):
    """The sign board (centre 40, 29). Returns (shadow path, svg)."""
    fo = BOARDS.get(role)
    if shape == "shield":
        d = smooth([(16, 15), (64, 15), (63, 30), (54, 40), (40, 45), (26, 40), (17, 30)], t=0.35)
    elif shape == "oval":
        d = ell(40, 29, 25, 15)
    elif shape == "none":
        return "", ""
    else:
        d = rect(13, 15, 54, 28, 3)
    o = [P.shape(d, "wood", s=3, fill_override=fo)]
    if shape == "rect":
        o.append(lin(rect(16, 18, 48, 22, 2), GILT, 0.9, 0.8))
    elif shape == "oval":
        o.append(lin(ell(40, 29, 21.5, 12), GILT, 0.9, 0.8))
    else:
        o.append(lin(smooth([(19, 18), (61, 18), (60, 30), (52, 38), (40, 42), (28, 38), (20, 30)], t=0.35), GILT, 0.9, 0.8))
    return d, J(o)


def hanging_sign(P, emblem, shape="rect", role="wood", chains=True):
    """Bracket + chains + board + emblem (emblem(P, cx, cy) -> (body, emit))."""
    bd, board = _board(P, shape, role)
    sh = sh_(P, rect(6, 4, 66, 7) + (" " + bd if bd else ""), 5, 6, op=0.45)
    b = [P.shape(rect(4, 4, 72, 6, 2), "darkiron", s=1, lw=1.6),
         P.shape(ell(6, 7, 4.2), "darkiron", s=0.6, lw=1.2),
         P.detail("M10,10 Q20,22 30,10 M70,10 Q60,22 50,10", "darkiron", 1.0),
         lin("M74,7 q4,-3 2,-6 q-3,-1 -3,2", PAL["darkiron"][1], 1.4)]
    if chains:
        b.append(lin("M22,10 L22,16 M58,10 L58,16", INK, 1.4))
        b.append(lin("M22,11 L22,15 M58,11 L58,15", PAL["metal"][0], 0.5, 0.7))
    b.append(board)
    eb, ee = emblem(P, 40, 29)
    b.append(eb)
    return sh, J(b), ee


def em_smithy(P, cx, cy):
    an = [(cx - 15, cy - 1), (cx + 11, cy - 1), (cx + 15, cy + 2), (cx + 6, cy + 3), (cx + 5, cy + 7), (cx + 9, cy + 10),
          (cx - 9, cy + 10), (cx - 5, cy + 7), (cx - 6, cy + 3), (cx - 16, cy + 1)]
    b = [P.shape(poly(an), "darkiron", s=1, lw=1.3), lin(f"M{cx-13},{cy} L{cx+10},{cy}", PAL["metal"][0], 0.7, 0.8)]
    # hammer raised over the anvil
    b.append(P.shape(f"M{cx-2},{cy-4} L{cx+12},{cy-14} L{cx+14},{cy-12} L{cx},{cy-2} Z", "wood", s=0.6, lw=1.0))
    b.append(P.shape(f"M{cx+6},{cy-17} L{cx+14},{cy-9} L{cx+18},{cy-13} L{cx+10},{cy-21} Z", "darkiron", s=0.8, lw=1.1))
    e = J([fill(ell(cx - 6, cy - 3, 1.4), EMBER_HOT, 0.9), fill(ell(cx - 10, cy - 6, 1.0), EMBER, 0.9), fill(ell(cx - 2, cy - 7, 0.9), EMBER, 0.8)])
    return J(b), e


def em_inn(P, cx, cy):
    b = [P.shape(rect(cx - 9, cy - 9, 16, 19, 2.5), "pewter", s=1, lw=1.3),
         P.shape(f"M{cx+7},{cy-5} q8,0 8,6 q0,6 -8,6", "pewter", s=0.4, lw=1.2, fill_override="none"),
         lin(f"M{cx+7},{cy-5} q8,0 8,6 q0,6 -8,6", INK, 2.6), lin(f"M{cx+7},{cy-5} q8,0 8,6 q0,6 -8,6", PAL["pewter"][0], 1.2),
         P.shape(smooth([(cx - 11, cy - 8), (cx - 7, cy - 14), (cx - 1, cy - 12), (cx + 4, cy - 15), (cx + 9, cy - 9), (cx + 3, cy - 7), (cx - 5, cy - 6)]),
                 "linen", s=0.8, lw=1.0, fill_override="#f4ecd4"),
         lin(f"M{cx-9},{cy-2} h16 M{cx-9},{cy+5} h16", INK, 0.6, 0.6),
         fill(ell(cx - 5, cy + 1, 1.6, 3.6), "#ffffff", 0.35)]
    return J(b), ""


def em_grocer(P, cx, cy):
    b = [lin(" ".join(f"M{cx-6},{cy+11} L{cx-12+i*2.6:.1f},{cy-9}" for i in range(5)), PAL["straw"][2], 1.8),
         lin(" ".join(f"M{cx-6},{cy+11} L{cx-12+i*2.6:.1f},{cy-9}" for i in range(5)), PAL["straw"][0], 0.8),
         fill(" ".join(ell(cx - 12 + i * 2.6, cy - 9, 1.5, 2.8) for i in range(5)), PAL["straw"][1]),
         lin(" ".join(ell(cx - 12 + i * 2.6, cy - 9, 1.5, 2.8) for i in range(5)), INK, 0.5, 0.7),
         lin(f"M{cx-11},{cy+3} h9", RUB, 1.4),
         P.shape(ell(cx + 9, cy + 3, 7), "apple", s=1, lw=1.2),
         lin(f"M{cx+9},{cy-3} q1,-3 3,-4", PAL["wood"][2], 1.0),
         P.shape(ell(cx + 13, cy - 5, 2.6, 1.3), "green", s=0.3, lw=0.6),
         fill(ell(cx + 6.5, cy + 0.5, 1.6, 1.0), "#ffffff", 0.5)]
    return J(b), ""


def em_herbalist(P, cx, cy):
    b = []
    # sprigs fanning out of the mortar
    for i, a in enumerate((-50, -25, 0, 25, 50)):
        r = math.radians(a - 90)
        x2, y2 = cx + math.cos(r) * 16, cy + 2 + math.sin(r) * 16
        b.append(lin(f"M{cx},{cy+2} L{x2:.1f},{y2:.1f}", PAL["green"][2], 1.1))
        for k in (0.45, 0.7, 0.95):
            lx, ly = cx + (x2 - cx) * k, cy + 2 + (y2 - cy - 2) * k
            b.append(P.shape(ell(lx + 2.2, ly, 2.4, 1.2), "green", s=0.3, lw=0.5, fill_override=["#6e8a4a", "#8aa060", "#5e7a3e"][(i + int(k * 10)) % 3]))
    b.append(P.shape(f"M{cx-11},{cy+1} L{cx+11},{cy+1} Q{cx+10},{cy+12} {cx},{cy+12} Q{cx-10},{cy+12} {cx-11},{cy+1} Z", "stone", s=1.2, lw=1.2))
    b.append(P.shape(ell(cx, cy + 1, 11, 2.6), "darkstone", s=0.4, lw=1.0))
    b.append(P.shape(f"M{cx+4},{cy} L{cx+14},{cy-9} L{cx+16},{cy-7} L{cx+6},{cy+2} Z", "wood", s=0.5, lw=1.0))
    return J(b), ""


def em_chapel(P, cx, cy):
    rays = " ".join(f"M{cx + math.cos(a) * 8.5:.1f},{cy - 1 + math.sin(a) * 8.5:.1f} L{cx + math.cos(a) * (13 if i % 2 else 11):.1f},"
                    f"{cy - 1 + math.sin(a) * (13 if i % 2 else 11):.1f}" for i, a in enumerate([k * math.tau / 16 for k in range(16)]))
    b = [lin(rays, INK, 2.6), lin(rays, PAL["gold"][0], 1.2),
         P.shape(ell(cx, cy - 1, 8), "gold", s=1, lw=1.2),
         lin(f"M{cx-3},{cy-3} a1.2,1 0 1,1 0.1,0 M{cx+3},{cy-3} a1.2,1 0 1,1 0.1,0 M{cx-3},{cy+2} q3,2 6,0", INK, 0.7, 0.8)]
    return J(b), J([glow(P, cx, cy - 1, 15, EMBER_HOT, 0.25)])


def em_barnaby(P, cx, cy):
    # a tiny tank in profile: tracks, hull, turret, long barrel
    b = [P.shape(rect(cx - 15, cy + 3, 28, 7, 3.5), "darkiron", s=0.8, lw=1.2),
         fill(" ".join(ell(cx - 11 + i * 5.5, cy + 6.5, 2, 2) for i in range(5)), PAL["metal"][1]),
         lin(" ".join(ell(cx - 11 + i * 5.5, cy + 6.5, 2, 2) for i in range(5)), INK, 0.6),
         P.shape(poly([(cx - 14, cy + 3), (cx - 11, cy - 2), (cx + 10, cy - 2), (cx + 14, cy + 3)]), "olive", s=0.9, lw=1.2),
         P.shape(smooth([(cx - 7, cy - 2), (cx - 5, cy - 8), (cx + 4, cy - 8), (cx + 6, cy - 2)], t=0.4), "olive", s=0.8, lw=1.2),
         P.shape(rect(cx + 5, cy - 6.5, 15, 2.6, 1), "darkiron", s=0.3, lw=0.9),
         fill(ell(cx - 1, cy - 5, 1.6, 1.0), "#f2ead2", 0.8)]
    return J(b), ""


def em_cooper(P, cx, cy):
    d = f"M{cx-9},{cy-11} Q{cx-13},{cy} {cx-9},{cy+11} L{cx+9},{cy+11} Q{cx+13},{cy} {cx+9},{cy-11} Z"
    b = [P.shape(d, "wood", s=1.4, lw=1.3),
         P.detail(f"M{cx-4},{cy-11} Q{cx-6},{cy} {cx-4},{cy+11} M{cx+4},{cy-11} Q{cx+6},{cy} {cx+4},{cy+11} M{cx},{cy-11} L{cx},{cy+11}", "wood", 0.4, 0.7),
         lin(f"M{cx-10.5},{cy-6} L{cx+10.5},{cy-6} M{cx-11.5},{cy+5} L{cx+11.5},{cy+5}", INK, 2.6),
         lin(f"M{cx-10.5},{cy-6} L{cx+10.5},{cy-6} M{cx-11.5},{cy+5} L{cx+11.5},{cy+5}", PAL["darkiron"][0], 1.0)]
    return J(b), ""


def em_stable(P, cx, cy):
    d = (f"M{cx-10},{cy+10} L{cx-12},{cy-1} Q{cx-12},{cy-13} {cx},{cy-13} Q{cx+12},{cy-13} {cx+12},{cy-1} L{cx+10},{cy+10} "
         f"L{cx+5},{cy+10} L{cx+6},{cy-1} Q{cx+6},{cy-7} {cx},{cy-7} Q{cx-6},{cy-7} {cx-6},{cy-1} L{cx-5},{cy+10} Z")
    b = [P.shape(d, "darkiron", s=1, lw=1.3),
         fill(" ".join(ell(x, y, 0.9) for x, y in [(cx - 9.5, cy + 5), (cx - 10, cy - 1), (cx - 8, cy - 7), (cx + 9.5, cy + 5),
                                                   (cx + 10, cy - 1), (cx + 8, cy - 7)]), "#f2ead2", 0.85),
         lin(f"M{cx-9},{cy-9} q9,-4 18,0", PAL["metal"][0], 0.8, 0.7)]
    return J(b), ""


def em_chandler(P, cx, cy):
    b = [P.shape(rect(cx - 4.5, cy - 6, 9, 17, 2), "wax", s=0.8, lw=1.1, fill_override="#f2e6c4"),
         lin(f"M{cx-4.5},{cy-3} q2,2 1,5", "#d8c49a", 1.2, 0.9),
         lin(f"M{cx},{cy-6} L{cx},{cy-9}", INK, 0.8),
         P.shape(ell(cx, cy + 11, 9, 2.4), "bronze", s=0.5, lw=1.0)]
    e = J([glow(P, cx, cy - 12, 10, EMBER_HOT, 0.55),
           fill(smooth([(cx, cy - 18), (cx + 2.4, cy - 11.5), (cx, cy - 9.2), (cx - 2.4, cy - 11.5)]), "#ffe2a0", 0.95),
           fill(smooth([(cx, cy - 15), (cx + 1.1, cy - 11.5), (cx, cy - 10.4), (cx - 1.1, cy - 11.5)]), "#ffffff", 0.8)])
    return J(b), e


def em_netloft(P, cx, cy):
    d = smooth([(cx - 13, cy), (cx - 6, cy - 6), (cx + 5, cy - 5), (cx + 11, cy), (cx + 5, cy + 5), (cx - 6, cy + 6)], t=0.45)
    b = [P.shape(f"M{cx+10},{cy} L{cx+17},{cy-6} L{cx+16},{cy} L{cx+17},{cy+6} Z", "navy", s=0.6, lw=1.0, fill_override="#7e94aa"),
         P.shape(d, "navy", s=1.2, lw=1.2, fill_override="#9ab0c4"),
         fill(ell(cx - 8, cy - 1, 1.3), INK), P.detail(f"M{cx-4},{cy-4} q2,4 0,8 M{cx},{cy-4.5} q2,4.5 0,9 M{cx+4},{cy-4} q2,4 0,8", "navy", 0.4, 0.6),
         lin(f"M{cx-12},{cy+1} q2,1 3,0", INK, 0.6)]
    # a knot of net behind
    b.insert(0, lin(" ".join(f"M{cx-16+i*5},{cy-12} L{cx-10+i*5},{cy+12}" for i in range(6)) + " " +
                    " ".join(f"M{cx+12-i*5},{cy-12} L{cx+6-i*5},{cy+12}" for i in range(6)), PAL["burlap"][1], 0.6, 0.6))
    return J(b), ""


def em_carpenter(P, cx, cy):
    blade = poly([(cx - 14, cy - 3), (cx + 8, cy - 7), (cx + 8, cy + 3), (cx - 14, cy + 2)])
    teeth = " ".join(f"M{cx-13+i*2.2:.1f},{cy+2-i*0.05:.1f} l1.1,1.6 l1.1,-1.6" for i in range(10))
    b = [P.shape(blade, "metal", s=0.8, lw=1.1), lin(teeth, INK, 0.6),
         P.shape(smooth([(cx + 7, cy - 9), (cx + 16, cy - 9), (cx + 17, cy + 6), (cx + 7, cy + 5)], t=0.3), "wood", s=1, lw=1.2),
         fill(ell(cx + 12, cy - 2, 2.2, 3.4), BOARDS["burgundy"]),
         lin(f"M{cx-9},{cy-1} h12", PAL["metal"][0], 0.6, 0.7)]
    return J(b), ""


def em_farm(P, cx, cy):
    b = [lin(f"M{cx-12},{cy+12} L{cx+6},{cy-6}", INK, 3.2), lin(f"M{cx-12},{cy+12} L{cx+6},{cy-6}", PAL["wood"][0], 1.6)]
    tines = " ".join(f"M{cx+3+i*2.2:.1f},{cy-3+i*2.2:.1f} l{8-i:.1f},{-8+i:.1f}" for i in range(-1, 2))
    b += [lin(f"M{cx+1},{cy-8} L{cx+11},{cy+2}", INK, 2.6), lin(tines, INK, 2.2), lin(tines, PAL["metal"][0], 0.9),
          lin(" ".join(f"M{cx-6},{cy+12} L{cx-13+i*2.4:.1f},{cy-6}" for i in range(4)), PAL["straw"][2], 1.6),
          fill(" ".join(ell(cx - 13 + i * 2.4, cy - 6, 1.3, 2.6) for i in range(4)), PAL["straw"][1]),
          lin(f"M{cx-12},{cy+5} h7", RUB, 1.2)]
    return J(b), ""


def em_laundry(P, cx, cy):
    shirt = poly([(cx - 5, cy - 10), (cx - 12, cy - 6), (cx - 9, cy - 1), (cx - 6, cy - 3), (cx - 6, cy + 10), (cx + 6, cy + 10),
                  (cx + 6, cy - 3), (cx + 9, cy - 1), (cx + 12, cy - 6), (cx + 5, cy - 10), (cx, cy - 7)])
    b = [lin(f"M{cx-18},{cy-11} Q{cx},{cy-8} {cx+18},{cy-11}", PAL["burlap"][2], 0.9),
         P.shape(shirt, "linen", s=1, lw=1.1, fill_override="#f2ecdc"),
         lin(f"M{cx-4},{cy-11} v3 M{cx+4},{cy-11} v3", PAL["wood"][1], 1.6),
         fill(" ".join(ell(cx + 12 + i * 2, cy + 6 - i * 4, 1.6 - i * 0.3) for i in range(3)), "#dce8f0", 0.9),
         lin(" ".join(ell(cx + 12 + i * 2, cy + 6 - i * 4, 1.6 - i * 0.3) for i in range(3)), INK, 0.4, 0.7)]
    return J(b), ""


def em_flower(P, cx, cy):
    b = [lin(f"M{cx},{cy+2} q-2,7 1,11", PAL["green"][2], 1.2),
         P.shape(ell(cx - 5, cy + 8, 3.2, 1.5), "green", s=0.3, lw=0.6)]
    for k in range(5):
        a = k * math.tau / 5 - math.pi / 2
        b.append(P.shape(ell(cx + math.cos(a) * 4.6, cy - 2 + math.sin(a) * 4.6, 3.4), "apple", s=0.5, lw=0.8, fill_override="#c86a5a"))
    b.append(P.shape(ell(cx, cy - 2, 2.6), "gold", s=0.4, lw=0.7))
    return J(b), ""


def em_house(P, cx, cy):
    b = [P.shape(poly([(cx - 11, cy - 1), (cx, cy - 11), (cx + 11, cy - 1)]), "roof_a", s=0.8, lw=1.2),
         P.shape(rect(cx - 8, cy - 1, 16, 11, 1), "stone", s=0.8, lw=1.2, fill_override="#e8dcc0"),
         P.shape(rect(cx - 2, cy + 3, 4, 7, 1), "wood", s=0.3, lw=0.8),
         fill(rect(cx + 3.5, cy + 1.5, 3, 3), EMBER_HOT, 0.9), lin(rect(cx + 3.5, cy + 1.5, 3, 3), INK, 0.6),
         P.shape(rect(cx + 5, cy - 9, 3, 5, 0.5), "stone", s=0.3, lw=0.8)]
    return J(b), ""


def em_rival(P, cx, cy):
    b = []
    for sd in (-1, 1):
        b.append(f'<g transform="rotate({sd*38} {cx} {cy+2})">' +
                 P.shape(rect(cx - 1.4, cy - 8, 2.8, 20, 1), "wood", s=0.4, lw=0.9) +
                 P.shape(rect(cx - 6, cy - 12, 12, 6, 1.2), "darkiron", s=0.6, lw=1.1) + "</g>")
    e = J([glow(P, cx, cy + 9, 9, EMBER, 0.5),
           fill(smooth([(cx, cy + 1), (cx + 4, cy + 7), (cx + 2.5, cy + 12), (cx - 2.5, cy + 12), (cx - 4, cy + 7)]), EMBER, 0.95),
           fill(smooth([(cx, cy + 5), (cx + 2, cy + 9), (cx, cy + 12), (cx - 2, cy + 9)]), EMBER_HOT, 0.95)])
    return J(b), e


def em_menagerie(P, cx, cy):
    b = [P.shape(ell(cx - 4, cy + 4, 5.5, 4.6), "hide", s=0.6, lw=1.0, fill_override="#4a3424")]
    for (dx, dy) in ((-10, -2), (-6, -7.5), (0, -7.5), (3, -2)):
        b.append(P.shape(ell(cx - 4 + dx * 0.9 + 3, cy + dy, 2.3, 2.6), "hide", s=0.4, lw=0.9, fill_override="#4a3424"))
    feather = smooth([(cx + 7, cy + 12), (cx + 9, cy - 2), (cx + 14, cy - 12), (cx + 16, cy - 4), (cx + 12, cy + 6)], t=0.4)
    b += [P.shape(feather, "cloth", s=0.5, lw=1.0, fill_override="#4e7a8a"),
          lin(f"M{cx+7},{cy+12} Q{cx+11},{cy} {cx+15},{cy-11}", "#f2ead2", 0.7, 0.9),
          lin(" ".join(f"M{cx+9+i*1.3:.1f},{cy+4-i*4:.1f} l3,-1.5" for i in range(4)), INK, 0.4, 0.6)]
    return J(b), J([fill(ell(cx + 13.5, cy - 7, 1.4), GILT, 0.9)])


def em_anchor(P, cx, cy):
    d = f"M{cx},{cy-10} L{cx},{cy+9} M{cx-11},{cy+2} Q{cx-10},{cy+11} {cx},{cy+11} Q{cx+10},{cy+11} {cx+11},{cy+2} M{cx-6},{cy-6} L{cx+6},{cy-6}"
    b = [lin(d, INK, 4.2), lin(d, PAL["gold"][0], 1.8), P.shape(ell(cx, cy - 12, 3), "gold", s=0.4, lw=1.0, fill_override="none"),
         lin(ell(cx, cy - 12.5, 2.6), INK, 2.4), lin(ell(cx, cy - 12.5, 2.6), PAL["gold"][0], 1.0),
         lin(f"M{cx-13},{cy+4} l2,-4 l2,4 M{cx+13},{cy+4} l-2,-4 l-2,4", PAL["gold"][0], 1.2)]
    return J(b), ""


def sign_smithy(P, W, H):
    return hanging_sign(P, em_smithy, "rect", "wood")


def sign_inn(P, W, H):
    return hanging_sign(P, em_inn, "shield", "burgundy")


def sign_grocer(P, W, H):
    return hanging_sign(P, em_grocer, "rect", "green")


def sign_herbalist(P, W, H):
    return hanging_sign(P, em_herbalist, "oval", "wood")


def sign_chapel(P, W, H):
    return hanging_sign(P, em_chapel, "shield", "navy")


def sign_barnaby(P, W, H):
    return hanging_sign(P, em_barnaby, "rect", "ochre")


def sign_cooper(P, W, H):
    return hanging_sign(P, em_cooper, "oval", "green")


def sign_stable(P, W, H):
    return hanging_sign(P, em_stable, "rect", "wood")


def sign_chandler(P, W, H):
    return hanging_sign(P, em_chandler, "shield", "black")


def sign_netloft(P, W, H):
    return hanging_sign(P, em_netloft, "oval", "wood")


def sign_carpenter(P, W, H):
    return hanging_sign(P, em_carpenter, "rect", "wood")


def sign_farm(P, W, H):
    return hanging_sign(P, em_farm, "rect", "ochre")


def sign_laundry(P, W, H):
    return hanging_sign(P, em_laundry, "oval", "navy")


def sign_cottage_a(P, W, H):
    return hanging_sign(P, em_flower, "oval", "green")


def sign_cottage_b(P, W, H):
    return hanging_sign(P, em_house, "oval", "wood")


def sign_rival(P, W, H):
    return hanging_sign(P, em_rival, "shield", "black")


def sign_menagerie(P, W, H):
    return hanging_sign(P, em_menagerie, "rect", "green")


def sign_harbour(P, W, H):
    return hanging_sign(P, em_anchor, "rect", "navy")


def sign_pawn(P, W, H):
    """The pawnbroker's three gilt balls hanging from the bracket (no board)."""
    sh = sh_(P, rect(6, 4, 66, 7) + " " + ell(28, 30, 7) + " " + ell(52, 30, 7) + " " + ell(40, 40, 7), 5, 6, op=0.45)
    b = [P.shape(rect(4, 4, 72, 6, 2), "darkiron", s=1, lw=1.6), P.shape(ell(6, 7, 4.2), "darkiron", s=0.6, lw=1.2),
         P.detail("M10,10 Q20,22 30,10 M70,10 Q60,22 50,10", "darkiron", 1.0),
         lin("M40,10 L40,16 M40,16 L28,22 M40,16 L52,22 M40,16 L40,32", INK, 1.6),
         lin("M40,10 L40,16 M40,16 L28,22 M40,16 L52,22 M40,16 L40,32", PAL["gold"][1], 0.6, 0.8)]
    for x, y in ((28, 29), (52, 29), (40, 39)):
        b.append(P.shape(ell(x, y, 7.5), "gold", s=1.6, lw=1.3))
        b.append(fill(ell(x - 2.4, y - 2.6, 2.2, 1.6), "#fff6d0", 0.75))
    return sh, J(b), ""


# ================================================================ street lamp (three-quarter miniature view)
def street_lamp(P, W, H):
    """An iron lamp post on a stone foot, seen like the miniatures: the foot at (32, 116), the post rising to a
    hanging lantern on a scrolled arm. The lit glass is a separate sprite (street_lamp_glow)."""
    cx, fy = 30, 116
    sh = J([fill(f"M{cx-8},{fy} L{cx+22},{fy+8} L{cx+30},{fy+4} L{cx+4},{fy-4} Z", INK, 0.22, blur_filter(P, 2.5)),
            sh_(P, ell(cx, fy, 12, 5), 3, 3)])
    b = [P.shape(ell(cx, fy, 12, 5.5), "stone", s=1.4, lw=1.4),
         P.shape(rect(cx - 7, fy - 12, 14, 12, 2), "stone", s=1.2, lw=1.3),
         P.shape(ell(cx, fy - 12, 7, 2.6), "stone", s=0.5, lw=1.0),
         P.shape(rect(cx - 3.2, 30, 6.4, fy - 42, 2), "darkiron", s=1.2, lw=1.4),
         P.detail(f"M{cx-1},{40} L{cx-1},{fy-16}", "darkiron", 0.4, 0.6),
         P.shape(rect(cx - 5, fy - 26, 10, 5, 1.5), "darkiron", s=0.6, lw=1.1),
         P.shape(rect(cx - 5, 44, 10, 4, 1.5), "darkiron", s=0.6, lw=1.1),
         # the arm: a scroll from the post top out to the right, the lantern hangs from its end
         lin(f"M{cx},32 Q{cx+10},22 {cx+24},24 M{cx+2},40 Q{cx+8},30 {cx+16},28 q4,-1 3,3", INK, 3.0),
         lin(f"M{cx},32 Q{cx+10},22 {cx+24},24 M{cx+2},40 Q{cx+8},30 {cx+16},28 q4,-1 3,3", PAL["darkiron"][0], 1.0),
         P.shape(ell(cx, 30, 4.4), "darkiron", s=0.6, lw=1.1),
         P.shape(f"M{cx},22 l2.6,6 l-5.2,0 Z", "darkiron", s=0.3, lw=0.9),
         lin(f"M{cx+24},24 L{cx+24},30", INK, 1.2)]
    lx, ly = cx + 24, 40
    lantern = [P.shape(poly([(lx - 6, ly - 9), (lx + 6, ly - 9), (lx + 8, ly + 5), (lx + 4, ly + 10), (lx - 4, ly + 10), (lx - 8, ly + 5)]),
                       "glass", s=0.8, lw=1.2, fill_override="#e8d4a0"),
               P.shape(poly([(lx - 8, ly - 9), (lx, ly - 15), (lx + 8, ly - 9)]), "darkiron", s=0.6, lw=1.2),
               P.shape(rect(lx - 6, ly + 9, 12, 3.5, 1), "darkiron", s=0.4, lw=1.0),
               lin(f"M{lx},{ly-9} L{lx},{ly+10} M{lx-6},{ly-9} L{lx-8},{ly+5} M{lx+6},{ly-9} L{lx+8},{ly+5}", INK, 0.9),
               fill(ell(lx, ly + 2, 2.4, 4), "#c8a060", 0.7), fill(ell(lx - 3, ly - 3, 1.2, 3), "#ffffff", 0.5)]
    b += lantern
    return sh, J(b), ""


def street_lamp_glow(P, W, H):
    """Night overlay for street_lamp: lit glass panes and a warm halo (shown only after dusk)."""
    lx, ly = 54, 40
    e = [glow(P, lx, ly + 2, 30, EMBER_HOT, 0.55), glow(P, lx, ly + 2, 14, "#fff0c0", 0.7),
         fill(poly([(lx - 5, ly - 8), (lx + 5, ly - 8), (lx + 7, ly + 5), (lx + 3.6, ly + 9), (lx - 3.6, ly + 9), (lx - 7, ly + 5)]), "#ffe2a0", 0.95),
         lin(f"M{lx},{ly-8} L{lx},{ly+9} M{lx-5},{ly-8} L{lx-7},{ly+5} M{lx+5},{ly-8} L{lx+7},{ly+5}", "#5a3a1a", 0.9, 0.8),
         fill(smooth([(lx, ly - 4), (lx + 2.4, ly + 2), (lx, ly + 5), (lx - 2.4, ly + 2)]), "#ffffff", 0.9)]
    return "", "", J(e)


# ================================================================ pawnshop
def pawn_counter(P, W, H):
    sh = sh_(P, rect(4, 6, W - 8, H - 12, 3))
    b = [planks(P, 4, 6, W - 8, H - 12, "wood", n=2, dirn="h", s=3, seed=31),
         P.shape(rect(4, 6, W - 8, 7, 2), "wood", s=1, lw=1.4, fill_override="#5a3a22"),
         lin(rect(4, 6, W - 8, H - 12, 3), INK, 2.2)]
    # brass scales: beam, two pans, the pillar
    sx, sy = 44, 30
    b += [P.shape(ell(sx, sy, 5), "bronze", s=0.8, lw=1.1), lin(f"M{sx-18},{sy-3} L{sx+18},{sy-3}", INK, 2.4),
          lin(f"M{sx-18},{sy-3} L{sx+18},{sy-3}", PAL["gold"][0], 1.0),
          P.shape(ell(sx - 18, sy + 1, 7, 4.5), "bronze", s=0.8, lw=1.0), P.shape(ell(sx + 18, sy + 1, 7, 4.5), "bronze", s=0.8, lw=1.0),
          fill(ell(sx - 18, sy + 1, 2.5), PAL["gold"][1]), fill(ell(sx + 16, sy, 1.6) + " " + ell(sx + 20, sy + 2, 1.6), PAL["metal"][0])]
    # a pocket watch, a ring box, a tagged parcel, a candlestick, a ledger
    b += [P.shape(ell(84, 30, 6), "gold", s=0.8, lw=1.0), fill(ell(84, 30, 4.4), "#f2ead2"), lin(f"M84,30 l0,-3 M84,30 l2,1", INK, 0.6),
          lin("M84,24 q-6,-6 -12,-2", PAL["gold"][1], 0.8),
          P.shape(rect(98, 22, 12, 10, 2), "cloth", s=0.6, lw=1.0, fill_override="#4a2a3a"), fill(ell(104, 27, 2), PAL["gold"][0]),
          P.shape(rect(118, 18, 24, 18, 1.5), "burlap", s=1, lw=1.1), lin("M118,27 h24 M130,18 v18", PAL["burlap"][2], 1.0),
          P.shape(rect(138, 30, 8, 6, 1), "paper", s=0.3, lw=0.7), lin("M138,31 l-4,-3", INK, 0.5),
          book(P, 152, 16, 30, 20, "leather", open_=True)]
    return sh, J(b), ""


def curio_shelf(P, W, H):
    sh = sh_(P, rect(2, 2, W - 4, H - 6, 2), 3, 4)
    b = [shelf_box(P, 2, 2, W - 4, H - 6, "wood")]
    # stuffed owl, a brass globe, bottles, a dented helm, a clock, a lute neck, price tags
    b += [P.shape(ell(16, 18, 8, 7), "hide", s=1, lw=1.0, fill_override="#8a6a46"), fill(ell(13, 16, 1.6) + " " + ell(19, 16, 1.6), GILT),
          P.shape(ell(34, 18, 8), "bronze", s=1, lw=1.0), lin(f"M26,18 h16 M34,10 v16", INK, 0.5, 0.7),
          bottle_top(P, 50, 14, 4, "brew"), bottle_top(P, 52, 24, 3.6, "wine"),
          P.shape(ell(68, 18, 9, 8), "metal", s=1.2, lw=1.1), lin("M60,18 h16", INK, 0.8), fill(rect(66, 12, 4, 4), INK, 0.6),
          P.shape(rect(84, 9, 14, 18, 2), "wood", s=0.8, lw=1.0), P.shape(ell(91, 16, 5), "paper", s=0.3, lw=0.8),
          lin("M91,16 l0,-3 M91,16 l2,1", INK, 0.6),
          P.shape(rect(104, 12, 18, 6, 2), "wood", s=0.5, lw=0.9), fill(ell(118, 15, 3.6), PAL["wood"][1])]
    b.append(fill(" ".join(rect(x, 28, 5, 4, 0.5) for x in (14, 32, 66, 88, 110)), "#f2ead2", 0.9))
    b.append(lin(" ".join(f"M{x+2.5},28 l0,-3" for x in (14, 32, 66, 88, 110)), RUB, 0.5))
    return sh, J(b), ""


def display_case(P, W, H):
    sh = sh_(P, rect(4, 4, W - 8, H - 8, 2))
    b = [P.shape(rect(4, 4, W - 8, H - 8, 2), "wood", s=2.4, fill_override="#5a3a22"),
         P.shape(rect(10, 10, W - 20, H - 20, 1), "cloth", s=-1, hl=False, lw=1.0, fill_override="#4a2230")]
    rnd = random.Random(7)
    for i in range(7):
        x, y = 16 + (i % 4) * 18 + rnd.uniform(-2, 2), 18 + (i // 4) * 16
        if i % 3 == 0:
            b.append(lin(ell(x, y, 3.4), PAL["gold"][0], 1.3))
            b.append(fill(ell(x, y - 3.4, 1.4), "#a8d0e8"))
        elif i % 3 == 1:
            b.append(lin(f"M{x-5},{y-3} Q{x},{y+5} {x+5},{y-3}", PAL["silver"][0] if "silver" in PAL else "#e4e8ec", 0.9))
            b.append(fill(ell(x, y + 1.5, 1.8), "#c84a4a"))
        else:
            b.append(P.shape(ell(x, y, 3.6), "gold", s=0.5, lw=0.8))
    b.append(fill(rect(10, 10, W - 20, H - 20, 1), "#dfeef6", 0.18))
    b.append(lin(f"M14,12 L30,{H-12} M40,12 L56,{H-12}", "#ffffff", 1.2, 0.35))
    b.append(lin(rect(10, 10, W - 20, H - 20, 1), INK, 1.2))
    return sh, J(b), ""


# ================================================================ the rival smith's forge
def rival_forge(P, W, H):
    sh = sh_(P, rect(6, 4, W - 12, H - 10, 4), 5, 6)
    b = [P.shape(rect(6, 4, W - 12, H - 10, 4), "stone", s=4),
         P.detail(" ".join(f"M6,{y} L{W-6},{y}" for y in (26, 48, 70)) + " " +
                  " ".join(f"M{x},{y0} L{x},{y0+22}" for y0, xs in ((4, (36, 72, 104)), (26, (22, 56, 90)), (48, (36, 72, 104)), (70, (22, 56, 90))) for x in xs),
                  "stone", 0.5, 0.6),
         P.shape(rect(24, 18, W - 48, H - 38, 3), "darkstone", s=2, hl=False)]
    cb, ce = coals(P, W / 2, H / 2 - 2, W / 2 - 30, H / 2 - 24, seed=17, hot=0.85)
    b.append(cb)
    # hood lip on the north side, bellows to the east
    b += [P.shape(rect(14, 2, W - 28, 10, 2), "darkiron", s=1, lw=1.4),
          P.shape(smooth([(W - 18, 52), (W - 2, 46), (W + 0, 70), (W - 18, 72)], t=0.3), "leather", s=1.5, lw=1.2),
          lin(f"M{W-18},60 L{W-28},58", INK, 2.0)]
    return sh, J(b), ce


def rival_anvil(P, W, H):
    cx, cy = W / 2, H / 2
    sh = sh_(P, ell(cx, cy + 2, 26, 16), 4, 5)
    b = [end_grain(P, cx, cy + 2, 18, "wood", seed=5)]
    horn = [(cx - 34, cy - 1), (cx - 18, cy - 6), (cx + 22, cy - 6), (cx + 24, cy - 2), (cx + 22, cy + 6), (cx - 18, cy + 6)]
    b += [P.shape(poly(horn), "darkiron", s=1.6, lw=1.4), lin(f"M{cx-16},{cy-2} L{cx+20},{cy-2}", PAL["metal"][0], 1.0, 0.8),
          fill(rect(cx + 12, cy - 2, 4, 4), INK, 0.8),
          P.shape(f"M{cx-6},{cy+10} L{cx+18},{cy+16} L{cx+20},{cy+13} L{cx-4},{cy+7} Z", "wood", s=0.5, lw=0.9),
          P.shape(rect(cx + 14, cy + 9, 9, 10, 1.5), "darkiron", s=0.6, lw=1.0)]
    return sh, J(b), ""


def rival_counter(P, W, H):
    sh = sh_(P, rect(4, 6, W - 8, H - 12, 3))
    b = [planks(P, 4, 6, W - 8, H - 12, "wood", n=2, dirn="h", s=3, seed=41), lin(rect(4, 6, W - 8, H - 12, 3), INK, 2.2),
         sword_top(P, 14, 28, 50, -0.08), axe_top(P, 86, 22, 28, 0.3),
         P.shape(rect(118, 18, 26, 16, 2), "darkiron", s=0.8, lw=1.0), lin("M121,22 h20 M121,26 h20 M121,30 h20", PAL["metal"][0], 0.6, 0.7),
         P.shape(rect(72, 32, 12, 8, 1), "paper", s=0.3, lw=0.7), lin("M74,35 h8 M74,37 h5", INK, 0.4, 0.6)]
    return sh, J(b), ""


def rival_display(P, W, H):
    sh = sh_(P, rect(4, 4, W - 8, H - 8, 2), 3, 4)
    b = [backboard(P, 4, 2, W - 8, 8, "wood", pegs=(20, 50, 80, 110, 140))]
    b += [sword_top(P, 12, 22, 40, 0), sword_top(P, 62, 30, 36, 0), axe_top(P, 112, 22, 30, 0),
          P.shape(ell(140, 22, 11), "wood", s=1, lw=1.2, fill_override="#6a2a22"), P.shape(ell(140, 22, 4), "darkiron", s=0.5, lw=1.0)]
    return sh, J(b), ""


# ================================================================ the Hales: cottage and menagerie
def creature_cages(P, W, H):
    sh = sh_(P, rect(2, 4, W - 4, H - 8, 2), 3, 4)
    b = [shelf_box(P, 2, 2, W - 4, H - 6, "wood")]
    for i, (x, kind) in enumerate([(22, "wicker"), (58, "iron"), (96, "wicker")]):
        cage = ell(x, 20, 15, 13)
        b.append(P.shape(cage, "burlap" if kind == "wicker" else "darkiron", s=1.2, lw=1.2,
                         fill_override="#a8844e" if kind == "wicker" else "#3a3430"))
        b.append(fill(ell(x, 20, 11, 9.5), "#1a120c", 0.7))
        # the occupant: two glinting eyes and a fluffy shape
        b.append(fill(blob(x + 1, 22, 6, 7, 0.2, i + 3), ["#c8b08a", "#5a6e8e", "#8a6a46"][i], 0.95))
        b.append(fill(ell(x - 2, 19, 1.2) + " " + ell(x + 3, 19, 1.2), ["#f0d070", "#a8f0ff", "#ffb060"][i]))
        bars = " ".join(f"M{x+k*4.5:.1f},{20-math.sqrt(max(0, 1-(k*4.5/15)**2))*13:.1f} L{x+k*4.5:.1f},{20+math.sqrt(max(0, 1-(k*4.5/15)**2))*13:.1f}"
                        for k in range(-3, 4))
        b.append(lin(bars, INK if kind == "iron" else PAL["burlap"][2], 0.9, 0.85))
    return sh, J(b), ""


def bestiary_desk(P, W, H):
    sh = sh_(P, rect(4, 4, W - 8, H - 8, 2))
    b = [planks(P, 4, 4, W - 8, H - 8, "wood", n=2, dirn="h", s=3, seed=51), lin(rect(4, 4, W - 8, H - 8, 2), INK, 2.0),
         book(P, 34, 14, 40, 26, "leather", open_=True),
         P.shape(ell(46, 27, 6, 4), "paper", s=0.2, lw=0.5, fill_override="#f2ead2"),
         lin("M44,26 q2,-4 5,-1 q2,3 -1,4 M51,29 l3,2", INK, 0.6, 0.8),
         bottle_top(P, 16, 18, 6, "brew"), bottle_top(P, 18, 36, 5, "glass" if "glass" in PAL else "brew"),
         fill(ell(18, 36, 2.4), "#c86a5a", 0.8),
         lin("M90,14 Q104,20 112,36", INK, 2.2), lin("M90,14 Q104,20 112,36", "#4e7a8a", 1.2),
         P.shape(ell(98, 40, 5), "darkiron", s=0.4, lw=0.8), fill(ell(98, 40, 3), INK),
         P.shape(rect(80, 24, 10, 14, 1), "paper", s=0.3, lw=0.7, fill_override="#e8dcc0")]
    ce = ""
    return sh, J(b), ce


def rabbit_hutch(P, W, H):
    sh = sh_(P, rect(4, 4, W - 8, H - 10, 3), 5, 6)
    b = [planks(P, 4, 4, 44, H - 12, "wood", n=4, dirn="v", s=3, seed=61),
         lin(rect(4, 4, 44, H - 12, 2), INK, 2.0)]
    # wire run attached to the east
    b += [P.shape(rect(48, 10, W - 54, H - 22, 2), "grass", s=0.5, hl=False, lw=1.2, fill_override="#8a9a5a"),
          fill(rect(48, 10, W - 54, H - 22, 2), hatch(P, 45, 4.0, 0.5), 0.6), fill(rect(48, 10, W - 54, H - 22, 2), hatch(P, -45, 4.0, 0.5), 0.6)]
    for i, (x, y) in enumerate(((62, 26), (78, 40))):
        b.append(P.shape(ell(x, y, 7, 5.5), "hide", s=0.8, lw=1.0, fill_override=["#e8e0d0", "#8a6a46"][i]))
        b.append(P.shape(ell(x + 6, y - 1, 3.6, 3), "hide", s=0.4, lw=0.8, fill_override=["#e8e0d0", "#8a6a46"][i]))
        b.append(P.shape(ell(x + 6, y - 5, 1.4, 3.4) + " " + ell(x + 9, y - 4, 1.4, 3.4), "hide", s=0.2, lw=0.6, fill_override=["#e8e0d0", "#8a6a46"][i]))
        b.append(fill(ell(x - 7, y, 1.8), "#f2ecdc"))
    b.append(P.shape(ell(68, H - 18, 4, 3), "cabbage", s=0.4, lw=0.7))
    return sh, J(b), ""


def chicken_coop(P, W, H):
    sh = sh_(P, rect(8, 4, W - 16, 52, 3), 5, 6)
    # little shingled house (roof seen from above, ridge across) + a fenced run with hens
    b = [P.shape(rect(8, 4, W - 16, 26, 2), "roof_a", s=2, fill_override="#9a6a4e"),
         P.shape(rect(8, 30, W - 16, 26, 2), "roof_a", s=1, fill_override="#7a4e38"),
         fill(rect(8, 30, W - 16, 26, 2), hatch(P, -35, 4.0, 0.8), 0.4),
         lin(" ".join(f"M8,{y} L{W-8},{y}" for y in (12, 20, 38, 46)), INK, 0.7, 0.7),
         lin(f"M8,30 L{W-8},30", INK, 2.2),
         P.shape(rect(W / 2 - 6, 56, 12, 6, 1), "wood", s=0.4, lw=0.9),
         lin(f"M{W/2-4},62 L{W/2-10},{H-6} M{W/2+4},62 L{W/2+10},{H-6}", PAL["wood"][1], 1.6)]
    rnd = random.Random(5)
    for i in range(3):
        x, y = 22 + i * 30 + rnd.uniform(-4, 4), 74 + rnd.uniform(-4, 6)
        b.append(P.shape(ell(x, y, 6.5, 5), "hen", s=0.8, lw=1.0, fill_override=["#f2e6cc", "#b8743a", "#5a3a24"][i]))
        b.append(P.shape(ell(x + 5, y - 3, 3, 2.6), "hen", s=0.3, lw=0.8, fill_override=["#f2e6cc", "#b8743a", "#5a3a24"][i]))
        b.append(fill(poly([(x + 7.6, y - 3.6), (x + 10.5, y - 3), (x + 7.6, y - 2)]), PAL["gold"][1]))
        b.append(fill(ell(x + 4.6, y - 5.4, 1.4, 1), "#c83a2a"))
    b.append(fill(" ".join(ell(x, y, 0.8) for x, y in [(30, 88), (50, 84), (70, 90), (86, 82), (44, 92)]), PAL["straw"][1]))
    return sh, J(b), ""


def arcane_enclosure(P, W, H):
    """A pen for the strange ones: standing stones linked by a low iron rail, a warded rune circle on the ground,
    a mossy nest with a sleeping drakeling curled tail-to-snout."""
    cx, cy = W / 2, H / 2
    rx, ry = W / 2 - 14, H / 2 - 14
    sh = sh_(P, ell(cx, cy, rx + 6, ry + 6), 5, 6, op=0.3)
    b = [fill(ell(cx, cy, rx, ry), "#6a6a4a", 0.35), lin(ell(cx, cy, rx * 0.72, ry * 0.72), INK, 1.0, 0.5)]
    # rail
    b.append(lin(ell(cx, cy, rx, ry), INK, 3.6))
    b.append(lin(ell(cx, cy, rx, ry), PAL["darkiron"][0], 1.4))
    for i in range(8):
        a = i / 8 * math.tau + 0.2
        x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry
        b.append(P.shape(blob(x, y, 8, 6, 0.14, i + 2), "stone", s=2.2))
        b.append(P.detail(f"M{x-2},{y-3} l2,4 l2,-4", "stone", 0.5, 0.8))
    # nest + drakeling
    b.append(P.shape(wobbly_ell(cx, cy + 4, 26, 18, 3, 0.1), "straw", s=2, fill_override="#7a6a42"))
    b.append(P.detail(" ".join(f"M{cx-20+i*5},{cy+4+(i%3-1)*6} l6,{2-(i%2)*4}" for i in range(9)), "straw", 0.5, 0.8))
    body = smooth([(cx - 14, cy + 2), (cx - 6, cy - 8), (cx + 8, cy - 7), (cx + 15, cy + 2), (cx + 8, cy + 12), (cx - 6, cy + 12)], t=0.45)
    b += [P.shape(body, "cloth", s=1.6, lw=1.2, fill_override="#4e6a5a"),
          P.shape(smooth([(cx + 12, cy + 2), (cx + 20, cy - 4), (cx + 16, cy - 10), (cx + 10, cy - 6)], t=0.4), "cloth", s=0.8, lw=1.1, fill_override="#5a7a68"),
          lin(f"M{cx-12},{cy+6} Q{cx-20},{cy+14} {cx-8},{cy+16} Q{cx+4},{cy+16} {cx+12},{cy+10}", INK, 3.2),
          lin(f"M{cx-12},{cy+6} Q{cx-20},{cy+14} {cx-8},{cy+16} Q{cx+4},{cy+16} {cx+12},{cy+10}", "#5a7a68", 1.6),
          P.shape(f"M{cx-4},{cy-6} q6,-12 12,-4 q-4,2 -12,4 Z", "cloth", s=0.4, lw=0.9, fill_override="#7a5a8a"),
          lin(f"M{cx-6},{cy-2} l3,-3 M{cx},{cy-4} l3,-3 M{cx+6},{cy-3} l3,-3", INK, 0.7, 0.8)]
    e = [lit_ring(P, cx, cy, rx * 0.72, ry * 0.72), glow(P, cx + 17, cy - 7, 6, VIOLET_HOT, 0.5), fill(ell(cx + 17, cy - 7, 1.2), VIOLET_HOT)]
    for i in range(8):
        a = i / 8 * math.tau + 0.2
        e.append(glow(P, cx + math.cos(a) * rx, cy + math.sin(a) * ry, 9, VIOLET, 0.35))
    return sh, J(b), J(e)


def lit_ring(P, cx, cy, rx, ry):
    bf = blur_filter(P, 1.6)
    d = ell(cx, cy, rx, ry)
    rnd = random.Random(3)
    glyphs = " ".join(f"M{cx+math.cos(a)*rx:.1f},{cy+math.sin(a)*ry-2:.1f} l2,4 l2,-4" for a in [k * math.tau / 12 + rnd.uniform(-0.05, 0.05) for k in range(12)])
    return (f'<path d="{d} {glyphs}" fill="none" stroke="{VIOLET}" stroke-width="3" opacity="0.45" {bf}/>' + lin(d, VIOLET_HOT, 0.8, 0.7)
            + lin(glyphs, VIOLET_HOT, 0.8, 0.85))


@decal
def feed_scatter(P, W, H):
    rnd = random.Random(11)
    o = [fill(ell(W / 2, H / 2, W / 2 - 6, H / 2 - 6), PAL["mud"][1], 0.18)]
    o.append(fill(" ".join(ell(rnd.gauss(W / 2, 12), rnd.gauss(H / 2, 8), rnd.uniform(0.7, 1.3)) for i in range(70)), PAL["straw"][1], 0.9))
    o.append(fill(" ".join(ell(rnd.gauss(W / 2, 10), rnd.gauss(H / 2, 7), rnd.uniform(0.6, 1.0)) for i in range(26)), PAL["straw"][2], 0.8))
    return "", J(o), ""


def hay_rack(P, W, H):
    sh = sh_(P, rect(4, 6, W - 8, H - 12, 2), 3, 4)
    b = [P.shape(rect(4, 6, W - 8, H - 12, 2), "wood", s=2), P.shape(blob(W / 2, H / 2, 24, 9, 0.12, 4, squash=0.5), "straw", s=2.5),
         P.detail(" ".join(f"M{12+i*6},{14+(i%3)*6} l{4-(i%2)*8},{3}" for i in range(10)), "straw", 0.5, 0.8),
         lin(" ".join(f"M{x},6 L{x},{H-6}" for x in range(12, W - 6, 10)), INK, 1.4), lin(" ".join(f"M{x},6 L{x},{H-6}" for x in range(12, W - 6, 10)), PAL["wood"][0], 0.6)]
    return sh, J(b), ""


def fence_gate_h(P, W, H):
    sh = sh_(P, rect(0, 9, 64, 6), 2, 3, op=0.4)
    b = [P.shape(rect(6, 7, 52, 4, 1), "wood", s=1, lw=1.3), P.shape(rect(6, 15, 52, 4, 1), "wood", s=1, lw=1.3),
         lin("M8,17 L56,9", INK, 3.0), lin("M8,17 L56,9", PAL["wood"][0], 1.4)]
    for x in (3, 61):
        b.append(P.shape(rect(x - 4, 5, 8, 14, 1.5), "wood", s=1.5, lw=1.6))
    b.append(P.shape(rect(30, 10, 6, 6, 1), "darkiron", s=0.3, lw=0.8))
    return sh, J(b), ""


def fence_gate_v(P, W, H):
    sh = sh_(P, rect(9, 0, 6, 64), 2, 3, op=0.4)
    b = [P.shape(rect(7, 6, 4, 52, 1), "wood", s=1, lw=1.3), P.shape(rect(15, 6, 4, 52, 1), "wood", s=1, lw=1.3),
         lin("M9,8 L17,56", INK, 3.0), lin("M9,8 L17,56", PAL["wood"][0], 1.4)]
    for y in (3, 61):
        b.append(P.shape(rect(5, y - 4, 14, 8, 1.5), "wood", s=1.5, lw=1.6))
    return sh, J(b), ""


# ================================================================ the caravan camp
def caravan_wagon(P, W, H):
    """A covered trader's wagon seen from above, shafts to the west: painted canvas hood on hoops, tasselled
    valance, four iron-shod wheels, a tail-board with crates and a lantern."""
    x0, x1, y0, y1 = 54, W - 30, 30, H - 30
    sh = sh_(P, rect(x0 - 6, y0 - 12, x1 - x0 + 16, y1 - y0 + 24, 10), 8, 9)
    b = []
    # wheels (seen edge-on from above: long rectangles beside the bed)
    for wx in (x0 + 18, x1 - 22):
        for wy, d in ((y0 - 12, -1), (y1 + 3, 1)):
            b.append(P.shape(rect(wx - 18, wy, 36, 9, 3), "wood", s=1.2, lw=1.4, fill_override="#6a4a2e"))
            b.append(lin(f"M{wx-18},{wy+4.5} L{wx+18},{wy+4.5}", PAL["darkiron"][1], 1.8))
            b.append(P.shape(ell(wx, wy + 4.5, 4, 5.5), "darkiron", s=0.4, lw=1.0))
    # shafts and yoke (west)
    b += [lin(f"M{x0},{y0+16} L8,{y0+26} M{x0},{y1-16} L8,{y1-26}", INK, 5.0),
          lin(f"M{x0},{y0+16} L8,{y0+26} M{x0},{y1-16} L8,{y1-26}", PAL["wood"][0], 2.6),
          P.shape(rect(8, y0 + 22, 8, y1 - y0 - 44, 2), "wood", s=0.6, lw=1.2)]
    # bed + tail-board with crates (east end)
    b.append(planks(P, x0, y0 - 2, x1 - x0, y1 - y0 + 4, "wood", n=6, dirn="h", s=3, seed=71))
    b.append(lin(rect(x0, y0 - 2, x1 - x0, y1 - y0 + 4, 3), INK, 2.4))
    b += [crate_top(P, x1 - 26, y0 + 8, 20, seed=3), crate_top(P, x1 - 26, y1 - 28, 20, seed=4)]
    # canvas hood over hoops: striped burgundy & cream, rounded ends
    hx0, hx1 = x0 + 10, x1 - 34
    hood = f"M{hx0},{y0-6} L{hx1},{y0-6} Q{hx1+14},{(y0+y1)/2} {hx1},{y1+6} L{hx0},{y1+6} Q{hx0-14},{(y0+y1)/2} {hx0},{y0-6} Z"
    b.append(P.shape(hood, "canvas", s=5))
    cid = artlib.uid("hc")
    P.defs.append(f'<clipPath id="{cid}"><path d="{hood}"/></clipPath>')
    stripes = " ".join(rect(hx0 - 16 + i * 26, y0 - 8, 13, y1 - y0 + 16) for i in range(7))
    inner = [fill(stripes, "#7e2a22", 0.85), fill(rect(hx0 - 20, (y0 + y1) / 2, hx1 - hx0 + 40, y1 - (y0 + y1) / 2 + 10), hatch(P, -35, 4.2, 0.9), 0.35),
             fill(rect(hx0 - 20, (y0 + y1) / 2 + 2, hx1 - hx0 + 40, y1 - (y0 + y1) / 2 + 10), INK, 0.12)]
    b.append(f'<g clip-path="url(#{cid})">' + "".join(inner) + "</g>")
    b.append(lin(" ".join(f"M{hx0+12+i*28},{y0-5} Q{hx0+10+i*28},{(y0+y1)/2} {hx0+12+i*28},{y1+5}" for i in range(5)), INK, 1.4, 0.8))
    b.append(lin(f"M{hx0},{(y0+y1)/2} L{hx1},{(y0+y1)/2}", "#f2e6c8", 1.6, 0.8))
    b.append(lin(hood, INK, 2.4))
    # tassels along the valance + painted star on the hood
    b.append(fill(" ".join(ell(hx0 + 6 + i * 13, y0 - 7, 1.8, 2.6) + " " + ell(hx0 + 6 + i * 13, y1 + 7, 1.8, 2.6) for i in range(int((hx1 - hx0) / 13))), GILT))
    sx, sy = (hx0 + hx1) / 2, (y0 + y1) / 2 - 18
    b.append(P.shape(poly([(sx + math.cos(a) * (9 if k % 2 == 0 else 4), sy + math.sin(a) * (9 if k % 2 == 0 else 4))
                           for k, a in enumerate([j * math.tau / 10 - math.pi / 2 for j in range(10)])]), "gold", s=0.6, lw=1.0))
    # tail lantern
    b.append(P.shape(rect(x1 + 2, (y0 + y1) / 2 - 5, 10, 10, 2), "darkiron", s=0.5, lw=1.1))
    b.append(fill(rect(x1 + 4, (y0 + y1) / 2 - 3, 6, 6, 1), "#e8d4a0"))
    return sh, J(b), ""


def campfire(P, W, H):
    cx, cy = W / 2, H / 2
    sh = sh_(P, ell(cx, cy, 26, 22), 3, 4, op=0.35)
    b = [fill(ell(cx, cy, 30, 26), "#3a2a1e", 0.35, blur_filter(P, 3)), fill(ell(cx, cy, 20, 16), "#2a221c", 0.9),
         stones_ring(P, cx, cy, 24, 20, n=11, size=0.32, seed=7)]
    for a in (0.3, 1.9, 3.6, 5.0):
        b.append(f'<g transform="rotate({math.degrees(a):.0f} {cx} {cy})">' +
                 P.shape(rect(cx - 13, cy - 2.6, 22, 5.2, 2.6), "wood", s=1, lw=1.1, fill_override="#4a3220") + "</g>")
    cb, ce = coals(P, cx, cy, 9, 7, seed=21, hot=0.55)
    b.append(cb)
    b.append(fill(" ".join(ell(cx + dx, cy + dy, 2.2, 1.6) for dx, dy in ((-6, 3), (5, -4), (2, 6))), "#8a8478", 0.7))
    return sh, J(b), ce


def log_seat(P, W, H):
    sh = sh_(P, rect(6, 10, W - 12, H - 18, 8), 3, 4)
    b = [P.shape(rect(10, 9, W - 20, H - 18, 9), "wood", s=2.4, fill_override="#6a4a30"),
         P.detail(" ".join(f"M{x},{11} q4,{(H-22)/2} 0,{H-22}" for x in range(24, W - 16, 12)), "wood", 0.5, 0.6),
         lin(f"M14,{H/2-3} L{W-18},{H/2-4}", PAL["wood"][0], 0.8, 0.6),
         end_grain(P, 12, H / 2, (H - 18) / 2, "wood", seed=3), end_grain(P, W - 12, H / 2, (H - 18) / 2, "wood", seed=4),
         P.shape(ell(W * 0.62, 12, 4, 2.6), "green", s=0.3, lw=0.6, fill_override="#7a8a52")]
    return sh, J(b), ""


def tether_post(P, W, H):
    cx, cy = W / 2, H / 2
    sh = sh_(P, ell(cx, cy, 8), 2, 3)
    b = [end_grain(P, cx, cy, 8, "wood", seed=6), lin(ell(cx, cy, 10.5, 10), INK, 2.6), lin(ell(cx, cy, 10.5, 10), PAL["burlap"][1], 1.2),
         lin(f"M{cx+10},{cy+2} q6,4 4,10", PAL["burlap"][1], 1.4)]
    return sh, J(b), ""


def caravan_pennant(P, W, H):
    """A tall pole seen from above with its swallow-tailed pennant streaming east (the camp's mark)."""
    cx, cy = 12, H / 2
    sh = sh_(P, ell(cx, cy, 6) + " " + f"M{cx},{cy-4} L{W-4},{cy-10} L{W-14},{cy} L{W-4},{cy+8} L{cx},{cy+5} Z", 6, 8, op=0.35)
    flag = f"M{cx+2},{cy-6} Q{W*0.45},{cy-14} {W-4},{cy-9} L{W-16},{cy+1} L{W-4},{cy+10} Q{W*0.45},{cy+5} {cx+2},{cy+6} Z"
    b = [P.shape(flag, "burgundy", s=2, fill_override="#7e2a22"),
         lin(f"M{cx+4},{cy} Q{W*0.45},{cy-4} {W-14},{cy+1}", GILT, 1.4, 0.9),
         P.shape(ell(W * 0.42, cy - 2, 4), "gold", s=0.4, lw=0.8),
         P.shape(ell(cx, cy, 5.5), "wood", s=1, lw=1.3), fill(ell(cx, cy, 2.2), PAL["gold"][0])]
    return sh, J(b), ""


# ================================================================ the ceremony stage on the square
@decal
def square_stage(P, W, H):
    """A plank stage for ceremonies, steps down to the square on its north side; drawn as a raised floor (the people
    walk on it): a deep shadowed skirt to the south and east, burgundy drapes with gilt fringe along the front."""
    x0, y0, x1, y1 = 14, 24, W - 18, H - 22
    o = [fill(rect(x0 + 6, y0 + 8, x1 - x0 + 10, y1 - y0 + 12, 6), INK, 0.35, blur_filter(P, 5)),
         fill(rect(x0, y1 - 2, x1 - x0, 14, 2), "#3a2416"), fill(rect(x1 - 2, y0, 12, y1 - y0 + 12, 2), "#2a1a10"),
         fill(rect(x0, y1 - 2, x1 - x0 + 10, 14, 2), hatch(P, -35, 3.6, 1.0), 0.6)]
    o.append(planks(P, x0, y0, x1 - x0, y1 - y0, "wood", n=9, dirn="h", s=3, seed=81, nails=True))
    o.append(fill(rect(x0, y0, x1 - x0, y1 - y0), "#ffffff", 0.06))
    o.append(lin(rect(x0, y0, x1 - x0, y1 - y0, 2), INK, 2.6))
    # steps down to the north (centre)
    sx0, sx1 = W / 2 - 34, W / 2 + 34
    for i, y in enumerate((y0 - 8, y0 - 16, y0 - 24)):
        o.append(planks(P, sx0 + i * 3, y, sx1 - sx0 - i * 6, 8, "wood", n=1, dirn="h", s=1.6, seed=90 + i))
        o.append(lin(rect(sx0 + i * 3, y, sx1 - sx0 - i * 6, 8, 1), INK, 1.4))
    # drapes along the front edge, either side of the steps
    for a, b2 in ((x0 + 4, sx0 - 4), (sx1 + 4, x1 - 4)):
        sw = " ".join(f"M{x:.1f},{y0+1} Q{x+11:.1f},{y0+10} {x+22:.1f},{y0+1}" for x in [a + k * 22 for k in range(int((b2 - a) / 22))])
        o.append(lin(sw, INK, 4.6))
        o.append(lin(sw, "#7e2a22", 3.0))
        o.append(lin(sw, GILT, 0.8, 0.9))
    # corner posts (round tops) carrying the bunting
    for x, y in ((x0 + 4, y0 + 4), (x1 - 4, y0 + 4), (x0 + 4, y1 - 4), (x1 - 4, y1 - 4)):
        o.append(P.shape(ell(x, y, 6), "wood", s=1, lw=1.3))
        o.append(fill(ell(x, y, 2.6), PAL["gold"][0]))
    # a worn red runner from the steps to the lectern
    o.append(P.shape(rect(W / 2 - 16, y0 + 6, 32, y1 - y0 - 26, 2), "cloth", s=0.8, lw=1.1, fill_override="#7e2a22"))
    o.append(lin(rect(W / 2 - 13, y0 + 8, 26, y1 - y0 - 30, 1), GILT, 0.8, 0.8))
    return "", J(o), ""


def podium_board(P, W, H):
    """The square's honours board on two legs with a lectern before it (seen from above-front)."""
    sh = sh_(P, rect(10, 8, W - 20, 30, 3), 4, 5)
    b = [P.shape(rect(10, 4, W - 20, 34, 3), "wood", s=3, fill_override="#5a3a22"),
         P.shape(rect(16, 9, W - 32, 24, 2), "cloth", s=-1, hl=False, lw=1.2, fill_override="#3a2a22"),
         P.shape(poly([(W / 2 - 14, 4), (W / 2, -2 + 4), (W / 2 + 14, 4)]), "gold", s=0.5, lw=1.0)]
    for i in range(3):
        for j in range(2):
            x, y = 22 + i * 30, 12 + j * 10
            b.append(P.shape(rect(x, y, 24, 7, 1), "gold", s=0.5, lw=0.8, fill_override="#b8923e"))
            b.append(lin(f"M{x+3},{y+3.5} h{14 - (i + j) % 3 * 3}", INK, 0.6, 0.7))
    # laurel crest at the centre top
    b.append(lin(f"M{W/2-10},8 q10,6 20,0", PAL["green"][1], 1.6))
    # lectern before the board
    b += [P.shape(rect(W / 2 - 14, 42, 28, 16, 2), "wood", s=1.6, fill_override="#6a4a2e"),
          book(P, W / 2 - 10, 44, 20, 12, "leather", open_=True)]
    return sh, J(b), ""


def bunting(P, W, H):
    """Strings of pennants for the square: two swags of alternating burgundy, cream, gilt and blue flags."""
    cols = ["#7e2a22", "#f2e6c8", "#b8923e", "#2e3e58"]
    o = []
    for row, (ya, sag) in enumerate(((10, 18), (16, 22))):
        pts = []
        n = 24
        for k in range(n + 1):
            t = k / n
            pts.append((8 + t * (W - 16), ya + sag * 4 * t * (1 - t) + row * 2))
        path = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        o.append(lin(path, INK, 1.4, 0.9))
        for k in range(1 + row % 2, n, 2):
            x, y = pts[k]
            d = poly([(x - 4.6, y), (x + 4.6, y), (x, y + 11)])
            o.append(P.shape(d, "cloth", s=0.5, lw=0.8, fill_override=cols[(k + row) % 4]))
    sh = f'<g transform="translate(10,30)" opacity="0.28">{fill(rect(8, 8, W - 16, 22, 10), INK, 0.4, blur_filter(P, 4))}</g>'
    return sh, J(o), ""


# ================================================================ the graveyard
@decal
def grave_plot(P, W, H):
    """An unused plot: a mown rectangle pegged out with string, waiting."""
    o = [fill(rect(10, 8, W - 20, H - 16, 3), "#7a8a52", 0.30), fill(rect(10, 8, W - 20, H - 16, 3), hatch(P, 80, 3.2, 0.6, "#3a4a22"), 0.35)]
    o.append(lin(rect(10, 8, W - 20, H - 16, 1), "#e8dcc0", 0.8, 0.75))
    o.append(fill(" ".join(ell(x, y, 1.8) for x, y in ((10, 8), (W - 10, 8), (10, H - 8), (W - 10, H - 8))), PAL["wood"][1]))
    o.append(lin(" ".join(ell(x, y, 1.8) for x, y in ((10, 8), (W - 10, 8), (10, H - 8), (W - 10, H - 8))), INK, 0.6))
    return "", J(o), ""


# ================================================================ jobs & review
PROPS_X = {k: v for k, v in dict(globals()).items() if callable(v) and not k.startswith("_") and not k.startswith("em_") and k not in (
    "J", "sh_", "decal", "painter", "sprite_svg", "svg_doc", "soft_filter", "ground_shadow", "glow", "lin", "fill", "planks",
    "end_grain", "liquid", "bottle_top", "candle_top", "coals", "stones_ring", "sigil_ring", "render", "load", "only_filter", "ell",
    "rect", "poly", "smooth", "blob", "wobbly_ell", "blur_filter", "hatch", "tankard", "book", "barrel_top", "crate_top", "sack_top",
    "sword_top", "axe_top", "backboard", "shelf_box", "open_crate", "hanging_sign", "lit_ring", "jobs", "contact_sheets")}


def jobs():
    only = only_filter()
    js = []
    props = load("props.json")
    for pid, fn in PROPS_X.items():
        if pid not in props or (only and pid not in only):
            continue
        W, H = props[pid]["size"]
        P = painter(scale=1.0, lw_mul=0.7)
        sh, body, emit = fn(P, W, H)
        if pid in DECALS:
            svg = svg_doc(W, H, P, f'<g {soft_filter(P, 0.8)}>{sh}{body}</g><g>{emit}</g>', ss=3)
        else:
            svg = sprite_svg(P, W, H, sh, body, emit, ss=3, wob=0.9, dil=0.7, grain=0.45, soot=0.6)
        js.append(dict(name=f"px_{pid}", svg=svg, w=W, h=H, ss=3, out=os.path.join(SPR, "props", pid + ".png")))
    return js


def contact_sheets():
    import contact
    props = load("props.json")
    pf = [os.path.join(SPR, "props", "template_" + p + ".png") for p in PROPS_X if p in props]
    contact.sheet("village10_props", pf, zoom=1.0, max_w=1600)
    contact.sheet("village10_props_ground", pf, zoom=1.0, max_w=1600, bg=(196, 176, 130))


if __name__ == "__main__":
    render(jobs())
    contact_sheets()
