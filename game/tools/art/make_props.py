"""World prop sprites (straight top-down, transparent, exact spec size).
python3 make_props.py [--only=well,bed]"""
import math
import os
import random
import artlib  # noqa: F401  (sets sys.path)
import subjects
from artlib import (painter, sprite_svg, ground_shadow, glow, lin, fill, planks, end_grain, stones_ring, coals, liquid,
                    bottle_top, candle_top, render, load, only_filter, ell, rect, poly, smooth, blob, wobbly_ell, ST,
                    INK, EMBER, EMBER_HOT, RUB, GILT, SPR, SOOT, blur_filter, hatch)
from make_stations import pelt

PAL = ST["pal"]


def J(o):
    return "\n".join(x for x in o if x)


def sh_(P, d, dx=4, dy=5, **k):
    return ground_shadow(P, d, dx, dy, **k)


# ---------------------------------------------------------------- small reusable objects
def tankard(P, x, y, r=4.5):
    return J([P.shape(rect(x + r * 0.7, y - 1.5, r * 0.9, 3, 1), "darkiron", s=0.5, lw=1),
              P.shape(ell(x, y, r), "wood", s=1, lw=1.3),
              fill(ell(x, y, r * 0.7), "#f2ead2", 1), fill(ell(x + r * 0.15, y + r * 0.15, r * 0.4), "#d8c49a", 0.7)])


def plate(P, x, y, r=6, food=True, seed=1):
    o = [P.shape(ell(x, y, r), "clay", s=1, lw=1.2), lin(ell(x, y, r * 0.7), INK, 0.4, 0.5)]
    if food:
        rnd = random.Random(seed)
        o.append(P.shape(wobbly_ell(x - 1, y, r * 0.45, r * 0.35, seed, 0.15), "apron", s=0.5, lw=0.7))
        o.append(fill(ell(x + r * 0.35, y + r * 0.2, r * 0.2), PAL["cabbage"][1]))
    return J(o)


def book(P, x, y, w, h, role="cloth", open_=False):
    if open_:
        return J([P.shape(rect(x - 1, y - 1, w + 2, h + 2, 1.5), role, s=1, lw=1.3),
                  P.shape(rect(x, y, w / 2, h, 1), "paper", s=0.8, lw=1), P.shape(rect(x + w / 2, y, w / 2, h, 1), "paper", s=0.8, lw=1),
                  P.detail(" ".join(f"M{x+2},{y+3+i*2.6:.1f} h{w/2-4:.1f} M{x+w/2+2},{y+3+i*2.6:.1f} h{w/2-4:.1f}" for i in range(int((h - 4) / 2.6))), "paper", 0.25, 0.6)])
    return J([P.shape(rect(x, y, w, h, 1.5), role, s=1.2, lw=1.3), lin(f"M{x+2},{y+1} L{x+2},{y+h-1}", GILT, 0.8)])


def sword_top(P, x, y, L, ang, role="metal"):
    ca, sa = math.cos(ang), math.sin(ang)
    px, py = -sa, ca
    def pt(t, o):
        return (x + ca * t + px * o, y + sa * t + py * o)
    blade = poly([pt(L * 0.3, -2.2), pt(L * 0.92, -2.2), pt(L, 0), pt(L * 0.92, 2.2), pt(L * 0.3, 2.2)])
    guard = poly([pt(L * 0.27, -7), pt(L * 0.31, -7), pt(L * 0.31, 7), pt(L * 0.27, 7)])
    grip = poly([pt(L * 0.06, -1.6), pt(L * 0.27, -1.6), pt(L * 0.27, 1.6), pt(L * 0.06, 1.6)])
    return J([P.shape(blade, role, s=1, lw=1.4), P.detail(f"M{pt(L*0.32,0)[0]:.1f},{pt(L*0.32,0)[1]:.1f} L{pt(L*0.88,0)[0]:.1f},{pt(L*0.88,0)[1]:.1f}", role, 0.4, 0.7),
              P.shape(grip, "leather", s=0.5, lw=1.2), P.shape(guard, "bronze", s=0.8, lw=1.3), P.shape(ell(*pt(L * 0.04, 0), 2.6), "bronze", s=0.5, lw=1.1)])


def axe_top(P, x, y, L, ang):
    ca, sa = math.cos(ang), math.sin(ang)
    px, py = -sa, ca
    def pt(t, o):
        return (x + ca * t + px * o, y + sa * t + py * o)
    haft = poly([pt(0, -1.8), pt(L, -1.8), pt(L, 1.8), pt(0, 1.8)])
    head = smooth([pt(L * 0.78, -2), pt(L * 0.74, -10), pt(L * 0.86, -12), pt(L * 0.94, -9), pt(L * 0.9, -2)])
    return J([P.shape(haft, "wood", s=0.6, lw=1.3), P.shape(head, "metal", s=1, lw=1.4)])


# ---------------------------------------------------------------- furniture
def shop_counter(P, W, H):
    sh = sh_(P, rect(4, 6, 246, 50, 3))
    b = [planks(P, 4, 6, 246, 50, "wood", n=4, dirn="h", s=3, seed=3),
         P.shape(rect(4, 6, 246, 7, 2), "brown", s=1, lw=1.6)]
    b.append(book(P, 30, 18, 46, 28, "cloth", open_=True))
    b.append(lin("M60,22 l10,14", INK, 1.2))  # quill
    b.append(lin("M60,22 l10,14", "#f4ead0", 0.5))
    # scales
    b.append(P.shape(rect(110, 30, 40, 3, 1), "bronze", s=0.5, lw=1.2))
    b.append(P.shape(ell(130, 31.5, 3.5), "bronze", s=0.5, lw=1.2))
    for x in (112, 148):
        b.append(P.shape(ell(x, 31.5, 8), "bronze", s=1.5, lw=1.4))
    b.append(fill(ell(148, 31.5, 3), PAL["gold"][1], 1))
    # coin dish
    b.append(P.shape(ell(196, 32, 12), "clay", s=2, lw=1.5))
    rnd = random.Random(2)
    for i in range(6):
        b.append(P.shape(ell(196 + rnd.gauss(0, 4), 32 + rnd.gauss(0, 3), 2.6), "gold", s=0.5, lw=0.8))
    b.append(P.shape(rect(222, 18, 16, 22, 1.5), "paper", s=1, lw=1.1))
    return sh, J(b), ""


def weapon_rack(P, W, H):
    sh = sh_(P, rect(4, 4, 150, 44, 3))
    b = [P.shape(rect(4, 4, 150, 10, 2), "wood", s=2), P.shape(rect(4, 38, 150, 8, 2), "wood", s=2)]
    for x in (6, 148):
        b.append(P.shape(rect(x - 2, 2, 8, 46, 2), "wood", s=1.5, lw=1.6))
    b.append(sword_top(P, 26, 46, 44, -math.pi / 2))
    b.append(axe_top(P, 58, 46, 42, -math.pi / 2))
    b.append(sword_top(P, 92, 46, 42, -math.pi / 2, "metal"))
    b.append(axe_top(P, 126, 46, 40, -math.pi / 2))
    b.append(P.shape(rect(4, 24, 150, 5, 1.5), "brown", s=1, lw=1.4))
    return sh, J(b), ""


def armor_stand(P, W, H):
    cx = 36
    sh = sh_(P, ell(cx, 76, 24, 8) + " " + rect(cx - 22, 12, 44, 46, 10), 3, 4)
    b = []
    for (x1, y1) in [(cx - 24, 84), (cx + 24, 84), (cx, 70)]:
        b += [lin(f"M{cx},78 L{x1},{y1}", INK, 4.4), lin(f"M{cx},78 L{x1},{y1}", PAL["wood"][1], 2.6)]
    b.append(P.shape(rect(cx - 2.5, 50, 5, 30, 1.5), "wood", s=1, lw=1.4))
    b.append(P.shape(rect(cx - 30, 14, 60, 6, 2), "wood", s=1, lw=1.5))
    # breastplate + pauldrons
    for sg in (-1, 1):
        b.append(P.shape(ell(cx + sg * 22, 18, 10, 8), "metal", s=2, lw=1.7))
    bp = smooth([(cx - 18, 14), (cx, 18), (cx + 18, 14), (cx + 20, 34), (cx + 12, 52), (cx, 56), (cx - 12, 52), (cx - 20, 34)])
    b.append(P.shape(bp, "metal", s=4))
    b.append(P.detail(f"M{cx},20 L{cx},54 M{cx-12},48 Q{cx},54 {cx+12},48", "metal", 0.6))
    b.append(fill(" ".join(ell(x, y, 1.2) for x, y in [(cx - 14, 20), (cx + 14, 20), (cx - 15, 40), (cx + 15, 40)]), PAL["gold"][1]))
    b.append(P.shape(ell(cx, 9, 6, 5), "wood", s=1, lw=1.4))
    return sh, J(b), ""


