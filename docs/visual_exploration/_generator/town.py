"""Straight top-down village layout shared by all five styles (1920x1080)."""
import math
import random
from svgcore import Painter, ell, rect, poly, smooth, blob, uid, svg_doc
import subjects

W, H = 1920, 1080
SHADOW = {  # dx, dy, colour, opacity, blur
    "gothic": (16, 20, "#000000", 0.62, 3),
    "storybook": (34, 26, "#4a2c10", 0.32, 6),
    "bold": (18, 22, "#1c1a2e", 0.30, 0),
    "ink": (18, 22, None, 0.75, 0),
    "prod": (16, 18, "#2e2a35", 0.20, 0),
}


def cast_shadow(P, x, y, w, h, mul=1.0):
    dx, dy, col, op, bl = SHADOW[P.k]
    dx, dy = dx * mul, dy * mul
    pts = [(x, y), (x + w, y), (x + w + dx, y + dy), (x + w + dx, y + h + dy), (x + dx, y + h + dy), (x, y + h)]
    fill = f"url(#{P.hatch_id})" if col is None else col
    st = f' style="filter:blur({bl}px)"' if bl else ""
    return f'<path d="{poly(pts)}" fill="{fill}" opacity="{op}"{st}/>'


def roof(P, x, y, w, h, role, ridge="h", chimney=None, smoke=True):
    o = [cast_shadow(P, x, y, w, h)]
    l, b, s = P.pal[role]
    k = P.k
    dark = s if k in ("bold", "prod") else (s if k == "gothic" else b)
    lit = b if k in ("bold", "prod", "gothic") else l
    if k == "storybook":
        lit, dark = l, b
    if ridge == "h":
        a = rect(x, y, w, h / 2)
        c = rect(x, y + h / 2, w, h / 2)
        rows = [f"M{x+4},{y+yy:.0f} L{x+w-4},{y+yy:.0f}" for yy in range(14, int(h) - 6, 14) if abs(yy - h / 2) > 6]
        ridge_d = f"M{x},{y+h/2} L{x+w},{y+h/2}"
    else:
        a = rect(x, y, w / 2, h)
        c = rect(x + w / 2, y, w / 2, h)
        rows = [f"M{x+xx:.0f},{y+4} L{x+xx:.0f},{y+h-4}" for xx in range(14, int(w) - 6, 14) if abs(xx - w / 2) > 6]
        ridge_d = f"M{x+w/2},{y} L{x+w/2},{y+h}"
    o.append(P.shape(a, role, flat=True, fill_override=lit, line=False))
    o.append(P.shape(c, role, flat=True, fill_override=dark, line=False))
    if k in ("gothic", "ink"):
        o.append(f'<path d="{c}" fill="url(#{P.hatch_id})" opacity="{0.5 if k=="gothic" else 0.7}"/>')
    if k == "storybook":
        gid = uid("rg")
        P.defs.append(f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff6d0" stop-opacity="0.35"/>'
                      f'<stop offset="1" stop-color="#5a3010" stop-opacity="0.25"/></linearGradient>')
        o.append(f'<path d="{rect(x,y,w,h)}" fill="url(#{gid})"/>')
    if k != "prod" or True:
        o.append(P.detail(" ".join(rows), role, 0.5 if k != "prod" else 0.7, 0.55 if k != "bold" else 0.35))
    o.append(P.detail(ridge_d, role, 1.0))
    if k in ("gothic", "bold", "ink", "storybook"):
        o.append(f'<path d="{rect(x,y,w,h)}" fill="none" stroke="{P.ink if k!="storybook" else s}" '
                 f'stroke-width="{ {"gothic":5,"bold":4.5,"ink":2.4,"storybook":2.4}[k] * P.lw_mul}" stroke-linejoin="round"/>')
    if chimney:
        cx, cy = chimney
        o.append(cast_shadow(P, cx - 14, cy - 14, 28, 28, 0.6))
        o.append(P.shape(rect(cx - 14, cy - 14, 28, 28, 3), "stone", s=4))
        o.append(P.spot(rect(cx - 7, cy - 7, 14, 14, 2), "#120c08"))
        if smoke:
            o.append(smoke_puffs(P, cx, cy))
    return "\n".join(o)


