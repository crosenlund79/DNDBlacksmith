"""Item-story art (iteration 011, "The World Remembers").
Maker's marks (marks/<id>, 32x32): small struck roundels, one per maker — the Ironhand anvil-and-flame, the Salt
Anvil (anchor crossed by a hammer), a barrow-king's worn crown over three lines, a dwarf-rune of Ironroot, a
journeyman's scratched initials, and a blank worn disc for "no mark".
Story icons (ui/story_<kind>, 96x96 in the ink idiom of make_ui_icons010): one per kind of history entry —
forged, sale, found, inherited, repaired, reforged, enchanted, treated, battle, survived, discovery, named, epic,
lost, reunion, commission, sharpened, note.
python3 make_itemstory_art.py [--only=mark_ironhand,story_named]  ->  assets/sprites/<dir>/template_<name>.png
No lettering except the journeyman's scratch (two crude strokes, not words)."""
import math
import os
from artlib import (painter, svg_doc, ink_filter, glow, lin, fill, render, only_filter, ell, rect, poly, smooth,
                    INK, EMBER, EMBER_HOT, RUB, GILT, SPR)

UI = os.path.join(SPR, "ui")
MARKS = os.path.join(SPR, "marks")
IRON_D = "#2a2420"
IRON_M = "#4a423a"
BRASS = "#c9a253"
EPIC = "#b8324f"


def J(o):
    return "\n".join(x for x in o if x)


# ------------------------------------------------------------------ maker's marks (128-unit space -> 32 px)
def _disc(P, rim=GILT, face=IRON_D):
    """A struck roundel: a dark iron face, a thin raised rim and a worn bevel."""
    o = [fill(ell(64, 64, 60), INK)]
    o.append(fill(ell(64, 64, 55), face))
    o.append(lin(ell(64, 64, 55), rim, 5, 0.9))
    o.append(lin(ell(64, 64, 45), rim, 2, 0.35))
    o.append(lin("M28,40 A44,44 0 0 1 64,18", "#ffffff", 3, 0.18))
    return o


def mark_ironhand(P):
    """An anvil under a single flame — the Ironhand forge."""
    o = _disc(P)
    anvil = poly([(24, 74), (48, 72), (52, 66), (96, 66), (108, 60), (104, 74), (86, 78), (80, 88), (90, 100), (38, 100), (48, 88), (44, 78)])
    o.append(fill(anvil, BRASS) + lin(anvil, INK, 2.2))
    fl = smooth([(64, 22), (76, 40), (74, 54), (64, 60), (54, 54), (52, 40)], close=True)
    o.append(fill(fl, "#e8762a") + lin(fl, INK, 1.8))
    fi = smooth([(64, 36), (70, 46), (64, 56), (58, 46)], close=True)
    o.append(fill(fi, "#ffd27a"))
    return J(o), glow(P, 64, 44, 16, EMBER, 0.35)


def mark_salt_anvil(P):
    """A ship's anchor crossed by a hammer — Maren Tallowgate's Salt Anvil."""
    o = _disc(P, rim="#9ab0b8", face="#24323a")
    anc = "M64,26 L64,98 M46,40 L82,40 M34,78 Q40,100 64,100 Q88,100 94,78"
    o.append(lin(anc, INK, 11) + lin(anc, "#cfd8dc", 6))
    o.append(fill(ell(64, 24, 7), "#cfd8dc") + lin(ell(64, 24, 7), INK, 2))
    ham = poly([(30, 34), (40, 26), (98, 86), (92, 94)])
    o.append(fill(ham, "#8a6a40") + lin(ham, INK, 2))
    head = poly([(20, 38), (36, 22), (46, 32), (30, 48)])
    o.append(fill(head, BRASS) + lin(head, INK, 2))
    return J(o), ""


def mark_barrow(P):
    """A worn crown over three lines — old beyond counting."""
    o = _disc(P, rim="#8a7a5a", face="#2e2a22")
    cr = poly([(30, 70), (34, 38), (48, 54), (64, 30), (80, 54), (94, 38), (98, 70)])
    o.append(fill(cr, "#b8a87a") + lin(cr, INK, 2.4))
    for (x, y) in [(34, 38), (64, 30), (94, 38)]:
        o.append(fill(ell(x, y, 4.5), "#d8c89a") + lin(ell(x, y, 4.5), INK, 1.5))
    o.append(lin("M32,80 L96,80 M36,90 L92,90 M42,100 L86,100", "#b8a87a", 4, 0.9))
    # worn: pits and a chip out of the rim
    for (x, y, r) in [(50, 62, 3), (76, 66, 2.5), (60, 86, 2)]:
        o.append(fill(ell(x, y, r), "#2e2a22", 0.9))
    o.append(fill(ell(108, 40, 9), INK, 0.9))
    return J(o), ""


