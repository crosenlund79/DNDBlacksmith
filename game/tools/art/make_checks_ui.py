"""Skill-check how-to illustrations and customer-request icons.
python3 make_checks_ui.py [--only=tut_ring,need_attack]  ->  assets/sprites/ui/template_<name>.png
 * tut_<mechanic> (360x260): an inked diagram of each skill check (ring, align, edge, multihit, rune, rings)
   on a small parchment plate, for the tutorial cards (CheckOverlay).
 * tut_eye / tut_key / tut_star (64): "watch", "keys" and "scores well" markers on the cards.
 * need_attack / need_protection / need_magic / need_deadline / need_dispute (64): request-card icons.
Text-free: the game writes all words on top."""
import math
import os
from artlib import (painter, svg_doc, ink_filter, glow, lin, fill, render, only_filter, ell, rect, poly, smooth,
                    INK, EMBER, EMBER_HOT, RUB, GILT, SPR, PARCH, VIOLET, VIOLET_HOT, hatch, blur_filter)

UI = os.path.join(SPR, "ui")
PAPER = "#efe2c2"
PAPER_D = "#d9c491"
STEEL = ("#e4e6e8", "#b4b8bc", "#6c7076")
GOLD = "#ffd27a"


def arc_path(cx, cy, r, a0, a1):
    """SVG arc from angle a0 to a1 (degrees, clockwise from +x)."""
    x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
    x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M{x0:.1f},{y0:.1f} A{r:.1f},{r:.1f} 0 {large},1 {x1:.1f},{y1:.1f}"


def arrow_head(x, y, ang, s=9, col=INK):
    a = math.radians(ang)
    p1 = (x + s * math.cos(a), y + s * math.sin(a))
    p2 = (x + s * 0.8 * math.cos(a + 2.4), y + s * 0.8 * math.sin(a + 2.4))
    p3 = (x + s * 0.8 * math.cos(a - 2.4), y + s * 0.8 * math.sin(a - 2.4))
    return fill(poly([p1, p2, p3]), col)


def curved_arrow(cx, cy, r, a0, a1, col=INK, w=3.0):
    end = a1
    tx = cx + r * math.cos(math.radians(end))
    ty = cy + r * math.sin(math.radians(end))
    return lin(arc_path(cx, cy, r, a0, a1), col, w) + arrow_head(tx, ty, end + 90, 10, col)


def plate(P, W, H):
    """A small parchment plate with a burnt, hatched edge."""
    d = rect(8, 8, W - 16, H - 16, 14)
    h = hatch(P, -35, sp=5.0, w=1.0, op=0.5)
    return (fill(rect(12, 14, W - 16, H - 16, 14), INK, 0.35, blur_filter(P, 4)) + fill(d, PAPER) +
            f'<path d="{d}" fill="none" stroke="{PAPER_D}" stroke-width="14" opacity="0.7"/>' +
            f'<path d="{rect(14, 14, W - 28, H - 28, 10)}" fill="none" stroke="{h}" stroke-width="6" opacity="0.6"/>' +
            lin(d, INK, 2.4))


def keycap(x, y, s=34):
    return (fill(rect(x - s / 2 + 2, y - s / 2 + 4, s, s, 6), INK, 0.4) + fill(rect(x - s / 2, y - s / 2, s, s, 6), "#f6eedc") +
            fill(rect(x - s / 2 + 4, y - s / 2 + 3, s - 8, s - 10, 4), "#fffaf0") + lin(rect(x - s / 2, y - s / 2, s, s, 6), INK, 2.0))


def mouse_icon(x, y):
    return (fill(rect(x - 13, y - 19, 26, 38, 13), "#f6eedc") + lin(rect(x - 13, y - 19, 26, 38, 13), INK, 2.0) +
            lin(f"M{x},{y-19} L{x},{y-5}", INK, 1.6) + lin(f"M{x-13},{y-5} L{x+13},{y-5}", INK, 1.6) +
            fill(rect(x - 13, y - 19, 13, 14, 6), EMBER, 0.55))