def smoke_puffs(P, cx, cy, n=5, glow=False):
    k = P.k
    o = []
    for i in range(n):
        x, y, r = cx + 16 + i * 22, cy - 10 - i * 16, 10 + i * 5
        if k == "gothic":
            o.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#8a96a8" opacity="{0.28 - i*0.04:.2f}" style="filter:blur(5px)"/>')
        elif k == "storybook":
            o.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#f6eee0" opacity="{0.55 - i*0.08:.2f}" style="filter:blur(4px)"/>')
        elif k == "bold":
            o.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#ffffff" stroke="{P.ink}" stroke-width="3" opacity="{0.95 - i*0.12:.2f}"/>')
        elif k == "ink":
            o.append(f'<path d="M{x-r},{y} a{r},{r} 0 1,1 {r},{r} a{r*0.5},{r*0.5} 0 1,1 {-r*0.4},{-r*0.6}" fill="none" stroke="{P.ink}" stroke-width="1.4" opacity="{0.8 - i*0.1:.2f}"/>')
        else:
            o.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#e8e4ec" opacity="{0.7 - i*0.1:.2f}"/>')
    return "\n".join(o)


def barrel(P, x, y, r=13):
    return "\n".join([cast_shadow(P, x - r, y - r, 2 * r, 2 * r, 0.35),
                      P.shape(ell(x, y, r), "wood", s=3),
                      P.detail(ell(x, y, r * 0.7), "wood", 0.5),
                      P.detail(f"M{x-r*0.5},{y} L{x+r*0.5},{y}", "wood", 0.4, 0.6)])


def crate(P, x, y, s=24):
    return "\n".join([cast_shadow(P, x, y, s, s, 0.35), P.shape(rect(x, y, s, s, 2), "wood", s=3),
                      P.detail(f"M{x+3},{y+3} L{x+s-3},{y+s-3} M{x+s-3},{y+3} L{x+3},{y+s-3}", "wood", 0.5)])


