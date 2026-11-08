"""Adventurer character-sheet art: attribute, class, combat-stat and condition icons (96x96, drawn in a
128-unit space), a durability warning, the empty companion slot, and the paper-doll figure that the
equipment tab arranges the slots around.
python3 make_adv_sheet.py [--only=attr_str,cls_wizard]  ->  assets/sprites/ui/template_<name>.png
No lettering: the game writes names and numbers next to the icons."""
import math
import os
from artlib import (painter, svg_doc, ink_filter, soft_filter, glow, lin, fill, render, only_filter, ell, rect, poly, smooth,
                    INK, EMBER, EMBER_HOT, RUB, GILT, SPR, VIOLET, VIOLET_HOT, FROST, blur_filter, uid)

UI = os.path.join(SPR, "ui")


def J(o):
    return "\n".join(x for x in o if x)


def star(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        r = r1 if i % 2 == 0 else r2
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


# ------------------------------------------------------------------ attributes
def attr_str(P):
    """A clenched gauntlet fist."""
    o = [P.shape(rect(36, 74, 46, 40, 8), "metal", s=3)]
    o.append(P.shape(smooth([(30, 48), (40, 34), (96, 34), (102, 50), (98, 74), (34, 76)]), "metal", s=4))
    for i in range(4):
        x = 42 + i * 14
        o.append(P.shape(rect(x, 30, 14, 26, 6), "metal", s=2))
    o.append(P.shape(smooth([(22, 56), (34, 50), (52, 58), (48, 70), (30, 72)]), "metal", s=2))
    o.append(P.detail("M40,90 L78,90 M40,100 L78,100", "metal", 0.8, 0.6))
    o.append(P.shape(rect(32, 104, 54, 10, 3), "leather", s=1.5))
    return J(o), ""


def attr_dex(P):
    """A feathered arrow in flight."""
    sh = [P.shape(poly([(18, 106), (22, 110), (100, 32), (96, 28)]), "wood", s=1.5)]
    sh.append(P.shape(poly([(96, 18), (112, 16), (110, 32), (100, 34), (94, 28)]), "metal", s=2))
    for k in range(3):
        t = 20 + k * 9
        sh.append(P.shape(poly([(t, 112 - k * 9), (t - 10, 96 - k * 9), (t + 4, 100 - k * 9)]), "cloth", s=1))
        sh.append(P.shape(poly([(t + 2, 110 - k * 9), (t + 18, 116 - k * 9), (t + 8, 104 - k * 9)]), "cloth", s=1))
    sh.append(lin("M30,74 Q44,60 58,62 M46,94 Q60,80 74,82", INK, 1.4, 0.45))
    return J(sh), ""


def attr_int(P):
    """An open book with a rune star above."""
    o = [P.shape(smooth([(14, 50), (40, 42), (64, 52), (64, 108), (40, 98), (14, 104)]), "paper", s=3)]
    o.append(P.shape(smooth([(64, 52), (88, 42), (114, 50), (114, 104), (88, 98), (64, 108)]), "paper", s=3))
    o.append(lin("M64,52 L64,108", INK, 2.6))
    o.append(lin("M24,60 L54,64 M24,70 L54,74 M24,80 L50,84 M74,64 L104,60 M74,74 L104,70 M74,84 L100,80", INK, 1.4, 0.6))
    o.append(fill(star(64, 24, 14, 6), GILT))
    o.append(lin(star(64, 24, 14, 6), INK, 1.8))
    return J(o), glow(P, 64, 24, 20, EMBER_HOT, 0.45)


def attr_wis(P):
    """The watchful eye within a sun-ring."""
    o = []
    for a in range(12):
        t = a * math.pi / 6
        o.append(lin(f"M{64 + 40 * math.cos(t):.1f},{64 + 40 * math.sin(t):.1f} L{64 + 54 * math.cos(t):.1f},{64 + 54 * math.sin(t):.1f}", GILT, 3.4))
    o.append(P.shape(smooth([(18, 64), (40, 40), (64, 34), (88, 40), (110, 64), (88, 88), (64, 94), (40, 88)]), "paper", s=3))
    o.append(P.shape(ell(64, 64, 18), "blue", s=3))
    o.append(fill(ell(64, 64, 8), INK))
    o.append(fill(ell(59, 59, 3.5), "#ffffff", 0.85))
    return J(o), ""


def attr_con(P):
    """A heart bound with an iron band."""
    h = smooth([(64, 112), (26, 76), (18, 48), (32, 26), (52, 24), (64, 40), (76, 24), (96, 26), (110, 48), (102, 76)])
    o = [P.shape(h, "redp", s=6)]
    o.append(P.shape(poly([(20, 58), (108, 58), (106, 70), (22, 70)]), "metal", s=2))
    for x in (30, 48, 80, 98):
        o.append(fill(ell(x, 64, 2.4), "#3a3028"))
    o.append(fill(ell(42, 40, 6, 4), "#ffffff", 0.5))
    return J(o), ""


# ------------------------------------------------------------------ classes
def cls_fighter(P):
    """An upright longsword."""
    o = [P.shape(poly([(58, 92), (70, 92), (70, 26), (64, 8), (58, 26)]), "metal", s=2)]
    o.append(P.detail("M64,88 L64,26", "metal", 0.8, 0.7))
    o.append(P.shape(rect(34, 88, 60, 10, 4), "gold", s=1.5))
    o.append(P.shape(rect(59, 98, 10, 18, 3), "leather", s=1.5))
    o.append(P.shape(ell(64, 119, 6), "gold", s=1.2))
    return J(o), ""


def cls_ranger(P):
    """A drawn bow with a nocked arrow."""
    o = [lin("M40,14 Q98,64 40,114", INK, 9), lin("M40,14 Q98,64 40,114", "#a87a4a", 6)]
    o.append(lin("M40,14 L26,64 L40,114", "#e8dcc0", 1.6))
    o.append(P.shape(poly([(24, 62), (100, 62), (100, 66), (24, 66)]), "wood", s=1))
    o.append(P.shape(poly([(98, 56), (118, 64), (98, 72)]), "metal", s=1.5))
    o.append(P.shape(poly([(24, 64), (14, 54), (32, 58)]), "cloth", s=1))
    o.append(P.shape(poly([(24, 64), (14, 74), (32, 70)]), "cloth", s=1))
    return J(o), ""


def cls_wizard(P):
    """A pointed hat strewn with stars."""
    o = [P.shape(smooth([(10, 98), (40, 88), (88, 88), (118, 98), (90, 108), (38, 108)]), "cloth", s=3)]
    o.append(P.shape(smooth([(36, 94), (50, 60), (66, 30), (92, 12), (78, 34), (80, 64), (92, 94)], close=True), "cloth", s=5))
    o.append(P.shape(rect(38, 84, 54, 10, 3), "gold", s=1.5))
    for (x, y, r) in [(62, 62, 6), (76, 44, 4), (56, 78, 3.5)]:
        o.append(fill(star(x, y, r, r * 0.42), EMBER_HOT))
    return J(o), glow(P, 64, 56, 22, VIOLET_HOT, 0.35)


def cls_rogue(P):
    """A curved dagger crossing a hooded mask."""
    o = [P.shape(smooth([(30, 54), (44, 34), (64, 28), (84, 34), (98, 54), (90, 64), (38, 64)]), "cloak", s=4)]
    o.append(fill(ell(50, 50, 8, 4.5), INK))
    o.append(fill(ell(78, 50, 8, 4.5), INK))
    d = [P.shape(smooth([(60, 70), (74, 78), (100, 98), (116, 118), (96, 104), (64, 82)]), "metal", s=2),
         P.shape(rect(40, 64, 26, 7, 3), "gold", s=1.2),
         P.shape(poly([(36, 62), (44, 70), (28, 88), (20, 80)]), "leather", s=1.2)]
    o.extend(d)
    return J(o), ""


def cls_paladin(P):
    """A heater shield bearing a gilt cross."""
    sh = smooth([(22, 22), (64, 14), (106, 22), (104, 64), (64, 116), (24, 64)])
    o = [P.shape(sh, "metal", s=5)]
    o.append(P.shape(smooth([(30, 28), (64, 22), (98, 28), (96, 62), (64, 104), (32, 62)]), "cloth", s=3))
    o.append(P.shape(poly([(58, 32), (70, 32), (70, 52), (88, 52), (88, 62), (70, 62), (70, 94), (58, 94), (58, 62), (40, 62), (40, 52), (58, 52)]), "gold", s=2))
    return J(o), ""


def cls_cleric(P):
    """A sun-disc holy symbol on its chain."""
    o = [lin("M30,8 Q64,40 98,8", "#8a7a60", 2.4)]
    for a in range(16):
        t = a * math.pi / 8
        r2 = 46 if a % 2 == 0 else 38
        o.append(lin(f"M{64 + 26 * math.cos(t):.1f},{70 + 26 * math.sin(t):.1f} L{64 + r2 * math.cos(t):.1f},{70 + r2 * math.sin(t):.1f}", GILT, 4.2))
    o.append(P.shape(ell(64, 70, 28), "gold", s=4))
    o.append(P.shape(ell(64, 70, 14), "paper", s=2))
    o.append(fill(star(64, 70, 9, 4, 4, -45), RUB))
    return J(o), glow(P, 64, 70, 40, EMBER_HOT, 0.35)


def cls_barbarian(P):
    """A double-bladed war axe."""
    o = [P.shape(poly([(60, 10), (68, 10), (70, 120), (58, 120)]), "wood", s=2)]
    o.append(P.shape(smooth([(60, 30), (34, 14), (14, 34), (16, 66), (34, 80), (60, 62)]), "metal", s=4))
    o.append(P.shape(smooth([(68, 30), (94, 14), (114, 34), (112, 66), (94, 80), (68, 62)]), "metal", s=4))
    o.append(P.detail("M22,40 Q30,56 22,70 M106,40 Q98,56 106,70", "metal", 0.8, 0.6))
    o.append(P.shape(rect(56, 84, 16, 8, 2), "leather", s=1))
    o.append(P.shape(rect(56, 98, 16, 8, 2), "leather", s=1))
    return J(o), ""


def cls_bard(P):
    """A lute with its strings."""
    body = smooth([(40, 70), (56, 56), (76, 60), (88, 78), (84, 104), (62, 116), (38, 108), (30, 88)])
    o = [P.shape(body, "wood", s=5)]
    o.append(P.shape(poly([(66, 62), (98, 18), (106, 24), (76, 68)]), "brown", s=2))
    o.append(P.shape(poly([(96, 12), (114, 14), (112, 30), (104, 26)]), "brown", s=1.5))
    o.append(fill(ell(58, 88, 9), INK, 0.85))
    o.append(lin("M50,104 L102,22 M54,106 L105,24 M58,108 L108,26", "#e8dcc0", 0.9, 0.9))
    o.append(P.shape(rect(44, 100, 22, 5, 2), "gold", s=1))
    return J(o), ""


# ------------------------------------------------------------------ combat and condition
def stat_tohit(P):
    """A painted target with an arrow in the gold."""
    o = [P.shape(ell(60, 68, 46), "paper", s=5)]
    o.append(fill(ell(60, 68, 34), RUB))
    o.append(fill(ell(60, 68, 24), "#efe4cc"))
    o.append(fill(ell(60, 68, 13), GILT))
    o.append(lin(ell(60, 68, 34), INK, 1.6) + lin(ell(60, 68, 24), INK, 1.4) + lin(ell(60, 68, 13), INK, 1.4))
    o.append(P.shape(poly([(58, 66), (62, 70), (114, 18), (110, 14)]), "wood", s=1))
    o.append(P.shape(poly([(108, 8), (120, 10), (118, 22)]), "cloth", s=1))
    return J(o), ""


def stat_defence(P):
    """A kite shield with a riveted boss."""
    sh = smooth([(24, 20), (64, 12), (104, 20), (100, 70), (64, 118), (28, 70)])
    o = [P.shape(sh, "metal", s=5)]
    o.append(P.shape(smooth([(32, 26), (64, 20), (96, 26), (92, 66), (64, 106), (36, 66)]), "wood", s=3))
    o.append(P.detail("M64,22 L64,104 M34,50 L94,50", "wood", 1, 0.6))
    o.append(P.shape(ell(64, 54, 11), "metal", s=2))
    return J(o), ""


def stat_damage(P):
    """A sword striking sparks."""
    o = [P.shape(poly([(18, 112), (26, 118), (88, 50), (94, 30), (80, 40)]), "metal", s=2)]
    o.append(P.shape(poly([(14, 98), (30, 116), (36, 110), (20, 92)]), "gold", s=1))
    o.append(fill(star(98, 30, 24, 8, 8), EMBER_HOT, 0.95))
    o.append(lin(star(98, 30, 24, 8, 8), INK, 1.6))
    return J(o), glow(P, 98, 30, 26, EMBER, 0.55)


def stat_fire(P):
    """A licking flame."""
    f1 = smooth([(64, 118), (30, 100), (24, 70), (42, 44), (44, 64), (56, 30), (66, 8), (74, 36), (88, 26), (90, 52), (104, 64), (100, 100)])
    f2 = smooth([(64, 112), (44, 98), (42, 78), (56, 62), (60, 76), (70, 52), (80, 74), (86, 90), (82, 104)])
    o = [P.shape(f1, "fire", s=4), fill(f2, EMBER_HOT, 0.95)]
    return J(o), glow(P, 64, 80, 40, EMBER, 0.5)


def stat_frost(P):
    """A six-armed snowflake."""
    o = []
    for a in range(6):
        t = a * math.pi / 3
        x, y = 64 + 50 * math.cos(t), 64 + 50 * math.sin(t)
        o.append(lin(f"M64,64 L{x:.1f},{y:.1f}", INK, 9))
        for k in (0.5, 0.75):
            bx, by = 64 + 50 * k * math.cos(t), 64 + 50 * k * math.sin(t)
            for s in (-1, 1):
                t2 = t + s * 0.7
                o.append(lin(f"M{bx:.1f},{by:.1f} L{bx + 13 * math.cos(t2):.1f},{by + 13 * math.sin(t2):.1f}", INK, 7))
    inner = []
    for a in range(6):
        t = a * math.pi / 3
        x, y = 64 + 50 * math.cos(t), 64 + 50 * math.sin(t)
        inner.append(lin(f"M64,64 L{x:.1f},{y:.1f}", FROST, 4.5))
        for k in (0.5, 0.75):
            bx, by = 64 + 50 * k * math.cos(t), 64 + 50 * k * math.sin(t)
            for s in (-1, 1):
                t2 = t + s * 0.7
                inner.append(lin(f"M{bx:.1f},{by:.1f} L{bx + 13 * math.cos(t2):.1f},{by + 13 * math.sin(t2):.1f}", FROST, 3))
    o += inner
    o.append(P.shape(ell(64, 64, 9), "ice", s=2))
    return J(o), glow(P, 64, 64, 30, "#c8ecff", 0.35)


def stat_magic(P):
    """A violet arcane star."""
    o = [fill(star(64, 64, 52, 18, 4), VIOLET), lin(star(64, 64, 52, 18, 4), INK, 2.4)]
    o.append(fill(star(64, 64, 30, 10, 4, -45), VIOLET_HOT, 0.9))
    o.append(lin(star(64, 64, 30, 10, 4, -45), INK, 1.6))
    o.append(fill(ell(64, 64, 6), "#ffffff", 0.9))
    return J(o), glow(P, 64, 64, 46, VIOLET_HOT, 0.45)


def stat_ward(P):
    """A warding circle of runes."""
    o = [P.shape(ell(64, 64, 48), "paper", s=4)]
    o.append(lin(ell(64, 64, 40), GILT, 3))
    o.append(lin(ell(64, 64, 30), INK, 1.6))
    for a in range(8):
        t = a * math.pi / 4
        x, y = 64 + 35 * math.cos(t), 64 + 35 * math.sin(t)
        o.append(lin(f"M{x - 3:.1f},{y - 4:.1f} L{x + 3:.1f},{y + 4:.1f} M{x + 3:.1f},{y - 4:.1f} L{x:.1f},{y:.1f}", INK, 1.6))
    o.append(fill(poly([(64, 40), (84, 76), (44, 76)]), RUB, 0.9))
    o.append(lin(poly([(64, 40), (84, 76), (44, 76)]), INK, 2))
    return J(o), ""


def stat_hp(P):
    """A red heart."""
    h = smooth([(64, 114), (24, 76), (16, 46), (32, 22), (52, 22), (64, 38), (76, 22), (96, 22), (112, 46), (104, 76)])
    o = [P.shape(h, "redp", s=6), fill(ell(42, 40, 8, 5), "#ffffff", 0.5)]
    return J(o), ""


def stat_fatigue(P):
    """An hourglass running low."""
    o = [P.shape(rect(26, 10, 76, 12, 4), "wood", s=2), P.shape(rect(26, 106, 76, 12, 4), "wood", s=2)]
    g = smooth([(36, 22), (92, 22), (88, 46), (68, 64), (88, 82), (92, 106), (36, 106), (40, 82), (60, 64), (40, 46)])
    o.append(P.shape(g, "glass", s=2))
    o.append(fill(poly([(52, 50), (76, 50), (64, 62)]), "#d2b464"))
    o.append(fill(smooth([(42, 104), (64, 84), (86, 104)]), "#d2b464"))
    o.append(lin("M64,62 L64,90", "#d2b464", 1.6))
    o.append(lin("M30,22 L30,106 M98,22 L98,106", "#6e5634", 3))
    return J(o), ""


def stat_morale(P):
    """A swallow-tailed banner on a spear."""
    o = [P.shape(poly([(24, 10), (30, 10), (30, 120), (24, 120)]), "wood", s=1.5)]
    o.append(P.shape(poly([(22, 4), (27, -6), (32, 4)]), "metal", s=1))
    b = smooth([(30, 16), (70, 12), (110, 20), (96, 40), (112, 60), (70, 56), (30, 62)], close=True)
    o.append(P.shape(b, "cloth", s=4))
    o.append(fill(star(64, 38, 11, 4.5), GILT))
    return J(o), ""


def stat_gear(P):
    """A cuirass on a stand (gear completeness)."""
    o = [P.shape(smooth([(26, 30), (50, 22), (78, 22), (102, 30), (96, 70), (86, 108), (42, 108), (32, 70)]), "metal", s=5)]
    o.append(P.detail("M64,28 L64,104 M40,60 Q64,70 88,60", "metal", 1, 0.6))
    o.append(P.shape(smooth([(14, 30), (30, 24), (36, 48), (20, 52)]), "metal", s=2))
    o.append(P.shape(smooth([(114, 30), (98, 24), (92, 48), (108, 52)]), "metal", s=2))
    return J(o), ""


def warn_broken(P):
    """A sword snapped in two."""
    o = [P.shape(poly([(16, 118), (24, 124), (58, 82), (52, 72), (46, 80)]), "metal", s=2)]
    o.append(P.shape(poly([(10, 102), (28, 122), (34, 116), (16, 96)]), "gold", s=1))
    o.append(P.shape(poly([(66, 62), (72, 72), (112, 22), (114, 8), (100, 16)]), "metal", s=2))
    o.append(lin("M54,74 L60,70 L58,78 L66,68", RUB, 3.2))
    o.append(fill(star(62, 72, 16, 5, 6), EMBER_HOT, 0.85))
    return J(o), glow(P, 62, 72, 20, EMBER, 0.5)


def warn_worn(P):
    """A dented, cracked shield (worn gear)."""
    sh = smooth([(24, 20), (64, 12), (104, 20), (100, 70), (64, 118), (28, 70)])
    o = [P.shape(sh, "metal", s=5)]
    o.append(lin("M60,14 L52,40 L66,52 L54,78 L64,100", INK, 3.2))
    o.append(lin("M60,14 L52,40 L66,52 L54,78 L64,100", RUB, 1.4))
    o.append(fill(ell(84, 44, 8, 6), "#3a3028", 0.5))
    return J(o), ""


def slot_companion(P):
    """A paw print — the companion's empty place."""
    o = [P.shape(smooth([(40, 86), (50, 66), (64, 60), (78, 66), (88, 86), (78, 104), (50, 104)]), "hide", s=3)]
    for (x, y, r) in [(34, 54, 10), (52, 36, 10), (76, 36, 10), (94, 54, 10)]:
        o.append(P.shape(ell(x, y, r * 0.85, r), "hide", s=2))
    return J(o), ""


def renown(P):
    """A laurel wreath."""
    o = []
    for side in (-1, 1):
        for i in range(7):
            t = math.radians(200 - i * 22) if side < 0 else math.radians(-20 + i * 22)
            x, y = 64 + 40 * math.cos(t), 70 + 40 * math.sin(t)
            a = math.degrees(t) + (90 if side > 0 else -90)
            o.append(f'<g transform="rotate({a:.1f} {x:.1f} {y:.1f})">' + P.shape(ell(x, y, 6, 12), "green", s=1.2) + "</g>")
    o.append(fill(star(64, 66, 14, 6), GILT))
    o.append(lin(star(64, 66, 14, 6), INK, 1.6))
    return J(o), ""


ICONS = {k: v for k, v in globals().items() if k.split("_")[0] in ("attr", "cls", "stat", "warn", "slot") and callable(v)}
ICONS["renown"] = renown


# ------------------------------------------------------------------ paper doll
def paperdoll(P):
    """A miniature-style figure seen from the front, standing on a round base: the equipment tab sets
    each slot around it. Drawn as a sepia ink study so the item icons stay the strongest marks."""
    W, H = 360, 560
    o = [fill(ell(W / 2, 512, 150, 34), "#000", 0.25, blur_filter(P, 6))]
    o.append(P.shape(ell(W / 2, 500, 140, 30), "stone", s=4))
    o.append(P.shape(ell(W / 2, 492, 128, 24), "slate", s=3))
    sep = "#5e421c"
    body = [
        smooth([(180, 40), (206, 50), (214, 82), (204, 112), (180, 122), (156, 112), (146, 82), (154, 50)]),   # head
        smooth([(110, 150), (150, 132), (210, 132), (250, 150), (256, 210), (238, 300), (122, 300), (104, 210)]),  # torso
        smooth([(104, 154), (78, 196), (66, 268), (72, 330), (92, 334), (100, 270), (118, 206)], close=True),  # left arm
        smooth([(256, 154), (282, 196), (294, 268), (288, 330), (268, 334), (260, 270), (242, 206)], close=True),
        smooth([(126, 296), (176, 300), (172, 400), (164, 470), (130, 474), (128, 400)]),  # legs
        smooth([(184, 300), (234, 296), (232, 400), (230, 474), (196, 470), (188, 400)]),
    ]
    for d in body:
        o.append(P.shape(d, "linen", s=6, opacity=0.9))
    o.append(P.shape(rect(160, 118, 40, 18, 6), "linen", s=2, opacity=0.9))
    o.append(lin("M122,300 Q180,316 238,300", sep, 2.4, 0.7))
    o.append(lin("M180,140 L180,296", sep, 1.4, 0.4))
    o.append(lin("M140,200 Q180,214 220,200", sep, 1.4, 0.35))
    return J(o), W, H


def jobs():
    only = only_filter()
    js = []
    for name, fn in ICONS.items():
        if only and name not in only:
            continue
        P = painter(scale=1.25, lw_mul=0.95)
        body, emit = fn(P)
        f = ink_filter(P, wob=1.3, dil=1.8, grain=0.5, soot=0.6)
        inner = f'<g {f}>{body}</g><g>{emit}</g>'
        js.append(dict(name=f"adv_{name}", svg=svg_doc(96, 96, P, inner, ss=4, vw=128, vh=128), w=96, h=96, ss=4,
                       out=os.path.join(UI, name + ".png")))
    if not only or "paperdoll" in only:
        P = painter(scale=1.6, lw_mul=1.0)
        body, W, H = paperdoll(P)
        f = ink_filter(P, wob=1.6, dil=1.4, grain=0.8, soot=0.4)
        js.append(dict(name="adv_paperdoll", svg=svg_doc(W, H, P, f'<g {f}>{body}</g>', ss=2), w=W, h=H, ss=2,
                       out=os.path.join(UI, "paperdoll.png")))
    return js


if __name__ == "__main__":
    render(jobs(), workers=3)
