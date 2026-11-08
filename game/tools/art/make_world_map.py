"""The parchment world map of the land around Brindlewick, its site icons and the new foes' miniatures
(iteration 011, world worker). Ink & Parchment / Gothic Noir 80:20, built on the regional map kit (make_maps.py).

    python3 make_world_map.py              # everything
    python3 make_world_map.py --only=map   # map | icons | enemies

Output (all template_ sprites):
    ui/maps/template_world_map.png     1600x1000 terrain: forests, mountains, the river, the marsh, the barrows,
                                       the four old roads and Brindlewick. No site landmarks and no text: the
                                       game draws discovered sites (icons below), fog over unknown places,
                                       party markers, seals and names on top.
    ui/world/template_site_<type>.png  160x140 site vignettes: forest, mine, road, barrow, deep, stronghold, temple, crag
    ui/world/template_village.png      Brindlewick's vignette
    ui/world/template_fog.png          a fog bank for unknown places
    ui/world/template_seal.png         a red wax seal (a notable recent event)
    ui/world/template_cleared.png      a gilt laurel (a cleared site)
    ui/world/template_party.png        a party pennant
    enemies/template_<id>.png          the new foes, re-inked from existing miniatures (tinted, scaled)
"""
import json
import math
import os
import random
import sys

import artlib
from artlib import (render, ink_filter, soft_filter, svg_doc, glow, lin, fill, ell, rect, poly, smooth, blob, blur_filter, SPR, DATA,
                    INK, EMBER, EMBER_HOT, RUB, GILT, PARCH, FROST, VIOLET_HOT)
import make_maps as MM
from make_maps import Map, J

WW, WH = 1600, 1000
OUT_UI = os.path.join(SPR, "ui")
VILLAGE = (800, 520)


def sites():
    with open(os.path.join(DATA, "expeditions.json")) as f:
        return json.load(f)["sites"]


# ====================================================================== the world map
def village(M, x, y, s=1.0):
    """Brindlewick from above-ish: a cluster of roofs round a green, the inn's sign, the forge's glow."""
    P = M.P
    o = [MM.shadow_ell(M, x + 4, y + 10, 70 * s, 14 * s)]
    o.append(fill(blob(x, y, 62 * s, 8, 0.1, 3, squash=0.62), "#c8b884", 0.85) + lin(blob(x, y, 62 * s, 8, 0.1, 3, squash=0.62), INK, 1.0, 0.5))
    rnd = random.Random(7)
    houses = [(-40, -10, 1.0), (-22, -26, 0.9), (2, -32, 1.1), (26, -24, 0.95), (42, -4, 1.0), (-30, 14, 0.9), (30, 18, 1.0), (4, 24, 0.85), (-6, -6, 1.2)]
    for (dx, dy, k) in sorted(houses, key=lambda h: h[1]):
        hx, hy = x + dx * s, y + dy * s
        w, h = 18 * s * k, 11 * s * k
        o.append(P.shape(rect(hx - w / 2, hy - h, w, h, 1), "clay" if rnd.random() < 0.5 else "wood", s=1.2, lw=1.6))
        o.append(P.shape(poly([(hx - w / 2 - 2 * s, hy - h), (hx, hy - h - 10 * s * k), (hx + w / 2 + 2 * s, hy - h)]), rnd.choice(["roof_a", "roof_b", "straw"]), s=1.2, lw=1.6))
        o.append(fill(rect(hx - 2 * s, hy - 6 * s * k, 4 * s, 6 * s * k), "#1a120c"))
    # the chapel spire and the forge chimney
    o.append(P.shape(rect(x + 52 * s, y - 40 * s, 10 * s, 30 * s, 1), "stone", s=1.5, lw=1.6))
    o.append(P.shape(poly([(x + 50 * s, y - 40 * s), (x + 57 * s, y - 60 * s), (x + 64 * s, y - 40 * s)]), "slate", s=1, lw=1.6))
    o.append(P.shape(rect(x - 10 * s, y - 32 * s, 5 * s, 16 * s, 0.5), "stone", s=0.6, lw=1.4))
    M.emit.append(glow(P, x - 6 * s, y - 14 * s, 18 * s, EMBER, 0.6))
    M.emit.append(fill(ell(x - 7.5 * s, y - 36 * s, 3 * s, 2 * s), "#6a6058", 0.5))
    return J(o)


