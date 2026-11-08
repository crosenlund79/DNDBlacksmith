"""Trade art for Ember & Ash: exotic material icons, docked merchant ships, the harbour signal pole and the
monsters whose hides reach the forge (bear, troll, wyvern).

    python3 game/tools/art/make_trade_art.py                 # everything
    python3 game/tools/art/make_trade_art.py icons ships enemies
    python3 game/tools/art/make_trade_art.py --contact        # review sheet only

Icons: assets/sprites/icons/template_<id>.png (64x64, same pipeline as make_icons.py).
Ships: assets/sprites/props/template_ship_{spice,barge,whaler}.png (512x192, straight top-down, bow to the right,
       moored: furled sails, mooring lines off the port side toward the quay at the top edge).
Flag:  assets/sprites/props/template_ship_flag.png (48x96).
Enemies: assets/sprites/enemies/template_{bear,troll,wyvern}.png via make_enemies.py's sheet pipeline.
Characters (herbalist, harbourmaster) use the shared tools: make_minis.py --only=... and make_characters.py <id>.
Review: tools/art/out/trade_contact.png
"""
import math
import os
import random
import sys

import artlib
from artlib import (painter, render, lin, fill, glow, ell, rect, poly, smooth, blob, lit_marks, sprite_svg, ground_shadow,
                    planks, INK, EMBER, EMBER_HOT, GILT, RUB, VIOLET, VIOLET_HOT, SPR, OUT)
import make_icons as MI

PAL = MI.PAL
J = MI.J

PAL.setdefault("bearfur", ("#8a6a4c", "#5a3e28", "#2a1c10"))
PAL.setdefault("trollhide", ("#a8ae88", "#6e7656", "#343a26"))
PAL.setdefault("wyvern", ("#a8c49a", "#5e8a5a", "#28402a"))
PAL.setdefault("dragon", ("#b0444a", "#5e1418", "#22060a"))
PAL.setdefault("dbone", ("#f4ecd6", "#d8caa4", "#8a7a56"))
PAL.setdefault("orich", ("#f0b878", "#c0702e", "#5e2c10"))
PAL.setdefault("bloodroot", ("#d0705c", "#8e2a1e", "#40100a"))
PAL.setdefault("frostcap", ("#f0f6fa", "#bcd4e2", "#5e7c92"))
PAL.setdefault("silverleaf", ("#d8e2d0", "#94a888", "#46583c"))
PAL.setdefault("pouch", ("#c8a87c", "#8e6a44", "#46321c"))
PAL.setdefault("ashbowl", ("#7a726a", "#4a4440", "#201c1a"))


# ================================================================== icons
def bear_pelt(P):
    from make_stations import pelt
    b = [P.shape(pelt(64, 70, 64, 50, 0), "bearfur", s=7)]
    rnd = random.Random(7)
    b.append(P.detail(" ".join(f"M{30+rnd.uniform(0,66):.1f},{44+rnd.uniform(0,52):.1f} l{rnd.uniform(-2,2):.1f},5" for _ in range(24)), "bearfur", 0.6, 0.8))
    b.append(fill(ell(60, 66, 20, 16), PAL["bearfur"][0], 0.3))
    # head with ears and muzzle at the top of the pelt
    b.append(P.shape(ell(50, 12, 6) + " " + ell(78, 12, 6), "bearfur", s=1.5))
    b.append(P.shape(ell(64, 24, 18, 14), "bearfur", s=3))
    b.append(P.shape(ell(64, 31, 8, 6), "hide", s=1.5))
    b.append(fill(ell(64, 28.5, 3, 2.2), INK))
    b.append(fill(ell(56, 20, 1.8) + " " + ell(72, 20, 1.8), INK))
    # claws on the four paws
    paws = [(16, 112, 1), (112, 112, -1), (26, 26, 1), (102, 26, -1)]
    claws = " ".join(f"M{x+(i-1)*3.2:.1f},{y:.1f} l{-d*0.6:.1f},{4 if y > 64 else -4}" for x, y, d in paws for i in range(3))
    b.append(lin(claws, INK, 2.6))
    b.append(lin(claws, "#f2ead2", 1.2))
    return J(b), ""


def _hide(P, role, seed, warts=False, scales=False):
    from make_stations import pelt
    shape = pelt(64, 64, 76, 54, 0.32)
    b = [P.shape(shape, role, s=7)]
    rnd = random.Random(seed)
    if warts:
        b.append(P.shape(" ".join(ell(30 + rnd.uniform(0, 66), 38 + rnd.uniform(0, 50), rnd.uniform(2.5, 4.5)) for _ in range(11)), role, s=1, lw=1.4,
                         fill_override=PAL[role][0]))
        b.append(P.detail("M40,60 Q58,52 88,62 M46,80 Q66,72 86,82", role, 0.6))
    if scales:
        cid = "hide_clip_%d" % seed
        P.defs.append(f'<clipPath id="{cid}"><path d="{shape}"/></clipPath>')
        sc = []
        for row, y in enumerate(range(14, 120, 8)):
            for x in range(4 + (row % 2) * 6, 128, 12):
                sc.append(f"M{x-6},{y} Q{x},{y+9} {x+6},{y}")
        b.append(f'<g clip-path="url(#{cid})">' + lin(" ".join(sc), INK, 1.1, 0.75) + lin(" ".join(sc), PAL[role][0], 0.5, 0.45) + "</g>")
        b.append(lin("M64,20 L64,108", INK, 2.4, 0.7))
        b.append(fill(" ".join(poly([(64, y), (68, y + 4), (64, y + 7), (60, y + 4)]) for y in range(24, 100, 12)), "#d8c070", 0.9))
    return J(b), ""