def display_table(P, W, H):
    sh = sh_(P, rect(4, 6, 118, 64, 3))
    b = [planks(P, 4, 6, 118, 64, "wood", n=4, dirn="h", s=3, seed=5), P.shape(rect(10, 10, 106, 56, 2), "cloth", s=2, lw=1.6)]
    b.append(lin(rect(13, 13, 100, 50, 1), GILT, 0.8, 0.8))
    # helmet (seen from above: dome with nasal + rim)
    b.append(P.shape(ell(32, 36, 15, 16), "metal", s=4))
    b.append(P.detail("M32,21 L32,51 M18,36 Q32,30 46,36", "metal", 0.5))
    b.append(P.shape(rect(30, 50, 4, 7, 1), "metal", s=0.5, lw=1.1))
    # round shield
    b.append(P.shape(ell(92, 38, 19), "wood", s=3))
    b.append(lin(ell(92, 38, 17), PAL["darkiron"][1], 2.6))
    b.append(P.shape(ell(92, 38, 6), "metal", s=1.5, lw=1.4))
    b.append(P.detail("M78,30 L106,46 M78,46 L106,30", "wood", 0.3, 0.5))
    # gloves pair
    for i, x in enumerate((54, 66)):
        g = smooth([(x - 4, 50), (x + 4, 50), (x + 5, 40), (x + 7, 34), (x + 3, 30), (x - 3, 30), (x - 6, 38)])
        b.append(P.shape(g, "leather", s=1.5, lw=1.4))
        b.append(P.detail(f"M{x-2},31 l0,-3 M{x+1},30 l0,-4 M{x+4},31 l1,-3", "leather", 0.8))
    return sh, J(b), ""


def bed(P, W, H, fancy=False):
    x0, w = 6, W - 14
    sh = sh_(P, rect(x0, 6, w, H - 16, 4))
    b = [P.shape(rect(x0, 6, w, H - 16, 4), "wood", s=3),
         P.shape(rect(x0, 6, w, 12, 3), "wood", s=2, lw=2)]  # headboard
    if fancy:
        for x in (x0 + 4, x0 + w - 4):
            b.append(P.shape(ell(x, 12, 5), "wood", s=1, lw=1.4))
            b.append(fill(ell(x, 12, 2), GILT))
    cover = "cloth" if fancy else "blue"
    b.append(P.shape(rect(x0 + 5, 18, w - 10, H - 34, 3), "linen", s=2, lw=1.6))
    for i, px in enumerate([x0 + 9, x0 + w / 2 + 2] if fancy or w > 70 else [x0 + 9]):
        pw = (w - 22) / 2 if (fancy or w > 70) else w - 18
        b.append(P.shape(rect(px, 22, pw, 20, 6), "linen", s=2.5, lw=1.6))
        b.append(P.detail(f"M{px+pw/2},24 L{px+pw/2},40", "linen", 0.3, 0.5))
    if fancy:
        b.append(P.shape(ell(x0 + w / 2, 46, 10, 7), "cloth", s=1.5, lw=1.4))
        b.append(fill(ell(x0 + w / 2, 46, 3), GILT, 0.9))
    blank = rect(x0 + 3, 54, w - 6, H - 72, 4)
    b.append(P.shape(blank, cover, s=5))
    b.append(P.shape(rect(x0 + 3, 54, w - 6, 12, 3), "linen" if not fancy else "cloth", s=2, lw=1.6))
    if fancy:
        b.append(lin(rect(x0 + 7, 70, w - 14, H - 92, 2), GILT, 0.9, 0.9))
        b.append(lin(f"M{x0+7},{(70+H-22)/2} h{w-14}", GILT, 0.6, 0.6))
    else:
        b.append(P.detail(" ".join(f"M{x0+5},{y} L{x0+w-5},{y}" for y in range(84, H - 22, 18)), cover, 0.35, 0.5))
        b.append(P.detail(" ".join(f"M{x},{68} L{x},{H-20}" for x in range(int(x0 + 20), int(x0 + w - 6), 18)), cover, 0.35, 0.5))
    b.append(P.detail(f"M{x0+10},{H-40} q{w*0.3},-8 {w*0.6},0", cover, 0.5, 0.7))
    return sh, J(b), ""


def bed_fancy(P, W, H):
    return bed(P, W, H, fancy=True)


def table_round(P, W, H):
    cx, cy = 46, 46
    sh = sh_(P, ell(cx, cy, 40))
    b = [P.shape(ell(cx, cy, 40), "wood", s=5)]
    b.append(P.detail(" ".join(f"M{cx-40+i*13},{cy-38+abs(3-i)*2} L{cx-40+i*13},{cy+38-abs(3-i)*2}" for i in range(1, 7)), "wood", 0.45, 0.7))
    b.append(tankard(P, cx - 16, cy - 10, 6))
    b.append(tankard(P, cx + 14, cy + 14, 6))
    b.append(plate(P, cx + 14, cy - 14, 8, seed=2))
    cb, ce = candle_top(P, cx - 6, cy + 10, 3.6)
    b.append(P.shape(ell(cx - 6, cy + 10, 6), "darkiron", s=1, lw=1.2))
    b.append(cb)
    return sh, J(b), ce


def table_long(P, W, H):
    sh = sh_(P, rect(4, 8, 180, 60, 3))
    b = [planks(P, 4, 8, 180, 60, "wood", n=4, dirn="h", s=3, seed=9)]
    for i, x in enumerate(range(22, 180, 36)):
        b.append(plate(P, x, 22, 8, seed=i))
        b.append(plate(P, x + 16, 54, 8, seed=i + 7))
        b.append(tankard(P, x + 14, 26, 5))
    b.append(P.shape(ell(96, 38, 9, 6), "clay", s=1, lw=1.3))
    return sh, J(b), ""


def chair(P, W, H):
    sh = sh_(P, rect(6, 4, 28, 30, 3), 3, 3)
    b = [P.shape(rect(7, 10, 26, 24, 3), "wood", s=2.5, lw=1.8),
         P.detail("M8,18 L32,18 M8,26 L32,26", "wood", 0.4, 0.7),
         P.shape(rect(5, 3, 30, 7, 2), "wood", s=1.5, lw=1.8)]
    return sh, J(b), ""


def stool(P, W, H):
    sh = sh_(P, ell(15, 15, 12), 3, 3)
    return sh, J([end_grain(P, 15, 15, 12, seed=4)]), ""


def bench(P, W, H):
    sh = sh_(P, rect(4, 6, 150, 22, 3), 3, 4)
    b = [planks(P, 4, 6, 150, 22, "wood", n=2, dirn="h", s=2, seed=2)]
    return sh, J(b), ""


def bar_counter(P, W, H):
    sh = sh_(P, rect(4, 6, 310, 50, 3))
    b = [planks(P, 4, 6, 310, 50, "wood", n=4, dirn="h", s=3, seed=31),
         P.shape(rect(4, 6, 310, 6, 2), "brown", s=1, lw=1.5)]
    # tap keg on the counter end
    b.append(P.shape(ell(282, 30, 18), "wood", s=3))
    b.append(lin(ell(282, 30, 15) + " " + ell(282, 30, 9), PAL["darkiron"][1], 1.8))
    b.append(P.shape(rect(278, 44, 8, 10, 2), "bronze", s=1, lw=1.3))
    for i, x in enumerate((40, 70, 120, 160, 214, 240)):
        b.append(tankard(P, x, 22 + (i % 2) * 14, 5.5))
    b.append(P.shape(rect(180, 18, 22, 14, 2), "linen", s=1, lw=1.2))
    b.append(P.shape(ell(92, 34, 7), "clay", s=1, lw=1.2))
    return sh, J(b), ""


def barrel_top(P, cx, cy, r, tap=False):
    o = [P.shape(ell(cx, cy, r), "wood", s=r * 0.18)]
    o.append(lin(ell(cx, cy, r * 0.94), INK, 1.0))
    o.append(lin(ell(cx, cy, r * 0.94), PAL["darkiron"][1], 1.6, 0.9))
    o.append(P.shape(ell(cx, cy, r * 0.8), "wood", s=r * 0.08, lw=1.4))
    o.append(P.detail(" ".join(f"M{cx-r*0.8:.1f},{cy+k*r:.1f} L{cx+r*0.8:.1f},{cy+k*r:.1f}" for k in (-0.4, 0, 0.4)), "wood", 0.4, 0.6))
    o.append(fill(ell(cx + r * 0.35, cy - r * 0.35, r * 0.07), INK))
    if tap:
        o.append(P.shape(rect(cx - 3, cy + r * 0.82, 6, r * 0.32, 1.5), "bronze", s=0.6, lw=1.2))
    return J(o)


def keg(P, W, H):
    sh = sh_(P, ell(26, 26, 21))
    return sh, barrel_top(P, 26, 26, 21, tap=True), ""


def barrel(P, W, H):
    sh = sh_(P, ell(26, 26, 22))
    return sh, barrel_top(P, 26, 26, 22), ""


def crate_top(P, x, y, s, seed=1):
    return J([planks(P, x, y, s, s, "wood", n=4, dirn="h", s=s * 0.08, seed=seed),
              P.shape(rect(x, y, s, s * 0.13, 1), "wood", s=1, lw=1.5), P.shape(rect(x, y + s * 0.87, s, s * 0.13, 1), "wood", s=1, lw=1.5),
              P.detail(f"M{x+3},{y+s*0.15} L{x+s-3},{y+s*0.85}", "wood", 1.0)])


def crate(P, W, H):
    sh = sh_(P, rect(5, 5, 44, 44))
    return sh, crate_top(P, 5, 5, 44, 3), ""