def world_map():
    S = sites()
    nodes = [{"id": sid, "x": s["pos"][0], "y": s["pos"][1], "links": [], "kind": "site"} for sid, s in S.items()]
    nodes.append({"id": "village", "x": VILLAGE[0], "y": VILLAGE[1], "links": [], "kind": "village"})
    MM.W, MM.H = WW, WH          # the map kit works on module-level canvas size
    M = Map("world_map", {"nodes": nodes}, seed=411)
    M.patch_cols = ["#b89a68", "#a8a874", "#c8ae80", "#a8b078"]
    N = M.nodes
    V = VILLAGE
    # ---- the river: from the northern mountains past the village to the south-east
    rv = [(1020, -20), (985, 160), (1030, 330), (990, 470), (1040, 640), (980, 820), (1030, 1020)]
    M.ground.append(MM.river(M, rv, 24))
    M.corr.append((rv, 18))
    # ---- the four old roads from Brindlewick (the game inks tracks to places found later)
    roads = {
        "whisperwood": [V, (680, 500), (560, 480), (N["whisperwood"]["x"] + 40, N["whisperwood"]["y"] + 10)],
        "ironroot_mine": [V, (790, 430), (760, 360), (N["ironroot_mine"]["x"], N["ironroot_mine"]["y"] + 40)],
        "highmarsh_road": [V, (900, 520), (1010, 505), (1110, 495), (N["highmarsh_road"]["x"] - 40, N["highmarsh_road"]["y"])],
        "barrow_fields": [V, (810, 620), (840, 720), (N["barrow_fields"]["x"], N["barrow_fields"]["y"] - 40)],
    }
    for k, pts in roads.items():
        M.ground.append(MM.road(M, pts, 13))
        M.corr.append((pts, 12))
    # the eastern road runs on, off the map, to Highmarsh
    east = [(N["highmarsh_road"]["x"] + 40, N["highmarsh_road"]["y"]), (1350, 520), (1500, 560), (1640, 580)]
    M.ground.append(MM.road(M, east, 13))
    M.corr.append((east, 12))
    M.ground.append(MM.bridge(M, 1012, 504, 64, -6, 20))
    # ---- mountains: a hachured range across the north, higher in the north-west (the crag) and north-east
    for k, pts in enumerate([[(60, 300), (180, 230), (300, 280), (420, 220), (540, 270), (640, 210)],
                             [(80, 120), (200, 70), (330, 110), (460, 60), (600, 100), (700, 60)],
                             [(860, 120), (960, 60), (1100, 110), (1220, 70), (1360, 120), (1500, 80)],
                             [(1180, 360), (1290, 300), (1400, 350), (1520, 300), (1580, 340)],
                             [(660, 330), (740, 290), (850, 320), (930, 280)]]):
        M.ground.append(MM.hachure_ridge(M, pts, depth=34 - k * 3, side=1, w=1.5))
    # ash on the crag
    bf = blur_filter(M.P, 14)
    M.ground.append(fill(blob(N["drakes_crag"]["x"], N["drakes_crag"]["y"] - 10, 120, 7, 0.15, 5, squash=0.6), "#4a4038", 0.3, bf))
    # ---- the south-western marsh
    sw = N["sunken_temple"]
    M.ground.append(fill(blob(sw["x"] + 20, sw["y"] + 10, 260, 9, 0.12, 3, squash=0.55), "#8e9468", 0.42, bf))
    rr = random.Random(5)
    for i in range(18):
        x, y = sw["x"] + rr.uniform(-240, 260), sw["y"] + rr.uniform(-120, 150)
        rx = rr.uniform(18, 46)
        if 30 < y < WH - 40 and M.free(x, y, rx * 0.6, link=8):
            M.ground.append(MM.pool(M, x, y, rx, rx * 0.4, i + 30))
            M.blocks.append((x, y, rx * 0.7))
    M.ground.append(MM.tufts(M, 260, lambda x, y: math.hypot((x - sw["x"]) / 1.4, (y - sw["y"]) / 0.8) < 220, kind="reed", op=0.6))
    # ---- the barrow fields: mounds and grave clusters in the south
    bw = N["barrow_fields"]
    M.scatter(16, MM.mound, 12, 22, area=lambda x, y: math.hypot((x - bw["x"]) / 1.6, y - bw["y"] - 20) < 140, tries=60)
    M.scatter(6, MM.grave_cluster, 12, 16, area=lambda x, y: math.hypot((x - bw["x"]) / 1.6, y - bw["y"] - 20) < 150, tries=80)
    # ---- fields round the village
    fl = []
    for (fx, fy, fw, fh, a) in [(650, 590, 90, 50, -8), (900, 610, 80, 46, 6), (690, 400, 70, 40, 4), (880, 420, 76, 40, -4)]:
        d = rect(fx - fw / 2, fy - fh / 2, fw, fh, 2)
        fl.append(f'<g transform="rotate({a} {fx} {fy})">' + fill(d, "#b4b074", 0.75) + lin(d, INK, 1.2, 0.6) +
                  lin(" ".join(f"M{fx-fw/2+3:.0f},{fy-fh/2+i*6:.0f} h{fw-6:.0f}" for i in range(1, int(fh / 6))), "#6e7040", 1.1, 0.7) + "</g>")
    M.ground.append(J(fl))
    M.blocks.append((V[0], V[1], 120))
    M.mark(V[0], V[1] - 8, village(M, V[0], V[1] - 8, 1.25), 70)
    # ---- forests and woods
    ww = N["whisperwood"]
    M.scatter(520, MM.tree, 11, 17, area=lambda x, y: math.hypot((x - ww["x"]) / 1.5, y - ww["y"]) < 210, tries=30, bk=0.42)
    M.scatter(140, MM.tree2, 10, 15, area=lambda x, y: math.hypot((x - ww["x"]) / 1.6, y - ww["y"]) < 240, tries=30, bk=0.42)
    M.scatter(110, MM.pine, 9, 14, area=lambda x, y: y < 360 and not math.hypot(x - 420, y - 160) < 90, tries=30)
    M.scatter(45, MM.pine, 9, 14, area=lambda x, y: x > 1180 and y < 460, tries=30)
    M.scatter(70, MM.tree, 10, 15, area=lambda x, y: (x > 1080 and y > 600) or (x < 680 and 600 < y < 700), tries=30)
    M.scatter(40, MM.dead_tree, 10, 15, area=lambda x, y: math.hypot((x - sw["x"]) / 1.4, (y - sw["y"]) / 0.8) < 230, tries=40, bk=0.6)
    M.scatter(14, MM.dead_tree, 9, 13, area=lambda x, y: math.hypot((x - bw["x"]) / 1.6, y - bw["y"]) < 170, tries=40, bk=0.6)
    M.scatter(90, MM.rock, 4, 9, area=lambda x, y: y < 380, tries=30)
    M.scatter(60, MM.bush, 5, 8, tries=20)
    M.ground.append(MM.tufts(M, 420, (30, 30, WW - 30, WH - 30), op=0.32))
    svg = M.svg(PARCH)
    MM.W, MM.H = 1280, 720
    return dict(name="world_map", svg=svg, w=WW, h=WH, ss=2, transparent=False, out=os.path.join(OUT_UI, "maps", "world_map.png"))


