"""Tabletop-miniature figure painter for "Ember & Ash" (Ink & Parchment / Gothic Noir 80:20).

Characters are drawn as small painted fantasy miniatures standing on round bases, seen three-quarter
from slightly above-front, in the same inked / hatched illustration style as the props and stations.
Unlike person.py (straight top-down, rotated per direction) the figures never rotate: each direction
is its own pose.

Design space: one 256x256 cell (rendered at 0.5 into a 128 px sheet cell).  The figure's feet stand
on FEET = (128, 192), the centre of the base's top face.  Views:
    "S"  front (facing the viewer)      "E"  side, facing right      "N"  back
West is drawn by the caller as the mirrored east view with a mirrored painter (see `painter(mirror)`),
so light stays top-left on screen.

Public API
    painter(pal, mirror=False) -> Painter
    figure(P, look, view, fr)  -> svg (design units)          fr = frame dict (see FRAMES)
    animal(P, spec, view, fr)  -> svg
    base(P, kind, rx, ry, rim, seed) -> svg (fixed, identical in every frame)
"""
import math
import random

import artlib  # noqa: F401  (sets sys.path for the exploration generator)
from artlib import ST, INK, EMBER, EMBER_HOT, GILT, glow, blur_filter, hatch, lin, fill
from svgcore import Painter, ell, rect, poly, smooth, blob, wobbly_ell  # noqa: F401
import person
from person import tri, mix

CX, FY = 128.0, 192.0          # feet / base-top centre in design units
SHADE = 1.35                   # crescent-shadow / hatch width multiplier
ANIMAL_K = 1.5                 # animals are drawn at this scale about the feet point

# walk cycle: phase angle per column; idle columns breathe
FRAMES = [
    dict(walk=False, ph=0.0, breathe=0.0),
    dict(walk=False, ph=0.0, breathe=1.0),
    dict(walk=True, ph=0.0, breathe=0.3),
    dict(walk=True, ph=0.5 * math.pi, breathe=0.6),
    dict(walk=True, ph=math.pi, breathe=0.3),
    dict(walk=True, ph=1.5 * math.pi, breathe=0.6),
]


def J(o):
    return "\n".join(x for x in o if x)


# ------------------------------------------------------------------ painter
def painter(pal, mirror=False, lw_mul=0.72):
    st = dict(ST)
    st["pal"] = pal
    P = Painter(st, scale=1.0)
    P.lw_mul = lw_mul
    if mirror:
        # drawn inside scale(-1,1): mirror the light and the hatch angles so they read correctly on screen
        P.light = (1.0, -1.0)
        sp, hw = 5.0, 1.1
        P.defs[0] = (f'<pattern id="{P.hatch_id}" width="{sp}" height="{sp}" patternUnits="userSpaceOnUse" '
                     f'patternTransform="rotate(35)"><line x1="0" y1="0" x2="0" y2="{sp}" stroke="{INK}" '
                     f'stroke-width="{hw}"/></pattern>')
        P.defs[1] = (f'<pattern id="{P.xhatch_id}" width="{sp}" height="{sp}" patternUnits="userSpaceOnUse" '
                     f'patternTransform="rotate(-35)"><line x1="0" y1="0" x2="0" y2="{sp}" stroke="{INK}" '
                     f'stroke-width="{hw*0.9:.2f}"/></pattern>')
    return P


def palette(look):
    pal = person.make_palette(ST["pal"], look)
    shirt = look.get("shirt") or "#6a5a40"
    pal["trouser"] = tri(mix(shirt, "#3e3022", 0.6), 0.06)
    pal["skirt"] = tri(mix(shirt, "#2a2018", 0.12), 0.08)
    pal["sleeve"] = pal["shirt"]
    pal["eye"] = ("#3a2a1e", "#20140c", "#100a06")
    return pal


# ------------------------------------------------------------------ geometry helpers
def capsule(p1, p2, r1, r2=None):
    r2 = r1 if r2 is None else r2
    (x1, y1), (x2, y2) = p1, p2
    L = math.hypot(x2 - x1, y2 - y1) or 1e-3
    dx, dy = (x2 - x1) / L, (y2 - y1) / L
    nx, ny = -dy, dx
    pts = [(x1 + nx * r1, y1 + ny * r1), (x2 + nx * r2, y2 + ny * r2), (x2 + dx * r2 * 0.95, y2 + dy * r2 * 0.95),
           (x2 - nx * r2, y2 - ny * r2), (x1 - nx * r1, y1 - ny * r1), (x1 - dx * r1 * 0.95, y1 - dy * r1 * 0.95)]
    return smooth(pts, t=0.55)


def frame_xf(ox, oy, ang):
    """Local (u along the shaft, v across) -> screen, shaft direction `ang` in degrees (0 = right, -90 = up)."""
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)

    def f(u, v=0.0):
        return (ox + ca * u - sa * v, oy + sa * u + ca * v)
    return f


def lpoly(f, pts):
    return poly([f(u, v) for u, v in pts])


def lsmooth(f, pts, t=0.5):
    return smooth([f(u, v) for u, v in pts], t=t)


def lell(f, u, v, ru, rv, n=14):
    return smooth([f(u + math.cos(i / n * math.tau) * ru, v + math.sin(i / n * math.tau) * rv) for i in range(n)], t=0.5)


def lline(f, *pts):
    q = [f(u, v) for u, v in pts]
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in q)


# ------------------------------------------------------------------ builds
# H height (feet to crown); hrx/hry head radii; sh shoulder half-width; ch chest; wa waist; hip hips;
# lw leg half-width; ls leg spacing; ar arm radius; hd hand radius; ll leg length fraction; dp side depth factor
BUILDS = {
    "average":  dict(H=166, hrx=14.0, hry=16.0, sh=25, ch=22, wa=18, hip=19, lw=8.0, ls=8.5, ar=6.8, hd=5.6, ll=0.45),
    "slim":     dict(H=164, hrx=13.2, hry=15.4, sh=21, ch=18, wa=15, hip=16, lw=7.0, ls=7.5, ar=5.8, hd=5.0, ll=0.46),
    "heavy":    dict(H=164, hrx=15.4, hry=17.0, sh=35, ch=32, wa=33, hip=29, lw=11.5, ls=12.5, ar=9.8, hd=7.4, ll=0.40),
    "dwarf":    dict(H=130, hrx=15.4, hry=16.4, sh=31, ch=29, wa=29, hip=27, lw=10.5, ls=11.5, ar=9.0, hd=7.0, ll=0.30),
    "halfling": dict(H=114, hrx=14.0, hry=15.0, sh=19, ch=17, wa=17, hip=17, lw=6.8, ls=7.5, ar=5.8, hd=5.0, ll=0.34),
    "orc":      dict(H=168, hrx=15.4, hry=16.6, sh=35, ch=31, wa=25, hip=24, lw=10.5, ls=11.5, ar=9.6, hd=7.4, ll=0.44),
}


def build_of(look):
    b = dict(BUILDS[look.get("build", "average")])
    if look.get("female"):
        b.update(sh=b["sh"] * 0.86, ch=b["ch"] * 0.9, wa=b["wa"] * 0.88, hip=b["hip"] * 1.08, hrx=b["hrx"] * 0.95,
                 ar=b["ar"] * 0.86, hd=b["hd"] * 0.9, lw=b["lw"] * 0.92, H=b["H"] * (0.97 if b["H"] > 150 else 1.0))
    return b


