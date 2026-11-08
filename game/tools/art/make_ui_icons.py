"""HUD toolbar art: ink-drawn toolbar icons (96x96, designed in a 128-unit space), the brass-ringed
toolbar socket and the parchment-and-brass toolbar strip (9-slice, 48 px margins).
python3 make_ui_icons.py [--only=tb_map,toolbar_bar]  ->  assets/sprites/ui/template_<name>.png
No lettering: the game draws names and shortcuts in tooltips."""
import math
import os
import random
from artlib import (painter, svg_doc, ink_filter, soft_filter, glow, lin, fill, render, only_filter, ell, rect, poly, smooth,
                    ST, INK, EMBER, EMBER_HOT, RUB, GILT, SPR, PARCH, blur_filter, hatch, uid)
from make_ui import parchment_fill, edge_burn

UI = os.path.join(SPR, "ui")
BRASS_L, BRASS, BRASS_D = "#e8cc84", "#b8923e", "#5e4416"


def J(o):
    return "\n".join(x for x in o if x)


# ------------------------------------------------------------------ icons (128-unit space)
def tb_inventory(P):
    """Leather satchel with a buckled flap."""
    o = [P.shape(smooth([(24, 52), (104, 52), (108, 104), (100, 112), (28, 112), (20, 104)]), "leather", s=4)]
    o.append(P.shape(smooth([(30, 34), (64, 26), (98, 34), (98, 54), (30, 54)]), "leather", s=3))
    o.append(P.shape(smooth([(22, 50), (106, 50), (100, 80), (64, 88), (28, 80)]), "strap", s=3))
    o.append(P.detail("M30,56 Q64,64 98,56", "strap", 0.8, 0.7))
    o.append(P.shape(rect(56, 74, 16, 26, 2), "strap", s=2))
    o.append(P.shape(rect(53, 80, 22, 14, 2), "gold", s=1.5, lw=1.4))
    o.append(fill(rect(59, 84, 10, 6, 1), INK, 0.8))
    o.append(P.detail("M28,108 L100,108", "leather", 0.6, 0.5))
    o.append(lin("M40,30 Q64,8 88,30", INK, 4))
    return J(o), ""


def tb_skilltree(P):
    """A branching tree of rubric nodes on a scrap of vellum."""
    o = [P.shape(rect(18, 14, 92, 100, 6), "paper" if "paper" in P.pal else "shirt", s=2)]
    br = "M64,104 L64,78 M64,78 L40,58 M64,78 L88,58 M40,58 L30,34 M40,58 L52,34 M88,58 L76,34 M88,58 L98,34"
    o.append(lin(br, INK, 3.2))
    o.append(lin("M64,104 L64,78", INK, 5))
    for (x, y, c) in [(64, 104, GILT), (64, 78, RUB), (40, 58, RUB), (88, 58, RUB), (30, 34, GILT), (52, 34, GILT), (76, 34, "#e4d8bc"), (98, 34, "#e4d8bc")]:
        o.append(fill(ell(x, y, 7.5), c))
        o.append(lin(ell(x, y, 7.5), INK, 2.2))
    return J(o), glow(P, 41, 34, 14, EMBER_HOT, 0.4)


def tb_hirelings(P):
    """Miner's helmet with a pick behind it."""
    o = [P.shape(poly([(14, 110), (20, 116), (104, 30), (98, 24)]), "wood", s=2)]
    o.append(P.shape(smooth([(70, 8), (92, 16), (112, 34), (120, 52), (104, 40), (88, 30), (64, 22)], close=True), "metal", s=2))
    o.append(P.shape(smooth([(18, 92), (22, 66), (40, 50), (58, 46), (76, 50), (94, 66), (98, 92)]), "metal", s=5))
    o.append(P.shape(rect(12, 88, 92, 13, 6), "metal", s=2))
    o.append(P.detail("M58,48 L58,88", "metal", 1, 0.6))
    o.append(P.shape(ell(58, 72, 10, 9), "gold", s=2, lw=1.4))
    e = glow(P, 58, 72, 20, EMBER_HOT, 0.55)
    return J(o), e