# ====================================================================== icons
ICONS = {
    "forest": (lambda M, x, y: J([MM.tree(M, x - 34, y - 6, 15, 3), MM.tree(M, x + 36, y - 4, 14, 8), MM.stone_tower(M, x, y, 1.0),
                                  MM.tree(M, x - 22, y + 10, 13, 5), MM.tree(M, x + 24, y + 12, 14, 9)]), 1.0),
    "mine": (lambda M, x, y: J([MM.spoil_heap(M, x + 34, y - 2, 13, 4), MM.quarry_mouth(M, x - 6, y, 1.0), MM.headframe(M, x + 30, y - 14, 0.75)]), 1.0),
    "road": (lambda M, x, y: J([MM.fort(M, x, y, 0.95)]), 1.0),
    "barrow": (lambda M, x, y: MM.wight_barrow(M, x, y, 0.75), 1.0),
    "deep": (lambda M, x, y: J([MM.deep_stair(M, x - 4, y, 1.0), MM.crystal_small(M, x + 34, y + 2, 12, 5, "ice", FROST)]), 1.0),
    "stronghold": (lambda M, x, y: MM.maud_keep(M, x, y + 2, 0.85), 1.0),
    "temple": (lambda M, x, y: MM.sanctum(M, x, y, 0.95), 1.0),
    "crag": (lambda M, x, y: J([MM.drake_lair(M, x, y + 4, 0.8)]), 1.0),
}


