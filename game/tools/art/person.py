"""Parametric straight-top-down person for "Ember & Ash" (Ink & Parchment / Gothic Noir 80:20).

Everything is drawn in the 512x512 design space of the exploration generator
(`docs/visual_exploration/_generator/subjects.py`), facing SOUTH (towards the viewer's
bottom edge): we see the top of the head, the shoulders, the back items (towards the top of the
canvas), the hands at the sides and the toes of the boots below.  The caller rotates the result for
the other directions and supplies a Painter whose light vector has been counter-rotated, so the
crescent shadows stay bottom-right on screen.

`figure(P, look, step, breathe)` is driven entirely by a characters.json `look` dict.
"""
import colorsys
import math
import os
import sys

GEN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs",
                   "visual_exploration", "_generator")
sys.path.insert(0, os.path.abspath(GEN))

from svgcore import ell, rect, poly, smooth, blob  # noqa: E402

CX = 256


# ------------------------------------------------------------------ colour helpers
def _hex(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) / 255 for i in (0, 2, 4))


def _tohex(rgb):
    return "#" + "".join(f"{max(0, min(255, round(v * 255))):02x}" for v in rgb)


def mix(a, b, t):
    A, B = _hex(a), _hex(b)
    return _tohex(tuple(A[i] * (1 - t) + B[i] * t for i in range(3)))


def tri(hexcol, wash=0.08):
    """(light, base, shadow) from one hex colour: +-18 % lightness, lightly washed toward parchment
    so saturated data colours sit in the 80:20 palette."""
    if lum(hexcol) < 0.3:
        wash = max(wash, 0.2 - lum(hexcol) * 0.3)
    base = mix(hexcol, "#e6d4ac", wash)
    h, l, s = colorsys.rgb_to_hls(*_hex(base))
    lt = _tohex(colorsys.hls_to_rgb(h, min(0.94, l + 0.18), s * 0.9))
    sh = _tohex(colorsys.hls_to_rgb(h, max(0.05, l - 0.18 if l > 0.24 else l * 0.45), min(1, s * 1.05)))
    return (lt, base, sh)


def lum(hexcol):
    r, g, b = _hex(hexcol)
    return 0.3 * r + 0.59 * g + 0.11 * b


def make_palette(base_pal, look):
    pal = dict(base_pal)
    if look.get("skin"):
        pal["skin"] = tri(look["skin"], 0.05)
    if look.get("hair_col"):
        pal["hair"] = tri(look["hair_col"], 0.06)
    bc = look.get("beard_col") or look.get("hair_col")
    if bc:
        pal["beard"] = tri(bc, 0.06)
    if look.get("shirt"):
        pal["shirt"] = tri(look["shirt"], 0.1)
    if look.get("cloak"):
        pal["cloak"] = tri(look["cloak"], 0.08)
    # a hood / hood_down uses the cloak colour, or a darkened shirt
    pal["hoodc"] = pal["cloak"] if look.get("cloak") else tri(mix(look.get("shirt", "#6a5a40"), "#2a2018", 0.25), 0.08)
    pal["ivory"] = ("#fbf4e2", "#eee2c4", "#9a8c6c")
    pal["chain"] = ("#d4d2ca", "#9e9c92", "#55544a")
    pal["olive"] = ("#8a9a5c", "#5e6e3c", "#2e3a1e")     # Ironfront M1 helmet (helmet_m1 extra)
    return pal


# ------------------------------------------------------------------ builds
# sw/sry/sy shoulders; cw/ch/cy chest or belly; ax arm x offset; uy/urx/ury upper arm;
# fy/frx/fry forearm; hy/hr hand; hdr/hdy head; fx/fty/brx/bry boots; k overall scale.
BUILDS = {
    "heavy":   dict(sw=110, sry=64, sy=202, cw=92, ch=82, cy=272, ax=108, uy=256, urx=31, ury=50,
                    fy=314, frx=25, fry=37, hy=346, hr=22, hdr=42, hdy=196, fx=35, fty=375, brx=25, bry=31,
                    k=1.0, stride=13, swing=10),
    "average": dict(sw=82, sry=46, sy=214, cw=62, ch=48, cy=248, ax=76, uy=242, urx=21, ury=38,
                    fy=272, frx=17, fry=25, hy=296, hr=15, hdr=34, hdy=212, fx=25, fty=324, brx=19, bry=27,
                    k=1.0, stride=13, swing=9),
    "slim":    dict(sw=72, sry=42, sy=216, cw=52, ch=42, cy=248, ax=67, uy=242, urx=18, ury=36,
                    fy=270, frx=14, fry=23, hy=292, hr=13, hdr=32, hdy=214, fx=22, fty=320, brx=17, bry=25,
                    k=1.0, stride=13, swing=9),
    "dwarf":   dict(sw=100, sry=56, sy=222, cw=88, ch=64, cy=262, ax=98, uy=250, urx=28, ury=38,
                    fy=284, frx=22, fry=27, hy=310, hr=20, hdr=39, hdy=222, fx=33, fty=328, brx=24, bry=26,
                    k=0.86, stride=10, swing=8),
    "halfling": dict(sw=74, sry=42, sy=216, cw=56, ch=44, cy=250, ax=69, uy=242, urx=19, ury=34,
                     fy=270, frx=15, fry=22, hy=292, hr=14, hdr=39, hdy=212, fx=24, fty=318, brx=19, bry=25,
                     k=0.72, stride=12, swing=9),
    "orc":     dict(sw=104, sry=56, sy=210, cw=76, ch=56, cy=252, ax=98, uy=246, urx=27, ury=42,
                    fy=286, frx=21, fry=29, hy=314, hr=19, hdr=40, hdy=218, fx=30, fty=336, brx=22, bry=29,
                    k=1.04, stride=14, swing=10),
}


def build_of(look):
    b = dict(BUILDS[look.get("build", "average")])
    if look.get("female"):
        if look["build"] == "slim":
            b.update(sw=62, sry=38, cw=44, ch=38, ax=58, urx=15, ury=33, frx=12, fry=21, hr=12, hdr=31,
                     fx=20, brx=15, bry=23)
        elif look["build"] == "average":
            b.update(sw=72, sry=42, cw=54, ch=44, ax=66, urx=18, ury=35, frx=14, fry=23, hr=13, hdr=32,
                     fx=22, brx=17, bry=24)
        elif look["build"] == "heavy":
            b.update(sw=96, sry=56, cw=84, ch=72, ax=94, urx=27, ury=44, frx=21, fry=31, hr=18, hdr=38,
                     hdy=200, fx=30, brx=21, bry=27, hy=336, fy=306)
        elif look["build"] == "dwarf":
            b.update(sw=92, cw=82, ax=90, urx=25, hdr=37)
    return b


# ------------------------------------------------------------------ helpers
def mx(side, dx):
    return CX + side * dx


def soot(P, x, y, rx, ry, op):
    s = P.st.get("soot", "#16100b")
    return f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{s}" opacity="{op:.2f}" style="filter:blur(2px)"/>'


def rot_pts(pts, ang, cx, cy):
    c, s = math.cos(ang), math.sin(ang)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


