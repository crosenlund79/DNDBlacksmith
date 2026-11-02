"""Shared helpers for Ember & Ash production sprites (Ink & Parchment / Gothic Noir 80:20).

Imports the exploration generator (docs/visual_exploration/_generator) read-only and adds:
 * an extended material palette (rune stone, brew, arcane violet, glass, coal, burgundy cloth ...)
 * a configurable ink filter (wobble / silhouette dilation / soot grain) tuned for small sprites
 * hatched ground shadows, glows, and common building blocks (planks, stone, coals, bottles ...)
 * a batch renderer: SVG -> headless Chromium (Playwright) at 2x -> Lanczos downsample to exact size.
"""
import copy
import json
import math
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(os.path.dirname(HERE))
REPO = os.path.dirname(GAME)
GEN = os.path.join(REPO, "docs", "visual_exploration", "_generator")
EXPL = os.path.join(REPO, "docs", "visual_exploration", "ink_parchment_gothic_80_20")
SPR = os.path.join(GAME, "assets", "sprites")
OUT = os.path.join(HERE, "out")
HTML = os.path.join(OUT, "html")
DATA = os.path.join(GAME, "data")
sys.path.insert(0, GEN)

import svgcore  # noqa: E402
from svgcore import Painter, ell, rect, poly, smooth, blob, wobbly_ell, uid  # noqa: E402,F401
from styles import STYLES  # noqa: E402

ST = copy.deepcopy(STYLES["ink_parchment_gothic_80_20"])
INK = ST["ink"]            # #20140c
PARCH = "#dcc79a"
RUB = ST["rubric"]          # #7e2418
GILT = ST["gilt"]           # #b8923e
EMBER = ST["glow"]          # #e6702a
EMBER_HOT = ST["glow2"]     # #ffc070
SOOT = ST["soot"]
VIOLET = "#8a5cd0"
VIOLET_HOT = "#d2b8ff"
RUNE_GOLD = "#e8d08a"
RUNE_BLUE = "#a8c4dc"
FROST = "#9fd4ec"
BREW = "#7d9a58"
BREW_HOT = "#c4e08c"
SILVER = "#e4e8ec"

ST["pal"].update(
    rune=("#ccd0d0", "#9da4a8", "#565e64"),        # blue-grey runestone
    slate=("#b4b8b8", "#868c8c", "#474c4e"),
    darkiron=("#8e8a84", "#5a5650", "#2c2824"),
    obsidian=("#6a6274", "#3c3644", "#1c1822"),
    coal=("#5a4e46", "#2e2620", "#16100b"),
    brew=("#bcd096", "#7d9a58", "#3c5226"),
    arcane=("#b8a2dc", "#7a58b4", "#36225c"),
    glass=("#eef2ea", "#c8d6cc", "#7a8a84"),
    copper=("#e6a878", "#b46c3e", "#5e3218"),
    bronze=("#dcb878", "#a8803e", "#5a4018"),
    mithril=("#e8f0f4", "#aac0d0", "#566a7c"),
    adamant=("#a8bcae", "#5e7a6a", "#2a3a32"),
    silver=("#f0f0ec", "#c8ccd0", "#767c84"),
    cloth=("#c27a6e", "#7e2418", "#3e0e08"),       # burgundy cloth
    linen=("#f2ead6", "#ddd0b0", "#8e8064"),
    straw=("#f0dc9c", "#d2b464", "#7a6230"),
    clay=("#dcae8c", "#b47a56", "#5e3a24"),
    hide=("#d8b48c", "#a8825a", "#5c4228"),
    brown=("#b08a64", "#7a5636", "#3e2a18"),
    green=("#bcc49a", "#8c9a64", "#4c5834"),
    apple=("#d88a6a", "#a83e26", "#5a1a0c"),
    cabbage=("#c8d4a0", "#98aa6a", "#56643a"),
    wax=("#f6ecd4", "#e8d8b4", "#9a8a68"),
    blue=("#a8b8c8", "#6e86a0", "#38485c"),
    paper=("#f4ead0", "#e6d6b0", "#9a8862"),
    ice=("#e4f4fa", "#9fd4ec", "#4a7e98"),
    burlap=("#e0c89a", "#c0a26e", "#6e5634"),
    redp=("#e8907a", "#b0321e", "#5a120a"),
)