# ------------------------------------------------------------------ tutorial plates (360 x 260)
def tut_ring(P, W, H):
    cx, cy, R = 150, 132, 82
    o = [plate(P, W, H), glow(P, cx, cy, 110, EMBER, 0.18)]
    o.append(lin(ell(cx, cy, R), "#8a7a5a", 16, 0.55))
    o.append(lin(arc_path(cx, cy, R, -10, 40), EMBER, 18))
    o.append(lin(arc_path(cx, cy, R, 10, 20), GOLD, 22))
    for i in range(24):
        a = math.radians(i * 15)
        o.append(lin(f"M{cx + (R-24)*math.cos(a):.1f},{cy + (R-24)*math.sin(a):.1f} L{cx + (R-15)*math.cos(a):.1f},{cy + (R-15)*math.sin(a):.1f}", INK, 1.4, 0.6))
    na = math.radians(-40)
    tip = (cx + (R + 10) * math.cos(na), cy + (R + 10) * math.sin(na))
    o.append(lin(f"M{cx},{cy} L{tip[0]:.1f},{tip[1]:.1f}", INK, 7))
    o.append(lin(f"M{cx},{cy} L{tip[0]:.1f},{tip[1]:.1f}", "#f2e8d0", 3))
    o.append(fill(ell(tip[0], tip[1], 7), GOLD) + lin(ell(tip[0], tip[1], 7), INK, 1.6))
    o.append(fill(ell(cx, cy, 12), INK) + fill(ell(cx, cy, 6), GILT))
    o.append(curved_arrow(cx, cy, R + 30, -80, -20, RUB, 3.2))
    o.append(keycap(300, 70))
    o.append(mouse_icon(300, 130))
    o.append(fill(ell(300, 200, 16), GOLD, 0.9) + lin(ell(300, 200, 16), INK, 2))
    return o


def tut_align(P, W, H):
    cx, cy = 150, 140
    o = [plate(P, W, H), glow(P, cx, cy, 60, EMBER, 0.55)]
    for r, col, notch in ((90, "#c8642a", -60), (56, "#e8dcc0", -130)):
        o.append(lin(ell(cx, cy, r), INK, 20))
        o.append(lin(ell(cx, cy, r), col, 14, 0.85))
        for i in range(12):
            a = math.radians(i * 30 + notch)
            o.append(lin(f"M{cx + (r-8)*math.cos(a):.1f},{cy + (r-8)*math.sin(a):.1f} L{cx + (r+8)*math.cos(a):.1f},{cy + (r+8)*math.sin(a):.1f}", INK, 1.6))
        a = math.radians(notch)
        nx, ny = cx + r * math.cos(a), cy + r * math.sin(a)
        o.append(fill(ell(nx, ny, 11), col) + lin(ell(nx, ny, 11), INK, 2.4))
        o.append(curved_arrow(cx, cy, r + 17, notch + 8, -98 if r > 60 else -100, RUB, 2.6))
    # the vent and its window at the top
    o.append(fill(poly([(cx - 13, 20), (cx + 13, 20), (cx, 38)]), GOLD) + lin(poly([(cx - 13, 20), (cx + 13, 20), (cx, 38)]), INK, 2))
    o.append(lin(arc_path(cx, cy, 110, -104, -76), GILT, 4))
    # flame in the hearth
    o.append(fill(ell(cx, cy, 28), "#2a1a10") + fill(poly([(cx - 12, cy + 12), (cx + 12, cy + 12), (cx + 3, cy - 22), (cx - 3, cy - 16)]), EMBER) +
             fill(poly([(cx - 5, cy + 12), (cx + 5, cy + 12), (cx, cy - 8)]), EMBER_HOT))
    o.append(keycap(292, 64) + keycap(326, 64) + keycap(292, 104) + keycap(326, 104))
    o.append(lin("M292,64 m-8,0 l16,0 m-6,-6 l6,6 l-6,6", INK, 2))
    o.append(lin("M326,104 m0,-8 l0,16 m-6,-6 l6,6 l6,-6", INK, 2))
    o.append(keycap(309, 178, 40))
    return o


