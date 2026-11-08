"""Building roofs seen from straight above: roofs/<building_id>.png, size = rect tiles x 64.
Two planes split by the ridge (lit top/left, hatched shade bottom/right), slate/clay/thatch strokes,
stone chimneys at (tile + 0.4) offsets (matching world.gd smoke), soot streaks. No cast shadow.
python3 make_roofs.py [--only=smithy]"""
import colorsys
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



# ------------------------------------------------------------------ iteration 010: weathered, characterful roofs
def tone(col, dv=0.0, ds=0.0, dh=0.0):
    """Shift a hex colour's lightness / saturation / hue (HLS)."""
    r, g, b = [int(col[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    h, li, s = colorsys.rgb_to_hls(r, g, b)
    r, g, b = colorsys.hls_to_rgb((h + dh) % 1.0, min(1, max(0, li + dv)), min(1, max(0, s * (1 + ds))))
    return "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))


def roof_cols(kind, seed):
    """Each building gets its own weathered tone of its roofing (older, sun-bleached, sooty or freshly redone)."""
    rnd = random.Random(seed * 7 + 3)
    l, b, s = PAL[ROLE[kind]]
    dv, ds, dh = rnd.uniform(-0.07, 0.04), rnd.uniform(-0.3, 0.12), rnd.uniform(-0.025, 0.02)
    if kind == "slate":
        dh = rnd.uniform(-0.06, 0.06)
    return tuple(tone(c, dv, ds, dh) for c in (l, b, s))


def _sag(x, x0, x1, amt):
    return amt * math.sin(math.pi * min(1.0, max(0.0, (x - x0) / (x1 - x0))))


def _row(x0, x1, y, amt, f, rnd, step=22, jit=0.8):
    """A course line bowed by the sagging ridge (f = how close to the ridge, 0 eave .. 1 ridge) with a little wobble."""
    pts = []
    x = x0
    while x < x1:
        pts.append((x, y + f * _sag(x, x0, x1, amt) + rnd.uniform(-jit, jit)))
        x += step
    pts.append((x1, y + rnd.uniform(-jit, jit)))
    return "M" + " L".join(f"{px:.1f},{py:.1f}" for px, py in pts)


def plane_h(P, kind, W, H, m, seed):
    """Roof with a horizontal ridge in a W x H box (lit top plane, hatched shade below). Returns svg.
    Weathered: per-building tone, a sagging ridge with bowed courses, ragged thatch eaves with tufts, patched and
    missing tiles showing the battens, moss and lichen along the shaded eave and the ridge, rain streaks."""
    role = ROLE[kind]
    l, b, s = roof_cols(kind, seed)
    rnd = random.Random(seed)
    x0, y0, x1, y1 = m, m, W - m, H - m
    ry = H / 2
    sag = min(9.0, max(2.5, W * rnd.uniform(0.006, 0.012))) * (1.35 if kind == "thatch" else 1.0)

    def ridge_pts(rev=False, dy=0.0):
        xs = [x0 + (x1 - x0) * k / 24 for k in range(25)]
        if rev:
            xs = xs[::-1]
        return [(x, ry + dy + _sag(x, x0, x1, sag)) for x in xs]

    def pathpts(pts):
        return " L".join(f"{x:.1f},{y:.1f}" for x, y in pts)

    top = f"M{x0},{y0} L{x1},{y0} L{pathpts(ridge_pts(True))} Z"
    bot = f"M{pathpts(ridge_pts())} L{x1},{y1} L{x0},{y1} Z"
    o = [fill(top, l), fill(bot, b)]
    sp = dict(slate=11, clay=12, thatch=8)[kind]
    lines, joints, light = [], [], []
    for plane in (0, 1):
        ya, yb = (y0, ry) if plane == 0 else (ry, y1)
        n = int((yb - ya) / sp)
        for i in range(1, n + 1):
            y = (ya + i * sp) if plane == 0 else (yb - i * sp)
            if abs(y - ry) < sp * 0.6:
                continue
            f = (y - y0) / (ry - y0) if plane == 0 else (y1 - y) / (y1 - ry)
            if kind == "thatch":
                for k in range(int((x1 - x0) / 3.2)):
                    x = x0 + 2 + k * 3.2 + rnd.uniform(-1, 1)
                    L = sp * rnd.uniform(0.7, 1.3)
                    d = (1 if plane == 1 else -1)
                    joints.append(f"M{x:.1f},{y + f * _sag(x, x0, x1, sag):.1f} l{rnd.uniform(-0.9,0.9):.1f},{d*L:.1f}")
                if i % 3 == 0:
                    lines.append(_row(x0, x1, y, sag, f, rnd, 24, 1.6))
            else:
                lines.append(_row(x0 + 1, x1 - 1, y, sag, f, rnd))
                w = dict(slate=18, clay=13)[kind]
                off = (i % 2) * w / 2 + rnd.uniform(-2, 2)
                xx = x0 + off
                while xx < x1 - 2:
                    seg = sp if kind == "clay" else sp * 0.95
                    yy = y + f * _sag(xx, x0, x1, sag)
                    yy0, yy1 = (yy, yy - seg) if plane == 0 else (yy, yy + seg)
                    if kind == "slate":
                        joints.append(f"M{xx:.1f},{yy0:.1f} L{xx+rnd.uniform(-0.6,0.6):.1f},{yy1:.1f}")
                        if rnd.random() < 0.07:
                            light.append(rect(xx + 1, min(yy0, yy1) + 1, w - 2, seg - 2))
                    else:
                        d = 1 if plane == 1 else -1
                        joints.append(f"M{xx:.1f},{yy0:.1f} q{w/2:.1f},{d*3.5:.1f} {w:.1f},0")
                        joints.append(f"M{xx+w*0.5:.1f},{yy0+ d*2.5:.1f} L{xx+w*0.5:.1f},{yy1:.1f}")
                    xx += w * rnd.uniform(0.9, 1.1)
    cid = uid("rc")
    P.defs.append(f'<clipPath id="{cid}"><path d="{rect(x0, y0, x1 - x0, y1 - y0, 14 if kind == "thatch" else 0)}"/></clipPath>')
    inner = []
    if light:
        inner.append(fill(" ".join(light), l if kind == "slate" else s, 0.5))
    inner.append(noise_rect(P, W, H, s, 1.6, -0.85, 0.02, seed, 4))
    inner.append(noise_rect(P, W, H, "#ffffff", 1.2, -0.85, 0.05, seed + 1, 3))
    # patched repairs: a few courses of newer (or older) tiles / a fresh bundle of straw
    area = (x1 - x0) * (y1 - y0)
    for i in range(1 + int(area / 70000)):
        pw, ph = rnd.uniform(34, 70), rnd.uniform(sp * 1.6, sp * 3.2)
        px, py = rnd.uniform(x0 + 8, x1 - pw - 8), rnd.uniform(y0 + 6, y1 - ph - 6)
        if abs(py + ph / 2 - ry) < ph:
            py = ry + 14 if py > ry - ph else py - ph
        col = tone(b, rnd.choice([-0.1, 0.08, 0.12]), rnd.uniform(-0.2, 0.2), rnd.uniform(-0.03, 0.03))
        if kind == "thatch":
            pd = blob(px + pw / 2, py + ph / 2, pw / 2, 9, 0.18, seed + i, squash=ph / pw)
            inner.append(fill(pd, tone(b, 0.06, 0.25, 0.01), 0.75))
            inner.append(lin(" ".join(f"M{px+k*3:.1f},{py+rnd.uniform(2,ph*0.3):.1f} l{rnd.uniform(-1,1):.1f},{ph*0.55:.1f}" for k in range(int(pw / 3))), s, 0.8, 0.7))
            inner.append(lin(pd, s, 1.2, 0.6))
        else:
            pd = rect(px, py, pw, ph, 1)
            inner.append(fill(pd, col, 0.8))
            w = dict(slate=18, clay=13)[kind]
            inner.append(lin(" ".join(f"M{px+k*w:.1f},{py:.1f} L{px+k*w:.1f},{py+ph:.1f}" for k in range(1, int(pw / w) + 1)) + " " +
                             " ".join(f"M{px:.1f},{py+k*sp:.1f} L{px+pw:.1f},{py+k*sp:.1f}" for k in range(1, int(ph / sp) + 1)), INK, 0.8, 0.55))
            inner.append(lin(pd, INK, 0.9, 0.45))
    # missing tiles: dark holes showing the battens; a slipped tile lying askew below
    if kind != "thatch":
        w = dict(slate=18, clay=13)[kind]
        for i in range(rnd.randint(1, 2 + int(area / 160000))):
            hx, hy = rnd.uniform(x0 + 20, x1 - 40), rnd.choice([rnd.uniform(y0 + 10, ry - 24), rnd.uniform(ry + 14, y1 - 22)])
            hw = w * rnd.choice([1, 2, 2, 3])
            hy2 = sp * rnd.choice([1, 2])
            inner.append(fill(rect(hx, hy, hw, hy2, 0.8), "#1a120c", 0.92))
            inner.append(lin(" ".join(f"M{hx+k*w:.1f},{hy:.1f} v{hy2:.1f}" for k in range(1, int(hw / w))), "#3a2a1a", 0.8, 0.8))
            inner.append(lin(" ".join(f"M{hx:.1f},{hy+sp*(k+0.4):.1f} h{hw:.1f}" for k in range(int(hy2 / sp))), "#9a7a52", 1.6, 0.9))
            ang = rnd.uniform(-25, 25)
            inner.append(f'<g transform="rotate({ang:.0f} {hx+hw/2+4:.1f} {hy+sp*1.6:.1f})">' +
                         fill(rect(hx + 4, hy + sp * 1.2, w - 2, sp - 2, 1), l, 0.95) + lin(rect(hx + 4, hy + sp * 1.2, w - 2, sp - 2, 1), INK, 0.9, 0.8) + "</g>")
    else:
        for i in range(rnd.randint(1, 2)):
            hx, hy = rnd.uniform(x0 + 30, x1 - 60), rnd.uniform(ry + 18, y1 - 30)
            bd = blob(hx, hy, rnd.uniform(14, 22), 8, 0.25, seed + 40 + i, squash=0.55)
            inner.append(fill(bd, tone(s, -0.05), 0.55))
            inner.append(fill(bd, hatch(P, 70, 3.0, 0.8), 0.35))
            inner.append(lin(" ".join(f"M{hx-10+k*5:.1f},{hy-4:.1f} l{rnd.uniform(-3,3):.1f},8" for k in range(5)), "#4a3a20", 0.9, 0.7))
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
    if kind == "thatch":
        ag = uid("ta")
        P.defs.append(f'<linearGradient id="{ag}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4a4030" stop-opacity="0.32"/>'
                      f'<stop offset="0.3" stop-color="#4a4030" stop-opacity="0"/><stop offset="0.7" stop-color="#4a4030" stop-opacity="0"/>'
                      f'<stop offset="1" stop-color="#4a4030" stop-opacity="0.38"/></linearGradient>')
        inner.append(fill(rect(x0, y0, x1 - x0, y1 - y0), f"url(#{ag})"))
    # rain streaks running down the slopes
    streaks = []
    for i in range(int((x1 - x0) / 26)):
        x = rnd.uniform(x0 + 6, x1 - 6)
        plane = rnd.random() < 0.65
        ya = ry + _sag(x, x0, x1, sag) + (6 if plane else -6)
        L = rnd.uniform(20, (y1 - ry) * 0.8)
        streaks.append(f"M{x:.1f},{ya:.1f} l{rnd.uniform(-2,2):.1f},{L if plane else -L:.1f}")
    inner.append(lin(" ".join(streaks), INK, 2.4, 0.09, extra=blur_filter(P, 1.2)))
    # moss and lichen: thick along the shaded eave and the ridge, sparse on the lit plane
    mc = ["#6e7e44", "#7d8a52", "#5e6e3a", "#8a9460"]
    clumps = []
    for i in range(int((x1 - x0) / (16 if kind != "slate" else 30))):
        x = rnd.uniform(x0 + 4, x1 - 4)
        where = rnd.random()
        if where < 0.5:
            y = y1 - rnd.uniform(2, 14)
        elif where < 0.8:
            y = ry + _sag(x, x0, x1, sag) + rnd.uniform(-10, 10)
        else:
            y = rnd.uniform(y0 + 4, ry - 10)
        clumps.append((x, y, rnd.uniform(6, 16 if kind != "slate" else 11)))
    # runs of moss hugging the shaded eave
    for i in range(int((x1 - x0) / 120) + 1):
        xa = rnd.uniform(x0, x1 - 60)
        run = [(xa + k * rnd.uniform(5, 9), y1 - rnd.uniform(3, 10), rnd.uniform(5, 11)) for k in range(rnd.randint(6, 14))]
        clumps += run
    for i, (x, y, r) in enumerate(clumps):
        bd = blob(x, y, r, 7, 0.32, seed + i, squash=0.62)
        inner.append(fill(bd, mc[i % 4], 0.8, blur_filter(P, 0.8)))
        inner.append(fill(blob(x - r * 0.2, y - r * 0.2, r * 0.55, 6, 0.3, seed + i + 9, squash=0.6), "#a8b468", 0.45))
        inner.append(fill(" ".join(ell(x + rnd.uniform(-r, r), y + rnd.uniform(-r * 0.5, r * 0.5), rnd.uniform(0.8, 1.8)) for _ in range(4)),
                          "#a8b468", 0.7))
    if kind == "slate":
        inner.append(fill(" ".join(ell(rnd.uniform(x0, x1), rnd.uniform(y0, y1), rnd.uniform(1.0, 2.6)) for _ in range(int(area / 3000))),
                          "#c8c88a", 0.55))
    o.append(f'<g clip-path="url(#{cid})">' + "".join(inner) + "</g>")
    # ridge cap, following the sag
    rp = "M" + pathpts(ridge_pts())
    if kind == "slate":
        o.append(lin(rp, INK, 12.0, cap="butt"))
        o.append(lin(rp, PAL["slate"][1], 9.0, cap="butt"))
        o.append(lin(" ".join(f"M{x:.1f},{ry+_sag(x,x0,x1,sag)-5:.1f} l0,10" for x in range(int(x0) + 14, int(x1), 16)), INK, 0.9, 0.7))
    elif kind == "clay":
        o.append(lin(rp, INK, 13.5, cap="butt"))
        o.append(lin(rp, tone(PAL["roof_a"][1], rnd.uniform(-0.05, 0.04)), 10.5, cap="butt"))
        caps = " ".join(f"M{x:.1f},{ry+_sag(x,x0,x1,sag)+6:.1f} a7,6 0 0,1 0,-12" for x in range(int(x0) + 9, int(x1) - 4, 14))
        o.append(lin(caps, INK, 0.9, 0.8))
        # a few cracked / missing ridge caps
        for i in range(rnd.randint(1, 3)):
            x = rnd.uniform(x0 + 20, x1 - 20)
            o.append(fill(ell(x, ry + _sag(x, x0, x1, sag), 5, 4), "#2a1a10", 0.85))
    else:
        o.append(lin(rp, INK, 20.0, cap="butt"))
        o.append(lin(rp, tone(PAL["straw"][1], rnd.uniform(-0.08, 0.02)), 17.0, cap="butt"))
        o.append(lin(" ".join(f"M{x:.1f},{ry+_sag(x,x0,x1,sag)-8:.1f} l9,16 M{x+9:.1f},{ry+_sag(x,x0,x1,sag)-8:.1f} l-9,16"
                              for x in range(int(x0) + 4, int(x1) - 10, 22)), PAL["brown"][2], 1.6, 0.85))
    # eaves: ragged straw fringe for thatch; slightly uneven tiled edges otherwise
    if kind == "thatch":
        tufts = []
        for (ye, d) in ((y0, -1), (y1, 1)):
            x = x0
            while x < x1:
                tufts.append(f"M{x:.1f},{ye - d*3:.1f} l{rnd.uniform(-2.2,2.2):.1f},{d*rnd.uniform(3,9.5):.1f}")
                x += rnd.uniform(1.6, 3.4)
        for (xe, d) in ((x0, -1), (x1, 1)):
            y = y0
            while y < y1:
                tufts.append(f"M{xe - d*2:.1f},{y:.1f} l{d*rnd.uniform(1.5,4.5):.1f},{rnd.uniform(-1.2,1.2):.1f}")
                y += rnd.uniform(2.2, 4.0)
        o.append(lin(" ".join(tufts), INK, 1.9, 0.9))
        o.append(lin(" ".join(tufts), PAL["straw"][1], 0.9, 0.95))
        edge = []
        for (ya, yb_) in ((y0, y0), (y1, y1)):
            pts = [(x, ya + rnd.uniform(-2.6, 2.6)) for x in [x0 + 12 + k * 9 for k in range(int((x1 - x0 - 24) / 9) + 1)]]
            edge.append("M" + pathpts(pts))
        o.append(lin(" ".join(edge), INK, 3.0))
        o.append(lin(f"M{x0},{y0+10} L{x0},{y1-10} M{x1},{y0+10} L{x1},{y1-10}", INK, 3.0))
        o.append(lin(f"M{x0},{y0+14} Q{x0},{y0} {x0+14},{y0} M{x1-14},{y0} Q{x1},{y0} {x1},{y0+14} M{x0},{y1-14} Q{x0},{y1} {x0+14},{y1} M{x1-14},{y1} Q{x1},{y1} {x1},{y1-14}", INK, 3.0))
        o.append(lin(rect(x0 + 5, y0 + 5, x1 - x0 - 10, y1 - y0 - 10, 12), s, 2.2, 0.5))
    else:
        o.append(lin(rect(x0 + 4, y0 + 4, x1 - x0 - 8, y1 - y0 - 8), INK, 1.0, 0.6))
        edge = []
        for ye in (y0, y1):
            pts = [(x, ye + rnd.uniform(-0.9, 0.9)) for x in [x0 + k * 12 for k in range(int((x1 - x0) / 12) + 1)]]
            edge.append("M" + pathpts(pts))
        o.append(lin(" ".join(edge), INK, 3.2))
        o.append(lin(f"M{x0},{y0} L{x0},{y1} M{x1},{y0} L{x1},{y1}", INK, 3.2))
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
    m = 9 if b["roof"] == "thatch" else 3
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
