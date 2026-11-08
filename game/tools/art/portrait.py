"""Front-view head-and-shoulders portraits (256x256, transparent) in the Ink & Parchment /
Gothic Noir 80:20 rendering, driven by characters.json `look` plus a few per-character accents.
Drawn in a 512 design space and scaled by 0.5."""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import person  # noqa: E402  (also puts the exploration generator on sys.path)
from svgcore import Painter, ell, rect, poly, smooth, blob, uid  # noqa: E402

CX = 256

# per-character accents: iris colour, smile (-0.3 .. 1), asym smirk, extra flags
ACCENT = {
    "player":   dict(iris="#7a8a96", smile=0.22, smirk=0.35, soot=True),
    "borin":    dict(iris="#6a5030", smile=0.55),
    "mira":     dict(iris="#5e7a44", smile=0.75, freckles=True),
    "sigrun":   dict(iris="#6a90b4", smile=0.35),
    "elowen":   dict(iris="#8a88b8", smile=0.12, smirk=0.4, brow_raise=True),
    "kestra":   dict(iris="#5a3a22", smile=0.45, smirk=0.8, scar_lip=True),
    "garrick":  dict(iris="#6a7a96", smile=0.65),
    "tomas":    dict(iris="#5a4030", smile=0.95),
    "varn":     dict(iris="#b08a30", smile=0.85),
    "pip":      dict(iris="#5a7a4a", smile=0.95, freckles=True),
    "aldric":   dict(iris="#6a7a80", smile=0.15),
    "hilde":    dict(iris="#5a6a40", smile=1.0),
    "martha":   dict(iris="#6a7a8a", smile=0.05, smirk=0.3),
    "tobin":    dict(iris="#4a3424", smile=0.2),
    "wenna":    dict(iris="#6a8a60", smile=0.85, freckles=True),
    "oswin":    dict(iris="#7a8a96", smile=0.35),
    "jory":     dict(iris="#6a5a3a", smile=0.45),
    "eda":      dict(iris="#3a2a1a", smile=0.75),
    "rosalind": dict(iris="#4a6a5a", smile=0.4, smirk=0.6, mole=True, earrings=True),
    "lysa":     dict(iris="#6a94b4", smile=0.5, earrings=True),
    "celeste":  dict(iris="#5a3a20", smile=0.6, earrings=True),
    "roisin":   dict(iris="#2f9a3e", smile=0.35, smirk=0.75, freckles=True, earrings=True, brow_raise=True),
    "applicant_0": dict(iris="#5a4030", smile=0.3),
    "applicant_1": dict(iris="#4a3020", smile=0.55),
    "applicant_2": dict(iris="#6a88a8", smile=0.4),
    "applicant_3": dict(iris="#5a6a3a", smile=0.85),
    "applicant_4": dict(iris="#a08030", smile=0.4),
    "applicant_5": dict(iris="#5a6a3a", smile=0.6, freckles=True),
}


def dims(look):
    b, f = look.get("build", "average"), look.get("female")
    d = dict(hw=72, hh=98, jw=0.8, chin=0.33, cy=226, sw=176, neck=0.42)
    if f:
        d.update(hw=68, hh=90, jw=0.66, chin=0.22, sw=168, neck=0.36)
    if b == "heavy":
        d.update(hw=84, hh=100, jw=0.96, chin=0.44, sw=226, neck=0.56) if not f else d.update(hw=72, hh=92, jw=0.78, chin=0.3, sw=196, neck=0.42)
    elif b == "slim":
        d.update(sw=d["sw"] - 8) if f else d.update(hw=68, hh=100, jw=0.74, chin=0.3, sw=160)
    elif b == "dwarf":
        d.update(hw=84, hh=92, jw=0.96, chin=0.46, sw=224, neck=0.55, cy=232) if not f else d.update(hw=74, hh=88, jw=0.78, chin=0.3, sw=200, neck=0.45, cy=232)
    elif b == "orc":
        d.update(hw=86, hh=100, jw=1.02, chin=0.52, sw=232, neck=0.62)
    elif b == "halfling":
        d.update(hw=72, hh=88, jw=0.78, chin=0.3, sw=164, neck=0.4, cy=236)
    return d


def face_path(D, cy=None):
    hw, hh, jw, ch = D["hw"], D["hh"], D["jw"], D["chin"]
    cy = D["cy"] if cy is None else cy
    right = [(0.7, -0.9), (0.96, -0.48), (1.0, -0.02), ((1 + jw) / 2, 0.34), (jw, 0.6), (ch + (jw - ch) * 0.45, 0.86), (ch, 0.98)]
    pts = [(0, -1.0)] + right + [(0, 1.03)] + [(-x, y) for x, y in reversed(right)]
    return smooth([(CX + x * hw, cy + y * hh) for x, y in pts], t=0.5)


# ------------------------------------------------------------------ features
def eye(P, x, y, side, ew, eh, iris, fem, closed=False, look_dx=0.0):
    o = []
    if closed:
        o.append(P.detail(f"M{x-ew},{y} Q{x},{y+eh*0.9} {x+ew},{y}", None, 1.6))
        return "\n".join(o)
    # almond, outer corner slightly higher for women
    oy = -eh * 0.25 if fem else -eh * 0.05
    inner, outer = (x - side * ew, y + eh * 0.1), (x + side * ew, y + oy)
    lx, rx = (inner, outer) if side > 0 else (outer, inner)
    alm = (f"M{lx[0]:.1f},{lx[1]:.1f} C{x - ew*0.5:.1f},{y - eh*1.35:.1f} {x + ew*0.5:.1f},{y - eh*1.35:.1f} {rx[0]:.1f},{rx[1]:.1f} "
           f"C{x + ew*0.5:.1f},{y + eh*1.05:.1f} {x - ew*0.5:.1f},{y + eh*1.05:.1f} {lx[0]:.1f},{lx[1]:.1f} Z")
    cid = uid("ec")
    P.defs.append(f'<clipPath id="{cid}"><path d="{alm}"/></clipPath>')
    o.append(f'<path d="{alm}" fill="#f2e8d4"/>')
    ir = eh * 0.98
    ix = x + look_dx
    o.append(f'<g clip-path="url(#{cid})">'
             f'<circle cx="{ix:.1f}" cy="{y - eh*0.08:.1f}" r="{ir:.1f}" fill="{iris}"/>'
             f'<circle cx="{ix:.1f}" cy="{y - eh*0.08:.1f}" r="{ir:.1f}" fill="none" stroke="#20140c" stroke-width="1.6" opacity="0.7"/>'
             f'<circle cx="{ix:.1f}" cy="{y - eh*0.08:.1f}" r="{ir*0.45:.1f}" fill="#20140c"/>'
             f'<circle cx="{ix - ir*0.35:.1f}" cy="{y - eh*0.42:.1f}" r="{ir*0.24:.1f}" fill="#fffaf0" opacity="0.9"/>'
             f'<path d="M{x-ew*1.2},{y-eh*1.6} L{x+ew*1.2},{y-eh*1.6} L{x+ew*1.2},{y-eh*0.35} Q{x},{y-eh*0.75} {x-ew*1.2},{y-eh*0.35} Z" fill="#866b4b" opacity="0.28"/>'
             f'</g>')
    # upper lid (heavy) + crease, lower lid (light)
    up = f"M{lx[0]:.1f},{lx[1]:.1f} C{x - ew*0.5:.1f},{y - eh*1.35:.1f} {x + ew*0.5:.1f},{y - eh*1.35:.1f} {rx[0]:.1f},{rx[1]:.1f}"
    o.append(P.detail(up, None, 2.2 if fem else 1.8))
    o.append(P.detail(f"M{x - ew*0.75:.1f},{y - eh*1.55:.1f} Q{x:.1f},{y - eh*2.2:.1f} {x + ew*0.8:.1f},{y - eh*1.5:.1f}", None, 0.7, 0.6))
    o.append(P.detail(f"M{x - ew*0.6:.1f},{y + eh*0.85:.1f} Q{x:.1f},{y + eh*1.15:.1f} {x + ew*0.6:.1f},{y + eh*0.8:.1f}", None, 0.6, 0.5))
    if fem:
        ox, oy2 = outer
        o.append(P.detail(f"M{ox:.1f},{oy2:.1f} l{side*6:.1f},-5 M{ox - side*4:.1f},{oy2 - eh*0.55:.1f} l{side*5:.1f},-6", None, 1.0))
    return "\n".join(o)