# ------------------------------------------------------------------ painters
def painter(scale=1.0, lw_mul=0.75):
    P = Painter(ST, scale=scale)
    P.lw_mul = lw_mul
    return P


def ink_filter(P, wob=1.2, dil=1.0, grain=1.0, soot=1.0, seed=4):
    """Noir ink treatment, tuned per sprite size (all values in the sprite's user units)."""
    fid = uid("f")
    sc = P.scale
    P.defs.append(f'''<filter id="{fid}" x="-8%" y="-8%" width="116%" height="116%" color-interpolation-filters="sRGB">
  <feTurbulence type="fractalNoise" baseFrequency="{0.06/sc:.4f}" numOctaves="2" seed="{seed}" result="n"/>
  <feDisplacementMap in="SourceGraphic" in2="n" scale="{wob:.2f}" xChannelSelector="R" yChannelSelector="G" result="d"/>
  <feMorphology in="d" operator="dilate" radius="{dil:.2f}" result="dil"/>
  <feFlood flood-color="{INK}"/><feComposite in2="dil" operator="in" result="ol"/>
  <feTurbulence type="fractalNoise" baseFrequency="{0.75/sc:.3f}" numOctaves="2" seed="11" result="grain"/>
  <feColorMatrix in="grain" type="matrix" values="0 0 0 0 0.1  0 0 0 0 0.07  0 0 0 0 0.05  0 0 0 {-1.3*grain:.2f} {0.8*grain:.2f}" result="g2"/>
  <feComposite in="g2" in2="d" operator="in" result="g3"/>
  <feTurbulence type="fractalNoise" baseFrequency="{0.05/sc:.4f}" numOctaves="3" seed="19" result="soot"/>
  <feColorMatrix in="soot" type="matrix" values="0 0 0 0 0.09  0 0 0 0 0.06  0 0 0 0 0.04  0 0 0 {1.15*soot:.2f} {-0.8 - 0.1*(1-soot):.2f}" result="s2"/>
  <feComposite in="s2" in2="d" operator="in" result="s3"/>
  <feMerge><feMergeNode in="ol"/><feMergeNode in="d"/><feMergeNode in="s3"/><feMergeNode in="g3"/></feMerge>
</filter>''')
    return f'filter="url(#{fid})"'


def soft_filter(P, wob=1.0, seed=6):
    fid = uid("sf")
    sc = P.scale
    P.defs.append(f'<filter id="{fid}" x="-5%" y="-5%" width="110%" height="110%">'
                  f'<feTurbulence type="fractalNoise" baseFrequency="{0.06/sc:.4f}" numOctaves="2" seed="{seed}" result="n"/>'
                  f'<feDisplacementMap in="SourceGraphic" in2="n" scale="{wob:.2f}" xChannelSelector="R" yChannelSelector="G"/></filter>')
    return f'filter="url(#{fid})"'


def blur_filter(P, r):
    fid = uid("bl")
    P.defs.append(f'<filter id="{fid}" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="{r:.2f}"/></filter>')
    return f'filter="url(#{fid})"'


def hatch(P, angle=-35, sp=None, w=None, col=INK, op=1.0):
    pid = uid("hp")
    sp = sp or 4.2 * P.scale
    w = w or 0.9 * P.scale
    P.defs.append(f'<pattern id="{pid}" width="{sp:.2f}" height="{sp:.2f}" patternUnits="userSpaceOnUse" '
                  f'patternTransform="rotate({angle})"><line x1="0" y1="0" x2="0" y2="{sp:.2f}" stroke="{col}" '
                  f'stroke-width="{w:.2f}" stroke-opacity="{op}"/></pattern>')
    return f"url(#{pid})"


def ground_shadow(P, d, dx, dy, op=0.55, soft=0.22, blur=None):
    """Hatched + soft ground shadow: the footprint d offset toward bottom-right."""
    blur = blur if blur is not None else max(1.2, abs(dx) * 0.45)
    h = hatch(P, -35, sp=3.6 * P.scale, w=0.95 * P.scale)
    bf = blur_filter(P, blur)
    return (f'<g transform="translate({dx:.1f},{dy:.1f})">'
            f'<path d="{d}" fill="{INK}" opacity="{soft}" {bf}/>'
            f'<path d="{d}" fill="{h}" opacity="{op}"/></g>')


