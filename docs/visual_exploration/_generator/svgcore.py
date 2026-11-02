"""Shared SVG helpers and the per-style 'painter' that turns plain shapes into
style-specific rendering (ink, painterly gradients, cel shading, hatching, flat)."""
import math
import random

_id = [0]


def uid(p="i"):
    _id[0] += 1
    return f"{p}{_id[0]}"


# ---------------------------------------------------------------- geometry
def ell(cx, cy, rx, ry=None):
    ry = rx if ry is None else ry
    return (f"M{cx-rx:.1f},{cy:.1f} a{rx:.1f},{ry:.1f} 0 1,0 {2*rx:.1f},0 "
            f"a{rx:.1f},{ry:.1f} 0 1,0 {-2*rx:.1f},0 Z")


def rect(x, y, w, h, r=0):
    if r <= 0:
        return f"M{x:.1f},{y:.1f} h{w:.1f} v{h:.1f} h{-w:.1f} Z"
    r = min(r, w / 2, h / 2)
    return (f"M{x+r:.1f},{y:.1f} h{w-2*r:.1f} a{r},{r} 0 0 1 {r},{r} v{h-2*r:.1f} "
            f"a{r},{r} 0 0 1 {-r},{r} h{-(w-2*r):.1f} a{r},{r} 0 0 1 {-r},{-r} "
            f"v{-(h-2*r):.1f} a{r},{r} 0 0 1 {r},{-r} Z")


def poly(pts, close=True):
    s = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    return s + (" Z" if close else "")


def smooth(pts, close=True, t=0.5):
    """Catmull-Rom spline through points -> cubic bezier path."""
    n = len(pts)
    if n < 3:
        return poly(pts, close)
    out = [f"M{pts[0][0]:.1f},{pts[0][1]:.1f}"]
    rng = range(n) if close else range(n - 1)
    for i in rng:
        p0 = pts[(i - 1) % n] if (close or i > 0) else pts[0]
        p1 = pts[i]
        p2 = pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if (close or i + 2 < n) else pts[-1]
        c1 = (p1[0] + (p2[0] - p0[0]) * t / 3, p1[1] + (p2[1] - p0[1]) * t / 3)
        c2 = (p2[0] - (p3[0] - p1[0]) * t / 3, p2[1] - (p3[1] - p1[1]) * t / 3)
        out.append(f"C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}")
    return " ".join(out) + (" Z" if close else "")


def blob(cx, cy, r, lobes=9, amp=0.12, seed=1, squash=1.0, rot=0.0):
    rnd = random.Random(seed)
    pts = []
    n = lobes * 2
    for i in range(n):
        a = rot + i / n * math.tau
        rr = r * (1 + (amp if i % 2 == 0 else -amp * 0.4) + rnd.uniform(-amp, amp) * 0.5)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * squash))
    return smooth(pts)


def wobbly_ell(cx, cy, rx, ry, seed=1, amp=0.04, n=14):
    rnd = random.Random(seed)
    pts = []
    for i in range(n):
        a = i / n * math.tau
        k = 1 + rnd.uniform(-amp, amp)
        pts.append((cx + math.cos(a) * rx * k, cy + math.sin(a) * ry * k))
    return smooth(pts)


def tf(d, dx=0, dy=0):
    return d  # placeholder (transforms are applied with SVG attributes)