def mark_ironroot(P):
    """An angular dwarf-rune for 'deep', cut into steel."""
    o = _disc(P, rim="#7a8a9a", face="#262a30")
    rune = "M44,26 L44,102 M44,26 L84,52 L44,72 M84,52 L84,102 M64,88 L96,102"
    o.append(lin(rune, INK, 12) + lin(rune, "#a8c0d4", 6))
    return J(o), glow(P, 64, 64, 30, "#7aa8d4", 0.15)


def mark_hand(P):
    """A journeyman's scratch: two crude initials scored by an unknown hand."""
    o = _disc(P, rim="#8a7a6a", face="#3a3028")
    sc = "M30,90 L42,36 L54,90 M35,68 L50,66 M68,38 L68,92 M68,38 Q98,40 92,60 Q86,66 68,64 Q100,70 94,88 Q88,94 68,92"
    o.append(lin(sc, INK, 8) + lin(sc, "#d8c8a8", 3.5))
    o.append(lin("M24,100 L104,98", "#d8c8a8", 1.6, 0.6))
    return J(o), ""


def mark_unknown(P):
    """No mark: a blank, worn disc."""
    o = _disc(P, rim="#6e6250", face="#3a342c")
    o.append(lin(ell(64, 64, 26), "#8a7a60", 3, 0.5))
    o.append(lin("M50,50 L78,78 M78,50 L50,78", "#8a7a60", 2.5, 0.35))
    return J(o), ""


# ------------------------------------------------------------------ story icons (ink idiom, 128-unit space -> 96 px)
def story_forged(P):
    """Hammer striking an anvil, sparks."""
    o = [P.shape(smooth([(14, 76), (34, 70), (94, 70), (116, 64), (106, 80), (84, 84), (44, 84), (24, 84)]), "metal", s=4)]
    o.append(P.shape(poly([(46, 84), (82, 84), (78, 98), (92, 112), (36, 112), (50, 98)]), "metal", s=4))
    o.append(P.shape(poly([(70, 20), (78, 14), (100, 46), (92, 52)]), "wood", s=2))
    o.append(P.shape(poly([(56, 22), (80, 6), (92, 22), (68, 38)]), "darkiron", s=2))
    return J(o), lin("M40,56 L30,44 M50,52 L48,38 M30,64 L16,58", EMBER_HOT, 3, 0.9) + glow(P, 46, 66, 16, EMBER, 0.5)


def story_sale(P):
    """A small stack of coins and one standing coin."""
    o = []
    for i, y in enumerate([98, 88, 78]):
        o.append(P.shape(ell(50, y, 30, 10), "gold", s=2))
    o.append(P.shape(ell(88, 64, 20, 26), "gold", s=3))
    o.append(lin(ell(88, 64, 12, 17), INK, 2, 0.6))
    return J(o), ""


def story_found(P):
    """An open chest."""
    o = [P.shape(rect(20, 58, 88, 50, 4), "wood", s=4)]
    o.append(P.shape(poly([(20, 58), (30, 26), (98, 26), (108, 58)]), "wood", s=3))
    o.append(P.shape(rect(20, 74, 88, 8, 1), "darkiron", s=1))
    o.append(P.shape(rect(58, 66, 12, 18, 2), "gold", s=1))
    o.append(fill(ell(64, 54, 28, 6), "#e8c860", 0.9))
    return J(o), glow(P, 64, 50, 26, "#ffd27a", 0.35)


def story_inherited(P):
    """A candle on a dish (a fallen owner's gear passed on)."""
    o = [P.shape(ell(64, 104, 40, 10), "metal", s=2)]
    o.append(P.shape(rect(50, 40, 28, 62, 3), "linen", s=3))
    o.append(lin("M64,40 L64,30", INK, 2))
    fl = smooth([(64, 8), (72, 22), (64, 32), (56, 22)], close=True)
    o.append(fill(fl, "#ffb050") + lin(fl, INK, 1.5))
    return J(o), glow(P, 64, 22, 20, EMBER, 0.45)


def story_repaired(P):
    """A cracked blade bound with a riveted band."""
    bl = poly([(18, 102), (92, 28), (104, 20), (98, 34), (26, 108)])
    o = [P.shape(bl, "metal", s=3)]
    o.append(lin("M52,74 L60,62 L56,58 L66,50", INK, 2.2))
    o.append(P.shape(poly([(44, 70), (60, 54), (70, 64), (54, 80)]), "darkiron", s=1.5))
    o.append(fill(ell(55, 63, 3), GILT) + fill(ell(61, 71, 3), GILT))
    return J(o), ""