def tb_adventurers(P):
    """Round shield with a sword crossed behind it."""
    sw = [P.shape(poly([(58, 86), (70, 86), (70, 22), (64, 6), (58, 22)]), "metal", s=2),
          P.detail("M64,82 L64,22", "metal", 0.8, 0.7),
          P.shape(rect(40, 84, 48, 9, 4), "gold", s=1.5),
          P.shape(rect(59, 93, 10, 20, 3), "leather", s=1.5),
          P.shape(ell(64, 117, 6), "gold", s=1.2)]
    o = [f'<g transform="rotate(-45 64 64)">{J(sw)}</g>']
    o.append(P.shape(ell(54, 72, 32), "wood", s=5))
    o.append(lin(ell(54, 72, 26), INK, 1.6, 0.7))
    o.append(P.detail("M54,40 L54,104 M22,72 L86,72", "wood", 0.9, 0.55))
    o.append(P.shape(ell(54, 72, 10), "metal", s=2))
    o.append(fill(ell(51, 69, 3), "#ffffff", 0.6))
    for a in range(8):
        t = a * math.pi / 4 + 0.4
        o.append(fill(ell(54 + 29 * math.cos(t), 72 + 29 * math.sin(t), 2.2), "#3a3028"))
    o.append(fill(smooth([(34, 54), (44, 50), (40, 62)]), RUB, 0.85))
    return J(o), ""


def tb_ledger(P):
    """Bound ledger with a ribbon and a stack of coins."""
    o = [P.shape(poly([(14, 34), (78, 22), (88, 96), (24, 108)]), "leather", s=4)]
    o.append(P.shape(poly([(20, 32), (76, 22), (84, 92), (28, 102)]), "shirt", s=1.5, flat=True))
    o.append(P.shape(poly([(14, 34), (78, 22), (88, 96), (24, 108)]), "cloak", s=4))
    o.append(lin("M18,40 L80,28 M22,96 L86,86", GILT, 1.8, 0.9))
    o.append(P.shape(poly([(52, 28), (60, 26), (64, 112), (58, 118), (54, 110)]), "cloak", s=1))
    o.append(fill(poly([(52, 28), (60, 26), (64, 112), (58, 118), (54, 110)]), RUB, 0.9))
    for i in range(4):
        y = 104 - i * 9
        o.append(P.shape(ell(96, y, 18, 7), "gold", s=2, lw=1.6))
    o.append(P.detail("M86,74 L106,74", "gold", 0.6, 0.6))
    return J(o), glow(P, 96, 76, 10, EMBER_HOT, 0.35)


def tb_map(P):
    """Unrolled map with a dotted route and a rubric X."""
    o = [P.shape(poly([(16, 30), (44, 22), (84, 32), (112, 24), (112, 98), (84, 106), (44, 96), (16, 104)]), "shirt", s=3)]
    o.append(P.detail("M44,22 L44,96 M84,32 L84,106", "shirt", 1, 0.55))
    o.append(f'<path d="{poly([(16, 30), (44, 22), (44, 96), (16, 104)])}" fill="{hatch(P, -35, 4, 0.8)}" opacity="0.35"/>')
    o.append(f'<path d="{poly([(84, 32), (112, 24), (112, 98), (84, 106)])}" fill="{hatch(P, -35, 4, 0.8)}" opacity="0.25"/>')
    o.append(lin("M26,88 Q40,64 56,72 T80,52 T98,42", INK, 2.4, 0.9, extra='stroke-dasharray="4 5"'))
    o.append(lin("M92,34 L104,48 M104,34 L92,48", RUB, 4.2))
    o.append(lin("M26,44 q6,-6 12,0 t12,0 M60,90 q5,-5 10,0", "#5a7a8a", 2, 0.8))
    o.append(fill(poly([(24, 82), (30, 72), (36, 82)]), "#6e5634", 0.9))
    return J(o), ""


def tb_designer(P):
    """Smith's hammer resting on an anvil."""
    o = [P.shape(smooth([(14, 72), (34, 66), (94, 66), (116, 60), (106, 76), (84, 80), (44, 80), (24, 80)]), "metal", s=4)]
    o.append(P.shape(poly([(46, 80), (82, 80), (78, 96), (92, 108), (36, 108), (50, 96)]), "metal", s=4))
    o.append(fill(rect(30, 68, 60, 3, 1), "#ffffff", 0.45))
    o.append(P.shape(poly([(56, 60), (62, 56), (98, 18), (104, 24), (68, 62)]), "wood", s=2))
    o.append(P.shape(poly([(36, 46), (52, 30), (74, 52), (58, 68)]), "metal", s=3))
    o.append(P.detail("M41,51 L57,35", "metal", 0.8, 0.6))
    e = glow(P, 40, 66, 18, EMBER, 0.55) + J([fill(ell(30 + 9 * i, 58 - (i % 2) * 7, 1.6), EMBER_HOT, 0.95) for i in range(3)])
    return J(o), e