def troll_hide(P):
    return _hide(P, "trollhide", 11, warts=True)


def wyvern_hide(P):
    return _hide(P, "wyvern", 12, scales=True)


def dragon_scale(P):
    shield = smooth([(64, 14), (98, 30), (106, 62), (92, 96), (64, 116), (36, 96), (22, 62), (30, 30)], t=0.35)
    b = [P.shape(shield, "dragon", s=8)]
    b.append(P.detail("M64,20 L64,108 M64,36 Q84,44 96,62 M64,36 Q44,44 32,62 M64,62 Q80,70 88,88 M64,62 Q48,70 40,88", "dragon", 0.8, 0.85))
    b.append(fill(smooth([(46, 30), (60, 22), (58, 46), (44, 60)]), "#ffffff", 0.22))
    e = glow(P, 64, 70, 34, EMBER, 0.35) + lit_marks(P, "M64,40 L64,100 M64,62 Q80,70 88,88 M64,62 Q48,70 40,88", EMBER, EMBER_HOT, w=0.9, glow_w=3, op=0.75, blur=1.6)
    return J(b), e


def dragon_bone(P):
    def bone(x0, y0, x1, y1, w, role="dbone"):
        ang = math.atan2(y1 - y0, x1 - x0)
        nx, ny = -math.sin(ang), math.cos(ang)
        shaft = poly([(x0 + nx * w, y0 + ny * w), (x1 + nx * w, y1 + ny * w), (x1 - nx * w, y1 - ny * w), (x0 - nx * w, y0 - ny * w)])
        knobs = " ".join(ell(x + nx * k * w * 0.9, y + ny * k * w * 0.9, w * 1.05) for x, y in [(x0, y0), (x1, y1)] for k in (1, -1))
        return [P.shape(knobs, role, s=2), P.shape(shaft, role, s=3)]
    b = bone(22, 100, 104, 30, 9)
    b.append(P.detail("M40,82 L86,44 M48,90 l6,-6 M80,58 l8,-6", "dbone", 0.6))
    # a cracked, ember-dark marrow end
    b.append(fill(ell(104, 30, 5, 4), "#3a1408"))
    e = glow(P, 104, 30, 14, EMBER, 0.5) + fill(ell(104, 30, 2.4, 1.8), EMBER_HOT, 0.9)
    return J(b), e


def ore_orichalcum(P):
    return MI.ore(P, "slate", "#f0a050", 21, glowv=("#e88a3a", "#ffe0a8"), sheen="#ffe0b0")


def herb_bloodroot(P):
    # knotted red roots with a few dark leaves
    b = [P.shape(smooth([(46, 34), (60, 40), (66, 58), (80, 70), (94, 96), (86, 100), (72, 78), (60, 70), (50, 92), (40, 96), (46, 70), (40, 48)], t=0.4), "bloodroot", s=5)]
    b.append(P.shape(smooth([(62, 62), (34, 74), (20, 92), (26, 96), (42, 82), (64, 72)], t=0.4), "bloodroot", s=2))
    b.append(P.detail("M50,48 l6,6 M58,62 l6,2 M72,76 l5,6 M40,80 l4,-4", "bloodroot", 0.7))
    b.append(lin("M90,98 q4,8 10,10 M44,96 q-2,10 -8,14 M22,94 q-6,4 -8,10", INK, 1.4))
    for x, y, a in [(46, 32, -1.9), (52, 30, -1.2), (40, 34, -2.5)]:
        tip = (x + math.cos(a) * 22, y + math.sin(a) * 22)
        px, py = -math.sin(a) * 7, math.cos(a) * 7
        mx, my = (x + tip[0]) / 2, (y + tip[1]) / 2
        b.append(P.shape(f"M{x:.1f},{y:.1f} Q{mx+px:.1f},{my+py:.1f} {tip[0]:.1f},{tip[1]:.1f} Q{mx-px:.1f},{my-py:.1f} {x:.1f},{y:.1f} Z", "green", s=1.5, lw=2.4))
    b.append(fill(" ".join(ell(x, y, 2.2) for x, y in [(66, 58), (84, 84), (46, 76)]), "#e83a2a", 0.95))
    return J(b), ""


def herb_frostcap(P):
    b = []
    for x, y, r, s in [(44, 78, 22, 1), (82, 70, 26, 2), (62, 52, 18, 3)]:
        b.append(P.shape(rect(x - 5, y, 10, 30 - s * 4, 4), "linen", s=2))
        b.append(P.shape(smooth([(x - r, y + 4), (x - r * 0.7, y - r * 0.6), (x, y - r * 0.85), (x + r * 0.7, y - r * 0.6), (x + r, y + 4), (x, y + 8)], t=0.4), "frostcap", s=4))
        b.append(P.detail(f"M{x-r*0.6:.1f},{y:.1f} Q{x:.1f},{y-r*0.5:.1f} {x+r*0.6:.1f},{y:.1f}", "frostcap", 0.6))
        b.append(fill(" ".join(ell(x + dx, y - r * 0.4 + dy, 1.8) for dx, dy in [(-r * 0.4, 2), (r * 0.1, -2), (r * 0.45, 3)]), "#ffffff", 0.95))
    e = J([glow(P, x, y, 16, "#bfe4ff", 0.45) for x, y in [(44, 70), (82, 60), (62, 44)]])
    return J(b), e


