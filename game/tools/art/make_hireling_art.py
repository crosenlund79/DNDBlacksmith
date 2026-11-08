"""Remembrance and hireling HUD art for Ember & Ash (iteration 010).

    python3 game/tools/art/make_hireling_art.py            # everything + contact sheet
    python3 game/tools/art/make_hireling_art.py --contact  # review sheet only

Props (straight top-down, transparent, exact spec size):
  props/template_vase.png (48x64, empty), props/template_vase_flowers.png (48x64),
  props/template_headstone_hireling.png (64x80), props/template_wildflowers_bundle.png (48x40)
Icons (64x64, item-icon pipeline): icons/template_flowers_remembrance.png
HUD / bubble activity icons (64x64): ui/template_act_{hammer,road,bandage,zzz,candle}.png
Review: tools/art/out/hireling_contact.png
"""
import os
import random
import sys

import artlib
from artlib import (painter, render, lin, fill, glow, ell, rect, poly, smooth, blob, sprite_svg, ground_shadow,
                    INK, EMBER, EMBER_HOT, GILT, RUB, SPR, OUT, ST, candle_top)
import make_icons as MI

PAL = ST["pal"]
J = MI.J
FLOWER_COLS = [PAL["cloth"][0], "#f2ead6", PAL["straw"][0], "#c8b4e0", "#a8b8d8", PAL["apple"][0]]


def blooms(P, pts, rnd, r=2.6):
    o = []
    for (x, y) in pts:
        col = rnd.choice(FLOWER_COLS)
        petals = " ".join(ell(x + r * 0.9 * c, y + r * 0.8 * s, r * 0.8, r * 0.7) for c, s in [(1, 0), (-1, 0), (0, 1), (0, -1), (0.7, 0.7)])
        o.append(fill(petals, col))
        o.append(lin(petals, INK, 0.45, 0.75))
        o.append(fill(ell(x, y, r * 0.42), PAL["gold"][1]))
    return J(o)


# ---------------------------------------------------------------- props
def vase_body(P, W, H):
    """A small glazed earthenware vase on a lace doily, seen from slightly above."""
    sh = ground_shadow(P, ell(26, 54, 17, 6), 3, 3, op=0.4)
    b = [P.shape(blob(24, 54, 19, 14, 0.05, 3, squash=0.42), "linen", s=1, lw=1.0, fill_override="#f4eedc")]
    b.append(lin(" ".join(ell(24 + 15 * c, 54 + 6 * s, 2.0) for c, s in [(1, 0), (-1, 0), (0.7, 0.7), (-0.7, 0.7), (0.7, -0.7), (-0.7, -0.7), (0, 1)]), INK, 0.45, 0.55))
    body = smooth([(17, 26), (13, 38), (14, 48), (24, 55), (34, 48), (35, 38), (31, 26)])
    b.append(P.shape(body, "blue", s=3, lw=1.3, fill_override="#4e6a8e"))
    b.append(P.detail("M15,40 Q24,44 33,40", "blue", 0.8, 0.9))
    b.append(fill("M18,30 Q16,40 19,48", "none") + lin("M18,31 Q16,40 19,47", "#dfe8f2", 1.6, 0.55))
    b.append(P.shape(rect(17.5, 20, 13, 8, 2), "blue", s=1, lw=1.2, fill_override="#5a7898"))
    b.append(P.shape(ell(24, 20.5, 8.5, 3.4), "blue", s=0.5, lw=1.2, fill_override="#6a88a8"))
    return sh, b


def vase(P, W, H):
    sh, b = vase_body(P, W, H)
    b.append(fill(ell(24, 20.8, 6.2, 2.2), "#1a1410", 0.9))
    return sh, J(b), ""


def vase_flowers(P, W, H):
    sh, b = vase_body(P, W, H)
    b.append(fill(ell(24, 20.8, 6.2, 2.2), "#1a1410", 0.9))
    rnd = random.Random(11)
    stems = []
    heads = [(10, 9), (17, 5), (25, 3), (33, 6), (39, 10), (14, 15), (22, 10), (30, 12), (36, 16), (8, 18)]
    for (x, y) in heads:
        stems.append(f"M{24 + rnd.uniform(-3, 3):.1f},21 Q{(x + 24) / 2:.1f},{y + 8:.1f} {x},{y}")
    b.append(lin(" ".join(stems), PAL["foliage"][2], 1.1))
    for (x, y) in [(12, 14), (34, 12), (20, 8)]:
        b.append(P.shape(f"M{x},{y} q4,-4 7,-1 q-3,4 -7,1 Z", "foliage", s=0.4, lw=0.8))
    b.append(blooms(P, heads, rnd, 2.5))
    return sh, J(b), ""


