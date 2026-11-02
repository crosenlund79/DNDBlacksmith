"""Inventory icons (64x64, designed in a 128-unit space) + star/gold/lock (32x32).
python3 make_icons.py [--only=sword_iron,ore_iron]"""
import math
import os
import random
from artlib import (painter, svg_doc, ink_filter, glow, lin, fill, render, load, only_filter, ell, rect, poly, smooth, blob,
                    wobbly_ell, ST, INK, EMBER, EMBER_HOT, RUB, GILT, SPR, VIOLET, VIOLET_HOT, RUNE_GOLD, FROST, BREW,
                    BREW_HOT, SILVER, lit_marks, rune_glyphs, blur_filter, hatch)

PAL = ST["pal"]
ICE = "#a8d4ee"


def J(o):
    return "\n".join(x for x in o if x)


def rot(d_svg, ang, cx=64, cy=64):
    return f'<g transform="rotate({ang} {cx} {cy})">{d_svg}</g>'


# ------------------------------------------------------------- weapons
def blade_sword(P, role="metal", guard="bronze", grip="leather", L=1.0, runes=None, pommel_gem=False, nicks=False):
    """Vertical sword (tip up) centred on x=64, rotated 45deg by caller."""
    b, e = [], []
    top, gy = 8 + (1 - L) * 60, 86
    b.append(P.shape(poly([(57, gy), (71, gy), (70.5, top + 14), (64, top), (57.5, top + 14)]), role, s=3))
    b.append(P.detail(f"M64,{gy-3} L64,{top+16}", role, 0.9, 0.85))
    b.append(fill(poly([(59.5, gy - 4), (62.5, gy - 4), (62.5, top + 16), (60, top + 18)]), "#ffffff", 0.35))
    if nicks:
        b.append(P.detail(f"M70.5,{top+30} l-2,1.5 M57.5,{top+44} l2,1", role, 0.6))
    b.append(P.shape(smooth([(38, gy + 2), (50, gy - 3), (64, gy - 1), (78, gy - 3), (90, gy + 2), (78, gy + 7), (64, gy + 6), (50, gy + 7)]), guard, s=2))
    b.append(P.shape(rect(59.5, gy + 6, 9, 22, 3), grip, s=2))
    b.append(P.detail(" ".join(f"M60,{gy+10+i*4} L68,{gy+13+i*4}" for i in range(4)), grip, 0.6))
    b.append(P.shape(ell(64, gy + 32, 6.5), guard, s=1.5))
    if pommel_gem:
        b.append(P.shape(ell(64, gy + 32, 3), "gem", s=1, lw=1.2))
    if runes:
        rnd = random.Random(3)
        d = " ".join(rune_glyphs(rnd, 64, y, 2.6) for y in range(int(top) + 24, gy - 6, 11))
        e.append(lit_marks(P, d, runes[0], runes[1], w=1.1, glow_w=3.4, op=0.95, blur=1.6))
    return J(b), J(e)


def sword_iron(P):
    b, e = blade_sword(P, "darkiron", "darkiron", "wood", nicks=True)
    return rot(b, 45), rot(e, 45)


def sword_steel(P):
    b, e = blade_sword(P, "metal", "bronze", "leather")
    return rot(b, 45), rot(e, 45)


def sword_mithril(P):
    b, e = blade_sword(P, "mithril", "gold", "cloth", pommel_gem=True, runes=(VIOLET, VIOLET_HOT))
    return rot(b, 45), rot(e, 45)


def dagger(P):
    b, e = blade_sword(P, "metal", "darkiron", "leather", L=0.62)
    return rot(f'<g transform="translate(0,-14)">{b}</g>', 45), ""


def axe_hand(P):
    b = [P.shape(rect(59, 14, 9, 104, 4), "wood", s=2),
         P.detail("M61,30 l4,8 M62,70 l3,6", "wood", 0.5),
         P.shape(rect(58, 96, 11, 18, 3), "leather", s=1.5)]
    head = smooth([(66, 16), (82, 12), (100, 6), (106, 26), (102, 48), (88, 40), (78, 36), (66, 38)])
    b.append(P.shape(head, "metal", s=3))
    b.append(P.detail("M100,10 Q108,28 102,46", "metal", 0.6, 0.8))
    b.append(fill(smooth([(94, 12), (100, 10), (103, 26), (98, 40)], close=False) + " Z", "#ffffff", 0.3))
    b.append(P.shape(rect(56, 14, 14, 26, 3), "darkiron", s=1.5))
    return rot(J(b), 20), ""


def mace_flanged(P):
    b = [P.shape(rect(59, 50, 10, 66, 4), "wood", s=2), P.shape(rect(58, 96, 12, 20, 3), "leather", s=1.5),
         P.shape(ell(64, 118, 5.5), "darkiron", s=1)]
    for i, dx in enumerate((-20, 20, -11, 11)):
        y0 = 18 if abs(dx) < 15 else 22
        b.append(P.shape(poly([(64, 16), (64 + dx, y0 + 4), (64 + dx * 1.05, 40), (64, 50)]), "metal", s=2, lw=3.2))
    b.append(P.shape(rect(58, 14, 12, 40, 4), "darkiron", s=2))
    b.append(P.shape(ell(64, 12, 5), "darkiron", s=1))
    return rot(J(b), 30), ""


def shield_round(P):
    b = [P.shape(ell(64, 64, 52), "wood", s=6)]
    b.append(P.detail(" ".join(f"M{x},{64-math.sqrt(max(0,52**2-(x-64)**2))+2:.1f} L{x},{64+math.sqrt(max(0,52**2-(x-64)**2))-2:.1f}" for x in range(30, 100, 14)), "wood", 0.7))
    b.append(lin(ell(64, 64, 48), INK, 6.5))
    b.append(lin(ell(64, 64, 48), PAL["darkiron"][1], 4.4))
    b.append(fill(" ".join(ell(64 + 48 * math.cos(a), 64 + 48 * math.sin(a), 1.6) for a in [i * math.tau / 12 for i in range(12)]), PAL["metal"][0]))
    b.append(P.shape(ell(64, 64, 15), "metal", s=3))
    b.append(fill(ell(59, 59, 4, 3), "#ffffff", 0.5))
    b.append(P.detail("M30,40 l8,6 M88,92 l6,-4", "wood", 0.6))
    return J(b), ""