def brow(P, x, y, side, w, fem, col, raise_=0.0, heavy=False):
    t = (5 if fem else 8) * (1.5 if heavy else 1)
    i0 = (x - side * w * 0.95, y + (-1 if fem else 2))
    pk = (x + side * w * (0.05 if fem else 0.2), y - (9 if fem else 5) - raise_)
    e0 = (x + side * w * 1.05, y + (2 if fem else 1) - raise_ * 0.3)
    pts = [i0, pk, e0, (pk[0] + side * 2, pk[1] + t * 0.8), (i0[0] + side * 2, i0[1] + t)]
    return P.shape(smooth(pts, t=0.4), "hair", s=2, hl=False, fill_override=col, lw=1.4)


def nose(P, D, look, y_eye, y_tip):
    hw = D["hw"]
    b = look.get("build")
    o = []
    w = hw * (0.2 if look.get("female") else 0.24)
    if b in ("dwarf",):
        w = hw * 0.32
        o.append(P.shape(smooth([(CX - w * 0.5, y_eye + 10), (CX + w * 0.4, y_eye + 10), (CX + w * 0.7, y_tip - 14), (CX + w * 1.05, y_tip),
                                 (CX, y_tip + 12), (CX - w * 1.05, y_tip), (CX - w * 0.7, y_tip - 14)]), "skin", s=7, lw=1.6))
    elif b == "orc":
        w = hw * 0.34
        o.append(P.shape(smooth([(CX - w * 0.3, y_eye + 18), (CX + w * 0.3, y_eye + 18), (CX + w * 1.0, y_tip - 4),
                                 (CX + w * 0.6, y_tip + 8), (CX, y_tip + 5), (CX - w * 0.6, y_tip + 8), (CX - w * 1.0, y_tip - 4)]), "skin", s=7, lw=1.6))
        o.append(P.spot(ell(CX - w * 0.42, y_tip + 2, 4.5, 3), "#20140c", 0.8))
        o.append(P.spot(ell(CX + w * 0.42, y_tip + 2, 4.5, 3), "#20140c", 0.8))
        return "\n".join(o)
    # bridge shadow on the shadow side (viewer right), wings and tip
    o.append(f'<path d="M{CX + w*0.35:.1f},{y_eye + 6:.1f} Q{CX + w*0.7:.1f},{(y_eye + y_tip)/2:.1f} {CX + w*0.95:.1f},{y_tip - 2:.1f} '
             f'L{CX + w*0.3:.1f},{y_tip - 2:.1f} Q{CX + w*0.2:.1f},{(y_eye + y_tip)/2:.1f} {CX + w*0.05:.1f},{y_eye + 6:.1f} Z" fill="{P.c("skin", 2)}" opacity="0.35"/>')
    o.append(P.detail(f"M{CX + w*0.32:.1f},{y_eye + 10:.1f} Q{CX + w*0.62:.1f},{(y_eye + y_tip)/2 + 6:.1f} {CX + w*0.72:.1f},{y_tip - 6:.1f}", "skin", 1.0, 0.75))
    o.append(P.detail(f"M{CX - w*1.0:.1f},{y_tip - 6:.1f} Q{CX - w*1.15:.1f},{y_tip + 6:.1f} {CX - w*0.5:.1f},{y_tip + 5:.1f} "
                      f"Q{CX:.1f},{y_tip + 11:.1f} {CX + w*0.5:.1f},{y_tip + 5:.1f} Q{CX + w*1.15:.1f},{y_tip + 6:.1f} {CX + w*1.0:.1f},{y_tip - 6:.1f}", None, 1.3))
    o.append(P.spot(ell(CX - w * 0.15, y_tip - 6, w * 0.32, 4), P.c("skin", 0), 0.7))
    return "\n".join(o)


def mouth(P, D, look, ym, smile, smirk, fem, beard):
    hw = D["hw"]
    mw = hw * (0.36 if fem else 0.4)
    o = []
    lu = smile * 5 + smirk * 2
    ru = smile * 5 - smirk * 1
    lc = (CX - mw, ym - lu)
    rc = (CX + mw, ym - ru - smirk * 4)
    rose = person.mix(P.c("skin", 1), "#9a3a3a", 0.42 if fem else 0.18)
    if fem or look.get("build") == "halfling":
        upper = (f"M{lc[0]:.1f},{lc[1]:.1f} Q{CX - mw*0.45:.1f},{ym - 8:.1f} {CX - mw*0.12:.1f},{ym - 7:.1f} Q{CX:.1f},{ym - 4:.1f} "
                 f"{CX + mw*0.12:.1f},{ym - 7:.1f} Q{CX + mw*0.45:.1f},{ym - 8:.1f} {rc[0]:.1f},{rc[1]:.1f} "
                 f"Q{CX + mw*0.4:.1f},{ym + 1 - smile*2:.1f} {CX:.1f},{ym + 1:.1f} Q{CX - mw*0.4:.1f},{ym + 1 - smile*2:.1f} {lc[0]:.1f},{lc[1]:.1f} Z")
        lower = (f"M{lc[0] + 3:.1f},{lc[1] + 1:.1f} Q{CX:.1f},{ym + 1:.1f} {rc[0] - 3:.1f},{rc[1] + 1:.1f} "
                 f"Q{CX + mw*0.5:.1f},{ym + 13 - smile*2:.1f} {CX:.1f},{ym + 14 - smile*2:.1f} Q{CX - mw*0.5:.1f},{ym + 13 - smile*2:.1f} {lc[0] + 3:.1f},{lc[1] + 1:.1f} Z")
        if look.get("build") == "halfling" and not fem:
            rose = person.mix(P.c("skin", 1), "#9a3a3a", 0.22)
        o.append(f'<path d="{lower}" fill="{rose}" opacity="0.9"/>')
        o.append(f'<path d="{upper}" fill="{person.mix(rose, "#20140c", 0.15)}" opacity="0.9"/>')
        o.append(P.spot(ell(CX - mw * 0.2, ym + 7 - smile, mw * 0.3, 2.4), "#fff4e4", 0.45))
    line = (f"M{lc[0]:.1f},{lc[1]:.1f} Q{CX - mw*0.4:.1f},{ym + 1 + smile*2:.1f} {CX:.1f},{ym + 1 + smile*1.5:.1f} "
            f"Q{CX + mw*0.4:.1f},{ym + 1 + smile*2:.1f} {rc[0]:.1f},{rc[1]:.1f}")
    if smile > 0.8 and not beard:
        # open smile: teeth
        tp = (f"M{lc[0] + 4:.1f},{lc[1] + 1:.1f} Q{CX:.1f},{ym + 3:.1f} {rc[0] - 4:.1f},{rc[1] + 1:.1f} "
              f"Q{CX:.1f},{ym + 12:.1f} {lc[0] + 4:.1f},{lc[1] + 1:.1f} Z")
        o.append(f'<path d="{tp}" fill="#f4ecdc"/>')
        o.append(P.detail(tp, None, 1.0))
    o.append(P.detail(line, None, 1.5))
    # corners + lower-lip shadow
    o.append(P.detail(f"M{lc[0] - 2:.1f},{lc[1] - 3:.1f} q-2,4 1,7 M{rc[0] + 2:.1f},{rc[1] - 3:.1f} q2,4 -1,7", None, 0.7, 0.6))
    if not fem:
        o.append(P.detail(f"M{CX - mw*0.45:.1f},{ym + 13:.1f} Q{CX:.1f},{ym + 18:.1f} {CX + mw*0.45:.1f},{ym + 13:.1f}", "skin", 0.8, 0.55))
    return "\n".join(o)