def glow(P, x, y, r, col=EMBER, op=0.6, rx=None, ry=None):
    gid = uid("gl")
    P.defs.append(f'<radialGradient id="{gid}"><stop offset="0" stop-color="{col}" stop-opacity="{op}"/>'
                  f'<stop offset="0.45" stop-color="{col}" stop-opacity="{op*0.4:.3f}"/>'
                  f'<stop offset="1" stop-color="{col}" stop-opacity="0"/></radialGradient>')
    rx = rx or r
    ry = ry or r
    return f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="url(#{gid})"/>'


def lin(d, col=INK, w=1.0, op=1.0, cap="round", extra=""):
    return (f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w:.2f}" stroke-linecap="{cap}" '
            f'stroke-linejoin="round" opacity="{op}" {extra}/>')


def fill(d, col, op=1.0, extra=""):
    return f'<path d="{d}" fill="{col}" opacity="{op}" {extra}/>'


def svg_doc(w, h, P, body, ss=2, vw=None, vh=None, bg=None):
    vw = vw or w
    vh = vh or h
    b = f'<rect width="{vw}" height="{vh}" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{w*ss}" height="{h*ss}" '
            f'viewBox="0 0 {vw} {vh}">{P.defs_svg()}{b}{body}</svg>')


def sprite_svg(P, w, h, shadow="", body="", emit="", ss=2, wob=1.1, dil=0.9, grain=1.0, soot=1.0, vw=None, vh=None, seed=4):
    f = ink_filter(P, wob=wob, dil=dil, grain=grain, soot=soot, seed=seed)
    inner = f'<g>{shadow}</g><g {f}>{body}</g><g>{emit}</g>'
    return svg_doc(w, h, P, inner, ss=ss, vw=vw, vh=vh)


# ------------------------------------------------------------------ building blocks
def jit(rnd, a):
    return rnd.uniform(-a, a)


