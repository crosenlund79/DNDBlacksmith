"""Ironfront card game art (PIL): card faces, card back, row / ability icons, the war-room board,
the green M1 helmet overlay, round gems and a review contact sheet.

    python3 make_ironfront_art.py                 # everything
    python3 make_ironfront_art.py --only=tiger,sherman,board

Outputs (template_ names, so a user-provided <name>.png overrides them):
    assets/sprites/cards/template_<card id>.png    360x520 (a 180x260 card at 2x), text: name + flavour
    assets/sprites/ironfront/template_back.png     card back
    assets/sprites/ironfront/template_row_<inf|arm|air>.png, template_ab_<ability>.png (128x128)
    assets/sprites/ironfront/template_board.png    1920x1080 felt map table in lamplight (text-free)
    assets/sprites/ironfront/template_helmet.png   256x256 overlay for a 256 portrait (green M1 helmet)
    assets/sprites/ironfront/template_gem_on.png / template_gem_off.png
Review: tools/art/out/ironfront_contact.png
The game draws the strength number into the brass seal at (55, 55) of the 360x520 face.
Style: ink and parchment — every subject is a simple ink silhouette (side view for vehicles and guns,
top view for aircraft) with a muted wash, hatched shadow side and a heavy ink outline.
Only plain national markings: RAF roundel, US star, plain cross, red star. No political symbols.
"""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", ".."))
SPR = os.path.join(GAME, "assets", "sprites")
OUT_CARDS = os.path.join(SPR, "cards")
OUT_IF = os.path.join(SPR, "ironfront")
OUT_REV = os.path.join(HERE, "out")
FONTS = os.path.join(GAME, "assets", "fonts")
DATA = json.load(open(os.path.join(GAME, "data", "ironfront.json")))

INK = (32, 20, 12)
PARCH = (220, 199, 154)
PARCH_L = (236, 222, 190)
BRASS = (184, 146, 62)
BRASS_L = (236, 210, 140)
BRASS_D = (104, 74, 30)
RUB = (126, 36, 24)
FACTION = {"allies": (94, 106, 62), "axis": (88, 92, 96), "soviet": (122, 58, 44), "neutral": (122, 100, 64)}
WASH = {"allies": (128, 132, 88), "axis": (122, 124, 120), "soviet": (112, 120, 84), "neutral": (150, 130, 96)}
RARITY = {"common": (90, 86, 80), "uncommon": (196, 200, 206), "rare": (214, 170, 60), "special": (200, 96, 40)}

SS = 2           # supersampling
CW, CH = 360, 520


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


F_SC = "im-fell-english-sc-latin-400-normal.woff2"
F_IT = "im-fell-english-latin-400-italic.woff2"
F_GOTH = "grenze-gotisch-latin-800-normal.woff2"
F_BOLD = "grenze-latin-800-normal.woff2"


def tpath(path):
    d, f = os.path.split(path)
    return os.path.join(d, "template_" + f)


# ======================================================================= textures
def noise(w, h, scale, seed, octaves=3):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        sw, sh = max(2, int(w / scale) + 2), max(2, int(h / scale) + 2)
        small = Image.fromarray((rng.random((sh, sw)) * 255).astype(np.uint8))
        big = np.asarray(small.resize((w, h), Image.BICUBIC), np.float32) / 255.0
        out += big * amp
        tot += amp
        amp *= 0.5
        scale /= 2.2
    return out / tot


def parchment(w, h, seed=1, base=PARCH, burn=0.55, speck=True):
    n = noise(w, h, 90, seed)
    n2 = noise(w, h, 14, seed + 5, 2)
    arr = np.zeros((h, w, 3), np.float32)
    for i in range(3):
        arr[..., i] = base[i] * (0.86 + 0.2 * n + 0.06 * n2)
    yy, xx = np.mgrid[0:h, 0:w]
    dx = np.abs(xx - w / 2) / (w / 2)
    dy = np.abs(yy - h / 2) / (h / 2)
    edge = np.clip(np.maximum(dx, dy) ** 6 * burn + (dx ** 2 + dy ** 2) * 0.12, 0, 0.8)
    for i in range(3):
        arr[..., i] = arr[..., i] * (1 - edge) + [70, 44, 22][i] * edge
    if speck:
        rng = np.random.default_rng(seed + 9)
        k = int(w * h / 900)
        ys, xs = rng.integers(0, h, k), rng.integers(0, w, k)
        arr[ys, xs] *= 0.75
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def hatch_img(w, h, sp=7, width=2, angle=-35, col=INK):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    diag = int(math.hypot(w, h))
    a = math.radians(angle)
    ca, sa = math.cos(a), math.sin(a)
    cx, cy = w / 2, h / 2
    for t in range(-diag, diag, sp):
        # lines perpendicular offset t along normal
        nx, ny = -sa, ca
        x0, y0 = cx + nx * t - ca * diag, cy + ny * t - sa * diag
        x1, y1 = cx + nx * t + ca * diag, cy + ny * t + sa * diag
        d.line([(x0, y0), (x1, y1)], fill=col + (255,), width=width)
    return im


