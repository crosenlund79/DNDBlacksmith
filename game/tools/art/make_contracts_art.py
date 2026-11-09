"""The Living Realm (milestone 5) — major contracts: the Project Bench station, its display base, the crates that
stand beside it (the patron's sealed material crate, the growing stack of finished goods) and the patron's letter.

    python3 game/tools/art/make_contracts_art.py

Output (templates; a user-provided file without the prefix overrides each):
  assets/sprites/stations/template_project_bench.png        128x96  (the station, straight top-down)
  assets/sprites/stations/bases/template_project_bench.png  (its painted tabletop base; anchors.json updated)
  assets/sprites/contracts/template_crate_goods.png         64x56   (open crate, finished blades and shield rims)
  assets/sprites/contracts/template_crate_patron.png        64x56   (closed crate, roped, the patron's wax seal)
  assets/sprites/contracts/template_letter.png              96x80   (a folded letter under a red wax seal)
Review sheet: tools/art/out/contracts_contact.png
"""
import json
import os

from artlib import (painter, sprite_svg, ground_shadow, glow, lin, fill, planks, candle_top, render, rect, poly, smooth,
                    ell, INK, GILT, EMBER, SPR, OUT, DATA)
import make_station_bases as BASES

RUB = "#7e2418"
SH = (5, 6)


def J(o):
    return "\n".join(x for x in o if x)


def _blade(P, x, y, L=40, w=5, ang=0):
    """A finished shortsword lying flat: grip, guard, blade (drawn along +x, rotated by ang)."""
    g = []
    t = f'transform="rotate({ang} {x} {y})"'
    g.append(f'<g {t}>')
    g.append(P.shape(rect(x, y - 1.6, 9, 3.2, 1.2), "brown", s=0.6, lw=1.0))
    g.append(P.shape(rect(x + 8.5, y - w * 0.9, 3, w * 1.8, 1), "darkiron", s=0.5, lw=1.0))
    g.append(P.shape(poly([(x + 11.5, y - w / 2), (x + L - 5, y - w / 2), (x + L, y), (x + L - 5, y + w / 2), (x + 11.5, y + w / 2)]), "metal", s=1, lw=1.1))
    g.append(lin(f"M{x + 12},{y} L{x + L - 4},{y}", "#f4f4f0", 0.5, 0.7))
    g.append('</g>')
    return "".join(g)


