"""Tabletop-miniature character sheets for "Ember & Ash" (replaces the top-down sheets of make_characters.py).

    python3 game/tools/art/make_minis.py                 # every character in data/characters.json + the animals
    python3 game/tools/art/make_minis.py --only=player,borin,animal_cat_1
    python3 game/tools/art/make_minis.py --contact       # only rebuild the review sheets from existing PNGs

Sheets: assets/sprites/chars/<id>.png, 768x512 RGBA, 6x4 cells of 128x128.
  rows 0 south (front), 1 east (side, facing right), 2 north (back), 3 west (mirrored east)
  cols 0-1 idle (breathing / tail flick), 2-5 walk (restrained step + small hop).
The base is drawn identically in every cell: centre x=64, top-face centre y=96.5 (cell px), ~60x19 px for
people, ~40x14 px for animals. Figures never rotate.  Portraits are not touched (see make_characters.py).
Review: tools/art/out/minis_contact.png, minis_scene.png (1.1x on floor textures), minis_strips/<id>.png.
The old top-down painter stays available via make_characters.py.
"""
import json
import os
import sys

import artlib
from artlib import render, ink_filter, svg_doc, SPR, OUT, DATA
import miniature as M

CELL = 128
COLS, ROWS = 6, 4
VIEWS = ["S", "E", "N", "W"]
OUT_CHARS = os.path.join(SPR, "chars")


def kind_of(c):
    if c["id"] == "player":
        return "player"
    return c.get("kind", "villager")


def sheet_svg(cid, look=None, kind="villager", animal=None):
    if animal:
        pal = M.animal_palette(animal)
    else:
        look = dict(look)
        look["_id"] = cid
        pal = M.palette(look)
    lw = 0.72 / (M.ANIMAL_K if animal else 1.0)
    P = M.painter(pal, lw_mul=lw)
    PM = M.painter(pal, mirror=True, lw_mul=lw)
    # base (identical in every cell): people rx 60 / animals rx 40 design units (= 60 / 40 px wide)
    if animal:
        shadow, base = M.base(P, "animal", rx=40, ry=11, rim=6, seed=3)
    else:
        shadow, base = M.base(P, kind, rx=60, ry=15, rim=8, seed=hash(cid) % 97 if False else 5)
    ff = ink_filter(P, wob=1.3, dil=1.1, grain=0.55, soot=0.55, seed=7)
    body = []
    for r, view in enumerate(VIEWS):
        for c, fr in enumerate(M.FRAMES):
            x0, y0 = c * CELL, r * CELL
            if animal:
                fig = M.animal(PM if view == "W" else P, animal, "E" if view == "W" else view, fr)
            else:
                fig = M.figure(PM if view == "W" else P, look, "E" if view == "W" else view, fr)
            if animal:
                k = M.ANIMAL_K
                fig = f'<g transform="translate({M.CX},{M.FY}) scale({k}) translate({-M.CX},{-M.FY})">{fig}</g>'
            if view == "W":
                fig = f'<g transform="translate(256,0) scale(-1,1)">{fig}</g>'
            body.append(f'<g transform="translate({x0},{y0}) scale(0.5)"><g {ff}>{fig}</g></g>')
    P.defs.extend(PM.defs)
    W, H = COLS * CELL, ROWS * CELL
    figs = svg_doc(W, H, P, "".join(body), ss=2)
    # the base is rendered once and composited under every cell, so it is pixel-identical in all 24 frames
    PB = M.painter(pal)
    if animal:
        shadow, base = M.base(PB, "animal", rx=40, ry=11, rim=6, seed=3)
    else:
        shadow, base = M.base(PB, kind, rx=60, ry=15, rim=8, seed=5)
    fb = ink_filter(PB, wob=1.0, dil=0.9, grain=0.5, soot=0.4, seed=4)
    bsvg = svg_doc(CELL, CELL, PB, f'<g transform="scale(0.5)"><g>{shadow}</g><g {fb}>{base}</g></g>', ss=2)
    return figs, bsvg


TMP = os.path.join(OUT, "minis_tmp")


def jobs_for(todo):
    js = []
    for cid, look, kind, animal in todo:
        figs, bsvg = sheet_svg(cid, look, kind, animal)
        js.append(dict(name=f"mini_{cid}", svg=figs, w=COLS * CELL, h=ROWS * CELL, ss=2, out=os.path.join(TMP, cid + "_fig.png")))
        js.append(dict(name=f"mini_{cid}_base", svg=bsvg, w=CELL, h=CELL, ss=2, out=os.path.join(TMP, cid + "_base.png")))
    return js


def compose(cid):
    from PIL import Image
    figs = Image.open(os.path.join(TMP, cid + "_fig.png")).convert("RGBA")
    b = Image.open(os.path.join(TMP, cid + "_base.png")).convert("RGBA")
    out = Image.new("RGBA", (COLS * CELL, ROWS * CELL))
    for r in range(ROWS):
        for c in range(COLS):
            out.paste(b, (c * CELL, r * CELL))
    out.alpha_composite(figs)
    out.save(os.path.join(OUT_CHARS, cid + ".png"), optimize=True)


