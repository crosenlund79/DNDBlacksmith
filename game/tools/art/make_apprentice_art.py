"""Apprentice art (iteration 012, "The Workshop Comes Alive").
One generic maker's mark for every apprentice of the Ironhand forge (marks/apprentice, 32x32): a copper-rimmed
punch-mark — a tiny anvil struck low on the disc under a ring of punched dots, the way a learner stamps beside the
master's mark. Each apprentice's own initials are named in their mark's text, not drawn (no lettering in art).
python3 make_apprentice_art.py  ->  assets/sprites/marks/template_apprentice.png"""
import os
from artlib import (painter, svg_doc, ink_filter, glow, lin, fill, render, ell, poly, INK, EMBER)
from make_itemstory_art import _disc, J, MARKS, BRASS

COPPER = "#b06a3a"


def mark_apprentice(P):
    """A small anvil struck low, under an arc of seven punched dots (a learner's punch-mark)."""
    o = _disc(P, rim=COPPER, face="#33281f")
    anvil = poly([(38, 80), (54, 79), (57, 74), (88, 74), (96, 70), (93, 80), (80, 83), (76, 90), (82, 98), (48, 98), (54, 90), (51, 83)])
    o.append(fill(anvil, BRASS) + lin(anvil, INK, 2.2))
    for i, (x, y) in enumerate([(30, 62), (36, 46), (48, 34), (64, 30), (80, 34), (92, 46), (98, 62)]):
        r = 5.2 if i == 3 else 4.2
        o.append(fill(ell(x, y, r + 1.6), INK) + fill(ell(x, y, r), "#e0b080"))
    o.append(lin("M58,60 L70,60 M64,54 L64,66", "#e0b080", 3, 0.8))
    return J(o), glow(P, 64, 60, 12, EMBER, 0.2)


def jobs():
    P = painter(scale=1.25, lw_mul=0.95)
    body, emit = mark_apprentice(P)
    f = ink_filter(P, wob=0.6, dil=0.8, grain=0.4, soot=0.3)
    inner = f'<g {f}>{body}</g><g>{emit}</g>'
    return [dict(name="marks_apprentice", svg=svg_doc(32, 32, P, inner, ss=8, vw=128, vh=128), w=32, h=32, ss=8,
                 out=os.path.join(MARKS, "apprentice.png"))]


if __name__ == "__main__":
    render(jobs(), workers=1)