# ------------------------------------------------------------------ held items
def held_item(P, look, B, x, y, side, detail):
    """Item in the weapon hand at hand centre (x, y). Drawn BEFORE the hand so the fist covers the grip."""
    h = look.get("hand", "none")
    o = []
    s = B["k"]
    hr = B["hr"]
    out = side  # outward direction (away from the body)
    if h == "hammer":
        if look.get("_id") == "player" or look.get("build") == "heavy":
            # the approved sledgehammer
            o.append(P.shape(rect(x - 8, y - 16, 16, 80, 6), "wood", s=5))
            if detail:
                o.append(P.detail(f"M{x-6},{y+14} L{x+6},{y+6} M{x-6},{y+32} L{x+6},{y+24} M{x-6},{y+50} L{x+6},{y+42}", "wood", 0.8))
            hy = y + 56
            o.append(P.shape(rect(x - 42, hy, 84, 38, 7), "metal", s=8))
            o.append(P.shape(rect(x - 48, hy + 4, 14, 30, 4), "metal", s=4))
            o.append(P.shape(rect(x + 34, hy + 4, 14, 30, 4), "metal", s=4))
            if detail:
                o.append(P.detail(f"M{x-28},{hy+10} L{x-28},{hy+28} M{x+28},{hy+10} L{x+28},{hy+28}", "metal", 0.8))
                o.append(P.detail(f"M{x-32},{hy+8} l12,10 M{x+6},{hy+6} l10,14", "metal", 0.6, 0.9))
                o.append(soot(P, x, hy + 22, 28, 10, 0.3))
        else:
            # carpenter's claw hammer
            o.append(P.shape(rect(x - 5, y - 6, 10, 64, 4), "wood", s=3))
            o.append(P.shape(smooth([(x - 22, y + 52), (x + 14, y + 50), (x + 30, y + 44), (x + 26, y + 58),
                                     (x + 14, y + 66), (x - 22, y + 66)]), "metal", s=4))
            o.append(P.shape(rect(x - 26, y + 50, 10, 18, 3), "metal", s=3))
    elif h in ("sword", "dagger"):
        L = 86 if h == "sword" else 44
        w = 7 if h == "sword" else 6
        o.append(P.shape(poly([(x - w, y + 8), (x + w, y + 8), (x + w - 2, y + 8 + L), (x, y + 8 + L + 18),
                               (x - w + 2, y + 8 + L)]), "metal", s=5))
        if detail:
            o.append(P.detail(f"M{x},{y+14} L{x},{y+L}", "metal", 0.6))
        gw = 22 if h == "sword" else 13
        o.append(P.shape(rect(x - gw, y + 2, 2 * gw, 10, 4), "gold" if h == "sword" else "metal", s=3))
        o.append(P.shape(ell(x, y - hr - 4, 6, 6), "gold", s=2))
    elif h == "mace":
        o.append(P.shape(rect(x - 5, y - 10, 10, 78, 4), "wood", s=3))
        o.append(P.shape(rect(x - 7, y + 58, 14, 10, 3), "metal", s=2))
        cy_ = y + 74
        fl = []
        for i in range(12):
            a = i / 12 * math.tau
            r = 22 if i % 2 == 0 else 14
            fl.append((x + math.cos(a) * r, cy_ + math.sin(a) * r))
        o.append(P.shape(smooth(fl, t=0.25), "metal", s=6))
        o.append(P.shape(ell(x, cy_, 8, 8), "metal", s=3, hl=False))
    elif h == "axe":
        o.append(P.shape(rect(x - 6, y - 12, 12, 100, 5), "wood", s=4))
        ay = y + 56
        blade = [(x + 2, ay - 12), (x + out * 22, ay - 20), (x + out * 44, ay - 30), (x + out * 50, ay + 4),
                 (x + out * 44, ay + 36), (x + out * 22, ay + 26), (x + 2, ay + 18)]
        o.append(P.shape(smooth(blade, t=0.4), "metal", s=6))
        o.append(P.shape(rect(x - 9, ay - 14, 18, 34, 4), "metal", s=3))
        if detail:
            o.append(P.detail(f"M{x+out*38},{ay-18} Q{x+out*48},{ay+4} {x+out*38},{ay+28}", "metal", 0.6))
    elif h == "pick":
        o.append(P.shape(rect(x - 6, y - 10, 12, 92, 5), "wood", s=4))
        py = y + 78
        head = [(x - 46, py + 14), (x - 30, py), (x, py - 6), (x + 30, py), (x + 46, py + 14),
                (x + 30, py + 8), (x, py + 8), (x - 30, py + 8)]
        o.append(P.shape(smooth(head, t=0.35), "metal", s=5))
        o.append(P.shape(rect(x - 9, py - 8, 18, 18, 4), "metal", s=3))
    elif h == "staff":
        # quarterstaff carried forward, crowned with an ember gem
        o.append(P.shape(smooth([(x - 5, y - 70), (x + 5, y - 70), (x + 6, y + 30), (x + 4, y + 78),
                                 (x - 4, y + 78), (x - 6, y + 30)]), "wood", s=4))
        tx, ty = x, y + 88
        o.append(P.shape(smooth([(tx - 18, ty - 14), (tx, ty - 22), (tx + 18, ty - 14), (tx + 20, ty + 8),
                                 (tx + 8, ty + 22), (tx - 8, ty + 22), (tx - 20, ty + 8)]), "wood", s=5))
        o.append(f'<circle cx="{tx}" cy="{ty+2}" r="16" fill="{P.st["glow"]}" opacity="0.35" style="filter:blur(4px)"/>')
        o.append(P.shape(ell(tx, ty + 2, 9, 9), "gem", s=3))
    elif h == "bow":
        bx = x + out * 4
        arc = [(bx, y - 74), (bx + out * 16, y - 40), (bx + out * 22, y), (bx + out * 16, y + 40), (bx, y + 74),
               (bx + out * 8, y + 40), (bx + out * 12, y), (bx + out * 8, y - 40)]
        o.append(P.shape(smooth(arc, t=0.45), "wood", s=4))
        o.append(P.detail(f"M{bx},{y-72} L{bx-out*2},{y+72}", None, 0.5, 0.85))
        o.append(P.shape(rect(bx + out * 6 - 6, y - 10, 14, 20, 3), "leather", s=2))
    elif h == "basket":
        bx, by = x + out * 4, y + 30
        o.append(P.shape(ell(bx, by, 34, 26), "wood", s=7))
        if detail:
            o.append(P.detail(f"M{bx-30},{by-6} Q{bx},{by-1} {bx+30},{by-6} M{bx-32},{by+6} Q{bx},{by+11} {bx+32},{by+6}", "wood", 0.6, 0.8))
        # contents: loaves / apples
        o.append(P.shape(ell(bx - 10, by - 2, 13, 9), "apron", s=3))
        o.append(P.shape(ell(bx + 12, by + 2, 9, 9), "cloak", s=3, fill_override="#a8443a"))
        o.append(P.shape(ell(bx + 2, by + 10, 8, 7), "foliage", s=2))
        o.append(P.detail(f"M{bx-30},{by} Q{bx},{by-44} {bx+30},{by}", "wood", 1.6))
    elif h == "tankard":
        tx, ty = x + out * 6, y + 18
        o.append(P.shape(ell(tx + out * 18, ty, 8, 6), "wood", s=2))
        o.append(P.shape(ell(tx, ty, 17, 16), "wood", s=4))
        o.append(P.shape(ell(tx, ty, 13, 12), "metal", s=2, hl=False))
        o.append(P.shape(blob(tx, ty, 11, 6, 0.12, 3), "shirt", s=2, fill_override="#f2e8cc"))
    elif h == "lute":
        o.append(P.shape(ell(x, y + 40, 26, 30), "wood", s=5))
        o.append(P.shape(rect(x - 5, y - 30, 10, 50, 3), "wood", s=3))
    return "\n".join(o)