def shield_kite(P):
    sh = smooth([(24, 18), (64, 10), (104, 18), (104, 52), (88, 90), (64, 120), (40, 90), (24, 52)])
    b = [P.shape(sh, "cloth", s=6)]
    b.append(fill(poly([(64, 30), (92, 62), (84, 70), (64, 50), (44, 70), (36, 62)]), "#e8d8b0", 0.95))
    b.append(lin(poly([(64, 30), (92, 62), (84, 70), (64, 50), (44, 70), (36, 62)]), INK, 1.4))
    b.append(lin(smooth([(30, 22), (64, 15), (98, 22), (98, 52), (84, 87), (64, 112), (44, 87), (30, 52)]), GILT, 2.2, 0.9))
    b.append(P.shape(ell(64, 26, 5), "gold", s=1))
    return J(b), ""


def cuirass_iron(P):
    b = []
    for sg in (-1, 1):
        b.append(P.shape(smooth([(64 + sg * 22, 22), (64 + sg * 44, 26), (64 + sg * 50, 44), (64 + sg * 38, 50), (64 + sg * 26, 40)]), "metal", s=3))
    bp = smooth([(40, 24), (64, 30), (88, 24), (96, 56), (88, 92), (64, 108), (40, 92), (32, 56)])
    b.append(P.shape(bp, "metal", s=8))
    b.append(P.detail("M64,32 L64,104 M44,92 Q64,104 84,92 M42,40 Q50,66 58,96 M86,40 Q78,66 70,96", "metal", 0.8))
    b.append(P.shape(smooth([(46, 18), (64, 12), (82, 18), (80, 30), (64, 34), (48, 30)]), "metal", s=2))
    b.append(fill(" ".join(ell(x, y, 2.2) for x, y in [(42, 36), (86, 36), (40, 78), (88, 78)]), PAL["metal"][0]))
    b.append(lin(" ".join(ell(x, y, 2.2) for x, y in [(42, 36), (86, 36), (40, 78), (88, 78)]), INK, 0.8))
    b.append(P.detail("M76,48 l8,6 M48,70 l6,3", "metal", 0.6))
    return J(b), ""


def chainmail(P):
    sh = smooth([(36, 20), (64, 26), (92, 20), (116, 46), (104, 60), (96, 52), (98, 110), (64, 116), (30, 110), (32, 52), (24, 60), (12, 46)])
    b = [P.shape(sh, "metal", s=8)]
    cid = "cm_clip"
    P.defs.append(f'<clipPath id="{cid}"><path d="{sh}"/></clipPath>')
    rings = " ".join(f"M{x+(3 if (y//6)%2 else 0)},{y} a3,2.4 0 1,0 6,0 a3,2.4 0 1,0 -6,0" for y in range(16, 120, 6) for x in range(8, 120, 6))
    b.append(f'<g clip-path="url(#{cid})">' + lin(rings, INK, 0.75, 0.6) + "</g>")
    b.append(P.shape(smooth([(46, 18), (64, 26), (82, 18), (76, 34), (64, 38), (52, 34)]), "leather", s=2))
    b.append(P.detail("M32,104 Q64,112 98,104", "metal", 0.8))
    return J(b), ""


def jerkin_leather(P):
    sh = smooth([(40, 18), (54, 22), (64, 34), (74, 22), (88, 18), (104, 30), (100, 60), (96, 112), (64, 118), (32, 112), (28, 60), (24, 30)])
    b = [P.shape(sh, "hide", s=7)]
    b.append(P.detail("M64,36 L64,114", "hide", 1.0))
    b.append(P.detail(" ".join(f"M60,{y} L68,{y+5} M68,{y} L60,{y+5}" for y in range(42, 100, 12)), "hide", 0.6))
    b.append(f'<path d="{smooth([(42, 26), (54, 30), (60, 40), (58, 108), (36, 106), (34, 60), (32, 34)])}" fill="none" stroke="#f0dcbc" stroke-width="1.1" stroke-dasharray="3 2.5" opacity="0.8"/>')
    b.append(P.shape(rect(30, 84, 68, 9, 2), "strap", s=1.5))
    b.append(P.shape(rect(58, 82, 12, 13, 2), "bronze", s=1))
    b.append(P.detail("M40,50 l6,10 M86,64 l-5,8", "hide", 0.6))
    return J(b), ""


def helm_iron(P):
    b = [P.shape(smooth([(26, 70), (28, 38), (44, 18), (64, 12), (84, 18), (100, 38), (102, 70), (96, 104), (82, 108), (80, 76), (64, 72), (48, 76), (46, 108), (32, 104)]), "metal", s=7)]
    b.append(P.detail("M64,14 L64,66 M30,52 Q64,40 98,52", "metal", 0.9))
    b.append(fill(smooth([(36, 62), (56, 58), (60, 70), (40, 72)]) + " " + smooth([(92, 62), (72, 58), (68, 70), (88, 72)]), "#16100b", 0.95))
    b.append(P.shape(rect(60, 56, 8, 40, 3), "metal", s=1.5))
    b.append(fill(" ".join(ell(x, 50, 1.8) for x in (34, 48, 80, 94)), PAL["metal"][0]))
    b.append(fill(ell(48, 30, 8, 5), "#ffffff", 0.35))
    return J(b), ""


def hood_leather(P):
    b = [P.shape(smooth([(22, 116), (24, 64), (36, 30), (64, 12), (92, 30), (104, 64), (106, 116), (82, 108), (64, 112), (46, 108)]), "hide", s=8)]
    b.append(fill(smooth([(40, 104), (40, 66), (52, 44), (64, 38), (76, 44), (88, 66), (88, 104), (64, 96)]), "#2a1c12", 0.95))
    b.append(fill(smooth([(46, 98), (48, 70), (58, 52), (64, 50), (70, 52), (80, 70), (82, 98), (64, 92)]), "#16100b", 0.6))
    b.append(P.detail("M64,14 Q60,30 64,40 M30,80 Q34,96 30,112 M98,80 Q94,96 98,112", "hide", 0.6))
    b.append(f'<path d="{smooth([(36, 106), (38, 64), (50, 40), (64, 34), (78, 40), (90, 64), (92, 106)], close=False)}" fill="none" stroke="#f0dcbc" stroke-width="1.1" stroke-dasharray="3 2.5" opacity="0.7"/>')
    return J(b), ""