# ======================================================================= figure builder
class Fig:
    """Collects a silhouette mask, a 'light' accent mask and ink detail strokes in a local box."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.mask = Image.new("L", (w, h), 0)
        self.md = ImageDraw.Draw(self.mask)
        self.det = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.dd = ImageDraw.Draw(self.det)
        self.cols = Image.new("RGBA", (w, h), (0, 0, 0, 0))   # flat colour accents painted over the wash
        self.cd = ImageDraw.Draw(self.cols)
        self.shadow = []

    # body shapes
    def poly(self, pts, cut=False):
        self.md.polygon([tuple(map(float, p)) for p in pts], fill=0 if cut else 255)

    def ell(self, cx, cy, rx, ry, cut=False):
        self.md.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=0 if cut else 255)

    def rect(self, x0, y0, x1, y1, r=0, cut=False):
        if r:
            self.md.rounded_rectangle([x0, y0, x1, y1], r, fill=0 if cut else 255)
        else:
            self.md.rectangle([x0, y0, x1, y1], fill=0 if cut else 255)

    def bar(self, p0, p1, wdt):
        """thick line (barrel, rifle, strut) as body"""
        (x0, y0), (x1, y1) = p0, p1
        L = math.hypot(x1 - x0, y1 - y0) or 1
        nx, ny = -(y1 - y0) / L * wdt / 2, (x1 - x0) / L * wdt / 2
        self.poly([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)])

    # ink details
    def line(self, pts, w=3, col=INK, a=255):
        self.dd.line([tuple(map(float, p)) for p in pts], fill=col + (a,), width=w, joint="curve")

    def circ(self, cx, cy, r, w=3, fill=None, col=INK):
        self.dd.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col + (255,), width=w, fill=fill)

    def dot(self, cx, cy, r, col=INK):
        self.dd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col + (255,))

    def paint_poly(self, pts, col):
        self.cd.polygon([tuple(map(float, p)) for p in pts], fill=col + (255,))

    def paint_ell(self, cx, cy, rx, ry, col):
        self.cd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=col + (255,))

    def ground(self, cx, cy, rx, ry):
        self.shadow.append((cx, cy, rx, ry))

    def render(self, wash, shade_dir="down", outline=7):
        w, h = self.w, self.h
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        # hatched ground shadow
        if self.shadow:
            sm = Image.new("L", (w, h), 0)
            sd = ImageDraw.Draw(sm)
            for cx, cy, rx, ry in self.shadow:
                sd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=150)
            sm = sm.filter(ImageFilter.GaussianBlur(6))
            hat = hatch_img(w, h, 8, 2, -35, (60, 40, 20))
            hat.putalpha(ImageChops.multiply(hat.getchannel("A"), sm))
            out.alpha_composite(hat)
        m = self.mask
        # wash
        body = Image.new("RGBA", (w, h), wash + (255,))
        # light gradient (top-left lit)
        yy, xx = np.mgrid[0:h, 0:w]
        if shade_dir == "down":
            g = np.clip((yy / h - 0.15) * 1.4, 0, 1)
        else:
            g = np.clip(((xx / w) * 0.6 + (yy / h) * 0.6 - 0.35) * 1.4, 0, 1)
        dark = Image.fromarray((g * 110).astype(np.uint8))
        shade = Image.new("RGBA", (w, h), (30, 20, 12, 255))
        shade.putalpha(dark)
        body.alpha_composite(shade)
        body.alpha_composite(self.cols)
        # hatch the shadow side
        hat = hatch_img(w, h, 7, 2, 35)
        hm = Image.fromarray((np.clip(g - 0.35, 0, 1) * 1.6 * 200).clip(0, 200).astype(np.uint8))
        hat.putalpha(ImageChops.multiply(hat.getchannel("A"), hm))
        body.alpha_composite(hat)
        body.putalpha(m)
        # outline ring
        dil = m.filter(ImageFilter.MaxFilter(outline if outline % 2 else outline + 1))
        ring = Image.new("RGBA", (w, h), INK + (255,))
        ring.putalpha(dil)
        out.alpha_composite(ring)
        out.alpha_composite(body)
        det = self.det.copy()
        out.alpha_composite(det)
        return out


# ======================================================================= markings
def roundel(f, cx, cy, r, faction, kind=None):
    k = kind or {"allies": "raf", "axis": "cross", "soviet": "star"}.get(faction, "")
    if k == "raf":
        f.paint_ell(cx, cy, r, r, (200, 196, 180))
        f.paint_ell(cx, cy, r, r, (52, 66, 104))
        f.paint_ell(cx, cy, r * 0.66, r * 0.66, (214, 206, 186))
        f.paint_ell(cx, cy, r * 0.36, r * 0.36, (150, 46, 34))
        f.circ(cx, cy, r, 2)
    elif k == "usstar":
        f.paint_ell(cx, cy, r, r, (52, 66, 104))
        f.paint_poly(star_pts(cx, cy, r * 0.95, r * 0.38), (222, 214, 194))
        f.circ(cx, cy, r, 2)
    elif k == "cross":
        a, b = r, r * 0.32
        f.paint_poly([(cx - a, cy - b - 3), (cx + a, cy - b - 3), (cx + a, cy + b + 3), (cx - a, cy + b + 3)], (222, 214, 194))
        f.paint_poly([(cx - b - 3, cy - a), (cx + b + 3, cy - a), (cx + b + 3, cy + a), (cx - b - 3, cy + a)], (222, 214, 194))
        a2, b2 = r * 0.8, r * 0.2
        f.paint_poly([(cx - a2, cy - b2), (cx + a2, cy - b2), (cx + a2, cy + b2), (cx - a2, cy + b2)], (34, 30, 28))
        f.paint_poly([(cx - b2, cy - a2), (cx + b2, cy - a2), (cx + b2, cy + a2), (cx - b2, cy + a2)], (34, 30, 28))
    elif k == "star":
        f.paint_poly(star_pts(cx, cy, r * 1.0, r * 0.4), (226, 216, 196))
        f.paint_poly(star_pts(cx, cy, r * 0.82, r * 0.33), (164, 44, 32))


def star_pts(cx, cy, R, r, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        rr = R if i % 2 == 0 else r
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return pts


# ======================================================================= vehicles (side view, facing right)
TANKS = {
    # L hull length, H hull height, glacis, turret (x0 frac, w frac, h, shape), gun (len frac, thick), wheels (n, r, overlap)
    "tank_sherman": dict(L=0.78, H=0.20, glacis=0.16, tx=0.38, tw=0.30, th=0.17, tshape="round", gun=0.30, gt=12, wheels=6, wr=0.045, bogie=True, tall=0.07),
    "tank_firefly": dict(L=0.78, H=0.20, glacis=0.16, tx=0.38, tw=0.30, th=0.17, tshape="round", gun=0.50, gt=11, wheels=6, wr=0.045, bogie=True, tall=0.07, brake=True),
    "tank_churchill": dict(L=0.92, H=0.22, glacis=0.02, tx=0.36, tw=0.24, th=0.15, tshape="box", gun=0.20, gt=12, wheels=11, wr=0.03, high_track=True),
    "tank_funnies": dict(L=0.9, H=0.22, glacis=0.02, tx=0.36, tw=0.24, th=0.15, tshape="box", gun=0.12, gt=14, wheels=11, wr=0.03, high_track=True, flail=True),
    "tank_p4": dict(L=0.78, H=0.16, glacis=0.08, tx=0.32, tw=0.30, th=0.15, tshape="box", gun=0.38, gt=10, wheels=8, wr=0.033, skirts=True, brake=True),
    "tank_panther": dict(L=0.84, H=0.17, glacis=0.24, tx=0.40, tw=0.26, th=0.15, tshape="slope", gun=0.52, gt=10, wheels=8, wr=0.05, overlap=True, brake=True),
    "tank_tiger": dict(L=0.82, H=0.22, glacis=0.05, tx=0.33, tw=0.36, th=0.18, tshape="tiger", gun=0.44, gt=13, wheels=8, wr=0.055, overlap=True, brake=True),
    "tank_tiger2": dict(L=0.86, H=0.20, glacis=0.22, tx=0.36, tw=0.36, th=0.17, tshape="slope", gun=0.54, gt=13, wheels=9, wr=0.05, overlap=True, brake=True),
    "tank_t34": dict(L=0.80, H=0.17, glacis=0.26, tx=0.36, tw=0.30, th=0.15, tshape="round", gun=0.42, gt=11, wheels=5, wr=0.07),
    "tank_kv1": dict(L=0.80, H=0.24, glacis=0.08, tx=0.33, tw=0.32, th=0.18, tshape="box", gun=0.26, gt=12, wheels=6, wr=0.04, high_track=True),
    "tank_is2": dict(L=0.84, H=0.20, glacis=0.18, tx=0.33, tw=0.36, th=0.17, tshape="round", gun=0.48, gt=14, wheels=6, wr=0.045, brake=True),
    "spg_stug": dict(L=0.80, H=0.15, glacis=0.10, tx=0.12, tw=0.48, th=0.13, tshape="casemate", gun=0.30, gt=11, wheels=6, wr=0.042, skirts=True, gun_y=0.5),
    "spg_su152": dict(L=0.82, H=0.18, glacis=0.10, tx=0.10, tw=0.56, th=0.18, tshape="casemate", gun=0.24, gt=18, wheels=6, wr=0.045, brake=True, gun_y=0.45),
    "spg_priest": dict(L=0.80, H=0.20, glacis=0.16, tx=0.18, tw=0.50, th=0.14, tshape="open", gun=0.22, gt=12, wheels=6, wr=0.045, bogie=True, pulpit=True, gun_y=0.6),
}


def tank(f, faction, spec, x0=None, base=None, scale=1.0):
    W, H = f.w, f.h
    scale = scale * 1.02 / (spec["L"] + spec.get("gun", 0.3) * 0.75)
    L = spec["L"] * W * scale
    x0 = (W - L - spec.get("gun", 0.3) * W * scale * 0.75) / 2 if x0 is None else x0
    gy = H * 0.78 if base is None else base           # ground line
    th_ = spec.get("wr", 0.05) * W * scale * 2.4       # track height
    hh = spec["H"] * L * 0.7
    tall = spec.get("tall", 0) * L * 0.6
    # track (rounded band)
    ty0 = gy - th_
    f.rect(x0, ty0, x0 + L, gy, r=th_ * 0.5)
    if spec.get("high_track"):
        f.poly([(x0 - 6, gy - th_ * 0.6), (x0 + L * 0.05, ty0 - hh * 0.55), (x0 + L * 0.95, ty0 - hh * 0.55), (x0 + L + 8, gy - th_ * 0.6), (x0 + L, gy), (x0, gy)])
    # hull
    hy1 = ty0 + th_ * 0.25
    hy0 = hy1 - hh - tall
    gl = spec["glacis"] * L
    f.poly([(x0 + L * 0.02, hy1), (x0 + L * 0.02, hy0), (x0 + L - gl, hy0), (x0 + L + 4, hy1 - (hh * 0.15)), (x0 + L, hy1)])
    # turret / superstructure
    tx = x0 + spec["tx"] * L
    tw = spec["tw"] * L
    tht = spec["th"] * L * 0.75
    ts = spec["tshape"]
    gun_y = hy0 - tht * spec.get("gun_y", 0.55)
    if ts == "round":
        f.poly([(tx, hy0 + 2), (tx + tw * 0.05, hy0 - tht * 0.75), (tx + tw * 0.35, hy0 - tht), (tx + tw * 0.8, hy0 - tht * 0.95),
                (tx + tw, hy0 - tht * 0.45), (tx + tw, hy0 + 2)])
        f.ell(tx + tw * 0.62, hy0 - tht * 0.62, tw * 0.42, tht * 0.5)
    elif ts in ("box", "tiger"):
        f.rect(tx, hy0 - tht, tx + tw, hy0 + 2, r=4)
        if ts == "tiger":
            f.rect(tx + tw * 0.3, hy0 - tht - 10, tx + tw * 0.48, hy0 - tht + 2, r=4)   # cupola
    elif ts == "slope":
        f.poly([(tx - 6, hy0 + 2), (tx + tw * 0.12, hy0 - tht), (tx + tw * 0.88, hy0 - tht), (tx + tw + 8, hy0 + 2)])
    elif ts == "casemate":
        f.poly([(tx, hy0 + 2), (tx + tw * 0.08, hy0 - tht), (tx + tw * 0.86, hy0 - tht), (tx + tw, hy0 + 2)])
        gun_y = hy0 - tht * spec.get("gun_y", 0.5)
    elif ts == "open":
        f.poly([(tx, hy0 + 2), (tx + 6, hy0 - tht), (tx + tw, hy0 - tht), (tx + tw + 10, hy0 + 2)])
        if spec.get("pulpit"):
            f.rect(tx + tw * 0.62, hy0 - tht - 26, tx + tw * 0.86, hy0 - tht + 4, r=8)
    if ts != "casemate" and ts != "open":
        f.rect(tx + tw * 0.78, gun_y - spec["gt"] * 0.9, tx + tw + 6, gun_y + spec["gt"] * 0.9, r=3)   # mantlet
    # gun
    gx0 = tx + tw * (0.92 if ts not in ("casemate", "open") else 0.98)
    if ts == "casemate":
        gx0 = x0 + L - gl * 0.6
    if ts == "open":
        gx0 = tx + tw
    gl_ = spec["gun"] * W * scale
    gt = spec["gt"] * scale
    f.bar((gx0, gun_y), (gx0 + gl_, gun_y + (0 if ts != "open" else -gl_ * 0.25)), gt)
    if spec.get("brake"):
        f.rect(gx0 + gl_ - 14, gun_y - gt * 0.95, gx0 + gl_ + 2, gun_y + gt * 0.95, r=2)
    if spec.get("flail"):
        f.bar((x0 + L * 0.8, hy0 + 6), (x0 + L + 70, hy0 + 20), 8)
        f.bar((x0 + L * 0.8, hy0 + 30), (x0 + L + 70, hy0 + 26), 8)
        f.ell(x0 + L + 74, hy0 + 30, 22, 46)
        for i in range(7):
            yy = hy0 - 10 + i * 13
            f.line([(x0 + L + 60, yy), (x0 + L + 100, yy + 10)], 3)
    # skirts
    if spec.get("skirts"):
        f.rect(x0 + L * 0.06, hy1 - hh * 0.45, x0 + L * 0.9, hy1 + th_ * 0.35)
        for i in range(1, 6):
            xx = x0 + L * 0.06 + (L * 0.84) * i / 6
            f.line([(xx, hy1 - hh * 0.45 + 3), (xx, hy1 + th_ * 0.35 - 3)], 2)
    # ink details: wheels
    n = spec["wheels"]
    wr = spec["wr"] * W * scale
    cy = gy - th_ * 0.45
    if not spec.get("skirts") and not spec.get("high_track"):
        for i in range(n):
            cx = x0 + th_ * 0.45 + (L - th_ * 0.9) * (i / max(1, n - 1))
            f.circ(cx, cy, wr, 3)
            f.dot(cx, cy, 3)
            if spec.get("overlap") and i < n - 1:
                f.circ(cx + (L - th_ * 0.9) / max(1, n - 1) * 0.5, cy + 2, wr * 0.9, 2)
    elif spec.get("high_track"):
        for i in range(n):
            cx = x0 + th_ * 0.3 + (L - th_ * 0.6) * (i / max(1, n - 1))
            f.circ(cx, gy - wr - 3, wr, 2)
    else:
        for i in range(n):
            cx = x0 + th_ * 0.45 + (L - th_ * 0.9) * (i / max(1, n - 1))
            f.circ(cx, gy - wr * 0.6, wr * 0.7, 2)
    # track links
    for i in range(int(L / 12)):
        xx = x0 + i * 12 + 6
        f.line([(xx, gy - 4), (xx + 3, gy)], 2)
    # hull plate line, hatch, marking
    f.line([(x0 + L * 0.04, hy0 + hh * 0.35), (x0 + L - gl * 0.7, hy0 + hh * 0.35)], 2)
    f.circ(tx + tw * 0.3, hy0 - tht * 0.95, 7, 2)
    mk = {"allies": "usstar", "axis": "cross", "soviet": "star"}[faction] if faction in FACTION and faction != "neutral" else None
    if mk:
        roundel(f, x0 + L * 0.3, hy0 + hh * 0.62, min(26, hh * 0.32), faction, mk)
    f.ground(x0 + L / 2, gy + 4, L * 0.62, 18)
    return x0, gy, L


def car(f, faction, kind):
    W, H = f.w, f.h
    gy = H * 0.80
    if kind == "car_jeep":
        x0, L = W * 0.22, W * 0.54
        f.poly([(x0, gy - 60), (x0 + L * 0.08, gy - 96), (x0 + L * 0.58, gy - 96), (x0 + L * 0.66, gy - 100), (x0 + L, gy - 84), (x0 + L, gy - 46), (x0, gy - 46)])
        f.poly([(x0 + L * 0.56, gy - 98), (x0 + L * 0.6, gy - 150), (x0 + L * 0.64, gy - 150), (x0 + L * 0.66, gy - 98)])  # windscreen
        f.bar((x0 + L * 0.2, gy - 96), (x0 + L * 0.2, gy - 170), 5)   # radio aerial
        for cx in (x0 + L * 0.18, x0 + L * 0.82):
            f.ell(cx, gy - 30, 34, 34)
        for cx in (x0 + L * 0.18, x0 + L * 0.82):
            f.circ(cx, gy - 30, 16, 3)
        f.ell(x0 - 10, gy - 74, 20, 26)   # spare wheel
        roundel(f, x0 + L * 0.42, gy - 70, 18, faction, "usstar")
        f.ground(W / 2, gy + 4, L * 0.6, 14)
    elif kind == "car_halftrack":
        x0, L = W * 0.12, W * 0.74
        f.rect(x0 + L * 0.34, gy - 50, x0 + L * 0.98, gy, r=24)
        f.poly([(x0 + L * 0.02, gy - 70), (x0 + L * 0.12, gy - 130), (x0 + L * 0.92, gy - 130), (x0 + L, gy - 60), (x0 + L, gy - 40), (x0 + L * 0.02, gy - 40)])
        f.poly([(x0 - 14, gy - 70), (x0 + L * 0.02, gy - 112), (x0 + L * 0.14, gy - 112), (x0 + L * 0.14, gy - 60)])
        f.ell(x0 + L * 0.06, gy - 32, 34, 34)
        f.circ(x0 + L * 0.06, gy - 32, 15, 3)
        for i in range(5):
            f.circ(x0 + L * 0.42 + i * L * 0.12, gy - 22, 18, 2)
        f.bar((x0 + L * 0.3, gy - 132), (x0 + L * 0.15, gy - 150), 6)   # MG
        roundel(f, x0 + L * 0.6, gy - 88, 20, faction, "cross")
        f.ground(W / 2, gy + 4, L * 0.6, 16)
    elif kind in ("car_truck", "gun_katyusha"):
        x0, L = W * 0.14, W * 0.72
        f.poly([(x0 + L * 0.72, gy - 50), (x0 + L * 0.74, gy - 140), (x0 + L * 0.9, gy - 140), (x0 + L * 0.96, gy - 100), (x0 + L, gy - 96), (x0 + L, gy - 50)])
        f.rect(x0, gy - 64, x0 + L, gy - 40)
        if kind == "car_truck":
            f.rect(x0, gy - 150, x0 + L * 0.7, gy - 60, r=8)   # canvas tilt
            for i in range(1, 5):
                xx = x0 + L * 0.7 * i / 5
                f.line([(xx, gy - 146), (xx, gy - 64)], 2)
        else:
            # rail rack, angled up and back
            p0, p1 = (x0 + L * 0.62, gy - 70), (x0 + L * 0.02, gy - 190)
            for k in range(4):
                f.bar((p0[0], p0[1] - k * 14), (p1[0], p1[1] - k * 14), 9)
            f.bar((x0 + L * 0.5, gy - 64), (x0 + L * 0.42, gy - 120), 12)
            for i in range(6):
                t = 0.15 + i * 0.14
                f.dot(p0[0] + (p1[0] - p0[0]) * t, p0[1] - 20 + (p1[1] - p0[1]) * t, 4)
        for cx in (x0 + L * 0.12, x0 + L * 0.3, x0 + L * 0.84):
            f.ell(cx, gy - 30, 32, 32)
        for cx in (x0 + L * 0.12, x0 + L * 0.3, x0 + L * 0.84):
            f.circ(cx, gy - 30, 14, 3)
        roundel(f, x0 + L * 0.84, gy - 100, 16, faction, "star")
        f.ground(W / 2, gy + 4, L * 0.6, 16)


def gun_88(f, faction):
    W, H = f.w, f.h
    gy = H * 0.82
    cx = W * 0.42
    f.poly([(cx - 220, gy - 8), (cx + 220, gy - 8), (cx + 220, gy + 6), (cx - 220, gy + 6)])
    f.poly([(cx - 60, gy - 40), (cx + 60, gy - 40), (cx + 70, gy - 6), (cx - 70, gy - 6)])
    for xx in (cx - 210, cx + 210):
        f.rect(xx - 22, gy - 4, xx + 22, gy + 12, r=4)
    f.rect(cx - 30, gy - 110, cx + 34, gy - 36, r=6)
    a = math.radians(-38)
    L = W * 0.55
    p0 = (cx - 40, gy - 92)
    p1 = (p0[0] + math.cos(a) * L, p0[1] + math.sin(a) * L)
    f.bar(p0, p1, 16)
    f.bar(p0, (p0[0] + math.cos(a) * L * 0.35, p0[1] + math.sin(a) * L * 0.35), 30)
    sh = [(cx + 40, gy - 50), (cx + 120, gy - 170), (cx + 150, gy - 150), (cx + 70, gy - 30)]
    f.poly(sh)   # shield
    f.line([(cx - 50, gy - 90), (cx - 120, gy - 40)], 4)
    for i in range(5):
        f.line([(cx - 60 + i * 30, gy - 38), (cx - 50 + i * 30, gy - 10)], 2)
    f.ground(cx, gy + 8, 250, 16)


# ======================================================================= aircraft (top view, nose up)
PLANES = {
    "air_spitfire": dict(span=0.86, length=0.62, chord=0.17, shape="ellipse", tail=0.26, nose="inline", engines=0),
    "air_mustang": dict(span=0.84, length=0.66, chord=0.15, shape="taper", tail=0.28, nose="inline", engines=0, scoop=True),
    "air_typhoon": dict(span=0.88, length=0.64, chord=0.17, shape="taper", tail=0.28, nose="chin", engines=0),
    "air_bf109": dict(span=0.78, length=0.64, chord=0.14, shape="clipped", tail=0.24, nose="inline", engines=0),
    "air_fw190": dict(span=0.80, length=0.62, chord=0.15, shape="taper", tail=0.25, nose="radial", engines=0),
    "air_yak": dict(span=0.76, length=0.62, chord=0.15, shape="taper", tail=0.24, nose="inline", engines=0),
    "air_il2": dict(span=0.90, length=0.66, chord=0.18, shape="taper", tail=0.30, nose="inline", engines=0, swept=0.06),
    "air_stuka": dict(span=0.90, length=0.66, chord=0.18, shape="gull", tail=0.30, nose="inline", engines=0, spats=True),
    "air_lancaster": dict(span=0.96, length=0.62, chord=0.15, shape="taper", tail=0.34, nose="glass", engines=4, twin_tail=True),
    "air_dakota": dict(span=0.96, length=0.60, chord=0.16, shape="taper", tail=0.30, nose="round", engines=2),
    "air_ju52": dict(span=0.96, length=0.60, chord=0.18, shape="taper", tail=0.32, nose="radial", engines=3, corrugated=True),
    "air_po2": dict(span=0.84, length=0.56, chord=0.16, shape="rect", tail=0.24, nose="radial", engines=0, biplane=True),
    "air_me262": dict(span=0.80, length=0.68, chord=0.14, shape="taper", tail=0.24, nose="jet", engines=2, swept=0.16, jets=True),
    "air_mosquito": dict(span=0.88, length=0.58, chord=0.15, shape="taper", tail=0.28, nose="glass", engines=2),
}
PLANE_MARK = {"allies": "raf", "axis": "cross", "soviet": "star"}


def plane(f, faction, spec, cx=None, cy=None, scale=1.0, mark=True):
    W, H = f.w, f.h
    cx = W / 2 if cx is None else cx
    cy = H * 0.5 if cy is None else cy
    s = min(W, H * 1.25) * scale
    span, length, chord = spec["span"] * s, spec["length"] * s * 0.95, spec["chord"] * s
    nose_y = cy - length * 0.5
    tail_y = cy + length * 0.5
    wy = cy - length * 0.12                 # wing leading edge at root
    fw = s * (0.07 if spec["nose"] != "radial" else 0.085)
    if spec.get("engines", 0) >= 2:
        fw = s * 0.065
    sw = spec.get("swept", 0) * s
    # wings
    half = span / 2
    shp = spec["shape"]
    if shp == "ellipse":
        pts = []
        for i in range(41):
            t = i / 40
            x = cx - half + span * t
            u = (x - cx) / half
            lead = wy + chord * 0.15 * u * u
            pts.append((x, lead))
        for i in range(41):
            t = 1 - i / 40
            x = cx - half + span * t
            u = (x - cx) / half
            trail = wy + chord * (1 - 0.25 * u * u) * math.sqrt(max(0.0, 1 - u ** 8)) + chord * 0.15 * u * u
            pts.append((x, max(trail, wy + chord * 0.15 * u * u + 4)))
        f.poly(pts)
    else:
        tipc = chord * (0.55 if shp in ("taper", "gull") else 0.75 if shp == "clipped" else 1.0)
        f.poly([(cx - fw, wy), (cx - half, wy + sw + chord * 0.1), (cx - half, wy + sw + chord * 0.1 + tipc),
                (cx - fw, wy + chord), (cx + fw, wy + chord), (cx + half, wy + sw + chord * 0.1 + tipc),
                (cx + half, wy + sw + chord * 0.1), (cx + fw, wy)])
        if shp == "clipped":
            pass
    if spec.get("biplane"):
        f.poly([(cx - half * 0.98, wy - chord * 0.9), (cx + half * 0.98, wy - chord * 0.9), (cx + half * 0.98, wy + chord * 0.05 - chord * 0.9 + chord), (cx - half * 0.98, wy + chord * 0.05 - chord * 0.9 + chord)])
    # fuselage
    fus = []
    for i in range(31):
        t = i / 30
        y = nose_y + length * t
        wdt = fw * (0.75 + 0.6 * math.sin(min(1.0, t * 2.2) * math.pi / 2)) * (1 - 0.72 * max(0.0, t - 0.45) / 0.55)
        if spec["nose"] in ("radial", "round", "glass") and t < 0.08:
            wdt = fw * (0.9 + t)
        fus.append((cx - wdt, y))
    fus += [(cx + x_ - cx + 2 * (cx - x_) + (x_ - cx) * 0, y) for (x_, y) in reversed(fus)]
    fus = fus[:31] + [(2 * cx - x, y) for (x, y) in reversed(fus[:31])]
    f.poly(fus)
    # tailplane
    tp = spec["tail"] * s / 2
    ty = tail_y - length * 0.1
    f.poly([(cx - tp, ty), (cx - tp * 0.9, ty + length * 0.08), (cx + tp * 0.9, ty + length * 0.08), (cx + tp, ty), (cx + fw * 0.5, ty - length * 0.06), (cx - fw * 0.5, ty - length * 0.06)])
    if spec.get("twin_tail"):
        for sd in (-1, 1):
            f.ell(cx + sd * tp, ty + length * 0.04, 10, 34)
    # engines
    ne = spec.get("engines", 0)
    pos = {2: [-0.3, 0.3], 3: [-0.34, 0.34], 4: [-0.44, -0.2, 0.2, 0.44]}.get(ne, [])
    for p in pos:
        ex = cx + p * span
        if spec.get("jets"):
            f.ell(ex, wy + chord * 0.4, s * 0.04, chord * 1.0)
            f.circ(ex, wy - chord * 0.5, s * 0.025, 3)
        else:
            f.ell(ex, wy + chord * 0.15, s * 0.04, chord * 0.75)
            f.line([(ex - s * 0.07, wy - chord * 0.55), (ex + s * 0.07, wy - chord * 0.55)], 4)
    if ne == 3:
        f.line([(cx - s * 0.07, nose_y - 6), (cx + s * 0.07, nose_y - 6)], 4)
    # propeller (single engine)
    if ne == 0:
        f.ell(cx, nose_y - 2, fw * 0.45, fw * 0.45)
        f.line([(cx - s * 0.12, nose_y - 6), (cx + s * 0.12, nose_y - 6)], 5)
        f.dd.ellipse([cx - s * 0.13, nose_y - 12, cx + s * 0.13, nose_y], outline=INK + (90,), width=2)
    # cockpit
    cpy = nose_y + length * (0.36 if ne == 0 else 0.14)
    f.paint_ell(cx, cpy, fw * 0.45, length * 0.07, (190, 200, 196))
    f.circ(cx, cpy, 0, 1)
    f.dd.ellipse([cx - fw * 0.45, cpy - length * 0.07, cx + fw * 0.45, cpy + length * 0.07], outline=INK + (255,), width=3)
    # details
    f.line([(cx - half * 0.9, wy + chord * 0.55), (cx - fw, wy + chord * 0.55)], 2)
    f.line([(cx + fw, wy + chord * 0.55), (cx + half * 0.9, wy + chord * 0.55)], 2)
    if spec.get("corrugated"):
        for i in range(-12, 13):
            xx = cx + i * span / 26
            f.line([(xx, wy + 6), (xx, wy + chord - 6)], 1)
    if spec.get("spats"):
        for sd in (-1, 1):
            f.ell(cx + sd * span * 0.13, wy - chord * 0.2, 12, 26)
        for sd in (-1, 1):
            f.line([(cx + sd * span * 0.17, wy + 4), (cx + sd * span * 0.17, wy + chord - 4)], 3)
    if spec.get("scoop"):
        f.line([(cx, cy + length * 0.05), (cx, cy + length * 0.18)], 6)
    if spec["nose"] == "glass":
        f.paint_ell(cx, nose_y + 10, fw * 0.7, fw * 0.6, (190, 200, 196))
    if mark:
        r = min(chord * 0.32, 30)
        mk = PLANE_MARK.get(faction, "")
        if faction == "allies" and spec is PLANES.get("air_mustang") or (faction == "allies" and spec is PLANES.get("air_dakota")):
            mk = "usstar"
        for sd in (-1, 1):
            roundel(f, cx + sd * half * 0.62, wy + sw * 0.62 + chord * 0.45, r, faction, mk)
    f.ground(cx + 30, cy + 40, span * 0.42, length * 0.3)


# ======================================================================= infantry
HELMETS = ("m1", "brodie", "stahl", "ssh", "beret", "hood", "cap")


def soldier(f, x, y, h, helmet="m1", pose="stand", weapon="rifle", face=1, pack=True):
    """x, y = feet centre; h = standing height; face 1 = facing right."""
    u = h / 10.0
    hx, hy = x + face * u * (0.6 if pose == "advance" else 0.2), y - u * 9.0
    if pose == "kneel":
        hy = y - u * 7.0
    if pose == "prone":
        hy = y - u * 1.6
        hx = x + face * u * 4.2
    # legs
    if pose == "stand":
        f.bar((x - u * 0.5, y - u * 4.6), (x - u * 0.7, y), u * 1.2)
        f.bar((x + u * 0.5, y - u * 4.6), (x + u * 0.6, y), u * 1.2)
    elif pose == "advance":
        f.bar((x, y - u * 4.6), (x - face * u * 1.8, y), u * 1.2)
        f.bar((x + face * u * 0.2, y - u * 4.6), (x + face * u * 1.6, y - u * 2.2), u * 1.2)
        f.bar((x + face * u * 1.6, y - u * 2.2), (x + face * u * 1.9, y), u * 1.15)
    elif pose == "kneel":
        f.bar((x, y - u * 3.0), (x + face * u * 1.9, y - u * 2.7), u * 1.25)
        f.bar((x + face * u * 1.9, y - u * 2.7), (x + face * u * 2.0, y), u * 1.15)
        f.bar((x, y - u * 3.0), (x - face * u * 0.9, y - u * 0.3), u * 1.2)
        f.bar((x - face * u * 0.9, y - u * 0.3), (x - face * u * 2.6, y - u * 0.2), u * 1.0)
    elif pose == "prone":
        f.bar((x - face * u * 4.5, y - u * 0.6), (x + face * u * 2.5, y - u * 1.0), u * 1.6)
    # torso
    if pose != "prone":
        ty0, ty1 = (hy + u * 1.0, y - u * 4.2) if pose != "kneel" else (hy + u * 1.0, y - u * 2.6)
        lean = face * u * (0.8 if pose == "advance" else 0.2)
        f.poly([(x - u * 1.3, ty1), (x - u * 1.25 + lean, ty0), (x + u * 1.25 + lean, ty0), (x + u * 1.3, ty1)])
        if pack:
            f.rect(x - face * u * 2.1 + lean * 0.5 - u * 0.6, ty0 + u * 0.4, x - face * u * 1.1 + lean * 0.5 + u * 0.3, ty0 + u * 2.6, r=6)
    # head + helmet
    f.ell(hx, hy, u * 0.85, u * 0.95)
    if helmet == "m1":
        f.poly([(hx - u * 1.35, hy - u * 0.05), (hx - u * 1.1, hy - u * 0.9), (hx - u * 0.4, hy - u * 1.45), (hx + u * 0.4, hy - u * 1.45),
                (hx + u * 1.1, hy - u * 0.9), (hx + u * 1.35, hy - u * 0.05)])
    elif helmet == "brodie":
        f.poly([(hx - u * 1.9, hy - u * 0.5), (hx + u * 1.9, hy - u * 0.5), (hx + u * 1.6, hy - u * 0.75), (hx + u * 0.6, hy - u * 1.35), (hx - u * 0.6, hy - u * 1.35), (hx - u * 1.6, hy - u * 0.75)])
    elif helmet == "stahl":
        f.poly([(hx - u * 1.2, hy + u * 0.35), (hx - u * 1.05, hy - u * 0.9), (hx - u * 0.4, hy - u * 1.42), (hx + u * 0.4, hy - u * 1.42), (hx + u * 1.05, hy - u * 0.9),
                (hx + u * 1.15, hy - u * 0.2), (hx + u * 1.5 * face, hy + u * 0.3)])
        f.poly([(hx - face * u * 0.4, hy - u * 0.2), (hx - face * u * 1.5, hy + u * 0.45), (hx - face * u * 1.0, hy - u * 0.8)])
    elif helmet == "ssh":
        f.poly([(hx - u * 1.25, hy + u * 0.1), (hx - u * 1.1, hy - u * 0.95), (hx - u * 0.4, hy - u * 1.5), (hx + u * 0.4, hy - u * 1.5), (hx + u * 1.1, hy - u * 0.95), (hx + u * 1.25, hy + u * 0.1)])
    elif helmet == "beret":
        f.ell(hx - face * u * 0.25, hy - u * 0.85, u * 1.05, u * 0.42)
    elif helmet == "hood":
        f.ell(hx, hy - u * 0.1, u * 1.15, u * 1.25)
    elif helmet == "cap":
        f.ell(hx, hy - u * 0.75, u * 0.95, u * 0.45)
        f.poly([(hx, hy - u * 0.6), (hx + face * u * 1.6, hy - u * 0.5), (hx + face * u * 0.8, hy - u * 0.95)])
    # arms + weapons
    sx, sy = x + face * u * 0.6, hy + u * 1.6
    if pose == "prone":
        sx, sy = hx - face * u * 1.2, hy + u * 0.5
    if weapon == "rifle":
        f.bar((sx, sy), (sx + face * u * 2.0, sy + u * 1.4), u * 0.75)
        f.bar((sx - face * u * 1.4, sy + u * 2.4), (sx + face * u * 4.4, sy - u * 0.4), u * 0.45)
    elif weapon == "smg":
        f.bar((sx, sy), (sx + face * u * 1.8, sy + u * 1.2), u * 0.75)
        f.bar((sx - face * u * 0.4, sy + u * 1.8), (sx + face * u * 3.0, sy + u * 0.9), u * 0.6)
    elif weapon == "tube":
        f.bar((sx - face * u * 3.2, sy - u * 0.2), (sx + face * u * 3.6, sy - u * 0.7), u * 0.95)
        f.bar((sx, sy + u * 0.2), (sx + face * u * 1.2, sy + u * 0.4), u * 0.7)
    elif weapon == "mg":
        f.bar((sx, sy + u * 0.2), (sx + face * u * 5.2, sy + u * 0.1), u * 0.65)
        f.bar((sx + face * u * 4.0, sy + u * 0.2), (sx + face * u * 4.4, y), u * 0.3)
        f.bar((sx + face * u * 4.0, sy + u * 0.2), (sx + face * u * 3.6, y), u * 0.3)
        f.rect(sx + face * u * 0.8 - u * 0.5, sy - u * 0.3, sx + face * u * 2.0 + u * 0.5, sy + u * 0.8, r=3)
    elif weapon == "long":
        f.bar((sx - face * u * 1.0, sy + u * 0.4), (sx + face * u * 6.4, sy + u * 0.1), u * 0.42)
        f.rect(sx + face * u * 1.0, sy - u * 0.65, sx + face * u * 2.6, sy - u * 0.1, r=3)
    elif weapon == "ptrd":
        f.bar((sx - face * u * 1.0, sy + u * 0.4), (sx + face * u * 8.0, sy + u * 0.2), u * 0.5)
        f.bar((sx + face * u * 3.6, sy + u * 0.3), (sx + face * u * 4.2, y), u * 0.3)
    elif weapon == "binoc":
        f.bar((sx, sy), (hx + face * u * 0.9, hy + u * 0.1), u * 0.7)
        f.rect(hx + face * u * 0.6 - u * 0.5, hy - u * 0.4, hx + face * u * 1.6 + u * 0.3, hy + u * 0.4, r=3)
    elif weapon == "satchel":
        f.bar((sx, sy), (sx + face * u * 1.6, sy + u * 2.4), u * 0.75)
        f.rect(sx + face * u * 1.0 - u * 1.0, sy + u * 2.2, sx + face * u * 1.0 + u * 1.2, sy + u * 3.6, r=5)
    f.ground(x + face * u * (1.5 if pose == "prone" else 0.3), y + 3, u * (5 if pose == "prone" else 2.4), u * 0.55)
    return hx, hy, u


INF = {
    # (helmet, [(dx, dy, h-scale, pose, weapon, face)], extras)
    "inf_m1": ("m1", [(-0.2, 0.0, 1.0, "advance", "rifle", 1), (0.12, -0.04, 0.86, "advance", "rifle", 1), (-0.36, -0.06, 0.78, "stand", "rifle", 1)], None),
    "inf_brodie": ("brodie", [(-0.18, 0.0, 1.0, "stand", "rifle", 1), (0.14, -0.03, 0.9, "advance", "rifle", 1), (-0.38, -0.05, 0.8, "stand", "rifle", 1)], "teapot"),
    "inf_para": ("m1", [(-0.2, 0.02, 0.9, "advance", "smg", 1), (0.16, -0.02, 0.8, "kneel", "rifle", 1)], "chute"),
    "inf_para_axis": ("stahl", [(-0.16, 0.02, 0.9, "kneel", "smg", 1), (0.16, -0.02, 0.84, "stand", "rifle", 1)], "chute"),
    "inf_beret": ("beret", [(-0.2, 0.0, 1.0, "advance", "smg", 1), (0.14, -0.03, 0.88, "kneel", "rifle", 1)], "dagger"),
    "inf_medic": (None, [(0.0, 0.0, 1.0, "kneel", "satchel", 1)], "wounded"),
    "inf_observer": (None, [(-0.14, 0.0, 1.0, "kneel", "binoc", 1)], "radio"),
    "inf_tube": (None, [(-0.04, 0.0, 1.0, "kneel", "tube", 1)], None),
    "inf_stahlhelm": ("stahl", [(-0.2, 0.0, 1.0, "stand", "rifle", 1), (0.12, -0.03, 0.9, "advance", "rifle", 1), (-0.38, -0.05, 0.8, "stand", "rifle", 1)], None),
    "inf_mg": ("stahl", [(-0.26, 0.0, 1.0, "prone", "mg", 1)], "sandbags"),
    "inf_ssh": ("ssh", [(-0.22, 0.0, 1.0, "advance", "smg", 1), (0.1, -0.03, 0.88, "advance", "rifle", 1), (-0.4, -0.05, 0.8, "advance", "rifle", 1)], "snow"),
    "inf_sniper": ("hood", [(-0.3, 0.0, 1.0, "prone", "long", 1), (-0.28, -0.12, 0.9, "prone", "binoc", 1)], "snow"),
    "inf_scout": ("hood", [(-0.18, 0.0, 1.0, "advance", "smg", 1), (0.16, -0.02, 0.86, "kneel", "smg", 1)], "snow"),
    "inf_ptrd": ("ssh", [(-0.3, 0.0, 1.0, "prone", "ptrd", 1)], "snow"),
}
INF_HELMET = {"allies": "m1", "axis": "stahl", "soviet": "ssh"}


def infantry(f, faction, art):
    W, H = f.w, f.h
    helmet, men, extra = INF[art]
    helmet = helmet or INF_HELMET.get(faction, "m1")
    base = H * 0.86
    if extra == "chute":
        cx, cy = W * 0.72, H * 0.24
        f.poly([(cx - 110, cy + 20)] + [(cx + 110 * math.cos(math.radians(a)), cy + 20 - 70 * math.sin(math.radians(a))) for a in range(0, 181, 10)][::-1] + [(cx + 110, cy + 20)])
        for sd in (-1, -0.4, 0.4, 1):
            f.line([(cx + sd * 108, cy + 20), (cx, cy + 120)], 2)
        soldier(f, cx, cy + 170, H * 0.18, helmet, "stand", "rifle", 1, pack=False)
        f.shadow.pop()
    if extra == "snow":
        rnd = random.Random(art)
        for i in range(26):
            f.dot(rnd.uniform(20, W - 20), rnd.uniform(20, H * 0.6), 3, (120, 110, 100))
    if extra == "sandbags":
        for i in range(5):
            f.ell(W * 0.52 + i * 44, base - 28, 30, 18)
        for i in range(4):
            f.ell(W * 0.56 + i * 44, base - 56, 30, 18)
    if extra == "radio":
        f.rect(W * 0.62, base - 120, W * 0.74, base, r=6)
        f.bar((W * 0.72, base - 120), (W * 0.76, base - 300), 5)
        f.line([(W * 0.64, base - 90), (W * 0.72, base - 90)], 3)
        f.circ(W * 0.66, base - 50, 9, 3)
    if extra == "wounded":
        f.bar((W * 0.16, base - 10), (W * 0.46, base - 20), 30)
        f.ell(W * 0.13, base - 16, 22, 20)
    if extra == "teapot":
        f.ell(W * 0.84, base - 36, 36, 30)
        f.poly([(W * 0.84 + 30, base - 46), (W * 0.84 + 70, base - 72), (W * 0.84 + 34, base - 30)])
        f.ell(W * 0.84, base - 70, 12, 8)
    if extra == "dagger":
        f.bar((W * 0.8, base - 260), (W * 0.86, base - 60), 10)
        f.bar((W * 0.79, base - 120), (W * 0.88, base - 112), 14)
    for dx, dy, hs, pose, weapon, face in men:
        h = H * 0.62 * hs
        x = W * (0.5 + dx)
        y = base + dy * H
        if pose == "prone":
            y = base + dy * H * 0.5
        soldier(f, x, y, h, helmet, pose, weapon, face)
    # national marking on a little pennant
    if False:
        roundel(f, W * 0.1, H * 0.12, 26, faction, {"allies": "usstar" if helmet == "m1" else "raf", "axis": "cross", "soviet": "star"}[faction])


# ======================================================================= tactics
def tactic(f, art):
    W, H = f.w, f.h
    rnd = random.Random(art)
    if art == "tac_mud":
        sp = TANKS["tank_t34"]
        tank(f, "neutral", sp, base=H * 0.86)
        f.cols = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        f.cd = ImageDraw.Draw(f.cols)
        mud = Image.new("L", (W, H), 0)
        md = ImageDraw.Draw(mud)
        for i in range(18):
            x = rnd.uniform(0, W)
            md.ellipse([x - 90, H * 0.74 + rnd.uniform(-10, 20), x + 90, H * 1.02], fill=255)
        f.mask = ImageChops.lighter(f.mask, mud)
        f.md = ImageDraw.Draw(f.mask)
        for i in range(10):
            x = rnd.uniform(30, W - 60)
            y = rnd.uniform(H * 0.8, H * 0.95)
            f.line([(x, y), (x + rnd.uniform(30, 80), y + rnd.uniform(-6, 6))], 3)
        for i in range(5):
            f.dot(rnd.uniform(40, W - 40), rnd.uniform(H * 0.55, H * 0.75), 6, (90, 66, 40))
    elif art == "tac_fog":
        plane(f, "neutral", PLANES["air_bf109"], scale=0.7, mark=False)
        for i in range(5):
            y = H * (0.2 + i * 0.16)
            for k in range(6):
                x = rnd.uniform(-40, W)
                f.paint_ell(x, y, rnd.uniform(70, 140), rnd.uniform(24, 40), (176, 170, 156))
            f.line([(rnd.uniform(0, 80), y + 10), (W * rnd.uniform(0.4, 0.9), y + 14)], 2, (90, 80, 70))
        f.cols.putalpha(f.cols.getchannel("A").point(lambda v: int(v * 0.8)))
        f.rect(0, 0, 1, 1)
    elif art == "tac_frost":
        cx, cy = W / 2, H * 0.45
        for k in range(6):
            a = math.radians(k * 60)
            f.bar((cx, cy), (cx + math.cos(a) * 170, cy + math.sin(a) * 170), 16)
            for t in (0.45, 0.72):
                bx, by = cx + math.cos(a) * 170 * t, cy + math.sin(a) * 170 * t
                for sd in (-1, 1):
                    b = a + sd * math.radians(40)
                    f.bar((bx, by), (bx + math.cos(b) * 50, by + math.sin(b) * 50), 10)
        f.ell(cx, cy, 30, 30)
        for i in range(9):
            x = W * 0.08 + i * W * 0.105
            f.poly([(x - 18, H * 0.9), (x + 18, H * 0.9), (x, H * 0.9 + rnd.uniform(-90, -40))])
        f.rect(0, H * 0.9, W, H * 0.94)
    elif art == "tac_smoke":
        for i, x in enumerate((W * 0.3, W * 0.5, W * 0.7)):
            f.rect(x - 22, H * 0.74, x + 22, H * 0.86, r=6)
            f.line([(x - 22, H * 0.78), (x + 22, H * 0.78)], 2)
        for i in range(16):
            ang = rnd.uniform(0, math.pi)
            r = rnd.uniform(40, 90)
            f.ell(W * 0.5 + math.cos(ang) * rnd.uniform(0, 220), H * 0.55 - math.sin(ang) * rnd.uniform(0, 240), r, r * 0.85)
        for i in range(10):
            x, y = rnd.uniform(W * 0.2, W * 0.8), rnd.uniform(H * 0.15, H * 0.6)
            f.dd.arc([x - 40, y - 30, x + 40, y + 30], 200, 340, fill=INK + (200,), width=3)
    elif art == "tac_air":
        for (dx, dy, sc) in ((0, -0.12, 0.42), (-0.25, 0.12, 0.34), (0.25, 0.12, 0.34)):
            plane(f, "allies", PLANES["air_spitfire"], cx=W * (0.5 + dx), cy=H * (0.42 + dy), scale=sc)
        for i in range(8):
            y = H * 0.82 + i * 6
            f.line([(W * 0.1, y), (W * 0.9, y)], 1, (90, 70, 50))
    elif art == "tac_pincer":
        f.rect(W * 0.06, H * 0.08, W * 0.94, H * 0.92, r=10)
        f.cols = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        f.cd = ImageDraw.Draw(f.cols)
        f.paint_poly([(W * 0.06, H * 0.08), (W * 0.94, H * 0.08), (W * 0.94, H * 0.92), (W * 0.06, H * 0.92)], (212, 196, 152))
        for i in range(1, 8):
            f.line([(W * 0.06 + i * W * 0.11, H * 0.08), (W * 0.06 + i * W * 0.11, H * 0.92)], 1, (120, 100, 70))
            f.line([(W * 0.06, H * 0.08 + i * H * 0.105), (W * 0.94, H * 0.08 + i * H * 0.105)], 1, (120, 100, 70))
        cx, cy = W * 0.62, H * 0.5
        f.circ(cx, cy, 46, 5, col=INK)
        for sd in (-1, 1):
            p0, c1, p1 = (W * 0.14, cy + sd * 30), (W * 0.36, cy + sd * 230), (cx + 30, cy + sd * 70)
            pts = []
            for i in range(30):
                t = i / 29
                pts.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c1[0] + t * t * p1[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c1[1] + t * t * p1[1]))
            f.line(pts, 16, (126, 36, 24))
            ex, ey = pts[-1]
            px, py = pts[-4]
            a = math.atan2(ey - py, ex - px)
            f.dd.polygon([(ex + math.cos(a) * 34, ey + math.sin(a) * 34), (ex + math.cos(a + 2.3) * 30, ey + math.sin(a + 2.3) * 30),
                          (ex + math.cos(a - 2.3) * 30, ey + math.sin(a - 2.3) * 30)], fill=(126, 36, 24, 255))
    elif art in ("tac_codebreakers", "tac_enigma"):
        if art == "tac_codebreakers":
            f.rect(W * 0.12, H * 0.2, W * 0.88, H * 0.86, r=8)
            for r_ in range(3):
                for c in range(6):
                    cx, cy = W * 0.2 + c * W * 0.12, H * 0.32 + r_ * H * 0.16
                    f.paint_ell(cx, cy, 26, 26, (150, 120, 60) if (r_ + c) % 2 else (110, 90, 50))
                    f.circ(cx, cy, 26, 3)
                    f.dot(cx, cy, 5)
            f.line([(W * 0.12, H * 0.78), (W * 0.88, H * 0.78)], 3)
            for i in range(8):
                f.line([(W * 0.2 + i * 50, H * 0.8), (W * 0.24 + i * 50, H * 0.84)], 2)
        else:
            f.rect(W * 0.14, H * 0.3, W * 0.86, H * 0.88, r=10)
            for c in range(3):
                cx = W * 0.38 + c * W * 0.12
                f.paint_poly([(cx - 22, H * 0.2), (cx + 22, H * 0.2), (cx + 22, H * 0.36), (cx - 22, H * 0.36)], (184, 146, 62))
                f.rect(cx - 22, H * 0.2, cx + 22, H * 0.36)
                for k in range(4):
                    f.line([(cx - 22, H * 0.22 + k * 9), (cx + 22, H * 0.22 + k * 9)], 2)
            for r_ in range(3):
                for c in range(9 - r_):
                    cx, cy = W * 0.22 + c * W * 0.07 + r_ * 18, H * 0.5 + r_ * H * 0.1
                    f.paint_ell(cx, cy, 15, 15, (220, 210, 180))
                    f.circ(cx, cy, 15, 3)
    elif art == "tac_fortitude":
        tank(f, "neutral", TANKS["tank_sherman"], scale=0.9)
        f.cols = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        f.cd = ImageDraw.Draw(f.cols)
        # patches and a bicycle pump
        for (x, y) in ((W * 0.36, H * 0.6), (W * 0.6, H * 0.46), (W * 0.5, H * 0.68)):
            f.paint_poly([(x - 18, y - 14), (x + 18, y - 16), (x + 16, y + 14), (x - 16, y + 12)], (200, 180, 140))
            f.dd.rectangle([x - 18, y - 15, x + 18, y + 14], outline=INK + (255,), width=2)
            for k in range(4):
                f.line([(x - 18 + k * 12, y - 18), (x - 18 + k * 12, y - 10)], 1)
        f.bar((W * 0.12, H * 0.88), (W * 0.12, H * 0.62), 12)
        f.bar((W * 0.06, H * 0.62), (W * 0.18, H * 0.62), 8)
        f.line([(W * 0.12, H * 0.88), (W * 0.2, H * 0.92), (W * 0.26, H * 0.78)], 3)
    elif art == "tac_doctrine":
        f.poly([(W * 0.06, H * 0.58), (W * 0.62, H * 0.58), (W * 0.62, H * 0.42), (W * 0.95, H * 0.66), (W * 0.62, H * 0.9), (W * 0.62, H * 0.74), (W * 0.06, H * 0.74)])
        f.cols = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        f.cd = ImageDraw.Draw(f.cols)
        f.paint_poly([(0, 0), (W, 0), (W, H), (0, H)], (150, 60, 40))
        sub = Fig(W, H)
        tank(sub, "neutral", TANKS["tank_p4"], scale=0.6, base=H * 0.5, x0=W * 0.12)
        f._extra = sub
        for i in range(4):
            f.line([(W * 0.02, H * 0.3 + i * 18), (W * 0.1, H * 0.3 + i * 18)], 3)
    elif art == "tac_barrage":
        for (x, y, r) in ((W * 0.3, H * 0.6, 110), (W * 0.66, H * 0.48, 140), (W * 0.5, H * 0.78, 80)):
            f.poly(star_pts(x, y, r, r * 0.45, n=9, rot=rnd.uniform(0, 40)))
            f.paint_poly(star_pts(x, y, r * 0.55, r * 0.25, n=9), (230, 160, 70))
        for i in range(5):
            x = W * (0.15 + i * 0.18)
            f.bar((x, H * 0.08), (x + 30, H * 0.22), 14)
            f.dd.line([(x - 30, H * 0.02), (x, H * 0.08)], fill=INK + (120,), width=2)
        f.rect(0, H * 0.9, W, H * 0.95)
    elif art == "tac_convoy":
        for k, (x, y, s) in enumerate(((W * 0.28, H * 0.42, 0.6), (W * 0.62, H * 0.6, 0.85))):
            L = W * 0.6 * s
            f.poly([(x - L / 2, y), (x + L / 2 + 30, y - 6), (x + L / 2, y + 40 * s), (x - L / 2 + 20, y + 40 * s)])
            f.rect(x - L * 0.1, y - 50 * s, x + L * 0.12, y)
            f.bar((x + L * 0.02, y - 50 * s), (x + L * 0.02, y - 90 * s), 10 * s)
            for i in range(3):
                f.rect(x - L * 0.42 + i * L * 0.11, y - 26 * s, x - L * 0.34 + i * L * 0.11, y)
        for i in range(12):
            y = H * 0.72 + i * 12
            f.dd.arc([rnd.uniform(0, W - 60), y, rnd.uniform(60, W), y + 20], 200, 340, fill=INK + (160,), width=2)


# ======================================================================= dispatch
def illustration(c, w, h):
    f = Fig(w, h)
    art = c["art"]
    fac = c["faction"]
    if art in TANKS:
        tank(f, fac, TANKS[art])
        img = f.render(WASH[fac])
    elif art.startswith("car_") or art == "gun_katyusha":
        car(f, fac, art)
        img = f.render(WASH[fac])
    elif art == "gun_88":
        gun_88(f, fac)
        img = f.render(WASH[fac])
    elif art in PLANES:
        plane(f, fac, PLANES[art])
        img = f.render(WASH[fac], shade_dir="diag")
    elif art in INF:
        infantry(f, fac, art)
        img = f.render(WASH[fac])
    else:
        tactic(f, art)
        img = f.render((148, 124, 88) if art not in ("tac_frost",) else (176, 190, 196), shade_dir="diag")
        if getattr(f, "_extra", None):
            img.alpha_composite(f._extra.render((200, 180, 140)))
    return img


# ======================================================================= card face
def brass_disc(im, cx, cy, r, seed=1):
    d = ImageDraw.Draw(im)
    d.ellipse([cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6], fill=INK)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=BRASS)
    # bevel: light top-left, dark bottom-right
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    ld.arc([cx - r + 5, cy - r + 5, cx + r - 5, cy + r - 5], 150, 300, fill=BRASS_L + (230,), width=8)
    ld.arc([cx - r + 5, cy - r + 5, cx + r - 5, cy + r - 5], 330, 120, fill=BRASS_D + (230,), width=8)
    lay = lay.filter(ImageFilter.GaussianBlur(2))
    im.alpha_composite(lay)
    d.ellipse([cx - r * 0.72, cy - r * 0.72, cx + r * 0.72, cy + r * 0.72], outline=BRASS_D + (255,), width=3)
    # little rivets
    for k in range(8):
        a = math.radians(k * 45 + 22)
        d.ellipse([cx + math.cos(a) * r * 0.86 - 4, cy + math.sin(a) * r * 0.86 - 4, cx + math.cos(a) * r * 0.86 + 4, cy + math.sin(a) * r * 0.86 + 4],
                  fill=BRASS_L, outline=BRASS_D)


def icon_layer(kind, size, col=INK):
    """Small ink icon (row or ability) as an RGBA image of size x size (drawn at 2x then reduced)."""
    S = size * 2
    f = Fig(S, S)
    c = S / 2
    if kind == "inf":
        f.poly([(c - S * 0.4, c + S * 0.12), (c - S * 0.32, c - S * 0.16), (c - S * 0.12, c - S * 0.34), (c + S * 0.12, c - S * 0.34),
                (c + S * 0.32, c - S * 0.16), (c + S * 0.4, c + S * 0.12)])
        f.rect(c - S * 0.44, c + S * 0.1, c + S * 0.44, c + S * 0.18, r=4)
    elif kind == "arm":
        sub = TANKS["tank_t34"]
        tank(f, "neutral", sub, scale=0.9, base=S * 0.78)
        f.shadow = []
        f.dd = ImageDraw.Draw(Image.new("RGBA", (S, S)))
    elif kind == "air":
        plane(f, "neutral", PLANES["air_bf109"], cx=c, cy=c, scale=0.95, mark=False)
        f.shadow = []
        f.det = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    elif kind == "spotter":
        for sd in (-1, 1):
            f.rect(c + sd * S * 0.2 - S * 0.12, c - S * 0.2, c + sd * S * 0.2 + S * 0.12, c + S * 0.26, r=10)
        f.rect(c - S * 0.1, c - S * 0.08, c + S * 0.1, c + S * 0.04)
    elif kind == "artillery":
        f.poly([(c - S * 0.12, c + S * 0.36), (c - S * 0.12, c - S * 0.08), (c, c - S * 0.4), (c + S * 0.12, c - S * 0.08), (c + S * 0.12, c + S * 0.36)])
        f.rect(c - S * 0.15, c + S * 0.2, c + S * 0.15, c + S * 0.26)
    elif kind == "barrage":
        for dx in (-0.26, 0, 0.26):
            x = c + dx * S
            f.poly([(x - S * 0.07, c + S * 0.38), (x - S * 0.07, c - S * 0.02), (x, c - S * 0.3), (x + S * 0.07, c - S * 0.02), (x + S * 0.07, c + S * 0.38)])
    elif kind == "entrench":
        for r_ in range(3):
            for k in range(3 - r_):
                f.ell(c + (k - (2 - r_) / 2) * S * 0.28, c + S * 0.26 - r_ * S * 0.2, S * 0.15, S * 0.1)
    elif kind == "combined":
        f.poly([(c - S * 0.4, c - S * 0.05), (c - S * 0.05, c - S * 0.05), (c - S * 0.05, c - S * 0.2), (c + S * 0.2, c + S * 0.06), (c - S * 0.05, c + S * 0.32), (c - S * 0.05, c + S * 0.17), (c - S * 0.4, c + S * 0.17)])
        f.poly([(c + S * 0.4, c - S * 0.12), (c + S * 0.12, c - S * 0.12), (c + S * 0.12, c - S * 0.26), (c - S * 0.06, c - S * 0.36 + S * 0.14), (c + S * 0.12, c - S * 0.04 + S * 0.04), (c + S * 0.12, c - S * 0.0), (c + S * 0.4, c - S * 0.0)])
    elif kind == "supply":
        f.rect(c - S * 0.36, c - S * 0.26, c + S * 0.36, c + S * 0.3, r=4)
        f.line([(c - S * 0.36, c - S * 0.26), (c + S * 0.36, c + S * 0.3)], 5)
        f.line([(c - S * 0.36, c + S * 0.3), (c + S * 0.36, c - S * 0.26)], 5)
    elif kind == "reinforce":
        for k in range(3):
            y = c - S * 0.3 + k * S * 0.22
            f.poly([(c - S * 0.36, y + S * 0.16), (c, y - S * 0.02), (c + S * 0.36, y + S * 0.16), (c + S * 0.36, y + S * 0.26), (c, y + S * 0.08), (c - S * 0.36, y + S * 0.26)])
    elif kind == "medic":
        f.ell(c, c, S * 0.32, S * 0.32)
        f.det.paste((0, 0, 0, 0), [0, 0, S, S])
        f.circ(c, c, S * 0.14, 6, col=(230, 220, 200))
        f.line([(c + S * 0.14, c), (c + S * 0.4, c + S * 0.3)], 8)
    elif kind == "assault":
        f.bar((c - S * 0.32, c + S * 0.32), (c + S * 0.28, c - S * 0.28), S * 0.09)
        f.poly([(c + S * 0.24, c - S * 0.24), (c + S * 0.42, c - S * 0.42), (c + S * 0.3, c - S * 0.18)])
        f.bar((c - S * 0.2, c + S * 0.06), (c - S * 0.04, c + S * 0.22), S * 0.06)
    elif kind == "rally":
        f.bar((c - S * 0.3, c + S * 0.38), (c - S * 0.3, c - S * 0.38), S * 0.06)
        f.poly([(c - S * 0.28, c - S * 0.38), (c + S * 0.38, c - S * 0.26), (c - S * 0.28, c - S * 0.04)])
    elif kind == "elite":
        f.poly(star_pts(c, c, S * 0.4, S * 0.17))
    elif kind == "tactic":
        f.poly(star_pts(c, c, S * 0.42, S * 0.08, n=4, rot=-90))
        f.poly(star_pts(c, c, S * 0.26, S * 0.06, n=4, rot=-45))
    img = f.render((206, 190, 150) if kind in ("inf", "arm", "air") else (190, 170, 130), outline=5)
    return img.resize((size, size), Image.LANCZOS)


def wrap(d, text, fnt, maxw):
    words = text.split()
    lines, cur = [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=fnt) <= maxw:
            cur = t
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def card_face(c):
    W, H = CW * SS, CH * SS
    fac = c["faction"]
    fc = FACTION[fac]
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # outer frame
    d.rounded_rectangle([0, 0, W - 1, H - 1], 36, fill=INK)
    d.rounded_rectangle([6, 6, W - 7, H - 7], 32, fill=fc)
    frame_tex = Image.fromarray((noise(W, H, 40, hash(c["id"]) % 999, 2) * 60).astype(np.uint8))
    shade = Image.new("RGBA", (W, H), (20, 14, 8, 255))
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle([6, 6, W - 7, H - 7], 32, fill=255)
    shade.putalpha(ImageChops.multiply(frame_tex, m))
    im.alpha_composite(shade)
    # inner parchment
    inner = parchment(W - 56, H - 56, seed=abs(hash(c["id"])) % 1000, base=PARCH_L, burn=0.35)
    pm = Image.new("L", inner.size, 0)
    ImageDraw.Draw(pm).rounded_rectangle([0, 0, inner.size[0] - 1, inner.size[1] - 1], 22, fill=255)
    d.rounded_rectangle([24, 24, W - 25, H - 25], 24, fill=INK)
    im.paste(inner, (28, 28), pm)
    # illustration window
    ix0, iy0, ix1, iy1 = 52, 176, W - 52, 676
    win = parchment(ix1 - ix0, iy1 - iy0, seed=abs(hash(c["id"] + "w")) % 1000, base=(214, 196, 156), burn=0.9)
    im.paste(win, (ix0, iy0))
    art = illustration(c, ix1 - ix0, iy1 - iy0)
    im.alpha_composite(art, (ix0, iy0))
    d.rectangle([ix0 - 2, iy0 - 2, ix1 + 2, iy1 + 2], outline=INK, width=5)
    d.rectangle([ix0 + 8, iy0 + 8, ix1 - 8, iy1 - 8], outline=INK + (90,), width=2)
    # brass seal (strength) and row medallion
    brass_disc(im, 110, 110, 74)
    if c["type"] == "tactic":
        ic = icon_layer("tactic", 100)
        im.alpha_composite(ic, (60, 60))
    rx, ry = W - 110, 110
    d.ellipse([rx - 66, ry - 66, rx + 66, ry + 66], fill=INK)
    d.ellipse([rx - 60, ry - 60, rx + 60, ry + 60], fill=fc)
    d.ellipse([rx - 52, ry - 52, rx + 52, ry + 52], fill=PARCH_L)
    if c["type"] == "unit":
        ic = icon_layer(c["row"], 92)
        im.alpha_composite(ic, (rx - 46, ry - 46))
    else:
        tgt = c.get("row_target", "")
        ic = icon_layer(tgt if tgt else "tactic", 88)
        im.alpha_composite(ic, (rx - 44, ry - 44))
    # faction ribbon under the seal: title line
    fsc = font(F_SC, 34)
    sub = {"unit": {"inf": "Infantry", "arm": "Armour", "air": "Air"}.get(c["row"], ""), "tactic": "Tactic"}[c["type"]]
    sub += " · " + c["rarity"].capitalize()
    tw = d.textlength(sub, font=fsc)
    d.text(((W - tw) / 2, 130), sub, font=fsc, fill=INK)
    d.text(((W - tw) / 2, 130 - 52), DATA["factions"][fac]["name"], font=font(F_IT, 30), fill=INK + (200,)) if False else None
    # name banner
    by0, by1 = 694, 790
    ribbon = [(30, by0 + 14), (W - 30, by0 + 14), (W - 54, (by0 + by1) / 2 + 7), (W - 30, by1), (30, by1), (54, (by0 + by1) / 2 + 7)]
    d.polygon([(x, y + 6) for x, y in ribbon], fill=(20, 12, 6, 160))
    d.polygon(ribbon, fill=INK)
    inset = [(38, by0 + 20), (W - 38, by0 + 20), (W - 60, (by0 + by1) / 2 + 7), (W - 38, by1 - 6), (38, by1 - 6), (60, (by0 + by1) / 2 + 7)]
    d.polygon(inset, fill=fc)
    d.rectangle([84, by0, W - 84, by1 - 10], fill=INK)
    d.rectangle([90, by0 + 6, W - 90, by1 - 16], fill=PARCH_L)
    name = c["name"]
    size = 54
    while size > 26:
        fn = font(F_SC, size)
        if d.textlength(name, font=fn) <= W - 200:
            break
        size -= 2
    fn = font(F_SC, size)
    tw = d.textlength(name, font=fn)
    bb = d.textbbox((0, 0), name, font=fn)
    d.text(((W - tw) / 2, (by0 + by1 - 10) / 2 - (bb[3] + bb[1]) / 2), name, font=fn, fill=INK)
    # ability icons
    abil = [a["k"] for a in c.get("abilities", [])]
    if c["type"] == "tactic":
        abil = []
    ay = 846
    n = len(abil)
    for i, k in enumerate(abil):
        ax = W / 2 + (i - (n - 1) / 2) * 104
        d.ellipse([ax - 42, ay - 42, ax + 42, ay + 42], fill=INK)
        d.ellipse([ax - 37, ay - 37, ax + 37, ay + 37], fill=BRASS)
        d.ellipse([ax - 31, ay - 31, ax + 31, ay + 31], fill=PARCH_L)
        im.alpha_composite(icon_layer(k, 54), (int(ax - 27), int(ay - 27)))
        num = next((a.get("n", 0) for a in c["abilities"] if a["k"] == k), 0)
        if num:
            d.ellipse([ax + 18, ay + 10, ax + 50, ay + 42], fill=RUB, outline=INK, width=3)
            fnum = font(F_BOLD, 26)
            t = str(num)
            d.text((ax + 34 - d.textlength(t, font=fnum) / 2, ay + 10), t, font=fnum, fill=PARCH_L)
    # flavour
    fi = font(F_IT, 27)
    fy0 = 900 if abil else 818
    lines = wrap(d, c["flavor"], fi, W - 140)[: (3 if abil else 5)]
    for i, ln in enumerate(lines):
        tw = d.textlength(ln, font=fi)
        d.text(((W - tw) / 2, fy0 + i * 31), ln, font=fi, fill=(60, 40, 24))
    # rarity jewel
    rc = RARITY[c["rarity"]]
    jx, jy = W / 2, H - 30
    d.polygon([(jx, jy - 20), (jx + 20, jy), (jx, jy + 20), (jx - 20, jy)], fill=INK)
    d.polygon([(jx, jy - 13), (jx + 13, jy), (jx, jy + 13), (jx - 13, jy)], fill=rc)
    if c.get("special"):
        for sd in (-1, 1):
            d.ellipse([jx + sd * 40 - 7, jy - 7, jx + sd * 40 + 7, jy + 7], fill=rc, outline=INK, width=3)
    return im.resize((CW, CH), Image.LANCZOS)


def card_back():
    W, H = CW * SS, CH * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, W - 1, H - 1], 36, fill=INK)
    felt = felt_tex(W - 12, H - 12, 7, (54, 70, 46))
    m = Image.new("L", felt.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, felt.size[0] - 1, felt.size[1] - 1], 32, fill=255)
    im.paste(felt, (6, 6), m)
    d.rounded_rectangle([30, 30, W - 31, H - 31], 22, outline=BRASS, width=8)
    d.rounded_rectangle([46, 46, W - 47, H - 47], 16, outline=BRASS_D, width=3)
    cx, cy = W / 2, H / 2 - 30
    for k in range(16):
        a = math.radians(k * 22.5)
        r = 230 if k % 2 == 0 else 150
        d.line([(cx, cy), (cx + math.cos(a) * r, cy + math.sin(a) * r)], fill=BRASS_D, width=3)
    d.ellipse([cx - 150, cy - 150, cx + 150, cy + 150], outline=BRASS, width=6)
    # M1 helmet emblem
    f = Fig(300, 300)
    f.poly([(30, 190), (52, 110), (110, 62), (190, 62), (248, 110), (270, 190)])
    f.rect(16, 182, 284, 204, r=8)
    f.line([(90, 120), (210, 120)], 3)
    hel = f.render((92, 104, 64))
    im.alpha_composite(hel, (int(cx - 150), int(cy - 170)))
    for k in range(4):
        a = math.radians(45 + k * 90)
        x, y = cx + math.cos(a) * 190, cy + math.sin(a) * 190
        d.polygon(star_pts(x, y, 22, 9), fill=BRASS)
    fg = font(F_GOTH, 92)
    t = "Ironfront"
    tw = d.textlength(t, font=fg)
    d.text(((W - tw) / 2 + 3, H - 260 + 3), t, font=fg, fill=(10, 8, 4))
    d.text(((W - tw) / 2, H - 260), t, font=fg, fill=BRASS_L)
    return im.resize((CW, CH), Image.LANCZOS)


def felt_tex(w, h, seed, base):
    n = noise(w, h, 6, seed, 2)
    n2 = noise(w, h, 120, seed + 3, 3)
    arr = np.zeros((h, w, 3), np.float32)
    for i in range(3):
        arr[..., i] = base[i] * (0.8 + 0.25 * n + 0.3 * n2)
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")


def board():
    W, H = 1920, 1080
    im = Image.new("RGBA", (W, H), (30, 20, 12, 255))
    # dark oak rim
    wood = noise(W, H, 300, 4, 3)
    grain = noise(W, H, 8, 5, 1)
    arr = np.zeros((H, W, 3), np.float32)
    for i, b in enumerate((58, 36, 22)):
        arr[..., i] = b * (0.7 + 0.5 * wood + 0.25 * grain)
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(im)
    # felt
    fx0, fy0, fx1, fy1 = 40, 40, W - 40, H - 40
    felt = felt_tex(fx1 - fx0, fy1 - fy0, 11, (46, 66, 44))
    im.paste(felt, (fx0, fy0))
    # map overlay: faint contour lines, grid, a river and coast
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    for x in range(fx0, fx1, 120):
        od.line([(x, fy0), (x, fy1)], fill=(200, 210, 170, 22), width=2)
    for y in range(fy0, fy1, 120):
        od.line([(fx0, y), (fx1, y)], fill=(200, 210, 170, 22), width=2)
    rnd = random.Random(3)
    for k in range(9):
        cx, cy = rnd.uniform(200, W - 200), rnd.uniform(160, H - 160)
        for r in range(40, 260, 34):
            pts = []
            for a in range(0, 361, 8):
                rr = r * (1 + 0.18 * math.sin(math.radians(a * 3 + k * 40)) + 0.08 * math.sin(math.radians(a * 7)))
                pts.append((cx + math.cos(math.radians(a)) * rr * 1.3, cy + math.sin(math.radians(a)) * rr))
            od.line(pts, fill=(220, 220, 180, 16), width=2)
    river = [(fx0, 300)]
    x, y = fx0, 300
    while x < fx1:
        x += 40
        y += rnd.uniform(-30, 34)
        river.append((x, y))
    od.line(river, fill=(150, 180, 190, 30), width=10)
    im.alpha_composite(ov)
    # brass rail and corner fittings
    d.rectangle([fx0 - 6, fy0 - 6, fx1 + 6, fy1 + 6], outline=(16, 10, 6), width=8)
    d.rectangle([fx0 - 2, fy0 - 2, fx1 + 2, fy1 + 2], outline=BRASS, width=4)
    for (x, y) in ((fx0, fy0), (fx1, fy0), (fx0, fy1), (fx1, fy1)):
        d.ellipse([x - 20, y - 20, x + 20, y + 20], fill=BRASS, outline=(16, 10, 6), width=4)
        d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=BRASS_D)
    # lamplight: warm pool in the middle, dark corners
    yy, xx = np.mgrid[0:H, 0:W]
    r = np.sqrt(((xx - W * 0.5) / (W * 0.62)) ** 2 + ((yy - H * 0.46) / (H * 0.7)) ** 2)
    light = np.clip(1.0 - r, 0, 1) ** 1.6
    dark = np.clip(r - 0.35, 0, 1) * 1.15
    lay = np.zeros((H, W, 4), np.float32)
    lay[..., 0], lay[..., 1], lay[..., 2] = 255, 190, 110
    lay[..., 3] = light * 60
    im.alpha_composite(Image.fromarray(lay.astype(np.uint8)))
    lay2 = np.zeros((H, W, 4), np.float32)
    lay2[..., 0], lay2[..., 1], lay2[..., 2] = 8, 5, 3
    lay2[..., 3] = np.clip(dark * 255, 0, 210)
    im.alpha_composite(Image.fromarray(lay2.astype(np.uint8)))
    return im.convert("RGB")


def helmet():
    """M1 helmet seen from the front, sized for a 256 portrait whose crown sits near (128, 58)."""
    S = 512
    f = Fig(S, S)
    cx = S / 2
    top, rim = 54, 196
    f.poly([(cx - 172, rim), (cx - 160, rim - 70), (cx - 120, top + 40), (cx - 60, top + 6), (cx, top), (cx + 60, top + 6), (cx + 120, top + 40), (cx + 160, rim - 70), (cx + 172, rim)])
    f.poly([(cx - 196, rim - 4), (cx + 196, rim - 4), (cx + 190, rim + 22), (cx, rim + 34), (cx - 190, rim + 22)])
    # netting / scrim
    for k in range(-5, 6):
        f.dd.line([(cx + k * 30 - 40, top + 20), (cx + k * 30 + 40, rim)], fill=(30, 40, 20, 110), width=2)
        f.dd.line([(cx + k * 30 + 40, top + 20), (cx + k * 30 - 40, rim)], fill=(30, 40, 20, 110), width=2)
    f.dd.line([(cx - 168, rim - 10), (cx + 168, rim - 10)], fill=INK + (255,), width=3)
    # chin strap hanging down at the sides
    for sd in (-1, 1):
        f.dd.line([(cx + sd * 160, rim + 18), (cx + sd * 150, rim + 150)], fill=(70, 60, 36, 255), width=12)
        f.dd.line([(cx + sd * 160, rim + 18), (cx + sd * 150, rim + 150)], fill=INK + (255,), width=3)
    img = f.render((86, 104, 56), outline=9)
    return img.resize((256, 256), Image.LANCZOS)


def gem(on):
    S = 128
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([6, 6, S - 6, S - 6], fill=INK)
    d.ellipse([14, 14, S - 14, S - 14], fill=BRASS)
    d.ellipse([22, 22, S - 22, S - 22], fill=BRASS_D)
    col = (196, 44, 30) if on else (54, 36, 30)
    d.ellipse([28, 28, S - 28, S - 28], fill=col)
    if on:
        lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ld = ImageDraw.Draw(lay)
        ld.ellipse([40, 36, 66, 58], fill=(255, 210, 180, 200))
        lay = lay.filter(ImageFilter.GaussianBlur(3))
        im.alpha_composite(lay)
    return im.resize((64, 64), Image.LANCZOS)


# ======================================================================= main
def only():
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            return set(a.split("=", 1)[1].split(","))
    return None


def save(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(tpath(path))


def contact(cards):
    cols = 11
    tw, th = 180, 260
    rows = (len(cards) + 1 + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (tw + 10) + 10, rows * (th + 10) + 10 + 300), (44, 32, 22))
    for i, c in enumerate(cards + [{"id": "_back"}]):
        p = tpath(os.path.join(OUT_IF, "back.png")) if c["id"] == "_back" else tpath(os.path.join(OUT_CARDS, c["id"] + ".png"))
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA").resize((tw, th), Image.LANCZOS)
        x, y = 10 + (i % cols) * (tw + 10), 10 + (i // cols) * (th + 10)
        sheet.paste(im, (x, y), im)
    y0 = 10 + rows * (th + 10)
    x = 10
    for n in ["row_inf", "row_arm", "row_air", "ab_spotter", "ab_artillery", "ab_barrage", "ab_entrench", "ab_combined", "ab_supply",
              "ab_reinforce", "ab_medic", "ab_assault", "ab_rally", "ab_elite", "gem_on", "gem_off", "helmet"]:
        p = tpath(os.path.join(OUT_IF, n + ".png"))
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA")
            im.thumbnail((110, 110))
            bg = Image.new("RGBA", (116, 116), PARCH + (255,))
            bg.alpha_composite(im, ((116 - im.size[0]) // 2, (116 - im.size[1]) // 2))
            sheet.paste(bg, (x, y0))
            x += 122
    bp = tpath(os.path.join(OUT_IF, "board.png"))
    if os.path.exists(bp):
        b = Image.open(bp).resize((300, 168))
        sheet.paste(b, (x + 10, y0))
    os.makedirs(OUT_REV, exist_ok=True)
    sheet.save(os.path.join(OUT_REV, "ironfront_contact.png"))


def main():
    sel = only()
    cards = DATA["cards"]
    for c in cards:
        if sel and c["id"] not in sel:
            continue
        save(card_face(c), os.path.join(OUT_CARDS, c["id"] + ".png"))
    misc = {
        "back": card_back,
        "board": board,
        "helmet": helmet,
        "gem_on": lambda: gem(True),
        "gem_off": lambda: gem(False),
    }
    for k in ("inf", "arm", "air"):
        misc["row_" + k] = (lambda k=k: icon_layer(k, 128))
    for k in ("spotter", "artillery", "barrage", "entrench", "combined", "supply", "reinforce", "medic", "assault", "rally", "elite", "tactic"):
        misc["ab_" + k] = (lambda k=k: icon_layer(k, 128))
    for name, fn in misc.items():
        if sel and name not in sel:
            continue
        save(fn(), os.path.join(OUT_IF, name + ".png"))
    contact(cards)
    print("ironfront art done")


if __name__ == "__main__":
    main()