def story_reforged(P):
    """A blade laid across the anvil with a flame beneath — rework."""
    o = [P.shape(smooth([(14, 80), (34, 74), (94, 74), (116, 68), (106, 84), (84, 88), (44, 88), (24, 88)]), "metal", s=4)]
    o.append(P.shape(poly([(46, 88), (82, 88), (78, 100), (92, 114), (36, 114), (50, 100)]), "metal", s=4))
    o.append(P.shape(poly([(10, 66), (100, 52), (118, 56), (100, 62), (12, 72)]), "metal", s=2))
    fl = smooth([(64, 14), (80, 32), (76, 46), (64, 50), (52, 46), (48, 32)], close=True)
    o.append(fill(fl, "#e8762a") + lin(fl, INK, 2))
    return J(o), glow(P, 64, 36, 24, EMBER, 0.5)


def story_enchanted(P):
    """A runestone with a glowing glyph."""
    st = smooth([(40, 16), (90, 22), (104, 62), (88, 108), (38, 110), (24, 64)], close=True)
    o = [P.shape(st, "slate", s=4)]
    g = "M52,34 L52,94 M52,50 L78,36 M52,66 L80,84"
    o.append(lin(g, "#6a3cc8", 7, 0.8) + lin(g, "#d8c4ff", 3))
    return J(o), glow(P, 64, 64, 30, "#9a6aff", 0.35)


def story_treated(P):
    """A flask of oil, a drop at the lip."""
    o = [P.shape(smooth([(46, 46), (82, 46), (104, 92), (92, 112), (36, 112), (24, 92)], close=True), "glass", s=3)]
    o.append(fill(smooth([(30, 86), (98, 86), (92, 108), (36, 108)], close=True), "#c88a2a", 0.85))
    o.append(P.shape(rect(52, 24, 24, 24, 2), "glass", s=1.5))
    o.append(P.shape(rect(50, 14, 28, 12, 3), "wood", s=1.5))
    return J(o), ""


def story_battle(P):
    """Crossed swords."""
    o = []
    for flip in (False, True):
        pts = [(18, 18), (26, 14), (92, 86), (86, 92)]
        hilt = [(80, 96), (96, 80), (102, 86), (86, 102)]
        if flip:
            pts = [(128 - x, y) for (x, y) in pts]
            hilt = [(128 - x, y) for (x, y) in hilt]
        o.append(P.shape(poly(pts), "metal", s=2))
        o.append(P.shape(poly(hilt), "darkiron", s=1.5))
    o.append(P.shape(ell(98, 104, 7), "gold", s=1) + P.shape(ell(30, 104, 7), "gold", s=1))
    return J(o), ""


def story_survived(P):
    """A dented shield with a deep score across it."""
    sh = smooth([(24, 18), (104, 18), (104, 60), (64, 112), (24, 60)], close=True)
    o = [P.shape(sh, "wood", s=4)]
    o.append(P.shape(rect(58, 18, 12, 80, 1), "darkiron", s=1))
    o.append(lin("M34,40 L92,78", INK, 5) + lin("M34,40 L92,78", "#e8dcc0", 2))
    return J(o), ""


def story_discovery(P):
    """An unrolled map with a route and an X."""
    o = [P.shape(rect(18, 26, 92, 76, 3), "paper", s=3)]
    o.append(lin("M30,86 Q46,60 62,74 Q78,88 92,46", RUB, 3, 0.85))
    o.append(lin("M86,38 L98,52 M98,38 L86,52", RUB, 4))
    o.append(P.shape(ell(18, 64, 6, 38), "paper", s=1.5) + P.shape(ell(110, 64, 6, 38), "paper", s=1.5))
    return J(o), ""