def boot(P, x, y, flip=1):
    s = smooth([(x, y), (x + 22 * flip, y), (x + 22 * flip, y + 46), (x + 30 * flip, y + 58), (x + 34 * flip, y + 68), (x + 30 * flip, y + 74),
                (x - 2 * flip, y + 74), (x - 3 * flip, y + 40)])
    return J([P.shape(s, "boot", s=4), P.shape(rect(min(x, x + 24 * flip) - 1, y - 4, 26, 10, 3), "leather", s=1.5),
              P.detail(f"M{x+2*flip},{y+70} L{x+30*flip},{y+70}", "boot", 0.8),
              P.detail(f"M{x+6*flip},{y+20} l{10*flip},3 M{x+6*flip},{y+30} l{10*flip},3", "boot", 0.6)])


def boots_leather(P):
    return J([boot(P, 54, 24, 1), boot(P, 30, 30, 1)]), ""


def glove(P, x, y, role="leather"):
    hand = smooth([(x, y + 50), (x - 4, y + 26), (x - 14, y + 22), (x - 16, y + 14), (x - 4, y + 12), (x + 2, y), (x + 8, y - 22), (x + 14, y - 22),
                   (x + 16, y - 6), (x + 20, y - 26), (x + 27, y - 26), (x + 28, y - 4), (x + 32, y - 22), (x + 39, y - 20), (x + 38, y + 2),
                   (x + 43, y - 10), (x + 49, y - 8), (x + 44, y + 24), (x + 40, y + 50)])
    return J([P.shape(hand, role, s=4), P.shape(rect(x - 3, y + 44, 46, 18, 4), role, s=2),
              P.detail(f"M{x+15},{y-4} L{x+16},{y+14} M{x+28},{y-2} L{x+28},{y+14} M{x+39},{y+2} L{x+38},{y+16}", role, 0.6)])


def gloves_leather(P):
    return glove(P, 42, 44), ""


def gloves_warded(P):
    b = glove(P, 42, 44, "hide")
    rnd = random.Random(8)
    d = rune_glyphs(rnd, 62, 34, 6) + " " + ell(62, 34, 11)
    e = lit_marks(P, d, RUNE_BLUE_G, "#e8f4ff", w=1.4, glow_w=4, op=0.95, blur=2)
    return b, e


RUNE_BLUE_G = "#9cc4e6"


def belt_leather(P):
    b = [P.shape(smooth([(14, 72), (28, 52), (64, 44), (100, 52), (114, 72), (100, 92), (64, 98), (28, 92)]), "strap", s=4, flat=True, fill_override="none", lw=3)]
    b.append(lin(smooth([(14, 72), (28, 52), (64, 44), (100, 52), (114, 72), (100, 92), (64, 98), (28, 92)]), PAL["strap"][1], 12))
    b.append(lin(smooth([(14, 72), (28, 52), (64, 44), (100, 52), (114, 72), (100, 92), (64, 98), (28, 92)]), INK, 1.0, 0.9))
    b.append(lin(smooth([(16, 72), (29, 54), (64, 46), (99, 54), (112, 72), (99, 90), (64, 96), (29, 90)], close=True), "#f0dcbc", 0.8, 0.5))
    b.append(P.shape(rect(48, 86, 30, 22, 4), "bronze", s=2.5, flat=True, fill_override="none", lw=4))
    b.append(lin(rect(48, 86, 30, 22, 4), PAL["bronze"][1], 4))
    b.append(lin("M63,86 L63,108", INK, 2.2))
    b.append(P.shape(poly([(78, 92), (110, 98), (106, 108), (78, 104)]), "strap", s=2))
    b.append(fill(" ".join(ell(88 + i * 8, 100, 1.6) for i in range(2)), INK))
    return J(b), ""


def ring_silver(P):
    b = [P.shape(ell(64, 70, 38, 30) + " " + ell(64, 66, 27, 20), "silver", s=4).replace('<path d="', '<path fill-rule="evenodd" d="')]
    b.append(lin(ell(64, 68, 32, 25), "#ffffff", 1.2, 0.6))
    b.append(fill(ell(44, 52, 6, 3), "#ffffff", 0.7))
    return J(b), ""


def amulet_silver(P):
    beads = []
    for i in range(26):
        t = i / 25
        x = (1 - t) ** 2 * 26 + 2 * (1 - t) * t * 64 + t * t * 102
        y = (1 - t) ** 2 * 14 + 2 * (1 - t) * t * 110 + t * t * 14
        beads.append(ell(x, y, 2.6, 2.0))
    chain = " ".join(beads)
    b = [lin(chain, INK, 1.4), lin(chain, PAL["silver"][1], 0.8)]
    b.append(P.shape(ell(64, 86, 20, 22), "silver", s=4))
    b.append(P.shape(ell(64, 86, 11, 12), "ice", s=2))
    b.append(fill(ell(60, 81, 3.5, 2.5), "#ffffff", 0.8))
    b.append(lin(" ".join(ell(64 + 16 * math.cos(a), 86 + 17.5 * math.sin(a), 1.2) for a in [i * math.tau / 10 for i in range(10)]), INK, 0.8))
    b.append(P.shape(rect(59, 60, 10, 8, 2), "silver", s=1))
    return J(b), ""


# ------------------------------------------------------------- runestones
def runestone(P, glowcol=None, core=None, seed=1, role="rune"):
    top = wobbly_ell(64, 58, 44, 32, seed, 0.05)
    side = smooth([(20, 58), (22, 72), (40, 90), (64, 96), (88, 90), (106, 72), (108, 58), (88, 84), (64, 90), (40, 84)])
    b = [P.shape(side, role, s=2, fill_override=PAL[role][2]), P.shape(top, role, s=5)]
    rnd = random.Random(seed + 3)
    d = rune_glyphs(rnd, 64, 58, 15)
    b.append(lin(d, INK, 4.4, 0.9))
    b.append(P.detail("M36,48 l6,-4 M88,70 l6,2", role, 0.5))
    e = ""
    if glowcol:
        e = glow(P, 64, 58, 34, glowcol, 0.45) + lit_marks(P, d, glowcol, core, w=2.6, glow_w=9, op=1.0, blur=2.6)
    return J(b), e


def runestone_blank(P):
    return runestone(P, None, seed=2, role="slate")


def runestone_ember(P):
    return runestone(P, EMBER, EMBER_HOT, seed=3)


def runestone_ward(P):
    return runestone(P, "#a8c8e8", "#f0f8ff", seed=4)