def sack_top(P, cx, cy, r, seed=1):
    o = [P.shape(blob(cx, cy, r, 6, 0.08, seed), "straw", s=r * 0.2, hl=True)]
    o[0] = P.shape(blob(cx, cy, r, 6, 0.08, seed), "burlap", s=r * 0.2)
    o.append(P.detail(f"M{cx-r*0.5:.1f},{cy-r*0.2:.1f} q{r*0.3:.1f},{r*0.4:.1f} {r*0.4:.1f},{r*0.3:.1f} M{cx+r*0.1:.1f},{cy+r*0.4:.1f} q{r*0.3:.1f},-{r*0.1:.1f} {r*0.5:.1f},-{r*0.4:.1f}", "burlap", 0.5, 0.8))
    o.append(P.shape(blob(cx - r * 0.05, cy - r * 0.05, r * 0.28, 5, 0.25, seed + 1), "burlap", s=1, lw=1.3))
    o.append(lin(ell(cx - r * 0.05, cy - r * 0.05, r * 0.16), PAL["brown"][1], 1.4))
    return J(o)


def sack(P, W, H):
    sh = sh_(P, ell(22, 22, 18))
    return sh, sack_top(P, 22, 22, 18, 3), ""


def shelf(P, W, H, books=False):
    sh = sh_(P, rect(4, 4, 118, 28, 2), 3, 4)
    b = [P.shape(rect(4, 4, 118, 28, 2), "wood", s=2)]
    rnd = random.Random(7 if books else 3)
    if books:
        x = 8
        cols = ["cloth", "brown", "blue", "green", "leather", "hide", "cloth", "darkiron"]
        while x < 114:
            w = rnd.uniform(4, 7.5)
            b.append(P.shape(rect(x, 7 + rnd.uniform(0, 4), w, 20 - rnd.uniform(0, 4), 1), rnd.choice(cols), s=0.8, lw=1.1))
            x += w + 0.4
            if rnd.random() < 0.08:
                x += 6
    else:
        x = 12
        while x < 116:
            kind = rnd.random()
            if kind < 0.6:
                r = rnd.uniform(4, 6)
                b.append(bottle_top(P, x, 18, r, rnd.choice(["brew", "straw", "copper", "redp", "ice", "brown"])))
                x += r * 2 + 3
            else:
                r = rnd.uniform(6, 8)
                b.append(P.shape(ell(x + 1, 18, r), "clay", s=1.5, lw=1.4))
                b.append(P.shape(ell(x + 1, 18, r * 0.5), "linen", s=0.5, lw=1))
                b.append(lin(ell(x + 1, 18, r * 0.62), PAL["brown"][1], 0.8))
                x += r * 2 + 3
    return sh, J(b), ""


def bookshelf(P, W, H):
    return shelf(P, W, H, books=True)


def wardrobe(P, W, H):
    sh = sh_(P, rect(4, 4, 102, 38, 2), 3, 4)
    b = [P.shape(rect(4, 4, 102, 38, 3), "brown", s=3),
         P.shape(rect(9, 8, 92, 30, 2), "wood", s=2, lw=1.6),
         P.detail("M55,8 L55,38", "wood", 0.6),
         P.detail(" ".join(f"M12,{y} L98,{y}" for y in (16, 24, 31)), "wood", 0.3, 0.5),
         P.shape(ell(30, 23, 6, 3.5), "bronze", s=0.5, lw=1), P.shape(ell(80, 23, 6, 3.5), "bronze", s=0.5, lw=1)]
    return sh, J(b), ""


def chest(P, W, H):
    sh = sh_(P, rect(6, 6, 58, 42, 4))
    b = [planks(P, 6, 6, 58, 42, "wood", n=4, dirn="h", s=3, seed=4, nails=False)]
    b.append(P.shape(rect(6, 6, 58, 42, 4), "darkiron", s=1, lw=2, flat=True, fill_override="none"))
    for x in (14, 52):
        b.append(P.shape(rect(x - 3, 6, 6, 42, 1), "darkiron", s=1, lw=1.4))
    b.append(lin(rect(7.5, 7.5, 55, 39, 3), PAL["darkiron"][1], 2))
    b.append(fill(" ".join(ell(x, y, 1.1) for x in (14, 52) for y in (10, 20, 34, 44)), PAL["metal"][0]))
    b.append(P.shape(rect(29, 40, 12, 10, 2), "bronze", s=1, lw=1.4))
    b.append(fill(rect(34, 43, 2, 4), INK))
    return sh, J(b), ""


def fireplace(P, W, H):
    sh = sh_(P, rect(4, 0, 116, 62, 4), 4, 4)
    b = [P.shape(rect(4, 0, 116, 62, 4), "stone", s=4)]
    rnd = random.Random(5)
    blocks = []
    for (x0, y0, x1, y1) in [(4, 0, 30, 62), (94, 0, 120, 62)]:
        y = y0
        while y < y1 - 3:
            h = min(rnd.uniform(12, 18), y1 - y)
            blocks.append(rect(x0 + 0.8, y + 0.8, x1 - x0 - 1.6, h - 1.6, 2))
            y += h
    x = 30
    while x < 94:
        w = min(rnd.uniform(14, 20), 94 - x)
        blocks.append(rect(x + 0.8, 48.8, w - 1.6, 12.4, 2))
        x += w
    for d in blocks:
        b.append(P.shape(d, "stone", s=1.6, lw=1.5))
    b.append(P.shape(rect(30, 0, 64, 49, 2), "coal", s=2, lw=1.6))
    # logs + fire
    b.append(P.shape(rect(40, 26, 44, 9, 4), "wood", s=1.5, lw=1.5))
    b.append(P.shape(poly([(46, 14), (80, 36), (76, 41), (42, 19)]), "wood", s=1.5, lw=1.5))
    cb, ce = coals(P, 62, 30, 24, 14, seed=4, hot=1.0, n=14)
    e = [ce]
    flame = smooth([(50, 34), (54, 20), (60, 26), (63, 10), (68, 24), (74, 18), (76, 34), (62, 40)])
    e.append(fill(flame, EMBER, 0.85))
    e.append(fill(smooth([(56, 34), (60, 24), (64, 28), (66, 18), (70, 30), (64, 37)]), EMBER_HOT, 0.95))
    e.append(glow(P, 62, 30, 0, EMBER, 0.4, rx=56, ry=42))
    b.append(fill(ell(62, 4, 30, 5), SOOT, 0.35, blur_filter(P, 3)))
    return sh, J(b), J(e)


def rug(P, W, H, role, seed):
    m = 8
    b = [P.shape(rect(m, m, W - 2 * m - 4, H - 2 * m - 4, 2), role, s=2, lw=1.8)]
    w, h = W - 2 * m - 4, H - 2 * m - 4
    l, bb, s = PAL[role]
    b.append(lin(rect(m + 6, m + 6, w - 12, h - 12, 1), PAL["straw"][1], 2.2, 0.8))
    b.append(lin(rect(m + 10, m + 10, w - 20, h - 20, 1), s, 1.2, 0.8))
    cx, cy = m + w / 2, m + h / 2
    b.append(fill(poly([(cx, cy - h * 0.3), (cx + w * 0.22, cy), (cx, cy + h * 0.3), (cx - w * 0.22, cy)]), s, 0.55))
    b.append(lin(poly([(cx, cy - h * 0.22), (cx + w * 0.15, cy), (cx, cy + h * 0.22), (cx - w * 0.15, cy)]), PAL["straw"][1], 1.6, 0.8))
    b.append(fill(ell(cx, cy, 4), PAL["straw"][1], 0.9))
    # diamond border motifs
    for i in range(int((w - 20) / 12)):
        x = m + 14 + i * 12
        for y in (m + 8, m + h - 8):
            b.append(fill(poly([(x, y - 2), (x + 2, y), (x, y + 2), (x - 2, y)]), l, 0.8))
    # fringe
    fr = " ".join(f"M{m-5},{y:.1f} L{m},{y:.1f} M{m+w},{y:.1f} L{m+w+5},{y:.1f}" for y in [m + 3 + i * 3 for i in range(int((h - 6) / 3) + 1)])
    b.append(lin(fr, PAL["linen"][2], 1.0, 0.9))
    sh = ""
    return sh, J(b), ""


def rug_red(P, W, H):
    return rug(P, W, H, "cloth", 1)


def rug_brown(P, W, H):
    return rug(P, W, H, "brown", 2)


def stairs(P, W, H, down=False):
    sh = sh_(P, rect(6, 4, 82, 116), 3, 3, op=0.4)
    b = [P.shape(rect(4, 4, 84, 118, 2), "wood", s=2)]
    n = 8
    for i in range(n):
        y = 8 + i * 13.5
        b.append(P.shape(rect(10, y, 72, 12.5, 1.5), "wood", s=2, lw=1.5))
        if down:
            b.append(fill(rect(10, y, 72, 12.5, 1.5), SOOT, 0.08 + i * 0.09))
        else:
            b.append(fill(rect(10, y + 9, 72, 3.5), INK, 0.3))
    for x in (6, 84):
        b.append(P.shape(rect(x - 3, 4, 6, 118, 2), "brown", s=1, lw=1.5))
    if down:
        hg = hatch(P, 35)
        b.append(fill(rect(10, 70, 72, 50), hg, 0.6))
    return sh, J(b), ""


def stairs_up(P, W, H):
    return stairs(P, W, H, False)


def stairs_down(P, W, H):
    return stairs(P, W, H, True)