def back_item(P, look, B, sway, detail):
    b = look.get("back", "none")
    o = []
    sw, sy = B["sw"], B["sy"]
    k = sw / 82.0
    if b == "shield":
        r = 48 * min(1.12, k ** 0.6)
        cx, cy = CX + sway * 0.5, sy - r * 1.02
        paint = "cloak" if look.get("cloak") else "apron"
        o.append(P.shape(ell(cx, cy, r, r), "wood", s=12))
        if detail:
            o.append(P.detail(f"M{cx-r*0.85},{cy-r*0.4} L{cx+r*0.85},{cy-r*0.4} M{cx-r*0.95},{cy} L{cx+r*0.95},{cy} "
                              f"M{cx-r*0.85},{cy+r*0.4} L{cx+r*0.85},{cy+r*0.4}", "wood", 0.6, 0.7))
        ri = r * 0.72
        o.append(P.shape(f"M{cx},{cy-r} A{r},{r} 0 0 1 {cx+r},{cy} L{cx+ri},{cy} A{ri},{ri} 0 0 0 {cx},{cy-ri} Z", paint, s=4, hl=False))
        o.append(P.shape(f"M{cx},{cy+r} A{r},{r} 0 0 1 {cx-r},{cy} L{cx-ri},{cy} A{ri},{ri} 0 0 0 {cx},{cy+ri} Z", paint, s=4, hl=False))
        o.append(P.detail(ell(cx, cy, r - 4, r - 4), "metal", 2.0))
        o.append(P.shape(ell(cx, cy, r * 0.28, r * 0.28), "metal", s=5))
        # strap across the chest is drawn with the torso
    elif b == "quiver":
        x0, y0 = CX + sw * 0.35 + sway * 0.3, sy + 6
        ang = math.radians(-28)
        L = 120
        x1, y1 = x0 + math.sin(-ang) * -L * 0.2 - 30, y0 - L
        pts = rot_pts([(x0 - 13, y0 - L), (x0 + 13, y0 - L), (x0 + 12, y0), (x0 - 12, y0)], ang, x0, y0)
        o.append(P.shape(poly(pts), "leather", s=5))
        tip = rot_pts([(x0, y0 - L - 4)], ang, x0, y0)[0]
        # fletchings
        for i, dx in enumerate((-8, 0, 8)):
            fx, fy = rot_pts([(x0 + dx, y0 - L - 10 + (i % 2) * 6)], ang, x0, y0)[0]
            o.append(P.shape(blob(fx, fy, 8, 5, 0.15, i + 2, squash=0.8), "cloak", s=2, hl=False,
                             fill_override=["#e8dcc0", "#8e3e3c", "#e8dcc0"][i]))
        if detail:
            ln = rot_pts([(x0 - 12, y0 - L * 0.66), (x0 + 12, y0 - L * 0.66), (x0 - 12, y0 - L * 0.3), (x0 + 12, y0 - L * 0.3)], ang, x0, y0)
            o.append(P.detail(f"M{ln[0][0]:.1f},{ln[0][1]:.1f} L{ln[1][0]:.1f},{ln[1][1]:.1f} M{ln[2][0]:.1f},{ln[2][1]:.1f} L{ln[3][0]:.1f},{ln[3][1]:.1f}", "leather", 0.7))
    elif b == "staff":
        x0, y0 = CX - sw * 0.9, sy + 10
        x1, y1 = CX + sw * 0.9, sy - 130
        o.append(P.detail(f"M{x0},{y0} L{x1},{y1}", None, 6.5))
        o.append(f'<path d="M{x0},{y0} L{x1},{y1}" stroke="{P.c("wood", 1)}" stroke-width="{7*P.lw_mul:.1f}" stroke-linecap="round"/>')
    elif b == "pack":
        w = sw * (0.78 if look.get("build") == "dwarf" else 0.9)
        top = sy - {"dwarf": 76, "heavy": 60}.get(look.get("build"), 86)
        x0 = CX + sway * 0.4
        o.append(P.shape(rect(x0 - w, top + 10, 2 * w, sy - top - 4, 18), "leather", s=9))
        o.append(P.shape(rect(x0 - w * 0.78, top + 34, w * 1.56, 40, 10), "leather", s=5, hl=False))  # flap
        o.append(P.shape(rect(x0 - 8, top + 60, 16, 12, 3), "gold", s=2))
        # bedroll on top
        o.append(P.shape(rect(x0 - w * 1.08, top - 10, w * 2.16, 30, 14), "tunic", s=5,
                         fill_override="#8a8a6e"))
        if detail:
            o.append(P.detail(f"M{x0-w*0.6},{top-8} L{x0-w*0.6},{top+18} M{x0+w*0.6},{top-8} L{x0+w*0.6},{top+18}", "strap", 1.2))
            o.append(P.detail(f"M{x0-w*0.9},{top+4} Q{x0},{top+10} {x0+w*0.9},{top+4}", "tunic", 0.6, 0.6))
            # pan / tin cup
            o.append(P.shape(ell(x0 + w * 0.82, top + 66, 12, 12), "metal", s=3))
    elif b == "lute":
        x0, y0 = CX - sw * 0.1 + sway * 0.4, sy - 50
        ang = math.radians(35)
        body = rot_pts([(x0, y0 - 34), (x0 + 30, y0 - 10), (x0 + 34, y0 + 22), (x0 + 16, y0 + 44), (x0, y0 + 48),
                        (x0 - 16, y0 + 44), (x0 - 34, y0 + 22), (x0 - 30, y0 - 10)], ang, x0, y0)
        neck = rot_pts([(x0 - 6, y0 - 30), (x0 + 6, y0 - 30), (x0 + 6, y0 - 92), (x0 - 6, y0 - 92)], ang, x0, y0)
        head = rot_pts([(x0 - 9, y0 - 90), (x0 + 9, y0 - 90), (x0 + 6, y0 - 114), (x0 - 6, y0 - 114)], ang, x0, y0)
        o.append(P.shape(poly(neck), "strap", s=3))
        o.append(P.shape(poly(head), "strap", s=3))
        o.append(P.shape(smooth(body), "wood", s=8))
        rx, ry = rot_pts([(x0, y0 + 6)], ang, x0, y0)[0]
        o.append(P.shape(ell(rx, ry, 9, 9), "strap", s=2, hl=False))
        if detail:
            s1 = rot_pts([(x0 - 3, y0 - 88), (x0 - 3, y0 + 36), (x0 + 3, y0 - 88), (x0 + 3, y0 + 36)], ang, x0, y0)
            o.append(P.detail(f"M{s1[0][0]:.1f},{s1[0][1]:.1f} L{s1[1][0]:.1f},{s1[1][1]:.1f} M{s1[2][0]:.1f},{s1[2][1]:.1f} L{s1[3][0]:.1f},{s1[3][1]:.1f}", None, 0.4, 0.8))
    return "\n".join(o)


# ------------------------------------------------------------------ hair & head
def hair_back(P, look, B, sway, detail):
    """Hair that trails BACK (up the canvas), drawn after the shoulders, before the head."""
    st = look.get("hair", "short")
    r, hy = B["hdr"], B["hdy"]
    o = []
    sw_ = sway
    if st == "long":
        fem = look.get("female")
        L = 2.35 if fem else 2.0
        w = 1.5 if fem else 1.25
        u = [(-0.98, 0.3), (-w * 0.92, -0.35), (-w, -0.95), (-w * 0.88, -L + 0.45), (-0.62, -L + 0.05), (-0.36, -L + 0.3),
             (-0.05, -L - 0.08), (0.28, -L + 0.28), (0.62, -L + 0.0), (w * 0.88, -L + 0.5), (w, -0.95), (w * 0.92, -0.35),
             (0.98, 0.3), (0.0, -0.2)]
        pts = [(CX + x * r + sw_ * max(0.0, -y - 0.6) * 0.45, hy + y * r) for x, y in u]
        o.append(P.shape(smooth(pts), "hair", s=8))
        if detail:
            segs = []
            for x0 in (-0.75, -0.3, 0.15, 0.6):
                p0 = (CX + x0 * r, hy - 0.5 * r)
                p1 = (CX + (x0 * 1.15 - 0.1) * r + sw_ * 0.4, hy - 1.5 * r)
                p2 = (CX + (x0 * 0.9 + 0.08) * r + sw_ * 0.8, hy - (L - 0.35) * r)
                segs.append(f"M{p0[0]:.1f},{p0[1]:.1f} Q{p1[0]:.1f},{p1[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}")
            o.append(P.detail(" ".join(segs), "hair", 0.6, 0.75))
    elif st == "ponytail":
        tw = r * 0.36
        c1 = (CX + r * 0.18 + sw_ * 0.5, hy - r * 1.55)
        tip = (CX - r * 0.12 + sw_ * 1.2, hy - r * 2.55)
        pts = [(CX - tw, hy - r * 0.72), (c1[0] - tw * 1.2, c1[1]), (tip[0] - tw * 0.5, tip[1] + r * 0.3), tip,
               (tip[0] + tw * 0.7, tip[1] + r * 0.25), (c1[0] + tw * 1.15, c1[1]), (CX + tw, hy - r * 0.72)]
        o.append(P.shape(smooth(pts), "hair", s=5))
        if detail:
            o.append(P.detail(f"M{CX},{hy-r*1.0} Q{c1[0]},{c1[1]} {tip[0]+2},{tip[1]+r*0.2}", "hair", 0.6, 0.8))
        o.append(P.shape(rect(CX - tw * 1.05, hy - r * 1.12, tw * 2.1, r * 0.22, 3), "strap", s=2, hl=False))
    elif st == "braid":
        n = 7
        for i in range(n):
            t = i / (n - 1)
            x = CX + r * 0.15 + sw_ * t + math.sin(t * 2.2) * r * 0.25
            y = hy - r * 0.8 - t * r * 1.65
            rr = r * (0.3 - 0.08 * t)
            o.append(P.shape(ell(x, y, rr, rr * 0.82), "hair", s=3, hl=False))
            if detail:
                o.append(P.detail(f"M{x-rr*0.7},{y+rr*0.2} Q{x},{y-rr*0.5} {x+rr*0.7},{y+rr*0.2}", "hair", 0.5, 0.8))
        tx = CX + r * 0.15 + sw_ + math.sin(2.2) * r * 0.25
        ty = hy - r * 2.6
        o.append(P.shape(rect(tx - r * 0.2, ty + r * 0.08, r * 0.4, r * 0.18, 2), "strap", s=2, hl=False))
        o.append(P.shape(blob(tx, ty - r * 0.12, r * 0.2, 4, 0.2, 5), "hair", s=2, hl=False))
    elif st == "hood":
        c = "hoodc"
        pts = [(CX - r * 1.28, hy + r * 0.25), (CX - r * 1.45, hy - r * 0.6), (CX - r * 1.05 + sw_ * 0.3, hy - r * 1.6),
               (CX + sw_ * 0.4, hy - r * 2.05), (CX + r * 1.05 + sw_ * 0.3, hy - r * 1.6), (CX + r * 1.45, hy - r * 0.6),
               (CX + r * 1.28, hy + r * 0.25), (CX, hy + r * 0.6)]
        o.append(P.shape(smooth(pts), c, s=9))
    return "\n".join(o)