def runestone_frost(P):
    return runestone(P, "#7cc8ec", "#e8fbff", seed=5, role="rune")


# ------------------------------------------------------------- materials
def ore(P, role, vein, seed, glowv=None, sheen=None):
    rnd = random.Random(seed)
    rock = blob(64, 66, 46, 7, 0.16, seed, squash=0.82)
    b = [P.shape(rock, role, s=7)]
    b.append(P.detail(f"M30,58 L48,52 L62,62 M66,44 L80,52 L98,48 M50,80 L70,76", role, 0.6, 0.8))
    veins = []
    for i in range(5):
        x, y = 34 + rnd.uniform(0, 56), 44 + rnd.uniform(0, 40)
        veins.append(f"M{x:.1f},{y:.1f} l{rnd.uniform(6,14):.1f},{rnd.uniform(-6,6):.1f} l{rnd.uniform(4,10):.1f},{rnd.uniform(-6,6):.1f}")
    vd = " ".join(veins)
    b.append(lin(vd, INK, 5.2, 0.8))
    b.append(lin(vd, vein, 3.2))
    flecks = " ".join(ell(30 + rnd.uniform(0, 66), 40 + rnd.uniform(0, 48), rnd.uniform(1.4, 2.6)) for _ in range(9))
    b.append(fill(flecks, vein, 0.95))
    if sheen:
        b.append(fill(ell(48, 48, 10, 5), sheen, 0.5))
    e = ""
    if glowv:
        e = lit_marks(P, vd, glowv[0], glowv[1], w=1.6, glow_w=5, op=0.9, blur=2) + glow(P, 64, 64, 40, glowv[0], 0.25)
    return J(b), e


def ore_iron(P):
    return ore(P, "stone", "#a8502c", 1)


def ore_copper(P):
    b, e = ore(P, "stone", "#d07a3c", 2)
    rnd = random.Random(4)
    b += fill(" ".join(ell(40 + rnd.uniform(0, 48), 50 + rnd.uniform(0, 30), rnd.uniform(2, 4)) for _ in range(5)), "#6aa088", 0.85)
    return b, e


def ore_silver(P):
    return ore(P, "slate", "#eef0f2", 3, sheen="#ffffff")


def ore_mithril(P):
    return ore(P, "slate", "#d8ecf8", 4, glowv=("#9ccbea", "#f4fbff"))


def ore_adamantine(P):
    return ore(P, "adamant", "#7fd0a0", 5, glowv=("#4f9a72", "#c8f4d8"))


def coal(P):
    b = []
    for i, (x, y, r) in enumerate([(46, 70, 26), (82, 74, 24), (62, 48, 22)]):
        b.append(P.shape(blob(x, y, r, 5, 0.2, i + 3), "coal", s=4))
        b.append(P.detail(f"M{x-r*0.4:.1f},{y-r*0.2:.1f} l{r*0.4:.1f},{-r*0.2:.1f} l{r*0.3:.1f},{r*0.3:.1f}", "coal", 0.7))
        b.append(lin(f"M{x-r*0.5:.1f},{y-r*0.45:.1f} l{r*0.4:.1f},-{r*0.15:.1f}", "#a09890", 1.4, 0.8))
    return J(b), ""


def ingot(P, role, mark=None, glowc=None):
    top = poly([(30, 50), (92, 42), (108, 56), (46, 66)])
    front = poly([(46, 66), (108, 56), (106, 76), (44, 88)])
    side = poly([(30, 50), (46, 66), (44, 88), (24, 70)])
    b = [P.shape(side, role, s=2, fill_override=PAL[role][2]), P.shape(front, role, s=2, fill_override=PAL[role][1]),
         P.shape(top, role, s=3, fill_override=PAL[role][0])]
    b.append(fill(poly([(40, 52), (84, 46), (88, 50), (44, 56)]), "#ffffff", 0.35))
    b.append(P.detail("M58,74 l8,-2 M80,70 l10,-2", role, 0.6))
    e = ""
    if mark:
        e = lit_marks(P, mark, glowc[0], glowc[1], w=1.4, glow_w=4.4, op=0.95, blur=1.8)
    return J(b), e


def ingot_iron(P):
    return ingot(P, "darkiron")


def ingot_steel(P):
    return ingot(P, "metal")


def ingot_mithril(P):
    b, e = ingot(P, "mithril", "M62,56 l6,-6 l6,6 l6,-6 M66,52 L66,58", (VIOLET, VIOLET_HOT))
    e += glow(P, 66, 60, 40, VIOLET, 0.3)
    return b, e


def leather_hide(P):
    from make_stations import pelt
    b = [P.shape(pelt(64, 64, 72, 52, 0.25), "hide", s=6)]
    b.append(P.detail("M40,58 Q64,50 92,62 M48,76 Q66,70 86,78", "hide", 0.6))
    b.append(fill(ell(68, 64, 18, 12), PAL["hide"][0], 0.35))
    return J(b), ""


def leather_cured(P):
    b = []
    for i, y in enumerate((76, 62, 48)):
        b.append(P.shape(poly([(22, y), (96, y - 10), (108, y + 6), (34, y + 18)]), "leather" if i != 1 else "hide", s=3))
    b.append(P.shape(smooth([(70, 24), (98, 24), (104, 40), (96, 52), (70, 50)]), "leather", s=3))
    b.append(lin(ell(98, 38, 7, 12), INK, 1.2))
    b.append(P.shape(rect(30, 40, 8, 46, 2), "strap", s=1.5))
    return J(b), ""


def spool_icon(P, thread, glowc=None):
    b = [P.shape(rect(32, 22, 64, 14, 4), "wood", s=2), P.shape(rect(32, 92, 64, 14, 4), "wood", s=2)]
    b.append(P.shape(rect(40, 34, 48, 60, 3), "linen", s=5, fill_override=thread))
    b.append(lin(" ".join(f"M41,{y} L87,{y+2}" for y in range(38, 92, 4)), PAL["linen"][2] if not glowc else "#8e9cb8", 0.7, 0.6))
    b.append(lin("M88,60 Q104,66 100,84 Q96,98 108,106", INK, 2.8))
    b.append(lin("M88,60 Q104,66 100,84 Q96,98 108,106", thread, 1.4))
    e = ""
    if glowc:
        e = glow(P, 64, 64, 46, glowc, 0.45) + lit_marks(P, "M88,60 Q104,66 100,84 Q96,98 108,106 M44,46 L84,48 M44,70 L84,72", "#c8d4ea", "#ffffff", w=1, glow_w=3.4, op=0.8)
    return J(b), e