def lantern_post(P, W, H):
    cx, cy = 22, 22
    sh = sh_(P, ell(cx, cy, 10) + " " + rect(cx, cy - 2, 16, 4), 4, 5)
    b = [P.shape(ell(cx, cy, 9), "darkiron", s=2), P.shape(rect(cx, cy - 2, 16, 4, 1), "darkiron", s=0.5, lw=1.2)]
    b.append(P.shape(rect(cx - 6, cy - 6, 12, 12, 2), "darkiron", s=1.5, lw=1.6))
    e = [glow(P, cx, cy, 21, EMBER_HOT, 0.6), fill(rect(cx - 3.5, cy - 3.5, 7, 7, 1.5), "#ffe2a0", 0.95)]
    b.append(P.detail(f"M{cx-6},{cy} L{cx+6},{cy} M{cx},{cy-6} L{cx},{cy+6}", "darkiron", 0.6))
    return sh, J(b), J(e)


def candle(P, W, H):
    sh = sh_(P, ell(11, 11, 6), 2, 2)
    b = [P.shape(ell(11, 11, 7), "bronze", s=1, lw=1.2)]
    cb, ce = candle_top(P, 11, 11, 3.6)
    return sh, J(b + [cb]), ce


def well(P, W, H):
    cx, cy = 54, 54
    sh = sh_(P, ell(cx, cy, 44))
    b = [P.shape(ell(cx, cy, 44), "stone", s=5)]
    rnd = random.Random(3)
    b.append(P.detail(" ".join(f"M{cx+30*math.cos(a):.1f},{cy+30*math.sin(a):.1f} L{cx+44*math.cos(a):.1f},{cy+44*math.sin(a):.1f}" for a in [i * math.tau / 14 + 0.1 for i in range(14)]), "stone", 0.6, 0.8))
    b.append(P.detail(ell(cx, cy, 37), "stone", 0.4, 0.6))
    b.append(P.shape(ell(cx, cy, 30), "stone", s=-3, hl=False, lw=2))
    b.append(fill(ell(cx, cy, 29), "#1c140e", 1))
    b.append(fill(ell(cx + 3, cy + 3, 21), PAL["water"][2], 0.9))
    b.append(fill(ell(cx - 4, cy - 4, 8, 4), PAL["water"][0], 0.5))
    # posts + roof frame (small gable across the well)
    for x in (cx - 46, cx + 40):
        b.append(P.shape(rect(x, cy - 4, 8, 8, 1.5), "wood", s=1, lw=1.5))
    b.append(P.shape(rect(cx - 50, cy - 18, 102, 18, 2), "roof_a", s=1, flat=True, fill_override=PAL["roof_a"][0], lw=2))
    b.append(P.shape(rect(cx - 50, cy, 102, 18, 2), "roof_a", s=1, flat=True, lw=2))
    b.append(fill(rect(cx - 50, cy, 102, 18, 2), hatch(P, -35), 0.6))
    b.append(P.detail(" ".join(f"M{x},{cy-17} L{x},{cy+17}" for x in range(cx - 44, cx + 50, 9)), "roof_a", 0.4, 0.6))
    b.append(P.detail(f"M{cx-50},{cy} L{cx+52},{cy}", "roof_a", 1.0))
    # bucket on rim
    b.append(P.shape(ell(cx + 22, cy + 30, 8), "wood", s=1.5, lw=1.6))
    b.append(lin(ell(cx + 22, cy + 30, 7), PAL["darkiron"][1], 1.3))
    b.append(fill(ell(cx + 22, cy + 30, 5), PAL["water"][1], 1))
    b.append(lin(f"M{cx+14},{cy+30} Q{cx+22},{cy+20} {cx+30},{cy+30}", INK, 1.0))
    b.append(lin(f"M{cx+22},{cy+22} Q{cx+16},{cy+12} {cx+6},{cy+18}", PAL["straw"][2], 1.0))
    return sh, J(b), ""


def notice_board(P, W, H):
    sh = sh_(P, rect(6, 6, 128, 54, 3))
    b = [P.shape(rect(6, 6, 128, 54, 3), "wood", s=3)]
    b.append(P.shape(rect(11, 11, 118, 44, 2), "brown", s=-2, hl=False, lw=1.5))
    b.append(P.shape(rect(2, 4, 136, 6, 2), "wood", s=1, lw=1.6))
    rnd = random.Random(4)
    for (x, y, w, h, rot) in [(16, 14, 22, 28, -4), (42, 16, 26, 20, 3), (72, 13, 20, 26, -2), (96, 18, 28, 18, 5), (46, 38, 18, 14, -6), (98, 38, 18, 15, 2)]:
        b.append(f'<g transform="rotate({rot} {x+w/2} {y+h/2})">' + P.shape(rect(x, y, w, h, 0.5), "paper", s=1, lw=1.1) +
                 P.detail(" ".join(f"M{x+3},{y+5+i*3.4:.1f} h{w-6 - rnd.uniform(0,6):.1f}" for i in range(int((h - 6) / 3.4))), "paper", 0.25, 0.6) + "</g>")
        b.append(fill(ell(x + w / 2, y + 2.5, 1.4), RUB))
    return sh, J(b), ""


def most_wanted_board(P, W, H):
    """Inn wall board (192x96): dark frame, cork field, carved header plank, pinned wanted sheets
    with tiny portrait squares and red wax seals."""
    sh = sh_(P, rect(4, 6, 184, 84, 3), 4, 4)
    b = [P.shape(rect(4, 8, 184, 82, 3), "wood", s=3, fill_override=PAL["brown"][2])]
    b.append(P.shape(rect(11, 22, 170, 61, 1.5), "brown", s=-2, hl=False, lw=1.4, fill_override="#9a7448"))
    rnd = random.Random(9)
    b.append(fill(" ".join(ell(rnd.uniform(14, 178), rnd.uniform(25, 80), 0.6) for _ in range(40)), INK, 0.55))
    # carved header plank with a recessed (blank) field and rubric lozenges
    b.append(P.shape(smooth([(46, 8), (96, 3), (146, 8), (152, 15), (146, 23), (96, 26), (46, 23), (40, 15)], t=0.25), "wood", s=1.5, lw=1.6))
    b.append(P.shape(rect(56, 10, 80, 10, 2), "brown", s=-1, hl=False, lw=1.0, fill_override=PAL["brown"][2]))
    for x in (50, 142):
        b.append(fill(poly([(x, 12), (x + 3, 15), (x, 18), (x - 3, 15)]), RUB))
    sheets = [(18, 28, 30, 40, -4), (54, 30, 28, 38, 3), (88, 27, 30, 41, -2), (124, 30, 28, 38, 4), (156, 28, 24, 34, -3)]
    for i, (x, y, w, h, rot) in enumerate(sheets):
        g = [P.shape(rect(x, y, w, h, 0.5), "paper", s=1, lw=1.1)]
        px, py, pw = x + w * 0.22, y + 6, w * 0.56
        g.append(P.shape(rect(px, py, pw, pw * 0.95, 0.5), "linen", s=0.6, lw=0.8, fill_override="#c8b48c"))
        g.append(fill(ell(px + pw / 2, py + pw * 0.38, pw * 0.2) + " " + ell(px + pw / 2, py + pw * 0.95, pw * 0.36, pw * 0.3), "#5a4430", 0.85))
        ty = py + pw + 4
        g.append(P.detail(" ".join(f"M{x+3},{ty+k*3.2:.1f} h{w-6-rnd.uniform(0,7):.1f}" for k in range(int((y + h - ty - 5) / 3.2) + 1)), "paper", 0.25, 0.6))
        g.append(fill(ell(x + w - 6, y + h - 6, 3.2), RUB) + lin(ell(x + w - 6, y + h - 6, 3.2), INK, 0.7) + fill(ell(x + w - 7, y + h - 7, 1), "#e8907a", 0.8))
        if i == 2:   # one notice struck through in red (a fallen adventurer)
            g.append(lin(f"M{x+2},{y+h-4} L{x+w-2},{y+4}", RUB, 1.4, 0.9))
        b.append(f'<g transform="rotate({rot} {x+w/2} {y+h/2})">' + J(g) + "</g>")
        b.append(fill(ell(x + w / 2, y + 2.5, 1.6), GILT) + lin(ell(x + w / 2, y + 2.5, 1.6), INK, 0.5))
    for x, y in [(8, 12), (184, 12), (8, 86), (184, 86)]:
        b.append(fill(ell(x, y, 1.6), PAL["darkiron"][0]) + lin(ell(x, y, 1.6), INK, 0.5))
    emit = glow(P, 30, 70, 50, EMBER_HOT, 0.12)
    return sh, J(b), emit


