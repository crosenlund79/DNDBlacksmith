"""Appearance layers for the player's miniature and portrait ("Ember & Ash").

    python3 game/tools/art/make_player_looks.py            # all layers + data/appearance.json + review sheet
    python3 game/tools/art/make_player_looks.py --review   # only rebuild the review sheet from existing PNGs

The default Brannoc keeps his hand-tuned sheet (chars/player) and portrait (portraits/player).  Any other
look is composited in the game (scripts/systems/appearance.gd) from a few layers rendered here:

    base            Brannoc with no hair, no beard, no head extras (pauldron kept)
    hair_<style>    pixels a hair style changes on top of the base   (portrait: also the brows)
    beard_<style>   pixels a beard changes
    x_<extra>       eyepatch, scalp scar, spectacles, headscarf

Each layer is the difference between a render WITH the piece and the base render, so stacking the layers
reproduces a full render closely.  Every layer has a colour-region mask (RGB, opaque):
    R = skin weight, G = shirt weight, B = the layer's own colour (base: apron, hair: hair, beard: beard)
found by re-rendering with that colour changed.  The game recolours a region with a gradient map from the
default tones to the chosen swatch's tones (both written to data/appearance.json), so choosing the
default colours changes nothing.

Files: assets/sprites/chars/template_player_l_<layer>[_mask].png (768x512)
       assets/sprites/portraits/template_player_l_<layer>[_mask].png (256x256)
Review: tools/art/out/player_looks.png
"""
import json
import os
import sys

import numpy as np
from PIL import Image

import artlib
from artlib import SPR, OUT, DATA
import make_minis as MM
import make_characters as MC
import portrait as PR
import person
import build

HAIR = [("bald_fringe", "Fringe"), ("bald", "Shaved"), ("cropped", "Cropped"), ("short", "Short"), ("ponytail", "Tied back"), ("long", "Long")]
BEARD = [("braided", "Braided"), ("long", "Long"), ("short", "Short"), ("stubble", "Stubble"), ("none", "Clean-shaven")]
EXTRAS = [("eyepatch", "Eyepatch"), ("scalp_scar", "Scar"), ("spectacles", "Spectacles"), ("headscarf", "Headscarf")]
HAIR_COL = [("iron", "Iron grey", "#a8a094"), ("ash", "Ash white", "#c8c2b4"), ("coal", "Coal black", "#2e2622"),
            ("umber", "Dark brown", "#4e3422"), ("chestnut", "Chestnut", "#7a4a28"), ("copper", "Copper red", "#a6481e"),
            ("straw", "Straw blond", "#c8a868")]
SKIN = [("weathered", "Weathered", "#d9a87e"), ("fair", "Fair", "#eec8a8"), ("ruddy", "Ruddy", "#d8907a"),
        ("olive", "Olive", "#b88c60"), ("bronze", "Bronze", "#96603e"), ("deep", "Deep brown", "#5e3c28")]
SHIRT = [("linen", "Linen", "#cdbd9a"), ("slate", "Slate blue", "#5e6a7c"), ("moss", "Moss green", "#6a7448"),
         ("madder", "Madder red", "#8a3a2c"), ("charcoal", "Charcoal", "#4c4642"), ("ochre", "Ochre", "#b48c44")]
APRON = [("hide", "Tanned hide", None), ("black", "Black leather", "#3a302a"), ("oxblood", "Oxblood", "#6e2c24"),
         ("canvas", "Grey canvas", "#a39d88"), ("walnut", "Walnut", "#5a3e26")]
WASH = {"skin": 0.05, "hair": 0.06, "beard": 0.06, "shirt": 0.1, "apron": 0.08}
DEFAULT = {"hair": "bald_fringe", "hair_col": "iron", "beard": "braided", "beard_col": "ash", "skin": "weathered",
           "shirt": "linen", "apron": "hide", "extras": ["eyepatch", "scalp_scar"]}
TMP = os.path.join(OUT, "player_looks_tmp")


def player():
    for c in json.load(open(os.path.join(DATA, "characters.json"))):
        if c["id"] == "player":
            return c
    raise SystemExit("no player in characters.json")


def tones(region, hexcol):
    if region == "apron" and hexcol is None:
        return list(artlib.ST["pal"]["apron"])
    return list(person.tri(hexcol, WASH[region]))


def base_look(look):
    lk = dict(look)
    lk.update(hair="bald", beard="none", extras=[e for e in look.get("extras", []) if e not in dict(EXTRAS)])
    return lk


