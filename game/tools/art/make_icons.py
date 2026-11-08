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
def blade_sword(P, role="metal", guard="bronze", grip="leather", L=1.0, runes=None, pommel_gem=False, nicks=False,
                guard_gem=None, guard_shape="std"):
    """Vertical sword (tip up) centred on x=64, rotated 45deg by caller."""
    b, e = [], []
    top, gy = 8 + (1 - L) * 60, 86
    b.append(P.shape(poly([(57, gy), (71, gy), (70.5, top + 14), (64, top), (57.5, top + 14)]), role, s=3))
    b.append(P.detail(f"M64,{gy-3} L64,{top+16}", role, 0.9, 0.85))
    b.append(fill(poly([(59.5, gy - 4), (62.5, gy - 4), (62.5, top + 16), (60, top + 18)]), "#ffffff", 0.35))
    if nicks:
        b.append(P.detail(f"M70.5,{top+30} l-2,1.5 M57.5,{top+44} l2,1", role, 0.6))
    if guard_shape == "down":   # ancient down-swept quillons
        b.append(P.shape(smooth([(40, gy + 12), (46, gy + 1), (64, gy - 2), (82, gy + 1), (88, gy + 12), (80, gy + 7), (64, gy + 6), (48, gy + 7)]), guard, s=2))
    else:
        b.append(P.shape(smooth([(38, gy + 2), (50, gy - 3), (64, gy - 1), (78, gy - 3), (90, gy + 2), (78, gy + 7), (64, gy + 6), (50, gy + 7)]), guard, s=2))
    if guard_gem:
        b.append(P.shape(ell(64, gy + 2.5, 5, 4.5), guard_gem, s=1.2, lw=1.4))
        b.append(fill(ell(62.5, gy + 1, 1.6, 1.1), "#ffffff", 0.75))
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


def boot(P, x, y, flip=1, role="boot", cuff="leather"):
    s = smooth([(x, y), (x + 22 * flip, y), (x + 22 * flip, y + 46), (x + 30 * flip, y + 58), (x + 34 * flip, y + 68), (x + 30 * flip, y + 74),
                (x - 2 * flip, y + 74), (x - 3 * flip, y + 40)])
    return J([P.shape(s, role, s=4), P.shape(rect(min(x, x + 24 * flip) - 1, y - 4, 26, 10, 3), cuff, s=1.5),
              P.detail(f"M{x+2*flip},{y+70} L{x+30*flip},{y+70}", role, 0.8),
              P.detail(f"M{x+6*flip},{y+20} l{10*flip},3 M{x+6*flip},{y+30} l{10*flip},3", role, 0.6)])


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


# ------------------------------------------------------------- gems, rare metals, unidentified relics (expansion)
PAL.setdefault("garnet", ("#e87a6a", "#9c1e1e", "#3e0608"))
PAL.setdefault("sapphire", ("#8ab4ec", "#2a54a8", "#0e1a48"))
PAL.setdefault("moonstone", ("#fbfaff", "#dcdcec", "#8a86a8"))
PAL.setdefault("starstone", ("#6a6a8c", "#2c2a44", "#100e1c"))
PAL.setdefault("starmetal", ("#9a9cac", "#4c4e60", "#1c1c28"))
PAL.setdefault("adamant_dark", ("#6c8276", "#34463c", "#121c16"))
PAL.setdefault("rust", ("#c8946a", "#8a4e2a", "#43200e"))
PAL.setdefault("ranger", ("#b4ae7c", "#76704a", "#3a3620"))
PAL.setdefault("ranger_cuff", ("#a8b48a", "#6a7a4e", "#34401e"))
VERDIGRIS = "#6aa088"
STARLIGHT = "#dfe6ff"


def ngon(cx, cy, rx, ry, n=8, a0=-math.pi / 8):
    return [(cx + math.cos(a0 + i * math.tau / n) * rx, cy + math.sin(a0 + i * math.tau / n) * ry) for i in range(n)]


def sparkle(x, y, r, k=0.22):
    """4-point star (path data)."""
    return poly([(x, y - r), (x + r * k, y - r * k), (x + r, y), (x + r * k, y + r * k), (x, y + r), (x - r * k, y + r * k),
                 (x - r, y), (x - r * k, y - r * k)])


def cut_gem(P, role, cx=64, cy=66, rx=40, ry=34, n=8, table=0.52, glint=EMBER_HOT, glow_c=None):
    """Faceted gem seen from above: girdle outline, table, star facets, lit glint (emit)."""
    l, b_, s = PAL[role]
    out = ngon(cx, cy, rx, ry, n)
    tab = ngon(cx - rx * 0.04, cy - ry * 0.06, rx * table, ry * table, n)
    b = [P.shape(poly(out), role, s=6, lw=3.6)]
    for i in range(n):
        j = (i + 1) % n
        tri = poly([out[i], out[j], tab[j], tab[i]])
        ang = math.atan2((out[i][1] + out[j][1]) / 2 - cy, (out[i][0] + out[j][0]) / 2 - cx)
        lite = -math.cos(ang + math.pi * 0.75)          # light from top-left
        col = l if lite > 0.35 else (s if lite < -0.35 else b_)
        b.append(fill(tri, col, 0.55))
    b.append(fill(poly(tab), l, 0.45))
    facets = " ".join(f"M{out[i][0]:.1f},{out[i][1]:.1f} L{tab[i][0]:.1f},{tab[i][1]:.1f}" for i in range(n))
    b.append(lin(facets + " " + poly(tab), INK, 1.3, 0.8))
    b.append(fill(poly([tab[n - 3], tab[n - 2], ((tab[n - 2][0] + tab[0][0]) / 2, (tab[n - 2][1] + tab[0][1]) / 2 + 6)]), "#ffffff", 0.5))
    gx, gy = cx - rx * 0.32, cy - ry * 0.34
    e = [glow(P, cx, cy, max(rx, ry) * 1.15, glow_c or PAL[role][1], 0.28),
         glow(P, gx, gy, 12, glint, 0.8), fill(sparkle(gx, gy, 9), "#ffffff", 0.95)]
    return J(b), J(e)


def gem_garnet(P):
    return cut_gem(P, "garnet", rx=40, ry=36, n=8, glint=EMBER_HOT, glow_c=EMBER)


def gem_sapphire(P):
    return cut_gem(P, "sapphire", rx=32, ry=44, n=10, table=0.5, glint="#cfe4ff", glow_c="#5a8ad8")