def herb_silverleaf(P):
    stem = "M64,118 Q60,84 66,30"
    b = [lin(stem, INK, 4.6), lin(stem, "#6a7a5a", 2.4)]
    leaves = [(64, 96, -2.7), (64, 90, -0.45), (63, 74, -2.6), (64, 68, -0.5), (64, 52, -2.5), (65, 46, -0.6), (66, 32, -1.6)]
    for x, y, a in leaves:
        L = 30
        tip = (x + math.cos(a) * L, y + math.sin(a) * L)
        px, py = -math.sin(a) * 10, math.cos(a) * 10
        mx, my = (x + tip[0]) / 2, (y + tip[1]) / 2
        d = f"M{x:.1f},{y:.1f} Q{mx+px:.1f},{my+py:.1f} {tip[0]:.1f},{tip[1]:.1f} Q{mx-px:.1f},{my-py:.1f} {x:.1f},{y:.1f} Z"
        b.append(P.shape(d, "silverleaf", s=1.5, lw=2.4))
        # silver underside flash on one half of each leaf
        b.append(fill(f"M{x:.1f},{y:.1f} Q{mx-px*0.85:.1f},{my-py*0.85:.1f} {tip[0]:.1f},{tip[1]:.1f} Q{mx-px*0.15:.1f},{my-py*0.15:.1f} {x:.1f},{y:.1f} Z", "#eef2f4", 0.85))
        b.append(lin(f"M{x:.1f},{y:.1f} L{tip[0]:.1f},{tip[1]:.1f}", PAL["silverleaf"][2], 0.8, 0.8))
    e = J([glow(P, x, y, 6, "#ffffff", 0.5) for x, y in [(40, 60), (90, 40), (36, 86)]])
    return J(b), e


def _pouch(P, role, mouth_col):
    body = smooth([(46, 40), (82, 40), (102, 70), (98, 102), (64, 114), (30, 102), (26, 70)], t=0.4)
    b = [P.shape(body, role, s=6)]
    b.append(P.shape(smooth([(42, 30), (86, 30), (82, 44), (46, 44)], t=0.3), role, s=2))
    b.append(fill(ell(64, 34, 18, 5), mouth_col))
    b.append(P.shape(rect(40, 42, 48, 6, 2), "strap", s=1))
    b.append(P.detail("M44,62 Q64,74 86,62 M40,86 Q64,98 90,86", role, 0.6))
    return b


def reagent_aether_dust(P):
    b = _pouch(P, "pouch", "#6a58c8")
    rnd = random.Random(5)
    spill = " ".join(ell(70 + rnd.uniform(-34, 40), 18 + rnd.uniform(-10, 14), rnd.uniform(1, 2.4)) for _ in range(16))
    b.append(fill(spill, "#b8a8ff", 0.95))
    e = glow(P, 64, 30, 30, VIOLET, 0.55) + fill(spill, "#e6deff", 0.9) + J(fill(MI.sparkle(x, y, r), "#ffffff", 0.95) for x, y, r in [(50, 20, 6), (84, 14, 5), (96, 30, 4)])
    return J(b), e


def reagent_wyrm_ash(P):
    bowl = smooth([(18, 62), (110, 62), (100, 96), (64, 110), (28, 96)], t=0.4)
    b = [P.shape(bowl, "ashbowl", s=5), P.shape(ell(64, 62, 46, 14), "ashbowl", s=-2, hl=False)]
    b.append(fill(smooth([(26, 62), (44, 50), (64, 46), (84, 50), (102, 62), (64, 70)], t=0.4), "#5e5650"))
    rnd = random.Random(9)
    b.append(fill(" ".join(ell(30 + rnd.uniform(0, 68), 52 + rnd.uniform(0, 14), rnd.uniform(1, 2.4)) for _ in range(18)), "#8e8680", 0.9))
    b.append(lin("M30,96 l10,-4 M90,96 l-8,-6", INK, 1.2, 0.6))
    cores = [(56, 56, 4), (72, 58, 3), (64, 52, 2.4)]
    b.append(fill(" ".join(ell(x, y, r) for x, y, r in cores), "#7a2010"))
    e = glow(P, 64, 56, 30, EMBER, 0.6) + fill(" ".join(ell(x, y, r * 0.7) for x, y, r in cores), EMBER_HOT, 0.95)
    e += lin("M60,44 q-6,-10 2,-18 q6,-8 0,-16 M72,46 q6,-8 0,-14", "#9a908a", 1.6, 0.55)
    return J(b), e


ICONS = dict(bear_pelt=bear_pelt, troll_hide=troll_hide, wyvern_hide=wyvern_hide, dragon_scale=dragon_scale, dragon_bone=dragon_bone,
             ore_orichalcum=ore_orichalcum, herb_bloodroot=herb_bloodroot, herb_frostcap=herb_frostcap, herb_silverleaf=herb_silverleaf,
             reagent_aether_dust=reagent_aether_dust, reagent_wyrm_ash=reagent_wyrm_ash)