def _star(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180.0 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


def story_named(P):
    """A star within a laurel — a name earned."""
    o = []
    for sgn in (-1, 1):
        stem = f"M64,112 Q{64 + sgn * 46},96 {64 + sgn * 44},40"
        o.append(lin(stem, "#3c5226", 3))
        for i in range(6):
            t = i / 5.0
            cx = 64 + sgn * (12 + 34 * math.sin(t * 1.4))
            cy = 106 - 62 * t
            leaf = smooth([(cx, cy), (cx + sgn * 10, cy - 4), (cx + sgn * 4, cy - 12)], t=0.5)
            o.append(P.shape(leaf, "foliage", s=0.6))
    st = _star(64, 58, 30, 13)
    o.append(fill(st, "#e8c860") + lin(st, INK, 2.4))
    return J(o), glow(P, 64, 58, 26, "#ffd27a", 0.35)


def story_epic(P):
    """A rose-crimson four-pointed star — Epic distinction."""
    st = _star(64, 64, 50, 14, n=4)
    o = [fill(st, EPIC) + lin(st, INK, 2.6)]
    o.append(fill(_star(64, 64, 22, 7, n=4), "#ffb0c0"))
    return J(o), glow(P, 64, 64, 34, "#ff6f8e", 0.35)


def story_lost(P):
    """A skull."""
    sk = smooth([(30, 54), (36, 20), (92, 20), (98, 54), (88, 72), (84, 92), (44, 92), (40, 72)], close=True)
    o = [P.shape(sk, "linen", s=3)]
    o.append(fill(ell(48, 56, 10, 12), INK) + fill(ell(80, 56, 10, 12), INK))
    o.append(fill(poly([(64, 66), (58, 78), (70, 78)]), INK))
    o.append(lin("M50,92 L50,104 M60,92 L60,106 M70,92 L70,106 M80,92 L80,104", INK, 2.6))
    return J(o), ""


def story_reunion(P):
    """A blade hanging over the forge's hearth — come home."""
    o = [P.shape(rect(20, 70, 88, 42, 3), "slate", s=4)]
    o.append(P.shape(poly([(14, 72), (64, 30), (114, 72)]), "roof_a", s=3))
    o.append(fill(rect(48, 84, 32, 28, 10), INK))
    o.append(P.shape(poly([(58, 6), (70, 6), (68, 50), (60, 50)]), "metal", s=1.5))
    o.append(P.shape(rect(50, 46, 28, 6, 2), "darkiron", s=1))
    return J(o), glow(P, 64, 100, 18, EMBER, 0.6)


def story_commission(P):
    """A sealed scroll."""
    o = [P.shape(rect(26, 28, 76, 70, 3), "paper", s=3)]
    o.append(P.shape(ell(26, 63, 7, 36), "paper", s=1.5) + P.shape(ell(102, 63, 7, 36), "paper", s=1.5))
    o.append(lin("M38,46 L90,46 M38,58 L90,58 M38,70 L74,70", INK, 2, 0.55))
    o.append(fill(ell(80, 88, 12), RUB) + lin(ell(80, 88, 12), INK, 2))
    return J(o), ""


def story_sharpened(P):
    """A grinding wheel throwing sparks off a blade."""
    o = [P.shape(ell(56, 72, 38), "slate", s=4)]
    o.append(lin(ell(56, 72, 26), INK, 1.5, 0.4))
    o.append(P.shape(ell(56, 72, 6), "darkiron", s=1))
    o.append(P.shape(poly([(70, 30), (118, 14), (122, 22), (76, 40)]), "metal", s=2))
    return J(o), lin("M82,40 L100,52 M86,36 L108,40 M80,44 L94,62", EMBER_HOT, 3, 0.9) + glow(P, 80, 40, 14, EMBER, 0.5)


def story_note(P):
    """A quill over a written page."""
    o = [P.shape(rect(22, 30, 74, 84, 3), "paper", s=3)]
    o.append(lin("M32,52 L84,52 M32,66 L84,66 M32,80 L70,80 M32,94 L78,94", INK, 2, 0.55))
    o.append(P.shape(smooth([(110, 10), (118, 14), (80, 74), (72, 84), (74, 70)], close=True), "linen", s=1.5))
    return J(o), ""


MARK_FNS = {k: v for k, v in globals().items() if k.startswith("mark_") and callable(v)}
STORY_FNS = {k: v for k, v in globals().items() if k.startswith("story_") and callable(v)}


def jobs():
    only = only_filter()
    js = []
    for name, fn in MARK_FNS.items():
        if only and name not in only:
            continue
        P = painter(scale=1.25, lw_mul=0.95)
        body, emit = fn(P)
        f = ink_filter(P, wob=0.6, dil=0.8, grain=0.4, soot=0.3)
        inner = f'<g {f}>{body}</g><g>{emit}</g>'
        js.append(dict(name=f"marks_{name}", svg=svg_doc(32, 32, P, inner, ss=8, vw=128, vh=128), w=32, h=32, ss=8,
                       out=os.path.join(MARKS, name[len("mark_"):] + ".png")))
    for name, fn in STORY_FNS.items():
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