# ------------------------------------------------------------------ figure
class Fig:
    def __init__(self, P, look, view, fr):
        self.P, self.look, self.view, self.fr = P, look, view, fr
        self.B = B = build_of(look)
        self.o = []
        ph = fr["ph"]
        walk = fr["walk"]
        self.step = math.cos(ph) if walk else 0.0          # +1: right(viewer-left in S) leg forward
        self.lift = math.sin(ph) if walk else 0.0          # >0: viewer-left leg lifted
        self.bob = -2.6 * abs(math.sin(ph)) if walk else 0.0
        br = fr["breathe"]
        self.br = br
        H = B["H"]
        top = FY - H + self.bob
        self.top = top
        self.hcy = top + B["hry"] - br * 0.8
        self.S = top + 2 * B["hry"] + 5 - br * 0.9                 # shoulder line
        self.Hp = FY - B["ll"] * H + self.bob * 0.6               # crotch line
        self.W = self.S + (self.Hp - self.S) * 0.62                # waist
        self.armor = look.get("armor", "none")
        self.ex = look.get("extras", []) or []
        self.fem = bool(look.get("female"))
        self.hand = look.get("hand", "none")
        self.back = look.get("back", "none")
        self.cid = look.get("_id", "")
        self.skirt = self.fem and self.armor in ("none", "apron", "robe")
        self.robe = self.armor == "robe"
        self.shield_arm = self.back == "shield"
        self.lute_front = self.back == "lute"
        if self.lute_front:
            self.hand = "none"          # the bard plays the lute; the dagger stays sheathed
        self.walk = walk

    # -- shorthands
    def add(self, *s):
        self.o.extend(s)

    def sh(self, d, role, s=3, **k):
        self.o.append(self.P.shape(d, role, s=s * SHADE, **k))

    def det(self, d, role=None, w=1.0, op=1.0):
        self.o.append(self.P.detail(d, role, w, op))

    # ============================================================ shared pieces
    def legs_front(self, back=False):
        B, P = self.B, self.P
        hide = self.robe or self.skirt
        for side in (-1, 1):
            x = CX + side * B["ls"]
            lifted = max(0.0, (self.lift if side == -1 else -self.lift))   # viewer-left leg lifts when lift > 0
            if back:
                lifted = max(0.0, (self.lift if side == 1 else -self.lift))
            fy = FY - lifted * 5.5 + (self.bob * 0.15)
            if not hide:
                role = "metal" if self.armor == "plate" else "trouser"
                self.sh(capsule((x, self.Hp - 6), (x + side * 0.6, fy - 10), B["lw"], B["lw"] * 0.86), "trouser", s=3)
                if self.armor == "plate":
                    self.sh(capsule((x + side * 0.4, self.Hp + (fy - self.Hp) * 0.42), (x + side * 0.6, fy - 11), B["lw"] * 0.95, B["lw"] * 0.92), role, s=2.5)
                    self.sh(ell(x + side * 0.4, self.Hp + (fy - self.Hp) * 0.45, B["lw"] * 0.8, B["lw"] * 0.6), "metal", s=1.5)
            self.boot_front(x, fy, side, back)

    def boot_front(self, x, fy, side, back=False):
        B = self.B
        w = B["lw"] * 1.02
        bare = self.look.get("build") == "halfling"
        role = "skin" if bare else "boot"
        if back:
            d = smooth([(x - w, fy - 16), (x + w, fy - 16), (x + w * 1.05, fy - 3), (x + w * 0.7, fy + 1),
                        (x - w * 0.7, fy + 1), (x - w * 1.05, fy - 3)], t=0.5)
            if not bare:
                self.sh(d, role, s=2.2)
            else:
                self.sh(ell(x, fy - 2, w, 4), role, s=1.5)
            return
        if not bare:
            self.sh(smooth([(x - w, fy - 16), (x + w, fy - 16), (x + w * 1.05, fy - 5), (x + w * 0.95, fy),
                            (x - w * 0.95, fy), (x - w * 1.05, fy - 5)], t=0.5), role, s=2.2)
            self.det(f"M{x-w*0.9:.1f},{fy-12:.1f} Q{x:.1f},{fy-10:.1f} {x+w*0.9:.1f},{fy-12:.1f}", "boot", 0.8, 0.8)
        # toe cap seen from above-front
        self.sh(ell(x + side * 0.8, fy + 0.5, w * 0.92, 4.2), role, s=1.4)
        if bare:
            self.det(f"M{x-w*0.5:.1f},{fy+1:.1f} l0,2 M{x:.1f},{fy+1.5:.1f} l0,2 M{x+w*0.5:.1f},{fy+1:.1f} l0,2", "skin", 0.5, 0.7)

    def torso_pts(self, sh, ch, wa, hip, S, W, Hp):
        return [(CX - 6, S - 4), (CX - sh * 0.62, S - 1), (CX - sh, S + 6), (CX - ch, S + (W - S) * 0.45),
                (CX - wa, W), (CX - hip, Hp + 3), (CX, Hp + 6), (CX + hip, Hp + 3), (CX + wa, W),
                (CX + ch, S + (W - S) * 0.45), (CX + sh, S + 6), (CX + sh * 0.62, S - 1), (CX + 6, S - 4)]

    # ============================================================ front view
    def front(self):
        B, P, L = self.B, self.P, self.look
        S, W, Hp = self.S, self.W, self.Hp
        brw = self.br * 0.6
        sh_, ch, wa, hip = B["sh"] + brw * 0.4, B["ch"] + brw, B["wa"], B["hip"]
        # --- behind the body: cloak, back items, long hair
        if L.get("cloak") and not self.hood_down_only():
            cl = smooth([(CX - sh_ * 0.8, S), (CX - sh_ * 1.15, S + 18), (CX - sh_ * 1.25, FY - 22),
                         (CX - sh_ * 0.6, FY - 14), (CX + sh_ * 0.6, FY - 14), (CX + sh_ * 1.25, FY - 22),
                         (CX + sh_ * 1.15, S + 18), (CX + sh_ * 0.8, S)], t=0.45)
            self.sh(cl, "cloak", s=4)
        self.back_items_front()
        self.hair_behind("S")
        # --- legs / skirt
        self.legs_front()
        if self.robe or self.skirt:
            self.skirt_front(hip)
        # --- torso
        tp = self.torso_pts(sh_, ch, wa, hip, S, W, Hp)
        top_role = "shirt"
        if self.robe:
            top_role = "shirt"
        self.sh(smooth(tp, t=0.42), top_role, s=4)
        self.armor_front(sh_, ch, wa, hip)
        # --- arms + held items
        self.arms_front(sh_)
        # --- head
        self.head_front()
        if "pauldron" in self.ex:
            px, py = CX + sh_ * 0.82, S + 3
            self.sh(smooth([(px - 12, py + 2), (px - 6, py - 7), (px + 6, py - 8), (px + 14, py - 1), (px + 15, py + 9),
                            (px + 4, py + 10), (px - 8, py + 8)]), "metal", s=3)
            self.det(f"M{px-6},{py-1} Q{px+4},{py-5} {px+12},{py+2} M{px-5},{py+4} Q{px+4},{py} {px+12},{py+6}", "metal", 0.6, 0.8)
        if self.shield_arm:
            self.shield_front(CX + sh_ + 3, W - 2)
        if self.lute_front:
            self.lute(CX + 4, W + 2, -52, front=True)

    def hood_down_only(self):
        return False

    def skirt_front(self, hip):
        B = self.B
        W = self.W
        hem = FY - (3 if self.robe else 10)
        wb = hip * (1.55 if self.robe else 1.45)
        sway = self.step * 2.0
        role = "shirt" if self.robe else "skirt"
        pts = [(CX - B["wa"] * 1.02, W - 2), (CX - hip * 1.15, W + 14), (CX - wb + sway, hem - 3),
               (CX - wb * 0.5 + sway, hem + 1), (CX + sway, hem - 1), (CX + wb * 0.5 + sway, hem + 1),
               (CX + wb + sway, hem - 3), (CX + hip * 1.15, W + 14), (CX + B["wa"] * 1.02, W - 2)]
        self.sh(smooth(pts, t=0.4), role, s=4)
        self.det(f"M{CX-wb*0.45+sway:.1f},{W+18:.1f} Q{CX-wb*0.55+sway:.1f},{hem-8:.1f} {CX-wb*0.5+sway:.1f},{hem-1:.1f} "
                 f"M{CX+wb*0.4+sway:.1f},{W+20:.1f} Q{CX+wb*0.5+sway:.1f},{hem-10:.1f} {CX+wb*0.48+sway:.1f},{hem-1:.1f} "
                 f"M{CX+sway*0.5:.1f},{W+26:.1f} L{CX+sway:.1f},{hem-4:.1f}", role, 0.7, 0.75)

    def armor_front(self, sh_, ch, wa, hip):
        B, P = self.B, self.P
        S, W, Hp = self.S, self.W, self.Hp
        a = self.armor
        if a == "leather":
            j = smooth([(CX - 5, S + 1), (CX - sh_ * 0.75, S + 3), (CX - ch * 0.98, S + (W - S) * 0.45), (CX - wa * 1.02, W + 1),
                        (CX - hip * 1.02, Hp + 2), (CX + hip * 1.02, Hp + 2), (CX + wa * 1.02, W + 1),
                        (CX + ch * 0.98, S + (W - S) * 0.45), (CX + sh_ * 0.75, S + 3), (CX + 5, S + 1), (CX, S + 12)], t=0.4)
            self.sh(j, "leather", s=3.5)
            self.det(f"M{CX},{S+12:.1f} L{CX},{Hp:.1f} M{CX-3},{S+18:.1f} l6,3 M{CX-3},{S+25:.1f} l6,3 M{CX-3},{S+32:.1f} l6,3", "leather", 0.6, 0.8)
            self.belt(wa, W + 1)
        elif a == "plate":
            # tabard skirt + breastplate + pauldrons
            self.sh(smooth([(CX - wa * 0.8, W), (CX - wa * 0.85, Hp + 16), (CX, Hp + 20), (CX + wa * 0.85, Hp + 16), (CX + wa * 0.8, W)], t=0.3), "shirt", s=3)
            bp = smooth([(CX - 6, S - 1), (CX - ch * 0.95, S + 4), (CX - ch * 0.98, S + (W - S) * 0.5), (CX - wa * 0.95, W + 2),
                         (CX, W + 6), (CX + wa * 0.95, W + 2), (CX + ch * 0.98, S + (W - S) * 0.5), (CX + ch * 0.95, S + 4), (CX + 6, S - 1)], t=0.42)
            self.sh(bp, "metal", s=4)
            self.det(f"M{CX},{S+3:.1f} L{CX},{W+3:.1f} M{CX-ch*0.6:.1f},{S+(W-S)*0.55:.1f} Q{CX},{S+(W-S)*0.7:.1f} {CX+ch*0.6:.1f},{S+(W-S)*0.55:.1f}", "metal", 0.6, 0.8)
            self.belt(wa * 0.98, W + 3)
            for sd in (-1, 1):
                self.sh(ell(CX + sd * (sh_ - 2), S + 4, B["ar"] * 1.45, B["ar"] * 1.1), "metal", s=2.5)
        elif a == "apron":
            if self.cid == "player":
                ap = smooth([(CX - ch * 0.62, S + 6), (CX + ch * 0.62, S + 6), (CX + wa * 0.98, W + 2), (CX + hip * 1.02, FY - 34),
                             (CX, FY - 30), (CX - hip * 1.02, FY - 34), (CX - wa * 0.98, W + 2)], t=0.3)
                self.sh(ap, "apron", s=4)
                self.det(f"M{CX-ch*0.62:.1f},{S+7:.1f} L{CX-6:.1f},{S-3:.1f} M{CX+ch*0.62:.1f},{S+7:.1f} L{CX+6:.1f},{S-3:.1f}", "strap", 1.4)
                self.sh(rect(CX - 11, W + 6, 22, 12, 2), "apron", s=1.5, hl=False)
                self.det(f"M{CX-8},{(S+W)/2:.1f} l5,3 M{CX+4},{W-4:.1f} l6,-2 M{CX-14},{W+26:.1f} l4,5", "apron", 0.6, 0.8)
                self.belt(wa, W)
            else:
                bot = (FY - 24) if not self.skirt else (FY - 22)
                ap = smooth([(CX - ch * 0.55, S + 10), (CX + ch * 0.55, S + 10), (CX + wa * 0.85, W + 2),
                             (CX + hip * 0.95, bot), (CX, bot + 3), (CX - hip * 0.95, bot), (CX - wa * 0.85, W + 2)], t=0.3)
                self.sh(ap, "linen" if self.skirt else "apron", s=3)
                self.det(f"M{CX-ch*0.55:.1f},{S+11:.1f} L{CX-6:.1f},{S-2:.1f} M{CX+ch*0.55:.1f},{S+11:.1f} L{CX+6:.1f},{S-2:.1f}", "strap", 1.0)
                self.belt(wa, W, role="strap", buckle=False)
        elif a == "robe":
            self.det(f"M{CX-7},{self.S-2:.1f} L{CX},{self.S+12:.1f} L{CX+7},{self.S-2:.1f}", "shirt", 1.0)
            self.belt(wa, W, role="straw", buckle=False, rope=True)
        else:  # tunic / dress
            if not self.skirt:
                self.sh(smooth([(CX - wa, W), (CX - hip * 1.1, Hp + 8), (CX, Hp + 10), (CX + hip * 1.1, Hp + 8), (CX + wa, W)], t=0.35), "shirt", s=2.5)
            self.det(f"M{CX-6},{S-2:.1f} L{CX},{S+8:.1f} L{CX+6},{S-2:.1f}", "shirt", 0.9)
            self.belt(wa, W, role="strap", buckle=not self.skirt)
        if self.back == "pack" or self.back == "quiver":
            # shoulder straps over the chest
            self.det(f"M{CX-sh_*0.62:.1f},{S:.1f} Q{CX-ch*0.7:.1f},{S+16:.1f} {CX-ch*0.75:.1f},{W-6:.1f}", "strap", 2.2)
            if self.back == "pack":
                self.det(f"M{CX+sh_*0.62:.1f},{S:.1f} Q{CX+ch*0.7:.1f},{S+16:.1f} {CX+ch*0.75:.1f},{W-6:.1f}", "strap", 2.2)
        if self.back == "shield" or self.back == "lute" or (self.back == "quiver"):
            self.det(f"M{CX+sh_*0.6:.1f},{S:.1f} L{CX-wa*0.9:.1f},{W:.1f}", "strap", 1.8)

    def belt(self, wa, y, role="strap", buckle=True, rope=False):
        if rope:
            self.det(f"M{CX-wa*1.02:.1f},{y:.1f} Q{CX},{y+3:.1f} {CX+wa*1.02:.1f},{y:.1f}", "straw", 2.4)
            self.add(lin(f"M{CX-wa*1.02:.1f},{y:.1f} Q{CX},{y+3:.1f} {CX+wa*1.02:.1f},{y:.1f}", self.P.c("straw", 0), 1.6))
            self.det(f"M{CX+3:.1f},{y+2:.1f} l-1,14 M{CX+6:.1f},{y+2:.1f} l2,12", "straw", 1.6)
            return
        self.sh(smooth([(CX - wa * 1.04, y - 3), (CX, y - 1.5), (CX + wa * 1.04, y - 3), (CX + wa * 1.04, y + 3), (CX, y + 4.5), (CX - wa * 1.04, y + 3)], t=0.3), role, s=1.2, hl=False)
        if buckle:
            self.sh(rect(CX - 3.5, y - 3, 7, 7, 1.2), "gold", s=1, hl=False)

    def arms_front(self, sh_, back=False):
        """Two arms. Weapon hand is viewer-left in the front view, viewer-right in the back view."""
        B = self.B
        S, W, Hp = self.S, self.W, self.Hp
        wside = 1 if back else -1
        for side in (-1, 1):
            weapon = side == wside
            sx, sy = CX + side * (sh_ - B["ar"] * 0.75), S + B["ar"] * 0.9
            swing = (self.step if side == -1 else -self.step) * (-1 if back else 1)
            ex, ey = CX + side * (sh_ + 1.5), S + (Hp - S) * 0.5
            hx, hy = CX + side * (sh_ + 0.5) - side * swing * 1.5, Hp + 3 - abs(swing) * 1.5 - max(0, swing) * 2
            pose = self.pose_for(weapon, side)
            if pose == "raised":       # forearm forward, hand at the waist holding something upright
                hx, hy = CX + side * (sh_ + 2.5), W + 6
                ex, ey = CX + side * (sh_ + 3.5), S + (W - S) * 0.75
            elif pose == "chest":      # tankard / lute strum
                hx, hy = CX + side * (sh_ - 3), S + (W - S) * 0.62
                ex, ey = CX + side * (sh_ + 3.5), W
            elif pose == "shield":
                hx, hy = CX + side * (sh_ + 2), W + 2
                ex, ey = CX + side * (sh_ + 3), S + (W - S) * 0.7
            sleeve = self.sleeve_role()
            fore = "metal" if self.armor == "plate" else sleeve
            item_behind = weapon and not back and self.hand in ("bow",)
            if weapon and back:
                self.held_item(hx, hy, side, "N")
            self.sh(capsule((sx, sy), (ex, ey), B["ar"], B["ar"] * 0.92), sleeve, s=2.6)
            self.sh(capsule((ex, ey), (hx, hy - 2), B["ar"] * 0.9, B["ar"] * 0.78), fore, s=2.2)
            if self.robe:
                # wide sleeve cuff
                self.sh(ell((ex + hx) / 2 + side * 0.5, (ey + hy) / 2 + 4, B["ar"] * 1.25, B["ar"] * 0.9), "shirt", s=2)
            if weapon and not back:
                self.held_item(hx, hy, side, "S", before_hand=True)
            if not (pose == "shield"):
                self.sh(ell(hx, hy, B["hd"], B["hd"] * 1.05), "metal" if self.armor == "plate" else "skin", s=1.6)
            if weapon and not back:
                self.held_item(hx, hy, side, "S", before_hand=False)
            if not weapon and self.hand == "dagger" and not self.lute_front:
                self.held_item(hx, hy, side, "N" if back else "S", off=True)

    def sleeve_role(self):
        if self.cid == "player" or (self.look.get("build") == "orc" and self.armor in ("leather", "none")):
            return "skin"
        if self.armor == "apron" and self.look.get("build") == "heavy":
            return "skin" if not self.fem else "shirt"
        return "shirt"

    def pose_for(self, weapon, side):
        h = self.hand
        if self.shield_arm and not weapon:
            return "shield"
        if self.lute_front:
            return "chest"
        if weapon:
            if h in ("sword", "mace", "axe", "pick", "staff", "bow"):
                return "raised"
            if h == "tankard":
                return "chest"
        return "down"

    # ============================================================ held items
    def held_item(self, hx, hy, side, view, before_hand=True, off=False):
        """side: -1 viewer-left, +1 viewer-right. view S/N: item drawn at the hand; before_hand marks the part that
        sits behind the fist (shafts), the rest is drawn after."""
        h = self.hand
        if off:
            h = "dagger"
        P = self.P
        out = side
        o = []
        if h == "sword":
            f = frame_xf(hx, hy, -90 + out * 14)
            if before_hand:
                o.append(P.shape(lpoly(f, [(-9, -1.8), (6, -1.8), (6, 1.8), (-9, 1.8)]), "leather", s=0.8))
                o.append(P.shape(lell(f, -11, 0, 2.6, 2.6), "gold", s=0.8))
            else:
                o.append(P.shape(lpoly(f, [(10, -3.4), (66, -2.6), (74, 0), (66, 2.6), (10, 3.4)]), "metal", s=1.6))
                o.append(P.detail(lline(f, (12, 0), (64, 0)), "metal", 0.6, 0.8))
                o.append(P.shape(lsmooth(f, [(6, -12), (10, -12), (10, 12), (6, 12)], t=0.2), "gold", s=0.8))
        elif h == "dagger":
            ang = 90 + out * 25 if not off else 90 + out * 25
            f = frame_xf(hx, hy, ang)
            if not before_hand or off:
                o.append(P.shape(lpoly(f, [(5, -2.6), (26, -1.8), (31, 0), (26, 1.8), (5, 2.6)]), "metal", s=1))
                o.append(P.shape(lpoly(f, [(3, -6), (6, -6), (6, 6), (3, 6)]), "darkiron", s=0.6))
                o.append(P.shape(lpoly(f, [(-8, -1.8), (3, -1.8), (3, 1.8), (-8, 1.8)]), "leather", s=0.6))
        elif h == "mace":
            f = frame_xf(hx, hy, -90 + out * 10)
            if before_hand:
                o.append(P.shape(lpoly(f, [(-10, -2.4), (40, -2.4), (40, 2.4), (-10, 2.4)]), "wood", s=1))
            else:
                fl = []
                for i in range(12):
                    a = i / 12 * math.tau
                    r = 10 if i % 2 == 0 else 6.5
                    fl.append((46 + math.cos(a) * r, math.sin(a) * r))
                o.append(P.shape(lsmooth(f, fl, t=0.3), "metal", s=2.2))
                o.append(P.shape(lell(f, 46, 0, 3.4, 3.4), "metal", s=1, hl=False))
                o.append(P.shape(lpoly(f, [(55, -2), (60, 0), (55, 2)]), "metal", s=0.5))
        elif h == "axe":
            f = frame_xf(hx, hy, -90 + out * 12)
            if before_hand:
                o.append(P.shape(lpoly(f, [(-26, -2.6), (70, -2.6), (70, 2.6), (-26, 2.6)]), "wood", s=1.2))
            else:
                bl = [(50, 2 * -out), (46, 10 * out), (40, 20 * out), (56, 24 * out), (72, 20 * out), (66, 10 * out), (64, 2 * -out)]
                bl = [(u, v) for u, v in bl]
                o.append(P.shape(lsmooth(f, bl, t=0.35), "metal", s=2))
                bl2 = [(52, 2 * out), (50, 9 * -out), (58, 13 * -out), (64, 9 * -out), (62, 2 * out)]
                o.append(P.shape(lsmooth(f, bl2, t=0.35), "metal", s=1.2))
                o.append(P.shape(lpoly(f, [(48, -4), (66, -4), (66, 4), (48, 4)]), "darkiron", s=0.8))
                o.append(P.detail(lline(f, (44, 19 * out), (62, 23 * out)), "metal", 0.6, 0.8))
        elif h == "pick":
            f = frame_xf(hx, hy, -90 + out * 8)
            if before_hand:
                o.append(P.shape(lpoly(f, [(-14, -2.6), (64, -2.6), (64, 2.6), (-14, 2.6)]), "wood", s=1.2))
            else:
                head = [(62, -26), (66, -14), (68, 0), (66, 14), (62, 26), (70, 14), (72, 0), (70, -14)]
                o.append(P.shape(lsmooth(f, head, t=0.4), "metal", s=1.8))
                o.append(P.shape(lpoly(f, [(60, -4.5), (72, -4.5), (72, 4.5), (60, 4.5)]), "darkiron", s=0.8))
        elif h == "staff":
            f = frame_xf(hx, hy, -90 + out * 4)
            if before_hand:
                o.append(P.shape(lsmooth(f, [(-58, -2.2), (44, -2.8), (64, -3.2), (64, 3.2), (44, 2.8), (-58, 2.2)], t=0.1), "wood", s=1.2))
            else:
                tp = [(62, -7), (72, -9), (82, -5), (84, 0), (82, 5), (72, 9), (62, 7)]
                o.append(P.shape(lsmooth(f, tp, t=0.5), "wood", s=1.6))
                gx, gy = f(74, 0)
                o.append(glow(P, gx, gy, 13, EMBER, 0.5))
                o.append(P.shape(lell(f, 74, 0, 4.2, 4.2), "gem", s=1.2))
        elif h == "bow":
            f = frame_xf(hx, hy, -90)
            if before_hand:
                arc = [(-56, 0), (-30, 7 * out), (0, 11 * out), (30, 7 * out), (56, 0), (30, 4.5 * out), (0, 7.5 * out), (-30, 4.5 * out)]
                o.append(P.shape(lsmooth(f, arc, t=0.45), "wood", s=1.2))
                o.append(P.detail(lline(f, (-55, 0.5 * out), (55, 0.5 * out)), None, 0.35, 0.85))
        elif h == "hammer":
            big = self.cid == "player" or self.look.get("build") == "heavy"
            f = frame_xf(hx, hy, 90 + out * 18)
            if big:
                if before_hand:
                    o.append(P.shape(lpoly(f, [(-12, -3), (40, -3), (40, 3), (-12, 3)]), "wood", s=1.2))
                    o.append(P.detail(lline(f, (-2, -3), (4, 3)) + " " + lline(f, (8, -3), (14, 3)), "leather", 0.7))
                else:
                    o.append(P.shape(lpoly(f, [(38, -16), (57, -16), (57, 16), (38, 16)]), "metal", s=2.4))
                    o.append(P.shape(lpoly(f, [(36, -18), (40, -18), (40, 18), (36, 18)]), "darkiron", s=0.8))
                    o.append(P.shape(lpoly(f, [(55, -18), (59, -18), (59, 18), (55, 18)]), "darkiron", s=0.8))
                    o.append(P.detail(lline(f, (41, -10), (51, 10)), "metal", 0.4, 0.6))
            else:
                if before_hand:
                    o.append(P.shape(lpoly(f, [(-6, -2), (26, -2), (26, 2), (-6, 2)]), "wood", s=0.8))
                else:
                    o.append(P.shape(lsmooth(f, [(24, -10), (28, -9), (30, 0), (28, 8), (32, 14), (26, 12), (24, 2)], t=0.3), "metal", s=1.2))
        elif h == "basket":
            if not before_hand:
                bx, by = hx + out * 1, hy + 11
                o.append(P.detail(f"M{bx-10:.1f},{by-2:.1f} Q{bx:.1f},{by-20:.1f} {bx+10:.1f},{by-2:.1f}", "wood", 1.6))
                o.append(P.shape(smooth([(bx - 12, by - 3), (bx + 12, by - 3), (bx + 10, by + 9), (bx - 10, by + 9)], t=0.3), "wood", s=2))
                o.append(P.detail(f"M{bx-11},{by+1:.1f} Q{bx},{by+3:.1f} {bx+11},{by+1:.1f} M{bx-10},{by+5:.1f} Q{bx},{by+7:.1f} {bx+10},{by+5:.1f}", "wood", 0.5, 0.7))
                o.append(P.shape(ell(bx - 5, by - 4, 4, 3), "apron", s=1))
                o.append(P.shape(ell(bx + 3, by - 4, 3.4, 3.4), "apple", s=1))
                o.append(P.shape(ell(bx + 8, by - 3, 3, 2.6), "cabbage", s=1))
        elif h == "tankard":
            if not before_hand:
                tx, ty = hx + out * 2, hy - 7
                o.append(P.shape(rect(tx - 6, ty - 6, 12, 15, 2), "wood", s=1.6))
                o.append(P.detail(f"M{tx-6},{ty-2} h12 M{tx-6},{ty+5} h12", "darkiron", 0.8))
                o.append(P.shape(ell(tx, ty - 6, 6, 2.2), "linen", s=0.5, lw=1))
                o.append(P.detail(f"M{tx+out*6},{ty-3} q{out*6},1 {out*1},9", "wood", 1.2))
        self.o.extend(o)

    def shield_front(self, x, y, back=False):
        P = self.P
        role = "cloak" if self.look.get("cloak") else "apron"
        d = smooth([(x - 13, y - 17), (x, y - 19), (x + 13, y - 17), (x + 13, y), (x + 8, y + 13), (x, y + 20),
                    (x - 8, y + 13), (x - 13, y)], t=0.35)
        if back:
            self.sh(d, "wood", s=2.6)
            self.det(f"M{x-12},{y-8} L{x+12},{y-8} M{x-12},{y+4} L{x+12},{y+4}", "strap", 1.6)
            return
        self.sh(d, "metal", s=3)
        inner = smooth([(x - 10, y - 14), (x, y - 16), (x + 10, y - 14), (x + 10, y), (x + 6, y + 10), (x, y + 16),
                        (x - 6, y + 10), (x - 10, y)], t=0.35)
        self.sh(inner, "shirt" if self.look.get("armor") == "plate" and self.cid == "garrick" else role, s=2, hl=False)
        if self.cid == "garrick":
            self.add(fill(f"M{x-1.6},{y-12} h3.2 v8 h7 v3.2 h-7 v12 h-3.2 v-12 h-7 v-3.2 h7 Z", GILT))
        else:
            self.det(f"M{x},{y-15} L{x},{y+15} M{x-9},{y-3} L{x+9},{y-3}", "metal", 1.4)
            self.sh(ell(x, y - 2, 3.4, 3.4), "metal", s=1)

    def lute(self, x, y, ang, front=True):
        P = self.P
        f = frame_xf(x, y, ang)
        neck = [(8, -2.6), (38, -2.2), (38, 2.2), (8, 2.6)]
        self.sh(lpoly(f, neck), "strap", s=1)
        self.sh(lpoly(f, [(37, -3.6), (47, -3), (47, 3), (37, 3.6)]), "strap", s=0.8)
        if front:
            self.sh(lsmooth(f, [(-14, -10), (0, -12), (12, -6), (14, 0), (12, 6), (0, 12), (-14, 10), (-18, 0)], t=0.5), "wood", s=2.2)
            cx_, cy_ = f(0, 0)
            self.sh(ell(cx_, cy_, 3, 3), "strap", s=0.6, hl=False)
            self.det(lline(f, (-12, -1), (40, -1)) + " " + lline(f, (-12, 1.2), (40, 1.2)), None, 0.3, 0.8)

    # ============================================================ back items
    def back_items_front(self):
        """Back items seen from the front: only the parts that peek past the body."""
        B, S = self.B, self.S
        b = self.back
        sh_ = B["sh"]
        if b == "quiver":
            x, y = CX + sh_ * 0.55, S - 10
            for i, dx in enumerate((-4, 0, 4)):
                self.sh(ell(x + dx, y - 4 + (i % 2) * 3, 2.6, 5), "linen", s=0.8, fill_override=["#e8dcc0", "#8e3e3c", "#e8dcc0"][i])
            self.sh(rect(x - 6, y, 12, 12, 2), "leather", s=1)
        elif b == "pack":
            w = sh_ * 0.75
            self.sh(rect(CX - w, S - 12, 2 * w, 18, 7), "leather", s=2)
            self.sh(rect(CX - w * 1.1, S - 18, 2 * w * 1.1, 10, 5), "blue", s=1.5, fill_override="#8a8a6e")

    def back_items_back(self):
        B, P = self.B, self.P
        S, W, Hp = self.S, self.W, self.Hp
        b = self.back
        sh_ = B["sh"]
        if b == "quiver":
            f = frame_xf(CX - 4, Hp + 2, -90 + 22)
            self.sh(lpoly(f, [(0, -6), (52, -7), (52, 7), (0, 6)]), "leather", s=2)
            self.det(lline(f, (14, -6.5), (14, 6.5)) + " " + lline(f, (38, -7), (38, 7)), "strap", 1.0)
            for i, dv in enumerate((-4, 0, 4)):
                self.sh(lell(f, 58 + (i % 2) * 3, dv, 5, 2.6), "linen", s=0.8, fill_override=["#e8dcc0", "#8e3e3c", "#e8dcc0"][i])
        elif b == "pack":
            w = sh_ * 0.78
            top = S - 6
            self.sh(rect(CX - w, top, 2 * w, (W - top) + 8, 7), "leather", s=3.5)
            self.sh(rect(CX - w * 0.85, top + 2, w * 1.7, (W - top) * 0.5, 5), "leather", s=2, hl=False)
            self.sh(rect(CX - 3, top + (W - top) * 0.5 - 2, 6, 6, 1), "gold", s=0.8)
            self.sh(rect(CX - w * 1.12, top - 10, 2 * w * 1.12, 11, 5.5), "blue", s=1.5, fill_override="#8a8a6e")
            self.det(f"M{CX-w*0.6:.1f},{top-10:.1f} l0,11 M{CX+w*0.6:.1f},{top-10:.1f} l0,11", "strap", 1.2)
            self.sh(ell(CX + w * 0.95, W - 2, 5.5, 6), "metal", s=1.2)
        elif b == "lute":
            pass

    # ============================================================ head
    def head_front(self):
        B, P, L = self.B, self.P, self.look
        hx, hy, rx, ry = CX, self.hcy, B["hrx"], B["hry"]
        ex = self.ex
        hair = L.get("hair", "short")
        # neck
        self.sh(rect(hx - rx * 0.42, hy + ry * 0.6, rx * 0.84, (self.S + 3) - (hy + ry * 0.6), 3), "skin", s=1.5, hl=False)
        if "hood_down" in ex:
            self.sh(smooth([(hx - rx * 1.25, self.S + 2), (hx - rx * 0.9, self.S - 7), (hx, self.S - 4), (hx + rx * 0.9, self.S - 7),
                            (hx + rx * 1.25, self.S + 2), (hx, self.S + 6)], t=0.45), "hoodc", s=2)
        if hair == "hood":
            self.sh(ell(hx, hy - 1, rx * 1.32, ry * 1.18), "hoodc", s=3)
        # ears
        if "pointed_ears" in ex:
            for sd in (-1, 1):
                self.sh(poly([(hx + sd * rx * 0.85, hy - 2), (hx + sd * (rx + 10), hy - 9), (hx + sd * rx * 0.9, hy + 5)]), "skin", s=1)
        elif hair not in ("long", "hood"):
            for sd in (-1, 1):
                self.sh(ell(hx + sd * rx * 0.98, hy + 1, 3.2, 4.4), "skin", s=1)
        # face
        face = smooth([(hx - rx, hy - ry * 0.2), (hx - rx * 0.8, hy - ry * 0.85), (hx, hy - ry), (hx + rx * 0.8, hy - ry * 0.85),
                       (hx + rx, hy - ry * 0.2), (hx + rx * 0.82, hy + ry * 0.62), (hx, hy + ry * 1.02), (hx - rx * 0.82, hy + ry * 0.62)], t=0.5)
        self.sh(face, "skin", s=3)
        # hair front
        self.hair_front(hx, hy, rx, ry, hair)
        # features
        ey = hy + ry * 0.08
        ink = INK
        patch = "eyepatch" in ex
        for sd in (-1, 1):
            if patch and sd == 1:
                self.add(fill(ell(hx + sd * rx * 0.38, ey, 3.4, 2.8), "#2a1c12"))
                continue
            self.add(fill(ell(hx + sd * rx * 0.38, ey, 1.5, 1.7), ink))
            self.add(lin(f"M{hx+sd*rx*0.18:.1f},{ey-4.2:.1f} L{hx+sd*rx*0.58:.1f},{ey-4.8+(1 if self.look.get('build') in ('orc','dwarf') else 0):.1f}", ink, 1.0, 0.85))
        if patch:
            self.add(lin(f"M{hx-rx*0.95:.1f},{hy-ry*0.55:.1f} L{hx+rx*0.95:.1f},{ey+2:.1f}", "#2a1c12", 1.1))
        self.add(lin(f"M{hx+0.5:.1f},{ey+2:.1f} q1.6,3.6 -0.8,4.6", self.P.c("skin", 2), 1.0, 0.9))
        beard = L.get("beard", "none")
        if beard in ("none", "stubble"):
            self.add(lin(f"M{hx-3:.1f},{hy+ry*0.56:.1f} q3,1.2 6,0", "#6a3a2a", 1.0, 0.9))
        if "tusks" in ex:
            for sd in (-1, 1):
                self.sh(poly([(hx + sd * 4.5, hy + ry * 0.6), (hx + sd * 6.5, hy + ry * 0.22), (hx + sd * 7.2, hy + ry * 0.6)]), "ivory", s=0.5, lw=1.4)
        self.beard_front(hx, hy, rx, ry, beard)
        if "scalp_scar" in ex:
            self.add(lin(f"M{hx-rx*0.15:.1f},{hy-ry*0.95:.1f} l{rx*0.42:.1f},{ry*0.45:.1f}", "#8a4a3a", 1.4))
            self.add(lin(f"M{hx-rx*0.05:.1f},{hy-ry*0.85:.1f} l3,-1.6 M{hx+rx*0.1:.1f},{hy-ry*0.7:.1f} l3,-1.6", "#8a4a3a", 0.8))
        if "spectacles" in ex:
            self.spectacles_front(hx, ey, rx)
        if "headscarf" in ex:
            self.headscarf(hx, hy, rx, ry, "S")
        if "helmet_miner" in ex:
            self.miner_helmet(hx, hy, rx, ry, "S")
        if "spectacles" in ex:
            for sd in (-1, 1):
                self.det(ell(hx + sd * rx * 0.38, ey, 3.4, 3.0), None, 0.9)
            self.add(lin(f"M{hx-rx*0.38+3.4:.1f},{ey:.1f} L{hx+rx*0.38-3.4:.1f},{ey:.1f}", INK, 0.9))
        if "helmet_m1" in ex:
            self.m1_helmet(hx, hy, rx, ry, "S")

    # -- optional head pieces (player appearance choices)
    def spectacles_front(self, hx, ey, rx):
        for sd in (-1, 1):
            x = hx + sd * rx * 0.38
            self.add(f'<ellipse cx="{x:.1f}" cy="{ey:.1f}" rx="3.9" ry="3.5" fill="#eef4f0" fill-opacity="0.35" stroke="{INK}" stroke-width="1.1"/>')
            self.add(lin(f"M{x + sd*3.9:.1f},{ey-0.6:.1f} L{hx + sd*rx*0.98:.1f},{ey-1.6:.1f}", INK, 0.9, 0.9))
            self.add(fill(ell(x - 1.4, ey - 1.3, 1.0, 0.7), "#ffffff", 0.8))
        self.add(lin(f"M{hx - rx*0.38 + 3.9:.1f},{ey-0.8:.1f} Q{hx:.1f},{ey-2.6:.1f} {hx + rx*0.38 - 3.9:.1f},{ey-0.8:.1f}", INK, 1.0))

    def headscarf(self, hx, hy, rx, ry, view):
        if view == "S":
            cap = smooth([(hx - rx * 1.1, hy - ry * 0.2), (hx - rx * 1.06, hy - ry * 0.75), (hx - rx * 0.6, hy - ry * 1.12), (hx, hy - ry * 1.2),
                          (hx + rx * 0.6, hy - ry * 1.12), (hx + rx * 1.06, hy - ry * 0.75), (hx + rx * 1.1, hy - ry * 0.2),
                          (hx + rx * 0.7, hy - ry * 0.4), (hx, hy - ry * 0.5), (hx - rx * 0.7, hy - ry * 0.4)], t=0.45)
            self.sh(cap, "scarf", s=2.2)
            self.det(f"M{hx-rx*0.8:.1f},{hy-ry*0.62:.1f} Q{hx:.1f},{hy-ry*0.78:.1f} {hx+rx*0.8:.1f},{hy-ry*0.62:.1f}", "scarf", 0.7, 0.8)
            kx, ky = hx + rx * 1.02, hy - ry * 0.4
            self.sh(ell(kx, ky, 3.6, 3.2), "scarf", s=1)
            self.sh(smooth([(kx, ky + 2), (kx + 5, ky + 8), (kx + 4, ky + 14), (kx + 1, ky + 9)], t=0.4), "scarf", s=1, lw=1.4)
        elif view == "E":
            cap = smooth([(hx + rx * 0.7, hy - ry * 0.5), (hx + rx * 0.5, hy - ry * 1.1), (hx - rx * 0.3, hy - ry * 1.18), (hx - rx * 1.1, hy - ry * 0.5),
                          (hx - rx * 1.1, hy + ry * 0.1), (hx - rx * 0.4, hy - ry * 0.25), (hx + rx * 0.2, hy - ry * 0.42)], t=0.45)
            self.sh(cap, "scarf", s=2.2)
            kx, ky = hx - rx * 1.05, hy - ry * 0.1
            self.sh(ell(kx, ky, 3.4, 3.2), "scarf", s=1)
            self.sh(smooth([(kx, ky + 2), (kx - 5 - self.step, ky + 9), (kx - 3 - self.step, ky + 15), (kx + 1, ky + 8)], t=0.4), "scarf", s=1, lw=1.4)
        else:
            self.sh(ell(hx, hy - ry * 0.3, rx * 1.1, ry * 0.92), "scarf", s=2.4)
            self.det(f"M{hx-rx*0.7:.1f},{hy-ry*0.7:.1f} Q{hx:.1f},{hy-ry*0.2:.1f} {hx+rx*0.7:.1f},{hy-ry*0.7:.1f}", "scarf", 0.7, 0.8)
            kx, ky = hx, hy + ry * 0.45
            self.sh(ell(kx, ky, 3.8, 3.2), "scarf", s=1)
            for sd in (-1, 1):
                self.sh(smooth([(kx, ky + 2), (kx + sd * 5, ky + 9), (kx + sd * 3, ky + 15), (kx - sd * 1, ky + 8)], t=0.4), "scarf", s=1, lw=1.4)

    def hair_front(self, hx, hy, rx, ry, hair):
        P = self.P
        if hair in ("short", "cropped", "braid", "ponytail", "bun", "long"):
            k = 1.06 if hair != "cropped" else 1.02
            line = ry * (0.38 if hair != "cropped" else 0.45)
            pts = [(hx - rx * k, hy + 1), (hx - rx * k, hy - ry * 0.5), (hx - rx * 0.62, hy - ry * k), (hx, hy - ry * (k + 0.06)),
                   (hx + rx * 0.62, hy - ry * k), (hx + rx * k, hy - ry * 0.5), (hx + rx * k, hy + 1),
                   (hx + rx * 0.84, hy - line + 3), (hx + rx * 0.3, hy - line), (hx - rx * 0.25, hy - line - 1), (hx - rx * 0.84, hy - line + 4)]
            if hair == "long":
                pts[0] = (hx - rx * 1.1, hy + ry * 0.7)
                pts[6] = (hx + rx * 1.1, hy + ry * 0.7)
            self.sh(smooth(pts, t=0.45), "hair", s=2.4)
            self.det(f"M{hx-rx*0.1:.1f},{hy-ry*1.0:.1f} Q{hx-rx*0.3:.1f},{hy-ry*0.7:.1f} {hx-rx*0.6:.1f},{hy-line+1:.1f}", "hair", 0.6, 0.7)
            if hair == "bun":
                self.sh(ell(hx, hy - ry * 1.08, 6.5, 5.5), "hair", s=1.5)
            if hair == "braid":
                for i in range(6):
                    self.sh(ell(hx + rx * 0.95 + i * 0.4, hy + ry * 0.7 + i * 6, 3.6, 4), "hair", s=1, lw=1.6)
        elif hair == "curly":
            rnd = random.Random(3)
            for i in range(9):
                a = math.pi * (1.05 + i / 8 * 0.9)
                cx_, cy_ = hx + math.cos(a) * rx * 0.95, hy - ry * 0.3 + math.sin(a) * ry * 0.85
                self.sh(ell(cx_, cy_, 5.2 + rnd.uniform(0, 1), 5), "hair", s=1.4, lw=1.6)
        elif hair == "mohawk":
            self.sh(smooth([(hx - 3, hy - ry * 0.5), (hx - 4.5, hy - ry * 1.05), (hx - 2, hy - ry - 9), (hx + 2, hy - ry - 9),
                            (hx + 4.5, hy - ry * 1.05), (hx + 3, hy - ry * 0.5)], t=0.4), "hair", s=1.5)
            self.add(fill(smooth([(hx - rx * 0.9, hy - ry * 0.35), (hx - rx * 0.6, hy - ry * 0.9), (hx + rx * 0.6, hy - ry * 0.9),
                                  (hx + rx * 0.9, hy - ry * 0.35), (hx, hy - ry * 0.55)]), f"url(#{P.hatch_id})", 0.35))
        elif hair == "bald":
            self.add(fill(ell(hx - rx * 0.35, hy - ry * 0.6, rx * 0.25, ry * 0.15), "#fff6e4", 0.45))
        elif hair == "bald_fringe":
            for sd in (-1, 1):
                self.sh(smooth([(hx + sd * rx * 1.04, hy - ry * 0.3), (hx + sd * rx * 0.86, hy - ry * 0.42), (hx + sd * rx * 0.8, hy + ry * 0.1),
                                (hx + sd * rx * 1.04, hy + ry * 0.35)], t=0.5), "hair", s=1)
            self.add(fill(ell(hx - rx * 0.35, hy - ry * 0.6, rx * 0.25, ry * 0.15), "#fff6e4", 0.45))
        elif hair == "hood":
            self.sh(smooth([(hx - rx * 1.25, hy + ry * 0.4), (hx - rx * 1.1, hy - ry * 0.8), (hx, hy - ry * 1.25), (hx + rx * 1.1, hy - ry * 0.8),
                            (hx + rx * 1.25, hy + ry * 0.4), (hx + rx * 0.92, hy - ry * 0.1), (hx + rx * 0.6, hy - ry * 0.62), (hx, hy - ry * 0.78),
                            (hx - rx * 0.6, hy - ry * 0.62), (hx - rx * 0.92, hy - ry * 0.1)], t=0.45), "hoodc", s=2.4)

    def hair_behind(self, view):
        B, L = self.B, self.look
        hx, hy, rx, ry = CX, self.hcy, B["hrx"], B["hry"]
        hair = L.get("hair", "short")
        if hair == "long" and view == "S":
            ln = ry * (2.6 if self.fem else 2.2)
            self.sh(smooth([(hx - rx * 1.1, hy - ry * 0.4), (hx - rx * 1.35, hy + ln * 0.6), (hx - rx * 1.2, hy + ln),
                            (hx + rx * 1.2, hy + ln), (hx + rx * 1.35, hy + ln * 0.6), (hx + rx * 1.1, hy - ry * 0.4)], t=0.45), "hair", s=3)
        if hair == "curly":
            self.sh(blob(hx, hy - ry * 0.25, rx * 1.3, 10, 0.1, 7, squash=ry / rx * 0.95), "hair", s=3)
        if hair == "ponytail" and view == "S":
            self.sh(ell(hx + rx * 0.9, hy + ry * 0.2, 4, 9), "hair", s=1.5)

    def beard_front(self, hx, hy, rx, ry, beard):
        P = self.P
        if beard == "stubble":
            d = smooth([(hx - rx * 0.92, hy + ry * 0.1), (hx - rx * 0.6, hy + ry * 0.85), (hx, hy + ry * 1.04), (hx + rx * 0.6, hy + ry * 0.85),
                        (hx + rx * 0.92, hy + ry * 0.1), (hx + rx * 0.5, hy + ry * 0.42), (hx, hy + ry * 0.45), (hx - rx * 0.5, hy + ry * 0.42)], t=0.45)
            self.add(fill(d, f"url(#{P.xhatch_id})", 0.5))
            return
        if beard == "none":
            return
        if beard == "short":
            ln = ry * 1.25
        elif beard == "long":
            ln = ry * (2.7 if self.look.get("build") == "dwarf" else 2.3)
        else:  # braided
            ln = ry * 2.2
        pts = [(hx - rx * 1.0, hy + ry * 0.05), (hx - rx * 0.95, hy + ry * 0.75), (hx - rx * 0.6, hy + ln * 0.85),
               (hx, hy + ln), (hx + rx * 0.6, hy + ln * 0.85), (hx + rx * 0.95, hy + ry * 0.75), (hx + rx * 1.0, hy + ry * 0.05),
               (hx + rx * 0.55, hy + ry * 0.5), (hx, hy + ry * 0.62), (hx - rx * 0.55, hy + ry * 0.5)]
        if beard == "braided":
            pts[2] = (hx - rx * 0.5, hy + ry * 1.25)
            pts[3] = (hx, hy + ry * 1.4)
            pts[4] = (hx + rx * 0.5, hy + ry * 1.25)
        self.sh(smooth(pts, t=0.45), "beard", s=2.6)
        if beard == "braided":
            for i in range(4):
                self.sh(ell(hx, hy + ry * 1.38 + i * 6.2, 4.4 - i * 0.4, 3.8), "beard", s=1, lw=1.6)
            self.sh(rect(hx - 4, hy + ry * 1.38 + 3.4 * 6.2 - 1, 8, 3.4, 1), "metal", s=0.6)
        else:
            self.det(f"M{hx-rx*0.4:.1f},{hy+ry*0.9:.1f} L{hx-rx*0.3:.1f},{hy+ln*0.8:.1f} M{hx+rx*0.35:.1f},{hy+ry*0.9:.1f} L{hx+rx*0.25:.1f},{hy+ln*0.82:.1f}", "beard", 0.6, 0.7)
        # moustache
        self.sh(smooth([(hx - rx * 0.62, hy + ry * 0.55), (hx - rx * 0.2, hy + ry * 0.32), (hx, hy + ry * 0.4), (hx + rx * 0.2, hy + ry * 0.32),
                        (hx + rx * 0.62, hy + ry * 0.55), (hx, hy + ry * 0.55)], t=0.45), "beard", s=1, lw=1.6)

    def m1_helmet(self, hx, hy, rx, ry, view):
        """Ironfront: the green M1-style steel helmet Barnaby wears at his card table."""
        top = hy - ry * 1.2
        dx = 2 if view == "E" else 0
        self.sh(smooth([(hx + dx - rx * 1.2, hy - ry * 0.18), (hx + dx - rx * 1.02, hy - ry * 0.98), (hx + dx, top - 3), (hx + dx + rx * 1.02, hy - ry * 0.98),
                        (hx + dx + rx * 1.2, hy - ry * 0.18)], t=0.5), "olive", s=2.4)
        self.sh(ell(hx + dx, hy - ry * 0.2, rx * 1.36, 3.4), "olive", s=1.2)
        self.det(f"M{hx+dx-rx*0.7:.1f},{hy-ry*0.75:.1f} Q{hx+dx:.1f},{hy-ry*0.95:.1f} {hx+dx+rx*0.7:.1f},{hy-ry*0.75:.1f}", "olive", 0.6, 0.7)

    def miner_helmet(self, hx, hy, rx, ry, view):
        P = self.P
        top = hy - ry * 1.12
        if view in ("S", "N"):
            self.sh(ell(hx, hy - ry * 0.32, rx * 1.28, 4.5), "bronze", s=1.2)
            self.sh(smooth([(hx - rx * 1.05, hy - ry * 0.36), (hx - rx * 0.9, hy - ry * 0.95), (hx, top - 2), (hx + rx * 0.9, hy - ry * 0.95),
                            (hx + rx * 1.05, hy - ry * 0.36)], t=0.5), "bronze", s=2.4)
            self.det(f"M{hx},{top-1:.1f} L{hx},{hy-ry*0.38:.1f}", "bronze", 0.8)
            if view == "S":
                self.sh(rect(hx - 4, hy - ry * 0.95, 8, 7, 2), "darkiron", s=0.6)
                self.add(glow(P, hx, hy - ry * 0.75, 9, EMBER_HOT, 0.6))
                self.add(fill(ell(hx, hy - ry * 0.75, 2.2, 2.8), "#ffe2a0"))
        else:
            self.sh(ell(hx + 2, hy - ry * 0.32, rx * 1.3, 4), "bronze", s=1.2)
            self.sh(smooth([(hx - rx * 1.0, hy - ry * 0.36), (hx - rx * 0.85, hy - ry * 0.95), (hx, top - 2), (hx + rx * 0.9, hy - ry * 0.95),
                            (hx + rx * 1.05, hy - ry * 0.36)], t=0.5), "bronze", s=2.4)
            self.sh(rect(hx + rx * 0.82, hy - ry * 0.95, 5, 7, 1.5), "darkiron", s=0.6)
            self.add(glow(P, hx + rx * 1.15, hy - ry * 0.75, 8, EMBER_HOT, 0.5))
            self.add(fill(ell(hx + rx * 1.15, hy - ry * 0.75, 1.8, 2.6), "#ffe2a0"))

    # ============================================================ back view
    def backv(self):
        B, P, L = self.B, self.P, self.look
        S, W, Hp = self.S, self.W, self.Hp
        brw = self.br * 0.6
        sh_, ch, wa, hip = B["sh"] + brw * 0.4, B["ch"] + brw, B["wa"], B["hip"]
        if self.lute_front:
            # lute held in front: the pegbox peeks out past the left shoulder
            f = frame_xf(CX - sh_ * 0.6, S + 6, -128)
            self.sh(lpoly(f, [(0, -2.6), (20, -2.2), (20, 2.2), (0, 2.6)]), "strap", s=0.8)
            self.sh(lpoly(f, [(19, -3.4), (28, -3), (28, 3), (19, 3.4)]), "strap", s=0.8)
        if self.shield_arm:
            pass
        self.legs_front(back=True)
        if self.robe or self.skirt:
            self.skirt_front(hip)
        tp = self.torso_pts(sh_, ch, wa, hip, S, W, Hp)
        self.sh(smooth(tp, t=0.42), "shirt", s=4)
        a = self.armor
        if a == "leather":
            self.sh(smooth([(CX - sh_ * 0.75, S + 2), (CX - ch * 0.98, S + 12), (CX - wa * 1.02, W + 1), (CX - hip * 1.02, Hp + 2),
                            (CX + hip * 1.02, Hp + 2), (CX + wa * 1.02, W + 1), (CX + ch * 0.98, S + 12), (CX + sh_ * 0.75, S + 2)], t=0.4), "leather", s=3)
            self.det(f"M{CX-ch*0.5:.1f},{S+10:.1f} Q{CX},{S+14:.1f} {CX+ch*0.5:.1f},{S+10:.1f}", "leather", 0.6, 0.8)
            self.belt(wa, W + 1, buckle=False)
        elif a == "plate":
            self.sh(smooth([(CX - wa * 0.8, W), (CX - wa * 0.85, Hp + 16), (CX, Hp + 20), (CX + wa * 0.85, Hp + 16), (CX + wa * 0.8, W)], t=0.3), "shirt", s=3)
            self.sh(smooth([(CX - ch * 0.95, S + 4), (CX - ch * 0.98, S + (W - S) * 0.5), (CX - wa * 0.95, W + 2), (CX, W + 4),
                            (CX + wa * 0.95, W + 2), (CX + ch * 0.98, S + (W - S) * 0.5), (CX + ch * 0.95, S + 4), (CX, S)], t=0.42), "metal", s=4)
            self.det(f"M{CX},{S+3:.1f} L{CX},{W+2:.1f}", "metal", 0.6, 0.8)
            self.belt(wa * 0.98, W + 3, buckle=False)
            for sd in (-1, 1):
                self.sh(ell(CX + sd * (sh_ - 2), S + 4, B["ar"] * 1.45, B["ar"] * 1.1), "metal", s=2.5)
        elif a == "apron":
            self.det(f"M{CX-ch*0.7:.1f},{S+4:.1f} L{CX+wa*0.6:.1f},{W:.1f} M{CX+ch*0.7:.1f},{S+4:.1f} L{CX-wa*0.6:.1f},{W:.1f}", "strap", 1.5)
            self.belt(wa, W, role="strap", buckle=False)
            self.det(f"M{CX-2},{W+2:.1f} l-4,10 M{CX+2},{W+2:.1f} l5,9", "strap", 1.2)
        elif a == "robe":
            self.belt(wa, W, role="straw", buckle=False, rope=False)
            self.det(f"M{CX-ch*0.4:.1f},{S+8:.1f} Q{CX},{(S+W)/2:.1f} {CX-ch*0.2:.1f},{W-4:.1f} M{CX+ch*0.45:.1f},{S+10:.1f} Q{CX+ch*0.1:.1f},{(S+W)/2:.1f} {CX+ch*0.3:.1f},{W-4:.1f}", "shirt", 0.6, 0.7)
        else:
            if not self.skirt:
                self.sh(smooth([(CX - wa, W), (CX - hip * 1.1, Hp + 8), (CX, Hp + 10), (CX + hip * 1.1, Hp + 8), (CX + wa, W)], t=0.35), "shirt", s=2.5)
            self.belt(wa, W, role="strap", buckle=False)
        # cloak hangs from the shoulders over the back
        if L.get("cloak"):
            sway = self.step * 2.5
            cl = smooth([(CX - sh_ * 0.55, S - 3), (CX - sh_ * 0.98, S + 8), (CX - sh_ * 1.12 + sway, FY - 26),
                         (CX - sh_ * 0.4 + sway, FY - 19), (CX + sh_ * 0.4 + sway, FY - 21), (CX + sh_ * 1.12 + sway, FY - 26),
                         (CX + sh_ * 0.98, S + 8), (CX + sh_ * 0.55, S - 3), (CX, S - 1)], t=0.42)
            self.sh(cl, "cloak", s=4)
            self.det(f"M{CX-sh_*0.5:.1f},{S+14:.1f} Q{CX-sh_*0.6+sway:.1f},{(S+FY)/2:.1f} {CX-sh_*0.7+sway:.1f},{FY-24:.1f} "
                     f"M{CX+sh_*0.1:.1f},{S+20:.1f} Q{CX+sway*0.5:.1f},{(S+FY)/2+10:.1f} {CX+sh_*0.1+sway:.1f},{FY-22:.1f} "
                     f"M{CX+sh_*0.6:.1f},{S+14:.1f} Q{CX+sh_*0.7+sway:.1f},{(S+FY)/2:.1f} {CX+sh_*0.8+sway:.1f},{FY-25:.1f}", "cloak", 0.7, 0.75)
        if "pauldron" in self.ex:
            px, py = CX - sh_ * 0.82, S + 3
            self.sh(smooth([(px + 12, py + 2), (px + 6, py - 7), (px - 6, py - 8), (px - 14, py - 1), (px - 15, py + 9),
                            (px - 4, py + 10), (px + 8, py + 8)]), "metal", s=3)
        self.arms_front(sh_, back=True)
        if self.shield_arm:
            self.shield_front(CX - sh_ - 3, W - 2, back=True)
        self.back_items_back()
        if "hood_down" in self.ex:
            self.sh(smooth([(CX - B["hrx"] * 1.0, S - 2), (CX + B["hrx"] * 1.0, S - 2), (CX + B["hrx"] * 0.8, S + 14), (CX, S + 20),
                            (CX - B["hrx"] * 0.8, S + 14)], t=0.45), "hoodc", s=2)
        self.head_back()
        self.head_back(after_cloak=True)

    def head_back(self, after_cloak=False):
        B, L = self.B, self.look
        hx, hy, rx, ry = CX, self.hcy, B["hrx"], B["hry"]
        hair = L.get("hair", "short")
        ex = self.ex
        if after_cloak:
            # long hair / braids fall over the cloak
            if hair == "long":
                ln = ry * (2.6 if self.fem else 2.2)
                self.sh(smooth([(hx - rx * 1.1, hy - ry * 0.4), (hx - rx * 1.3, hy + ln * 0.6), (hx - rx * 1.1, hy + ln),
                                (hx + rx * 1.1, hy + ln), (hx + rx * 1.3, hy + ln * 0.6), (hx + rx * 1.1, hy - ry * 0.4)], t=0.45), "hair", s=3)
                self.det(f"M{hx-rx*0.4:.1f},{hy+ry*0.4:.1f} L{hx-rx*0.5:.1f},{hy+ln*0.95:.1f} M{hx+rx*0.3:.1f},{hy+ry*0.4:.1f} L{hx+rx*0.35:.1f},{hy+ln*0.95:.1f}", "hair", 0.6, 0.7)
                self.sh(ell(hx, hy - ry * 0.1, rx * 1.06, ry * 1.04), "hair", s=2.4)
            elif hair == "ponytail":
                self.sh(smooth([(hx - 4, hy + 2), (hx + 4, hy + 2), (hx + 5, hy + ry * 2.2), (hx, hy + ry * 2.7), (hx - 5, hy + ry * 2.2)], t=0.45), "hair", s=1.6)
            elif hair == "braid":
                for i in range(7):
                    self.sh(ell(hx, hy + ry * 0.8 + i * 6, 3.8, 4.1), "hair", s=1, lw=1.6)
            return
        if "hood_down" in ex and not L.get("cloak"):
            pass
        self.sh(rect(hx - rx * 0.42, hy + ry * 0.5, rx * 0.84, (self.S + 3) - (hy + ry * 0.5), 3), "skin", s=1.5, hl=False)
        if "pointed_ears" in ex:
            for sd in (-1, 1):
                self.sh(poly([(hx + sd * rx * 0.85, hy - 2), (hx + sd * (rx + 10), hy - 9), (hx + sd * rx * 0.9, hy + 5)]), "skin", s=1)
        elif hair not in ("long", "hood"):
            for sd in (-1, 1):
                self.sh(ell(hx + sd * rx * 0.98, hy + 1, 3.2, 4.4), "skin", s=1)
        beard = L.get("beard", "none")
        if beard in ("long", "braided"):
            for sd in (-1, 1):
                self.sh(ell(hx + sd * rx * 0.85, hy + ry * 0.8, 5, 6), "beard", s=1.5)
        if hair == "hood":
            self.sh(smooth([(hx - rx * 1.25, hy + ry * 0.5), (hx - rx * 1.15, hy - ry * 0.7), (hx, hy - ry * 1.25), (hx + rx * 1.15, hy - ry * 0.7),
                            (hx + rx * 1.25, hy + ry * 0.5), (hx + rx * 0.5, hy + ry * 1.3), (hx, hy + ry * 1.6), (hx - rx * 0.5, hy + ry * 1.3)], t=0.45), "hoodc", s=3)
            return
        skin_head = hair in ("bald_fringe", "mohawk", "bald")
        self.sh(ell(hx, hy - ry * 0.05, rx * (1.0 if skin_head else 1.06), ry * (1.0 if skin_head else 1.04)),
                "skin" if skin_head else "hair", s=3)
        if hair == "bald_fringe":
            self.sh(smooth([(hx - rx * 1.04, hy - ry * 0.3), (hx, hy + ry * 0.05), (hx + rx * 1.04, hy - ry * 0.3), (hx + rx * 0.9, hy + ry * 0.5),
                            (hx, hy + ry * 0.75), (hx - rx * 0.9, hy + ry * 0.5)], t=0.45), "hair", s=1.5)
            if "scalp_scar" in ex:
                self.add(lin(f"M{hx+rx*0.2:.1f},{hy-ry*0.8:.1f} l{-rx*0.4:.1f},{ry*0.4:.1f}", "#8a4a3a", 1.2))
        elif hair == "bald":
            if "scalp_scar" in ex:
                self.add(lin(f"M{hx+rx*0.2:.1f},{hy-ry*0.8:.1f} l{-rx*0.4:.1f},{ry*0.4:.1f}", "#8a4a3a", 1.2))
        elif hair == "mohawk":
            self.sh(rect(hx - 4, hy - ry - 8, 8, ry * 1.8 + 8, 4), "hair", s=1.5)
        elif hair == "curly":
            self.sh(blob(hx, hy - ry * 0.15, rx * 1.3, 10, 0.1, 7, squash=ry / rx * 0.95), "hair", s=3)
        elif hair == "bun":
            self.sh(ell(hx, hy - ry * 0.5, 7, 6.5), "hair", s=1.5)
            self.det(f"M{hx-5},{hy-ry*0.5:.1f} q5,-3 10,0", "hair", 0.6)
        else:
            self.det(f"M{hx:.1f},{hy-ry*0.95:.1f} Q{hx-rx*0.2:.1f},{hy:.1f} {hx-rx*0.1:.1f},{hy+ry*0.8:.1f}", "hair", 0.6, 0.7)
        if "headscarf" in ex:
            self.headscarf(hx, hy, rx, ry, "N")
        if "helmet_miner" in ex:
            self.miner_helmet(hx, hy, rx, ry, "N")
        if "helmet_m1" in ex:
            self.m1_helmet(hx, hy, rx, ry, "N")

    # ============================================================ side view (facing right / east)
    def side(self):
        B, P, L = self.B, self.P, self.look
        S, W, Hp = self.S, self.W, self.Hp
        brw = self.br * 0.6
        d = B["ch"] * 0.74 + brw * 0.5      # half depth of the chest
        db = B["wa"] * 0.72                 # belly
        stride = 12 if B["H"] > 140 else 9
        sw = self.step                      # +1 near leg forward
        sway = -self.step * 2.0
        # far arm (behind) ----------------------------------------------------
        self.arm_side(far=True, d=d)
        # cloak behind
        if L.get("cloak"):
            fl = 3 + (abs(self.step) * 3 if self.walk else 0)
            cl = smooth([(CX - 2, S - 3), (CX - d * 1.1, S + 6), (CX - d * 1.5 - fl, FY - 24), (CX - d * 0.6 - fl * 0.5, FY - 17),
                         (CX + 2, FY - 30), (CX + d * 0.2, S + 20)], t=0.45)
            self.sh(cl, "cloak", s=3.5)
        self.back_items_side(d)
        self.hair_behind_side()
        # legs ---------------------------------------------------------------
        for near in (False, True):
            fwd = sw if near else -sw
            lifted = max(0.0, self.lift if near else -self.lift)
            fx = CX + fwd * stride
            fy = FY - lifted * 5.5 - (2 if not near else 0)
            self.leg_side(fx, fy, near)
        if self.robe or self.skirt:
            hem = FY - (3 if self.robe else 10)
            wb = B["hip"] * 0.95
            sk = smooth([(CX - db, W - 2), (CX - wb * 1.25 - sway, hem - 2), (CX - wb * 0.2 - sway, hem + 1), (CX + wb * 1.15 - sway * 0.5, hem - 2),
                         (CX + db * 1.05, W - 2)], t=0.4)
            self.sh(sk, "shirt" if self.robe else "skirt", s=3.5)
            self.det(f"M{CX-2:.1f},{W+12:.1f} Q{CX-4-sway:.1f},{hem-10:.1f} {CX-6-sway:.1f},{hem-1:.1f} M{CX+wb*0.5:.1f},{W+14:.1f} L{CX+wb*0.7-sway:.1f},{hem-2:.1f}", "shirt", 0.6, 0.7)
        # torso ----------------------------------------------------------------
        bel = max(db, d * 0.9)
        tp = [(CX - 3, S - 4), (CX - d * 0.85, S + 1), (CX - d * 0.95, S + 14), (CX - db * 0.95, W), (CX - B["hip"] * 0.72, Hp + 4),
              (CX + B["hip"] * 0.62, Hp + 4), (CX + bel * 1.02, W), (CX + d * 1.0, S + (W - S) * 0.42), (CX + d * 0.75, S + 1), (CX + 4, S - 4)]
        self.sh(smooth(tp, t=0.42), "shirt", s=3.5)
        self.armor_side(d, db, bel)
        # head -----------------------------------------------------------------
        self.head_side()
        # near arm and item ------------------------------------------------------
        self.arm_side(far=False, d=d)
        if self.shield_arm:
            x, y = CX + d + 8, W - 4
            self.sh(smooth([(x - 5, y - 18), (x + 4, y - 19), (x + 6, y), (x + 2, y + 19), (x - 4, y + 13), (x - 6, y)], t=0.4), "metal", s=1.5)
            role = "cloak" if L.get("cloak") else "apron"
            self.sh(smooth([(x - 2, y - 15), (x + 3, y - 16), (x + 4, y), (x + 1, y + 15), (x - 2, y + 10), (x - 3, y)], t=0.4),
                    "shirt" if self.cid == "garrick" else role, s=1, hl=False)
            self.sh(ell(x + 1, y - 2, 2.4, 3.4), "metal", s=0.6)
        if self.lute_front:
            self.lute(CX + d * 0.6, W + 2, -40, front=True)

    def leg_side(self, fx, fy, near):
        B = self.B
        hip = (CX + (1.5 if near else -1.5), self.Hp - 6)
        w = B["lw"]
        if not (self.robe or self.skirt):
            self.sh(capsule(hip, (fx, fy - 10), w, w * 0.84), "trouser", s=2.6 if near else 2.0,
                    fill_override=None if near else mix(self.P.c("trouser"), "#20140c", 0.25))
            if self.armor == "plate":
                kx, ky = (hip[0] + fx) / 2, (hip[1] + fy) / 2 + 2
                self.sh(capsule((kx, ky), (fx, fy - 11), w * 0.95, w * 0.9), "metal", s=2)
                self.sh(ell(kx + 2, ky, w * 0.7, w * 0.6), "metal", s=1.2)
        bare = self.look.get("build") == "halfling"
        role = "skin" if bare else "boot"
        if bare:
            self.sh(smooth([(fx - w * 0.9, fy - 8), (fx + w * 0.6, fy - 8), (fx + w * 1.8, fy - 2), (fx + w * 1.7, fy + 1), (fx - w, fy + 1)], t=0.4), role, s=1.4)
        else:
            self.sh(smooth([(fx - w * 0.95, fy - 16), (fx + w * 0.8, fy - 16), (fx + w * 0.9, fy - 7), (fx + w * 2.0, fy - 4), (fx + w * 2.0, fy + 0.5),
                            (fx - w * 1.0, fy + 0.5)], t=0.35), role, s=1.8)
            self.det(f"M{fx-w*0.95:.1f},{fy-12:.1f} L{fx+w*0.8:.1f},{fy-12:.1f}", "boot", 0.7, 0.8)

    def armor_side(self, d, db, bel):
        B = self.B
        S, W, Hp = self.S, self.W, self.Hp
        a = self.armor
        if a == "leather":
            self.sh(smooth([(CX - d * 0.8, S + 3), (CX - d * 0.92, S + 14), (CX - db * 0.95, W + 1), (CX - B["hip"] * 0.72, Hp + 2),
                            (CX + B["hip"] * 0.62, Hp + 2), (CX + bel * 1.02, W + 1), (CX + d, S + (W - S) * 0.42), (CX + d * 0.6, S + 2)], t=0.42), "leather", s=3)
            self.det(f"M{CX+d*0.85:.1f},{S+10:.1f} L{CX+bel*0.95:.1f},{Hp:.1f}", "leather", 0.6, 0.8)
            self.belt_side(db, bel, W + 1)
        elif a == "plate":
            self.sh(smooth([(CX - db * 0.7, W), (CX - db * 0.75, Hp + 16), (CX + bel * 0.9, Hp + 18), (CX + bel * 0.9, W)], t=0.3), "shirt", s=2.5)
            self.sh(smooth([(CX - d * 0.9, S + 3), (CX - d * 0.95, S + 14), (CX - db * 0.95, W + 2), (CX + bel * 1.04, W + 3),
                            (CX + d * 1.04, S + (W - S) * 0.42), (CX + d * 0.7, S + 1)], t=0.42), "metal", s=3.5)
            self.belt_side(db, bel, W + 3)
            self.sh(ell(CX, S + 4, self.B["ar"] * 1.5, self.B["ar"] * 1.15), "metal", s=2.4)
        elif a == "apron":
            if self.cid == "player":
                self.sh(smooth([(CX + d * 0.55, S + 6), (CX + d * 1.08, S + (W - S) * 0.42), (CX + bel * 1.1, W), (CX + B["hip"] * 0.95, FY - 32),
                                (CX + B["hip"] * 0.5, FY - 31), (CX + B["hip"] * 0.4, W)], t=0.35), "apron", s=2.5)
                self.det(f"M{CX+d*0.6:.1f},{S+6:.1f} L{CX+2:.1f},{S-3:.1f}", "strap", 1.4)
            else:
                bot = FY - 24 if not self.skirt else FY - 22
                self.sh(smooth([(CX + d * 0.55, S + 10), (CX + d * 1.06, S + (W - S) * 0.5), (CX + bel * 1.08, W), (CX + B["hip"] * 1.05, bot),
                                (CX + B["hip"] * 0.55, bot + 1), (CX + B["hip"] * 0.45, W)], t=0.35), "linen" if self.skirt else "apron", s=2)
            self.belt_side(db, bel, W, buckle=False)
        elif a == "robe":
            self.belt_side(db, bel, W, buckle=False, role="straw")
        else:
            if not self.skirt:
                self.sh(smooth([(CX - db, W), (CX - B["hip"] * 0.8, Hp + 8), (CX + B["hip"] * 0.75, Hp + 8), (CX + bel * 1.02, W)], t=0.35), "shirt", s=2)
            self.belt_side(db, bel, W, buckle=False)

    def belt_side(self, db, bel, y, buckle=True, role="strap"):
        self.sh(smooth([(CX - db * 1.0, y - 3), (CX + bel * 1.06, y - 3), (CX + bel * 1.06, y + 3), (CX - db * 1.0, y + 3)], t=0.2), role, s=1, hl=False)
        if buckle:
            self.sh(rect(CX + bel * 0.75, y - 3, 5, 6.5, 1), "gold", s=0.6, hl=False)

    def arm_side(self, far, d):
        B, P = self.B, self.P
        S, W, Hp = self.S, self.W, self.Hp
        sw = (self.step if far else -self.step)   # arms swing opposite to the leg on their side
        sx, sy = CX + (3 if far else -1), S + B["ar"] * 0.9
        pose = "down"
        if not far:
            pose = self.pose_for(True, 1)
        elif self.shield_arm:
            pose = "shield"
        elif self.lute_front:
            pose = "chest"
        if pose == "raised":
            ex_, ey_ = CX + 2, S + (W - S) * 0.8
            hx, hy = CX + d + 7, W + 2
        elif pose == "chest":
            ex_, ey_ = CX + 2, W + 2
            hx, hy = CX + d + 5, S + (W - S) * 0.62
        elif pose == "shield":
            ex_, ey_ = CX + 4, S + (W - S) * 0.85
            hx, hy = CX + d + 6, W - 2
        else:
            ex_, ey_ = CX + sw * 5, S + (Hp - S) * 0.5
            hx, hy = CX + sw * 12, Hp + 2 - abs(sw) * 2
        sleeve = self.sleeve_role()
        fore = "metal" if self.armor == "plate" else sleeve
        dark = (lambda r: mix(self.P.c(r), "#20140c", 0.28)) if far else (lambda r: None)
        if not far:
            pass
        else:
            if self.hand == "dagger" and not self.lute_front:
                self.held_side(hx, hy, off=True, behind=True)
        if not far and self.hand in ("sword", "mace", "axe", "pick", "staff", "bow", "hammer"):
            self.held_side(hx, hy, before_hand=True)
        self.sh(capsule((sx, sy), (ex_, ey_), B["ar"], B["ar"] * 0.92), sleeve, s=2.4, fill_override=dark(sleeve))
        self.sh(capsule((ex_, ey_), (hx, hy), B["ar"] * 0.9, B["ar"] * 0.78), fore, s=2, fill_override=dark(fore))
        if self.robe:
            self.sh(ell((ex_ + hx) / 2, (ey_ + hy) / 2 + 3, B["ar"] * 1.2, B["ar"] * 0.9), "shirt", s=1.6, fill_override=dark("shirt"))
        hr = "metal" if self.armor == "plate" else "skin"
        self.sh(ell(hx, hy, B["hd"], B["hd"] * 1.05), hr, s=1.4, fill_override=dark(hr))
        if not far:
            self.held_side(hx, hy, before_hand=False)

    def held_side(self, hx, hy, before_hand=True, off=False, behind=False):
        """Held item in the near (right) hand while facing right."""
        P = self.P
        h = "dagger" if off else self.hand
        o = []
        if h in ("sword", "mace", "axe", "pick", "staff", "bow"):
            ang = {"sword": -70, "mace": -78, "axe": -72, "pick": -66, "staff": -88, "bow": -90}[h]
            # reuse the front-view item drawn at an angle (out=+1: blades point away from the body)
            save = self.o
            self.o = o
            self._item_angled(h, hx, hy, ang, before_hand)
            self.o = save
        elif h == "hammer":
            save = self.o
            self.o = o
            self._item_angled(h, hx, hy, 80, before_hand)
            self.o = save
        elif h == "dagger":
            if not before_hand or off:
                f = frame_xf(hx, hy, 60 if not off else 70)
                o.append(P.shape(lpoly(f, [(5, -2.6), (26, -1.8), (31, 0), (26, 1.8), (5, 2.6)]), "metal", s=1))
                o.append(P.shape(lpoly(f, [(3, -6), (6, -6), (6, 6), (3, 6)]), "darkiron", s=0.6))
        elif h == "basket" and not before_hand:
            bx, by = hx + 2, hy + 11
            o.append(P.detail(f"M{bx-10:.1f},{by-2:.1f} Q{bx:.1f},{by-20:.1f} {bx+10:.1f},{by-2:.1f}", "wood", 1.6))
            o.append(P.shape(smooth([(bx - 12, by - 3), (bx + 12, by - 3), (bx + 10, by + 9), (bx - 10, by + 9)], t=0.3), "wood", s=2))
            o.append(P.shape(ell(bx - 4, by - 4, 4, 3), "apron", s=1))
            o.append(P.shape(ell(bx + 4, by - 4, 3.4, 3.4), "apple", s=1))
        elif h == "tankard" and not before_hand:
            tx, ty = hx + 3, hy - 7
            o.append(P.shape(rect(tx - 6, ty - 6, 12, 15, 2), "wood", s=1.6))
            o.append(P.detail(f"M{tx-6},{ty-2} h12 M{tx-6},{ty+5} h12", "darkiron", 0.8))
            o.append(P.shape(ell(tx, ty - 6, 6, 2.2), "linen", s=0.5, lw=1))
        self.o.extend(o)

    def _item_angled(self, h, hx, hy, ang, before_hand):
        """Draw a shafted item with the shaft along `ang` (side view)."""
        P = self.P
        f = frame_xf(hx, hy, ang)
        out = 1
        if h == "sword":
            if before_hand:
                self.sh(lpoly(f, [(-9, -1.8), (6, -1.8), (6, 1.8), (-9, 1.8)]), "leather", s=0.8)
                self.sh(lell(f, -11, 0, 2.6, 2.6), "gold", s=0.8)
            else:
                self.sh(lpoly(f, [(10, -3.4), (66, -2.6), (74, 0), (66, 2.6), (10, 3.4)]), "metal", s=1.6)
                self.det(lline(f, (12, 0), (64, 0)), "metal", 0.6, 0.8)
                self.sh(lsmooth(f, [(6, -12), (10, -12), (10, 12), (6, 12)], t=0.2), "gold", s=0.8)
        elif h == "mace":
            if before_hand:
                self.sh(lpoly(f, [(-10, -2.4), (40, -2.4), (40, 2.4), (-10, 2.4)]), "wood", s=1)
            else:
                fl = [(46 + math.cos(i / 12 * math.tau) * (10 if i % 2 == 0 else 6.5), math.sin(i / 12 * math.tau) * (10 if i % 2 == 0 else 6.5)) for i in range(12)]
                self.sh(lsmooth(f, fl, t=0.3), "metal", s=2.2)
                self.sh(lell(f, 46, 0, 3.4, 3.4), "metal", s=1, hl=False)
        elif h == "axe":
            if before_hand:
                self.sh(lpoly(f, [(-26, -2.6), (70, -2.6), (70, 2.6), (-26, 2.6)]), "wood", s=1.2)
            else:
                bl = [(50, 2), (46, 10), (40, 20), (56, 24), (72, 20), (66, 10), (64, 2)]
                self.sh(lsmooth(f, bl, t=0.35), "metal", s=2)
                self.sh(lsmooth(f, [(52, -2), (50, -9), (58, -13), (64, -9), (62, -2)], t=0.35), "metal", s=1.2)
                self.sh(lpoly(f, [(48, -4), (66, -4), (66, 4), (48, 4)]), "darkiron", s=0.8)
        elif h == "pick":
            if before_hand:
                self.sh(lpoly(f, [(-14, -2.6), (64, -2.6), (64, 2.6), (-14, 2.6)]), "wood", s=1.2)
            else:
                head = [(62, -26), (66, -14), (68, 0), (66, 14), (62, 26), (70, 14), (72, 0), (70, -14)]
                self.sh(lsmooth(f, head, t=0.4), "metal", s=1.8)
                self.sh(lpoly(f, [(60, -4.5), (72, -4.5), (72, 4.5), (60, 4.5)]), "darkiron", s=0.8)
        elif h == "staff":
            if before_hand:
                self.sh(lsmooth(f, [(-58, -2.2), (44, -2.8), (64, -3.2), (64, 3.2), (44, 2.8), (-58, 2.2)], t=0.1), "wood", s=1.2)
            else:
                self.sh(lsmooth(f, [(62, -7), (72, -9), (82, -5), (84, 0), (82, 5), (72, 9), (62, 7)], t=0.5), "wood", s=1.6)
                gx, gy = f(74, 0)
                self.add(glow(P, gx, gy, 13, EMBER, 0.5))
                self.sh(lell(f, 74, 0, 4.2, 4.2), "gem", s=1.2)
        elif h == "bow":
            if before_hand:
                arc = [(-56, 0), (-30, 7), (0, 11), (30, 7), (56, 0), (30, 4.5), (0, 7.5), (-30, 4.5)]
                self.sh(lsmooth(f, arc, t=0.45), "wood", s=1.2)
                self.det(lline(f, (-55, -0.5), (55, -0.5)), None, 0.35, 0.85)
        elif h == "hammer":
            big = self.cid == "player" or self.look.get("build") == "heavy"
            if big:
                if before_hand:
                    self.sh(lpoly(f, [(-12, -3), (40, -3), (40, 3), (-12, 3)]), "wood", s=1.2)
                else:
                    self.sh(lpoly(f, [(38, -16), (57, -16), (57, 16), (38, 16)]), "metal", s=2.4)
                    self.sh(lpoly(f, [(36, -18), (40, -18), (40, 18), (36, 18)]), "darkiron", s=0.8)
                    self.sh(lpoly(f, [(55, -18), (59, -18), (59, 18), (55, 18)]), "darkiron", s=0.8)
            else:
                if before_hand:
                    self.sh(lpoly(f, [(-6, -2), (26, -2), (26, 2), (-6, 2)]), "wood", s=0.8)
                else:
                    self.sh(lsmooth(f, [(24, -10), (28, -9), (30, 0), (28, 8), (32, 14), (26, 12), (24, 2)], t=0.3), "metal", s=1.2)

    def back_items_side(self, d):
        B = self.B
        S, W, Hp = self.S, self.W, self.Hp
        b = self.back
        if b == "quiver":
            f = frame_xf(CX - d * 0.9, W + 6, -90 - 28)
            self.sh(lpoly(f, [(0, -5.5), (50, -6.5), (50, 6.5), (0, 5.5)]), "leather", s=2)
            self.det(lline(f, (14, -6), (14, 6)) + " " + lline(f, (38, -6.5), (38, 6.5)), "strap", 1.0)
            for i, dv in enumerate((-4, 0, 4)):
                self.sh(lell(f, 56 + (i % 2) * 3, dv, 5, 2.6), "linen", s=0.8, fill_override=["#e8dcc0", "#8e3e3c", "#e8dcc0"][i])
        elif b == "pack":
            top = S - 8
            w = B["sh"] * 0.5
            x1 = CX - d * 0.8
            self.sh(rect(x1 - w, top, w + 4, (W - top) + 8, 6), "leather", s=3)
            self.sh(rect(x1 - w - 3, top - 9, w + 10, 11, 5), "blue", s=1.5, fill_override="#8a8a6e")
            self.sh(rect(x1 - w * 0.8, top + 6, w * 0.6, (W - top) * 0.5, 3), "leather", s=1.2, hl=False)
            self.sh(ell(x1 - w * 0.5, W - 2, 4.5, 6), "metal", s=1)
        if b in ("pack", "quiver", "shield", "lute"):
            pass

    def hair_behind_side(self):
        B, L = self.B, self.look
        hx, hy, rx, ry = CX + 2, self.hcy, B["hrx"], B["hry"]
        hair = L.get("hair", "short")
        if hair == "long":
            ln = ry * (2.6 if self.fem else 2.2)
            self.sh(smooth([(hx - rx * 0.2, hy - ry * 0.8), (hx - rx * 1.15, hy - ry * 0.2), (hx - rx * 1.3, hy + ln * 0.7), (hx - rx * 0.9, hy + ln),
                            (hx - rx * 0.1, hy + ln * 0.9), (hx + rx * 0.2, hy + ry * 0.4)], t=0.45), "hair", s=2.5)
        elif hair == "ponytail":
            self.sh(smooth([(hx - rx * 0.8, hy - ry * 0.3), (hx - rx * 1.25, hy + ry * 0.3), (hx - rx * 1.35 - self.step, hy + ry * 1.8),
                            (hx - rx * 1.05, hy + ry * 2.2), (hx - rx * 0.85, hy + ry * 0.6)], t=0.45), "hair", s=1.6)
        elif hair == "braid":
            for i in range(6):
                self.sh(ell(hx - rx * 0.95 - i * 0.6, hy + ry * 0.4 + i * 6, 3.6, 4), "hair", s=1, lw=1.6)

    def head_side(self):
        B, L, P = self.B, self.look, self.P
        hx, hy, rx, ry = CX + 2, self.hcy, B["hrx"] * 0.96, B["hry"]
        ex = self.ex
        hair = L.get("hair", "short")
        if "hood_down" in ex:
            self.sh(smooth([(hx - rx * 1.3, self.S + 2), (hx - rx * 1.2, self.S - 9), (hx - rx * 0.2, self.S - 6), (hx, self.S + 4)], t=0.45), "hoodc", s=2)
        self.sh(rect(hx - rx * 0.45, hy + ry * 0.5, rx * 0.8, (self.S + 3) - (hy + ry * 0.5), 3), "skin", s=1.4, hl=False)
        if hair == "hood":
            self.sh(smooth([(hx - rx * 1.3, hy + ry * 0.6), (hx - rx * 1.25, hy - ry * 0.6), (hx - rx * 0.2, hy - ry * 1.25), (hx + rx * 0.9, hy - ry * 0.85),
                            (hx + rx * 1.05, hy - ry * 0.1), (hx + rx * 0.4, hy + ry * 1.2), (hx - rx * 0.6, hy + ry * 1.5)], t=0.45), "hoodc", s=3)
        if hair == "curly":
            self.sh(blob(hx - rx * 0.2, hy - ry * 0.3, rx * 1.22, 10, 0.1, 7, squash=ry / rx * 0.95), "hair", s=3)
        # head with nose and chin
        hd = smooth([(hx - rx, hy), (hx - rx * 0.8, hy - ry * 0.8), (hx, hy - ry), (hx + rx * 0.82, hy - ry * 0.7), (hx + rx * 0.98, hy - ry * 0.1),
                     (hx + rx * 1.22, hy + ry * 0.18), (hx + rx * 0.98, hy + ry * 0.36), (hx + rx * 0.9, hy + ry * 0.75), (hx + rx * 0.3, hy + ry * 1.0),
                     (hx - rx * 0.6, hy + ry * 0.7)], t=0.45)
        self.sh(hd, "skin", s=2.6)
        # hair
        if hair in ("short", "cropped", "braid", "ponytail", "bun", "long"):
            k = 1.06 if hair != "cropped" else 1.02
            pts = [(hx + rx * 0.62, hy - ry * 0.55), (hx + rx * 0.5, hy - ry * k), (hx - rx * 0.3, hy - ry * (k + 0.04)), (hx - rx * k, hy - ry * 0.45),
                   (hx - rx * k, hy + ry * 0.35), (hx - rx * 0.7, hy + ry * (0.8 if hair == "long" else 0.6)), (hx - rx * 0.25, hy + ry * 0.2),
                   (hx - rx * 0.2, hy - ry * 0.25), (hx + rx * 0.2, hy - ry * 0.45)]
            self.sh(smooth(pts, t=0.45), "hair", s=2.2)
            if hair == "bun":
                self.sh(ell(hx - rx * 0.85, hy - ry * 0.75, 6, 5.5), "hair", s=1.4)
        elif hair == "mohawk":
            self.sh(smooth([(hx + rx * 0.6, hy - ry * 0.85), (hx + rx * 0.2, hy - ry - 9), (hx - rx * 0.6, hy - ry - 6), (hx - rx * 1.05, hy - ry * 0.3),
                            (hx - rx * 0.7, hy - ry * 0.55), (hx, hy - ry * 0.9)], t=0.4), "hair", s=1.5)
        elif hair == "bald":
            if "scalp_scar" in ex:
                self.add(lin(f"M{hx-rx*0.1:.1f},{hy-ry*0.95:.1f} l{rx*0.4:.1f},{ry*0.35:.1f}", "#8a4a3a", 1.3))
        elif hair == "bald_fringe":
            self.sh(smooth([(hx - rx * 1.02, hy - ry * 0.4), (hx - rx * 0.2, hy - ry * 0.05), (hx - rx * 0.1, hy + ry * 0.35), (hx - rx * 0.85, hy + ry * 0.62)], t=0.45), "hair", s=1.2)
            if "scalp_scar" in ex:
                self.add(lin(f"M{hx-rx*0.1:.1f},{hy-ry*0.95:.1f} l{rx*0.4:.1f},{ry*0.35:.1f}", "#8a4a3a", 1.3))
        elif hair == "curly":
            for i in range(4):
                self.sh(ell(hx + rx * (0.45 - i * 0.12), hy - ry * (0.85 - i * 0.05), 4.6, 4.4), "hair", s=1, lw=1.5)
        elif hair == "hood":
            self.det(f"M{hx+rx*0.8:.1f},{hy-ry*0.8:.1f} Q{hx+rx*1.1:.1f},{hy:.1f} {hx+rx*0.5:.1f},{hy+ry*1.1:.1f}", "hoodc", 1.2)
        # ear
        if "pointed_ears" in ex:
            self.sh(poly([(hx - rx * 0.25, hy - 1), (hx - rx * 1.0, hy - 11), (hx - rx * 0.1, hy + 5)]), "skin", s=1)
        elif hair not in ("long", "hood"):
            self.sh(ell(hx - rx * 0.12, hy + 1, 3.4, 4.6), "skin", s=1)
        # eye, brow, mouth
        ey = hy + ry * 0.04
        if "eyepatch" in ex:
            self.add(lin(f"M{hx-rx*0.8:.1f},{hy-ry*0.6:.1f} L{hx+rx*0.9:.1f},{ey:.1f}", "#2a1c12", 1.1))
        self.add(fill(ell(hx + rx * 0.62, ey, 1.4, 1.7), INK))
        self.add(lin(f"M{hx+rx*0.42:.1f},{ey-4.4:.1f} L{hx+rx*0.86:.1f},{ey-4.6:.1f}", INK, 1.0, 0.85))
        beard = L.get("beard", "none")
        if beard in ("none", "stubble"):
            self.add(lin(f"M{hx+rx*0.92:.1f},{hy+ry*0.56:.1f} l-3,0.6", "#6a3a2a", 1.0, 0.9))
        if "tusks" in ex:
            self.sh(poly([(hx + rx * 0.7, hy + ry * 0.62), (hx + rx * 0.95, hy + ry * 0.25), (hx + rx * 1.0, hy + ry * 0.62)]), "ivory", s=0.5, lw=1.4)
        if beard == "stubble":
            self.add(fill(smooth([(hx + rx * 0.1, hy + ry * 0.3), (hx + rx * 0.95, hy + ry * 0.45), (hx + rx * 0.85, hy + ry * 0.85), (hx + rx * 0.2, hy + ry * 0.95)]),
                          f"url(#{P.xhatch_id})", 0.5))
        elif beard != "none":
            ln = {"short": ry * 1.25, "long": ry * (2.7 if L.get("build") == "dwarf" else 2.3), "braided": ry * 1.4}[beard]
            sw = self.step * 1.0
            pts = [(hx - rx * 0.05, hy + ry * 0.2), (hx + rx * 0.55, hy + ry * 0.35), (hx + rx * 1.05, hy + ry * 0.45), (hx + rx * 1.05, hy + ry * 0.9),
                   (hx + rx * 0.7 + sw, hy + ln), (hx + rx * 0.2 + sw, hy + ln * 0.9), (hx - rx * 0.2, hy + ry * 0.75)]
            self.sh(smooth(pts, t=0.45), "beard", s=2)
            if beard == "braided":
                for i in range(4):
                    self.sh(ell(hx + rx * 0.45 + sw, hy + ln + i * 6.0, 4.2 - i * 0.4, 3.6), "beard", s=1, lw=1.6)
                self.sh(rect(hx + rx * 0.45 + sw - 4, hy + ln + 3.4 * 6.0 - 1, 8, 3.4, 1), "metal", s=0.6)
            else:
                self.det(f"M{hx+rx*0.5:.1f},{hy+ry*0.8:.1f} L{hx+rx*0.5+sw:.1f},{hy+ln*0.85:.1f}", "beard", 0.6, 0.7)
        if "spectacles" in ex:
            self.add(f'<ellipse cx="{hx+rx*0.7:.1f}" cy="{ey:.1f}" rx="2.2" ry="3.4" fill="#eef4f0" fill-opacity="0.35" stroke="{INK}" stroke-width="1.1"/>')
            self.add(lin(f"M{hx+rx*0.6:.1f},{ey-1:.1f} L{hx-rx*0.15:.1f},{ey-0.6:.1f}", INK, 0.9, 0.9))
        if "headscarf" in ex:
            self.headscarf(hx, hy, rx, ry, "E")
        if "helmet_miner" in ex:
            self.miner_helmet(hx, hy, rx, ry, "E")
        if "spectacles" in ex:
            self.det(ell(hx + rx * 0.62, ey, 3.2, 3.0), None, 0.9)
            self.add(lin(f"M{hx+rx*0.3:.1f},{ey-1:.1f} L{hx-rx*0.2:.1f},{ey-2:.1f}", INK, 0.8))
        if "helmet_m1" in ex:
            self.m1_helmet(hx, hy, rx, ry, "E")
        if "pauldron" in ex:
            pass

    # ============================================================ entry
    def draw(self):
        if self.view == "S":
            self.front()
        elif self.view == "N":
            self.backv()
        else:
            self.side()
        return J(self.o)