def perturb(region, hexcol):
    """A contrasting colour for the mask renders."""
    if hexcol is None or person.lum(hexcol) > 0.35:
        return "#183868"
    return "#e8f4ff"


# ------------------------------------------------------------------ variants to render
def variants(look0):
    """[(layer, own_region, {name: look})] — 'n' is the normal render, 'p_<region>' perturbed ones."""
    base = base_look(look0)
    out = []

    def regions_for(own):
        rs = ["skin", "shirt"] + ([own] if own else [])
        return rs

    def set_col(lk, region, col):
        lk = dict(lk)
        key = {"skin": "skin", "shirt": "shirt", "hair": "hair_col", "beard": "beard_col", "apron": "apron_col"}[region]
        lk[key] = col
        if region == "hair" and not lk.get("beard_col"):
            lk["beard_col"] = look0.get("beard_col") or look0.get("hair_col")
        return lk

    def add(layer, own, lk):
        d = {"n": lk}
        for r in regions_for(own):
            cur = {"skin": lk.get("skin"), "shirt": lk.get("shirt"), "hair": lk.get("hair_col"), "beard": lk.get("beard_col"),
                   "apron": lk.get("apron_col")}[r]
            d["p_" + r] = set_col(lk, r, perturb(r, cur))
        out.append((layer, own, d))

    add("base", "apron", base)
    for h, _ in HAIR:
        add("hair_" + h, "hair", dict(base, hair=h))
    for b, _ in BEARD:
        if b != "none":
            add("beard_" + b, "beard", dict(base, beard=b))
    for x, _ in EXTRAS:
        add("x_" + x, None, dict(base, extras=base["extras"] + [x]))
    return base, out


# ------------------------------------------------------------------ rendering
def render_minis(named):
    """named: {key: look} -> {key: RGBA ndarray 512x768}"""
    jobs, keys = [], []
    for key, lk in named.items():
        figs, bsvg = MM.sheet_svg("player", lk, "player")
        jobs.append(dict(name=f"plk_{key}", svg=figs, w=768, h=512, ss=2, out=os.path.join(TMP, key + "_fig.png")))
        jobs.append(dict(name=f"plk_{key}_base", svg=bsvg, w=128, h=128, ss=2, out=os.path.join(TMP, key + "_base.png")))
        keys.append(key)
    artlib.render(jobs, workers=4)
    res = {}
    for i, key in enumerate(keys):
        figs = Image.open(jobs[2 * i]["out"]).convert("RGBA")
        b = Image.open(jobs[2 * i + 1]["out"]).convert("RGBA")
        im = Image.new("RGBA", (768, 512))
        for r in range(4):
            for c in range(6):
                im.paste(b, (c * 128, r * 128))
        im.alpha_composite(figs)
        res[key] = np.asarray(im).astype(np.int32)
    return res


def render_portraits(named):
    jobs, keys = [], []
    for key, lk in named.items():
        svg = PR.portrait_svg({"id": "player", "look": lk, "age": 58}, MC.STYLE)
        hp = os.path.join(MC.TMP, f"plk_portrait_{key}.html")
        with open(hp, "w") as f:
            f.write(build.page(svg, 256, 256))
        jobs.append(dict(html=hp, png=os.path.join(TMP, f"portrait_{key}.png"), w=256, h=256, transparent=True))
        keys.append(key)
    MC.render(jobs)
    return {k: np.asarray(Image.open(jobs[i]["png"]).convert("RGBA")).astype(np.int32) for i, k in enumerate(keys)}


def premul(a):
    return np.concatenate([a[..., :3] * a[..., 3:4] / 255.0, a[..., 3:4]], axis=-1)


def diff(a, b):
    return np.abs(premul(a) - premul(b)).max(axis=-1)


def weight(n, p):
    d = np.abs(premul(n)[..., :3] - premul(p)[..., :3]).max(axis=-1)
    w = np.clip((d - 4.0) / 40.0, 0.0, 1.0)
    return (w * 255).astype(np.uint8)