# also visible to make_icons.py so a full icon rebuild includes these
MI.ICONS.update(ICONS)


def icon_jobs(only=None):
    js = []
    for ic, fn in ICONS.items():
        if only and ic not in only:
            continue
        svg, ss = MI.build(ic, fn, 64, 0.95)
        js.append(dict(name=f"ic_{ic}", svg=svg, w=64, h=64, ss=ss, out=os.path.join(SPR, "icons", ic + ".png")))
    return js


# ================================================================== ships (512 x 192, bow to the right)
SHIPS = {
    "spice": dict(hull="#8a5a34", deck="wood", sail="#e8d6a8", trim=GILT, masts=2, cargo="spice", awning="#9a2a1e"),
    "barge": dict(hull="#5a5048", deck="wood", sail="#8a7a64", trim="#8e8a84", masts=1, cargo="ore", awning=None),
    "whaler": dict(hull="#2e2824", deck="wood", sail="#c8c0ac", trim="#6e6a64", masts=2, cargo="hides", awning=None),
}
PAL.setdefault("hull_spice", ("#b07a4c", "#8a5a34", "#46281a"))
PAL.setdefault("hull_barge", ("#8a8078", "#5a5048", "#2a2420"))
PAL.setdefault("hull_whaler", ("#58504a", "#2e2824", "#120e0c"))
PAL.setdefault("sailcloth", ("#f4ead0", "#e0ceA0".lower(), "#8e7c56"))
PAL.setdefault("sail_barge", ("#b4a690", "#8a7a64", "#4a3e2e"))
PAL.setdefault("sail_whaler", ("#e0dacc", "#c8c0ac", "#6a6456"))


def hull_outline(kind, W=512, H=192):
    cy = H / 2 + 6
    if kind == "barge":     # broad, blunt
        x0, x1, hw = 44, 470, 58
        return smooth([(x0, cy - hw + 6), (x1 - 40, cy - hw), (x1, cy - hw * 0.55), (x1 + 8, cy), (x1, cy + hw * 0.55), (x1 - 40, cy + hw),
                       (x0, cy + hw - 6), (x0 - 8, cy)], t=0.3), cy, x0, x1, hw
    if kind == "whaler":    # double-ended
        x0, x1, hw = 40, 478, 50
        return smooth([(x0, cy), (x0 + 60, cy - hw), (W / 2, cy - hw - 3), (x1 - 70, cy - hw), (x1, cy), (x1 - 70, cy + hw), (W / 2, cy + hw + 3),
                       (x0 + 60, cy + hw)], t=0.45), cy, x0, x1, hw
    x0, x1, hw = 36, 486, 48     # spice: sleek, transom stern, long bow
    return smooth([(x0, cy - hw * 0.8), (x0 + 120, cy - hw), (x1 - 120, cy - hw + 2), (x1, cy), (x1 - 120, cy + hw - 2), (x0 + 120, cy + hw),
                   (x0, cy + hw * 0.8)], t=0.4), cy, x0, x1, hw