# ---------------------------------------------------------------- painter
class Painter:
    """Collects <defs> and renders shapes in one of the five styles."""

    def __init__(self, st, scale=1.0, light=(-1, -1)):
        self.st = st
        self.k = st["key"]
        self.pal = st["pal"]
        self.ink = st["ink"]
        self.defs = []
        self.scale = scale
        self.lw_mul = 1.0
        self.light = light
        self.grad_cache = {}
        self.hatch_id = uid("hatch")
        self.xhatch_id = uid("xh")
        hcol = self.st.get("pencil", self.ink)
        hw = {"gothic": 1.6, "ballpoint": 1.05, "sketchbook": 0.8}.get(self.k, 1.1) * scale
        sp = {"gothic": 7, "ballpoint": 4.2, "sketchbook": 4.5}.get(self.k, 5) * scale
        self.defs.append(
            f'<pattern id="{self.hatch_id}" width="{sp}" height="{sp}" patternUnits="userSpaceOnUse" '
            f'patternTransform="rotate(-35)"><line x1="0" y1="0" x2="0" y2="{sp}" stroke="{hcol}" '
            f'stroke-width="{hw}"/></pattern>')
        self.defs.append(
            f'<pattern id="{self.xhatch_id}" width="{sp}" height="{sp}" patternUnits="userSpaceOnUse" '
            f'patternTransform="rotate(35)"><line x1="0" y1="0" x2="0" y2="{sp}" stroke="{hcol}" '
            f'stroke-width="{hw*0.9}"/></pattern>')
        if self.k == "ballpoint":
            # third hatch direction + red-ink versions for accent roles
            self.h3_id = uid("h3")
            self.defs.append(
                f'<pattern id="{self.h3_id}" width="{sp}" height="{sp}" patternUnits="userSpaceOnUse" '
                f'patternTransform="rotate(90)"><line x1="0" y1="0" x2="0" y2="{sp}" stroke="{hcol}" '
                f'stroke-width="{hw*0.8}"/></pattern>')
            self.red = {}
            for name, rot in (("h", -35), ("x", 35), ("3", 90)):
                rid = uid("rh")
                self.defs.append(
                    f'<pattern id="{rid}" width="{sp}" height="{sp}" patternUnits="userSpaceOnUse" '
                    f'patternTransform="rotate({rot})"><line x1="0" y1="0" x2="0" y2="{sp}" stroke="{self.st["accent"]}" '
                    f'stroke-width="{hw}"/></pattern>')
                self.red[name] = rid

    # -- colour helpers
    def c(self, role, i=1):
        return self.pal[role][i]

    def grad(self, role):
        if role in self.grad_cache:
            return self.grad_cache[role]
        gid = uid("g")
        l, b, s = self.pal[role]
        self.defs.append(
            f'<radialGradient id="{gid}" cx="0.36" cy="0.3" r="0.85" fx="0.3" fy="0.24">'
            f'<stop offset="0" stop-color="{l}"/><stop offset="0.45" stop-color="{b}"/>'
            f'<stop offset="1" stop-color="{s}"/></radialGradient>')
        self.grad_cache[role] = gid
        return gid

    def _crescent(self, d, dx, dy, fill, opacity=1.0, extra=""):
        """Fill the part of shape d NOT covered by d shifted by (dx,dy)."""
        mid = uid("m")
        self.defs.append(
            f'<mask id="{mid}">'
            f'<rect x="-4000" y="-4000" width="10000" height="10000" fill="white"/>'
            f'<path d="{d}" fill="black" transform="translate({dx:.1f},{dy:.1f})"/></mask>')
        return f'<path d="{d}" fill="{fill}" opacity="{opacity}" mask="url(#{mid})" {extra}/>'

    def shape(self, d, role, s=None, line=True, lw=None, hl=True, flat=False, opacity=1.0,
              rim=True, fill_override=None):
        """Main entry: draw a closed shape of material `role`."""
        k = self.k
        l, b, sh = self.pal[role]
        if fill_override:
            b = fill_override
        s = (10 if s is None else s) * self.scale
        lx, ly = self.light
        lw = (self.st["line_w"] if lw is None else lw) * self.scale * self.lw_mul
        out = [f'<g opacity="{opacity}">'] if opacity != 1 else []
        if k == "gothic":
            out.append(f'<path d="{d}" fill="{b}"/>')
            if not flat:
                out.append(self._crescent(d, lx * s, ly * s, sh))
                out.append(self._crescent(d, lx * s * 1.7, ly * s * 1.7, f"url(#{self.hatch_id})", 0.55))
                if hl:
                    out.append(self._crescent(d, -lx * s * 0.35, -ly * s * 0.35, l, 0.85))
                if rim:
                    rc = "#7f9cc0" if role in ("foliage", "foliage2", "grass", "roof_a", "roof_b", "stone", "water") else self.st["glow"]
                    out.append(self._crescent(d, 0, -s * 0.45, rc, 0.5))
            if line and lw:
                out.append(f'<path d="{d}" fill="none" stroke="{self.ink}" stroke-width="{lw:.1f}" '
                           f'stroke-linejoin="round"/>')
        elif k == "storybook":
            fill = b if flat else f"url(#{self.grad(role)})"
            out.append(f'<path d="{d}" fill="{fill}"/>')
            if not flat:
                cid = uid("c")
                self.defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
                out.append(f'<g clip-path="url(#{cid})">' + self._crescent(d, lx * s * 0.9, ly * s * 0.9, sh, 0.45,
                                          'style="filter:blur(%.1fpx)"' % (3 * self.scale)) + '</g>')
            if line and lw:
                out.append(f'<path d="{d}" fill="none" stroke="{sh}" stroke-width="{lw:.1f}" '
                           f'stroke-opacity="0.75" stroke-linejoin="round"/>')
        elif k == "bold":
            out.append(f'<path d="{d}" fill="{b}"/>')
            if not flat:
                out.append(self._crescent(d, lx * s, ly * s, sh))
                if hl:
                    out.append(self._crescent(d, -lx * s * 0.45, -ly * s * 0.45, l))
            if line and lw:
                out.append(f'<path d="{d}" fill="none" stroke="{self.ink}" stroke-width="{lw:.1f}" '
                           f'stroke-linejoin="round"/>')
        elif k == "ink":
            out.append(f'<path d="{d}" fill="{b}" opacity="0.92"/>')
            if not flat:
                out.append(self._crescent(d, lx * s * 0.9, ly * s * 0.9, sh, 0.55))
                out.append(self._crescent(d, lx * s * 1.4, ly * s * 1.4, f"url(#{self.hatch_id})", 0.9))
                out.append(self._crescent(d, lx * s * 0.6, ly * s * 0.6, f"url(#{self.xhatch_id})", 0.6))
            if line and lw:
                out.append(f'<path d="{d}" fill="none" stroke="{self.ink}" stroke-width="{lw:.1f}" '
                           f'stroke-linejoin="round" stroke-linecap="round"/>')
        elif k == "ballpoint":
            red = role in self.st["red_roles"]
            lc = self.st["accent"] if red else self.ink
            hid = self.red["h"] if red else self.hatch_id
            xid = self.red["x"] if red else self.xhatch_id
            tid = self.red["3"] if red else self.h3_id
            tone = self.st["tone"].get(role, 0)
            if not fill_override:
                b = "#fdf2f0" if red else "#fcfcf9"
            out.append(f'<path d="{d}" fill="{b}"/>')
            if not flat:
                if tone >= 1:
                    out.append(f'<path d="{d}" fill="url(#{hid})" opacity="0.6"/>')
                if tone >= 2:
                    out.append(f'<path d="{d}" fill="url(#{xid})" opacity="0.6"/>')
                if tone >= 3:
                    out.append(f'<path d="{d}" fill="url(#{tid})" opacity="0.6"/>')
                out.append(self._crescent(d, lx * s * 1.1, ly * s * 1.1, f"url(#{hid})", 0.95))
                out.append(self._crescent(d, lx * s * 0.6, ly * s * 0.6, f"url(#{xid})", 0.85))
            elif fill_override is None and tone >= 1:
                out.append(f'<path d="{d}" fill="url(#{hid})" opacity="0.45"/>')
            if line and lw:
                out.append(f'<path d="{d}" fill="none" stroke="{lc}" stroke-width="{lw*0.55:.1f}" opacity="0.5" '
                           f'transform="translate({1.3*self.lw_mul:.1f},{-0.9*self.lw_mul:.1f})" stroke-linejoin="round"/>')
                out.append(f'<path d="{d}" fill="none" stroke="{lc}" stroke-width="{lw:.1f}" opacity="0.92" '
                           f'stroke-linejoin="round" stroke-linecap="round"/>')
        elif k == "sketchbook":
            out.append(f'<path d="{d}" fill="{b}" opacity="0.9"/>')
            cid = uid("c")
            self.defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
            inner = [f'<path d="{d}" fill="none" stroke="{sh}" stroke-width="{7*self.scale:.1f}" opacity="0.32" style="filter:blur({1.6*self.scale:.1f}px)"/>']
            if not flat:
                inner.append(self._crescent(d, lx * s * 0.9, ly * s * 0.9, sh, 0.38, 'style="filter:blur(%.1fpx)"' % (2.5 * self.scale)))
                inner.append(self._crescent(d, lx * s * 1.2, ly * s * 1.2, f"url(#{self.hatch_id})", 0.55))
                if hl:
                    inner.append(self._crescent(d, -lx * s * 0.5, -ly * s * 0.5, l, 0.55, 'style="filter:blur(%.1fpx)"' % (2 * self.scale)))
            out.append(f'<g clip-path="url(#{cid})">' + "".join(inner) + "</g>")
            if line and lw:
                out.append(f'<path d="{d}" fill="none" stroke="{self.ink}" stroke-width="{lw*0.45:.1f}" opacity="0.55" '
                           f'transform="translate({0.9*self.lw_mul:.1f},{0.8*self.lw_mul:.1f})" stroke-linejoin="round"/>')
                out.append(f'<path d="{d}" fill="none" stroke="{self.ink}" stroke-width="{lw:.1f}" opacity="0.88" '
                           f'stroke-linejoin="round" stroke-linecap="round"/>')
        else:  # prod
            out.append(f'<path d="{d}" fill="{b}"/>')
            if not flat:
                out.append(self._crescent(d, lx * s * 0.8, ly * s * 0.8, sh))
        if opacity != 1:
            out.append("</g>")
        return "\n".join(out)

    def detail(self, d, role=None, w=1.0, op=1.0, cap="round"):
        """Interior detail line (seams, folds, engravings)."""
        k = self.k
        w = w * self.scale * self.lw_mul
        if k == "gothic":
            col, ww = self.ink, w * 3.2
        elif k == "storybook":
            col, ww, op = (self.pal[role][2] if role else self.ink), w * 2.0, op * 0.8
        elif k == "bold":
            col, ww = self.ink, w * 2.6
        elif k == "ink":
            col, ww = self.ink, w * 1.6
        elif k == "ballpoint":
            col, ww = (self.st["accent"] if role in self.st["red_roles"] else self.ink), w * 1.4
        elif k == "sketchbook":
            col, ww, op = self.ink, w * 1.8, op * 0.85
        else:
            col, ww = (self.pal[role][2] if role else "#00000055"), w * 2.2
        return (f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{ww:.1f}" '
                f'stroke-linecap="{cap}" stroke-linejoin="round" opacity="{op}"/>')

    def spot(self, d, color, op=1.0):
        return f'<path d="{d}" fill="{color}" opacity="{op}"/>'

    # -- group-level treatments
    def sprite_filter(self):
        """Filter applied to an entire sprite/composition group."""
        k = self.k
        fid = uid("f")
        sc = self.scale
        if k == "gothic":
            ow = self.st["outer_w"] * sc
            self.defs.append(f'''<filter id="{fid}" x="-10%" y="-10%" width="120%" height="120%">
  <feTurbulence type="fractalNoise" baseFrequency="{0.035/sc:.4f}" numOctaves="2" seed="3" result="n"/>
  <feDisplacementMap in="SourceGraphic" in2="n" scale="{self.st['rough']*sc:.1f}" xChannelSelector="R" yChannelSelector="G" result="d"/>
  <feMorphology in="d" operator="dilate" radius="{ow:.1f}" result="dil"/>
  <feFlood flood-color="{self.ink}"/><feComposite in2="dil" operator="in" result="ol"/>
  <feTurbulence type="fractalNoise" baseFrequency="{0.9/sc:.3f}" numOctaves="2" seed="8" result="grain"/>
  <feColorMatrix in="grain" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -1.1 0.75" result="g2"/>
  <feComposite in="g2" in2="d" operator="in" result="g3"/>
  <feMerge><feMergeNode in="ol"/><feMergeNode in="d"/><feMergeNode in="g3"/></feMerge>
</filter>''')
        elif k == "storybook":
            self.defs.append(f'''<filter id="{fid}" x="-10%" y="-10%" width="120%" height="120%">
  <feTurbulence type="fractalNoise" baseFrequency="{0.02/sc:.4f}" numOctaves="2" seed="5" result="n"/>
  <feDisplacementMap in="SourceGraphic" in2="n" scale="{self.st['rough']*sc:.1f}" xChannelSelector="R" yChannelSelector="G" result="d"/>
  <feTurbulence type="fractalNoise" baseFrequency="{0.55/sc:.3f}" numOctaves="3" seed="2" result="paper"/>
  <feColorMatrix in="paper" type="matrix" values="0 0 0 0 0.45  0 0 0 0 0.32  0 0 0 0 0.2  0 0 0 -0.7 0.42" result="p2"/>
  <feComposite in="p2" in2="d" operator="in" result="p3"/>
  <feMerge><feMergeNode in="d"/><feMergeNode in="p3"/></feMerge>
</filter>''')
        elif k == "bold":
            ow = self.st["outer_w"] * sc
            self.defs.append(f'''<filter id="{fid}" x="-10%" y="-10%" width="120%" height="120%">
  <feMorphology in="SourceAlpha" operator="dilate" radius="{ow:.1f}" result="dil"/>
  <feFlood flood-color="{self.ink}"/><feComposite in2="dil" operator="in" result="ol"/>
  <feMerge><feMergeNode in="ol"/><feMergeNode in="SourceGraphic"/></feMerge>
</filter>''')
        elif k == "ink":
            self.defs.append(f'''<filter id="{fid}" x="-10%" y="-10%" width="120%" height="120%">
  <feTurbulence type="fractalNoise" baseFrequency="{0.05/sc:.4f}" numOctaves="2" seed="4" result="n"/>
  <feDisplacementMap in="SourceGraphic" in2="n" scale="{self.st['rough']*sc:.1f}" xChannelSelector="R" yChannelSelector="G" result="d"/>
  <feTurbulence type="fractalNoise" baseFrequency="{0.7/sc:.3f}" numOctaves="2" seed="11" result="grain"/>
  <feColorMatrix in="grain" type="matrix" values="0 0 0 0 0.17  0 0 0 0 0.11  0 0 0 0 0.07  0 0 0 -1.2 0.7" result="g2"/>
  <feComposite in="g2" in2="d" operator="in" result="g3"/>
  <feMerge><feMergeNode in="d"/><feMergeNode in="g3"/></feMerge>
</filter>''')
        elif k == "ballpoint":
            # pen wobble + uneven ink pressure (alpha speckle on strokes only)
            self.defs.append(f'''<filter id="{fid}" x="-10%" y="-10%" width="120%" height="120%">
  <feTurbulence type="fractalNoise" baseFrequency="{0.06/sc:.4f}" numOctaves="2" seed="6" result="n"/>
  <feDisplacementMap in="SourceGraphic" in2="n" scale="{self.st['rough']*sc:.1f}" xChannelSelector="R" yChannelSelector="G" result="d"/>
  <feTurbulence type="fractalNoise" baseFrequency="{1.1/sc:.3f}" numOctaves="1" seed="12" result="pr"/>
  <feColorMatrix in="pr" type="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 -0.9 0.55" result="p2"/>
  <feComposite in="p2" in2="d" operator="in" result="p3"/>
  <feMerge><feMergeNode in="d"/><feMergeNode in="p3"/></feMerge>
</filter>''')
        elif k == "sketchbook":
            self.defs.append(f'''<filter id="{fid}" x="-10%" y="-10%" width="120%" height="120%">
  <feTurbulence type="fractalNoise" baseFrequency="{0.03/sc:.4f}" numOctaves="2" seed="15" result="n"/>
  <feDisplacementMap in="SourceGraphic" in2="n" scale="{self.st['rough']*sc:.1f}" xChannelSelector="R" yChannelSelector="G" result="d"/>
  <feTurbulence type="fractalNoise" baseFrequency="{0.6/sc:.3f}" numOctaves="3" seed="3" result="paper"/>
  <feColorMatrix in="paper" type="matrix" values="0 0 0 0 0.35  0 0 0 0 0.27  0 0 0 0 0.2  0 0 0 -0.8 0.45" result="p2"/>
  <feComposite in="p2" in2="d" operator="in" result="p3"/>
  <feTurbulence type="fractalNoise" baseFrequency="{0.045/sc:.4f}" numOctaves="3" seed="21" result="bloom"/>
  <feColorMatrix in="bloom" type="matrix" values="0 0 0 0 1  0 0 0 0 0.97  0 0 0 0 0.9  0 0 0 0.55 -0.33" result="b2"/>
  <feComposite in="b2" in2="d" operator="in" result="b3"/>
  <feMerge><feMergeNode in="d"/><feMergeNode in="b3"/><feMergeNode in="p3"/></feMerge>
</filter>''')
        else:
            return ""
        return f'filter="url(#{fid})"'

    def defs_svg(self):
        return "<defs>" + "\n".join(self.defs) + "</defs>"


def svg_doc(w, h, body, painter, bg=None):
    bgr = f'<rect width="{w}" height="{h}" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}">{painter.defs_svg()}{bgr}{body}</svg>')