def thread_linen(P):
    return spool_icon(P, "#ece0c2")


def thread_ethereal(P):
    return spool_icon(P, "#e8ecf8", "#c8d8ff")


def herb(P, leaf_role, stem, flower=None, moons=False):
    b = [lin("M46,116 Q56,80 64,40 M58,74 Q78,64 94,44 M54,92 Q38,74 28,60", INK, 4.6),
         lin("M46,116 Q56,80 64,40 M58,74 Q78,64 94,44 M54,92 Q38,74 28,60", stem, 2.4)]
    leaves = [(64, 40, -1.6), (94, 44, -0.8), (28, 60, -2.3), (62, 58, -2.4), (66, 54, -0.6), (78, 62, -1.6), (42, 72, -2.6), (54, 82, -0.6),
              (86, 52, 0.2), (36, 64, -1.2)]
    for i, (x, y, a) in enumerate(leaves):
        L = 16
        tip = (x + math.cos(a) * L, y + math.sin(a) * L)
        px, py = -math.sin(a) * 6, math.cos(a) * 6
        mx, my = (x + tip[0]) / 2, (y + tip[1]) / 2
        d = f"M{x:.1f},{y:.1f} Q{mx+px:.1f},{my+py:.1f} {tip[0]:.1f},{tip[1]:.1f} Q{mx-px:.1f},{my-py:.1f} {x:.1f},{y:.1f} Z"
        b.append(P.shape(d, leaf_role, s=1.5, lw=2.6))
        b.append(lin(f"M{x:.1f},{y:.1f} L{tip[0]:.1f},{tip[1]:.1f}", PAL[leaf_role][2], 0.8, 0.8))
    e = ""
    if moons:
        e = J([glow(P, x, y, 9, "#d8e8ff", 0.6) + fill(f"M{x-4},{y-4} a5,5 0 1,0 6,8 a4,4 0 1,1 -6,-8 Z", "#f4f8ff", 0.95) for x, y in [(64, 34), (96, 38), (26, 54)]])
    if flower:
        e = J([glow(P, x, y, 8, EMBER, 0.6) for x, y in [(64, 38), (94, 42)]])
    return J(b), e


def herb_emberleaf(P):
    PAL.setdefault("emberleaf", ("#f0a070", "#c8502a", "#6a1e0c"))
    return herb(P, "emberleaf", "#6a5030", flower=True)


def herb_moonwort(P):
    PAL.setdefault("moonleaf", ("#e0e8ec", "#a8bcc8", "#56687a"))
    return herb(P, "moonleaf", "#6a7a6a", moons=True)


def reagent_salt(P):
    b = [P.shape(smooth([(20, 64), (108, 64), (98, 96), (64, 108), (30, 96)]), "clay", s=5)]
    b.append(P.shape(ell(64, 64, 44, 14), "clay", s=-2, hl=False))
    rnd = random.Random(3)
    cr = []
    for i in range(14):
        x, y = 34 + rnd.uniform(0, 60), 48 + rnd.uniform(0, 18)
        s = rnd.uniform(5, 9)
        cr.append(poly([(x, y - s), (x + s * 0.7, y), (x, y + s * 0.5), (x - s * 0.7, y)]))
    b.append(P.shape(" ".join(cr), "glass", s=1, lw=2, fill_override="#f4f4ee"))
    b.append(lin(" ".join(cr), "#c8d0d4", 0.8))
    return J(b), ""


def potion(P, liq, glowc=None, shape="round", cork="wood"):
    if shape == "round":
        body = smooth([(56, 36), (72, 36), (72, 48), (94, 64), (100, 86), (90, 106), (64, 114), (38, 106), (28, 86), (34, 64), (56, 48)])
        liqd = smooth([(32, 80), (96, 80), (98, 90), (88, 106), (64, 112), (40, 106), (30, 90)])
    else:
        body = smooth([(56, 30), (72, 30), (72, 46), (84, 52), (86, 110), (64, 116), (42, 110), (44, 52), (56, 46)])
        liqd = poly([(44, 70), (86, 66), (86, 110), (64, 115), (42, 110)])
    b = [P.shape(body, "glass", s=4)]
    l, bb, s = PAL[liq]
    b.append(fill(liqd, bb, 0.92))
    b.append(fill(liqd, f"url(#{P.hatch_id})", 0.35))
    b.append(lin(body, INK, 4.0))
    b.append(fill(smooth([(42, 66), (50, 58), (52, 72), (46, 92), (40, 86)]), "#ffffff", 0.55))
    b.append(P.shape(rect(53, 22, 22, 16, 4), cork, s=2))
    b.append(P.shape(rect(50, 34, 28, 6, 2), "darkiron" if cork == "wood" else cork, s=1))
    e = ""
    if glowc:
        e = glow(P, 64, 92, 40, glowc, 0.45) + fill(ell(64, 92, 14, 8), l, 0.6)
    return J(b), e


def oil_whetstone(P):
    b, e = potion(P, "straw", None, "tall")
    b = f'<g transform="translate(14,-4) scale(0.82)">{b}</g>'
    stone = P.shape(poly([(14, 98), (64, 84), (72, 96), (22, 112)]), "slate", s=3) + P.shape(poly([(14, 98), (64, 84), (66, 88), (16, 102)]), "rune", s=1)
    return b + stone, ""


def potion_healing(P):
    return potion(P, "redp", "#e8604a")


def coating_flame(P):
    b, e = potion(P, "fire", EMBER, "tall")
    e += lit_marks(P, "M58,96 q-4,-10 4,-18 q0,8 6,10 q2,-6 0,-10 q8,8 4,18", EMBER, EMBER_HOT, w=1.4, glow_w=4, op=0.95)
    return b, e


def relic_idol(P):
    b = [P.shape(ell(64, 108, 30, 9), "slate", s=2)]
    body = smooth([(40, 104), (34, 80), (40, 56), (50, 48), (44, 36), (48, 20), (64, 14), (80, 20), (84, 36), (78, 48), (88, 56), (94, 80), (88, 104), (64, 110)])
    b.append(P.shape(body, "clay", s=7, fill_override="#9a8a6a"))
    b.append(P.detail("M54,30 l6,2 M68,32 l6,-2 M58,42 Q64,46 70,42 M50,64 Q64,74 78,64 M48,80 L80,80 M64,80 L64,104", "stone", 0.8))
    b.append(fill(ell(57, 31, 2.4) + " " + ell(71, 31, 2.4), EMBER, 0.9))
    e = glow(P, 64, 72, 40, EMBER, 0.25) + glow(P, 64, 31, 12, EMBER, 0.6)
    b.append(P.detail("M42,90 l6,-6 M84,60 l-4,6", "stone", 0.6))
    return J(b), e