def ship(kind):
    def fn(P, W, H):
        cfg = SHIPS[kind]
        sh, b, e = [], [], []
        outline, cy, x0, x1, hw = hull_outline(kind, W, H)
        # water wake and ripples under the hull (soft, on the transparent sprite)
        sh.append(fill(smooth([(x0 - 20, cy - hw - 6), (x1 + 20, cy - hw * 0.5), (x1 + 30, cy), (x1 + 20, cy + hw * 0.5), (x0 - 20, cy + hw + 6), (x0 - 30, cy)], t=0.4),
                       "#1e3442", 0.22))
        rip = " ".join(f"M{x:.0f},{cy + s * (hw + 10 + (i % 3) * 5):.0f} q14,{-3 * s} 28,0" for i, x in enumerate(range(int(x0), int(x1), 46)) for s in (1, -1))
        sh.append(lin(rip, "#e8f0f0", 1.2, 0.45))
        sh.append(ground_shadow(P, outline, 6, 9, op=0.45))
        b.append(P.shape(outline, "hull_" + kind, s=8))
        # deck inset with planks
        inset = 9
        cid = f"deck_{kind}"
        deck_d = hull_outline(kind, W, H)[0]
        P.defs.append(f'<clipPath id="{cid}"><path d="{deck_d}" transform="translate({W/2},{cy}) scale(0.94,0.78) translate({-W/2},{-cy})"/></clipPath>')
        planks_d = planks(P, x0, cy - hw, x1 - x0, hw * 2, "wood", n=9, dirn="h", s=2, nails=False, seed=3 + len(kind))
        b.append(f'<g clip-path="url(#{cid})">{planks_d}</g>')
        b.append(f'<path d="{deck_d}" transform="translate({W/2},{cy}) scale(0.94,0.78) translate({-W/2},{-cy})" fill="none" stroke="{INK}" stroke-width="2.4"/>')
        # rail trim
        b.append(f'<path d="{deck_d}" transform="translate({W/2},{cy}) scale(0.97,0.89) translate({-W/2},{-cy})" fill="none" stroke="{cfg["trim"]}" stroke-width="2.6" opacity="0.9"/>')
        # hatches / cargo
        rnd = random.Random(len(kind) * 7)
        if cfg["cargo"] == "spice":
            for i, x in enumerate((150, 196, 240)):
                b.append(P.shape(rect(x, cy - 22 + (i % 2) * 8, 34, 26, 2), "wood", s=2))
                b.append(P.detail(f"M{x},{cy-22+(i%2)*8+13} h34", "wood", 0.6))
            for x, y, c in [(290, cy - 18, "#c8502a"), (300, cy + 8, "#d8a83a"), (318, cy - 6, "#7e2418")]:
                b.append(P.shape(ell(x, y, 11, 9), "burlap", s=1.5))
                b.append(fill(ell(x, y - 2, 7, 4), c))
            if cfg["awning"]:
                b.append(P.shape(rect(64, cy - 30, 60, 60, 3), "cloth", s=3))
                b.append(P.detail(" ".join(f"M{64+i*12},{cy-30} v60" for i in range(1, 5)), "cloth", 0.6))
        elif cfg["cargo"] == "ore":
            for i, x in enumerate((110, 190, 270, 350)):
                b.append(P.shape(rect(x, cy - 34, 64, 68, 3), "darkiron", s=3))
                b.append(P.shape(blob(x + 32, cy, 26, 7, 0.2, i + 2, squash=0.9), "stone", s=3))
                b.append(fill(" ".join(ell(x + 14 + rnd.uniform(0, 36), cy - 16 + rnd.uniform(0, 32), rnd.uniform(2, 4)) for _ in range(6)),
                              ["#d07a3c", "#d8ecf8", "#f0a050", "#a8502c"][i], 0.95))
            b.append(P.shape(rect(52, cy - 22, 40, 44, 3), "wood", s=2))   # deckhouse
            e.append(glow(P, 72, cy, 18, EMBER, 0.35))
        else:  # hides drying, barrels, harpoons
            for i, x in enumerate((140, 210)):
                from make_stations import pelt
                b.append(P.shape(pelt(x, cy, 46, 40, math.pi / 2), "hide" if i else "trollhide", s=3))
            for x, y in [(300, cy - 22), (318, cy - 4), (300, cy + 16)]:
                b.append(P.shape(ell(x, y, 10), "wood", s=2))
                b.append(lin(ell(x, y, 6.5), INK, 1.0, 0.7))
            b.append(lin(f"M350,{cy-30} L420,{cy-24} M352,{cy+26} L418,{cy+20}", INK, 3.0))
            b.append(lin(f"M350,{cy-30} L420,{cy-24} M352,{cy+26} L418,{cy+20}", "#8e8a84", 1.4))
        # masts with furled sails (seen from above: yards across the hull, sail bundled along each yard)
        mx = [W * 0.42, W * 0.64] if cfg["masts"] == 2 else [W * 0.56]
        sail_role = {"spice": "sailcloth", "barge": "sail_barge", "whaler": "sail_whaler"}[kind]
        for m in mx:
            yl = hw * 1.25
            b.append(P.shape(rect(m - 3, cy - yl, 6, yl * 2, 3), "wood", s=1.5))
            b.append(P.shape(smooth([(m - 8, cy - yl + 4), (m + 2, cy - yl + 2), (m + 9, cy), (m + 2, cy + yl - 2), (m - 8, cy + yl - 4), (m - 2, cy)], t=0.4), sail_role, s=3))
            b.append(P.detail(" ".join(f"M{m-6},{cy+y:.0f} l12,2" for y in range(int(-yl + 10), int(yl - 6), 12)), sail_role, 0.6))
            b.append(P.shape(ell(m, cy, 8), "wood", s=1.5))
        # bowsprit + figurehead
        b.append(lin(f"M{x1-6},{cy} L{x1+22},{cy}", INK, 4.4))
        b.append(lin(f"M{x1-6},{cy} L{x1+22},{cy}", PAL["wood"][1], 2.2))
        # mooring lines toward the quay (top edge)
        b.append(lin(f"M{x0+40},{cy-hw+8} L{x0+20},2 M{x1-60},{cy-hw+10} L{x1-30},2", "#e8dcc0", 1.6, 0.9))
        b.append(lin(f"M{x0+40},{cy-hw+8} L{x0+20},2 M{x1-60},{cy-hw+10} L{x1-30},2", INK, 0.5, 0.6))
        # stern lantern
        e.append(glow(P, x0 + 10, cy, 14, EMBER, 0.55))
        e.append(fill(ell(x0 + 10, cy, 3), EMBER_HOT))
        return J(sh), J(b), J(e)
    return fn


def ship_flag(P, W, H):
    sh = [ground_shadow(P, ell(24, 88, 10, 4), 4, 3, op=0.4)]
    b = [P.shape(ell(24, 88, 8, 5), "stone", s=2), P.shape(rect(21, 10, 6, 80, 3), "wood", s=1.5)]
    b.append(P.shape(smooth([(27, 12), (46, 18), (40, 24), (46, 30), (27, 34)], t=0.2), "cloth", s=2))
    b.append(fill(ell(34, 23, 3), GILT))
    return J(sh), J(b), ""


PROPS = {"ship_spice": ship("spice"), "ship_barge": ship("barge"), "ship_whaler": ship("whaler"), "ship_flag": ship_flag}