def tb_help(P):
    """Rolled scroll bearing a rubric question mark."""
    o = [P.shape(rect(30, 20, 68, 88, 4), "shirt", s=3)]
    o.append(P.shape(rect(22, 12, 84, 14, 7), "shirt", s=2))
    o.append(P.shape(rect(22, 102, 84, 14, 7), "shirt", s=2))
    o.append(P.shape(ell(22, 19, 5, 7), "wood", s=1))
    o.append(P.shape(ell(106, 19, 5, 7), "wood", s=1))
    o.append(P.shape(ell(22, 109, 5, 7), "wood", s=1))
    o.append(P.shape(ell(106, 109, 5, 7), "wood", s=1))
    q = "M50,50 Q50,36 64,36 Q78,36 78,50 Q78,60 66,64 Q64,66 64,76"
    o.append(lin(q, RUB, 7.5))
    o.append(fill(ell(64, 90, 5), RUB))
    o.append(lin("M38,98 L90,98", INK, 1.2, 0.5))
    return J(o), ""


def tb_property(P):
    """Timbered workshop gable with an iron key."""
    o = [P.shape(poly([(18, 60), (64, 22), (110, 60), (100, 60), (100, 108), (28, 108), (28, 60)]), "shirt", s=4)]
    o.append(P.shape(poly([(12, 64), (64, 18), (116, 64), (106, 66), (64, 32), (22, 66)]), "roof_a", s=2))
    o.append(P.detail("M28,72 L100,72 M28,72 L52,108 M100,72 L76,108", "wood", 1.2, 0.8))
    o.append(P.shape(rect(52, 80, 24, 28, 2), "wood", s=2))
    o.append(fill(rect(38, 78, 10, 10, 1), EMBER_HOT, 0.8))
    o.append(fill(rect(80, 78, 10, 10, 1), EMBER_HOT, 0.8))
    k = [P.shape(ell(92, 92, 12), "metal", s=2), fill(ell(92, 92, 5), "#000", 0.0),
         P.shape(poly([(82, 100), (88, 104), (64, 124), (58, 120)]), "metal", s=1.5),
         P.shape(poly([(66, 116), (72, 122), (68, 126), (62, 120)]), "metal", s=1)]
    o.extend(k)
    o.append(lin(ell(92, 92, 5), INK, 2.2))
    return J(o), glow(P, 64, 84, 26, EMBER, 0.25)


def tb_orders(P):
    """Folded letter sealed with rubric wax."""
    o = [P.shape(rect(14, 30, 100, 70, 4), "shirt", s=3)]
    o.append(lin("M14,32 L64,72 L114,32", INK, 2.6))
    o.append(lin("M14,98 L52,62 M114,98 L76,62", INK, 1.4, 0.6))
    o.append(fill(smooth([(64, 58), (76, 62), (80, 74), (72, 86), (58, 86), (50, 74), (52, 62)]), RUB))
    o.append(lin(smooth([(64, 58), (76, 62), (80, 74), (72, 86), (58, 86), (50, 74), (52, 62)]), INK, 2))
    o.append(lin("M58,72 L70,72 M64,66 L64,78", "#e8a088", 1.6, 0.8))
    return J(o), ""


def tb_wanted(P):
    """Pinned notice with a skull silhouette."""
    o = [P.shape(poly([(26, 18), (102, 14), (106, 112), (24, 116)]), "shirt", s=3)]
    o.append(P.shape(smooth([(46, 56), (50, 38), (64, 32), (78, 38), (82, 56), (76, 66), (52, 66)]), "shirt", s=1, flat=True))
    o.append(fill(ell(56, 52, 5.5, 6), INK))
    o.append(fill(ell(72, 52, 5.5, 6), INK))
    o.append(lin("M56,72 L56,78 M64,72 L64,78 M72,72 L72,78", INK, 2.2))
    o.append(lin("M40,92 L88,92 M44,100 L84,100", INK, 2.2, 0.6))
    o.append(P.shape(ell(64, 18, 6), "gold", s=1.5))
    return J(o), ""