def gem_moonstone(P):
    d = wobbly_ell(64, 68, 40, 34, 3, 0.02)
    b = [P.shape(ell(66, 82, 40, 12), "slate", s=1, fill_override=PAL["moonstone"][2], hl=False),
         P.shape(d, "moonstone", s=5, lw=3.6)]
    b.append(fill(smooth([(40, 80), (58, 70), (82, 72), (98, 66), (94, 84), (70, 94), (46, 92)]), "#b8a8e8", 0.55))
    b.append(fill(ell(56, 58, 20, 12), "#ffffff", 0.6))
    b.append(lin("M36,62 Q46,42 70,40", "#ffffff", 3, 0.8))
    e = [glow(P, 70, 80, 32, VIOLET, 0.6, rx=34, ry=18), glow(P, 84, 62, 16, "#9cc4ff", 0.5),
         fill(smooth([(50, 84), (68, 78), (90, 76), (78, 88), (60, 90)]), VIOLET_HOT, 0.45), glow(P, 64, 68, 52, "#d8d0ff", 0.25)]
    return J(b), J(e)


def gem_starstone(P):
    d = poly(ngon(64, 66, 42, 38, 7, -0.3))
    b = [P.shape(d, "starstone", s=6, lw=3.6)]
    b.append(P.detail("M40,52 L58,60 L86,50 M58,60 L62,92 M58,60 L34,78", "starstone", 0.8, 0.8))
    b.append(fill(ell(50, 48, 12, 5), "#c8ccff", 0.25))
    rnd = random.Random(7)
    pts = [(rnd.uniform(36, 92), rnd.uniform(40, 92)) for _ in range(11)]
    e = [glow(P, 64, 66, 52, "#6a70c8", 0.35), glow(P, 64, 66, 24, STARLIGHT, 0.3)]
    e.append(fill(" ".join(ell(x, y, rnd.uniform(1.1, 1.8)) for x, y in pts), "#f4f6ff", 0.95))
    for x, y, r in [(70, 62, 12), (48, 78, 7), (84, 80, 6)]:
        e.append(glow(P, x, y, r * 1.4, STARLIGHT, 0.7) + fill(sparkle(x, y, r, 0.18), "#ffffff", 1.0))
    return J(b), J(e)


def ingot_adamantine(P):
    b, e = ingot(P, "adamant_dark")
    veins = "M34,52 l10,3 l6,-4 l10,4 M52,62 l12,-6 l8,3 M72,48 l8,4 l10,-3 M50,74 l10,-3 l6,4 l12,-5 l8,2 M90,66 l10,-4"
    b += lin(veins, INK, 2.2, 0.7)
    e = (glow(P, 66, 62, 44, VIOLET, 0.32) + lit_marks(P, veins, VIOLET, VIOLET_HOT, w=1.1, glow_w=4, op=0.95, blur=1.8))
    return b, e


def starmetal_fragment(P):
    sh = poly([(30, 84), (24, 62), (40, 46), (52, 22), (64, 38), (84, 28), (100, 50), (94, 66), (106, 84), (78, 100), (58, 94), (42, 104)])
    b = [P.shape(sh, "starmetal", s=7, lw=3.6)]
    b.append(P.detail("M40,46 L60,62 L84,28 M60,62 L58,94 M60,62 L94,66 M30,84 L60,62", "starmetal", 0.9, 0.85))
    b.append(fill(poly([(52, 24), (60, 58), (42, 48)]) + " " + poly([(84, 30), (96, 50), (64, 58)]), PAL["starmetal"][0], 0.55))
    rnd = random.Random(4)
    b.append(fill(" ".join(ell(rnd.uniform(40, 92), rnd.uniform(60, 92), rnd.uniform(1.4, 2.6)) for _ in range(8)), INK, 0.55))
    e = [glow(P, 64, 64, 46, "#8a9ccc", 0.25)]
    for x, y, r in [(56, 34, 9), (88, 44, 6), (74, 80, 5), (40, 70, 4)]:
        e.append(glow(P, x, y, r * 1.3, STARLIGHT, 0.6) + fill(sparkle(x, y, r, 0.18), "#ffffff", 0.95))
    return J(b), J(e)


def unknown_tag(P, x, y, ang=-12, sx=None, sy=None):
    """Parchment tag with a rubric '?' tied by a cord: the 'unidentified' cue shared by relic_unknown_*."""
    o = []
    if sx is not None:
        o.append(lin(f"M{sx},{sy} Q{(sx + x) / 2},{max(sy, y) + 6} {x - 9},{y}", INK, 2.4))
        o.append(lin(f"M{sx},{sy} Q{(sx + x) / 2},{max(sy, y) + 6} {x - 9},{y}", "#efe2c0", 1.1))
    t = poly([(x - 12, y - 4), (x - 6, y - 12), (x + 14, y - 12), (x + 14, y + 12), (x - 6, y + 12), (x - 12, y + 4)])
    g = [P.shape(t, "paper", s=2, lw=2.6), fill(ell(x - 6, y, 2), INK, 0.9)]
    q = f"M{x-1},{y-4.5} q0,-4.5 4.5,-4.5 q4.5,0 4.5,4 q0,3 -4.5,4.5 l0,3"
    g.append(lin(q, RUB, 2.8))
    g.append(fill(ell(x + 3.5, y + 8, 1.7), RUB))
    o.append(f'<g transform="rotate({ang} {x} {y})">' + J(g) + "</g>")
    return J(o)


def crust(rnd, n, x0, x1, y0, y1, r0, r1, seed):
    return " ".join(blob(rnd.uniform(x0, x1), rnd.uniform(y0, y1), rnd.uniform(r0, r1), 5, 0.3, seed + i) for i in range(n))