def ear(P, D, look, side):
    hw, hh, cy = D["hw"], D["hh"], D["cy"]
    x = CX + side * hw * 0.97
    if "pointed_ears" in look.get("extras", []):
        pts = [(x, cy - hh * 0.12), (x + side * hw * 0.2, cy - hh * 0.3), (x + side * hw * 0.42, cy - hh * 0.62),
               (x + side * hw * 0.3, cy - hh * 0.2), (x + side * hw * 0.2, cy + hh * 0.18), (x + side * 2, cy + hh * 0.3)]
        o = P.shape(smooth(pts, t=0.35), "skin", s=4, lw=1.6)
        o += P.detail(f"M{x + side*hw*0.08},{cy - hh*0.1} Q{x + side*hw*0.24},{cy - hh*0.28} {x + side*hw*0.33},{cy - hh*0.5}", "skin", 0.8, 0.7)
        return o
    pts = [(x, cy - hh * 0.12), (x + side * hw * 0.16, cy - hh * 0.2), (x + side * hw * 0.2, cy + hh * 0.02),
           (x + side * hw * 0.12, cy + hh * 0.26), (x + side * 2, cy + hh * 0.34)]
    o = P.shape(smooth(pts, t=0.4), "skin", s=4, lw=1.6)
    o += P.detail(f"M{x + side*hw*0.05},{cy - hh*0.08} Q{x + side*hw*0.15},{cy} {x + side*hw*0.06},{cy + hh*0.18}", "skin", 0.8, 0.7)
    return o


# ------------------------------------------------------------------ hair
def hair_back(P, D, look):
    st = look.get("hair")
    hw, hh, cy = D["hw"], D["hh"], D["cy"]
    o = []
    if st == "long":
        L = 512 if look.get("female") else cy + hh * 1.8
        w = 1.32 if look.get("female") else 1.15
        pts = [(CX, cy - hh * 1.12), (CX + hw * 0.95, cy - hh * 0.9), (CX + hw * w, cy - hh * 0.2), (CX + hw * (w + 0.06), cy + hh * 0.6),
               (CX + hw * (w + 0.18), L - 30), (CX + hw * 0.5, L), (CX - hw * 0.5, L),
               (CX - hw * (w + 0.18), L - 30), (CX - hw * (w + 0.06), cy + hh * 0.6), (CX - hw * w, cy - hh * 0.2), (CX - hw * 0.95, cy - hh * 0.9)]
        o.append(P.shape(smooth(pts), "hair", s=14))
    elif st == "curly":
        o.append(P.shape(blob(CX, cy - hh * 0.25, hw * 1.42, 13, 0.08, 3, squash=0.95), "hair", s=14))
    elif st == "bun":
        o.append(P.shape(ell(CX + hw * 0.1, cy - hh * 1.05, hw * 0.48, hh * 0.36), "hair", s=8))
        o.append(P.detail(f"M{CX - hw*0.25},{cy - hh*1.15} Q{CX + hw*0.1},{cy - hh*0.85} {CX + hw*0.48},{cy - hh*1.1}", "hair", 0.8, 0.8))
    elif st == "ponytail":
        pts = [(CX + hw * 0.7, cy - hh * 0.4), (CX + hw * 1.2, cy + hh * 0.1), (CX + hw * 1.3, cy + hh * 0.8), (CX + hw * 1.05, cy + hh * 1.5),
               (CX + hw * 0.85, cy + hh * 1.05), (CX + hw * 0.82, cy + hh * 0.3)]
        o.append(P.shape(smooth(pts), "hair", s=8))
    elif st == "hood":
        pts = [(CX, cy - hh * 1.32), (CX + hw * 1.25, cy - hh * 0.9), (CX + hw * 1.45, cy + hh * 0.3), (CX + hw * 1.55, cy + hh * 1.1),
               (CX - hw * 1.55, cy + hh * 1.1), (CX - hw * 1.45, cy + hh * 0.3), (CX - hw * 1.25, cy - hh * 0.9)]
        o.append(P.shape(smooth(pts), "hoodc", s=14))
    return "\n".join(o)


