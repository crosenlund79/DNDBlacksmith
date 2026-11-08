"""Iteration 010 interface icons, in the toolbar's ink idiom (96x96, drawn in a 128-unit space):
quick-travel destination medallions (qt_*) and small row/section icons for panels (ic_*).
python3 make_ui_icons010.py [--only=qt_inn,ic_home]  ->  assets/sprites/ui/template_<name>.png
No lettering: the game draws names next to them."""
import math
import os
from artlib import (painter, svg_doc, ink_filter, glow, lin, fill, render, only_filter, ell, rect, poly, smooth,
                    INK, EMBER, EMBER_HOT, RUB, GILT, SPR, hatch)

UI = os.path.join(SPR, "ui")
WATER = "#5a7a8a"


def J(o):
    return "\n".join(x for x in o if x)


def cottage(P, x, y, w, h, roof="roof_a", door=True):
    o = [P.shape(rect(x, y, w, h, 2), "shirt", s=3)]
    o.append(P.shape(poly([(x - 8, y + 2), (x + w / 2, y - h * 0.62), (x + w + 8, y + 2)]), roof, s=3))
    if door:
        o.append(P.shape(rect(x + w / 2 - 8, y + h - 22, 16, 22, 2), "wood", s=1.5))
    return o


# ------------------------------------------------------------------ quick-travel destinations
def qt_smithy(P):
    """Anvil with a flame above it."""
    o = [P.shape(smooth([(14, 70), (34, 64), (94, 64), (116, 58), (106, 74), (84, 78), (44, 78), (24, 78)]), "metal", s=4)]
    o.append(P.shape(poly([(46, 78), (82, 78), (78, 94), (92, 108), (36, 108), (50, 94)]), "metal", s=4))
    o.append(fill(rect(30, 66, 60, 3, 1), "#ffffff", 0.45))
    fl = smooth([(64, 58), (50, 44), (54, 26), (62, 34), (66, 12), (78, 34), (80, 46)], close=True)
    o.append(fill(fl, EMBER) + lin(fl, INK, 2.4))
    o.append(fill(smooth([(64, 54), (58, 44), (64, 32), (70, 44)], close=True), EMBER_HOT))
    return J(o), glow(P, 64, 40, 26, EMBER_HOT, 0.5)


def qt_inn(P):
    """A foaming tankard."""
    o = [P.shape(smooth([(84, 52), (106, 54), (106, 86), (84, 90)]), "wood", s=2)]
    o.append(P.shape(rect(30, 40, 58, 70, 6), "wood", s=4))
    for y in (52, 96):
        o.append(P.shape(rect(26, y, 66, 8, 3), "metal", s=1.5))
    o.append(P.detail("M44,62 L44,92 M60,62 L60,92 M74,62 L74,92", "wood", 1, 0.6))
    foam = smooth([(26, 44), (30, 28), (44, 24), (54, 16), (68, 20), (82, 22), (92, 34), (90, 46)], close=True)
    o.append(fill(foam, "#f4ecd8") + lin(foam, INK, 2.4))
    return J(o), ""


def qt_square(P):
    """The village well: stone ring, roof and bucket."""
    o = [P.shape(rect(26, 74, 76, 34, 4), "slate", s=4)]
    o.append(P.detail("M26,90 L102,90 M44,74 L44,90 M64,90 L64,108 M84,74 L84,90", "slate", 1, 0.6))
    o.append(P.shape(rect(32, 34, 6, 42, 1), "wood", s=1.5))
    o.append(P.shape(rect(90, 34, 6, 42, 1), "wood", s=1.5))
    o.append(P.shape(poly([(18, 40), (64, 14), (110, 40), (100, 44), (64, 24), (28, 44)]), "roof_a", s=2))
    o.append(lin("M38,46 L90,46", INK, 2.6))
    o.append(lin("M64,46 L64,58", INK, 1.6))
    o.append(P.shape(poly([(56, 58), (72, 58), (70, 72), (58, 72)]), "wood", s=1.5))
    return J(o), ""


def qt_market(P):
    """A market stall with a striped awning and produce."""
    o = [P.shape(rect(22, 64, 84, 40, 3), "wood", s=3)]
    for i in range(5):
        x = 18 + i * 18.4
        o.append(P.shape(poly([(x, 30), (x + 18.4, 30), (x + 18.4, 56), (x + 9.2, 62), (x, 56)]), "cloth" if i % 2 == 0 else "linen", s=1.5))
    o.append(lin("M18,30 L110,30", INK, 3))
    for (x, c) in [(38, "apple"), (54, "cabbage"), (70, "apple"), (86, "straw")]:
        o.append(P.shape(ell(x, 70, 8, 7), c, s=1.5))
    o.append(P.detail("M22,82 L106,82", "wood", 1, 0.6))
    return J(o), ""