def relic_coin(P):
    b = [P.shape(ell(70, 70, 40, 38), "bronze", s=2, fill_override=PAL["bronze"][2]), P.shape(ell(64, 64, 40, 38), "gold", s=6)]
    b.append(lin(ell(64, 64, 33, 31), INK, 1.4, 0.8))
    b.append(lin(" ".join(f"M{64+36*math.cos(a):.1f},{64+34*math.sin(a):.1f} L{64+33*math.cos(a):.1f},{64+31*math.sin(a):.1f}" for a in [i * math.tau / 40 for i in range(40)]), INK, 0.8, 0.7))
    crown = poly([(46, 70), (46, 52), (54, 60), (64, 46), (74, 60), (82, 52), (82, 70)])
    b.append(P.shape(crown, "gold", s=2, lw=2.4))
    b.append(lin("M46,78 L82,78", INK, 2))
    rnd = random.Random(6)
    b.append(fill(" ".join(blob(64 + rnd.uniform(-30, 30), 64 + rnd.uniform(-30, 30), rnd.uniform(4, 8), 5, 0.3, i) for i in range(5)), "#5e8e7a", 0.7))
    return J(b), ""


def relic_map(P):
    sheet = poly([(18, 30), (52, 22), (78, 32), (110, 24), (110, 100), (78, 108), (52, 98), (18, 106)])
    b = [P.shape(sheet, "paper", s=5)]
    b.append(fill(poly([(52, 22), (78, 32), (78, 108), (52, 98)]), PAL["paper"][2], 0.35))
    b.append(P.detail("M52,22 L52,98 M78,32 L78,108", "paper", 0.8))
    b.append(f'<path d="M28,90 Q40,70 56,74 Q72,80 74,58 Q78,40 96,44" fill="none" stroke="{RUB}" stroke-width="2.2" stroke-dasharray="4 3"/>')
    b.append(lin("M92,38 l8,8 M100,38 l-8,8", RUB, 3))
    b.append(lin("M28,40 q6,-4 12,0 q6,4 12,0 M84,80 l6,-10 l6,10 M90,90 l6,-10 l6,10", INK, 1.4, 0.8))
    b.append(fill(ell(30, 98, 8, 5), SOOT_C, 0.3))
    return J(b), ""


SOOT_C = ST["soot"]


def relic_crown_shard(P):
    sh = poly([(18, 92), (24, 56), (40, 72), (54, 34), (68, 66), (80, 56), (88, 70), (78, 84), (92, 96), (60, 104)])
    b = [P.shape(sh, "gold", s=7)]
    b.append(P.detail("M22,84 L86,92", "gold", 0.9))
    b.append(P.shape(ell(54, 82, 8, 7), "gem", s=2))
    b.append(P.shape(ell(30, 82, 4.5), "ice", s=1))
    b.append(fill(ell(52, 79, 2.6, 1.8), "#ffffff", 0.7))
    b.append(lin("M88,70 l-6,4 l4,6 l-6,4 M92,96 l-5,-2", INK, 1.6))
    return J(b), glow(P, 54, 82, 18, EMBER, 0.35)


def ale_mug(P):
    body = rect(30, 38, 54, 72, 6)
    b = [P.shape(smooth([(82, 50), (106, 52), (108, 84), (82, 94)], close=False) + " L82,86 Q98,82 98,70 Q98,60 82,58 Z", "wood", s=2)]
    b.append(planks(P, 30, 38, 54, 72, "wood", n=4, dirn="v", s=4, nails=False, seed=3) if False else P.shape(body, "wood", s=6))
    b.append(P.detail("M43,40 L43,108 M57,40 L57,108 M71,40 L71,108", "wood", 0.6))
    for y in (50, 96):
        b.append(P.shape(rect(28, y, 58, 6, 2), "darkiron", s=1))
    b.append(P.shape(smooth([(26, 40), (34, 26), (50, 30), (60, 20), (76, 28), (88, 36), (82, 46), (60, 44), (34, 46)]), "linen", s=2, fill_override="#f6f0e0"))
    b.append(fill(ell(76, 46, 4, 6), "#f6f0e0"))
    return J(b), ""


def bread_cheese(P):
    loaf = smooth([(14, 72), (24, 50), (52, 40), (78, 48), (84, 70), (70, 86), (34, 88)])
    b = [P.shape(loaf, "apron", s=7)]
    b.append(P.detail("M34,52 l8,14 M50,46 l8,14 M64,48 l8,14", "apron", 0.9))
    wedge = poly([(58, 86), (112, 70), (112, 96), (60, 108)])
    top = poly([(58, 86), (112, 70), (96, 64)])
    b.append(P.shape(wedge, "straw", s=3))
    b.append(P.shape(top, "straw", s=1, fill_override=PAL["straw"][0]))
    b.append(fill(" ".join(ell(x, y, r) for x, y, r in [(76, 92, 3.5), (96, 86, 2.5), (100, 96, 3), (86, 100, 2)]), PAL["straw"][2], 0.8))
    return J(b), ""


# ------------------------------------------------------------- containers
def bag_traveller(P):
    body = smooth([(30, 46), (64, 38), (98, 46), (106, 82), (98, 112), (64, 116), (30, 112), (22, 82)])
    b = [lin("M40,46 Q64,6 88,46", INK, 6.4), lin("M40,46 Q64,6 88,46", PAL["strap"][1], 4)]
    b.append(P.shape(body, "leather", s=8))
    b.append(P.shape(smooth([(28, 50), (64, 42), (100, 50), (96, 74), (64, 80), (32, 74)]), "hide", s=3))
    b.append(P.shape(rect(58, 66, 12, 16, 2), "bronze", s=1.5))
    b.append(P.shape(rect(36, 88, 56, 20, 4), "leather", s=2))
    b.append(P.detail("M30,100 Q64,108 98,100", "leather", 0.6))
    return J(b), ""