def head(P, look, B, detail, tilt=0.0):
    st = look.get("hair", "short")
    ex = look.get("extras", [])
    r, hy = B["hdr"], B["hdy"]
    o = []
    fem = look.get("female")
    lx, ly = P.light
    o.append(f'<ellipse cx="{CX - lx * r * 0.14:.1f}" cy="{hy - ly * r * 0.14:.1f}" rx="{r * 1.12:.1f}" ry="{r * 1.08:.1f}" '
             f'fill="{P.st["soot"]}" opacity="0.28" style="filter:blur({r*0.12:.1f}px)"/>')
    # ears
    if st != "hood":
        for side in (-1, 1):
            if "pointed_ears" in ex:
                pts = [(mx(side, r * 0.86), hy - r * 0.05), (mx(side, r * 1.12), hy - r * 0.3), (mx(side, r * 1.55), hy - r * 0.75),
                       (mx(side, r * 1.22), hy + r * 0.05), (mx(side, r * 0.9), hy + r * 0.28)]
                o.append(P.shape(smooth(pts, t=0.35), "skin", s=3, hl=False))
            else:
                o.append(P.shape(ell(mx(side, r * 1.03), hy - r * 0.02, r * 0.2, r * 0.3), "skin", s=3, hl=False))
    # hair mass under the skull (fringe / volume)
    if st == "bald_fringe":
        o.append(P.shape(ell(CX, hy - r * 0.22, r * 1.08, r * 1.04), "hair", s=6))
        if detail:
            o.append(P.detail(f"M{CX-r*0.72},{hy-r*0.85} l-6,-8 M{CX-r*0.24},{hy-r*1.08} l-2,-9 M{CX+r*0.28},{hy-r*1.08} l2,-9 M{CX+r*0.72},{hy-r*0.85} l6,-8", "hair", 0.7))
    elif st == "curly":
        o.append(P.shape(blob(CX, hy - r * 0.18, r * 1.22, 9, 0.1, 4), "hair", s=8))
    elif st == "bun":
        o.append(P.shape(ell(CX, hy - r * 1.02, r * 0.5, r * 0.46), "hair", s=4))
    elif st == "hood":
        pass
    # skull
    if st == "hood":
        # face recessed in the hood: only the brow, nose and beard read
        o.append(P.shape(ell(CX, hy + r * 0.32, r * 0.72, r * 0.62), "skin", s=4))
        hp = [(CX - r * 1.18, hy + r * 0.45), (CX - r * 1.22, hy - r * 0.4), (CX - r * 0.7, hy - r * 1.1), (CX, hy - r * 1.24),
              (CX + r * 0.7, hy - r * 1.1), (CX + r * 1.22, hy - r * 0.4), (CX + r * 1.18, hy + r * 0.45),
              (CX + r * 0.74, hy + r * 0.32), (CX, hy + r * 0.0), (CX - r * 0.74, hy + r * 0.32)]
        o.append(P.shape(smooth(hp), "hoodc", s=8))
        if detail:
            o.append(P.detail(f"M{CX-r*0.5},{hy-r*0.55} Q{CX},{hy-r*0.75} {CX+r*0.5},{hy-r*0.55}", "hoodc", 0.6, 0.7))
    else:
        o.append(P.shape(ell(CX, hy, r, r * 0.98), "skin", s=max(5, r * 0.26)))
    # hair cap
    if st in ("short", "long", "ponytail", "braid", "cropped", "bun"):
        cover = {"short": 0.42, "cropped": 0.12, "long": 0.55, "ponytail": 0.4, "braid": 0.4, "bun": 0.45}[st]
        wid = 1.03 if st != "cropped" else 1.0
        if st == "long" and fem:
            wid = 1.1
        pts = [(CX - r * wid, hy + r * cover * 0.6), (CX - r * (wid - 0.04), hy - r * 0.4), (CX - r * 0.55, hy - r * 0.94),
               (CX, hy - r * 1.04), (CX + r * 0.55, hy - r * 0.94), (CX + r * (wid - 0.04), hy - r * 0.4),
               (CX + r * wid, hy + r * cover * 0.6), (CX + r * 0.62, hy + r * cover), (CX + r * 0.2, hy + r * cover * 0.55),
               (CX - r * 0.15, hy + r * cover * 0.8), (CX - r * 0.62, hy + r * cover)]
        if st == "cropped":
            o.append(P.shape(smooth(pts), "hair", s=4))
            if detail:
                o.append(P.detail(f"M{CX-r*0.6},{hy-r*0.3} l-2,6 M{CX-r*0.2},{hy-r*0.6} l-1,6 M{CX+r*0.25},{hy-r*0.5} l1,6 "
                                  f"M{CX+r*0.6},{hy-r*0.2} l2,6 M{CX},{hy-r*0.1} l0,6", "hair", 0.5, 0.7))
        else:
            o.append(P.shape(smooth(pts), "hair", s=7))
            if detail:
                o.append(P.detail(f"M{CX},{hy-r*0.95} L{CX+r*0.05},{hy+r*cover*0.5} M{CX-r*0.5},{hy-r*0.78} Q{CX-r*0.62},{hy-r*0.1} {CX-r*0.55},{hy+r*cover*0.8} "
                                  f"M{CX+r*0.5},{hy-r*0.78} Q{CX+r*0.62},{hy-r*0.1} {CX+r*0.55},{hy+r*cover*0.8}", "hair", 0.6, 0.75))
        if st == "bun":
            o.append(P.shape(ell(CX, hy - r * 0.98, r * 0.44, r * 0.4), "hair", s=4))
            if detail:
                o.append(P.detail(f"M{CX-r*0.3},{hy-r*1.08} Q{CX},{hy-r*0.8} {CX+r*0.3},{hy-r*1.1}", "hair", 0.6))
            o.append(P.detail(f"M{CX-r*0.42},{hy-r*0.68} L{CX+r*0.5},{hy-r*1.32}", "strap", 1.0, 0.9))  # hairpin
        if st == "long" and fem:
            # parting + strands framing the face
            o.append(P.detail(f"M{CX+r*0.08},{hy-r*1.0} L{CX+r*0.12},{hy+r*0.15}", "hair", 0.7))
    elif st == "curly":
        o.append(P.shape(blob(CX, hy - r * 0.2, r * 1.04, 8, 0.12, 7), "hair", s=7))
        if detail:
            curls = []
            for i, (dx, dy) in enumerate([(-0.5, -0.5), (0.1, -0.7), (0.55, -0.3), (-0.2, -0.1), (0.3, 0.15), (-0.65, 0.1)]):
                x, y = CX + dx * r, hy + dy * r
                curls.append(f"M{x-r*0.14:.1f},{y:.1f} a{r*0.14:.1f},{r*0.12:.1f} 0 1,1 {r*0.2:.1f},{r*0.08:.1f}")
            o.append(P.detail(" ".join(curls), "hair", 0.6, 0.8))
    elif st == "mohawk":
        o.append(P.spot(ell(CX, hy - r * 0.1, r * 0.92, r * 0.86), P.c("hair", 1), 0.22))
        pts = [(CX - r * 0.2, hy + r * 0.6), (CX - r * 0.26, hy - r * 0.2), (CX - r * 0.24, hy - r * 0.95), (CX - r * 0.14, hy - r * 1.45),
               (CX, hy - r * 1.62), (CX + r * 0.14, hy - r * 1.45), (CX + r * 0.24, hy - r * 0.95), (CX + r * 0.26, hy - r * 0.2),
               (CX + r * 0.2, hy + r * 0.6), (CX, hy + r * 0.75)]
        o.append(P.shape(smooth(pts), "hair", s=4))
        if detail:
            o.append(P.detail(f"M{CX},{hy+r*0.5} L{CX},{hy-r*1.4} M{CX-r*0.18},{hy} l-6,8 M{CX+r*0.18},{hy-r*0.5} l6,8", "hair", 0.6))
    # extras on the head
    if "scalp_scar" in ex:
        o.append(P.detail(f"M{CX-r*0.48},{hy-r*0.62} Q{CX-r*0.1},{hy-r*0.24} {CX+r*0.48},{hy+r*0.24}", "skin", 1.2))
        o.append(P.detail(f"M{CX-r*0.31},{hy-r*0.57} l-6,8 M{CX-r*0.07},{hy-r*0.33} l-6,8 M{CX+r*0.17},{hy-r*0.1} l-6,8", "skin", 0.7))
    if "eyepatch" in ex:
        o.append(P.detail(f"M{CX-r},{hy+r*0.19} Q{CX},{hy-r*1.1} {CX+r},{hy-r*0.19}", None, 2.0))
        # the patch itself, just visible on the brow (right eye = viewer's left)
        o.append(P.shape(ell(CX - r * 0.42, hy + r * 0.86, r * 0.24, r * 0.12), "strap", s=2, hl=False))
    if "helmet_miner" in ex:
        o.append(P.shape(ell(CX, hy - r * 0.05, r * 1.18, r * 1.12), "metal", s=6))
        o.append(P.shape(ell(CX, hy - r * 0.12, r * 0.92, r * 0.86), "metal", s=9))
        if detail:
            o.append(P.detail(f"M{CX},{hy-r*0.95} L{CX},{hy+r*0.7}", "metal", 0.8))
            o.append(P.detail(f"M{CX-r*0.5},{hy-r*0.5} l10,6 M{CX+r*0.3},{hy-r*0.6} l8,8", "metal", 0.5, 0.8))
        # brass lamp at the front with a candle glow
        lx, ly = CX, hy + r * 0.92
        o.append(f'<circle cx="{lx}" cy="{ly+4}" r="{r*0.55:.1f}" fill="{P.st["glow2"]}" opacity="0.35" style="filter:blur(4px)"/>')
        o.append(P.shape(rect(lx - r * 0.26, ly - r * 0.2, r * 0.52, r * 0.4, 3), "gold", s=3))
        o.append(P.shape(ell(lx, ly + r * 0.02, r * 0.11, r * 0.11), "fire", s=1, hl=False, line=False))
    if "hood_down" in ex:
        pass  # drawn on the shoulders
    # face front: brows + nose (beards cover the jaw below)
    beard = look.get("beard", "none")
    if st != "hood" and "helmet_miner" not in ex:
        by = hy + r * 0.78
        if beard in ("braided", "long"):
            pass  # brows drawn with the beard (bushy)
        elif detail:
            o.append(P.detail(f"M{CX-r*0.62},{by} Q{CX-r*0.36},{by-r*0.1} {CX-r*0.12},{by+r*0.02} M{CX+r*0.12},{by+r*0.02} Q{CX+r*0.36},{by-r*0.1} {CX+r*0.62},{by}",
                              "skin", 0.9 if fem else 1.1, 0.9))
    if "tusks" in ex:
        for side in (-1, 1):
            tx = CX + side * r * 0.36
            ty = hy + r * 1.02
            o.append(P.shape(smooth([(tx - 6, ty - 4), (tx + 6, ty - 4), (tx + side * 7, ty + 10), (tx + side * 4, ty + 17), (tx - side * 2, ty + 8)], t=0.3), "ivory", s=1, hl=False))
    return "\n".join(o)