def icon_job(name, fn, w=160, h=140, wob=1.1):
    MM.W, MM.H = w, h
    M = Map("icon_" + name, {"nodes": [{"id": "x", "x": -999, "y": -999, "links": [], "kind": "x"}]}, seed=3)
    ax, ay = w / 2, h * 0.8
    # the map vignettes are drawn at map scale; an icon shows them larger
    body = f'<g transform="translate({ax},{ay}) scale(1.35) translate({-ax},{-ay})">' + fn(M, ax, ay) + "</g>"
    M.emit = [f'<g transform="translate({ax},{ay}) scale(1.35) translate({-ax},{-ay})">' + J(M.emit) + "</g>"]
    P = M.P
    f = ink_filter(P, wob=wob, dil=0.5, grain=0.5, soot=0.55, seed=9)
    svg = svg_doc(w, h, P, f'<g {f}>{body}</g>' + J(M.emit), ss=2)
    MM.W, MM.H = 1280, 720
    return dict(name="world_icon_" + name, svg=svg, w=w, h=h, ss=2, transparent=True, out=os.path.join(OUT_UI, "world", name + ".png"))


def fog_job():
    P = artlib.painter(1.0, 0.5)
    w, h = 220, 150
    bf = blur_filter(P, 7)
    rnd = random.Random(4)
    o = [fill(blob(w / 2, h / 2, 92, 9, 0.18, 2, squash=0.58), "#e8e0cc", 0.92, bf)]
    for i in range(7):
        x, y = rnd.uniform(50, 170), rnd.uniform(45, 105)
        o.append(fill(blob(x, y, rnd.uniform(26, 40), 7, 0.2, i, squash=0.6), rnd.choice(["#f2ecdc", "#d8ccb0", "#e0d6bc"]), 0.75, bf))
    # inked cloud curls
    curls = " ".join(f"M{x:.0f},{y:.0f} q{r*0.5:.0f},{-r*0.7:.0f} {r:.0f},0 q{r*0.4:.0f},{-r*0.5:.0f} {r*0.8:.0f},0"
                     for x, y, r in [(40, 70, 26), (90, 52, 30), (120, 96, 24), (60, 104, 20), (140, 66, 22)])
    o.append(lin(curls, INK, 1.4, 0.55))
    svg = svg_doc(w, h, P, f'<g {soft_filter(P, 1.2)}>' + J(o) + "</g>", ss=2)
    return dict(name="world_fog", svg=svg, w=w, h=h, ss=2, transparent=True, out=os.path.join(OUT_UI, "world", "fog.png"))


def seal_job():
    P = artlib.painter(1.0, 0.5)
    w = h = 64
    cx, cy = 32, 32
    rim = smooth([(cx + math.cos(a) * (24 + 3 * math.sin(a * 5)), cy + math.sin(a) * (24 + 3 * math.cos(a * 4))) for a in [i * math.tau / 18 for i in range(18)]], close=True, t=0.35)
    o = [fill(ell(cx + 2, cy + 3, 24), "#000000", 0.25), fill(rim, "#8e2018") + lin(rim, "#4a0e0a", 1.6)]
    o.append(fill(ell(cx, cy, 15), "#a8281e") + lin(ell(cx, cy, 15), "#5a1410", 1.2))
    # an anvil-and-flame stamp
    o.append(fill(f"M{cx-9},{cy+2} h18 l-4,4 h-3 l1,4 h3 v2 h-11 v-2 h3 l1,-4 h-3 Z", "#5a1410"))
    o.append(fill(f"M{cx},{cy-11} q5,5 2,10 q-2,-3 -4,0 q-3,-5 2,-10 Z", "#5a1410"))
    o.append(lin(f"M{cx-12},{cy-8} q6,-6 14,-6", "#e8a088", 1.4, 0.6))
    svg = svg_doc(w, h, P, f'<g {soft_filter(P, 0.6)}>' + J(o) + "</g>", ss=2)
    return dict(name="world_seal", svg=svg, w=w, h=h, ss=2, transparent=True, out=os.path.join(OUT_UI, "world", "seal.png"))