def build_layers(kind, look0):
    base, vs = variants(look0)
    named = {}
    for layer, own, d in vs:
        for k, lk in d.items():
            lk = dict(lk)
            if kind == "portrait" and layer in ("base", "beard_braided", "beard_long", "beard_short", "beard_stubble") or \
                    (kind == "portrait" and layer.startswith("x_")):
                lk["_nobrows"] = True
            named[f"{layer}__{k}"] = lk
    imgs = render_minis(named) if kind == "mini" else render_portraits(named)
    base_n = imgs["base__n"]
    outdir = os.path.join(SPR, "chars" if kind == "mini" else "portraits")
    made = []
    for layer, own, d in vs:
        n = imgs[f"{layer}__n"]
        if layer == "base":
            sel = n[..., 3] > 0
        else:
            sel = diff(n, base_n) > 3.0
            if sel.sum() < 4:
                continue
        lay = np.zeros_like(n)
        lay[sel] = n[sel]
        mask = np.zeros(n.shape[:2] + (3,), np.uint8)
        for ch, r in enumerate(["skin", "shirt", own]):
            if r and f"{layer}__p_{r}" in imgs:
                mask[..., ch] = weight(n, imgs[f"{layer}__p_{r}"])
        mask[~sel] = 0
        Image.fromarray(lay.astype(np.uint8), "RGBA").save(artlib.tpath(os.path.join(outdir, f"player_l_{layer}.png")), optimize=True)
        Image.fromarray(mask, "RGB").save(artlib.tpath(os.path.join(outdir, f"player_l_{layer}_mask.png")), optimize=True)
        made.append(layer)
    return made, imgs


def write_json(mini_layers, port_layers):
    def sw(lst, region):
        return [{"id": i, "name": n, "hex": h or artlib.ST["pal"]["apron"][1],
                 "tones": tones(region, h)} for i, n, h in lst]
    data = {
        "_doc": "Player appearance options (generated by tools/art/make_player_looks.py). Layers live in "
                "chars/player_l_<layer> and portraits/player_l_<layer> with _mask companions.",
        "default": DEFAULT,
        "hair": [{"id": i, "name": n} for i, n in HAIR],
        "beard": [{"id": i, "name": n} for i, n in BEARD],
        "extras": [{"id": i, "name": n} for i, n in EXTRAS],
        "colours": {"hair": sw(HAIR_COL, "hair"), "beard": sw(HAIR_COL, "beard"), "skin": sw(SKIN, "skin"),
                    "shirt": sw(SHIRT, "shirt"), "apron": sw(APRON, "apron")},
        "own_region": {"base": "apron", "hair": "hair", "beard": "beard"},
        "layers": {"mini": mini_layers, "portrait": port_layers},
        "ink": artlib.INK,
    }
    with open(os.path.join(DATA, "appearance.json"), "w") as f:
        json.dump(data, f, indent=1)


def review(imgs_m, imgs_p):
    """Full renders of a few combinations next to each other (what the composite approximates)."""
    from contact import font
    sheet = Image.new("RGB", (6 * 260 + 20, 440), (220, 199, 154))
    fnt = font(14)
    from PIL import ImageDraw
    d = ImageDraw.Draw(sheet)
    look0 = player()["look"]
    combos = [("default", {}), ("short_coal", dict(hair="short", hair_col="#2e2622", beard="short", beard_col="#2e2622")),
              ("long_copper", dict(hair="long", hair_col="#a6481e", beard="long", beard_col="#a6481e", skin="#eec8a8")),
              ("ponytail", dict(hair="ponytail", hair_col="#7a4a28", beard="stubble", beard_col="#7a4a28", shirt="#5e6a7c")),
              ("scarf+specs", dict(hair="cropped", extras=["pauldron", "spectacles", "headscarf"], skin="#96603e")),
              ("shaved", dict(hair="bald", beard="none", extras=["pauldron", "scalp_scar"], skin="#5e3c28", apron_col="#3a302a"))]
    named = {k: dict(look0, **v) for k, v in combos}
    m = render_minis(named)
    p = render_portraits(named)
    for i, (k, _) in enumerate(combos):
        x = 10 + i * 260
        sheet.paste(Image.fromarray(p[k].astype(np.uint8), "RGBA"), (x, 10), Image.fromarray(p[k].astype(np.uint8), "RGBA"))
        im = Image.fromarray(m[k].astype(np.uint8), "RGBA")
        for r in range(2):
            cell = im.crop((0, r * 2 * 128, 128, r * 2 * 128 + 128))
            sheet.paste(cell, (x + r * 128, 280), cell)
        d.text((x, 410), k, fill=(32, 20, 12), font=fnt)
    sheet.save(os.path.join(OUT, "player_looks.png"))
    print(os.path.join(OUT, "player_looks.png"))


def main():
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(MC.TMP, exist_ok=True)
    look0 = dict(player()["look"])
    if "--review" not in sys.argv:
        ml, im_m = build_layers("mini", look0)
        pl, im_p = build_layers("portrait", look0)
        write_json(ml, pl)
        print("mini layers:", ml)
        print("portrait layers:", pl)
    review(None, None)


if __name__ == "__main__":
    main()