def figure(P, look, view, fr):
    return Fig(P, look, view, fr).draw()


# ------------------------------------------------------------------ bases
BASE_TINT = {
    "player": "#9a7440",      # warm bronze
    "hireling": "#6e6250",    # mine-floor slate brown
    "adventurer": "#6a7072",  # slate
    "villager": "#7a6040",    # earth
    "applicant_look": "#7e6a4c",
    "companion": "#5a2e46",   # deep plum
    "animal": "#6e6a44",      # mossy earth
}


def base(P, kind, rx=60.0, ry=15.0, rim=8.0, seed=1, cy=FY + 1):
    """Round miniature base: dark painted rim, tinted top with a hint of grass / flagstone, soft contact shadow.
    Returns (shadow_svg, base_svg)."""
    rnd = random.Random(seed)
    tint = BASE_TINT.get(kind, BASE_TINT["villager"])
    top = tri(tint, 0.0)
    pal = P.pal
    pal["basetop"] = top
    pal["baserim"] = ("#4a3624", "#2a1c12", "#140c06")
    # contact shadow (offset to bottom-right, soft + hatched)
    bf = blur_filter(P, 3.2)
    h = hatch(P, -35, sp=4.4, w=1.0)
    sh = (f'<ellipse cx="{CX+5:.1f}" cy="{cy+rim+3:.1f}" rx="{rx+4:.1f}" ry="{ry+5:.1f}" fill="{INK}" opacity="0.30" {bf}/>'
          f'<path d="M{CX-rx*0.2:.1f},{cy+rim+ry+3:.1f} A{rx+5:.1f},{ry+5:.1f} 0 0 0 {CX+rx+7:.1f},{cy+rim+2:.1f} '
          f'A{rx+2:.1f},{ry+2:.1f} 0 0 1 {CX-rx*0.2:.1f},{cy+rim+ry:.1f} Z" fill="{h}" opacity="0.55"/>')
    o = []
    # rim (cylinder side)
    side = (f"M{CX-rx:.1f},{cy:.1f} L{CX-rx:.1f},{cy+rim:.1f} A{rx:.1f},{ry:.1f} 0 0 0 {CX+rx:.1f},{cy+rim:.1f} "
            f"L{CX+rx:.1f},{cy:.1f} A{rx:.1f},{ry:.1f} 0 0 1 {CX-rx:.1f},{cy:.1f} Z")
    o.append(P.shape(side, "baserim", s=3, hl=False))
    o.append(lin(f"M{CX-rx+3:.1f},{cy+rim*0.55:.1f} A{rx-2:.1f},{ry:.1f} 0 0 0 {CX-rx*0.2:.1f},{cy+ry+rim*0.7:.1f}", "#6a5240", 1.2, 0.7))
    # top face
    o.append(P.shape(ell(CX, cy, rx, ry), "basetop", s=3))
    o.append(lin(ell(CX, cy, rx - 2.5, ry - 1.4), "#20140c", 0.6, 0.35))
    # surface: flagstones / grass / gilt ring
    if kind in ("adventurer", "player", "hireling"):
        cracks = []
        for i in range(5):
            a = rnd.uniform(0, math.tau)
            r1 = rnd.uniform(0.35, 0.9)
            x, y = CX + math.cos(a) * rx * r1, cy + math.sin(a) * ry * r1
            cracks.append(f"M{x:.1f},{y:.1f} l{rnd.uniform(-9,9):.1f},{rnd.uniform(-2.5,2.5):.1f} l{rnd.uniform(-6,6):.1f},{rnd.uniform(-2,2):.1f}")
        o.append(lin(" ".join(cracks), INK, 0.8, 0.55))
        for i in range(4):
            a = rnd.uniform(0, math.tau)
            r1 = rnd.uniform(0.5, 0.85)
            x, y = CX + math.cos(a) * rx * r1, cy + math.sin(a) * ry * r1
            o.append(fill(ell(x, y, rnd.uniform(1.6, 3), rnd.uniform(1, 1.8)), top[0], 0.8))
            o.append(lin(ell(x, y, 2.4, 1.4), INK, 0.5, 0.5))
        if kind == "player":
            o.append(fill(ell(CX + rx * 0.45, cy + ry * 0.3, 6, 2.2), "#2a1c12", 0.25))
    if kind in ("villager", "applicant_look", "animal", "hireling"):
        tufts = []
        for i in range(9 if kind != "hireling" else 3):
            a = rnd.uniform(0, math.tau)
            r1 = rnd.uniform(0.45, 0.92)
            x, y = CX + math.cos(a) * rx * r1, cy + math.sin(a) * ry * r1
            tufts.append(f"M{x-2:.1f},{y:.1f} l-1,-4 M{x:.1f},{y:.1f} l0.5,-5 M{x+2:.1f},{y:.1f} l1.5,-3.5")
        o.append(lin(" ".join(tufts), "#4e5a30", 1.4, 0.9))
        o.append(lin(" ".join(tufts), "#9aa46a", 0.6, 0.9))
    if kind == "companion":
        o.append(lin(ell(CX, cy, rx - 6, ry - 3.6), GILT, 0.9, 0.7))
        for i in range(6):
            a = rnd.uniform(0, math.tau)
            x, y = CX + math.cos(a) * rx * 0.75, cy + math.sin(a) * ry * 0.75
            o.append(fill(ell(x, y, 1.2, 0.8), "#c8a8c0", 0.7))
    # figure's own soft shadow on the base top (fixed)
    o.append(f'<ellipse cx="{CX+6:.1f}" cy="{cy+2:.1f}" rx="{rx*0.42:.1f}" ry="{ry*0.42:.1f}" fill="{INK}" opacity="0.28" {blur_filter(P, 2.0)}/>')
    # rim highlight top-left
    o.append(lin(f"M{CX-rx+1.5:.1f},{cy-1:.1f} A{rx-1.5:.1f},{ry-1:.1f} 0 0 1 {CX-rx*0.1:.1f},{cy-ry+1:.1f}", top[0], 1.0, 0.6))
    return sh, J(o)