def relic_unknown_arms(P):
    # a second, broken blade behind, crossed
    back = [P.shape(poly([(58, 24), (70, 22), (72, 92), (56, 94)]), "rust", s=3),
            P.shape(rect(52, 88, 24, 8, 3), "rust", s=1.5)]
    b, _ = blade_sword(P, "rust", "rust", "rust", nicks=True)
    rnd = random.Random(9)
    cr = crust(rnd, 6, 54, 74, 22, 80, 3, 6, 20)
    vg = crust(rnd, 5, 52, 76, 30, 96, 3, 6, 40)
    b += fill(cr, PAL["rust"][2], 0.75) + fill(vg, VERDIGRIS, 0.85) + lin(vg, INK, 0.8, 0.6)
    b += P.detail("M58,40 l6,3 l4,-2 M60,62 l5,2 M57,30 l3,4", "rust", 0.7)
    back_s = rot(J(back) + fill(crust(rnd, 4, 56, 72, 30, 80, 3, 5, 60), VERDIGRIS, 0.8), -40)
    wrap = P.shape(poly([(46, 70), (82, 58), (86, 70), (50, 82)]), "burlap", s=2, lw=2.4)
    wrap += P.detail("M54,68 L58,79 M66,64 L70,75 M76,61 L80,72", "burlap", 0.7)
    body = back_s + rot(b, 45) + wrap + unknown_tag(P, 98, 98, -10, 82, 68)
    return body, ""


def relic_unknown_tablet(P):
    front = poly([(26, 30), (52, 18), (96, 24), (104, 46), (100, 96), (90, 108), (40, 112), (28, 98), (24, 60)])
    side = poly([(96, 24), (106, 30), (112, 52), (108, 100), (98, 114), (90, 108), (100, 96), (104, 46)])
    b = [P.shape(side, "slate", s=2, fill_override=PAL["slate"][2]), P.shape(front, "slate", s=7, lw=3.6)]
    rnd = random.Random(14)
    runes = " ".join(rune_glyphs(rnd, x, y, 5.5) for y in (42, 62, 82) for x in (42, 58, 74, 88) if not (x == 88 and y == 82))
    b.append(lin(runes, "#e4e4dc", 2.6, 0.45, extra='transform="translate(0.9,1.1)"'))
    b.append(lin(runes, INK, 2.2, 0.7))
    b.append(lin("M52,18 L56,34 L48,50 L54,66 M96,58 L84,68 L88,84 L78,98 M24,60 L36,66", INK, 2.0, 0.95))
    b.append(fill(crust(rnd, 6, 28, 98, 24, 108, 3, 6, 70), "#7a8a5a", 0.55))
    b.append(P.detail("M30,96 l8,4 M70,104 l10,-2", "slate", 0.6))
    e = glow(P, 64, 62, 34, RUNE_GOLD, 0.18) + lin(runes, RUNE_GOLD, 0.8, 0.35)
    return J(b) + unknown_tag(P, 100, 100, 8, 92, 86), e


def relic_unknown_reliquary(P):
    """Small gabled shrine-box of bronze, crusted with verdigris, sealed with wax."""
    side = poly([(94, 58), (106, 52), (106, 96), (94, 104)])
    roof_side = poly([(64, 26), (76, 22), (110, 50), (98, 58)])
    box = rect(30, 58, 64, 46, 3)
    roof = poly([(24, 62), (64, 26), (100, 60)])
    b = [P.shape(side, "bronze", s=2, fill_override=PAL["bronze"][2]), P.shape(roof_side, "bronze", s=2, fill_override=PAL["bronze"][1]),
         P.shape(box, "bronze", s=5, lw=3.4), P.shape(roof, "bronze", s=3, fill_override=PAL["bronze"][0], lw=3.4)]
    for x in (28, 96):                       # feet
        b.append(P.shape(rect(x, 102, 10, 8, 2), "bronze", s=1, fill_override=PAL["bronze"][2]))
    b.append(P.shape(rect(26, 58, 72, 6, 2), "gold", s=1))           # lid seam band
    b.append(lin("M64,26 L64,10", INK, 5))                           # finial: spike + orb
    b.append(lin("M64,26 L64,10", PAL["gold"][1], 2.6))
    b.append(P.shape(ell(64, 18, 5), "gold", s=1, lw=2))
    b.append(lin("M40,72 L84,72 L84,98 L40,98 Z", INK, 1.4, 0.6))   # engraved panel
    b.append(lin("M62,76 L72,85 L62,94 L52,85 Z M62,81 L62,89", INK, 1.6, 0.5))
    pins = [(36, 68), (88, 68), (36, 98), (88, 98)]
    b.append(fill(" ".join(ell(x, y, 2.4) for x, y in pins), PAL["gold"][0]))
    b.append(lin(" ".join(ell(x, y, 2.4) for x, y in pins), INK, 0.8))
    rnd = random.Random(21)
    vg = crust(rnd, 8, 30, 96, 36, 104, 3.5, 6.5, 80)
    b.append(fill(vg, VERDIGRIS, 0.85))
    b.append(lin(vg, INK, 0.8, 0.5))
    b.append(fill(poly([(34, 58), (64, 30), (64, 38), (42, 58)]), "#ffffff", 0.2))
    # wax seal across the lid seam
    b.append(P.shape(wobbly_ell(64, 62, 10, 9, 2, 0.12), "garnet", s=1.5, lw=2.4))
    b.append(lin("M60,62 l4,-4 l4,4 l-4,4 Z", "#e87a6a", 1.1, 0.9))
    b.append(lin("M58,70 l-2,8 M70,70 l2,7", "#9c1e1e", 2.4, 0.9))
    return J(b) + unknown_tag(P, 100, 104, -8, 104, 90), ""


def recipe_scroll(P):
    body = rect(24, 50, 78, 30, 4)
    b = [P.shape(body, "paper", s=5, lw=3.4)]
    b.append(P.shape(ell(102, 65, 9, 15), "paper", s=2, fill_override=PAL["paper"][0]))
    b.append(lin("M102,65 m-1,0 a2,3 0 1,1 3,1 a4,6 0 1,1 -6,-3 a6,10 0 1,1 9,6", INK, 1.2, 0.8))
    b.append(P.detail("M30,58 L96,58 M30,72 L96,72", "paper", 0.5, 0.6))
    # loose curl of the unrolled end
    b.append(P.shape(smooth([(24, 50), (14, 54), (12, 66), (18, 78), (24, 80)], close=False) + " Z", "paper", s=2, fill_override=PAL["paper"][2]))
    # faded ink lines peeking on the flap
    b.append(lin("M40,62 l18,0 M62,62 l14,0 M40,68 l26,0", RUB, 1.0, 0.5))
    # cord + wax seal with ribbon tails
    b.append(lin("M60,48 L60,82", INK, 4.4))
    b.append(lin("M60,48 L60,82", "#b89060", 2.2))
    b.append(P.shape(smooth([(56, 82), (52, 108), (58, 104), (60, 94)]) + " " + smooth([(64, 82), (72, 106), (66, 104), (62, 94)]), "cloth", s=1.5, lw=2.4))
    b.append(P.shape(wobbly_ell(60, 84, 12, 11, 4, 0.1), "garnet", s=3, lw=2.8))
    b.append(lin(wobbly_ell(60, 84, 7.5, 7, 4, 0.06), "#3e0608", 1.4, 0.8))
    b.append(lin("M56,86 l4,-6 l4,6 M57,84 l6,0", "#3e0608", 1.4, 0.9))
    b.append(fill(ell(56, 79, 2.6, 1.6), "#ffffff", 0.55))
    return rot(J(b), -18), ""


