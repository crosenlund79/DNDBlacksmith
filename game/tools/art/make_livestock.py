"""Horses and cows as tabletop miniatures on oval bases, in the same sheet layout as the village cats and dogs
(make_minis.py): assets/sprites/chars/template_animal_<id>.png, 768x512, 6x4 cells of 128 px.
  rows: south (front), east (side), north (back), west (mirrored east); cols 0-1 idle (grazing, tail flick), 2-5 walk.
python3 make_livestock.py [--only=animal_horse_1]     (review: out/livestock_strips.png)"""
import math
import os

import artlib
from artlib import render, ink_filter, svg_doc, SPR, OUT, INK, lin, fill, glow
import miniature as M
from miniature import CX, FY, SHADE, FRAMES, capsule
from svgcore import ell, rect, poly, smooth, blob
from person import tri
import make_minis

SPECS = {
    "animal_horse_1": dict(kind="horse", fur="#8a5a36", fur2="#5e3a20", belly="#9a6a44", mane="#2a1a10", hoof="#2a2018", blaze=True,
                           socks=False, blanket="#6a2a1e"),
    "animal_horse_2": dict(kind="horse", fur="#d8ccb4", fur2="#a89a80", belly="#e4dac8", mane="#8a7a64", hoof="#4a4038", blaze=False,
                           socks=False, blanket=None, dapple=True),
    "animal_cow_1": dict(kind="cow", fur="#f0e8dc", fur2="#c8bcac", belly="#f4ece0", patch="#2e2622", hoof="#3a3028", horn="#e8dcc0"),
    "animal_cow_2": dict(kind="cow", fur="#a8643a", fur2="#7a4426", belly="#c08a5e", patch="#f0e8dc", hoof="#3a2a1e", horn="#e8dcc0"),
}


def palette(spec):
    pal = dict(artlib.ST["pal"])
    for k in ("fur", "fur2", "belly"):
        pal[k] = tri(spec[k], 0.05)
    pal["mane"] = tri(spec.get("mane", spec["fur2"]), 0.05)
    pal["hoof"] = tri(spec["hoof"], 0.05)
    pal["patch"] = tri(spec.get("patch", spec["fur2"]), 0.05)
    pal["horn"] = tri(spec.get("horn", "#e8dcc0"), 0.05)
    pal["blanket"] = tri(spec.get("blanket") or "#6a2a1e", 0.05)
    pal["udder"] = tri("#e0a89a", 0.05)
    return pal