ICONS = {k: v for k, v in globals().items() if k.startswith("tb_") and callable(v)}


# ------------------------------------------------------------------ toolbar frames
def tb_socket(P):
    """96x96 brass ring with rivets around a parchment disc (the icon sits on top)."""
    W = 96
    c = W / 2
    o = [f'<circle cx="{c}" cy="{c + 2}" r="44" fill="#000" opacity="0.35" {blur_filter(P, 2.4)}/>']
    o.append(f'<circle cx="{c}" cy="{c}" r="44" fill="{BRASS_D}"/>')
    gid = uid("br")
    P.defs.append(f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{BRASS_L}"/>'
                  f'<stop offset="0.5" stop-color="{BRASS}"/><stop offset="1" stop-color="{BRASS_D}"/></linearGradient>')
    o.append(f'<circle cx="{c}" cy="{c}" r="42" fill="url(#{gid})"/>')
    o.append(lin(ell(c, c, 42), INK, 2.4))
    cid = uid("sc")
    P.defs.append(f'<clipPath id="{cid}"><circle cx="{c}" cy="{c}" r="35"/></clipPath>')
    o.append(f'<g clip-path="url(#{cid})">' + parchment_fill(P, c - 36, c - 36, 72, 72, 36, seed=5, burn=0.7, depth=14) + "</g>")
    o.append(lin(ell(c, c, 35), INK, 2.2))
    o.append(lin(ell(c, c, 38.5), "#3a2a0c", 0.9, 0.6))
    for a in range(8):
        t = a * math.pi / 4 + math.pi / 8
        x, y = c + 38.6 * math.cos(t), c + 38.6 * math.sin(t)
        o.append(fill(ell(x, y, 2.2), BRASS_D) + fill(ell(x - 0.6, y - 0.6, 1.0), BRASS_L, 0.9))
    return J(o)


def toolbar_bar(P):
    """512x128 strip: parchment band framed by brass rails and end caps (9-slice margins 48)."""
    W, H = 512, 128
    o = [fill(rect(6, 14, W - 12, H - 22, 10), "#000", 0.4, blur_filter(P, 5))]
    gid = uid("rb")
    P.defs.append(f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{BRASS_L}"/>'
                  f'<stop offset="0.45" stop-color="{BRASS}"/><stop offset="1" stop-color="{BRASS_D}"/></linearGradient>')
    o.append(f'<path d="{rect(4, 8, W - 8, H - 16, 12)}" fill="url(#{gid})"/>')
    o.append(lin(rect(4, 8, W - 8, H - 16, 12), INK, 3))
    o.append(parchment_fill(P, 14, 18, W - 28, H - 36, 6, seed=17, burn=0.6, depth=18))
    o.append(lin(rect(14, 18, W - 28, H - 36, 6), INK, 2.4))
    o.append(lin(rect(20, 24, W - 40, H - 48, 3), GILT, 0.9, 0.8))
    for x in (24, W - 24):
        for y in (14, H - 14):
            o.append(fill(ell(x, y, 3), BRASS_D) + fill(ell(x - 0.8, y - 0.8, 1.3), BRASS_L))
    for x in (11, W - 11):
        d = poly([(x, H / 2 - 9), (x + 6, H / 2), (x, H / 2 + 9), (x - 6, H / 2)])
        o.append(fill(d, RUB) + lin(d, INK, 1.4))
    return J(o)


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
    for name, fn, W, H in [("tb_socket", tb_socket, 96, 96), ("toolbar_bar", toolbar_bar, 512, 128)]:
        if only and name not in only:
            continue
        P = painter(scale=1.0, lw_mul=0.75)
        body = f'<g {soft_filter(P, 0.8)}>{fn(P)}</g>'
        js.append(dict(name=f"ui_{name}", svg=svg_doc(W, H, P, body, ss=3), w=W, h=H, ss=3, out=os.path.join(UI, name + ".png")))
    return js


if __name__ == "__main__":
    render(jobs(), workers=3)
