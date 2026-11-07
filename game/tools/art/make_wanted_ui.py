"""Most Wanted board UI art (inn notice board for famous adventurers) + the expedition-map party marker.
python3 make_wanted_ui.py [--only=wanted_board,wax_seal]  ->  assets/sprites/ui/template_<name>.png
Only the two stamps carry lettering (FALLEN / MISSING); everything else is text-free (the game draws text on top)."""
import math
import os
import random
from artlib import (painter, svg_doc, ink_filter, soft_filter, glow, lin, fill, render, only_filter, ell, rect, poly, smooth, blob,
                    wobbly_ell, ST, INK, EMBER, EMBER_HOT, RUB, GILT, SPR, PARCH, blur_filter, hatch, uid, GEN)
from make_ui import noise, edge_burn

PAL = ST["pal"]
UI = os.path.join(SPR, "ui")
FONT_DIR = os.path.join(GEN, "fonts")
WOOD_D = "#2a1a10"
WOOD_M = "#4a3020"
WOOD_L = "#6e4a30"


def J(o):
    return "\n".join(x for x in o if x)


def clip(P, d):
    cid = uid("wc")
    P.defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
    return f'clip-path="url(#{cid})"'


def inner_shadow(P, d, col="#000000", op=0.6, w=30, blur=12):
    return f'<g {clip(P, d)}><path d="{d}" fill="none" stroke="{col}" stroke-width="{w}" opacity="{op}" {blur_filter(P, blur)}/></g>'


