"""Expedition region maps: illustrated parchment maps (1280x720) for every region in expeditions.json.
Each node gets a small inked landmark drawn just above (or beside) its point; the point itself and a label
strip under it stay calm (the game draws the marker ring + name there). Links are faint dotted paths;
the entry node gets a road running off the map edge. No text anywhere.
python3 make_maps.py [--only=whisperwood,barrow_fields]  ->  assets/sprites/ui/maps/template_map_<region>.png"""
import math
import os
import random
from artlib import (painter, svg_doc, ink_filter, soft_filter, glow, lin, fill, render, load, only_filter, ell, rect, poly,
                    smooth, blob, wobbly_ell, ST, INK, EMBER, EMBER_HOT, RUB, GILT, SPR, SOOT, PARCH, blur_filter, hatch, uid,
                    rune_glyphs, lit_marks, VIOLET, VIOLET_HOT, RUNE_GOLD, RUNE_BLUE, FROST)
from make_ui import noise, edge_burn

PAL = ST["pal"]
W, H = 1280, 720
OUTDIR = os.path.join(SPR, "ui", "maps")
LIGHT = "#efe2c0"
NODE_R = 44          # calm disc around every node point
LABEL = (70, 30, 62)  # label strip under the point: half width, top offset, bottom offset


def J(o):
    return "\n".join(x for x in o if x)


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy or 1
    t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / L2))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


# ====================================================================== map container
class Map:
    def __init__(self, rid, reg, seed=1, dark=False):
        self.rid = rid
        self.P = painter(1.0, 0.5)
        self.nodes = {n["id"]: n for n in reg["nodes"]}
        self.rnd = random.Random(seed)
        self.dark = dark
        self.links = []
        for n in reg["nodes"]:
            for l in n["links"]:
                if l in self.nodes:
                    self.links.append((n["id"], l))
        self.ground = []    # flat ground features (water, roads, floors, fields) - soft wobble
        self.terr = []      # (y, svg) scattered terrain - inked, depth sorted
        self.marks = []     # (y, svg) landmarks - inked, depth sorted
        self.emit = []      # glows on top of ink
        self.blocks = []    # (x, y, r) keep-out discs registered by landmarks / ground features
        self.corr = []      # extra corridors kept free (polyline pts, half width)
        self.patch_cols = ["#b89a68", "#a8a874", "#c8ae80"]
        cands = [(110, 110), (W - 110, 110), (110, H - 110), (W - 110, H - 110), (W - 110, H / 2)]
        self.compass_at = max(cands, key=lambda c: min(math.hypot(c[0] - n["x"], c[1] - n["y"]) for n in self.nodes.values()))
        self.blocks.append((*self.compass_at, 70))

    # ---------------------------------------------------------------- keep-out logic
    def free(self, x, y, r=0, node=NODE_R + 6, link=14, margin=34):
        if x < margin + r or x > W - margin - r or y < margin + r * 0.6 or y > H - margin - r * 0.3:
            return False
        for n in self.nodes.values():
            if math.hypot(x - n["x"], y - n["y"]) < node + r:
                return False
            if abs(x - n["x"]) < LABEL[0] + r and n["y"] + LABEL[1] - r < y < n["y"] + LABEL[2] + r:
                return False
        for a, b in self.links:
            A, B = self.nodes[a], self.nodes[b]
            if seg_dist(x, y, A["x"], A["y"], B["x"], B["y"]) < link + r * 0.7:
                return False
        for (bx, by, br) in self.blocks:
            if math.hypot(x - bx, y - by) < br + r:
                return False
        for pts, hw in self.corr:
            for i in range(len(pts) - 1):
                if seg_dist(x, y, *pts[i], *pts[i + 1]) < hw + r * 0.7:
                    return False
        return True

    def scatter(self, n, fn, rmin, rmax, area=None, tries=40, bk=0.8, **kw):
        """Place n objects fn(M,x,y,r,seed) where free (area: callable(x,y)->bool or (x0,y0,x1,y1))."""
        placed = 0
        for i in range(n * tries):
            if placed >= n:
                break
            if callable(area):
                x, y = self.rnd.uniform(0, W), self.rnd.uniform(0, H)
                if not area(x, y):
                    continue
            else:
                x0, y0, x1, y1 = area or (0, 0, W, H)
                x, y = self.rnd.uniform(x0, x1), self.rnd.uniform(y0, y1)
            r = self.rnd.uniform(rmin, rmax)
            if not self.free(x, y, r, **kw):
                continue
            self.terr.append((y, fn(self, x, y, r, self.rnd.randint(1, 9999))))
            self.blocks.append((x, y, r * bk))
            placed += 1
        return placed

    def mark(self, x, y, svg, r):
        self.marks.append((y, svg))
        self.blocks.append((x, y - r * 0.3, r))

    # ---------------------------------------------------------------- compose
    def svg(self, tone=PARCH):
        P = self.P
        o = []
        # parchment ground
        o.append(fill(rect(0, 0, W, H), tone))
        o.append(noise(P, W, H, "#b8965c", 0.9, -0.3, 0.012, 3, 4))
        o.append(noise(P, W, H, "#efe0b8", 0.6, -0.3, 0.03, 4, 3))
        o.append(noise(P, W, H, "#20140c", 1.2, -0.97, 0.5, 5, 2))
        # foxing / water stains
        fid = uid("stain")
        P.defs.append(f'<filter id="{fid}" x="0" y="0" width="1" height="1"><feTurbulence type="fractalNoise" baseFrequency="0.009" numOctaves="4" seed="{len(self.rid)*7}"/>'
                      f'<feColorMatrix values="0 0 0 0 0.45  0 0 0 0 0.3  0 0 0 0 0.12  0 0 0 1.5 -0.6"/></filter>')
        o.append(f'<rect width="{W}" height="{H}" filter="url(#{fid})" opacity="0.35"/>')
        # broad ground-tone patches (earth / grass) so the plain parchment is not uniform
        rr = random.Random(len(self.rid))
        bfp = blur_filter(P, 22)
        o.append(J(fill(blob(rr.uniform(80, W - 80), rr.uniform(80, H - 80), rr.uniform(70, 160), 7, 0.2, i, squash=0.6),
                        rr.choice(self.patch_cols), 0.22, bfp) for i in range(14)))
        # ground features
        o.append(f'<g {soft_filter(P, 2.0, seed=3)}>' + J(self.ground) + "</g>")
        if getattr(self, "cave", None):
            o.append(self.cave)
        # node clearings: lighten the ground so the point reads
        bf = blur_filter(P, 9)
        o.append(J(fill(ell(n["x"], n["y"] + 4, 40, 34), LIGHT if not self.dark else "#c8b48c", 0.55, bf) for n in self.nodes.values()))
        # dotted links (faint; the game inks explored ones on top)
        o.append(self.link_svg())
        # terrain
        f = ink_filter(P, wob=1.6, dil=0.45, grain=0.55, soot=0.55, seed=7)
        o.append(f'<g {f}>' + J(s for _, s in sorted(self.terr, key=lambda t: t[0])) + "</g>")
        f2 = ink_filter(P, wob=1.2, dil=0.5, grain=0.5, soot=0.6, seed=9)
        o.append(f'<g {f2}>' + J(s for _, s in sorted(self.marks, key=lambda t: t[0])) + "</g>")
        o.append(J(self.emit))
        o.append(self.dressing())
        return svg_doc(W, H, P, J(o), ss=2)

    def link_svg(self):
        segs = []
        for a, b in self.links:
            A, B = self.nodes[a], self.nodes[b]
            ax, ay, bx, by = A["x"], A["y"], B["x"], B["y"]
            L = math.hypot(bx - ax, by - ay)
            ux, uy = (bx - ax) / L, (by - ay) / L
            s, e = 30, L - 30
            # a very slight bow so the dots look hand-walked, while staying near the straight line the game draws
            k = 0.04 * L * (1 if (len(a) + len(b)) % 2 else -1)
            mx, my = ax + ux * L / 2 - uy * k, ay + uy * L / 2 + ux * k
            p0 = (ax + ux * s, ay + uy * s)
            p1 = (ax + ux * e, ay + uy * e)
            segs.append(f"M{p0[0]:.1f},{p0[1]:.1f} Q{mx:.1f},{my:.1f} {p1[0]:.1f},{p1[1]:.1f}")
        d = " ".join(segs)
        col = INK if not self.dark else "#1a0f08"
        return (lin(d, LIGHT, 4.2, 0.35, extra='stroke-dasharray="0.1 9"') +
                lin(d, col, 2.4, 0.55, extra='stroke-dasharray="0.1 9"'))

    def dressing(self):
        P = self.P
        o = []
        # gothic-noir dusk + vignette
        gid = uid("vg")
        dk = 0.62 if not self.dark else 0.8
        P.defs.append(f'<radialGradient id="{gid}" cx="0.5" cy="0.5" r="0.75"><stop offset="0.5" stop-color="#3a2410" stop-opacity="0"/>'
                      f'<stop offset="0.85" stop-color="#2a180a" stop-opacity="{dk*0.55:.2f}"/><stop offset="1" stop-color="#140a04" stop-opacity="{dk:.2f}"/></radialGradient>')
        o.append(f'<rect width="{W}" height="{H}" fill="url(#{gid})"/>')
        o.append(edge_burn(P, 0, 0, W, H, "#3a1e08", 0.55, 34, 0))
        # border: thick rule, hatched band, thin rule, corner lozenges
        o.append(lin(rect(10, 10, W - 20, H - 20), INK, 4.0))
        o.append(lin(rect(22, 22, W - 44, H - 44), INK, 1.4))
        segs = " ".join(f"M{x},10 L{x+12},22 M{x},{H-22} L{x+12},{H-10}" for x in range(20, W - 30, 22))
        segs += " " + " ".join(f"M10,{y} L22,{y+12} M{W-22},{y} L{W-10},{y+12}" for y in range(20, H - 30, 22))
        o.append(lin(segs, INK, 1.0, 0.7))
        o.append(lin(rect(25.5, 25.5, W - 51, H - 51), GILT, 0.8, 0.55))
        for (cx, cy) in [(16, 16), (W - 16, 16), (16, H - 16), (W - 16, H - 16)]:
            o.append(fill(rect(cx - 13, cy - 13, 26, 26), "#e9d8b0") + lin(rect(cx - 13, cy - 13, 26, 26), INK, 1.8))
            o.append(fill(poly([(cx, cy - 9), (cx + 9, cy), (cx, cy + 9), (cx - 9, cy)]), RUB))
        o.append(self.compass())
        return J(o)

    def compass(self):
        """Compass rose in the corner farthest from all nodes (no lettering)."""
        cx, cy = self.compass_at
        r = 56
        o = [fill(ell(cx, cy, r + 6), LIGHT, 0.75), lin(ell(cx, cy, r + 6), INK, 1.8), lin(ell(cx, cy, r - 2), INK, 0.8),
             lin(ell(cx, cy, r * 0.42), INK, 0.8, 0.8)]
        ticks = " ".join(f"M{cx+math.sin(a)*(r-2):.1f},{cy-math.cos(a)*(r-2):.1f} L{cx+math.sin(a)*(r+6):.1f},{cy-math.cos(a)*(r+6):.1f}"
                         for a in [i * math.tau / 32 for i in range(32)])
        o.append(lin(ticks, INK, 0.7, 0.7))
        for i in range(8):
            a = i * math.pi / 4
            L = r + 2 if i % 2 == 0 else r * 0.6
            x, y = cx + math.sin(a) * L, cy - math.cos(a) * L
            lx, ly = cx + math.sin(a + 0.4) * 9, cy - math.cos(a + 0.4) * 9
            rx, ry = cx + math.sin(a - 0.4) * 9, cy - math.cos(a - 0.4) * 9
            o.append(fill(f"M{cx},{cy} L{lx:.1f},{ly:.1f} L{x:.1f},{y:.1f} Z", RUB if i == 0 else INK))
            o.append(fill(f"M{cx},{cy} L{rx:.1f},{ry:.1f} L{x:.1f},{y:.1f} Z", LIGHT) + lin(f"M{cx},{cy} L{rx:.1f},{ry:.1f} L{x:.1f},{y:.1f} Z", INK, 0.8))
        # fleur on north tip instead of a letter
        nx, ny = cx, cy - r - 12
        o.append(fill(f"M{nx},{ny-8} q5,6 0,12 q-5,-6 0,-12 Z M{nx-1},{ny+2} q-8,-3 -9,-9 q6,2 9,9 Z M{nx+1},{ny+2} q8,-3 9,-9 q-6,2 -9,9 Z", RUB))
        o.append(fill(ell(cx, cy, 3), GILT) + lin(ell(cx, cy, 3), INK, 0.8))
        return f'<g {soft_filter(self.P, 1.0)}>' + J(o) + "</g>"


# ====================================================================== terrain pieces (top-down, map scale)
def tree(M, x, y, r, seed, role="foliage"):
    P = M.P
    rnd = random.Random(seed)
    sd = blob(x + r * 0.28, y + r * 0.32, r * 0.95, 7, 0.1, seed)
    o = [fill(sd, f"url(#{P.hatch_id})", 0.5)]
    o.append(P.shape(blob(x, y, r, 7, 0.13, seed), role, s=r * 0.18))
    arcs = []
    for i in range(3):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(0.2, 0.6) * r
        px, py = x + math.cos(a) * rr, y + math.sin(a) * rr
        arcs.append(f"M{px-r*0.2:.1f},{py:.1f} q{r*0.2:.1f},{-r*0.18:.1f} {r*0.4:.1f},0")
    o.append(lin(" ".join(arcs), INK, 0.8, 0.55))
    return J(o)


def tree2(M, x, y, r, seed):
    return tree(M, x, y, r, seed, "foliage2")


