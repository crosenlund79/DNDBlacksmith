"""Seamlessly tileable 256x256 ground / floor / wall textures.
Every mark is drawn at +-256 offsets and noise uses stitchTiles, so the tile wraps.
python3 make_textures.py [--only=grass]"""
import math
import os
import random
from artlib import (painter, svg_doc, lin, fill, render, only_filter, ell, rect, poly, smooth, blob, wobbly_ell, ST, INK,
                    SPR, OUT, uid, hatch)
from PIL import Image

T = 256
PAL = ST["pal"]
OFFS = [(dx, dy) for dx in (-T, 0, T) for dy in (-T, 0, T)]


def wrap(svg_fragment_fn):
    """Call fn(dx,dy) for every wrap offset and join."""
    return "\n".join(svg_fragment_fn(dx, dy) for dx, dy in OFFS)


def noise(P, freq_cycles, col, alpha_slope, alpha_off, seed=1, octaves=3, fx=None):
    """Tileable fractal noise layer: freq given in whole cycles per tile."""
    fid = uid("tn")
    bfx = (fx or freq_cycles) / T
    bfy = freq_cycles / T
    r, g, b = [int(col[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    P.defs.append(f'<filter id="{fid}" filterUnits="userSpaceOnUse" x="0" y="0" width="{T}" height="{T}" color-interpolation-filters="sRGB">'
                  f'<feTurbulence type="fractalNoise" baseFrequency="{bfx:.5f} {bfy:.5f}" numOctaves="{octaves}" seed="{seed}" stitchTiles="stitch"/>'
                  f'<feColorMatrix values="0 0 0 0 {r:.3f}  0 0 0 0 {g:.3f}  0 0 0 0 {b:.3f}  {alpha_slope:.2f} 0 0 0 {alpha_off:.2f}"/></filter>')
    return f'<rect x="0" y="0" width="{T}" height="{T}" filter="url(#{fid})"/>'


def grain_layer(P, seed=5, op=1.0):
    return noise(P, 64, "#20140c", 1.6 * op, -0.95, seed, 2)


def grass(P):
    rnd = random.Random(3)
    o = [fill(rect(0, 0, T, T), "#d8c99a")]
    o.append(noise(P, 3, "#9aa068", 1.3, -0.5, 2, 4))
    o.append(noise(P, 5, "#c8a868", 1.1, -0.48, 7, 3))
    o.append(noise(P, 4, "#e8dcb4", 1.1, -0.5, 13, 3))
    ticks = []
    for i in range(70):
        x, y = rnd.uniform(0, T), rnd.uniform(0, T)
        k = rnd.choice([0, 1, 1, 2])
        if k == 0:
            ticks.append((x, y, f"l2,-7 l2,7 l2,-5"))
        elif k == 1:
            ticks.append((x, y, f"l1.5,-6 M{x+3:.1f},{y:.1f} l2,-7 M{x+6:.1f},{y:.1f} l1,-5"))
        else:
            ticks.append((x, y, f"q2,-4 1,-8 M{x+3:.1f},{y:.1f} q-1,-4 2,-7"))
    d = lambda dx, dy: " ".join(f"M{x+dx:.1f},{y+dy:.1f} " + t.replace(f"M{x+3:.1f}", f"M{x+3+dx:.1f}").replace(f"M{x+6:.1f}", f"M{x+6+dx:.1f}").replace(f",{y:.1f}", f",{y+dy:.1f}") for x, y, t in ticks)
    o.append(wrap(lambda dx, dy: lin(d(dx, dy), PAL["foliage"][2], 1.0, 0.55)))
    dots = [(rnd.uniform(0, T), rnd.uniform(0, T)) for _ in range(40)]
    o.append(wrap(lambda dx, dy: fill(" ".join(ell(x + dx, y + dy, 0.7) for x, y in dots), INK, 0.35)))
    o.append(grain_layer(P, 5, 0.6))
    return "\n".join(o)


def dirt_road(P):
    rnd = random.Random(4)
    o = [fill(rect(0, 0, T, T), "#d6c094")]
    o.append(noise(P, 3, "#a88a5c", 2.0, -0.9, 3, 4))
    o.append(noise(P, 6, "#efe0bc", 1.6, -0.95, 9, 3))
    peb = [(rnd.uniform(0, T), rnd.uniform(0, T), rnd.uniform(1.2, 3.2), i) for i in range(55)]
    def pebbles(dx, dy):
        out = []
        for x, y, r, i in peb:
            dd = wobbly_ell(x + dx, y + dy, r, r * 0.75, i, 0.15, 8)
            out.append(fill(dd, PAL["stone"][0], 0.9) + lin(dd, INK, 0.7, 0.55))
        return "".join(out)
    o.append(wrap(pebbles))
    fl = [(rnd.uniform(0, T), rnd.uniform(0, T), rnd.uniform(4, 9)) for _ in range(40)]
    o.append(wrap(lambda dx, dy: lin(" ".join(f"M{x+dx:.1f},{y+dy:.1f} l{L:.1f},{-L*0.25:.1f}" for x, y, L in fl), PAL["road"][2], 0.8, 0.45)))
    o.append(grain_layer(P, 6, 0.7))
    return "\n".join(o)


def row_widths(rnd, total, lo, hi):
    ws = []
    while sum(ws) < total - hi:
        ws.append(rnd.uniform(lo, hi))
    rest = total - sum(ws)
    if rest < lo:
        ws[-1] += rest
    else:
        ws.append(rest)
    return ws


def stone_course(P, role, rows, lo, hi, seed, gap=2.5, rad=4, mortar="#5e5242", jitter=1.2, wob=0.06, shade=True, hatch_op=0.0):
    rnd = random.Random(seed)
    stones = []
    rh = T / rows
    for r in range(rows):
        ws = row_widths(rnd, T, lo, hi)
        x = rnd.uniform(0, T)
        for w in ws:
            stones.append((x, r * rh, w, rh, rnd.randint(0, 999)))
            x += w
    o = [fill(rect(0, 0, T, T), mortar)]
    def draw(dx, dy):
        out = []
        for (x, y, w, h, sd) in stones:
            xx, yy = x + dx + gap / 2, y + dy + gap / 2
            if xx > T + 4 or yy > T + 4 or xx + w < -4 or yy + h < -4:
                continue
            rnd2 = random.Random(sd)
            pts = [(xx + rnd2.uniform(0, jitter), yy + rnd2.uniform(0, jitter)), (xx + w - gap - rnd2.uniform(0, jitter), yy + rnd2.uniform(0, jitter)),
                   (xx + w - gap - rnd2.uniform(0, jitter), yy + h - gap - rnd2.uniform(0, jitter)), (xx + rnd2.uniform(0, jitter), yy + h - gap - rnd2.uniform(0, jitter))]
            d = rounded(pts, rad)
            tone = rnd2.choice([0, 1, 1, 1, 2])
            col = [PAL[role][0], PAL[role][1], mix(PAL[role][1], PAL[role][2], 0.3)][tone]
            out.append(P.shape(d, role, s=2.2 if shade else 0, fill_override=col, flat=not shade, lw=1.6))
            if rnd2.random() < 0.35:
                cx, cy = xx + w * rnd2.uniform(0.3, 0.6), yy + h * rnd2.uniform(0.3, 0.6)
                out.append(lin(f"M{cx:.1f},{cy:.1f} l{rnd2.uniform(3,7):.1f},{rnd2.uniform(-3,3):.1f} l{rnd2.uniform(2,5):.1f},{rnd2.uniform(-2,3):.1f}", INK, 0.7, 0.5))
        return "".join(out)
    o.append(wrap(draw))
    return "\n".join(o)


def rounded(pts, r):
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        def toward(a, b, d):
            L = math.hypot(b[0] - a[0], b[1] - a[1]) or 1
            return (a[0] + (b[0] - a[0]) * d / L, a[1] + (b[1] - a[1]) * d / L)
        a = toward(p1, p0, r)
        b = toward(p1, p2, r)
        out.append((a, p1, b))
    d = f"M{out[0][0][0]:.1f},{out[0][0][1]:.1f} "
    for i, (a, p, b) in enumerate(out):
        if i:
            d += f"L{a[0]:.1f},{a[1]:.1f} "
        d += f"Q{p[0]:.1f},{p[1]:.1f} {b[0]:.1f},{b[1]:.1f} "
    return d + "Z"


def mix(c1, c2, t):
    a = [int(c1[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(c2[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{int(a[i] + (b[i] - a[i]) * t):02x}" for i in range(3))


def cobble(P):
    o = [stone_course(P, "stone", 9, 22, 36, 11, gap=3.4, rad=8, mortar="#8a7a5e", jitter=2.4)]
    o.append(noise(P, 4, "#6a5a40", 1.4, -0.85, 4, 3))
    o.append(grain_layer(P, 8, 0.7))
    return "\n".join(o)


def floor_stone(P):
    o = [stone_course(P, "stone", 4, 50, 90, 21, gap=3, rad=3, mortar="#6e604a", jitter=1.5)]
    o.append(noise(P, 3, "#5a4a36", 1.2, -0.62, 6, 4))
    o.append(grain_layer(P, 9, 0.7))
    return "\n".join(o)


def planks_tex(P, role, seed, dark=0.0):
    rnd = random.Random(seed)
    rows = 8
    rh = T / rows
    l, b, s = PAL[role]
    if dark:
        l, b, s = mix(l, "#3a2a1a", dark), mix(b, "#3a2a1a", dark), mix(s, "#1a120a", dark * 0.6)
    o = [fill(rect(0, 0, T, T), b)]
    o.append(noise(P, 2, s, 1.4, -0.85, seed, 3, fx=1))
    boards = []
    for r in range(rows):
        ws = row_widths(rnd, T, 70, 150)
        x = rnd.uniform(0, T)
        for w in ws:
            boards.append((x, r * rh, w, rh, rnd.randint(0, 999), rnd.uniform(-0.06, 0.06)))
            x += w
    def draw(dx, dy):
        out = []
        for (x, y, w, h, sd, tint) in boards:
            xx, yy = x + dx, y + dy
            if xx > T + 2 or yy > T + 2 or xx + w < -2 or yy + h < -2:
                continue
            rnd2 = random.Random(sd)
            col = l if tint > 0.03 else (s if tint < -0.04 else None)
            if col:
                out.append(fill(rect(xx, yy, w, h), col, 0.28))
            # grain
            g = []
            for k in range(4):
                gy = yy + h * rnd2.uniform(0.15, 0.85)
                gx = xx + rnd2.uniform(0, w * 0.5)
                L = rnd2.uniform(w * 0.3, w * 0.7)
                g.append(f"M{gx:.1f},{gy:.1f} q{L*0.5:.1f},{rnd2.uniform(-1.6,1.6):.1f} {L:.1f},0")
            if rnd2.random() < 0.3:
                kx, ky = xx + w * rnd2.uniform(0.2, 0.8), yy + h * 0.5
                g.append(wobbly_ell(kx, ky, 3.2, 1.8, sd, 0.1, 8))
            out.append(lin(" ".join(g), s, 0.8, 0.6))
            # bottom shadow edge (hatched) + gaps + nails
            out.append(fill(rect(xx, yy + h - 4, w, 4), hatch(P, -35, 3, 0.8), 0.35))
            out.append(lin(f"M{xx:.1f},{yy:.1f} L{xx:.1f},{yy+h:.1f}", INK, 1.8, 0.9))
            out.append(fill(ell(xx + 5, yy + h * 0.3, 1.1) + " " + ell(xx + 5, yy + h * 0.7, 1.1) + " " + ell(xx + w - 5, yy + h * 0.3, 1.1) + " " + ell(xx + w - 5, yy + h * 0.7, 1.1), INK, 0.85))
        return "".join(out)
    o.append(wrap(draw))
    o.append(wrap(lambda dx, dy: lin(" ".join(f"M{-T+dx},{r*rh+dy:.1f} L{2*T+dx},{r*rh+dy:.1f}" for r in range(rows + 1)), INK, 1.8, 0.95) if dx == 0 else ""))
    o.append(grain_layer(P, seed + 3, 0.7))
    return "\n".join(o)


def floor_wood(P):
    return planks_tex(P, "wood", 31)


def floor_tavern(P):
    return planks_tex(P, "wood", 47, dark=0.42)


def water(P):
    rnd = random.Random(8)
    o = [fill(rect(0, 0, T, T), "#7e9c98")]
    o.append(noise(P, 2, "#56706c", 2.0, -0.9, 3, 4))
    o.append(noise(P, 4, "#a8c0b8", 1.8, -0.95, 11, 3))
    rip = [(rnd.uniform(0, T), rnd.uniform(0, T), rnd.uniform(8, 22)) for _ in range(46)]
    def r(dx, dy, light):
        sel = rip[::2] if light else rip[1::2]
        col = "#d4e2da" if light else "#3e5450"
        return lin(" ".join(f"M{x+dx:.1f},{y+dy:.1f} q{L*0.25:.1f},{-L*0.12:.1f} {L*0.5:.1f},0 t{L*0.5:.1f},0" for x, y, L in sel), col, 1.3, 0.6 if light else 0.45)
    o.append(wrap(lambda dx, dy: r(dx, dy, False)))
    o.append(wrap(lambda dx, dy: r(dx, dy, True)))
    o.append(wrap(lambda dx, dy: r(dx + 3, dy + 1.5, True).replace('opacity="0.6"', 'opacity="0.25"')))
    o.append(grain_layer(P, 12, 0.5))
    return "\n".join(o)


def wall_stone(P):
    PAL.setdefault("wallstone", ("#b8ac98", "#9a8c78", "#5a4e40"))
    o = [stone_course(P, "wallstone", 8, 36, 72, 51, gap=3, rad=3.5, mortar="#4a4034", jitter=1.6)]
    o.append(noise(P, 3, "#16100b", 1.5, -0.9, 14, 4))
    o.append(grain_layer(P, 15, 0.8))
    return "\n".join(o)


def wall_timber(P):
    o = [fill(rect(0, 0, T, T), "#e2d4b2")]
    o.append(noise(P, 5, "#b8a47c", 1.8, -0.9, 21, 4))
    o.append(noise(P, 2, "#7a6646", 1.2, -0.85, 22, 3))
    beam = PAL["wood"]
    dark = mix(beam[1], "#3a2414", 0.45)
    def timbers(dx, dy):
        out = []
        bw = 18
        ds = [rect(-bw / 2 + dx, dy, bw, T), rect(T / 2 - bw / 2 + dx, dy, bw, T), rect(dx, T / 2 - bw / 2 + dy, T, bw),
              rect(dx, -bw / 2 + dy, T, bw)]
        for d in ds:
            out.append(P.shape(d, "wood", s=2.5, fill_override=dark, lw=2))
        # diagonal braces in two panels
        for (x0, y0, x1, y1) in [(9, 9, T / 2 - 9, T / 2 - 9), (T / 2 + 9, T - 9, T - 9, T / 2 + 9)]:
            ang = math.atan2(y1 - y0, x1 - x0)
            px, py = -math.sin(ang) * 7, math.cos(ang) * 7
            out.append(P.shape(poly([(x0 + px + dx, y0 + py + dy), (x1 + px + dx, y1 + py + dy), (x1 - px + dx, y1 - py + dy), (x0 - px + dx, y0 - py + dy)]),
                               "wood", s=2, fill_override=dark, lw=2))
        out.append(fill(" ".join(ell(x + dx, y + dy, 1.6) for x in (0, T / 2) for y in (T / 4, T * 3 / 4)), INK, 0.9))
        return "".join(out)
    o.append(wrap(timbers))
    rnd = random.Random(6)
    cr = [(rnd.uniform(0, T), rnd.uniform(0, T)) for _ in range(10)]
    o.append(wrap(lambda dx, dy: lin(" ".join(f"M{x+dx:.1f},{y+dy:.1f} l4,3 l2,6" for x, y in cr), INK, 0.7, 0.35)))
    o.append(grain_layer(P, 23, 0.8))
    return "\n".join(o)


TEX = dict(grass=grass, dirt_road=dirt_road, cobble=cobble, floor_wood=floor_wood, floor_stone=floor_stone,
           floor_tavern=floor_tavern, water=water, wall_stone=wall_stone, wall_timber=wall_timber)


def jobs():
    only = only_filter()
    js = []
    for name, fn in TEX.items():
        if only and name not in only:
            continue
        P = painter(scale=1.0, lw_mul=0.55)
        body = f'<g clip-path="none">{fn(P)}</g>'
        svg = svg_doc(T, T, P, body, ss=2)
        js.append(dict(name=f"tx_{name}", svg=svg, w=T, h=T, ss=2, wrap=True, transparent=False,
                       out=os.path.join(SPR, "textures", name + ".png")))
    return js


def tile_test():
    os.makedirs(OUT, exist_ok=True)
    names = list(TEX)
    sheet = Image.new("RGB", (len(names) * 2 * T // 2 + (len(names) - 1) * 8, T))
    x = 0
    for n in names:
        im = Image.open(os.path.join(SPR, "textures", n + ".png")).convert("RGB")
        t = Image.new("RGB", (2 * T, 2 * T))
        for a in range(2):
            for b in range(2):
                t.paste(im, (a * T, b * T))
        t.save(os.path.join(OUT, f"tile2x2_{n}.png"))
        sheet.paste(t.resize((T, T)), (x, 0))
        x += T + 8


if __name__ == "__main__":
    render(jobs())
    tile_test()
