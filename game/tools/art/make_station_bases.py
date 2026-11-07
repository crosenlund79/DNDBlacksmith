"""Tabletop display bases for the crafting stations — the same painted miniature base the characters
stand on (miniature.base: dark rim, tinted top, contact shadow, hatching), scaled to each station.

    python3 game/tools/art/make_station_bases.py            # all stations in data/stations.json
    python3 game/tools/art/make_station_bases.py --only=forge,anvil

Output: assets/sprites/stations/bases/<station_id>.png (RGBA). Size: the base spans ~1.12x the station
sprite's width; its depth follows the character bases' perspective (ry/rx 0.25–0.3) but is never
shallower than a quarter of the sprite's height, so tall pieces still look grounded. The world places
the base so the station's lower edge stands on it (see world.gd _station_base()).
Tint and surface follow the discipline: smithing = sooty flagstones, runecraft = slate, alchemy =
mossy earth, stitching = worn leather-brown flagstones, arcane = deep plum with a gilt ring.
Review: tools/art/out/station_bases_contact.png.
"""
import json
import os
import sys

import artlib
from artlib import render, ink_filter, svg_doc, SPR, OUT, DATA
import miniature as M

OUT_DIR = os.path.join(SPR, "stations", "bases")
# discipline -> (surface style as drawn by miniature.base, top tint)
STYLE = {
    "classic": ("adventurer", "#5a4a3e"),
    "runecraft": ("adventurer", "#5c666c"),
    "alchemy": ("villager", "#5e6644"),
    "stitching": ("player", "#76583c"),
    "arcane": ("companion", "#4a3658"),
}


def geometry(w, h):
    """Base radii in px for a station sprite of w x h px, plus the rim depth."""
    rx = w * 0.56
    ry = max(rx * 0.27, h * 0.24)
    rim = min(9.0, max(4.0, rx / 14.0))
    return rx, ry, rim


def base_svg(st):
    w, h = float(st["size"][0]), float(st["size"][1])
    rx, ry, rim = geometry(w, h)
    pad = 16.0
    W = int(round(2 * rx + 2 * pad))
    H = int(round(2 * ry + rim + 2 * pad + 6))
    style, tint = STYLE.get(st.get("discipline", "classic"), STYLE["classic"])
    P = M.painter(M.palette({"_id": st["id"]}))
    old = M.BASE_TINT.get(style)
    M.BASE_TINT[style] = tint
    # miniature.base works in design units at 2x (centre CX, FY); draw at 2x then scale by 0.5
    shadow, base = M.base(P, style, rx=rx * 2, ry=ry * 2, rim=rim * 2, seed=abs(hash(st["id"])) % 97)
    M.BASE_TINT[style] = old
    cx_px, cy_px = W / 2.0, pad + ry
    tr = f"translate({cx_px:.1f},{cy_px:.1f}) scale(0.5) translate({-M.CX:.1f},{-M.FY - 1:.1f})"
    fb = ink_filter(P, wob=1.0, dil=0.9, grain=0.5, soot=0.4, seed=4)
    svg = svg_doc(W, H, P, f'<g transform="{tr}"><g>{shadow}</g><g {fb}>{base}</g></g>', ss=2)
    return svg, W, H, cx_px, cy_px


def main():
    only = None
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            only = set(a[7:].split(","))
    stations = json.load(open(os.path.join(DATA, "stations.json")))
    os.makedirs(OUT_DIR, exist_ok=True)
    jobs, meta = [], {}
    for st in stations:
        if only and st["id"] not in only:
            continue
        svg, W, H, cx, cy = base_svg(st)
        jobs.append(dict(name=f"base_{st['id']}", svg=svg, w=W, h=H, ss=2, out=os.path.join(OUT_DIR, st["id"] + ".png")))
        meta[st["id"]] = dict(w=W, h=H, cx=round(cx, 1), cy=round(cy, 1))
    render(jobs)
    # anchor metadata: where the base's top-face centre sits inside each PNG
    mp = os.path.join(OUT_DIR, "anchors.json")
    allm = json.load(open(mp)) if os.path.exists(mp) else {}
    allm.update(meta)
    json.dump(allm, open(mp, "w"), indent=1)
    contact(stations)
    print("bases:", len(jobs))


def contact(stations):
    """Each station standing on its base, on a stone floor, for review."""
    from PIL import Image
    tiles = []
    for st in stations:
        bp = os.path.join(OUT_DIR, st["id"] + ".png")
        sp = os.path.join(SPR, "stations", st["id"] + ".png")
        if not (artlib.exists(bp) and artlib.exists(sp)):
            continue
        b = Image.open(bp).convert("RGBA")
        s = Image.open(sp).convert("RGBA")
        W = max(b.width, s.width) + 20
        H = s.height + b.height + 20
        cell = Image.new("RGBA", (W, H), (120, 104, 84, 255))
        cx = W // 2
        sy = 10
        # same placement rule as the world: base top-face centre at the station's lower edge minus a margin
        rx, ry, rim = geometry(float(st["size"][0]), float(st["size"][1]))
        base_cy = sy + s.height * 0.5 + st_offset(float(st["size"][1]), ry)
        a = json.load(open(os.path.join(OUT_DIR, "anchors.json")))[st["id"]]
        cell.alpha_composite(b, (int(cx - a["cx"]), int(base_cy - a["cy"])))
        cell.alpha_composite(s, (int(cx - s.width / 2), sy))
        tiles.append(cell)
    if not tiles:
        return
    cols = 6
    cw = max(t.width for t in tiles)
    ch = max(t.height for t in tiles)
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (60, 48, 36, 255))
    for i, t in enumerate(tiles):
        sheet.alpha_composite(t, ((i % cols) * cw + (cw - t.width) // 2, (i // cols) * ch))
    sheet.save(os.path.join(OUT, "station_bases_contact.png"))


def st_offset(h, ry):
    """Vertical offset from the station sprite's centre to the base's top-face centre (px)."""
    return h * 0.5 - ry * 0.55


if __name__ == "__main__":
    main()