def hair_front(P, D, look, ex):
    st = look.get("hair")
    hw, hh, cy = D["hw"], D["hh"], D["cy"]
    fem = look.get("female")
    o = []
    if st == "bald":
        return P.spot(ell(CX - hw * 0.3, cy - hh * 0.72, hw * 0.3, hh * 0.1), "#fff4e0", 0.35)
    if st == "bald_fringe":
        for side in (-1, 1):
            pts = [(CX + side * hw * 0.88, cy - hh * 0.5), (CX + side * hw * 1.04, cy - hh * 0.4), (CX + side * hw * 1.06, cy - hh * 0.05),
                   (CX + side * hw * 0.98, cy + hh * 0.05), (CX + side * hw * 0.93, cy - hh * 0.2)]
            o.append(P.shape(smooth(pts), "hair", s=3, hl=False))
        o.append(P.spot(ell(CX - hw * 0.3, cy - hh * 0.72, hw * 0.3, hh * 0.1), "#fff4e0", 0.35))
        return "\n".join(o)
    if st == "mohawk":
        pts = [(CX - hw * 0.18, cy - hh * 0.72), (CX - hw * 0.22, cy - hh * 1.05), (CX - hw * 0.1, cy - hh * 1.42), (CX + hw * 0.08, cy - hh * 1.48),
               (CX + hw * 0.22, cy - hh * 1.1), (CX + hw * 0.18, cy - hh * 0.72)]
        o.append(P.shape(smooth(pts), "hair", s=6))
        o.append(P.detail(f"M{CX - hw*0.1},{cy - hh*0.8} L{CX - hw*0.06},{cy - hh*1.35} M{CX + hw*0.08},{cy - hh*0.8} L{CX + hw*0.06},{cy - hh*1.38}", "hair", 0.7, 0.8))
        # shaved sides
        for side in (-1, 1):
            o.append(P.spot(ell(CX + side * hw * 0.62, cy - hh * 0.55, hw * 0.3, hh * 0.28), P.c("hair", 1), 0.18))
        return "\n".join(o)
    if st == "hood":
        # hood rim framing the face
        rim = [(CX - hw * 1.12, cy + hh * 0.75), (CX - hw * 1.18, cy - hh * 0.25), (CX - hw * 0.8, cy - hh * 1.05), (CX, cy - hh * 1.26),
               (CX + hw * 0.8, cy - hh * 1.05), (CX + hw * 1.18, cy - hh * 0.25), (CX + hw * 1.12, cy + hh * 0.75),
               (CX + hw * 0.96, cy + hh * 0.2), (CX + hw * 0.82, cy - hh * 0.6), (CX, cy - hh * 0.86), (CX - hw * 0.82, cy - hh * 0.6),
               (CX - hw * 0.96, cy + hh * 0.2)]
        o.append(P.shape(smooth(rim), "hoodc", s=8))
        o.append(P.shape(smooth([(CX - hw * 0.75, cy - hh * 0.55), (CX, cy - hh * 0.82), (CX + hw * 0.75, cy - hh * 0.55),
                                 (CX + hw * 0.4, cy - hh * 0.5), (CX, cy - hh * 0.58), (CX - hw * 0.4, cy - hh * 0.48)]), "hair", s=3, hl=False))
        return "\n".join(o)
    if st == "curly":
        pts = []
        for i in range(9):
            t = i / 8
            x = CX + (t - 0.5) * hw * 1.9
            y = cy - hh * (0.62 + 0.38 * math.sin(t * math.pi))
            pts.append((x, y))
        for i, (x, y) in enumerate(pts):
            o.append(P.shape(ell(x, y, hw * 0.24, hh * 0.18), "hair", s=4, hl=(i % 2 == 0)))
        for side in (-1, 1):
            for j in range(3):
                o.append(P.shape(ell(CX + side * hw * (1.02 + 0.04 * j), cy - hh * (0.35 - 0.3 * j), hw * 0.2, hh * 0.17), "hair", s=3))
        return "\n".join(o)
    # cap-based styles
    hairline = {"short": 0.64, "cropped": 0.7, "long": 0.6, "ponytail": 0.66, "braid": 0.64, "bun": 0.66}.get(st, 0.64)
    vol = {"short": 1.12, "cropped": 1.05, "long": 1.1, "ponytail": 1.06, "braid": 1.08, "bun": 1.06}.get(st, 1.1)
    side_part = 1 if (sum(map(ord, look.get("_id", ""))) % 2) else -1
    if fem and st == "long":
        # centre-parted curtains falling past the cheeks over the shoulders
        for side in (-1, 1):
            pts = [(CX + side * hw * 0.04, cy - hh * vol), (CX + side * hw * 0.75, cy - hh * 0.95), (CX + side * hw * 1.1, cy - hh * 0.35),
                   (CX + side * hw * 1.12, cy + hh * 0.5), (CX + side * hw * 1.28, cy + hh * 1.3), (CX + side * hw * 1.45, cy + hh * 2.2),
                   (CX + side * hw * 1.05, cy + hh * 2.3), (CX + side * hw * 0.95, cy + hh * 1.3), (CX + side * hw * 0.92, cy + hh * 0.4),
                   (CX + side * hw * 0.82, cy - hh * 0.3), (CX + side * hw * 0.45, cy - hh * hairline), (CX + side * hw * 0.04, cy - hh * (hairline + 0.12))]
            o.append(P.shape(smooth(pts), "hair", s=8))
            o.append(P.detail(f"M{CX + side*hw*0.5},{cy - hh*0.85} Q{CX + side*hw*1.0},{cy - hh*0.3} {CX + side*hw*1.08},{cy + hh*0.8} "
                              f"Q{CX + side*hw*1.2},{cy + hh*1.5} {CX + side*hw*1.3},{cy + hh*2.1} "
                              f"M{CX + side*hw*0.25},{cy - hh*0.9} Q{CX + side*hw*0.8},{cy - hh*0.5} {CX + side*hw*0.98},{cy + hh*0.3}", "hair", 0.7, 0.7))
        return "\n".join(o)
    # generic cap: crown volume, sides over the temples, side parting with a soft swept fringe
    sp_ = side_part
    top = cy - hh * vol
    sideY = cy + hh * (0.12 if fem else -0.18) if st != "cropped" else cy - hh * (0.02 if fem else 0.25)
    hl = hairline
    pts = [(-1.06, sideY), (-1.12, cy - hh * 0.45), (-0.78, top + hh * 0.13), (0.0, top), (0.78, top + hh * 0.13),
           (1.12, cy - hh * 0.45), (1.06, sideY),
           (0.9, sideY - hh * 0.08), (0.86, cy - hh * 0.36), (0.6, cy - hh * (hl - 0.02)), (0.3, cy - hh * (hl + 0.08)),
           (0.0, cy - hh * (hl - 0.02)), (-0.4, cy - hh * (hl - 0.16)), (-0.72, cy - hh * (hl - 0.22)), (-0.9, cy - hh * 0.2),
           (-0.92, sideY - hh * 0.08)]
    pts = [(CX + sp_ * x * hw, y) for x, y in pts]
    d = smooth(pts, t=0.45)
    o.append(P.shape(d, "hair", s=9))
    hcid = uid("hc")
    P.defs.append(f'<clipPath id="{hcid}"><path d="{d}"/></clipPath>')
    px, py = CX + sp_ * hw * 0.3, top + hh * 0.06
    segs = []
    for tx, ty in ((0.95, cy - hh * 0.3), (0.62, cy - hh * (hl + 0.02)), (-0.1, cy - hh * (hl - 0.06)),
                   (-0.55, cy - hh * (hl - 0.2)), (-0.95, cy - hh * 0.05)):
        ex_, ey_ = CX + sp_ * tx * hw, ty
        cx_, cy_ = (px + ex_) / 2 + sp_ * tx * hw * 0.15, py + (ey_ - py) * 0.25
        segs.append(f"M{px:.1f},{py:.1f} Q{cx_:.1f},{cy_:.1f} {ex_:.1f},{ey_:.1f}")
    o.append(f'<g clip-path="url(#{hcid})">' + P.detail(" ".join(segs), "hair", 0.7, 0.7) + '</g>')
    if st == "bun":
        for side in (-1, 1):
            o.append(P.detail(f"M{CX + side*hw*0.92},{cy - hh*0.3} q{side*6},18 {side*2},34", "hair", 0.8, 0.8))
    if st == "braid":
        # braid over the shoulder (viewer right)
        for i in range(8):
            y = cy + hh * 0.2 + i * hh * 0.24
            x = CX + hw * (1.02 + 0.06 * i) - i * 1.5
            rr = hw * (0.2 - 0.008 * i)
            o.append(P.shape(ell(x, y, rr, hh * 0.15), "hair", s=3, hl=(i % 2 == 0)))
        o.append(P.shape(rect(CX + hw * 1.42 - 12, cy + hh * 2.1, 24, 10, 3), "strap", s=2))
    if st == "ponytail":
        o.append(P.shape(ell(CX + hw * 0.86, cy - hh * 0.55, hw * 0.12, hh * 0.08), "strap", s=2, hl=False))
    return "\n".join(o)


def beard(P, D, look, ym):
    bt = look.get("beard", "none")
    hw, hh, cy = D["hw"], D["hh"], D["cy"]
    dwarf = look.get("build") == "dwarf"
    o = []
    if bt == "none":
        return ""
    if bt == "stubble":
        pts = [(CX - hw * 0.95, cy + hh * 0.15), (CX - hw * 0.62, cy + hh * 0.78), (CX, cy + hh * 1.02), (CX + hw * 0.62, cy + hh * 0.78),
               (CX + hw * 0.95, cy + hh * 0.15), (CX + hw * 0.6, cy + hh * 0.45), (CX + hw * 0.3, cy + hh * 0.36), (CX, cy + hh * 0.38),
               (CX - hw * 0.3, cy + hh * 0.36), (CX - hw * 0.6, cy + hh * 0.45)]
        o.append(f'<path d="{smooth(pts)}" fill="{P.c("beard", 2)}" opacity="0.3"/>')
        rnd = random.Random(5)
        dots = []
        for _ in range(70):
            x = rnd.uniform(-0.85, 0.85)
            y = rnd.uniform(0.4, 0.98)
            if abs(x) < 0.85 - (y - 0.4) * 0.6:
                dots.append(f"M{CX + x*hw:.1f},{cy + y*hh:.1f} h0.6")
        o.append(P.detail(" ".join(dots), None, 1.1, 0.45))
        return "\n".join(o)
    L = {"short": 1.18, "long": 1.85, "braided": 2.0}.get(bt, 1.2)
    W = 1.0
    if dwarf:
        L, W = 2.75, 1.25
    bot = cy + hh * L
    pts = [(CX - hw * 0.98, cy - hh * 0.05), (CX - hw * 1.0 * W, cy + hh * 0.5), (CX - hw * 0.85 * W, cy + hh * (0.7 + (L - 1) * 0.6)),
           (CX - hw * 0.4 * W, bot - hh * 0.08), (CX, bot), (CX + hw * 0.4 * W, bot - hh * 0.08), (CX + hw * 0.85 * W, cy + hh * (0.7 + (L - 1) * 0.6)),
           (CX + hw * 1.0 * W, cy + hh * 0.5), (CX + hw * 0.98, cy - hh * 0.05), (CX + hw * 0.84, cy + hh * 0.2),
           (CX + hw * 0.55, cy + hh * 0.48), (CX + hw * 0.3, ym + 14), (CX, ym + 18), (CX - hw * 0.3, ym + 14), (CX - hw * 0.55, cy + hh * 0.48),
           (CX - hw * 0.84, cy + hh * 0.2)]
    if bt == "braided":
        pts[3] = (CX - hw * 0.3, bot - hh * 0.35)
        pts[4] = (CX, bot)
        pts[5] = (CX + hw * 0.3, bot - hh * 0.35)
    o.append(P.shape(smooth(pts), "beard", s=12))
    # strands
    segs = []
    for x0 in (-0.7, -0.4, -0.1, 0.2, 0.5, 0.75):
        segs.append(f"M{CX + x0*hw*W:.1f},{ym + 22:.1f} Q{CX + x0*hw*W*0.9:.1f},{(ym + bot)/2:.1f} {CX + x0*hw*W*0.45:.1f},{bot - hh*0.12:.1f}")
    o.append(P.detail(" ".join(segs), "beard", 0.7, 0.7))
    if bt == "braided":
        o.append(P.shape(rect(CX - 14, bot - hh * 0.32, 28, 18, 4), "gold", s=3))
        o.append(P.detail(f"M{CX - 10},{bot - hh*0.55} l10,8 l10,-8 M{CX - 10},{bot - hh*0.45} l10,8 l10,-8", "beard", 0.8))
    if dwarf:
        for side in (-1, 1):
            x = CX + side * hw * 0.5
            o.append(P.shape(rect(x - 12, bot - hh * 0.5, 24, 16, 4), "gold", s=3))
            o.append(P.shape(rect(x - 12, bot - hh * 0.3, 24, 16, 4), "gold", s=3))
    # moustache
    mw = hw * (0.62 if dwarf else 0.52)
    for side in (-1, 1):
        mp = [(CX + side * 4, ym - 12), (CX + side * mw * 0.6, ym - 14), (CX + side * mw * 1.05, ym - 4), (CX + side * mw * 1.15, ym + 12),
              (CX + side * mw * 0.8, ym + 2), (CX + side * mw * 0.3, ym - 2), (CX + side * 2, ym - 4)]
        o.append(P.shape(smooth(mp), "beard", s=4, hl=False))
    return "\n".join(o)