def pine(M, x, y, r, seed):
    P = M.P
    rnd = random.Random(seed)
    o = [fill(ell(x + r * 0.3, y + r * 0.35, r * 0.9), f"url(#{P.hatch_id})", 0.45)]
    for layer, (R, n, col) in enumerate([(r, 8, "#6c7a52"), (r * 0.6, 6, "#8a9a68")]):
        pts = []
        for i in range(n * 2):
            a = i / (n * 2) * math.tau + layer * 0.4 + seed
            rr = R if i % 2 == 0 else R * 0.62
            pts.append((x + math.cos(a) * rr * rnd.uniform(0.92, 1.08), y + math.sin(a) * rr * rnd.uniform(0.92, 1.08)))
        o.append(P.shape(smooth(pts, t=0.2), "foliage", s=R * 0.14, fill_override=col))
    o.append(fill(ell(x, y, 1.4), PAL["wood"][2]))
    return J(o)


def dead_tree(M, x, y, r, seed):
    """Bare snag drawn in elevation (reads better than a top-down spider at map scale)."""
    rnd = random.Random(seed)
    h = r * 2.2
    tw = r * 0.16 + 1
    trunk = f"M{x-tw:.1f},{y:.1f} q{-tw*0.3:.1f},{-h*0.5:.1f} {tw*0.4:.1f},{-h:.1f} l{tw*0.9:.1f},0 q{tw*0.2:.1f},{h*0.5:.1f} {tw*1.2:.1f},{h:.1f} Z"
    br = []
    for i in range(4):
        yy = y - h * rnd.uniform(0.35, 0.9)
        sd = rnd.choice((-1, 1))
        L = r * rnd.uniform(0.5, 0.9)
        br.append(f"M{x:.1f},{yy:.1f} q{sd*L*0.5:.1f},{-L*0.1:.1f} {sd*L:.1f},{-L*0.6:.1f} m{-sd*L*0.35:.1f},{L*0.25:.1f} l{sd*L*0.1:.1f},{-L*0.35:.1f}")
    o = [fill(ell(x + r * 0.4, y, r * 0.7, r * 0.18), f"url(#{M.P.hatch_id})", 0.6)]
    o.append(lin(" ".join(br), INK, 2.6, 0.95) + lin(" ".join(br), "#5e4430", 1.2))
    o.append(fill(trunk, "#5e4430") + lin(trunk, INK, 1.3))
    return J(o)


def dead_tree_top(M, x, y, r, seed):
    """Bare snag seen from above: a dark trunk disc with spidery branches."""
    rnd = random.Random(seed)
    br = []
    for i in range(6):
        a = i / 6 * math.tau + rnd.uniform(-0.3, 0.3)
        L = r * rnd.uniform(0.7, 1.1)
        mx, my = x + math.cos(a) * L * 0.55, y + math.sin(a) * L * 0.55
        ex, ey = x + math.cos(a + 0.25) * L, y + math.sin(a + 0.25) * L
        br.append(f"M{x:.1f},{y:.1f} Q{mx:.1f},{my:.1f} {ex:.1f},{ey:.1f}")
        br.append(f"M{mx:.1f},{my:.1f} l{math.cos(a-0.6)*L*0.35:.1f},{math.sin(a-0.6)*L*0.35:.1f}")
    o = [lin(" ".join(br), "#3e2a18", 2.4), lin(" ".join(br), INK, 1.0, 0.8)]
    o.append(fill(ell(x, y, r * 0.18 + 1.5), "#3e2a18") + lin(ell(x, y, r * 0.18 + 1.5), INK, 1))
    return J(o)


def rock(M, x, y, r, seed, role="stone"):
    P = M.P
    o = [fill(blob(x + r * 0.3, y + r * 0.35, r * 0.9, 5, 0.15, seed, squash=0.75), f"url(#{P.hatch_id})", 0.5)]
    o.append(P.shape(blob(x, y, r, 5, 0.16, seed, squash=0.75), role, s=r * 0.25))
    o.append(lin(f"M{x-r*0.4:.1f},{y-r*0.05:.1f} l{r*0.3:.1f},{r*0.18:.1f} l{r*0.25:.1f},{-r*0.12:.1f}", INK, 0.7, 0.7))
    return J(o)


def bush(M, x, y, r, seed):
    P = M.P
    o = [fill(blob(x + r * 0.3, y + r * 0.3, r * 0.9, 6, 0.12, seed), f"url(#{P.hatch_id})", 0.4)]
    o.append(P.shape(blob(x, y, r, 6, 0.18, seed), "foliage", s=r * 0.2, fill_override="#9aa874"))
    return J(o)


def tufts(M, n, area, col=INK, op=0.45, kind="grass"):
    """Grass / reed tufts as one path (ground layer)."""
    rnd = M.rnd
    s = []
    for i in range(n * 4):
        if len(s) >= n:
            break
        x, y = rnd.uniform(30, W - 30), rnd.uniform(30, H - 30)
        if callable(area):
            if not area(x, y):
                continue
        else:
            x0, y0, x1, y1 = area
            x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        if not M.free(x, y, 2, node=NODE_R - 4, link=6, margin=30):
            continue
        if kind == "grass":
            s.append(f"M{x:.0f},{y:.0f} l1.5,-5 M{x+3:.0f},{y:.0f} l2,-6.5 M{x+6:.0f},{y:.0f} l1,-4")
        elif kind == "reed":
            s.append(f"M{x:.0f},{y:.0f} l-1,-9 M{x+2:.0f},{y:.0f} l1,-11 M{x+4:.0f},{y:.0f} l3,-8 M{x-2:.0f},{y:.0f} h9")
        elif kind == "dot":
            s.append(f"M{x:.0f},{y:.0f} h0.5")
    return lin(" ".join(s), col, 1.0 if kind != "dot" else 2.0, op)


def hachure_ridge(M, pts, depth=16, n=None, side=1, col=INK, w=1.0, op=0.75):
    """Mountain / scarp ridge as a ridge line with short downslope hachures."""
    d = [smooth(pts, close=False)]
    rr = M.rnd
    seg = []
    tot = sum(math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]) for i in range(len(pts) - 1))
    n = n or int(tot / 5)
    for k in range(n):
        t = k / n * tot
        acc = 0
        for i in range(len(pts) - 1):
            L = math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1])
            if acc + L >= t:
                u = (t - acc) / L
                x = pts[i][0] + (pts[i + 1][0] - pts[i][0]) * u
                y = pts[i][1] + (pts[i + 1][1] - pts[i][1]) * u
                nx, ny = -(pts[i + 1][1] - pts[i][1]) / L * side, (pts[i + 1][0] - pts[i][0]) / L * side
                dd = depth * rr.uniform(0.5, 1.0) * (0.6 + 0.4 * math.sin(k / n * math.pi))
                seg.append(f"M{x:.1f},{y:.1f} l{nx*dd:.1f},{ny*dd:.1f}")
                break
            acc += L
    return lin(d[0], col, w * 1.8, op) + lin(" ".join(seg), col, w, op * 0.8)


def river(M, pts, w=22, col=None):
    """Ribbon river on the ground layer (ink banks, water fill, ripple dashes)."""
    col = col or PAL["water"][1]
    d = smooth(pts, close=False)
    o = [lin(d, INK, w + 5, 0.9), lin(d, "#a8b8b4", w, 1), lin(d, col, w * 0.7, 0.85)]
    o.append(lin(d, "#e8f0ea", 1.2, 0.6, extra=f'stroke-dasharray="7 19" transform="translate(-3,-2)"'))
    o.append(lin(d, "#e8f0ea", 1.0, 0.45, extra=f'stroke-dasharray="4 23" transform="translate(4,3)"'))
    return J(o)


def road(M, pts, w=16, ruts=True):
    d = smooth(pts, close=False)
    o = [lin(d, INK, w + 5, 1.0), lin(d, "#c9ab78", w, 1), lin(d, "#dcc596", w * 0.4, 0.55)]
    if ruts:
        o.append(lin(d, "#8a6e46", 0.9, 0.55, extra=f'stroke-dasharray="10 6" transform="translate(-2.5,-2.5)"'))
        o.append(lin(d, "#8a6e46", 0.9, 0.55, extra=f'stroke-dasharray="12 5" transform="translate(2.5,2.5)"'))
    return J(o)


def entry_road(M, nid, edge_pt, via=None, w=16):
    n = M.nodes[nid]
    pts = [edge_pt] + (via or []) + [(n["x"], n["y"])]
    if n["links"]:   # run on a little past the gate toward the first waypoint, then the dotted trail takes over
        t = M.nodes[n["links"][0]]
        L = math.hypot(t["x"] - n["x"], t["y"] - n["y"])
        pts.append((n["x"] + (t["x"] - n["x"]) / L * 46, n["y"] + (t["y"] - n["y"]) / L * 46))
    M.ground.append(road(M, pts, w))
    M.corr.append((pts, w * 0.5 + 6))