# ------------------------------------------------------------------ animals
ANIMALS = {
    "animal_cat_1": dict(kind="cat", fur="#c88a4a", fur2="#8a4e22", belly="#ecd6b0", stripes=True, eye="#7a8a2a"),
    "animal_cat_2": dict(kind="cat", fur="#3a3230", fur2="#1e1816", belly="#4a4240", stripes=False, eye="#c8a030"),
    "animal_dog_1": dict(kind="dog", fur="#8a5a34", fur2="#5a3418", belly="#c8a07a", shaggy=False, ears="drop"),
    "animal_dog_2": dict(kind="dog", fur="#9a968c", fur2="#5e5a52", belly="#c8c4b8", shaggy=True, ears="drop"),
}


def animal_palette(spec):
    pal = dict(ST["pal"])
    pal["fur"] = tri(spec["fur"], 0.04)
    pal["fur2"] = tri(spec["fur2"], 0.04)
    pal["belly"] = tri(spec["belly"], 0.04)
    pal["eye"] = ("#3a2a1e", "#20140c", "#100a06")
    return pal


class Beast:
    def __init__(self, P, spec, view, fr):
        self.P, self.sp, self.view, self.fr = P, spec, view, fr
        self.o = []
        self.cat = spec["kind"] == "cat"
        ph = fr["ph"]
        self.walk = fr["walk"]
        self.ph = ph
        self.bob = -2.2 * abs(math.sin(ph)) if self.walk else 0.0
        self.br = fr["breathe"]
        k = 1.0 if self.cat else 1.25
        self.k = k

    def sh(self, d, role, s=2, **kw):
        self.o.append(self.P.shape(d, role, s=s * SHADE, **kw))

    def det(self, d, role=None, w=1.0, op=1.0):
        self.o.append(self.P.detail(d, role, w, op))

    def draw(self):
        if self.view == "E":
            self.side()
        elif self.view == "S":
            self.front()
        else:
            self.back()
        return J(self.o)

    # proportions (design units)
    def dims(self):
        k = self.k
        if self.cat:
            return dict(bl=26 * k, bh=11 * k, hr=10.5, leg=15, lw=3.4, tail=30)
        return dict(bl=25, bh=13, hr=11.5, leg=19, lw=4.4, tail=22)

    # ---------------- side (facing right)
    def side(self):
        d = self.dims()
        P = self.P
        cat = self.cat
        y0 = FY + self.bob
        sit = not self.walk
        bl, bh, hr, leg, lw = d["bl"], d["bh"], d["hr"], d["leg"], d["lw"]
        if sit:
            # sitting: haunch at the back, upright chest, head high
            hx, hy = CX + 14, y0 - leg - bh - 18 - self.br * 0.8
            # tail curled round on the ground
            flick = 6 * self.br if cat else 0
            self.sh(smooth([(CX - 14, y0 - 4), (CX - 26, y0 - 4), (CX - 32, y0 - 14 - flick), (CX - 29, y0 - 18 - flick), (CX - 24, y0 - 9), (CX - 12, y0 - 9)], t=0.45), "fur", s=1.4)
            # far front leg
            self.sh(capsule((CX + 9, y0 - leg - 6), (CX + 11, y0 - 3), lw, lw * 0.9), "fur2", s=1.2)
            # haunch + body
            self.sh(smooth([(CX - 18, y0 - 2), (CX - 20, y0 - 18), (CX - 8, y0 - leg - bh - 2), (CX + 10, y0 - leg - bh - 10),
                            (CX + 18, y0 - leg - 4), (CX + 14, y0 - 2)], t=0.45), "fur", s=3)
            self.sh(ell(CX - 9, y0 - 11, 11, 10), "fur", s=2.4)
            self.sh(capsule((CX + 15, y0 - leg - 4), (CX + 16, y0 - 3), lw, lw * 0.9), "fur", s=1.4)
            self.sh(ell(CX + 18, y0 - 2, lw * 1.2, 2.4), "belly" if cat else "fur", s=0.8)
            self.sh(ell(CX - 4, y0 - 1.5, 5, 2.2), "fur", s=0.8)
            self.sh(smooth([(CX + 10, hy + 6), (CX + 20, hy + 10), (CX + 18, hy + 22), (CX + 12, hy + 20)], t=0.4), "belly", s=1, lw=1.2)
        else:
            sw = math.cos(self.ph)
            lift = math.sin(self.ph)
            by = y0 - leg - bh * 0.5
            hx, hy = CX + bl * 0.75 + 4, by - bh * 0.6 - 6
            tail_up = 1.0 if cat else 0.6
            # tail
            tx = CX - bl * 0.9
            if cat:
                self.sh(smooth([(tx + 4, by - 3), (tx - 6, by - 10), (tx - 10, by - 24 - 2 * sw), (tx - 6, by - 32 - 2 * sw), (tx - 3, by - 30), (tx - 5, by - 22), (tx + 2, by - 9), (tx + 6, by + 1)], t=0.45), "fur", s=1.4)
            else:
                self.sh(smooth([(tx + 4, by - 4), (tx - 8, by - 12 - 3 * sw), (tx - 16, by - 18 - 4 * sw), (tx - 13, by - 14), (tx - 4, by + 1)], t=0.45), "fur", s=1.4)
            # far legs (darker)
            for (lx, ph2) in ((CX + bl * 0.55, 0), (CX - bl * 0.6, math.pi)):
                s2 = math.cos(self.ph + ph2 + math.pi)
                l2 = max(0, math.sin(self.ph + ph2 + math.pi))
                self.sh(capsule((lx, by), (lx + s2 * 6, y0 - 2 - l2 * 4), lw, lw * 0.85), "fur2", s=1)
            # body
            self.sh(smooth([(CX - bl, by - bh * 0.2), (CX - bl * 0.7, by - bh * 0.95), (CX, by - bh * 0.9 - self.br * 0.5), (CX + bl * 0.7, by - bh * 1.05),
                            (CX + bl * 1.02, by - bh * 0.2), (CX + bl * 0.8, by + bh * 0.75), (CX, by + bh * 0.6), (CX - bl * 0.8, by + bh * 0.7)], t=0.45), "fur", s=3)
            self.sh(smooth([(CX - bl * 0.4, by + bh * 0.4), (CX + bl * 0.6, by + bh * 0.45), (CX + bl * 0.75, by + bh * 0.75), (CX - bl * 0.2, by + bh * 0.7)], t=0.4), "belly", s=1, lw=1.0)
            # near legs
            for (lx, ph2) in ((CX + bl * 0.6, math.pi), (CX - bl * 0.55, 0)):
                s2 = math.cos(self.ph + ph2 + math.pi)
                l2 = max(0, math.sin(self.ph + ph2 + math.pi))
                fx, fy = lx + s2 * 6, y0 - l2 * 4
                self.sh(capsule((lx, by), (fx, fy - 2), lw * 1.1, lw * 0.9), "fur", s=1.4)
                self.sh(ell(fx + 1.5, fy - 1.5, lw * 1.15, 2.4), "fur", s=0.6)
        self.head_side(hx, hy, d["hr"])
        if not self.cat and not sit:
            pass
        if self.sp.get("stripes"):
            if sit:
                self.det(f"M{CX-14},{y0-20} q3,4 0,8 M{CX-8},{y0-24} q3,4 0,8 M{CX-2},{y0-30} q3,4 1,7", "fur", 1.0, 0.8)
            else:
                by = y0 - d["leg"] - d["bh"] * 0.5
                self.det(" ".join(f"M{CX+x},{by-d['bh']*0.85:.1f} q-2,5 1,9" for x in (-16, -8, 0, 8)), "fur", 1.0, 0.8)
        if self.sp.get("shaggy"):
            by = (y0 - d["leg"] - d["bh"] * 0.5) if not sit else (y0 - 20)
            self.det(" ".join(f"M{CX+x},{by+4:.1f} l-2,5" for x in (-20, -12, -4, 4, 12)), "fur", 0.8, 0.8)

    def head_side(self, hx, hy, r):
        P = self.P
        if self.cat:
            # ears
            self.sh(poly([(hx - 7, hy - 6), (hx - 4, hy - 17), (hx + 2, hy - 8)]), "fur", s=1)
            self.sh(poly([(hx + 1, hy - 8), (hx + 6, hy - 18), (hx + 8, hy - 6)]), "fur", s=1)
            self.sh(smooth([(hx - r, hy), (hx - r * 0.6, hy - r * 0.85), (hx + r * 0.5, hy - r * 0.9), (hx + r * 1.05, hy - r * 0.1),
                            (hx + r * 1.15, hy + r * 0.35), (hx + r * 0.6, hy + r * 0.8), (hx - r * 0.5, hy + r * 0.8)], t=0.5), "fur", s=2)
            self.sh(ell(hx + r * 0.7, hy + r * 0.45, r * 0.42, r * 0.32), "belly", s=0.6, lw=1.0)
            self.o.append(fill(ell(hx + r * 0.35, hy - r * 0.15, 1.8, 1.6), self.sp["eye"]))
            self.o.append(fill(ell(hx + r * 0.4, hy - r * 0.15, 0.6, 1.4), INK))
            self.o.append(lin(f"M{hx+r*0.9:.1f},{hy+r*0.4:.1f} l7,-1 M{hx+r*0.9:.1f},{hy+r*0.5:.1f} l7,2", INK, 0.5, 0.7))
        else:
            # long muzzle, drop ear
            self.sh(smooth([(hx - r, hy + 2), (hx - r * 0.7, hy - r * 0.8), (hx + r * 0.3, hy - r * 0.95), (hx + r * 0.75, hy - r * 0.4),
                            (hx + r * 1.7, hy - r * 0.05), (hx + r * 1.85, hy + r * 0.45), (hx + r * 1.2, hy + r * 0.75), (hx - r * 0.2, hy + r * 0.95)], t=0.45), "fur", s=2)
            self.sh(ell(hx + r * 1.78, hy + r * 0.12, 3, 2.6), "eye", s=0.4, fill_override="#2a1c12")
            self.o.append(fill(ell(hx + r * 0.3, hy - r * 0.25, 1.6, 1.7), INK))
            self.o.append(lin(f"M{hx+r*1.75:.1f},{hy+r*0.55:.1f} q-6,2 -10,0", INK, 0.8, 0.8))
            ear = smooth([(hx - r * 0.5, hy - r * 0.7), (hx + r * 0.1, hy - r * 0.8), (hx + r * 0.0, hy + r * 0.5), (hx - r * 0.45, hy + r * 0.75), (hx - r * 0.7, hy)], t=0.45)
            self.sh(ear, "fur2", s=1)
            if self.sp.get("shaggy"):
                self.det(f"M{hx+r*1.2:.1f},{hy+r*0.7:.1f} l-1,4 M{hx+r*0.8:.1f},{hy+r*0.8:.1f} l-1,4", "fur", 0.8, 0.8)
            # collar
            self.sh(smooth([(hx - r * 0.75, hy + r * 0.7), (hx + r * 0.1, hy + r * 1.0), (hx + r * 0.1, hy + r * 1.35), (hx - r * 0.8, hy + r * 1.1)], t=0.3), "cloth", s=0.6, hl=False)

    # ---------------- front (facing viewer)
    def front(self):
        d = self.dims()
        P = self.P
        y0 = FY + self.bob
        cat = self.cat
        sit = not self.walk
        hr, lw, leg = d["hr"], d["lw"], d["leg"]
        if sit:
            hy = y0 - leg - 26 - self.br * 0.8
            # tail around feet
            flick = 3 * self.br
            self.sh(smooth([(CX - 14, y0 - 2), (CX + 16 + flick, y0 - 2), (CX + 22 + flick, y0 - 6), (CX + 18 + flick, y0 - 9), (CX + 4, y0 - 6), (CX - 12, y0 - 6)], t=0.45), "fur", s=1)
            # haunches
            for sd in (-1, 1):
                self.sh(ell(CX + sd * 11, y0 - 9, 9, 9), "fur", s=2)
            # chest
            self.sh(smooth([(CX - 12, y0 - 4), (CX - 11, hy + 6), (CX, hy + 2), (CX + 11, hy + 6), (CX + 12, y0 - 4)], t=0.45), "fur", s=2.6)
            self.sh(smooth([(CX - 6, hy + 10), (CX + 6, hy + 10), (CX + 5, y0 - 12), (CX - 5, y0 - 12)], t=0.45), "belly", s=1, lw=1.0)
            for sd in (-1, 1):
                self.sh(capsule((CX + sd * 6, hy + 16), (CX + sd * 6, y0 - 3), lw, lw * 0.95), "fur", s=1)
                self.sh(ell(CX + sd * 6, y0 - 2, lw * 1.15, 2.4), "fur", s=0.6)
        else:
            sw = math.cos(self.ph)
            lift = math.sin(self.ph)
            hy = y0 - leg - 18
            # rump behind
            self.sh(ell(CX, hy + 14, d["bh"] * 1.0, d["bh"] * 0.9), "fur2", s=1.5)
            if cat:
                self.sh(smooth([(CX + 4, hy + 8), (CX + 10, hy - 6), (CX + 9, hy - 16), (CX + 13, hy - 14), (CX + 14, hy - 4), (CX + 8, hy + 10)], t=0.45), "fur", s=1)
            # chest
            self.sh(smooth([(CX - d["bh"] * 0.95, hy + 22), (CX - d["bh"] * 0.85, hy + 4), (CX, hy), (CX + d["bh"] * 0.85, hy + 4), (CX + d["bh"] * 0.95, hy + 22),
                            (CX, hy + 28)], t=0.45), "fur", s=2.4)
            for sd in (-1, 1):
                lf = max(0.0, lift * sd)
                fx, fy = CX + sd * 6.5, y0 - lf * 4
                self.sh(capsule((CX + sd * 6.5, hy + 18), (fx, fy - 2), lw, lw * 0.9), "fur", s=1)
                self.sh(ell(fx, fy - 1.5, lw * 1.15, 2.4), "fur", s=0.6)
        self.head_front(CX, hy, hr)

    def head_front(self, hx, hy, r):
        P = self.P
        if self.cat:
            for sd in (-1, 1):
                self.sh(poly([(hx + sd * r * 0.85, hy - r * 0.2), (hx + sd * r * 0.75, hy - r * 1.45), (hx + sd * r * 0.15, hy - r * 0.75)]), "fur", s=1)
            self.sh(smooth([(hx - r * 1.05, hy), (hx - r * 0.7, hy - r * 0.85), (hx, hy - r * 0.95), (hx + r * 0.7, hy - r * 0.85), (hx + r * 1.05, hy),
                            (hx + r * 0.7, hy + r * 0.75), (hx, hy + r * 0.9), (hx - r * 0.7, hy + r * 0.75)], t=0.5), "fur", s=2)
            self.sh(ell(hx, hy + r * 0.45, r * 0.5, r * 0.35), "belly", s=0.6, lw=1.0)
            for sd in (-1, 1):
                self.o.append(fill(ell(hx + sd * r * 0.4, hy - r * 0.1, 2.0, 1.8), self.sp["eye"]))
                self.o.append(fill(ell(hx + sd * r * 0.4, hy - r * 0.1, 0.6, 1.5), INK))
                self.o.append(lin(f"M{hx+sd*r*0.4:.1f},{hy+r*0.45:.1f} l{sd*8},-1 M{hx+sd*r*0.4:.1f},{hy+r*0.55:.1f} l{sd*8},2", INK, 0.5, 0.6))
            self.o.append(fill(poly([(hx - 1.6, hy + r * 0.28), (hx + 1.6, hy + r * 0.28), (hx, hy + r * 0.42)]), "#8a4a3a"))
        else:
            for sd in (-1, 1):
                self.sh(smooth([(hx + sd * r * 0.6, hy - r * 0.75), (hx + sd * r * 1.25, hy - r * 0.5), (hx + sd * r * 1.3, hy + r * 0.5),
                                (hx + sd * r * 1.0, hy + r * 0.7), (hx + sd * r * 0.8, hy - r * 0.1)], t=0.45), "fur2", s=1)
            self.sh(smooth([(hx - r * 0.9, hy + 1), (hx - r * 0.7, hy - r * 0.85), (hx, hy - r * 0.95), (hx + r * 0.7, hy - r * 0.85), (hx + r * 0.9, hy + 1),
                            (hx + r * 0.55, hy + r * 0.95), (hx, hy + r * 1.1), (hx - r * 0.55, hy + r * 0.95)], t=0.5), "fur", s=2)
            self.sh(ell(hx, hy + r * 0.62, r * 0.5, r * 0.42), "belly", s=0.8, lw=1.0)
            self.o.append(fill(ell(hx, hy + r * 0.45, 2.8, 2.2), "#2a1c12"))
            for sd in (-1, 1):
                self.o.append(fill(ell(hx + sd * r * 0.38, hy - r * 0.15, 1.6, 1.7), INK))
            self.o.append(lin(f"M{hx-3:.1f},{hy+r*0.85:.1f} q3,1.5 6,0", INK, 0.7, 0.8))
            self.sh(smooth([(hx - r * 0.75, hy + r * 1.05), (hx + r * 0.75, hy + r * 1.05), (hx + r * 0.7, hy + r * 1.35), (hx - r * 0.7, hy + r * 1.35)], t=0.3), "cloth", s=0.6, hl=False)
            if self.sp.get("shaggy"):
                self.det(f"M{hx-r*0.5:.1f},{hy-r*0.85:.1f} l2,4 M{hx:.1f},{hy-r*0.95:.1f} l0,4 M{hx+r*0.5:.1f},{hy-r*0.85:.1f} l-2,4", "fur", 0.8, 0.8)
        if self.sp.get("stripes"):
            self.det(f"M{hx-3},{hy-r*0.85:.1f} l1,5 M{hx},{hy-r*0.9:.1f} l0,5 M{hx+3},{hy-r*0.85:.1f} l-1,5", "fur", 0.9, 0.8)

    # ---------------- back
    def back(self):
        d = self.dims()
        y0 = FY + self.bob
        cat = self.cat
        sit = not self.walk
        hr, lw, leg = d["hr"], d["lw"], d["leg"]
        if sit:
            hy = y0 - leg - 26 - self.br * 0.8
            self.sh(smooth([(CX - 14, y0 - 2), (CX - 16, y0 - 16), (CX - 9, hy + 8), (CX + 9, hy + 8), (CX + 16, y0 - 16), (CX + 14, y0 - 2)], t=0.45), "fur", s=3)
            flick = 4 * self.br
            self.sh(smooth([(CX - 2, y0 - 6), (CX + 2, y0 - 6), (CX + 14 + flick, y0 - 3), (CX + 22 + flick, y0 - 7), (CX + 20 + flick, y0 - 1), (CX + 6, y0 + 1), (CX - 3, y0 - 1)], t=0.45), "fur", s=1)
            hx = CX
        else:
            sw = math.cos(self.ph)
            lift = math.sin(self.ph)
            hy = y0 - leg - 18
            for sd in (-1, 1):
                lf = max(0.0, -lift * sd)
                fx, fy = CX + sd * 7.5, y0 - lf * 4
                self.sh(capsule((CX + sd * 7.5, hy + 14), (fx, fy - 2), lw * 1.1, lw * 0.9), "fur", s=1)
                self.sh(ell(fx, fy - 1.5, lw * 1.15, 2.4), "fur", s=0.6)
            self.sh(ell(CX, hy + 12, d["bh"] * 1.05, d["bh"] * 1.0), "fur", s=2.4)
            if cat:
                self.sh(smooth([(CX - 3, hy + 6), (CX - 5, hy - 10), (CX - 2, hy - 26 - sw * 2), (CX + 2, hy - 26 - sw * 2), (CX + 3, hy - 10), (CX + 3, hy + 6)], t=0.45), "fur", s=1)
            else:
                self.sh(smooth([(CX - 3, hy + 4), (CX - 4 + sw * 3, hy - 10), (CX + sw * 4, hy - 16), (CX + 4 + sw * 3, hy - 10), (CX + 3, hy + 4)], t=0.45), "fur", s=1)
            hy = hy - 6
            hx = CX
        # head from behind
        if self.cat:
            for sd in (-1, 1):
                self.sh(poly([(hx + sd * hr * 0.85, hy - hr * 0.2), (hx + sd * hr * 0.75, hy - hr * 1.45), (hx + sd * hr * 0.15, hy - hr * 0.75)]), "fur", s=1)
            self.sh(ell(hx, hy, hr * 1.02, hr * 0.92), "fur", s=2)
        else:
            self.sh(ell(hx, hy, hr * 0.92, hr * 0.95), "fur", s=2)
            for sd in (-1, 1):
                self.sh(smooth([(hx + sd * hr * 0.5, hy - hr * 0.8), (hx + sd * hr * 1.2, hy - hr * 0.5), (hx + sd * hr * 1.25, hy + hr * 0.5),
                                (hx + sd * hr * 0.9, hy + hr * 0.6)], t=0.45), "fur2", s=1)
            self.sh(smooth([(hx - hr * 0.8, hy + hr * 0.7), (hx + hr * 0.8, hy + hr * 0.7), (hx + hr * 0.75, hy + hr * 1.0), (hx - hr * 0.75, hy + hr * 1.0)], t=0.3), "cloth", s=0.6, hl=False)
        if self.sp.get("stripes"):
            self.det(f"M{CX-8},{hy+16:.1f} q8,3 16,0 M{CX-9},{hy+22:.1f} q9,3 18,0", "fur", 1.0, 0.8)


def animal(P, spec, view, fr):
    return Beast(P, spec, view, fr).draw()