def coating_frost(P):
    b, e = potion(P, "ice", FROST, "tall")
    flake = "M64,78 L64,104 M53,84 L75,98 M75,84 L53,98 M60,80 l4,3 l4,-3 M60,102 l4,-3 l4,3"
    e += lit_marks(P, flake, "#7cc8ec", "#f4fcff", w=1.4, glow_w=4, op=0.95)
    b += fill(" ".join(ell(x, y, 2) for x, y in [(52, 30), (76, 32), (50, 46)]), "#f4fcff", 0.9)
    return b, e


def ring_garnet(P):
    b = [P.shape(ell(64, 74, 38, 30) + " " + ell(64, 70, 27, 20), "gold", s=4).replace('<path d="', '<path fill-rule="evenodd" d="')]
    b.append(lin(ell(64, 72, 32, 25), "#fff2c0", 1.2, 0.6))
    b.append(P.shape(smooth([(46, 46), (54, 36), (74, 36), (82, 46), (74, 52), (54, 52)]), "gold", s=2))
    for x, y in [(50, 30), (78, 30), (52, 48), (76, 48)]:
        b.append(P.shape(ell(x, y, 3.2), "gold", s=0.6, lw=1.6))
    gb, ge = cut_gem(P, "garnet", 64, 38, 15, 13, 8, 0.5, EMBER_HOT, EMBER)
    b.append(gb)
    b.append(fill(ell(44, 58, 6, 3), "#ffffff", 0.6))
    return J(b), ge


def amulet_sapphire(P):
    beads = []
    for i in range(26):
        t = i / 25
        x = (1 - t) ** 2 * 26 + 2 * (1 - t) * t * 64 + t * t * 102
        y = (1 - t) ** 2 * 14 + 2 * (1 - t) * t * 104 + t * t * 14
        beads.append(ell(x, y, 2.6, 2.0))
    chain = " ".join(beads)
    b = [lin(chain, INK, 1.4), lin(chain, PAL["gold"][1], 0.8)]
    drop = smooth([(64, 58), (82, 74), (86, 94), (76, 110), (64, 114), (52, 110), (42, 94), (46, 74)])
    b.append(P.shape(drop, "gold", s=4))
    b.append(lin(" ".join(ell(64 + 19 * math.cos(a), 92 + 19 * math.sin(a), 1.2) for a in [i * math.tau / 12 for i in range(1, 12)]), INK, 0.8))
    b.append(P.shape(rect(59, 54, 10, 9, 2), "gold", s=1))
    gb, ge = cut_gem(P, "sapphire", 64, 92, 13, 16, 8, 0.5, "#cfe4ff", "#5a8ad8")
    b.append(gb)
    return J(b), ge


def sword_emberwarden(P):
    b, e = blade_sword(P, "metal", "darkiron", "leather", runes=(EMBER, EMBER_HOT), guard_gem="garnet")
    e += glow(P, 64, 88, 10, EMBER, 0.7)
    return rot(b, 45), rot(e, 45)


def sword_starsteel(P):
    b, e = blade_sword(P, "starmetal", "bronze", "cloth", guard_shape="down", pommel_gem=False)
    g = [glow(P, 64, 50, 40, "#8a9ccc", 0.18, rx=12, ry=44)]
    for x, y, r in [(62, 30, 5), (66, 52, 4), (61, 70, 3.5)]:
        g.append(glow(P, x, y, r * 1.6, STARLIGHT, 0.6) + fill(sparkle(x, y, r, 0.18), "#ffffff", 0.95))
    rnd = random.Random(5)
    b += fill(" ".join(ell(rnd.uniform(60, 68), rnd.uniform(26, 82), rnd.uniform(0.6, 1.1)) for _ in range(10)), "#e8ecff", 0.8)
    b += P.detail("M64,118 m-4,0 l4,-4 l4,4 l-4,4 Z", "bronze", 0.8)
    return rot(b, 45), rot(e + J(g), 45)


def warplate_adamantine(P):
    b = []
    for sg in (-1, 1):
        b.append(P.shape(smooth([(64 + sg * 20, 20), (64 + sg * 46, 22), (64 + sg * 54, 42), (64 + sg * 40, 52), (64 + sg * 24, 40)]), "adamant_dark", s=3))
        b.append(P.detail(f"M{64 + sg * 30},{26} Q{64 + sg * 46},{30} {64 + sg * 50},{42}", "adamant_dark", 0.7))
    bp = smooth([(38, 24), (64, 30), (90, 24), (100, 56), (92, 96), (64, 112), (36, 96), (28, 56)])
    b.append(P.shape(bp, "adamant_dark", s=8, lw=3.6))
    b.append(P.detail("M64,32 L64,108 M40,84 Q64,96 88,84 M36,98 Q64,110 92,98", "adamant_dark", 0.9))
    b.append(P.shape(smooth([(44, 16), (64, 10), (84, 16), (82, 30), (64, 34), (46, 30)]), "adamant_dark", s=2))
    riv = [(40, 34), (88, 34), (36, 74), (92, 74), (46, 92), (82, 92)]
    b.append(fill(" ".join(ell(x, y, 2.6) for x, y in riv), PAL["adamant_dark"][0]))
    b.append(lin(" ".join(ell(x, y, 2.6) for x, y in riv), INK, 0.8))
    b.append(fill(smooth([(42, 36), (52, 34), (54, 60), (46, 78), (40, 60)]), "#ffffff", 0.14))
    marks = "M48,46 L56,54 L64,46 L72,54 L80,46 M50,62 L64,72 L78,62 M64,72 L64,84 M56,80 l8,4 l8,-4"
    b.append(lin(marks, INK, 3.2, 0.8))
    e = glow(P, 64, 62, 46, VIOLET, 0.3) + lit_marks(P, marks, VIOLET, VIOLET_HOT, w=1.2, glow_w=4.4, op=0.95, blur=1.8)
    return J(b), e