class Beast:
    def __init__(self, P, spec, view, fr):
        self.P, self.sp, self.view, self.fr = P, spec, view, fr
        self.o = []
        self.horse = spec["kind"] == "horse"
        self.walk = fr["walk"]
        self.ph = fr["ph"]
        self.br = fr["breathe"]
        self.bob = -2.5 * abs(math.sin(self.ph)) if self.walk else 0.0
        if self.horse:
            self.d = dict(bl=50, bh=19, leg=54, lw=4.8, neck=42, hl=32, hw=9.5)
        else:
            self.d = dict(bl=46, bh=22, leg=36, lw=5.6, neck=20, hl=25, hw=12)

    def sh(self, d, role, s=2, **kw):
        self.o.append(self.P.shape(d, role, s=s * SHADE, **kw))

    def det(self, d, role=None, w=1.0, op=1.0):
        self.o.append(self.P.detail(d, role, w, op))

    def draw(self):
        {"E": self.side, "S": self.front, "N": self.back}[self.view]()
        return "\n".join(x for x in self.o if x)

    # ---------------------------------------------------------------- side view, facing right
    def leg(self, hx, hy, ph, near, hind):
        d = self.d
        y0 = FY + self.bob
        sw = math.sin(ph) * (9 if self.walk else 0)
        lift = max(0.0, math.cos(ph)) * (5 if self.walk else 0)
        fx, fy = hx + sw, y0 - lift
        role = "fur" if near else "fur2"
        lw = d["lw"] * (1.0 if near else 0.9)
        if hind:
            kx, ky = hx - 5 + sw * 0.4, hy + (fy - hy) * 0.55
            self.sh(capsule((hx, hy), (kx, ky), lw * 1.35, lw * 0.95), role, s=1.4)
            self.sh(capsule((kx, ky), (fx, fy - 4), lw * 0.9, lw * 0.75), role, s=1.1)
        else:
            kx, ky = hx + sw * 0.5, hy + (fy - hy) * 0.55
            self.sh(capsule((hx, hy), (kx, ky), lw * 1.2, lw * 0.9), role, s=1.3)
            self.sh(capsule((kx, ky), (fx, fy - 4), lw * 0.85, lw * 0.75), role, s=1.1)
        if self.sp.get("socks") and near:
            self.sh(capsule((fx, fy - 14), (fx, fy - 4), lw * 0.8), "belly", s=0.5)
        self.sh(rect(fx - lw * 0.85, fy - 5, lw * 1.7, 5, 1.5), "hoof", s=0.6, lw=1.0)

    def side(self):
        d = self.d
        y0 = FY + self.bob
        bl, bh, leg = d["bl"], d["bh"], d["leg"]
        by = y0 - leg - bh * 0.55
        graze = not self.walk
        ph = self.ph
        # tail (behind everything at the rump)
        tx, ty = CX - bl + 2, by - bh * 0.55
        flick = 5 * self.br if graze else 4 * math.sin(ph)
        if self.horse:
            self.sh(smooth([(tx + 4, ty - 2), (tx - 8, ty + 4), (tx - 12 - flick, ty + 30), (tx - 8 - flick, ty + 52), (tx - 2, ty + 48),
                            (tx - 2, ty + 22), (tx + 6, ty + 6)], t=0.45), "mane", s=1.4)
            self.det(f"M{tx-4},{ty+6} q-6,20 -4,40 M{tx-8},{ty+10} q-4,18 -2,34", "mane", 0.6, 0.7)
        else:
            self.o.append(lin(f"M{tx+2},{ty} Q{tx-8},{ty+16} {tx-6-flick},{ty+40}", INK, 3.4))
            self.o.append(lin(f"M{tx+2},{ty} Q{tx-8},{ty+16} {tx-6-flick},{ty+40}", self.P.pal["fur2"][1], 1.8))
            self.sh(blob(tx - 6 - flick, ty + 44, 4.4, 6, 0.25, 3, squash=1.4), "patch", s=0.6)
        # far legs
        self.leg(CX + bl * 0.62, by + bh * 0.3, ph + math.pi, False, False)
        self.leg(CX - bl * 0.66, by + bh * 0.2, ph, False, True)
        # body barrel
        body = smooth([(CX + bl * 0.98, by - bh * 0.15), (CX + bl * 0.72, by - bh * 0.95), (CX + bl * 0.1, by - bh * 0.88 - self.br * 0.6),
                       (CX - bl * 0.62, by - bh * 1.02), (CX - bl * 1.02, by - bh * 0.35), (CX - bl * 0.95, by + bh * 0.6),
                       (CX - bl * 0.3, by + bh * 1.02), (CX + bl * 0.45, by + bh * 0.95), (CX + bl * 0.95, by + bh * 0.55)], t=0.45)
        self.sh(body, "fur", s=3.4)
        if not self.horse:
            self.patches(body, by)
            # udder between the hind legs
            self.sh(ell(CX - bl * 0.35, by + bh * 1.0, 7, 5), "udder", s=0.8, lw=1.0)
        elif self.sp.get("dapple"):
            self.o.append(fill(" ".join(ell(CX + x, by + y, 3.2, 2.6) for x, y in ((-30, -6), (-18, 4), (-4, -8), (8, 2), (-24, 10), (14, -10))),
                               self.P.pal["fur2"][1], 0.35))
        self.sh(smooth([(CX - bl * 0.3, by + bh * 0.55), (CX + bl * 0.5, by + bh * 0.5), (CX + bl * 0.55, by + bh * 0.85), (CX - bl * 0.25, by + bh * 0.95)], t=0.4),
                "belly", s=1, lw=1.0)
        if self.horse and self.sp.get("blanket"):
            self.sh(rect(CX - 16, by - bh * 0.92, 30, bh * 1.15, 4), "blanket", s=1.2, lw=1.1)
            self.o.append(lin(rect(CX - 13, by - bh * 0.92 + 3, 24, bh * 1.15 - 6, 2), artlib.GILT, 0.8, 0.8))
        # near legs
        self.leg(CX + bl * 0.58, by + bh * 0.35, ph, True, False)
        self.leg(CX - bl * 0.62, by + bh * 0.25, ph + math.pi, True, True)
        # neck and head
        nx, ny = CX + bl * 0.72, by - bh * 0.35
        ang = 62 if graze else (-52 if self.horse else -18)
        ang += (2 * self.br) if graze else 2 * math.sin(ph * 2)
        self.neck_head(nx, ny, ang)

    def patches(self, body, by):
        cid = artlib.uid("cp")
        self.P.defs.append(f'<clipPath id="{cid}"><path d="{body}"/></clipPath>')
        bl, bh = self.d["bl"], self.d["bh"]
        ps = " ".join(blob(CX + x, by + y, r, 7, 0.28, i + 5, squash=0.75) for i, (x, y, r) in
                      enumerate(((-26, -8, 13), (6, -12, 11), (22, 8, 9), (-6, 10, 8))))
        self.o.append(f'<g clip-path="url(#{cid})">' + fill(ps, self.P.pal["patch"][1], 0.95) + lin(ps, INK, 0.7, 0.6) + "</g>")

    def neck_head(self, nx, ny, ang):
        d = self.d
        L = d["neck"]
        a = math.radians(ang)
        ex, ey = nx + math.cos(a) * L, ny + math.sin(a) * L
        w0, w1 = (12, 7.5) if self.horse else (17, 12)
        px, py = -math.sin(a), math.cos(a)
        neck = smooth([(nx + px * w0 - 6, ny + py * w0), (ex + px * w1, ey + py * w1), (ex - px * w1, ey - py * w1), (nx - px * w0 - 8, ny - py * w0 - 4)], t=0.3)
        self.sh(neck, "fur", s=2.4)
        if self.horse:
            mane = f"M{nx - px * w0 - 6:.1f},{ny - py * w0 - 2:.1f} L{ex - px * (w1 + 1):.1f},{ey - py * (w1 + 1):.1f}"
            self.o.append(lin(mane, INK, 7.0))
            self.o.append(lin(mane, self.P.pal["mane"][1], 5.0))
            self.det(" ".join(f"M{nx - px*w0 + (ex-nx)*t - 6*(1-t):.1f},{ny - py*w0 + (ey-ny)*t:.1f} l{-px*5:.1f},{-py*5+3:.1f}" for t in (0.2, 0.4, 0.6, 0.8)), "mane", 0.6, 0.7)
        # head drawn pointing along +x in local space, then rotated: horses long and tapered, cows broad with horns
        hang = ang + (68 if ang < 0 else 30) if self.horse else ang + (40 if ang < 0 else 20)
        hl, hw = d["hl"], d["hw"]
        g = []
        P = self.P
        if self.horse:
            head = smooth([(-4, -hw), (hl * 0.5, -hw * 0.9), (hl, -hw * 0.6), (hl + 3, 0), (hl, hw * 0.65), (hl * 0.4, hw * 0.95), (-4, hw)], t=0.45)
            g.append(P.shape(head, "fur", s=2 * SHADE))
            if self.sp.get("blaze"):
                g.append(fill(smooth([(2, -2.5), (hl * 0.7, -2), (hl + 1, 0), (hl * 0.7, 2.5), (2, 2.5)], t=0.4), "#f2ead6", 0.95))
            g.append(fill(ell(hl - 2, -hw * 0.25, 2, 1.4), INK))
            g.append(fill(ell(4, -hw * 0.45, 2.2, 1.8), INK))
            g.append(fill(ell(3.4, -hw * 0.55, 0.7), "#ffffff", 0.8))
            ears = poly([(-6, -hw * 0.8), (-14, -hw * 1.2), (-4, -hw * 0.2)])
            g.append(P.shape(ears, "fur2", s=0.6 * SHADE, lw=1.0))
            # bridle
            g.append(lin(f"M{hl*0.55:.1f},{-hw} L{hl*0.55:.1f},{hw} M-2,{-hw} L{hl*0.55:.1f},{-hw*0.2}", "#3a2216", 1.6, 0.9))
        else:
            head = smooth([(-4, -hw), (hl * 0.6, -hw * 0.95), (hl, -hw * 0.75), (hl + 3, 0), (hl, hw * 0.8), (hl * 0.5, hw), (-4, hw)], t=0.4)
            g.append(P.shape(head, "fur", s=2 * SHADE))
            g.append(P.shape(ell(hl - 1, 0, 5.5, hw * 0.75), "udder", s=0.6 * SHADE, lw=1.0))
            g.append(fill(ell(hl, -hw * 0.3, 1.2) + " " + ell(hl, hw * 0.3, 1.2), INK, 0.8))
            g.append(fill(ell(5, -hw * 0.5, 2.2, 1.8), INK))
            g.append(P.shape(f"M-2,{-hw*0.7:.1f} q-6,-8 -2,-14 q2,6 6,8 Z", "horn", s=0.5 * SHADE, lw=0.9))
            g.append(P.shape(ell(-2, hw * 0.9, 6, 3), "fur2", s=0.5 * SHADE, lw=0.9))
            g.append(fill(blob(6, -2, 5, 6, 0.3, 2), P.pal["patch"][1], 0.7))
        self.o.append(f'<g transform="translate({ex:.1f},{ey:.1f}) rotate({hang:.1f})">' + "\n".join(g) + "</g>")

    # ---------------------------------------------------------------- front view (towards the viewer)
    def front(self):
        d = self.d
        y0 = FY + self.bob
        bh, leg = d["bh"], d["leg"]
        by = y0 - leg - bh * 0.55
        graze = not self.walk
        lw = d["lw"]
        # barrel behind, hind legs between the front ones
        self.sh(ell(CX, by - 2, bh * 1.15, bh * 1.0), "fur2", s=2)
        for sd in (-1, 1):
            lift = max(0.0, math.sin(self.ph) * sd) * 5 if self.walk else 0
            self.sh(capsule((CX + sd * 9, by + 6), (CX + sd * 9, y0 - 6 - lift), lw * 0.9, lw * 0.75), "fur2", s=1)
            self.sh(rect(CX + sd * 9 - lw * 0.75, y0 - 6 - lift, lw * 1.5, 5, 1.5), "hoof", s=0.5, lw=0.9)
        if not self.horse:
            self.sh(ell(CX, by + bh * 0.85, 8, 5), "udder", s=0.6, lw=0.9)
        # chest + front legs
        self.sh(ell(CX, by, bh * 1.05, bh * 1.05), "fur", s=2.6)
        for sd in (-1, 1):
            lift = max(0.0, -math.sin(self.ph) * sd) * 5 if self.walk else 0
            fx = CX + sd * (bh * 0.55)
            self.sh(capsule((fx, by + 4), (fx, y0 - 4 - lift), lw * 1.1, lw * 0.85), "fur", s=1.3)
            self.sh(rect(fx - lw * 0.85, y0 - 5 - lift, lw * 1.7, 5, 1.5), "hoof", s=0.6, lw=1.0)
        if not self.horse:
            self.sh(blob(CX + 8, by - 6, 9, 7, 0.25, 4), "patch", s=0.8, lw=0.9)
        # head (up when walking, lowered toward the grass when grazing)
        hw, hl = d["hw"], d["hl"]
        if graze:
            hy = by + bh * 0.6 + self.br * 1.0
        else:
            hy = by - (d["neck"] * 0.75 if self.horse else bh * 0.6)
        if self.horse and not graze:
            self.sh(smooth([(CX - 9, by - 4), (CX - 7, hy + 6), (CX + 7, hy + 6), (CX + 9, by - 4)], t=0.3), "fur", s=1.6)
            self.o.append(lin(f"M{CX},{by-12} L{CX},{hy+4}", self.P.pal["mane"][1], 4, 0.9))
        self.head_front(CX, hy, hw, hl, graze)

    def head_front(self, hx, hy, hw, hl, graze):
        P = self.P
        if self.horse:
            ln = hl * 0.75
            for sd in (-1, 1):
                self.sh(poly([(hx + sd * hw * 0.35, hy - ln * 0.45), (hx + sd * hw * 0.95, hy - ln * 0.85), (hx + sd * hw * 0.85, hy - ln * 0.3)]), "fur2", s=0.6, lw=1.0)
            head = smooth([(hx - hw, hy - ln * 0.4), (hx, hy - ln * 0.55), (hx + hw, hy - ln * 0.4), (hx + hw * 0.7, hy + ln * 0.45), (hx, hy + ln * 0.62),
                           (hx - hw * 0.7, hy + ln * 0.45)], t=0.45)
            self.sh(head, "fur", s=1.8)
            if self.sp.get("blaze"):
                self.o.append(fill(smooth([(hx - 2.5, hy - ln * 0.4), (hx + 2.5, hy - ln * 0.4), (hx + 3, hy + ln * 0.4), (hx - 3, hy + ln * 0.4)], t=0.4), "#f2ead6", 0.95))
            self.o.append(fill(ell(hx - hw * 0.75, hy - ln * 0.15, 1.8, 2) + " " + ell(hx + hw * 0.75, hy - ln * 0.15, 1.8, 2), INK))
            self.o.append(fill(ell(hx - 3, hy + ln * 0.48, 1.4, 1) + " " + ell(hx + 3, hy + ln * 0.48, 1.4, 1), INK, 0.8))
            self.o.append(lin(f"M{hx-hw},{hy+ln*0.05} L{hx+hw},{hy+ln*0.05}", "#3a2216", 1.4, 0.9))
            self.o.append(lin(f"M{hx-5},{hy-ln*0.5} q5,4 10,0", self.P.pal["mane"][1], 3, 0.9))
        else:
            for sd in (-1, 1):
                self.sh(f"M{hx+sd*hw*0.7},{hy-hl*0.35} q{sd*9},-4 {sd*11},-12 q{-sd*2},8 {-sd*8},14 Z", "horn", s=0.5, lw=0.9)
                self.sh(ell(hx + sd * hw * 1.15, hy - hl * 0.15, 6, 3.4), "fur2", s=0.6, lw=0.9)
            head = smooth([(hx - hw, hy - hl * 0.4), (hx + hw, hy - hl * 0.4), (hx + hw * 0.8, hy + hl * 0.3), (hx, hy + hl * 0.45), (hx - hw * 0.8, hy + hl * 0.3)], t=0.45)
            self.sh(head, "fur", s=1.8)
            self.o.append(fill(blob(hx + 3, hy - hl * 0.2, 6, 6, 0.3, 7), P.pal["patch"][1], 0.75))
            self.sh(ell(hx, hy + hl * 0.3, hw * 0.75, 6), "udder", s=0.5, lw=0.9)
            self.o.append(fill(ell(hx - 3, hy + hl * 0.3, 1.3) + " " + ell(hx + 3, hy + hl * 0.3, 1.3), INK, 0.8))
            self.o.append(fill(ell(hx - hw * 0.6, hy - hl * 0.1, 1.8) + " " + ell(hx + hw * 0.6, hy - hl * 0.1, 1.8), INK))

    # ---------------------------------------------------------------- back view
    def back(self):
        d = self.d
        y0 = FY + self.bob
        bh, leg, lw = d["bh"], d["leg"], d["lw"]
        by = y0 - leg - bh * 0.55
        graze = not self.walk
        # head beyond (only when up), then the front legs peeking between the hind legs
        if not graze:
            hy = by - (d["neck"] * 0.75 if self.horse else bh * 0.6)
            self.sh(smooth([(CX - 9, by - 4), (CX - 7, hy + 4), (CX + 7, hy + 4), (CX + 9, by - 4)], t=0.3), "fur", s=1.4)
            if self.horse:
                self.o.append(lin(f"M{CX},{by-8} L{CX},{hy}", self.P.pal["mane"][1], 5, 0.95))
                for sd in (-1, 1):
                    self.sh(poly([(CX + sd * 3, hy - 2), (CX + sd * 8, hy - 12), (CX + sd * 9, hy)]), "fur2", s=0.5, lw=0.9)
            else:
                for sd in (-1, 1):
                    self.sh(f"M{CX+sd*5},{hy} q{sd*9},-4 {sd*11},-12 q{-sd*2},8 {-sd*8},14 Z", "horn", s=0.4, lw=0.9)
                    self.sh(ell(CX + sd * 12, hy + 2, 6, 3.2), "fur2", s=0.5, lw=0.9)
                self.sh(ell(CX, hy + 2, 10, 7), "fur", s=1)
        for sd in (-1, 1):
            lift = max(0.0, math.sin(self.ph) * sd) * 5 if self.walk else 0
            self.sh(capsule((CX + sd * 8, by + 8), (CX + sd * 8, y0 - 6 - lift), lw * 0.85, lw * 0.7), "fur2", s=1)
            self.sh(rect(CX + sd * 8 - lw * 0.7, y0 - 6 - lift, lw * 1.4, 5, 1.5), "hoof", s=0.5, lw=0.9)
        # rump and hind legs
        rump = smooth([(CX - bh * 1.05, by + bh * 0.4), (CX - bh * 0.95, by - bh * 0.7), (CX, by - bh * 0.95), (CX + bh * 0.95, by - bh * 0.7),
                       (CX + bh * 1.05, by + bh * 0.4), (CX, by + bh * 0.9)], t=0.45)
        self.sh(rump, "fur", s=2.8)
        if not self.horse:
            self.sh(blob(CX - 9, by - 4, 9, 7, 0.25, 6), "patch", s=0.8, lw=0.9)
        for sd in (-1, 1):
            lift = max(0.0, -math.sin(self.ph) * sd) * 5 if self.walk else 0
            fx = CX + sd * bh * 0.6
            self.sh(capsule((fx, by + 2), (fx, y0 - 4 - lift), lw * 1.15, lw * 0.8), "fur", s=1.3)
            self.sh(rect(fx - lw * 0.85, y0 - 5 - lift, lw * 1.7, 5, 1.5), "hoof", s=0.6, lw=1.0)
        if not self.horse:
            self.sh(ell(CX, by + bh * 0.95, 7, 4), "udder", s=0.5, lw=0.8)
        # tail down the middle
        flick = 4 * (self.br if graze else math.sin(self.ph))
        if self.horse:
            self.sh(smooth([(CX - 5, by - bh * 0.8), (CX + 5, by - bh * 0.8), (CX + 6 + flick, by + bh * 1.4), (CX + flick, by + bh * 1.9), (CX - 6 + flick, by + bh * 1.4)], t=0.4),
                    "mane", s=1.2)
        else:
            self.o.append(lin(f"M{CX},{by-bh*0.8} Q{CX+flick},{by+bh*0.4} {CX+flick},{by+bh*1.2}", INK, 3.4))
            self.o.append(lin(f"M{CX},{by-bh*0.8} Q{CX+flick},{by+bh*0.4} {CX+flick},{by+bh*1.2}", self.P.pal["fur2"][1], 1.8))
            self.sh(blob(CX + flick, by + bh * 1.3, 4, 6, 0.25, 3, squash=1.4), "patch", s=0.5)