def beard_front(P, look, B, detail):
    beard = look.get("beard", "none")
    r, hy = B["hdr"], B["hdy"]
    o = []
    dwarf = look.get("build") == "dwarf"
    if beard == "none":
        pass
    elif beard == "stubble":
        pts = [(CX - r * 0.95, hy + r * 0.25), (CX - r * 0.7, hy + r * 0.85), (CX, hy + r * 1.08), (CX + r * 0.7, hy + r * 0.85),
               (CX + r * 0.95, hy + r * 0.25), (CX + r * 0.6, hy + r * 0.65), (CX, hy + r * 0.8), (CX - r * 0.6, hy + r * 0.65)]
        o.append(P.spot(smooth(pts), P.c("beard", 2), 0.45))
        if detail:
            dots = " ".join(f"M{CX + dx * r:.1f},{hy + dy * r:.1f} h0.5" for dx, dy in
                            [(-0.7, 0.6), (-0.4, 0.82), (0, 0.92), (0.4, 0.82), (0.7, 0.6), (-0.2, 0.9), (0.2, 0.9)])
            o.append(P.detail(dots, None, 1.4, 0.6))
    else:
        if beard == "short":
            L, W = 1.55, 0.86
        elif beard == "long":
            L, W = (3.3, 1.22) if dwarf else (2.7, 0.92)
        else:  # braided
            L, W = 3.3, 1.0
        pts = [(CX - r * W * 0.95, hy + r * 0.55), (CX - r * W * 1.12, hy + r * 1.05), (CX - r * W * 0.78, hy + r * (0.6 + L * 0.42)),
               (CX - r * W * 0.32, hy + r * (0.5 + L * 0.72)), (CX, hy + r * (0.5 + L * 0.8)),
               (CX + r * W * 0.32, hy + r * (0.5 + L * 0.72)), (CX + r * W * 0.78, hy + r * (0.6 + L * 0.42)),
               (CX + r * W * 1.12, hy + r * 1.05), (CX + r * W * 0.95, hy + r * 0.55), (CX, hy + r * 0.95)]
        if beard == "braided":
            # the approved blacksmith beard, scaled from its r=42 head
            q = r / 42.0
            bd = [(222, 228), (210, 256), (226, 292), (244, 322), (256, 334), (268, 322), (286, 292), (302, 256), (290, 228), (256, 238)]
            pts = [(CX + (x - 256) * q, hy + (y - 196) * q) for x, y in bd]
        o.append(P.shape(smooth(pts), "beard", s=8 if L > 2 else 5))
        if detail:
            ly = hy + r * (0.5 + L * 0.66)
            o.append(P.detail(f"M{CX-r*0.45*W},{hy+r*1.3} Q{CX-r*0.38*W},{(hy+r*1.3+ly)/2} {CX-r*0.1},{ly} M{CX},{hy+r*1.3} L{CX},{ly+r*0.1} "
                              f"M{CX+r*0.45*W},{hy+r*1.3} Q{CX+r*0.38*W},{(hy+r*1.3+ly)/2} {CX+r*0.1},{ly}", "beard", 0.7, 0.8))
        if beard == "braided":
            q = r / 42.0
            o.append(P.shape(rect(CX - 9 * q, hy + 116 * q, 18 * q, 12 * q, 3), "gold", s=3))
        if dwarf and beard == "long":
            # two braided tails with bronze rings
            for side in (-1, 1):
                x = CX + side * r * 0.42
                y = hy + r * (0.5 + L * 0.7)
                o.append(P.shape(rect(x - r * 0.13, y, r * 0.26, r * 0.2, 2), "gold", s=2))
        # moustache + nose tip + bushy brows
        for side in (-1, 1):
            o.append(P.shape(ell(mx(side, r * 0.43), hy + r * 1.05, r * 0.48, r * 0.22), "beard", s=3, hl=False))
            o.append(P.shape(ell(mx(side, r * 0.43), hy + r * 0.86, r * 0.32, r * 0.16), "beard", s=2, hl=False))
    o.append(P.shape(ell(CX, hy + r * (1.0 if beard not in ("none", "stubble") else 0.98), r * 0.19, r * 0.16), "skin", s=2, hl=False))
    return "\n".join(o)