def qt_herbalist(P):
    """Mortar with a sprig of herbs."""
    o = [lin("M64,64 Q60,40 48,22 M62,52 Q72,36 86,26 M58,44 Q44,40 34,30", "#4c5834", 3)]
    for (x, y, a) in [(48, 22, -30), (86, 26, 30), (34, 30, -60), (56, 34, -10), (74, 38, 40), (40, 40, -50)]:
        leaf = f'<ellipse cx="{x}" cy="{y}" rx="9" ry="4.5" transform="rotate({a} {x} {y})" fill="#8c9a64" stroke="{INK}" stroke-width="1.8"/>'
        o.append(leaf)
    o.append(P.shape(smooth([(20, 62), (108, 62), (100, 92), (82, 106), (46, 106), (28, 92)]), "slate", s=4))
    o.append(P.shape(ell(64, 62, 44, 8), "slate", s=2))
    o.append(fill(ell(64, 62, 36, 5), "#3a3028", 0.7))
    o.append(P.shape(poly([(76, 60), (84, 56), (104, 20), (98, 16)]), "wood", s=1.5))
    return J(o), ""


def qt_harbour(P):
    """An anchor over waves."""
    o = [lin("M64,30 L64,96", INK, 9), lin("M64,30 L64,96", "#868c8c", 5)]
    o.append(P.shape(ell(64, 22, 9), "metal", s=2))
    o.append(fill(ell(64, 22, 4), "#e6d6b0"))
    o.append(P.shape(rect(44, 38, 40, 8, 3), "metal", s=1.5))
    arc = "M30,72 Q34,100 64,102 Q94,100 98,72"
    o.append(lin(arc, INK, 9) + lin(arc, "#868c8c", 5))
    o.append(fill(poly([(22, 74), (36, 66), (36, 80)]), "#5a5650") + lin(poly([(22, 74), (36, 66), (36, 80)]), INK, 2))
    o.append(fill(poly([(106, 74), (92, 66), (92, 80)]), "#5a5650") + lin(poly([(106, 74), (92, 66), (92, 80)]), INK, 2))
    o.append(lin("M12,114 q8,-6 16,0 t16,0 t16,0 t16,0 t16,0 t16,0 t16,0", WATER, 3.2))
    return J(o), ""


def qt_barnaby(P):
    """A narrow house with a playing card on the door."""
    o = cottage(P, 34, 52, 60, 56, door=False)
    o.append(P.shape(rect(54, 76, 20, 32, 2), "wood", s=1.5))
    o.append(P.shape(rect(57, 80, 14, 19, 1), "paper", s=1, lw=1.2))
    o.append(fill(smooth([(64, 84), (68, 89), (64, 95), (60, 89)], close=True), RUB))
    o.append(fill(rect(40, 64, 10, 10, 1), EMBER_HOT, 0.85))
    o.append(fill(rect(78, 64, 10, 10, 1), EMBER_HOT, 0.85))
    return J(o), ""


def qt_chapel(P):
    """A chapel gable with a dawn sun and a headstone beside it."""
    o = [P.shape(rect(26, 56, 56, 52, 2), "slate", s=3)]
    o.append(P.shape(poly([(18, 60), (54, 22), (90, 60)]), "roof_a", s=3))
    o.append(P.shape(smooth([(46, 108), (46, 84), (54, 76), (62, 84), (62, 108)]), "wood", s=1.5))
    o.append(fill(ell(54, 40, 7), GILT) + lin(ell(54, 40, 7), INK, 1.8))
    for a in range(8):
        t = a * math.pi / 4
        o.append(lin(f"M{54 + 9 * math.cos(t):.1f},{40 + 9 * math.sin(t):.1f} L{54 + 13 * math.cos(t):.1f},{40 + 13 * math.sin(t):.1f}", GILT, 1.6))
    o.append(P.shape(smooth([(90, 108), (90, 82), (100, 74), (110, 82), (110, 108)]), "slate", s=2))
    o.append(lin("M100,84 L100,98 M95,89 L105,89", INK, 2))
    return J(o), glow(P, 54, 40, 14, EMBER_HOT, 0.35)