def planks(P, x, y, w, h, role="wood", n=None, dirn="h", s=3, r=2, nails=True, seed=1, gap_op=0.85):
    """Rectangle of planks (dirn h: planks run horizontally)."""
    rnd = random.Random(seed)
    o = [P.shape(rect(x, y, w, h, r), role, s=s)]
    segs = []
    if dirn == "h":
        n = n or max(2, int(h // 9))
        for i in range(1, n):
            yy = y + h * i / n + jit(rnd, 0.4)
            segs.append(f"M{x+1.5:.1f},{yy:.1f} L{x+w-1.5:.1f},{yy:.1f}")
        # grain + butt joints
        for i in range(n):
            y0 = y + h * (i + 0.5) / n
            xx = x + rnd.uniform(0.25, 0.75) * w
            segs.append(f"M{xx:.1f},{y0 - h/n/2 + 0.8:.1f} L{xx:.1f},{y0 + h/n/2 - 0.8:.1f}")
    else:
        n = n or max(2, int(w // 9))
        for i in range(1, n):
            xx = x + w * i / n + jit(rnd, 0.4)
            segs.append(f"M{xx:.1f},{y+1.5:.1f} L{xx:.1f},{y+h-1.5:.1f}")
        for i in range(n):
            x0 = x + w * (i + 0.5) / n
            yy = y + rnd.uniform(0.25, 0.75) * h
            segs.append(f"M{x0 - w/n/2 + 0.8:.1f},{yy:.1f} L{x0 + w/n/2 - 0.8:.1f},{yy:.1f}")
    o.append(P.detail(" ".join(segs), role, 0.55, gap_op))
    # grain hairlines
    g = []
    for i in range(int((w * h) / 260) + 1):
        if dirn == "h":
            gx, gy = x + rnd.uniform(0.08, 0.7) * w, y + rnd.uniform(0.1, 0.9) * h
            g.append(f"M{gx:.1f},{gy:.1f} q{w*0.08:.1f},{jit(rnd,0.8):.1f} {w*rnd.uniform(0.12,0.25):.1f},0")
        else:
            gx, gy = x + rnd.uniform(0.1, 0.9) * w, y + rnd.uniform(0.08, 0.7) * h
            g.append(f"M{gx:.1f},{gy:.1f} q{jit(rnd,0.8):.1f},{h*0.08:.1f} 0,{h*rnd.uniform(0.12,0.25):.1f}")
    o.append(P.detail(" ".join(g), role, 0.3, 0.45))
    if nails:
        d = []
        if dirn == "h":
            for i in range(n):
                yy = y + h * (i + 0.5) / n
                d += [ell(x + 3, yy, 0.7), ell(x + w - 3, yy, 0.7)]
        else:
            for i in range(n):
                xx = x + w * (i + 0.5) / n
                d += [ell(xx, y + 3, 0.7), ell(xx, y + h - 3, 0.7)]
        o.append(fill(" ".join(d), INK, 0.8))
    return "\n".join(o)


def end_grain(P, cx, cy, r, role="wood", seed=1):
    o = [P.shape(wobbly_ell(cx, cy, r, r, seed, 0.05), role, s=r * 0.18)]
    rings = " ".join(wobbly_ell(cx + 0.5, cy + 0.3, r * k, r * k * 0.98, seed + i, 0.06) for i, k in enumerate((0.75, 0.5, 0.26)))
    o.append(P.detail(rings, role, 0.35, 0.6))
    o.append(P.detail(f"M{cx+r*0.15:.1f},{cy-r*0.2:.1f} L{cx+r*0.72:.1f},{cy-r*0.6:.1f}", role, 0.45, 0.7))
    return "\n".join(o)


def stones_ring(P, cx, cy, rx, ry, n=10, size=0.28, role="stone", seed=3):
    """Ring of rounded stones (hearth / fire ring / well)."""
    rnd = random.Random(seed)
    o = []
    for i in range(n):
        a = i / n * math.tau + jit(rnd, 0.1)
        x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry
        r = min(rx, ry) * size * rnd.uniform(0.85, 1.1)
        o.append(P.shape(blob(x, y, r, 5, 0.12, seed + i, rot=a), role, s=r * 0.3))
    return "\n".join(o)


def coals(P, cx, cy, rx, ry, seed=2, hot=1.0, n=None):
    """Glowing coal bed: returns (body, emit)."""
    rnd = random.Random(seed)
    body = [P.shape(wobbly_ell(cx, cy, rx, ry, seed, 0.08), "coal", s=min(rx, ry) * 0.15)]
    n = n or int(rx * ry / 16) + 6
    lumps = []
    for i in range(n):
        a = rnd.uniform(0, math.tau)
        rr = math.sqrt(rnd.uniform(0, 1))
        x, y = cx + math.cos(a) * rx * 0.85 * rr, cy + math.sin(a) * ry * 0.85 * rr
        r = rnd.uniform(1.6, 3.4) * min(1.6, max(0.8, rx / 20))
        lumps.append((x, y, r, rr))
    lp = " ".join(wobbly_ell(x, y, r, r * 0.8, i, 0.18, 7) for i, (x, y, r, rr) in enumerate(lumps))
    body.append(fill(lp, "#2a201a", 0.9))
    body.append(lin(lp, INK, 0.5, 0.8))
    emit = [glow(P, cx, cy, 0, EMBER, 0.55 * hot, rx=rx * 1.25, ry=ry * 1.25)]
    hotd, warm = [], []
    for i, (x, y, r, rr) in enumerate(lumps):
        if rr < 0.75 or i % 3 == 0:
            (hotd if rr < 0.45 else warm).append(wobbly_ell(x - r * 0.15, y - r * 0.15, r * 0.6, r * 0.5, i + 50, 0.2, 7))
    emit.append(glow(P, cx, cy, 0, EMBER, 0.45 * hot, rx=rx * 0.85, ry=ry * 0.85))
    emit.append(fill(" ".join(warm), EMBER, 0.85 * hot))
    emit.append(fill(" ".join(hotd), EMBER_HOT, 0.95 * hot))
    emit.append(glow(P, cx, cy, 0, EMBER_HOT, 0.45 * hot, rx=rx * 0.55, ry=ry * 0.55))
    return "\n".join(body), "\n".join(emit)


def liquid(P, d, role, cx, cy, rx, ry, ripples=2, sheen=True, op=1.0):
    l, b, s = ST["pal"][role]
    o = [fill(d, b, op)]
    cid = uid("lc")
    P.defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
    inner = [P._crescent(d, -rx * 0.18, -ry * 0.18, s, 0.55)]
    for i in range(ripples):
        k = 0.35 + i * 0.25
        inner.append(lin(f"M{cx - rx*k:.1f},{cy - ry*0.1 + i*ry*0.25:.1f} q{rx*k*0.5:.1f},{-ry*0.12:.1f} {rx*k:.1f},0",
                         l, max(0.6, rx * 0.04), 0.8))
    if sheen:
        inner.append(fill(ell(cx - rx * 0.35, cy - ry * 0.35, rx * 0.22, ry * 0.12), "#ffffff", 0.35))
    o.append(f'<g clip-path="url(#{cid})">' + "".join(inner) + "</g>")
    return "\n".join(o)


def bottle_top(P, cx, cy, r, liq="brew", cork=True, role="glass"):
    """Bottle seen from above: glass body ring, liquid tint, neck + cork."""
    o = [P.shape(ell(cx, cy, r), role, s=r * 0.2)]
    o.append(fill(ell(cx + r * 0.05, cy + r * 0.05, r * 0.72), ST["pal"][liq][1], 0.85))
    o.append(fill(ell(cx + r * 0.25, cy + r * 0.25, r * 0.42), ST["pal"][liq][2], 0.35))
    o.append(P.shape(ell(cx, cy, r * 0.42), role, s=1, hl=False, lw=0.6))
    if cork:
        o.append(P.shape(ell(cx, cy, r * 0.3), "wood", s=0.8, lw=0.5))
    o.append(fill(ell(cx - r * 0.45, cy - r * 0.45, r * 0.18, r * 0.12), "#ffffff", 0.6))
    return "\n".join(o)


def rune_glyphs(rnd, x, y, s, n=1):
    """Angular futhark-like glyph strokes (path data) centred at x,y size s."""
    shapes = [
        lambda x, y, s: f"M{x},{y-s} L{x},{y+s} M{x},{y-s*0.4} L{x+s*0.6},{y-s} M{x},{y} L{x+s*0.6},{y-s*0.4}",
        lambda x, y, s: f"M{x-s*0.3},{y+s} L{x-s*0.3},{y-s} L{x+s*0.4},{y-s*0.3} L{x-s*0.3},{y+s*0.2}",
        lambda x, y, s: f"M{x},{y-s} L{x},{y+s} M{x-s*0.6},{y-s*0.5} L{x+s*0.6},{y+s*0.1}",
        lambda x, y, s: f"M{x-s*0.5},{y+s} L{x},{y-s} L{x+s*0.5},{y+s} M{x-s*0.25},{y+s*0.1} L{x+s*0.25},{y+s*0.1}",
        lambda x, y, s: f"M{x-s*0.5},{y-s} L{x+s*0.5},{y+s} M{x+s*0.5},{y-s} L{x-s*0.5},{y+s}",
        lambda x, y, s: f"M{x},{y-s} L{x},{y+s} M{x-s*0.55},{y-s*0.55} L{x},{y} L{x+s*0.55},{y-s*0.55}",
        lambda x, y, s: f"M{x-s*0.5},{y-s} L{x+s*0.5},{y} L{x-s*0.5},{y+s}",
        lambda x, y, s: f"M{x-s*0.45},{y-s} L{x-s*0.45},{y+s} M{x+s*0.45},{y-s} L{x+s*0.45},{y+s} M{x-s*0.45},{y-s*0.3} L{x+s*0.45},{y+s*0.3}",
    ]
    out = []
    for i in range(n):
        out.append(rnd.choice(shapes)(x + i * s * 1.6, y, s))
    return " ".join(out)


def lit_marks(P, d, col, core, w=1.0, glow_w=3.0, op=0.85, blur=1.4):
    """Glowing engraved marks: blurred glow + bright core (emit layer)."""
    bf = blur_filter(P, blur)
    return (f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{glow_w:.2f}" opacity="{op*0.6:.2f}" '
            f'stroke-linecap="round" stroke-linejoin="round" {bf}/>' +
            lin(d, core, w, op))


def candle_top(P, cx, cy, r=3.2, flame=True):
    body = [P.shape(ell(cx, cy, r), "wax", s=r * 0.25, lw=0.8)]
    body.append(fill(ell(cx + r * 0.2, cy + r * 0.2, r * 0.45), "#c8b48c", 0.5))
    emit = []
    if flame:
        emit.append(glow(P, cx, cy, r * 5, EMBER_HOT, 0.45))
        emit.append(fill(smooth([(cx, cy - r * 1.1), (cx + r * 0.5, cy), (cx, cy + r * 0.5), (cx - r * 0.5, cy)]), "#ffe2a0", 0.95))
    return "\n".join(body), "\n".join(emit)


def sigil_ring(P, cx, cy, r, col=VIOLET, core=VIOLET_HOT, seed=5, n=10, w=1.0, ticks=True):
    """Arcane ring with glyphs (path data for emit)."""
    rnd = random.Random(seed)
    d = [ell(cx, cy, r), ell(cx, cy, r * 0.82)]
    gl = []
    for i in range(n):
        a = i / n * math.tau
        x, y = cx + math.cos(a) * r * 0.91, cy + math.sin(a) * r * 0.91
        gl.append(rune_glyphs(rnd, x, y, r * 0.055))
    if ticks:
        for i in range(n * 2):
            a = (i + 0.5) / (n * 2) * math.tau
            d.append(f"M{cx+math.cos(a)*r*0.82:.1f},{cy+math.sin(a)*r*0.82:.1f} L{cx+math.cos(a)*r*0.76:.1f},{cy+math.sin(a)*r*0.76:.1f}")
    return " ".join(d), " ".join(gl)


# ------------------------------------------------------------------ render
def write_html(name, svg, w, h, ss=2, css=""):
    os.makedirs(HTML, exist_ok=True)
    p = os.path.join(HTML, name.replace("/", "__") + ".html")
    with open(p, "w") as f:
        f.write(f"<!doctype html><html><head><meta charset='utf-8'><style>{css}html,body{{margin:0;padding:0;background:transparent;"
                f"width:{w*ss}px;height:{h*ss}px;overflow:hidden}} svg{{display:block}}</style></head><body>{svg}</body></html>")
    return p


def render(jobs, workers=4):
    """jobs: list of dict(name, html|svg, w, h, ss, out, transparent=True, wrap=False).
    Renders at w*ss x h*ss, then Lanczos-downsamples to exactly w x h."""
    from PIL import Image
    tmp = os.path.join(OUT, "raw")
    os.makedirs(tmp, exist_ok=True)
    rj = []
    for j in jobs:
        ss = j.get("ss", 2)
        if "html" not in j:
            j["html"] = write_html(j["name"], j["svg"], j["w"], j["h"], ss, j.get("css", ""))
        j["raw"] = os.path.join(tmp, j["name"].replace("/", "__") + ".png")
        rj.append(dict(html=j["html"], png=j["raw"], w=j["w"] * ss, h=j["h"] * ss, transparent=j.get("transparent", True)))
    jf = os.path.join(OUT, "jobs_%d.json" % os.getpid())
    with open(jf, "w") as f:
        json.dump(rj, f)
    subprocess.run(["node", os.path.join(HERE, "render.js"), jf, str(workers)], check=True)
    for j in jobs:
        im = Image.open(j["raw"]).convert("RGBA")
        W, H = j["w"], j["h"]
        if im.size != (W, H):
            if j.get("wrap"):
                big = Image.new("RGBA", (im.width * 3, im.height * 3))
                for a in range(3):
                    for b in range(3):
                        big.paste(im, (a * im.width, b * im.height))
                big = big.resize((W * 3, H * 3), Image.LANCZOS)
                im = big.crop((W, H, 2 * W, 2 * H))
            else:
                im = premult_resize(im, (W, H))
        os.makedirs(os.path.dirname(j["out"]), exist_ok=True)
        if j.get("transparent", True) is False:
            im = im.convert("RGB")
        im.save(j["out"], optimize=True)
    print(f"saved {len(jobs)} images")


def premult_resize(im, size):
    """Lanczos downsample with premultiplied alpha (no dark/light fringes)."""
    import numpy as np
    from PIL import Image
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb = a[..., :3] * a[..., 3:4]
    chans = [Image.fromarray(rgb[..., i]).resize(size, Image.LANCZOS) for i in range(3)]
    al = Image.fromarray(a[..., 3]).resize(size, Image.LANCZOS)
    al_n = np.clip(np.asarray(al), 0, 1)
    out = np.zeros((size[1], size[0], 4), np.float32)
    for i in range(3):
        c = np.asarray(chans[i])
        out[..., i] = np.where(al_n > 1e-4, c / np.maximum(al_n, 1e-4), 0)
    out[..., 3] = al_n
    return Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def load(name):
    with open(os.path.join(DATA, name)) as f:
        return json.load(f)


def only_filter():
    """--only=a,b CLI filter."""
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            return set(a.split("=", 1)[1].split(","))
    return None
