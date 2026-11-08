"""UX iteration guidance icons (Guide readiness states), in the toolbar's ink idiom (96x96, drawn in a 128-unit space).
python3 make_guide_icons.py [--only=guide_ready]  ->  assets/sprites/ui/template_<name>.png
  guide_ready       a green wax seal with a tick: you have it / you can do it now
  guide_obtainable  an hourglass: obtainable, later or elsewhere
  guide_locked      a padlock in rubric: a public obstacle stands in the way
  guide_unavailable a struck-through ring: no known source
  guide_knowledge   a sealed note with a key: bought knowledge
No lettering: the game draws words next to them."""
import os
from artlib import (painter, svg_doc, ink_filter, lin, fill, render, only_filter, ell, rect, poly, smooth,
                    INK, RUB, GILT, SPR)

UI = os.path.join(SPR, "ui")
GREEN = "#3f7a3a"
AMBER = "#c08a2a"


def J(o):
    return "\n".join(x for x in o if x)


def guide_ready(P):
    seal = smooth([(64, 10), (88, 18), (110, 40), (114, 66), (104, 92), (82, 112), (54, 116), (28, 102), (14, 76), (16, 46), (34, 20)], close=True)
    o = [fill(seal, GREEN) + lin(seal, INK, 3.2)]
    o.append(lin(ell(64, 64, 34), INK, 1.6, 0.5))
    o.append(lin("M40,66 L58,84 L90,44", "#f4ecd8", 9))
    o.append(lin("M40,66 L58,84 L90,44", INK, 2.2, 0.7))
    return J(o), ""


def guide_obtainable(P):
    o = [P.shape(rect(28, 12, 72, 12, 3), "wood", s=2), P.shape(rect(28, 104, 72, 12, 3), "wood", s=2)]
    glass = "M36,24 C36,52 58,56 58,64 C58,72 36,76 36,104 L92,104 C92,76 70,72 70,64 C70,56 92,52 92,24 Z"
    o.append(fill(glass, "#f4ecd8", 0.85) + lin(glass, INK, 3))
    o.append(fill("M46,34 C50,50 62,54 64,60 C66,54 78,50 82,34 Z", AMBER))
    o.append(fill("M42,102 C48,86 60,84 64,80 C68,84 80,86 86,102 Z", AMBER))
    o.append(lin("M64,62 L64,82", AMBER, 2.4))
    return J(o), ""


def guide_locked(P):
    o = [lin("M40,58 L40,40 C40,16 88,16 88,40 L88,58", INK, 9)]
    o.append(lin("M40,58 L40,40 C40,16 88,16 88,40 L88,58", "#8a8f96", 4))
    body = rect(24, 56, 80, 60, 8)
    o.append(fill(body, RUB) + lin(body, INK, 3.2))
    o.append(fill(ell(64, 80, 8), INK))
    o.append(fill(poly([(60, 82), (68, 82), (71, 102), (57, 102)]), INK))
    return J(o), ""


def guide_unavailable(P):
    o = [lin(ell(64, 64, 42), "#6b5b45", 9)]
    o.append(lin(ell(64, 64, 42), INK, 2, 0.6))
    o.append(lin("M34,94 L94,34", "#6b5b45", 9))
    o.append(lin("M34,94 L94,34", INK, 2, 0.6))
    return J(o), ""


def guide_knowledge(P):
    note = poly([(16, 34), (100, 22), (110, 96), (24, 110)])
    o = [P.shape(note, "paper", s=3)]
    o.append(lin("M30,50 L90,42 M32,64 L92,56 M34,78 L66,74", INK, 2, 0.55))
    o.append(fill(ell(92, 92, 16), RUB) + lin(ell(92, 92, 16), INK, 2.4))
    o.append(lin("M70,100 L44,100 M50,100 L50,108 M58,100 L58,106", GILT, 5))
    o.append(lin(ell(78, 100, 7), GILT, 4))
    return J(o), ""


ICONS = {k: v for k, v in globals().items() if k.startswith("guide_") and callable(v)}


def jobs():
    only = only_filter()
    js = []
    for name, fn in ICONS.items():
        if only and name not in only:
            continue
        P = painter(scale=1.25, lw_mul=0.95)
        body, emit = fn(P)
        f = ink_filter(P, wob=1.1, dil=1.4, grain=0.5, soot=0.5)
        inner = f'<g {f}>{body}</g><g>{emit}</g>'
        js.append(dict(name=f"ui_{name}", svg=svg_doc(96, 96, P, inner, ss=4, vw=128, vh=128), w=96, h=96, ss=4,
                       out=os.path.join(UI, name + ".png")))
    return js


if __name__ == "__main__":
    render(jobs(), workers=4)