# ------------------------------------------------------------------ bust (clothing)
def bust(P, D, look, A):
    hw, hh, cy, sw = D["hw"], D["hh"], D["cy"], D["sw"]
    armor = look.get("armor", "none")
    ex = look.get("extras", [])
    fem = look.get("female")
    gown = bool(fem and armor == "robe" and look.get("hand", "none") == "none")
    ny = cy + hh * 0.82          # neck top (behind jaw)
    by = cy + hh + 34            # neck base
    nw = hw * D["neck"]
    o = []
    # cloak behind the shoulders
    if look.get("cloak"):
        o.append(P.shape(smooth([(CX - sw * 1.08, 530), (CX - sw * 1.04, by + 70), (CX - sw * 0.6, by + 8), (CX, by - 4),
                                 (CX + sw * 0.6, by + 8), (CX + sw * 1.04, by + 70), (CX + sw * 1.08, 530)]), "cloak", s=12))
    # neck
    o.append(P.shape(smooth([(CX - nw, ny), (CX + nw, ny), (CX + nw * 1.08, by + 6), (CX, by + 20), (CX - nw * 1.08, by + 6)], t=0.3), "skin", s=10))
    o.append(f'<path d="M{CX - nw},{ny} Q{CX},{ny + 46} {CX + nw},{ny} L{CX + nw},{ny + 30} Q{CX},{ny + 60} {CX - nw},{ny + 30} Z" fill="{P.c("skin", 2)}" opacity="0.45"/>')
    # torso silhouette
    sh = [(CX - sw * 1.02, 530), (CX - sw * 1.0, by + 96), (CX - sw * 0.86, by + 46), (CX - sw * 0.5, by + 16), (CX - nw * 1.1, by - 2),
          (CX, by + 6), (CX + nw * 1.1, by - 2), (CX + sw * 0.5, by + 16), (CX + sw * 0.86, by + 46), (CX + sw * 1.0, by + 96), (CX + sw * 1.02, 530)]
    if fem:
        sh = [(CX - sw * 0.98, 530), (CX - sw * 0.98, by + 100), (CX - sw * 0.82, by + 50), (CX - sw * 0.45, by + 22), (CX - nw * 1.15, by + 4),
              (CX, by + 10), (CX + nw * 1.15, by + 4), (CX + sw * 0.45, by + 22), (CX + sw * 0.82, by + 50), (CX + sw * 0.98, by + 100), (CX + sw * 0.98, 530)]
    if gown:
        # bare shoulders: skin silhouette, then the gown bodice + sleeves
        o.append(P.shape(smooth(sh, t=0.45), "skin", s=12))
        o.append(P.detail(f"M{CX - nw*1.3},{by + 24} Q{CX - sw*0.3},{by + 34} {CX - sw*0.55},{by + 30} "
                          f"M{CX + nw*1.3},{by + 24} Q{CX + sw*0.3},{by + 34} {CX + sw*0.55},{by + 30}", "skin", 0.7, 0.5))
        dt = by + 74
        bod = [(CX - sw * 1.0, 530), (CX - sw * 0.99, dt + 10), (CX - sw * 0.75, dt - 8), (CX - sw * 0.3, dt + 16), (CX, dt + 46),
               (CX + sw * 0.3, dt + 16), (CX + sw * 0.75, dt - 8), (CX + sw * 0.99, dt + 10), (CX + sw * 1.0, 530)]
        o.append(P.shape(smooth(bod, t=0.4), "shirt", s=12))
        o.append(P.detail(f"M{CX},{dt + 46} L{CX},{530} M{CX - 8},{dt + 66} l16,8 M{CX - 8},{dt + 86} l16,8", "shirt", 0.7, 0.7))
        for side in (-1, 1):
            o.append(P.shape(ell(CX + side * sw * 0.9, dt + 6, sw * 0.2, 30), "shirt", s=6))
        # necklace
        o.append(P.detail(f"M{CX - nw*1.05},{by + 2} Q{CX},{by + 52} {CX + nw*1.05},{by + 2}", "gold", 1.4))
        o.append(P.shape(smooth([(CX, by + 36), (CX + 8, by + 46), (CX, by + 60), (CX - 8, by + 46)]), "gem", s=3))
        return "\n".join(o)
    base_role = {"leather": "shirt", "chain": "chain", "plate": "shirt"}.get(armor, "shirt")
    if look.get("build") == "orc" and armor == "leather":
        base_role = "skin"
    o.append(P.shape(smooth(sh, t=0.45), base_role, s=14))
    # neckline
    if base_role != "skin":
        if fem:
            o.append(P.shape(smooth([(CX - nw * 1.2, by + 2), (CX, by + 8), (CX + nw * 1.2, by + 2), (CX + nw * 0.5, by + 54), (CX, by + 66),
                                     (CX - nw * 0.5, by + 54)], t=0.4), "skin", s=5, lw=1.6))
            o.append(P.detail(f"M{CX - nw*0.4},{by + 46} Q{CX},{by + 62} {CX + nw*0.4},{by + 46}", "skin", 0.6, 0.5))
        else:
            o.append(P.shape(poly([(CX - nw * 1.05, by - 2), (CX + nw * 1.05, by - 2), (CX + nw * 0.25, by + 44), (CX - nw * 0.25, by + 44)]), "skin", s=4, lw=1.6))
            o.append(P.detail(f"M{CX - nw*1.1},{by} L{CX},{by + 48} L{CX + nw*1.1},{by}", "shirt", 1.2))
    o.append(P.detail(f"M{CX - sw*0.7},{by + 60} Q{CX - sw*0.6},{by + 120} {CX - sw*0.66},{530} M{CX + sw*0.7},{by + 60} Q{CX + sw*0.6},{by + 120} {CX + sw*0.66},{530}", "shirt", 0.8, 0.6))
    if armor == "leather":
        if look.get("build") == "orc":
            for side in (-1, 1):
                o.append(P.shape(poly([(CX + side * sw * 0.55, by + 10), (CX + side * sw * 0.75, by + 22), (CX - side * sw * 0.45, 530), (CX - side * sw * 0.7, 530)]), "strap", s=3))
            o.append(P.shape(blob(CX + sw * 0.78, by + 50, sw * 0.32, 11, 0.14, 7, squash=0.75), "hair", s=8, fill_override="#6a5a48"))
            o.append(P.shape(ell(CX, by + 92, 20, 20), "metal", s=4))
        else:
            jer = [(CX - sw * 0.94, 530), (CX - sw * 0.9, by + 80), (CX - sw * 0.62, by + 30), (CX - nw * 1.3, by + 12), (CX - nw * 0.6, 530)]
            for side in (-1, 1):
                o.append(P.shape(smooth([(CX + side * (x - CX) * -1 if False else 2 * CX - x if side > 0 else x, y) for x, y in jer], t=0.35), "leather", s=10))
            o.append(P.detail(f"M{CX - nw*0.6},{by + 70} l{nw*1.2},10 M{CX - nw*0.6},{by + 100} l{nw*1.2},10 M{CX - nw*0.6},{by + 130} l{nw*1.2},10", "strap", 0.8))
            for side in (-1, 1):
                o.append(P.detail(f"M{CX + side*sw*0.5},{by + 40} Q{CX + side*sw*0.66},{by + 46} {CX + side*sw*0.8},{by + 70}", "leather", 0.7, 0.7))
    elif armor == "chain":
        rings = []
        for j in range(8):
            for i in range(-12, 13):
                x = CX + i * 16 + (j % 2) * 8
                y = by + 40 + j * 14
                if abs(x - CX) < sw * 0.95:
                    rings.append(f"M{x - 6},{y} q6,7 12,0")
        o.append(P.detail(" ".join(rings), "chain", 0.6, 0.7))
    elif armor == "plate":
        bp = [(CX - sw * 0.62, by + 40), (CX, by + 30), (CX + sw * 0.62, by + 40), (CX + sw * 0.66, 530), (CX - sw * 0.66, 530)]
        o.append(P.shape(smooth(bp, t=0.3), "metal", s=14))
        o.append(f'<path d="{smooth(bp, t=0.3)}" fill="url(#{P.hatch_id})" opacity="0.3"/>')
        o.append(P.detail(f"M{CX},{by + 34} L{CX},{530}", "metal", 1.0))
        o.append(P.detail(f"M{CX - sw*0.4},{by + 60} Q{CX - sw*0.3},{by + 120} {CX - sw*0.36},{530} M{CX + sw*0.4},{by + 60} Q{CX + sw*0.3},{by + 120} {CX + sw*0.36},{530}", "metal", 0.6, 0.6))
        o.append(P.detail(f"M{CX + sw*0.3},{by + 90} l18,12 M{CX - sw*0.42},{by + 120} l14,8", "metal", 0.6, 0.9))
        # gorget
        o.append(P.shape(smooth([(CX - nw * 1.5, by - 6), (CX, by + 6), (CX + nw * 1.5, by - 6), (CX + nw * 1.6, by + 30), (CX, by + 46), (CX - nw * 1.6, by + 30)]), "metal", s=6))
        for side in (-1, 1):
            px = CX + side * sw * 0.84
            o.append(P.shape(ell(px + side * 6, by + 84, sw * 0.26, 34), "metal", s=6))
            o.append(P.shape(ell(px, by + 54, sw * 0.3, 44), "metal", s=10))
            for a in (-0.8, 0.0, 0.8):
                o.append(P.spot(ell(px + sw * 0.22 * math.sin(a), by + 54 - 32 * math.cos(a), 3.5, 3.5), P.c("gold", 1)))
    elif armor == "robe":
        # monk/priest robe: deep cowl collar
        o.append(P.shape(smooth([(CX - sw * 0.7, by + 30), (CX - nw * 1.4, by - 10), (CX, by + 4), (CX + nw * 1.4, by - 10), (CX + sw * 0.7, by + 30),
                                 (CX + sw * 0.4, by + 66), (CX, by + 80), (CX - sw * 0.4, by + 66)]), "shirt", s=8, fill_override=P.c("shirt", 2)))
        o.append(P.detail(f"M{CX - sw*0.5},{by + 46} Q{CX},{by + 72} {CX + sw*0.5},{by + 46}", "shirt", 0.7, 0.7))
        if look.get("_id") == "oswin":
            o.append(P.shape(smooth([(CX - 8, by + 90), (CX + 8, by + 90), (CX + 8, by + 140), (CX - 8, by + 140)]), "gold", s=3))
            o.append(P.shape(rect(CX - 22, by + 104, 44, 12, 3), "gold", s=3))
    elif armor == "apron":
        q = sw / 226
        for side in (-1, 1):
            o.append(P.shape(poly([(CX + side * nw * 1.05, by + 2), (CX + side * (nw * 1.05 + 16), by + 4), (CX + side * sw * 0.48, 530), (CX + side * (sw * 0.48 - 18), 530)]), "strap", s=3, hl=False))
        o.append(P.shape(smooth([(CX - sw * 0.46, 530), (CX - sw * 0.5, by + 120), (CX - sw * 0.34, by + 104), (CX, by + 100), (CX + sw * 0.34, by + 104),
                                 (CX + sw * 0.5, by + 120), (CX + sw * 0.46, 530)], t=0.3), "apron", s=10))
        if look.get("_id") == "player":
            o.append(P.detail(f"M{CX - 40},{by + 130} l16,10 M{CX + 50},{by + 140} l-14,10", "apron", 0.7, 0.8))
            o.append(f'<ellipse cx="{CX + 40}" cy="{by + 150}" rx="22" ry="10" fill="{P.st["soot"]}" opacity="0.3" style="filter:blur(3px)"/>')
    if "hood_down" in ex:
        o.append(P.shape(smooth([(CX - nw * 2.2, by + 30), (CX - nw * 1.9, by - 18), (CX, by - 6), (CX + nw * 1.9, by - 18), (CX + nw * 2.2, by + 30),
                                 (CX, by + 40)]), "hoodc", s=8))
        o.append(P.detail(f"M{CX - nw*1.6},{by + 10} Q{CX},{by + 30} {CX + nw*1.6},{by + 10}", "hoodc", 0.7, 0.7))
    if look.get("cloak"):
        # cloak edges over the shoulders + clasp
        for side in (-1, 1):
            o.append(P.shape(smooth([(CX + side * sw * 1.08, 530), (CX + side * sw * 1.06, by + 70), (CX + side * sw * 0.7, by + 18),
                                     (CX + side * sw * 0.42, by + 14), (CX + side * sw * 0.7, by + 44), (CX + side * sw * 0.86, 530)]), "cloak", s=8))
        if armor != "plate" and "hood_down" not in ex:
            o.append(P.shape(ell(CX - sw * 0.42, by + 20, 12, 12), "gold", s=3))
    if "pauldron" in ex:
        px = CX + sw * 0.86
        o.append(P.shape(ell(px + 6, by + 84, sw * 0.24, 32), "metal", s=6))
        o.append(P.shape(ell(px, by + 56, sw * 0.28, 44), "metal", s=10))
        for a in (-1.0, -0.4, 0.2, 0.8):
            o.append(P.spot(ell(px + sw * 0.22 * math.sin(a), by + 56 - 34 * math.cos(a), 3.5, 3.5), P.c("gold", 1)))
        o.append(P.detail(f"M{px - 30},{by + 40} l40,-12 M{px - 20},{by + 62} l26,-6", "metal", 0.7, 0.9))
    back = look.get("back")
    if back in ("shield", "quiver", "lute"):
        o.append(P.shape(poly([(CX - sw * 0.62, by + 14), (CX - sw * 0.48, by + 6), (CX + sw * 0.7, 530), (CX + sw * 0.52, 530)]), "strap", s=3, hl=False))
        if back == "quiver":
            for i, dx in enumerate((-14, 0, 14)):
                o.append(P.shape(blob(CX + sw * 0.72 + dx * 1.3, by - 30 - (i % 2) * 12, 12, 5, 0.15, i + 2, squash=1.4), "cloak", s=2, hl=False,
                                 fill_override=["#e8dcc0", "#8e3e3c", "#e8dcc0"][i]))
    if back == "pack":
        for side in (-1, 1):
            o.append(P.shape(poly([(CX + side * sw * 0.5, by + 14), (CX + side * (sw * 0.5 + 20), by + 18), (CX + side * (sw * 0.56 + 20), 530),
                                   (CX + side * sw * 0.56, 530)]), "strap", s=3, hl=False))
    if back == "staff" or look.get("hand") == "staff":
        o.append(P.shape(rect(CX + sw * 0.86, cy - hh * 0.9, 14, 530, 6), "wood", s=4))
        o.append(f'<circle cx="{CX + sw*0.86 + 7}" cy="{cy - hh*0.95}" r="22" fill="{P.st["glow"]}" opacity="0.35" style="filter:blur(6px)"/>')
        o.append(P.shape(ell(CX + sw * 0.86 + 7, cy - hh * 0.95, 13, 15), "gem", s=4))
    if back == "lute":
        o.append(P.shape(rect(CX - sw * 0.92, by - 60, 16, 90, 4), "strap", s=3))
    return "\n".join(o)