def market_stall(P, W, H):
    sh = sh_(P, rect(8, 8, 172, 104, 3), 6, 7)
    b = []
    # counter with produce visible at the front (south)
    b.append(planks(P, 12, 84, 164, 26, "wood", n=2, dirn="h", s=2, seed=8))
    rnd = random.Random(5)
    for i, x in enumerate(range(24, 170, 22)):
        b.append(P.shape(ell(x, 98, 9.5, 8), "straw", s=1.5, lw=1.4))
        role = ["apple", "cabbage", "straw", "apple", "brown", "cabbage", "apple"][i % 7]
        b.append(fill(" ".join(ell(x + rnd.gauss(0, 2.5), 97 + rnd.gauss(0, 2), 2.6) for _ in range(5)), PAL[role][1]))
        b.append(lin(" ".join(ell(x + rnd.gauss(0, 2.5), 97 + rnd.gauss(0, 2), 2.6) for _ in range(3)), INK, 0.5, 0.6))
    # striped awning, two planes split by the ridge (east-west)
    for i in range(8):
        role = "cloth" if i % 2 == 0 else "linen"
        x = 8 + i * 21.5
        b.append(P.shape(rect(x, 8, 21.5, 40), role, flat=True, fill_override=PAL[role][0] if role == "linen" else PAL[role][1], line=False))
        b.append(P.shape(rect(x, 48, 21.5, 34), role, flat=True, fill_override=PAL[role][1] if role == "linen" else PAL[role][2], line=False))
    b.append(fill(rect(8, 48, 172, 34), hatch(P, -35), 0.45))
    scallop = "M8,82 " + " ".join(f"q5.4,7 10.75,0" for _ in range(16))
    b.append(f'<path d="{scallop} L180,82 Z" fill="{PAL["cloth"][2]}" stroke="{INK}" stroke-width="1.4"/>')
    b.append(lin(rect(8, 8, 172, 74), INK, 2.2))
    b.append(lin("M8,48 L180,48", INK, 1.6))
    for x in (8, 180):
        b.append(P.shape(rect(x - 3, 80, 6, 30, 1.5), "wood", s=1, lw=1.4))
    return sh, J(b), ""


def cart(P, W, H):
    sh = sh_(P, rect(14, 14, 86, 66, 3), 5, 6)
    b = []
    for y in (8, 78):
        b.append(P.shape(rect(36, y, 40, 10, 3), "wood", s=1.5, lw=1.6))
        b.append(P.detail(f"M44,{y} L44,{y+10} M56,{y} L56,{y+10} M68,{y} L68,{y+10}", "wood", 0.4))
        b.append(lin(f"M36,{y+1} L76,{y+1} M36,{y+9} L76,{y+9}", PAL["darkiron"][1], 1.2))
    b.append(lin("M56,8 L56,88", INK, 3.6))
    b.append(planks(P, 14, 16, 86, 64, "wood", n=6, dirn="v", s=3, seed=4))
    b.append(P.shape(blob(56, 48, 34, 9, 0.1, 3, squash=0.75), "straw", s=4))
    b.append(P.detail(" ".join(f"M{30+i*7},{30+(i%3)*12} l{6 - (i%2)*10},{4+(i%2)*3}" for i in range(9)), "straw", 0.5, 0.8))
    for y in (26, 66):
        b.append(P.shape(rect(98, y, 28, 5, 2), "wood", s=1, lw=1.4))
    b.append(P.shape(rect(120, 26, 5, 45, 2), "wood", s=1, lw=1.3))
    return sh, J(b), ""


def beer_table(P, W, H):
    sh = sh_(P, rect(6, 8, 114, 80, 3))
    b = [planks(P, 6, 8, 114, 16, "wood", n=1, dirn="h", s=2, seed=1),
         planks(P, 6, 72, 114, 16, "wood", n=1, dirn="h", s=2, seed=2),
         planks(P, 6, 30, 114, 36, "wood", n=3, dirn="h", s=3, seed=3)]
    b.append(tankard(P, 28, 40, 5.5))
    b.append(tankard(P, 92, 56, 5.5))
    b.append(tankard(P, 70, 40, 5.5))
    b.append(plate(P, 48, 54, 7, seed=3))
    return sh, J(b), ""


def sign(P, W, H, kind):
    sh = sh_(P, rect(6, 4, 66, 8) + " " + rect(14, 14, 50, 28, 3), 4, 4)
    b = [P.shape(rect(4, 4, 70, 6, 2), "darkiron", s=1, lw=1.6),
         P.detail("M10,10 Q20,22 30,10 M70,10 Q60,22 50,10", "darkiron", 1.0),
         lin("M20,10 L20,15 M58,10 L58,15", INK, 1.2),
         P.shape(rect(12, 14, 54, 28, 3), "wood", s=3),
         lin(rect(15, 17, 48, 22, 2), GILT, 0.9, 0.8)]
    cx, cy = 39, 28
    if kind == "smithy":
        an = [(cx - 15, cy - 5), (cx + 12, cy - 5), (cx + 15, cy - 2), (cx + 6, cy), (cx + 5, cy + 5), (cx + 9, cy + 8), (cx - 9, cy + 8), (cx - 5, cy + 5), (cx - 6, cy), (cx - 16, cy - 2)]
        b.append(P.shape(poly(an), "darkiron", s=1, lw=1.3))
    elif kind == "inn":
        wy = smooth([(cx - 16, cy + 2), (cx - 8, cy - 6), (cx - 2, cy - 2), (cx + 2, cy - 8), (cx + 8, cy - 4), (cx + 4, cy + 2), (cx - 4, cy + 6)])
        b.append(P.shape(wy, "cloth", s=1, lw=1.2))
        b.append(P.shape(poly([(cx - 4, cy - 2), (cx + 2, cy - 12), (cx + 6, cy - 3)]), "cloth", s=0.5, lw=1))
        b.append(P.shape(rect(cx + 8, cy - 2, 8, 9, 1.5), "bronze", s=0.5, lw=1.1))
        b.append(fill(rect(cx + 8.5, cy - 2, 7, 2.5, 1), "#f2ead2"))
    else:
        b.append(lin(" ".join(f"M{cx-6},{cy+8} L{cx-10+i*2.2:.1f},{cy-8}" for i in range(5)), PAL["straw"][2], 1.6))
        b.append(lin(" ".join(f"M{cx-6},{cy+8} L{cx-10+i*2.2:.1f},{cy-8}" for i in range(5)), PAL["straw"][0], 0.8))
        b.append(fill(" ".join(ell(cx - 10 + i * 2.2, cy - 8, 1.4, 2.4) for i in range(5)), PAL["straw"][1]))
        b.append(lin(f"M{cx-9},{cy+2} h7", RUB, 1.2))
        b.append(P.shape(ell(cx + 9, cy + 2, 6), "apple", s=1, lw=1.2))
        b.append(P.shape(ell(cx + 11, cy - 5, 2.2, 1.2), "green", s=0.3, lw=0.6))
    return sh, J(b), ""


def sign_smithy(P, W, H):
    return sign(P, W, H, "smithy")


def sign_inn(P, W, H):
    return sign(P, W, H, "inn")


def sign_grocer(P, W, H):
    return sign(P, W, H, "grocer")


def fence_h(P, W, H):
    sh = sh_(P, rect(0, 9, 64, 5), 2, 3, op=0.4)
    b = [P.shape(rect(-2, 8, 68, 4, 1), "wood", s=1, lw=1.4), P.shape(rect(-2, 14, 68, 4, 1), "wood", s=1, lw=1.4)]
    for x in (16, 48):
        b.append(P.shape(rect(x - 4, 7, 8, 12, 1.5), "wood", s=1.5, lw=1.6))
        b.append(P.detail(ell(x, 13, 1.8), "wood", 0.4))
    return sh, J(b), ""


def fence_v(P, W, H):
    sh = sh_(P, rect(9, 0, 5, 64), 2, 3, op=0.4)
    b = [P.shape(rect(8, -2, 4, 68, 1), "wood", s=1, lw=1.4), P.shape(rect(14, -2, 4, 68, 1), "wood", s=1, lw=1.4)]
    for y in (16, 48):
        b.append(P.shape(rect(7, y - 4, 12, 8, 1.5), "wood", s=1.5, lw=1.6))
    return sh, J(b), ""


def bush(P, W, H, flowers=False):
    cx, cy = 36, 36
    sh = sh_(P, blob(cx, cy, 30, 9, 0.08, 4))
    b = [P.shape(blob(cx, cy, 30, 9, 0.08, 4), "foliage", s=3)]
    rnd = random.Random(3)
    for i in range(7):
        a = i / 7 * math.tau
        b.append(P.shape(blob(cx + math.cos(a) * 15, cy + math.sin(a) * 15, 12, 7, 0.1, i + 2), "foliage", s=2.2, lw=1.6))
    b.append(P.shape(blob(cx - 3, cy - 3, 12, 7, 0.1, 30), "foliage", s=2.2, lw=1.6))
    b.append(P.detail(" ".join(f"M{cx+rnd.uniform(-22,22):.1f},{cy+rnd.uniform(-22,22):.1f} q2,2 4,0" for _ in range(10)), "foliage", 0.5, 0.7))
    if flowers:
        cols = [PAL["cloth"][0], "#f2ead6", PAL["straw"][0], "#c8b4e0"]
        for i in range(16):
            x, y = cx + rnd.uniform(-22, 22), cy + rnd.uniform(-22, 22)
            if math.hypot(x - cx, y - cy) > 25:
                continue
            b.append(fill(ell(x, y, 2.4), rnd.choice(cols)))
            b.append(lin(ell(x, y, 2.4), INK, 0.6, 0.8))
            b.append(fill(ell(x, y, 0.8), PAL["gold"][1]))
    return sh, J(b), ""


def bush_flower(P, W, H):
    return bush(P, W, H, True)


def rock(P, cx, cy, r, sq, seed):
    o = [P.shape(blob(cx, cy, r, 6, 0.14, seed, squash=sq), "stone", s=r * 0.2)]
    o.append(P.detail(f"M{cx-r*0.4:.1f},{cy-r*0.1:.1f} l{r*0.3:.1f},{r*0.2:.1f} l{r*0.2:.1f},-{r*0.15:.1f} M{cx+r*0.1:.1f},{cy+r*0.3*sq:.1f} l{r*0.3:.1f},-{r*0.1:.1f}", "stone", 0.5, 0.8))
    return J(o)