def wood_fill(P, d, x, y, w, h, base=WOOD_M, seed=1, vertical=False):
    """Dark oak: base + streaky grain noise (anisotropic turbulence) + ink grain lines, clipped to d."""
    fid = uid("wg")
    bf = "0.09 0.004" if vertical else "0.004 0.09"
    P.defs.append(f'<filter id="{fid}" filterUnits="userSpaceOnUse" x="{x}" y="{y}" width="{w}" height="{h}">'
                  f'<feTurbulence type="fractalNoise" baseFrequency="{bf}" numOctaves="4" seed="{seed}"/>'
                  f'<feColorMatrix values="0 0 0 0 0.06  0 0 0 0 0.035  0 0 0 0 0.02  1.6 0 0 0 -0.55"/></filter>')
    fid2 = uid("wh")
    P.defs.append(f'<filter id="{fid2}" filterUnits="userSpaceOnUse" x="{x}" y="{y}" width="{w}" height="{h}">'
                  f'<feTurbulence type="fractalNoise" baseFrequency="{"0.2 0.01" if vertical else "0.01 0.2"}" numOctaves="2" seed="{seed+7}"/>'
                  f'<feColorMatrix values="0 0 0 0 0.62  0 0 0 0 0.44  0 0 0 0 0.28  1.4 0 0 0 -0.72"/></filter>')
    rnd = random.Random(seed)
    lines = []
    for i in range(int((w if vertical else h) / 7)):
        if vertical:
            xx = x + rnd.uniform(0, w)
            lines.append(f"M{xx:.1f},{y:.1f} q{rnd.uniform(-4,4):.1f},{h/2:.1f} {rnd.uniform(-3,3):.1f},{h:.1f}")
        else:
            yy = y + rnd.uniform(0, h)
            lines.append(f"M{x:.1f},{yy:.1f} q{w/2:.1f},{rnd.uniform(-4,4):.1f} {w:.1f},{rnd.uniform(-3,3):.1f}")
    return (f'<g {clip(P, d)}><path d="{d}" fill="{base}"/>'
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" filter="url(#{fid})"/>'
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" filter="url(#{fid2})" opacity="0.5"/>' +
            lin(" ".join(lines), "#120a05", 0.8, 0.35) + "</g>")


def bevel(P, d, light="#a07850", dark="#0c0603", w=3):
    """Raised edge: light top-left, dark bottom-right (clipped strokes)."""
    c = clip(P, d)
    return (f'<g {c}><path d="{d}" fill="none" stroke="{dark}" stroke-width="{w*2}" transform="translate({-w*0.6},{-w*0.6})" opacity="0.8"/>'
            f'<path d="{d}" fill="none" stroke="{light}" stroke-width="{w*2}" transform="translate({w*0.6},{w*0.6})" opacity="0.0"/></g>'
            f'<g {c}><path d="{d}" fill="none" stroke="{light}" stroke-width="{w}" opacity="0.55" transform="translate({w*0.5},{w*0.5})"/></g>'
            + lin(d, dark, 1.6, 0.9))


def nail(x, y, r=4):
    return (fill(ell(x + 1, y + 1.5, r), "#000", 0.5) + fill(ell(x, y, r), "#5a544c") + lin(ell(x, y, r), "#0e0805", 1.2) +
            fill(ell(x - r * 0.3, y - r * 0.3, r * 0.35), "#b0a898", 0.8))


# ------------------------------------------------------------------ board
def wanted_board(P):
    Wd, Hd = 1600, 900
    o = [fill(rect(0, 0, Wd, Hd), "#120a06")]
    # frame
    F = 64
    outer = rect(0, 0, Wd, Hd)
    o.append(wood_fill(P, outer, 0, 0, Wd, Hd, WOOD_M, seed=3))
    # mitred frame rails (each with its own grain direction)
    for (pts, vert, sd) in [([(0, 0), (Wd, 0), (Wd - F, F), (F, F)], False, 4), ([(0, Hd), (Wd, Hd), (Wd - F, Hd - F), (F, Hd - F)], False, 5),
                            ([(0, 0), (F, F), (F, Hd - F), (0, Hd)], True, 6), ([(Wd, 0), (Wd - F, F), (Wd - F, Hd - F), (Wd, Hd)], True, 7)]:
        d = poly(pts)
        o.append(wood_fill(P, d, 0, 0, Wd, Hd, WOOD_M, seed=sd, vertical=vert))
        o.append(lin(d, "#0c0603", 1.6, 0.9))
    o.append(lin(rect(10, 10, Wd - 20, Hd - 20, 2), "#8a6440", 1.2, 0.35))
    o.append(lin(rect(F - 10, F - 10, Wd - 2 * F + 20, Hd - 2 * F + 20, 2), "#0c0603", 2.4, 0.9))
    o.append(lin(rect(F - 6, F - 6, Wd - 2 * F + 12, Hd - 2 * F + 12, 2), "#8a6440", 1.0, 0.45))
    # cork field
    inner = rect(F, F, Wd - 2 * F, Hd - 2 * F)
    cid = clip(P, inner)
    o.append(f'<g {cid}><path d="{inner}" fill="#7a5a38"/>' +
             noise(P, Wd, Hd, "#3a2414", 1.2, -0.4, 0.035, 11, 3) +
             noise(P, Wd, Hd, "#c8a070", 1.4, -0.82, 0.55, 12, 2) +
             noise(P, Wd, Hd, "#1a0e06", 1.6, -0.9, 0.9, 13, 1) +
             noise(P, Wd, Hd, "#e0b880", 2.2, -1.5, 0.35, 14, 1) +
             noise(P, Wd, Hd, "#2a1608", 2.4, -1.6, 0.28, 15, 1) +
             noise(P, Wd, Hd, "#4a2c14", 1.0, -0.45, 0.008, 16, 2) + "</g>")
    # old pin holes, torn paper scraps, faint rectangles where notices hung
    rnd = random.Random(5)
    holes = " ".join(ell(rnd.uniform(F + 20, Wd - F - 20), rnd.uniform(F + 140, Hd - F - 20), rnd.uniform(1.0, 1.8)) for _ in range(90))
    o.append(fill(holes, "#140a04", 0.75))
    for _ in range(9):
        x, y = rnd.uniform(F + 40, Wd - F - 260), rnd.uniform(F + 170, Hd - F - 300)
        o.append(fill(rect(x, y, rnd.uniform(160, 260), rnd.uniform(220, 300)), "#a07a4e", 0.12))
    for _ in range(5):   # torn corners left behind on old pins
        x, y = rnd.uniform(F + 30, Wd - F - 60), rnd.uniform(F + 150, Hd - F - 40)
        pts = [(x, y), (x + rnd.uniform(16, 26), y + rnd.uniform(-2, 2))]
        for k in range(5):
            t = (k + 1) / 6
            pts.append((pts[1][0] * (1 - t) + x * t + rnd.uniform(-2, 2), y + 18 * t * (1 - t) * 4 * rnd.uniform(0.5, 1.2) + rnd.uniform(-2, 2)))
        d = poly(pts)
        o.append(fill(d, "#c4ac80", 0.85) + lin(d, "#3a2414", 0.8, 0.6))
        o.append(fill(ell(x + 5, y + 4, 2.4), "#5a544c") + lin(ell(x + 5, y + 4, 2.4), "#0e0805", 0.8))
    o.append(inner_shadow(P, inner, "#000", 0.75, 70, 22))
    # header plank (carved, no text): x 380..1220, y 26..146
    hx, hy, hw, hh = 400, 22, 800, 124
    hd = smooth([(hx, hy + 14), (hx + 40, hy), (hx + hw / 2, hy - 6), (hx + hw - 40, hy), (hx + hw, hy + 14), (hx + hw + 18, hy + hh / 2),
                 (hx + hw, hy + hh - 10), (hx + hw - 40, hy + hh), (hx + hw / 2, hy + hh + 6), (hx + 40, hy + hh), (hx, hy + hh - 10), (hx - 18, hy + hh / 2)], t=0.25)
    o.append(f'<path d="{hd}" fill="#000" opacity="0.6" transform="translate(6,10)" {blur_filter(P, 8)}/>')
    o.append(wood_fill(P, hd, hx - 30, hy - 10, hw + 60, hh + 30, "#5a3a24", seed=21))
    o.append(bevel(P, hd, "#b08458", "#0c0603", 4))
    # carved recessed field
    pd = rect(hx + 50, hy + 22, hw - 100, hh - 44, 10)
    o.append(fill(pd, "#2a1a0e", 0.55) + inner_shadow(P, pd, "#000", 0.7, 14, 4))
    o.append(f'<g {clip(P, pd)}>' + lin(pd, "#c8a070", 2, 0.35, extra='transform="translate(2,2)"') + "</g>")
    o.append(lin(pd, "#0c0603", 1.4, 0.9))
    # carved scrolls at the plank ends + iron brackets
    for sx in (1, -1):
        cx = hx + hw / 2 - sx * (hw / 2 - 22)
        o.append(lin(f"M{cx},{hy+hh/2-26} q{-sx*14},{26} 0,{52} M{cx-sx*6},{hy+hh/2-14} q{-sx*8},{14} 0,{28}", "#0c0603", 3, 0.85))
        o.append(lin(f"M{cx+1},{hy+hh/2-25} q{-sx*14},{26} 0,{52}", "#c8a070", 1, 0.35))
        bx = hx + hw / 2 - sx * (hw / 2 - 90)
        o.append(fill(rect(bx - 16, hy + hh - 6, 32, 40, 3), "#2c2824") + lin(rect(bx - 16, hy + hh - 6, 32, 40, 3), "#0c0603", 2))
        o.append(nail(bx, hy + hh + 6, 3.5) + nail(bx, hy + hh + 24, 3.5))
    # small rubric lozenges flanking the field (gothic accent)
    for x in (hx + 74, hx + hw - 74):
        d = poly([(x, hy + hh / 2 - 10), (x + 10, hy + hh / 2), (x, hy + hh / 2 + 10), (x - 10, hy + hh / 2)])
        o.append(fill(d, RUB) + lin(d, "#0c0603", 1.6) + fill(ell(x - 2, hy + hh / 2 - 2, 2), "#e8b48a", 0.8))
    # corner iron brackets on the frame
    for (cx, cy, sx, sy) in [(0, 0, 1, 1), (Wd, 0, -1, 1), (0, Hd, 1, -1), (Wd, Hd, -1, -1)]:
        d = f"M{cx},{cy} h{sx*120} l{-sx*14},{sy*22} h{-sx*84} v{sy*84} l{-sx*22},{sy*14} Z"
        o.append(fill(d, "#2c2824") + fill(d, f"url(#{P.hatch_id})", 0.25) + lin(d, "#0c0603", 2.2))
        o.append(lin(f"M{cx+sx*4},{cy+sy*4} h{sx*108} M{cx+sx*4},{cy+sy*4} v{sy*108}", "#8a8078", 1.2, 0.5))
        o.append(nail(cx + sx * 30, cy + sy * 30, 4.5) + nail(cx + sx * 80, cy + sy * 12, 3.5) + nail(cx + sx * 12, cy + sy * 80, 3.5))
    # candle-light warmth from the lower-left + vignette
    o.append(glow(P, 160, Hd - 80, 700, EMBER, 0.16))
    gid = uid("bv")
    P.defs.append(f'<radialGradient id="{gid}" cx="0.5" cy="0.48" r="0.72"><stop offset="0.55" stop-color="#000" stop-opacity="0"/>'
                  f'<stop offset="1" stop-color="#000" stop-opacity="0.6"/></radialGradient>')
    o.append(fill(rect(0, 0, Wd, Hd), f"url(#{gid})"))
    return J(o)


# ------------------------------------------------------------------ parchment sheets
def deckle(rnd, x, y, w, h, step=7, amp=2.2, tears=2):
    """Rect outline with ragged edges and a couple of small torn notches."""
    pts = []
    tear_at = set(rnd.sample(range(4), min(tears, 4)))
    for side in range(4):
        n = int((w if side % 2 == 0 else h) / step)
        tear = rnd.randint(int(n * 0.25), int(n * 0.75)) if side in tear_at else -99
        for i in range(n):
            t = i / n
            j = rnd.uniform(-amp, amp)
            if abs(i - tear) <= 1:
                j += amp * 3.2 * (1 if abs(i - tear) == 0 else 0.5)
            if side == 0:
                pts.append((x + t * w, y + j + amp))
            elif side == 1:
                pts.append((x + w - j - amp, y + t * h))
            elif side == 2:
                pts.append((x + w - t * w, y + h - j - amp))
            else:
                pts.append((x + j + amp, y + h - t * h))
    return poly(pts)


def parchment_sheet(P, d, x, y, w, h, seed=1, tone="#e6d4a8", burn="#6a4418", foxing=8, shadow=True):
    o = []
    if shadow:
        o.append(f'<path d="{d}" fill="#000" opacity="0.5" transform="translate(4,6)" {blur_filter(P, 5)}/>')
    c = clip(P, d)
    rnd = random.Random(seed)
    fox = " ".join(ell(x + rnd.uniform(0.05, 0.95) * w, y + rnd.uniform(0.05, 0.95) * h, rnd.uniform(1.5, 6)) for _ in range(foxing))
    o.append(f'<g {c}><path d="{d}" fill="{tone}"/>' +
             noise(P, w, h, "#b8965c", 0.9, -0.32, 0.018 * 300 / max(w, 300), seed, 4, x, y) +
             noise(P, w, h, "#f4e8c8", 0.7, -0.3, 0.05, seed + 1, 3, x, y) +
             noise(P, w, h, "#20140c", 1.3, -0.97, 0.6, seed + 2, 2, x, y) +
             fill(fox, "#8a5a28", 0.28, blur_filter(P, 1.5)) +
             f'<path d="{d}" fill="none" stroke="{burn}" stroke-width="{min(w, h)*0.09:.1f}" opacity="0.55" {blur_filter(P, min(w, h)*0.04)}/>' +
             "</g>")
    o.append(lin(d, "#5a3a18", 1.0, 0.7))
    return J(o)


def wanted_sheet(P):
    w, h = 300, 400
    rnd = random.Random(7)
    d = deckle(rnd, 6, 6, w - 14, h - 16, step=6, amp=1.8)
    o = [parchment_sheet(P, d, 6, 6, w - 14, h - 16, seed=7, foxing=10)]
    # a faint fold crease across the middle
    o.append(lin(f"M10,{h*0.52:.0f} Q{w/2},{h*0.52+2:.0f} {w-10},{h*0.52-1:.0f}", "#8a6a3a", 1.0, 0.35))
    o.append(lin(f"M10,{h*0.52+2:.0f} Q{w/2},{h*0.52+4:.0f} {w-10},{h*0.52+1:.0f}", "#fff4d8", 1.0, 0.35))
    return J(o)


def dossier(P):
    Wd, Hd = 1200, 800
    rnd = random.Random(11)
    d = deckle(rnd, 10, 10, Wd - 26, Hd - 28, step=9, amp=2.4, tears=1)
    o = [parchment_sheet(P, d, 10, 10, Wd - 26, Hd - 28, seed=11, tone="#e4d0a2", foxing=26)]
    # ruled margins: double rubric rule left, single ink rules around the text block, faint ruled lines
    o.append(lin("M118,40 V770 M124,40 V770", RUB, 1.2, 0.55))
    o.append(lin(rect(70, 60, Wd - 150, Hd - 120, 1), INK, 1.0, 0.35))
    o.append(lin(" ".join(f"M140,{y} H{Wd-100}" for y in range(150, Hd - 70, 34)), "#6a5a3a", 0.6, 0.18))
    o.append(lin(f"M140,118 H{Wd-100}", INK, 1.6, 0.4) + lin(f"M140,124 H{Wd-100}", INK, 0.6, 0.35))
    # page-gutter shadow on the left (the folio binding) + a faint coffee ring
    o.append(f'<g {clip(P, d)}><rect x="0" y="0" width="60" height="{Hd}" fill="#3a2410" opacity="0.28" {blur_filter(P, 16)}/></g>')
    o.append(lin(ell(Wd - 300, Hd - 150, 46, 42), "#7a5228", 3, 0.12, extra=blur_filter(P, 1.2)))
    # ribbon + wax seal at the top-right corner
    sx, sy = Wd - 96, 96
    for (ang, L) in ((-62, 120), (-30, 110)):
        a = math.radians(ang + 90)
        ex, ey = sx + math.cos(a) * L * 0.4, sy + math.sin(a) * L
        rib = poly([(sx - 9, sy), (sx + 9, sy), (ex + 9, ey), (ex, ey - 12), (ex - 9, ey)])
        o.append(f'<path d="{rib}" fill="#000" opacity="0.35" transform="translate(3,4)" {blur_filter(P, 3)}/>')
        o.append(fill(rib, "#6e1a12") + lin(rib, "#2a0806", 1.2) + lin(f"M{sx-3},{sy} L{ex-3:.1f},{ey-6:.1f}", "#a8402e", 1.4, 0.6))
    o.append(seal_svg(P, sx, sy, 50, seed=4))
    return J(o)


# ------------------------------------------------------------------ seal / pin / marker
def anvil_path(cx, cy, s):
    return (f"M{cx-15*s:.1f},{cy-7*s:.1f} h{26*s:.1f} q{6*s:.1f},0 {9*s:.1f},{-3*s:.1f} q{-1*s:.1f},{5*s:.1f} {-7*s:.1f},{7*s:.1f} "
            f"q{-5*s:.1f},{2*s:.1f} {-7*s:.1f},{5*s:.1f} l{2*s:.1f},{5*s:.1f} h{5*s:.1f} v{3.5*s:.1f} h{-22*s:.1f} v{-3.5*s:.1f} h{5*s:.1f} "
            f"l{2*s:.1f},{-5*s:.1f} q{-5*s:.1f},{-1*s:.1f} {-9*s:.1f},{-5*s:.1f} Z")


def seal_svg(P, cx, cy, r, seed=1):
    rnd = random.Random(seed)
    pts = []
    for i in range(22):
        a = i / 22 * math.tau
        rr = r * (1.0 + rnd.uniform(-0.04, 0.07) + (0.12 if i % 5 == 0 else 0))
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    outer = smooth(pts, t=0.5)
    o = [f'<path d="{outer}" fill="#000" opacity="0.45" transform="translate({r*0.06:.1f},{r*0.1:.1f})" {blur_filter(P, r*0.06)}/>']
    gid = uid("sg")
    P.defs.append(f'<radialGradient id="{gid}" cx="0.38" cy="0.34" r="0.75"><stop offset="0" stop-color="#d04a34"/>'
                  f'<stop offset="0.55" stop-color="#9a2216"/><stop offset="1" stop-color="#4e0c06"/></radialGradient>')
    o.append(fill(outer, f"url(#{gid})") + lin(outer, "#2a0604", r * 0.035))
    # pressed die: recessed ring + raised anvil
    ri = r * 0.68
    o.append(fill(ell(cx, cy, ri), "#7a160c", 0.9))
    o.append(lin(ell(cx + r * 0.02, cy + r * 0.03, ri), "#e8786a", r * 0.035, 0.55))
    o.append(lin(ell(cx - r * 0.02, cy - r * 0.02, ri), "#2a0604", r * 0.04, 0.8))
    o.append(lin(ell(cx, cy, ri * 0.86), "#3a0806", r * 0.02, 0.6, extra=f'stroke-dasharray="{r*0.05:.1f} {r*0.06:.1f}"'))
    s = r / 30
    av = anvil_path(cx, cy + 2 * s, s)
    o.append(fill(av, "#3a0806", 0.8, f'transform="translate({-0.8*s:.1f},{-0.8*s:.1f})"'))
    o.append(fill(av, "#b4382a") + lin(av, "#e8907a", 0.6 * s, 0.6, extra=f'transform="translate({-0.4*s:.1f},{-0.4*s:.1f})"'))
    # wax sheen
    o.append(fill(ell(cx - r * 0.42, cy - r * 0.5, r * 0.22, r * 0.1), "#ffd0c0", 0.35, f'transform="rotate(-35 {cx-r*0.42:.1f} {cy-r*0.5:.1f})"'))
    return J(o)


def wax_seal(P):
    return seal_svg(P, 31, 30, 25, seed=2)


def pin(P):
    c = 15.5
    o = [fill(ell(c + 2.2, c + 3, 10), "#000", 0.45, blur_filter(P, 1.6))]
    gid = uid("pg")
    P.defs.append(f'<radialGradient id="{gid}" cx="0.36" cy="0.32" r="0.8"><stop offset="0" stop-color="#fff2c0"/>'
                  f'<stop offset="0.3" stop-color="#d8b060"/><stop offset="0.75" stop-color="#8a6420"/><stop offset="1" stop-color="#3e2a0c"/></radialGradient>')
    o.append(fill(ell(c, c, 10), f"url(#{gid})") + lin(ell(c, c, 10), "#20140c", 1.4))
    o.append(lin(ell(c, c, 6.5), "#5a3e14", 0.7, 0.5))
    o.append(fill(ell(c - 3.5, c - 4, 2.6, 1.6), "#ffffff", 0.75, f'transform="rotate(-35 {c-3.5} {c-4})"'))
    return J(o)


def map_marker(P):
    c = 24
    o = [lin(ell(c, c, 18), "#000", 6, 0.35, extra=blur_filter(P, 1.5))]
    o.append(lin(ell(c, c, 18), INK, 5.4))
    o.append(lin(ell(c, c, 18), GILT, 3.0))
    o.append(lin(ell(c, c, 18), "#f0d890", 0.9, 0.8, extra='transform="translate(-0.6,-0.6)"'))
    o.append(lin(ell(c, c, 12.5), INK, 3.2))
    o.append(lin(ell(c, c, 12.5), RUB, 1.8))
    for i in range(4):
        a = i * math.pi / 2 - math.pi / 2
        x, y = c + math.cos(a) * 21.5, c + math.sin(a) * 21.5
        px, py = -math.sin(a), math.cos(a)
        d = poly([(x + math.cos(a) * 3.5, y + math.sin(a) * 3.5), (x + px * 3, y + py * 3), (x - math.cos(a) * 3.5, y - math.sin(a) * 3.5), (x - px * 3, y - py * 3)])
        o.append(fill(d, RUB if i == 0 else GILT) + lin(d, INK, 1))
    return J(o)


# ------------------------------------------------------------------ stamps (text)
def stamp_svg(P, word, col, seed, rot):
    Wd, Hd = 220, 80
    fid = uid("ds")
    # distress: knock holes in the ink with thresholded noise + speckle, slight edge wobble
    P.defs.append(f'<filter id="{fid}" x="-5%" y="-5%" width="110%" height="110%">'
                  f'<feTurbulence type="fractalNoise" baseFrequency="0.06" numOctaves="2" seed="{seed}" result="w"/>'
                  f'<feDisplacementMap in="SourceGraphic" in2="w" scale="2.2" xChannelSelector="R" yChannelSelector="G" result="d"/>'
                  f'<feTurbulence type="fractalNoise" baseFrequency="0.22" numOctaves="3" seed="{seed+3}" result="n"/>'
                  f'<feColorMatrix in="n" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  -5 0 0 0 3.45" result="holes"/>'
                  f'<feTurbulence type="fractalNoise" baseFrequency="0.018" numOctaves="2" seed="{seed+5}" result="m"/>'
                  f'<feColorMatrix in="m" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  -3 0 0 0 2.5" result="worn"/>'
                  f'<feComposite in="holes" in2="worn" operator="arithmetic" k1="1" k2="0" k3="0" k4="0" result="keep"/>'
                  f'<feComposite in="d" in2="keep" operator="in"/></filter>')
    body = (f'<g transform="rotate({rot} {Wd/2} {Hd/2})">'
            f'<rect x="14" y="13" width="{Wd-28}" height="{Hd-26}" rx="5" fill="none" stroke="{col}" stroke-width="4.2"/>'
            f'<rect x="21" y="20" width="{Wd-42}" height="{Hd-40}" rx="2" fill="none" stroke="{col}" stroke-width="1.5"/>'
            f'<text x="{Wd/2}" y="{Hd/2+11}" text-anchor="middle" font-family="Grenze" font-weight="800" font-size="37" '
            f'letter-spacing="5" fill="{col}">{word}</text>'
            '</g>')
    return f'<g filter="url(#{fid})" opacity="0.92">{body}</g>'


def stamp_fallen(P):
    return stamp_svg(P, "FALLEN", "#9e1c10", 21, -6)


def stamp_missing(P):
    return stamp_svg(P, "MISSING", "#1e1612", 33, 5)


FONT_CSS = "".join(f"@font-face{{font-family:'Grenze';src:url('file://{FONT_DIR}/grenze-latin-{w}-normal.woff2') format('woff2');font-weight:{w};}}"
                   for w in (600, 700, 800))

ITEMS = dict(wanted_board=(wanted_board, 1600, 900, 1), wanted_sheet=(wanted_sheet, 300, 400, 2), wax_seal=(wax_seal, 64, 64, 4),
             pin=(pin, 32, 32, 4), stamp_fallen=(stamp_fallen, 220, 80, 3), stamp_missing=(stamp_missing, 220, 80, 3),
             map_marker=(map_marker, 48, 48, 4), dossier=(dossier, 1200, 800, 1))
SOFT = {"wanted_board": 1.0, "wanted_sheet": 0.8, "dossier": 1.0}


def jobs():
    only = only_filter()
    js = []
    for name, (fn, Wd, Hd, ss) in ITEMS.items():
        if only and name not in only:
            continue
        P = painter(scale=1.0, lw_mul=0.75)
        body = fn(P)
        if name in SOFT:
            body = f'<g {soft_filter(P, SOFT[name])}>{body}</g>'
        elif name in ("wax_seal", "map_marker"):
            body = f'<g {soft_filter(P, 0.6)}>{body}</g>'
        js.append(dict(name=f"ui_{name}", svg=svg_doc(Wd, Hd, P, body, ss=ss), w=Wd, h=Hd, ss=ss, css=FONT_CSS,
                       out=os.path.join(UI, name + ".png"), transparent=name != "wanted_board"))
    return js


if __name__ == "__main__":
    render(jobs(), workers=3)