# ------------------------------------------------------------------ the figure
def figure(P, look, step=0.0, breathe=0.0, detail=True):
    """South-facing figure. step in [-1, 1] (+1 = viewer-left foot forward), breathe in [0, 1]."""
    B = build_of(look)
    armor = look.get("armor", "none")
    ex = look.get("extras", [])
    fem = look.get("female")
    sw, sry, sy = B["sw"], B["sry"], B["sy"]
    cw, ch, cy = B["cw"], B["ch"], B["cy"]
    ax = B["ax"]
    br = 1 + 0.025 * breathe
    gown = bool(fem and armor == "robe" and look.get("hand", "none") == "none")
    sway = step * 6
    twist = step * 3.2
    o = []

    # cloak (behind, flows up the canvas)
    if look.get("cloak"):
        cl = max(92, min(114, sw * 1.4)) / 146.0
        ck0 = [(CX - sw * 0.96, sy + 4), (CX - sw * 1.2 - sway * 0.2, sy - 62), (CX - sw * 1.04 + sway, sy - 124),
              (CX - sw * 0.38 + sway * 1.4, sy - 146), (CX + sw * 0.05 + sway * 1.2, sy - 136), (CX + sw * 0.5 + sway * 1.4, sy - 150),
              (CX + sw * 1.1 + sway, sy - 122), (CX + sw * 1.22 - sway * 0.2, sy - 60), (CX + sw * 0.96, sy + 6), (CX, sy + 18)]
        ck = [(x, sy + (y - sy) * cl) for x, y in ck0]
        if armor == "robe" or look.get("build") in ("halfling", "dwarf"):
            ck = [(x, sy + (y - sy) * 0.8) for x, y in ck]
        o.append(P.shape(smooth(ck), "cloak", s=12))
        if detail:
            o.append(P.detail(f"M{CX-sw*0.72},{sy-40*cl} Q{CX-sw*0.6+sway*0.5},{sy-90*cl} {CX-sw*0.7+sway},{sy-128*cl} "
                              f"M{CX+sw*0.74},{sy-40*cl} Q{CX+sw*0.62+sway*0.5},{sy-90*cl} {CX+sw*0.72+sway},{sy-124*cl} "
                              f"M{CX+sway*0.3},{sy-50*cl} Q{CX+sway*0.6},{sy-96*cl} {CX+sway*1.1},{sy-130*cl}", "cloak", 0.8, 0.75))

    # boots (feet, not twisted)
    for side in (-1, 1):
        off = (step if side < 0 else -step) * B["stride"]
        x = mx(side, B["fx"])
        y = B["fty"] + off
        o.append(P.shape(ell(x, y, B["brx"], B["bry"]), "boot", s=7))
        if detail:
            o.append(P.detail(f"M{x-B['brx']*0.7},{y+B['bry']*0.45} Q{x},{y+B['bry']*0.85} {x+B['brx']*0.7},{y+B['bry']*0.45}", "boot", 1))

    up = []  # upper body (twisted)
    up.append(back_item(P, look, B, sway, detail))

    # robe hem over the legs
    if gown:
        hw = cw * 1.42
        ft = B["fty"]
        wy = cy + ch * 0.35
        hem = [(CX - cw * 0.6, wy), (CX - hw * 0.8, (wy + ft) / 2), (CX - hw - sway * 0.3, ft + 2), (CX - hw * 0.62, ft + 14 + step * 4),
               (CX - hw * 0.2, ft + 10), (CX + hw * 0.2, ft + 16), (CX + hw * 0.62, ft + 12 - step * 4), (CX + hw - sway * 0.3, ft + 2),
               (CX + hw * 0.8, (wy + ft) / 2), (CX + cw * 0.6, wy)]
        up.append(P.shape(smooth(hem, t=0.45), "shirt", s=11))
        if detail:
            up.append(P.detail(f"M{CX-cw*0.35},{wy+8} Q{CX-hw*0.5},{ft-24} {CX-hw*0.62},{ft+10} M{CX},{wy+10} Q{CX+4},{ft-20} {CX-hw*0.2},{ft+8} "
                               f"M{CX+cw*0.35},{wy+8} Q{CX+hw*0.45},{ft-24} {CX+hw*0.62},{ft+8}", "shirt", 0.7, 0.75))
    elif armor == "robe":
        hw = cw * (1.18 if cw < 80 else 1.0)
        hem = [(CX - cw * 0.9, cy), (CX - hw, B["fty"] - 4), (CX - hw * 0.6, B["fty"] + 12), (CX, B["fty"] + 16),
               (CX + hw * 0.6, B["fty"] + 12), (CX + hw, B["fty"] - 4), (CX + cw * 0.9, cy)]
        up.append(P.shape(smooth(hem, t=0.4), "shirt", s=10))
        if detail:
            up.append(P.detail(f"M{CX-hw*0.5},{cy+20} Q{CX-hw*0.6},{B['fty']-20} {CX-hw*0.55},{B['fty']+6} "
                               f"M{CX+hw*0.5},{cy+20} Q{CX+hw*0.6},{B['fty']-20} {CX+hw*0.55},{B['fty']+6} "
                               f"M{CX},{cy+30} L{CX},{B['fty']+12}", "shirt", 0.7, 0.75))

    # weapon hand = viewer's left in the south pose (side -1)
    ws = -1
    swing = B["swing"]
    arm_off = {-1: -step * swing, 1: step * swing}
    hx = {s: mx(s, ax * br) for s in (-1, 1)}
    hyy = {s: B["hy"] + arm_off[s] for s in (-1, 1)}
    up.append(held_item(P, look, B, hx[ws], hyy[ws], ws, detail))

    # tongs at the hip (the player)
    if look.get("_id") == "player":
        tx = CX + 92
        up.append(P.shape(poly([(tx - 4, 280), (tx + 4, 280), (tx + 14, 372), (tx + 6, 374)]), "metal", s=3, hl=False))
        up.append(P.shape(poly([(tx - 4, 280), (tx + 4, 280), (tx - 2, 374), (tx - 10, 372)]), "metal", s=3, hl=False))

    # sleeves / upper arms
    sleeve = "shirt"
    bare = look.get("build") == "orc"
    if bare:
        sleeve = "skin"
    if armor == "chain":
        sleeve = "chain"
    for side in (-1, 1):
        x = mx(side, (ax - 4) * br)
        yy = B["uy"] + arm_off[side] * 0.3
        if gown:
            up.append(P.shape(ell(x, yy + B["ury"] * 0.25, B["urx"] * 0.82, B["ury"] * 0.8), "skin", s=5))
            up.append(P.shape(ell(x, yy - B["ury"] * 0.3, B["urx"] * 1.2 * br, B["ury"] * 0.62), "shirt", s=6))
        elif armor == "robe":
            up.append(P.shape(smooth([(x - B["urx"] * 0.9, yy - B["ury"] * 0.8), (x + B["urx"] * 0.9, yy - B["ury"] * 0.8),
                                      (x + B["urx"] * 1.45, yy + B["ury"] * 0.95 + arm_off[side] * 0.6),
                                      (x, yy + B["ury"] * 1.2 + arm_off[side] * 0.7),
                                      (x - B["urx"] * 1.45, yy + B["ury"] * 0.95 + arm_off[side] * 0.6)], t=0.45), "shirt", s=8))
        else:
            up.append(P.shape(ell(x, yy, B["urx"] * br, B["ury"]), sleeve, s=8))

    # torso
    if fem and look["build"] in ("slim", "average"):
        up.append(P.shape(ell(CX, cy + ch * 0.62, cw * 1.0 * br, ch * 0.52), "shirt" if armor != "leather" else "leather", s=7))
    torso_role = {"leather": "leather", "chain": "chain", "plate": "shirt", "robe": "shirt", "apron": "shirt", "none": "shirt"}[armor]
    up.append(P.shape(ell(CX, cy, (cw * (0.74 if gown else 0.86 if fem else 1)) * br, ch * br), torso_role, s=12 if cw > 80 else 9))
    if gown and detail:
        up.append(P.detail(f"M{CX},{cy-ch*0.6} L{CX},{cy+ch*0.8} M{CX-5},{cy-ch*0.3} l10,5 M{CX-5},{cy} l10,5 M{CX-5},{cy+ch*0.3} l10,5", "shirt", 0.6, 0.8))
    if armor == "chain" and detail:
        rings = []
        for j in range(4):
            for i in range(-3, 4):
                x = CX + i * cw * 0.24 + (j % 2) * cw * 0.12
                y = cy - ch * 0.4 + j * ch * 0.28
                if ((x - CX) / cw) ** 2 + ((y - cy) / ch) ** 2 < 0.8:
                    rings.append(f"M{x-5:.1f},{y:.1f} q5,6 10,0")
        up.append(P.detail(" ".join(rings), "chain", 0.6, 0.8))
    if armor == "leather" and detail:
        up.append(P.detail(f"M{CX},{cy-ch*0.7} L{CX},{cy+ch*0.75} M{CX-6},{cy-ch*0.4} l12,6 M{CX-6},{cy-ch*0.1} l12,6 M{CX-6},{cy+ch*0.2} l12,6", "leather", 0.7, 0.85))
        up.append(P.detail(f"M{CX-cw*0.55},{cy-ch*0.5} Q{CX-cw*0.62},{cy} {CX-cw*0.48},{cy+ch*0.6} M{CX+cw*0.55},{cy-ch*0.5} Q{CX+cw*0.62},{cy} {CX+cw*0.48},{cy+ch*0.6}", "leather", 0.6, 0.6))
    if armor == "plate":
        bp = [(CX - cw * 0.92, cy - ch * 0.5), (CX, cy - ch * 0.3), (CX + cw * 0.92, cy - ch * 0.5), (CX + cw * 0.86, cy + ch * 0.4),
              (CX + cw * 0.4, cy + ch * 0.9), (CX, cy + ch * 0.98), (CX - cw * 0.4, cy + ch * 0.9), (CX - cw * 0.86, cy + ch * 0.4)]
        up.append(P.shape(smooth(bp), "metal", s=11))
        up.append(f'<path d="{smooth(bp)}" fill="url(#{P.hatch_id})" opacity="0.35"/>')
        if detail:
            up.append(P.detail(f"M{CX},{cy-ch*0.3} L{CX},{cy+ch*0.95}", "metal", 0.9))
            up.append(P.detail(f"M{CX-cw*0.6},{cy-ch*0.2} Q{CX-cw*0.4},{cy+ch*0.4} {CX-cw*0.15},{cy+ch*0.8} M{CX+cw*0.6},{cy-ch*0.2} Q{CX+cw*0.4},{cy+ch*0.4} {CX+cw*0.15},{cy+ch*0.8}", "metal", 0.5, 0.6))
            up.append(P.detail(f"M{CX+cw*0.4},{cy} l12,10 M{CX-cw*0.3},{cy+ch*0.5} l10,6", "metal", 0.5, 0.9))
    if armor == "apron":
        heavy = cw > 80
        aw = cw * (0.92 if heavy else 0.86)
        top = cy - ch * (0.2 if heavy else 0.35)
        bot = cy + ch * (1.0 if heavy else 1.15)
        ap = [(CX - aw, top + 4), (CX - aw * 0.82, cy + ch * 0.55), (CX, bot), (CX + aw * 0.82, cy + ch * 0.55), (CX + aw, top + 4), (CX, top - 6)]
        up.append(P.shape(smooth(ap), "apron", s=12))
        if detail:
            q = cw / 92
            up.append(P.shape(rect(CX - 34 * q, cy + 24 * q, 40 * q, 30 * q, 6), "apron", s=5, hl=False))
            up.append(P.detail(f"M{CX-28*q},{cy+28*q} L{CX},{cy+28*q}", "apron", 0.7))
            up.append(P.detail(f"M{CX-aw*0.65},{cy+12*q} Q{CX-aw*0.58},{cy+44*q} {CX-aw*0.28},{cy+66*q} M{CX+aw*0.65},{cy+12*q} Q{CX+aw*0.58},{cy+44*q} {CX+aw*0.28},{cy+66*q}", "apron", 0.8, 0.7))
            up.append(P.spot(ell(CX + 36 * q, cy + 40 * q, 10 * q, 7 * q), P.c("apron", 2), 0.6))
            up.append(P.spot(ell(CX + 48 * q, cy + 28 * q, 5 * q, 4 * q), P.c("apron", 2), 0.6))
            if look.get("_id") == "player":
                up.append(P.detail("M196,300 l10,8 M206,322 l14,4 M300,318 l-12,10 M318,292 l-6,12", "apron", 0.6, 0.8))
    # belt
    by = cy + ch * (0.0 if cw > 80 else 0.55)
    bw = cw * (0.86 if fem else 1.0) * br
    if gown:
        up.append(P.detail(f"M{CX-bw*0.7},{by-6} Q{CX},{by+6} {CX+bw*0.7},{by-6}", "gold", 1.6))
        up.append(P.shape(ell(CX, by + 1, 6, 5), "gem", s=2))
    elif armor == "robe":
        up.append(P.detail(f"M{CX-bw*0.95},{by-4} Q{CX},{by+10} {CX+bw*0.95},{by-4}", "strap", 2.6))
        up.append(P.detail(f"M{CX+bw*0.3},{by+4} q4,20 -2,40 M{CX+bw*0.3+6},{by+4} q8,18 6,34", "strap", 1.4))
    elif armor != "plate" or True:
        bt = 12 if cw > 80 else 9
        up.append(P.shape(smooth([(CX - bw, by - 2), (CX, by + 10), (CX + bw, by - 2), (CX + bw * 0.98, by + bt + 2),
                                  (CX, by + bt + 14), (CX - bw * 0.98, by + bt + 2)]), "leather" if armor != "leather" else "strap", s=3))
        up.append(P.shape(rect(CX - 10, by + 2, 20, 18 if cw > 80 else 14, 3), "gold", s=3))
        if cw > 80:
            up.append(P.shape(rect(CX - bw * 0.92, by + 6, 30, 32, 8), "leather", s=5))
    # shield strap / quiver strap across the chest
    if look.get("back") in ("shield", "quiver", "lute"):
        a = (CX - sw * 0.7, sy - sry * 0.4)
        b = (CX + cw * 0.85, cy + ch * 0.55)
        up.append(P.shape(poly([(a[0] - 6, a[1] + 4), (a[0] + 8, a[1] - 4), (b[0] + 6, b[1] - 4), (b[0] - 6, b[1] + 4)]), "strap", s=2, hl=False))
    if look.get("back") == "pack":
        for side in (-1, 1):
            x = mx(side, sw * 0.42)
            up.append(P.shape(poly([(x - 7, sy - sry * 0.9), (x + 7, sy - sry * 0.9), (x + 7 + side * 2, sy + sry * 0.75), (x - 7 + side * 2, sy + sry * 0.75)]),
                              "strap", s=2, hl=False))

    # shoulders
    sh_role = {"chain": "chain", "leather": "shirt", "plate": "shirt"}.get(armor, "shirt")
    if bare:
        sh_role = "skin" if armor == "leather" else "shirt"
    if fem:
        sp = [(CX - sw * br, sy + sry * 0.15), (CX - sw * 0.82 * br, sy - sry * 0.6), (CX - sw * 0.3, sy - sry * 0.92), (CX, sy - sry * 0.85),
              (CX + sw * 0.3, sy - sry * 0.92), (CX + sw * 0.82 * br, sy - sry * 0.6), (CX + sw * br, sy + sry * 0.15),
              (CX + sw * 0.7 * br, sy + sry * 0.8), (CX, sy + sry * 0.98), (CX - sw * 0.7 * br, sy + sry * 0.8)]
        up.append(P.shape(smooth(sp), sh_role, s=10))
    else:
        up.append(P.shape(ell(CX, sy, sw * br, sry * br), sh_role, s=12 if sw > 90 else 10))
    if detail:
        up.append(P.detail(f"M{CX-sw*0.73},{sy-sry*0.25} Q{CX-sw*0.55},{sy+sry*0.2} {CX-sw*0.64},{sy+sry*0.53} "
                           f"M{CX+sw*0.73},{sy-sry*0.25} Q{CX+sw*0.55},{sy+sry*0.2} {CX+sw*0.64},{sy+sry*0.53}", "shirt", 0.8, 0.8))
    if fem and detail and armor not in ("plate",) and not gown:
        # bust line at the front of the chest
        up.append(P.detail(f"M{CX-sw*0.5},{sy+sry*0.72} Q{CX-sw*0.26},{sy+sry*1.08} {CX-sw*0.04},{sy+sry*0.82} "
                           f"M{CX+sw*0.04},{sy+sry*0.82} Q{CX+sw*0.26},{sy+sry*1.08} {CX+sw*0.5},{sy+sry*0.72}", "shirt", 0.8, 0.8))
    if armor == "leather" and bare:
        # barbarian harness + fur mantle on one shoulder
        for side in (-1, 1):
            up.append(P.shape(poly([(mx(side, sw * 0.62), sy - sry * 0.7), (mx(side, sw * 0.42), sy - sry * 0.85),
                                    (mx(-side, sw * 0.5), sy + sry * 0.95), (mx(-side, sw * 0.7), sy + sry * 0.8)]), "strap", s=2, hl=False))
        up.append(P.shape(blob(CX + sw * 0.72, sy - 4, sw * 0.34, 9, 0.16, 11, squash=0.85), "hair", s=6, fill_override="#6a5a48"))
        up.append(P.shape(ell(CX, sy + sry * 0.1, B["hdr"] * 0.6, B["hdr"] * 0.5), "metal", s=3))
    elif armor == "leather":
        up.append(P.shape(ell(CX, sy + sry * 0.1, sw * 0.62 * br, sry * 0.78), "leather", s=7))
        for side in (-1, 1):
            up.append(P.shape(ell(mx(side, sw * 0.76 * br), sy - 2, sw * 0.26, sry * 0.5), "leather", s=5))
    if gown:
        # neckline: bare skin under the chin + a fine chain necklace
        up.append(P.shape(smooth([(CX - sw * 0.5, sy + sry * 0.05), (CX, sy - sry * 0.1), (CX + sw * 0.5, sy + sry * 0.05),
                                  (CX + sw * 0.34, sy + sry * 0.62), (CX, sy + sry * 0.92), (CX - sw * 0.34, sy + sry * 0.62)]), "skin", s=4, hl=False))
        up.append(P.detail(f"M{CX-sw*0.36},{sy+sry*0.25} Q{CX},{sy+sry*0.82} {CX+sw*0.36},{sy+sry*0.25}", "gold", 0.9))
        up.append(P.shape(ell(CX, sy + sry * 0.62, 5, 6), "gem", s=2))
    elif armor == "robe":
        # deep collar / stole
        up.append(P.shape(smooth([(CX - sw * 0.5, sy - sry * 0.5), (CX, sy - sry * 0.2), (CX + sw * 0.5, sy - sry * 0.5),
                                  (CX + sw * 0.32, sy + sry * 0.7), (CX, sy + sry * 1.0), (CX - sw * 0.32, sy + sry * 0.7)]),
                          "shirt", s=5, fill_override=P.c("shirt", 2)))
    if armor == "apron":
        q = sw / 110
        up.append(P.shape(poly([(CX - 44 * q, sy + 58 * q), (CX - 30 * q, sy + 58 * q), (CX - 20 * q, sy - 52 * q), (CX - 34 * q, sy - 56 * q)]), "strap", s=3, hl=False))
        up.append(P.shape(poly([(CX + 30 * q, sy + 58 * q), (CX + 44 * q, sy + 58 * q), (CX + 34 * q, sy - 56 * q), (CX + 20 * q, sy - 52 * q)]), "strap", s=3, hl=False))
        up.append(P.shape(poly([(CX - 34 * q, sy - 56 * q), (CX - 20 * q, sy - 52 * q), (CX + 34 * q, sy - 56 * q), (CX + 20 * q, sy - 52 * q), (CX, sy - 62 * q)]), "strap", s=3, hl=False))
    if "hood_down" in ex:
        hr_ = B["hdr"]
        up.append(P.shape(smooth([(CX - hr_ * 1.3, sy - sry * 0.25), (CX - hr_ * 1.1, sy - sry * 1.25), (CX, sy - sry * 1.55),
                                  (CX + hr_ * 1.1, sy - sry * 1.25), (CX + hr_ * 1.3, sy - sry * 0.25), (CX, sy - sry * 0.5)]), "hoodc", s=7))
        if detail:
            up.append(P.detail(f"M{CX-hr_*0.8},{sy-sry*0.7} Q{CX},{sy-sry*1.25} {CX+hr_*0.8},{sy-sry*0.7}", "hoodc", 0.7, 0.8))

    # pauldrons
    if armor == "plate":
        for side in (-1, 1):
            x = mx(side, sw * 0.8 * br)
            pr = sw * 0.36
            up.append(P.shape(ell(x + side * 3, sy + pr * 0.45, pr * 0.9, pr * 0.5), "metal", s=4))
            up.append(P.shape(ell(x, sy - 2, pr, pr * 0.85), "metal", s=8))
            if detail:
                up.append(P.detail(f"M{x-pr*0.6},{sy+pr*0.15} Q{x},{sy+pr*0.5} {x+pr*0.6},{sy+pr*0.15}", "metal", 0.6))
                for a in (-0.9, 0.0, 0.9):
                    up.append(P.spot(ell(x + pr * 0.8 * math.sin(a), sy - 2 - pr * 0.62 * math.cos(a), 2.6, 2.6), P.c("gold", 1)))
        # gorget
        up.append(P.shape(ell(CX, sy + sry * 0.2, B["hdr"] * 1.15, B["hdr"] * 0.75), "metal", s=5))
    if "pauldron" in ex:
        px = CX + 92 * sw / 110
        q = sw / 110
        up.append(P.shape(ell(px, sy - 6 * q, 38 * q, 32 * q), "metal", s=9))
        up.append(P.shape(ell(px + 4 * q, sy + 12 * q, 30 * q, 16 * q), "metal", s=5))
        if detail:
            for a in (-1.2, -0.6, 0.0, 0.6, 1.2):
                up.append(P.spot(ell(px + 30 * q * math.sin(a), sy - 6 * q + 24 * q * math.cos(a), 2.6, 2.6), P.c("gold", 1)))
            up.append(P.detail(f"M{px-16*q},{sy-22*q} L{px+14*q},{sy-30*q} M{px-10*q},{sy-12*q} L{px+6*q},{sy-16*q}", "metal", 0.6, 0.8))
            up.append(P.detail(f"M{px-22*q},{sy+4*q} l18,-6 M{px},{sy+12*q} l14,6", "metal", 0.6, 0.9))

    # hair that hangs down the back (over the shoulders), then forearms, hands, head
    up.append(hair_back(P, look, B, sway, detail))
    for side in (-1, 1):
        x = hx[side]
        fy = B["fy"] + arm_off[side] * 0.75
        hyv = hyy[side]
        if gown:
            up.append(P.shape(ell(x, fy, B["frx"] * 0.85, B["fry"]), "skin", s=5))
            up.append(P.detail(f"M{x-B['frx']*0.8},{fy+B['fry']*0.5} Q{x},{fy+B['fry']*0.7} {x+B['frx']*0.8},{fy+B['fry']*0.5}", "gold", 1.2))
        elif armor == "robe":
            up.append(P.shape(ell(x, hyv - B["hr"] * 0.6, B["frx"] * 1.25, B["hr"] * 0.9), "shirt", s=4, fill_override=P.c("shirt", 2)))
        else:
            fr = "skin" if bare or (armor in ("apron", "none") and look.get("build") == "heavy") else ("chain" if armor == "chain" else "shirt")
            up.append(P.shape(ell(x, fy, B["frx"], B["fry"]), fr, s=7))
            if fr == "skin" and detail:
                up.append(P.detail(f"M{x-8},{fy-14} l4,6 M{x+4},{fy-18} l4,6 M{x-4},{fy+4} l4,6 M{x+8},{fy} l3,6", "skin", 0.6, 0.7))
            if armor in ("leather", "plate", "apron") or look.get("_id") == "player":
                role = "metal" if armor == "plate" else "leather"
                up.append(P.shape(rect(x - B["frx"], fy - B["fry"] * 0.75, 2 * B["frx"], B["fry"] * 0.6, 5), role, s=4))
        up.append(P.shape(ell(x, hyv, B["hr"], B["hr"] * 0.92), "skin", s=5))
        if detail:
            up.append(P.detail(f"M{x-B['hr']*0.5},{hyv+B['hr']*0.38} Q{x},{hyv+B['hr']*0.62} {x+B['hr']*0.5},{hyv+B['hr']*0.38}", "skin", 0.6))
    # hand item parts that sit OVER the fist (sword pommel already above; bow grip)
    up.append(head(P, look, B, detail))
    up.append(beard_front(P, look, B, detail))

    # soot & wear (never on faces)
    if P.st.get("noir"):
        t = P.st["noir"] / 0.15
        sp = [(mx(-1, ax), B["fy"] + 10, 9, 6, .3), (mx(1, ax), B["fy"] + 14, 10, 6, .3)]
        if armor == "apron":
            sp += [(CX - cw * 0.3, cy + ch * 0.7, 16, 7, .3), (CX + cw * 0.36, cy + ch * 0.75, 12, 6, .3)]
        for (x, y, rx, ry, op) in sp:
            up.append(soot(P, x, y, rx, ry, min(op * t * (1.0 if look.get("_id") == "player" or armor == "apron" else 0.55), 0.45)))

    o.append(f'<g transform="rotate({twist:.2f} {CX} {cy}) translate({sway*0.25:.2f},0)">' + "\n".join(up) + "</g>")
    return "\n".join(o)


def anchor(look):
    """Design-space point mapped to the cell's ground point, and the build scale."""
    B = build_of(look)
    off = 2 if look.get("build") == "heavy" else -8
    return (CX, (B["sy"] + B["fty"]) / 2 + off), B["k"]


def shadow_size(look):
    B = build_of(look)
    return B["sw"] * 1.25, (B["fty"] + B["bry"] - (B["sy"] - B["sry"])) * 0.5