def boots_ranger(P):
    o = []
    for x, y in ((54, 24), (30, 30)):
        o.append(boot(P, x, y, 1, "ranger", "ranger_cuff"))
        o.append(P.shape(smooth([(x - 3, y - 6), (x + 12, y - 9), (x + 26, y - 6), (x + 27, y + 10), (x + 12, y + 14), (x - 3, y + 12)]), "ranger_cuff", s=2))
        o.append(lin(" ".join(f"M{x+4},{y+20+i*7} L{x+18},{y+25+i*7} M{x+18},{y+20+i*7} L{x+4},{y+25+i*7}" for i in range(3)), "#e8d8b0", 1.0, 0.85))
    return J(o), ""


def hood_embroidered(P):
    b = [P.shape(smooth([(22, 116), (24, 64), (36, 30), (64, 12), (92, 30), (104, 64), (106, 116), (82, 108), (64, 112), (46, 108)]), "strap", s=8)]
    b.append(fill(smooth([(40, 104), (40, 66), (52, 44), (64, 38), (76, 44), (88, 66), (88, 104), (64, 96)]), "#2a1c12", 0.95))
    b.append(fill(smooth([(46, 98), (48, 70), (58, 52), (64, 50), (70, 52), (80, 70), (82, 98), (64, 92)]), "#16100b", 0.6))
    trim = smooth([(36, 108), (38, 64), (50, 40), (64, 34), (78, 40), (90, 64), (92, 108)], close=False)
    b.append(lin(trim, INK, 4.2))
    b.append(lin(trim, PAL["gold"][1], 2.4))
    b.append(f'<path d="{trim}" fill="none" stroke="#f4dc90" stroke-width="1.0" stroke-dasharray="2.5 2.5" opacity="0.9"/>')
    rnd = random.Random(11)
    sig = rune_glyphs(rnd, 64, 22, 5) + " " + ell(64, 22, 8.5) + " " + rune_glyphs(rnd, 28, 92, 4.5) + " " + rune_glyphs(rnd, 100, 92, 4.5)
    sig += " M24,74 l4,-4 l4,4 l-4,4 Z M104,74 l-4,-4 l-4,4 l4,4 Z"
    b.append(lin(sig, INK, 3.2, 0.9))
    b.append(lin(sig, "#e8c874", 1.5))
    e = glow(P, 64, 22, 12, GILT, 0.3)
    return J(b), e


# ------------------------------------------------------------- small UI icons (32x32, 128 design)
# ------------------------------------------------------------- bows (vertical in a 128 space, rotated by the caller)
PAL.setdefault("yew", ("#e2a070", "#b4643a", "#5e2c14"))
PAL.setdefault("sapwood", ("#f6e8c4", "#e6d0a0", "#9a8058"))
PAL.setdefault("horn", ("#efe2c4", "#b8a07a", "#4e3e2a"))


def bow_limb(top, bot, bulge, th, cx=52):
    """Closed tapering limb shape: tips at (cx, top)/(cx, bot), belly bulging right by `bulge`, `th` thick at the grip."""
    mid = (top + bot) / 2
    q1, q3 = top + (mid - top) * 0.45, mid + (bot - mid) * 0.55
    outer = [(cx, top), (cx + bulge * 0.78, q1), (cx + bulge, mid), (cx + bulge * 0.78, q3), (cx, bot)]
    inner = [(cx - 1.2, bot - 1), (cx + bulge * 0.78 - th * 0.7, q3), (cx + bulge - th, mid), (cx + bulge * 0.78 - th * 0.7, q1), (cx - 1.2, top + 1)]
    return smooth(outer, close=False) + " " + "L" + smooth(inner, close=False)[1:] + " Z", outer


def bow(P, top, bot, bulge, th, role="yew", grip="leather", nock="horn", string="#efe6cc", back_stripe=None, fine=False):
    d, outer = bow_limb(top, bot, bulge, th)
    b = []
    cx = 52
    # string first (behind the limb), slightly bowed by the nocks
    b.append(lin(f"M{cx+1},{top+3} L{cx+1},{bot-3}", INK, 3.0))
    b.append(lin(f"M{cx+1},{top+3} L{cx+1},{bot-3}", string, 1.3))
    b.append(P.shape(d, role, s=2.2))
    if back_stripe:   # pale sapwood back along the outside of the limb
        b.append(lin(smooth([(cx + 0.5, top + 4), (cx + bulge * 0.78 - 0.4, top + (bot - top) * 0.225), (cx + bulge - 1.4, (top + bot) / 2),
                             (cx + bulge * 0.78 - 0.4, bot - (bot - top) * 0.225), (cx + 0.5, bot - 4)], close=False), back_stripe, 2.2, 0.95))
    mid = (top + bot) / 2
    gx = cx + bulge - th / 2
    b.append(P.shape(rect(gx - th / 2 - 2, mid - 10, th + 4, 20, 2.5), grip, s=1.2, lw=2.6))
    b.append(P.detail(" ".join(f"M{gx-th/2-1.5:.1f},{mid-7+i*4.5:.1f} L{gx+th/2+1.5:.1f},{mid-5+i*4.5:.1f}" for i in range(4)), grip, 0.55))
    if fine:
        for yy in (mid - 12, mid + 12):
            b.append(P.shape(rect(gx - th / 2 - 2.5, yy - 1.6, th + 5, 3.2, 1), "gold", s=0.5, lw=1.6))
    # arrow rest nub + grain
    b.append(P.detail(f"M{cx+bulge*0.6:.1f},{top+(bot-top)*0.3:.1f} q2,10 3,20 M{cx+bulge*0.6:.1f},{bot-(bot-top)*0.3:.1f} q2,-10 3,-20", role, 0.4, 0.6))
    for (y, sy) in ((top, 1), (bot, -1)):
        b.append(P.shape(f"M{cx-2.5},{y+sy*8} L{cx+2.8},{y+sy*8} L{cx+0.6},{y-sy*1.5} Z", nock, s=0.6, lw=2))
    return J(b)


def bow_hunting(P):
    b = bow(P, 22, 106, 30, 10.5, role="yew", grip="leather", nock="wood", string="#e8dcc0")
    return rot(f'<g transform="translate(4,0)">{b}</g>', 45), ""


