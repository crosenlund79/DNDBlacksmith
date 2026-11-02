"""Building roofs seen from straight above: roofs/<building_id>.png, size = rect tiles x 64.
Two planes split by the ridge (lit top/left, hatched shade bottom/right), slate/clay/thatch strokes,
stone chimneys at (tile + 0.4) offsets (matching world.gd smoke), soot streaks. No cast shadow.
python3 make_roofs.py [--only=smithy]"""
import math
import os
import random
from artlib import (painter, svg_doc, ink_filter, lin, fill, render, load, only_filter, ell, rect, poly, smooth, blob,
                    wobbly_ell, ST, INK, SPR, SOOT, blur_filter, hatch, uid)

PAL = ST["pal"]
TILE = 64
ROLE = dict(slate="roof_b", clay="roof_a", thatch="straw")


def noise_rect(P, w, h, col, slope, off, freq, seed, octaves=4):
    fid = uid("rn")
    r, g, b = [int(col[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    P.defs.append(f'<filter id="{fid}" filterUnits="userSpaceOnUse" x="0" y="0" width="{w}" height="{h}">'
                  f'<feTurbulence type="fractalNoise" baseFrequency="{freq}" numOctaves="{octaves}" seed="{seed}"/>'
                  f'<feColorMatrix values="0 0 0 0 {r:.3f}  0 0 0 0 {g:.3f}  0 0 0 0 {b:.3f}  {slope} 0 0 0 {off}"/></filter>')
    return f'<rect width="{w}" height="{h}" filter="url(#{fid})"/>'


def plane_h(P, kind, W, H, m, seed):
    """Roof with a horizontal ridge in a W x H box (lit top). Returns svg."""
    role = ROLE[kind]
    l, b, s = PAL[role]
    rnd = random.Random(seed)
    x0, y0, x1, y1 = m, m, W - m, H - m
    ry = H / 2
    o = []
    top, bot = rect(x0, y0, x1 - x0, ry - y0), rect(x0, ry, x1 - x0, y1 - ry)
    o.append(fill(top, l))
    o.append(fill(bot, b))
    # course spacing and strokes
    sp = dict(slate=11, clay=12, thatch=8)[kind]
    lines, joints, light = [], [], []
    for plane in (0, 1):
        ya, yb = (y0, ry) if plane == 0 else (ry, y1)
        n = int((yb - ya) / sp)
        for i in range(1, n + 1):
            # rows measured from the eave toward the ridge
            y = (ya + i * sp) if plane == 0 else (yb - i * sp)
            if abs(y - ry) < sp * 0.6:
                continue
            if kind == "thatch":
                # straw: short strokes running down-slope, plus a ragged course line
                for k in range(int((x1 - x0) / 3.2)):
                    x = x0 + 2 + k * 3.2 + rnd.uniform(-1, 1)
                    L = sp * rnd.uniform(0.7, 1.25)
                    d = (1 if plane == 1 else -1)
                    joints.append(f"M{x:.1f},{y:.1f} l{rnd.uniform(-0.8,0.8):.1f},{d*L:.1f}")
                if i % 3 == 0:
                    lines.append(f"M{x0},{y + rnd.uniform(-1,1):.1f} " + " ".join(f"L{x0 + t:.1f},{y + rnd.uniform(-1.5,1.5):.1f}" for t in range(24, int(x1 - x0), 24)))
            else:
                lines.append(f"M{x0+1},{y:.1f} L{x1-1},{y:.1f}")
                w = dict(slate=18, clay=13)[kind]
                off = (i % 2) * w / 2 + rnd.uniform(-2, 2)
                xx = x0 + off
                while xx < x1 - 2:
                    seg = sp if kind == "clay" else sp * 0.95
                    yy0, yy1 = (y, y - seg) if plane == 0 else (y, y + seg)
                    if kind == "slate":
                        joints.append(f"M{xx:.1f},{yy0:.1f} L{xx:.1f},{yy1:.1f}")
                        if rnd.random() < 0.06:
                            light.append(rect(xx + 1, min(yy0, yy1) + 1, w - 2, seg - 2))
                    else:
                        # barrel tile: curved lower lip
                        d = 1 if plane == 1 else -1
                        joints.append(f"M{xx:.1f},{yy0:.1f} q{w/2:.1f},{d*3.5:.1f} {w:.1f},0")
                        joints.append(f"M{xx+w*0.5:.1f},{yy0+ d*2.5:.1f} L{xx+w*0.5:.1f},{yy1:.1f}")
                    xx += w * rnd.uniform(0.92, 1.08)
    cid = uid("rc")
    P.defs.append(f'<clipPath id="{cid}"><path d="{rect(x0, y0, x1 - x0, y1 - y0)}"/></clipPath>')
    inner = []
    if light:
        inner.append(fill(" ".join(light), l if kind == "slate" else s, 0.5))
    inner.append(noise_rect(P, W, H, s, 1.6, -0.85, 0.02, seed, 4))
    inner.append(noise_rect(P, W, H, "#ffffff", 1.2, -0.85, 0.05, seed + 1, 3))
    lw_c = dict(slate=1.1, clay=1.0, thatch=0.9)[kind]
    inner.append(lin(" ".join(lines), INK, lw_c, 0.75))
    inner.append(lin(" ".join(joints), INK if kind != "thatch" else s, 0.8 if kind != "thatch" else 0.9, 0.6 if kind != "thatch" else 0.75))
    if kind == "thatch":
        inner.append(lin(" ".join(joints[::4]), l, 0.8, 0.6))
    # shaded plane: wash + hatch + darkening near the ridge
    inner.append(fill(bot, s, 0.12))
    inner.append(fill(bot, hatch(P, -35, 4.6, 1.0), 0.45))
    
    gid = uid("rg")
    P.defs.append(f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{INK}" stop-opacity="0.22"/>'
                  f'<stop offset="0.35" stop-color="{INK}" stop-opacity="0"/></linearGradient>')
    inner.append(fill(bot, f"url(#{gid})"))
    # lit plane: small bright eave + moss/lichen for clay & thatch
    if kind in ("clay", "thatch"):
        mc = "#7d8a52" if kind == "thatch" else "#8a9460"
        for i in range(int(W * H / 26000) + 2):
            x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
            inner.append(fill(blob(x, y, rnd.uniform(8, 18), 6, 0.3, i, squash=0.6), mc, 0.35, blur_filter(P, 2)))
    o.append(f'<g clip-path="url(#{cid})">' + "".join(inner) + "</g>")
    # ridge cap
    if kind == "slate":
        o.append(fill(rect(x0, ry - 5, x1 - x0, 10), PAL["slate"][1]))
        o.append(lin(" ".join(f"M{x:.1f},{ry-5} L{x:.1f},{ry+5}" for x in range(int(x0) + 14, int(x1), 16)), INK, 0.9, 0.7))
        o.append(fill(rect(x0, ry, x1 - x0, 5), hatch(P, -35, 3.6, 0.9), 0.5))
        o.append(lin(f"M{x0},{ry-5} L{x1},{ry-5} M{x0},{ry+5} L{x1},{ry+5}", INK, 1.8))
    elif kind == "clay":
        caps = " ".join(f"M{x:.1f},{ry+6} a7,6 0 0,1 0,-12 l14,0 a7,6 0 0,0 0,12 Z" for x in range(int(x0) + 2, int(x1) - 14, 14))
        o.append(fill(rect(x0, ry - 6, x1 - x0, 12), PAL["roof_a"][2], 0.9))
        o.append(fill(caps, PAL["roof_a"][1]))
        o.append(lin(caps, INK, 0.9, 0.8))
        o.append(lin(f"M{x0},{ry-6} L{x1},{ry-6} M{x0},{ry+6} L{x1},{ry+6}", INK, 1.8))
    else:
        o.append(fill(rect(x0, ry - 9, x1 - x0, 18, 6), PAL["straw"][1]))
        o.append(fill(rect(x0, ry, x1 - x0, 9), hatch(P, -35, 3.6, 0.9), 0.45))
        o.append(lin(" ".join(f"M{x},{ry-9} l9,18 M{x+9},{ry-9} l-9,18" for x in range(int(x0) + 4, int(x1) - 10, 22)), PAL["brown"][2], 1.6, 0.85))
        o.append(lin(f"M{x0},{ry-9} L{x1},{ry-9} M{x0},{ry+9} L{x1},{ry+9}", INK, 1.8))
    # eave edge: thick ink outline + inner double rule (overhang)
    edge_w = 5 if kind != "thatch" else 7
    if kind == "thatch":
        o.append(lin(rect(x0 + 3, y0 + 3, x1 - x0 - 6, y1 - y0 - 6, 6), PAL["straw"][2], 2.2, 0.6))
    else:
        o.append(lin(rect(x0 + 4, y0 + 4, x1 - x0 - 8, y1 - y0 - 8), INK, 1.0, 0.6))
    o.append(lin(rect(x0, y0, x1 - x0, y1 - y0, 6 if kind == "thatch" else 1.5), INK, 3.2))
    return "\n".join(o)


def chimney(P, cx, cy, sz=48, seed=1):
    rnd = random.Random(seed)
    x, y = cx - sz / 2, cy - sz / 2
    o = []
    # soot streak down-slope / toward bottom-right
    o.append(fill(f"M{cx-10},{cy} L{cx+46},{cy+70} L{cx+70},{cy+50} L{cx+12},{cy-6} Z", SOOT, 0.32, blur_filter(P, 9)))
    o.append(fill(ell(cx + 6, cy + 6, sz * 0.8, sz * 0.7), SOOT, 0.22, blur_filter(P, 8)))
    # lead flashing
    o.append(P.shape(rect(x - 4, y - 4, sz + 8, sz + 8, 3), "slate", s=2, lw=1.6, fill_override=PAL["darkiron"][1]))
    o.append(P.shape(rect(x, y, sz, sz, 3), "stone", s=5, lw=2.4))
    # stone blocks
    seg = []
    for r in range(3):
        yy = y + r * sz / 3
        if r:
            seg.append(f"M{x},{yy:.1f} L{x+sz},{yy:.1f}")
        for k in range(2):
            xx = x + (k + 0.5 + (r % 2) * 0.5) * sz / 2
            if xx < x + sz - 2:
                seg.append(f"M{xx:.1f},{yy:.1f} L{xx:.1f},{yy+sz/3:.1f}")
    o.append(P.detail(" ".join(seg), "stone", 0.7, 0.7))
    # cap + dark flue opening with soot rim
    o.append(P.shape(rect(x + 9, y + 9, sz - 18, sz - 18, 2), "stone", s=-2, hl=False, lw=1.8, fill_override=PAL["stone"][2]))
    o.append(fill(rect(x + 13, y + 13, sz - 26, sz - 26, 1.5), "#120c08", 1))
    o.append(fill(ell(cx, cy, sz * 0.32), SOOT, 0.45, blur_filter(P, 3)))
    return "\n".join(o)


def roof_svg(b):
    tx, ty, tw, th = b["rect"]
    W, H = tw * TILE, th * TILE
    kind, ridge = b["roof"], b["ridge"]
    P = painter(scale=1.0, lw_mul=0.75)
    m = 3
    seed = sum(map(ord, b["id"]))
    if ridge == "h":
        plane = plane_h(P, kind, W, H, m, seed)
    else:
        plane = f'<g transform="matrix(0,1,1,0,0,0)">{plane_h(P, kind, H, W, m, seed)}</g>'
    chim = "".join(chimney(P, (c[0] + 0.4) * TILE, (c[1] + 0.4) * TILE, 48, i + seed) for i, c in enumerate(b.get("chimneys", [])))
    f = ink_filter(P, wob=1.6, dil=0.6, grain=0.5, soot=0.9)
    body = f'<g {f}>{plane}{chim}</g>'
    return svg_doc(W, H, P, body, ss=2), W, H


def jobs():
    only = only_filter()
    js = []
    L = load("layout.json")
    for b in L["buildings"]:
        if only and b["id"] not in only:
            continue
        svg, W, H = roof_svg(b)
        js.append(dict(name=f"rf_{b['id']}", svg=svg, w=W, h=H, ss=2, out=os.path.join(SPR, "roofs", b["id"] + ".png")))
    return js


if __name__ == "__main__":
    render(jobs(), workers=3)