def rock_a(P, W, H):
    sh = sh_(P, blob(30, 22, 24, 6, 0.14, 3, squash=0.7))
    return sh, rock(P, 30, 22, 24, 0.7, 3), ""


def rock_b(P, W, H):
    sh = sh_(P, blob(40, 30, 32, 6, 0.14, 5, squash=0.7) + " " + blob(66, 40, 12, 6, 0.14, 8))
    return sh, J([rock(P, 40, 30, 32, 0.7, 5), rock(P, 68, 44, 12, 0.9, 8)]), ""


def flowers(P, W, H):
    rnd = random.Random(7)
    b = []
    cols = [PAL["cloth"][0], "#f2ead6", PAL["straw"][0], "#c8b4e0", PAL["apple"][0]]
    for i in range(9):
        x, y = 10 + rnd.uniform(0, 44), 10 + rnd.uniform(0, 44)
        b.append(lin(" ".join(f"M{x},{y} l{rnd.uniform(-4,4):.1f},{rnd.uniform(-6,-2):.1f}" for _ in range(3)), PAL["foliage"][2], 1.0))
        b.append(fill(ell(x + rnd.uniform(-2, 2), y - 4, 2.4), rnd.choice(cols)))
        b.append(lin(ell(x, y - 4, 2.4), INK, 0.6, 0.7))
    b.append(lin(" ".join(f"M{rnd.uniform(6,58):.1f},{rnd.uniform(8,60):.1f} l1.5,-5 l1.5,5" for _ in range(10)), INK, 0.8, 0.6))
    return "", J(b), ""


def tree_scaled(P, W, H, seed, role="foliage"):
    k = W / 512.0
    old = P.lw_mul
    P.lw_mul = 1.0 / k * 0.62 / 3.2 * 1.0
    P.lw_mul = 2.1 / (3.2 * k)
    body = f'<g transform="scale({k:.5f})">' + subjects.tree(P, cx=246, cy=240, r=200, seed=seed, shadow=False, role=role) + "</g>"
    P.lw_mul = old
    sd = blob(246 + 200 * 0.14, 240 + 200 * 0.18, 200 * 0.98, 11, 0.06, seed)
    sh = f'<g transform="scale({k:.5f})">' + f'<path d="{sd}" fill="{hatch(P, -35, sp=3.6/k, w=0.95/k)}" opacity="0.55"/>' + \
        f'<path d="{sd}" fill="{INK}" opacity="0.18" {blur_filter(P, 3/k)}/></g>'
    return sh, body, ""


def tree_oak_a(P, W, H):
    return tree_scaled(P, W, H, 7)


def tree_oak_b(P, W, H):
    return tree_scaled(P, W, H, 12, "foliage2")


def tree_small(P, W, H):
    return tree_scaled(P, W, H, 21)


def tree_pine(P, W, H):
    cx, cy = 82, 82
    sh = sh_(P, ell(cx, cy, 70), 10, 12)
    b = []
    rnd = random.Random(3)
    for layer, (R, n) in enumerate([(72, 11), (54, 9), (36, 7), (18, 5)]):
        pts = []
        for i in range(n * 2):
            a = i / (n * 2) * math.tau + layer * 0.3
            r = R if i % 2 == 0 else R * 0.72
            pts.append((cx + math.cos(a) * r * rnd.uniform(0.95, 1.05), cy + math.sin(a) * r * rnd.uniform(0.95, 1.05)))
        b.append(P.shape(smooth(pts, t=0.25), "foliage", s=R * 0.1, fill_override=["#6c7a52", "#7a8a5c", "#8a9a68", "#9aa874"][layer]))
        b.append(P.detail(" ".join(f"M{cx+math.cos(a)*R*0.3:.1f},{cy+math.sin(a)*R*0.3:.1f} L{cx+math.cos(a)*R*0.85:.1f},{cy+math.sin(a)*R*0.85:.1f}" for a in [i / n * math.tau + layer * 0.3 for i in range(n)]), "foliage", 0.4, 0.55))
    b.append(fill(ell(cx, cy, 3), PAL["wood"][2]))
    return sh, J(b), ""


def haybale(P, W, H):
    sh = sh_(P, rect(6, 8, 50, 44, 4))
    b = [P.shape(rect(6, 8, 50, 44, 5), "straw", s=4)]
    rnd = random.Random(2)
    b.append(P.detail(" ".join(f"M{rnd.uniform(9,48):.1f},{rnd.uniform(11,48):.1f} l{rnd.uniform(3,7):.1f},{rnd.uniform(-1.5,1.5):.1f}" for _ in range(26)), "straw", 0.45, 0.8))
    for x in (20, 42):
        b.append(lin(f"M{x},8 L{x},52", INK, 2.2))
        b.append(lin(f"M{x},8 L{x},52", PAL["brown"][1], 1.0))
    return sh, J(b), ""


def heap(P, W, H, role, seed, vein=None):
    rnd = random.Random(seed)
    cx, cy = 38, 30
    sh = sh_(P, blob(cx, cy, 30, 8, 0.1, seed, squash=0.72))
    b = [P.shape(blob(cx, cy, 30, 8, 0.1, seed, squash=0.72), role, s=4)]
    lumps = sorted([(cx + rnd.gauss(0, 13), cy + rnd.gauss(0, 8), rnd.uniform(4, 8)) for _ in range(16)], key=lambda t: -(t[0] + t[1]))
    for i, (x, y, r) in enumerate(lumps):
        b.append(P.shape(blob(x, y, r, 5, 0.2, seed + i), role, s=r * 0.3, lw=1.5))
        if vein and i % 2 == 0:
            b.append(lin(f"M{x-r*0.5:.1f},{y:.1f} l{r*0.4:.1f},{-r*0.3:.1f} l{r*0.5:.1f},{r*0.2:.1f}", vein, 1.4, 0.95))
    return sh, J(b), ""


def coal_pile(P, W, H):
    sh, b, e = heap(P, W, H, "coal", 4)
    return sh, b + lin("M30,22 l3,-2 M44,28 l3,-1 M24,34 l2,-2", "#8a8078", 0.8, 0.8), e


def ore_pile(P, W, H):
    return heap(P, W, H, "stone", 6, vein="#b06030")


def woodpile(P, W, H):
    sh = sh_(P, rect(6, 8, 82, 46, 3))
    b = []
    for row in range(2):
        for i in range(5 - row):
            x, y = 16 + i * 16 + row * 8, 42 - row * 18
            b.append(end_grain(P, x, y, 8.5, seed=i + row * 5))
    b.append(P.shape(rect(8, 6, 78, 7, 3), "wood", s=1, lw=1.4))
    return sh, J(b), ""