def shipment_miner(P):
    b = []
    top = poly([(20, 50), (84, 40), (108, 52), (44, 64)])
    front = poly([(44, 64), (108, 52), (106, 100), (44, 112)])
    side = poly([(20, 50), (44, 64), (44, 112), (20, 96)])
    b.append(P.shape(side, "wood", s=2, fill_override=PAL["wood"][2]))
    b.append(P.shape(front, "wood", s=3))
    b.append(P.detail("M44,80 L108,70 M44,96 L106,86", "wood", 0.7))
    b.append(lin("M44,64 L106,100 M108,52 L44,112", INK, 1.2, 0.6))
    b.append(P.shape(top, "wood", s=1, fill_override=PAL["wood"][0]))
    for i, (x, y) in enumerate([(50, 48), (66, 50), (58, 42), (78, 46)]):
        b.append(P.shape(blob(x, y, 8, 5, 0.2, i), "stone", s=1.5))
        b.append(lin(f"M{x-4},{y} l4,-2 l4,2", "#a8502c", 1.6))
    b.append(lin("M70,40 L96,10", INK, 4.6))
    b.append(lin("M70,40 L96,10", PAL["wood"][1], 2.6))
    b.append(P.shape(smooth([(80, 6), (96, 8), (112, 18), (98, 14), (88, 14)]), "darkiron", s=1))
    return J(b), ""


def satchel_relic(P):
    body = rect(22, 50, 84, 60, 8)
    b = [lin("M28,54 Q64,4 100,54", INK, 6.4), lin("M28,54 Q64,4 100,54", PAL["strap"][1], 4)]
    b.append(P.shape(body, "leather", s=7))
    b.append(P.shape(smooth([(20, 50), (108, 50), (104, 84), (64, 92), (24, 84)]), "brown", s=4))
    b.append(f'<path d="{smooth([(26, 54), (102, 54), (99, 80), (64, 87), (29, 80)])}" fill="none" stroke="#e8c8a0" stroke-width="1" stroke-dasharray="3 2.4" opacity="0.8"/>')
    b.append(P.shape(rect(56, 78, 16, 14, 3), "bronze", s=1.5))
    b.append(P.shape(ell(64, 66, 8), "gold", s=1.5))
    b.append(lin("M60,66 l4,-5 l4,5 l-4,5 Z", INK, 1.2))
    return J(b), ""


def purse_gift(P):
    body = smooth([(48, 46), (80, 46), (100, 70), (104, 96), (88, 112), (40, 112), (24, 96), (28, 70)])
    b = [P.shape(body, "cloth", s=8)]
    b.append(P.shape(smooth([(46, 46), (40, 30), (52, 22), (64, 30), (76, 22), (88, 30), (82, 46)]), "cloth", s=3))
    b.append(P.shape(rect(42, 42, 44, 8, 3), "gold", s=1.5))
    b.append(P.shape(smooth([(64, 46), (50, 58), (46, 70), (56, 62)]) + " " + smooth([(64, 46), (78, 58), (82, 70), (72, 62)]), "gold", s=1))
    b.append(P.detail("M40,70 Q64,82 88,70 M36,92 Q64,104 92,92", "cloth", 0.6))
    b.append(P.shape(ell(92, 104, 9), "gold", s=1.5))
    return J(b), ""


def chest_recovered(P):
    top = smooth([(18, 56), (24, 38), (64, 28), (104, 38), (110, 56)], close=False) + " Z"
    front = rect(18, 56, 92, 52, 4)
    b = [P.shape(front, "wood", s=6), P.shape(top, "wood", s=3, fill_override=PAL["wood"][0])]
    b.append(P.detail("M18,76 L110,76 M18,92 L110,92", "wood", 0.7))
    for x in (30, 98):
        b.append(P.shape(rect(x - 5, 34, 10, 74, 2), "darkiron", s=1.5))
    b.append(P.shape(rect(54, 50, 20, 22, 3), "bronze", s=2))
    b.append(fill(rect(62, 58, 4, 8), INK))
    rnd = random.Random(5)
    b.append(fill(" ".join(blob(18 + rnd.uniform(0, 92), 92 + rnd.uniform(0, 16), rnd.uniform(4, 9), 5, 0.3, i) for i in range(5)), "#6e7e4a", 0.8))
    b.append(fill(" ".join(blob(rnd.uniform(24, 100), rnd.uniform(36, 48), rnd.uniform(3, 6), 5, 0.3, i) for i in range(3)), "#6e7e4a", 0.7))
    return J(b), ""


def package_reward(P):
    top = poly([(20, 52), (78, 36), (110, 52), (52, 70)])
    front = poly([(52, 70), (110, 52), (108, 98), (52, 114)])
    side = poly([(20, 52), (52, 70), (52, 114), (22, 96)])
    b = [P.shape(side, "paper", s=2, fill_override=PAL["burlap"][2] if "burlap" in PAL else PAL["paper"][2]),
         P.shape(front, "paper", s=3, fill_override=PAL["burlap"][1] if "burlap" in PAL else PAL["paper"][1]),
         P.shape(top, "paper", s=1, fill_override=PAL["burlap"][0] if "burlap" in PAL else PAL["paper"][0])]
    tw = "M36,61 L94,44 M50,44 L80,62 M80,62 L80,106 M36,61 L36,104"
    b.append(lin(tw, INK, 4))
    b.append(lin(tw, "#efe2c0", 2))
    b.append(P.shape(ell(66, 53, 10, 7), "cloth", s=1.5))
    b.append(lin("M62,52 l4,-3 l4,3", "#e8b48a", 1.2))
    return J(b), ""


# ------------------------------------------------------------- unique / set
def grimhold(P):
    b = [P.shape(rect(58, 40, 12, 80, 4), "darkiron", s=2), P.shape(rect(57, 92, 14, 24, 3), "cloth", s=1.5),
         P.detail(" ".join(f"M58,{96+i*5} L70,{99+i*5}" for i in range(4)), "cloth", 0.6), P.shape(ell(64, 120, 6), "gold", s=1)]
    head = poly([(20, 22), (108, 22), (114, 30), (114, 54), (108, 62), (20, 62), (14, 54), (14, 30)])
    b.append(P.shape(head, "obsidian", s=7))
    b.append(P.shape(rect(50, 18, 28, 48, 4), "darkiron", s=3))
    b.append(P.shape(rect(52, 20, 24, 6, 2), "gold", s=1))
    b.append(P.shape(rect(52, 58, 24, 6, 2), "gold", s=1))
    b.append(fill(poly([(18, 28), (34, 26), (34, 32), (18, 34)]), "#ffffff", 0.18))
    rnd = random.Random(12)
    d = " ".join(rune_glyphs(rnd, x, 42, 6) for x in (28, 100)) + " " + rune_glyphs(rnd, 64, 42, 8)
    e = lit_marks(P, d, EMBER, EMBER_HOT, w=1.6, glow_w=6, op=1.0, blur=2.2) + glow(P, 64, 42, 60, EMBER, 0.3)
    b.append(P.detail("M20,40 l6,4 M104,54 l6,-4 M40,60 l4,-4", "obsidian", 0.6))
    return rot(J(b), 30), rot(e, 30)


