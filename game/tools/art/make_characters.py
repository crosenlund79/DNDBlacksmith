"""Generates character sprite sheets, portraits and a review contact sheet for "Ember & Ash".

    python3 game/tools/art/make_characters.py [id ...] [--no-portraits] [--no-sheets]

Pipeline: Python -> SVG (exploration generator painter, style "ink_parchment_gothic_80_20")
-> headless Chromium via docs/visual_exploration/_generator/render.js -> PNG.

Sheets: assets/sprites/chars/<id>.png, 6x4 cells of 128x128 (768x512), transparent.
  rows: 0 south, 1 east, 2 north, 3 west; cols 0-1 idle (breathing), 2-5 walk.
Portraits: assets/sprites/portraits/<id>.png, 256x256 front-view bust, transparent.
Contact sheet (review only): tools/art/out/characters_contact.png

NOTE: the in-game sheets are now tabletop miniatures built by make_minis.py.  This script only writes the
old straight-top-down sheets when run with --style=topdown; otherwise it regenerates portraits only.
"""
import json
import artlib
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", ".."))
GEN = os.path.abspath(os.path.join(GAME, "..", "docs", "visual_exploration", "_generator"))
sys.path.insert(0, GEN)
sys.path.insert(0, HERE)

from styles import STYLES  # noqa: E402
from svgcore import Painter, uid  # noqa: E402
import build  # noqa: E402
import person  # noqa: E402
import portrait  # noqa: E402

STYLE = STYLES["ink_parchment_gothic_80_20"]
CELL = 128
COLS, ROWS = 6, 4
GROUND = (64, 76)
K = 0.27                      # 512 design -> 128 cell
DIRS = [0, -90, 180, 90]      # south (authored), east, north, west  (SVG rotate degrees)
OUT_CHARS = os.path.join(GAME, "assets", "sprites", "chars")
OUT_PORT = os.path.join(GAME, "assets", "sprites", "portraits")
OUT_REV = os.path.join(HERE, "out")
TMP = os.path.join(OUT_REV, "html")

# frame table: (step, breathe)
FRAMES = [(0.0, 0.0), (0.0, 1.0), (1.0, 0.3), (0.0, 0.6), (-1.0, 0.3), (0.0, 0.6)]


def styled(look):
    st = dict(STYLE)
    st["pal"] = person.make_palette(STYLE["pal"], look)
    return st


def dir_painter(st, theta, scale_px, lw_mul):
    """Painter whose light and hatch angles are counter-rotated so that, after the figure is
    rotated by theta, light stays top-left and hatching stays at -35/+35 deg on screen."""
    P = Painter(st)
    a = math.radians(-theta)
    lx, ly = -1.0, -1.0
    P.light = (lx * math.cos(a) - ly * math.sin(a), lx * math.sin(a) + ly * math.cos(a))
    P.lw_mul = lw_mul
    sp = 2.7 / scale_px
    hw = 0.62 / scale_px
    col = STYLE["ink"]
    P.defs[0] = (f'<pattern id="{P.hatch_id}" width="{sp:.2f}" height="{sp:.2f}" patternUnits="userSpaceOnUse" '
                 f'patternTransform="rotate({-35 - theta})"><line x1="0" y1="0" x2="0" y2="{sp:.2f}" stroke="{col}" '
                 f'stroke-width="{hw:.2f}"/></pattern>')
    P.defs[1] = (f'<pattern id="{P.xhatch_id}" width="{sp:.2f}" height="{sp:.2f}" patternUnits="userSpaceOnUse" '
                 f'patternTransform="rotate({35 - theta})"><line x1="0" y1="0" x2="0" y2="{sp:.2f}" stroke="{col}" '
                 f'stroke-width="{hw*0.9:.2f}"/></pattern>')
    return P


def sheet_svg(cid, look):
    look = dict(look)
    look["_id"] = cid
    st = styled(look)
    (ax, ay), bk = person.anchor(look)
    scale = K * bk
    lw_mul = 2.45 / math.sqrt(bk)
    FP = Painter(st, scale=0.42)
    filt = FP.sprite_filter()
    defs = list(FP.defs)
    # screen-space hatch for ground shadows
    shid = uid("shh")
    defs.append(f'<pattern id="{shid}" width="2.6" height="2.6" patternUnits="userSpaceOnUse" patternTransform="rotate(-35)">'
                f'<line x1="0" y1="0" x2="0" y2="2.6" stroke="{STYLE["ink"]}" stroke-width="0.6"/></pattern>')
    srx, sry = person.shadow_size(look)
    body = []
    for row, theta in enumerate(DIRS):
        P = dir_painter(st, theta, scale, lw_mul)
        for col, (step, breathe) in enumerate(FRAMES):
            gx, gy = col * CELL + GROUND[0], row * CELL + GROUND[1]
            rx, ry = srx * scale, sry * scale
            if theta in (90, -90):
                rx, ry = ry, rx
            body.append(f'<g transform="translate({gx+3},{gy+4})">'
                        f'<ellipse rx="{rx:.1f}" ry="{ry:.1f}" fill="#3a2614" opacity="0.16" style="filter:blur(2.5px)"/>'
                        f'<ellipse rx="{rx*0.9:.1f}" ry="{ry*0.88:.1f}" fill="url(#{shid})" opacity="0.5"/></g>')
            fig = person.figure(P, look, step=step, breathe=breathe, detail=True)
            body.append(f'<g transform="translate({gx},{gy})" {filt}><g transform="rotate({theta}) scale({scale:.4f}) '
                        f'translate({-ax},{-ay})">{fig}</g></g>')
        defs.extend(P.defs)
    W, H = COLS * CELL, ROWS * CELL
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'<defs>{"".join(defs)}</defs>{"".join(body)}</svg>'), W, H