def tut_edge(P, W, H):
    o = [plate(P, W, H)]
    wx, wy, R = 250, 134, 78
    o.append(fill(ell(wx, wy, R + 5), INK) + fill(ell(wx, wy, R), "#8a8070") + fill(ell(wx, wy, R * 0.8), "#9a9080"))
    for i in range(10):
        a = math.radians(i * 36 + 8)
        o.append(lin(f"M{wx + 16*math.cos(a):.1f},{wy + 16*math.sin(a):.1f} L{wx + (R-4)*math.cos(a):.1f},{wy + (R-4)*math.sin(a):.1f}", INK, 1.2, 0.45))
    o.append(fill(ell(wx, wy, 14), "#3a2c1c") + fill(ell(wx, wy, 6), GILT))
    o.append(curved_arrow(wx, wy, R + 16, 200, 260, RUB, 2.6))
    # the blade touching the stone
    tip = (wx - R - 2, wy + 6)
    o.append(lin(f"M{tip[0]-150:.1f},{tip[1]-8:.1f} L{tip[0]:.1f},{tip[1]:.1f}", GOLD, 14, 0.35))
    o.append(fill(poly([(tip[0] - 150, tip[1] - 2), (tip[0], tip[1] + 2), (tip[0], tip[1] + 8), (tip[0] - 150, tip[1] + 18)]), STEEL[0]) +
             lin(poly([(tip[0] - 150, tip[1] - 2), (tip[0], tip[1] + 2), (tip[0], tip[1] + 8), (tip[0] - 150, tip[1] + 18)]), INK, 2))
    for i in range(9):
        a = math.radians(200 + i * 9)
        o.append(lin(f"M{tip[0]:.1f},{tip[1]:.1f} l{24*math.cos(a):.1f},{24*math.sin(a):.1f}", EMBER_HOT, 2))
    # the gauge with the wandering sweet spot
    gx, gy, gs = 30, 28, 96
    o.append(fill(rect(gx, gy, gs, gs, 4), "#2a1d12") + lin(rect(gx, gy, gs, gs, 4), INK, 2.4))
    o.append(fill(ell(gx + 60, gy + 40, 18), GOLD, 0.3) + lin(ell(gx + 60, gy + 40, 18), GOLD, 2.4))
    o.append(lin(f"M{gx+28},{gy+66} q 14,-6 24,-18", "#f2e8d0", 1.6, 0.8, extra='stroke-dasharray="3 4"'))
    o.append(fill(ell(gx + 26, gy + 68, 7), "#f0d060") + lin(ell(gx + 26, gy + 68, 7), INK, 1.8))
    o.append(arrow_head(gx + 54, gy + 46, -50, 8, "#f2e8d0"))
    o.append(keycap(48, 200) + keycap(86, 200) + mouse_icon(126, 200))
    return o


def tut_multihit(P, W, H):
    cx, cy, R = 150, 132, 84
    o = [plate(P, W, H), glow(P, cx, cy, 100, VIOLET, 0.2)]
    o.append(lin(ell(cx, cy, R), INK, 22) + lin(ell(cx, cy, R), "#8c74b8", 14, 0.45))
    secs = [-40, 20, 80, 150, 215]
    for i, s in enumerate(secs):
        col = GOLD if i < 2 else VIOLET_HOT
        o.append(lin(arc_path(cx, cy, R, s - 12, s + 12), col, 18))
        if i < 2:
            a = math.radians(s)
            sx, sy = cx + (R + 26) * math.cos(a), cy + (R + 26) * math.sin(a)
            o.append(fill(ell(sx, sy, 7), GOLD) + lin(ell(sx, sy, 7), INK, 1.6))
    na = math.radians(50)
    tip = (cx + (R + 10) * math.cos(na), cy + (R + 10) * math.sin(na))
    o.append(lin(f"M{cx},{cy} L{tip[0]:.1f},{tip[1]:.1f}", INK, 7) + lin(f"M{cx},{cy} L{tip[0]:.1f},{tip[1]:.1f}", "#e8dcff", 3))
    o.append(fill(ell(cx, cy, 12), INK) + fill(ell(cx, cy, 6), VIOLET))
    o.append(curved_arrow(cx, cy, R + 30, -150, -60, RUB, 2.6))
    o.append(keycap(306, 92) + keycap(306, 150))
    return o