def wyvernscale_pauldron(P):
    PAL.setdefault("wyvern", ("#a8c49a", "#5e8a5a", "#28402a"))
    shell = smooth([(16, 84), (20, 50), (44, 24), (78, 18), (108, 32), (116, 62), (102, 76), (64, 70), (34, 84)])
    b = [P.shape(shell, "wyvern", s=8)]
    cid = "wy_clip"
    P.defs.append(f'<clipPath id="{cid}"><path d="{shell}"/></clipPath>')
    sc = []
    for row, y in enumerate(range(24, 90, 9)):
        for x in range(10 + (row % 2) * 7, 124, 14):
            sc.append(f"M{x-7},{y} Q{x},{y+10} {x+7},{y}")
    b.append(f'<g clip-path="url(#{cid})">' + lin(" ".join(sc), INK, 1.2, 0.8) + lin(" ".join(sc).replace("M", "M").replace("Q", "Q"), "#cce0bc", 0.6, 0.35) + "</g>")
    b.append(P.shape(smooth([(12, 88), (34, 80), (64, 72), (104, 78), (110, 96), (64, 92), (24, 104)]), "metal", s=3))
    b.append(fill(" ".join(ell(x, y, 2.4) for x, y in [(30, 92), (64, 86), (98, 90)]), PAL["gold"][1]))
    b.append(lin(" ".join(ell(x, y, 2.4) for x, y in [(30, 92), (64, 86), (98, 90)]), INK, 0.8))
    b.append(P.shape(poly([(82, 20), (100, 4), (96, 26)]), "bone", s=1) if "bone" in PAL else P.shape(poly([(82, 20), (100, 4), (96, 26)]), "linen", s=1))
    b.append(P.shape(rect(46, 100, 36, 14, 3), "strap", s=1.5))
    return J(b), ""


# ------------------------------------------------------------- small UI icons (32x32, 128 design)
def star(P):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 54 if i % 2 == 0 else 23
        pts.append((64 + math.cos(a) * r, 68 + math.sin(a) * r))
    b = P.shape(poly(pts), "gold", s=8, lw=4.5, fill_override="#e8a040")
    b += fill(poly([(64, 20), (72, 52), (64, 60), (56, 52)]), "#ffe2a0", 0.7)
    return b, glow(P, 64, 66, 60, EMBER, 0.35)


def gold(P):
    b = []
    for i, y in enumerate((96, 84, 72, 60, 48)):
        x = 60 + (i % 2) * 6 - 2
        b.append(P.shape(ell(x, y + 8, 36, 12), "gold", s=1, fill_override=PAL["gold"][2]))
        b.append(P.shape(ell(x, y, 36, 12), "gold", s=3))
    b.append(lin(ell(62, 48, 26, 8), INK, 2, 0.7))
    b.append(P.shape(ell(98, 104, 22, 8), "gold", s=1, fill_override=PAL["gold"][2]))
    b.append(P.shape(ell(98, 98, 22, 8), "gold", s=2))
    b.append(fill(ell(50, 44, 10, 3), "#fff2c0", 0.7))
    return J(b), ""


def lock(P):
    b = [lin("M40,60 L40,40 A24,24 0 0,1 88,40 L88,60", INK, 20), lin("M40,60 L40,40 A24,24 0 0,1 88,40 L88,60", PAL["darkiron"][1], 12)]
    b.append(P.shape(rect(24, 56, 80, 62, 8), "darkiron", s=6, lw=5))
    b.append(fill(ell(64, 80, 8) + " " + poly([(60, 84), (68, 84), (71, 104), (57, 104)]), "#120c08"))
    b.append(fill(" ".join(ell(x, y, 3) for x, y in [(34, 66), (94, 66), (34, 108), (94, 108)]), PAL["metal"][0]))
    return J(b), ""


ICONS = {k: v for k, v in globals().items() if callable(v)}


SCALE = dict(ring_silver=1.3, mace_flanged=1.12, dagger=1.15, herb_emberleaf=1.12, herb_moonwort=1.12, axe_hand=1.08,
             amulet_silver=1.08, runestone_blank=1.1, runestone_ember=1.1, runestone_ward=1.1, runestone_frost=1.1)


def build(name, fn, size, lw_mul):
    P = painter(scale=1.25, lw_mul=lw_mul)
    body, emit = fn(P)
    k = SCALE.get(name)
    if k:
        t = f'transform="translate(64,64) scale({k}) translate(-64,-64)"'
        body, emit = f"<g {t}>{body}</g>", f"<g {t}>{emit}</g>"
    f = ink_filter(P, wob=1.4, dil=1.6 if size == 64 else 2.6, grain=0.5, soot=0.7)
    inner = f'<g {f}>{body}</g><g>{emit}</g>'
    ss = 4 if size == 64 else 4
    return svg_doc(size, size, P, inner, ss=ss, vw=128, vh=128), ss


def jobs():
    only = only_filter()
    js = []
    seen = set()
    for it in load("items.json"):
        ic = it["icon"]
        if ic in seen or (only and ic not in only):
            continue
        seen.add(ic)
        svg, ss = build(ic, ICONS[ic], 64, 0.95)
        js.append(dict(name=f"ic_{ic}", svg=svg, w=64, h=64, ss=ss, out=os.path.join(SPR, "icons", ic + ".png")))
    for ic in ("star", "gold", "lock"):
        if only and ic not in only:
            continue
        svg, ss = build(ic, ICONS[ic], 32, 1.6)
        js.append(dict(name=f"ic_{ic}", svg=svg, w=32, h=32, ss=ss, out=os.path.join(SPR, "icons", ic + ".png")))
    return js


if __name__ == "__main__":
    render(jobs())