def project_bench(P, W, H):
    """A long oak bench: the order pinned to a board at the back under the patron's seal, an open ledger with tally
    marks, three finished blades laid side by side, a round shield rim, a hammer, rivets and a candle."""
    sh, b, e = [], [], []
    sh.append(ground_shadow(P, rect(4, 16, 120, 70, 4), *SH))
    # trestle legs peeking out at the ends
    b.append(P.shape(rect(2, 30, 8, 44, 2), "wood", s=1.5, lw=1.4))
    b.append(P.shape(rect(118, 30, 8, 44, 2), "wood", s=1.5, lw=1.4))
    b.append(planks(P, 6, 18, 116, 64, "wood", n=4, dirn="h", s=3, seed=53))
    # the order board along the back edge, the parchment order and the seal
    b.append(P.shape(rect(30, 2, 68, 18, 2), "brown", s=2, lw=1.5))
    b.append(P.shape(poly([(36, 4), (88, 3.5), (89, 18), (35, 18.5)]), "paper", s=1.2, lw=1.1))
    b.append(lin(" ".join(f"M40,{y} L{84 - (y % 3) * 4},{y}" for y in (7, 10, 13, 16)), INK, 0.6, 0.7))
    b.append(P.shape(ell(86, 15, 4.2), "redp", s=0.8, lw=1.1))
    b.append(fill(ell(86, 15, 1.6), "#5a120a", 0.8))
    b.append(fill(" ".join(ell(x, 4.5, 1.1) for x in (37, 87)), GILT))
    # open ledger with tally marks (left)
    b.append(P.shape(poly([(10, 26), (30, 24), (31, 50), (11, 52)]), "paper", s=1.2, lw=1.2))
    b.append(P.shape(poly([(30, 24), (50, 26), (49, 52), (31, 50)]), "paper", s=1.2, lw=1.2))
    tally = []
    for i, (x0, y0) in enumerate([(14, 30), (14, 38), (34, 30)]):
        for k in range(4):
            tally.append(f"M{x0 + k * 3},{y0} l0,6")
        tally.append(f"M{x0 - 1},{y0 + 5} l12,-4")
    b.append(lin(" ".join(tally), INK, 0.7, 0.85))
    b.append(lin("M34,40 L46,40 M34,44 L44,44", INK, 0.5, 0.6))
    # three finished blades laid side by side (centre), a round shield rim (right)
    for i in range(3):
        b.append(_blade(P, 54, 30 + i * 8, L=42, w=4.5))
    b.append(P.shape(ell(108, 58, 13, 12), "wood", s=1.5, lw=1.3))
    b.append(P.shape(ell(108, 58, 13, 12), "darkiron", s=0.5, lw=1.6, flat=True, fill_override="none"))
    b.append(P.shape(ell(108, 58, 4), "darkiron", s=0.8, lw=1.2))
    # hammer, a little dish of rivets, chalk
    b.append(P.shape(rect(58, 62, 26, 4, 1.4), "wood", s=1, lw=1.3))
    b.append(P.shape(rect(80, 58, 8, 12, 1.4), "darkiron", s=1.5, lw=1.4))
    b.append(P.shape(ell(24, 66, 8, 6), "clay", s=1, lw=1.2))
    b.append(fill(" ".join(ell(24 + dx, 66 + dy, 1.0) for dx, dy in [(-3, -1), (0, 1), (3, -1), (-1, -2), (2, 2)]), "#3a3632"))
    b.append(P.shape(rect(38, 70, 10, 3.5, 1), "paper", s=0.6, lw=0.9))
    # the candle (a warm accent)
    cb, ce = candle_top(P, 112, 28, 3.4)
    b.append(cb)
    e.append(ce)
    e.append(glow(P, 112, 28, 0, EMBER, 0.35, rx=16, ry=12))
    return J(sh), J(b), J(e)


def crate_goods(P, W, H):
    """An open crate: straw, blade hilts and shield rims inside — finished contract work."""
    sh, b, e = [], [], []
    sh.append(ground_shadow(P, rect(4, 6, 56, 46, 3), 4, 5))
    b.append(planks(P, 4, 6, 56, 46, "wood", n=3, dirn="v", s=2.5, seed=71))
    b.append(P.shape(rect(9, 11, 46, 36, 1.5), "straw", s=2, lw=1.2))
    b.append(lin(" ".join(f"M{10 + i * 5},{12 + (i % 3) * 3} l{3 - i % 4},{30 - (i % 5) * 2}" for i in range(9)), "#a88a44", 0.6, 0.6))
    for i in range(3):
        b.append(_blade(P, 12, 18 + i * 9, L=34, w=4))
    b.append(P.shape(ell(46, 36, 8, 7.5), "wood", s=1, lw=1.2))
    b.append(P.shape(ell(46, 36, 8, 7.5), "darkiron", s=0.4, lw=1.3, flat=True, fill_override="none"))
    # corner irons
    b.append(fill(" ".join(rect(x, y, 5, 5, 1) for x, y in [(4, 6), (55, 6), (4, 47), (55, 47)]), "#3a3632", 0.9))
    return J(sh), J(b), J(e)


def crate_patron(P, W, H):
    """A closed crate roped crosswise under the patron's red wax seal — the materials he sent with the order."""
    sh, b, e = [], [], []
    sh.append(ground_shadow(P, rect(4, 6, 56, 46, 3), 4, 5))
    b.append(planks(P, 4, 6, 56, 46, "wood", n=4, dirn="h", s=2.5, seed=73))
    b.append(lin("M4,29 L60,29 M32,6 L32,52", "#c0a26e", 3.2))
    b.append(lin("M4,29 L60,29 M32,6 L32,52", "#6e5634", 0.8, 0.8))
    b.append(P.shape(ell(32, 29, 6), "redp", s=0.8, lw=1.2))
    b.append(fill(ell(32, 29, 2.4), "#5a120a", 0.85))
    b.append(P.shape(poly([(8, 10), (22, 10), (22, 16), (8, 16)]), "paper", s=0.5, lw=0.9))
    b.append(lin("M10,12.5 L20,12.5 M10,14.5 L17,14.5", INK, 0.5, 0.7))
    b.append(fill(" ".join(rect(x, y, 5, 5, 1) for x, y in [(4, 6), (55, 6), (4, 47), (55, 47)]), "#3a3632", 0.9))
    return J(sh), J(b), J(e)


