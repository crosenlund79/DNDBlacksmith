"""UI art: 9-slice panels/buttons, slots, tooltip, divider, corner ornament, dice, skill-check ring,
menu background (80:20 ledger, no text) and a burnt-edge vignette overlay.
python3 make_ui.py [--only=panel_parchment,menu_background]"""
import math
import os
import random
import re
from artlib import (painter, svg_doc, ink_filter, soft_filter, glow, lin, fill, render, only_filter, ell, rect, poly,
                    smooth, blob, ST, INK, EMBER, EMBER_HOT, RUB, GILT, SPR, SOOT, PARCH, blur_filter, hatch, uid,
                    rune_glyphs, write_html, EXPL, GEN)

PAL = ST["pal"]
UI = os.path.join(SPR, "ui")
LEATHER = "#2a1c12"


def noise(P, w, h, col, slope, off, freq, seed, octaves=4, x=0, y=0, stitch=False):
    fid = uid("un")
    r, g, b = [int(col[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    P.defs.append(f'<filter id="{fid}" filterUnits="userSpaceOnUse" x="{x}" y="{y}" width="{w}" height="{h}">'
                  f'<feTurbulence type="fractalNoise" baseFrequency="{freq}" numOctaves="{octaves}" seed="{seed}"'
                  f'{" stitchTiles=\"stitch\"" if stitch else ""}/>'
                  f'<feColorMatrix values="0 0 0 0 {r:.3f}  0 0 0 0 {g:.3f}  0 0 0 0 {b:.3f}  {slope} 0 0 0 {off}"/></filter>')
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" filter="url(#{fid})"/>'


def edge_burn(P, x, y, w, h, col, op, depth, rx=6):
    """Darkening toward the edges of a rect (inner vignette via blurred stroke, clipped)."""
    cid = uid("ec")
    P.defs.append(f'<clipPath id="{cid}"><path d="{rect(x, y, w, h, rx)}"/></clipPath>')
    bf = blur_filter(P, depth * 0.45)
    return (f'<g clip-path="url(#{cid})"><path d="{rect(x, y, w, h, rx)}" fill="none" stroke="{col}" stroke-width="{depth*1.4:.1f}" '
            f'opacity="{op}" {bf}/></g>')


def parchment_fill(P, x, y, w, h, rx, seed=1, tone=PARCH, burn=0.55, depth=26):
    o = [fill(rect(x, y, w, h, rx), tone)]
    cid = uid("pc")
    P.defs.append(f'<clipPath id="{cid}"><path d="{rect(x, y, w, h, rx)}"/></clipPath>')
    o.append(f'<g clip-path="url(#{cid})">' +
             noise(P, w, h, "#b8965c", 0.9, -0.3, 0.02, seed, 4, x, y) +
             noise(P, w, h, "#efe0b8", 0.7, -0.3, 0.05, seed + 1, 3, x, y) +
             noise(P, w, h, "#20140c", 1.4, -0.98, 0.6, seed + 2, 2, x, y) + "</g>")
    o.append(edge_burn(P, x, y, w, h, "#5a3a18", burn, depth, rx))
    return "\n".join(o)


# ------------------------------------------------------------------ panels
def corner_flourish(x, y, sx, sy, col=INK, w=1.4):
    d = (f"M{x+sx*6},{y+sy*22} Q{x+sx*6},{y+sy*6} {x+sx*22},{y+sy*6} "
         f"M{x+sx*11},{y+sy*22} Q{x+sx*11},{y+sy*11} {x+sx*22},{y+sy*11}")
    return lin(d, col, w, 0.85) + fill(ell(x + sx * 15, y + sy * 15, 2), col, 0.9)


def panel_parchment(P):
    W = 256
    o = [parchment_fill(P, 2, 2, W - 4, W - 4, 6, seed=3, burn=0.6, depth=30)]
    o.append(lin(rect(10, 10, W - 20, W - 20, 3), INK, 3.2))
    o.append(lin(rect(17, 17, W - 34, W - 34, 2), INK, 1.2))
    o.append(lin(rect(20, 20, W - 40, W - 40, 1), GILT, 0.9, 0.7))
    for (x, y, sx, sy) in [(17, 17, 1, 1), (W - 17, 17, -1, 1), (17, W - 17, 1, -1), (W - 17, W - 17, -1, -1)]:
        o.append(corner_flourish(x, y, sx, sy))
        o.append(fill(poly([(x - sx * 7 + sx * 7, y - sy * 7), (x + sx * 0, y), (x - sx * 7 + sx * 7, y + sy * 7 - sy * 7)]), INK))
        cx, cy = x - sx * 7 + sx * 0.5, y - sy * 7 + sy * 0.5
        o.append(fill(poly([(cx, cy - 4.5), (cx + 4.5, cy), (cx, cy + 4.5), (cx - 4.5, cy)]), RUB))
    o.append(lin(rect(2, 2, W - 4, W - 4, 6), INK, 1.6, 0.8))
    return "\n".join(o)


def dark_fill(P, x, y, w, h, rx, seed=1):
    o = [fill(rect(x, y, w, h, rx), LEATHER)]
    cid = uid("dc")
    P.defs.append(f'<clipPath id="{cid}"><path d="{rect(x, y, w, h, rx)}"/></clipPath>')
    o.append(f'<g clip-path="url(#{cid})">' +
             noise(P, w, h, "#5a3e26", 0.9, -0.28, 0.035, seed, 4, x, y) +
             noise(P, w, h, "#000000", 1.6, -0.9, 0.5, seed + 1, 2, x, y) +
             noise(P, w, h, "#e6702a", 0.5, -0.25, 0.01, seed + 2, 2, x, y) + "</g>")
    o.append(edge_burn(P, x, y, w, h, "#000000", 0.7, 22, rx))
    return "\n".join(o)


def panel_dark(P):
    W = 256
    o = [dark_fill(P, 2, 2, W - 4, W - 4, 6, seed=5)]
    o.append(lin(rect(2, 2, W - 4, W - 4, 6), "#0e0805", 3))
    o.append(lin(rect(12, 12, W - 24, W - 24, 2), GILT, 1.2, 0.95))
    o.append(lin(rect(16, 16, W - 32, W - 32, 1), GILT, 0.6, 0.45))
    for (x, y) in [(12, 12), (W - 12, 12), (12, W - 12), (W - 12, W - 12)]:
        o.append(fill(ell(x, y, 4.5), GILT))
        o.append(lin(ell(x, y, 4.5), "#0e0805", 1.2))
        o.append(fill(ell(x - 1.2, y - 1.2, 1.4), "#f0d890", 0.8))
    for (x, y, sx, sy) in [(16, 16, 1, 1), (W - 16, 16, -1, 1), (16, W - 16, 1, -1), (W - 16, W - 16, -1, -1)]:
        o.append(corner_flourish(x, y, sx, sy, GILT, 1.1))
    return "\n".join(o)


def tooltip_bg(P):
    W = 128
    o = [dark_fill(P, 2, 2, W - 4, W - 4, 5, seed=9)]
    o.append(lin(rect(2, 2, W - 4, W - 4, 5), "#0e0805", 2.4))
    o.append(lin(rect(8, 8, W - 16, W - 16, 2), GILT, 1.0, 0.9))
    for (x, y) in [(8, 8), (W - 8, 8), (8, W - 8), (W - 8, W - 8)]:
        o.append(fill(poly([(x, y - 3.5), (x + 3.5, y), (x, y + 3.5), (x - 3.5, y)]), GILT))
    return "\n".join(o)


def button(P, state):
    W, H = 192, 56
    tone = {"normal": PARCH, "hover": "#e6cf9c", "pressed": "#b89a66", "disabled": "#d4c6a6"}[state]
    o = []
    if state == "pressed":
        o.append(parchment_fill(P, 2, 3, W - 4, H - 5, 4, seed=21, tone=tone, burn=0.75, depth=16))
        o.append(edge_burn(P, 2, 3, W - 4, H - 5, "#20140c", 0.5, 8, 4))
    else:
        o.append(parchment_fill(P, 2, 2, W - 4, H - 5, 4, seed=21, tone=tone, burn=0.5 if state != "disabled" else 0.25, depth=16))
    if state == "hover":
        o.append(glow(P, W / 2, H / 2, 0, EMBER, 0.24, rx=W * 0.6, ry=H * 0.9))
        o.append(edge_burn(P, 2, 2, W - 4, H - 5, EMBER, 0.45, 9, 4))
    border = {"normal": INK, "hover": "#5a1e10", "pressed": INK, "disabled": "#8a7a62"}[state]
    o.append(lin(rect(2, 2 if state != "pressed" else 3, W - 4, H - 5, 4), border, 2.6))
    inner = GILT if state != "disabled" else "#b8a888"
    o.append(lin(rect(7, 7 if state != "pressed" else 8, W - 14, H - 15, 2), inner if state == "hover" else INK, 0.9, 0.7 if state != "disabled" else 0.4))
    if state == "hover":
        o.append(lin(rect(2, 2, W - 4, H - 5, 4), EMBER, 1.0, 0.8))
    # small end diamonds (inside the 18 px 9-slice margin)
    cy = H / 2 - 1 + (1 if state == "pressed" else 0)
    dcol = {"normal": RUB, "hover": EMBER, "pressed": RUB, "disabled": "#a89a80"}[state]
    for x in (11, W - 11):
        o.append(fill(poly([(x, cy - 4), (x + 4, cy), (x, cy + 4), (x - 4, cy)]), dcol))
    if state != "pressed":
        o.append(fill(rect(4, H - 4, W - 8, 3, 1.5), "#20140c", 0.25, blur_filter(P, 1.2)))
    return "\n".join(o)


def slot(P, sel=False):
    W = 72
    o = []
    if sel:
        o.append(glow(P, W / 2, W / 2, 0, EMBER, 0.0, rx=1, ry=1))
        o.append(f'<path d="{rect(3, 3, W - 6, W - 6, 4)}" fill="none" stroke="{EMBER}" stroke-width="7" opacity="0.55" {blur_filter(P, 3)}/>')
    # faint inset shading (the centre stays transparent)
    o.append(f'<path d="{rect(5, 5, W - 10, W - 10, 3)}" fill="none" stroke="#20140c" stroke-width="5" opacity="0.18" {blur_filter(P, 2)}/>')
    col = RUB if sel else INK
    o.append(lin(rect(3, 3, W - 6, W - 6, 4), col, 3.0 if sel else 2.4))
    o.append(lin(rect(8, 8, W - 16, W - 16, 2), GILT if sel else INK, 1.1 if sel else 0.8, 0.9 if sel else 0.45))
    for (x, y, sx, sy) in [(3, 3, 1, 1), (W - 3, 3, -1, 1), (3, W - 3, 1, -1), (W - 3, W - 3, -1, -1)]:
        o.append(lin(f"M{x+sx*2},{y+sy*13} L{x+sx*2},{y+sy*2} L{x+sx*13},{y+sy*2}", GILT if sel else INK, 2.6 if sel else 2.0))
    if sel:
        for x, y in [(W / 2, 3), (W / 2, W - 3)]:
            o.append(fill(poly([(x, y - 4), (x + 4, y), (x, y + 4), (x - 4, y)]), EMBER_HOT))
            o.append(lin(poly([(x, y - 4), (x + 4, y), (x, y + 4), (x - 4, y)]), INK, 1))
    return "\n".join(o)


def slot_select(P):
    return slot(P, True)


def divider(P):
    W, H = 512, 24
    cy = 12
    o = []
    gid = uid("dg")
    P.defs.append(f'<linearGradient id="{gid}" x1="0" x2="1"><stop offset="0" stop-color="{INK}" stop-opacity="0"/>'
                  f'<stop offset="0.18" stop-color="{INK}" stop-opacity="1"/><stop offset="0.82" stop-color="{INK}" stop-opacity="1"/>'
                  f'<stop offset="1" stop-color="{INK}" stop-opacity="0"/></linearGradient>')
    o.append(f'<path d="M8,{cy} L232,{cy-1.4} L232,{cy+1.4} Z M504,{cy} L280,{cy-1.4} L280,{cy+1.4} Z" fill="url(#{gid})"/>')
    o.append(f'<path d="M40,{cy+5} L226,{cy+4.4} M472,{cy+5} L286,{cy+4.4}" stroke="url(#{gid})" stroke-width="0.8" opacity="0.7"/>')
    o.append(lin(f"M232,{cy} q6,-8 14,-6 M280,{cy} q-6,-8 -14,-6 M232,{cy} q6,8 14,6 M280,{cy} q-6,8 -14,6", INK, 1.4))
    o.append(fill(poly([(256, cy - 9), (265, cy), (256, cy + 9), (247, cy)]), RUB))
    o.append(lin(poly([(256, cy - 9), (265, cy), (256, cy + 9), (247, cy)]), INK, 1.4))
    o.append(fill(ell(256, cy, 2), "#e8b48a"))
    for x in (238, 274):
        o.append(fill(ell(x, cy, 1.8), GILT))
    return "\n".join(o)


def corner_ornament(P):
    """96x96 top-left corner (flip in code for other corners): dark iron L-bracket + gilt leaves."""
    o = []
    o.append(lin("M6,90 L6,6 L90,6", "#0e0805", 9))
    o.append(lin("M6,90 L6,6 L90,6", "#4a4440", 5.5))
    o.append(lin("M6,90 L6,6 L90,6", "#7a746c", 1.2, 0.7))
    o.append(lin("M18,72 L18,18 L72,18", INK, 3))
    o.append(lin("M18,72 L18,18 L72,18", GILT, 1, 0.7))
    o.append(fill("M24,24 q26,0 34,26 q-26,-5 -34,-26 Z M24,24 q0,26 26,34 q-5,-26 -26,-34 Z", GILT, 0.92))
    o.append(lin("M24,24 q26,0 34,26 q-26,-5 -34,-26 Z M24,24 q0,26 26,34 q-5,-26 -26,-34 Z M26,26 L48,40 M26,26 L40,48", INK, 1.1, 0.9))
    o.append(fill(ell(8, 8, 7.5), GILT))
    o.append(lin(ell(8, 8, 7.5), "#0e0805", 1.8))
    o.append(fill(ell(6, 6, 2.5), "#f4dc98", 0.85))
    for x, y in [(6, 90), (90, 6)]:
        o.append(fill(poly([(x, y - 5), (x + 5, y), (x, y + 5), (x - 5, y)]), GILT))
        o.append(lin(poly([(x, y - 5), (x + 5, y), (x, y + 5), (x - 5, y)]), "#0e0805", 1.2))
    return "\n".join(o)


# ------------------------------------------------------------------ dice (top-down faces, no numbers)
BONE = ("#f6ecd4", "#e4d4b0", "#9a8662")


def die_face(P, outer, facets, seed):
    PAL.setdefault("bone", BONE)
    o = [P.shape(outer, "bone", s=6, lw=3.2)]
    o.append(lin(facets, INK, 1.8, 0.85))
    return "\n".join(o)


def regular(n, cx, cy, r, rot=-math.pi / 2):
    return [(cx + r * math.cos(rot + i * math.tau / n), cy + r * math.sin(rot + i * math.tau / n)) for i in range(n)]


def dice_d20(P):
    hexo = regular(6, 48, 48, 42, -math.pi / 2)
    tri = regular(3, 48, 50, 24, -math.pi / 2)
    f = [poly(tri)]
    # connect triangle vertices to hexagon vertices
    for i, t in enumerate(tri):
        for j in (2 * i - 1, 2 * i, 2 * i + 1):
            h = hexo[j % 6]
            f.append(f"M{t[0]:.1f},{t[1]:.1f} L{h[0]:.1f},{h[1]:.1f}")
    o = [die_face(P, poly(hexo), " ".join(f), 1)]
    o.append(fill(poly(tri), "#ffffff", 0.25))
    o.append(fill(poly([hexo[2], hexo[3], tri[1]]) + " " + poly([hexo[3], hexo[4], tri[2]]), f"url(#{P.hatch_id})", 0.45))
    return "\n".join(o)


def dice_d12(P):
    outer = regular(10, 48, 48, 42, -math.pi / 2)
    pent = regular(5, 48, 49, 20, -math.pi / 2)
    f = [poly(pent)]
    for i, p in enumerate(pent):
        q = outer[(2 * i) % 10]
        f.append(f"M{p[0]:.1f},{p[1]:.1f} L{q[0]:.1f},{q[1]:.1f}")
    o = [die_face(P, poly(outer), " ".join(f), 2)]
    o.append(fill(poly(pent), "#ffffff", 0.25))
    o.append(fill(poly([pent[1], outer[2], outer[3], outer[4], pent[2]]) + " " + poly([pent[2], outer[4], outer[5], outer[6], pent[3]]), f"url(#{P.hatch_id})", 0.4))
    return "\n".join(o)


def dice_d6(P):
    o = [die_face(P, rect(10, 10, 76, 76, 14), rect(20, 20, 56, 56, 9), 3)]
    o.append(fill(rect(20, 20, 56, 56, 9), "#ffffff", 0.22))
    o.append(fill(f"M86,24 L86,72 Q86,86 72,86 L24,86 L20,76 Q20,76 76,76 L76,20 Z", f"url(#{P.hatch_id})", 0.45))
    return "\n".join(o)


# ------------------------------------------------------------------ skill-check ring (384, transparent centre)
def skillcheck_ring(P):
    c = 192
    o = []
    # game draws the track at r~133-148 (texture px); the frame sits outside (r 154-186) with a thin inner rim (r 118-126)
    ring = ell(c, c, 186) + " " + ell(c, c, 154)
    o.append(f'<path d="{ring}" fill-rule="evenodd" fill="#3a3430"/>')
    o.append(f'<path d="{ring}" fill-rule="evenodd" fill="url(#{P.hatch_id})" opacity="0.5"/>')
    o.append(lin(ell(c, c, 186), "#0e0805", 4))
    o.append(lin(ell(c, c, 154), "#0e0805", 3))
    o.append(lin(ell(c, c, 180), GILT, 1.4, 0.95))
    o.append(lin(ell(c, c, 160), GILT, 1.0, 0.8))
    o.append(lin(ell(c - 0.8, c - 0.8, 184), "#8a8078", 1.0, 0.6))
    # ticks + runes in the band
    t = " ".join(f"M{c+160*math.cos(a):.1f},{c+160*math.sin(a):.1f} L{c+166*math.cos(a):.1f},{c+166*math.sin(a):.1f}" for a in [i * math.tau / 72 for i in range(72)])
    o.append(lin(t, GILT, 1.0, 0.8))
    rnd = random.Random(4)
    g = " ".join(rune_glyphs(rnd, c + 172 * math.cos(a), c + 172 * math.sin(a), 4.2) for a in [(i + 0.5) * math.tau / 24 for i in range(24) if i % 6 not in (0, 5)])
    o.append(lin(g, "#d8b870", 1.2, 0.85))
    # cardinal studs (diamonds) + small burgundy gems
    for i in range(4):
        a = i * math.pi / 2 - math.pi / 2
        x, y = c + 170 * math.cos(a), c + 170 * math.sin(a)
        d = poly([(x + 14 * math.cos(a), y + 14 * math.sin(a)), (x + 9 * math.cos(a + math.pi / 2), y + 9 * math.sin(a + math.pi / 2)),
                  (x - 14 * math.cos(a), y - 14 * math.sin(a)), (x - 9 * math.cos(a + math.pi / 2), y - 9 * math.sin(a + math.pi / 2))])
        o.append(fill(d, GILT))
        o.append(lin(d, "#0e0805", 1.6))
        o.append(fill(ell(x, y, 3.6), RUB))
        o.append(fill(ell(x - 1, y - 1, 1.2), "#e8b48a"))
    # inner thin rim
    o.append(f'<path d="{ell(c, c, 126)} {ell(c, c, 119)}" fill-rule="evenodd" fill="#3a3430"/>')
    o.append(lin(ell(c, c, 126) + " " + ell(c, c, 119), "#0e0805", 1.6))
    o.append(lin(ell(c, c, 122.5), GILT, 0.8, 0.7))
    return "\n".join(o)


# ------------------------------------------------------------------ full-screen pieces
def parchment_vignette(P):
    W, H = 1920, 1080
    mid = uid("vm")
    # mask: white at edges with irregular burnt boundary
    P.defs.append(f'<filter id="{mid}f" x="0" y="0" width="1" height="1"><feTurbulence type="fractalNoise" baseFrequency="0.006" numOctaves="4" seed="3"/>'
                  f'<feDisplacementMap in="SourceGraphic" scale="90" xChannelSelector="R" yChannelSelector="G"/><feGaussianBlur stdDeviation="18"/></filter>')
    gid = uid("vg")
    P.defs.append(f'<radialGradient id="{gid}" cx="0.5" cy="0.5" r="0.72"><stop offset="0.5" stop-color="#3a2410" stop-opacity="0"/>'
                  f'<stop offset="0.82" stop-color="#3a2410" stop-opacity="0.35"/><stop offset="1" stop-color="#1a0e06" stop-opacity="0.85"/></radialGradient>')
    o = [f'<rect width="{W}" height="{H}" fill="url(#{gid})"/>']
    o.append(f'<path d="M0,0 H{W} V{H} H0 Z M60,60 V{H-60} H{W-60} V60 Z" fill-rule="evenodd" fill="#160c05" opacity="0.75" filter="url(#{mid}f)"/>')
    o.append(f'<path d="M0,0 H{W} V{H} H0 Z M26,26 V{H-26} H{W-26} V26 Z" fill-rule="evenodd" fill="#0c0603" opacity="0.8" filter="url(#{mid}f)"/>')
    # scorch speckle
    o.append(f'<path d="M0,0 H{W} V{H} H0 Z M30,30 V{H-30} H{W-30} V30 Z" fill-rule="evenodd" fill="{EMBER}" opacity="0.10" filter="url(#{mid}f)"/>')
    return "\n".join(o)


def menu_background_html():
    """80:20 ledger menu composition without any text, title, buttons or labels."""
    import compositions as C
    import town as T
    st = ST
    svg, _ = T.town_svg(st)
    svg = re.sub(r"<text\b[^>]*>.*?</text>", "", svg, flags=re.S)
    # also drop the empty cartouche plate and scale bar so the map plate is clean
    svg = re.sub(r'<path d="M640,950 h640[^>]*/>', "", svg)
    svg = re.sub(r'<path d="M650,958 h620[^>]*/>', "", svg)
    t = st["noir"] / 0.15
    ink, rub, gilt = INK, RUB, GILT

    def corner(x, y, sx, sy):
        return (f'<g transform="translate({x},{y}) scale({sx},{sy})"><path d="M0,0 h70 M0,0 v70 M8,8 h40 M8,8 v40" stroke="{ink}" stroke-width="3" fill="none"/>'
                f'<path d="M14,14 q20,0 26,20 q-20,-4 -26,-20 Z M14,14 q0,20 20,26 q-4,-20 -20,-26 Z" fill="{gilt}" opacity=".85"/>'
                f'<circle cx="8" cy="8" r="5" fill="{gilt}"/></g>')
    cs = "".join(corner(x, y, sx, sy) for (x, y, sx, sy) in
                 [(92, 64, 1, 1), (1838, 64, -1, 1), (92, 1016, 1, -1), (1838, 1016, -1, -1), (952, 64, -1, 1), (988, 64, 1, 1), (952, 1016, -1, -1), (988, 1016, 1, -1)])
    rows = "".join('<div class="row"></div>' for _ in range(6))
    spr = lambda n: f"file://{EXPL}/{n}.png"
    body = f"""
<div style="position:absolute;inset:0;background:radial-gradient(ellipse 55% 70% at 8% 100%,rgba(224,120,42,{0.55 + 0.15 * (t - 1):.2f}),transparent 60%),
 radial-gradient(ellipse 30% 30% at 96% 4%,rgba(255,192,112,.28),transparent 70%),
 repeating-linear-gradient(90deg,#24160c 0 180px,#2a1a0e 180px 360px),#1e120a"></div>
<div style="position:absolute;inset:0;background:repeating-linear-gradient(90deg,transparent 0 178px,rgba(0,0,0,.35) 178px 181px,transparent 181px 360px)"></div>
<svg width="1920" height="1080" style="position:absolute;inset:0">{C.embers(int(70 * t), 0, 520, 600, 1080, st["glow2"], 7)}{C.embers(int(40 * t), 0, 700, 400, 1080, st["glow"], 8)}</svg>
<div class="book">
 <div class="page l">
  <div class="rule"><svg width="120" height="24"><path d="M6,12 L46,11 L46,13 Z M114,12 L74,11 L74,13 Z" fill="{gilt}"/><path d="M60,4 L68,12 L60,20 L52,12 Z" fill="{rub}" stroke="{ink}" stroke-width="1.2"/></svg></div>
  <div class="colh"></div>
  <div class="menu">{rows}</div>
 </div>
 <div class="spine"></div>
 <div class="page r">
  <div class="map">{svg}</div>
  <div class="caprule"></div>
  <img src="{spr('blacksmith')}" style="position:absolute;left:110px;top:590px;width:340px">
  <img src="{spr('sword')}" style="position:absolute;left:430px;top:600px;width:200px">
  <img src="{spr('armor')}" style="position:absolute;left:600px;top:610px;width:220px">
  <div class="plate" style="left:110px;width:330px"></div><div class="plate" style="left:470px;width:330px"></div>
 </div>
</div>
<svg width="1920" height="1080" style="position:absolute;inset:0;pointer-events:none">{cs}</svg>
<div style="position:absolute;inset:0;box-shadow:inset 0 0 200px 40px rgba(10,6,3,{0.75 + 0.1 * (t - 1):.2f});pointer-events:none"></div>
"""
    pg = "radial-gradient(ellipse at 50% 40%,#f0e0b8,#dcc290 68%,#b08c5c)"
    css = f"""
.book{{position:absolute;left:70px;top:46px;width:1780px;height:988px}}
.page{{position:absolute;top:0;width:880px;height:988px;background:{pg};overflow:hidden}}
.page.l{{left:0;border-radius:10px 0 0 10px;box-shadow:0 24px 60px rgba(0,0,0,.75),inset -70px 0 70px -30px rgba(70,40,14,.6),inset 0 0 110px rgba(70,40,14,.45)}}
.page.r{{left:900px;border-radius:0 10px 10px 0;box-shadow:0 24px 60px rgba(0,0,0,.75),inset 70px 0 70px -30px rgba(70,40,14,.6),inset 0 0 110px rgba(70,40,14,.45)}}
.spine{{position:absolute;left:880px;top:0;width:20px;height:988px;background:linear-gradient(90deg,#3a2414,#120a05 50%,#3a2414)}}
.page.l::after{{content:"";position:absolute;left:30px;bottom:60px;width:170px;height:90px;border-radius:50%;background:rgba(26,18,12,.12);filter:blur(10px)}}
.rule{{position:absolute;top:400px;left:0;width:100%;text-align:center}}
.colh{{position:absolute;top:470px;left:120px;right:110px;border-bottom:2px solid {gilt}}}
.menu{{position:absolute;top:478px;left:120px;right:110px}}
.row{{height:66px;border-bottom:1px solid rgba(36,23,14,.25)}}
.map{{position:absolute;left:50px;top:56px;width:780px;height:439px;overflow:hidden;border:3px solid {ink};outline:1px solid {gilt};outline-offset:6px}}
.map svg{{width:1920px;height:1080px;transform:scale(.40625);transform-origin:0 0}}
.caprule{{position:absolute;left:200px;top:548px;width:480px;border-top:1px solid rgba(36,23,14,.35)}}
.plate{{position:absolute;top:946px;border-top:1px solid rgba(36,23,14,.35)}}
"""
    from build import page
    return page(body, 1920, 1080, css)


SVG_UI = dict(panel_parchment=(panel_parchment, 256, 256), panel_dark=(panel_dark, 256, 256),
              button_normal=(lambda P: button(P, "normal"), 192, 56), button_hover=(lambda P: button(P, "hover"), 192, 56),
              button_pressed=(lambda P: button(P, "pressed"), 192, 56), button_disabled=(lambda P: button(P, "disabled"), 192, 56),
              slot=(slot, 72, 72), slot_select=(slot_select, 72, 72), tooltip_bg=(tooltip_bg, 128, 128), divider=(divider, 512, 24),
              corner_ornament=(corner_ornament, 96, 96), dice_d20=(dice_d20, 96, 96), dice_d12=(dice_d12, 96, 96),
              dice_d6=(dice_d6, 96, 96), skillcheck_ring=(skillcheck_ring, 384, 384),
              parchment_vignette=(parchment_vignette, 1920, 1080))
INKED = {"dice_d20", "dice_d12", "dice_d6", "corner_ornament", "skillcheck_ring"}


def jobs():
    only = only_filter()
    js = []
    for name, (fn, W, H) in SVG_UI.items():
        if only and name not in only:
            continue
        P = painter(scale=1.0, lw_mul=0.75)
        body = fn(P)
        if name in INKED:
            body = f'<g {ink_filter(P, wob=1.2, dil=0.6, grain=0.5, soot=0.5)}>{body}</g>'
        elif W <= 512:
            body = f'<g {soft_filter(P, 0.8)}>{body}</g>'
        ss = 1 if W >= 1920 else 3
        js.append(dict(name=f"ui_{name}", svg=svg_doc(W, H, P, body, ss=ss), w=W, h=H, ss=ss, out=os.path.join(UI, name + ".png")))
    if not only or "menu_background" in only:
        html = write_html("ui_menu_background", "", 1920, 1080, 1)
        with open(html, "w") as f:
            f.write(menu_background_html())
        js.append(dict(name="ui_menu_background", html=html, w=1920, h=1080, ss=1, transparent=False,
                       out=os.path.join(UI, "menu_background.png")))
    return js


if __name__ == "__main__":
    render(jobs(), workers=3)