def bow_yew(P):
    b = bow(P, 0, 128, 17, 9, role="yew", grip="cloth", nock="horn", string="#f4ecd4", back_stripe=PAL["sapwood"][1], fine=True)
    return rot(f'<g transform="translate(6,0)">{b}</g>', 45), ""


def yew_stave(P):
    """Seasoned yew stave: a split length with the pale sapwood back, bark scraps, a knot and a sealed end grain."""
    b = []
    body = smooth([(58, 10), (66, 8), (70, 40), (71, 84), (69, 118), (61, 120), (58, 84), (57, 40)], t=0.35)
    b.append(P.shape(body, "yew", s=2.5))
    # sapwood stripe along the left side + bark scraps
    b.append(P.shape(smooth([(58, 12), (61.5, 11), (60.5, 50), (61, 90), (61.5, 117), (58.5, 117), (57.5, 84), (57, 40)], t=0.35), "sapwood", s=0.6, lw=1.4))
    for (y0, y1, dx) in ((26, 40, 0), (70, 86, 0.5), (98, 106, 0)):
        b.append(P.shape(f"M{56+dx},{y0} q-2.4,{(y1-y0)/2} 0,{y1-y0} l2,-1 q-1.2,{-(y1-y0)/2+1} 0,{-(y1-y0)+2} Z", "brown", s=0.4, lw=1.2))
    b.append(P.detail(" ".join(f"M{64+i*1.6:.1f},{16+i*3} q1.5,30 0.8,{88-i*6}" for i in range(3)), "yew", 0.45, 0.7))
    b.append(P.shape(ell(66, 62, 2.8, 4.2), "brown", s=0.6, lw=1.4))
    b.append(P.detail("M64,56 q2,6 0,12 M68.5,56 q-2,6 0,12", "yew", 0.4, 0.7))
    # waxed end (top) showing rings, twine binding + tag near the bottom
    b.append(P.shape(ell(62, 10, 5.5, 3.2), "wax", s=0.6, lw=1.6, fill_override="#c84a30"))
    b.append(lin("M57.5,104 L70.5,101 M57.5,108 L70.5,105", INK, 3.2) + lin("M57.5,104 L70.5,101 M57.5,108 L70.5,105", PAL["straw"][1], 1.6))
    b.append(lin("M70,103 q8,4 12,12", INK, 1.2))
    b.append(P.shape(rect(76, 113, 14, 10, 1.5), "paper", s=0.6, lw=1.6) + fill(ell(80, 116.5, 1.3), INK))
    return rot(J(b), 45), ""


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


# ------------------------------------------------------------- skill-tree progression (iteration 9: skill-tree worker)
PAL.setdefault("bearleather", ("#a07450", "#6a4428", "#2e1a0c"))
PAL.setdefault("wyrmleather", ("#8aa078", "#4a6040", "#1c2818"))
PAL.setdefault("orichalcum", ("#f0b070", "#c0602e", "#5a240c"))
PAL.setdefault("dragonscale", ("#d06a52", "#8a1e1a", "#3a0806"))
PAL.setdefault("dragonbone", ("#f2e6c8", "#cbb68a", "#6e5a38"))
PAL.setdefault("quint", ("#eef4f6", "#b8ccd4", "#5a7480"))
PAL.setdefault("aether", ("#d8ccf4", "#9a82d8", "#3e2a74"))
PAL.setdefault("wyrmfire", ("#ffb060", "#d0401c", "#5a0e04"))
PAL.setdefault("brig_plate", ("#a8a49c", "#6c6862", "#2c2824"))