def sheet_svg(cid, spec):
    pal = palette(spec)
    P = M.painter(pal, lw_mul=0.62)
    PM = M.painter(pal, mirror=True, lw_mul=0.62)
    ff = ink_filter(P, wob=1.3, dil=1.1, grain=0.55, soot=0.55, seed=7)
    body = []
    for r, view in enumerate(make_minis.VIEWS):
        for c, fr in enumerate(FRAMES):
            x0, y0 = c * 128, r * 128
            fig = Beast(PM if view == "W" else P, spec, "E" if view == "W" else view, fr).draw()
            k = 1.12 if spec["kind"] == "horse" else 1.08
            fig = f'<g transform="translate({CX},{FY}) scale({k}) translate({-CX},{-FY})">{fig}</g>'
            if view == "W":
                fig = f'<g transform="translate(256,0) scale(-1,1)">{fig}</g>'
            body.append(f'<g transform="translate({x0},{y0}) scale(0.5)"><g {ff}>{fig}</g></g>')
    P.defs.extend(PM.defs)
    figs = svg_doc(768, 512, P, "".join(body), ss=2)
    PB = M.painter(palette(spec))
    rx = 76 if spec["kind"] == "horse" else 72
    shadow, base = M.base(PB, "animal", rx=rx, ry=17, rim=7, seed=3)
    fb = ink_filter(PB, wob=1.0, dil=0.9, grain=0.5, soot=0.4, seed=4)
    bsvg = svg_doc(128, 128, PB, f'<g transform="scale(0.5)"><g>{shadow}</g><g {fb}>{base}</g></g>', ss=2)
    return figs, bsvg


def main():
    only = artlib.only_filter()
    ids = [k for k in SPECS if not only or k in only]
    js = []
    for cid in ids:
        figs, bsvg = sheet_svg(cid, SPECS[cid])
        js.append(dict(name=f"mini_{cid}", svg=figs, w=768, h=512, ss=2, out=os.path.join(make_minis.TMP, cid + "_fig.png")))
        js.append(dict(name=f"mini_{cid}_base", svg=bsvg, w=128, h=128, ss=2, out=os.path.join(make_minis.TMP, cid + "_base.png")))
    os.makedirs(make_minis.TMP, exist_ok=True)
    render(js)
    for cid in ids:
        make_minis.compose(cid)
    # review strip: every sheet on a grass-coloured ground at 1x
    from PIL import Image
    out = Image.new("RGBA", (768, 512 * len(ids)), (196, 176, 130, 255))
    for i, cid in enumerate(ids):
        out.alpha_composite(Image.open(os.path.join(SPR, "chars", "template_" + cid + ".png")).convert("RGBA"), (0, 512 * i))
    p = os.path.join(OUT, "livestock_strips.png")
    out.convert("RGB").save(p)
    print(p)


if __name__ == "__main__":
    main()