def cleared_job():
    P = artlib.painter(1.0, 0.5)
    w = h = 64
    cx, cy = 32, 34
    o = []
    leaves = []
    for side in (-1, 1):
        for i in range(6):
            a = math.pi / 2 + side * (0.35 + i * 0.36)
            x, y = cx + math.cos(a) * 21, cy + math.sin(a) * 21
            leaves.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="5" ry="2.4" transform="rotate({math.degrees(a) + side * 60:.0f} {x:.1f} {y:.1f})"/>')
    o.append(f'<g fill="{GILT}" stroke="{INK}" stroke-width="1">' + "".join(leaves) + "</g>")
    o.append(lin(f"M{cx-6},{cy+21} q6,3 12,0", INK, 1.6))
    o.append(lin(f"M{cx-9},{cy} l6,7 l12,-14", INK, 5.0) + lin(f"M{cx-9},{cy} l6,7 l12,-14", GILT, 2.6))
    svg = svg_doc(w, h, P, f'<g {soft_filter(P, 0.6)}>' + J(o) + "</g>", ss=2)
    return dict(name="world_cleared", svg=svg, w=w, h=h, ss=2, transparent=True, out=os.path.join(OUT_UI, "world", "cleared.png"))


def party_job():
    P = artlib.painter(1.0, 0.5)
    w, h = 48, 72
    o = [fill(ell(24, 66, 12, 4), "#000000", 0.3)]
    o.append(P.shape(ell(24, 64, 10, 4), "darkiron", s=0.8, lw=1.6))
    o.append(lin("M18,64 V10", "#3e2a18", 3.2) + lin("M18,64 V10", "#7a5636", 1.6))
    flag = "M19,11 h22 l-6,8 l6,8 h-22 Z"
    o.append(fill(flag, RUB) + lin(flag, INK, 1.4))
    o.append(fill("M24,15 l3,4 l-3,4 l-3,-4 Z", GILT))
    o.append(fill(ell(18, 9, 3), GILT) + lin(ell(18, 9, 3), INK, 1))
    svg = svg_doc(w, h, P, f'<g {soft_filter(P, 0.6)}>' + J(o) + "</g>", ss=2)
    return dict(name="world_party", svg=svg, w=w, h=h, ss=2, transparent=True, out=os.path.join(OUT_UI, "world", "party.png"))


def icon_jobs():
    js = [icon_job(k, fn) for k, (fn, _) in ICONS.items()]
    js.append(icon_job("village", lambda M, x, y: village(M, x, y - 10, 0.85), w=200, h=150))
    js += [fog_job(), seal_job(), cleared_job(), party_job()]
    return js


# ====================================================================== the new foes (re-inked miniatures)
# id: (source miniature, tint colour, tint strength, figure scale, boss sheet)
ENEMY_FROM = {
    "bandit_archer": ("bandit", "#4a5a3a", 0.30, 1.0, False),
    "war_hound": ("wolf", "#5a2e1e", 0.38, 1.0, False),
    "black_maud": ("bandit_captain", "#1e1a22", 0.45, 1.0, True),
    "drowned": ("skeleton", "#3e6a5e", 0.42, 1.0, False),
    "temple_serpent": ("wyvern", "#2e5a4e", 0.50, 1.0, False),
    "drowned_oracle": ("bog_wraith", "#2e6a6a", 0.45, 1.0, True),
    "harpy": ("wyvern", "#6a5a4a", 0.45, 0.85, False),
    "drakeling": ("wyvern", "#7a2a14", 0.40, 0.9, False),
    "cinderjaw": ("wyvern", "#8a1e0c", 0.45, 1.0, True),
    "young_alpha": ("wolf_alpha", "#9a9082", 0.30, 0.92, True),
    "brood_daughter": ("brood_mother", "#5a3a5a", 0.35, 0.92, True),
    "toll_sergeant": ("bandit_captain", "#6a5034", 0.35, 0.92, True),
    "wight_steward": ("wight", "#3a4a6a", 0.40, 1.0, True),
    "hollow_warden": ("golem", "#4a3a2a", 0.40, 0.95, True),
    "corvin": ("bandit_captain", "#2a2a3a", 0.50, 0.92, True),
    "oracle_echo": ("bog_wraith", "#4a8a8a", 0.40, 0.95, True),
    "smoulderwing": ("wyvern", "#9a3a14", 0.40, 1.0, True),
}