def qt_pond(P):
    """A duck on rippling water among reeds."""
    o = [P.shape(ell(64, 92, 52, 18), "blue", s=3)]
    o.append(lin("M30,92 q8,-4 16,0 t16,0 M74,98 q7,-4 14,0 t14,0", "#e4f4fa", 2, 0.8))
    o.append(P.shape(smooth([(42, 84), (46, 70), (64, 66), (82, 70), (90, 80), (80, 88), (52, 90)]), "linen", s=3))
    o.append(P.shape(ell(84, 58, 11, 10), "green", s=2))
    o.append(fill(poly([(93, 58), (106, 60), (93, 64)]), "#d2a04a") + lin(poly([(93, 58), (106, 60), (93, 64)]), INK, 1.6))
    o.append(fill(ell(86, 55, 2), INK))
    o.append(lin("M18,96 L22,58 M24,98 L30,64 M110,96 L106,62", "#4c5834", 2.6))
    o.append(fill(ell(22, 56, 2.5, 8), "#7a5636") + fill(ell(106, 60, 2.5, 8), "#7a5636"))
    return J(o), ""


def qt_pawn(P):
    """The pawnbroker's three gilt balls on a bracket."""
    o = [lin("M20,20 L104,20 M30,20 L30,36 M64,20 L64,52 M98,20 L98,36", INK, 3.4)]
    for (x, y) in [(30, 58), (98, 58), (64, 90)]:
        o.append(P.shape(ell(x, y, 19), "gold", s=3))
        o.append(fill(ell(x - 6, y - 6, 4), "#ffffff", 0.55))
    o.append(lin("M30,36 L30,40 M98,36 L98,40 M64,52 L64,72", INK, 2))
    return J(o), glow(P, 64, 70, 30, EMBER_HOT, 0.25)


def qt_rival(P):
    """Two hammers crossed in challenge."""
    def hammer(rot):
        h = [P.shape(rect(60, 30, 8, 84, 3), "wood", s=2), P.shape(rect(40, 14, 48, 22, 4), "metal", s=3),
             P.detail("M46,25 L82,25", "metal", 0.8, 0.6)]
        return f'<g transform="rotate({rot} 64 64)">{J(h)}</g>'
    o = [hammer(-38), hammer(38)]
    o.append(fill(ell(64, 66, 6), RUB) + lin(ell(64, 66, 6), INK, 1.8))
    return J(o), ""


def qt_creatures(P):
    """A large paw print."""
    o = [P.shape(smooth([(40, 88), (46, 68), (64, 60), (82, 68), (88, 88), (78, 104), (50, 104)]), "brown", s=4)]
    for (x, y, r) in [(30, 58, 10), (48, 38, 11), (80, 38, 11), (98, 58, 10)]:
        o.append(P.shape(ell(x, y, r * 0.85, r), "brown", s=2))
    return J(o), ""


def qt_caravan(P):
    """A covered wagon."""
    o = [P.shape(smooth([(18, 72), (22, 40), (44, 24), (84, 24), (106, 40), (110, 72)]), "linen", s=4)]
    o.append(P.detail("M44,26 L40,72 M64,24 L64,72 M84,26 L88,72", "linen", 1.2, 0.7))
    o.append(P.shape(rect(14, 70, 100, 14, 2), "wood", s=2))
    for x in (36, 92):
        o.append(P.shape(ell(x, 96, 16), "wood", s=3))
        o.append(lin(f"M{x - 14},96 L{x + 14},96 M{x},82 L{x},110 M{x - 10},86 L{x + 10},106 M{x + 10},86 L{x - 10},106", INK, 1.6))
        o.append(P.shape(ell(x, 96, 4), "metal", s=1))
    return J(o), ""


# ------------------------------------------------------------------ panel row/section icons
def ic_home(P):
    """A cottage with a lit window."""
    o = cottage(P, 30, 56, 68, 52)
    o.append(fill(rect(38, 68, 12, 12, 1), EMBER_HOT, 0.9) + lin(rect(38, 68, 12, 12, 1), INK, 1.6))
    o.append(P.shape(rect(78, 22, 10, 22, 1), "slate", s=1.5))
    return J(o), ""


def ic_work(P):
    """A smith's hammer over a workbench."""
    o = [P.shape(rect(16, 84, 96, 14, 2), "wood", s=3)]
    o.append(lin("M24,98 L24,114 M104,98 L104,114", INK, 4))
    o.append(P.shape(poly([(58, 76), (66, 76), (92, 18), (84, 14)]), "wood", s=2))
    o.append(P.shape(poly([(64, 10), (100, 26), (94, 40), (58, 24)]), "metal", s=3))
    return J(o), ""