def fence(P, pts, post=10):
    o = []
    d = poly(pts, close=False)
    k = P.k
    col = P.c("wood", 2 if k != "ink" else 1)
    lw = {"gothic": 7, "storybook": 6, "bold": 7, "ink": 4, "prod": 6}[k]
    if k in ("bold", "gothic"):
        o.append(f'<path d="{d}" fill="none" stroke="{P.ink}" stroke-width="{lw+5}" stroke-linecap="round"/>')
    o.append(f'<path d="{d}" fill="none" stroke="{P.c("wood",1)}" stroke-width="{lw}" stroke-linecap="round"/>')
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        L = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(L // 40))
        for i in range(n + 1):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            o.append(P.shape(rect(x - post / 2, y - post / 2, post, post, 2), "wood", s=2, hl=False))
    return "\n".join(o)


def villager(P, x, y, rot, role, hair="hair", scale=1.0):
    s = scale
    o = [f'<g transform="translate({x},{y}) rotate({rot}) scale({s})">',
         f'<ellipse cx="4" cy="6" rx="30" ry="26" fill="#000" opacity="0.25"/>' if P.k != "ink" else
         f'<ellipse cx="4" cy="6" rx="30" ry="26" fill="url(#{P.hatch_id})" opacity="0.5"/>',
         P.shape(ell(-22, 4, 9, 14), role, s=2, hl=False),
         P.shape(ell(22, 4, 9, 14), role, s=2, hl=False),
         P.shape(ell(0, 0, 28, 17), role, s=4),
         P.shape(ell(0, 10, 9, 6), "skin", s=1, hl=False),
         P.shape(ell(0, 0, 13, 13), hair, s=3),
         "</g>"]
    return "\n".join(o)


def char(P, fn, x, y, rot, scale):
    old = P.lw_mul
    P.lw_mul = {"gothic": 2.4, "storybook": 2.2, "bold": 2.6, "ink": 2.6, "prod": 1}[P.k]
    g = f'<g transform="translate({x},{y}) rotate({rot}) scale({scale}) translate(-256,-260)">{fn(P, shadow=True, detail=False)}</g>'
    P.lw_mul = old
    return g


def lamp_glow(P, x, y, r, col, op):
    gid = uid("lg")
    P.defs.append(f'<radialGradient id="{gid}"><stop offset="0" stop-color="{col}" stop-opacity="{op}"/>'
                  f'<stop offset="0.4" stop-color="{col}" stop-opacity="{op*0.45:.2f}"/>'
                  f'<stop offset="1" stop-color="{col}" stop-opacity="0"/></radialGradient>')
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="url(#{gid})" style="mix-blend-mode:screen"/>'


def ground(P):
    k = P.k
    o = []
    g = P.pal["grass"]
    o.append(f'<rect width="{W}" height="{H}" fill="{g[1]}"/>')
    rnd = random.Random(3)
    if k in ("storybook", "gothic", "prod", "bold"):
        for i in range(70):
            x, y = rnd.uniform(0, W), rnd.uniform(0, H)
            r = rnd.uniform(40, 140)
            col = g[0] if i % 2 else g[2]
            op = {"storybook": 0.35, "gothic": 0.35, "prod": 0.5, "bold": 0.45}[k]
            bl = {"storybook": 14, "gothic": 16, "prod": 0, "bold": 0}[k]
            if k in ("prod", "bold") and i % 2 == 0:
                continue
            o.append(f'<path d="{blob(x, y, r, 7, 0.15, i, squash=0.6)}" fill="{col}" opacity="{op}" style="filter:blur({bl}px)"/>')
    # grass tufts
    segs = []
    for i in range(260 if k != "prod" else 90):
        x, y = rnd.uniform(0, W), rnd.uniform(0, H)
        segs.append(f"M{x:.0f},{y:.0f} l3,-8 l3,8 l3,-6")
    tcol = {"gothic": g[2], "storybook": g[2], "bold": g[2], "ink": P.ink, "prod": g[2]}[k]
    o.append(f'<path d="{" ".join(segs)}" fill="none" stroke="{tcol}" stroke-width="{1.6 if k!="ink" else 1.1}" '
             f'opacity="{0.7 if k!="ink" else 0.55}" stroke-linecap="round" stroke-linejoin="round"/>')
    if k == "storybook":
        for i in range(120):
            x, y = rnd.uniform(0, W), rnd.uniform(0, H)
            col = rnd.choice(["#fff4d6", "#f4b0a0", "#f8de70", "#c8b4f0"])
            o.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="2.6" fill="{col}" opacity="0.9"/>')
    return "\n".join(o)


def road_paths():
    main = smooth([(-40, 568), (300, 552), (620, 572), (960, 560), (1300, 546), (1640, 560), (1960, 548)], close=False)
    north = smooth([(980, 560), (990, 380), (960, 200), (990, -40)], close=False)
    south = smooth([(950, 560), (930, 760), (960, 900), (940, 1120)], close=False)
    lane = smooth([(960, 560), (760, 470), (560, 420), (380, 440), (120, 420)], close=False)
    return main, north, south, lane


def roads(P):
    k = P.k
    o = []
    l, b, s = P.pal["road"]
    main, north, south, lane = road_paths()
    edge = {"gothic": P.ink, "storybook": s, "bold": P.ink, "ink": P.ink, "prod": s}[k]
    widths = [(main, 96), (north, 74), (south, 74), (lane, 50)]
    if k in ("gothic", "bold", "ink", "storybook"):
        ew = {"gothic": 8, "bold": 8, "ink": 3, "storybook": 6}[k]
        for d, w in widths:
            o.append(f'<path d="{d}" fill="none" stroke="{edge}" stroke-width="{w+ew}" stroke-linecap="round" opacity="{0.9 if k!="storybook" else 0.45}"/>')
    for d, w in widths:
        o.append(f'<path d="{d}" fill="none" stroke="{b}" stroke-width="{w}" stroke-linecap="round"/>')
    # wheel ruts / texture
    if k != "prod":
        for d, w in widths[:3]:
            o.append(f'<path d="{d}" fill="none" stroke="{s}" stroke-width="{w*0.55}" stroke-dasharray="40 26 70 30" stroke-linecap="round" opacity="0.28"/>')
    if k == "storybook":
        for d, w in widths:
            o.append(f'<path d="{d}" fill="none" stroke="{l}" stroke-width="{w*0.4}" stroke-linecap="round" opacity="0.5" style="filter:blur(6px)"/>')
    # square (cobbles)
    sq = blob(960, 560, 190, 9, 0.05, 4, squash=0.78)
    o.append(P.shape(sq, "stone", s=6, flat=True, line=(k != "prod")))
    rnd = random.Random(8)
    cob = []
    for i in range(380):
        a, r = rnd.uniform(0, math.tau), 180 * math.sqrt(rnd.random())
        x, y = 960 + math.cos(a) * r, 560 + math.sin(a) * r * 0.76
        cob.append(f"M{x-6:.0f},{y:.0f} q6,-6 12,0 q-6,6 -12,0")
    cc = {"gothic": P.ink, "storybook": P.c("stone", 2), "bold": P.c("stone", 2), "ink": P.ink, "prod": P.c("stone", 2)}[k]
    o.append(f'<path d="{" ".join(cob)}" fill="none" stroke="{cc}" stroke-width="{1.4 if k!="ink" else 1}" opacity="{0.55 if k!="prod" else 0.4}"/>')
    return "\n".join(o)


def stream(P):
    k = P.k
    d = smooth([(1650, -40), (1620, 160), (1700, 360), (1690, 560), (1760, 760), (1730, 960), (1780, 1120)], close=False)
    l, b, s = P.pal["water"]
    o = []
    bank = {"gothic": P.ink, "storybook": P.c("grass", 2), "bold": P.ink, "ink": P.ink, "prod": P.c("water", 2)}[k]
    o.append(f'<path d="{d}" fill="none" stroke="{bank}" stroke-width="{96 if k!="ink" else 90}" stroke-linecap="round" opacity="{0.9 if k!="storybook" else 0.6}"/>')
    o.append(f'<path d="{d}" fill="none" stroke="{b}" stroke-width="84" stroke-linecap="round"/>')
    o.append(f'<path d="{d}" fill="none" stroke="{l}" stroke-width="10" stroke-dasharray="30 60" stroke-linecap="round" opacity="0.6" transform="translate(-14,0)"/>')
    o.append(f'<path d="{d}" fill="none" stroke="{l}" stroke-width="6" stroke-dasharray="18 70" stroke-linecap="round" opacity="0.5" transform="translate(16,10)"/>')
    if k == "ink":
        o.append(f'<path d="{d}" fill="none" stroke="{P.ink}" stroke-width="1" stroke-dasharray="10 14" transform="translate(-24,0)" opacity="0.7"/>')
        o.append(f'<path d="{d}" fill="none" stroke="{P.ink}" stroke-width="1" stroke-dasharray="10 14" transform="translate(24,0)" opacity="0.7"/>')
    # bridge
    o.append(cast_shadow(P, 1640, 520, 110, 72, 0.5))
    o.append(P.shape(rect(1640, 520, 110, 72, 4), "wood", s=5))
    o.append(P.detail(" ".join(f"M{x},524 L{x},588" for x in range(1652, 1745, 12)), "wood", 0.5, 0.7))
    o.append(P.shape(rect(1636, 512, 118, 10, 3), "wood", s=2, hl=False))
    o.append(P.shape(rect(1636, 590, 118, 10, 3), "wood", s=2, hl=False))
    return "\n".join(o)


def forge_yard(P):
    k = P.k
    o = []
    # yard floor (packed earth)
    o.append(P.shape(rect(430, 800, 330, 150, 14), "road", s=6, flat=True, line=(k != "prod")))
    o.append(fence(P, [(424, 806), (424, 956), (766, 956), (766, 860)]))
    # forge hearth
    o.append(cast_shadow(P, 470, 820, 90, 70, 0.4))
    o.append(P.shape(rect(470, 820, 90, 70, 8), "stone", s=6))
    o.append(P.shape(ell(515, 855, 30, 22), "fire", s=6, line=True))
    o.append(P.spot(ell(515, 855, 14, 10), P.c("fire", 0)))
    # anvil
    an = [(600, 870), (660, 870), (668, 878), (648, 884), (648, 896), (612, 896), (612, 884), (592, 878)]
    o.append(cast_shadow(P, 596, 870, 70, 26, 0.4))
    o.append(P.shape(rect(616, 880, 30, 34, 4), "wood", s=3))
    o.append(P.shape(poly(an), "metal", s=4))
    # quench trough
    o.append(cast_shadow(P, 690, 820, 54, 92, 0.4))
    o.append(P.shape(rect(690, 820, 54, 92, 6), "wood", s=4))
    o.append(P.spot(rect(697, 828, 40, 76, 3), P.c("water", 1)))
    # weapon rack
    o.append(P.shape(rect(450, 914, 150, 14, 3), "wood", s=3))
    for i, x in enumerate(range(462, 600, 22)):
        o.append(P.shape(poly([(x - 3, 902), (x + 3, 902), (x + 3, 938), (x, 944), (x - 3, 938)]), "metal", s=2, hl=False))
    # coal pile & grindstone
    o.append(P.shape(blob(720, 934, 18, 6, 0.2, 2), "boot", s=3, fill_override="#1a1614"))
    o.append(P.shape(ell(580, 832, 18, 18), "stone", s=4))
    o.append(P.detail(ell(580, 832, 6, 6), "stone", 0.5))
    return "\n".join(o)


def inn(P):
    k = P.k
    o = []
    o.append(roof(P, 1040, 250, 360, 170, "roof_b", "h", chimney=(1110, 300)))
    o.append(roof(P, 1360, 170, 140, 310, "roof_b", "v", chimney=(1450, 420)))
    # stable
    o.append(roof(P, 1530, 290, 110, 160, "wood", "v", smoke=False))
    # beer garden tables + benches
    for x in (1080, 1180, 1280):
        o.append(cast_shadow(P, x, 452, 64, 24, 0.3))
        o.append(P.shape(rect(x, 452, 64, 24, 3), "wood", s=3))
        o.append(P.shape(rect(x, 440, 64, 8, 2), "wood", s=2, hl=False))
        o.append(P.shape(rect(x, 480, 64, 8, 2), "wood", s=2, hl=False))
        o.append(P.spot(ell(x + 16, 462, 4, 4), P.c("gold", 1)))
        o.append(P.spot(ell(x + 44, 466, 4, 4), P.c("gold", 1)))
    # hanging sign
    o.append(P.shape(rect(1030, 436, 8, 40, 2), "wood", s=2, hl=False))
    o.append(P.shape(rect(1004, 470, 60, 34, 4), "wood", s=3))
    o.append(P.spot(blob(1034, 487, 10, 5, 0.3, 4), P.c("tunic", 1)))
    o.append(barrel(P, 1420, 500))
    o.append(barrel(P, 1446, 512))
    o.append(crate(P, 1470, 490))
    return "\n".join(o)


def chapel(P):
    o = [roof(P, 1250, 840, 230, 120, "stone", "h", smoke=False)]
    # tower with pyramid roof
    x, y, s = 1186, 852, 80
    o.append(cast_shadow(P, x, y, s, s, 1.3))
    c = (x + s / 2, y + s / 2)
    tris = [((x, y), (x + s, y), c), ((x + s, y), (x + s, y + s), c), ((x + s, y + s), (x, y + s), c), ((x, y + s), (x, y), c)]
    tones = [0, 2, 2, 1]
    for t, tn in zip(tris, tones):
        o.append(P.shape(poly(list(t)), "roof_a", flat=True, fill_override=P.c("roof_a", tn), line=False))
    o.append(P.detail(f"M{x},{y} L{x+s},{y+s} M{x+s},{y} L{x},{y+s}", "roof_a", 0.7))
    o.append(P.detail(rect(x, y, s, s), "roof_a", 1.2))
    o.append(P.spot(ell(c[0], c[1], 6, 6), P.c("gold", 1)))
    return "\n".join(o)


def market_and_well(P):
    o = []
    # well
    o.append(cast_shadow(P, 926, 526, 68, 68, 0.4))
    o.append(P.shape(ell(960, 560, 36), "stone", s=6))
    o.append(P.spot(ell(960, 560, 20), P.c("water", 2)))
    o.append(P.spot(ell(956, 556, 8, 5), P.c("water", 0), 0.6))
    o.append(P.shape(rect(918, 556, 84, 8, 2), "wood", s=2, hl=False))
    # market stall with striped awning
    x, y, w, h = 1040, 600, 110, 70
    o.append(cast_shadow(P, x, y, w, h, 0.6))
    for i in range(5):
        role = "tunic" if i % 2 == 0 else "shirt"
        o.append(P.shape(rect(x + i * w / 5, y, w / 5, h), role, s=3, hl=False, line=False))
    o.append(P.detail(rect(x, y, w, h), None, 1.0))
    # baskets of produce
    for i, (bx, by) in enumerate([(1050, 690), (1080, 694), (1110, 690), (1140, 694)]):
        o.append(P.shape(ell(bx, by, 12, 10), "wood", s=2))
        o.append(P.spot(ell(bx, by - 1, 8, 6), [P.c("tunic", 0), P.c("foliage", 0), P.c("gold", 0), P.c("gem", 1)][i]))
    # hay cart
    o.append(cast_shadow(P, 800, 640, 80, 46, 0.4))
    o.append(P.shape(rect(800, 640, 80, 46, 4), "wood", s=3))
    o.append(P.shape(blob(838, 662, 26, 7, 0.15, 3, squash=0.7), "roof_a", s=3))
    o.append(P.shape(rect(808, 630, 16, 8, 2), "boot", s=1, hl=False))
    o.append(P.shape(rect(856, 630, 16, 8, 2), "boot", s=1, hl=False))
    o.append(P.shape(rect(808, 688, 16, 8, 2), "boot", s=1, hl=False))
    o.append(P.shape(rect(856, 688, 16, 8, 2), "boot", s=1, hl=False))
    return "\n".join(o)


def forest(P):
    rnd = random.Random(21)
    trees = []
    for x in range(-40, 2000, 95):  # north edge
        trees.append((x + rnd.uniform(-20, 20), rnd.uniform(-10, 70), rnd.uniform(70, 100)))
    for y in range(120, 1100, 95):  # west edge
        trees.append((rnd.uniform(-20, 70), y + rnd.uniform(-20, 20), rnd.uniform(70, 100)))
    for x in range(80, 400, 90):  # south-west copse
        trees.append((x + rnd.uniform(-20, 20), rnd.uniform(990, 1080), rnd.uniform(60, 90)))
    for x in range(1830, 2000, 80):  # east beyond stream
        for y in range(120, 1100, 130):
            trees.append((x + rnd.uniform(-20, 20), y + rnd.uniform(-30, 30), rnd.uniform(60, 90)))
    # village trees
    trees += [(820, 300, 62), (360, 560 - 120, 0), (1560, 760, 70), (1130, 960, 60), (1560, 980, 66), (300, 860, 64),
              (770, 1010, 56), (660, 190, 56)]
    trees = [t for t in trees if t[2] > 0]
    trees.sort(key=lambda t: t[1])
    out = []
    for i, (x, y, r) in enumerate(trees):
        role = "foliage2" if i % 4 == 0 else "foliage"
        out.append(subjects.tree(P, cx=x, cy=y, r=r, seed=i * 3 + 1, role=role, detail=True))
    return "\n".join(out)


def town_svg(st, with_overlay=True):
    P = Painter(st)
    k = P.k
    P.lw_mul = {"gothic": 0.8, "storybook": 0.9, "bold": 0.85, "ink": 0.75, "prod": 1}[k]
    body = [ground(P), roads(P), stream(P)]
    # houses
    houses = [
        (210, 290, 180, 120, "roof_b", "h", (250, 320)),
        (500, 230, 150, 150, "roof_a", "v", (600, 260)),
        (690, 330, 120, 96, "roof_b", "h", None),
        (1100, 690, 190, 120, "roof_a", "h", (1250, 720)),
        (1380, 680, 150, 160, "roof_b", "v", (1420, 800)),
        (200, 680, 150, 110, "roof_b", "h", (320, 700)),
        (1020, 870, 150, 100, "roof_b", "h", None),
        (1180, 70, 150, 110, "roof_a", "h", (1210, 100)),
        (700, 60, 130, 110, "roof_b", "v", None),
    ]
    for (x, y, w, h, r, rd, ch) in houses:
        body.append(roof(P, x, y, w, h, r, rd, chimney=ch))
    # smithy (slate) with big forge chimney
    body.append(forge_yard(P))
    body.append(roof(P, 430, 610, 330, 180, {"gothic": "roof_a", "storybook": "roof_a", "bold": "roof_b", "ink": "roof_b", "prod": "roof_b"}[k], "h", chimney=(520, 650)))
    body.append(roof(P, 430, 610, 0, 0, "roof_a", "h") if False else "")
    body.append(inn(P))
    body.append(chapel(P))
    body.append(market_and_well(P))
    # props
    for (x, y) in [(400, 640), (414, 666), (780, 600), (1500, 620), (330, 820), (880, 780)]:
        body.append(barrel(P, x, y))
    for (x, y) in [(392, 690), (790, 740), (1340, 600), (1000, 470)]:
        body.append(crate(P, x, y))
    body.append(fence(P, [(180, 270), (420, 270), (420, 300)]))
    body.append(fence(P, [(1520, 280), (1660, 280), (1660, 470), (1520, 470)]))
    body.append(fence(P, [(180, 820), (360, 820), (360, 860)]))
    # people
    body.append(char(P, subjects.blacksmith, 632, 846, 180, 0.17))
    body.append(char(P, subjects.adventurer, 840, 552, -90, 0.15))
    vill = [(1006, 640, 30, "tunic"), (1120, 520, 160, "cloak"), (1210, 470, 0, "shirt"), (900, 470, -40, "apron"),
            (1290, 552, 90, "cloak"), (560, 470, 100, "tunic"), (1500, 560, -90, "shirt"), (948, 680, 200, "cloak"),
            (1245, 830, 0, "tunic"), (1580, 360, 180, "shirt")]
    for (x, y, r, role) in vill:
        body.append(villager(P, x, y, r, role, scale=0.85))
    # horse in stable yard (simple)
    body.append(f'<g transform="translate(1590,400) rotate(80)">' + P.shape(ell(0, 0, 14, 36), "leather", s=4) +
                P.shape(ell(0, -40, 9, 16), "leather", s=3) + "</g>")
    body.append(forest(P))
    filt = P.sprite_filter()
    scene = f'<g {filt}>' + "\n".join(body) + "</g>"
    over = overlay(P) if with_overlay else ""
    return svg_doc(W, H, scene + over, P), P


def overlay(P):
    k = P.k
    o = []
    if k == "gothic":
        o.append(f'<rect width="{W}" height="{H}" fill="#0a1426" opacity="0.38" style="mix-blend-mode:multiply"/>')
        o.append(f'<rect width="{W}" height="{H}" fill="#1a2a44" opacity="0.12"/>')
        # fog
        fid = uid("fog")
        P.defs.append(f'<filter id="{fid}"><feTurbulence type="fractalNoise" baseFrequency="0.004 0.008" numOctaves="3" seed="2"/>'
                      f'<feColorMatrix values="0 0 0 0 0.62  0 0 0 0 0.7  0 0 0 0 0.82  0 0 0 0.9 -0.32"/></filter>')
        o.append(f'<rect width="{W}" height="{H}" filter="url(#{fid})" opacity="0.28"/>')
        # light pools
        for (x, y, r, op) in [(515, 860, 260, 0.95), (515, 855, 90, 0.9), (1040, 500, 170, 0.7), (1200, 440, 140, 0.55),
                              (960, 560, 120, 0.35), (1440, 500, 120, 0.5), (1700, 545, 90, 0.4), (520, 650, 120, 0.55),
                              (1225, 900, 110, 0.4), (330, 560, 100, 0.4), (760, 560, 90, 0.4)]:
            o.append(lamp_glow(P, x, y, r, P.st["glow"], op))
        o.append(lamp_glow(P, 515, 855, 50, P.st["glow2"], 0.9))
        # embers
        rnd = random.Random(5)
        for i in range(40):
            x, y = 515 + rnd.gauss(30, 50), 830 - abs(rnd.gauss(60, 70))
            o.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{rnd.uniform(1.2,2.8):.1f}" fill="{P.st["glow2"]}" opacity="{rnd.uniform(0.5,1):.2f}"/>')
        o.append(vignette(P, "#000", 0.85))
    elif k == "storybook":
        gid = uid("sun")
        P.defs.append(f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffd890" stop-opacity="0.5"/>'
                      f'<stop offset="0.6" stop-color="#ffb860" stop-opacity="0.12"/><stop offset="1" stop-color="#8a4a30" stop-opacity="0.35"/></linearGradient>')
        o.append(f'<rect width="{W}" height="{H}" fill="url(#{gid})" style="mix-blend-mode:soft-light"/>')
        o.append(lamp_glow(P, 515, 855, 150, P.st["glow"], 0.6))
        o.append(vignette(P, "#3a2410", 0.5))
    elif k == "bold":
        o.append(lamp_glow(P, 515, 855, 90, P.st["glow"], 0.6))
    elif k == "ink":
        o.append(lamp_glow(P, 515, 855, 70, P.st["glow"], 0.25).replace("screen", "multiply"))
        o.append(ink_map_dressing(P))
    else:
        o.append(lamp_glow(P, 515, 855, 70, P.st["glow"], 0.45))
    return "\n".join(o)


def vignette(P, col, op):
    gid = uid("vg")
    P.defs.append(f'<radialGradient id="{gid}" cx="0.5" cy="0.5" r="0.75"><stop offset="0.55" stop-color="{col}" stop-opacity="0"/>'
                  f'<stop offset="1" stop-color="{col}" stop-opacity="{op}"/></radialGradient>')
    return f'<rect width="{W}" height="{H}" fill="url(#{gid})"/>'


def ink_map_dressing(P):
    ink, rub = P.ink, P.st["rubric"]
    o = []
    # parchment stain + border
    fid = uid("stain")
    P.defs.append(f'<filter id="{fid}"><feTurbulence type="fractalNoise" baseFrequency="0.006" numOctaves="4" seed="7"/>'
                  f'<feColorMatrix values="0 0 0 0 0.45  0 0 0 0 0.3  0 0 0 0 0.12  0 0 0 1.4 -0.55"/></filter>')
    o.append(f'<rect width="{W}" height="{H}" filter="url(#{fid})" opacity="0.45" style="mix-blend-mode:multiply"/>')
    o.append(vignette(P, "#6a4a20", 0.45))
    o.append(f'<rect x="22" y="22" width="{W-44}" height="{H-44}" fill="none" stroke="{ink}" stroke-width="5"/>')
    o.append(f'<rect x="36" y="36" width="{W-72}" height="{H-72}" fill="none" stroke="{ink}" stroke-width="1.6"/>')
    segs = " ".join(f"M{x},22 L{x+20},36" for x in range(40, W - 40, 40))
    segs += " " + " ".join(f"M{x},{H-36} L{x+20},{H-22}" for x in range(40, W - 40, 40))
    o.append(f'<path d="{segs}" stroke="{ink}" stroke-width="1.2"/>')
    for (cx, cy) in [(29, 29), (W - 29, 29), (29, H - 29), (W - 29, H - 29)]:
        o.append(f'<rect x="{cx-16}" y="{cy-16}" width="32" height="32" fill="#e9d8b0" stroke="{ink}" stroke-width="2"/>'
                 f'<path d="M{cx},{cy-11} L{cx+11},{cy} L{cx},{cy+11} L{cx-11},{cy} Z" fill="{rub}"/>')
    # cartouche title
    o.append(f'<path d="M640,950 h640 l30,40 l-30,40 h-640 l-30,-40 Z" fill="#efe2c0" stroke="{ink}" stroke-width="3"/>')
    o.append(f'<path d="M650,958 h620 l24,32 l-24,32 h-620 l-24,-32 Z" fill="none" stroke="{ink}" stroke-width="1"/>')
    o.append(f'<text x="960" y="1004" text-anchor="middle" font-family="IM Fell English SC" font-size="40" fill="{ink}">'
             f'<tspan fill="{rub}" font-size="52">B</tspan>rindlewick · The Village</text>')
    # labels
    labels = [(595, 772, "The Smithy", 30, rub), (1250, 236, "The Tipsy Wyvern", 30, rub), (1365, 990, "Chapel of the Dawn", 22, ink),
              (960, 666, "Market Square", 22, ink), (1795, 300, "Brindle Brook", 24, ink), (300, 140, "The Old Wood", 34, ink),
              (1585, 278, "Stables", 18, ink), (1690, 630, "Mill Bridge", 18, ink)]
    for (x, y, t, s, c) in labels:
        o.append(f'<text x="{x}" y="{y}" text-anchor="middle" font-family="IM Fell English" font-style="italic" font-size="{s}" '
                 f'fill="{c}" stroke="#efe2c0" stroke-width="5" paint-order="stroke">{t}</text>')
    o.append(f'<text x="1795" y="300" text-anchor="middle" font-family="IM Fell English" font-style="italic" font-size="24" fill="{ink}" transform="rotate(80 1795 300)"></text>')
    # compass rose
    cx, cy = 1760, 880
    o.append(f'<circle cx="{cx}" cy="{cy}" r="78" fill="#efe2c0" fill-opacity="0.8" stroke="{ink}" stroke-width="2"/>')
    o.append(f'<circle cx="{cx}" cy="{cy}" r="66" fill="none" stroke="{ink}" stroke-width="1"/>')
    for i in range(8):
        a = i * math.pi / 4
        L = 70 if i % 2 == 0 else 42
        x, y = cx + math.sin(a) * L, cy - math.cos(a) * L
        lx, ly = cx + math.sin(a + 0.35) * 14, cy - math.cos(a + 0.35) * 14
        rx, ry = cx + math.sin(a - 0.35) * 14, cy - math.cos(a - 0.35) * 14
        o.append(f'<path d="M{cx},{cy} L{lx:.1f},{ly:.1f} L{x:.1f},{y:.1f} Z" fill="{rub if i==0 else ink}"/>')
        o.append(f'<path d="M{cx},{cy} L{rx:.1f},{ry:.1f} L{x:.1f},{y:.1f} Z" fill="#efe2c0" stroke="{ink}" stroke-width="1"/>')
    o.append(f'<text x="{cx}" y="{cy-84}" text-anchor="middle" font-family="IM Fell English SC" font-size="26" fill="{rub}">N</text>')
    # scale bar
    o.append(f'<path d="M120,980 h240" stroke="{ink}" stroke-width="2"/>' +
             "".join(f'<rect x="{120+i*40}" y="972" width="40" height="8" fill="{ink if i%2==0 else "#efe2c0"}" stroke="{ink}" stroke-width="1"/>' for i in range(6)))
    o.append(f'<text x="240" y="1008" text-anchor="middle" font-family="IM Fell English" font-style="italic" font-size="18" fill="{ink}">one hundred paces</text>')
    return "\n".join(o)