def headstone_hireling(P, W, H):
    """A fresh pale headstone over a new earth mound; the name is set in the face by the game."""
    sh = ground_shadow(P, rect(14, 10, 40, 60, 6), 4, 4)
    b = [P.shape(blob(32, 60, 26, 9, 0.08, 5, squash=0.55), "brown", s=2, lw=1.3, fill_override="#6e5038")]
    b.append(P.detail("M14,60 l6,-2 M24,64 l5,1 M38,62 l6,-1 M44,58 l4,2", "brown", 0.6))
    b.append(P.shape("M12,52 L12,18 Q12,4 32,4 Q52,4 52,18 L52,52 Z", "stone", s=3, lw=1.5, fill_override="#cfc8b4"))
    b.append(P.detail("M16,50 L16,19 Q16,8 32,8 Q48,8 48,19 L48,50", "stone", 0.5, 0.7))
    b.append(lin("M32,10 L32,18 M28,13 L36,13", INK, 1.1, 0.8))
    b.append(P.shape(rect(9, 50, 46, 7, 2), "stone", s=1, lw=1.3, fill_override="#b4ac98"))
    rnd = random.Random(5)
    b.append(blooms(P, [(18 + rnd.uniform(-2, 2), 63 + rnd.uniform(-1, 2)) for _ in range(2)] + [(46, 64)], rnd, 2.2))
    return sh, J(b), ""


def wildflowers_bundle(P, W, H):
    sh = ground_shadow(P, ell(24, 26, 18, 7), 2, 2, op=0.35)
    rnd = random.Random(4)
    b = [lin(" ".join(f"M{30 + rnd.uniform(-2, 2):.1f},{30 + rnd.uniform(-1, 1):.1f} L{12 + i * 3:.1f},{12 + rnd.uniform(-3, 3):.1f}" for i in range(7)),
             PAL["foliage"][2], 1.2)]
    b.append(lin("M34,33 L42,36 M33,31 L43,32", PAL["foliage"][1], 1.0))
    b.append(P.shape(rect(26, 25, 6, 8, 2), "straw", s=0.5, lw=1.0))
    b.append(blooms(P, [(12, 12), (15, 18), (19, 10), (22, 16), (26, 11), (11, 22), (18, 22)], rnd, 3.0))
    return sh, J(b), ""


PROPS = {"vase": (vase, 48, 64), "vase_flowers": (vase_flowers, 48, 64), "headstone_hireling": (headstone_hireling, 64, 80),
         "wildflowers_bundle": (wildflowers_bundle, 48, 40)}


def prop_jobs(only=None):
    js = []
    for pid, (fn, W, H) in PROPS.items():
        if only and pid not in only:
            continue
        P = painter(scale=1.0, lw_mul=0.7)
        sh, body, emit = fn(P, W, H)
        svg = sprite_svg(P, W, H, sh, body, emit, ss=3, wob=0.9, dil=0.7, grain=0.45, soot=0.6)
        js.append(dict(name=f"pr_{pid}", svg=svg, w=W, h=H, ss=3, out=os.path.join(SPR, "props", pid + ".png")))
    return js


# ---------------------------------------------------------------- icons (128 viewbox)
def flowers_remembrance(P):
    rnd = random.Random(8)
    heads = [(30, 30), (44, 20), (60, 16), (76, 22), (90, 34), (38, 46), (54, 34), (70, 38), (84, 50), (26, 54)]
    b = [lin(" ".join(f"M{96 + rnd.uniform(-3, 3):.1f},{100 + rnd.uniform(-3, 3):.1f} Q{(x + 96) / 2:.1f},{(y + 100) / 2 + 8:.1f} {x},{y}" for (x, y) in heads),
             PAL["foliage"][2], 3.2)]
    b.append(P.shape("M86,84 l14,-6 l8,10 l-14,8 Z", "straw", s=1, lw=2))
    b.append(lin("M100,98 L112,112 M96,100 L104,116 M102,94 L116,104", PAL["foliage"][1], 2.6))
    for (x, y, a) in [(40, 64, 20), (70, 58, -30)]:
        b.append(f'<g transform="rotate({a} {x} {y})">' + P.shape(ell(x, y, 10, 4), "foliage", s=1, lw=1.6) + "</g>")
    b.append(blooms(P, heads, rnd, 7.0))
    return J(b), ""


def act_hammer(P):
    b = [P.shape("M22,96 L92,96 L100,84 L84,80 L84,70 L36,70 L36,80 L18,84 Z", "darkiron", s=4)]
    b.append(P.shape("M30,96 L80,96 L74,112 L36,112 Z", "darkiron", s=2))
    b.append(P.shape(poly([(44, 60), (88, 18), (96, 26), (52, 68)]), "wood", s=2))
    b.append(P.shape(poly([(76, 10), (98, 32), (108, 22), (86, 0)]), "metal", s=3))
    b.append(glow(P, 60, 70, 18, EMBER, 0.5))
    return J(b), ""