# ------------------------------------------------------------------ head
def head(P, D, look, A, cid):
    hw, hh, cy = D["hw"], D["hh"], D["cy"]
    fem = look.get("female")
    ex = look.get("extras", [])
    b = look.get("build")
    o = []
    ey = cy + hh * 0.02
    ew = hw * (0.2 if not fem else 0.225)
    eh = ew * (0.42 if not fem else 0.5)
    if b == "halfling":
        ew *= 1.08
        eh *= 1.15
    if b in ("orc", "dwarf"):
        eh *= 0.88
    ex_ = hw * 0.42
    for side in (-1, 1):
        o.append(ear(P, D, look, side))
    if A.get("earrings"):
        for side in (-1, 1):
            o.append(P.shape(ell(CX + side * hw * 1.04, cy + hh * 0.38, 4.5, 4.5), "gold", s=2))
    o.append(P.shape(face_path(D), "skin", s=12))
    # cheekbone & temple modelling
    o.append(P.spot(ell(CX - hw * 0.45, cy - hh * 0.35, hw * 0.4, hh * 0.25), P.c("skin", 0), 0.35))
    o.append(P.detail(f"M{CX + hw*0.78},{cy + hh*0.18} Q{CX + hw*0.7},{cy + hh*0.42} {CX + hw*0.5},{cy + hh*0.52}", "skin", 0.7, 0.4))
    if fem or b == "halfling" or A.get("smile", 0) > 0.8:
        blush = person.mix(P.c("skin", 1), "#c0504a", 0.5)
        for side in (-1, 1):
            o.append(f'<ellipse cx="{CX + side*hw*0.52:.1f}" cy="{cy + hh*0.3:.1f}" rx="{hw*0.2:.1f}" ry="{hh*0.09:.1f}" fill="{blush}" opacity="0.28" style="filter:blur(4px)"/>')
    # age
    age = A.get("age", 30)
    if age >= 45:
        o.append(P.detail(f"M{CX - hw*0.4},{cy - hh*0.55} q{hw*0.4},-6 {hw*0.8},0 M{CX - hw*0.3},{cy - hh*0.45} q{hw*0.3},-5 {hw*0.6},0", "skin", 0.6, 0.5))
        for side in (-1, 1):
            x = CX + side * (ex_ + ew * 1.25)
            o.append(P.detail(f"M{x},{ey - 2} l{side*8},-4 M{x},{ey + 3} l{side*9},2", "skin", 0.6, 0.6))
            o.append(P.detail(f"M{CX + side*hw*0.24},{cy + hh*0.4} Q{CX + side*hw*0.38},{cy + hh*0.55} {CX + side*hw*0.36},{cy + hh*0.68}", "skin", 0.7, 0.55))
    # eyes
    irises = A.get("iris", "#6a5030")
    for side in (-1, 1):
        x = CX + side * ex_
        if "eyepatch" in ex and side < 0:
            continue
        o.append(eye(P, x, ey, side, ew, eh, irises, fem))
    # brows
    hc = P.c("hair", 1) if look.get("hair") not in ("bald_fringe",) else P.c("hair", 1)
    if look.get("hair") == "mohawk":
        hc = P.c("hair", 1)
    bcol = person.mix(hc, "#20140c", 0.15)
    for side in ((-1, 1) if not look.get("_nobrows") else ()):
        r = (8 if A.get("brow_raise") and side > 0 else 0)
        o.append(brow(P, CX + side * ex_, ey - eh * 2.6 - (2 if fem else 0), side, ew * 1.15, fem, bcol, r, heavy=b in ("dwarf", "orc") or look.get("_id") == "player"))
    # nose & mouth
    y_tip = cy + hh * 0.42
    ym = cy + hh * 0.66
    o.append(nose(P, D, look, ey, y_tip))
    if A.get("freckles"):
        rnd = random.Random(len(cid))
        fr = " ".join(f"M{CX + s_*hw*rnd.uniform(0.25, 0.65):.1f},{cy + hh*rnd.uniform(0.18, 0.36):.1f} h0.5" for s_ in (-1, 1) for _ in range(6))
        o.append(f'<path d="{fr}" stroke="{P.c("skin", 2)}" stroke-width="3" stroke-linecap="round" opacity="0.55"/>')
    o.append(mouth(P, D, look, ym, A.get("smile", 0.3), A.get("smirk", 0.0), fem, look.get("beard", "none") not in ("none", "stubble")))
    if A.get("mole"):
        o.append(P.spot(ell(CX + hw * 0.36, ym - 10, 2.8, 2.8), "#3a2418", 0.85))
    if A.get("scar_lip"):
        o.append(P.detail(f"M{CX - hw*0.12},{ym - 18} l6,24", "skin", 0.9, 0.8))
    # chin cleft / dimple
    if not fem and b not in ("orc",):
        o.append(P.detail(f"M{CX - 6},{cy + hh*0.9} Q{CX},{cy + hh*0.94} {CX + 6},{cy + hh*0.9}", "skin", 0.6, 0.5))
    if "tusks" in ex:
        for side in (-1, 1):
            tx = CX + side * hw * 0.3
            o.append(P.shape(smooth([(tx - 7, ym + 8), (tx + 7, ym + 8), (tx + side * 6, ym - 14), (tx + side * 3, ym - 24), (tx - side * 3, ym - 12)], t=0.3), "ivory", s=2, lw=1.4))
    return "\n".join(o)