def enemies():
    from PIL import Image, ImageOps
    src_dir = os.path.join(SPR, "enemies")
    n = 0
    for eid, (src, col, k, scale, boss) in ENEMY_FROM.items():
        p = os.path.join(src_dir, "template_" + src + ".png")
        im = Image.open(p).convert("RGBA")
        cell_in = im.height
        cell = 192 if boss else 128
        out = Image.new("RGBA", (cell * 2, cell))
        tint = Image.new("RGBA", (cell_in, cell_in), col)
        for f in (0, 1):
            fr = im.crop((f * cell_in, 0, (f + 1) * cell_in, cell_in))
            # tint the figure toward the colour; the dark ink lines stay dark (multiply)
            from PIL import ImageChops
            rgb = fr.convert("RGB")
            # re-hue toward the colour (saturation kept, value kept: ink stays ink), then a light multiply
            th, ts, tv = Image.new("RGB", (1, 1), col).convert("HSV").getpixel((0, 0))
            h_, s_, v_ = rgb.convert("HSV").split()
            s2 = s_.point(lambda p: min(255, int(p * 0.7 + ts * 0.45)))
            hued = Image.merge("HSV", (Image.new("L", fr.size, th), s2, v_)).convert("RGB")
            light = Image.blend(Image.new("RGB", fr.size, col), Image.new("RGB", fr.size, "#ffffff"), 0.45)
            mixed = Image.blend(rgb, ImageChops.multiply(hued, light), min(1.0, k * 1.9)).convert("RGBA")
            mixed.putalpha(fr.split()[3])
            sz = int(cell * scale)
            mixed = mixed.resize((sz, sz), Image.LANCZOS)
            ox = f * cell + (cell - sz) // 2
            oy = cell - sz - int((cell - sz) * 0.25)
            out.alpha_composite(mixed, (ox, max(0, oy)))
        os.makedirs(src_dir, exist_ok=True)
        out.save(artlib.tpath(os.path.join(src_dir, eid + ".png")), optimize=True)
        n += 1
    print("enemies:", n)


def contact():
    from PIL import Image
    files = [os.path.join(OUT_UI, "world", f) for f in ["template_site_" + k + ".png" for k in ICONS] +
             ["template_village.png", "template_fog.png", "template_seal.png", "template_cleared.png", "template_party.png"]]
    files += [os.path.join(SPR, "enemies", "template_" + e + ".png") for e in ENEMY_FROM]
    ims = [Image.open(f).convert("RGBA") for f in files if os.path.exists(f)]
    W = 1600
    x = y = rowh = 0
    sheet = Image.new("RGBA", (W, 1400), "#dcc79a")
    for im in ims:
        if x + im.width > W:
            x = 0
            y += rowh + 10
            rowh = 0
        sheet.alpha_composite(im, (x, y))
        x += im.width + 10
        rowh = max(rowh, im.height)
    sheet = sheet.crop((0, 0, W, y + rowh + 10))
    os.makedirs(artlib.OUT, exist_ok=True)
    sheet.convert("RGB").save(os.path.join(artlib.OUT, "world_contact.png"))
    print("contact:", os.path.join(artlib.OUT, "world_contact.png"))


if __name__ == "__main__":
    only = artlib.only_filter() or {"map", "icons", "enemies"}
    js = []
    if "map" in only:
        js.append(world_map())
    if "icons" in only:
        js += icon_jobs()
    for j in js:
        # site icons are named site_<type>; the rest keep their names
        base = os.path.basename(j["out"])
        if j["name"].startswith("world_icon_") and base[:-4] in ICONS:
            j["out"] = os.path.join(os.path.dirname(j["out"]), "site_" + base)
        j["out"] = artlib.tpath(j["out"])
        os.makedirs(os.path.dirname(j["out"]), exist_ok=True)
    if js:
        render(js, workers=4)
    if "enemies" in only:
        enemies()
    contact()