def render(jobs):
    jf = os.path.join(TMP, "jobs.json")
    with open(jf, "w") as f:
        json.dump(jobs, f)
    subprocess.run(["node", os.path.join(GEN, "render.js"), jf], check=True, stdout=subprocess.DEVNULL)


def check_margins(path, cid):
    from PIL import Image
    im = Image.open(path).convert("RGBA")
    bad = []
    a = im.getchannel("A")
    for r in range(ROWS):
        for c in range(COLS):
            box = a.crop((c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL)).point(lambda v: 255 if v > 24 else 0)
            bb = box.getbbox()
            if bb and (bb[0] < 4 or bb[1] < 4 or bb[2] > CELL - 4 or bb[3] > CELL - 4):
                bad.append((r, c, bb))
    if bad:
        print(f"  margin warning {cid}: {bad[:3]}")


def contact(chars):
    from PIL import Image, ImageDraw
    n = len(chars)
    cols = 7
    cw, chh = 300, 300
    rows = (n + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * chh), (220, 199, 154, 255))
    d = ImageDraw.Draw(sheet)
    for i, c in enumerate(chars):
        x0, y0 = (i % cols) * cw, (i // cols) * chh
        sp = os.path.join(OUT_CHARS, c["id"] + ".png")
        pp = os.path.join(OUT_PORT, c["id"] + ".png")
        if os.path.exists(pp):
            p = Image.open(pp).convert("RGBA").resize((160, 160), Image.LANCZOS)
            sheet.alpha_composite(p, (x0 + 140, y0 + 4))
        if os.path.exists(sp):
            s = Image.open(sp).convert("RGBA").crop((0, 0, CELL, CELL))
            sheet.alpha_composite(s, (x0 + 6, y0 + 20))
            s2 = s.resize((CELL * 2, CELL * 2), Image.NEAREST).crop((40, 40, 216, 216)).resize((120, 120), Image.LANCZOS)
            sheet.alpha_composite(Image.open(sp).convert("RGBA").crop((CELL * 2, CELL, CELL * 3, CELL * 2)), (x0 + 6, y0 + 150))
        d.text((x0 + 8, y0 + 4), f'{c["id"]} ({c["look"]["build"]})', fill=(32, 20, 12, 255))
    os.makedirs(OUT_REV, exist_ok=True)
    sheet.save(os.path.join(OUT_REV, "characters_contact.png"))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    if "--style=topdown" not in flags and "--no-sheets" not in flags:
        print("sheets: skipped (miniature sheets come from make_minis.py; pass --style=topdown for the old ones)")
        flags.append("--no-sheets")
    chars = json.load(open(os.path.join(GAME, "data", "characters.json")))
    todo = [c for c in chars if not args or c["id"] in args]
    for d in (OUT_CHARS, OUT_PORT, OUT_REV, TMP):
        os.makedirs(d, exist_ok=True)
    jobs = []
    zoom = [int(f.split("=")[1]) for f in flags if f.startswith("--zoom=")]
    if zoom:
        # review only: south-row strip of the selected characters, rendered at N x
        z = zoom[0]
        for c in todo:
            svg, W, H = sheet_svg(c["id"], c["look"])
            svg = svg.replace(f'width="{W}" height="{H}" viewBox="0 0 {W} {H}"',
                              f'width="{W*z}" height="{CELL*z}" viewBox="0 0 {W} {CELL}"', 1)
            hp = os.path.join(TMP, f"zoom_{c['id']}.html")
            with open(hp, "w") as f:
                f.write(build.page(svg, W * z, CELL * z))
            jobs.append(dict(html=hp, png=os.path.join(OUT_REV, f"zoom_{c['id']}.png"), w=W * z, h=CELL * z, transparent=False))
        render(jobs)
        return
    for c in todo:
        if "--no-sheets" not in flags:
            svg, W, H = sheet_svg(c["id"], c["look"])
            hp = os.path.join(TMP, f"sheet_{c['id']}.html")
            with open(hp, "w") as f:
                f.write(build.page(svg, W, H))
            jobs.append(dict(html=hp, png=artlib.tpath(os.path.join(OUT_CHARS, c["id"] + ".png")), w=W, h=H, transparent=True))
        if "--no-portraits" not in flags:
            svg = portrait.portrait_svg(c, STYLE)
            hp = os.path.join(TMP, f"portrait_{c['id']}.html")
            with open(hp, "w") as f:
                f.write(build.page(svg, 256, 256))
            jobs.append(dict(html=hp, png=os.path.join(OUT_PORT, c["id"] + ".png"), w=256, h=256, transparent=True))
    render(jobs)
    if "--no-sheets" not in flags:
        for c in todo:
            check_margins(os.path.join(OUT_CHARS, c["id"] + ".png"), c["id"])
    contact(chars)
    print("done:", len(todo), "characters")


if __name__ == "__main__":
    main()