def spectacles(P, D, look):
    hw, hh, cy = D["hw"], D["hh"], D["cy"]
    ey = cy + hh * 0.02
    ex_ = hw * 0.42
    r = hw * 0.27
    o = []
    for side in (-1, 1):
        x = CX + side * ex_
        o.append(f'<circle cx="{x:.1f}" cy="{ey:.1f}" r="{r:.1f}" fill="#e8f2f0" fill-opacity="0.18"/>')
        o.append(f'<path d="M{x - r*0.55:.1f},{ey - r*0.2:.1f} l{r*0.5:.1f},{-r*0.45:.1f}" stroke="#ffffff" stroke-width="3" opacity="0.55" stroke-linecap="round"/>')
        o.append(P.detail(ell(x, ey, r, r), "metal", 2.6))
        o.append(P.detail(f"M{x + side*r:.1f},{ey - 4:.1f} L{CX + side*hw*1.02:.1f},{ey - 10:.1f}", "metal", 2.0))
    o.append(P.detail(f"M{CX - ex_ + r:.1f},{ey - 4:.1f} Q{CX:.1f},{ey - 16:.1f} {CX + ex_ - r:.1f},{ey - 4:.1f}", "metal", 2.2))
    return "\n".join(o)


def headscarf(P, D, look):
    hw, hh, cy = D["hw"], D["hh"], D["cy"]
    o = []
    cap = [(CX - hw * 1.12, cy - hh * 0.12), (CX - hw * 1.14, cy - hh * 0.6), (CX - hw * 0.8, cy - hh * 1.06), (CX, cy - hh * 1.2),
           (CX + hw * 0.8, cy - hh * 1.06), (CX + hw * 1.14, cy - hh * 0.6), (CX + hw * 1.12, cy - hh * 0.12),
           (CX + hw * 0.92, cy - hh * 0.36), (CX + hw * 0.5, cy - hh * 0.6), (CX, cy - hh * 0.66), (CX - hw * 0.5, cy - hh * 0.6),
           (CX - hw * 0.92, cy - hh * 0.36)]
    o.append(P.shape(smooth(cap), "scarf", s=10))
    o.append(P.detail(f"M{CX - hw*0.9},{cy - hh*0.62} Q{CX},{cy - hh*0.9} {CX + hw*0.9},{cy - hh*0.62} "
                      f"M{CX - hw*0.6},{cy - hh*0.98} Q{CX - hw*0.1},{cy - hh*0.82} {CX + hw*0.3},{cy - hh*1.1}", "scarf", 0.8, 0.8))
    # dotted print
    rnd = random.Random(9)
    dots = " ".join(f"M{CX + rnd.uniform(-0.85, 0.85)*hw:.1f},{cy - hh*rnd.uniform(0.72, 1.05):.1f} h0.6" for _ in range(22))
    o.append(f'<path d="{dots}" stroke="{P.c("scarf", 0)}" stroke-width="5" stroke-linecap="round" opacity="0.7"/>')
    kx, ky = CX + hw * 1.1, cy - hh * 0.3
    o.append(P.shape(smooth([(kx, ky + 8), (kx + 26, ky + 40), (kx + 22, ky + 92), (kx + 6, ky + 60), (kx - 6, ky + 20)]), "scarf", s=5))
    o.append(P.shape(ell(kx, ky, 15, 13), "scarf", s=4))
    return "\n".join(o)