def _scales(cx0, cy0, w, h, step=11, row=8):
    """Overlapping scale arcs (path data) filling a rectangle; clip it to a shape."""
    d = []
    for r, y in enumerate(range(int(cy0), int(cy0 + h), row)):
        for x in range(int(cx0) + (r % 2) * (step // 2), int(cx0 + w), step):
            d.append(f"M{x - step / 2:.1f},{y} Q{x},{y + row * 1.35:.1f} {x + step / 2:.1f},{y}")
    return " ".join(d)


def _clip(P, cid, shape, inner):
    P.defs.append(f'<clipPath id="{cid}"><path d="{shape}"/></clipPath>')
    return f'<g clip-path="url(#{cid})">{inner}</g>'


def leather_bear(P):
    """A folded stack of thick dark leather with a tuft of bear fur on the top edge and a tie-thong."""
    b = []
    for i, y in enumerate((80, 64, 48)):
        b.append(P.shape(poly([(20, y), (96, y - 12), (110, y + 6), (32, y + 20)]), "bearleather" if i != 1 else "brown", s=3))
    fur = " ".join(f"M{24 + i * 7},{46 - i * 1.1:.1f} l{-2 + (i % 3)},-8" for i in range(11))
    b.append(lin(fur, INK, 3.0, 0.9))
    b.append(lin(fur, "#4a3020", 1.6))
    b.append(P.shape(rect(52, 34, 9, 56, 2), "strap", s=1.5))
    b.append(P.detail("M40,70 l10,-2 M74,58 l12,-2", "bearleather", 0.6))
    b.append(P.shape(ell(56, 40, 6, 4), "bone" if "bone" in PAL else "dragonbone", s=1))
    return J(b), ""


def leather_wyrm(P):
    """A rolled hide of scaled green-black wyrm leather tied with cord."""
    hide = smooth([(18, 56), (60, 38), (104, 42), (112, 70), (98, 92), (52, 96), (22, 84)])
    b = [P.shape(hide, "wyrmleather", s=6)]
    b.append(_clip(P, "lw_clip", hide, lin(_scales(10, 34, 110, 66, 12, 8), INK, 1.1, 0.75) + lin(_scales(10, 35, 110, 66, 12, 8), "#c4d8a8", 0.5, 0.35)))
    b.append(P.shape(ell(30, 70, 13, 22), "wyrmleather", s=3))
    b.append(lin(ell(30, 70, 7, 13), INK, 1.4, 0.9))
    b.append(P.shape(rect(62, 40, 7, 56, 2), "strap", s=1.5))
    return J(b), ""


def ingot_orichalcum(P):
    b, e = ingot(P, "orichalcum", "M60,58 l5,-8 l5,8 l5,-8 l5,8", ("#ff9a4a", "#ffe0a8"))
    e += glow(P, 66, 60, 40, "#ff8a3a", 0.25)
    return b, e


def reagent_quintessence(P):
    """A slim corked phial of silvery quintessence beside a silverleaf sprig."""
    b, e = potion(P, "quint", "#dfeef4", "tall")
    b = f'<g transform="translate(16,0) scale(0.86)">{b}</g>'
    leaf = smooth([(16, 104), (26, 84), (40, 74), (46, 82), (36, 98)])
    b += P.shape(leaf, "silver", s=2) + P.detail("M18,102 Q32,86 44,78", "silver", 0.8)
    e = f'<g transform="translate(16,0) scale(0.86)">{e}</g>'
    e += fill(" ".join(sparkle(x, y, r) for x, y, r in [(92, 30, 5), (104, 50, 3.5)]), "#f4fcff", 0.95)
    return b, e


def runestone_original(P):
    """Your own rune: a mirror-polished stone with a new, star-like sigil in gold."""
    top = wobbly_ell(64, 58, 44, 32, 21, 0.05)
    side = smooth([(20, 58), (22, 72), (40, 90), (64, 96), (88, 90), (106, 72), (108, 58), (88, 84), (64, 90), (40, 84)])
    b = [P.shape(side, "obsidian", s=2, fill_override=PAL["obsidian"][2]), P.shape(top, "obsidian", s=5)]
    sig = "M64,38 L64,78 M46,48 L82,68 M82,48 L46,68 M54,40 Q64,50 74,40 M54,76 Q64,66 74,76 " + ell(64, 58, 6)
    b.append(lin(sig, INK, 4.6, 0.9))
    b.append(fill(ell(48, 46, 10, 4), "#ffffff", 0.25))
    e = glow(P, 64, 58, 36, RUNE_GOLD, 0.45) + lit_marks(P, sig, GILT, "#fff2c0", w=2.4, glow_w=8, op=1.0, blur=2.4)
    return J(b), e


def runestone_concord(P):
    """Three interlocked runes on one stone: ember, ward and the smith's own, each its colour."""
    top = wobbly_ell(64, 58, 46, 34, 23, 0.05)
    side = smooth([(18, 58), (20, 74), (40, 92), (64, 98), (88, 92), (108, 74), (110, 58), (88, 86), (64, 92), (40, 86)])
    b = [P.shape(side, "rune", s=2, fill_override=PAL["rune"][2]), P.shape(top, "rune", s=5)]
    rings = [(50, 52, EMBER, EMBER_HOT), (78, 52, "#a8c8e8", "#f0f8ff"), (64, 72, GILT, "#fff2c0")]
    e = glow(P, 64, 60, 40, "#e8d8a0", 0.35)
    for i, (x, y, c1, c2) in enumerate(rings):
        d = ell(x, y, 13) + " " + rune_glyphs(random.Random(31 + i), x, y, 6)
        b.append(lin(d, INK, 4.0, 0.85))
        e += lit_marks(P, d, c1, c2, w=1.8, glow_w=6, op=1.0, blur=2.0)
    return J(b), e


def infusion_aether(P):
    b, e = potion(P, "aether", VIOLET, "round")
    e += fill(" ".join(sparkle(x, y, r) for x, y, r in [(52, 90, 5), (74, 96, 4), (64, 84, 3), (84, 86, 3)]), VIOLET_HOT, 0.95)
    e += fill(" ".join(sparkle(x, y, r) for x, y, r in [(40, 30, 4), (88, 24, 5)]), "#ece0ff", 0.85)
    return b, e


def coating_wyrmfire(P):
    b, e = potion(P, "wyrmfire", "#ff6a2a", "tall")
    flame = "M56,104 q-8,-14 4,-26 q0,10 6,12 q2,-10 -2,-16 q12,10 8,30 Z"
    b += lin("M38,52 Q30,40 40,30 M90,50 Q100,38 90,26", "#5a0e04", 2.4, 0.7)
    e += lit_marks(P, flame, "#ff6a2a", "#ffe08a", w=1.6, glow_w=6, op=1.0) + glow(P, 64, 94, 30, "#ff3a10", 0.35)
    return b, e


def _cuirass(P, role, rivet_role="metal", lw=None):
    b = []
    for sg in (-1, 1):
        b.append(P.shape(smooth([(64 + sg * 22, 22), (64 + sg * 44, 26), (64 + sg * 50, 44), (64 + sg * 38, 50), (64 + sg * 26, 40)]), role, s=3))
    bp = smooth([(40, 24), (64, 30), (88, 24), (96, 56), (88, 92), (64, 108), (40, 92), (32, 56)])
    b.append(P.shape(bp, role, s=8) if lw is None else P.shape(bp, role, s=8, lw=lw))
    b.append(P.shape(smooth([(46, 18), (64, 12), (82, 18), (80, 30), (64, 34), (48, 30)]), role, s=2))
    riv = [(42, 36), (86, 36), (40, 78), (88, 78)]
    b.append(fill(" ".join(ell(x, y, 2.3) for x, y in riv), PAL[rivet_role][0]))
    b.append(lin(" ".join(ell(x, y, 2.3) for x, y in riv), INK, 0.8))
    return b, bp


def cuirass_steel(P):
    """Bright steel breastplate with a crisp medial ridge and rolled, brass-trimmed edges."""
    b, bp = _cuirass(P, "metal", "bronze")
    b.append(P.detail("M64,32 L64,104 M44,92 Q64,104 84,92", "metal", 0.9))
    b.append(lin(smooth([(40, 26), (64, 32), (88, 26)], close=False), PAL["bronze"][1], 2.4, 0.95))
    b.append(lin(smooth([(42, 90), (64, 104), (86, 90)], close=False), PAL["bronze"][1], 2.4, 0.95))
    b.append(fill(smooth([(44, 36), (56, 36), (58, 70), (50, 88), (42, 64)]), "#ffffff", 0.32))
    b.append(fill(smooth([(70, 40), (80, 40), (84, 60), (76, 80)]), "#ffffff", 0.12))
    return J(b), ""


def mithril_plated_cuirass(P):
    """Steel cuirass overlaid with pale charged-mithril plates, their seams glowing violet."""
    b, bp = _cuirass(P, "metal", "gold")
    plates = [poly([(42, 36), (62, 40), (62, 66), (40, 62)]), poly([(66, 40), (86, 36), (88, 62), (66, 66)]),
              poly([(42, 68), (62, 72), (62, 98), (48, 92)]), poly([(66, 72), (86, 68), (80, 92), (66, 98)])]
    for pl in plates:
        b.append(P.shape(pl, "mithril", s=2))
    seams = "M64,36 L64,102 M40,66 L88,66"
    b.append(lin(seams, INK, 3.4, 0.85))
    e = glow(P, 64, 66, 40, VIOLET, 0.28) + lit_marks(P, seams, VIOLET, VIOLET_HOT, w=1.2, glow_w=4.4, op=0.95, blur=1.8)
    b.append(fill(" ".join(ell(x, y, 2) for x, y in [(52, 52), (76, 52), (54, 84), (74, 84)]), PAL["gold"][0]))
    return J(b), e


def bearhide_brigandine(P):
    """Dark bear-leather jerkin studded with the rivet heads of hidden iron plates, a fur collar."""
    sh = smooth([(40, 22), (54, 26), (64, 36), (74, 26), (88, 22), (104, 34), (100, 62), (96, 112), (64, 118), (32, 112), (28, 62), (24, 34)])
    b = [P.shape(sh, "bearleather", s=7)]
    b.append(P.detail("M64,38 L64,114", "bearleather", 1.0))
    studs = [(x, y) for y in range(46, 108, 11) for x in (40, 51, 77, 88)]
    b.append(fill(" ".join(ell(x, y, 2.4) for x, y in studs), PAL["brig_plate"][0]))
    b.append(lin(" ".join(ell(x, y, 2.4) for x, y in studs), INK, 0.8))
    fur = " ".join(f"M{36 + i * 5},{28 + abs(i - 6) * 0.9:.1f} l{-1 + (i % 3)},-9" for i in range(13))
    b.append(lin(fur, INK, 3.2, 0.9))
    b.append(lin(fur, "#5a3a24", 1.8))
    b.append(P.shape(rect(30, 92, 68, 8, 2), "strap", s=1.5))
    b.append(P.shape(rect(58, 90, 12, 12, 2), "darkiron", s=1))
    return J(b), ""


def boots_wyrmleather(P):
    o = []
    for x, y in ((54, 24), (30, 30)):
        o.append(boot(P, x, y, 1, "wyrmleather", "orichalcum"))
        s = smooth([(x, y), (x + 22, y), (x + 22, y + 46), (x + 30, y + 58), (x + 34, y + 68), (x + 30, y + 74), (x - 2, y + 74), (x - 3, y + 40)])
        o.append(_clip(P, f"bw_clip{x}", s, lin(_scales(x - 6, y + 4, 44, 72, 8, 6), INK, 0.9, 0.6)))
    e = lit_marks(P, "M36,58 l6,-4 l6,4 M60,52 l6,-4 l6,4", EMBER, EMBER_HOT, w=1.2, glow_w=4, op=0.9)
    return J(o), e


def dragonscale_armor(P):
    """Legendary: a cuirass of deep-red dragon scales on a bone frame, gilt edges and an ember glow."""
    b = []
    for sg in (-1, 1):
        sp = smooth([(64 + sg * 20, 20), (64 + sg * 46, 22), (64 + sg * 56, 42), (64 + sg * 42, 54), (64 + sg * 24, 40)])
        b.append(P.shape(sp, "dragonscale", s=3))
        b.append(_clip(P, f"ds_sp{sg + 1}", sp, lin(_scales(64 + min(0, sg * 60), 18, 60, 40, 9, 6), INK, 0.9, 0.7)))
        b.append(P.shape(poly([(64 + sg * 50, 38), (64 + sg * 62, 26), (64 + sg * 56, 46)]), "dragonbone", s=1))
    bp = smooth([(38, 24), (64, 30), (90, 24), (100, 56), (92, 96), (64, 114), (36, 96), (28, 56)])
    b.append(P.shape(bp, "dragonscale", s=8, lw=3.6))
    b.append(_clip(P, "ds_bp", bp, lin(_scales(24, 26, 82, 92, 11, 8), INK, 1.2, 0.8) + lin(_scales(24, 27, 82, 92, 11, 8), "#f4a080", 0.6, 0.45)))
    b.append(P.shape(smooth([(44, 16), (64, 10), (84, 16), (82, 30), (64, 34), (46, 30)]), "dragonbone", s=2))
    b.append(lin(smooth([(38, 26), (64, 32), (90, 26)], close=False), PAL["gold"][1], 2.6))
    b.append(lin(smooth([(36, 96), (64, 114), (92, 96)], close=False), PAL["gold"][1], 2.6))
    b.append(lin("M64,34 L64,110", PAL["dragonbone"][1], 3.0))
    b.append(lin("M64,34 L64,110", INK, 0.8, 0.8))
    b.append(fill(smooth([(42, 38), (52, 36), (54, 60), (46, 76), (40, 58)]), "#ffffff", 0.14))
    e = glow(P, 64, 66, 48, EMBER, 0.32) + lit_marks(P, "M52,56 l12,10 l12,-10 M56,80 l8,6 l8,-6", EMBER, EMBER_HOT, w=1.3, glow_w=5, op=0.95, blur=2.0)
    e += fill(" ".join(sparkle(x, y, r) for x, y, r in [(100, 22, 6), (24, 30, 4)]), "#fff2c0", 0.95)
    return J(b), e


ICONS = {k: v for k, v in globals().items() if callable(v)}


SCALE = dict(bow_hunting=1.28, gem_garnet=1.08, gem_moonstone=1.06, relic_unknown_arms=1.06,
             ring_silver=1.3, mace_flanged=1.12, dagger=1.15, herb_emberleaf=1.12, herb_moonwort=1.12, axe_hand=1.08,
             amulet_silver=1.08, runestone_blank=1.1, runestone_ember=1.1, runestone_ward=1.1, runestone_frost=1.1)


EXTRA = ["gem_garnet", "gem_sapphire", "gem_moonstone", "gem_starstone", "ingot_adamantine", "starmetal_fragment",
         "relic_unknown_arms", "relic_unknown_tablet", "relic_unknown_reliquary", "recipe_scroll", "coating_frost", "ring_garnet",
         "amulet_sapphire", "sword_emberwarden", "sword_starsteel", "warplate_adamantine", "boots_ranger", "hood_embroidered"]


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
    for ic in EXTRA:                       # expansion icons (rendered even before items.json lists them)
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