def tut_rune(P, W, H):
    o = [plate(P, W, H)]
    sx, sy = 196, 170
    # blade lying across the plate, socket in its ricasso
    o.append(fill(poly([(30, sy - 22), (290, sy - 16), (334, sy), (290, sy + 16), (30, sy + 22)]), STEEL[0]) +
             lin(poly([(30, sy - 22), (290, sy - 16), (334, sy), (290, sy + 16), (30, sy + 22)]), INK, 2.4))
    o.append(lin(f"M44,{sy} L284,{sy}", STEEL[2], 4))
    o.append(glow(P, sx, sy, 40, VIOLET, 0.45))
    o.append(fill(ell(sx, sy, 16), "#40424a") + lin(ell(sx, sy, 16), INK, 2.4) + lin(ell(sx, sy, 28), VIOLET_HOT, 1.8, 0.9))
    # the rune hovering, a dotted path into the socket
    rx, ry = 110, 70
    o.append(lin(f"M{rx},{ry} C {rx+30},{ry+70} {sx-60},{sy-70} {sx-10},{sy-12}", RUB, 2.4, 1.0, extra='stroke-dasharray="5 6"'))
    o.append(arrow_head(sx - 12, sy - 14, 50, 10, RUB))
    o.append(glow(P, rx, ry, 34, VIOLET, 0.5))
    o.append(fill(ell(rx, ry, 18), "#3a3448") + lin(ell(rx, ry, 18), INK, 2.4))
    o.append(lin(f"M{rx},{ry-10} L{rx},{ry+10} M{rx},{ry-2} L{rx+7},{ry-9} M{rx},{ry+4} L{rx-7},{ry-3}", VIOLET_HOT, 2.4))
    for dx, dy in ((-26, -12), (24, -18), (-18, 22)):
        o.append(fill(ell(rx + dx, ry + dy, 2.4), VIOLET_HOT))
    o.append(mouse_icon(300, 60))
    o.append(keycap(250, 52, 30))
    return o


def tut_rings(P, W, H):
    cx, cy = 150, 132
    o = [plate(P, W, H)]
    o.append(fill(ell(cx, cy, 108), INK) + fill(ell(cx, cy, 102), "#5a4a3a") + fill(ell(cx, cy, 94), "#3c5226") + fill(ell(cx, cy, 86), "#7d9a58", 0.55))
    o.append(lin(ell(cx, cy, 52), "#c8f0a0", 14, 0.3) + lin(ell(cx, cy, 52), "#c8f0a0", 4) + lin(ell(cx, cy, 52), INK, 1.4))
    o.append(lin(ell(cx, cy, 78), "#e8f6d0", 5, 0.9, extra='stroke-dasharray="10 6"'))
    for a in (-45, 45, 135, 225):
        ar = math.radians(a)
        x0, y0 = cx + 92 * math.cos(ar), cy + 92 * math.sin(ar)
        x1, y1 = cx + 66 * math.cos(ar), cy + 66 * math.sin(ar)
        o.append(lin(f"M{x0:.1f},{y0:.1f} L{x1:.1f},{y1:.1f}", GOLD, 3) + arrow_head(x1, y1, a + 180, 8, GOLD))
    for i, (dx, dy) in enumerate(((-30, -20), (20, 10), (6, -34), (-10, 30))):
        o.append(fill(ell(cx + dx, cy + dy, 3 + i % 2), "#e8f6d0", 0.8))
    o.append(keycap(306, 92) + mouse_icon(306, 152))
    return o


# ------------------------------------------------------------------ small icons (64)
def tut_eye(P, W, H):
    return [fill("M6,32 C18,12 46,12 58,32 C46,52 18,52 6,32 Z", "#f6eedc") + lin("M6,32 C18,12 46,12 58,32 C46,52 18,52 6,32 Z", INK, 2.6),
            fill(ell(32, 32, 12), "#7e5a2a") + fill(ell(32, 32, 6), INK) + fill(ell(28, 28, 3), "#fff8e8")]


def tut_key(P, W, H):
    return [keycap(32, 32, 46)]