def produce_crate(P, W, H):
    sh = sh_(P, rect(5, 5, 50, 50))
    b = [P.shape(rect(5, 5, 50, 50, 2), "wood", s=3), P.shape(rect(10, 10, 40, 40, 1.5), "brown", s=-2, hl=False, lw=1.4)]
    rnd = random.Random(3)
    pts = [(14 + (i % 4) * 10 + rnd.uniform(-1, 1), 15 + (i // 4) * 10 + rnd.uniform(-1, 1)) for i in range(16)]
    for i, (x, y) in enumerate(pts):
        if x < 30:
            b.append(P.shape(ell(x, y, 4.6), "apple", s=1, lw=1.1))
            b.append(fill(ell(x - 1.4, y - 1.4, 1.2), "#f4c8a8", 0.7))
        else:
            b.append(P.shape(ell(x, y, 5), "cabbage", s=1.2, lw=1.1))
            b.append(lin(f"M{x-2},{y} q2,-2 4,0", PAL["cabbage"][2], 0.6))
    b.append(P.detail("M30,10 L30,50", "wood", 0.8))
    return sh, J(b), ""


def grain_sacks(P, W, H):
    sh = sh_(P, blob(38, 30, 30, 6, 0.1, 2, squash=0.8))
    b = [sack_top(P, 22, 38, 16, 2), sack_top(P, 52, 40, 15, 5), sack_top(P, 38, 20, 15, 7)]
    b.append(fill(" ".join(ell(60 + i * 2.4, 54 + (i % 2), 0.8, 0.5) for i in range(6)), PAL["straw"][0]))
    return sh, J(b), ""


def altar(P, W, H):
    sh = sh_(P, rect(6, 8, 114, 46, 3))
    b = [P.shape(rect(6, 8, 114, 46, 3), "stone", s=4), P.shape(rect(32, 6, 62, 50, 2), "cloth", s=3, lw=1.8),
         lin(rect(35, 9, 56, 44, 1), GILT, 1.0, 0.85)]
    b.append(book(P, 50, 20, 26, 18, "cloth", open_=True))
    e = []
    for x, y in [(16, 18), (16, 44), (110, 18), (110, 44)]:
        b.append(P.shape(ell(x, y, 6), "bronze", s=1, lw=1.2))
        cb, ce = candle_top(P, x, y, 3.2)
        b.append(cb)
        e.append(ce)
    b.append(lin("M63,40 L63,50 M59,44 L67,44", GILT, 1.4))
    return sh, J(b), J(e)


def pew(P, W, H):
    sh = sh_(P, rect(4, 4, 150, 28, 3), 3, 4)
    b = [P.shape(rect(4, 4, 150, 8, 2), "brown", s=1.5, lw=1.6), planks(P, 4, 12, 150, 20, "brown", n=2, dirn="h", s=2, seed=4)]
    for x in (4, 150):
        b.append(P.shape(rect(x - 1, 2, 6, 32, 2), "brown", s=1, lw=1.5))
    return sh, J(b), ""


def washtub(P, W, H):
    cx, cy = 34, 34
    sh = sh_(P, ell(cx, cy, 28))
    b = [P.shape(ell(cx, cy, 28), "wood", s=4), lin(ell(cx, cy, 26), PAL["darkiron"][1], 1.8),
         P.shape(ell(cx, cy, 22), "wood", s=-2, hl=False, lw=1.6),
         liquid(P, ell(cx, cy, 21), "water", cx, cy, 21, 21, ripples=1)]
    rnd = random.Random(2)
    b.append(fill(" ".join(ell(cx + rnd.gauss(-4, 6), cy + rnd.gauss(4, 6), rnd.uniform(1.4, 3.2)) for _ in range(12)), "#f4f2ea", 0.9))
    b.append(planks(P, cx + 2, cy - 22, 14, 26, "wood", n=1, dirn="v", s=1, nails=False, seed=3))
    b.append(P.detail(" ".join(f"M{cx+4},{cy-18+i*3} h10" for i in range(6)), "wood", 0.5))
    return sh, J(b), ""


def eggs_splat(P, W, H):
    rnd = random.Random(9)
    b = []
    for (x, y, r) in [(30, 26, 14), (62, 38, 12), (48, 50, 8)]:
        b.append(fill(blob(x, y, r, 9, 0.35, int(x)), "#f4ecd6", 0.85))
        b.append(lin(blob(x, y, r, 9, 0.35, int(x)), PAL["straw"][2], 0.8, 0.6))
        b.append(fill(ell(x + 1, y + 1, r * 0.38), "#e8b030", 0.95))
        b.append(lin(ell(x + 1, y + 1, r * 0.38), "#a06a10", 0.8))
        b.append(fill(ell(x - r * 0.1, y - r * 0.1, r * 0.12), "#fff2c0", 0.9))
    for i in range(12):
        x, y = 30 + rnd.uniform(-20, 50), 34 + rnd.uniform(-20, 20)
        b.append(fill(ell(x, y, rnd.uniform(0.8, 2)), "#f4ecd6", 0.8))
    for (x, y, a) in [(18, 44, 20), (76, 22, -30), (82, 50, 60)]:
        b.append(f'<g transform="rotate({a} {x} {y})">' + P.shape(f"M{x-5},{y} a5,4 0 0,1 10,0 l-2,-1.5 l-2,1.5 l-2,-1.5 l-2,1.5 Z", "wax", s=0.5, lw=1.0) + "</g>")
    return "", J(b), ""


def gravestone(P, W, H):
    sh = sh_(P, rect(8, 6, 22, 34, 3), 3, 4)
    b = [P.shape(rect(6, 18, 26, 26, 6), "green", s=2, lw=1.4, fill_override="#a8a678"),
         P.shape(f"M8,22 L8,10 a11,8 0 0,1 22,0 L30,22 Z", "stone", s=2.5),
         P.detail("M14,12 L24,12 M19,8 L19,18", "stone", 0.7),
         P.detail("M12,30 l2,-3 M24,34 l-2,-2 M18,38 l1,-3", "foliage", 0.6)]
    return sh, J(b), ""


def loot_pile(P, W, H):
    sh = sh_(P, ell(30, 24, 24, 16))
    b = [P.shape(blob(26, 24, 17, 6, 0.1, 3, squash=0.8), "leather", s=3),
         P.shape(blob(20, 18, 6, 5, 0.2, 4), "leather", s=1, lw=1.4),
         lin("M14,16 Q24,10 30,18", PAL["strap"][1], 2.2)]
    b.append(sword_top(P, 30, 40, 30, -0.35))
    rnd = random.Random(3)
    for i in range(5):
        b.append(P.shape(ell(44 + rnd.uniform(-4, 8), 24 + rnd.uniform(-6, 6), 2.6), "gold", s=0.5, lw=0.9))
    b.append(bottle_top(P, 50, 12, 4.4, "redp"))
    return sh, J(b), ""


def door_mat(P, W, H):
    b = [P.shape(rect(6, 6, 82, 26, 3), "straw", s=1.5, lw=1.6)]
    b.append(lin(rect(10, 10, 74, 18, 2), PAL["brown"][1], 1.4, 0.8))
    b.append(P.detail(" ".join(f"M{x},{11} l3,8 l-3,8" for x in range(13, 84, 5)), "straw", 0.35, 0.6))
    return "", J(b), ""


def workbench(P, W, H):
    sh = sh_(P, rect(4, 6, 148, 48, 3))
    b = [planks(P, 4, 6, 148, 48, "wood", n=3, dirn="h", s=3, seed=17), P.shape(rect(6, 40, 20, 14, 2), "darkiron", s=1, lw=1.4)]
    # saw
    b.append(P.shape(poly([(34, 16), (78, 12), (80, 22), (36, 26)]), "metal", s=1, lw=1.3))
    b.append(P.detail(" ".join(f"M{36+i*3.6:.1f},{26-i*0.3:.1f} l1.8,1.5" for i in range(12)), "metal", 0.5))
    b.append(P.shape(rect(78, 10, 12, 14, 3), "wood", s=1, lw=1.4))
    # hammer, plane, chisel
    b.append(P.shape(poly([(98, 40), (128, 30), (129, 33), (99, 43)]), "wood", s=0.8, lw=1.3))
    b.append(P.shape(rect(124, 24, 7, 16, 1.5), "darkiron", s=1, lw=1.4))
    b.append(P.shape(rect(100, 12, 26, 10, 2), "wood", s=1.5, lw=1.5))
    b.append(P.shape(rect(108, 13, 8, 8, 1), "darkiron", s=0.5, lw=1))
    b.append(P.shape(poly([(56, 40), (82, 42), (82, 44.5), (56, 43)]), "metal", s=0.5, lw=1.1))
    rnd = random.Random(4)
    b.append(lin(" ".join(f"M{rnd.uniform(30,140):.1f},{rnd.uniform(30,52):.1f} a2.5,2 0 1,1 3,1" for _ in range(9)), PAL["wood"][0], 1.0, 0.9))
    return sh, J(b), ""


def dummy_target(P, W, H):
    cx, cy = 30, 30
    sh = sh_(P, ell(cx, cy, 20, 16) + " " + rect(4, cy - 4, 52, 8))
    b = [P.shape(rect(4, cy - 3.5, 52, 7, 2), "wood", s=1, lw=1.5),
         P.shape(ell(cx, cy, 16, 13), "straw", s=3)]
    rnd = random.Random(5)
    b.append(P.detail(" ".join(f"M{cx+rnd.uniform(-12,10):.1f},{cy+rnd.uniform(-9,9):.1f} l{rnd.uniform(2,5):.1f},{rnd.uniform(-2,2):.1f}" for _ in range(14)), "straw", 0.45, 0.8))
    b.append(P.shape(ell(cx, cy, 8), "cloth", s=1, lw=1.2))
    b.append(fill(ell(cx, cy, 5), "#f2ead6"))
    b.append(fill(ell(cx, cy, 2.4), RUB))
    b.append(P.shape(ell(cx, cy - 15, 7, 6), "linen", s=1.5, lw=1.4))
    b.append(lin(f"M{cx-2},{cy-17} l1,1 M{cx+2},{cy-17} l1,1", INK, 0.8))
    b.append(lin(f"M{cx-6},{cy+2} l3,-3 M{cx+8},{cy-6} l-4,3", INK, 1.4))  # arrow shafts
    return sh, J(b), ""


# ---------------------------------------------------------------- waiting area / shop front decor
def waiting_seat(P, W, H):
    """Single outdoor wooden seat with a burgundy cushion (backrest to the north)."""
    sh = sh_(P, rect(12, 10, 40, 44, 4), 3, 4)
    b = [P.shape(rect(9, 12, 6, 40, 2), "wood", s=1.2, lw=1.5), P.shape(rect(49, 12, 6, 40, 2), "wood", s=1.2, lw=1.5),
         planks(P, 13, 18, 38, 34, "wood", n=3, dirn="h", s=2.5, seed=6),
         P.shape(rect(11, 8, 42, 9, 3), "wood", s=1.6, lw=1.7),
         P.detail("M16,12.5 L48,12.5", "wood", 0.4, 0.7)]
    cush = smooth([(19, 23), (32, 21.5), (45, 23), (46.5, 35), (45, 47), (32, 48.5), (19, 47), (17.5, 35)], t=0.4)
    b.append(P.shape(cush, "cloth", s=3))
    b.append(P.detail("M21,35 Q32,33 43,35 M32,25 Q30.5,35 32,46", "cloth", 0.45, 0.6))
    b.append(P.shape(ell(32, 35, 2.2), "gold", s=0.5, lw=1))
    for x, y in ((19, 23), (45, 23), (19, 47), (45, 47)):
        b.append(lin(f"M{x},{y} l{-2 if x < 32 else 2},{-2 if y < 32 else 2}", PAL["straw"][1], 1.2))
    return sh, J(b), ""


def waiting_awning(P, W, H):
    """Small striped awning on two poles with a hanging hourglass sign (waiting area)."""
    sh = sh_(P, rect(8, 6, 176, 42, 3), 5, 6)
    b = []
    n = 8
    w = 176 / n
    for i in range(n):
        role = "cloth" if i % 2 == 0 else "linen"
        x = 8 + i * w
        b.append(P.shape(rect(x, 6, w, 22), role, flat=True, line=False,
                         fill_override=PAL[role][0] if role == "linen" else PAL[role][1]))
        b.append(P.shape(rect(x, 28, w, 16), role, flat=True, line=False,
                         fill_override=PAL[role][1] if role == "linen" else PAL[role][2]))
    b.append(fill(rect(8, 28, 176, 16), hatch(P, -35), 0.4))
    scallop = "M8,44 " + " ".join(f"q{w/4:.2f},7 {w/2:.2f},0" for _ in range(2 * n))
    b.append(f'<path d="{scallop} L184,44 Z" fill="{PAL["cloth"][2]}" stroke="{INK}" stroke-width="1.3"/>')
    b.append(lin(rect(8, 6, 176, 38), INK, 2.0))
    b.append(lin("M8,28 L184,28", INK, 1.4))
    for x in (12, 180):
        b.append(P.shape(rect(x - 3, 40, 6, 20, 1.5), "wood", s=1, lw=1.4))
        b.append(P.shape(ell(x, 41, 4.2), "darkiron", s=0.6, lw=1.2))
    # hanging sign under the valance
    b.append(lin("M86,46 L86,50 M106,46 L106,50", INK, 1.0))
    b.append(P.shape(rect(80, 49, 32, 13, 2), "wood", s=1.5, lw=1.4))
    b.append(lin(rect(82, 51, 28, 9, 1), GILT, 0.6, 0.8))
    b.append(lin("M92,52.5 h8 l-8,6 h8 Z", INK, 0.9))
    b.append(fill("M93.5,57.5 h5 l-2.5,-1.8 Z", PAL["straw"][1]))
    return sh, J(b), ""


def craft_display(P, W, H):
    """Display stand of example smithing work: two swords in a rack, cuirass on a stand, helm on a post, shield."""
    sh = sh_(P, rect(6, 54, 180, 36, 4) + " " + rect(60, 10, 44, 46, 10) + " " + ell(162, 46, 22), 4, 5)
    b = [planks(P, 6, 56, 180, 34, "wood", n=3, dirn="h", s=3, seed=9),
         P.shape(rect(6, 84, 180, 6, 2), "brown", s=1, lw=1.5)]
    # sword rack (left): rail + two swords standing point up
    b.append(P.shape(rect(10, 30, 36, 5, 1.5), "wood", s=1, lw=1.4))
    b.append(sword_top(P, 20, 82, 64, -math.pi / 2 + 0.06))
    b.append(sword_top(P, 36, 82, 58, -math.pi / 2 - 0.06, "metal"))
    b.append(P.shape(rect(10, 70, 36, 6, 1.5), "wood", s=1, lw=1.4))
    # cuirass on a stand (centre)
    cx = 82
    b.append(P.shape(rect(cx - 2.5, 50, 5, 30, 1.5), "wood", s=1, lw=1.3))
    b.append(P.shape(ell(cx, 80, 12, 4), "wood", s=1, lw=1.3))
    b.append(P.shape(rect(cx - 26, 14, 52, 5, 2), "wood", s=1, lw=1.4))
    for sg in (-1, 1):
        b.append(P.shape(ell(cx + sg * 19, 18, 9, 7), "metal", s=2, lw=1.6))
    bp = smooth([(cx - 16, 14), (cx, 18), (cx + 16, 14), (cx + 18, 32), (cx + 11, 48), (cx, 52), (cx - 11, 48), (cx - 18, 32)])
    b.append(P.shape(bp, "metal", s=4))
    b.append(P.detail(f"M{cx},20 L{cx},50 M{cx-11},44 Q{cx},50 {cx+11},44", "metal", 0.6))
    b.append(fill(" ".join(ell(x, y, 1.1) for x, y in [(cx - 12, 20), (cx + 12, 20), (cx - 13, 36), (cx + 13, 36)]), PAL["gold"][1]))
    b.append(P.shape(ell(cx, 9, 5, 4), "wood", s=1, lw=1.3))
    # helm on a post
    hx = 124
    b.append(P.shape(rect(hx - 2.5, 40, 5, 40, 1.5), "wood", s=1, lw=1.3))
    b.append(P.shape(ell(hx, 80, 9, 3.4), "wood", s=1, lw=1.2))
    b.append(P.shape(smooth([(hx - 14, 44), (hx - 14, 30), (hx - 8, 20), (hx, 18), (hx + 8, 20), (hx + 14, 30), (hx + 14, 44), (hx + 6, 46),
                             (hx + 5, 34), (hx - 5, 34), (hx - 6, 46)], t=0.4), "metal", s=3))
    b.append(P.shape(rect(hx - 1.6, 33, 3.2, 12, 1), "metal", s=0.5, lw=1.0))
    b.append(P.detail(f"M{hx},19 L{hx},33 M{hx-13},31 Q{hx},27 {hx+13},31", "metal", 0.5))
    b.append(P.shape(smooth([(hx - 3, 18), (hx, 6), (hx + 3, 18)], t=0.3), "cloth", s=0.6, lw=1.0))
    # round shield leaning at the right
    sx, sy = 162, 46
    b.append(P.shape(ell(sx, sy, 22, 24), "wood", s=3))
    ri = 17
    b.append(P.shape(f"M{sx},{sy-ri} A{ri},{ri} 0 0 1 {sx+ri},{sy} L{sx},{sy} Z", "cloth", s=1, hl=False))
    b.append(P.shape(f"M{sx},{sy+ri} A{ri},{ri} 0 0 1 {sx-ri},{sy} L{sx},{sy} Z", "cloth", s=1, hl=False))
    b.append(lin(ell(sx, sy, 20, 22), PAL["darkiron"][1], 2.2))
    b.append(P.shape(ell(sx, sy, 6), "metal", s=1.5, lw=1.4))
    # parchment price tag on the plinth
    b.append(P.shape(rect(92, 72, 18, 11, 1.5), "paper", s=0.8, lw=1.1))
    b.append(lin("M95,76 h12 M95,79 h8", INK, 0.5, 0.7))
    emit = glow(P, sx - 8, sy - 10, 6, EMBER_HOT, 0.25)
    return sh, J(b), emit


def flower_patch(P, W, H, seed, cols):
    """Small flower clump; stems rooted on the bottom edge so a sway shader can pivot there."""
    rnd = random.Random(seed)
    b = []
    leaves = []
    base_y = H - 1.5
    stems = []
    heads = []
    for i in range(7):
        x0 = 10 + i * 4.6 + rnd.uniform(-1.5, 1.5)
        top = (x0 + rnd.uniform(-6, 6), rnd.uniform(9, 22))
        stems.append(f"M{x0:.1f},{base_y} Q{(x0+top[0])/2+rnd.uniform(-3,3):.1f},{(base_y+top[1])/2:.1f} {top[0]:.1f},{top[1]:.1f}")
        heads.append(top)
    for i in range(6):
        x0 = 9 + i * 6 + rnd.uniform(-2, 2)
        lx, ly = x0 + rnd.choice((-1, 1)) * rnd.uniform(5, 9), base_y - rnd.uniform(9, 16)
        leaves.append(smooth([(x0 - 1.5, base_y), (lx, ly), (x0 + 1.5, base_y)], t=0.5))
    b.append(lin(" ".join(stems), INK, 2.0))
    b.append(lin(" ".join(stems), PAL["green"][1], 1.0))
    for d in leaves:
        b.append(P.shape(d, "foliage", s=0.6, lw=1.0))
    for j, (x, y) in enumerate(heads):
        col = cols[j % len(cols)]
        petals = " ".join(ell(x + math.cos(a) * 2.6, y + math.sin(a) * 2.2, 2.2, 1.9) for a in [k * math.tau / 5 + j for k in range(5)])
        b.append(fill(petals, col))
        b.append(lin(petals, INK, 0.5, 0.75))
        b.append(fill(ell(x, y, 1.2), PAL["gold"][1]))
    sh = f'<ellipse cx="{W/2+2:.1f}" cy="{H-2:.1f}" rx="{W*0.38:.1f}" ry="3" fill="{INK}" opacity="0.18" {blur_filter(P, 1.5)}/>'
    return sh, J(b), ""


def flower_patch_a(P, W, H):
    return flower_patch(P, W, H, 11, [PAL["cloth"][0], "#f2ead6", PAL["straw"][0]])


def flower_patch_b(P, W, H):
    return flower_patch(P, W, H, 23, ["#c8b4e0", "#f2ead6", PAL["apple"][0], "#a8b8d8"])


PROPS = {k: v for k, v in globals().items() if callable(v)}


def jobs():
    only = only_filter()
    js = []
    for pid, spec in load("props.json").items():
        if only and pid not in only:
            continue
        if pid not in PROPS:  # interior decor props are drawn by make_interiors.py
            continue
        W, H = spec["size"]
        P = painter(scale=1.0, lw_mul=0.7)
        fn = PROPS[pid]
        sh, body, emit = fn(P, W, H)
        svg = sprite_svg(P, W, H, sh, body, emit, ss=3, wob=0.9, dil=0.7, grain=0.45, soot=0.6)
        js.append(dict(name=f"pr_{pid}", svg=svg, w=W, h=H, ss=3, out=os.path.join(SPR, "props", pid + ".png")))
    return js


if __name__ == "__main__":
    render(jobs())