def act_road(P):
    b = [P.shape("M48,124 Q56,80 60,60 Q62,40 66,20 L74,20 Q78,40 82,60 Q90,90 104,124 Z", "road", s=3)]
    b.append(P.detail("M64,110 L66,96 M68,80 L69,70 M70,56 L71,48", "road", 0.8, 2))
    b.append(P.shape(rect(26, 30, 8, 80, 2), "wood", s=1))
    b.append(P.shape("M18,34 L62,34 L72,44 L62,54 L18,54 Z", "wood", s=2))
    b.append(P.shape("M20,62 L60,62 L60,80 L20,80 L10,71 Z", "wood", s=2))
    b.append(lin("M26,44 L56,44 M24,71 L52,71", INK, 2, 0.6))
    return J(b), ""


def act_bandage(P):
    b = [f'<g transform="rotate(-35 64 64)">' + P.shape(rect(16, 46, 96, 36, 14), "linen", s=3, fill_override="#f2ead8") +
         P.shape(rect(48, 46, 32, 36, 4), "linen", s=1, fill_override="#e4d8bc") +
         lin(" ".join(f"M{52 + i * 6},52 l0,24" for i in range(5)), INK, 1.2, 0.35) + "</g>"]
    b.append(f'<g transform="rotate(-35 64 64)">' + P.shape(rect(58, 56, 12, 16, 1), "redp", s=0.5, lw=1.5, fill_override="#a43a2a") + "</g>")
    return J(b), ""


def act_zzz(P):
    b = [P.shape("M86,14 A40,40 0 1,0 116,70 A32,32 0 1,1 86,14 Z", "straw", s=2, fill_override="#f0dc9a")]
    for (x, y, s) in [(18, 70, 22), (44, 44, 17), (64, 24, 13)]:
        b.append(lin(f"M{x},{y} l{s},0 l{-s},{s} l{s},0", INK, 6.5))
        b.append(lin(f"M{x},{y} l{s},0 l{-s},{s} l{s},0", "#5a6a8e", 3.2))
    return J(b), ""


def act_candle(P):
    b = [P.shape(ell(64, 106, 32, 12), "darkiron", s=2)]
    b.append(P.shape(rect(50, 44, 28, 62, 4), "wax", s=4))
    b.append(P.detail("M56,50 q3,10 0,22", "wax", 0.6, 2))
    b.append(lin("M64,44 L64,36", INK, 2.5))
    b.append(glow(P, 64, 28, 24, EMBER, 0.65))
    b.append(fill("M64,10 Q74,26 64,38 Q54,26 64,10 Z", EMBER_HOT))
    b.append(lin("M64,10 Q74,26 64,38 Q54,26 64,10 Z", INK, 1.5, 0.8))
    return J(b), ""


ICONS = {"flowers_remembrance": ("icons", flowers_remembrance), "act_hammer": ("ui", act_hammer), "act_road": ("ui", act_road),
         "act_bandage": ("ui", act_bandage), "act_zzz": ("ui", act_zzz), "act_candle": ("ui", act_candle)}


def icon_jobs(only=None):
    js = []
    for ic, (folder, fn) in ICONS.items():
        if only and ic not in only:
            continue
        svg, ss = MI.build(ic, fn, 64, 0.95)
        js.append(dict(name=f"ic_{ic}", svg=svg, w=64, h=64, ss=ss, out=os.path.join(SPR, folder, ic + ".png")))
    return js


def contact():
    from PIL import Image, ImageDraw
    sheet = Image.new("RGBA", (900, 330), (232, 220, 190, 255))
    d = ImageDraw.Draw(sheet)
    x = 20
    for pid, (_, W, H) in PROPS.items():
        p = artlib.tpath(os.path.join(SPR, "props", pid + ".png"))
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA")
            im2 = im.resize((W * 2, H * 2), Image.NEAREST)
            sheet.alpha_composite(im2, (x, 20))
            d.text((x, 190), pid, fill=(32, 20, 12, 255))
            x += W * 2 + 30
    x = 20
    for ic, (folder, _) in ICONS.items():
        p = artlib.tpath(os.path.join(SPR, folder, ic + ".png"))
        if os.path.exists(p):
            sheet.alpha_composite(Image.open(p).convert("RGBA").resize((96, 96)), (x, 210))
            sheet.alpha_composite(Image.open(p).convert("RGBA").resize((24, 24)), (x + 100, 280))
            x += 140
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, "hireling_contact.png")
    sheet.convert("RGB").save(out)
    print(out)


if __name__ == "__main__":
    only = artlib.only_filter()
    if "--contact" not in sys.argv:
        render(prop_jobs(only) + icon_jobs(only))
    contact()