# ------------------------------------------------------------------ checks
def check(path):
    """768x512 RGBA, and the base pixels (bottom band under the feet) identical in all 24 cells."""
    from PIL import Image
    import numpy as np
    im = Image.open(path)
    errs = []
    if im.size != (768, 512) or im.mode != "RGBA":
        errs.append(f"size/mode {im.size} {im.mode}")
    a = np.asarray(im.convert("RGBA")).astype(int)
    # band below the figure's feet: rows 102..127 of each cell hold rim + contact shadow only
    ref = a[102:128, 0:128]
    for r in range(ROWS):
        for c in range(COLS):
            cell = a[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL]
            d = np.abs(cell[102:128] - ref).max()
            if d > 0:
                errs.append(f"base band differs r{r}c{c} ({d})")
            al = cell[..., 3]
            ys, xs = np.nonzero(al > 24)
            if len(xs) and (xs.min() < 2 or xs.max() > CELL - 3 or ys.min() < 2):
                errs.append(f"touches cell edge r{r}c{c} x[{xs.min()},{xs.max()}] y{ys.min()}")
    # base geometry from the first cell's alpha below y=100
    al = a[88:128, 0:128, 3]
    ys, xs = np.nonzero(al > 128)
    geom = (int(xs.min()), int(xs.max()), int(ys.min()) + 88, int(ys.max()) + 88) if len(xs) else None
    return errs, geom


# ------------------------------------------------------------------ review sheets
def contact(ids):
    from PIL import Image, ImageDraw
    from contact import font
    fnt = font(12)
    cw, ch = 4 * 128 + 20, 128 + 22
    cols = 3
    rows = (len(ids) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw + 10, rows * ch + 10), (220, 199, 154, 255))
    d = ImageDraw.Draw(sheet)
    for i, cid in enumerate(ids):
        p = os.path.join(OUT_CHARS, cid + ".png")
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        x0, y0 = 10 + (i % cols) * cw, 6 + (i // cols) * ch
        for r in range(4):
            sheet.alpha_composite(im.crop((0, r * 128, 128, (r + 1) * 128)), (x0 + r * 128, y0 + 14))
        d.text((x0 + 2, y0), cid, fill=(32, 20, 12), font=fnt)
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, "minis_contact.png")
    sheet.convert("RGB").save(out)
    print(out, sheet.size)
    # full animation strips for a few ids (all 24 cells at 1x)
    sd = os.path.join(OUT, "minis_strips")
    os.makedirs(sd, exist_ok=True)
    for cid in ids:
        p = os.path.join(OUT_CHARS, cid + ".png")
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA")
            bg = Image.new("RGBA", im.size, (220, 199, 154, 255))
            bg.alpha_composite(im)
            bg.convert("RGB").save(os.path.join(sd, cid + ".png"))


def scene(ids):
    """Figures at 1.1x on the game's floor textures, to judge integration."""
    from PIL import Image
    tex = [os.path.join(SPR, "textures", t + ".png") for t in ("grass", "cobble", "floor_wood", "floor_stone")]
    W, H = 1280, 4 * 200
    out = Image.new("RGBA", (W, H))
    for b, tp in enumerate(tex):
        t = Image.open(tp).convert("RGBA")
        for x in range(0, W, t.width):
            for y in range(b * 200, (b + 1) * 200, t.height):
                out.alpha_composite(t.crop((0, 0, t.width, min(t.height, (b + 1) * 200 - y))), (x, y))
    k = 1.1
    for i, cid in enumerate(ids):
        p = os.path.join(OUT_CHARS, cid + ".png")
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        band = i % 4
        col = i // 4
        r = [0, 1, 3, 2][(i // 2) % 4]
        cell = im.crop((0, r * 128, 128, (r + 1) * 128)).resize((round(128 * k), round(128 * k)), Image.LANCZOS)
        x = 10 + col * 150
        if x + cell.width > W:
            continue
        out.alpha_composite(cell, (x, band * 200 + 30))
    p = os.path.join(OUT, "minis_scene.png")
    out.convert("RGB").save(p)
    print(p)


def all_targets():
    chars = json.load(open(os.path.join(DATA, "characters.json")))
    t = [(c["id"], c["look"], kind_of(c), None) for c in chars]
    t += [(aid, None, "animal", spec) for aid, spec in M.ANIMALS.items()]
    return t


def main():
    only = artlib.only_filter()
    targets = all_targets()
    todo = [t for t in targets if not only or t[0] in only]
    ids = [t[0] for t in targets]
    if "--contact" not in sys.argv:
        render(jobs_for(todo), workers=4)
        for t in todo:
            compose(t[0])
        bad = 0
        for t in todo:
            errs, geom = check(os.path.join(OUT_CHARS, t[0] + ".png"))
            print(f"  {t[0]:14s} base bbox x{geom[0]}-{geom[1]} y{geom[2]}-{geom[3]}" + ("" if not errs else "  !! " + "; ".join(errs[:4])))
            bad += bool(errs)
        print("check:", "OK" if not bad else f"{bad} sheet(s) with issues")
    contact(ids)
    scene(ids)


if __name__ == "__main__":
    main()