def prop_jobs(only=None):
    js = []
    for pid, fn in PROPS.items():
        if only and pid not in only:
            continue
        W, H = (48, 96) if pid == "ship_flag" else (512, 192)
        P = painter(scale=1.0, lw_mul=0.7)
        sh, body, emit = fn(P, W, H)
        svg = sprite_svg(P, W, H, sh, body, emit, ss=3 if W < 100 else 2, wob=0.9, dil=0.7, grain=0.45, soot=0.6)
        js.append(dict(name=f"pr_{pid}", svg=svg, w=W, h=H, ss=3 if W < 100 else 2, out=os.path.join(SPR, "props", pid + ".png")))
    return js


# ================================================================== enemies (registered into make_enemies)
def _enemy_mod():
    import make_enemies as ME
    from make_enemies import L, fur_strokes, Biped
    from miniature import CX, FY, capsule
    from person import tri
    ME.ROLES.update(bear=tri("#6a4c34", 0.0), bear2=tri("#3e2a1c", 0.0), muzzle=tri("#a88464", 0.02),
                    troll=tri("#7a8462", 0.0), troll2=tri("#4e5640", 0.0), trollbelly=tri("#9aa080", 0.02), loin=tri("#5a4430", 0.0),
                    wyv=tri("#5e7e58", 0.0), wyv2=tri("#34502e", 0.0), wing=tri("#7e6a52", 0.0), wyvbelly=tri("#c8bc8c", 0.02))

    def bear(e):
        a = e.a
        rnd = random.Random(8)
        dx = -9 * a
        y0 = FY
        shx, shy = CX - 22 + dx, y0 - 66 + 6 * a
        hpx, hpy = CX + 32 + dx * 0.4, y0 - 56
        e.limb([(shx + 6, shy + 22), (shx - 2 - 8 * a, y0 - 18), (shx - 2 - 10 * a, y0 - 7)], 9, 6.5, "bear2")
        e.limb([(hpx + 4, hpy + 12), (hpx + 10 + 6 * a, y0 - 18), (hpx + 6 + 8 * a, y0 - 7)], 10, 6.5, "bear2")
        body = [(shx - 20, shy + 6), (shx - 10, shy - 24), (CX + dx * 0.6 - 6, shy - 30), (hpx, hpy - 22), (hpx + 22, hpy - 6), (hpx + 20, hpy + 18),
                (CX + dx * 0.6, hpy + 28), (shx, shy + 40), (shx - 20, shy + 30)]
        e.sh(smooth(body, t=0.42), "bear", s=3.4)
        e.det(fur_strokes(rnd, shx - 8, hpx + 14, shy - 20, hpy + 18, 26, 5), 0.7, 0.7)
        nf = (shx - 8 - 16 * a, y0 + 2)
        e.limb([(shx + 2, shy + 24), (shx - 6 - 10 * a, y0 - 14), (nf[0], nf[1] - 4)], 10.5, 7, "bear")
        e.sh(ell(nf[0] - 1, nf[1] - 2, 8, 3.6), "bear2", s=0.6)
        e.ln(" ".join(f"M{nf[0]-7+i*3:.1f},{nf[1]-1:.1f} l-2,3" for i in range(4)), "#f2ead2", 1.1)
        nh = (hpx + 2 + 10 * a, y0 + 3)
        e.limb([(hpx, hpy + 10), (hpx + 6 + 6 * a, y0 - 14), (nh[0], nh[1] - 4)], 11, 7, "bear")
        e.sh(ell(nh[0], nh[1] - 2, 8, 3.6), "bear2", s=0.6)
        # head: round with small ears, short muzzle; mouth open in the attack
        hx, hy = shx - 26 - 6 * a, shy - 6 + 10 * a
        e.sh(ell(hx + 10, hy - 16, 6, 6) + " " + ell(hx - 6, hy - 18, 6, 6), "bear2", s=0.8)
        e.sh(smooth([(hx + 16, hy - 12), (hx + 2, hy - 18), (hx - 12, hy - 14), (hx - 18, hy - 2), (hx - 30, hy + 2), (hx - 30, hy + 10),
                     (hx - 14, hy + 14), (hx + 4, hy + 14), (hx + 18, hy + 4)], t=0.42), "bear", s=2.2)
        e.sh(smooth([(hx - 16, hy + 0), (hx - 30, hy + 3), (hx - 29, hy + 10), (hx - 14, hy + 12)], t=0.4), "muzzle", s=0.6, lw=1.0)
        e.fl(ell(hx - 30, hy + 4, 3, 2.4), INK)
        if a:
            e.fl(poly([(hx - 28, hy + 10), (hx - 14, hy + 12), (hx - 26, hy + 18)]), "#5a1610")
            e.ln(f"M{hx-26:.1f},{hy+10:.1f} l1,3 M{hx-20:.1f},{hy+11:.1f} l1,3", "#f2ead2", 1.3)
        e.eye(hx - 12, hy - 5, "#d8a040", "#fff0a0", r=1.6, g=4, gop=0.5)

    def troll(e):
        a = e.a
        b = Biped(e, H=176, hr=13, sw=30, hw=22, lw=10, ar=8.5, hunch=1.6, lunge=12)
        hx0, hy0 = b.head
        fh = (b.sx - 34 - 8 * a, b.S + 70 - 20 * a)
        b.arm(False, fh, "troll2", "troll2", r=8)
        b.legs("troll2", "troll2", far=True)
        b.legs("troll", "troll2", far=False)
        b.torso("troll", s=3.4, flare=4)
        hx, hy = b.hip
        e.sh(smooth([(hx - 20, hy - 4), (hx + 22, hy - 6), (hx + 18, hy + 16), (hx, hy + 22), (hx - 18, hy + 14)], t=0.4), "loin", s=1.6)
        e.sh(ell(b.sx + 4, b.S + 34, b.sw * 0.6, 20), "trollbelly", s=1.2, lw=1.0)
        rnd = random.Random(4)
        e.sh(" ".join(ell(b.sx - 14 + rnd.uniform(0, 34), b.S + 6 + rnd.uniform(0, 50), rnd.uniform(1.8, 3)) for _ in range(9)), "troll2", s=0.4, lw=0.9)
        hx, hy = b.head
        b.head_shape("troll", rx=15, ry=14)
        e.sh(smooth([(hx - 10, hy - 2), (hx - 26, hy + 2), (hx - 24, hy + 8), (hx - 10, hy + 8)], t=0.4), "troll", s=0.6, lw=1.0)   # long nose
        e.sh(poly([(hx + 10, hy - 6), (hx + 26, hy - 14), (hx + 14, hy - 1)]), "troll2", s=0.6)  # ear
        e.ln(f"M{hx-16:.1f},{hy+11:.1f} q6,3 12,0", INK, 1.0)
        e.ln(f"M{hx-14:.1f},{hy+11:.1f} l-1,-4 M{hx-7:.1f},{hy+12:.1f} l0,-4", "#f2ead2", 1.4)
        e.eye(hx - 8, hy - 4, "#d8c040", "#fff4a0", r=1.6, g=4, gop=0.5)
        e.sh(smooth([(hx - 14, hy - 12), (hx - 2, hy - 18), (hx + 12, hy - 14), (hx + 4, hy - 10)], t=0.4), "troll2", s=0.6, lw=1.0)  # brow tuft
        # near arm: a club of bog oak
        nh = (b.sx - 14, b.S - 6) if a else (b.sx + b.sw + 8, b.S + 64)
        b.arm(True, nh, "troll", "troll2", r=9)
        ang = 205 if a else 250
        c_, s_ = math.cos(math.radians(ang)), math.sin(math.radians(ang))
        top = (nh[0] + c_ * 52, nh[1] + s_ * 52)
        e.sh(capsule((nh[0] - c_ * 8, nh[1] - s_ * 8), top, 4, 9), "wood", s=1.2)
        e.det(f"M{top[0]:.1f},{top[1]:.1f} l4,5 M{L(nh[0], top[0], 0.6):.1f},{L(nh[1], top[1], 0.6):.1f} l-5,3", 0.8)
        hx0 += hy0 * 0

    def wyvern(e):
        a = e.a
        dx = -10 * a
        y0 = FY
        bx, by = CX + 10 + dx * 0.5, y0 - 58 + 6 * a
        # far wing (raised behind)
        wing_up = -14 * a
        far_w = [(bx + 6, by - 20), (bx + 30, by - 92 + wing_up), (bx + 62, by - 104 + wing_up), (bx + 76, by - 62)]
        far_w += [(bx + 64, by - 52), (bx + 62, by - 40), (bx + 48, by - 34), (bx + 40, by - 22), (bx + 22, by - 14)]
        e.sh(smooth(far_w, t=0.2), "wing", s=2)
        e.det(f"M{bx+30:.1f},{by-92+wing_up:.1f} L{bx+40:.1f},{by-30:.1f} M{bx+62:.1f},{by-104+wing_up:.1f} L{bx+56:.1f},{by-40:.1f}", 0.8)
        # tail curling behind with a barbed sting
        tail = [(bx + 30, by + 4), (bx + 66, by + 6), (bx + 90, by - 6), (bx + 100, by - 30), (bx + 92, by - 34), (bx + 84, by - 14), (bx + 62, by + 18), (bx + 26, by + 18)]
        e.sh(smooth(tail, t=0.45), "wyv2", s=1.6)
        e.sh(poly([(bx + 92, by - 32), (bx + 104, by - 48), (bx + 100, by - 28)]), "bone", s=0.5)
        # legs
        e.limb([(bx + 14, by + 10), (bx + 24 + 6 * a, y0 - 22), (bx + 16 + 6 * a, y0 - 6)], 8, 4.5, "wyv2")
        e.limb([(bx - 6, by + 12), (bx - 14 - 8 * a, y0 - 22), (bx - 10 - 10 * a, y0 - 4)], 9, 5, "wyv")
        for fx, fy in [(bx + 16 + 6 * a, y0 - 4), (bx - 10 - 10 * a, y0 - 2)]:
            e.ln(f"M{fx:.1f},{fy:.1f} l-7,3 M{fx:.1f},{fy:.1f} l-2,4 M{fx:.1f},{fy:.1f} l5,3", INK, 2.0)
        # body
        e.sh(smooth([(bx - 26, by - 6), (bx - 6, by - 22), (bx + 24, by - 18), (bx + 36, by + 4), (bx + 22, by + 22), (bx - 8, by + 24), (bx - 26, by + 10)], t=0.42), "wyv", s=3)
        e.sh(smooth([(bx - 20, by + 8), (bx + 8, by + 20), (bx + 26, by + 14), (bx + 6, by + 24), (bx - 18, by + 16)], t=0.4), "wyvbelly", s=0.8, lw=0.9)
        e.det(" ".join(f"M{bx-16+i*9:.1f},{by-14+abs(i-2)*2:.1f} q4,4 8,0" for i in range(5)), 0.7, 0.75)
        # neck + head (lunging forward-down in the attack)
        hx, hy = bx - 46 - 10 * a, by - 50 + 26 * a
        e.sh(capsule((bx - 18, by - 8), (hx + 10, hy + 6), 11, 7), "wyv", s=1.6)
        e.sh(smooth([(hx + 14, hy - 6), (hx, hy - 10), (hx - 20, hy - 4), (hx - 30, hy + 2), (hx - 28, hy + 8), (hx - 12, hy + 10), (hx + 10, hy + 10)], t=0.4), "wyv", s=2)
        e.sh(poly([(hx + 4, hy - 8), (hx + 22, hy - 20), (hx + 12, hy - 4)]), "bone", s=0.5)   # horn
        if a:
            e.fl(poly([(hx - 28, hy + 6), (hx - 10, hy + 9), (hx - 26, hy + 16)]), "#5a1610")
            e.ln(f"M{hx-24:.1f},{hy+7:.1f} l1,3 M{hx-18:.1f},{hy+8:.1f} l1,3", "#f2ead2", 1.2)
        e.eye(hx - 12, hy - 2, EMBER, EMBER_HOT, r=1.6, g=5, gop=0.6)
        # near wing: folded along the body, membrane hanging
        near_w = [(bx - 4, by - 18), (bx + 8, by - 60 + wing_up * 0.6), (bx + 34, by - 70 + wing_up * 0.6), (bx + 34, by - 52), (bx + 26, by - 40), (bx + 26, by - 26), (bx + 18, by - 10)]
        e.sh(smooth(near_w, t=0.2), "wing", s=2.2)
        e.sh(capsule((bx - 4, by - 18), (bx + 8, by - 60 + wing_up * 0.6), 3.4, 2.2), "wyv2", s=0.6)
        e.det(f"M{bx+8:.1f},{by-60+wing_up*0.6:.1f} L{bx+18:.1f},{by-10:.1f}", 0.8)

    ME.PAINTERS.update(bear=bear, troll=troll, wyvern=wyvern)
    ME.STYLE.update(bear=("beast", 1.2), troll=("bog", 1.1), wyvern=("crypt", 1.05))
    return ME