def letter(P, W, H):
    """A folded letter, its flap closed with a red wax seal pressed with a crown-and-hammer."""
    sh, b, e = [], [], []
    body = poly([(8, 14), (88, 10), (90, 68), (10, 72)])
    sh.append(ground_shadow(P, body, 3, 4, op=0.4))
    b.append(P.shape(body, "paper", s=2.5, lw=1.4))
    b.append(P.detail("M8,14 L49,44 L88,10", "paper", 0.5, 0.9))
    b.append(lin("M18,56 L44,55 M18,61 L38,60", INK, 0.6, 0.5))
    b.append(P.shape(smooth([(41, 38), (49, 34), (58, 38), (60, 46), (55, 53), (46, 54), (39, 49)], close=True), "redp", s=1.2, lw=1.3))
    b.append(lin("M44,46 L54,46 M45,46 L46,41 L49,44 L52,41 L53,46", "#5a120a", 0.9, 0.9))
    b.append(lin("M49,47 L49,51", "#5a120a", 1.0, 0.9))
    return J(sh), J(b), J(e)


SPRITES = [
    ("stations", "project_bench", project_bench, 128, 96),
    ("contracts", "crate_goods", crate_goods, 64, 56),
    ("contracts", "crate_patron", crate_patron, 64, 56),
    ("contracts", "letter", letter, 96, 80),
]


def jobs():
    js = []
    for d, name, fn, W, H in SPRITES:
        P = painter(scale=1.0, lw_mul=0.7)
        sh, body, emit = fn(P, W, H)
        svg = sprite_svg(P, W, H, sh, body, emit, ss=3, wob=0.9, dil=0.75, grain=0.45, soot=0.8)
        js.append(dict(name=f"ct_{name}", svg=svg, w=W, h=H, ss=3, out=os.path.join(SPR, d, name + ".png")))
    return js


def base_job():
    st = [s for s in json.load(open(os.path.join(DATA, "stations.json"))) if s["id"] == "project_bench"][0]
    svg, W, H, cx, cy = BASES.base_svg(st)
    return dict(name="base_project_bench", svg=svg, w=W, h=H, ss=2, out=os.path.join(BASES.OUT_DIR, "project_bench.png")), \
        dict(w=W, h=H, cx=round(cx, 1), cy=round(cy, 1))


def contact():
    from PIL import Image
    import artlib
    tiles = []
    for d, name, fn, W, H in SPRITES:
        im = Image.open(artlib.tpath(os.path.join(SPR, d, name + ".png"))).convert("RGBA")
        cell = Image.new("RGBA", (max(W, 140) + 20, H + 120), (150, 132, 104, 255))
        big = im.resize((W * 2, H * 2), Image.NEAREST) if W <= 64 else im
        cell.alpha_composite(big, ((cell.width - big.width) // 2, 10))
        tiles.append(cell)
    sheet = Image.new("RGBA", (sum(t.width for t in tiles), max(t.height for t in tiles)), (60, 48, 36, 255))
    x = 0
    for t in tiles:
        sheet.alpha_composite(t, (x, 0))
        x += t.width
    sheet.save(os.path.join(OUT, "contracts_contact.png"))


if __name__ == "__main__":
    bj, meta = base_job()
    render(jobs() + [bj])
    mp = os.path.join(BASES.OUT_DIR, "anchors.json")
    allm = json.load(open(mp)) if os.path.exists(mp) else {}
    allm["project_bench"] = meta
    json.dump(allm, open(mp, "w"), indent=1)
    contact()
    BASES.contact(json.load(open(os.path.join(DATA, "stations.json"))))