def cr_points(pts, n=10):
    """Dense Catmull-Rom samples through pts (open curve)."""
    out = []
    P_ = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(P_) - 2):
        p0, p1, p2, p3 = P_[i - 1], P_[i], P_[i + 1], P_[i + 2]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 +
                                    (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    out.append(pts[-1])
    return out


def rails(M, pts, gauge=3.2, tie=5.5, step=7):
    q = cr_points(pts, 14)
    L, ties, a, b = 0, [], [], []
    nxt = 0
    for i in range(len(q)):
        p0, p1 = q[max(0, i - 1)], q[min(len(q) - 1, i + 1)]
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        l = math.hypot(dx, dy) or 1
        nx, ny = -dy / l, dx / l
        x, y = q[i]
        a.append((x + nx * gauge, y + ny * gauge))
        b.append((x - nx * gauge, y - ny * gauge))
        if i:
            L += math.hypot(q[i][0] - q[i - 1][0], q[i][1] - q[i - 1][1])
        if L >= nxt:
            ties.append(f"M{x+nx*tie:.1f},{y+ny*tie:.1f} L{x-nx*tie:.1f},{y-ny*tie:.1f}")
            nxt += step
    return (lin(" ".join(ties), INK, 3.2, 0.8) + lin(" ".join(ties), "#7a5636", 1.8, 0.95) +
            lin(poly(a, False) + " " + poly(b, False), INK, 1.4, 0.95))


def pool(M, x, y, rx, ry, seed):
    d = blob(x, y, rx, 7, 0.14, seed, squash=ry / rx)
    o = [fill(d, PAL["water"][1], 0.75), lin(d, INK, 1.4, 0.85)]
    o.append(lin(f"M{x-rx*0.5:.1f},{y:.1f} h{rx*0.35:.1f} M{x:.1f},{y+ry*0.35:.1f} h{rx*0.4:.1f}", "#e8f0ea", 0.9, 0.7))
    return J(o)


def mound(M, x, y, r, seed, role="grass"):
    """Grave mound / barrow from above: grassy ellipse with hachured flank."""
    P = M.P
    d = blob(x, y, r, 6, 0.08, seed, squash=0.7)
    o = [fill(blob(x + r * 0.25, y + r * 0.25, r, 6, 0.08, seed, squash=0.7), f"url(#{P.hatch_id})", 0.45)]
    o.append(P.shape(d, role, s=r * 0.22, fill_override="#a2a676"))
    hs = " ".join(f"M{x+math.cos(a)*r*0.55:.1f},{y+math.sin(a)*r*0.4:.1f} L{x+math.cos(a)*r*0.92:.1f},{y+math.sin(a)*r*0.65:.1f}"
                  for a in [i * math.tau / 14 for i in range(14)])
    o.append(lin(hs, INK, 0.7, 0.6))
    return J(o)


def headstone(M, x, y, r, seed):
    P = M.P
    rnd = random.Random(seed)
    w, h = r * 0.9, r * 1.3
    ang = rnd.uniform(-12, 12)
    d = f"M{x-w/2:.1f},{y:.1f} v{-h*0.65:.1f} a{w/2:.1f},{w/2:.1f} 0 0 1 {w:.1f},0 v{h*0.65:.1f} Z"
    if rnd.random() < 0.3:  # cross
        d = (f"M{x-w*0.15:.1f},{y:.1f} v{-h*0.6:.1f} h{-w*0.3:.1f} v{-w*0.3:.1f} h{w*0.3:.1f} v{-w*0.3:.1f} h{w*0.3:.1f} "
             f"v{w*0.3:.1f} h{w*0.3:.1f} v{w*0.3:.1f} h{-w*0.3:.1f} v{h*0.6:.1f} Z")
    o = [fill(ell(x + 2, y + 1, w * 0.7, 2), INK, 0.35)]
    o.append(f'<g transform="rotate({ang:.1f} {x:.1f} {y:.1f})">' + P.shape(d, "stone", s=1.2, lw=2.4) + "</g>")
    return J(o)


def grave_cluster(M, x, y, r, seed):
    rnd = random.Random(seed)
    pts = sorted(((x + rnd.uniform(-r, r), y + rnd.uniform(-r, r) * 0.6) for _ in range(rnd.randint(4, 7))), key=lambda p: p[1])
    return J(headstone(M, px, py, rnd.uniform(5.5, 7.5), rnd.randint(1, 999)) for px, py in pts)


def crypt(M, x, y, s, seed):
    P = M.P
    w, h = 18 * s, 14 * s
    o = [fill(ell(x + 3, y, w * 0.65, 3 * s), f"url(#{P.hatch_id})", 0.6)]
    o.append(P.shape(rect(x - w / 2, y - h, w, h, 0.5), "rune", s=1.5, lw=2))
    o.append(P.shape(poly([(x - w / 2 - 2 * s, y - h), (x, y - h - 9 * s), (x + w / 2 + 2 * s, y - h)]), "slate", s=1, lw=2))
    o.append(fill(f"M{x-3*s:.1f},{y:.1f} v{-7*s:.1f} a{3*s:.1f},{3*s:.1f} 0 0 1 {6*s:.1f},0 v{7*s:.1f} Z", "#140c08"))
    return J(o)


def crypt_row(M, x, y, r, seed):
    n = 3 + seed % 2
    return J(crypt(M, x + (i - (n - 1) / 2) * 24, y + (i % 2) * 2, 1.0, seed + i) for i in range(n))


def spoil_heap(M, x, y, r, seed):
    P = M.P
    d = blob(x, y, r, 6, 0.1, seed, squash=0.8)
    o = [fill(blob(x + r * 0.3, y + r * 0.3, r, 6, 0.1, seed, squash=0.8), f"url(#{P.hatch_id})", 0.5)]
    o.append(P.shape(d, "clay", s=r * 0.3, fill_override="#a88a64"))
    rnd = random.Random(seed)
    o.append(lin(" ".join(f"M{x:.1f},{y:.1f} L{x+math.cos(a)*r*0.9:.1f},{y+math.sin(a)*r*0.72:.1f}" for a in [i * math.tau / 10 + rnd.uniform(-.2, .2) for i in range(10)]), INK, 0.7, 0.55))
    o.append(fill(" ".join(ell(x + rnd.uniform(-r, r) * 0.6, y + rnd.uniform(-r, r) * 0.5, rnd.uniform(1, 2.2)) for _ in range(8)), INK, 0.7))
    return J(o)


def crystal_small(M, x, y, r, seed, role="ice", col=FROST):
    P = M.P
    rnd = random.Random(seed)
    o = []
    for i in range(3):
        a = -math.pi / 2 + rnd.uniform(-0.7, 0.7)
        L = r * rnd.uniform(0.7, 1.2)
        bx, by = x + rnd.uniform(-r, r) * 0.35, y
        tx, ty = bx + math.cos(a) * L, by + math.sin(a) * L
        px, py = -math.sin(a) * r * 0.2, math.cos(a) * r * 0.2
        o.append(P.shape(poly([(bx - px, by - py), (tx - px * 0.6, ty - py * 0.6), (tx + math.cos(a) * r * 0.25, ty + math.sin(a) * r * 0.25),
                               (tx + px * 0.6, ty + py * 0.6), (bx + px, by + py)]), role, s=1.2, lw=2.2))
    M.emit.append(glow(M.P, x, y - r * 0.4, r * 1.6, col, 0.35))
    return J(o)


# ====================================================================== landmark pieces (small oblique vignettes)
def shadow_ell(M, x, y, rx, ry=None):
    P = M.P
    ry = ry or rx * 0.32
    return fill(ell(x + rx * 0.12, y, rx, ry), f"url(#{P.hatch_id})", 0.6) + fill(ell(x + rx * 0.12, y, rx * 0.8, ry * 0.7), INK, 0.12)


def skull(M, x, y, s=1.0, col=RUB):
    """Red-ink skull mark (boss lairs)."""
    d = (f"M{x-7*s:.1f},{y:.1f} a{7*s:.1f},{7*s:.1f} 0 1 1 {14*s:.1f},0 v{4*s:.1f} h{-2.5*s:.1f} v{3.5*s:.1f} h{-9*s:.1f} v{-3.5*s:.1f} h{-2.5*s:.1f} Z")
    eyes = ell(x - 3 * s, y + 0.5 * s, 2.1 * s, 2.3 * s) + " " + ell(x + 3 * s, y + 0.5 * s, 2.1 * s, 2.3 * s)
    nose = poly([(x, y + 3 * s), (x - 1.2 * s, y + 5 * s), (x + 1.2 * s, y + 5 * s)])
    bones = f"M{x-11*s:.1f},{y+12*s:.1f} L{x+11*s:.1f},{y-6*s:.1f} M{x+11*s:.1f},{y+12*s:.1f} L{x-11*s:.1f},{y-6*s:.1f}"
    o = [lin(bones, INK, 4.4 * s), lin(bones, "#efe2c0", 2.4 * s)]
    o.append(fill(d, "#efe2c0") + lin(d, col, 1.8 * s))
    o.append(fill(eyes + " " + nose, col))
    o.append(lin(f"M{x-2.5*s:.1f},{y+7.5*s:.1f} v{-2*s:.1f} M{x:.1f},{y+7.5*s:.1f} v{-2*s:.1f} M{x+2.5*s:.1f},{y+7.5*s:.1f} v{-2*s:.1f}", col, 0.8 * s))
    return J(o)


def chest(M, x, y, s=1.0, role="wood", lid_open=False):
    P = M.P
    w, h, t = 22 * s, 12 * s, 9 * s
    o = [shadow_ell(M, x, y, w * 0.7, 4 * s)]
    o.append(P.shape(rect(x - w / 2, y - h, w, h, 1), role, s=2))
    o.append(P.shape(f"M{x-w/2:.1f},{y-h:.1f} q{w/2:.1f},{-t*1.2:.1f} {w:.1f},0 Z", role, s=1.5))
    o.append(lin(f"M{x-w*0.3:.1f},{y:.1f} v{-h:.1f} q0,{-t*0.7:.1f} 0,{-t*0.75:.1f} M{x+w*0.3:.1f},{y:.1f} v{-h:.1f} q0,{-t*0.7:.1f} 0,{-t*0.75:.1f}",
                 PAL["darkiron"][2], 2.2 * s))
    o.append(fill(rect(x - 2.5 * s, y - h - 1.5 * s, 5 * s, 5.5 * s, 1), GILT) + lin(rect(x - 2.5 * s, y - h - 1.5 * s, 5 * s, 5.5 * s, 1), INK, 0.9))
    return J(o)


def campfire(M, x, y, s=1.0):
    P = M.P
    o = []
    for i in range(7):
        a = i / 7 * math.tau
        o.append(P.shape(blob(x + math.cos(a) * 7 * s, y + math.sin(a) * 3 * s, 2.4 * s, 5, 0.15, i), "stone", s=0.6, lw=1.6))
    o.append(lin(f"M{x-6*s:.1f},{y+1:.1f} L{x+6*s:.1f},{y-3*s:.1f} M{x-6*s:.1f},{y-3*s:.1f} L{x+6*s:.1f},{y+1:.1f}", "#3e2a18", 2.4 * s))
    fl = smooth([(x - 4 * s, y - 1), (x - 2 * s, y - 9 * s), (x, y - 14 * s), (x + 2.5 * s, y - 8 * s), (x + 4 * s, y - 1)], t=0.4)
    M.emit.append(glow(P, x, y - 4 * s, 26 * s, EMBER, 0.55))
    M.emit.append(fill(fl, EMBER, 0.95) + fill(smooth([(x - 2 * s, y - 1), (x, y - 8 * s), (x + 2 * s, y - 1)], t=0.4), EMBER_HOT, 0.95))
    return J(o)


def tent(M, x, y, s=1.0, role="hide", flip=1):
    P = M.P
    w, h = 26 * s, 22 * s
    o = [shadow_ell(M, x, y, w * 0.65, 4 * s)]
    o.append(P.shape(poly([(x - w / 2, y), (x - w * 0.05 * flip, y - h), (x + w / 2, y)]), role, s=2.5))
    o.append(fill(poly([(x - w * 0.1, y), (x - w * 0.02 * flip, y - h * 0.62), (x + w * 0.12, y)]), "#1a120c"))
    o.append(lin(f"M{x-w*0.05*flip:.1f},{y-h:.1f} l{-3*s*flip:.1f},{-5*s:.1f} M{x-w*0.05*flip:.1f},{y-h:.1f} l{3*s*flip:.1f},{-5*s:.1f}", "#3e2a18", 1.6 * s))
    return J(o)


def stone_tower(M, x, y, s=1.0, ruined=True):
    """Ruined round watchtower in elevation."""
    P = M.P
    w, h = 30 * s, 58 * s
    top = y - h
    o = [shadow_ell(M, x + 4, y, w * 1.0, 6 * s)]
    if ruined:
        rim = [(x + w / 2, top + 12 * s), (x + w * 0.3, top + 4 * s), (x + w * 0.15, top + 9 * s), (x, top), (x - w * 0.18, top + 7 * s),
               (x - w * 0.32, top + 2 * s), (x - w / 2, top + 16 * s)]
    else:
        rim = [(x + w / 2, top), (x - w / 2, top)]
    body = f"M{x-w/2:.1f},{y:.1f} q{w/2:.1f},{5*s:.1f} {w:.1f},0 L{rim[0][0]:.1f},{rim[0][1]:.1f} " + " ".join(f"L{px:.1f},{py:.1f}" for px, py in rim[1:]) + " Z"
    o.append(P.shape(body, "stone", s=5 * s))
    rnd = random.Random(int(x))
    courses = []
    for i in range(1, 9):
        yy = y - i * h / 9
        courses.append(f"M{x-w/2+1:.1f},{yy+2*s:.1f} q{w/2:.1f},{4*s:.1f} {w-2:.1f},0")
        for j in range(3):
            xx = x - w / 2 + (j + 0.5 + (i % 2) * 0.5) * w / 3.5
            courses.append(f"M{xx:.1f},{yy+2*s+2:.1f} v{h/9-1:.1f}")
    cid = uid("tc")
    M.P.defs.append(f'<clipPath id="{cid}"><path d="{body}"/></clipPath>')
    o.append(f'<g clip-path="url(#{cid})">' + lin(" ".join(courses), INK, 0.7, 0.55) + "</g>")
    o.append(fill(f"M{x-5*s:.1f},{y+1:.1f} v{-11*s:.1f} a{5*s:.1f},{5*s:.1f} 0 0 1 {10*s:.1f},0 v{11*s:.1f} Z", "#1a120c"))
    o.append(fill(rect(x + 3 * s, top + 22 * s, 3 * s, 8 * s, 1), "#1a120c"))
    o.append(fill(rect(x - 8 * s, top + 26 * s, 3 * s, 7 * s, 1), "#1a120c"))
    if ruined:
        for i in range(5):
            o.append(P.shape(blob(x + w * 0.5 + rnd.uniform(0, 16) * s, y - rnd.uniform(0, 3) * s, rnd.uniform(2.5, 4.5) * s, 5, 0.2, i),
                             "stone", s=1, lw=1.8))
        o.append(P.shape(blob(x + w * 0.45, top + 14 * s, 6 * s, 5, 0.3, 3), "foliage", s=1.5, lw=1.6, fill_override="#8c9a64"))
    return J(o)


def wayshrine(M, x, y, s=1.0):
    P = M.P
    o = [shadow_ell(M, x + 2, y, 18 * s, 5 * s)]
    o.append(P.shape(rect(x - 14 * s, y - 6 * s, 28 * s, 7 * s, 1), "stone", s=1.5))
    o.append(P.shape(rect(x - 9 * s, y - 40 * s, 18 * s, 35 * s, 1), "stone", s=3))
    o.append(P.shape(poly([(x - 14 * s, y - 38 * s), (x, y - 52 * s), (x + 14 * s, y - 38 * s)]), "slate", s=2))
    o.append(fill(f"M{x-5*s:.1f},{y-10*s:.1f} v{-16*s:.1f} a{5*s:.1f},{5*s:.1f} 0 0 1 {10*s:.1f},0 v{16*s:.1f} Z", "#1a120c"))
    o.append(P.shape(blob(x - 8 * s, y - 38 * s, 5 * s, 5, 0.3, 2), "foliage", s=1, lw=1.4, fill_override="#8c9a64"))
    o.append(P.shape(blob(x + 9 * s, y - 4 * s, 5 * s, 5, 0.3, 4), "foliage", s=1, lw=1.4, fill_override="#8c9a64"))
    M.emit.append(glow(P, x, y - 16 * s, 22 * s, EMBER_HOT, 0.5))
    M.emit.append(fill(smooth([(x, y - 23 * s), (x + 2 * s, y - 18 * s), (x, y - 16 * s), (x - 2 * s, y - 18 * s)]), "#ffe2a0", 0.95))
    return J(o)


def cave_mouth(M, x, y, s=1.0, role="stone", dark="#140c08", web=False, roots=False):
    """Rocky mound with a black opening facing the viewer."""
    P = M.P
    w, h = 64 * s, 40 * s
    o = [shadow_ell(M, x + 4, y + 1, w * 0.62, 6 * s)]
    mound_d = smooth([(x - w / 2, y), (x - w * 0.42, y - h * 0.55), (x - w * 0.18, y - h * 0.95), (x + w * 0.12, y - h),
                      (x + w * 0.38, y - h * 0.7), (x + w / 2, y)], close=True, t=0.45)
    o.append(P.shape(mound_d, role, s=6 * s))
    o.append(lin(f"M{x-w*0.3:.1f},{y-h*0.6:.1f} l{8*s:.1f},{4*s:.1f} M{x+w*0.18:.1f},{y-h*0.78:.1f} l{7*s:.1f},{5*s:.1f} l{3*s:.1f},{-3*s:.1f}", INK, 0.9, 0.7))
    mo = f"M{x-15*s:.1f},{y:.1f} q{-1*s:.1f},{-22*s:.1f} {15*s:.1f},{-24*s:.1f} q{16*s:.1f},{2*s:.1f} {15*s:.1f},{24*s:.1f} Z"
    o.append(fill(mo, dark) + lin(mo, INK, 2.0))
    if roots:
        o.append(lin(f"M{x-12*s:.1f},{y-16*s:.1f} q{4*s:.1f},{6*s:.1f} {2*s:.1f},{12*s:.1f} M{x+2*s:.1f},{y-22*s:.1f} q{2*s:.1f},{7*s:.1f} {-2*s:.1f},{12*s:.1f} "
                     f"M{x+10*s:.1f},{y-17*s:.1f} q{-3*s:.1f},{5*s:.1f} 0,{11*s:.1f}", "#5c4228", 1.6 * s))
    if web:
        cx, cy = x, y - 12 * s
        spokes = " ".join(f"M{cx:.1f},{cy:.1f} L{cx+math.cos(a)*15*s:.1f},{cy+math.sin(a)*13*s:.1f}" for a in [i * math.tau / 8 for i in range(8)])
        rings = " ".join(poly([(cx + math.cos(a) * rr * s, cy + math.sin(a) * rr * 0.87 * s) for a in [i * math.tau / 8 for i in range(8)]]) for rr in (5, 9.5, 13.5))
        o.append(lin(spokes + " " + rings, "#efe8dc", 0.8, 0.85))
    return J(o)


def signpost(M, x, y, s=1.0):
    P = M.P
    o = [shadow_ell(M, x, y, 8 * s, 2.5 * s)]
    o.append(P.shape(rect(x - 1.8 * s, y - 30 * s, 3.6 * s, 30 * s, 0.5), "wood", s=1, lw=1.8))
    o.append(P.shape(poly([(x - 2 * s, y - 28 * s), (x + 15 * s, y - 28 * s), (x + 19 * s, y - 24.5 * s), (x + 15 * s, y - 21 * s), (x - 2 * s, y - 21 * s)]), "wood", s=1, lw=1.8))
    o.append(P.shape(poly([(x + 2 * s, y - 19 * s), (x - 14 * s, y - 19 * s), (x - 18 * s, y - 15.5 * s), (x - 14 * s, y - 12 * s), (x + 2 * s, y - 12 * s)]), "wood", s=1, lw=1.8))
    return J(o)


def milestone(M, x, y, s=1.0):
    P = M.P
    d = f"M{x-7*s:.1f},{y:.1f} v{-18*s:.1f} a{7*s:.1f},{7*s:.1f} 0 0 1 {14*s:.1f},0 v{18*s:.1f} Z"
    return J([shadow_ell(M, x + 2, y, 10 * s, 3 * s), P.shape(d, "stone", s=2), lin(f"M{x-3*s:.1f},{y-16*s:.1f} h{6*s:.1f} M{x-3*s:.1f},{y-12*s:.1f} h{6*s:.1f}", INK, 0.9, 0.7)])


def wagon_wreck(M, x, y, s=1.0):
    P = M.P
    o = [shadow_ell(M, x, y, 34 * s, 7 * s)]
    # tipped box with a torn canvas hood
    o.append(f'<g transform="rotate(-14 {x} {y})">' +
             P.shape(rect(x - 26 * s, y - 16 * s, 46 * s, 14 * s, 1.5), "wood", s=2) +
             lin(f"M{x-26*s:.1f},{y-9*s:.1f} h{46*s:.1f}", INK, 0.8, 0.7) +
             P.shape(f"M{x-24*s:.1f},{y-16*s:.1f} q{4*s:.1f},{-24*s:.1f} {20*s:.1f},{-22*s:.1f} l{4*s:.1f},{8*s:.1f} l{5*s:.1f},{-6*s:.1f} q{10*s:.1f},{8*s:.1f} {12*s:.1f},{20*s:.1f} Z", "linen", s=3) +
             lin(f"M{x-12*s:.1f},{y-34*s:.1f} q{2*s:.1f},{10*s:.1f} 0,{18*s:.1f} M{x+8*s:.1f},{y-30*s:.1f} q{-1*s:.1f},{8*s:.1f} 0,{14*s:.1f}", INK, 0.8, 0.7) +
             "</g>")
    for (wx, wy, r) in [(x - 22 * s, y + 1 * s, 7 * s), (x + 20 * s, y - 9 * s, 7 * s)]:
        o.append(P.shape(ell(wx, wy, r), "wood", s=1, lw=2) + lin(" ".join(f"M{wx:.1f},{wy:.1f} l{math.cos(a)*r:.1f},{math.sin(a)*r:.1f}" for a in [i * math.pi / 3 for i in range(6)]), INK, 0.9))
    # loose wheel on the ground + spilled crates
    o.append(P.shape(ell(x + 34 * s, y + 2 * s, 8 * s, 3 * s), "wood", s=0.8, lw=1.8))
    o.append(P.shape(rect(x - 44 * s, y - 6 * s, 9 * s, 8 * s, 1), "wood", s=1, lw=1.6))
    o.append(P.shape(rect(x - 37 * s, y - 2 * s, 8 * s, 6 * s, 1), "burlap", s=1, lw=1.6))
    return J(o)


def palisade(M, x, y, w, s=1.0, n=None, h=20):
    P = M.P
    n = n or int(w / (5 * s))
    o = []
    for i in range(n):
        px = x - w / 2 + (i + 0.5) * w / n
        hh = h * s * (0.85 + 0.15 * math.sin(i * 2.3))
        o.append(P.shape(f"M{px-2.4*s:.1f},{y:.1f} v{-hh:.1f} l{2.4*s:.1f},{-4*s:.1f} l{2.4*s:.1f},{4*s:.1f} v{hh:.1f} Z", "wood", s=0.6, lw=1.4))
    o.append(lin(f"M{x-w/2:.1f},{y-h*s*0.35:.1f} h{w:.1f} M{x-w/2:.1f},{y-h*s*0.75:.1f} h{w:.1f}", "#3e2a18", 1.3))
    return J(o)


def banner(M, x, y, s=1.0, col=RUB, skull_=False):
    P = M.P
    o = [lin(f"M{x:.1f},{y:.1f} v{-36*s:.1f}", "#3e2a18", 2.2 * s)]
    d = f"M{x:.1f},{y-35*s:.1f} h{16*s:.1f} l{-4*s:.1f},{6*s:.1f} l{4*s:.1f},{6*s:.1f} h{-16*s:.1f} Z"
    o.append(fill(d, col) + lin(d, INK, 1.2))
    if skull_:
        o.append(fill(ell(x + 6.5 * s, y - 29.5 * s, 2.6 * s, 2.4 * s), "#efe2c0"))
    return J(o)


def bridge(M, x, y, length, ang=0, w=18):
    """Plank bridge (top-down) on the ground layer."""
    P = M.P
    o = []
    o.append(P.shape(rect(x - length / 2, y - w / 2, length, w, 1.5), "wood", s=1.5, lw=2.2))
    o.append(lin(" ".join(f"M{x-length/2+i*5:.1f},{y-w/2+1:.1f} v{w-2:.1f}" for i in range(1, int(length / 5))), INK, 0.6, 0.6))
    o.append(lin(f"M{x-length/2:.1f},{y-w/2-1:.1f} h{length:.1f} M{x-length/2:.1f},{y+w/2+1:.1f} h{length:.1f}", "#3e2a18", 2.4))
    o.append(fill(" ".join(ell(x - length / 2 + i * length / 4, yy, 2.4) for i in range(5) for yy in (y - w / 2 - 1, y + w / 2 + 1)), "#3e2a18"))
    return f'<g transform="rotate({ang} {x} {y})">' + J(o) + "</g>"


def toll_hut(M, x, y, s=1.0):
    P = M.P
    o = [shadow_ell(M, x + 3, y, 22 * s, 5 * s)]
    o.append(P.shape(rect(x - 15 * s, y - 22 * s, 30 * s, 22 * s, 1), "wood", s=2))
    o.append(lin(" ".join(f"M{x-15*s+i*5*s:.1f},{y-21*s:.1f} v{21*s:.1f}" for i in range(1, 6)), INK, 0.6, 0.6))
    o.append(P.shape(poly([(x - 20 * s, y - 20 * s), (x, y - 38 * s), (x + 20 * s, y - 20 * s)]), "roof_b", s=2))
    o.append(fill(rect(x - 4 * s, y - 14 * s, 8 * s, 14 * s, 1), "#1a120c"))
    # striped toll bar
    o.append(lin(f"M{x+16*s:.1f},{y-6*s:.1f} L{x+46*s:.1f},{y-9*s:.1f}", INK, 4.2 * s))
    o.append(lin(f"M{x+16*s:.1f},{y-6*s:.1f} L{x+46*s:.1f},{y-9*s:.1f}", "#efe2c0", 2.4 * s))
    o.append(lin(f"M{x+16*s:.1f},{y-6*s:.1f} L{x+46*s:.1f},{y-9*s:.1f}", RUB, 2.4 * s, 1, extra=f'stroke-dasharray="{4*s:.1f} {4*s:.1f}" stroke-linecap="butt"'))
    o.append(P.shape(rect(x + 44 * s, y - 12 * s, 4 * s, 12 * s, 0.5), "wood", s=0.5, lw=1.4))
    return J(o)


def fort(M, x, y, s=1.0):
    """Bandit hideout: palisade ring + a long hut, skull banner."""
    P = M.P
    o = [shadow_ell(M, x + 3, y, 46 * s, 8 * s)]
    o.append(palisade(M, x - 4 * s, y - 16 * s, 70 * s, s * 0.8, h=16))
    o.append(P.shape(rect(x - 22 * s, y - 40 * s, 40 * s, 18 * s, 1), "wood", s=2))
    o.append(P.shape(poly([(x - 26 * s, y - 38 * s), (x - 14 * s, y - 54 * s), (x + 10 * s, y - 54 * s), (x + 22 * s, y - 38 * s)]), "straw", s=2))
    o.append(fill(rect(x - 6 * s, y - 34 * s, 7 * s, 12 * s, 1), "#1a120c"))
    o.append(palisade(M, x, y, 92 * s, s, h=20))
    o.append(fill(f"M{x-8*s:.1f},{y:.1f} v{-15*s:.1f} h{16*s:.1f} v{15*s:.1f} Z", "#1a120c"))
    o.append(banner(M, x + 30 * s, y - 22 * s, s * 0.9, RUB, True))
    return J(o)


def herb_glade(M, x, y, s=1.0):
    """A great oak with moonwort / emberleaf clumps and a little basket."""
    P = M.P
    o = [shadow_ell(M, x + 6, y - 6, 34 * s, 10 * s)]
    o.append(P.shape(f"M{x-4*s:.1f},{y-6*s:.1f} q{-1*s:.1f},{-14*s:.1f} {-2*s:.1f},{-22*s:.1f} l{8*s:.1f},0 q{-1*s:.1f},{9*s:.1f} {2*s:.1f},{22*s:.1f} Z", "wood", s=1.5))
    crown = blob(x - 2 * s, y - 44 * s, 30 * s, 8, 0.13, 4, squash=0.75)
    o.append(P.shape(crown, "foliage", s=5 * s))
    o.append(lin(" ".join(f"M{x+dx*s:.1f},{y+dy*s:.1f} q{5*s:.1f},{-4*s:.1f} {10*s:.1f},0" for dx, dy in [(-18, -46), (-2, -58), (6, -40), (-14, -34)]), INK, 0.8, 0.6))
    rnd = random.Random(5)
    for i, (dx, col) in enumerate([(-26, "#c8b4e0"), (-14, EMBER), (16, "#c8b4e0"), (26, EMBER), (34, "#f2ead6")]):
        hx, hy = x + dx * s, y + rnd.uniform(-3, 2) * s
        o.append(lin(f"M{hx:.1f},{hy:.1f} l-2,-6 M{hx:.1f},{hy:.1f} l0,-8 M{hx:.1f},{hy:.1f} l3,-6", PAL["foliage"][2], 1.3))
        o.append(fill(" ".join(ell(hx + ddx, hy - 7 + ddy, 1.8) for ddx, ddy in [(-2, 1), (0, -1.5), (3, 1)]), col) +
                 lin(" ".join(ell(hx + ddx, hy - 7 + ddy, 1.8) for ddx, ddy in [(-2, 1), (0, -1.5), (3, 1)]), INK, 0.5, 0.7))
    return J(o)


def wolf_den(M, x, y, s=1.0):
    o = [cave_mouth(M, x, y, s, "stone", roots=True)]
    # bones in front
    bx, by = x + 22 * s, y + 2 * s
    o.append(lin(f"M{bx-6*s:.1f},{by:.1f} l{11*s:.1f},{-3*s:.1f} M{bx-28*s:.1f},{by+1*s:.1f} l{7*s:.1f},{2*s:.1f}", INK, 3.0 * s))
    o.append(lin(f"M{bx-6*s:.1f},{by:.1f} l{11*s:.1f},{-3*s:.1f} M{bx-28*s:.1f},{by+1*s:.1f} l{7*s:.1f},{2*s:.1f}", "#efe8dc", 1.6 * s))
    # claw marks on the rock
    o.append(lin(" ".join(f"M{x+12*s+i*3*s:.1f},{y-30*s:.1f} l{3*s:.1f},{9*s:.1f}" for i in range(3)), RUB, 1.1, 0.9))
    return J(o)


def trapper_camp(M, x, y, s=1.0):
    P = M.P
    o = [tent(M, x - 14 * s, y - 2 * s, s * 1.05, "linen", flip=1)]
    o.append(campfire(M, x + 14 * s, y + 1 * s, s))
    # bedroll + trap
    o.append(P.shape(rect(x - 6 * s, y + 2 * s, 16 * s, 5 * s, 2), "cloth", s=0.8, lw=1.4))
    o.append(lin(f"M{x+26*s:.1f},{y-2*s:.1f} a{5*s:.1f},{3*s:.1f} 0 1 0 {10*s:.1f},0 a{5*s:.1f},{3*s:.1f} 0 1 0 {-10*s:.1f},0", PAL["darkiron"][1], 1.6))
    o.append(lin(" ".join(f"M{x+26*s+i*2.5*s:.1f},{y-2*s:.1f} l0,-2" for i in range(5)), INK, 0.8))
    return J(o)


def alpha_hollow(M, x, y, s=1.0):
    """Gnarled great-tree roots over a dark hollow; red skull mark."""
    P = M.P
    o = [shadow_ell(M, x + 4, y, 46 * s, 8 * s)]
    crown = blob(x, y - 52 * s, 40 * s, 9, 0.14, 11, squash=0.6)
    o.append(P.shape(crown, "foliage2", s=6 * s))
    trunk = (f"M{x-34*s:.1f},{y:.1f} q{10*s:.1f},{-6*s:.1f} {14*s:.1f},{-18*s:.1f} q{2*s:.1f},{-12*s:.1f} {2*s:.1f},{-22*s:.1f} l{36*s:.1f},0 "
             f"q{-2*s:.1f},{14*s:.1f} {2*s:.1f},{22*s:.1f} q{6*s:.1f},{12*s:.1f} {16*s:.1f},{18*s:.1f} Z")
    o.append(P.shape(trunk, "wood", s=4 * s, fill_override="#5e4430"))
    mo = f"M{x-13*s:.1f},{y:.1f} q{0:.1f},{-20*s:.1f} {13*s:.1f},{-22*s:.1f} q{13*s:.1f},{2*s:.1f} {13*s:.1f},{22*s:.1f} Z"
    o.append(fill(mo, "#0e0805") + lin(mo, INK, 2))
    M.emit.append(fill(ell(x - 5 * s, y - 11 * s, 1.6 * s, 1.1 * s) + " " + ell(x + 5 * s, y - 11 * s, 1.6 * s, 1.1 * s), EMBER_HOT, 0.95))
    M.emit.append(glow(M.P, x, y - 11 * s, 10 * s, EMBER, 0.35))
    o.append(lin(f"M{x-34*s:.1f},{y:.1f} q{-8*s:.1f},{2*s:.1f} {-14*s:.1f},{-2*s:.1f} M{x+38*s:.1f},{y:.1f} q{8*s:.1f},{2*s:.1f} {12*s:.1f},{-3*s:.1f}", "#5e4430", 3 * s))
    o.append(lin(" ".join(f"M{x+dx*s:.1f},{y-58*s+dy*s:.1f} q{5*s:.1f},{-4*s:.1f} {10*s:.1f},0" for dx, dy in [(-24, 4), (-2, -6), (14, 6)]), INK, 0.8, 0.6))
    o.append(skull(M, x + 38 * s, y - 40 * s, 1.0 * s))
    return J(o)


# --- mine
def headframe(M, x, y, s=1.0):
    """Mine shaft: timber A-frame with a wheel over a black shaft."""
    P = M.P
    o = [shadow_ell(M, x + 2, y, 22 * s, 5 * s)]
    o.append(fill(ell(x, y - 2 * s, 14 * s, 4.5 * s), "#140c08") + lin(ell(x, y - 2 * s, 14 * s, 4.5 * s), INK, 1.6))
    legs = f"M{x-16*s:.1f},{y:.1f} L{x:.1f},{y-40*s:.1f} L{x+16*s:.1f},{y:.1f} M{x-9*s:.1f},{y-18*s:.1f} h{18*s:.1f}"
    o.append(lin(legs, INK, 4.4 * s) + lin(legs, PAL["wood"][1], 2.4 * s))
    o.append(P.shape(ell(x, y - 40 * s, 7 * s), "wood", s=1, lw=2) + lin(" ".join(f"M{x:.1f},{y-40*s:.1f} l{math.cos(a)*7*s:.1f},{math.sin(a)*7*s:.1f}" for a in [i * math.pi / 3 for i in range(6)]), INK, 0.8))
    o.append(lin(f"M{x+7*s:.1f},{y-40*s:.1f} v{36*s:.1f}", INK, 0.8, 0.8))
    return J(o)


def mine_cart(M, x, y, s=1.0, ore=True):
    P = M.P
    o = [lin(f"M{x-20*s:.1f},{y+1:.1f} h{40*s:.1f} M{x-20*s:.1f},{y+4*s:.1f} h{40*s:.1f}", PAL["darkiron"][1], 1.2)]
    o.append(lin(" ".join(f"M{x-18*s+i*6*s:.1f},{y:.1f} v{5*s:.1f}" for i in range(7)), "#5c4228", 1.6))
    if ore:
        o.append(P.shape(blob(x, y - 12 * s, 9 * s, 5, 0.25, 3, squash=0.6), "coal", s=1, lw=1.6))
        o.append(fill(" ".join(ell(x + dx * s, y - 13 * s + dy * s, 1.3 * s) for dx, dy in [(-3, 0), (2, -2), (4, 1)]), PAL["copper"][0]))
    o.append(P.shape(poly([(x - 12 * s, y - 13 * s), (x + 12 * s, y - 13 * s), (x + 9 * s, y - 2 * s), (x - 9 * s, y - 2 * s)]), "darkiron", s=1.5))
    o.append(fill(ell(x - 6 * s, y - 1 * s, 2.6 * s) + " " + ell(x + 6 * s, y - 1 * s, 2.6 * s), INK))
    return J(o)


def quarry_mouth(M, x, y, s=1.0):
    """Timbered adit into a rock face."""
    P = M.P
    w, h = 70 * s, 44 * s
    o = [shadow_ell(M, x + 4, y, w * 0.6, 6 * s)]
    face = smooth([(x - w / 2, y), (x - w * 0.45, y - h * 0.6), (x - w * 0.2, y - h), (x + w * 0.2, y - h * 0.92), (x + w * 0.46, y - h * 0.55), (x + w / 2, y)], t=0.4)
    o.append(P.shape(face, "slate", s=6 * s))
    o.append(lin(f"M{x-w*0.36:.1f},{y-h*0.5:.1f} l{10*s:.1f},{-3*s:.1f} l{6*s:.1f},{4*s:.1f} M{x+w*0.2:.1f},{y-h*0.7:.1f} l{9*s:.1f},{5*s:.1f}", INK, 0.9, 0.7))
    o.append(fill(rect(x - 12 * s, y - 28 * s, 24 * s, 28 * s), "#120a06"))
    fr = f"M{x-13*s:.1f},{y:.1f} v{-29*s:.1f} M{x+13*s:.1f},{y:.1f} v{-29*s:.1f} M{x-16*s:.1f},{y-29*s:.1f} h{32*s:.1f}"
    o.append(lin(fr, INK, 5 * s) + lin(fr, PAL["wood"][1], 3 * s))
    o.append(lin(f"M{x-6*s:.1f},{y:.1f} L{x-3*s:.1f},{y-14*s:.1f} M{x+6*s:.1f},{y:.1f} L{x+3*s:.1f},{y-14*s:.1f}", PAL["darkiron"][0], 1.0, 0.8))
    M.emit.append(glow(M.P, x + 18 * s, y - 20 * s, 9 * s, EMBER_HOT, 0.6))
    o.append(lin(f"M{x+18*s:.1f},{y-29*s:.1f} v{5*s:.1f}", INK, 1))
    o.append(P.shape(rect(x + 15.5 * s, y - 24 * s, 5 * s, 6 * s, 1), "darkiron", s=0.5, lw=1.2))
    return J(o)


def ore_vein(M, x, y, s=1.0):
    P = M.P
    o = [shadow_ell(M, x + 4, y, 36 * s, 6 * s)]
    rocks = [(-14, -14, 20, 3), (12, -18, 16, 5), (24, -6, 11, 7), (-28, -4, 10, 9)]
    for dx, dy, r, sd in rocks:
        o.append(P.shape(blob(x + dx * s, y + dy * s, r * s, 6, 0.22, sd, squash=0.85), "slate", s=r * 0.3 * s))
    vein = f"M{x-26*s:.1f},{y-10*s:.1f} q{10*s:.1f},{-8*s:.1f} {16*s:.1f},{-6*s:.1f} t{14*s:.1f},{-8*s:.1f} t{12*s:.1f},{4*s:.1f} t{12*s:.1f},{8*s:.1f}"
    o.append(lin(vein, INK, 3.4 * s) + lin(vein, PAL["copper"][0], 1.8 * s))
    o.append(fill(" ".join(ell(x + dx * s, y + dy * s, 1.6 * s) for dx, dy in [(-12, -16), (2, -22), (16, -18), (24, -12), (-20, -10)]), "#ffd8a8"))
    M.emit.append(glow(M.P, x, y - 16 * s, 26 * s, EMBER_HOT, 0.25))
    # pick leaning on the rocks
    o.append(lin(f"M{x-34*s:.1f},{y+2*s:.1f} L{x-22*s:.1f},{y-20*s:.1f}", INK, 3 * s) + lin(f"M{x-34*s:.1f},{y+2*s:.1f} L{x-22*s:.1f},{y-20*s:.1f}", PAL["wood"][1], 1.6 * s))
    o.append(lin(f"M{x-30*s:.1f},{y-24*s:.1f} q{8*s:.1f},{0:.1f} {14*s:.1f},{8*s:.1f}", INK, 3.2 * s) + lin(f"M{x-30*s:.1f},{y-24*s:.1f} q{8*s:.1f},0 {14*s:.1f},{8*s:.1f}", PAL["darkiron"][0], 1.6 * s))
    return J(o)


def goblin_camp(M, x, y, s=1.0):
    o = [tent(M, x - 24 * s, y - 6 * s, s * 0.95, "hide", 1), tent(M, x + 22 * s, y - 10 * s, s * 0.85, "burlap", -1)]
    o.append(campfire(M, x, y + 2 * s, s))
    o.append(banner(M, x - 40 * s, y + 2 * s, s * 0.8, "#4c5834"))
    # crude spear rack
    o.append(lin(" ".join(f"M{x+36*s+i*3*s:.1f},{y+2*s:.1f} l{-1*s:.1f},{-22*s:.1f}" for i in range(3)), "#3e2a18", 1.4))
    o.append(fill(" ".join(poly([(x + 35 * s + i * 3 * s, y - 20 * s), (x + 34 * s + i * 3 * s, y - 26 * s), (x + 36.5 * s + i * 3 * s, y - 20 * s)]) for i in range(3)), PAL["darkiron"][1]))
    return J(o)


def collapsed_gallery(M, x, y, s=1.0):
    P = M.P
    o = [quarry_mouth(M, x, y, s)]
    # rubble choking the adit + broken beam + warning X
    rnd = random.Random(8)
    for i in range(9):
        o.append(P.shape(blob(x + rnd.uniform(-13, 13) * s, y - rnd.uniform(0, 14) * s, rnd.uniform(3, 6) * s, 5, 0.2, i), "slate", s=1, lw=1.6))
    o.append(lin(f"M{x-18*s:.1f},{y-2*s:.1f} L{x+10*s:.1f},{y-24*s:.1f}", INK, 5 * s) + lin(f"M{x-18*s:.1f},{y-2*s:.1f} L{x+10*s:.1f},{y-24*s:.1f}", PAL["wood"][1], 3 * s))
    o.append(lin(f"M{x-32*s:.1f},{y-40*s:.1f} l{10*s:.1f},{10*s:.1f} M{x-22*s:.1f},{y-40*s:.1f} l{-10*s:.1f},{10*s:.1f}", RUB, 2.4 * s))
    return J(o)


def strongbox_rubble(M, x, y, s=1.0):
    P = M.P
    o = [chest(M, x - 6 * s, y, s * 1.15, "darkiron")]
    rnd = random.Random(12)
    for i in range(7):
        a = rnd.uniform(-0.3, math.pi + 0.3)
        o.append(P.shape(blob(x - 6 * s + math.cos(a) * 16 * s, y - 4 * s - abs(math.sin(a)) * 8 * s, rnd.uniform(3, 5.5) * s, 5, 0.2, i), "slate", s=1, lw=1.6))
    o.append(mine_cart(M, x + 30 * s, y + 2 * s, s * 0.8, ore=False))
    return J(o)


def spider_nest(M, x, y, s=1.0):
    o = [cave_mouth(M, x, y, s * 1.15, "slate", web=True)]
    P = M.P
    # web strands across the rocks + egg sacs
    o.append(lin(f"M{x-36*s:.1f},{y-16*s:.1f} q{12*s:.1f},{8*s:.1f} {20*s:.1f},{-2*s:.1f} M{x+20*s:.1f},{y-34*s:.1f} q{10*s:.1f},{10*s:.1f} {20*s:.1f},{4*s:.1f}", "#efe8dc", 0.8, 0.8))
    o.append(fill(" ".join(ell(x + dx * s, y + dy * s, 3.2 * s, 4 * s) for dx, dy in [(26, -6), (32, -3), (-30, -3)]), "#efe8dc") +
             lin(" ".join(ell(x + dx * s, y + dy * s, 3.2 * s, 4 * s) for dx, dy in [(26, -6), (32, -3), (-30, -3)]), INK, 0.8))
    o.append(skull(M, x + 44 * s, y - 42 * s, 1.0))
    return J(o)


# --- marsh / road
def bog_crossing(M, x, y, s=1.0):
    """Dead trees and a wisp light over black water; plank walk to the left."""
    P = M.P
    o = [shadow_ell(M, x + 4, y, 30 * s, 5 * s)]
    o.append(fill(blob(x, y - 2 * s, 32 * s, 7, 0.12, 4, squash=0.25), "#2e3a30", 0.9) + lin(blob(x, y - 2 * s, 32 * s, 7, 0.12, 4, squash=0.25), INK, 1.4))
    snag = (f"M{x+6*s:.1f},{y-4*s:.1f} l{1*s:.1f},{-26*s:.1f} l{-9*s:.1f},{-12*s:.1f} M{x+7*s:.1f},{y-22*s:.1f} l{9*s:.1f},{-10*s:.1f} l{2*s:.1f},{-8*s:.1f} "
            f"M{x+7*s:.1f},{y-14*s:.1f} l{-8*s:.1f},{-5*s:.1f}")
    o.append(lin(snag, INK, 4 * s) + lin(snag, "#5e4430", 2.2 * s))
    snag2 = f"M{x-20*s:.1f},{y-2*s:.1f} l{-2*s:.1f},{-16*s:.1f} l{-6*s:.1f},{-6*s:.1f} M{x-21*s:.1f},{y-12*s:.1f} l{6*s:.1f},{-6*s:.1f}"
    o.append(lin(snag2, INK, 3.4 * s) + lin(snag2, "#5e4430", 1.8 * s))
    o.append(lin(" ".join(f"M{x+dx*s:.1f},{y:.1f} l{-1*s:.1f},{-9*s:.1f} M{x+dx*s+2*s:.1f},{y:.1f} l{1*s:.1f},{-11*s:.1f}" for dx in (-30, -12, 20, 28)), INK, 1.0, 0.85))
    wx, wy = x - 6 * s, y - 34 * s
    M.emit.append(glow(M.P, wx, wy, 20 * s, "#bfe8c8", 0.55))
    M.emit.append(fill(ell(wx, wy, 2.6 * s), "#f0fff4", 0.95))
    return J(o)


def cache_stump(M, x, y, s=1.0):
    """Hollow stump with a chest half-hidden under a tarp and stones."""
    P = M.P
    o = [shadow_ell(M, x + 3, y, 32 * s, 6 * s)]
    st = f"M{x-30*s:.1f},{y:.1f} l{2*s:.1f},{-22*s:.1f} l{4*s:.1f},{3*s:.1f} l{4*s:.1f},{-6*s:.1f} l{5*s:.1f},{4*s:.1f} l{3*s:.1f},{-3*s:.1f} l{2*s:.1f},{24*s:.1f} Z"
    o.append(P.shape(st, "wood", s=2, fill_override="#7a5636"))
    o.append(fill(ell(x - 20 * s, y - 20 * s, 6 * s, 2.2 * s), "#1a120c"))
    o.append(chest(M, x + 8 * s, y, s, "wood"))
    o.append(P.shape(f"M{x-4*s:.1f},{y-12*s:.1f} q{12*s:.1f},{-8*s:.1f} {26*s:.1f},{-2*s:.1f} l{-2*s:.1f},{9*s:.1f} q{-10*s:.1f},{-3*s:.1f} {-22*s:.1f},{2*s:.1f} Z", "burlap", s=1.5))
    o.append(P.shape(blob(x + 26 * s, y - 2 * s, 5 * s, 5, 0.2, 2), "stone", s=1, lw=1.6))
    return J(o)


def mile_camp(M, x, y, s=1.0):
    return J([milestone(M, x - 16 * s, y, s * 1.1), campfire(M, x + 10 * s, y, s * 0.9), tent(M, x + 30 * s, y - 4 * s, s * 0.75, "linen", -1)])


# --- barrow
def grave_rows(M, x, y, s=1.0):
    o = []
    rnd = random.Random(3)
    for row in range(3):
        for i in range(5):
            px = x + (i - 2) * 15 * s + (row % 2) * 4 * s
            py = y - row * 12 * s
            o.append((py, headstone(M, px, py, (7 + rnd.uniform(-1, 1.5)) * s, rnd.randint(1, 999))))
    o.sort(key=lambda t: t[0])
    return J([shadow_ell(M, x, y + 2, 44 * s, 6 * s)] + [t[1] for t in o])


def sarcophagus(M, x, y, s=1.0):
    P = M.P
    o = [shadow_ell(M, x + 3, y, 34 * s, 6 * s)]
    o.append(P.shape(rect(x - 32 * s, y - 6 * s, 64 * s, 6 * s, 1), "stone", s=1))
    o.append(P.shape(poly([(x - 26 * s, y - 6 * s), (x - 24 * s, y - 20 * s), (x + 24 * s, y - 20 * s), (x + 26 * s, y - 6 * s)]), "rune", s=2))
    lid = poly([(x - 28 * s, y - 20 * s), (x - 20 * s, y - 30 * s), (x + 22 * s, y - 30 * s), (x + 28 * s, y - 20 * s)])
    o.append(f'<g transform="rotate(-5 {x} {y})">' + P.shape(lid, "rune", s=2) +
             lin(f"M{x-10*s:.1f},{y-25*s:.1f} h{20*s:.1f} M{x:.1f},{y-28*s:.1f} v{6*s:.1f}", INK, 1.0, 0.8) + "</g>")
    # pressure-plate trap hint: a red-inked ring of tiny spikes
    o.append(lin(" ".join(f"M{x+math.cos(a)*36*s:.1f},{y+math.sin(a)*5*s:.1f} l0,{-4*s:.1f}" for a in [i * math.tau / 14 for i in range(14)]), RUB, 1.2, 0.9))
    return J(o)


def rune_door(M, x, y, s=1.0):
    """Stone door set in a turfed hill, glowing runes on the leaves."""
    P = M.P
    o = [shadow_ell(M, x + 4, y, 48 * s, 7 * s)]
    hill = smooth([(x - 52 * s, y), (x - 36 * s, y - 34 * s), (x, y - 50 * s), (x + 38 * s, y - 34 * s), (x + 52 * s, y)], t=0.5)
    o.append(P.shape(hill, "grass", s=7 * s, fill_override="#9aa274"))
    fr = f"M{x-18*s:.1f},{y:.1f} v{-26*s:.1f} l{18*s:.1f},{-12*s:.1f} l{18*s:.1f},{12*s:.1f} v{26*s:.1f} Z"
    o.append(P.shape(fr, "rune", s=2))
    door = f"M{x-12*s:.1f},{y:.1f} v{-23*s:.1f} l{12*s:.1f},{-8*s:.1f} l{12*s:.1f},{8*s:.1f} v{23*s:.1f} Z"
    o.append(fill(door, "#4a4e52") + lin(door, INK, 1.6) + lin(f"M{x:.1f},{y:.1f} v{-31*s:.1f}", INK, 1.2))
    rnd = random.Random(2)
    g = " ".join(rune_glyphs(rnd, x + dx * s, y + dy * s, 2.6 * s) for dx, dy in [(-6, -20), (-6, -9), (6, -20), (6, -9)])
    M.emit.append(lit_marks(M.P, g, RUNE_GOLD, "#fff2c0", w=1.0, glow_w=3.2, op=0.95, blur=1.6))
    M.emit.append(glow(M.P, x, y - 15 * s, 26 * s, RUNE_GOLD, 0.25))
    return J(o)


def ossuary(M, x, y, s=1.0):
    """Small charnel house: gabled stone hut, skull niches."""
    P = M.P
    o = [shadow_ell(M, x + 4, y, 36 * s, 6 * s)]
    o.append(P.shape(rect(x - 26 * s, y - 28 * s, 52 * s, 28 * s, 1), "stone", s=3))
    o.append(P.shape(poly([(x - 31 * s, y - 26 * s), (x - 18 * s, y - 46 * s), (x + 18 * s, y - 46 * s), (x + 31 * s, y - 26 * s)]), "slate", s=2))
    o.append(lin(" ".join(f"M{x-31*s+i*6.2*s:.1f},{y-26*s:.1f} L{x-18*s+i*3.6*s:.1f},{y-46*s:.1f}" for i in range(1, 10)), INK, 0.6, 0.55))
    o.append(fill(f"M{x-6*s:.1f},{y:.1f} v{-14*s:.1f} a{6*s:.1f},{6*s:.1f} 0 0 1 {12*s:.1f},0 v{14*s:.1f} Z", "#140c08"))
    for dx in (-17, 17):
        nx = x + dx * s
        o.append(fill(rect(nx - 4.5 * s, y - 22 * s, 9 * s, 9 * s, 1), "#140c08"))
        o.append(fill(ell(nx, y - 17 * s, 3 * s, 2.6 * s), "#efe8dc") + fill(ell(nx - 1.1 * s, y - 17 * s, 0.8 * s) + " " + ell(nx + 1.1 * s, y - 17 * s, 0.8 * s), INK))
    o.append(lin(f"M{x:.1f},{y-46*s:.1f} v{-10*s:.1f} M{x-4*s:.1f},{y-52*s:.1f} h{8*s:.1f}", INK, 2.2 * s))
    # bone heap at the side
    o.append(lin(" ".join(f"M{x+28*s+dx*s:.1f},{y+dy*s:.1f} l{6*s:.1f},{-2*s:.1f}" for dx, dy in [(0, 0), (4, -3), (2, -6), (8, -1)]), "#efe8dc", 1.6 * s))
    return J(o)


def relic_vault(M, x, y, s=1.0):
    """Sealed mausoleum with columns and a gilt chest in the doorway."""
    P = M.P
    o = [shadow_ell(M, x + 4, y, 40 * s, 7 * s)]
    o.append(P.shape(rect(x - 34 * s, y - 6 * s, 68 * s, 6 * s, 1), "stone", s=1))
    o.append(P.shape(rect(x - 28 * s, y - 36 * s, 56 * s, 30 * s, 1), "rune", s=3))
    for dx in (-22, -11, 11, 22):
        o.append(P.shape(rect(x + dx * s - 2.5 * s, y - 36 * s, 5 * s, 30 * s, 1), "stone", s=1, lw=1.4))
    o.append(P.shape(poly([(x - 34 * s, y - 36 * s), (x, y - 54 * s), (x + 34 * s, y - 36 * s)]), "rune", s=2))
    o.append(fill(rect(x - 7 * s, y - 26 * s, 14 * s, 20 * s), "#140c08"))
    o.append(fill(ell(x, y - 44 * s, 4 * s), GILT) + lin(ell(x, y - 44 * s, 4 * s), INK, 1))
    o.append(chest(M, x, y - 6 * s, s * 0.55, "wood"))
    M.emit.append(glow(M.P, x, y - 12 * s, 14 * s, EMBER_HOT, 0.4))
    return J(o)


def wight_barrow(M, x, y, s=1.0):
    """The great barrow: huge mound with a stone-lined entrance, standing stones, skull."""
    P = M.P
    o = [shadow_ell(M, x + 6, y, 62 * s, 9 * s)]
    hill = smooth([(x - 66 * s, y), (x - 44 * s, y - 30 * s), (x, y - 46 * s), (x + 44 * s, y - 30 * s), (x + 66 * s, y)], t=0.5)
    o.append(P.shape(hill, "grass", s=8 * s, fill_override="#8e9268"))
    o.append(lin(" ".join(f"M{x+dx*s:.1f},{y-40*s+abs(dx)*0.35*s:.1f} l{dx*0.12*s:.1f},{9*s:.1f}" for dx in range(-50, 52, 7)), INK, 0.7, 0.55))
    fr = f"M{x-16*s:.1f},{y:.1f} v{-20*s:.1f} h{32*s:.1f} v{20*s:.1f}"
    o.append(fill(f"M{x-12*s:.1f},{y:.1f} v{-17*s:.1f} h{24*s:.1f} v{17*s:.1f} Z", "#0e0805"))
    o.append(lin(fr, INK, 6 * s) + lin(fr, PAL["rune"][1], 4 * s))
    for dx, hh in [(-78, 22), (-60, 16), (62, 18), (80, 24)]:
        o.append(P.shape(rect(x + dx * s - 4 * s, y - hh * s + 4 * s, 8 * s, hh * s, 2), "rune", s=1.5, lw=1.8))
    M.emit.append(fill(ell(x - 4 * s, y - 9 * s, 1.4 * s, 1 * s) + " " + ell(x + 4 * s, y - 9 * s, 1.4 * s, 1 * s), "#d8f0ff", 0.95))
    M.emit.append(glow(M.P, x, y - 9 * s, 12 * s, "#a8c4dc", 0.4))
    o.append(skull(M, x + 40 * s, y - 50 * s, 1.0))
    return J(o)


def lychgate(M, x, y, s=1.0):
    """Two gate posts with a broken lintel either side of the south road."""
    P = M.P
    o = []
    for dx in (-30, 30):
        px = x + dx * s
        o.append(shadow_ell(M, px + 2, y, 9 * s, 3 * s))
        o.append(P.shape(rect(px - 5 * s, y - 34 * s, 10 * s, 34 * s, 1), "stone", s=2))
        o.append(P.shape(rect(px - 7 * s, y - 38 * s, 14 * s, 5 * s, 1), "rune", s=1, lw=1.6))
    o.append(P.shape(poly([(x - 34 * s, y - 40 * s), (x - 2 * s, y - 46 * s), (x - 4 * s, y - 40 * s), (x - 34 * s, y - 36 * s)]), "wood", s=1, lw=1.6))
    o.append(lin(f"M{x+20*s:.1f},{y-30*s:.1f} q{6*s:.1f},{6*s:.1f} {10*s:.1f},{14*s:.1f}", "#3e2a18", 1.4))
    return J(o)


# --- deep
def deep_stair(M, x, y, s=1.0):
    """Carved stair descending into the dark, dwarf-cut arch."""
    P = M.P
    o = [shadow_ell(M, x + 4, y, 36 * s, 6 * s)]
    arch = f"M{x-26*s:.1f},{y:.1f} v{-30*s:.1f} a{26*s:.1f},{20*s:.1f} 0 0 1 {52*s:.1f},0 v{30*s:.1f} Z"
    o.append(P.shape(arch, "rune", s=4))
    inner = f"M{x-17*s:.1f},{y:.1f} v{-26*s:.1f} a{17*s:.1f},{14*s:.1f} 0 0 1 {34*s:.1f},0 v{26*s:.1f} Z"
    o.append(fill(inner, "#0e0805"))
    o.append(lin(" ".join(f"M{x-15*s+i*1.5*s:.1f},{y-2*s-i*4.5*s:.1f} h{30*s-i*3*s:.1f}" for i in range(5)), PAL["rune"][1], 1.6, 0.9 - 0.0))
    o.append(lin(f"M{x-26*s:.1f},{y-30*s:.1f} h{52*s:.1f}", INK, 1.2, 0.8))
    rnd = random.Random(9)
    M.emit.append(lit_marks(M.P, rune_glyphs(rnd, x - 9 * s, y - 40 * s, 2.4 * s, 4), RUNE_BLUE, "#e8f4ff", w=0.9, glow_w=3, op=0.9, blur=1.4))
    return J(o)


def crystal_cave(M, x, y, s=1.0):
    P = M.P
    o = [shadow_ell(M, x + 4, y, 40 * s, 7 * s)]
    rnd = random.Random(14)
    shards = [(-24, 0, 30, -0.35, "arcane"), (-8, 2, 46, -0.1, "ice"), (10, 0, 36, 0.25, "ice"), (26, 2, 24, 0.5, "arcane"), (-36, 2, 18, -0.6, "ice"), (36, 3, 14, 0.7, "ice")]
    for dx, dy, L, a, role in shards:
        bx, by = x + dx * s, y + dy * s
        ang = -math.pi / 2 + a
        tx, ty = bx + math.cos(ang) * L * s, by + math.sin(ang) * L * s
        px, py = -math.sin(ang) * 6 * s, math.cos(ang) * 6 * s
        d = poly([(bx - px, by - py), (tx - px * 0.8, ty - py * 0.8), (tx + math.cos(ang) * 8 * s, ty + math.sin(ang) * 8 * s), (tx + px * 0.8, ty + py * 0.8), (bx + px, by + py)])
        o.append(P.shape(d, role, s=2))
        o.append(lin(f"M{bx:.1f},{by:.1f} L{tx+math.cos(ang)*8*s:.1f},{ty+math.sin(ang)*8*s:.1f}", "#ffffff", 0.8, 0.6))
    M.emit.append(glow(M.P, x, y - 20 * s, 48 * s, FROST, 0.4))
    M.emit.append(glow(M.P, x - 20 * s, y - 14 * s, 24 * s, VIOLET_HOT, 0.35))
    return J(o)


def golem_forge(M, x, y, s=1.0):
    """Ancient dwarf forge: stone hearth with a fire mouth, anvil and a slumped golem husk."""
    P = M.P
    o = [shadow_ell(M, x + 4, y, 44 * s, 7 * s)]
    o.append(P.shape(rect(x - 34 * s, y - 34 * s, 36 * s, 34 * s, 2), "rune", s=3))
    o.append(P.shape(poly([(x - 38 * s, y - 34 * s), (x - 16 * s, y - 50 * s), (x + 6 * s, y - 34 * s)]), "slate", s=2))
    o.append(P.shape(rect(x - 22 * s, y - 64 * s, 10 * s, 18 * s, 1), "rune", s=1, lw=1.6))
    mo = f"M{x-26*s:.1f},{y-4*s:.1f} v{-14*s:.1f} a{10*s:.1f},{8*s:.1f} 0 0 1 {20*s:.1f},0 v{14*s:.1f} Z"
    o.append(fill(mo, "#2a0e04") + lin(mo, INK, 1.6))
    M.emit.append(fill(mo, EMBER, 0.85))
    M.emit.append(glow(M.P, x - 16 * s, y - 12 * s, 30 * s, EMBER, 0.6))
    M.emit.append(glow(M.P, x - 16 * s, y - 10 * s, 10 * s, EMBER_HOT, 0.8))
    # anvil
    av = f"M{x+12*s:.1f},{y-14*s:.1f} h{24*s:.1f} l{-4*s:.1f},{5*s:.1f} h{-5*s:.1f} l{2*s:.1f},{7*s:.1f} h{4*s:.1f} v{2*s:.1f} h{-18*s:.1f} v{-2*s:.1f} h{4*s:.1f} l{2*s:.1f},{-7*s:.1f} h{-3*s:.1f} q{-5*s:.1f},{-1*s:.1f} {-8*s:.1f},{-5*s:.1f} Z"
    o.append(P.shape(av, "darkiron", s=1.5))
    # golem husk: blocky head + shoulder slumped against the wall
    o.append(P.shape(rect(x + 2 * s, y - 30 * s, 14 * s, 14 * s, 2), "slate", s=2, lw=2))
    o.append(fill(rect(x + 5 * s, y - 25 * s, 3 * s, 2 * s) + " " + rect(x + 10 * s, y - 25 * s, 3 * s, 2 * s), EMBER_HOT))
    return J(o)


def shadow_rift(M, x, y, s=1.0):
    """A jagged chasm leaking violet light, faint smoke-shadows curling up out of it."""
    P = M.P
    o = [shadow_ell(M, x + 4, y, 46 * s, 7 * s)]
    rim = [(x - 44 * s, y - 6 * s), (x - 30 * s, y - 14 * s), (x - 16 * s, y - 10 * s), (x - 4 * s, y - 20 * s), (x + 10 * s, y - 13 * s),
           (x + 26 * s, y - 18 * s), (x + 44 * s, y - 8 * s), (x + 30 * s, y - 2 * s), (x + 14 * s, y - 4 * s), (x - 2 * s, y + 3 * s),
           (x - 20 * s, y - 1 * s)]
    lip = poly([(px + (x - px) * -0.18, py + (y - 8 * s - py) * -0.5) for px, py in rim])
    o.append(P.shape(lip, "obsidian", s=3))
    o.append(fill(poly(rim), "#07040c") + lin(poly(rim), INK, 1.8))
    M.emit.append(glow(P, x, y - 10 * s, 64 * s, VIOLET, 0.55, ry=34 * s))
    M.emit.append(lin(poly(rim), VIOLET_HOT, 1.1, 0.85))
    M.emit.append(fill(poly([(x - 26 * s, y - 8 * s), (x - 4 * s, y - 13 * s), (x + 24 * s, y - 10 * s), (x + 4 * s, y - 4 * s)]), VIOLET, 0.55))
    bf = blur_filter(P, 2.2 * s)
    wisp = " ".join(f"M{x+dx*s:.1f},{y-10*s:.1f} c{6*s:.1f},{-10*s:.1f} {-8*s:.1f},{-18*s:.1f} {0:.1f},{-30*s:.1f} s{-6*s:.1f},{-14*s:.1f} {3*s:.1f},{-22*s:.1f}"
                    for dx in (-22, 2, 22))
    M.emit.append(f'<path d="{wisp}" fill="none" stroke="#1a1024" stroke-width="{6*s:.1f}" stroke-linecap="round" opacity="0.55" {bf}/>')
    M.emit.append(lin(wisp, "#2a1a3a", 1.4 * s, 0.6))
    M.emit.append(fill(" ".join(ell(x + dx * s, y + dy * s, 1.5 * s) for dx, dy in [(-18, -40), (8, -52), (22, -36)]), VIOLET_HOT, 0.9))
    for dx, r in ((-56, 9), (54, 8), (40, 5)):
        o.append(rock(M, x + dx * s, y - 2 * s, r * s, 3 + dx, "obsidian"))
    return J(o)


def adamant_seam(M, x, y, s=1.0):
    P = M.P
    o = [shadow_ell(M, x + 4, y, 36 * s, 6 * s)]
    for dx, dy, r, sd in [(-16, -12, 20, 5), (12, -16, 17, 6), (26, -4, 11, 8), (-30, -2, 10, 9)]:
        o.append(P.shape(blob(x + dx * s, y + dy * s, r * s, 6, 0.24, sd, squash=0.85), "obsidian", s=r * 0.3 * s))
    vein = f"M{x-30*s:.1f},{y-6*s:.1f} l{10*s:.1f},{-10*s:.1f} l{8*s:.1f},{4*s:.1f} l{10*s:.1f},{-12*s:.1f} l{8*s:.1f},{6*s:.1f} l{12*s:.1f},{-4*s:.1f}"
    o.append(lin(vein, INK, 4 * s) + lin(vein, "#9ad0b0", 2 * s))
    M.emit.append(lit_marks(M.P, vein, "#7ad0a8", "#e0fff0", w=1.0, glow_w=4, op=0.8, blur=2))
    o.append(mine_cart(M, x + 40 * s, y + 4 * s, s * 0.7, ore=False))
    return J(o)


def dwarf_hall(M, x, y, s=1.0):
    """The Dwarf-King's hall: carved gate between two pillars, stair, skull mark."""
    P = M.P
    o = [shadow_ell(M, x + 6, y, 60 * s, 9 * s)]
    o.append(P.shape(rect(x - 50 * s, y - 8 * s, 100 * s, 8 * s, 1), "rune", s=1))
    o.append(P.shape(rect(x - 42 * s, y - 14 * s, 84 * s, 6 * s, 1), "rune", s=1))
    face = f"M{x-40*s:.1f},{y-14*s:.1f} v{-46*s:.1f} l{40*s:.1f},{-22*s:.1f} l{40*s:.1f},{22*s:.1f} v{46*s:.1f} Z"
    o.append(P.shape(face, "rune", s=4, fill_override="#7a8288"))
    door = f"M{x-16*s:.1f},{y-14*s:.1f} v{-36*s:.1f} l{16*s:.1f},{-12*s:.1f} l{16*s:.1f},{12*s:.1f} v{36*s:.1f} Z"
    o.append(fill(door, "#0a0604") + lin(door, INK, 2))
    for dx in (-30, 30):
        o.append(P.shape(rect(x + dx * s - 5 * s, y - 62 * s, 10 * s, 48 * s, 1), "stone", s=1.5, lw=1.8))
        o.append(P.shape(rect(x + dx * s - 7 * s, y - 66 * s, 14 * s, 5 * s, 1), "gold", s=1, lw=1.6))
    rnd = random.Random(21)
    M.emit.append(lit_marks(M.P, rune_glyphs(rnd, x - 9 * s, y - 64 * s, 2.6 * s, 4), RUNE_GOLD, "#fff2c0", w=0.9, glow_w=3, op=0.9, blur=1.4))
    M.emit.append(fill(ell(x - 4 * s, y - 34 * s, 1.5 * s, 1.1 * s) + " " + ell(x + 4 * s, y - 34 * s, 1.5 * s, 1.1 * s), "#d8f0ff", 0.95))
    M.emit.append(glow(M.P, x, y - 34 * s, 14 * s, "#a8c4dc", 0.45))
    o.append(skull(M, x + 56 * s, y - 64 * s, 1.0))
    return J(o)


# ====================================================================== regions
LM = 1.3   # landmark scale (the vignettes are drawn at ~55-80 units, shipped at ~70-105 px)


def place(M, nid, fn, dx=0, dy=-34, s=1.0, r=56):
    n = M.nodes[nid]
    x, y = n["x"] + dx, n["y"] + dy
    M.mark(x, y, fn(M, x, y, s * LM), r * s)


def whisperwood(M):
    N = M.nodes
    # stream: from the top between glade and tower, under the den/tower link, out at the bottom
    st = [(520, -20), (505, 90), (540, 190), (500, 300), (430, 380), (440, 470), (400, 600), (430, 740)]
    M.ground.append(river(M, st, 13))
    M.corr.append((st, 12))
    # stepping stones where the trail crosses the stream
    entry_road(M, "gate", (170, 750), [(150, 690)], 14)
    # ruined wall fragments near the tower
    M.ground.append(lin("M770,300 l40,8 M820,312 l26,-4 M610,160 l-30,14", INK, 4, 0.55) + lin("M770,300 l40,8 M820,312 l26,-4 M610,160 l-30,14", PAL["stone"][1], 2.2, 0.8))
    place(M, "gate", signpost, dx=-2, dy=-32)
    place(M, "trail", lambda M, x, y, s: J([lin(" ".join(f"M{x-30+i*12:.1f},{y+4-i*3:.1f} l-2,4 M{x-26+i*12:.1f},{y+4-i*3:.1f} l2,4" for i in range(6)), INK, 1.3, 0.8),
                                             M.P.shape(rect(x - 28, y - 14, 56, 9, 4), "wood", s=1.5, fill_override="#7a5636"),
                                             lin(f"M{x-20},{y-10} h40", INK, 0.7, 0.6), bush(M, x + 34, y - 10, 9, 3)]), dy=-34)
    place(M, "glade", herb_glade, dy=-30)
    place(M, "den", wolf_den, dy=-32)
    place(M, "tower", stone_tower, dy=-30)
    M.mark(N["tower"]["x"] + 34, N["tower"]["y"] - 34, chest(M, N["tower"]["x"] + 34, N["tower"]["y"] - 34, 0.9), 14)
    place(M, "shrine", wayshrine, dy=-32)
    place(M, "traveller", trapper_camp, dy=-34)
    place(M, "hollow", alpha_hollow, dy=-30)
    # glade: flowers around the clearing
    g = N["glade"]
    M.ground.append(fill(blob(g["x"], g["y"] - 10, 90, 8, 0.12, 2, squash=0.8), "#e8dcae", 0.45))
    # forest
    M.scatter(420, tree, 12, 19, tries=30, bk=0.42)
    M.scatter(160, tree2, 10, 16, tries=30, bk=0.42)
    M.scatter(50, bush, 5, 8, tries=20)
    M.ground.append(tufts(M, 260, (30, 30, W - 30, H - 30), op=0.35))


def ironroot_mine(M):
    N = M.nodes
    entry_road(M, "gate", (220, 750), [(170, 690)], 14)
    # quarry terraces: two pits with stepped, hachured scarps
    for (cx, cy, rx, ry, k) in [(490, 390, 112, 64, 3), (1040, 585, 150, 82, 3), (900, 150, 124, 54, 2)]:
        rr = random.Random(cx)
        for i in range(k):
            f = 1 - i * 0.27
            ox, oy = (i * rx * 0.06, i * ry * 0.08)     # terraces step down toward the south-east
            wob = [1 + 0.1 * math.sin(3 * a + cx) + 0.06 * math.sin(7 * a + i) + rr.uniform(-0.03, 0.03) for a in [j * math.tau / 48 for j in range(48)]]
            pts = [(cx + ox + math.cos(a) * rx * f * wob[j], cy + oy + math.sin(a) * ry * f * wob[j]) for j, a in enumerate([j * math.tau / 48 for j in range(48)])]
            M.ground.append(fill(smooth(pts), ["#cbb286", "#bea47a", "#ae946a"][i], 0.95))
            M.ground.append(hachure_ridge(M, pts + [pts[0]], depth=11 * f + 4, side=-1, w=0.9, op=0.75))
            # broken lip: a few fallen blocks on each terrace
            for _ in range(4):
                j = rr.randrange(48)
                bx, by = pts[j]
                M.ground.append(fill(blob(bx + (cx - bx) * 0.12, by + (cy - by) * 0.12, rr.uniform(2.5, 4.5), 5, 0.2, j), PAL["slate"][1]) +
                                lin(blob(bx + (cx - bx) * 0.12, by + (cy - by) * 0.12, rr.uniform(2.5, 4.5), 5, 0.2, j), INK, 0.8))
        M.ground.append(fill(blob(cx + rx * 0.14, cy + ry * 0.18, rx * 0.2, 6, 0.15, cx, squash=ry / rx), "#2a221a", 0.7))
        M.ground.append(fill(blob(cx + rx * 0.14, cy + ry * 0.18, rx * 0.12, 6, 0.15, cx + 1, squash=ry / rx), "#5a6a70", 0.6))
        M.blocks.append((cx, cy, min(rx, ry) * 1.1))
    # mountain ridge along the top edge
    M.ground.append(hachure_ridge(M, [(40, 120), (140, 70), (240, 110), (330, 60), (420, 100)], depth=26, side=1, w=1.1))
    M.ground.append(hachure_ridge(M, [(1060, 70), (1160, 110), (1240, 60)], depth=24, side=1, w=1.1))
    # rail line from the quarry mouth to the strongbox, with ties
    rail = [(300, 604), (470, 612), (640, 614), (780, 612), (900, 600)]
    M.ground.append(rails(M, rail))
    M.corr.append((rail, 8))
    place(M, "gate", signpost, dy=-32)
    place(M, "mouth", quarry_mouth, dy=-32)
    place(M, "vein", ore_vein, dy=-30)
    place(M, "camp", goblin_camp, dy=-34)
    place(M, "gallery", collapsed_gallery, dy=-32)
    place(M, "strongbox", strongbox_rubble, dy=-32)
    place(M, "nest", spider_nest, dy=-30)
    for (x, y) in [(760, 150), (1000, 230)]:
        M.mark(x, y, headframe(M, x, y, 0.9), 26)
    M.mark(700, 615, mine_cart(M, 700, 615, 0.9), 16)
    M.scatter(14, spoil_heap, 12, 20, tries=40)
    M.scatter(60, rock, 4, 9, tries=30)
    M.scatter(40, pine, 9, 14, area=lambda x, y: y < 200 or x > 1150 or x < 160, tries=30)
    M.ground.append(tufts(M, 120, (30, 30, W - 30, H - 30), op=0.3))


def highmarsh_road(M):
    N = M.nodes
    # river N-S under the toll bridge
    rv = [(600, -20), (585, 120), (555, 260), (548, 400), (520, 520), (488, 640), (470, 740)]
    M.ground.append(river(M, rv, 26))
    M.corr.append((rv, 16))
    # the trade road: gate -> mile -> bridge -> cache -> captain
    road_pts = [(-20, 360), (N["gate"]["x"], 360), (N["mile"]["x"], 360), (400, 440), (N["bridge"]["x"], N["bridge"]["y"]), (690, 560),
                (N["cache"]["x"], N["cache"]["y"]), (1010, 470), (N["captain"]["x"], N["captain"]["y"])]
    M.ground.append(road(M, road_pts, 16))
    M.corr.append((road_pts, 14))
    b = N["bridge"]
    M.ground.append(bridge(M, b["x"], b["y"], 60, -12, 20))
    # bog: pools around the crossing
    bog = N["bog"]
    bf = blur_filter(M.P, 8)
    M.ground.append(fill(blob(bog["x"] + 10, bog["y"] + 10, 200, 9, 0.12, 3, squash=0.62), "#8e9468", 0.45, bf))
    rr = random.Random(8)
    ms = []
    for _ in range(140):
        x, y = bog["x"] + rr.uniform(-210, 210), bog["y"] + rr.uniform(-130, 130)
        if math.hypot((x - bog["x"]) / 1.2, (y - bog["y"]) / 0.75) < 185 and M.free(x, y, 4, node=NODE_R, link=8):
            ms.append(f"M{x:.0f},{y:.0f} h{rr.uniform(9,16):.0f} M{x+3:.0f},{y-3.5:.0f} h{rr.uniform(4,8):.0f}")
    M.ground.append(lin(" ".join(ms), "#4c5834", 1.1, 0.7))
    for i, (dx, dy, rx, ry) in enumerate([(-130, -60, 40, 16), (-90, 70, 50, 18), (110, -70, 46, 15), (140, 60, 54, 20), (40, 110, 36, 14),
                                         (-170, 10, 28, 11), (190, -10, 30, 12), (-40, -110, 34, 12)]):
        x, y = bog["x"] + dx, bog["y"] + dy
        if M.free(x, y, rx * 0.6, link=10):
            M.ground.append(pool(M, x, y, rx, ry, i + 4))
            M.blocks.append((x, y, rx * 0.7))
    # plank walkway through the bog along the links
    M.ground.append(tufts(M, 200, lambda x, y: math.hypot((x - bog["x"]) / 1.2, (y - bog["y"]) / 0.8) < 190, kind="reed", op=0.6))
    place(M, "gate", signpost, dy=-34)
    place(M, "mile", mile_camp, dy=-32)
    place(M, "caravan", wagon_wreck, dx=82, dy=6, s=0.95)
    place(M, "bridge", toll_hut, dx=-14, dy=-40)
    place(M, "bog", bog_crossing, dy=-32)
    place(M, "cache", cache_stump, dy=-32)
    place(M, "captain", fort, dy=-32)
    M.scatter(20, dead_tree, 10, 16, area=lambda x, y: math.hypot((x - bog["x"]) / 1.2, (y - bog["y"]) / 0.8) < 220, tries=60)
    M.scatter(120, tree, 11, 17, area=lambda x, y: math.hypot((x - bog["x"]) / 1.2, (y - bog["y"]) / 0.8) > 240, tries=30)
    M.scatter(40, bush, 5, 8, tries=20)
    M.ground.append(tufts(M, 220, (30, 30, W - 30, H - 30), op=0.32))
    M.ground.append(tufts(M, 90, lambda x, y: abs(x - (600 - y * 0.18)) < 60, kind="reed", op=0.5))


def barrow_fields(M):
    N = M.nodes
    entry_road(M, "gate", (640, 740), [(640, 700)], 16)
    # old field walls
    for pts in [[(60, 560), (250, 590), (420, 560), (520, 600)], [(760, 600), (900, 560), (1080, 590), (1230, 560)],
                [(180, 120), (200, 330), (150, 470)], [(1110, 120), (1080, 300), (1130, 460)]]:
        d = smooth(pts, close=False)
        M.ground.append(lin(d, INK, 6.5, 0.6, extra='stroke-dasharray="7 2"') + lin(d, PAL["stone"][1], 4, 0.85, extra='stroke-dasharray="7 2"'))
        M.corr.append((pts, 6))
    # fog banks
    bf = blur_filter(M.P, 14)
    for (x, y, rx, ry) in [(260, 640, 200, 30), (1000, 650, 220, 34), (480, 300, 160, 26), (820, 320, 180, 28), (640, 40, 300, 30)]:
        M.emit.append(fill(ell(x, y, rx, ry), "#eef0ea", 0.28, bf))
    place(M, "gate", lychgate, dy=0, s=0.95)
    place(M, "rows", grave_rows, dy=-34)
    place(M, "sarcophagus", sarcophagus, dy=-32)
    place(M, "door", rune_door, dy=-32)
    place(M, "ossuary", ossuary, dy=-32)
    place(M, "vault", relic_vault, dy=-32)
    place(M, "lord", wight_barrow, dx=-2, dy=-20, s=0.92)
    M.scatter(7, crypt_row, 36, 40, tries=200)
    M.scatter(30, mound, 13, 24, tries=40)
    M.scatter(14, grave_cluster, 14, 18, tries=60)
    M.scatter(18, dead_tree, 10, 15, tries=40, bk=0.6)
    M.scatter(20, rock, 4, 8, tries=30)
    M.ground.append(tufts(M, 320, (30, 30, W - 30, H - 30), op=0.35))


def deep_ironroot(M):
    """Cave floor carved out of solid rock: a hatched rock mass masked by node chambers and link tunnels,
    with an inked wall rim and a soft shadow falling from the walls onto the floor."""
    P = M.P
    N = M.nodes
    tun = " ".join(f"M{N[a]['x']},{N[a]['y']} L{N[b]['x']},{N[b]['y']}" for a, b in M.links)
    g = N["gate"]
    tun += f" M{g['x']},{g['y']} L40,40 L-30,-30"
    side = [(800, 330, 64), (290, 540, 74), (1010, 590, 66), (790, 70, 48)]
    tun_side = " ".join(f"M{x},{y} L{tx},{ty}" for (x, y, _), (tx, ty) in zip(side, [(700, 340), (420, 440), (860, 560), (640, 120)]))
    chambers = " ".join(blob(n["x"], n["y"] - 18, 92 if n["kind"] != "boss" else 124, 8, 0.14, i + 3, squash=0.78) for i, n in enumerate(N.values()))
    chambers += " " + " ".join(blob(x, y, r, 7, 0.2, int(x), squash=0.7) for (x, y, r) in side)
    floor = (f'<path d="{chambers}" fill="white"/><path d="{tun}" stroke="white" stroke-width="76" stroke-linecap="round" fill="none"/>'
             f'<path d="{tun_side}" stroke="white" stroke-width="34" stroke-linecap="round" fill="none"/>')
    turb = '<feTurbulence type="fractalNoise" baseFrequency="0.02" numOctaves="3" seed="4" result="n"/>'
    disp = uid("cd")
    P.defs.append(f'<filter id="{disp}" filterUnits="userSpaceOnUse" x="-60" y="-60" width="{W+120}" height="{H+120}">{turb}'
                  f'<feDisplacementMap in="SourceGraphic" in2="n" scale="34" xChannelSelector="R" yChannelSelector="G"/></filter>')
    rimf = uid("cr")
    P.defs.append(f'<filter id="{rimf}" filterUnits="userSpaceOnUse" x="-60" y="-60" width="{W+120}" height="{H+120}">{turb}'
                  f'<feDisplacementMap in="SourceGraphic" in2="n" scale="34" xChannelSelector="R" yChannelSelector="G" result="d"/>'
                  f'<feMorphology in="d" operator="dilate" radius="2.6" result="dd"/><feComposite in="dd" in2="d" operator="out" result="ring"/>'
                  f'<feFlood flood-color="{INK}"/><feComposite in2="ring" operator="in"/></filter>')
    mid = uid("cv")
    P.defs.append(f'<mask id="{mid}" maskUnits="userSpaceOnUse" x="0" y="0" width="{W}" height="{H}"><rect width="{W}" height="{H}" fill="white"/>'
                  f'<g filter="url(#{disp})">{floor.replace("white", "black")}</g></mask>')
    hp = hatch(P, -35, sp=4.4, w=1.1)
    hx = hatch(P, 40, sp=7, w=0.8)
    rnd = random.Random(5)
    strata = " ".join(f"M{x:.0f},{y:.0f} q{rnd.uniform(8,20):.0f},{rnd.uniform(-6,6):.0f} {rnd.uniform(20,44):.0f},{rnd.uniform(-4,4):.0f}"
                      for x, y in [(rnd.uniform(0, W), rnd.uniform(0, H)) for _ in range(260)])
    rock = (f'<rect width="{W}" height="{H}" fill="#463c34"/>' + noise(P, W, H, "#000000", 1.1, -0.42, 0.018, 7, 3) +
            f'<rect width="{W}" height="{H}" fill="{hp}" opacity="0.75"/><rect width="{W}" height="{H}" fill="{hx}" opacity="0.4"/>' +
            lin(strata, "#7a6c5e", 1.2, 0.55) + lin(strata, INK, 0.9, 0.5, extra='transform="translate(1.5,2)"'))
    shadow = f'<g {blur_filter(P, 9)}><g mask="url(#{mid})"><rect width="{W}" height="{H}" fill="#140a04" opacity="0.75"/></g></g>'
    M.cave = shadow + f'<g mask="url(#{mid})">{rock}</g>' + f'<g filter="url(#{rimf})">{floor}</g>'

    def on_floor(x, y):
        for n in N.values():
            if math.hypot(x - n["x"], (y - n["y"] + 18) / 0.78) < 78:
                return True
        for a, b in M.links:
            if seg_dist(x, y, N[a]["x"], N[a]["y"], N[b]["x"], N[b]["y"]) < 26:
                return True
        return any(math.hypot(x - sx, (y - sy) / 0.7) < r * 0.75 for sx, sy, r in side)
    place(M, "gate", deep_stair, dx=72, dy=-12, s=0.95)
    place(M, "crystal", crystal_cave, dy=-32)
    place(M, "forge", golem_forge, dx=0, dy=-30, s=0.92)
    place(M, "rift", shadow_rift, dy=-30)
    place(M, "seam", adamant_seam, dy=-30)
    place(M, "hall", dwarf_hall, dy=-30)
    M.scatter(45, rock_, 4, 8, area=on_floor, tries=60, node=NODE_R + 2, link=10)
    M.scatter(12, lambda M, x, y, r, sd: crystal_small(M, x, y, r, sd, "ice" if sd % 2 else "arcane", FROST if sd % 2 else VIOLET_HOT), 7, 11,
              area=on_floor, tries=80, node=NODE_R + 2, link=12)
    for i in range(40):
        x, y = rnd.uniform(40, W - 40), rnd.uniform(40, H - 40)
        if not on_floor(x, y) and min(math.hypot(x - n["x"], y - n["y"]) for n in N.values()) > 120:
            M.emit.append(fill(ell(x, y, 1.4), rnd.choice([FROST, VIOLET_HOT, "#9ad0b0"]), 0.7))


def rock_(M, x, y, r, seed):
    return rock(M, x, y, r, seed, "slate")


BUILDERS = dict(whisperwood=whisperwood, ironroot_mine=ironroot_mine, highmarsh_road=highmarsh_road, barrow_fields=barrow_fields,
                deep_ironroot=deep_ironroot)
TONES = dict(deep_ironroot="#a68e68", barrow_fields="#d4c294")


def jobs():
    only = only_filter()
    regs = load("expeditions.json")["regions"]
    js = []
    for i, (rid, reg) in enumerate(regs.items()):
        if only and rid not in only:
            continue
        M = Map(rid, reg, seed=11 + i, dark=(rid == "deep_ironroot"))
        BUILDERS.get(rid, lambda M: None)(M)
        js.append(dict(name=f"map_{rid}", svg=M.svg(TONES.get(rid, PARCH)), w=W, h=H, ss=2, transparent=False,
                       out=os.path.join(OUTDIR, f"map_{rid}.png")))
    return js


if __name__ == "__main__":
    render(jobs(), workers=3)