def enemies(only=None):
    ME = _enemy_mod()
    ids = [i for i in ("bear", "troll", "wyvern") if not only or i in only]
    if not ids:
        return
    render(ME.jobs_for(ids), workers=3)
    for eid in ids:
        ME.compose(eid)
        errs, g = ME.check(eid)
        print(f"  {eid:8s}", "OK" if not errs else "!! " + "; ".join(errs))


# ================================================================== review
def contact():
    from PIL import Image, ImageDraw
    sheet = Image.new("RGBA", (1100, 900), (220, 199, 154, 255))
    d = ImageDraw.Draw(sheet)
    for i, ic in enumerate(ICONS):
        p = artlib.tpath(os.path.join(SPR, "icons", ic + ".png"))
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA").resize((96, 96), Image.LANCZOS)
            sheet.alpha_composite(im, (10 + i * 98, 10))
    y = 120
    water = (70, 100, 110, 255)
    for pid in ("ship_spice", "ship_barge", "ship_whaler"):
        p = artlib.tpath(os.path.join(SPR, "props", pid + ".png"))
        if os.path.exists(p):
            bg = Image.new("RGBA", (512, 192), water)
            bg.alpha_composite(Image.open(p).convert("RGBA"))
            sheet.alpha_composite(bg, (10, y))
            d.text((530, y + 4), pid, fill=(32, 20, 12))
        y += 200
    p = artlib.tpath(os.path.join(SPR, "props", "ship_flag.png"))
    if os.path.exists(p):
        sheet.alpha_composite(Image.open(p).convert("RGBA"), (560, 130))
    x = 620
    for eid in ("bear", "troll", "wyvern"):
        p = artlib.tpath(os.path.join(SPR, "enemies", eid + ".png"))
        if os.path.exists(p):
            sheet.alpha_composite(Image.open(p).convert("RGBA"), (620, 330 + (["bear", "troll", "wyvern"].index(eid)) * 140))
    for j, cid in enumerate(("herbalist", "harbourmaster")):
        p = artlib.tpath(os.path.join(SPR, "portraits", cid + ".png"))
        if os.path.exists(p):
            sheet.alpha_composite(Image.open(p).convert("RGBA").resize((160, 160)), (900, 120 + j * 170))
        p = artlib.tpath(os.path.join(SPR, "chars", cid + ".png"))
        if os.path.exists(p):
            sheet.alpha_composite(Image.open(p).convert("RGBA").crop((0, 0, 128, 128)), (900, 470 + j * 140))
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, "trade_contact.png")
    sheet.convert("RGB").save(out)
    print(out)


if __name__ == "__main__":
    groups = [a for a in sys.argv[1:] if not a.startswith("--")] or ["icons", "ships", "enemies"]
    only = artlib.only_filter()
    if "--contact" not in sys.argv:
        js = []
        if "icons" in groups:
            js += icon_jobs(only)
        if "ships" in groups:
            js += prop_jobs(only)
        if js:
            render(js)
        if "enemies" in groups:
            enemies(only)
    contact()