def ic_family(P):
    """Two figures, a larger and a smaller, side by side."""
    o = [P.shape(ell(46, 34, 14), "clay", s=2), P.shape(smooth([(22, 110), (24, 64), (46, 52), (68, 64), (70, 110)]), "cloth", s=3)]
    o.append(P.shape(ell(88, 56, 11), "clay", s=2))
    o.append(P.shape(smooth([(70, 110), (72, 80), (88, 70), (104, 80), (106, 110)]), "blue", s=3))
    return J(o), ""


def ic_memory(P):
    """A quill over a folded note."""
    o = [P.shape(poly([(18, 50), (96, 40), (104, 104), (24, 112)]), "paper", s=3)]
    o.append(lin("M30,66 L88,60 M32,80 L90,74 M34,94 L70,90", INK, 2, 0.55))
    o.append(P.shape(smooth([(110, 10), (96, 18), (78, 40), (64, 66), (70, 62), (92, 40), (106, 24)], close=True), "linen", s=2))
    o.append(lin("M110,10 L62,72", INK, 2))
    return J(o), ""


def ic_standing(P):
    """A heart pierced by nothing: plain rubric."""
    h = smooth([(64, 108), (22, 70), (18, 42), (34, 24), (54, 26), (64, 40), (74, 26), (94, 24), (110, 42), (106, 70)], close=True)
    o = [fill(h, RUB) + lin(h, INK, 3)]
    o.append(fill(ell(42, 44, 7, 5), "#e8a088", 0.7))
    return J(o), ""


def ic_history(P):
    """An hourglass."""
    o = [P.shape(rect(26, 12, 76, 12, 3), "wood", s=2), P.shape(rect(26, 104, 76, 12, 3), "wood", s=2)]
    g = smooth([(36, 24), (92, 24), (90, 40), (68, 62), (90, 84), (92, 104), (36, 104), (38, 84), (60, 62), (38, 40)], close=True)
    o.append(fill(g, "#eef2ea", 0.85) + lin(g, INK, 2.6))
    o.append(fill(poly([(44, 36), (84, 36), (64, 58)]), "#d2b464"))
    o.append(fill(poly([(44, 100), (84, 100), (64, 84)]), "#d2b464"))
    o.append(lin("M64,60 L64,96", "#d2b464", 1.6))
    return J(o), ""


def ic_sheet(P):
    """A character sheet: portrait box and lines on a pinned page."""
    o = [P.shape(rect(24, 14, 80, 100, 3), "paper", s=3)]
    o.append(P.shape(rect(34, 26, 26, 30, 2), "linen", s=1))
    o.append(fill(ell(47, 36, 6), "#b47a56") + fill(smooth([(37, 56), (40, 46), (54, 46), (57, 56)]), RUB))
    o.append(lin("M68,30 L94,30 M68,40 L94,40 M68,50 L88,50 M34,68 L94,68 M34,80 L94,80 M34,92 L80,92", INK, 2, 0.6))
    o.append(P.shape(ell(64, 14, 6), "gold", s=1.5))
    return J(o), ""


def ic_travel(P):
    """A walking boot with motion lines."""
    o = [P.shape(smooth([(48, 18), (78, 18), (80, 70), (106, 84), (108, 104), (40, 104), (42, 70)]), "leather", s=4)]
    o.append(P.shape(rect(38, 100, 72, 10, 3), "wood", s=2))
    o.append(lin("M56,40 L72,40 M56,52 L72,52", INK, 2, 0.6))
    o.append(lin("M10,60 L30,60 M6,76 L30,76 M12,92 L32,92", INK, 3, 0.7))
    return J(o), ""


def ic_talk(P):
    """A speech scroll."""
    b = smooth([(16, 30), (64, 18), (112, 30), (112, 76), (64, 86), (48, 86), (30, 108), (34, 84), (16, 76)], close=True)
    o = [fill(b, "#f4ead0") + lin(b, INK, 3)]
    o.append(lin("M34,44 L94,40 M34,58 L94,56 M34,70 L72,70", INK, 2.2, 0.6))
    return J(o), ""


ICONS = {k: v for k, v in globals().items() if (k.startswith("qt_") or k.startswith("ic_")) and callable(v)}


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
        js.append(dict(name=f"ui_{name}", svg=svg_doc(96, 96, P, inner, ss=4, vw=128, vh=128), w=96, h=96, ss=4,
                       out=os.path.join(UI, name + ".png")))
    return js


if __name__ == "__main__":
    render(jobs(), workers=4)