def star_path(cx, cy, r0, r1, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r0 if i % 2 == 0 else r1
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


def tut_star(P, W, H):
    return [glow(P, 32, 32, 30, EMBER, 0.5), fill(star_path(32, 33, 26, 11), GOLD) + lin(star_path(32, 33, 26, 11), INK, 2.4)]


def need_attack(P, W, H):
    o = []
    for flip in (1, -1):
        def T(x, y):
            return (32 + flip * (x - 32), y)
        blade = [T(12, 10), T(16, 8), T(48, 42), T(44, 46)]
        o.append(fill(poly(blade), STEEL[0]) + lin(poly(blade), INK, 2.2))
        o.append(lin("M%.1f,%.1f L%.1f,%.1f" % (*T(38, 50), *T(52, 36)), "#6a4a2a", 5) + lin("M%.1f,%.1f L%.1f,%.1f" % (*T(46, 46), *T(56, 56)), "#4a3020", 5))
    return o


def need_protection(P, W, H):
    d = "M32,6 C40,10 50,11 56,10 C56,34 48,50 32,58 C16,50 8,34 8,10 C14,11 24,10 32,6 Z"
    return [fill(d, "#a8b0b6") + fill("M32,10 L32,54 C18,47 12,33 12,14 C18,14 26,13 32,10 Z", "#c8ccd0") + lin(d, INK, 2.6),
            lin("M32,10 L32,54 M14,28 L50,28", RUB, 3)]


def need_magic(P, W, H):
    return [glow(P, 32, 32, 30, VIOLET, 0.6), fill(star_path(32, 32, 26, 7, 4, -90), VIOLET_HOT) + lin(star_path(32, 32, 26, 7, 4, -90), INK, 2.2),
            fill(star_path(50, 14, 8, 3, 4, -90), "#e8dcff") + lin(star_path(50, 14, 8, 3, 4, -90), INK, 1.4)]


def need_deadline(P, W, H):
    o = [fill(rect(14, 6, 36, 6, 2), "#6a4a2a") + fill(rect(14, 52, 36, 6, 2), "#6a4a2a")]
    glass = "M18,12 L46,12 C46,24 36,28 34,32 C36,36 46,40 46,52 L18,52 C18,40 28,36 30,32 C28,28 18,24 18,12 Z"
    o.append(fill(glass, "#eef2ea", 0.85) + fill("M22,48 L42,48 C40,42 34,40 32,36 C30,40 24,42 22,48 Z", "#d2a050") +
             fill("M25,18 L39,18 C37,24 33,26 32,28 C31,26 27,24 25,18 Z", "#d2a050") + lin(glass, INK, 2.2))
    o.append(lin("M14,6 L50,6 M14,58 L50,58", INK, 2.4))
    return o


def need_dispute(P, W, H):
    return [fill(poly([(8, 50), (30, 28), (34, 32), (12, 54)]), STEEL[0]) + lin(poly([(8, 50), (30, 28), (34, 32), (12, 54)]), INK, 2.2),
            fill(poly([(36, 24), (54, 6), (58, 10), (40, 28)]), STEEL[0]) + lin(poly([(36, 24), (54, 6), (58, 10), (40, 28)]), INK, 2.2),
            lin("M30,22 L36,30 L32,34 L40,38", RUB, 2.6)]


TUTS = {"tut_ring": tut_ring, "tut_align": tut_align, "tut_edge": tut_edge, "tut_multihit": tut_multihit,
        "tut_rune": tut_rune, "tut_rings": tut_rings}
ICONS = {"tut_eye": tut_eye, "tut_key": tut_key, "tut_star": tut_star, "need_attack": need_attack,
         "need_protection": need_protection, "need_magic": need_magic, "need_deadline": need_deadline,
         "need_dispute": need_dispute}


def main():
    only = only_filter()
    jobs = []
    for name, fn in list(TUTS.items()) + list(ICONS.items()):
        if only and name not in only:
            continue
        W, H = (360, 260) if name in TUTS else (64, 64)
        P = painter(1.0)
        body = "".join(fn(P, W, H))
        f = ink_filter(P, wob=1.0, dil=0.4, grain=0.8, soot=0.6, seed=7)
        svg = svg_doc(W, H, P, f"<g {f}>{body}</g>", ss=2)
        jobs.append(dict(name="checks_" + name, svg=svg, w=W, h=H, ss=2, out=os.path.join(UI, name + ".png")))
    render(jobs)


if __name__ == "__main__":
    main()