def portrait_svg(c, st):
    look = dict(c["look"])
    look["_id"] = c["id"]
    A = dict(ACCENT.get(c["id"], {}))
    A["age"] = c.get("age", 30)
    st2 = dict(st)
    st2["pal"] = person.make_palette(st["pal"], look)
    P = Painter(st2)
    P.lw_mul = 1.15
    FP = Painter(st2, scale=0.75)
    filt = FP.sprite_filter()
    D = dims(look)
    hw, hh, cy = D["hw"], D["hh"], D["cy"]
    ex = look.get("extras", [])
    o = []
    if look.get("back") == "shield":
        sx, sy_ = CX - D["sw"] * 0.9, cy + hh + 60
        paint = "cloak" if look.get("cloak") else "apron"
        o.append(P.shape(ell(sx, sy_, 92, 92), "wood", s=12))
        o.append(P.shape(f"M{sx},{sy_-92} A92,92 0 0 1 {sx+92},{sy_} L{sx+66},{sy_} A66,66 0 0 0 {sx},{sy_-66} Z", paint, s=5, hl=False))
        o.append(P.detail(ell(sx, sy_, 87, 87), "metal", 2.4))
    o.append(hair_back(P, D, look))
    o.append(bust(P, D, look, A))
    o.append(head(P, D, look, A, c["id"]))
    o.append(beard(P, D, look, cy + hh * 0.66))
    o.append(hair_front(P, D, look, ex))
    if "scalp_scar" in ex:
        o.append(P.detail(f"M{CX - hw*0.5},{cy - hh*0.92} Q{CX - hw*0.1},{cy - hh*0.7} {CX + hw*0.3},{cy - hh*0.32}", "skin", 1.4))
        o.append(P.detail(f"M{CX - hw*0.36},{cy - hh*0.92} l-8,10 M{CX - hw*0.14},{cy - hh*0.76} l-8,10 M{CX + hw*0.08},{cy - hh*0.6} l-8,10 M{CX + hw*0.24},{cy - hh*0.44} l-8,10", "skin", 0.8))
    if "eyepatch" in ex:
        ex_ = hw * 0.42
        o.append(P.detail(f"M{CX - hw*1.0},{cy - hh*0.5} L{CX + hw*1.0},{cy + hh*0.1}", None, 3.0))
        o.append(P.shape(smooth([(CX - ex_ - 22, cy - 14), (CX - ex_ + 24, cy - 16), (CX - ex_ + 22, cy + 14), (CX - ex_, cy + 22), (CX - ex_ - 22, cy + 10)]), "strap", s=4))
        o.append(P.detail(f"M{CX - ex_ - 18},{cy + 32} l8,6", "skin", 0.8, 0.7))   # scar below the patch
    if "spectacles" in ex:
        o.append(spectacles(P, D, look))
    if "headscarf" in ex:
        o.append(headscarf(P, D, look))
    if A.get("soot"):
        o.append(f'<ellipse cx="{CX + hw*0.55}" cy="{cy + hh*0.3}" rx="18" ry="9" fill="{st["soot"]}" opacity="0.32" style="filter:blur(3px)"/>')
        o.append(f'<ellipse cx="{CX - hw*0.1}" cy="{cy - hh*0.75}" rx="14" ry="6" fill="{st["soot"]}" opacity="0.2" style="filter:blur(3px)"/>')
    if "spectacles" in ex:
        ex_ = hw * 0.42
        for sd in (-1, 1):
            o.append(P.detail(ell(CX + sd * ex_, cy + 2, 26, 22), None, 2.6))
        o.append(P.detail(f"M{CX - ex_ + 26},{cy} Q{CX},{cy - 8} {CX + ex_ - 26},{cy}", None, 2.2))
        o.append(P.detail(f"M{CX - ex_ - 26},{cy - 2} L{CX - hw * 1.0},{cy - 8} M{CX + ex_ + 26},{cy - 2} L{CX + hw * 1.0},{cy - 8}", None, 2.0))
    if "helmet_m1" in ex:
        hp = [(CX - hw * 1.26, cy - hh * 0.36), (CX - hw * 1.12, cy - hh * 0.92), (CX - hw * 0.55, cy - hh * 1.32), (CX, cy - hh * 1.4),
              (CX + hw * 0.55, cy - hh * 1.32), (CX + hw * 1.12, cy - hh * 0.92), (CX + hw * 1.26, cy - hh * 0.36)]
        o.append(P.shape(smooth(hp + [(CX, cy - hh * 0.5)]), "olive", s=12))
        o.append(P.shape(smooth([(CX - hw * 1.42, cy - hh * 0.4), (CX, cy - hh * 0.55), (CX + hw * 1.42, cy - hh * 0.4),
                                 (CX + hw * 1.38, cy - hh * 0.27), (CX, cy - hh * 0.4), (CX - hw * 1.38, cy - hh * 0.27)]), "olive", s=4))
        o.append(P.detail(f"M{CX - hw*0.7},{cy - hh*1.0} Q{CX},{cy - hh*1.22} {CX + hw*0.7},{cy - hh*1.0}", "olive", 0.8, 0.8))
    if "helmet_miner" in ex:
        hp = [(CX - hw * 1.18, cy - hh * 0.38), (CX - hw * 1.05, cy - hh * 0.9), (CX - hw * 0.5, cy - hh * 1.28), (CX, cy - hh * 1.34),
              (CX + hw * 0.5, cy - hh * 1.28), (CX + hw * 1.05, cy - hh * 0.9), (CX + hw * 1.18, cy - hh * 0.38)]
        o.append(P.shape(smooth(hp + [(CX, cy - hh * 0.5)]), "metal", s=12))
        o.append(P.shape(smooth([(CX - hw * 1.32, cy - hh * 0.42), (CX, cy - hh * 0.56), (CX + hw * 1.32, cy - hh * 0.42),
                                 (CX + hw * 1.28, cy - hh * 0.3), (CX, cy - hh * 0.42), (CX - hw * 1.28, cy - hh * 0.3)]), "metal", s=4))
        o.append(P.detail(f"M{CX - hw*0.6},{cy - hh*1.0} l20,8 M{CX + hw*0.4},{cy - hh*1.1} l14,10", "metal", 0.7, 0.9))
        o.append(f'<circle cx="{CX}" cy="{cy - hh*0.82}" r="34" fill="{st["glow2"]}" opacity="0.45" style="filter:blur(8px)"/>')
        o.append(P.shape(rect(CX - 20, cy - hh * 0.98, 40, 34, 6), "gold", s=4))
        o.append(P.shape(ell(CX, cy - hh * 0.98 + 17, 9, 11), "fire", s=2, hl=False))
    body = "\n".join(o)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">'
            f'<defs>{"".join(P.defs)}{"".join(FP.defs)}</defs>'
            f'<g transform="translate(-15,-6) scale(0.56)"><g {filt}>{body}</g></g></svg>')
